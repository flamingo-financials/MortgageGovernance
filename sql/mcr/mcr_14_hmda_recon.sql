/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_14_hmda_recon.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT - ADD-ON
   14 - HMDA reconciliation layer (Option A: control, not filing engine)
   ----------------------------------------------------------------------------
   Prereq: 01-08 installed. Run once per deploy; idempotent. Deploy BEFORE
   running 12 if you want the demo dataset to stage LAR rows and exercise
   the recon (12 is a data script, not part of the numbered deploy order).

   What this is: the HMDA LAR as a COMPARISON SOURCE. The same loan
   population reported to two regulators should tell one story; rule 12
   proves it does, with the definitional differences made explicit and
   tolerated rather than ignored.

   What this is NOT: a HMDA filing engine. The CFPB HMDA Platform runs the
   authoritative edit set; geocoding and the full ~110-field LAR are out
   of scope by design.

   Objects:
     mcrstg.HmdaLar            loan-level LAR subset staging (interface
                            contract, same pattern as the other dbo tables)
     mcr.HmdaMcrBridge      the check definitions: what compares to what,
                            tolerance, and the documented definitional
                            exclusions. Compliance-owned config.
     mcr.usp_ReconcileHmda  runs the checks, returns a comparison grid,
                            and writes findings to mcr.ValidationResults
                            as RuleType = 'HMDA_RECON', Severity = WARNING
                            (never ERROR - definitional drift is
                            dispositioned, not submission-blocking)
     mcrpbi.FactHmdaRecon      the same comparisons as a view for the Power
                            BI Controls page

   KEY DEFINITIONAL DIFFERENCES the checks encode:
     - Brokered-out loans are in MCR AC070/AC990 but NOT on your LAR
       (the funding lender reports them). Funded-only MCR totals are
       therefore taken from the closed-loan grid's retail + wholesale
       column groups (ColumnNo 3-6), never from AC070.
     - MCR includes pre-approvals and uses its own application-date rule;
       HMDA excludes temporary financing and reports purchased loans
       (action 6) that MCR treats differently. Hence tolerances, not
       exact ties. An unexplained breach means one filing is wrong.

   OPERATION ORDER: once this file is deployed, mcr.usp_RunFilingPipeline
   runs the reconciliation automatically as stage 3a (after validate,
   before variance/generate), so findings exist BEFORE usp_ArchiveFiling
   snapshots mcr.ValidationResults into the immutable archive. Stage the
   LAR rows for the period BEFORE running the pipeline. Standalone
   EXEC mcr.usp_ReconcileHmda remains valid for reruns (e.g. after
   restaging the LAR) - but always AFTER usp_ValidateFiling, which
   deletes ALL validation rows for the filing, including these.
   ============================================================================ */

/* ------------------------------------------------------- LAR staging ---- */
IF OBJECT_ID('mcrstg.HmdaLar') IS NOT NULL DROP TABLE mcrstg.HmdaLar;
GO
CREATE TABLE mcrstg.HmdaLar (
    LarId        BIGINT      NOT NULL PRIMARY KEY,
    FilingId     INT         NOT NULL,   -- MCR period linkage
    Uli          VARCHAR(45) NOT NULL,   -- ULI / NULI
    ActionTaken  TINYINT     NOT NULL,   -- HMDA codes: 1 originated,
                                         -- 2 approved not accepted,
                                         -- 3 denied, 4 withdrawn,
                                         -- 5 closed for incompleteness,
                                         -- 6 purchased, 7/8 preapproval
    ActionDate   DATE        NOT NULL,
    StateCode    CHAR(2)     NOT NULL,   -- property state
    LoanAmount   BIGINT      NOT NULL,   -- whole dollars (post-2018 LAR)
    LoanPurpose  TINYINT     NOT NULL,   -- 1 purchase, 2 home improvement,
                                         -- 31 refi, 32 cash-out refi,
                                         -- 4 other, 5 n/a
    CONSTRAINT CK_HmdaLar_Action  CHECK (ActionTaken BETWEEN 1 AND 8),
    CONSTRAINT CK_HmdaLar_Purpose CHECK (LoanPurpose IN (1,2,31,32,4,5))
);
GO

/* --------------------------------------------------- check definitions -- *
   Compliance-owned. TolerancePct is the dispositioned drift allowance;
   Exclusions documents WHY exact ties are not expected. Deactivate a
   check by setting IsActive = 0; never delete (governance trail).        */
IF OBJECT_ID('mcr.HmdaMcrBridge') IS NOT NULL DROP TABLE mcr.HmdaMcrBridge;
GO
CREATE TABLE mcr.HmdaMcrBridge (
    CheckCode    VARCHAR(10)  NOT NULL PRIMARY KEY,
    Description  VARCHAR(200) NOT NULL,
    LarSide      VARCHAR(200) NOT NULL,
    McrSide      VARCHAR(200) NOT NULL,
    Basis        VARCHAR(10)  NOT NULL,  -- COUNT / AMOUNT
    TolerancePct DECIMAL(9,2) NOT NULL,
    Exclusions   VARCHAR(400) NOT NULL,
    IsActive     BIT          NOT NULL DEFAULT 1,
    CONSTRAINT CK_Bridge_Basis CHECK (Basis IN ('COUNT','AMOUNT'))
);
GO
INSERT INTO mcr.HmdaMcrBridge
(CheckCode, Description, LarSide, McrSide, Basis, TolerancePct, Exclusions)
VALUES
('HMDA01',
 'Originations count per state',
 'LAR ActionTaken = 1 (originated), count',
 'MCR funded closed loans: QM split AC920-940, retail+wholesale ' +
 'column groups only (ColumnNo 3-6), count',
 'COUNT', 5.00,
 'Brokered-out loans excluded from both sides (not on your LAR; MCR ' +
 'brokered column group excluded). HMDA temporary-financing exclusion ' +
 'and MCR scope differences absorbed by tolerance.'),
('HMDA02',
 'Originations amount per state',
 'LAR ActionTaken = 1, sum of LoanAmount',
 'MCR funded closed loans: AC920-940 retail+wholesale columns, $',
 'AMOUNT', 10.00,
 'LAR reports final loan amount; MCR closed grids report note amount. ' +
 'Wider tolerance covers amount-basis drift.'),
('HMDA03',
 'Non-originated dispositions count per state',
 'LAR ActionTaken IN (2,3,4,5), count',
 'MCR AC030 + AC040 + AC050 + AC060, all column groups, count',
 'COUNT', 5.00,
 'Approved-not-accepted / denied / withdrawn / incomplete. MCR ' +
 'pre-approval handling and HMDA preapproval codes (7/8) excluded.'),
('HMDA04',
 'Purchase-purpose originations count per state',
 'LAR ActionTaken = 1 AND LoanPurpose = 1, count',
 'MCR AC300 (home purchase), retail+wholesale columns, count',
 'COUNT', 5.00,
 'Purpose taxonomies differ at the edges (HMDA 31/32 refi split, MCR ' +
 'home-improvement definition); purchase is the cleanest overlap.');
GO

/* ------------------------------------------------------------ recon proc */
IF OBJECT_ID('mcr.usp_ReconcileHmda') IS NOT NULL
    DROP PROCEDURE mcr.usp_ReconcileHmda;
GO
CREATE PROCEDURE mcr.usp_ReconcileHmda @FilingId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM mcrstg.HmdaLar WHERE FilingId = @FilingId)
    BEGIN
        PRINT 'No HMDA LAR rows staged for filing '
            + CAST(@FilingId AS VARCHAR(10)) + '; reconciliation skipped.';
        RETURN;
    END

    /* clear only this rule's prior findings (usp_ValidateFiling wipes
       everything for the filing anyway - run this proc AFTER validate) */
    DELETE FROM mcr.ValidationResults
    WHERE FilingId = @FilingId AND RuleType = 'HMDA_RECON';

    /* ---- LAR side, per state per check ---- */
    ;WITH lar AS (
        SELECT StateCode, CheckCode = 'HMDA01',
               Val = CAST(COUNT(*) AS DECIMAL(18,2))
        FROM mcrstg.HmdaLar
        WHERE FilingId = @FilingId AND ActionTaken = 1
        GROUP BY StateCode
        UNION ALL
        SELECT StateCode, 'HMDA02', CAST(SUM(LoanAmount) AS DECIMAL(18,2))
        FROM mcrstg.HmdaLar
        WHERE FilingId = @FilingId AND ActionTaken = 1
        GROUP BY StateCode
        UNION ALL
        SELECT StateCode, 'HMDA03', CAST(COUNT(*) AS DECIMAL(18,2))
        FROM mcrstg.HmdaLar
        WHERE FilingId = @FilingId AND ActionTaken IN (2,3,4,5)
        GROUP BY StateCode
        UNION ALL
        SELECT StateCode, 'HMDA04', CAST(COUNT(*) AS DECIMAL(18,2))
        FROM mcrstg.HmdaLar
        WHERE FilingId = @FilingId AND ActionTaken = 1 AND LoanPurpose = 1
        GROUP BY StateCode
    ),
    /* ---- MCR side, per state per check ----
       Funded-only = retail + wholesale column groups = ColumnNo 3-6.   */
    mcr_ AS (
        SELECT rv.ScopeKey AS StateCode, CheckCode = 'HMDA01',
               Val = SUM(rv.NumValue)
        FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        WHERE rv.FilingId = @FilingId
          AND e.ItemCode IN ('AC920','AC930','AC940')
          AND e.ColumnNo BETWEEN 3 AND 6 AND e.DataType = 'Count'
        GROUP BY rv.ScopeKey
        UNION ALL
        SELECT rv.ScopeKey, 'HMDA02', SUM(rv.NumValue)
        FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        WHERE rv.FilingId = @FilingId
          AND e.ItemCode IN ('AC920','AC930','AC940')
          AND e.ColumnNo BETWEEN 3 AND 6 AND e.DataType <> 'Count'
        GROUP BY rv.ScopeKey
        UNION ALL
        SELECT rv.ScopeKey, 'HMDA03', SUM(rv.NumValue)
        FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        WHERE rv.FilingId = @FilingId
          AND e.ItemCode IN ('AC030','AC040','AC050','AC060')
          AND e.DataType = 'Count'
        GROUP BY rv.ScopeKey
        UNION ALL
        SELECT rv.ScopeKey, 'HMDA04', SUM(rv.NumValue)
        FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        WHERE rv.FilingId = @FilingId
          AND e.ItemCode = 'AC300'
          AND e.ColumnNo BETWEEN 3 AND 6 AND e.DataType = 'Count'
        GROUP BY rv.ScopeKey
    ),
    cmp AS (
        SELECT
            StateCode = COALESCE(l.StateCode, m.StateCode),
            CheckCode = COALESCE(l.CheckCode, m.CheckCode),
            LarVal    = ISNULL(l.Val, 0),
            McrVal    = ISNULL(m.Val, 0)
        FROM lar l
        FULL OUTER JOIN mcr_ m
          ON m.StateCode = l.StateCode AND m.CheckCode = l.CheckCode
    ),
    graded AS (
        SELECT c.StateCode, c.CheckCode, b.Description, b.Basis,
               c.LarVal, c.McrVal,
               DiffPct = CASE WHEN c.McrVal = 0 AND c.LarVal = 0 THEN 0
                              WHEN c.McrVal = 0 THEN NULL
                              ELSE CAST(ABS(c.LarVal - c.McrVal) * 100.0
                                   / c.McrVal AS DECIMAL(15,2)) END,
               b.TolerancePct, b.Exclusions
        FROM cmp c
        JOIN mcr.HmdaMcrBridge b
          ON b.CheckCode = c.CheckCode AND b.IsActive = 1
    )
    SELECT g.StateCode, g.CheckCode, g.Description, g.Basis,
           g.LarVal, g.McrVal, g.DiffPct, g.TolerancePct,
           Status = CASE WHEN g.DiffPct IS NULL
                              AND (g.LarVal <> 0 OR g.McrVal <> 0)
                         THEN 'WARN'
                         WHEN g.DiffPct > g.TolerancePct THEN 'WARN'
                         ELSE 'PASS' END,
           g.Exclusions
    INTO #recon
    FROM graded g;

    /* findings -> validation results, WARNING only, rule 12 */
    INSERT INTO mcr.ValidationResults
        (FilingId, Severity, RuleType, ScopeKey, ItemCode, Detail)
    SELECT @FilingId, 'WARNING', 'HMDA_RECON', r.StateCode, r.CheckCode,
        r.Description + ': LAR '
        + CAST(CAST(r.LarVal AS BIGINT) AS VARCHAR(20)) + ' vs MCR '
        + CAST(CAST(r.McrVal AS BIGINT) AS VARCHAR(20)) + ' ('
        + ISNULL(CAST(r.DiffPct AS VARCHAR(12)), 'n/a')
        + '% diff, tolerance ' + CAST(r.TolerancePct AS VARCHAR(12))
        + '%). Disposition required: explain or correct. '
        + 'Documented exclusions: ' + r.Exclusions
    FROM #recon r
    WHERE r.Status = 'WARN';

    DECLARE @warn INT;
    SELECT @warn = COUNT(*) FROM #recon WHERE Status = 'WARN';
    PRINT 'HMDA reconciliation filing ' + CAST(@FilingId AS VARCHAR(10))
        + ': ' + CAST(@warn AS VARCHAR(10))
        + ' finding(s) written as WARNING (rule 12, HMDA_RECON).';

    SELECT StateCode, CheckCode, Description, Basis,
           LarVal, McrVal, DiffPct, TolerancePct, Status
    FROM #recon
    ORDER BY CASE Status WHEN 'WARN' THEN 0 ELSE 1 END,
             CheckCode, StateCode;

    DROP TABLE #recon;
END;
GO

/* --------------------------------------------------- PBI Controls view -- */
IF SCHEMA_ID('mcrpbi') IS NULL EXEC('CREATE SCHEMA mcrpbi;');
GO
CREATE OR ALTER VIEW mcrpbi.FactHmdaRecon AS
WITH lar AS (
    SELECT FilingId, StateCode, CheckCode = 'HMDA01',
           Val = CAST(COUNT(*) AS DECIMAL(18,2))
    FROM mcrstg.HmdaLar WHERE ActionTaken = 1
    GROUP BY FilingId, StateCode
    UNION ALL
    SELECT FilingId, StateCode, 'HMDA02',
           CAST(SUM(LoanAmount) AS DECIMAL(18,2))
    FROM mcrstg.HmdaLar WHERE ActionTaken = 1
    GROUP BY FilingId, StateCode
    UNION ALL
    SELECT FilingId, StateCode, 'HMDA03',
           CAST(COUNT(*) AS DECIMAL(18,2))
    FROM mcrstg.HmdaLar WHERE ActionTaken IN (2,3,4,5)
    GROUP BY FilingId, StateCode
    UNION ALL
    SELECT FilingId, StateCode, 'HMDA04',
           CAST(COUNT(*) AS DECIMAL(18,2))
    FROM mcrstg.HmdaLar WHERE ActionTaken = 1 AND LoanPurpose = 1
    GROUP BY FilingId, StateCode
),
mcr_ AS (
    SELECT rv.FilingId, rv.ScopeKey AS StateCode, CheckCode = 'HMDA01',
           Val = SUM(rv.NumValue)
    FROM mcr.ReportValues rv
    JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
    WHERE e.ItemCode IN ('AC920','AC930','AC940')
      AND e.ColumnNo BETWEEN 3 AND 6 AND e.DataType = 'Count'
    GROUP BY rv.FilingId, rv.ScopeKey
    UNION ALL
    SELECT rv.FilingId, rv.ScopeKey, 'HMDA02', SUM(rv.NumValue)
    FROM mcr.ReportValues rv
    JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
    WHERE e.ItemCode IN ('AC920','AC930','AC940')
      AND e.ColumnNo BETWEEN 3 AND 6 AND e.DataType <> 'Count'
    GROUP BY rv.FilingId, rv.ScopeKey
    UNION ALL
    SELECT rv.FilingId, rv.ScopeKey, 'HMDA03', SUM(rv.NumValue)
    FROM mcr.ReportValues rv
    JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
    WHERE e.ItemCode IN ('AC030','AC040','AC050','AC060')
      AND e.DataType = 'Count'
    GROUP BY rv.FilingId, rv.ScopeKey
    UNION ALL
    SELECT rv.FilingId, rv.ScopeKey, 'HMDA04', SUM(rv.NumValue)
    FROM mcr.ReportValues rv
    JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
    WHERE e.ItemCode = 'AC300'
      AND e.ColumnNo BETWEEN 3 AND 6 AND e.DataType = 'Count'
    GROUP BY rv.FilingId, rv.ScopeKey
),
cmp AS (
    SELECT
        FilingId  = COALESCE(l.FilingId, m.FilingId),
        StateCode = COALESCE(l.StateCode, m.StateCode),
        CheckCode = COALESCE(l.CheckCode, m.CheckCode),
        LarVal    = ISNULL(l.Val, 0),
        McrVal    = ISNULL(m.Val, 0)
    FROM lar l
    FULL OUTER JOIN mcr_ m
      ON m.FilingId = l.FilingId AND m.StateCode = l.StateCode
     AND m.CheckCode = l.CheckCode
)
SELECT c.FilingId, c.StateCode, c.CheckCode, b.Description, b.Basis,
       c.LarVal, c.McrVal,
       DiffPct = CASE WHEN c.McrVal = 0 AND c.LarVal = 0 THEN 0
                      WHEN c.McrVal = 0 THEN NULL
                      ELSE CAST(ABS(c.LarVal - c.McrVal) * 100.0
                           / c.McrVal AS DECIMAL(15,2)) END,
       b.TolerancePct,
       Status = CASE WHEN c.McrVal = 0 AND c.LarVal <> 0 THEN 'WARN'
                     WHEN c.McrVal = 0 THEN 'PASS'
                     WHEN ABS(c.LarVal - c.McrVal) * 100.0 / c.McrVal
                          > b.TolerancePct THEN 'WARN'
                     ELSE 'PASS' END
FROM cmp c
JOIN mcr.HmdaMcrBridge b
  ON b.CheckCode = c.CheckCode AND b.IsActive = 1;
GO

PRINT '14 complete: mcrstg.HmdaLar, mcr.HmdaMcrBridge, '
    + 'mcr.usp_ReconcileHmda, mcrpbi.FactHmdaRecon created.';
GO
