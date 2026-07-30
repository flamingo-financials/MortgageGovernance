/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_15_mbfrf_layer.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT - ADD-ON
   15 - MBFRF layer (Option A: control + keying package, not a filing engine)
   ----------------------------------------------------------------------------
   Prereq: 01-08 installed. Run once per deploy; idempotent. Deploy BEFORE
   running 12 if you want the demo dataset to stage MBFRF values and
   exercise rules 13/14.

   What this is: the Mortgage Bankers' Financial Reporting Form
   (Fannie Mae Form 1002 / Freddie Mac Form 1055 / Ginnie Mae HUD-11750)
   as a STAGED, CHECKED, RECONCILED, AND ARCHIVED dataset. Every nonbank
   agency seller/servicer files it quarterly (due 30 days after quarter
   end; 60 for Q4) via the WebMB site, CEO/CFO-certified. Large nonbanks
   ($50B+ servicing UPB) also file a monthly 1002A subset.

   What this is NOT: a submission engine. WebMB is a keyed web form with
   no XML upload, so the toolkit's role ends at a verified keying package:
     rule 13 (MBFRF_CHECK)  internal consistency - balance sheet ties,
                            schedule detail sums to totals. Failures gate
                            the KEYING PACKAGE and the MBFRF archive; they
                            never block MCR XML generation (severity is
                            WARNING so the 05 error gate is untouched -
                            the hard gate lives in the package/archive
                            procs instead).
     rule 14 (MBFRF_RECON)  cross-report reconciliation - the same GL and
                            loan population reported to the states (MCR)
                            and to the agencies (MBFRF) must tell one
                            story. Tolerance-based, dispositioned, never
                            blocking - the rule 12 pattern, second
                            instance.

   Objects:
     mcr.MbfrfCatalog        field reference (schedule, label, basis,
                             derived vs manual). SEEDED AS A REPRESENTATIVE
                             SUBSET for demonstration - complete and verify
                             field codes against the current WebMB
                             definitions before production use.
                             Compliance-owned, like the bridges.
     mcr.MbfrfValues         staged values for the quarter, WHOLE DOLLARS
                             (the keying package converts to the rounded
                             thousands WebMB expects)
     mcr.MbfrfCheck          rule 13 definitions: total field = sum of
                             component fields. Compliance-owned config.
     mcr.McrMbfrfBridge      rule 14 definitions: what compares to what,
                             tolerance, documented exclusions
     mcr.usp_LoadMbfrfFromSource  derives production / servicing /
                             repurchase fields from the dbo staging tables;
                             financial-statement fields are controlled
                             manual entries (same posture as MCR FC)
     mcr.usp_ValidateMbfrf   runs rules 13 + 14, returns both grids,
                             writes findings to mcr.ValidationResults
     mcr.usp_GetMbfrfKeyingPackage  the ordered WebMB entry grid, in
                             rounded thousands. REFUSES if rule 13
                             findings exist.
     mcr.usp_ArchiveMbfrf    freezes the keyed values append-only with a
                             SHA-256 hash. REFUSES if rule 13 findings
                             exist.
     mcr.usp_VerifyMbfrfArchive  recomputes and compares the hash
     mcrpbi.FactMbfrf           the staged values for the Power BI model
                             (recon findings surface through the existing
                             mcrpbi.FactValidation view)

   OPERATION ORDER: once deployed, mcr.usp_RunFilingPipeline runs
   usp_ValidateMbfrf automatically as stage 3b (after validate and the
   rule 12 recon, before the archive snapshot), so rules 13/14 findings
   are part of the immutable archive record. Stage MBFRF values (loader +
   manual entries) BEFORE running the pipeline. Standalone EXEC remains
   valid for reruns - always AFTER usp_ValidateFiling, which deletes all
   validation rows for the filing, including these.
   ============================================================================ */

/* --------------------------------------------------------- field catalog */
IF OBJECT_ID('mcr.MbfrfValuesHistory') IS NOT NULL DROP TABLE mcr.MbfrfValuesHistory;
IF OBJECT_ID('mcr.MbfrfArchive')       IS NOT NULL DROP TABLE mcr.MbfrfArchive;
IF OBJECT_ID('mcr.MbfrfValues')        IS NOT NULL DROP TABLE mcr.MbfrfValues;
IF OBJECT_ID('mcr.MbfrfCheck')         IS NOT NULL DROP TABLE mcr.MbfrfCheck;
IF OBJECT_ID('mcr.McrMbfrfBridge')     IS NOT NULL DROP TABLE mcr.McrMbfrfBridge;
IF OBJECT_ID('mcr.MbfrfCatalog')       IS NOT NULL DROP TABLE mcr.MbfrfCatalog;
GO
CREATE TABLE mcr.MbfrfCatalog (
    FieldCode  VARCHAR(12)  NOT NULL PRIMARY KEY,
    Schedule   VARCHAR(60)  NOT NULL,
    Label      VARCHAR(200) NOT NULL,
    Basis      VARCHAR(10)  NOT NULL,   -- AMOUNT (whole $; keyed in $000s)
                                        -- or COUNT
    SourceType VARCHAR(10)  NOT NULL,   -- DERIVED (loader) or MANUAL (GL)
    EntryOrder INT          NOT NULL,
    IsActive   BIT          NOT NULL DEFAULT 1,
    CONSTRAINT CK_MbfrfCat_Basis  CHECK (Basis IN ('AMOUNT','COUNT')),
    CONSTRAINT CK_MbfrfCat_Source CHECK (SourceType IN ('DERIVED','MANUAL'))
);
GO
/* REPRESENTATIVE SUBSET - complete/verify against the current WebMB
   definitions (field-level help on every WebMB screen) before production.
   Amounts are staged in WHOLE DOLLARS; WebMB is keyed in rounded $000s. */
INSERT INTO mcr.MbfrfCatalog
(FieldCode, Schedule, Label, Basis, SourceType, EntryOrder) VALUES
('A010',  'Schedule A - Assets',
 'Cash and Cash Equivalents',                     'AMOUNT','MANUAL', 10),
('A030A', 'Schedule A - Assets',
 'Agency MBS (Investment Grade)',                 'AMOUNT','MANUAL', 20),
('A060',  'Schedule A - Assets',
 'Mortgage Loans Held for Sale, UPB',             'AMOUNT','MANUAL', 30),
('A100',  'Schedule A - Assets',
 'Total Assets',                                  'AMOUNT','MANUAL', 40),
('L100',  'Schedule B - Liabilities',
 'Total Liabilities',                             'AMOUNT','MANUAL', 50),
('E100',  'Schedule C - Equity',
 'Total Equity',                                  'AMOUNT','MANUAL', 60),
('I100',  'Income Statement',
 'Net Income, Quarter',                           'AMOUNT','MANUAL', 70),
('P010',  'Production',
 'Loans Originated - Retail, $',                  'AMOUNT','DERIVED',80),
('P020',  'Production',
 'Loans Originated - Third-Party Funded, $',      'AMOUNT','DERIVED',90),
('P100',  'Production',
 'Total Loans Originated, $',                     'AMOUNT','DERIVED',100),
('P101',  'Production',
 'Total Loans Originated, #',                     'COUNT', 'DERIVED',110),
('S010',  'Servicing',
 'Servicing Portfolio UPB - Owned / Under MSRs',  'AMOUNT','DERIVED',120),
('S020',  'Servicing',
 'Servicing Portfolio UPB - Subserviced for Others','AMOUNT','DERIVED',130),
('S100',  'Servicing',
 'Total Servicing Portfolio UPB',                 'AMOUNT','DERIVED',140),
('S101',  'Servicing',
 'Total Servicing Portfolio, #',                  'COUNT', 'DERIVED',150),
('R010',  'Repurchases',
 'Loans Repurchased During Quarter, UPB',         'AMOUNT','DERIVED',160),
('R011',  'Repurchases',
 'Loans Repurchased During Quarter, #',           'COUNT', 'DERIVED',170);
GO

/* --------------------------------------------------------- staged values */
CREATE TABLE mcr.MbfrfValues (
    FilingId  INT           NOT NULL,
    FieldCode VARCHAR(12)   NOT NULL
        REFERENCES mcr.MbfrfCatalog(FieldCode),
    NumValue  DECIMAL(15,2) NOT NULL,   -- whole dollars / counts
    CONSTRAINT PK_MbfrfValues PRIMARY KEY (FilingId, FieldCode)
);
GO

/* --------------------------------------- rule 13: internal consistency -- *
   Compliance-owned. Total field must equal the sum of ComponentCsv
   fields. Ginnie Mae runs automated cross-field consistency validations
   on MBFRF submissions each quarter - these checks are the pre-keying
   equivalent. Deactivate with IsActive = 0; never delete.               */
CREATE TABLE mcr.MbfrfCheck (
    CheckCode    VARCHAR(10)  NOT NULL PRIMARY KEY,
    Description  VARCHAR(200) NOT NULL,
    TotalField   VARCHAR(12)  NOT NULL
        REFERENCES mcr.MbfrfCatalog(FieldCode),
    ComponentCsv VARCHAR(200) NOT NULL,   -- comma-separated FieldCodes
    IsActive     BIT          NOT NULL DEFAULT 1
);
GO
INSERT INTO mcr.MbfrfCheck (CheckCode, Description, TotalField, ComponentCsv)
VALUES
('CHK01','Balance sheet ties: Total Assets = Total Liabilities + Equity',
 'A100','L100,E100'),
('CHK02','Production detail sums to total ($)',
 'P100','P010,P020'),
('CHK03','Servicing detail sums to total (UPB)',
 'S100','S010,S020');
GO

/* --------------------------------- rule 14: MCR <-> MBFRF reconciliation *
   Compliance-owned. Same GL, same loan population, two regulators.
   Both sides compared in WHOLE DOLLARS. An unexplained breach means one
   filing is wrong - investigate before submitting either.               */
CREATE TABLE mcr.McrMbfrfBridge (
    CheckCode    VARCHAR(10)  NOT NULL PRIMARY KEY,
    Description  VARCHAR(200) NOT NULL,
    McrSide      VARCHAR(200) NOT NULL,
    MbfrfField   VARCHAR(12)  NOT NULL
        REFERENCES mcr.MbfrfCatalog(FieldCode),
    Basis        VARCHAR(10)  NOT NULL,
    TolerancePct DECIMAL(9,2) NOT NULL,
    Exclusions   VARCHAR(400) NOT NULL,
    IsActive     BIT          NOT NULL DEFAULT 1,
    CONSTRAINT CK_MbfBridge_Basis CHECK (Basis IN ('AMOUNT','COUNT'))
);
GO
INSERT INTO mcr.McrMbfrfBridge
(CheckCode, Description, McrSide, MbfrfField, Basis, TolerancePct, Exclusions)
VALUES
('MBF01',
 'Unrestricted cash: MCR FC vs MBFRF',
 'MCR FC A010_1 (Cash and Cash Equivalents, Unrestricted)',
 'A010','AMOUNT', 1.00,
 'Same GL line, same quarter. Tolerance covers only the WebMB ' +
 'thousands-rounding and cutoff timing.'),
('MBF02',
 'Quarterly originations $: MCR closed loans vs MBFRF production',
 'MCR QM split AC920-940, retail + wholesale column groups only ' +
 '(ColumnNo 3-6), $, all states',
 'P100','AMOUNT', 10.00,
 'Brokered-out loans excluded from both sides (funded in another ' +
 'lender''s name; MBFRF production counts loans closed in your own ' +
 'name). Note-amount vs funded-amount basis drift absorbed by ' +
 'tolerance.'),
('MBF03',
 'Servicing portfolio UPB: MCR nationwide LS vs MBFRF servicing',
 'MCR LS010 + LS020 + LS030 (wholly owned, under MSRs, subservicing ' +
 'for others), $',
 'S100','AMOUNT', 5.00,
 'LS040 (subserviced BY others) excluded: MBFRF reports servicing ' +
 'performed, not loans another shop services for you. Definitional ' +
 'edges absorbed by tolerance.'),
('MBF04',
 'Quarterly repurchase UPB: MCR FC memo vs MBFRF',
 'MCR FC O360_1 (UPB of loans repurchased or indemnified during ' +
 'the quarter)',
 'R010','AMOUNT', 1.00,
 'Same source population. Tolerance covers rounding only; ' +
 'indemnifications without repurchase may require disposition.');
GO

/* ----------------------------------------------------------- loader ---- */
IF OBJECT_ID('mcr.usp_LoadMbfrfFromSource') IS NOT NULL
    DROP PROCEDURE mcr.usp_LoadMbfrfFromSource;
GO
CREATE PROCEDURE mcr.usp_LoadMbfrfFromSource @FilingId INT
AS
BEGIN
    /* Derives the DERIVED catalog fields from the dbo staging tables.
       MANUAL fields (balance sheet, income) are controlled entries -
       same posture as the MCR FC schedules - and are left untouched. */
    SET NOCOUNT ON;

    DELETE v
    FROM mcr.MbfrfValues v
    JOIN mcr.MbfrfCatalog c ON c.FieldCode = v.FieldCode
    WHERE v.FilingId = @FilingId AND c.SourceType = 'DERIVED';

    INSERT INTO mcr.MbfrfValues (FilingId, FieldCode, NumValue)
    SELECT @FilingId, x.FieldCode, x.Val
    FROM (
        /* production: loans closed in own name (exclude brokered-out) */
        SELECT FieldCode = 'P010',
               Val = ISNULL(SUM(CASE WHEN Channel = 'ClosedRetail'
                                     THEN NoteAmount END), 0)
        FROM mcrstg.ClosedLoans WHERE FilingId = @FilingId
        UNION ALL
        SELECT 'P020',
               ISNULL(SUM(CASE WHEN Channel = 'ClosedWholesale'
                               THEN NoteAmount END), 0)
        FROM mcrstg.ClosedLoans WHERE FilingId = @FilingId
        UNION ALL
        SELECT 'P100',
               ISNULL(SUM(CASE WHEN Channel <> 'Brokered'
                               THEN NoteAmount END), 0)
        FROM mcrstg.ClosedLoans WHERE FilingId = @FilingId
        UNION ALL
        SELECT 'P101',
               ISNULL(SUM(CASE WHEN Channel <> 'Brokered' THEN 1 END), 0)
        FROM mcrstg.ClosedLoans WHERE FilingId = @FilingId
        UNION ALL
        /* servicing: performed book (exclude subserviced BY others) */
        SELECT 'S010',
               ISNULL(SUM(CASE WHEN OwnershipType IN
                               ('WhollyOwned','UnderMSR')
                               THEN UPB END), 0)
        FROM mcrstg.ServicingPortfolio WHERE FilingId = @FilingId
        UNION ALL
        SELECT 'S020',
               ISNULL(SUM(CASE WHEN OwnershipType =
                               'SubservicingForOthers'
                               THEN UPB END), 0)
        FROM mcrstg.ServicingPortfolio WHERE FilingId = @FilingId
        UNION ALL
        SELECT 'S100',
               ISNULL(SUM(CASE WHEN OwnershipType <>
                               'SubservicedByOthers'
                               THEN UPB END), 0)
        FROM mcrstg.ServicingPortfolio WHERE FilingId = @FilingId
        UNION ALL
        SELECT 'S101',
               ISNULL(SUM(CASE WHEN OwnershipType <>
                               'SubservicedByOthers'
                               THEN 1 END), 0)
        FROM mcrstg.ServicingPortfolio WHERE FilingId = @FilingId
        UNION ALL
        SELECT 'R010', ISNULL(SUM(UPB), 0)
        FROM mcrstg.Repurchases WHERE FilingId = @FilingId
        UNION ALL
        SELECT 'R011', ISNULL(SUM(LoanCount), 0)
        FROM mcrstg.Repurchases WHERE FilingId = @FilingId
    ) x;

    DECLARE @n INT = @@ROWCOUNT;
    PRINT 'MBFRF loader filing ' + CAST(@FilingId AS VARCHAR(10)) + ': '
        + CAST(@n AS VARCHAR(10)) + ' derived fields staged. Manual '
        + 'fields (balance sheet, income) enter via mcr.MbfrfValues.';
END;
GO

/* ------------------------------------------------- rules 13 + 14 proc -- */
IF OBJECT_ID('mcr.usp_ValidateMbfrf') IS NOT NULL
    DROP PROCEDURE mcr.usp_ValidateMbfrf;
GO
CREATE PROCEDURE mcr.usp_ValidateMbfrf @FilingId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM mcr.MbfrfValues WHERE FilingId = @FilingId)
    BEGIN
        PRINT 'No MBFRF values staged for filing '
            + CAST(@FilingId AS VARCHAR(10)) + '; MBFRF checks skipped.';
        RETURN;
    END

    DELETE FROM mcr.ValidationResults
    WHERE FilingId = @FilingId
      AND RuleType IN ('MBFRF_CHECK','MBFRF_RECON');

    /* ---- rule 13: internal consistency (config-driven) ---- */
    ;WITH comp AS (
        SELECT c.CheckCode,
               CompSum = SUM(ISNULL(v.NumValue, 0))
        FROM mcr.MbfrfCheck c
        CROSS APPLY STRING_SPLIT(c.ComponentCsv, ',') s
        LEFT JOIN mcr.MbfrfValues v
          ON v.FilingId = @FilingId
         AND v.FieldCode = LTRIM(RTRIM(s.value))
        WHERE c.IsActive = 1
        GROUP BY c.CheckCode
    ),
    graded AS (
        SELECT c.CheckCode, c.Description, c.TotalField,
               TotalVal = ISNULL(tv.NumValue, 0),
               CompSum  = ISNULL(m.CompSum, 0)
        FROM mcr.MbfrfCheck c
        JOIN comp m ON m.CheckCode = c.CheckCode
        LEFT JOIN mcr.MbfrfValues tv
          ON tv.FilingId = @FilingId AND tv.FieldCode = c.TotalField
        WHERE c.IsActive = 1
    )
    SELECT g.CheckCode, g.Description, g.TotalField,
           g.TotalVal, g.CompSum,
           Diff   = g.TotalVal - g.CompSum,
           Status = CASE WHEN g.TotalVal = g.CompSum
                         THEN 'PASS' ELSE 'FAIL' END
    INTO #chk
    FROM graded g;

    INSERT INTO mcr.ValidationResults
        (FilingId, Severity, RuleType, ScopeKey, ItemCode, Detail)
    SELECT @FilingId, 'WARNING', 'MBFRF_CHECK', 'COMPANY', r.CheckCode,
        r.Description + ': total '
        + CAST(CAST(r.TotalVal AS BIGINT) AS VARCHAR(20))
        + ' vs components '
        + CAST(CAST(r.CompSum AS BIGINT) AS VARCHAR(20))
        + '. Keying package and MBFRF archive are gated until resolved.'
    FROM #chk r
    WHERE r.Status = 'FAIL';

    /* ---- rule 14: MCR <-> MBFRF reconciliation ---- */
    ;WITH mcr_ AS (
        SELECT CheckCode = 'MBF01',
               Val = (SELECT rv.NumValue FROM mcr.ReportValues rv
                      WHERE rv.FilingId = @FilingId
                        AND rv.ScopeKey = 'FC'
                        AND rv.ElementName = 'A010_1')
        UNION ALL
        SELECT 'MBF02',
               (SELECT SUM(rv.NumValue)
                FROM mcr.ReportValues rv
                JOIN mcr.FieldCatalogElement e
                  ON e.ElementName = rv.ElementName
                WHERE rv.FilingId = @FilingId
                  AND e.ItemCode IN ('AC920','AC930','AC940')
                  AND e.ColumnNo BETWEEN 3 AND 6
                  AND e.DataType <> 'Count')
        UNION ALL
        SELECT 'MBF03',
               (SELECT SUM(rv.NumValue)
                FROM mcr.ReportValues rv
                JOIN mcr.FieldCatalogElement e
                  ON e.ElementName = rv.ElementName
                WHERE rv.FilingId = @FilingId
                  AND rv.ScopeKey = 'COMPANY'
                  AND e.ItemCode IN ('LS010','LS020','LS030')
                  AND e.DataType <> 'Count')
        UNION ALL
        SELECT 'MBF04',
               (SELECT rv.NumValue FROM mcr.ReportValues rv
                WHERE rv.FilingId = @FilingId
                  AND rv.ScopeKey = 'FC'
                  AND rv.ElementName = 'O360_1')
    ),
    cmp AS (
        SELECT b.CheckCode, b.Description, b.Basis,
               McrVal   = ISNULL(m.Val, 0),
               MbfrfVal = ISNULL(v.NumValue, 0),
               b.TolerancePct, b.Exclusions
        FROM mcr.McrMbfrfBridge b
        JOIN mcr_ m ON m.CheckCode = b.CheckCode
        LEFT JOIN mcr.MbfrfValues v
          ON v.FilingId = @FilingId AND v.FieldCode = b.MbfrfField
        WHERE b.IsActive = 1
    )
    SELECT c.CheckCode, c.Description, c.Basis,
           c.McrVal, c.MbfrfVal,
           DiffPct = CASE WHEN c.McrVal = 0 AND c.MbfrfVal = 0 THEN 0
                          WHEN c.McrVal = 0 THEN NULL
                          ELSE CAST(ABS(c.MbfrfVal - c.McrVal) * 100.0
                               / ABS(c.McrVal) AS DECIMAL(15,2)) END,
           c.TolerancePct,
           Status = CASE WHEN c.McrVal = 0 AND c.MbfrfVal <> 0 THEN 'WARN'
                         WHEN c.McrVal = 0 THEN 'PASS'
                         WHEN ABS(c.MbfrfVal - c.McrVal) * 100.0
                              / ABS(c.McrVal) > c.TolerancePct THEN 'WARN'
                         ELSE 'PASS' END,
           c.Exclusions
    INTO #rec
    FROM cmp c;

    INSERT INTO mcr.ValidationResults
        (FilingId, Severity, RuleType, ScopeKey, ItemCode, Detail)
    SELECT @FilingId, 'WARNING', 'MBFRF_RECON', 'COMPANY', r.CheckCode,
        r.Description + ': MCR '
        + CAST(CAST(r.McrVal AS BIGINT) AS VARCHAR(20)) + ' vs MBFRF '
        + CAST(CAST(r.MbfrfVal AS BIGINT) AS VARCHAR(20)) + ' ('
        + ISNULL(CAST(r.DiffPct AS VARCHAR(12)), 'n/a')
        + '% diff, tolerance ' + CAST(r.TolerancePct AS VARCHAR(12))
        + '%). Disposition required: explain or correct.'
    FROM #rec r
    WHERE r.Status = 'WARN';

    DECLARE @fail INT, @warn INT;
    SELECT @fail = COUNT(*) FROM #chk WHERE Status = 'FAIL';
    SELECT @warn = COUNT(*) FROM #rec WHERE Status = 'WARN';
    PRINT 'MBFRF filing ' + CAST(@FilingId AS VARCHAR(10)) + ': '
        + CAST(@fail AS VARCHAR(10)) + ' internal check failure(s) '
        + '(rule 13, MBFRF_CHECK), '
        + CAST(@warn AS VARCHAR(10)) + ' reconciliation finding(s) '
        + '(rule 14, MBFRF_RECON).';

    SELECT CheckCode, Description, TotalField, TotalVal, CompSum, Diff,
           Status
    FROM #chk
    ORDER BY CASE Status WHEN 'FAIL' THEN 0 ELSE 1 END, CheckCode;

    SELECT CheckCode, Description, Basis, McrVal, MbfrfVal, DiffPct,
           TolerancePct, Status
    FROM #rec
    ORDER BY CASE Status WHEN 'WARN' THEN 0 ELSE 1 END, CheckCode;

    DROP TABLE #chk;
    DROP TABLE #rec;
END;
GO

/* --------------------------------------------------- keying package ---- */
IF OBJECT_ID('mcr.usp_GetMbfrfKeyingPackage') IS NOT NULL
    DROP PROCEDURE mcr.usp_GetMbfrfKeyingPackage;
GO
CREATE PROCEDURE mcr.usp_GetMbfrfKeyingPackage @FilingId INT
AS
BEGIN
    /* The ordered WebMB entry grid. KeyAs is what gets typed:
       AMOUNT fields in rounded thousands (WebMB convention), COUNT
       fields as-is. HARD GATE: refuses while rule 13 failures exist -
       "errors block the output" applies to the MBFRF package exactly
       as it applies to the MCR XML. */
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM mcr.ValidationResults
               WHERE FilingId = @FilingId AND RuleType = 'MBFRF_CHECK')
    BEGIN
        RAISERROR('Filing %d has MBFRF internal check failures (rule 13). Fix the staged values and rerun mcr.usp_ValidateMbfrf before keying.', 16, 1, @FilingId);
        RETURN;
    END

    SELECT c.Schedule, c.FieldCode, c.Label, c.SourceType,
           ValueDollars = v.NumValue,
           KeyAs = CASE c.Basis
                       WHEN 'AMOUNT' THEN ROUND(v.NumValue / 1000.0, 0)
                       ELSE v.NumValue END,
           Unit = CASE c.Basis WHEN 'AMOUNT' THEN '$000s' ELSE '#' END
    FROM mcr.MbfrfValues v
    JOIN mcr.MbfrfCatalog c ON c.FieldCode = v.FieldCode
    WHERE v.FilingId = @FilingId AND c.IsActive = 1
    ORDER BY c.EntryOrder;

    PRINT 'MBFRF keying package filing ' + CAST(@FilingId AS VARCHAR(10))
        + ': key the KeyAs column into WebMB in grid order. CEO/CFO '
        + 'certification required at submission.';
END;
GO

/* ---------------------------------------------------------- archive ---- */
CREATE TABLE mcr.MbfrfArchive (
    MbfrfArchiveId INT IDENTITY(1,1) PRIMARY KEY,
    FilingId       INT           NOT NULL,
    ArchivedAt     DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    ValueCount     INT           NOT NULL,
    Sha256         CHAR(64)      NOT NULL,
    Notes          NVARCHAR(400) NULL
);
CREATE TABLE mcr.MbfrfValuesHistory (
    MbfrfArchiveId INT           NOT NULL
        REFERENCES mcr.MbfrfArchive(MbfrfArchiveId),
    FieldCode      VARCHAR(12)   NOT NULL,
    NumValue       DECIMAL(15,2) NOT NULL,
    CONSTRAINT PK_MbfrfHist PRIMARY KEY (MbfrfArchiveId, FieldCode)
);
GO
CREATE TRIGGER mcr.trg_MbfrfArchive_Immutable
ON mcr.MbfrfArchive INSTEAD OF UPDATE, DELETE
AS BEGIN
    RAISERROR('mcr.MbfrfArchive is append-only.', 16, 1);
END;
GO
CREATE TRIGGER mcr.trg_MbfrfHist_Immutable
ON mcr.MbfrfValuesHistory INSTEAD OF UPDATE, DELETE
AS BEGIN
    RAISERROR('mcr.MbfrfValuesHistory is append-only.', 16, 1);
END;
GO

IF OBJECT_ID('mcr.usp_ArchiveMbfrf') IS NOT NULL
    DROP PROCEDURE mcr.usp_ArchiveMbfrf;
GO
CREATE PROCEDURE mcr.usp_ArchiveMbfrf
    @FilingId INT,
    @Notes    NVARCHAR(400) = NULL
AS
BEGIN
    /* Freezes the values as keyed, hash-verified. Rerun after any
       restage creates a NEW archive row; the last one before WebMB
       submission is the one you certify against. */
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM mcr.MbfrfValues WHERE FilingId = @FilingId)
    BEGIN
        RAISERROR('No MBFRF values staged for filing %d.', 16, 1, @FilingId);
        RETURN;
    END
    IF EXISTS (SELECT 1 FROM mcr.ValidationResults
               WHERE FilingId = @FilingId AND RuleType = 'MBFRF_CHECK')
    BEGIN
        RAISERROR('Filing %d has MBFRF internal check failures (rule 13); archive refused.', 16, 1, @FilingId);
        RETURN;
    END

    DECLARE @canon NVARCHAR(MAX), @n INT, @hash CHAR(64);
    SELECT @canon = STRING_AGG(
               CAST(FieldCode + '=' + CONVERT(VARCHAR(32), NumValue)
                    AS NVARCHAR(MAX)), '|')
               WITHIN GROUP (ORDER BY FieldCode),
           @n = COUNT(*)
    FROM mcr.MbfrfValues
    WHERE FilingId = @FilingId;
    SET @hash = CONVERT(CHAR(64), HASHBYTES('SHA2_256', @canon), 2);

    INSERT INTO mcr.MbfrfArchive (FilingId, ValueCount, Sha256, Notes)
    VALUES (@FilingId, @n, @hash, @Notes);
    DECLARE @aid INT = SCOPE_IDENTITY();

    INSERT INTO mcr.MbfrfValuesHistory (MbfrfArchiveId, FieldCode, NumValue)
    SELECT @aid, FieldCode, NumValue
    FROM mcr.MbfrfValues
    WHERE FilingId = @FilingId;

    PRINT 'MBFRF filing ' + CAST(@FilingId AS VARCHAR(10))
        + ' archived as MBFRF archive ' + CAST(@aid AS VARCHAR(10))
        + ' (' + CAST(@n AS VARCHAR(10)) + ' values, SHA-256 '
        + LEFT(@hash, 12) + '...).';
END;
GO

IF OBJECT_ID('mcr.usp_VerifyMbfrfArchive') IS NOT NULL
    DROP PROCEDURE mcr.usp_VerifyMbfrfArchive;
GO
CREATE PROCEDURE mcr.usp_VerifyMbfrfArchive @MbfrfArchiveId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.MbfrfArchiveId, a.FilingId, a.ArchivedAt, a.ValueCount,
           StoredHash   = a.Sha256,
           ComputedHash = h.Recomputed,
           Status = CASE WHEN a.Sha256 = h.Recomputed
                         THEN 'VERIFIED' ELSE 'HASH MISMATCH' END
    FROM mcr.MbfrfArchive a
    CROSS APPLY (
        SELECT Recomputed = CONVERT(CHAR(64), HASHBYTES('SHA2_256',
            (SELECT STRING_AGG(
                 CAST(FieldCode + '=' + CONVERT(VARCHAR(32), NumValue)
                      AS NVARCHAR(MAX)), '|')
                 WITHIN GROUP (ORDER BY FieldCode)
             FROM mcr.MbfrfValuesHistory
             WHERE MbfrfArchiveId = a.MbfrfArchiveId)), 2)
    ) h
    WHERE a.MbfrfArchiveId = ISNULL(@MbfrfArchiveId, a.MbfrfArchiveId)
    ORDER BY a.MbfrfArchiveId;
END;
GO

/* --------------------------------------------------------- PBI view ---- */
IF SCHEMA_ID('mcrpbi') IS NULL EXEC('CREATE SCHEMA mcrpbi;');
GO
CREATE OR ALTER VIEW mcrpbi.FactMbfrf AS
SELECT
    v.FilingId,
    c.Schedule,
    v.FieldCode,
    c.Label,
    c.Basis,
    c.SourceType,
    ValueDollars   = v.NumValue,
    ValueThousands = CASE c.Basis
                         WHEN 'AMOUNT' THEN ROUND(v.NumValue / 1000.0, 0)
                         ELSE v.NumValue END
FROM mcr.MbfrfValues v
JOIN mcr.MbfrfCatalog c ON c.FieldCode = v.FieldCode
WHERE c.IsActive = 1;
GO
/* Rules 13/14 findings surface through the existing mcrpbi.FactValidation
   view (RuleType MBFRF_CHECK / MBFRF_RECON) - no extra recon view.
   Relate FactMbfrf to DimFiling on FilingId; add to the Controls page. */

PRINT '15 complete: mcr.MbfrfCatalog/Values/Check, mcr.McrMbfrfBridge, '
    + 'usp_LoadMbfrfFromSource, usp_ValidateMbfrf, '
    + 'usp_GetMbfrfKeyingPackage, usp_ArchiveMbfrf, '
    + 'usp_VerifyMbfrfArchive, mcrpbi.FactMbfrf created.';
GO
