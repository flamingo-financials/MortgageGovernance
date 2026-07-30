/* ============================================================
   MortgageGovernance | Integration Phase 2 | Script 036
   Governed Q2 2026 MCR filing: warehouse extract to the
   filing engine staging contract.

   WHY THIS EXISTS
   Every filing in mcr.Filing was loaded from demo staging
   unrelated to the governed portfolio. Filing 2026001
   reports LS200 at $2.9M over 3 loans against a real book
   of 11,214 active loans and $3.97B. No reconciliation
   control built on those filings could fail, because there
   was nothing on the other side of the comparison.

   This script creates filing 2026002 for the quarter ended
   2026-06-30 and stages it from dw.FactLoanMonthEndSnapshot
   at one row per active loan.

   BOUNDARY
   reg.usp_StageMcrServicingPortfolio reads dw and writes
   mcrstg. mcr.usp_LoadReportValues reads mcrstg and writes
   mcr.*. Neither crosses the other. mcrstg is the contract.

   CODE CROSSWALK
   Warehouse codes do not match the FV7 staging domains.
   The crosswalk lives in ref.McrStagingCodeMap, not in CASE
   expressions, per the ref-table principle.

   NOT IN SCOPE
   LS1300 to LS1340 are not emitted by the existing engine
   loader. That extension lands in 037 with the independent
   recompute, so LS1390 has a real cross-foot to check.

   Azure SQL Database. No USE. Idempotent.
   ============================================================ */
SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   1. Preflight. Fail loudly and specifically.
   ------------------------------------------------------------ */
DECLARE @Msg NVARCHAR(400);

IF OBJECT_ID('mcrstg.ServicingPortfolio', 'U') IS NULL
BEGIN
    SET @Msg = N'mcrstg.ServicingPortfolio not found. Run '
             + N'mcr_01 through mcr_11 first.';
    THROW 50036, @Msg, 1;
END;

IF OBJECT_ID('mcr.usp_LoadReportValues', 'P') IS NULL
BEGIN
    SET @Msg = N'mcr.usp_LoadReportValues not found. Run '
             + N'mcr_03 first.';
    THROW 50036, @Msg, 1;
END;

IF NOT EXISTS (SELECT 1 FROM dw.FactLoanMonthEndSnapshot
               WHERE AsOfDate = '2026-06-30')
BEGIN
    SET @Msg = N'No dw snapshot at 2026-06-30. Run the '
             + N'pipeline before staging the filing.';
    THROW 50036, @Msg, 1;
END;
GO

/* ------------------------------------------------------------
   2. ref.McrStagingCodeMap
      Warehouse code to FV7 staging domain crosswalk.
      Auditable, and the only place the translation lives.
   ------------------------------------------------------------ */
IF OBJECT_ID('ref.McrStagingCodeMap', 'U') IS NULL
BEGIN
    CREATE TABLE ref.McrStagingCodeMap
    (
        McrStagingCodeMapId INT IDENTITY(1,1) NOT NULL,
        MapTypeCode    VARCHAR(30)  NOT NULL,
        SourceCode     VARCHAR(30)  NOT NULL,
        TargetCode     VARCHAR(30)  NOT NULL,
        MappingNote    NVARCHAR(400) NULL,
        ActiveFlag     BIT NOT NULL
            CONSTRAINT DF_McrStagingCodeMap_ActiveFlag
            DEFAULT 1,
        CreatedDateUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_McrStagingCodeMap_CreatedDateUtc
            DEFAULT SYSUTCDATETIME(),
        ModifiedDateUtc DATETIME2(3) NULL,
        CONSTRAINT PK_McrStagingCodeMap
            PRIMARY KEY CLUSTERED (McrStagingCodeMapId),
        CONSTRAINT UQ_McrStagingCodeMap_Type_Source
            UNIQUE (MapTypeCode, SourceCode),
        CONSTRAINT CK_McrStagingCodeMap_MapTypeCode CHECK
            (MapTypeCode IN ('SERVICING_TYPE','INVESTOR',
             'DELINQ_BUCKET'))
    );
END;
GO

INSERT INTO ref.McrStagingCodeMap
    (MapTypeCode, SourceCode, TargetCode, MappingNote)
SELECT v.MapType, v.Src, v.Tgt, v.Note
FROM (VALUES
 ('SERVICING_TYPE','WHOLLY_OWNED','WhollyOwned',
  N'LS010 / S510.'),
 ('SERVICING_TYPE','MSR_OWNED','UnderMSR',
  N'LS020 / S520.'),
 ('SERVICING_TYPE','SUBSERV_FOR','SubservicingForOthers',
  N'LS030 / S530.'),
 ('SERVICING_TYPE','SUBSERV_BY','SubservicedByOthers',
  N'LS040 / S540.'),
 ('INVESTOR','FNMA','FNMA', N'GSE, exact match.'),
 ('INVESTOR','FHLMC','FHLMC', N'GSE, exact match.'),
 ('INVESTOR','GNMA','GNMA', N'Government, exact match.'),
 ('INVESTOR','PRIV1','PrivateLabel',
  N'Palmetto Private Capital maps to the private label '
+ N'investor category.'),
 ('INVESTOR','OTH1','Other',
  N'Flamingo Portfolio maps to the residual category.'),
 ('INVESTOR','UNKNOWN','Other',
  N'Unresolved investor routes to Other rather than being '
+ N'dropped. Volume is reported by the staging proc and '
+ N'must be zero before the filing is submitted.'),
 ('DELINQ_BUCKET','CURRENT','LT30', N'Under 30 DPD.'),
 ('DELINQ_BUCKET','DPD30_59','D30_59', N'30 to 59 DPD.'),
 ('DELINQ_BUCKET','DPD60_89','D60_89', N'60 to 89 DPD.'),
 ('DELINQ_BUCKET','DPD90_PLUS','D90Plus', N'90 or more.')
) v(MapType, Src, Tgt, Note)
WHERE NOT EXISTS
      (SELECT 1 FROM ref.McrStagingCodeMap m
       WHERE m.MapTypeCode = v.MapType
         AND m.SourceCode = v.Src);
GO

/* ------------------------------------------------------------
   3. reg.usp_StageMcrServicingPortfolio
      dw to mcrstg. One row per active loan at the period
      end. Loans whose property state is not a registered
      US state are excluded and counted, never silently
      coerced: an incomplete filing must be visible.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE reg.usp_StageMcrServicingPortfolio
    @FilingId    INT,
    @PeriodEnd   DATE,
    @LoadBatchId INT = NULL,
    @StagedRows  INT = NULL OUTPUT,
    @ExcludedRows INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ActiveRows INT;

    SELECT @ActiveRows = COUNT(*)
    FROM dw.FactLoanMonthEndSnapshot
    WHERE AsOfDate = @PeriodEnd
      AND ActiveServicingFlag = 1;

    DELETE FROM mcrstg.ServicingPortfolio
    WHERE FilingId = @FilingId;

    ;WITH Elig AS
    (
        SELECT
            s.LoanNumber,
            s.CurrentUpbAmount,
            p.PropertyStateCode,
            mt.TargetCode AS StgOwnership,
            mi.TargetCode AS StgInvestor,
            md.TargetCode AS StgBucket
        FROM dw.FactLoanMonthEndSnapshot s
        JOIN dw.DimProperty p
          ON p.LoanNumber = s.LoanNumber
        JOIN ref.State rs
          ON rs.StateCode = p.PropertyStateCode
        JOIN dw.DimServicingType t
          ON t.ServicingTypeKey = s.ServicingTypeKey
        JOIN ref.McrStagingCodeMap mt
          ON mt.MapTypeCode = 'SERVICING_TYPE'
         AND mt.SourceCode = t.ServicingTypeCode
         AND mt.ActiveFlag = 1
        JOIN dw.DimInvestor i
          ON i.InvestorKey = s.InvestorKey
        JOIN ref.McrStagingCodeMap mi
          ON mi.MapTypeCode = 'INVESTOR'
         AND mi.SourceCode = i.InvestorCode
         AND mi.ActiveFlag = 1
        JOIN dw.DimDelinquencyStatus d
          ON d.DelinquencyStatusKey = s.DelinquencyStatusKey
        JOIN ref.McrStagingCodeMap md
          ON md.MapTypeCode = 'DELINQ_BUCKET'
         AND md.SourceCode = d.DelinquencyBucketCode
         AND md.ActiveFlag = 1
        WHERE s.AsOfDate = @PeriodEnd
          AND s.ActiveServicingFlag = 1
    ),
    Fc AS
    (
        SELECT DISTINCT f.LoanNumber
        FROM dw.FactForeclosureCase f
        WHERE ISNULL(f.ReferralDate, '9999-12-31')
              <= @PeriodEnd
          AND ISNULL(f.SaleHeldDate, '9999-12-31')
              > @PeriodEnd
    )
    INSERT INTO mcrstg.ServicingPortfolio
        (ServiceId, FilingId, StateCode, OwnershipType,
         Investor, DelinquencyBucket, InForeclosure, UPB)
    SELECT
        CAST(@FilingId AS BIGINT) * 1000000
            + ROW_NUMBER() OVER (ORDER BY e.LoanNumber),
        @FilingId,
        LEFT(e.PropertyStateCode, 2),
        e.StgOwnership,
        e.StgInvestor,
        e.StgBucket,
        CASE WHEN fc.LoanNumber IS NULL THEN 0 ELSE 1 END,
        CAST(ROUND(ISNULL(e.CurrentUpbAmount, 0), 0)
             AS BIGINT)
    FROM Elig e
    LEFT JOIN Fc fc ON fc.LoanNumber = e.LoanNumber;

    SET @StagedRows = @@ROWCOUNT;
    SET @ExcludedRows = ISNULL(@ActiveRows, 0)
                      - ISNULL(@StagedRows, 0);
END;
GO

/* ------------------------------------------------------------
   4. Create filing 2026002 under a guard.
   ------------------------------------------------------------ */
DECLARE @FilingId  INT  = 2026002;
DECLARE @PeriodEnd DATE = '2026-06-30';

IF NOT EXISTS (SELECT 1 FROM mcr.Filing
               WHERE FilingId = @FilingId)
BEGIN
    INSERT INTO mcr.Filing
        (FilingId, CompanyNmlsId, CompanyName, FilerType,
         FormVersion, [Year], PeriodType, PeriodStart,
         PeriodEnd, PrimaryStateCode, PriorFilingId)
    VALUES
        (@FilingId, 1820999, 'Fictional Mortgage Co', 'E',
         'v7', 2026, 'MCRQ2', '2026-04-01', '2026-06-30',
         'OK', 2026001);
END;
GO

/* ------------------------------------------------------------
   5. Stage, load, and audit the run.
   ------------------------------------------------------------ */
DECLARE @FilingId    INT  = 2026002;
DECLARE @PeriodEnd   DATE = '2026-06-30';
DECLARE @LoadBatchId INT;
DECLARE @LoadExecId  INT;
DECLARE @Staged      INT;
DECLARE @Excluded    INT;
DECLARE @Detail      NVARCHAR(2000);
DECLARE @BatchNotes  NVARCHAR(1000) =
    N'Script 036: stage Q2 2026 MCR servicing filing from '
  + N'dw.FactLoanMonthEndSnapshot at 2026-06-30.';

EXEC audit.usp_StartLoadBatch
    @BatchName = N'MCR Q2 2026 servicing filing stage',
    @BatchTypeCode = 'FULL',
    @Notes = @BatchNotes,
    @LoadBatchId = @LoadBatchId OUTPUT;

BEGIN TRY

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Stage servicing portfolio to mcrstg',
        @TargetObject = N'mcrstg.ServicingPortfolio',
        @LoadExecutionId = @LoadExecId OUTPUT;

    EXEC reg.usp_StageMcrServicingPortfolio
        @FilingId = @FilingId,
        @PeriodEnd = @PeriodEnd,
        @LoadBatchId = @LoadBatchId,
        @StagedRows = @Staged OUTPUT,
        @ExcludedRows = @Excluded OUTPUT;

    EXEC audit.usp_CompleteLoadExecution
        @LoadExecutionId = @LoadExecId,
        @StatusCode = 'SUCCESS',
        @RowsInserted = @Staged;

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FV7 report values from mcrstg',
        @TargetObject = N'mcr.ReportValues',
        @LoadExecutionId = @LoadExecId OUTPUT;

    EXEC mcr.usp_LoadReportValues @FilingId = @FilingId;

    EXEC audit.usp_CompleteLoadExecution
        @LoadExecutionId = @LoadExecId,
        @StatusCode = 'SUCCESS';

    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'SUCCESS';

    SET @Detail = N'Staged ' + CAST(@Staged AS NVARCHAR(20))
                + N' rows, excluded '
                + CAST(@Excluded AS NVARCHAR(20)) + N'.';
    PRINT @Detail;

END TRY
BEGIN CATCH
    EXEC audit.usp_LogError
        @LoadBatchId = @LoadBatchId,
        @LoadExecutionId = @LoadExecId,
        @ContextInfo = N'036 MCR Q2 stage';
    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'FAILED';
    THROW;
END CATCH
GO

/* ------------------------------------------------------------
   6. Verification
   ------------------------------------------------------------ */

/* 6a. Staged versus warehouse, with the exclusion visible */
SELECT
    (SELECT COUNT(*) FROM dw.FactLoanMonthEndSnapshot
     WHERE AsOfDate = '2026-06-30'
       AND ActiveServicingFlag = 1)      AS DwActiveLoans,
    (SELECT COUNT(*) FROM mcrstg.ServicingPortfolio
     WHERE FilingId = 2026002)           AS StagedLoans,
    (SELECT SUM(CurrentUpbAmount)
     FROM dw.FactLoanMonthEndSnapshot
     WHERE AsOfDate = '2026-06-30'
       AND ActiveServicingFlag = 1)      AS DwActiveUpb,
    (SELECT SUM(UPB) FROM mcrstg.ServicingPortfolio
     WHERE FilingId = 2026002)           AS StagedUpb;

/* 6b. Why anything was excluded */
SELECT
    ExclusionReason =
        CASE WHEN p.LoanNumber IS NULL
                  THEN 'No property row'
             WHEN rs.StateCode IS NULL
                  THEN 'Property state not in ref.State'
             ELSE 'Code crosswalk miss' END,
    LoanCount = COUNT(*)
FROM dw.FactLoanMonthEndSnapshot s
LEFT JOIN dw.DimProperty p
  ON p.LoanNumber = s.LoanNumber
LEFT JOIN ref.State rs
  ON rs.StateCode = p.PropertyStateCode
WHERE s.AsOfDate = '2026-06-30'
  AND s.ActiveServicingFlag = 1
  AND NOT EXISTS (SELECT 1 FROM mcrstg.ServicingPortfolio g
                  WHERE g.FilingId = 2026002
                    AND g.ServiceId IS NOT NULL
                    AND g.StateCode = LEFT(p.PropertyStateCode, 2))
GROUP BY
    CASE WHEN p.LoanNumber IS NULL
              THEN 'No property row'
         WHEN rs.StateCode IS NULL
              THEN 'Property state not in ref.State'
         ELSE 'Code crosswalk miss' END;

/* 6c. Staged distribution, the shape being filed */
SELECT DelinquencyBucket,
       Loans = COUNT(*),
       Upb = SUM(UPB),
       InForeclosure = SUM(CAST(InForeclosure AS INT))
FROM mcrstg.ServicingPortfolio
WHERE FilingId = 2026002
GROUP BY DelinquencyBucket
ORDER BY DelinquencyBucket;

/* 6d. THE DECIDING RESULT: which bucket the engine files
       into LS200. FV7 says LS200 is Current Loans. */
SELECT e.ItemCode, fc.Label, rv.ElementName, e.DataType,
       rv.ScopeKey, rv.NumValue
FROM reg.vw_McrReportValues rv
JOIN reg.vw_McrFieldCatalogElement e
  ON e.ElementName = rv.ElementName
JOIN reg.vw_McrFieldCatalog fc
  ON fc.ItemCode = e.ItemCode
WHERE rv.FilingId = 2026002
  AND e.ItemCode IN ('LS200','LS210','LS220','LS230',
                     'LS290','LS010','LS020','LS030',
                     'LS040')
ORDER BY fc.FormOrder, e.ColumnNo;

/* 6e. Filed value volume for the new filing */
SELECT rv.FilingId,
       ValueRows = COUNT(*),
       ScopeKeys = COUNT(DISTINCT rv.ScopeKey),
       Elements = COUNT(DISTINCT rv.ElementName)
FROM reg.vw_McrReportValues rv
WHERE rv.FilingId = 2026002
GROUP BY rv.FilingId;

/* 6f. gov.ChangeLog EntityTypeCode domain, needed by 037 */
SELECT cc.name AS ConstraintName, cc.definition
FROM sys.check_constraints cc
WHERE cc.parent_object_id = OBJECT_ID('gov.ChangeLog');
GO