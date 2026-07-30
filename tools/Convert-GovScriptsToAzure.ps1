<#
    Convert-GovScriptsToAzure.ps1

    Removes USE statements so the repo is reproducible
    against Azure SQL Database (EngineEdition 5), which does
    not support switching database context.

    DEFERRED WORK. Your objects already exist in Azure and
    you are not re-running 002-024, so this is a
    reproducibility task for the final README pass, not a
    deployment blocker. Run it before the portfolio zip.

    001 is replaced by hand with 001_create_schemas.sql, not
    transformed, because its database-scope statements have
    no Azure equivalent.

    Counts whatever files are present; no hardcoded list.

    Usage:
      .\Convert-GovScriptsToAzure.ps1 `
          -SourceDir ".\sql-source" -OutputDir ".\sql"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceDir,
    [Parameter(Mandatory)][string]$OutputDir
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$enc   = New-Object System.Text.UTF8Encoding $true
$total = 0
$files = 0

foreach ($f in Get-ChildItem -Path $SourceDir -Filter '0*.sql' |
                Sort-Object Name) {

    if ($f.Name -match '^001_') {
        Write-Host "  $($f.Name)  SKIPPED (replaced by hand)"
        continue
    }

    $t = Get-Content -LiteralPath $f.FullName -Raw
    $p = "(?m)^USE MortgageGovernance;[ \t]*\r?\n(?:GO[ \t]*\r?\n)?"
    $n = ([regex]::Matches($t, $p)).Count
    $t = $t -replace $p, ''

    if ($n -gt 0) {
        $t = ("/* Azure SQL Database form. Connect directly to`r`n" +
              "   MortgageGovernance. No USE statement. */`r`n") + $t
    }

    [System.IO.File]::WriteAllText(
        (Join-Path $OutputDir $f.Name), $t, $enc)

    Write-Host ("  {0,-45} USE removed: {1}" -f $f.Name, $n)
    $total += $n
    $files++
}

Write-Host ""
Write-Host "Files written: $files   USE statements removed: $total"

$bad = Select-String -Path (Join-Path $OutputDir '0*.sql') `
       -Pattern '(?m)^USE |ALTER DATABASE|CREATE DATABASE'
if ($bad) {
    Write-Host ""
    Write-Warning "Residual database-scope statements:"
    $bad | ForEach-Object {
        Write-Host ("  {0}:{1}  {2}" -f `
            $_.Filename, $_.LineNumber, $_.Line.Trim())
    }
    exit 1
}
Write-Host "Clean. Repo is Azure SQL Database reproducible."
