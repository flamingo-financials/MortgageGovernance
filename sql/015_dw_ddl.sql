/* ============================================================
   MortgageGovernance | Phase 4 | Script 015
   Dimensional warehouse DDL. DimDate plus 12 dimensions, 15
   fact tables, dw.ufn_NextBusinessDate, and 22 stg contract
   views over src. DDL only: load and derivation logic is
   implemented in script 016 per gov.DerivationRule canonical
   logic. Idempotent (guarded CREATE TABLE; CREATE OR ALTER
   for the function and views).
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

/* ============================================================
   DIMENSIONS
   ============================================================ */

/* dw.DimDate
   Grain: one row per calendar date, 2015-01-01 to 2027-12-31
   (populated by dw.usp_LoadDimDate in 016). HolidayFlag and
   BusinessDayFlag derive from ref.Holiday and weekends. */
IF OBJECT_ID('dw.DimDate') IS NULL
CREATE TABLE dw.DimDate
(
    DateKey INT NOT NULL,
    FullDate DATE NOT NULL,
    CalendarYear INT NOT NULL,
    CalendarQuarter INT NOT NULL,
    QuarterName CHAR(2) NOT NULL,
    CalendarMonth INT NOT NULL,
    MonthName VARCHAR(12) NOT NULL,
    YearMonth INT NOT NULL,
    CalendarDay INT NOT NULL,
    DayOfWeekNo INT NOT NULL,
    DayName VARCHAR(12) NOT NULL,
    MonthStartDate DATE NOT NULL,
    MonthEndDate DATE NOT NULL,
    MonthEndFlag BIT NOT NULL,
    WeekendFlag BIT NOT NULL,
    HolidayFlag BIT NOT NULL,
    HolidayName NVARCHAR(100) NULL,
    BusinessDayFlag BIT NOT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimDate_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimDate PRIMARY KEY CLUSTERED (DateKey),
    CONSTRAINT UQ_DimDate_FullDate UNIQUE (FullDate)
);
GO

/* Business-day helper. Returns the first business day strictly
   after @FromDate. Used by DRV payment timeliness logic with
   ref.SlaPolicy PAY_POSTING (post by next business day). */
CREATE OR ALTER FUNCTION dw.ufn_NextBusinessDate
(
    @FromDate DATE
)
RETURNS TABLE
AS
RETURN
SELECT MIN(d.FullDate) AS NextBusinessDate
FROM dw.DimDate d
WHERE d.FullDate > @FromDate
  AND d.BusinessDayFlag = 1;
GO

/* dw.DimLoan
   Grain: one row per serviced loan (LoanNumber), type 1.
   ConformingFlag (ref.ConformingLoanLimit by origination
   year), McrLoanTypeCode (from LoanProgramCode), and
   ProductClassCode (rate type / HELOC / reverse) are derived
   in the loader per registered DRV rules. */
IF OBJECT_ID('dw.DimLoan') IS NULL
CREATE TABLE dw.DimLoan
(
    LoanKey INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    OriginationDate DATE NULL,
    MaturityDate DATE NULL,
    OriginalLoanAmount DECIMAL(18,2) NULL,
    NoteRatePercent DECIMAL(9,4) NULL,
    InterestRateTypeCode VARCHAR(10) NULL,
    AmortizationTermMonths INT NULL,
    LienPosition INT NULL,
    HelocFlag BIT NULL,
    ReverseMortgageFlag BIT NULL,
    LoanProgramCode VARCHAR(10) NULL,
    LoanPurposeCode VARCHAR(20) NULL,
    EscrowedFlag BIT NULL,
    ConformingFlag BIT NULL,
    McrLoanTypeCode VARCHAR(20) NULL,
    ProductClassCode VARCHAR(20) NULL,
    InvestorLoanNumber VARCHAR(30) NULL,
    BoardedDate DATE NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimLoan_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimLoan PRIMARY KEY CLUSTERED (LoanKey),
    CONSTRAINT UQ_DimLoan_LoanNumber UNIQUE (LoanNumber)
);

/* dw.DimBorrower
   Grain: one row per loan primary borrower (1:1 synthetic).
   PII dimension. BorrowerFirstName / BorrowerLastName are
   classified DIRECT_IDENTIFIER / RESTRICTED in gov metadata
   (script 017). Not exposed in pbi views except where a
   documented use case requires it. */
IF OBJECT_ID('dw.DimBorrower') IS NULL
CREATE TABLE dw.DimBorrower
(
    BorrowerKey INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    BorrowerFirstName NVARCHAR(60) NULL,
    BorrowerLastName NVARCHAR(60) NULL,
    BorrowerFullName NVARCHAR(121) NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimBorrower_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimBorrower
        PRIMARY KEY CLUSTERED (BorrowerKey),
    CONSTRAINT UQ_DimBorrower_LoanNumber UNIQUE (LoanNumber)
);

/* dw.DimProperty
   Grain: one row per loan collateral property (1:1).
   PropertyStateCode is loaded as received from source. DQR02
   flags invalid states; the dimension does not silently
   cleanse defective values. */
IF OBJECT_ID('dw.DimProperty') IS NULL
CREATE TABLE dw.DimProperty
(
    PropertyKey INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    PropertyStreet NVARCHAR(120) NULL,
    PropertyCity NVARCHAR(60) NULL,
    PropertyStateCode VARCHAR(4) NULL,
    PropertyPostalCode VARCHAR(10) NULL,
    PropertyTypeCode VARCHAR(20) NULL,
    OccupancyTypeCode VARCHAR(20) NULL,
    UnitsCount INT NULL,
    FloodZoneFlag BIT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimProperty_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimProperty
        PRIMARY KEY CLUSTERED (PropertyKey),
    CONSTRAINT UQ_DimProperty_LoanNumber UNIQUE (LoanNumber)
);

/* dw.DimInvestor
   Grain: one row per investor. Seeded from ref.Investor plus
   an UNKNOWN member for unmapped investor codes (DEF12 rows
   remain unmapped until governed remediation in 024). */
IF OBJECT_ID('dw.DimInvestor') IS NULL
CREATE TABLE dw.DimInvestor
(
    InvestorKey INT IDENTITY(1,1) NOT NULL,
    InvestorCode VARCHAR(10) NOT NULL,
    InvestorName NVARCHAR(100) NOT NULL,
    InvestorTypeCode VARCHAR(20) NOT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimInvestor_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimInvestor
        PRIMARY KEY CLUSTERED (InvestorKey),
    CONSTRAINT UQ_DimInvestor_InvestorCode
        UNIQUE (InvestorCode)
);

/* dw.DimServicingType
   Grain: one row per servicing arrangement type
   (ref.ServicingType, MCR LS010-LS040 basis). */
IF OBJECT_ID('dw.DimServicingType') IS NULL
CREATE TABLE dw.DimServicingType
(
    ServicingTypeKey INT IDENTITY(1,1) NOT NULL,
    ServicingTypeCode VARCHAR(30) NOT NULL,
    ServicingTypeName NVARCHAR(100) NOT NULL,
    McrLineNote NVARCHAR(200) NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimServicingType_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimServicingType
        PRIMARY KEY CLUSTERED (ServicingTypeKey),
    CONSTRAINT UQ_DimServicingType_ServicingTypeCode
        UNIQUE (ServicingTypeCode)
);

/* dw.DimRemittanceType
   Grain: one row per remittance type (ref.RemittanceType). */
IF OBJECT_ID('dw.DimRemittanceType') IS NULL
CREATE TABLE dw.DimRemittanceType
(
    RemittanceTypeKey INT IDENTITY(1,1) NOT NULL,
    RemittanceTypeCode VARCHAR(10) NOT NULL,
    RemittanceTypeName NVARCHAR(100) NOT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimRemittanceType_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimRemittanceType
        PRIMARY KEY CLUSTERED (RemittanceTypeKey),
    CONSTRAINT UQ_DimRemittanceType_RemittanceTypeCode
        UNIQUE (RemittanceTypeCode)
);

/* dw.DimLoanStatus
   Grain: one row per loan status (ref.LoanStatus).
   ActiveServicingFlag drives LS090 active-portfolio scope. */
IF OBJECT_ID('dw.DimLoanStatus') IS NULL
CREATE TABLE dw.DimLoanStatus
(
    LoanStatusKey INT IDENTITY(1,1) NOT NULL,
    LoanStatusCode VARCHAR(10) NOT NULL,
    LoanStatusName NVARCHAR(100) NOT NULL,
    ActiveServicingFlag BIT NOT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimLoanStatus_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimLoanStatus
        PRIMARY KEY CLUSTERED (LoanStatusKey),
    CONSTRAINT UQ_DimLoanStatus_LoanStatusCode
        UNIQUE (LoanStatusCode)
);

/* dw.DimDelinquencyStatus
   Grain: one row per delinquency bucket
   (ref.DelinquencyBucket). Facts carry the DERIVED bucket
   through DelinquencyStatusKey; the source-claimed bucket is
   kept on the fact as SourceReportedBucketCode so RC controls
   can expose claimed-vs-derived breaks (DEF05). */
IF OBJECT_ID('dw.DimDelinquencyStatus') IS NULL
CREATE TABLE dw.DimDelinquencyStatus
(
    DelinquencyStatusKey INT IDENTITY(1,1) NOT NULL,
    DelinquencyBucketCode VARCHAR(20) NOT NULL,
    DelinquencyBucketName NVARCHAR(100) NOT NULL,
    MinDpd INT NOT NULL,
    MaxDpd INT NULL,
    SortOrder INT NOT NULL,
    DelinquentFlag BIT NOT NULL,
    SeriousDelinquencyFlag BIT NOT NULL,
    McrLineNote NVARCHAR(200) NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimDelinquencyStatus_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimDelinquencyStatus
        PRIMARY KEY CLUSTERED (DelinquencyStatusKey),
    CONSTRAINT UQ_DimDelinquencyStatus_BucketCode
        UNIQUE (DelinquencyBucketCode)
);

/* dw.DimWorkoutType
   Grain: one row per workout type (ref.WorkoutType). */
IF OBJECT_ID('dw.DimWorkoutType') IS NULL
CREATE TABLE dw.DimWorkoutType
(
    WorkoutTypeKey INT IDENTITY(1,1) NOT NULL,
    WorkoutTypeCode VARCHAR(20) NOT NULL,
    WorkoutTypeName NVARCHAR(100) NOT NULL,
    RetentionFlag BIT NOT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimWorkoutType_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimWorkoutType
        PRIMARY KEY CLUSTERED (WorkoutTypeKey),
    CONSTRAINT UQ_DimWorkoutType_WorkoutTypeCode
        UNIQUE (WorkoutTypeCode)
);

/* dw.DimLeadSource
   Grain: one row per lead source code observed in CRM plus
   an UNKNOWN member (DEF20 null LeadSourceCode maps to
   UNKNOWN; the defect stays visible, not cleansed).
   MarketingSourcedFlag / ReferralFlag support marketing
   attribution metrics. */
IF OBJECT_ID('dw.DimLeadSource') IS NULL
CREATE TABLE dw.DimLeadSource
(
    LeadSourceKey INT IDENTITY(1,1) NOT NULL,
    LeadSourceCode VARCHAR(30) NOT NULL,
    LeadSourceName NVARCHAR(100) NOT NULL,
    MarketingSourcedFlag BIT NOT NULL,
    ReferralFlag BIT NOT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimLeadSource_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimLeadSource
        PRIMARY KEY CLUSTERED (LeadSourceKey),
    CONSTRAINT UQ_DimLeadSource_LeadSourceCode
        UNIQUE (LeadSourceCode)
);

/* dw.DimBranch
   Grain: one row per branch from the LIC roster. */
IF OBJECT_ID('dw.DimBranch') IS NULL
CREATE TABLE dw.DimBranch
(
    BranchKey INT IDENTITY(1,1) NOT NULL,
    BranchCode VARCHAR(10) NOT NULL,
    BranchName NVARCHAR(100) NOT NULL,
    Region NVARCHAR(40) NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimBranch_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimBranch PRIMARY KEY CLUSTERED (BranchKey),
    CONSTRAINT UQ_DimBranch_BranchCode UNIQUE (BranchCode)
);

/* dw.DimLoanOfficer
   Grain: one row per NmlsId per roster effective period
   (SCD2). Facts attribute as-of the governed event date per
   DRV rules. UNKNOWN member absorbs unmapped NMLS ids
   (DEF14 LO 999999) so the defect is countable, not hidden. */
IF OBJECT_ID('dw.DimLoanOfficer') IS NULL
CREATE TABLE dw.DimLoanOfficer
(
    LoanOfficerKey INT IDENTITY(1,1) NOT NULL,
    NmlsId VARCHAR(12) NOT NULL,
    FirstName NVARCHAR(60) NULL,
    LastName NVARCHAR(60) NULL,
    FullName NVARCHAR(121) NULL,
    BranchCode VARCHAR(10) NULL,
    Region NVARCHAR(40) NULL,
    ManagerNmlsId VARCHAR(12) NULL,
    ChannelCode VARCHAR(20) NULL,
    EmploymentStatusCode VARCHAR(20) NULL,
    HireDate DATE NULL,
    TerminationDate DATE NULL,
    EffectiveFromDate DATE NOT NULL,
    EffectiveToDate DATE NULL,
    CurrentRowFlag BIT NOT NULL
        CONSTRAINT DF_DimLoanOfficer_CurrentRowFlag DEFAULT 1,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DimLoanOfficer_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DimLoanOfficer
        PRIMARY KEY CLUSTERED (LoanOfficerKey),
    CONSTRAINT UQ_DimLoanOfficer_NmlsId_From
        UNIQUE (NmlsId, EffectiveFromDate)
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'UX_DimLoanOfficer_CurrentRow')
CREATE UNIQUE NONCLUSTERED INDEX UX_DimLoanOfficer_CurrentRow
    ON dw.DimLoanOfficer (NmlsId)
    WHERE CurrentRowFlag = 1;
GO

/* ============================================================
   FACTS
   ============================================================ */

/* dw.FactLoanMonthEndSnapshot
   Grain: one row per loan per month-end (LoanNumber +
   SnapshotDateKey). DaysPastDue derives from
   NextPaymentDueDate; DelinquencyStatusKey is the DERIVED
   bucket via ref.DelinquencyBucket; SourceReportedBucketCode
   preserves the source-claimed bucket for claimed-vs-derived
   reconciliation (DEF05). Roll/cure via prior-month self
   join; CLTV via latest valuation and ref.LtvBand. */
IF OBJECT_ID('dw.FactLoanMonthEndSnapshot') IS NULL
CREATE TABLE dw.FactLoanMonthEndSnapshot
(
    LoanMonthEndSnapshotKey BIGINT IDENTITY(1,1) NOT NULL,
    LoanKey INT NOT NULL,
    SnapshotDateKey INT NOT NULL,
    AsOfDate DATE NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    InvestorKey INT NOT NULL,
    ServicingTypeKey INT NOT NULL,
    RemittanceTypeKey INT NOT NULL,
    LoanStatusKey INT NOT NULL,
    DelinquencyStatusKey INT NOT NULL,
    CurrentUpbAmount DECIMAL(18,2) NULL,
    BeginningUpbAmount DECIMAL(18,2) NULL,
    ScheduledPrincipalAmount DECIMAL(18,2) NULL,
    VoluntaryPrepaidPrincipalAmount DECIMAL(18,2) NULL,
    InterestRatePercent DECIMAL(9,4) NULL,
    ServicingFeeRatePercent DECIMAL(9,4) NULL,
    NextPaymentDueDate DATE NULL,
    DaysPastDue INT NULL,
    SourceReportedBucketCode VARCHAR(20) NULL,
    EscrowBalanceAmount DECIMAL(18,2) NULL,
    SuspenseBalanceAmount DECIMAL(18,2) NULL,
    EscrowedFlag BIT NULL,
    ForbearanceFlag BIT NULL,
    ActiveServicingFlag BIT NOT NULL,
    Roll30to60Flag BIT NOT NULL
        CONSTRAINT DF_FactLoanMonthEndSnapshot_Roll30to60Flag
        DEFAULT 0,
    CureFlag BIT NOT NULL
        CONSTRAINT DF_FactLoanMonthEndSnapshot_CureFlag
        DEFAULT 0,
    RunoffFlag BIT NOT NULL
        CONSTRAINT DF_FactLoanMonthEndSnapshot_RunoffFlag
        DEFAULT 0,
    RunoffReasonCode VARCHAR(20) NULL,
    ModSeasoningCode VARCHAR(20) NULL,
    CurrentLtvPct DECIMAL(9,4) NULL,
    LtvBandCode VARCHAR(20) NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactLoanMonthEndSnapshot_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactLoanMonthEndSnapshot
        PRIMARY KEY CLUSTERED (LoanMonthEndSnapshotKey),
    CONSTRAINT UQ_FactLoanMonthEndSnapshot_Loan_Snapshot
        UNIQUE (LoanNumber, SnapshotDateKey),
    CONSTRAINT FK_FactLoanMonthEndSnapshot_DimLoan
        FOREIGN KEY (LoanKey)
        REFERENCES dw.DimLoan (LoanKey),
    CONSTRAINT FK_FactLoanMonthEndSnapshot_DimDate
        FOREIGN KEY (SnapshotDateKey)
        REFERENCES dw.DimDate (DateKey),
    CONSTRAINT FK_FactLoanMonthEndSnapshot_DimInvestor
        FOREIGN KEY (InvestorKey)
        REFERENCES dw.DimInvestor (InvestorKey),
    CONSTRAINT FK_FactLoanMonthEndSnapshot_DimServicingType
        FOREIGN KEY (ServicingTypeKey)
        REFERENCES dw.DimServicingType (ServicingTypeKey),
    CONSTRAINT FK_FactLoanMonthEndSnapshot_DimRemittanceType
        FOREIGN KEY (RemittanceTypeKey)
        REFERENCES dw.DimRemittanceType (RemittanceTypeKey),
    CONSTRAINT FK_FactLoanMonthEndSnapshot_DimLoanStatus
        FOREIGN KEY (LoanStatusKey)
        REFERENCES dw.DimLoanStatus (LoanStatusKey),
    CONSTRAINT FK_FactLoanMonthEndSnapshot_DimDelinqStatus
        FOREIGN KEY (DelinquencyStatusKey)
        REFERENCES dw.DimDelinquencyStatus
            (DelinquencyStatusKey)
);

/* dw.FactPaymentTransaction
   Grain: one row per source payment transaction.
   PostedTimelyFlag: PostedDate on or before the next business
   day after ReceivedDate (dw.ufn_NextBusinessDate +
   ref.SlaPolicy PAY_POSTING). PostedAccuratelyFlag: original
   postings later reversed and reposted are inaccurate
   (reversal-chain logic, DEF08). Orphan payments (DEF06) map
   to the UNKNOWN loan member with UnmatchedLoanFlag = 1. */
IF OBJECT_ID('dw.FactPaymentTransaction') IS NULL
CREATE TABLE dw.FactPaymentTransaction
(
    PaymentTransactionKey BIGINT IDENTITY(1,1) NOT NULL,
    PaymentTransactionId BIGINT NOT NULL,
    LoanKey INT NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    ReceivedDateKey INT NOT NULL,
    ReceivedDate DATE NOT NULL,
    PostedDate DATE NULL,
    EffectiveDate DATE NULL,
    PaymentAmount DECIMAL(18,2) NOT NULL,
    PrincipalAmount DECIMAL(18,2) NULL,
    InterestAmount DECIMAL(18,2) NULL,
    EscrowAmount DECIMAL(18,2) NULL,
    FeeAmount DECIMAL(18,2) NULL,
    SuspenseFlag BIT NOT NULL,
    ReversalFlag BIT NOT NULL,
    OriginalTransactionId BIGINT NULL,
    ChannelCode VARCHAR(20) NULL,
    DaysToPost INT NULL,
    PostedTimelyFlag BIT NULL,
    PostedAccuratelyFlag BIT NULL,
    UnmatchedLoanFlag BIT NOT NULL
        CONSTRAINT DF_FactPaymentTransaction_UnmatchedLoan
        DEFAULT 0,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactPaymentTransaction_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactPaymentTransaction
        PRIMARY KEY CLUSTERED (PaymentTransactionKey),
    CONSTRAINT UQ_FactPaymentTransaction_TransactionId
        UNIQUE (PaymentTransactionId),
    CONSTRAINT FK_FactPaymentTransaction_DimLoan
        FOREIGN KEY (LoanKey)
        REFERENCES dw.DimLoan (LoanKey),
    CONSTRAINT FK_FactPaymentTransaction_DimDate
        FOREIGN KEY (ReceivedDateKey)
        REFERENCES dw.DimDate (DateKey)
);

/* dw.FactEscrowDisbursement
   Grain: one row per escrow disbursement.
   DisbursedTimelyFlag: TAX rows disbursed on or before
   TaxDueDate (DEF09 exposes late tax disbursements); NULL
   when no due date applies. */
IF OBJECT_ID('dw.FactEscrowDisbursement') IS NULL
CREATE TABLE dw.FactEscrowDisbursement
(
    EscrowDisbursementKey INT IDENTITY(1,1) NOT NULL,
    EscrowDisbursementId INT NOT NULL,
    LoanKey INT NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    DisbursementTypeCode VARCHAR(10) NOT NULL,
    PayeeName NVARCHAR(120) NULL,
    DisbursedAmount DECIMAL(18,2) NULL,
    DisbursedDateKey INT NULL,
    DisbursedDate DATE NULL,
    TaxDueDate DATE NULL,
    PolicyExpirationDate DATE NULL,
    DisbursedTimelyFlag BIT NULL,
    AmountMatchFlag BIT NULL,
    PayeeMatchFlag BIT NULL,
    LoanMatchFlag BIT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactEscrowDisbursement_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactEscrowDisbursement
        PRIMARY KEY CLUSTERED (EscrowDisbursementKey),
    CONSTRAINT UQ_FactEscrowDisbursement_DisbursementId
        UNIQUE (EscrowDisbursementId),
    CONSTRAINT FK_FactEscrowDisbursement_DimLoan
        FOREIGN KEY (LoanKey)
        REFERENCES dw.DimLoan (LoanKey),
    CONSTRAINT FK_FactEscrowDisbursement_DimDate
        FOREIGN KEY (DisbursedDateKey)
        REFERENCES dw.DimDate (DateKey)
);

/* dw.FactEscrowAnalysis
   Grain: one row per escrow analysis obligation.
   CompletedOnTimeFlag: AnalysisCompletedDate on or before
   AnalysisDueDate (cycle per ref.EscrowAnalysisCycle). */
IF OBJECT_ID('dw.FactEscrowAnalysis') IS NULL
CREATE TABLE dw.FactEscrowAnalysis
(
    EscrowAnalysisKey INT IDENTITY(1,1) NOT NULL,
    EscrowAnalysisId INT NOT NULL,
    LoanKey INT NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    AnalysisDueDateKey INT NOT NULL,
    AnalysisDueDate DATE NOT NULL,
    AnalysisCompletedDate DATE NULL,
    CompletedOnTimeFlag BIT NULL,
    ShortageAmount DECIMAL(18,2) NULL,
    ShortageFlag BIT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactEscrowAnalysis_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactEscrowAnalysis
        PRIMARY KEY CLUSTERED (EscrowAnalysisKey),
    CONSTRAINT UQ_FactEscrowAnalysis_AnalysisId
        UNIQUE (EscrowAnalysisId),
    CONSTRAINT FK_FactEscrowAnalysis_DimLoan
        FOREIGN KEY (LoanKey)
        REFERENCES dw.DimLoan (LoanKey),
    CONSTRAINT FK_FactEscrowAnalysis_DimDate
        FOREIGN KEY (AnalysisDueDateKey)
        REFERENCES dw.DimDate (DateKey)
);

/* dw.FactLossMitigationCase
   Grain: one row per loss mitigation case.
   EvalTurnTimeDays = DecisionDate minus CompletePackageDate.
   WorkoutApprovedFlag from DecisionCode; NULL while pending.
   WorkoutTypeKey NULL when no workout type applies. */
IF OBJECT_ID('dw.FactLossMitigationCase') IS NULL
CREATE TABLE dw.FactLossMitigationCase
(
    LossMitigationCaseKey INT IDENTITY(1,1) NOT NULL,
    LossMitCaseId INT NOT NULL,
    LoanKey INT NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    WorkoutTypeKey INT NULL,
    AppReceivedDateKey INT NOT NULL,
    AppReceivedDate DATE NOT NULL,
    CompletePackageDate DATE NULL,
    DecisionDate DATE NULL,
    DecisionCode VARCHAR(20) NULL,
    WorkoutTypeCode VARCHAR(20) NULL,
    TrialStartDate DATE NULL,
    TrialCompletedDate DATE NULL,
    EvalTurnTimeDays INT NULL,
    WorkoutApprovedFlag BIT NULL,
    TrialConvertedFlag BIT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactLossMitigationCase_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactLossMitigationCase
        PRIMARY KEY CLUSTERED (LossMitigationCaseKey),
    CONSTRAINT UQ_FactLossMitigationCase_CaseId
        UNIQUE (LossMitCaseId),
    CONSTRAINT FK_FactLossMitigationCase_DimLoan
        FOREIGN KEY (LoanKey)
        REFERENCES dw.DimLoan (LoanKey),
    CONSTRAINT FK_FactLossMitigationCase_DimWorkoutType
        FOREIGN KEY (WorkoutTypeKey)
        REFERENCES dw.DimWorkoutType (WorkoutTypeKey),
    CONSTRAINT FK_FactLossMitigationCase_DimDate
        FOREIGN KEY (AppReceivedDateKey)
        REFERENCES dw.DimDate (DateKey)
);

/* dw.FactForeclosureCase
   Grain: one row per foreclosure case. ReferralDays =
   ReferralDate minus FirstLegalEligibleDate;
   FcReferralTimelyFlag per ref.SlaPolicy FC_REFERRAL. */
IF OBJECT_ID('dw.FactForeclosureCase') IS NULL
CREATE TABLE dw.FactForeclosureCase
(
    ForeclosureCaseKey INT IDENTITY(1,1) NOT NULL,
    ForeclosureCaseId INT NOT NULL,
    LoanKey INT NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    FirstLegalEligibleDateKey INT NOT NULL,
    FirstLegalEligibleDate DATE NOT NULL,
    ReferralDate DATE NULL,
    FirstLegalDate DATE NULL,
    SaleScheduledDate DATE NULL,
    SaleHeldDate DATE NULL,
    CaseStatusCode VARCHAR(10) NOT NULL,
    ResolutionTypeCode VARCHAR(20) NULL,
    ReferralDays INT NULL,
    FcReferralTimelyFlag BIT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactForeclosureCase_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactForeclosureCase
        PRIMARY KEY CLUSTERED (ForeclosureCaseKey),
    CONSTRAINT UQ_FactForeclosureCase_CaseId
        UNIQUE (ForeclosureCaseId),
    CONSTRAINT FK_FactForeclosureCase_DimLoan
        FOREIGN KEY (LoanKey)
        REFERENCES dw.DimLoan (LoanKey),
    CONSTRAINT FK_FactForeclosureCase_DimDate
        FOREIGN KEY (FirstLegalEligibleDateKey)
        REFERENCES dw.DimDate (DateKey)
);

/* dw.FactBankruptcyCase
   Grain: one row per bankruptcy case. PocTimelyFlag: proof
   of claim filed on or before PocBarDate; NULL when no bar
   date recorded. */
IF OBJECT_ID('dw.FactBankruptcyCase') IS NULL
CREATE TABLE dw.FactBankruptcyCase
(
    BankruptcyCaseKey INT IDENTITY(1,1) NOT NULL,
    BankruptcyCaseId INT NOT NULL,
    LoanKey INT NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    ChapterCode VARCHAR(5) NOT NULL,
    PetitionDateKey INT NOT NULL,
    PetitionDate DATE NOT NULL,
    PocBarDate DATE NULL,
    PocFiledDate DATE NULL,
    CaseStatusCode VARCHAR(10) NOT NULL,
    DispositionCode VARCHAR(20) NULL,
    PocTimelyFlag BIT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactBankruptcyCase_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactBankruptcyCase
        PRIMARY KEY CLUSTERED (BankruptcyCaseKey),
    CONSTRAINT UQ_FactBankruptcyCase_CaseId
        UNIQUE (BankruptcyCaseId),
    CONSTRAINT FK_FactBankruptcyCase_DimLoan
        FOREIGN KEY (LoanKey)
        REFERENCES dw.DimLoan (LoanKey),
    CONSTRAINT FK_FactBankruptcyCase_DimDate
        FOREIGN KEY (PetitionDateKey)
        REFERENCES dw.DimDate (DateKey)
);

/* dw.FactBoardingEvent
   Grain: one row per loan per boarding batch (duplicate tape
   rows collapse; TapeRowCount preserves DEF04 evidence).
   BoardedOnTimeFlag per ref.SlaPolicy BOARDING from
   TransferEffectiveDate. Five tape-vs-master critical field
   comparisons (DEF10): UPB, note rate, next due date, escrow
   balance, investor. BoardingAccuracyScore = matched fields
   divided by 5. */
IF OBJECT_ID('dw.FactBoardingEvent') IS NULL
CREATE TABLE dw.FactBoardingEvent
(
    BoardingEventKey INT IDENTITY(1,1) NOT NULL,
    LoanKey INT NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    BoardingBatchId INT NOT NULL,
    TransferTypeCode VARCHAR(10) NOT NULL,
    TransferEffectiveDateKey INT NOT NULL,
    TransferEffectiveDate DATE NOT NULL,
    ScheduledBoardDate DATE NOT NULL,
    BoardingCompletedDate DATE NULL,
    BoardingDays INT NULL,
    BoardedOnTimeFlag BIT NULL,
    TapeRowCount INT NOT NULL
        CONSTRAINT DF_FactBoardingEvent_TapeRowCount
        DEFAULT 1,
    UpbMismatchFlag BIT NULL,
    RateMismatchFlag BIT NULL,
    NextDueDateMismatchFlag BIT NULL,
    EscrowBalanceMismatchFlag BIT NULL,
    InvestorMismatchFlag BIT NULL,
    MismatchCount INT NULL,
    BoardingAccuracyScore DECIMAL(9,4) NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactBoardingEvent_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactBoardingEvent
        PRIMARY KEY CLUSTERED (BoardingEventKey),
    CONSTRAINT UQ_FactBoardingEvent_Loan_Batch
        UNIQUE (LoanNumber, BoardingBatchId),
    CONSTRAINT FK_FactBoardingEvent_DimLoan
        FOREIGN KEY (LoanKey)
        REFERENCES dw.DimLoan (LoanKey),
    CONSTRAINT FK_FactBoardingEvent_DimDate
        FOREIGN KEY (TransferEffectiveDateKey)
        REFERENCES dw.DimDate (DateKey)
);

/* dw.FactInvestorLoanReporting
   Grain: one row per loan per investor reporting period.
   SubmittedOnTimeFlag: submitted on or before deadline.
   CorrectionResubmissionFlag carries the DEF13 correction
   spike signal (intentionally rule-less business defect). */
IF OBJECT_ID('dw.FactInvestorLoanReporting') IS NULL
CREATE TABLE dw.FactInvestorLoanReporting
(
    InvestorLoanReportingKey BIGINT IDENTITY(1,1) NOT NULL,
    InvLoanReportId BIGINT NOT NULL,
    LoanKey INT NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    InvestorKey INT NOT NULL,
    ReportingPeriod INT NOT NULL,
    ReportingDeadlineDateKey INT NOT NULL,
    ReportingDeadlineDate DATE NOT NULL,
    ReportSubmittedDate DATE NULL,
    SubmittedOnTimeFlag BIT NULL,
    AcceptedFlag BIT NULL,
    ErrorCount INT NULL,
    ReportedTransactionCount INT NULL,
    CorrectionResubmissionFlag BIT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactInvestorLoanReporting_CreatedUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactInvestorLoanReporting
        PRIMARY KEY CLUSTERED (InvestorLoanReportingKey),
    CONSTRAINT UQ_FactInvestorLoanReporting_ReportId
        UNIQUE (InvLoanReportId),
    CONSTRAINT FK_FactInvestorLoanReporting_DimLoan
        FOREIGN KEY (LoanKey)
        REFERENCES dw.DimLoan (LoanKey),
    CONSTRAINT FK_FactInvestorLoanReporting_DimInvestor
        FOREIGN KEY (InvestorKey)
        REFERENCES dw.DimInvestor (InvestorKey),
    CONSTRAINT FK_FactInvestorLoanReporting_DimDate
        FOREIGN KEY (ReportingDeadlineDateKey)
        REFERENCES dw.DimDate (DateKey)
);

/* dw.FactInvestorRemittance
   Grain: one row per investor per remittance period.
   RemittedOnTimeFlag: sent on or before due date. */
IF OBJECT_ID('dw.FactInvestorRemittance') IS NULL
CREATE TABLE dw.FactInvestorRemittance
(
    InvestorRemittanceKey INT IDENTITY(1,1) NOT NULL,
    InvRemittanceId INT NOT NULL,
    InvestorKey INT NOT NULL,
    RemittancePeriod INT NOT NULL,
    RemittanceDueDateKey INT NOT NULL,
    RemittanceDueDate DATE NOT NULL,
    RemittanceSentDate DATE NULL,
    RemittanceAmount DECIMAL(18,2) NULL,
    RemittedOnTimeFlag BIT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactInvestorRemittance_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactInvestorRemittance
        PRIMARY KEY CLUSTERED (InvestorRemittanceKey),
    CONSTRAINT UQ_FactInvestorRemittance_RemittanceId
        UNIQUE (InvRemittanceId),
    CONSTRAINT FK_FactInvestorRemittance_DimInvestor
        FOREIGN KEY (InvestorKey)
        REFERENCES dw.DimInvestor (InvestorKey),
    CONSTRAINT FK_FactInvestorRemittance_DimDate
        FOREIGN KEY (RemittanceDueDateKey)
        REFERENCES dw.DimDate (DateKey)
);

/* dw.FactRepurchaseDemand
   Grain: one row per investor repurchase demand.
   ResolutionDays = ResolutionDate minus DemandReceivedDate. */
IF OBJECT_ID('dw.FactRepurchaseDemand') IS NULL
CREATE TABLE dw.FactRepurchaseDemand
(
    RepurchaseDemandKey INT IDENTITY(1,1) NOT NULL,
    RepurchaseDemandId INT NOT NULL,
    LoanKey INT NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    InvestorKey INT NOT NULL,
    DemandReceivedDateKey INT NOT NULL,
    DemandReceivedDate DATE NOT NULL,
    DemandReasonCode VARCHAR(30) NULL,
    DemandAmount DECIMAL(18,2) NULL,
    ResolutionDate DATE NULL,
    ResolutionTypeCode VARCHAR(20) NULL,
    ResolutionDays INT NULL,
    ResolvedFlag BIT NOT NULL
        CONSTRAINT DF_FactRepurchaseDemand_ResolvedFlag
        DEFAULT 0,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactRepurchaseDemand_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactRepurchaseDemand
        PRIMARY KEY CLUSTERED (RepurchaseDemandKey),
    CONSTRAINT UQ_FactRepurchaseDemand_DemandId
        UNIQUE (RepurchaseDemandId),
    CONSTRAINT FK_FactRepurchaseDemand_DimLoan
        FOREIGN KEY (LoanKey)
        REFERENCES dw.DimLoan (LoanKey),
    CONSTRAINT FK_FactRepurchaseDemand_DimInvestor
        FOREIGN KEY (InvestorKey)
        REFERENCES dw.DimInvestor (InvestorKey),
    CONSTRAINT FK_FactRepurchaseDemand_DimDate
        FOREIGN KEY (DemandReceivedDateKey)
        REFERENCES dw.DimDate (DateKey)
);

/* dw.FactLead
   Grain: one row per CRM lead. LoanOfficerKey attributes to
   the SCD2 roster row as of AssignedDate (fallback
   LeadCreatedDate); unmapped ids go to UNKNOWN.
   ConvertedInWindowFlag per ref.SlaPolicy LEAD_ATTRIB.
   Null LeadSourceCode (DEF20) maps to the UNKNOWN lead
   source member. */
IF OBJECT_ID('dw.FactLead') IS NULL
CREATE TABLE dw.FactLead
(
    LeadKey INT IDENTITY(1,1) NOT NULL,
    LeadId INT NOT NULL,
    LeadCreatedDateKey INT NOT NULL,
    LeadCreatedDate DATE NOT NULL,
    LeadSourceKey INT NOT NULL,
    CampaignCode VARCHAR(30) NULL,
    ContactKey VARCHAR(40) NOT NULL,
    PropertyStateCode VARCHAR(4) NULL,
    LoanOfficerKey INT NOT NULL,
    AssignedDate DATE NULL,
    FirstContactDate DATE NULL,
    LeadStatusCode VARCHAR(20) NOT NULL,
    ConvertedApplicationId INT NULL,
    ConvertedFlag BIT NOT NULL
        CONSTRAINT DF_FactLead_ConvertedFlag DEFAULT 0,
    ConvertedInWindowFlag BIT NOT NULL
        CONSTRAINT DF_FactLead_ConvertedInWindowFlag
        DEFAULT 0,
    DaysToConvert INT NULL,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactLead_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactLead PRIMARY KEY CLUSTERED (LeadKey),
    CONSTRAINT UQ_FactLead_LeadId UNIQUE (LeadId),
    CONSTRAINT FK_FactLead_DimDate
        FOREIGN KEY (LeadCreatedDateKey)
        REFERENCES dw.DimDate (DateKey),
    CONSTRAINT FK_FactLead_DimLeadSource
        FOREIGN KEY (LeadSourceKey)
        REFERENCES dw.DimLeadSource (LeadSourceKey),
    CONSTRAINT FK_FactLead_DimLoanOfficer
        FOREIGN KEY (LoanOfficerKey)
        REFERENCES dw.DimLoanOfficer (LoanOfficerKey)
);

/* dw.FactApplication
   Grain: one row per LOS application. LoanOfficerKey
   attributes to the SCD2 roster row as of
   COALESCE(FundingDate, AppReceivedDate, AppStartedDate);
   NMLS ids missing from the roster (DEF14 LO 999999) map to
   UNKNOWN with the raw id preserved in LoanOfficerNmlsId.
   BranchKey follows the attributed loan officer. Flag logic
   (funded, cycle time, on-time close, ever locked, fallout,
   denial eligibility, denied) implements the registered DRV
   rules in the loader. */
IF OBJECT_ID('dw.FactApplication') IS NULL
CREATE TABLE dw.FactApplication
(
    ApplicationKey INT IDENTITY(1,1) NOT NULL,
    ApplicationId INT NOT NULL,
    LeadId INT NULL,
    LoanOfficerKey INT NOT NULL,
    BranchKey INT NOT NULL,
    LoanOfficerNmlsId VARCHAR(12) NOT NULL,
    AppStartedDateKey INT NOT NULL,
    AppStartedDate DATE NOT NULL,
    AppCompletedDate DATE NULL,
    AppReceivedDateKey INT NULL,
    AppReceivedDate DATE NULL,
    LoanAmountAtApplication DECIMAL(18,2) NULL,
    CurrentLoanAmount DECIMAL(18,2) NULL,
    LoanPurposeCode VARCHAR(20) NULL,
    PurposeDetailCode VARCHAR(20) NULL,
    LoanProgramCode VARCHAR(10) NULL,
    InterestRateTypeCode VARCHAR(10) NULL,
    LienPosition INT NULL,
    PropertyStateCode VARCHAR(4) NULL,
    ChannelCode VARCHAR(20) NULL,
    DispositionCode VARCHAR(20) NULL,
    DispositionDate DATE NULL,
    ScheduledClosingDate DATE NULL,
    ActualClosingDate DATE NULL,
    FundingDateKey INT NULL,
    FundingDate DATE NULL,
    LoanNumber VARCHAR(20) NULL,
    FundedFlag BIT NOT NULL
        CONSTRAINT DF_FactApplication_FundedFlag DEFAULT 0,
    CycleTimeDays INT NULL,
    OnTimeCloseFlag BIT NULL,
    EverLockedFlag BIT NOT NULL
        CONSTRAINT DF_FactApplication_EverLockedFlag
        DEFAULT 0,
    FallenOutFlag BIT NOT NULL
        CONSTRAINT DF_FactApplication_FallenOutFlag
        DEFAULT 0,
    DenialEligibleFlag BIT NOT NULL
        CONSTRAINT DF_FactApplication_DenialEligibleFlag
        DEFAULT 0,
    DeniedFlag BIT NOT NULL
        CONSTRAINT DF_FactApplication_DeniedFlag DEFAULT 0,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactApplication_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactApplication
        PRIMARY KEY CLUSTERED (ApplicationKey),
    CONSTRAINT UQ_FactApplication_ApplicationId
        UNIQUE (ApplicationId),
    CONSTRAINT FK_FactApplication_DimLoanOfficer
        FOREIGN KEY (LoanOfficerKey)
        REFERENCES dw.DimLoanOfficer (LoanOfficerKey),
    CONSTRAINT FK_FactApplication_DimBranch
        FOREIGN KEY (BranchKey)
        REFERENCES dw.DimBranch (BranchKey),
    CONSTRAINT FK_FactApplication_DimDate_Started
        FOREIGN KEY (AppStartedDateKey)
        REFERENCES dw.DimDate (DateKey),
    CONSTRAINT FK_FactApplication_DimDate_Received
        FOREIGN KEY (AppReceivedDateKey)
        REFERENCES dw.DimDate (DateKey),
    CONSTRAINT FK_FactApplication_DimDate_Funding
        FOREIGN KEY (FundingDateKey)
        REFERENCES dw.DimDate (DateKey)
);

/* dw.FactRateLock
   Grain: one row per PPE rate lock. ExtendedFlag from
   ExtensionCount > 0. ExpiredWithoutFundingFlag: lock
   expired or cancelled with no funded application (DEF18
   inverted expirations surface here). RelockFlag from
   PriorLockId. ApplicationId is degenerate (no fact-to-fact
   FK); indexed for pull-through joins. */
IF OBJECT_ID('dw.FactRateLock') IS NULL
CREATE TABLE dw.FactRateLock
(
    RateLockKey INT IDENTITY(1,1) NOT NULL,
    RateLockId INT NOT NULL,
    ApplicationId INT NOT NULL,
    LockDateKey INT NOT NULL,
    LockDate DATE NOT NULL,
    LockAmount DECIMAL(18,2) NULL,
    NoteRatePercent DECIMAL(9,4) NULL,
    LockPeriodDays INT NULL,
    OriginalExpirationDate DATE NULL,
    CurrentExpirationDate DATE NULL,
    ExtensionCount INT NULL,
    TotalExtensionDays INT NULL,
    LockStatusCode VARCHAR(20) NOT NULL,
    PriorLockId INT NULL,
    ExtendedFlag BIT NOT NULL
        CONSTRAINT DF_FactRateLock_ExtendedFlag DEFAULT 0,
    ExpiredWithoutFundingFlag BIT NOT NULL
        CONSTRAINT DF_FactRateLock_ExpiredNoFundFlag
        DEFAULT 0,
    RelockFlag BIT NOT NULL
        CONSTRAINT DF_FactRateLock_RelockFlag DEFAULT 0,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactRateLock_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactRateLock
        PRIMARY KEY CLUSTERED (RateLockKey),
    CONSTRAINT UQ_FactRateLock_RateLockId
        UNIQUE (RateLockId),
    CONSTRAINT FK_FactRateLock_DimDate
        FOREIGN KEY (LockDateKey)
        REFERENCES dw.DimDate (DateKey)
);

/* dw.FactLoanOfficerLicense
   Grain: one row per roster license record, evaluated as of
   2026-07-31 (loader sets AsOfDate). LicenseCompliantFlag:
   license ACTIVE and not expired as of AsOfDate.
   CeCompliantFlag: completed hours >= required hours.
   DEF19 (expired TX licenses on funding LOs FL30007 and
   FL30021) surfaces as LicenseCompliantFlag = 0.
   LoanOfficerKey links to the current SCD2 row; NULL when
   the NMLS id is not on the roster. */
IF OBJECT_ID('dw.FactLoanOfficerLicense') IS NULL
CREATE TABLE dw.FactLoanOfficerLicense
(
    LoanOfficerLicenseKey INT IDENTITY(1,1) NOT NULL,
    LoanOfficerLicenseId INT NOT NULL,
    NmlsId VARCHAR(12) NOT NULL,
    LoanOfficerKey INT NULL,
    LicenseStateCode CHAR(2) NOT NULL,
    LicenseTypeCode VARCHAR(20) NULL,
    LicenseStatusCode VARCHAR(20) NOT NULL,
    IssueDate DATE NULL,
    ExpirationDate DATE NULL,
    RenewalDeadline DATE NULL,
    CeRequiredHours DECIMAL(6,2) NULL,
    CeCompletedHours DECIMAL(6,2) NULL,
    CeCompletedDate DATE NULL,
    AsOfDate DATE NOT NULL,
    AsOfDateKey INT NOT NULL,
    CeCompliantFlag BIT NOT NULL
        CONSTRAINT DF_FactLoanOfficerLicense_CeFlag
        DEFAULT 0,
    LicenseCompliantFlag BIT NOT NULL
        CONSTRAINT DF_FactLoanOfficerLicense_LicFlag
        DEFAULT 0,
    LoadBatchId INT NULL,
    RowHash VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_FactLoanOfficerLicense_CreatedUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_FactLoanOfficerLicense
        PRIMARY KEY CLUSTERED (LoanOfficerLicenseKey),
    CONSTRAINT UQ_FactLoanOfficerLicense_LicenseId
        UNIQUE (LoanOfficerLicenseId),
    CONSTRAINT FK_FactLoanOfficerLicense_DimLoanOfficer
        FOREIGN KEY (LoanOfficerKey)
        REFERENCES dw.DimLoanOfficer (LoanOfficerKey),
    CONSTRAINT FK_FactLoanOfficerLicense_DimDate
        FOREIGN KEY (AsOfDateKey)
        REFERENCES dw.DimDate (DateKey)
);
GO

/* ------------------------------------------------------------
   Section 4. Fact indexes (guarded, idempotent)
   ------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE name = 'IX_FactLoanMonthEndSnapshot_Snapshot'
      AND object_id =
          OBJECT_ID('dw.FactLoanMonthEndSnapshot'))
CREATE NONCLUSTERED INDEX
    IX_FactLoanMonthEndSnapshot_Snapshot
    ON dw.FactLoanMonthEndSnapshot
       (SnapshotDateKey, LoanKey)
    INCLUDE (CurrentUpbAmount, ActiveServicingFlag);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE name = 'IX_FactLoanMonthEndSnapshot_Loan'
      AND object_id =
          OBJECT_ID('dw.FactLoanMonthEndSnapshot'))
CREATE NONCLUSTERED INDEX
    IX_FactLoanMonthEndSnapshot_Loan
    ON dw.FactLoanMonthEndSnapshot
       (LoanKey, SnapshotDateKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE name = 'IX_FactPaymentTransaction_Loan'
      AND object_id =
          OBJECT_ID('dw.FactPaymentTransaction'))
CREATE NONCLUSTERED INDEX
    IX_FactPaymentTransaction_Loan
    ON dw.FactPaymentTransaction
       (LoanKey, ReceivedDateKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE name = 'IX_FactApplication_LoanOfficer'
      AND object_id = OBJECT_ID('dw.FactApplication'))
CREATE NONCLUSTERED INDEX
    IX_FactApplication_LoanOfficer
    ON dw.FactApplication (LoanOfficerKey);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE name = 'IX_FactRateLock_Application'
      AND object_id = OBJECT_ID('dw.FactRateLock'))
CREATE NONCLUSTERED INDEX
    IX_FactRateLock_Application
    ON dw.FactRateLock (ApplicationId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
    WHERE name = 'IX_FactLead_LoanOfficer'
      AND object_id = OBJECT_ID('dw.FactLead'))
CREATE NONCLUSTERED INDEX
    IX_FactLead_LoanOfficer
    ON dw.FactLead (LoanOfficerKey);
GO

/* ------------------------------------------------------------
   Section 5. stg contract views
   Loaders in 016 read stg views only, never src directly.
   Explicit column lists are the contract: source PK plus
   business columns; LoadBatchId and CreatedDateUtc excluded.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW stg.vw_BrdBoardingBatch
AS
SELECT
    BoardingBatchId,
    BatchName,
    TransferTypeCode,
    TransferEffectiveDate,
    ScheduledBoardDate,
    PriorServicerName
FROM src.BrdBoardingBatch;
GO

CREATE OR ALTER VIEW stg.vw_BrdBoardingTape
AS
SELECT
    BoardingTapeId,
    BoardingBatchId,
    LoanNumber,
    BorrowerFirstName,
    BorrowerLastName,
    PropertyStreet,
    PropertyCity,
    PropertyStateCode,
    PropertyPostalCode,
    PropertyTypeCode,
    OccupancyTypeCode,
    UnitsCount,
    FloodZoneFlag,
    OriginalLoanAmount,
    OriginationDate,
    MaturityDate,
    NoteRatePercent,
    InterestRateTypeCode,
    AmortizationTermMonths,
    LienPosition,
    HelocFlag,
    ReverseMortgageFlag,
    LoanProgramCode,
    LoanPurposeCode,
    EscrowIndicator,
    ServicingTypeCode,
    RemittanceTypeCode,
    InvestorCode,
    InvestorLoanNumber,
    TapeUpbAmount,
    TapeInterestRatePercent,
    TapeNextPaymentDueDate,
    TapeEscrowBalanceAmount,
    TapeInvestorCode,
    BoardingCompletedDate
FROM src.BrdBoardingTape;
GO

CREATE OR ALTER VIEW stg.vw_SvcLoanMaster
AS
SELECT
    LoanMasterId,
    LoanNumber,
    BorrowerFirstName,
    BorrowerLastName,
    PropertyStreet,
    PropertyCity,
    PropertyStateCode,
    PropertyPostalCode,
    PropertyTypeCode,
    OccupancyTypeCode,
    UnitsCount,
    FloodZoneFlag,
    OriginalLoanAmount,
    OriginationDate,
    MaturityDate,
    NoteRatePercent,
    InterestRateTypeCode,
    AmortizationTermMonths,
    LienPosition,
    HelocFlag,
    ReverseMortgageFlag,
    LoanProgramCode,
    LoanPurposeCode,
    EscrowIndicator,
    ServicingTypeCode,
    RemittanceTypeCode,
    InvestorCode,
    InvestorLoanNumber,
    BoardedDate,
    BoardInterestRatePercent,
    BoardNextPaymentDueDate,
    BoardUpbAmount,
    BoardEscrowBalanceAmount,
    MsrOwnerName,
    MsrOwnerNmlsId,
    PoolNumber,
    ServiceReleasedDate
FROM src.SvcLoanMaster;
GO

CREATE OR ALTER VIEW stg.vw_SvcLoanMonthEnd
AS
SELECT
    LoanMonthEndId,
    LoanNumber,
    AsOfDate,
    CurrentUpbAmount,
    BeginningUpbAmount,
    ScheduledPrincipalAmount,
    VoluntaryPrepaidPrincipalAmount,
    InterestRatePercent,
    ServicingFeeRatePercent,
    NextPaymentDueDate,
    EscrowBalanceAmount,
    SuspenseBalanceAmount,
    LoanStatusCode,
    RunoffReasonCode,
    DelinquencyBucketCode,
    InvestorCode,
    ServicingTypeCode,
    RemittanceTypeCode,
    EscrowIndicator,
    ForbearanceFlag
FROM src.SvcLoanMonthEnd;
GO

CREATE OR ALTER VIEW stg.vw_SvcEscrowAnalysis
AS
SELECT
    EscrowAnalysisId,
    LoanNumber,
    AnalysisDueDate,
    AnalysisCompletedDate,
    ShortageAmount
FROM src.SvcEscrowAnalysis;
GO

CREATE OR ALTER VIEW stg.vw_SvcEscrowDisbursement
AS
SELECT
    EscrowDisbursementId,
    LoanNumber,
    DisbursementTypeCode,
    PayeeName,
    DisbursedAmount,
    DisbursedDate,
    TaxDueDate,
    PolicyExpirationDate,
    AmountMatchFlag,
    PayeeMatchFlag,
    LoanMatchFlag
FROM src.SvcEscrowDisbursement;
GO

CREATE OR ALTER VIEW stg.vw_SvcInsurancePolicy
AS
SELECT
    InsurancePolicyId,
    LoanNumber,
    PolicyTypeCode,
    PolicyEffectiveDate,
    PolicyExpirationDate,
    AnnualPremiumAmount
FROM src.SvcInsurancePolicy;
GO

CREATE OR ALTER VIEW stg.vw_SvcForbearancePlan
AS
SELECT
    ForbearancePlanId,
    LoanNumber,
    PlanStartDate,
    PlanEndDate,
    PlanStatusCode,
    ExitDestinationCode
FROM src.SvcForbearancePlan;
GO

CREATE OR ALTER VIEW stg.vw_SvcLoanModification
AS
SELECT
    LoanModificationId,
    LoanNumber,
    ModificationEffectiveDate,
    ModificationBookedDate,
    PreModRatePercent,
    PostModRatePercent
FROM src.SvcLoanModification;
GO

CREATE OR ALTER VIEW stg.vw_PayPaymentTransaction
AS
SELECT
    PaymentTransactionId,
    LoanNumber,
    ReceivedDate,
    PostedDate,
    EffectiveDate,
    PaymentAmount,
    PrincipalAmount,
    InterestAmount,
    EscrowAmount,
    FeeAmount,
    SuspenseFlag,
    ReversalFlag,
    OriginalTransactionId,
    ChannelCode
FROM src.PayPaymentTransaction;
GO

CREATE OR ALTER VIEW stg.vw_DmsLossMitigationCase
AS
SELECT
    LossMitCaseId,
    LoanNumber,
    AppReceivedDate,
    CompletePackageDate,
    DecisionDate,
    DecisionCode,
    WorkoutTypeCode,
    TrialStartDate,
    TrialCompletedDate,
    TrialConvertedFlag
FROM src.DmsLossMitigationCase;
GO

CREATE OR ALTER VIEW stg.vw_DmsForeclosureCase
AS
SELECT
    ForeclosureCaseId,
    LoanNumber,
    FirstLegalEligibleDate,
    ReferralDate,
    FirstLegalDate,
    SaleScheduledDate,
    SaleHeldDate,
    CaseStatusCode,
    ResolutionTypeCode
FROM src.DmsForeclosureCase;
GO

CREATE OR ALTER VIEW stg.vw_DmsBankruptcyCase
AS
SELECT
    BankruptcyCaseId,
    LoanNumber,
    ChapterCode,
    PetitionDate,
    PocBarDate,
    PocFiledDate,
    CaseStatusCode,
    DispositionCode
FROM src.DmsBankruptcyCase;
GO

CREATE OR ALTER VIEW stg.vw_InvLoanReport
AS
SELECT
    InvLoanReportId,
    LoanNumber,
    InvestorCode,
    ReportingPeriod,
    ReportingDeadlineDate,
    ReportSubmittedDate,
    AcceptedFlag,
    ErrorCount,
    ReportedTransactionCount,
    CorrectionResubmissionFlag
FROM src.InvLoanReport;
GO

CREATE OR ALTER VIEW stg.vw_InvRemittance
AS
SELECT
    InvRemittanceId,
    InvestorCode,
    RemittancePeriod,
    RemittanceDueDate,
    RemittanceSentDate,
    RemittanceAmount
FROM src.InvRemittance;
GO

CREATE OR ALTER VIEW stg.vw_InvRepurchaseDemand
AS
SELECT
    RepurchaseDemandId,
    LoanNumber,
    InvestorCode,
    DemandReceivedDate,
    DemandReasonCode,
    DemandAmount,
    ResolutionDate,
    ResolutionTypeCode
FROM src.InvRepurchaseDemand;
GO

CREATE OR ALTER VIEW stg.vw_ValPropertyValuation
AS
SELECT
    PropertyValuationId,
    LoanNumber,
    ValuationDate,
    ValuationMethodCode,
    PropertyValueAmount
FROM src.ValPropertyValuation;
GO

CREATE OR ALTER VIEW stg.vw_CrmLead
AS
SELECT
    LeadId,
    LeadCreatedDate,
    LeadSourceCode,
    CampaignCode,
    ContactKey,
    PropertyStateCode,
    AssignedLoanOfficerNmlsId,
    AssignedDate,
    FirstContactDate,
    LeadStatusCode,
    ConvertedApplicationId
FROM src.CrmLead;
GO

CREATE OR ALTER VIEW stg.vw_LosApplication
AS
SELECT
    ApplicationId,
    LeadId,
    LoanOfficerNmlsId,
    AppStartedDate,
    AppCompletedDate,
    AppReceivedDate,
    LoanAmountAtApplication,
    CurrentLoanAmount,
    LoanPurposeCode,
    PurposeDetailCode,
    LoanProgramCode,
    InterestRateTypeCode,
    LienPosition,
    PropertyStateCode,
    ChannelCode,
    DispositionCode,
    DispositionDate,
    ScheduledClosingDate,
    ActualClosingDate,
    FundingDate,
    FundedFlag,
    ServicingDispositionIntentCode,
    LoanNumber
FROM src.LosApplication;
GO

CREATE OR ALTER VIEW stg.vw_PpeRateLock
AS
SELECT
    RateLockId,
    ApplicationId,
    LockDate,
    LockAmount,
    NoteRatePercent,
    LockPeriodDays,
    OriginalExpirationDate,
    CurrentExpirationDate,
    ExtensionCount,
    TotalExtensionDays,
    LockStatusCode,
    PriorLockId
FROM src.PpeRateLock;
GO

CREATE OR ALTER VIEW stg.vw_LicLoanOfficerRoster
AS
SELECT
    LoanOfficerRosterId,
    NmlsId,
    FirstName,
    LastName,
    BranchCode,
    Region,
    ManagerNmlsId,
    ChannelCode,
    EmploymentStatusCode,
    HireDate,
    TerminationDate,
    CrmUserId,
    LosUserId,
    RosterEffectiveDate,
    RosterEndDate
FROM src.LicLoanOfficerRoster;
GO

CREATE OR ALTER VIEW stg.vw_LicLoanOfficerLicense
AS
SELECT
    LoanOfficerLicenseId,
    NmlsId,
    LicenseStateCode,
    LicenseTypeCode,
    LicenseStatusCode,
    IssueDate,
    ExpirationDate,
    RenewalDeadline,
    CeRequiredHours,
    CeCompletedHours,
    CeCompletedDate
FROM src.LicLoanOfficerLicense;
GO

PRINT 'Script 015 complete: dw dims, facts, indexes,';
PRINT 'ufn_NextBusinessDate, and 22 stg contract views.';
GO
