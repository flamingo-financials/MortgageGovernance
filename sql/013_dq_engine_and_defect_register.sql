/* ============================================================
   MortgageGovernance | Phase 5a | Script 013
   Data quality engine DDL plus the synthetic defect register.
   The register is seeded BEFORE data generation on purpose:
   every defect is designed, documented, and deterministic, so
   rule precision and recall can be computed against known
   truth (dq.SyntheticDefectTruth is populated by script 014
   during generation). Rules themselves seed in script 020.
   Idempotent (guarded DDL; register delete-and-reload).
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

IF OBJECT_ID('dq.Rule') IS NULL
CREATE TABLE dq.[Rule]
(
    DqRuleId INT IDENTITY(1,1) NOT NULL,
    RuleCode VARCHAR(30) NOT NULL,
    RuleName NVARCHAR(200) NOT NULL,
    DqDimensionCode VARCHAR(30) NOT NULL,
    SeverityCode VARCHAR(10) NOT NULL,
    BlockingFlag BIT NOT NULL
        CONSTRAINT DF_Rule_BlockingFlag DEFAULT 0,
    TargetObjectName NVARCHAR(200) NOT NULL,
    TargetFilter NVARCHAR(1000) NULL,
    TargetColumnName NVARCHAR(128) NULL,
    DataElementCode VARCHAR(60) NULL,
    ThresholdTypeCode VARCHAR(20) NOT NULL
        CONSTRAINT DF_Rule_ThresholdTypeCode
        DEFAULT 'PCT_PASS_MIN',
    ThresholdValue DECIMAL(9,4) NOT NULL,
    RuleSql NVARCHAR(MAX) NOT NULL,
    ExpectedDefectCode VARCHAR(20) NULL,
    OwnerPartyId INT NULL,
    StewardPartyId INT NULL,
    ActiveFlag BIT NOT NULL
        CONSTRAINT DF_Rule_ActiveFlag DEFAULT 1,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_Rule_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Rule PRIMARY KEY CLUSTERED (DqRuleId),
    CONSTRAINT UQ_Rule_RuleCode UNIQUE (RuleCode),
    CONSTRAINT CK_Rule_DqDimensionCode CHECK
        (DqDimensionCode IN ('COMPLETENESS','VALIDITY',
         'ACCURACY','CONSISTENCY','UNIQUENESS','TIMELINESS',
         'REFERENTIAL','REASONABLENESS')),
    CONSTRAINT CK_Rule_SeverityCode CHECK
        (SeverityCode IN ('CRITICAL','HIGH','MEDIUM','LOW'))
);

IF OBJECT_ID('dq.RuleExecutionBatch') IS NULL
CREATE TABLE dq.RuleExecutionBatch
(
    RuleExecutionBatchId INT IDENTITY(1,1) NOT NULL,
    LoadBatchId INT NULL,
    AsOfDate DATE NOT NULL,
    ExecutedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_RuleExecutionBatch_ExecutedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_RuleExecutionBatch
        PRIMARY KEY CLUSTERED (RuleExecutionBatchId)
);

IF OBJECT_ID('dq.RuleResult') IS NULL
CREATE TABLE dq.RuleResult
(
    RuleResultId INT IDENTITY(1,1) NOT NULL,
    RuleExecutionBatchId INT NOT NULL,
    DqRuleId INT NOT NULL,
    EvaluatedRowCount INT NOT NULL,
    FailedRowCount INT NOT NULL,
    PassRatePct AS (CASE WHEN EvaluatedRowCount = 0 THEN NULL
        ELSE CAST(1.0 - CAST(FailedRowCount AS DECIMAL(18,6))
             / EvaluatedRowCount AS DECIMAL(9,6)) END),
    StatusCode VARCHAR(10) NOT NULL,
    ExecutedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_RuleResult_ExecutedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_RuleResult
        PRIMARY KEY CLUSTERED (RuleResultId),
    CONSTRAINT FK_RuleResult_RuleExecutionBatch
        FOREIGN KEY (RuleExecutionBatchId)
        REFERENCES dq.RuleExecutionBatch
        (RuleExecutionBatchId),
    CONSTRAINT FK_RuleResult_Rule FOREIGN KEY (DqRuleId)
        REFERENCES dq.[Rule] (DqRuleId),
    CONSTRAINT CK_RuleResult_StatusCode CHECK
        (StatusCode IN ('PASS','FAIL'))
);

IF OBJECT_ID('dq.RuleFailureRow') IS NULL
CREATE TABLE dq.RuleFailureRow
(
    RuleFailureRowId BIGINT IDENTITY(1,1) NOT NULL,
    RuleResultId INT NOT NULL,
    KeyValue1 NVARCHAR(100) NOT NULL,
    KeyValue2 NVARCHAR(100) NULL,
    FailureDetail NVARCHAR(500) NULL,
    CONSTRAINT PK_RuleFailureRow
        PRIMARY KEY CLUSTERED (RuleFailureRowId),
    CONSTRAINT FK_RuleFailureRow_RuleResult
        FOREIGN KEY (RuleResultId)
        REFERENCES dq.RuleResult (RuleResultId)
);

IF OBJECT_ID('dq.DataException') IS NULL
CREATE TABLE dq.DataException
(
    DataExceptionId INT IDENTITY(1,1) NOT NULL,
    DqRuleId INT NOT NULL,
    KeyValue1 NVARCHAR(100) NOT NULL,
    StatusCode VARCHAR(20) NOT NULL
        CONSTRAINT DF_DataException_StatusCode DEFAULT 'NEW',
    OwnerPartyId INT NULL,
    OpenedDate DATE NOT NULL
        CONSTRAINT DF_DataException_OpenedDate
        DEFAULT CAST(GETDATE() AS DATE),
    DueDate DATE NULL,
    ClosedDate DATE NULL,
    ResolutionNote NVARCHAR(1000) NULL,
    CONSTRAINT PK_DataException
        PRIMARY KEY CLUSTERED (DataExceptionId),
    CONSTRAINT FK_DataException_Rule FOREIGN KEY (DqRuleId)
        REFERENCES dq.[Rule] (DqRuleId),
    CONSTRAINT CK_DataException_StatusCode CHECK
        (StatusCode IN ('NEW','ACKNOWLEDGED','ACCEPTED_RISK',
         'REMEDIATED','CLOSED'))
);

IF OBJECT_ID('dq.SyntheticDefectRegister') IS NULL
CREATE TABLE dq.SyntheticDefectRegister
(
    SyntheticDefectId INT IDENTITY(1,1) NOT NULL,
    DefectCode VARCHAR(20) NOT NULL,
    DefectName NVARCHAR(200) NOT NULL,
    TargetObjectName NVARCHAR(200) NOT NULL,
    Mechanism NVARCHAR(1000) NOT NULL,
    InjectionRateNote NVARCHAR(200) NOT NULL,
    ExpectedDetectingRuleCode VARCHAR(30) NULL,
    GovernanceScenario NVARCHAR(500) NOT NULL,
    SeedFormula NVARCHAR(500) NOT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_SyntheticDefectRegister_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_SyntheticDefectRegister
        PRIMARY KEY CLUSTERED (SyntheticDefectId),
    CONSTRAINT UQ_SyntheticDefectRegister_DefectCode
        UNIQUE (DefectCode)
);

IF OBJECT_ID('dq.SyntheticDefectTruth') IS NULL
CREATE TABLE dq.SyntheticDefectTruth
(
    SyntheticDefectTruthId INT IDENTITY(1,1) NOT NULL,
    DefectCode VARCHAR(20) NOT NULL,
    KeyValue1 NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_SyntheticDefectTruth
        PRIMARY KEY CLUSTERED (SyntheticDefectTruthId)
);

IF OBJECT_ID('dq.RuleEffectiveness') IS NULL
CREATE TABLE dq.RuleEffectiveness
(
    RuleEffectivenessId INT IDENTITY(1,1) NOT NULL,
    RuleExecutionBatchId INT NOT NULL,
    DqRuleId INT NOT NULL,
    DefectCode VARCHAR(20) NOT NULL,
    TruePositive INT NOT NULL,
    FalsePositive INT NOT NULL,
    FalseNegative INT NOT NULL,
    PrecisionPct AS (CASE WHEN TruePositive+FalsePositive = 0
        THEN NULL ELSE CAST(1.0*TruePositive
        / (TruePositive+FalsePositive) AS DECIMAL(9,6)) END),
    RecallPct AS (CASE WHEN TruePositive+FalseNegative = 0
        THEN NULL ELSE CAST(1.0*TruePositive
        / (TruePositive+FalseNegative) AS DECIMAL(9,6)) END),
    CONSTRAINT PK_RuleEffectiveness
        PRIMARY KEY CLUSTERED (RuleEffectivenessId)
);
GO

/* ---- defect register: designed before generation ---- */
DELETE FROM dq.SyntheticDefectRegister;
INSERT INTO dq.SyntheticDefectRegister
    (DefectCode, DefectName, TargetObjectName, Mechanism,
     InjectionRateNote, ExpectedDetectingRuleCode,
     GovernanceScenario, SeedFormula) VALUES
('DEF01','Null note rate on boarded loans',
 'src.SvcLoanMaster',
 'NoteRatePercent set NULL on a deterministic slice of '
 + 'boarded loans','~0.8% of loans','DQR01',
 'Completeness failure on a CDE',
 'ABS(CHECKSUM(''DEF01'', LoanNumber)) % 1000 < 8'),
('DEF02','Invalid property state code',
 'src.SvcLoanMaster',
 'PropertyStateCode set to ZZ on a deterministic slice',
 '~0.4% of loans','DQR02',
 'Validity failure that breaks MCR state-level splits',
 'ABS(CHECKSUM(''DEF02'', LoanNumber)) % 1000 < 4'),
('DEF03','UPB above original amount without modification',
 'src.SvcLoanMonthEnd',
 'CurrentUpbAmount inflated 8% above OriginalLoanAmount on '
 + 'a slice of latest-month rows with no modification',
 '~0.3% of latest-month rows','DQR03',
 'Reasonableness failure',
 'ABS(CHECKSUM(''DEF03'', LoanNumber)) % 1000 < 3'),
('DEF04','Duplicate loan number across boarding batches',
 'src.BrdBoardingTape',
 'Tape rows duplicated into a second batch for a slice',
 '~15 loans','DQR04',
 'Uniqueness failure at the raw layer; master dedupes',
 'ABS(CHECKSUM(''DEF04'', LoanNumber)) % 1000 < 2'),
('DEF05','Source bucket contradicts days past due',
 'src.SvcLoanMonthEnd',
 'DelinquencyBucketCode shifted one bucket on a slice of '
 + '2026 rows; derived DPD is unchanged',
 '~0.7% of 2026 rows','DQR05',
 'Consistency failure on a direct MCR field',
 'ABS(CHECKSUM(''DEF05'', LoanNumber, AsOfDate)) % 1000 < 7'),
('DEF06','Payments referencing nonexistent loans',
 'src.PayPaymentTransaction',
 'Payment rows written with LoanNumber FLORPHAN01-12',
 '12 payment rows','DQR06',
 'Referential integrity failure',
 'Fixed key list FLORPHAN01 through FLORPHAN12'),
('DEF07','Late payment posting',
 'src.PayPaymentTransaction',
 'PostedDate pushed 2-4 business days after ReceivedDate '
 + 'on a slice','~2.5% of payments','DQR07',
 'Timeliness; makes Payment Posting Timeliness real',
 'ABS(CHECKSUM(''DEF07'', PaymentTransactionId)) % 1000 < 25'),
('DEF08','Wrong split then reversal and repost',
 'src.PayPaymentTransaction',
 'Original posting P/I swapped, then a reversal row and a '
 + 'corrected repost chained by OriginalTransactionId',
 '~0.9% of payments','DQR08',
 'Accuracy; drives Payment Posting Accuracy',
 'ABS(CHECKSUM(''DEF08'', PaymentTransactionId)) % 1000 < 9'),
('DEF09','Tax disbursed after due date',
 'src.SvcEscrowDisbursement',
 'DisbursedDate pushed 3-20 days past TaxDueDate on a slice',
 '~4% of tax disbursements','DQR09',
 'Drives Tax Payment Timeliness',
 'ABS(CHECKSUM(''DEF09'', EscrowDisbursementId)) % 1000 < 40'),
('DEF10','Boarding critical field mismatch',
 'src.SvcLoanMaster',
 'One of 5 critical fields perturbed in SVC vs the tape '
 + '(rate +0.125, or next due +1 month, or escrow +250)',
 '~1.5% of boarded loans','DQR10',
 'Accuracy against known tape truth; Boarding Data Accuracy',
 'ABS(CHECKSUM(''DEF10'', LoanNumber)) % 1000 < 15'),
('DEF11','Missing month-end snapshot rows',
 'src.SvcLoanMonthEnd',
 'Snapshot rows deleted for a slice of active loans for '
 + 'AsOfDate 2025-03-31','~40 loans, one month','DQR11',
 'Snapshot continuity break; blocking reconciliation',
 'ABS(CHECKSUM(''DEF11'', LoanNumber)) % 1000 < 4'),
('DEF12','Investor code typo FNM',
 'src.SvcLoanMonthEnd',
 'InvestorCode written as FNM instead of FNMA on a slice '
 + 'of latest-month rows',
 '~120 rows, latest month','DQR12',
 'Validity failure that visibly breaks the LS300 investor '
 + 'reconciliation: the interview demo',
 'ABS(CHECKSUM(''DEF12'', LoanNumber)) % 1000 < 12'),
('DEF13','Seeded investor report corrections',
 'src.InvLoanReport',
 'CorrectionResubmissionFlag and errors concentrated in two '
 + 'months','~heavier slice in 2025-11 and 2026-02',NULL,
 'Business defect driving investor accuracy metrics; not a '
 + 'DQ rule target',
 'ABS(CHECKSUM(''DEF13'', LoanNumber)) % 1000 < 30'),
('DEF14','Application LO not on roster',
 'src.LosApplication',
 'LoanOfficerNmlsId set to 999999 on a slice of '
 + 'applications','~0.5% of applications','DQR14',
 'Referential integrity; breaks ACMLO1 attribution',
 'ABS(CHECKSUM(''DEF14'', ApplicationId)) % 1000 < 5'),
('DEF15','Duplicate leads same contact same day',
 'src.CrmLead',
 'Second lead row inserted for the same ContactKey and '
 + 'LeadCreatedDate on a slice','~120 duplicate pairs',
 'DQR15','Uniqueness; inflates conversion denominators',
 'ABS(CHECKSUM(''DEF15'', ContactKey)) % 1000 < 3'),
('DEF16','Funding date before application received',
 'src.LosApplication',
 'FundingDate set 10 days before AppReceivedDate on a tiny '
 + 'funded slice','~0.3% of funded apps','DQR16',
 'Temporal validity',
 'ABS(CHECKSUM(''DEF16'', ApplicationId)) % 1000 < 3'),
('DEF17','Terminal application missing disposition code',
 'src.LosApplication',
 'DispositionCode nulled on a slice of terminal '
 + 'non-funded applications',
 '~0.8% of terminal apps','DQR17',
 'Completeness; breaks the AC066 = AC090 pipeline tie-out, '
 + 'the Section I reconciliation demo',
 'ABS(CHECKSUM(''DEF17'', ApplicationId)) % 1000 < 8'),
('DEF18','Lock expiration before lock date',
 'src.PpeRateLock',
 'CurrentExpirationDate set before LockDate on a slice',
 '~0.4% of locks','DQR18',
 'Validity and consistency on lock terms',
 'ABS(CHECKSUM(''DEF18'', RateLockId)) % 1000 < 4'),
('DEF19','Funded in a state with an expired license',
 'src.LicLoanOfficerLicense',
 'Two named LOs given an expired TX license while TX '
 + 'fundings exist','2 LOs','DQR19',
 'Critical blocking compliance-flavored DQ; SAFE Act',
 'Fixed NmlsIds FL30007 and FL30021, state TX'),
('DEF20','Missing lead source code',
 'src.CrmLead',
 'LeadSourceCode nulled on a slice of leads',
 '~1.2% of leads','DQR20',
 'Attribution completeness for marketing metrics',
 'ABS(CHECKSUM(''DEF20'', LeadId)) % 1000 < 12');

DELETE FROM dq.SyntheticDefectTruth;

PRINT 'Script 013 complete: DQ engine tables created; 20 '
    + 'defects pre-registered before generation.';
GO
