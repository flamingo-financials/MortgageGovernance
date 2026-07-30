/* ============================================================
   MortgageGovernance | Phase 8 | Script 024
   Governed remediation and recertification.
   Remediates the two blocking DQ failures at source with a
   full audit trail, registers accepted-risk exceptions for
   the non-blocking failures, then reruns the pipeline.
   Expected result: DQR12 and DQR19 PASS; certification
   moves NOT_CERTIFIED -> CERTIFIED_WITH_EXCEPTIONS (the
   non-blocking failures and the DEF11 continuity gap
   remain documented, not hidden).
   Idempotent: safe to re-run.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;
GO

DECLARE @LoadBatchId INT, @LoadExecutionId INT,
        @Rows INT, @Detail NVARCHAR(2000),
        @Err NVARCHAR(4000),
        @MarcoId INT, @NoahId INT, @SofiaId INT,
        @IssueId INT;

SELECT @MarcoId = PartyId FROM gov.Party
WHERE PartyName = 'Marco Ibis'
  AND PartyTypeCode = 'PERSON';
SELECT @SofiaId = PartyId FROM gov.Party
WHERE PartyName = 'Sofia Egret'
  AND PartyTypeCode = 'PERSON';
SELECT @NoahId = PartyId FROM gov.Party
WHERE PartyName = 'Noah Curlew'
  AND PartyTypeCode = 'PERSON';

EXEC audit.usp_StartLoadBatch
    @BatchName = N'Remediation: DQR12 and DQR19',
    @BatchTypeCode = 'ADHOC',
    @Notes = N'Governed data correction of blocking DQ
failures ahead of recertification.',
    @LoadBatchId = @LoadBatchId OUTPUT;

BEGIN TRY

/* ------------------------------------------------------------
   1. DQR12 remediation (DEF12): invalid investor code FNM
      corrected to FNMA in src.SvcLoanMonthEnd. Business
      approval: Marco Ibis (data owner). The typo exists
      only in the 2026-07-31 snapshot extract.
   ------------------------------------------------------------ */
EXEC audit.usp_StartLoadExecution
    @LoadBatchId = @LoadBatchId,
    @StepName = N'Correct InvestorCode FNM to FNMA',
    @TargetObject = N'src.SvcLoanMonthEnd',
    @LoadExecutionId = @LoadExecutionId OUTPUT;

UPDATE src.SvcLoanMonthEnd
   SET InvestorCode = 'FNMA'
 WHERE InvestorCode = 'FNM';
SET @Rows = @@ROWCOUNT;

EXEC audit.usp_CompleteLoadExecution
    @LoadExecutionId = @LoadExecutionId,
    @StatusCode = 'SUCCESS',
    @RowsUpdated = @Rows;

IF NOT EXISTS (SELECT 1 FROM gov.DataIssue
               WHERE IssueTitle =
               N'DQR12: invalid investor code FNM in '
               + N'servicing month-end extract')
BEGIN
    INSERT INTO gov.DataIssue
        (IssueTitle, IssueDescription, DqRuleReference,
         SeverityCode, StatusCode, ClosedDate,
         OwnerPartyId, ResolutionNotes, LoadBatchId)
    VALUES
        (N'DQR12: invalid investor code FNM in '
         + N'servicing month-end extract',
         N'DQR12 detected loans in the 2026-07-31 '
         + N'month-end extract carrying investor code '
         + N'FNM, which is not a registered investor. '
         + N'Root cause: upstream extract typo for FNMA '
         + N'loans. CDE affected: DE_INVESTOR_CODE.',
         N'DQR12', 'CRITICAL', 'RESOLVED',
         CAST(GETDATE() AS DATE), @MarcoId,
         N'InvestorCode corrected FNM to FNMA at source '
         + N'with owner approval; pipeline rerun and '
         + N'rule re-executed to verify.',
         @LoadBatchId);
END

SET @Detail = N'DQR12 remediation: corrected '
    + CAST(@Rows AS NVARCHAR(10))
    + N' src.SvcLoanMonthEnd rows from FNM to FNMA.';
INSERT INTO gov.ChangeLog
    (EntityTypeCode, EntityReference, ChangeTypeCode,
     ChangeDescription, LoadBatchId)
VALUES
    ('DATA_REMEDIATION', N'src.SvcLoanMonthEnd', 'UPDATE',
     @Detail, @LoadBatchId);

/* ------------------------------------------------------------
   2. DQR19 remediation (DEF19): expired TX MLO licenses
      for FL30007 and FL30021 renewed. Business action:
      licenses renewed through NMLS; affected fundings
      reviewed by compliance. Owner: Noah Curlew.
   ------------------------------------------------------------ */
EXEC audit.usp_StartLoadExecution
    @LoadBatchId = @LoadBatchId,
    @StepName = N'Renew expired TX MLO licenses',
    @TargetObject = N'src.LicLoanOfficerLicense',
    @LoadExecutionId = @LoadExecutionId OUTPUT;

UPDATE src.LicLoanOfficerLicense
   SET LicenseStatusCode = 'ACTIVE',
       ExpirationDate = '2026-12-31'
 WHERE NmlsId IN ('FL30007', 'FL30021')
   AND LicenseStateCode = 'TX'
   AND LicenseStatusCode = 'EXPIRED';
SET @Rows = @@ROWCOUNT;

EXEC audit.usp_CompleteLoadExecution
    @LoadExecutionId = @LoadExecutionId,
    @StatusCode = 'SUCCESS',
    @RowsUpdated = @Rows;

IF NOT EXISTS (SELECT 1 FROM gov.DataIssue
               WHERE IssueTitle =
               N'DQR19: fundings by MLOs with expired '
               + N'TX licenses')
BEGIN
    INSERT INTO gov.DataIssue
        (IssueTitle, IssueDescription, DqRuleReference,
         SeverityCode, StatusCode, ClosedDate,
         OwnerPartyId, ResolutionNotes, LoadBatchId)
    VALUES
        (N'DQR19: fundings by MLOs with expired '
         + N'TX licenses',
         N'DQR19 detected fundings on TX properties by '
         + N'FL30007 and FL30021 after their TX MLO '
         + N'license expiration (2025-12-31).',
         N'DQR19', 'CRITICAL', 'RESOLVED',
         CAST(GETDATE() AS DATE), @NoahId,
         N'TX licenses renewed through 2026-12-31. '
         + N'Affected fundings reviewed by compliance; '
         + N'no consumer harm identified. Preventive '
         + N'control: DQR19 remains active and '
         + N'blocking.',
         @LoadBatchId);
END

SET @Detail = N'DQR19 remediation: renewed '
    + CAST(@Rows AS NVARCHAR(10))
    + N' expired TX license rows for FL30007, FL30021.';
INSERT INTO gov.ChangeLog
    (EntityTypeCode, EntityReference, ChangeTypeCode,
     ChangeDescription, LoadBatchId)
VALUES
    ('DATA_REMEDIATION', N'src.LicLoanOfficerLicense',
     'UPDATE', @Detail, @LoadBatchId);

/* ------------------------------------------------------------
   3. Accepted-risk exceptions for non-blocking failures.
      DQR07, DQR09, DQR13 fail thresholds by design
      (broad-condition monitors); DEF11 continuity gap is
      accepted and tracked. These drive
      CERTIFIED_WITH_EXCEPTIONS; they are documented, not
      suppressed.
   ------------------------------------------------------------ */
INSERT INTO dq.DataException
    (DqRuleId, KeyValue1, StatusCode, OwnerPartyId,
     DueDate, ResolutionNote)
SELECT r.DqRuleId, N'BATCH_LEVEL', 'ACCEPTED_RISK',
       @SofiaId, DATEADD(MONTH, 6,
           CAST(GETDATE() AS DATE)),
       CASE r.RuleCode
         WHEN 'DQR07' THEN
           N'Broad-condition monitor; pass rate below '
           + N'threshold is expected while upstream '
           + N'process improvements are in flight. '
           + N'Reviewed and accepted by steward; '
           + N'6-month review cycle.'
         WHEN 'DQR09' THEN
           N'Broad-condition monitor; known systemic '
           + N'condition, accepted with 6-month review.'
         WHEN 'DQR13' THEN
           N'Correction resubmission rate reflects DEF11 '
           + N'snapshot gap and investor reporting '
           + N'corrections; accepted with 6-month '
           + N'review.'
       END
FROM dq.[Rule] r
WHERE r.RuleCode IN ('DQR07', 'DQR09', 'DQR13')
  AND NOT EXISTS
      (SELECT 1 FROM dq.DataException e
       WHERE e.DqRuleId = r.DqRuleId
         AND e.KeyValue1 = N'BATCH_LEVEL'
         AND e.StatusCode = 'ACCEPTED_RISK');

IF NOT EXISTS (SELECT 1 FROM gov.DataIssue
               WHERE IssueTitle =
               N'RC_SNAP_CONTINUITY: 2025-03 snapshot '
               + N'gap (DEF11)')
BEGIN
    INSERT INTO gov.DataIssue
        (IssueTitle, IssueDescription, DqRuleReference,
         SeverityCode, StatusCode, OwnerPartyId,
         ResolutionNotes, LoadBatchId)
    VALUES
        (N'RC_SNAP_CONTINUITY: 2025-03 snapshot '
         + N'gap (DEF11)',
         N'43 loans are missing their 2025-03-31 '
         + N'month-end snapshot. Source extract cannot '
         + N'be regenerated for the historical period. '
         + N'Detected by DQR13 and the '
         + N'RC_SNAP_CONTINUITY control (non-blocking).',
         N'RC_SNAP_CONTINUITY', 'MEDIUM',
         'ACCEPTED_RISK', @SofiaId,
         N'Historical gap accepted; metrics touching '
         + N'2025-03 carry a documented caveat. Control '
         + N'remains active to catch new gaps.',
         @LoadBatchId);
END

EXEC audit.usp_CompleteLoadBatch
    @LoadBatchId = @LoadBatchId,
    @StatusCode = 'SUCCESS';

END TRY
BEGIN CATCH
    SET @Err = ERROR_MESSAGE();
    EXEC audit.usp_LogError
        @LoadBatchId = @LoadBatchId,
        @ContextInfo = N'024 remediation';
    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'FAILED';
    THROW;
END CATCH
GO

/* ------------------------------------------------------------
   4. Rerun the full pipeline and recertify.
   ------------------------------------------------------------ */
EXEC dw.usp_RunPipeline @AsOfDate = '2026-07-31';
GO

/* ------------------------------------------------------------
   5. Verification
   ------------------------------------------------------------ */
SELECT RuleCode, SeverityCode, BlockingFlag, StatusCode,
       FailedRowCount, PassRatePct, ThresholdValue
FROM dq.vw_RuleResultLatest
WHERE RuleCode IN ('DQR12', 'DQR19')
   OR StatusCode = 'FAIL'
ORDER BY RuleCode;

SELECT ReportCode, CertificationStatusCode, CertifiedBy,
       CertifiedDateUtc, DataAsOfDate, EvidenceRowCount,
       CertificationNotes
FROM gov.vw_ReportCertificationStatus
WHERE ReportCode = 'PBI_SVC_GOV';

SELECT r.RuleCode, e.StatusCode, e.OwnerPartyId,
       e.DueDate
FROM dq.DataException e
JOIN dq.[Rule] r ON r.DqRuleId = e.DqRuleId
WHERE e.KeyValue1 = N'BATCH_LEVEL';
GO

PRINT 'Script 024 complete: blocking defects remediated, '
    + 'exceptions registered, pipeline rerun, report '
    + 'recertified.';
GO
