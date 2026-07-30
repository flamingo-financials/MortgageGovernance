/* ============================================================
   MortgageGovernance | Integration Phase 2 | Script 038
   reg.McrInternalValue: the governance layer's independent
   statement of what filing 2026002 should contain.

   INDEPENDENCE
   The submission path is dw to mcrstg to the engine loader,
   with BIGINT truncation and a NOT NULL state constraint.
   This path reads dw directly at DECIMAL(18,2) over the full
   active population with no state requirement, because
   LS010-LS040, LS200-LS230 and LS1300-LS1340 are COMPANY
   scope nationwide totals. The two paths share only the
   ref crosswalk, which is deliberate: category definitions
   should be common, aggregation and population should not.

   EXPLICIT ZEROS
   Every item in scope gets a row even when the population
   is empty, so an absent filed line (LS1330) is visible as
   a variance rather than disappearing into a NULL join.

   NMLS-DERIVED TOTALS
   LS290 and LS1390 are calculated by NMLS and carry no
   submittable element. They are stored here under synthetic
   element names with NmlsDerivedFlag = 1, representing the
   total NMLS will derive from the detail we submit.

   Azure SQL Database. No USE. Idempotent.
   ============================================================ */
SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   1. Extend the crosswalk domain for the two grid maps.
   ------------------------------------------------------------ */
IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_McrStagingCodeMap_MapTypeCode'
             AND parent_object_id =
                 OBJECT_ID('ref.McrStagingCodeMap')
             AND definition NOT LIKE '%OWNERSHIP_ITEM%')
BEGIN
    ALTER TABLE ref.McrStagingCodeMap
        DROP CONSTRAINT CK_McrStagingCodeMap_MapTypeCode;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name =
                     'CK_McrStagingCodeMap_MapTypeCode'
                 AND parent_object_id =
                     OBJECT_ID('ref.McrStagingCodeMap'))
BEGIN
    ALTER TABLE ref.McrStagingCodeMap
        ADD CONSTRAINT CK_McrStagingCodeMap_MapTypeCode
        CHECK (MapTypeCode IN ('SERVICING_TYPE','INVESTOR',
               'DELINQ_BUCKET','FC_INVESTOR_ITEM',
               'OWNERSHIP_ITEM','DELINQ_ITEM'));
END;
GO

INSERT INTO ref.McrStagingCodeMap
    (MapTypeCode, SourceCode, TargetCode, MappingNote)
SELECT v.MapType, v.Src, v.Tgt, v.Note
FROM (VALUES
 ('OWNERSHIP_ITEM','WhollyOwned','LS010',
  N'FV7 Wholly Owned Loans Serviced.'),
 ('OWNERSHIP_ITEM','UnderMSR','LS020',
  N'FV7 Loans Serviced Under MSRs.'),
 ('OWNERSHIP_ITEM','SubservicingForOthers','LS030',
  N'FV7 Subservicing for Others.'),
 ('OWNERSHIP_ITEM','SubservicedByOthers','LS040',
  N'FV7 Subservicing by Others.'),
 ('DELINQ_ITEM','LT30','LS200',
  N'FV7 Current Loans. Confirmed against filing 2026002.'),
 ('DELINQ_ITEM','D30_59','LS210',
  N'FV7 30 to 59 Days Delinquent.'),
 ('DELINQ_ITEM','D60_89','LS220',
  N'FV7 60 to 89 Days Delinquent.'),
 ('DELINQ_ITEM','D90Plus','LS230',
  N'FV7 90 or more Days Delinquent.')
) v(MapType, Src, Tgt, Note)
WHERE NOT EXISTS
      (SELECT 1 FROM ref.McrStagingCodeMap m
       WHERE m.MapTypeCode = v.MapType
         AND m.SourceCode = v.Src);
GO

/* ------------------------------------------------------------
   2. Register the derivation logic. Business logic
      registers once here, not in the procedure body.
   ------------------------------------------------------------ */
INSERT INTO gov.DerivationRule
    (RuleCode, RuleName, BusinessDescription,
     CanonicalLogic, ImplementingObjectName,
     ImplementationTypeCode)
SELECT v.Code, v.Nm, v.Descr, v.Logic, v.Obj, v.ImplType
FROM (VALUES
 ('DRV_MCRSVCPOP',
  N'MCR Servicing Filing Population',
  N'The loan population reportable on MCR RMLA Section '
+ N'III at a filing period end.',
  N'Population = dw.FactLoanMonthEndSnapshot rows where
AsOfDate = the filing period end and ActiveServicingFlag
= 1. No property state filter is applied: LS010 to LS040,
LS200 to LS230 and LS1300 to LS1340 are COMPANY scope
nationwide totals reported regardless of state licensure.
Loans subserviced by others remain in the population and
are reported on LS040.',
  N'reg.usp_ComputeMcrInternalValue', 'PROC_SET_BASED'),

 ('DRV_MCRFCOPEN',
  N'MCR Foreclosure Open at Period End',
  N'Whether a loan is in active foreclosure at a filing '
+ N'period end.',
  N'A loan is in foreclosure at period end when a
dw.FactForeclosureCase row exists with
ISNULL(ReferralDate, ''9999-12-31'') <= period end and
ISNULL(SaleHeldDate, ''9999-12-31'') > period end.
Referral opens the case; sale held closes it. A loan with
multiple cases counts once.',
  N'reg.usp_ComputeMcrInternalValue', 'PROC_SET_BASED'),

 ('DRV_MCROWNSHIP',
  N'MCR Servicing Ownership Grid',
  N'LS010 to LS040 by servicing ownership type.',
  N'For the DRV_MCRSVCPOP population, group by
dw.DimServicingType.ServicingTypeCode mapped through
ref.McrStagingCodeMap SERVICING_TYPE then OWNERSHIP_ITEM
to the FV7 item. Amount = SUM(CurrentUpbAmount) at
DECIMAL(18,2). Count = COUNT(loans). Every item emits a
row including zero.',
  N'reg.usp_ComputeMcrInternalValue', 'PROC_SET_BASED'),

 ('DRV_MCRDELINQ',
  N'MCR Servicing Delinquency Grid',
  N'LS200 to LS230 and the NMLS-derived LS290 total.',
  N'For the DRV_MCRSVCPOP population, group by
dw.DimDelinquencyStatus.DelinquencyBucketCode mapped
through ref.McrStagingCodeMap DELINQ_BUCKET then
DELINQ_ITEM to the FV7 item. Amount = SUM(
CurrentUpbAmount). Count = COUNT(loans). LS290 is not
submittable; it is the total NMLS derives as the sum of
LS200 through LS230 and is stored here for control
purposes only.',
  N'reg.usp_ComputeMcrInternalValue', 'PROC_SET_BASED'),

 ('DRV_MCRFCINV',
  N'MCR Foreclosure by Investor Grid',
  N'LS1300 to LS1340 and the NMLS-derived LS1390 total.',
  N'For the DRV_MCRSVCPOP population restricted to
DRV_MCRFCOPEN = true, group by
dw.DimInvestor.InvestorCode mapped through
ref.McrStagingCodeMap INVESTOR then FC_INVESTOR_ITEM to
the FV7 item. Investor UNKNOWN routes to LS1340 and is
reported separately as a control exception. LS1390 is not
submittable; it is the total NMLS derives as the sum of
LS1300 through LS1340.',
  N'reg.usp_ComputeMcrInternalValue', 'PROC_SET_BASED')
) v(Code, Nm, Descr, Logic, Obj, ImplType)
WHERE NOT EXISTS
      (SELECT 1 FROM gov.DerivationRule r
       WHERE r.RuleCode = v.Code);
GO

INSERT INTO gov.DerivationRuleInput
    (DerivationRuleId, DataElementId, InputReference,
     InputRoleNote)
SELECT r.DerivationRuleId, de.DataElementId, v.InputRef,
       v.RoleNote
FROM (VALUES
 ('DRV_MCRSVCPOP',
  N'dw.FactLoanMonthEndSnapshot.ActiveServicingFlag',
  NULL, N'Population gate.'),
 ('DRV_MCRSVCPOP',
  N'dw.FactLoanMonthEndSnapshot.AsOfDate',
  'DE_ASOF_DATE', N'Period end anchor.'),
 ('DRV_MCRFCOPEN',
  N'dw.FactForeclosureCase.ReferralDate',
  'DE_FC_CASE_STATUS', N'Opens the foreclosure case.'),
 ('DRV_MCRFCOPEN',
  N'dw.FactForeclosureCase.SaleHeldDate',
  'DE_FC_CASE_STATUS', N'Closes the foreclosure case.'),
 ('DRV_MCROWNSHIP',
  N'dw.DimServicingType.ServicingTypeCode',
  NULL, N'Ownership grid discriminator.'),
 ('DRV_MCROWNSHIP',
  N'dw.FactLoanMonthEndSnapshot.CurrentUpbAmount',
  'DE_CURRENT_UPB', N'Filed dollar measure.'),
 ('DRV_MCRDELINQ',
  N'dw.DimDelinquencyStatus.DelinquencyBucketCode',
  NULL, N'Delinquency grid discriminator.'),
 ('DRV_MCRDELINQ',
  N'dw.FactLoanMonthEndSnapshot.CurrentUpbAmount',
  'DE_CURRENT_UPB', N'Filed dollar measure.'),
 ('DRV_MCRDELINQ',
  N'dw.FactLoanMonthEndSnapshot.LoanNumber',
  'DE_LOAN_NUMBER', N'Filed count grain.'),
 ('DRV_MCRFCINV',
  N'dw.DimInvestor.InvestorCode',
  'DE_INVESTOR_CODE', N'Investor category discriminator.'),
 ('DRV_MCRFCINV',
  N'dw.FactLoanMonthEndSnapshot.CurrentUpbAmount',
  'DE_CURRENT_UPB', N'Filed dollar measure.')
) v(RuleCode, InputRef, ElementCode, RoleNote)
JOIN gov.DerivationRule r ON r.RuleCode = v.RuleCode
LEFT JOIN gov.DataElement de
  ON de.DataElementCode = v.ElementCode
WHERE NOT EXISTS
      (SELECT 1 FROM gov.DerivationRuleInput i
       WHERE i.DerivationRuleId = r.DerivationRuleId
         AND i.InputReference = v.InputRef);
GO

/* ------------------------------------------------------------
   3. reg.McrInternalValue
      No FK to mcr.*: the isolation rule holds in both
      directions. DerivationRuleCode is NOT NULL and FK'd,
      so no computed value can exist without registered
      logic behind it.
   ------------------------------------------------------------ */
IF OBJECT_ID('reg.McrInternalValue', 'U') IS NULL
BEGIN
    CREATE TABLE reg.McrInternalValue
    (
        McrInternalValueId INT IDENTITY(1,1) NOT NULL,
        FilingId        INT           NOT NULL,
        PeriodEndDate   DATE          NOT NULL,
        ItemCode        VARCHAR(20)   NOT NULL,
        ElementName     VARCHAR(20)   NOT NULL,
        ScopeKey        VARCHAR(10)   NOT NULL,
        MeasureTypeCode VARCHAR(10)   NOT NULL,
        NumValue        DECIMAL(18,2) NOT NULL,
        PopulationRowCount INT        NOT NULL,
        NmlsDerivedFlag BIT           NOT NULL
            CONSTRAINT DF_McrInternalValue_NmlsDerivedFlag
            DEFAULT 0,
        DerivationRuleCode VARCHAR(30) NOT NULL,
        ComputationNote NVARCHAR(400) NULL,
        LoadBatchId     INT           NULL,
        ComputedDateUtc DATETIME2(3)  NOT NULL
            CONSTRAINT DF_McrInternalValue_ComputedDateUtc
            DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_McrInternalValue
            PRIMARY KEY CLUSTERED (McrInternalValueId),
        CONSTRAINT UQ_McrInternalValue_Filing_Scope_Element
            UNIQUE (FilingId, ScopeKey, ElementName),
        CONSTRAINT CK_McrInternalValue_MeasureTypeCode
            CHECK (MeasureTypeCode IN ('AMOUNT','COUNT')),
        CONSTRAINT FK_McrInternalValue_DerivationRule
            FOREIGN KEY (DerivationRuleCode)
            REFERENCES gov.DerivationRule (RuleCode)
    );
END;
GO

/* ------------------------------------------------------------
   4. reg.usp_ComputeMcrInternalValue
      Set based, no cursors, no dynamic SQL.
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

    /* ---- Population, full and unfiltered by state ---- */
    IF OBJECT_ID('tempdb..#Pop') IS NOT NULL
        DROP TABLE #Pop;

    CREATE TABLE #Pop
    (
        LoanNumber   VARCHAR(20)   NOT NULL,
        Upb          DECIMAL(18,2) NOT NULL,
        OwnItemCode  VARCHAR(20)   NULL,
        DelItemCode  VARCHAR(20)   NULL,
        InvItemCode  VARCHAR(20)   NULL,
        FcOpenFlag   BIT           NOT NULL
    );

    INSERT INTO #Pop
        (LoanNumber, Upb, OwnItemCode, DelItemCode,
         InvItemCode, FcOpenFlag)
    SELECT
        s.LoanNumber,
        ISNULL(s.CurrentUpbAmount, 0),
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

    /* ---- Aggregate the three grids ---- */
    IF OBJECT_ID('tempdb..#Line') IS NOT NULL
        DROP TABLE #Line;

    CREATE TABLE #Line
    (
        ItemCode VARCHAR(20)   NOT NULL PRIMARY KEY,
        Amt      DECIMAL(18,2) NOT NULL,
        Cnt      INT           NOT NULL
    );

    INSERT INTO #Line (ItemCode, Amt, Cnt)
    SELECT x.ItemCode, SUM(x.Upb), COUNT(*)
    FROM
    (
        SELECT OwnItemCode AS ItemCode, Upb FROM #Pop
        UNION ALL
        SELECT DelItemCode, Upb FROM #Pop
        UNION ALL
        SELECT InvItemCode, Upb FROM #Pop
        WHERE FcOpenFlag = 1
    ) x
    GROUP BY x.ItemCode;

    /* ---- Detail rows, explicit zeros included ---- */
    INSERT INTO reg.McrInternalValue
        (FilingId, PeriodEndDate, ItemCode, ElementName,
         ScopeKey, MeasureTypeCode, NumValue,
         PopulationRowCount, NmlsDerivedFlag,
         DerivationRuleCode, ComputationNote, LoadBatchId)
    SELECT
        @FilingId, @PeriodEnd, i.ItemCode, e.ElementName,
        'COMPANY',
        CASE WHEN e.DataType = 'Count'
             THEN 'COUNT' ELSE 'AMOUNT' END,
        CASE WHEN e.DataType = 'Count'
             THEN CAST(ISNULL(l.Cnt, 0) AS DECIMAL(18,2))
             ELSE ISNULL(l.Amt, 0) END,
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

    /* ---- NMLS-derived totals ---- */
    INSERT INTO reg.McrInternalValue
        (FilingId, PeriodEndDate, ItemCode, ElementName,
         ScopeKey, MeasureTypeCode, NumValue,
         PopulationRowCount, NmlsDerivedFlag,
         DerivationRuleCode, ComputationNote, LoadBatchId)
    SELECT
        @FilingId, @PeriodEnd, t.ItemCode,
        t.ItemCode + t.Suffix, 'COMPANY', t.MeasType,
        CASE WHEN t.MeasType = 'COUNT'
             THEN CAST(SUM(v.PopulationRowCount)
                  AS DECIMAL(18,2))
             ELSE SUM(CASE WHEN v.MeasureTypeCode = 'AMOUNT'
                           THEN v.NumValue ELSE 0 END) END,
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
   5. Execute for filing 2026002.
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
DECLARE @Detail      NVARCHAR(2000);

SET @BatchName = N'MCR internal value recompute Q2 2026';
SET @StepName  = N'Recompute MCR servicing lines from dw';
SET @TargetObj = N'reg.McrInternalValue';
SET @BatchNotes =
    N'Script 038: independent governance recompute of the '
  + N'MCR RMLA Section III servicing lines from the '
  + N'warehouse, at full precision over the full active '
  + N'population.';

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

    SET @Detail = N'reg.McrInternalValue populated for '
                + N'filing 2026002 at 2026-06-30 from '
                + N'dw at full precision and full active '
                + N'population.';

    INSERT INTO gov.ChangeLog
        (EntityTypeCode, EntityReference, ChangeTypeCode,
         ChangeDescription, LoadBatchId)
    SELECT 'MCR_INTERNAL_VALUE', N'FilingId 2026002',
           'INSERT', @Detail, @LoadBatchId;

END TRY
BEGIN CATCH
    EXEC audit.usp_LogError
        @LoadBatchId = @LoadBatchId,
        @LoadExecutionId = @LoadExecId,
        @ContextInfo = N'038 MCR internal recompute';
    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'FAILED';
    THROW;
END CATCH
GO

/* ------------------------------------------------------------
   6. Verification
   ------------------------------------------------------------ */

/* 6a. Internal versus filed, element by element. This is
       the shape script 039 turns into controls. */
SELECT
    iv.ItemCode, fc.Label, iv.ElementName,
    iv.MeasureTypeCode,
    InternalValue = iv.NumValue,
    FiledValue = rv.NumValue,
    Variance = rv.NumValue - iv.NumValue,
    FiledStatus = CASE WHEN rv.NumValue IS NULL
                       THEN 'ABSENT FROM FILING'
                       WHEN rv.NumValue = iv.NumValue
                       THEN 'MATCH' ELSE 'VARIANCE' END,
    iv.NmlsDerivedFlag
FROM reg.McrInternalValue iv
JOIN reg.vw_McrFieldCatalog fc
  ON fc.ItemCode = iv.ItemCode
LEFT JOIN reg.vw_McrReportValues rv
  ON rv.FilingId = iv.FilingId
 AND rv.ScopeKey = iv.ScopeKey
 AND rv.ElementName = iv.ElementName
WHERE iv.FilingId = 2026002
ORDER BY fc.FormOrder, iv.ElementName;

/* 6b. Grid totals. Internal must equal the warehouse
       population exactly; filed will fall short. */
SELECT
    Grid = CASE WHEN ItemCode IN ('LS010','LS020','LS030',
                                  'LS040')
                THEN 'Ownership'
                WHEN ItemCode IN ('LS200','LS210','LS220',
                                  'LS230')
                THEN 'Delinquency' ELSE 'Foreclosure' END,
    InternalLoans = SUM(CASE WHEN MeasureTypeCode = 'COUNT'
                             THEN NumValue END),
    InternalUpb = SUM(CASE WHEN MeasureTypeCode = 'AMOUNT'
                           THEN NumValue END)
FROM reg.McrInternalValue
WHERE FilingId = 2026002
  AND NmlsDerivedFlag = 0
GROUP BY CASE WHEN ItemCode IN ('LS010','LS020','LS030',
                                'LS040')
              THEN 'Ownership'
              WHEN ItemCode IN ('LS200','LS210','LS220',
                                'LS230')
              THEN 'Delinquency' ELSE 'Foreclosure' END;

/* 6c. The completeness variance, quantified. */
SELECT
    WarehouseActiveLoans =
        (SELECT COUNT(*) FROM dw.FactLoanMonthEndSnapshot
         WHERE AsOfDate = '2026-06-30'
           AND ActiveServicingFlag = 1),
    InternalDelinqLoans =
        (SELECT SUM(NumValue) FROM reg.McrInternalValue
         WHERE FilingId = 2026002
           AND MeasureTypeCode = 'COUNT'
           AND ItemCode IN ('LS200','LS210','LS220',
                            'LS230')),
    FiledDelinqLoans =
        (SELECT SUM(rv.NumValue)
         FROM reg.vw_McrReportValues rv
         JOIN reg.vw_McrFieldCatalogElement e
           ON e.ElementName = rv.ElementName
         WHERE rv.FilingId = 2026002
           AND e.DataType = 'Count'
           AND e.ItemCode IN ('LS200','LS210','LS220',
                              'LS230')),
    InternalDelinqUpb =
        (SELECT SUM(NumValue) FROM reg.McrInternalValue
         WHERE FilingId = 2026002
           AND MeasureTypeCode = 'AMOUNT'
           AND ItemCode IN ('LS200','LS210','LS220',
                            'LS230')),
    FiledDelinqUpb =
        (SELECT SUM(rv.NumValue)
         FROM reg.vw_McrReportValues rv
         JOIN reg.vw_McrFieldCatalogElement e
           ON e.ElementName = rv.ElementName
         WHERE rv.FilingId = 2026002
           AND e.DataType <> 'Count'
           AND e.ItemCode IN ('LS200','LS210','LS220',
                              'LS230'));

/* 6d. Registered logic behind every computed value. */
SELECT r.RuleCode, r.RuleName, r.ImplementationTypeCode,
       Inputs = COUNT(DISTINCT i.DerivationRuleInputId),
       BoundElements = COUNT(DISTINCT i.DataElementId),
       ValuesComputed = COUNT(DISTINCT
           v.McrInternalValueId)
FROM gov.DerivationRule r
LEFT JOIN gov.DerivationRuleInput i
  ON i.DerivationRuleId = r.DerivationRuleId
LEFT JOIN reg.McrInternalValue v
  ON v.DerivationRuleCode = r.RuleCode
WHERE r.RuleCode LIKE 'DRV_MCR%'
GROUP BY r.RuleCode, r.RuleName,
         r.ImplementationTypeCode
ORDER BY r.RuleCode;
GO