<#
    Convert-McrToolkitToSingleDb.ps1

    Rewrites the MCR FV7 toolkit to run inside the
    MortgageGovernance database instead of its own database.

    Required for Azure SQL Database, which supports neither
    USE nor three-part cross-database names. Harmless on
    Managed Instance and on the box product.

    Re-run this after every build_catalog.py regeneration.
    Never hand-edit the output.

    Usage:
      .\Convert-McrToolkitToSingleDb.ps1 `
          -SourceDir ".\mcr-source" -OutputDir ".\sql\mcr"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceDir,
    [Parameter(Mandatory)][string]$OutputDir
)

$ErrorActionPreference = 'Stop'

$StagingTables = @(
    'Applications','ClosedLoans','Investors','Repurchases',
    'ServicingPortfolio','ServicingTransfers',
    'WarehouseLines','HmdaLar'
)

# 13 is TMDL, not SQL. It is not transformed here.
$RunOrder = @('01','02','03','04','05','06','07','08',
              '09','10','11','12','14','15')

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$enc = New-Object System.Text.UTF8Encoding $true
$tot = [ordered]@{ Use=0; Db=0; Dbo=0; Pbi=0; Schema=0 }

foreach ($file in Get-ChildItem -Path $SourceDir `
                  -Filter 'MCR_Toolkit_*.sql' | Sort-Object Name) {

    if ($file.Name -notmatch '^MCR_Toolkit_(\d\d)_(.+)\.sql$') {
        continue
    }
    $num  = $Matches[1]
    $name = $Matches[2]
    if ($RunOrder -notcontains $num) { continue }

    $t = Get-Content -LiteralPath $file.FullName -Raw

    # 1. Drop the CREATE DATABASE block (file 01 only).
    $p = "IF DB_ID\('MCR_Toolkit'\) IS NULL\s*\r?\n" +
         "\s*CREATE DATABASE MCR_Toolkit;\s*\r?\nGO\r?\n"
    $tot.Db += ([regex]::Matches($t, $p)).Count
    $t = $t -replace $p, ''

    # 2. Drop USE, with or without a trailing GO.
    $p = "(?m)^USE MCR_Toolkit;[ \t]*\r?\n(?:GO[ \t]*\r?\n)?"
    $tot.Use += ([regex]::Matches($t, $p)).Count
    $t = $t -replace $p, ''

    # 3. Retarget staging tables out of dbo. Named tables
    #    only; a blanket dbo. replace is unsafe.
    foreach ($tb in $StagingTables) {
        $p = "\bdbo\.$tb\b"
        $tot.Dbo += ([regex]::Matches($t, $p)).Count
        $t = $t -replace $p, "mcrstg.$tb"
    }

    # 4. Retarget the toolkit view schema so it cannot
    #    collide with the governed pbi schema.
    $p = "IF SCHEMA_ID\('pbi'\) IS NULL " +
         "EXEC\('CREATE SCHEMA pbi;'\);"
    $tot.Schema += ([regex]::Matches($t, $p)).Count
    $t = $t -replace $p,
        ("IF SCHEMA_ID('mcrpbi') IS NULL " +
         "EXEC('CREATE SCHEMA mcrpbi;');")

    $p = "\bpbi\.([A-Za-z_])"
    $tot.Pbi += ([regex]::Matches($t, $p)).Count
    $t = $t -replace $p, 'mcrpbi.$1'

    # 5. Add the two new schema guards alongside mcr.
    if ($num -eq '01') {
        $t = $t -replace
            "IF SCHEMA_ID\('mcr'\) IS NULL EXEC\('CREATE SCHEMA mcr;'\);",
            ("IF SCHEMA_ID('mcr') IS NULL EXEC('CREATE SCHEMA mcr;');`r`nGO`r`n" +
             "IF SCHEMA_ID('mcrstg') IS NULL EXEC('CREATE SCHEMA mcrstg;');`r`nGO`r`n" +
             "IF SCHEMA_ID('mcrpbi') IS NULL EXEC('CREATE SCHEMA mcrpbi;');")
    }

    # 6. Provenance banner.
    $hdr = @"
/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from $($file.Name)
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

"@
    $t = $hdr + $t

    $out = Join-Path $OutputDir "mcr_${num}_${name}.sql"
    [System.IO.File]::WriteAllText($out, $t, $enc)
    Write-Host "  wrote mcr_${num}_${name}.sql"
}

Write-Host ""
Write-Host "Transformation counts:"
$tot.GetEnumerator() | ForEach-Object {
    Write-Host ("  {0,-8} {1}" -f $_.Key, $_.Value)
}

# Fail loudly rather than shipping a partial conversion.
# Header text is excluded from the residual scan.
$bad = Select-String -Path (Join-Path $OutputDir '*.sql') `
       -Pattern 'USE MCR_Toolkit|\bdbo\.|(?<!r)\bpbi\.|MCR_Toolkit\.' |
       Where-Object { $_.Line -notmatch '^\s*(/\*|\*|\s+No USE)' }

if ($bad) {
    Write-Host ""
    Write-Warning "Residual artifacts found:"
    $bad | ForEach-Object {
        Write-Host ("  {0}:{1}" -f $_.Filename, $_.LineNumber)
    }
    exit 1
}
Write-Host ""
Write-Host "Clean. Zero residual cross-database artifacts."
