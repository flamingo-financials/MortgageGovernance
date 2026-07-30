/* ============================================================
   MortgageGovernance | Phase 4 | Script 011
   Raw source layer DDL. System-code prefixed tables, one set
   per source system, loose typing on purpose (raw layer),
   LoadBatchId + CreatedDateUtc audit columns. No FKs across
   systems: source systems do not know about each other.
   Idempotent (guarded creates).
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

/* ---------------- BRD BoardingTape ---------------- */
IF OBJECT_ID('src.BrdBoardingBatch') IS NULL
CREATE TABLE src.BrdBoardingBatch
(
    BoardingBatchId INT IDENTITY(1,1) NOT NULL,
    BatchName NVARCHAR(200) NOT NULL,
    TransferTypeCode VARCHAR(10) NOT NULL,       -- BULK/FLOW
    TransferEffectiveDate DATE NOT NULL,
    ScheduledBoardDate DATE NOT NULL,
    PriorServicerName NVARCHAR(200) NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_BrdBoardingBatch_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_BrdBoardingBatch
        PRIMARY KEY CLUSTERED (BoardingBatchId)
);

IF OBJECT_ID('src.BrdBoardingTape') IS NULL
CREATE TABLE src.BrdBoardingTape
(
    BoardingTapeId INT IDENTITY(1,1) NOT NULL,
    BoardingBatchId INT NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    BorrowerFirstName NVARCHAR(60) NULL,
    BorrowerLastName NVARCHAR(60) NULL,
    PropertyStreet NVARCHAR(120) NULL,
    PropertyCity NVARCHAR(60) NULL,
    PropertyStateCode VARCHAR(4) NULL,
    PropertyPostalCode VARCHAR(10) NULL,
    PropertyTypeCode VARCHAR(20) NULL,
    OccupancyTypeCode VARCHAR(20) NULL,
    UnitsCount INT NULL,
    FloodZoneFlag BIT NULL,
    OriginalLoanAmount DECIMAL(18,2) NULL,
    OriginationDate DATE NULL,
    MaturityDate DATE NULL,
    NoteRatePercent DECIMAL(9,4) NULL,
    InterestRateTypeCode VARCHAR(10) NULL,       -- FIXED/ARM
    AmortizationTermMonths INT NULL,
    LienPosition INT NULL,
    HelocFlag BIT NULL,
    ReverseMortgageFlag BIT NULL,
    LoanProgramCode VARCHAR(10) NULL,  -- CONV/FHA/VA/USDA/OTH
    LoanPurposeCode VARCHAR(20) NULL,  -- PURCHASE/REFINANCE
    EscrowIndicator BIT NULL,
    ServicingTypeCode VARCHAR(30) NULL,
    RemittanceTypeCode VARCHAR(10) NULL,
    InvestorCode VARCHAR(10) NULL,
    InvestorLoanNumber VARCHAR(30) NULL,
    TapeUpbAmount DECIMAL(18,2) NULL,
    TapeInterestRatePercent DECIMAL(9,4) NULL,
    TapeNextPaymentDueDate DATE NULL,
    TapeEscrowBalanceAmount DECIMAL(18,2) NULL,
    TapeInvestorCode VARCHAR(10) NULL,
    BoardingCompletedDate DATE NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_BrdBoardingTape_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_BrdBoardingTape
        PRIMARY KEY CLUSTERED (BoardingTapeId),
    CONSTRAINT FK_BrdBoardingTape_BrdBoardingBatch
        FOREIGN KEY (BoardingBatchId)
        REFERENCES src.BrdBoardingBatch (BoardingBatchId)
);

/* ---------------- SVC CoreServ ---------------- */
IF OBJECT_ID('src.SvcLoanMaster') IS NULL
CREATE TABLE src.SvcLoanMaster
(
    LoanMasterId INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    BorrowerFirstName NVARCHAR(60) NULL,
    BorrowerLastName NVARCHAR(60) NULL,
    PropertyStreet NVARCHAR(120) NULL,
    PropertyCity NVARCHAR(60) NULL,
    PropertyStateCode VARCHAR(4) NULL,
    PropertyPostalCode VARCHAR(10) NULL,
    PropertyTypeCode VARCHAR(20) NULL,
    OccupancyTypeCode VARCHAR(20) NULL,
    UnitsCount INT NULL,
    FloodZoneFlag BIT NULL,
    OriginalLoanAmount DECIMAL(18,2) NULL,
    OriginationDate DATE NULL,
    MaturityDate DATE NULL,
    NoteRatePercent DECIMAL(9,4) NULL,
    InterestRateTypeCode VARCHAR(10) NULL,
    AmortizationTermMonths INT NULL,
    LienPosition INT NULL,
    HelocFlag BIT NULL,
    ReverseMortgageFlag BIT NULL,
    LoanProgramCode VARCHAR(10) NULL,
    LoanPurposeCode VARCHAR(20) NULL,
    EscrowIndicator BIT NULL,
    ServicingTypeCode VARCHAR(30) NULL,
    RemittanceTypeCode VARCHAR(10) NULL,
    InvestorCode VARCHAR(10) NULL,
    InvestorLoanNumber VARCHAR(30) NULL,
    BoardedDate DATE NULL,
    BoardInterestRatePercent DECIMAL(9,4) NULL,
    BoardNextPaymentDueDate DATE NULL,
    BoardUpbAmount DECIMAL(18,2) NULL,
    BoardEscrowBalanceAmount DECIMAL(18,2) NULL,
    MsrOwnerName NVARCHAR(120) NULL,
    MsrOwnerNmlsId VARCHAR(12) NULL,
    PoolNumber VARCHAR(20) NULL,
    ServiceReleasedDate DATE NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_SvcLoanMaster_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_SvcLoanMaster
        PRIMARY KEY CLUSTERED (LoanMasterId),
    CONSTRAINT UQ_SvcLoanMaster_LoanNumber UNIQUE (LoanNumber)
);

IF OBJECT_ID('src.SvcLoanMonthEnd') IS NULL
CREATE TABLE src.SvcLoanMonthEnd
(
    LoanMonthEndId BIGINT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    AsOfDate DATE NOT NULL,
    CurrentUpbAmount DECIMAL(18,2) NULL,
    BeginningUpbAmount DECIMAL(18,2) NULL,
    ScheduledPrincipalAmount DECIMAL(18,2) NULL,
    VoluntaryPrepaidPrincipalAmount DECIMAL(18,2) NULL,
    InterestRatePercent DECIMAL(9,4) NULL,
    ServicingFeeRatePercent DECIMAL(9,4) NULL,
    NextPaymentDueDate DATE NULL,
    EscrowBalanceAmount DECIMAL(18,2) NULL,
    SuspenseBalanceAmount DECIMAL(18,2) NULL,
    LoanStatusCode VARCHAR(10) NOT NULL,
    RunoffReasonCode VARCHAR(20) NULL,
    DelinquencyBucketCode VARCHAR(20) NULL,  -- source-claimed
    InvestorCode VARCHAR(10) NULL,
    ServicingTypeCode VARCHAR(30) NULL,
    RemittanceTypeCode VARCHAR(10) NULL,
    EscrowIndicator BIT NULL,
    ForbearanceFlag BIT NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_SvcLoanMonthEnd_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_SvcLoanMonthEnd
        PRIMARY KEY CLUSTERED (LoanMonthEndId),
    CONSTRAINT UQ_SvcLoanMonthEnd_Loan_AsOf
        UNIQUE (LoanNumber, AsOfDate)
);

IF OBJECT_ID('src.SvcEscrowAnalysis') IS NULL
CREATE TABLE src.SvcEscrowAnalysis
(
    EscrowAnalysisId INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    AnalysisDueDate DATE NOT NULL,
    AnalysisCompletedDate DATE NULL,
    ShortageAmount DECIMAL(18,2) NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_SvcEscrowAnalysis_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_SvcEscrowAnalysis
        PRIMARY KEY CLUSTERED (EscrowAnalysisId)
);

IF OBJECT_ID('src.SvcEscrowDisbursement') IS NULL
CREATE TABLE src.SvcEscrowDisbursement
(
    EscrowDisbursementId INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    DisbursementTypeCode VARCHAR(10) NOT NULL,   -- TAX/INS
    PayeeName NVARCHAR(120) NULL,
    DisbursedAmount DECIMAL(18,2) NULL,
    DisbursedDate DATE NULL,
    TaxDueDate DATE NULL,
    PolicyExpirationDate DATE NULL,
    AmountMatchFlag BIT NULL,
    PayeeMatchFlag BIT NULL,
    LoanMatchFlag BIT NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_SvcEscrowDisbursement_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_SvcEscrowDisbursement
        PRIMARY KEY CLUSTERED (EscrowDisbursementId)
);

IF OBJECT_ID('src.SvcInsurancePolicy') IS NULL
CREATE TABLE src.SvcInsurancePolicy
(
    InsurancePolicyId INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    PolicyTypeCode VARCHAR(10) NOT NULL,  -- HAZ/LPI/FLOOD
    PolicyEffectiveDate DATE NOT NULL,
    PolicyExpirationDate DATE NOT NULL,
    AnnualPremiumAmount DECIMAL(18,2) NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_SvcInsurancePolicy_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_SvcInsurancePolicy
        PRIMARY KEY CLUSTERED (InsurancePolicyId)
);

IF OBJECT_ID('src.SvcForbearancePlan') IS NULL
CREATE TABLE src.SvcForbearancePlan
(
    ForbearancePlanId INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    PlanStartDate DATE NOT NULL,
    PlanEndDate DATE NULL,
    PlanStatusCode VARCHAR(20) NOT NULL, -- ACTIVE/COMPLETED
    ExitDestinationCode VARCHAR(20) NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_SvcForbearancePlan_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_SvcForbearancePlan
        PRIMARY KEY CLUSTERED (ForbearancePlanId)
);

IF OBJECT_ID('src.SvcLoanModification') IS NULL
CREATE TABLE src.SvcLoanModification
(
    LoanModificationId INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    ModificationEffectiveDate DATE NOT NULL,
    ModificationBookedDate DATE NULL,
    PreModRatePercent DECIMAL(9,4) NULL,
    PostModRatePercent DECIMAL(9,4) NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_SvcLoanModification_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_SvcLoanModification
        PRIMARY KEY CLUSTERED (LoanModificationId)
);

/* ---------------- PAY PayStream ---------------- */
IF OBJECT_ID('src.PayPaymentTransaction') IS NULL
CREATE TABLE src.PayPaymentTransaction
(
    PaymentTransactionId BIGINT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    ReceivedDate DATE NOT NULL,
    PostedDate DATE NULL,
    EffectiveDate DATE NULL,
    PaymentAmount DECIMAL(18,2) NOT NULL,
    PrincipalAmount DECIMAL(18,2) NULL,
    InterestAmount DECIMAL(18,2) NULL,
    EscrowAmount DECIMAL(18,2) NULL,
    FeeAmount DECIMAL(18,2) NULL,
    SuspenseFlag BIT NOT NULL
        CONSTRAINT DF_PayPaymentTransaction_SuspenseFlag
        DEFAULT 0,
    ReversalFlag BIT NOT NULL
        CONSTRAINT DF_PayPaymentTransaction_ReversalFlag
        DEFAULT 0,
    OriginalTransactionId BIGINT NULL,
    ChannelCode VARCHAR(20) NULL,   -- ACH/WEB/PHONE/MAIL
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_PayPaymentTransaction_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_PayPaymentTransaction
        PRIMARY KEY CLUSTERED (PaymentTransactionId)
);

/* ---------------- DMS DefaultTrack ---------------- */
IF OBJECT_ID('src.DmsLossMitigationCase') IS NULL
CREATE TABLE src.DmsLossMitigationCase
(
    LossMitCaseId INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    AppReceivedDate DATE NOT NULL,
    CompletePackageDate DATE NULL,
    DecisionDate DATE NULL,
    DecisionCode VARCHAR(20) NULL,
    WorkoutTypeCode VARCHAR(20) NULL,
    TrialStartDate DATE NULL,
    TrialCompletedDate DATE NULL,
    TrialConvertedFlag BIT NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DmsLossMitigationCase_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_DmsLossMitigationCase
        PRIMARY KEY CLUSTERED (LossMitCaseId)
);

IF OBJECT_ID('src.DmsForeclosureCase') IS NULL
CREATE TABLE src.DmsForeclosureCase
(
    ForeclosureCaseId INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    FirstLegalEligibleDate DATE NOT NULL,
    ReferralDate DATE NULL,
    FirstLegalDate DATE NULL,
    SaleScheduledDate DATE NULL,
    SaleHeldDate DATE NULL,
    CaseStatusCode VARCHAR(10) NOT NULL,  -- OPEN/CLOSED
    ResolutionTypeCode VARCHAR(20) NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DmsForeclosureCase_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_DmsForeclosureCase
        PRIMARY KEY CLUSTERED (ForeclosureCaseId)
);

IF OBJECT_ID('src.DmsBankruptcyCase') IS NULL
CREATE TABLE src.DmsBankruptcyCase
(
    BankruptcyCaseId INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    ChapterCode VARCHAR(5) NOT NULL,      -- 7/13
    PetitionDate DATE NOT NULL,
    PocBarDate DATE NULL,
    PocFiledDate DATE NULL,
    CaseStatusCode VARCHAR(10) NOT NULL,
    DispositionCode VARCHAR(20) NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DmsBankruptcyCase_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_DmsBankruptcyCase
        PRIMARY KEY CLUSTERED (BankruptcyCaseId)
);

/* ---------------- INV InvestorLink ---------------- */
IF OBJECT_ID('src.InvLoanReport') IS NULL
CREATE TABLE src.InvLoanReport
(
    InvLoanReportId BIGINT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    InvestorCode VARCHAR(10) NOT NULL,
    ReportingPeriod INT NOT NULL,          -- yyyymm
    ReportingDeadlineDate DATE NOT NULL,
    ReportSubmittedDate DATE NULL,
    AcceptedFlag BIT NULL,
    ErrorCount INT NULL,
    ReportedTransactionCount INT NULL,
    CorrectionResubmissionFlag BIT NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_InvLoanReport_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_InvLoanReport
        PRIMARY KEY CLUSTERED (InvLoanReportId)
);

IF OBJECT_ID('src.InvRemittance') IS NULL
CREATE TABLE src.InvRemittance
(
    InvRemittanceId INT IDENTITY(1,1) NOT NULL,
    InvestorCode VARCHAR(10) NOT NULL,
    RemittancePeriod INT NOT NULL,
    RemittanceDueDate DATE NOT NULL,
    RemittanceSentDate DATE NULL,
    RemittanceAmount DECIMAL(18,2) NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_InvRemittance_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_InvRemittance
        PRIMARY KEY CLUSTERED (InvRemittanceId)
);

IF OBJECT_ID('src.InvRepurchaseDemand') IS NULL
CREATE TABLE src.InvRepurchaseDemand
(
    RepurchaseDemandId INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    InvestorCode VARCHAR(10) NOT NULL,
    DemandReceivedDate DATE NOT NULL,
    DemandReasonCode VARCHAR(30) NULL,
    DemandAmount DECIMAL(18,2) NULL,
    ResolutionDate DATE NULL,
    ResolutionTypeCode VARCHAR(20) NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_InvRepurchaseDemand_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_InvRepurchaseDemand
        PRIMARY KEY CLUSTERED (RepurchaseDemandId)
);

/* ---------------- VAL CollateralVal ---------------- */
IF OBJECT_ID('src.ValPropertyValuation') IS NULL
CREATE TABLE src.ValPropertyValuation
(
    PropertyValuationId INT IDENTITY(1,1) NOT NULL,
    LoanNumber VARCHAR(20) NOT NULL,
    ValuationDate DATE NOT NULL,
    ValuationMethodCode VARCHAR(20) NOT NULL, -- AVM/BPO/APPR
    PropertyValueAmount DECIMAL(18,2) NOT NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_ValPropertyValuation_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ValPropertyValuation
        PRIMARY KEY CLUSTERED (PropertyValuationId)
);

/* ---------------- CRM LagoonCRM ---------------- */
IF OBJECT_ID('src.CrmLead') IS NULL
CREATE TABLE src.CrmLead
(
    LeadId INT IDENTITY(1,1) NOT NULL,
    LeadCreatedDate DATE NOT NULL,
    LeadSourceCode VARCHAR(30) NULL,
    CampaignCode VARCHAR(30) NULL,
    ContactKey VARCHAR(40) NOT NULL,
    PropertyStateCode VARCHAR(4) NULL,
    AssignedLoanOfficerNmlsId VARCHAR(12) NULL,
    AssignedDate DATE NULL,
    FirstContactDate DATE NULL,
    LeadStatusCode VARCHAR(20) NOT NULL,
    ConvertedApplicationId INT NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_CrmLead_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_CrmLead PRIMARY KEY CLUSTERED (LeadId)
);

/* ---------------- LOS MangoLOS ---------------- */
IF OBJECT_ID('src.LosApplication') IS NULL
CREATE TABLE src.LosApplication
(
    ApplicationId INT IDENTITY(1,1) NOT NULL,
    LeadId INT NULL,
    LoanOfficerNmlsId VARCHAR(12) NOT NULL,
    AppStartedDate DATE NOT NULL,
    AppCompletedDate DATE NULL,
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
    FundingDate DATE NULL,
    FundedFlag BIT NOT NULL
        CONSTRAINT DF_LosApplication_FundedFlag DEFAULT 0,
    ServicingDispositionIntentCode VARCHAR(20) NULL,
    LoanNumber VARCHAR(20) NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_LosApplication_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_LosApplication
        PRIMARY KEY CLUSTERED (ApplicationId)
);

/* ---------------- PPE PalmLock ---------------- */
IF OBJECT_ID('src.PpeRateLock') IS NULL
CREATE TABLE src.PpeRateLock
(
    RateLockId INT IDENTITY(1,1) NOT NULL,
    ApplicationId INT NOT NULL,
    LockDate DATE NOT NULL,
    LockAmount DECIMAL(18,2) NOT NULL,
    NoteRatePercent DECIMAL(9,4) NULL,
    LockPeriodDays INT NOT NULL,
    OriginalExpirationDate DATE NOT NULL,
    CurrentExpirationDate DATE NOT NULL,
    ExtensionCount INT NOT NULL
        CONSTRAINT DF_PpeRateLock_ExtensionCount DEFAULT 0,
    TotalExtensionDays INT NOT NULL
        CONSTRAINT DF_PpeRateLock_TotalExtensionDays DEFAULT 0,
    LockStatusCode VARCHAR(20) NOT NULL,
    PriorLockId INT NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_PpeRateLock_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_PpeRateLock
        PRIMARY KEY CLUSTERED (RateLockId)
);

/* ---------------- LIC NmlsFeed ---------------- */
IF OBJECT_ID('src.LicLoanOfficerRoster') IS NULL
CREATE TABLE src.LicLoanOfficerRoster
(
    LoanOfficerRosterId INT IDENTITY(1,1) NOT NULL,
    NmlsId VARCHAR(12) NOT NULL,
    FirstName NVARCHAR(60) NOT NULL,
    LastName NVARCHAR(60) NOT NULL,
    BranchCode VARCHAR(10) NOT NULL,
    Region NVARCHAR(40) NOT NULL,
    ManagerNmlsId VARCHAR(12) NULL,
    ChannelCode VARCHAR(20) NOT NULL,
    EmploymentStatusCode VARCHAR(20) NOT NULL,
    HireDate DATE NOT NULL,
    TerminationDate DATE NULL,
    CrmUserId VARCHAR(20) NULL,
    LosUserId VARCHAR(20) NULL,
    RosterEffectiveDate DATE NOT NULL,
    RosterEndDate DATE NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_LicLoanOfficerRoster_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_LicLoanOfficerRoster
        PRIMARY KEY CLUSTERED (LoanOfficerRosterId)
);

IF OBJECT_ID('src.LicLoanOfficerLicense') IS NULL
CREATE TABLE src.LicLoanOfficerLicense
(
    LoanOfficerLicenseId INT IDENTITY(1,1) NOT NULL,
    NmlsId VARCHAR(12) NOT NULL,
    LicenseStateCode CHAR(2) NOT NULL,
    LicenseTypeCode VARCHAR(20) NOT NULL,
    LicenseStatusCode VARCHAR(20) NOT NULL,
    IssueDate DATE NOT NULL,
    ExpirationDate DATE NOT NULL,
    RenewalDeadline DATE NOT NULL,
    CeRequiredHours DECIMAL(6,2) NOT NULL,
    CeCompletedHours DECIMAL(6,2) NULL,
    CeCompletedDate DATE NULL,
    LoadBatchId INT NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_LicLoanOfficerLicense_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_LicLoanOfficerLicense
        PRIMARY KEY CLUSTERED (LoanOfficerLicenseId)
);
GO

/* helpful indexes for generation and loads */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_SvcLoanMonthEnd_AsOfDate')
CREATE INDEX IX_SvcLoanMonthEnd_AsOfDate
    ON src.SvcLoanMonthEnd (AsOfDate) INCLUDE (LoanNumber);
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_PayPaymentTransaction_Loan')
CREATE INDEX IX_PayPaymentTransaction_Loan
    ON src.PayPaymentTransaction (LoanNumber, ReceivedDate);
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'IX_PpeRateLock_ApplicationId')
CREATE INDEX IX_PpeRateLock_ApplicationId
    ON src.PpeRateLock (ApplicationId);
GO

PRINT 'Script 011 complete: 22 source tables created across '
    + '10 systems.';
GO
