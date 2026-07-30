/* ------------------------------------------------------------
   037 section 3 (corrected). Sections 1 and 2 already
   deployed. Idempotent, safe to run as-is.
   ------------------------------------------------------------ */
SET NOCOUNT ON;
GO

DECLARE @FilingId    INT  = 2026002;
DECLARE @PeriodEnd   DATE = '2026-06-30';
DECLARE @LoadBatchId INT;
DECLARE @LoadExecId  INT;
DECLARE @Rows        INT;
DECLARE @Detail      NVARCHAR(2000);
DECLARE @MarcoId     INT;
DECLARE @NoahId      INT;
DECLARE @ExcludedCnt INT;
DECLARE @ExcludedUpb DECIMAL(18,2);
DECLARE @IssueTitle  NVARCHAR(300);
DECLARE @IssueDesc   NVARCHAR(2000);
DECLARE @BatchName   NVARCHAR(200);
DECLARE @StepName    NVARCHAR(200);
DECLARE @TargetObj   NVARCHAR(200);
DECLARE @BatchNotes  NVARCHAR(1000);

SET @BatchNotes =
    N'Script 037: LS1300-LS1340 engine extension, '
  + N'delinquency metadata correction, filing '
  + N'completeness defect registration.';

SET @BatchName =
    N'MCR Q2 2026 foreclosure detail and governance '
  + N'findings';

SELECT @MarcoId = PartyId FROM gov.Party
WHERE PartyName = 'Marco Ibis' AND PartyTypeCode = 'PERSON';

SELECT @NoahId = PartyId FROM gov.Party
WHERE PartyName = 'Noah Curlew'
  AND PartyTypeCode = 'PERSON';

SELECT @ExcludedCnt = COUNT(*),
       @ExcludedUpb = SUM(s.CurrentUpbAmount)
FROM dw.FactLoanMonthEndSnapshot s
LEFT JOIN dw.DimProperty p
  ON p.LoanNumber = s.LoanNumber
LEFT JOIN ref.State rs
  ON rs.StateCode = p.PropertyStateCode
WHERE s.AsOfDate = @PeriodEnd
  AND s.ActiveServicingFlag = 1
  AND rs.StateCode IS NULL;

EXEC audit.usp_StartLoadBatch
    @BatchName = @BatchName,
    @BatchTypeCode = 'FULL',
    @Notes = @BatchNotes,
    @LoadBatchId = @LoadBatchId OUTPUT;

BEGIN TRY

    /* ---- Part A: engine extension ---- */
    SET @StepName = N'Load LS1300-LS1340 foreclosure detail';
    SET @TargetObj = N'mcr.ReportValues';

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = @StepName,
        @TargetObject = @TargetObj,
        @LoadExecutionId = @LoadExecId OUTPUT;

    EXEC mcr.usp_LoadRmlaForeclosureByInvestor
        @FilingId = @FilingId;

    EXEC audit.usp_CompleteLoadExecution
        @LoadExecutionId = @LoadExecId,
        @StatusCode = 'SUCCESS';

    /* ---- Part B: metadata correction ---- */
    SET @StepName = N'Correct McrLineNote bucket shift';
    SET @TargetObj = N'dw.DimDelinquencyStatus';

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = @StepName,
        @TargetObject = @TargetObj,
        @LoadExecutionId = @LoadExecId OUTPUT;

    UPDATE d
       SET d.McrLineNote = v.CorrectNote,
           d.ModifiedDateUtc = SYSUTCDATETIME()
    FROM dw.DimDelinquencyStatus d
    JOIN (VALUES
        ('CURRENT',    'LS200 / S300'),
        ('DPD30_59',   'LS210 / S305'),
        ('DPD60_89',   'LS220 / S310'),
        ('DPD90_PLUS', 'LS230 / S315')
    ) v(BucketCode, CorrectNote)
      ON v.BucketCode = d.DelinquencyBucketCode
    WHERE ISNULL(d.McrLineNote, N'') <> v.CorrectNote;

    SET @Rows = @@ROWCOUNT;

    EXEC audit.usp_CompleteLoadExecution
        @LoadExecutionId = @LoadExecId,
        @StatusCode = 'SUCCESS',
        @RowsUpdated = @Rows;

    IF @Rows > 0
    BEGIN
        SET @Detail =
            N'Corrected McrLineNote on '
          + CAST(@Rows AS NVARCHAR(10))
          + N' dw.DimDelinquencyStatus rows. The prior '
          + N'note mapped each bucket one line toward '
          + N'severity (DPD30_59 to LS200, DPD60_89 to '
          + N'LS210, DPD90_PLUS to LS220-LS230). FV7 '
          + N'labels LS200 as Current Loans, confirmed by '
          + N'filing 2026002 which reports 10,762 current '
          + N'loans on LS200. No filed value changed; the '
          + N'engine never read this column.';

        INSERT INTO gov.ChangeLog
            (EntityTypeCode, EntityReference,
             ChangeTypeCode, ChangeDescription,
             LoadBatchId)
        VALUES
            ('DIMENSION_METADATA',
             N'dw.DimDelinquencyStatus.McrLineNote',
             'UPDATE', @Detail, @LoadBatchId);
    END

    SET @IssueTitle =
        N'DimDelinquencyStatus.McrLineNote mapped each '
      + N'bucket one MCR line toward severity';

    IF @Rows > 0
       AND NOT EXISTS (SELECT 1 FROM gov.DataIssue
                       WHERE IssueTitle = @IssueTitle)
    BEGIN
        SET @IssueDesc =
            N'Governance metadata on the delinquency '
          + N'dimension mapped CURRENT to LS090 basis and '
          + N'shifted every delinquent bucket one line. '
          + N'Detected by comparing the dimension note to '
          + N'filing 2026002, where the engine filed '
          + N'10,762 current loans into LS200. No filed '
          + N'regulatory value was affected because no '
          + N'process read the column. Risk was that a '
          + N'future mapping built from the dimension '
          + N'would have understated LS200 and overstated '
          + N'every delinquency line.';

        INSERT INTO gov.DataIssue
            (IssueTitle, IssueDescription, SeverityCode,
             StatusCode, ClosedDate, OwnerPartyId,
             ResolutionNotes, LoadBatchId)
        VALUES
            (@IssueTitle, @IssueDesc, 'MEDIUM', 'RESOLVED',
             CAST(GETDATE() AS DATE), @MarcoId,
             N'Corrected in this script against the FV7 '
           + N'catalog labels and the mcr_03 S-code '
           + N'mapping, both independent of the '
           + N'dimension. Change recorded in '
           + N'gov.ChangeLog.',
             @LoadBatchId);
    END

    /* ---- Part C: completeness defect, left OPEN ---- */
    SET @IssueTitle =
        N'MCR filing completeness: active loans excluded '
      + N'for unregistered property state';

    IF NOT EXISTS (SELECT 1 FROM gov.DataIssue
                   WHERE IssueTitle = @IssueTitle)
    BEGIN
        SET @IssueDesc =
            N'Staging filing 2026002 from the 2026-06-30 '
          + N'snapshot excluded '
          + CAST(@ExcludedCnt AS NVARCHAR(10))
          + N' active loans carrying '
          + CAST(CAST(ISNULL(@ExcludedUpb, 0)
                 AS DECIMAL(18,2)) AS NVARCHAR(30))
          + N' of UPB, because PropertyStateCode is not '
          + N'present in ref.State. LS200 through LS230 '
          + N'and LS010 through LS040 are COMPANY scope '
          + N'nationwide totals that do not require '
          + N'state, so these loans are reportable and '
          + N'were omitted by a staging constraint, not '
          + N'by a filing rule. DQR02 evaluates the same '
          + N'condition at a 99 percent pass threshold '
          + N'and does not fail on this volume, so no '
          + N'existing data quality control surfaces it.';

        INSERT INTO gov.DataIssue
            (IssueTitle, IssueDescription,
             DqRuleReference, SeverityCode, StatusCode,
             TargetResolutionDate, OwnerPartyId,
             LoadBatchId)
        VALUES
            (@IssueTitle, @IssueDesc, N'DQR02', 'HIGH',
             'NEW', DATEADD(DAY, 30,
                    CAST(GETDATE() AS DATE)),
             @MarcoId, @LoadBatchId);

        SET @Detail =
            N'Registered MCR filing completeness defect '
          + N'from the 037 staging review. Owner Marco '
          + N'Ibis. Remediate at source or accept with '
          + N'documented rationale; a reconciliation '
          + N'control enforcing staged rows equal active '
          + N'warehouse rows follows in script 039.';

        INSERT INTO gov.ChangeLog
            (EntityTypeCode, EntityReference,
             ChangeTypeCode, ChangeDescription,
             LoadBatchId)
        VALUES
            ('DATA_ISSUE', N'MCR_FILING_COMPLETENESS',
             'INSERT', @Detail, @LoadBatchId);
    END

    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'SUCCESS';

END TRY
BEGIN CATCH
    EXEC audit.usp_LogError
        @LoadBatchId = @LoadBatchId,
        @LoadExecutionId = @LoadExecId,
        @ContextInfo = N'037 MCR foreclosure detail';
    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'FAILED';
    THROW;
END CATCH
GO

/* ------------------------------------------------------------
   4. Verification
   ------------------------------------------------------------ */

/* 4a. LS1300-LS1340 as filed, and the cross-foot NMLS will
       perform to derive LS1390. */
SELECT fc.Label, e.ItemCode, rv.ElementName, e.DataType,
       rv.NumValue
FROM reg.vw_McrReportValues rv
JOIN reg.vw_McrFieldCatalogElement e
  ON e.ElementName = rv.ElementName
JOIN reg.vw_McrFieldCatalog fc
  ON fc.ItemCode = e.ItemCode
WHERE rv.FilingId = 2026002
  AND e.ItemCode IN ('LS1300','LS1310','LS1320',
                     'LS1330','LS1340')
ORDER BY fc.FormOrder, e.ColumnNo;

SELECT
    FiledForeclosureCount =
        SUM(CASE WHEN e.DataType = 'Count'
                 THEN rv.NumValue END),
    FiledForeclosureUpb =
        SUM(CASE WHEN e.DataType <> 'Count'
                 THEN rv.NumValue END),
    StagedForeclosureCount =
        (SELECT COUNT(*) FROM mcrstg.ServicingPortfolio
         WHERE FilingId = 2026002 AND InForeclosure = 1),
    StagedForeclosureUpb =
        (SELECT SUM(UPB) FROM mcrstg.ServicingPortfolio
         WHERE FilingId = 2026002 AND InForeclosure = 1)
FROM reg.vw_McrReportValues rv
JOIN reg.vw_McrFieldCatalogElement e
  ON e.ElementName = rv.ElementName
WHERE rv.FilingId = 2026002
  AND e.ItemCode IN ('LS1300','LS1310','LS1320',
                     'LS1330','LS1340');

/* 4b. Foreclosure loans routed to LS1340 only because the
       warehouse investor is UNKNOWN. */
SELECT UnknownInvestorForeclosureLoans = COUNT(*)
FROM dw.FactLoanMonthEndSnapshot s
JOIN dw.DimInvestor i ON i.InvestorKey = s.InvestorKey
JOIN dw.DimProperty p ON p.LoanNumber = s.LoanNumber
JOIN ref.State rs ON rs.StateCode = p.PropertyStateCode
WHERE s.AsOfDate = '2026-06-30'
  AND s.ActiveServicingFlag = 1
  AND i.InvestorCode = 'UNKNOWN'
  AND EXISTS (SELECT 1 FROM dw.FactForeclosureCase f
              WHERE f.LoanNumber = s.LoanNumber
                AND ISNULL(f.ReferralDate,'9999-12-31')
                    <= '2026-06-30'
                AND ISNULL(f.SaleHeldDate,'9999-12-31')
                    > '2026-06-30');

/* 4c. Corrected dimension metadata */
SELECT DelinquencyBucketCode, DelinquencyBucketName,
       McrLineNote, ModifiedDateUtc
FROM dw.DimDelinquencyStatus
ORDER BY SortOrder;

/* 4d. A blocking rule reporting PASS over the same
       condition that removed 36 loans from the filing. */
SELECT RuleCode, SeverityCode, BlockingFlag, StatusCode,
       EvaluatedRowCount, FailedRowCount, PassRatePct,
       ThresholdValue
FROM dq.vw_RuleResultLatest
WHERE RuleCode = 'DQR02';

/* 4e. Open governance issues after this script */
SELECT i.DataIssueId, i.IssueTitle, i.SeverityCode,
       i.StatusCode, i.OpenedDate, i.TargetResolutionDate,
       p.PartyName AS Owner
FROM gov.DataIssue i
LEFT JOIN gov.Party p ON p.PartyId = i.OwnerPartyId
WHERE i.StatusCode IN ('NEW','ACKNOWLEDGED',
                       'IN_REMEDIATION')
ORDER BY i.SeverityCode, i.DataIssueId;
GO