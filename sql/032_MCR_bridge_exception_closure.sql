/* ============================================================
   MortgageGovernance | Phase 2 | Script 032 (corrected)
   MCR bridge exception closure.
   Supersedes the first 032 issue. Safe to run over the
   partial state left by that run: closes the orphaned load
   batch, recreates reg.McrBridgeDisposition at the correct
   width, and suppresses duplicate ChangeLog entries when the
   CalculatedFlag correction is already applied.
   Azure SQL Database form: no USE, no three-part names.
   All mcr access via the 7 reg.vw_Mcr* isolation views.
   Idempotent: safe to re-run.
   ============================================================ */
SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   0. Reconcile the aborted run.
   ------------------------------------------------------------ */
UPDATE audit.LoadBatch
   SET StatusCode = 'FAILED',
       EndDateUtc = SYSUTCDATETIME()
 WHERE BatchName = N'MCR bridge exception closure'
   AND EndDateUtc IS NULL;

IF OBJECT_ID('reg.McrBridgeDisposition') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM reg.McrBridgeDisposition)
    DROP TABLE reg.McrBridgeDisposition;
GO

DECLARE @LoadBatchId INT,
        @Rows INT,
        @ToCalc INT,
        @ToSubmit INT,
        @Detail NVARCHAR(2000),
        @Context NVARCHAR(1000),
        @NoahId INT,
        @MarcoId INT,
        @SofiaId INT,
        @SecCompany INT,
        @SecOne INT;

SELECT @NoahId = PartyId FROM gov.Party
WHERE PartyName = 'Noah Curlew'
  AND PartyTypeCode = 'PERSON';
SELECT @MarcoId = PartyId FROM gov.Party
WHERE PartyName = 'Marco Ibis'
  AND PartyTypeCode = 'PERSON';
SELECT @SofiaId = PartyId FROM gov.Party
WHERE PartyName = 'Sofia Egret'
  AND PartyTypeCode = 'PERSON';

SELECT @SecCompany = RegulatoryReportSectionId
FROM gov.RegulatoryReportSection
WHERE SectionCode = 'RMLA_COMPANY';

SELECT @SecOne = RegulatoryReportSectionId
FROM gov.RegulatoryReportSection
WHERE SectionCode = 'RMLA_SEC1';

IF @SecCompany IS NULL OR @SecOne IS NULL
BEGIN
    RAISERROR('Required RMLA sections not found. Run 006.',
              16, 1);
    RETURN;
END;

EXEC audit.usp_StartLoadBatch
    @BatchName = N'MCR bridge exception closure',
    @BatchTypeCode = 'ADHOC',
    @Notes = N'Corrects gov CalculatedFlag to XSD authority, dispositions annotation and alias exceptions, registers the MCR_ONLY block.',
    @LoadBatchId = @LoadBatchId OUTPUT;

BEGIN TRY

/* ------------------------------------------------------------
   1. Disposition register. TargetItemCode is VARCHAR(60) to
      hold either an ItemCode or an mcr.ListCatalog.ListName.
   ------------------------------------------------------------ */
IF OBJECT_ID('reg.McrBridgeDisposition') IS NULL
BEGIN
    CREATE TABLE reg.McrBridgeDisposition
    (
        McrBridgeDispositionId INT IDENTITY(1,1) NOT NULL,
        GovItemCode      VARCHAR(30)   NOT NULL,
        DispositionCode  VARCHAR(20)   NOT NULL,
        TargetItemCode   VARCHAR(60)   NULL,
        Rationale        NVARCHAR(600) NOT NULL,
        DispositionedByPartyId INT      NULL,
        LoadBatchId      INT NULL,
        CreatedDateUtc   DATETIME2(3) NOT NULL
            CONSTRAINT DF_McrBridgeDisposition_CreatedDateUtc
            DEFAULT SYSUTCDATETIME(),
        ModifiedDateUtc  DATETIME2(3) NULL,
        CONSTRAINT PK_McrBridgeDisposition
            PRIMARY KEY CLUSTERED (McrBridgeDispositionId),
        CONSTRAINT UQ_McrBridgeDisposition_GovItemCode
            UNIQUE (GovItemCode),
        CONSTRAINT CK_McrBridgeDisposition_DispositionCode
            CHECK (DispositionCode IN
                   ('ANNOTATION','ALIAS','LIST','DEPRECATED',
                    'REGISTERED','COVERAGE_DEFERRED'))
    );
END;

/* ------------------------------------------------------------
   2. CalculatedFlag correction. mcr.FieldCatalog is
      authoritative for submission structure. Derived from the
      bridge, not a hardcoded list, so the correction stays
      valid if the XSD is reissued.
   ------------------------------------------------------------ */
IF OBJECT_ID('tempdb..#CalcFix') IS NOT NULL
    DROP TABLE #CalcFix;

SELECT b.ItemCode,
       b.GovCalculatedFlag AS OldFlag,
       v.IsCalculated      AS NewFlag
INTO #CalcFix
FROM reg.McrItemBridge b
JOIN reg.vw_McrFieldCatalog v
  ON v.ItemCode = b.ItemCode
WHERE b.MatchStatusCode = 'MATCHED'
  AND ISNULL(b.CalcFlagAlignedFlag, 1) = 0;

SELECT @ToCalc = SUM(CASE WHEN NewFlag = 1 THEN 1 ELSE 0 END),
       @ToSubmit = SUM(CASE WHEN NewFlag = 0 THEN 1 ELSE 0 END)
FROM #CalcFix;

UPDATE g
   SET g.CalculatedFlag  = f.NewFlag,
       g.ModifiedDateUtc = SYSUTCDATETIME()
FROM gov.RegulatoryReportItem g
JOIN #CalcFix f
  ON f.ItemCode = g.ItemCode
WHERE g.CalculatedFlag <> f.NewFlag;
SET @Rows = @@ROWCOUNT;

IF @Rows > 0
BEGIN
    SET @Detail = N'CalculatedFlag corrected on '
        + CAST(@Rows AS NVARCHAR(10))
        + N' items to XSD authority. '
        + CAST(ISNULL(@ToCalc, 0) AS NVARCHAR(10))
        + N' flipped to NMLS-calculated (no source lineage '
        + N'required). '
        + CAST(ISNULL(@ToSubmit, 0) AS NVARCHAR(10))
        + N' flipped to submittable (source lineage now '
        + N'mandatory).';

    INSERT INTO gov.ChangeLog
        (EntityTypeCode, EntityReference, ChangeTypeCode,
         ChangeDescription, LoadBatchId)
    VALUES
        ('REGULATORY_REPORT_ITEM',
         N'gov.RegulatoryReportItem.CalculatedFlag',
         'UPDATE', @Detail, @LoadBatchId);
END;

/* ------------------------------------------------------------
   3. Repeating list correspondences. Confirmed by element
      prefix: S520_n under SectionIIILoansServicedUnderMsrsItem
      and so on. Resolves 3 of the 11 GOV_ONLY items.
   ------------------------------------------------------------ */
INSERT INTO reg.McrListMap
    (GovItemCode, McrListName, MappingNote, LoadBatchId)
SELECT v.GovCode, v.ListName, v.Note, @LoadBatchId
FROM (VALUES
 ('S520A', 'SectionIIILoansServicedUnderMsrsItem',
  N'RMLA Section III detail. One repeating row per '
+ N'investor for loans serviced under owned MSRs.'),
 ('S530A', 'SectionIIILoansServicedForOthersItem',
  N'RMLA Section III detail. One repeating row per '
+ N'master servicer for subservicing performed for '
+ N'others.'),
 ('S540A', 'SectionIIILoansServicedByOthersItem',
  N'RMLA Section III detail. One repeating row per '
+ N'subservicer for loans subserviced by others.')
) v(GovCode, ListName, Note)
WHERE NOT EXISTS
      (SELECT 1 FROM reg.McrListMap m
       WHERE m.GovItemCode = v.GovCode);

/* ------------------------------------------------------------
   4. Annotation and alias dispositions.
      The 5 NOTE codes are gov-side instruction carriers for
      parents that are already MATCHED. The 3 TOT codes are
      gov-side over-decomposition of a single XSD item.
      Neither is a coverage gap.
   ------------------------------------------------------------ */
INSERT INTO reg.McrBridgeDisposition
    (GovItemCode, DispositionCode, TargetItemCode,
     Rationale, DispositionedByPartyId, LoadBatchId)
SELECT v.GovCode, v.Disp, v.Target, v.Why,
       @SofiaId, @LoadBatchId
FROM (VALUES
 ('A060AHNOTE','ANNOTATION','A060AH',
  N'Instruction text carrier for matched parent A060AH. '
+ N'Not a reportable item. Fold into parent definition.'),
 ('A060AINOTE','ANNOTATION','A060AI',
  N'Instruction text carrier for matched parent A060AI. '
+ N'Not a reportable item. Fold into parent definition.'),
 ('A230GNOTE','ANNOTATION','A230G',
  N'Instruction text carrier for matched parent A230G. '
+ N'Not a reportable item. Fold into parent definition.'),
 ('A230HNOTE','ANNOTATION','A230H',
  N'Instruction text carrier for matched parent A230H. '
+ N'Not a reportable item. Fold into parent definition.'),
 ('B350NNOTE','ANNOTATION','B350N',
  N'Instruction text carrier for matched parent B350N. '
+ N'Not a reportable item. Fold into parent definition.'),
 ('S520TOT','ALIAS','S520',
  N'Gov-side total decomposition. XSD carries the section '
+ N'total as item S520 with elements S520_1 and S520_2.'),
 ('S530TOT','ALIAS','S530',
  N'Gov-side total decomposition. XSD carries the section '
+ N'total as item S530 with elements S530_1 and S530_2.'),
 ('S540TOT','ALIAS','S540',
  N'Gov-side total decomposition. XSD carries the section '
+ N'total as item S540 with elements S540_1 and S540_2.'),
 ('S520A','LIST','SectionIIILoansServicedUnderMsrsItem',
  N'Repeating list correspondence, see reg.McrListMap.'),
 ('S530A','LIST','SectionIIILoansServicedForOthersItem',
  N'Repeating list correspondence, see reg.McrListMap.'),
 ('S540A','LIST','SectionIIILoansServicedByOthersItem',
  N'Repeating list correspondence, see reg.McrListMap.')
) v(GovCode, Disp, Target, Why)
WHERE NOT EXISTS
      (SELECT 1 FROM reg.McrBridgeDisposition d
       WHERE d.GovItemCode = v.GovCode);

/* ------------------------------------------------------------
   5. Register the MCR_ONLY block. LS1300 to LS1340 are the
      nationwide foreclosed-loan breakout by investor
      category, sourceable from dw.FactForeclosureCase and
      dw.DimInvestor. AC710 is vestigial: FHA retired the
      HECM Saver product, the XSD field persists and is
      NMLS-calculated with zero elements.
   ------------------------------------------------------------ */
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
SELECT v.SecId, v.Code, v.Nm, v.Sub, v.Instr, v.Guide,
       v.Fmt, v.Calc, v.Ex, v.Ord, @LoadBatchId
FROM (VALUES
 (@SecCompany, 'LS1300', N'FNMA',
  N'Loans Serviced - Nationwide Totals',
  N'Enter the UPB and Loan Count of foreclosed loans serviced where FNMA is the investor. Report nationwide totals regardless of state licensure.',
  N'Population: loans in active foreclosure at period end where investor category is FNMA | Filters: DimInvestor.InvestorCode = ''FNMA''; foreclosure case open at period end; NATIONWIDE, no state filter | Timing: as of period end | Measures: SUM(current UPB), COUNT(loans) | Source: dw.FactForeclosureCase joined to dw.DimInvestor and dw.FactLoanMonthEndSnapshot',
  N'UPB: dollar; Count: whole number', 0,
  N'UPB 41200000 | Count 168', 242),
 (@SecCompany, 'LS1310', N'FHLMC',
  N'Loans Serviced - Nationwide Totals',
  N'Enter the UPB and Loan Count of foreclosed loans serviced where FHLMC is the investor. Report nationwide totals regardless of state licensure.',
  N'Population: loans in active foreclosure at period end where investor category is FHLMC | Filters: DimInvestor.InvestorCode = ''FHLMC''; foreclosure case open at period end; NATIONWIDE, no state filter | Timing: as of period end | Measures: SUM(current UPB), COUNT(loans) | Source: dw.FactForeclosureCase joined to dw.DimInvestor and dw.FactLoanMonthEndSnapshot',
  N'UPB: dollar; Count: whole number', 0,
  N'UPB 33900000 | Count 141', 243),
 (@SecCompany, 'LS1320', N'GNMA',
  N'Loans Serviced - Nationwide Totals',
  N'Enter the UPB and Loan Count of foreclosed loans serviced where GNMA is the investor. Report nationwide totals regardless of state licensure.',
  N'Population: loans in active foreclosure at period end where investor category is GNMA | Filters: DimInvestor.InvestorCode = ''GNMA''; foreclosure case open at period end; NATIONWIDE, no state filter | Timing: as of period end | Measures: SUM(current UPB), COUNT(loans) | Source: dw.FactForeclosureCase joined to dw.DimInvestor and dw.FactLoanMonthEndSnapshot',
  N'UPB: dollar; Count: whole number', 0,
  N'UPB 28400000 | Count 132', 244),
 (@SecCompany, 'LS1330', N'Private Label',
  N'Loans Serviced - Nationwide Totals',
  N'Enter the UPB and Loan Count of foreclosed loans serviced in private label securitizations. Report nationwide totals regardless of state licensure.',
  N'Population: loans in active foreclosure at period end held in private label securitizations | Filters: DimInvestor investor category = private label; foreclosure case open at period end; NATIONWIDE, no state filter | Timing: as of period end | Measures: SUM(current UPB), COUNT(loans) | Source: dw.FactForeclosureCase joined to dw.DimInvestor and dw.FactLoanMonthEndSnapshot',
  N'UPB: dollar; Count: whole number', 0,
  N'UPB 9100000 | Count 38', 245),
 (@SecCompany, 'LS1340', N'Other',
  N'Loans Serviced - Nationwide Totals',
  N'Enter the UPB and Loan Count of foreclosed loans serviced for all other investor categories not reported in LS1300 through LS1330.',
  N'Population: loans in active foreclosure at period end whose investor category is not FNMA, FHLMC, GNMA or private label, including portfolio and whole loan investors | Filters: residual of the four named categories; foreclosure case open at period end; NATIONWIDE, no state filter | Timing: as of period end | Measures: SUM(current UPB), COUNT(loans) | Source: dw.FactForeclosureCase joined to dw.DimInvestor and dw.FactLoanMonthEndSnapshot',
  N'UPB: dollar; Count: whole number', 0,
  N'UPB 5600000 | Count 24', 246),
 (@SecCompany, 'LS1390', N'Total Foreclosed Loans',
  N'Loans Serviced - Nationwide Totals',
  N'NMLS-calculated. Equals the sum of rows LS1300 to LS1340 in the above column.',
  N'Derived by NMLS at filing. No source mapping required. Reconciliation control only: internal total must agree to the sum of LS1300 through LS1340 before submission.',
  N'UPB: dollar; Count: whole number', 1,
  N'UPB 118200000 | Count 503', 247),
 (@SecOne, 'AC710', N'HECM-Saver',
  N'Section I - Reverse Mortgage Loan Type',
  N'NMLS-calculated field retained in the FV7 schema for backward compatibility. The FHA HECM Saver product was retired and consolidated into a single HECM product; no new originations are reportable.',
  N'No source mapping. Vestigial schema field with zero submittable elements. Expected to submit as zero or absent for all periods. Steward review required only if FHA reintroduces a tiered HECM product.',
  N'Not submittable; no elements', 1,
  N'0', 33)
) v(SecId, Code, Nm, Sub, Instr, Guide, Fmt, Calc, Ex, Ord)
WHERE NOT EXISTS
      (SELECT 1 FROM gov.RegulatoryReportItem g
       WHERE g.ItemCode = v.Code
         AND g.RegulatoryReportSectionId = v.SecId);

INSERT INTO reg.McrBridgeDisposition
    (GovItemCode, DispositionCode, TargetItemCode,
     Rationale, DispositionedByPartyId, LoadBatchId)
SELECT v.GovCode, v.Disp, v.GovCode, v.Why,
       v.Owner, @LoadBatchId
FROM (VALUES
 ('LS1300','REGISTERED',
  N'Business definition registered. Sourceable from dw '
+ N'foreclosure and investor structures.', @MarcoId),
 ('LS1310','REGISTERED',
  N'Business definition registered. Sourceable from dw '
+ N'foreclosure and investor structures.', @MarcoId),
 ('LS1320','REGISTERED',
  N'Business definition registered. Sourceable from dw '
+ N'foreclosure and investor structures.', @MarcoId),
 ('LS1330','REGISTERED',
  N'Business definition registered. Sourceable from dw '
+ N'foreclosure and investor structures.', @MarcoId),
 ('LS1340','REGISTERED',
  N'Business definition registered. Sourceable from dw '
+ N'foreclosure and investor structures.', @MarcoId),
 ('LS1390','REGISTERED',
  N'NMLS-calculated total. Reconciliation control only, '
+ N'no source lineage.', @MarcoId),
 ('AC710','DEPRECATED',
  N'Vestigial FV7 field. FHA retired the HECM Saver '
+ N'product. Zero elements, NMLS-calculated.', @SofiaId)
) v(GovCode, Disp, Why, Owner)
WHERE NOT EXISTS
      (SELECT 1 FROM reg.McrBridgeDisposition d
       WHERE d.GovItemCode = v.GovCode);

/* ------------------------------------------------------------
   6. Coverage honesty. D310 and D510 are submittable per the
      XSD but Flamingo has no Finance/GL source domain.
      Registered as deferred rather than given synthetic
      lineage.
   ------------------------------------------------------------ */
INSERT INTO reg.McrBridgeDisposition
    (GovItemCode, DispositionCode, TargetItemCode,
     Rationale, DispositionedByPartyId, LoadBatchId)
SELECT v.GovCode, 'COVERAGE_DEFERRED', v.GovCode,
       v.Why, @NoahId, @LoadBatchId
FROM (VALUES
 ('D310',
  N'Submittable per XSD with an NMLS validation formula, '
+ N'not a derivation. Requires a Finance/GL source domain '
+ N'which is out of scope for this portfolio. No source '
+ N'lineage will be asserted.'),
 ('D510',
  N'Submittable per XSD with an NMLS validation formula, '
+ N'not a derivation. Requires a Finance/GL source domain '
+ N'which is out of scope for this portfolio. No source '
+ N'lineage will be asserted.')
) v(GovCode, Why)
WHERE NOT EXISTS
      (SELECT 1 FROM reg.McrBridgeDisposition d
       WHERE d.GovItemCode = v.GovCode);

SET @Detail = N'Bridge exception closure complete. '
    + N'3 list correspondences, 11 annotation, alias and '
    + N'list dispositions, 7 MCR_ONLY items registered, '
    + N'2 coverage deferrals recorded.';

INSERT INTO gov.ChangeLog
    (EntityTypeCode, EntityReference, ChangeTypeCode,
     ChangeDescription, LoadBatchId)
VALUES
    ('MCR_BRIDGE', N'reg.McrItemBridge', 'VERSION',
     @Detail, @LoadBatchId);

EXEC audit.usp_CompleteLoadBatch
    @LoadBatchId = @LoadBatchId,
    @StatusCode = 'SUCCESS';

END TRY
BEGIN CATCH
    SET @Context = N'Script 032 MCR bridge exception closure';
    EXEC audit.usp_LogError
        @LoadBatchId = @LoadBatchId,
        @ContextInfo = @Context;
    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'FAILED';
    THROW;
END CATCH;
GO

/* ------------------------------------------------------------
   Verification
   ------------------------------------------------------------ */
SELECT 'CalcFlag residual mismatches' AS Check_,
       COUNT(*) AS Actual, 0 AS Expected
FROM reg.McrItemBridge b
JOIN reg.vw_McrFieldCatalog v ON v.ItemCode = b.ItemCode
JOIN gov.RegulatoryReportItem g ON g.ItemCode = b.ItemCode
WHERE g.CalculatedFlag <> v.IsCalculated;

SELECT DispositionCode, COUNT(*) AS Items
FROM reg.McrBridgeDisposition
GROUP BY DispositionCode
ORDER BY DispositionCode;

SELECT 'Undispositioned bridge exceptions' AS Check_,
       COUNT(*) AS Actual, 0 AS Expected
FROM reg.McrItemBridge b
LEFT JOIN reg.McrBridgeDisposition d
       ON d.GovItemCode = b.ItemCode
WHERE b.MatchStatusCode IN ('GOV_ONLY','MCR_ONLY')
  AND d.GovItemCode IS NULL;

SELECT 'Open load batches' AS Check_,
       COUNT(*) AS Actual, 0 AS Expected
FROM audit.LoadBatch
WHERE BatchName = N'MCR bridge exception closure'
  AND EndDateUtc IS NULL;
GO