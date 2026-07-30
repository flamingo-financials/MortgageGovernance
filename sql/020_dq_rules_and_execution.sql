/* ============================================================
   MortgageGovernance | Phase 10 | Script 020
   Data quality rules and execution engine.

   013 built the dq schema (Rule, RuleExecutionBatch,
   RuleResult, RuleFailureRow, DataException,
   SyntheticDefectRegister, SyntheticDefectTruth,
   RuleEffectiveness) and the 20-defect register, and 014
   populated dq.SyntheticDefectTruth with the injected keys.
   013 seeded NO rules and NO procedures. This script owns:
     1. the executable rule catalog (dq.Rule)
     2. dq.usp_ExecuteRules: runs every active rule at an
        as-of date, writing RuleResult and the failing keys
        to RuleFailureRow
     3. dq.usp_ScoreRuleEffectiveness: scores each detection
        rule against the known truth set, computing true
        positives, false positives, and false negatives so
        precision and recall are measured, not asserted
     4. reporting views

   DESIGN
   Every rule stores its logic as a SELECT that returns the
   failing business keys (KeyValue1, optional KeyValue2). The
   engine runs that SELECT, counts the population, counts the
   failures, and persists the failing keys. Because the rule
   returns keys rather than a bare count, effectiveness can be
   computed by intersecting detected keys with the truth set.
   This is the difference between claiming a rule works and
   proving it against a known answer.

   The 20 DQR rules pair one-to-one with the 20 seeded
   defects (DEF01-DEF20). Each rule's detection logic targets
   the defect mechanism independently; it does not read the
   truth table, or the score would be circular. Truth is used
   only after the fact, by the scorer.

   Rules run against src, the layer where defects were
   injected, so detection is measured at the point of entry.

   Idempotent: 020 owns dq.Rule and reloads it; procedures and
   views are CREATE OR ALTER.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

DECLARE @LoadBatchId INT;
DECLARE @BatchNotes NVARCHAR(400) =
    N'Script 020: DQ rule catalog, execution engine, and '
  + N'effectiveness scoring.';
EXEC audit.usp_StartLoadBatch
     @BatchName     = N'Phase 10 DQ rules seed',
     @BatchTypeCode = 'SEED',
     @Notes         = @BatchNotes,
     @LoadBatchId   = @LoadBatchId OUTPUT;

BEGIN TRY
BEGIN TRAN;

DECLARE @PaigeId INT =
    (SELECT PartyId FROM gov.Party
     WHERE PartyName = 'Paige Justice' AND PartyTypeCode = 'PERSON');
DECLARE @NoahId INT =
    (SELECT PartyId FROM gov.Party
     WHERE PartyName = 'Noah Curlew' AND PartyTypeCode = 'PERSON');

/* ------------------------------------------------------------
   1. Rule catalog. 020 owns dq.Rule; clear dependent result
      rows first to avoid orphan FKs, then reload.
   ------------------------------------------------------------ */
DELETE FROM dq.RuleEffectiveness;
DELETE FROM dq.RuleFailureRow;
DELETE FROM dq.RuleResult;
DELETE FROM dq.DataException;
DELETE FROM dq.[Rule];

/* Rule SQL contract: each RuleSql is a SELECT returning the
   failing rows with columns aliased KeyValue1 and, where a
   two-part key is needed, KeyValue2. A token {ASOF} is
   replaced by the execution as-of date at run time. The
   population (denominator) is defined per rule below in
   PopulationSql, aliased the same way, so pass rate is
   failures over evaluated population, not over the whole
   table. */

DECLARE @Rule TABLE
(
    RuleCode   VARCHAR(30)  NOT NULL PRIMARY KEY,
    RuleName   NVARCHAR(200) NOT NULL,
    Dim        VARCHAR(30)  NOT NULL,
    Severity   VARCHAR(10)  NOT NULL,
    Blocking   BIT          NOT NULL,
    TargetObj  NVARCHAR(200) NOT NULL,
    TargetCol  NVARCHAR(128) NULL,
    ElementCode VARCHAR(60) NULL,
    Threshold  DECIMAL(9,4) NOT NULL,
    DefectCode VARCHAR(20)  NULL,
    PopSql     NVARCHAR(MAX) NOT NULL,
    RuleSql    NVARCHAR(MAX) NOT NULL
);

/* ---- DQR01-DQR10: boarding, snapshot, payments, escrow ---- */
INSERT INTO @Rule
 (RuleCode, RuleName, Dim, Severity, Blocking, TargetObj,
  TargetCol, ElementCode, Threshold, DefectCode, PopSql, RuleSql)
VALUES
('DQR01','Note rate present on boarded loans',
 'COMPLETENESS','CRITICAL',1,'src.SvcLoanMaster',
 'NoteRatePercent','DE_NOTE_RATE',0.9900,'DEF01',
 N'SELECT LoanNumber AS KeyValue1 FROM src.SvcLoanMaster',
 N'SELECT LoanNumber AS KeyValue1 FROM src.SvcLoanMaster '
 + N'WHERE NoteRatePercent IS NULL'),
('DQR02','Property state code is a valid US state',
 'VALIDITY','HIGH',1,'src.SvcLoanMaster',
 'PropertyStateCode','DE_PROPERTY_STATE',0.9900,'DEF02',
 N'SELECT LoanNumber AS KeyValue1 FROM src.SvcLoanMaster',
 N'SELECT m.LoanNumber AS KeyValue1 FROM src.SvcLoanMaster m '
 + N'LEFT JOIN ref.State s ON s.StateCode = '
 + N'm.PropertyStateCode WHERE s.StateCode IS NULL'),
('DQR03','UPB not above original amount absent modification',
 'REASONABLENESS','MEDIUM',0,'src.SvcLoanMonthEnd',
 'CurrentUpbAmount','DE_CURRENT_UPB',0.9900,'DEF03',
 N'SELECT me.LoanNumber AS KeyValue1 '
 + N'FROM src.SvcLoanMonthEnd me WHERE me.AsOfDate = '
 + N'(SELECT MAX(AsOfDate) FROM src.SvcLoanMonthEnd)',
 N'SELECT me.LoanNumber AS KeyValue1 '
 + N'FROM src.SvcLoanMonthEnd me '
 + N'JOIN src.SvcLoanMaster lm ON lm.LoanNumber = me.LoanNumber '
 + N'WHERE me.AsOfDate = (SELECT MAX(AsOfDate) '
 + N'FROM src.SvcLoanMonthEnd) '
 + N'AND me.CurrentUpbAmount > lm.OriginalLoanAmount * 1.02 '
 + N'AND NOT EXISTS (SELECT 1 FROM src.SvcLoanModification mod '
 + N'WHERE mod.LoanNumber = me.LoanNumber '
 + N'AND mod.ModificationEffectiveDate <= me.AsOfDate)'),
('DQR04','Loan number unique across boarding tape',
 'UNIQUENESS','HIGH',1,'src.BrdBoardingTape',
 'LoanNumber','DE_LOAN_NUMBER',0.9900,'DEF04',
 N'SELECT LoanNumber AS KeyValue1 FROM src.BrdBoardingTape',
 N'SELECT LoanNumber AS KeyValue1 FROM src.BrdBoardingTape '
 + N'GROUP BY LoanNumber HAVING COUNT(*) > 1'),
('DQR05','Source bucket agrees with derived days past due',
 'CONSISTENCY','HIGH',1,'src.SvcLoanMonthEnd',
 'DelinquencyBucketCode','DE_SOURCE_BUCKET',0.9900,'DEF05',
 N'SELECT LoanNumber + ''|'' + CONVERT(VARCHAR(10),'
 + N'AsOfDate,120) AS KeyValue1 FROM src.SvcLoanMonthEnd '
 + N'WHERE NextPaymentDueDate IS NOT NULL',
 N'SELECT me.LoanNumber + ''|'' + '
 + N'CONVERT(VARCHAR(10),me.AsOfDate,120) AS KeyValue1 '
 + N'FROM src.SvcLoanMonthEnd me CROSS APPLY (SELECT '
 + N'DATEDIFF(DAY, me.NextPaymentDueDate, me.AsOfDate) AS Dpd) d '
 + N'CROSS APPLY (SELECT CASE WHEN d.Dpd < 30 THEN ''CURRENT'' '
 + N'WHEN d.Dpd < 60 THEN ''DPD30_59'' WHEN d.Dpd < 90 THEN '
 + N'''DPD60_89'' ELSE ''DPD90_PLUS'' END AS DerivedBucket) b '
 + N'WHERE me.NextPaymentDueDate IS NOT NULL '
 + N'AND me.DelinquencyBucketCode <> b.DerivedBucket'),
('DQR06','Payments reference an existing loan',
 'REFERENTIAL','CRITICAL',1,'src.PayPaymentTransaction',
 'LoanNumber','DE_LOAN_NUMBER',0.9900,'DEF06',
 N'SELECT CAST(PaymentTransactionId AS VARCHAR(20)) AS '
 + N'KeyValue1 FROM src.PayPaymentTransaction',
 N'SELECT p.LoanNumber AS '
 + N'KeyValue1 FROM src.PayPaymentTransaction p LEFT JOIN '
 + N'src.SvcLoanMaster m ON m.LoanNumber = p.LoanNumber '
 + N'WHERE m.LoanNumber IS NULL'),
('DQR07','Payment posted within one business day',
 'TIMELINESS','MEDIUM',0,'src.PayPaymentTransaction',
 'PostedDate','DE_PAY_POSTED_DATE',0.9500,'DEF07',
 N'SELECT CAST(PaymentTransactionId AS VARCHAR(20)) AS '
 + N'KeyValue1 FROM src.PayPaymentTransaction '
 + N'WHERE ReceivedDate IS NOT NULL AND PostedDate IS NOT NULL',
 N'SELECT CAST(PaymentTransactionId AS VARCHAR(20)) AS '
 + N'KeyValue1 FROM src.PayPaymentTransaction '
 + N'WHERE PostedDate IS NOT NULL AND ReceivedDate IS NOT NULL '
 + N'AND DATEDIFF(DAY, ReceivedDate, PostedDate) > 2'),
('DQR08','Payment posting corrected by a reversal chain',
 'ACCURACY','MEDIUM',0,'src.PayPaymentTransaction',
 'PrincipalAmount','DE_PAY_AMOUNT',0.9500,'DEF08',
 N'SELECT CAST(PaymentTransactionId AS VARCHAR(20)) AS '
 + N'KeyValue1 FROM src.PayPaymentTransaction '
 + N'WHERE OriginalTransactionId IS NULL',
 N'SELECT CAST(orig.PaymentTransactionId AS VARCHAR(20)) AS '
 + N'KeyValue1 FROM src.PayPaymentTransaction orig '
 + N'WHERE orig.OriginalTransactionId IS NULL '
 + N'AND EXISTS (SELECT 1 FROM src.PayPaymentTransaction corr '
 + N'WHERE corr.OriginalTransactionId = '
 + N'orig.PaymentTransactionId AND corr.ChannelCode = '
 + N'''CORR'')'),
('DQR09','Tax disbursed on or before the tax due date',
 'TIMELINESS','HIGH',0,'src.SvcEscrowDisbursement',
 'DisbursedDate','DE_TAX_DUE_DATE',0.9500,'DEF09',
 N'SELECT CAST(EscrowDisbursementId AS VARCHAR(20)) AS '
 + N'KeyValue1 FROM src.SvcEscrowDisbursement '
 + N'WHERE DisbursementTypeCode = ''TAX'' '
 + N'AND TaxDueDate IS NOT NULL',
 N'SELECT CAST(EscrowDisbursementId AS VARCHAR(20)) AS '
 + N'KeyValue1 FROM src.SvcEscrowDisbursement '
 + N'WHERE DisbursementTypeCode = ''TAX'' '
 + N'AND TaxDueDate IS NOT NULL AND DisbursedDate IS NOT NULL '
 + N'AND DisbursedDate > TaxDueDate'),
('DQR10','Boarding tape agrees with the servicing master',
 'ACCURACY','HIGH',1,'src.BrdBoardingTape',
 'TapeUpbAmount','DE_TAPE_UPB',0.9500,'DEF10',
 N'SELECT LoanNumber AS KeyValue1 FROM src.BrdBoardingTape',
 N'SELECT t.LoanNumber AS KeyValue1 FROM src.BrdBoardingTape t '
 + N'JOIN src.SvcLoanMaster m ON m.LoanNumber = t.LoanNumber '
 + N'WHERE ABS(m.BoardInterestRatePercent - '
 + N't.TapeInterestRatePercent) > 0.001 '
 + N'OR m.BoardNextPaymentDueDate <> t.TapeNextPaymentDueDate '
 + N'OR ABS(m.BoardEscrowBalanceAmount - '
 + N't.TapeEscrowBalanceAmount) > 0.01 '
 + N'OR ABS(m.BoardUpbAmount - t.TapeUpbAmount) > 0.01');

/* ---- DQR11-DQR20: snapshot completeness, investor,
        production, licensing ---- */
INSERT INTO @Rule
 (RuleCode, RuleName, Dim, Severity, Blocking, TargetObj,
  TargetCol, ElementCode, Threshold, DefectCode, PopSql, RuleSql)
VALUES
('DQR11','Active loans have no interior snapshot gap',
 'COMPLETENESS','HIGH',1,'src.SvcLoanMonthEnd',
 'AsOfDate','DE_ASOF_DATE',0.9900,'DEF11',
 N'SELECT DISTINCT LoanNumber AS KeyValue1 '
 + N'FROM src.SvcLoanMonthEnd',
 N'SELECT b.LoanNumber AS KeyValue1 FROM (SELECT LoanNumber, '
 + N'MIN(AsOfDate) AS MinD, MAX(AsOfDate) AS MaxD, '
 + N'COUNT(DISTINCT AsOfDate) AS MonthsPresent '
 + N'FROM src.SvcLoanMonthEnd GROUP BY LoanNumber) b '
 + N'WHERE DATEDIFF(MONTH, b.MinD, b.MaxD) + 1 '
 + N'> b.MonthsPresent'),
('DQR12','Investor code is a registered investor',
 'VALIDITY','CRITICAL',1,'src.SvcLoanMonthEnd',
 'InvestorCode','DE_INVESTOR_CODE',0.9900,'DEF12',
 N'SELECT me.LoanNumber AS KeyValue1 '
 + N'FROM src.SvcLoanMonthEnd me WHERE me.AsOfDate = '
 + N'(SELECT MAX(AsOfDate) FROM src.SvcLoanMonthEnd)',
 N'SELECT me.LoanNumber AS KeyValue1 '
 + N'FROM src.SvcLoanMonthEnd me LEFT JOIN ref.Investor i '
 + N'ON i.InvestorCode = me.InvestorCode '
 + N'WHERE me.AsOfDate = (SELECT MAX(AsOfDate) '
 + N'FROM src.SvcLoanMonthEnd) AND i.InvestorCode IS NULL'),
('DQR13','Investor reporting correction rate within tolerance',
 'ACCURACY','MEDIUM',0,'src.InvLoanReport',
 'CorrectionResubmissionFlag','DE_INV_CORRECTION_FLAG',
 0.9000,'DEF13',
 N'SELECT DISTINCT LoanNumber AS '
 + N'KeyValue1 FROM src.InvLoanReport',
 N'SELECT DISTINCT LoanNumber AS '
 + N'KeyValue1 FROM src.InvLoanReport '
 + N'WHERE CorrectionResubmissionFlag = 1'),
('DQR14','Application loan officer is on the licensed roster',
 'REFERENTIAL','HIGH',1,'src.LosApplication',
 'LoanOfficerNmlsId','DE_APP_LO_NMLS',0.9900,'DEF14',
 N'SELECT CAST(ApplicationId AS VARCHAR(20)) AS KeyValue1 '
 + N'FROM src.LosApplication WHERE LoanOfficerNmlsId IS NOT NULL',
 N'SELECT CAST(a.ApplicationId AS VARCHAR(20)) AS KeyValue1 '
 + N'FROM src.LosApplication a LEFT JOIN '
 + N'src.LicLoanOfficerRoster r ON r.NmlsId = a.LoanOfficerNmlsId '
 + N'WHERE a.LoanOfficerNmlsId IS NOT NULL AND r.NmlsId IS NULL'),
('DQR15','No duplicate leads for one contact on one day',
 'UNIQUENESS','LOW',0,'src.CrmLead',
 'ContactKey','DE_LEAD_CONTACT_KEY',0.9700,'DEF15',
 N'SELECT CAST(LeadId AS VARCHAR(20)) AS KeyValue1 '
 + N'FROM src.CrmLead WHERE ContactKey IS NOT NULL',
 N'SELECT DISTINCT l.ContactKey AS KeyValue1 '
 + N'FROM src.CrmLead l JOIN (SELECT ContactKey, '
 + N'CAST(LeadCreatedDate AS DATE) AS D FROM src.CrmLead '
 + N'WHERE ContactKey IS NOT NULL GROUP BY ContactKey, '
 + N'CAST(LeadCreatedDate AS DATE) HAVING COUNT(*) > 1) dup '
 + N'ON dup.ContactKey = l.ContactKey AND dup.D = '
 + N'CAST(l.LeadCreatedDate AS DATE)'),
('DQR16','Funding date on or after application received date',
 'VALIDITY','HIGH',1,'src.LosApplication',
 'FundingDate','DE_APP_FUNDING_DATE',0.9900,'DEF16',
 N'SELECT CAST(ApplicationId AS VARCHAR(20)) AS KeyValue1 '
 + N'FROM src.LosApplication WHERE FundingDate IS NOT NULL '
 + N'AND AppReceivedDate IS NOT NULL',
 N'SELECT CAST(ApplicationId AS VARCHAR(20)) AS KeyValue1 '
 + N'FROM src.LosApplication WHERE FundingDate IS NOT NULL '
 + N'AND AppReceivedDate IS NOT NULL '
 + N'AND FundingDate < AppReceivedDate'),
('DQR17','Terminal applications have a disposition code',
 'COMPLETENESS','HIGH',1,'src.LosApplication',
 'DispositionCode','DE_APP_DISPOSITION',0.9900,'DEF17',
 N'SELECT CAST(ApplicationId AS VARCHAR(20)) AS KeyValue1 '
 + N'FROM src.LosApplication WHERE DispositionDate IS NOT NULL',
 N'SELECT CAST(ApplicationId AS VARCHAR(20)) AS KeyValue1 '
 + N'FROM src.LosApplication WHERE DispositionDate IS NOT NULL '
 + N'AND DispositionCode IS NULL'),
('DQR18','Lock expiration on or after lock date',
 'VALIDITY','MEDIUM',0,'src.PpeRateLock',
 'CurrentExpirationDate','DE_LOCK_CURRENT_EXPIRATION',
 0.9900,'DEF18',
 N'SELECT CAST(RateLockId AS VARCHAR(20)) AS KeyValue1 '
 + N'FROM src.PpeRateLock WHERE CurrentExpirationDate '
 + N'IS NOT NULL AND LockDate IS NOT NULL',
 N'SELECT CAST(RateLockId AS VARCHAR(20)) AS KeyValue1 '
 + N'FROM src.PpeRateLock WHERE CurrentExpirationDate '
 + N'IS NOT NULL AND LockDate IS NOT NULL '
 + N'AND CurrentExpirationDate < LockDate'),
('DQR19','No funding by an originator with an expired license',
 'CONSISTENCY','CRITICAL',1,'src.LicLoanOfficerLicense',
 'LicenseStatusCode','DE_LIC_STATUS',0.9900,'DEF19',
 N'SELECT DISTINCT a.LoanOfficerNmlsId AS KeyValue1 '
 + N'FROM src.LosApplication a WHERE a.FundingDate IS NOT NULL '
 + N'AND a.LoanOfficerNmlsId IS NOT NULL',
 N'SELECT DISTINCT lic.NmlsId AS KeyValue1 '
 + N'FROM src.LosApplication a JOIN src.SvcLoanMaster m '
 + N'ON m.LoanNumber = a.LoanNumber JOIN src.LicLoanOfficerLicense '
 + N'lic ON lic.NmlsId = a.LoanOfficerNmlsId AND '
 + N'lic.LicenseStateCode = m.PropertyStateCode '
 + N'WHERE a.FundingDate IS NOT NULL AND '
 + N'lic.LicenseStatusCode = ''EXPIRED'' AND '
 + N'a.FundingDate > lic.ExpirationDate'),
('DQR20','Leads carry a source code',
 'COMPLETENESS','LOW',0,'src.CrmLead',
 'LeadSourceCode','DE_LEAD_SOURCE',0.9500,'DEF20',
 N'SELECT CAST(LeadId AS VARCHAR(20)) AS KeyValue1 '
 + N'FROM src.CrmLead',
 N'SELECT CAST(LeadId AS VARCHAR(20)) AS KeyValue1 '
 + N'FROM src.CrmLead WHERE LeadSourceCode IS NULL '
 + N'OR LeadSourceCode = ''''');

/* ---- Insert catalog ---- */
INSERT INTO dq.[Rule]
    (RuleCode, RuleName, DqDimensionCode, SeverityCode,
     BlockingFlag, TargetObjectName, TargetColumnName,
     DataElementCode, ThresholdTypeCode, ThresholdValue,
     RuleSql, ExpectedDefectCode, OwnerPartyId, StewardPartyId)
SELECT r.RuleCode, r.RuleName, r.Dim, r.Severity, r.Blocking,
       r.TargetObj, r.TargetCol, r.ElementCode, 'PCT_PASS_MIN',
       r.Threshold,
       N'/*POP*/' + r.PopSql + N'/*DETECT*/' + r.RuleSql,
       r.DefectCode, @PaigeId, @NoahId
FROM @Rule r;

/* ------------------------------------------------------------
   1b. Broad-condition registry. DQR07, DQR09, and DQR13
       detect a real business condition across the whole
       population (late postings, late tax disbursements,
       correction resubmissions). The seeded defect adds
       instances, but many occur naturally, so precision
       against a single defect code is not a meaningful
       measure for these rules. They are scored on recall
       (did they catch the seeded defect); precision is
       reported as not applicable. This registry marks them
       so the effectiveness view can make that distinction
       explicit rather than showing a misleadingly low
       precision. Owned by 020.
   ------------------------------------------------------------ */
IF OBJECT_ID('dq.BroadConditionRule') IS NULL
CREATE TABLE dq.BroadConditionRule
(
    RuleCode VARCHAR(30) NOT NULL
        CONSTRAINT PK_BroadConditionRule PRIMARY KEY (RuleCode),
    Rationale NVARCHAR(500) NOT NULL
);
DELETE FROM dq.BroadConditionRule;
INSERT INTO dq.BroadConditionRule (RuleCode, Rationale)
VALUES
('DQR07', N'Flags every payment posted beyond one business '
 + N'day. Many late postings occur naturally; the defect '
 + N'adds a slice. Scored on recall.'),
('DQR09', N'Flags every tax disbursement after its due date. '
 + N'Late disbursements occur naturally; the defect adds a '
 + N'slice. Scored on recall.'),
('DQR13', N'Flags every correction resubmission. Corrections '
 + N'occur naturally; the defect concentrates them. Scored '
 + N'on recall.');

/* ------------------------------------------------------------
   2. Change log for the seed, then commit the catalog before
      creating procedures (procedures are separate batches).
   ------------------------------------------------------------ */
IF NOT EXISTS
   (SELECT 1 FROM gov.ChangeLog
    WHERE EntityTypeCode = 'GOVERNANCE_PLATFORM'
      AND EntityReference = N'dq.Rule')
BEGIN
    INSERT INTO gov.ChangeLog
        (EntityTypeCode, EntityReference, ChangeTypeCode,
         ChangeDescription, LoadBatchId)
    VALUES
        ('GOVERNANCE_PLATFORM', N'dq.Rule', 'INSERT',
         N'Phase 10 DQ rule catalog: 20 detection rules '
         + N'(DQR01-DQR20) paired one-to-one with the seeded '
         + N'defect register, spanning all eight DQ '
         + N'dimensions. Each rule stores population and '
         + N'detection SQL returning failing business keys.',
         @LoadBatchId);
END

COMMIT;

EXEC audit.usp_CompleteLoadBatch
     @LoadBatchId = @LoadBatchId, @StatusCode = 'SUCCESS';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    EXEC audit.usp_LogError
         @LoadBatchId = @LoadBatchId,
         @ContextInfo = N'020_dq_rules_and_execution.sql';
    EXEC audit.usp_CompleteLoadBatch
         @LoadBatchId = @LoadBatchId, @StatusCode = 'FAILED';
    THROW;
END CATCH
GO

/* ============================================================
   3. dq.usp_ExecuteRules
   Runs every active rule at an as-of date. For each rule it
   splits the stored SQL into its population and detection
   halves, replaces the {ASOF} token, counts the evaluated
   population and the failing rows, writes one RuleResult, and
   persists the failing keys to RuleFailureRow. Status is FAIL
   when the pass rate is below the rule threshold.
   ============================================================ */
CREATE OR ALTER PROCEDURE dq.usp_ExecuteRules
    @AsOfDate DATE,
    @LoadBatchId INT = NULL,
    @RuleExecutionBatchId INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @AsOfText CHAR(10) = CONVERT(CHAR(10), @AsOfDate, 23);

    INSERT INTO dq.RuleExecutionBatch (LoadBatchId, AsOfDate)
    VALUES (@LoadBatchId, @AsOfDate);
    SET @RuleExecutionBatchId = SCOPE_IDENTITY();

    DECLARE @DqRuleId INT, @RuleSql NVARCHAR(MAX),
            @Threshold DECIMAL(9,4), @Split INT,
            @PopSql NVARCHAR(MAX), @DetectSql NVARCHAR(MAX),
            @EvalCount INT, @FailCount INT, @RuleResultId INT,
            @Status VARCHAR(10),
            @Exec1 NVARCHAR(MAX), @Exec2 NVARCHAR(MAX),
            @PopWrap NVARCHAR(MAX);

    DECLARE rule_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT DqRuleId, RuleSql, ThresholdValue
        FROM dq.[Rule] WHERE ActiveFlag = 1
        ORDER BY RuleCode;
    OPEN rule_cur;
    FETCH NEXT FROM rule_cur
        INTO @DqRuleId, @RuleSql, @Threshold;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        /* Split the stored SQL into population and detection */
        SET @PopSql = SUBSTRING(@RuleSql,
            CHARINDEX('/*POP*/', @RuleSql) + 7,
            CHARINDEX('/*DETECT*/', @RuleSql)
            - CHARINDEX('/*POP*/', @RuleSql) - 7);
        SET @DetectSql = SUBSTRING(@RuleSql,
            CHARINDEX('/*DETECT*/', @RuleSql) + 10, 2000000);
        SET @PopSql = REPLACE(@PopSql, '{ASOF}', @AsOfText);
        SET @DetectSql = REPLACE(@DetectSql, '{ASOF}', @AsOfText);

        /* Evaluated population count */
        SET @PopWrap =
            N'SELECT @c = COUNT(*) FROM (' + @PopSql + N') p';
        SET @EvalCount = 0;
        EXEC sp_executesql @PopWrap,
            N'@c INT OUTPUT', @c = @EvalCount OUTPUT;

        /* Capture failing keys. Detection SQL may return one
           or two key columns; try the two-column insert and
           fall back to one column if the rule omits KeyValue2.
           sp_executesql requires a variable, not an
           expression, so build the statement first. */
        IF OBJECT_ID('tempdb..#fail') IS NOT NULL
            DROP TABLE #fail;
        CREATE TABLE #fail
            (KeyValue1 NVARCHAR(100), KeyValue2 NVARCHAR(100));

        SET @Exec2 =
            N'INSERT INTO #fail (KeyValue1, KeyValue2) '
          + @DetectSql;
        SET @Exec1 =
            N'INSERT INTO #fail (KeyValue1) ' + @DetectSql;
        BEGIN TRY
            EXEC sp_executesql @Exec2;
        END TRY
        BEGIN CATCH
            EXEC sp_executesql @Exec1;
        END CATCH

        SET @FailCount = (SELECT COUNT(*) FROM #fail);
        SET @Status = CASE WHEN @EvalCount = 0 THEN 'PASS'
            WHEN (1.0 - CAST(@FailCount AS DECIMAL(18,6))
                  / @EvalCount) >= @Threshold
            THEN 'PASS' ELSE 'FAIL' END;

        INSERT INTO dq.RuleResult
            (RuleExecutionBatchId, DqRuleId, EvaluatedRowCount,
             FailedRowCount, StatusCode)
        VALUES (@RuleExecutionBatchId, @DqRuleId, @EvalCount,
             @FailCount, @Status);
        SET @RuleResultId = SCOPE_IDENTITY();

        INSERT INTO dq.RuleFailureRow
            (RuleResultId, KeyValue1, KeyValue2, FailureDetail)
        SELECT @RuleResultId, KeyValue1, KeyValue2, NULL
        FROM #fail;

        DROP TABLE #fail;
        FETCH NEXT FROM rule_cur
            INTO @DqRuleId, @RuleSql, @Threshold;
    END
    CLOSE rule_cur;
    DEALLOCATE rule_cur;

    RETURN;
END
GO

/* ============================================================
   4. dq.usp_ScoreRuleEffectiveness
   Scores each detection rule against the injected truth set
   for its expected defect. Matching is on KeyValue1, the
   business key both the rule and the truth set express:
     true positive  detected key that is in truth
     false positive detected key that is NOT in truth
     false negative truth key the rule did NOT detect
   Precision and recall are computed columns on
   dq.RuleEffectiveness. A rule with no ExpectedDefectCode is
   skipped: there is no ground truth to score it against.

   Scoring reads truth only here, never inside detection, so
   the measurement is honest: the rules found these rows on
   their own logic and we are checking their work.
   ============================================================ */
CREATE OR ALTER PROCEDURE dq.usp_ScoreRuleEffectiveness
    @RuleExecutionBatchId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dq.RuleEffectiveness
    WHERE RuleExecutionBatchId = @RuleExecutionBatchId;

    /* One row per (rule, detected key). Distinct guards
       against a rule emitting same key twice. */
    ;WITH Detected AS (
        SELECT DISTINCT r.DqRuleId,
               r.ExpectedDefectCode AS DefectCode,
               fr.KeyValue1
        FROM dq.RuleResult rr
        JOIN dq.[Rule] r ON r.DqRuleId = rr.DqRuleId
        JOIN dq.RuleFailureRow fr
          ON fr.RuleResultId = rr.RuleResultId
        WHERE rr.RuleExecutionBatchId = @RuleExecutionBatchId
          AND r.ExpectedDefectCode IS NOT NULL
    ),
    RuleList AS (
        SELECT DqRuleId, ExpectedDefectCode AS DefectCode
        FROM dq.[Rule]
        WHERE ExpectedDefectCode IS NOT NULL
    ),
    /* TP: detected keys that exist in truth for the defect.
       FP: detected keys not in truth. */
    DetScored AS (
        SELECT d.DqRuleId, d.DefectCode,
          SUM(CASE WHEN t.KeyValue1 IS NOT NULL
                   THEN 1 ELSE 0 END) AS TruePositive,
          SUM(CASE WHEN t.KeyValue1 IS NULL
                   THEN 1 ELSE 0 END) AS FalsePositive
        FROM Detected d
        LEFT JOIN dq.SyntheticDefectTruth t
          ON t.DefectCode = d.DefectCode
         AND t.KeyValue1 = d.KeyValue1
        GROUP BY d.DqRuleId, d.DefectCode
    ),
    /* FN: truth keys for the defect that the rule did not
       detect. */
    FnScored AS (
        SELECT rl.DqRuleId, rl.DefectCode,
          COUNT(*) AS FalseNegative
        FROM RuleList rl
        JOIN dq.SyntheticDefectTruth t
          ON t.DefectCode = rl.DefectCode
        WHERE NOT EXISTS (
            SELECT 1 FROM Detected d
            WHERE d.DqRuleId = rl.DqRuleId
              AND d.KeyValue1 = t.KeyValue1)
        GROUP BY rl.DqRuleId, rl.DefectCode
    )
    INSERT INTO dq.RuleEffectiveness
        (RuleExecutionBatchId, DqRuleId, DefectCode,
         TruePositive, FalsePositive, FalseNegative)
    SELECT @RuleExecutionBatchId, rl.DqRuleId, rl.DefectCode,
           ISNULL(ds.TruePositive, 0),
           ISNULL(ds.FalsePositive, 0),
           ISNULL(fn.FalseNegative, 0)
    FROM RuleList rl
    LEFT JOIN DetScored ds ON ds.DqRuleId = rl.DqRuleId
    LEFT JOIN FnScored fn ON fn.DqRuleId = rl.DqRuleId;

    RETURN;
END
GO

/* ============================================================
   5. Reporting views.
   ============================================================ */

/* ---- 5a. Latest execution result per rule, with severity,
        blocking flag, owner, steward, and the CDE it protects.
        Feeds the Power BI Data Quality page. ---- */
CREATE OR ALTER VIEW dq.vw_RuleResultLatest
AS
WITH LastBatch AS (
    SELECT TOP 1 RuleExecutionBatchId, AsOfDate
    FROM dq.RuleExecutionBatch
    ORDER BY RuleExecutionBatchId DESC
)
SELECT
    lb.AsOfDate,
    r.RuleCode, r.RuleName, r.DqDimensionCode,
    r.SeverityCode, r.BlockingFlag,
    r.TargetObjectName, r.DataElementCode,
    de.CdeFlag,
    rr.EvaluatedRowCount, rr.FailedRowCount, rr.PassRatePct,
    r.ThresholdValue, rr.StatusCode,
    own.PartyName AS RuleOwner, stw.PartyName AS RuleSteward
FROM LastBatch lb
JOIN dq.RuleResult rr
  ON rr.RuleExecutionBatchId = lb.RuleExecutionBatchId
JOIN dq.[Rule] r ON r.DqRuleId = rr.DqRuleId
LEFT JOIN gov.DataElement de
  ON de.DataElementCode = r.DataElementCode
LEFT JOIN gov.Party own ON own.PartyId = r.OwnerPartyId
LEFT JOIN gov.Party stw ON stw.PartyId = r.StewardPartyId;
GO

/* ---- 5b. Effectiveness for the latest batch: precision,
        recall, and the raw confusion counts per rule. This is
        the artifact that proves the DQ layer works. ---- */
CREATE OR ALTER VIEW dq.vw_RuleEffectivenessLatest
AS
WITH LastBatch AS (
    SELECT TOP 1 RuleExecutionBatchId
    FROM dq.RuleExecutionBatch
    ORDER BY RuleExecutionBatchId DESC
)
SELECT
    r.RuleCode, r.RuleName, r.DqDimensionCode, r.SeverityCode,
    e.DefectCode, sd.DefectName,
    e.TruePositive, e.FalsePositive, e.FalseNegative,
    CASE WHEN bc.RuleCode IS NOT NULL THEN 1 ELSE 0 END
        AS BroadConditionFlag,
    CASE WHEN bc.RuleCode IS NOT NULL THEN NULL
         ELSE e.PrecisionPct END AS PrecisionPct,
    e.RecallPct,
    CASE WHEN bc.RuleCode IS NOT NULL THEN NULL
         WHEN e.PrecisionPct IS NULL OR e.RecallPct IS NULL
         THEN NULL
         WHEN e.PrecisionPct + e.RecallPct = 0 THEN 0
         ELSE CAST(2.0 * e.PrecisionPct * e.RecallPct
              / (e.PrecisionPct + e.RecallPct)
              AS DECIMAL(9,6)) END AS F1Score,
    bc.Rationale AS BroadConditionRationale
FROM LastBatch lb
JOIN dq.RuleEffectiveness e
  ON e.RuleExecutionBatchId = lb.RuleExecutionBatchId
JOIN dq.[Rule] r ON r.DqRuleId = e.DqRuleId
LEFT JOIN dq.SyntheticDefectRegister sd
  ON sd.DefectCode = e.DefectCode
LEFT JOIN dq.BroadConditionRule bc
  ON bc.RuleCode = r.RuleCode;
GO

/* ---- 5c. Blocking failures for the latest batch: the rows a
        certification gate reads. Any CRITICAL or blocking rule
        in FAIL is a certification blocker. ---- */
CREATE OR ALTER VIEW dq.vw_BlockingFailureLatest
AS
SELECT
    v.AsOfDate, v.RuleCode, v.RuleName, v.SeverityCode,
    v.DataElementCode, v.FailedRowCount, v.PassRatePct,
    v.ThresholdValue
FROM dq.vw_RuleResultLatest v
WHERE v.StatusCode = 'FAIL' AND v.BlockingFlag = 1;
GO

PRINT 'Script 020 complete: 20 rules, execution engine, '
    + 'effectiveness scorer, and 3 views created.';
PRINT 'Rules are seeded but not yet executed. Run the '
    + 'pipeline in 023 (or call dq.usp_ExecuteRules and '
    + 'dq.usp_ScoreRuleEffectiveness) to populate results.';
GO
