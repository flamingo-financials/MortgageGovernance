/* ============================================================
   MortgageGovernance | Integration Phase 2 | Script 040
   MCR filing reconciliation controls.

   AS-OF DATE
   These execute at the FILING PERIOD END (2026-06-30), not
   the servicing certification date (2026-07-31).
   gov.usp_CertifyReport counts reconciliation results
   WHERE AsOfDate = its own as-of, so these results are
   correctly invisible to the PBI_SVC_GOV gate. An MCR
   filing certifies as a filing. Stamping filing controls
   with the report's as-of date to make them visible would
   be falsifying the as-of date on regulatory evidence.
   The filing certification gate that consumes BlockingFlag
   is script 041.

   TOLERANCE
   All EXACT. Both sides are computed on the filed whole
   dollar basis, so form-required rounding is matched rather
   than absorbed into a tolerance that would blind the
   control to real errors of similar magnitude.

   EXPECTED STATE
   Six FAIL, four PASS. The failures are one root cause
   observed at four points plus two distinct completeness
   defects. Controls that cannot fail prove nothing, and
   controls that all fail prove nothing either.

   Azure SQL Database. No USE. Idempotent.
   ============================================================ */
SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   1. Seed the controls.
   ------------------------------------------------------------ */
DECLARE @OwnerId INT =
    (SELECT PartyId FROM gov.Party
     WHERE PartyName = 'Paige Justice'
       AND PartyTypeCode = 'PERSON');

INSERT INTO audit.ReconciliationControl
    (ControlCode, ControlName, ControlDescription,
     ControlTypeCode, SourceExpression, TargetExpression,
     ImplementingObject, ToleranceTypeCode, BlockingFlag,
     OwnerPartyId)
SELECT v.Code, v.Nm, v.Descr, 'MCR_TIEOUT', v.SrcExpr,
       v.TgtExpr, N'reg.usp_RunMcrReconciliation', 'EXACT',
       v.Blocking, @OwnerId
FROM (VALUES
 ('RC_MCR_SVC_UPB',
  N'MCR delinquency grid UPB, governance to filed',
  N'Independent warehouse recompute of LS200 to LS230 '
+ N'total UPB on the filed whole dollar basis, against '
+ N'the value the filing engine actually filed.',
  N'SUM(NumValueFiledBasis) reg.McrInternalValue LS200-230',
  N'SUM(NumValue) filed LS200-230 amount elements', 1),
 ('RC_MCR_SVC_CNT',
  N'MCR delinquency grid loan count, governance to filed',
  N'Same comparison on loan count. A count variance means '
+ N'loans are missing from the filing, not mispriced.',
  N'SUM(NumValueFiledBasis) reg.McrInternalValue LS200-230',
  N'SUM(NumValue) filed LS200-230 count elements', 1),
 ('RC_MCR_OWN_UPB',
  N'MCR ownership grid UPB, governance to filed',
  N'LS010 to LS040 total UPB. Partitions the same '
+ N'population as the delinquency grid through a '
+ N'different dimension, so it corroborates independently.',
  N'SUM(NumValueFiledBasis) reg.McrInternalValue LS010-040',
  N'SUM(NumValue) filed LS010-040 amount elements', 1),
 ('RC_MCR_OWN_CNT',
  N'MCR ownership grid loan count, governance to filed',
  N'Same comparison on loan count.',
  N'SUM(NumValueFiledBasis) reg.McrInternalValue LS010-040',
  N'SUM(NumValue) filed LS010-040 count elements', 1),
 ('RC_MCR_GRID_UPB',
  N'MCR filed grids cross-foot on UPB',
  N'Internal consistency of the submission itself. The '
+ N'ownership grid and the delinquency grid partition one '
+ N'population, so their filed totals must agree '
+ N'regardless of whether either matches the warehouse.',
  N'SUM(NumValue) filed LS010-040 amount elements',
  N'SUM(NumValue) filed LS200-230 amount elements', 1),
 ('RC_MCR_GRID_CNT',
  N'MCR filed grids cross-foot on loan count',
  N'Same internal consistency check on loan count.',
  N'SUM(NumValue) filed LS010-040 count elements',
  N'SUM(NumValue) filed LS200-230 count elements', 1),
 ('RC_MCR_FC_UPB',
  N'MCR foreclosure grid UPB, governance to filed',
  N'LS1300 to LS1340 total UPB.',
  N'SUM(NumValueFiledBasis) reg.McrInternalValue LS13xx',
  N'SUM(NumValue) filed LS13xx amount elements', 1),
 ('RC_MCR_FC_CNT',
  N'MCR foreclosure grid loan count, governance to filed',
  N'LS1300 to LS1340 total loan count. This is the detail '
+ N'from which NMLS derives LS1390.',
  N'SUM(NumValueFiledBasis) reg.McrInternalValue LS13xx',
  N'SUM(NumValue) filed LS13xx count elements', 1),
 ('RC_MCR_ELEM_PRESENT',
  N'MCR submittable elements present in the filing',
  N'Every governed detail element must appear in the '
+ N'filing, including those computing to zero. A summed '
+ N'total cannot detect an absent zero line, so this '
+ N'control counts elements rather than adding values.',
  N'COUNT of reg.McrInternalValue detail elements',
  N'COUNT of those elements present in mcr.ReportValues',
  1),
 ('RC_MCR_STG_COMPLETE',
  N'MCR staging completeness, warehouse to staging',
  N'Active loans at period end must all reach the filing '
+ N'staging contract. Catches population loss at the dw '
+ N'to mcrstg boundary, upstream of any filed value.',
  N'COUNT dw.FactLoanMonthEndSnapshot active at period end',
  N'COUNT mcrstg.ServicingPortfolio for the filing', 1)
) v(Code, Nm, Descr, SrcExpr, TgtExpr, Blocking)
WHERE NOT EXISTS
      (SELECT 1 FROM audit.ReconciliationControl c
       WHERE c.ControlCode = v.Code);
GO

/* ------------------------------------------------------------
   2. reg.usp_RunMcrReconciliation
      All values and all detail strings are staged
      set-based into a temp table first. The cursor fetches
      directly into pre-declared variables and every EXEC
      argument is a variable, never an expression.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE reg.usp_RunMcrReconciliation
    @FilingId    INT,
    @PeriodEnd   DATE,
    @LoadBatchId INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OwnBatch    BIT = 0;
    DECLARE @LoadExecId  INT;
    DECLARE @ControlCode VARCHAR(50);
    DECLARE @Src         DECIMAL(18,2);
    DECLARE @Tgt         DECIMAL(18,2);
    DECLARE @Det         NVARCHAR(2000);
    DECLARE @BatchName   NVARCHAR(200);
    DECLARE @StepName    NVARCHAR(200);
    DECLARE @TargetObj   NVARCHAR(200);
    DECLARE @BatchNotes  NVARCHAR(1000);
    DECLARE @IntElem     DECIMAL(18,2);
    DECLARE @FilElem     DECIMAL(18,2);
    DECLARE @DwActive    DECIMAL(18,2);
    DECLARE @Staged      DECIMAL(18,2);
    DECLARE @Executed    INT;

    IF @LoadBatchId IS NULL
    BEGIN
        SET @OwnBatch = 1;
        SET @BatchName = N'MCR filing reconciliation';
        SET @BatchNotes =
            N'reg.usp_RunMcrReconciliation executing the '
          + N'MCR_TIEOUT control set at a filing period '
          + N'end.';
        EXEC audit.usp_StartLoadBatch
            @BatchName = @BatchName,
            @BatchTypeCode = 'RECON',
            @Notes = @BatchNotes,
            @LoadBatchId = @LoadBatchId OUTPUT;
    END

    BEGIN TRY

        SET @StepName  = N'Execute MCR tie-out controls';
        SET @TargetObj = N'audit.ReconciliationResult';

        EXEC audit.usp_StartLoadExecution
            @LoadBatchId = @LoadBatchId,
            @StepName = @StepName,
            @TargetObject = @TargetObj,
            @LoadExecutionId = @LoadExecId OUTPUT;

        /* ---- Grid aggregates, both sides ---- */
        IF OBJECT_ID('tempdb..#Agg') IS NOT NULL
            DROP TABLE #Agg;

        CREATE TABLE #Agg
        (
            GridCode VARCHAR(10)   NOT NULL PRIMARY KEY,
            IntAmt   DECIMAL(18,2) NOT NULL,
            IntCnt   DECIMAL(18,2) NOT NULL,
            FilAmt   DECIMAL(18,2) NOT NULL,
            FilCnt   DECIMAL(18,2) NOT NULL
        );

        ;WITH GridMap AS
        (
            SELECT g.ItemCode, g.GridCode
            FROM (VALUES
                ('LS010','OWN'),('LS020','OWN'),
                ('LS030','OWN'),('LS040','OWN'),
                ('LS200','DELINQ'),('LS210','DELINQ'),
                ('LS220','DELINQ'),('LS230','DELINQ'),
                ('LS1300','FC'),('LS1310','FC'),
                ('LS1320','FC'),('LS1330','FC'),
                ('LS1340','FC')
            ) g(ItemCode, GridCode)
        ),
        IntSide AS
        (
            SELECT g.GridCode,
                   IntAmt = SUM(CASE
                       WHEN v.MeasureTypeCode = 'AMOUNT'
                       THEN v.NumValueFiledBasis END),
                   IntCnt = SUM(CASE
                       WHEN v.MeasureTypeCode = 'COUNT'
                       THEN v.NumValueFiledBasis END)
            FROM reg.McrInternalValue v
            JOIN GridMap g ON g.ItemCode = v.ItemCode
            WHERE v.FilingId = @FilingId
              AND v.NmlsDerivedFlag = 0
            GROUP BY g.GridCode
        ),
        FilSide AS
        (
            SELECT g.GridCode,
                   FilAmt = SUM(CASE
                       WHEN e.DataType <> 'Count'
                       THEN rv.NumValue END),
                   FilCnt = SUM(CASE
                       WHEN e.DataType = 'Count'
                       THEN rv.NumValue END)
            FROM reg.vw_McrReportValues rv
            JOIN reg.vw_McrFieldCatalogElement e
              ON e.ElementName = rv.ElementName
            JOIN GridMap g ON g.ItemCode = e.ItemCode
            WHERE rv.FilingId = @FilingId
              AND rv.ScopeKey = 'COMPANY'
            GROUP BY g.GridCode
        )
        INSERT INTO #Agg
            (GridCode, IntAmt, IntCnt, FilAmt, FilCnt)
        SELECT i.GridCode,
               ISNULL(i.IntAmt, 0), ISNULL(i.IntCnt, 0),
               ISNULL(f.FilAmt, 0), ISNULL(f.FilCnt, 0)
        FROM IntSide i
        LEFT JOIN FilSide f ON f.GridCode = i.GridCode;

        /* ---- Element presence ---- */
        SELECT @IntElem = COUNT(*)
        FROM reg.McrInternalValue v
        WHERE v.FilingId = @FilingId
          AND v.NmlsDerivedFlag = 0;

        SELECT @FilElem = COUNT(*)
        FROM reg.McrInternalValue v
        JOIN reg.vw_McrReportValues rv
          ON rv.FilingId = v.FilingId
         AND rv.ScopeKey = v.ScopeKey
         AND rv.ElementName = v.ElementName
        WHERE v.FilingId = @FilingId
          AND v.NmlsDerivedFlag = 0;

        /* ---- Staging completeness ---- */
        SELECT @DwActive = COUNT(*)
        FROM dw.FactLoanMonthEndSnapshot
        WHERE AsOfDate = @PeriodEnd
          AND ActiveServicingFlag = 1;

        SELECT @Staged = COUNT(*)
        FROM mcrstg.ServicingPortfolio
        WHERE FilingId = @FilingId;

        /* ---- Stage every control row and its detail ---- */
        IF OBJECT_ID('tempdb..#Result') IS NOT NULL
            DROP TABLE #Result;

        CREATE TABLE #Result
        (
            SeqNo       INT           NOT NULL,
            ControlCode VARCHAR(50)   NOT NULL,
            SourceValue DECIMAL(18,2) NULL,
            TargetValue DECIMAL(18,2) NULL,
            Details     NVARCHAR(2000) NULL
        );

        INSERT INTO #Result
            (SeqNo, ControlCode, SourceValue, TargetValue,
             Details)
        SELECT 1, 'RC_MCR_SVC_UPB', a.IntAmt, a.FilAmt,
               N'Delinquency grid UPB. Governance '
             + N'recompute on filed basis vs filed value. '
             + N'Filing ' + CAST(@FilingId AS NVARCHAR(12))
             + N' at '
             + CONVERT(CHAR(10), @PeriodEnd, 23) + N'.'
        FROM #Agg a WHERE a.GridCode = 'DELINQ'
        UNION ALL
        SELECT 2, 'RC_MCR_SVC_CNT', a.IntCnt, a.FilCnt,
               N'Delinquency grid loan count. A shortfall '
             + N'means reportable loans are absent from '
             + N'the submission.'
        FROM #Agg a WHERE a.GridCode = 'DELINQ'
        UNION ALL
        SELECT 3, 'RC_MCR_OWN_UPB', a.IntAmt, a.FilAmt,
               N'Ownership grid UPB. Independent '
             + N'corroboration through the servicing type '
             + N'dimension.'
        FROM #Agg a WHERE a.GridCode = 'OWN'
        UNION ALL
        SELECT 4, 'RC_MCR_OWN_CNT', a.IntCnt, a.FilCnt,
               N'Ownership grid loan count.'
        FROM #Agg a WHERE a.GridCode = 'OWN'
        UNION ALL
        SELECT 5, 'RC_MCR_GRID_UPB',
               o.FilAmt, d.FilAmt,
               N'Filed ownership total vs filed '
             + N'delinquency total. Both partition one '
             + N'population; disagreement is a defect in '
             + N'the submission itself.'
        FROM #Agg o CROSS JOIN #Agg d
        WHERE o.GridCode = 'OWN' AND d.GridCode = 'DELINQ'
        UNION ALL
        SELECT 6, 'RC_MCR_GRID_CNT',
               o.FilCnt, d.FilCnt,
               N'Filed ownership count vs filed '
             + N'delinquency count.'
        FROM #Agg o CROSS JOIN #Agg d
        WHERE o.GridCode = 'OWN' AND d.GridCode = 'DELINQ'
        UNION ALL
        SELECT 7, 'RC_MCR_FC_UPB', a.IntAmt, a.FilAmt,
               N'Foreclosure by investor grid UPB.'
        FROM #Agg a WHERE a.GridCode = 'FC'
        UNION ALL
        SELECT 8, 'RC_MCR_FC_CNT', a.IntCnt, a.FilCnt,
               N'Foreclosure by investor grid loan count. '
             + N'This detail is what NMLS sums to derive '
             + N'LS1390.'
        FROM #Agg a WHERE a.GridCode = 'FC'
        UNION ALL
        SELECT 9, 'RC_MCR_ELEM_PRESENT', @IntElem, @FilElem,
               N'Governed detail elements vs elements '
             + N'actually present in the filing. A summed '
             + N'total cannot detect an absent zero line.'
        UNION ALL
        SELECT 10, 'RC_MCR_STG_COMPLETE', @DwActive, @Staged,
               N'Active warehouse loans at period end vs '
             + N'rows reaching the staging contract. '
             + N'Population loss upstream of any filed '
             + N'value.';

        DECLARE ctl_cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT ControlCode, SourceValue, TargetValue,
                   Details
            FROM #Result
            ORDER BY SeqNo;

        OPEN ctl_cur;
        FETCH NEXT FROM ctl_cur
            INTO @ControlCode, @Src, @Tgt, @Det;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC audit.usp_RecordReconciliationResult
                @ControlCode = @ControlCode,
                @AsOfDate = @PeriodEnd,
                @SourceValue = @Src,
                @TargetValue = @Tgt,
                @LoadBatchId = @LoadBatchId,
                @Details = @Det;

            FETCH NEXT FROM ctl_cur
                INTO @ControlCode, @Src, @Tgt, @Det;
        END

        CLOSE ctl_cur;
        DEALLOCATE ctl_cur;

        SELECT @Executed = COUNT(*) FROM #Result;

        DROP TABLE #Agg;
        DROP TABLE #Result;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecId,
            @StatusCode = 'SUCCESS',
            @RowsInserted = @Executed;

        IF @OwnBatch = 1
            EXEC audit.usp_CompleteLoadBatch
                @LoadBatchId = @LoadBatchId,
                @StatusCode = 'SUCCESS';

    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'ctl_cur') >= 0
        BEGIN
            CLOSE ctl_cur;
            DEALLOCATE ctl_cur;
        END

        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecId,
            @ContextInfo = N'reg.usp_RunMcrReconciliation';

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecId,
            @StatusCode = 'FAILED';

        IF @OwnBatch = 1
            EXEC audit.usp_CompleteLoadBatch
                @LoadBatchId = @LoadBatchId,
                @StatusCode = 'FAILED';
        THROW;
    END CATCH
END;
GO

/* ------------------------------------------------------------
   3. Execute at the filing period end.
   ------------------------------------------------------------ */
DECLARE @FilingId  INT  = 2026002;
DECLARE @PeriodEnd DATE = '2026-06-30';
DECLARE @BatchId   INT;

EXEC reg.usp_RunMcrReconciliation
    @FilingId = @FilingId,
    @PeriodEnd = @PeriodEnd,
    @LoadBatchId = @BatchId OUTPUT;
GO

/* ------------------------------------------------------------
   4. Verification
   ------------------------------------------------------------ */

/* 4a. The control set. */
SELECT ControlCode, ControlName, BlockingFlag,
       SourceValue, TargetValue, VarianceValue, StatusCode
FROM audit.vw_ReconciliationLatest
WHERE AsOfDate = '2026-06-30'
  AND ControlTypeCode = 'MCR_TIEOUT'
ORDER BY ControlCode;

/* 4b. DRV_REGRECON at the filing period end. */
SELECT AsOfDate,
       ControlsExecuted = COUNT(*),
       Passed = SUM(CASE WHEN StatusCode = 'PASS'
                         THEN 1 ELSE 0 END),
       Failed = SUM(CASE WHEN StatusCode = 'FAIL'
                         THEN 1 ELSE 0 END),
       RegReconAccuracyPct =
           CAST(100.0 * SUM(CASE WHEN StatusCode = 'PASS'
                                 THEN 1 ELSE 0 END)
                / COUNT(*) AS DECIMAL(9,2))
FROM audit.vw_ReconciliationLatest
WHERE ControlTypeCode = 'MCR_TIEOUT'
  AND AsOfDate = '2026-06-30'
GROUP BY AsOfDate;

/* 4c. The servicing certification must be untouched. */
SELECT ReportCode, CertificationStatusCode,
       CertifiedDateUtc, DataAsOfDate, EvidenceRowCount
FROM gov.vw_ReportCertificationStatus
WHERE ReportCode = 'PBI_SVC_GOV';

SELECT AsOfDate, ControlTypeCode,
       Controls = COUNT(*)
FROM audit.vw_ReconciliationLatest
GROUP BY AsOfDate, ControlTypeCode
ORDER BY AsOfDate, ControlTypeCode;

/* 4d. Every failure attributed to a named cause. */
SELECT r.ControlCode, r.StatusCode, r.VarianceValue,
       AttributedCause =
           CASE r.ControlCode
             WHEN 'RC_MCR_ELEM_PRESENT'
               THEN 'LS1330 filed sparsely: zero '
                  + 'population emitted no element'
             WHEN 'RC_MCR_STG_COMPLETE'
               THEN 'DataIssue 5: property state absent '
                  + 'from ref.State'
             ELSE 'DataIssue 5 propagated to filed values'
           END,
       i.IssueTitle, p.PartyName AS IssueOwner
FROM audit.vw_ReconciliationLatest r
LEFT JOIN gov.DataIssue i
  ON i.DataIssueId = 5
LEFT JOIN gov.Party p ON p.PartyId = i.OwnerPartyId
WHERE r.AsOfDate = '2026-06-30'
  AND r.ControlTypeCode = 'MCR_TIEOUT'
  AND r.StatusCode = 'FAIL'
ORDER BY r.ControlCode;
GO