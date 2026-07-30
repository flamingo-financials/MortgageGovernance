/* ============================================================
   MortgageGovernance | Integration Phase 2 | Script 039
   Filed-basis measure for reg.McrInternalValue.

   WHY
   NMLS FV7 requires whole-dollar amounts; mcr_04 rejects
   non-integer PositiveDollar elements. Staging therefore
   rounds each loan before summing. Comparing a filed value
   to a full-precision warehouse sum produces a few dollars
   of unavoidable noise per line, which would force a
   tolerance onto every MCR tie-out control and blunt it.

   Storing the same aggregate on the filed basis, SUM of
   per-loan ROUND, removes the noise entirely and lets every
   control run EXACT. NumValue is retained unchanged as the
   full-precision governance figure, so the rounding effect
   stays visible and quantified rather than being discarded.

   Azure SQL Database. No USE. Idempotent.
   ============================================================ */
SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   1. Add the filed-basis measure.
   ------------------------------------------------------------ */
IF COL_LENGTH('reg.McrInternalValue',
              'NumValueFiledBasis') IS NULL
BEGIN
    ALTER TABLE reg.McrInternalValue
        ADD NumValueFiledBasis DECIMAL(18,2) NOT NULL
        CONSTRAINT DF_McrInternalValue_NumValueFiledBasis
        DEFAULT 0;
END;
GO

/* ------------------------------------------------------------
   2. Record the logic change against the affected rules.
   ------------------------------------------------------------ */
UPDATE gov.DerivationRule
   SET CanonicalLogic = CanonicalLogic
     + N'
FILED BASIS: NMLS requires whole-dollar amounts. The filed
basis measure is SUM(ROUND(CurrentUpbAmount, 0)) over the
same population, rounding each loan before summing, which
is what the staging contract does. NumValue remains the
full-precision figure. The difference between them is the
rounding effect and is reported, not controlled.',
       RuleVersion = RuleVersion + 1,
       ModifiedDateUtc = SYSUTCDATETIME()
WHERE RuleCode IN ('DRV_MCROWNSHIP','DRV_MCRDELINQ',
                   'DRV_MCRFCINV')
  AND CanonicalLogic NOT LIKE '%FILED BASIS%';
GO

DECLARE @Rows   INT = @@ROWCOUNT;
DECLARE @Detail NVARCHAR(2000);

IF @Rows > 0
BEGIN
    SET @Detail =
        N'Added a filed-basis measure to the MCR servicing '
      + N'derivation rules. Prior guidance in scripts 037 '
      + N'and 038 described the staging conversion as '
      + N'BIGINT truncation; it is symmetric rounding, '
      + N'confirmed by a positive variance of 5.43 on '
      + N'LS230 which truncation cannot produce. Rounding '
      + N'is a filing requirement, not a defect, so it is '
      + N'matched on both sides rather than absorbed by a '
      + N'control tolerance.';

    INSERT INTO gov.ChangeLog
        (EntityTypeCode, EntityReference, ChangeTypeCode,
         ChangeDescription)
    VALUES
        ('DERIVATION_RULE', N'DRV_MCR servicing grids',
         'VERSION', @Detail);
END;
GO

/* ------------------------------------------------------------
   3. Recompute with the filed basis populated.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE reg.usp_ComputeMcrInternalValue
    @FilingId    INT,
    @PeriodEnd   DATE,
    @LoadBatchId INT = NULL,
    @RowsWritten INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM reg.McrInternalValue
    WHERE FilingId = @FilingId;

    IF OBJECT_ID('tempdb..#Pop') IS NOT NULL
        DROP TABLE #Pop;

    CREATE TABLE #Pop
    (
        LoanNumber   VARCHAR(20)   NOT NULL,
        Upb          DECIMAL(18,2) NOT NULL,
        UpbFiled     DECIMAL(18,2) NOT NULL,
        OwnItemCode  VARCHAR(20)   NULL,
        DelItemCode  VARCHAR(20)   NULL,
        InvItemCode  VARCHAR(20)   NULL,
        FcOpenFlag   BIT           NOT NULL
    );

    INSERT INTO #Pop
        (LoanNumber, Upb, UpbFiled, OwnItemCode,
         DelItemCode, InvItemCode, FcOpenFlag)
    SELECT
        s.LoanNumber,
        ISNULL(s.CurrentUpbAmount, 0),
        ROUND(ISNULL(s.CurrentUpbAmount, 0), 0),
        oi.TargetCode,
        di.TargetCode,
        fi.TargetCode,
        CASE WHEN fc.LoanNumber IS NULL THEN 0 ELSE 1 END
    FROM dw.FactLoanMonthEndSnapshot s
    JOIN dw.DimServicingType t
      ON t.ServicingTypeKey = s.ServicingTypeKey
    JOIN ref.McrStagingCodeMap ot
      ON ot.MapTypeCode = 'SERVICING_TYPE'
     AND ot.SourceCode = t.ServicingTypeCode
     AND ot.ActiveFlag = 1
    JOIN ref.McrStagingCodeMap oi
      ON oi.MapTypeCode = 'OWNERSHIP_ITEM'
     AND oi.SourceCode = ot.TargetCode
     AND oi.ActiveFlag = 1
    JOIN dw.DimDelinquencyStatus d
      ON d.DelinquencyStatusKey = s.DelinquencyStatusKey
    JOIN ref.McrStagingCodeMap db
      ON db.MapTypeCode = 'DELINQ_BUCKET'
     AND db.SourceCode = d.DelinquencyBucketCode
     AND db.ActiveFlag = 1
    JOIN ref.McrStagingCodeMap di
      ON di.MapTypeCode = 'DELINQ_ITEM'
     AND di.SourceCode = db.TargetCode
     AND di.ActiveFlag = 1
    JOIN dw.DimInvestor iv
      ON iv.InvestorKey = s.InvestorKey
    JOIN ref.McrStagingCodeMap ic
      ON ic.MapTypeCode = 'INVESTOR'
     AND ic.SourceCode = iv.InvestorCode
     AND ic.ActiveFlag = 1
    JOIN ref.McrStagingCodeMap fi
      ON fi.MapTypeCode = 'FC_INVESTOR_ITEM'
     AND fi.SourceCode = ic.TargetCode
     AND fi.ActiveFlag = 1
    LEFT JOIN
    (
        SELECT DISTINCT f.LoanNumber
        FROM dw.FactForeclosureCase f
        WHERE ISNULL(f.ReferralDate, '9999-12-31')
              <= @PeriodEnd
          AND ISNULL(f.SaleHeldDate, '9999-12-31')
              > @PeriodEnd
    ) fc ON fc.LoanNumber = s.LoanNumber
    WHERE s.AsOfDate = @PeriodEnd
      AND s.ActiveServicingFlag = 1;

    IF OBJECT_ID('tempdb..#Line') IS NOT NULL
        DROP TABLE #Line;

    CREATE TABLE #Line
    (
        ItemCode VARCHAR(20)   NOT NULL PRIMARY KEY,
        Amt      DECIMAL(18,2) NOT NULL,
        AmtFiled DECIMAL(18,2) NOT NULL,
        Cnt      INT           NOT NULL
    );

    INSERT INTO #Line (ItemCode, Amt, AmtFiled, Cnt)
    SELECT x.ItemCode, SUM(x.Upb), SUM(x.UpbFiled),
           COUNT(*)
    FROM
    (
        SELECT OwnItemCode AS ItemCode, Upb, UpbFiled
        FROM #Pop
        UNION ALL
        SELECT DelItemCode, Upb, UpbFiled FROM #Pop
        UNION ALL
        SELECT InvItemCode, Upb, UpbFiled FROM #Pop
        WHERE FcOpenFlag = 1
    ) x
    GROUP BY x.ItemCode;

    INSERT INTO reg.McrInternalValue
        (FilingId, PeriodEndDate, ItemCode, ElementName,
         ScopeKey, MeasureTypeCode, NumValue,
         NumValueFiledBasis, PopulationRowCount,
         NmlsDerivedFlag, DerivationRuleCode,
         ComputationNote, LoadBatchId)
    SELECT
        @FilingId, @PeriodEnd, i.ItemCode, e.ElementName,
        'COMPANY',
        CASE WHEN e.DataType = 'Count'
             THEN 'COUNT' ELSE 'AMOUNT' END,
        CASE WHEN e.DataType = 'Count'
             THEN CAST(ISNULL(l.Cnt, 0) AS DECIMAL(18,2))
             ELSE ISNULL(l.Amt, 0) END,
        CASE WHEN e.DataType = 'Count'
             THEN CAST(ISNULL(l.Cnt, 0) AS DECIMAL(18,2))
             ELSE ISNULL(l.AmtFiled, 0) END,
        ISNULL(l.Cnt, 0),
        0,
        i.RuleCode,
        CASE WHEN l.ItemCode IS NULL
             THEN N'Zero population at period end. Row '
                + N'emitted explicitly so an absent filed '
                + N'line is distinguishable from a filed '
                + N'zero.'
             ELSE NULL END,
        @LoadBatchId
    FROM (VALUES
        ('LS010','DRV_MCROWNSHIP'),
        ('LS020','DRV_MCROWNSHIP'),
        ('LS030','DRV_MCROWNSHIP'),
        ('LS040','DRV_MCROWNSHIP'),
        ('LS200','DRV_MCRDELINQ'),
        ('LS210','DRV_MCRDELINQ'),
        ('LS220','DRV_MCRDELINQ'),
        ('LS230','DRV_MCRDELINQ'),
        ('LS1300','DRV_MCRFCINV'),
        ('LS1310','DRV_MCRFCINV'),
        ('LS1320','DRV_MCRFCINV'),
        ('LS1330','DRV_MCRFCINV'),
        ('LS1340','DRV_MCRFCINV')
    ) i(ItemCode, RuleCode)
    JOIN reg.vw_McrFieldCatalogElement e
      ON e.ItemCode = i.ItemCode
     AND e.ColumnNo IN (1, 2)
    LEFT JOIN #Line l ON l.ItemCode = i.ItemCode;

    INSERT INTO reg.McrInternalValue
        (FilingId, PeriodEndDate, ItemCode, ElementName,
         ScopeKey, MeasureTypeCode, NumValue,
         NumValueFiledBasis, PopulationRowCount,
         NmlsDerivedFlag, DerivationRuleCode,
         ComputationNote, LoadBatchId)
    SELECT
        @FilingId, @PeriodEnd, t.ItemCode,
        t.ItemCode + t.Suffix, 'COMPANY', t.MeasType,
        CASE WHEN t.MeasType = 'COUNT'
             THEN CAST(SUM(v.PopulationRowCount)
                  AS DECIMAL(18,2))
             ELSE SUM(CASE WHEN v.MeasureTypeCode = 'AMOUNT'
                           THEN v.NumValue ELSE 0 END) END,
        CASE WHEN t.MeasType = 'COUNT'
             THEN CAST(SUM(v.PopulationRowCount)
                  AS DECIMAL(18,2))
             ELSE SUM(CASE WHEN v.MeasureTypeCode = 'AMOUNT'
                           THEN v.NumValueFiledBasis
                           ELSE 0 END) END,
        SUM(v.PopulationRowCount),
        1, t.RuleCode,
        N'Not submittable. This is the total NMLS derives '
      + N'from the detail lines we submit.',
        @LoadBatchId
    FROM (VALUES
        ('LS290','_1','AMOUNT','DRV_MCRDELINQ','DEL'),
        ('LS290','_2','COUNT','DRV_MCRDELINQ','DEL'),
        ('LS1390','_1','AMOUNT','DRV_MCRFCINV','FC'),
        ('LS1390','_2','COUNT','DRV_MCRFCINV','FC')
    ) t(ItemCode, Suffix, MeasType, RuleCode, Grid)
    JOIN reg.McrInternalValue v
      ON v.FilingId = @FilingId
     AND v.NmlsDerivedFlag = 0
     AND v.MeasureTypeCode = t.MeasType
     AND ((t.Grid = 'DEL'
           AND v.ItemCode IN ('LS200','LS210','LS220',
                              'LS230'))
       OR (t.Grid = 'FC'
           AND v.ItemCode IN ('LS1300','LS1310','LS1320',
                              'LS1330','LS1340')))
    GROUP BY t.ItemCode, t.Suffix, t.MeasType, t.RuleCode;

    SELECT @RowsWritten = COUNT(*)
    FROM reg.McrInternalValue
    WHERE FilingId = @FilingId;

    DROP TABLE #Pop;
    DROP TABLE #Line;
END;
GO

/* ------------------------------------------------------------
   4. Re-run for filing 2026002.
   ------------------------------------------------------------ */
DECLARE @FilingId    INT  = 2026002;
DECLARE @PeriodEnd   DATE = '2026-06-30';
DECLARE @LoadBatchId INT;
DECLARE @LoadExecId  INT;
DECLARE @RowsWritten INT;
DECLARE @BatchName   NVARCHAR(200);
DECLARE @StepName    NVARCHAR(200);
DECLARE @TargetObj   NVARCHAR(200);
DECLARE @BatchNotes  NVARCHAR(1000);

SET @BatchName  = N'MCR internal value filed-basis rebuild';
SET @StepName   = N'Recompute with filed-basis measure';
SET @TargetObj  = N'reg.McrInternalValue';
SET @BatchNotes =
    N'Script 039: add the filed-basis measure so MCR '
  + N'tie-out controls run EXACT rather than absorbing '
  + N'form-required rounding into a tolerance.';

EXEC audit.usp_StartLoadBatch
    @BatchName = @BatchName,
    @BatchTypeCode = 'RECON',
    @Notes = @BatchNotes,
    @LoadBatchId = @LoadBatchId OUTPUT;

BEGIN TRY

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = @StepName,
        @TargetObject = @TargetObj,
        @LoadExecutionId = @LoadExecId OUTPUT;

    EXEC reg.usp_ComputeMcrInternalValue
        @FilingId = @FilingId,
        @PeriodEnd = @PeriodEnd,
        @LoadBatchId = @LoadBatchId,
        @RowsWritten = @RowsWritten OUTPUT;

    EXEC audit.usp_CompleteLoadExecution
        @LoadExecutionId = @LoadExecId,
        @StatusCode = 'SUCCESS',
        @RowsInserted = @RowsWritten;

    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'SUCCESS';

END TRY
BEGIN CATCH
    EXEC audit.usp_LogError
        @LoadBatchId = @LoadBatchId,
        @LoadExecutionId = @LoadExecId,
        @ContextInfo = N'039 filed-basis rebuild';
    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'FAILED';
    THROW;
END CATCH
GO

/* ------------------------------------------------------------
   5. Verification
   ------------------------------------------------------------ */

/* 5a. Filed basis versus filed. Every line whose count
       matches must now show exactly zero variance. */
SELECT
    iv.ItemCode, fc.Label, iv.ElementName,
    iv.MeasureTypeCode,
    FiledBasis = iv.NumValueFiledBasis,
    FiledValue = rv.NumValue,
    Variance = rv.NumValue - iv.NumValueFiledBasis,
    RoundingEffect = iv.NumValueFiledBasis - iv.NumValue,
    Status = CASE WHEN rv.NumValue IS NULL
                  THEN 'ABSENT FROM FILING'
                  WHEN rv.NumValue = iv.NumValueFiledBasis
                  THEN 'MATCH' ELSE 'VARIANCE' END
FROM reg.McrInternalValue iv
JOIN reg.vw_McrFieldCatalog fc
  ON fc.ItemCode = iv.ItemCode
LEFT JOIN reg.vw_McrReportValues rv
  ON rv.FilingId = iv.FilingId
 AND rv.ScopeKey = iv.ScopeKey
 AND rv.ElementName = iv.ElementName
WHERE iv.FilingId = 2026002
ORDER BY fc.FormOrder, iv.ElementName;

/* 5b. Anything still varying after rounding is matched. */
SELECT
    RemainingVarianceLines = COUNT(*),
    NetAmountVariance =
        SUM(CASE WHEN iv.MeasureTypeCode = 'AMOUNT'
                 THEN rv.NumValue - iv.NumValueFiledBasis
                 ELSE 0 END),
    NetCountVariance =
        SUM(CASE WHEN iv.MeasureTypeCode = 'COUNT'
                 THEN rv.NumValue - iv.NumValueFiledBasis
                 ELSE 0 END)
FROM reg.McrInternalValue iv
JOIN reg.vw_McrReportValues rv
  ON rv.FilingId = iv.FilingId
 AND rv.ScopeKey = iv.ScopeKey
 AND rv.ElementName = iv.ElementName
WHERE iv.FilingId = 2026002
  AND rv.NumValue <> iv.NumValueFiledBasis;

/* 5c. Total rounding effect, disclosed not controlled. */
SELECT
    Grid = CASE WHEN ItemCode IN ('LS010','LS020','LS030',
                                  'LS040')
                THEN 'Ownership'
                WHEN ItemCode IN ('LS200','LS210','LS220',
                                  'LS230')
                THEN 'Delinquency' ELSE 'Foreclosure' END,
    FullPrecisionUpb = SUM(NumValue),
    FiledBasisUpb = SUM(NumValueFiledBasis),
    RoundingEffect = SUM(NumValueFiledBasis) - SUM(NumValue)
FROM reg.McrInternalValue
WHERE FilingId = 2026002
  AND NmlsDerivedFlag = 0
  AND MeasureTypeCode = 'AMOUNT'
GROUP BY CASE WHEN ItemCode IN ('LS010','LS020','LS030',
                                'LS040')
              THEN 'Ownership'
              WHEN ItemCode IN ('LS200','LS210','LS220',
                                'LS230')
              THEN 'Delinquency' ELSE 'Foreclosure' END;
GO