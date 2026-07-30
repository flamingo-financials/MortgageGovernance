/* ============================================================
   MortgageGovernance | Phase 6 | Script 021
   Reconciliation controls and report certification gate.
   Seeds 10 controls into audit.ReconciliationControl,
   creates the execution procs, a latest-result view, the
   gov.usp_CertifyReport gate for PBI_SVC_GOV, and a
   certification status view. Executes reconciliation and
   certification at 2026-07-31 at the end.
   Expected demo state: all blocking recons PASS, snapshot
   continuity WARN (DEF11, owned by DQR13), certification
   NOT_CERTIFIED because DQR12 (blocking, CRITICAL) fails.
   Idempotent: safe to re-run.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   1. Seed reconciliation control definitions.
      Source/Target expressions are documentation; execution
      is hard-coded in audit.usp_RunReconciliation (no
      dynamic SQL). Owner: Paige Justice (governance office
      owns recon controls).
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
SELECT v.Code, v.Name, v.Descr, v.Type, v.SrcExpr,
       v.TgtExpr, N'audit.usp_RunReconciliation', 'EXACT',
       v.Blocking, @OwnerId
FROM (VALUES
 ('RC_SRC_DW_SNAP_COUNT',
  N'Snapshot row count src to dw',
  N'Row count of src.SvcLoanMonthEnd must equal '
  + N'dw.FactLoanMonthEndSnapshot. Loaders never drop '
  + N'rows; any variance is a load defect.',
  'SRC_TO_DW',
  N'COUNT(*) FROM src.SvcLoanMonthEnd',
  N'COUNT(*) FROM dw.FactLoanMonthEndSnapshot', 1),
 ('RC_SRC_DW_SNAP_UPB',
  N'Snapshot UPB sum src to dw',
  N'SUM(CurrentUpbAmount) across all snapshot months, '
  + N'src vs dw, exact.',
  'SRC_TO_DW',
  N'SUM(CurrentUpbAmount) FROM src.SvcLoanMonthEnd',
  N'SUM(CurrentUpbAmount) FROM '
  + N'dw.FactLoanMonthEndSnapshot', 1),
 ('RC_SRC_DW_PAY_COUNT',
  N'Payment row count src to dw',
  N'Row count of src.PayPaymentTransaction must equal '
  + N'dw.FactPaymentTransaction. DEF06 orphans load to '
  + N'the UNKNOWN loan; they are flagged, not dropped.',
  'SRC_TO_DW',
  N'COUNT(*) FROM src.PayPaymentTransaction',
  N'COUNT(*) FROM dw.FactPaymentTransaction', 1),
 ('RC_SRC_DW_PAY_AMT',
  N'Payment amount sum src to dw',
  N'SUM(PaymentAmount) src vs dw, exact.',
  'SRC_TO_DW',
  N'SUM(PaymentAmount) FROM src.PayPaymentTransaction',
  N'SUM(PaymentAmount) FROM dw.FactPaymentTransaction', 1),
 ('RC_SRC_DW_LEAD_COUNT',
  N'Lead row count src to dw',
  N'Row count of src.CrmLead must equal dw.FactLead.',
  'SRC_TO_DW',
  N'COUNT(*) FROM src.CrmLead',
  N'COUNT(*) FROM dw.FactLead', 1),
 ('RC_SRC_DW_APP_COUNT',
  N'Application row count src to dw',
  N'Row count of src.LosApplication must equal '
  + N'dw.FactApplication.',
  'SRC_TO_DW',
  N'COUNT(*) FROM src.LosApplication',
  N'COUNT(*) FROM dw.FactApplication', 1),
 ('RC_SRC_DW_LOCK_COUNT',
  N'Rate lock row count src to dw',
  N'Row count of src.PpeRateLock must equal '
  + N'dw.FactRateLock.',
  'SRC_TO_DW',
  N'COUNT(*) FROM src.PpeRateLock',
  N'COUNT(*) FROM dw.FactRateLock', 1),
 ('RC_SNAP_CONTINUITY',
  N'Month-end snapshot continuity',
  N'Count of loan-months where a loan has snapshots in '
  + N'month M-1 and M+1 but not M. Expected 0. Known '
  + N'DEF11 gap (2025-03 slice) is detected by DQR13 and '
  + N'exception-managed; control is non-blocking so the '
  + N'defect surfaces without hiding it behind a '
  + N'tolerance.',
  'SNAPSHOT_CONTINUITY',
  N'0 (no gaps expected)',
  N'Gap instance count in dw.FactLoanMonthEndSnapshot', 0),
 ('RC_MCR_LS010_COUNT',
  N'MCR LS010 loan count tie-out',
  N'Wholly Owned active serviced loan count at as-of '
  + N'date. Independent src-side calculation '
  + N'(src.SvcLoanMonthEnd + ref.LoanStatus) vs dw-side '
  + N'(FactLoanMonthEndSnapshot + DimServicingType). '
  + N'Prototype for gov.RegulatoryReportItem LS010.',
  'MCR_TIEOUT',
  N'COUNT(*) src.SvcLoanMonthEnd WHOLLY_OWNED active '
  + N'at as-of',
  N'COUNT(*) dw.FactLoanMonthEndSnapshot WHOLLY_OWNED '
  + N'ActiveServicingFlag=1 at as-of', 1),
 ('RC_MCR_LS010_UPB',
  N'MCR LS010 UPB tie-out',
  N'Wholly Owned active serviced UPB at as-of date, '
  + N'independent src vs dw calculation. Prototype for '
  + N'gov.RegulatoryReportItem LS010.',
  'MCR_TIEOUT',
  N'SUM(CurrentUpbAmount) src WHOLLY_OWNED active',
  N'SUM(CurrentUpbAmount) dw WHOLLY_OWNED active', 1)
) v(Code, Name, Descr, Type, SrcExpr, TgtExpr, Blocking)
WHERE NOT EXISTS
      (SELECT 1 FROM audit.ReconciliationControl c
       WHERE c.ControlCode = v.Code);
GO

/* ------------------------------------------------------------
   2. audit.usp_RecordReconciliationResult
      Resolves the control, applies tolerance, records the
      result. Miss on a blocking control = FAIL; miss on a
      non-blocking control = WARN.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE audit.usp_RecordReconciliationResult
    @ControlCode VARCHAR(50),
    @AsOfDate    DATE,
    @SourceValue DECIMAL(18,2),
    @TargetValue DECIMAL(18,2),
    @LoadBatchId INT = NULL,
    @Details     NVARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ControlId INT, @TolType VARCHAR(20),
            @TolValue DECIMAL(18,4), @Blocking BIT,
            @Met BIT, @Status VARCHAR(20),
            @Var DECIMAL(18,2);

    SELECT @ControlId = ReconciliationControlId,
           @TolType   = ToleranceTypeCode,
           @TolValue  = ToleranceValue,
           @Blocking  = BlockingFlag
    FROM audit.ReconciliationControl
    WHERE ControlCode = @ControlCode
      AND ActiveFlag = 1;

    IF @ControlId IS NULL
        THROW 50021,
          'ControlCode not found or inactive.', 1;

    SET @Var = ISNULL(@TargetValue, 0)
             - ISNULL(@SourceValue, 0);

    SET @Met =
        CASE
          WHEN @TolType = 'EXACT'
               AND ISNULL(@SourceValue, 0)
                 = ISNULL(@TargetValue, 0) THEN 1
          WHEN @TolType = 'ABS_AMOUNT'
               AND ABS(@Var) <= ISNULL(@TolValue, 0) THEN 1
          WHEN @TolType = 'PCT'
               AND ISNULL(@SourceValue, 0) <> 0
               AND ABS(@Var / @SourceValue)
                   <= ISNULL(@TolValue, 0) THEN 1
          ELSE 0
        END;

    SET @Status =
        CASE WHEN @Met = 1 THEN 'PASS'
             WHEN @Blocking = 1 THEN 'FAIL'
             ELSE 'WARN' END;

    INSERT INTO audit.ReconciliationResult
        (ReconciliationControlId, LoadBatchId, AsOfDate,
         SourceValue, TargetValue, StatusCode, Details)
    VALUES
        (@ControlId, @LoadBatchId, @AsOfDate,
         @SourceValue, @TargetValue, @Status, @Details);
END
GO

/* ------------------------------------------------------------
   3. audit.usp_RunReconciliation
      Executes all 10 controls at @AsOfDate inside a RECON
      load batch. All calculations are static T-SQL.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE audit.usp_RunReconciliation
    @AsOfDate    DATE = '2026-07-31',
    @LoadBatchId INT  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @Src DECIMAL(18,2), @Tgt DECIMAL(18,2),
            @Err NVARCHAR(4000),
            @BatchName NVARCHAR(200),
            @Detail NVARCHAR(2000),
            @OwnBatch BIT = 0;

    IF @LoadBatchId IS NULL
    BEGIN
        SET @OwnBatch = 1;
        SET @BatchName = N'Reconciliation run '
            + CONVERT(CHAR(10), @AsOfDate, 23);
        EXEC audit.usp_StartLoadBatch
            @BatchName = @BatchName,
            @BatchTypeCode = 'RECON',
            @LoadBatchId = @LoadBatchId OUTPUT;
    END

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Run reconciliation controls',
        @TargetObject = N'audit.ReconciliationResult',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        /* ---- SRC_TO_DW: snapshots ---- */
        SELECT @Src = COUNT(*)
        FROM src.SvcLoanMonthEnd;
        SELECT @Tgt = COUNT(*)
        FROM dw.FactLoanMonthEndSnapshot;
        EXEC audit.usp_RecordReconciliationResult
            @ControlCode = 'RC_SRC_DW_SNAP_COUNT',
            @AsOfDate = @AsOfDate, @SourceValue = @Src,
            @TargetValue = @Tgt,
            @LoadBatchId = @LoadBatchId,
            @Details = N'All snapshot months, full table.';

        SELECT @Src = SUM(CurrentUpbAmount)
        FROM src.SvcLoanMonthEnd;
        SELECT @Tgt = SUM(CurrentUpbAmount)
        FROM dw.FactLoanMonthEndSnapshot;
        EXEC audit.usp_RecordReconciliationResult
            @ControlCode = 'RC_SRC_DW_SNAP_UPB',
            @AsOfDate = @AsOfDate, @SourceValue = @Src,
            @TargetValue = @Tgt,
            @LoadBatchId = @LoadBatchId,
            @Details = N'SUM(CurrentUpbAmount), all months.';

        /* ---- SRC_TO_DW: payments ---- */
        SELECT @Src = COUNT(*)
        FROM src.PayPaymentTransaction;
        SELECT @Tgt = COUNT(*)
        FROM dw.FactPaymentTransaction;
        SET @Detail = N'DEF06 orphans included both '
            + N'sides (flagged, not dropped).';
        EXEC audit.usp_RecordReconciliationResult
            @ControlCode = 'RC_SRC_DW_PAY_COUNT',
            @AsOfDate = @AsOfDate, @SourceValue = @Src,
            @TargetValue = @Tgt,
            @LoadBatchId = @LoadBatchId,
            @Details = @Detail;

        SELECT @Src = SUM(PaymentAmount)
        FROM src.PayPaymentTransaction;
        SELECT @Tgt = SUM(PaymentAmount)
        FROM dw.FactPaymentTransaction;
        EXEC audit.usp_RecordReconciliationResult
            @ControlCode = 'RC_SRC_DW_PAY_AMT',
            @AsOfDate = @AsOfDate, @SourceValue = @Src,
            @TargetValue = @Tgt,
            @LoadBatchId = @LoadBatchId,
            @Details = N'SUM(PaymentAmount), all rows.';

        /* ---- SRC_TO_DW: leads, apps, locks ---- */
        SELECT @Src = COUNT(*) FROM src.CrmLead;
        SELECT @Tgt = COUNT(*) FROM dw.FactLead;
        EXEC audit.usp_RecordReconciliationResult
            @ControlCode = 'RC_SRC_DW_LEAD_COUNT',
            @AsOfDate = @AsOfDate, @SourceValue = @Src,
            @TargetValue = @Tgt,
            @LoadBatchId = @LoadBatchId;

        SELECT @Src = COUNT(*) FROM src.LosApplication;
        SELECT @Tgt = COUNT(*) FROM dw.FactApplication;
        EXEC audit.usp_RecordReconciliationResult
            @ControlCode = 'RC_SRC_DW_APP_COUNT',
            @AsOfDate = @AsOfDate, @SourceValue = @Src,
            @TargetValue = @Tgt,
            @LoadBatchId = @LoadBatchId;

        SELECT @Src = COUNT(*) FROM src.PpeRateLock;
        SELECT @Tgt = COUNT(*) FROM dw.FactRateLock;
        EXEC audit.usp_RecordReconciliationResult
            @ControlCode = 'RC_SRC_DW_LOCK_COUNT',
            @AsOfDate = @AsOfDate, @SourceValue = @Src,
            @TargetValue = @Tgt,
            @LoadBatchId = @LoadBatchId;

        /* ---- Snapshot continuity: consecutive snapshots
                for a loan more than one month apart.
                Single pass via LEAD; the prior self-join
                had no supporting index and ran for
                minutes. Expected 0; DEF11 produces real
                gaps at 2025-03. ---- */
        SELECT @Tgt = COUNT(*)
        FROM (
            SELECT DATEDIFF(MONTH, AsOfDate,
                       LEAD(AsOfDate) OVER
                           (PARTITION BY LoanNumber
                            ORDER BY AsOfDate)) AS MonthGap
            FROM dw.FactLoanMonthEndSnapshot
        ) g
        WHERE g.MonthGap >= 2;
        SET @Src = 0;
        SET @Detail = N'Gap instances = loans with '
            + N'snapshots in M-1 and M+1 but not M. '
            + N'Known cause DEF11 (2025-03 slice), '
            + N'detected by DQR13, exception-managed.';
        EXEC audit.usp_RecordReconciliationResult
            @ControlCode = 'RC_SNAP_CONTINUITY',
            @AsOfDate = @AsOfDate, @SourceValue = @Src,
            @TargetValue = @Tgt,
            @LoadBatchId = @LoadBatchId,
            @Details = @Detail;

        /* ---- MCR LS010 tie-out: count ---- */
        SELECT @Src = COUNT(*)
        FROM src.SvcLoanMonthEnd e
        JOIN ref.LoanStatus ls
          ON ls.LoanStatusCode = e.LoanStatusCode
        WHERE e.AsOfDate = @AsOfDate
          AND ls.ActiveServicingFlag = 1
          AND e.ServicingTypeCode = 'WHOLLY_OWNED';
        SELECT @Tgt = COUNT(*)
        FROM dw.FactLoanMonthEndSnapshot f
        JOIN dw.DimServicingType dst
          ON dst.ServicingTypeKey = f.ServicingTypeKey
        WHERE f.AsOfDate = @AsOfDate
          AND f.ActiveServicingFlag = 1
          AND dst.ServicingTypeCode = 'WHOLLY_OWNED';
        SET @Detail = N'gov.RegulatoryReportItem LS010 '
            + N'(Wholly Owned Loans Serviced), loan '
            + N'count, independent src vs dw.';
        EXEC audit.usp_RecordReconciliationResult
            @ControlCode = 'RC_MCR_LS010_COUNT',
            @AsOfDate = @AsOfDate, @SourceValue = @Src,
            @TargetValue = @Tgt,
            @LoadBatchId = @LoadBatchId,
            @Details = @Detail;

        /* ---- MCR LS010 tie-out: UPB ---- */
        SELECT @Src = SUM(e.CurrentUpbAmount)
        FROM src.SvcLoanMonthEnd e
        JOIN ref.LoanStatus ls
          ON ls.LoanStatusCode = e.LoanStatusCode
        WHERE e.AsOfDate = @AsOfDate
          AND ls.ActiveServicingFlag = 1
          AND e.ServicingTypeCode = 'WHOLLY_OWNED';
        SELECT @Tgt = SUM(f.CurrentUpbAmount)
        FROM dw.FactLoanMonthEndSnapshot f
        JOIN dw.DimServicingType dst
          ON dst.ServicingTypeKey = f.ServicingTypeKey
        WHERE f.AsOfDate = @AsOfDate
          AND f.ActiveServicingFlag = 1
          AND dst.ServicingTypeCode = 'WHOLLY_OWNED';
        SET @Detail = N'gov.RegulatoryReportItem LS010 '
            + N'(Wholly Owned Loans Serviced), UPB, '
            + N'independent src vs dw.';
        EXEC audit.usp_RecordReconciliationResult
            @ControlCode = 'RC_MCR_LS010_UPB',
            @AsOfDate = @AsOfDate, @SourceValue = @Src,
            @TargetValue = @Tgt,
            @LoadBatchId = @LoadBatchId,
            @Details = @Detail;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsInserted = 10;

        IF @OwnBatch = 1
            EXEC audit.usp_CompleteLoadBatch
                @LoadBatchId = @LoadBatchId,
                @StatusCode = 'SUCCESS';
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo = N'audit.usp_RunReconciliation';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        IF @OwnBatch = 1
            EXEC audit.usp_CompleteLoadBatch
                @LoadBatchId = @LoadBatchId,
                @StatusCode = 'FAILED';
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   4. audit.vw_ReconciliationLatest
      Latest result per control per as-of date, with control
      metadata. Certification gate and PBI both read this.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW audit.vw_ReconciliationLatest
AS
WITH Ranked AS
(
    SELECT rr.*,
           ROW_NUMBER() OVER
               (PARTITION BY rr.ReconciliationControlId,
                             rr.AsOfDate
                ORDER BY rr.ReconciliationResultId DESC)
               AS rn
    FROM audit.ReconciliationResult rr
)
SELECT
    c.ControlCode, c.ControlName, c.ControlTypeCode,
    c.ToleranceTypeCode, c.BlockingFlag,
    r.AsOfDate, r.ExecutedDateUtc,
    r.SourceValue, r.TargetValue, r.VarianceValue,
    r.VariancePct, r.StatusCode, r.Details,
    p.PartyName AS ControlOwner,
    r.ReconciliationResultId
FROM Ranked r
JOIN audit.ReconciliationControl c
  ON c.ReconciliationControlId = r.ReconciliationControlId
LEFT JOIN gov.Party p ON p.PartyId = c.OwnerPartyId
WHERE r.rn = 1
  AND c.ActiveFlag = 1;
GO

/* ------------------------------------------------------------
   5. gov.usp_CertifyReport
      Certification gate. Decision:
        NOT_CERTIFIED when any blocking DQ rule fails, any
          blocking recon control fails, or either evidence
          set is missing for @AsOfDate;
        CERTIFIED_WITH_EXCEPTIONS when only non-blocking
          issues exist (WARN recons, non-blocking DQ FAILs);
        CERTIFIED otherwise.
      Appends evidence (append-only, grouped by run
      timestamp), updates gov.Certification in place, and
      writes gov.ChangeLog.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE gov.usp_CertifyReport
    @ReportCode VARCHAR(30) = 'PBI_SVC_GOV',
    @AsOfDate   DATE = '2026-07-31',
    @CertifiedByPartyName NVARCHAR(200) = N'Paige Justice'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ReportInvId INT, @CertId INT, @PartyId INT,
            @DqAsOf DATE,
            @BlockDq INT = 0, @BlockRecon INT = 0,
            @WarnRecon INT = 0, @NonBlockDq INT = 0,
            @ReconCount INT = 0,
            @Status VARCHAR(30),
            @Notes NVARCHAR(1000),
            @RunUtc DATETIME2(3) = SYSUTCDATETIME(),
            @ChangeDescr NVARCHAR(2000),
            @BlockList NVARCHAR(500);

    SELECT @ReportInvId = ReportInventoryId
    FROM gov.ReportInventory
    WHERE ReportCode = @ReportCode AND ActiveFlag = 1;

    IF @ReportInvId IS NULL
        THROW 50022,
          'ReportCode not found in gov.ReportInventory.', 1;

    SELECT @PartyId = PartyId
    FROM gov.Party
    WHERE PartyName = @CertifiedByPartyName
      AND PartyTypeCode = 'PERSON';

    /* ---- DQ evidence: latest batch must be for @AsOfDate */
    SELECT TOP 1 @DqAsOf = AsOfDate
    FROM dq.RuleExecutionBatch
    ORDER BY RuleExecutionBatchId DESC;

    IF @DqAsOf = @AsOfDate
    BEGIN
        SELECT @BlockDq = COUNT(*)
        FROM dq.vw_BlockingFailureLatest;
        SELECT @NonBlockDq = COUNT(*)
        FROM dq.vw_RuleResultLatest
        WHERE StatusCode = 'FAIL' AND BlockingFlag = 0;
        SELECT @BlockList = STRING_AGG(RuleCode, ', ')
        FROM dq.vw_BlockingFailureLatest;
    END

    /* ---- Recon evidence at @AsOfDate ---- */
    SELECT
        @ReconCount = COUNT(*),
        @BlockRecon = SUM(CASE WHEN StatusCode = 'FAIL'
                               THEN 1 ELSE 0 END),
        @WarnRecon  = SUM(CASE WHEN StatusCode = 'WARN'
                               THEN 1 ELSE 0 END)
    FROM audit.vw_ReconciliationLatest
    WHERE AsOfDate = @AsOfDate;

    SET @BlockRecon = ISNULL(@BlockRecon, 0);
    SET @WarnRecon  = ISNULL(@WarnRecon, 0);

    /* ---- Decision ---- */
    IF @DqAsOf IS NULL OR @DqAsOf <> @AsOfDate
    BEGIN
        SET @Status = 'NOT_CERTIFIED';
        SET @Notes = N'No DQ execution evidence for as-of '
            + CONVERT(CHAR(10), @AsOfDate, 23) + N'.';
    END
    ELSE IF @ReconCount = 0
    BEGIN
        SET @Status = 'NOT_CERTIFIED';
        SET @Notes = N'No reconciliation evidence for '
            + N'as-of '
            + CONVERT(CHAR(10), @AsOfDate, 23) + N'.';
    END
    ELSE IF @BlockDq > 0 OR @BlockRecon > 0
    BEGIN
        SET @Status = 'NOT_CERTIFIED';
        SET @Notes = N'Blocked. Blocking DQ failures: '
            + CAST(@BlockDq AS NVARCHAR(10))
            + CASE WHEN @BlockList IS NULL THEN N''
                   ELSE N' (' + @BlockList + N')' END
            + N'. Blocking recon failures: '
            + CAST(@BlockRecon AS NVARCHAR(10))
            + N'. Non-blocking issues: '
            + CAST(@WarnRecon + @NonBlockDq
                   AS NVARCHAR(10)) + N'.';
    END
    ELSE IF @WarnRecon + @NonBlockDq > 0
    BEGIN
        SET @Status = 'CERTIFIED_WITH_EXCEPTIONS';
        SET @Notes = N'Certified with exceptions. '
            + N'Non-blocking recon warns: '
            + CAST(@WarnRecon AS NVARCHAR(10))
            + N'. Non-blocking DQ failures: '
            + CAST(@NonBlockDq AS NVARCHAR(10)) + N'.';
    END
    ELSE
    BEGIN
        SET @Status = 'CERTIFIED';
        SET @Notes = N'All blocking DQ rules and '
            + N'reconciliation controls passed at as-of '
            + CONVERT(CHAR(10), @AsOfDate, 23) + N'.';
    END

    /* ---- Upsert gov.Certification ---- */
    SELECT @CertId = CertificationId
    FROM gov.Certification
    WHERE EntityTypeCode = 'REPORT'
      AND EntityReference = @ReportCode;

    IF @CertId IS NULL
    BEGIN
        INSERT INTO gov.Certification
            (EntityTypeCode, EntityId, EntityReference,
             CertificationStatusCode, CertifiedByPartyId,
             CertifiedDateUtc, DataAsOfDate,
             CertificationNotes)
        VALUES
            ('REPORT', @ReportInvId, @ReportCode, @Status,
             CASE WHEN @Status IN ('CERTIFIED',
                  'CERTIFIED_WITH_EXCEPTIONS')
                  THEN @PartyId END,
             CASE WHEN @Status IN ('CERTIFIED',
                  'CERTIFIED_WITH_EXCEPTIONS')
                  THEN @RunUtc END,
             @AsOfDate, @Notes);
        SET @CertId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE gov.Certification
           SET CertificationStatusCode = @Status,
               CertifiedByPartyId =
                   CASE WHEN @Status IN ('CERTIFIED',
                        'CERTIFIED_WITH_EXCEPTIONS')
                        THEN @PartyId END,
               CertifiedDateUtc =
                   CASE WHEN @Status IN ('CERTIFIED',
                        'CERTIFIED_WITH_EXCEPTIONS')
                        THEN @RunUtc END,
               DataAsOfDate = @AsOfDate,
               CertificationNotes = @Notes,
               ModifiedDateUtc = @RunUtc
         WHERE CertificationId = @CertId;
    END

    /* ---- Evidence: append-only, one run timestamp ---- */
    IF @DqAsOf = @AsOfDate
        INSERT INTO gov.CertificationEvidence
            (CertificationId, EvidenceTypeCode,
             EvidenceEntityId, EvidenceReference,
             EvidenceDateUtc)
        SELECT @CertId, 'DQ_RESULT', NULL,
               v.RuleCode + N' | ' + v.StatusCode
               + N' | blocking='
               + CAST(v.BlockingFlag AS NVARCHAR(1))
               + N' | failed='
               + CAST(v.FailedRowCount AS NVARCHAR(12)),
               @RunUtc
        FROM dq.vw_RuleResultLatest v;

    INSERT INTO gov.CertificationEvidence
        (CertificationId, EvidenceTypeCode,
         EvidenceEntityId, EvidenceReference,
         EvidenceDateUtc)
    SELECT @CertId, 'RECON_RESULT',
           r.ReconciliationResultId,
           r.ControlCode + N' | ' + r.StatusCode
           + N' | variance='
           + CAST(r.VarianceValue AS NVARCHAR(30)),
           @RunUtc
    FROM audit.vw_ReconciliationLatest r
    WHERE r.AsOfDate = @AsOfDate;

    /* ---- Change log ---- */
    SET @ChangeDescr = N'Certification run for '
        + @ReportCode + N' at as-of '
        + CONVERT(CHAR(10), @AsOfDate, 23)
        + N'. Result: ' + @Status + N'. ' + @Notes;
    INSERT INTO gov.ChangeLog
        (EntityTypeCode, EntityId, EntityReference,
         ChangeTypeCode, ChangeDescription)
    VALUES
        ('CERTIFICATION', @CertId, @ReportCode,
         'UPDATE', @ChangeDescr);

    SELECT @ReportCode AS ReportCode,
           @AsOfDate AS AsOfDate,
           @Status AS CertificationStatusCode,
           @BlockDq AS BlockingDqFailures,
           @BlockRecon AS BlockingReconFailures,
           @WarnRecon AS NonBlockingReconWarns,
           @NonBlockDq AS NonBlockingDqFailures,
           @Notes AS CertificationNotes;
END
GO

/* ------------------------------------------------------------
   6. gov.vw_ReportCertificationStatus
      One row per report for PBI certification page.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW gov.vw_ReportCertificationStatus
AS
SELECT
    ri.ReportCode, ri.ReportName, ri.ReportTypeCode,
    ri.SemanticModelName,
    own.PartyName AS ReportOwner,
    c.CertificationStatusCode,
    cb.PartyName AS CertifiedBy,
    c.CertifiedDateUtc, c.DataAsOfDate,
    c.CertificationNotes,
    (SELECT COUNT(*) FROM gov.CertificationEvidence e
     WHERE e.CertificationId = c.CertificationId)
        AS EvidenceRowCount
FROM gov.ReportInventory ri
LEFT JOIN gov.Certification c
  ON c.EntityTypeCode = 'REPORT'
 AND c.EntityReference = ri.ReportCode
LEFT JOIN gov.Party own ON own.PartyId = ri.OwnerPartyId
LEFT JOIN gov.Party cb
  ON cb.PartyId = c.CertifiedByPartyId
WHERE ri.ActiveFlag = 1;
GO

/* ------------------------------------------------------------
   7. Execute: reconciliation then certification at
      2026-07-31.
   ------------------------------------------------------------ */
DECLARE @ReconBatchId INT;
EXEC audit.usp_RunReconciliation
    @AsOfDate = '2026-07-31',
    @LoadBatchId = @ReconBatchId OUTPUT;

EXEC gov.usp_CertifyReport
    @ReportCode = 'PBI_SVC_GOV',
    @AsOfDate = '2026-07-31';
GO

/* ------------------------------------------------------------
   8. Verification output
   ------------------------------------------------------------ */
SELECT ControlCode, ControlTypeCode, BlockingFlag,
       SourceValue, TargetValue, VarianceValue, StatusCode
FROM audit.vw_ReconciliationLatest
WHERE AsOfDate = '2026-07-31'
ORDER BY ControlTypeCode, ControlCode;

SELECT ReportCode, CertificationStatusCode, CertifiedBy,
       CertifiedDateUtc, DataAsOfDate, EvidenceRowCount,
       CertificationNotes
FROM gov.vw_ReportCertificationStatus
WHERE ReportCode = 'PBI_SVC_GOV';
GO

PRINT 'Script 021 complete: 10 recon controls, 3 procs, '
    + '2 views, reconciliation and certification executed '
    + 'at 2026-07-31.';
GO
