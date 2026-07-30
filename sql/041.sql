/* ============================================================
   MortgageGovernance | Integration Phase 2 | Script 041
   MCR filing certification gate.

   WHY A SECOND GATE
   gov.usp_CertifyReport certifies a Power BI report at a
   servicing as-of date from DQ results and the full recon
   set. A regulatory filing is a different object certified
   on different evidence at a different as-of: the filing
   period end, the MCR_TIEOUT control set, and the engine's
   own validation findings. Reusing the report gate would
   have required stamping filing evidence with the report's
   as-of date, which falsifies the evidence.

   Both gates write to gov.Certification. One certification
   register, two scopes, neither absolving the other.

   AS-OF DISCIPLINE
   The gate reads MCR_TIEOUT results at @PeriodEnd only.
   The two script 021 controls carrying the same type at
   2026-07-31 are deliberately out of scope; a filing is
   not certified by controls run against a different
   period.

   EXPECTED RESULT
   NOT_CERTIFIED. Six blocking control failures plus
   whatever the engine validator reports. The gate exists
   to stop this filing, and it does.

   Azure SQL Database. No USE. Idempotent.
   ============================================================ */
SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   1. Extend the certification domains.
   ------------------------------------------------------------ */
IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_Certification_EntityTypeCode'
             AND parent_object_id =
                 OBJECT_ID('gov.Certification')
             AND definition NOT LIKE
                 '%REGULATORY_FILING%')
BEGIN
    ALTER TABLE gov.Certification
        DROP CONSTRAINT CK_Certification_EntityTypeCode;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name =
                     'CK_Certification_EntityTypeCode'
                 AND parent_object_id =
                     OBJECT_ID('gov.Certification'))
BEGIN
    ALTER TABLE gov.Certification
        ADD CONSTRAINT CK_Certification_EntityTypeCode
        CHECK (EntityTypeCode IN ('REPORT','METRIC',
               'DATASET','SEMANTIC_MODEL',
               'REGULATORY_FILING'));
END;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name =
                 'CK_CertificationEvidence_EvidenceTypeCode'
             AND parent_object_id =
                 OBJECT_ID('gov.CertificationEvidence')
             AND definition NOT LIKE '%MCR_VALIDATION%')
BEGIN
    ALTER TABLE gov.CertificationEvidence
        DROP CONSTRAINT
        CK_CertificationEvidence_EvidenceTypeCode;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name =
                 'CK_CertificationEvidence_EvidenceTypeCode'
                 AND parent_object_id =
                     OBJECT_ID('gov.CertificationEvidence'))
BEGIN
    ALTER TABLE gov.CertificationEvidence
        ADD CONSTRAINT
        CK_CertificationEvidence_EvidenceTypeCode
        CHECK (EvidenceTypeCode IN ('DQ_RESULT',
               'RECON_RESULT','LOAD_EXECUTION',
               'SCREENSHOT','QUERY_RESULT','DOCUMENT',
               'MCR_VALIDATION'));
END;
GO

/* ------------------------------------------------------------
   2. reg.usp_CertifyMcrFiling
      Evidence must exist for the period end; missing
      evidence is NOT_CERTIFIED, never a silent pass.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE reg.usp_CertifyMcrFiling
    @FilingId  INT,
    @PeriodEnd DATE,
    @CertifiedByPartyName NVARCHAR(200) = N'Paige Justice'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CertId      INT;
    DECLARE @PartyId     INT;
    DECLARE @FilingRef   NVARCHAR(300);
    DECLARE @ReconCount  INT = 0;
    DECLARE @BlockFail   INT = 0;
    DECLARE @NonBlockF   INT = 0;
    DECLARE @ReconWarn   INT = 0;
    DECLARE @ValError    INT = 0;
    DECLARE @ValWarn     INT = 0;
    DECLARE @OpenIssues  INT = 0;
    DECLARE @Status      VARCHAR(30);
    DECLARE @Notes       NVARCHAR(1000);
    DECLARE @FailList    NVARCHAR(500);
    DECLARE @RunUtc      DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @ChangeDescr NVARCHAR(2000);
    DECLARE @NoFilingMsg NVARCHAR(400);

    IF NOT EXISTS (SELECT 1 FROM reg.vw_McrFiling
                   WHERE FilingId = @FilingId)
    BEGIN
        SET @NoFilingMsg =
            N'FilingId not found in the MCR filing '
          + N'register. Create the filing before '
          + N'certifying it.';
        THROW 50041, @NoFilingMsg, 1;
    END

    SET @FilingRef = N'MCR_FV7_'
                   + CAST(@FilingId AS NVARCHAR(12));

    SELECT @PartyId = PartyId
    FROM gov.Party
    WHERE PartyName = @CertifiedByPartyName
      AND PartyTypeCode = 'PERSON';

    /* ---- Reconciliation evidence at the period end ---- */
    SELECT
        @ReconCount = COUNT(*),
        @BlockFail  = SUM(CASE WHEN StatusCode = 'FAIL'
                               AND BlockingFlag = 1
                               THEN 1 ELSE 0 END),
        @NonBlockF  = SUM(CASE WHEN StatusCode = 'FAIL'
                               AND BlockingFlag = 0
                               THEN 1 ELSE 0 END),
        @ReconWarn  = SUM(CASE WHEN StatusCode = 'WARN'
                               THEN 1 ELSE 0 END)
    FROM audit.vw_ReconciliationLatest
    WHERE AsOfDate = @PeriodEnd
      AND ControlTypeCode = 'MCR_TIEOUT';

    SET @BlockFail = ISNULL(@BlockFail, 0);
    SET @NonBlockF = ISNULL(@NonBlockF, 0);
    SET @ReconWarn = ISNULL(@ReconWarn, 0);

    SELECT @FailList = STRING_AGG(ControlCode, ', ')
    FROM audit.vw_ReconciliationLatest
    WHERE AsOfDate = @PeriodEnd
      AND ControlTypeCode = 'MCR_TIEOUT'
      AND StatusCode = 'FAIL'
      AND BlockingFlag = 1;

    /* ---- Engine validation findings ---- */
    SELECT
        @ValError = SUM(CASE WHEN Severity = 'ERROR'
                             THEN 1 ELSE 0 END),
        @ValWarn  = SUM(CASE WHEN Severity = 'WARNING'
                             THEN 1 ELSE 0 END)
    FROM reg.vw_McrValidationResults
    WHERE FilingId = @FilingId;

    SET @ValError = ISNULL(@ValError, 0);
    SET @ValWarn  = ISNULL(@ValWarn, 0);

    /* ---- Open issues touching the filing ---- */
    SELECT @OpenIssues = COUNT(*)
    FROM gov.DataIssue
    WHERE StatusCode IN ('NEW','ACKNOWLEDGED',
                         'IN_REMEDIATION')
      AND SeverityCode IN ('CRITICAL','HIGH');

    /* ---- Decision ---- */
    IF @ReconCount = 0
    BEGIN
        SET @Status = 'NOT_CERTIFIED';
        SET @Notes =
            N'No MCR reconciliation evidence at period '
          + N'end ' + CONVERT(CHAR(10), @PeriodEnd, 23)
          + N'. Run reg.usp_RunMcrReconciliation before '
          + N'certifying.';
    END
    ELSE IF @BlockFail > 0
    BEGIN
        SET @Status = 'NOT_CERTIFIED';
        SET @Notes =
            N'Blocked by ' + CAST(@BlockFail
                             AS NVARCHAR(10))
          + N' failing blocking control(s): '
          + ISNULL(@FailList, N'')
          + N'. Engine validation errors: '
          + CAST(@ValError AS NVARCHAR(10))
          + N'. Open high or critical data issues: '
          + CAST(@OpenIssues AS NVARCHAR(10)) + N'.';
    END
    ELSE IF @ValError > 0
    BEGIN
        SET @Status = 'NOT_CERTIFIED';
        SET @Notes =
            N'All blocking controls passed but the engine '
          + N'validator reported '
          + CAST(@ValError AS NVARCHAR(10))
          + N' error-severity finding(s). A filing with '
          + N'ERROR findings must not be submitted.';
    END
    ELSE IF @NonBlockF + @ReconWarn + @ValWarn > 0
    BEGIN
        SET @Status = 'CERTIFIED_WITH_EXCEPTIONS';
        SET @Notes =
            N'Certified with exceptions. Non-blocking '
          + N'control failures: '
          + CAST(@NonBlockF AS NVARCHAR(10))
          + N'. Control warnings: '
          + CAST(@ReconWarn AS NVARCHAR(10))
          + N'. Validation warnings: '
          + CAST(@ValWarn AS NVARCHAR(10)) + N'.';
    END
    ELSE
    BEGIN
        SET @Status = 'CERTIFIED';
        SET @Notes =
            N'All MCR blocking controls passed and the '
          + N'engine validator reported no findings at '
          + N'period end '
          + CONVERT(CHAR(10), @PeriodEnd, 23) + N'.';
    END

    /* ---- Upsert ---- */
    SELECT @CertId = CertificationId
    FROM gov.Certification
    WHERE EntityTypeCode = 'REGULATORY_FILING'
      AND EntityReference = @FilingRef;

    IF @CertId IS NULL
    BEGIN
        INSERT INTO gov.Certification
            (EntityTypeCode, EntityId, EntityReference,
             CertificationStatusCode, CertifiedByPartyId,
             CertifiedDateUtc, DataAsOfDate,
             CertificationNotes)
        VALUES
            ('REGULATORY_FILING', @FilingId, @FilingRef,
             @Status,
             CASE WHEN @Status IN ('CERTIFIED',
                  'CERTIFIED_WITH_EXCEPTIONS')
                  THEN @PartyId END,
             CASE WHEN @Status IN ('CERTIFIED',
                  'CERTIFIED_WITH_EXCEPTIONS')
                  THEN @RunUtc END,
             @PeriodEnd, @Notes);
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
               DataAsOfDate = @PeriodEnd,
               CertificationNotes = @Notes,
               ModifiedDateUtc = @RunUtc
         WHERE CertificationId = @CertId;
    END

    /* ---- Evidence: controls in full, validation
            summarised so evidence stays proportionate ---- */
    INSERT INTO gov.CertificationEvidence
        (CertificationId, EvidenceTypeCode,
         EvidenceEntityId, EvidenceReference,
         EvidenceDateUtc)
    SELECT @CertId, 'RECON_RESULT',
           r.ReconciliationResultId,
           r.ControlCode + N' | ' + r.StatusCode
         + N' | blocking='
         + CAST(r.BlockingFlag AS NVARCHAR(1))
         + N' | variance='
         + CAST(r.VarianceValue AS NVARCHAR(30)),
           @RunUtc
    FROM audit.vw_ReconciliationLatest r
    WHERE r.AsOfDate = @PeriodEnd
      AND r.ControlTypeCode = 'MCR_TIEOUT';

    INSERT INTO gov.CertificationEvidence
        (CertificationId, EvidenceTypeCode,
         EvidenceEntityId, EvidenceReference,
         EvidenceDateUtc)
    SELECT @CertId, 'MCR_VALIDATION', NULL,
           v.Severity + N' | ' + v.RuleType + N' | '
         + CAST(COUNT(*) AS NVARCHAR(12)) + N' finding(s)',
           @RunUtc
    FROM reg.vw_McrValidationResults v
    WHERE v.FilingId = @FilingId
    GROUP BY v.Severity, v.RuleType;

    SET @ChangeDescr =
        N'MCR filing certification run for ' + @FilingRef
      + N' at period end '
      + CONVERT(CHAR(10), @PeriodEnd, 23)
      + N'. Result: ' + @Status + N'. ' + @Notes;

    INSERT INTO gov.ChangeLog
        (EntityTypeCode, EntityId, EntityReference,
         ChangeTypeCode, ChangeDescription)
    VALUES
        ('CERTIFICATION', @CertId, @FilingRef,
         'UPDATE', @ChangeDescr);

    SELECT @FilingRef  AS FilingReference,
           @PeriodEnd  AS PeriodEndDate,
           @Status     AS CertificationStatusCode,
           @ReconCount AS ControlsEvaluated,
           @BlockFail  AS BlockingControlFailures,
           @ValError   AS ValidationErrors,
           @ValWarn    AS ValidationWarnings,
           @OpenIssues AS OpenHighOrCriticalIssues,
           @Notes      AS CertificationNotes;
END;
GO

/* ------------------------------------------------------------
   3. reg.vw_McrFilingCertificationStatus
      One row per filing. The data product in 042 reads
      this, never gov.Certification directly.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW reg.vw_McrFilingCertificationStatus
AS
SELECT
    f.FilingId, f.CompanyName, f.FormVersion,
    f.[Year], f.PeriodType, f.PeriodStart, f.PeriodEnd,
    f.PrimaryStateCode,
    c.CertificationStatusCode,
    cb.PartyName AS CertifiedBy,
    c.CertifiedDateUtc, c.DataAsOfDate,
    c.CertificationNotes,
    EvidenceRowCount =
        (SELECT COUNT(*) FROM gov.CertificationEvidence e
         WHERE e.CertificationId = c.CertificationId),
    ControlsEvaluated =
        (SELECT COUNT(*)
         FROM audit.vw_ReconciliationLatest r
         WHERE r.AsOfDate = f.PeriodEnd
           AND r.ControlTypeCode = 'MCR_TIEOUT'),
    BlockingControlFailures =
        (SELECT COUNT(*)
         FROM audit.vw_ReconciliationLatest r
         WHERE r.AsOfDate = f.PeriodEnd
           AND r.ControlTypeCode = 'MCR_TIEOUT'
           AND r.StatusCode = 'FAIL'
           AND r.BlockingFlag = 1),
    ValidationErrors =
        (SELECT COUNT(*)
         FROM reg.vw_McrValidationResults v
         WHERE v.FilingId = f.FilingId
           AND v.Severity = 'ERROR'),
    ValidationWarnings =
        (SELECT COUNT(*)
         FROM reg.vw_McrValidationResults v
         WHERE v.FilingId = f.FilingId
           AND v.Severity = 'WARNING')
FROM reg.vw_McrFiling f
LEFT JOIN gov.Certification c
  ON c.EntityTypeCode = 'REGULATORY_FILING'
 AND c.EntityId = f.FilingId
LEFT JOIN gov.Party cb
  ON cb.PartyId = c.CertifiedByPartyId;
GO

/* ------------------------------------------------------------
   4. Validate the filing, then certify it.
   ------------------------------------------------------------ */
DECLARE @FilingId    INT  = 2026002;
DECLARE @PeriodEnd   DATE = '2026-06-30';
DECLARE @LoadBatchId INT;
DECLARE @LoadExecId  INT;
DECLARE @BatchName   NVARCHAR(200);
DECLARE @StepName    NVARCHAR(200);
DECLARE @TargetObj   NVARCHAR(200);
DECLARE @BatchNotes  NVARCHAR(1000);

SET @BatchName  = N'MCR filing validation and certification';
SET @BatchNotes =
    N'Script 041: run the FV7 engine validator against '
  + N'filing 2026002 and execute the filing certification '
  + N'gate at the period end.';

EXEC audit.usp_StartLoadBatch
    @BatchName = @BatchName,
    @BatchTypeCode = 'CERT',
    @Notes = @BatchNotes,
    @LoadBatchId = @LoadBatchId OUTPUT;

BEGIN TRY

    SET @StepName  = N'Validate FV7 filing';
    SET @TargetObj = N'mcr.ValidationResults';

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = @StepName,
        @TargetObject = @TargetObj,
        @LoadExecutionId = @LoadExecId OUTPUT;

    EXEC mcr.usp_ValidateFiling @FilingId = @FilingId;

    EXEC audit.usp_CompleteLoadExecution
        @LoadExecutionId = @LoadExecId,
        @StatusCode = 'SUCCESS';

    SET @StepName  = N'Certify MCR filing';
    SET @TargetObj = N'gov.Certification';

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = @StepName,
        @TargetObject = @TargetObj,
        @LoadExecutionId = @LoadExecId OUTPUT;

    EXEC reg.usp_CertifyMcrFiling
        @FilingId = @FilingId,
        @PeriodEnd = @PeriodEnd;

    EXEC audit.usp_CompleteLoadExecution
        @LoadExecutionId = @LoadExecId,
        @StatusCode = 'SUCCESS';

    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'SUCCESS';

END TRY
BEGIN CATCH
    EXEC audit.usp_LogError
        @LoadBatchId = @LoadBatchId,
        @LoadExecutionId = @LoadExecId,
        @ContextInfo = N'041 MCR filing certification';
    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'FAILED';
    THROW;
END CATCH
GO

/* ------------------------------------------------------------
   5. Verification
   ------------------------------------------------------------ */

/* 5a. Filing certification status. */
SELECT FilingId, PeriodType, PeriodEnd,
       CertificationStatusCode, CertifiedBy,
       ControlsEvaluated, BlockingControlFailures,
       ValidationErrors, ValidationWarnings,
       EvidenceRowCount
FROM reg.vw_McrFilingCertificationStatus
WHERE FilingId = 2026002;

/* 5b. Why it was blocked, in the validator's own terms. */
SELECT Severity, RuleType, Findings = COUNT(*)
FROM reg.vw_McrValidationResults
WHERE FilingId = 2026002
GROUP BY Severity, RuleType
ORDER BY Severity, RuleType;

/* 5c. Both certifications side by side. */
SELECT Scope = 'Power BI report',
       Reference = ReportCode,
       CertificationStatusCode,
       AsOfDate = DataAsOfDate,
       EvidenceRowCount
FROM gov.vw_ReportCertificationStatus
WHERE ReportCode = 'PBI_SVC_GOV'
UNION ALL
SELECT 'Regulatory filing',
       'MCR_FV7_' + CAST(FilingId AS VARCHAR(12)),
       CertificationStatusCode, PeriodEnd,
       EvidenceRowCount
FROM reg.vw_McrFilingCertificationStatus
WHERE FilingId = 2026002;

/* 5d. Evidence composition. */
SELECT e.EvidenceTypeCode, Rows_ = COUNT(*)
FROM gov.CertificationEvidence e
JOIN gov.Certification c
  ON c.CertificationId = e.CertificationId
WHERE c.EntityTypeCode = 'REGULATORY_FILING'
  AND c.EntityId = 2026002
GROUP BY e.EvidenceTypeCode;
GO