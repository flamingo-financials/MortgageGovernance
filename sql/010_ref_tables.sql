/* ============================================================
   MortgageGovernance | Phase 4 | Script 010
   Reference layer: controlled enumerations and policy tables.
   Buckets, bands, limits, SLAs, cycles, and targets live here,
   never in CASE expressions. Idempotent (drop-and-recreate
   seed data; DDL guarded).
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

IF OBJECT_ID('ref.Holiday') IS NULL
CREATE TABLE ref.Holiday
(
    HolidayDate DATE NOT NULL,
    HolidayName NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_Holiday PRIMARY KEY CLUSTERED (HolidayDate)
);

IF OBJECT_ID('ref.State') IS NULL
CREATE TABLE ref.State
(
    StateCode CHAR(2) NOT NULL,
    StateName NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_State PRIMARY KEY CLUSTERED (StateCode)
);

IF OBJECT_ID('ref.Investor') IS NULL
CREATE TABLE ref.Investor
(
    InvestorCode VARCHAR(10) NOT NULL,
    InvestorName NVARCHAR(100) NOT NULL,
    InvestorTypeCode VARCHAR(20) NOT NULL,
    CONSTRAINT PK_Investor PRIMARY KEY CLUSTERED (InvestorCode)
);

IF OBJECT_ID('ref.ServicingType') IS NULL
CREATE TABLE ref.ServicingType
(
    ServicingTypeCode VARCHAR(30) NOT NULL,
    ServicingTypeName NVARCHAR(100) NOT NULL,
    McrLineNote NVARCHAR(200) NULL,
    CONSTRAINT PK_ServicingType
        PRIMARY KEY CLUSTERED (ServicingTypeCode)
);

IF OBJECT_ID('ref.RemittanceType') IS NULL
CREATE TABLE ref.RemittanceType
(
    RemittanceTypeCode VARCHAR(10) NOT NULL,
    RemittanceTypeName NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_RemittanceType
        PRIMARY KEY CLUSTERED (RemittanceTypeCode)
);

IF OBJECT_ID('ref.LoanStatus') IS NULL
CREATE TABLE ref.LoanStatus
(
    LoanStatusCode VARCHAR(10) NOT NULL,
    LoanStatusName NVARCHAR(100) NOT NULL,
    ActiveServicingFlag BIT NOT NULL,
    CONSTRAINT PK_LoanStatus
        PRIMARY KEY CLUSTERED (LoanStatusCode)
);

IF OBJECT_ID('ref.DelinquencyBucket') IS NULL
CREATE TABLE ref.DelinquencyBucket
(
    DelinquencyBucketCode VARCHAR(20) NOT NULL,
    DelinquencyBucketName NVARCHAR(100) NOT NULL,
    MinDpd INT NOT NULL,
    MaxDpd INT NULL,
    SortOrder INT NOT NULL,
    McrLineNote NVARCHAR(200) NULL,
    CONSTRAINT PK_DelinquencyBucket
        PRIMARY KEY CLUSTERED (DelinquencyBucketCode)
);

IF OBJECT_ID('ref.LtvBand') IS NULL
CREATE TABLE ref.LtvBand
(
    LtvBandCode VARCHAR(20) NOT NULL,
    LtvBandName NVARCHAR(100) NOT NULL,
    MinLtvPct DECIMAL(9,4) NOT NULL,
    MaxLtvPct DECIMAL(9,4) NULL,
    SortOrder INT NOT NULL,
    CONSTRAINT PK_LtvBand PRIMARY KEY CLUSTERED (LtvBandCode)
);

IF OBJECT_ID('ref.ConformingLoanLimit') IS NULL
CREATE TABLE ref.ConformingLoanLimit
(
    LimitYear INT NOT NULL,
    UnitsCount INT NOT NULL,
    LimitAmount DECIMAL(18,2) NOT NULL,
    CONSTRAINT PK_ConformingLoanLimit
        PRIMARY KEY CLUSTERED (LimitYear, UnitsCount)
);

IF OBJECT_ID('ref.SlaPolicy') IS NULL
CREATE TABLE ref.SlaPolicy
(
    SlaPolicyCode VARCHAR(30) NOT NULL,
    SlaDays INT NOT NULL,
    SlaDescription NVARCHAR(300) NOT NULL,
    EffectiveFromDate DATE NOT NULL,
    CONSTRAINT PK_SlaPolicy
        PRIMARY KEY CLUSTERED (SlaPolicyCode)
);

IF OBJECT_ID('ref.EscrowAnalysisCycle') IS NULL
CREATE TABLE ref.EscrowAnalysisCycle
(
    StateCode CHAR(2) NOT NULL,
    CycleMonth INT NOT NULL,
    CycleDescription NVARCHAR(200) NULL,
    CONSTRAINT PK_EscrowAnalysisCycle
        PRIMARY KEY CLUSTERED (StateCode)
);

IF OBJECT_ID('ref.WorkoutType') IS NULL
CREATE TABLE ref.WorkoutType
(
    WorkoutTypeCode VARCHAR(20) NOT NULL,
    WorkoutTypeName NVARCHAR(100) NOT NULL,
    RetentionFlag BIT NOT NULL,
    CONSTRAINT PK_WorkoutType
        PRIMARY KEY CLUSTERED (WorkoutTypeCode)
);

IF OBJECT_ID('ref.RunoffReason') IS NULL
CREATE TABLE ref.RunoffReason
(
    RunoffReasonCode VARCHAR(20) NOT NULL,
    RunoffReasonName NVARCHAR(100) NOT NULL,
    VoluntaryFlag BIT NOT NULL,
    CONSTRAINT PK_RunoffReason
        PRIMARY KEY CLUSTERED (RunoffReasonCode)
);

IF OBJECT_ID('ref.TaxDueMonth') IS NULL
CREATE TABLE ref.TaxDueMonth
(
    StateCode CHAR(2) NOT NULL,
    InstallmentNo INT NOT NULL,
    DueMonth INT NOT NULL,
    CONSTRAINT PK_TaxDueMonth
        PRIMARY KEY CLUSTERED (StateCode, InstallmentNo)
);

IF OBJECT_ID('ref.ScorecardTarget') IS NULL
CREATE TABLE ref.ScorecardTarget
(
    ScorecardTargetId INT IDENTITY(1,1) NOT NULL,
    MetricCode VARCHAR(10) NOT NULL,
    ScopeLevelCode VARCHAR(20) NOT NULL,
    ScopeCode VARCHAR(30) NULL,
    TargetValue DECIMAL(18,4) NOT NULL,
    DirectionCode VARCHAR(10) NOT NULL,
    Weight DECIMAL(9,4) NOT NULL,
    EffectiveFromDate DATE NOT NULL,
    EffectiveToDate DATE NULL,
    CONSTRAINT PK_ScorecardTarget
        PRIMARY KEY CLUSTERED (ScorecardTargetId),
    CONSTRAINT CK_ScorecardTarget_DirectionCode
        CHECK (DirectionCode IN ('HIGHER','LOWER')),
    CONSTRAINT CK_ScorecardTarget_ScopeLevelCode
        CHECK (ScopeLevelCode IN
               ('COMPANY','REGION','BRANCH','LO'))
);
GO

/* ---- seeds (delete and reload; small controlled tables) ---- */
DELETE FROM ref.Holiday;
INSERT INTO ref.Holiday (HolidayDate, HolidayName) VALUES
('2023-01-02','New Year Day (observed)'),
('2023-05-29','Memorial Day'),('2023-06-19','Juneteenth'),
('2023-07-04','Independence Day'),('2023-09-04','Labor Day'),
('2023-11-23','Thanksgiving'),('2023-12-25','Christmas'),
('2024-01-01','New Year Day'),('2024-05-27','Memorial Day'),
('2024-06-19','Juneteenth'),('2024-07-04','Independence Day'),
('2024-09-02','Labor Day'),('2024-11-28','Thanksgiving'),
('2024-12-25','Christmas'),
('2025-01-01','New Year Day'),('2025-05-26','Memorial Day'),
('2025-06-19','Juneteenth'),('2025-07-04','Independence Day'),
('2025-09-01','Labor Day'),('2025-11-27','Thanksgiving'),
('2025-12-25','Christmas'),
('2026-01-01','New Year Day'),('2026-05-25','Memorial Day'),
('2026-06-19','Juneteenth'),('2026-07-03','Independence Day (observed)'),
('2026-09-07','Labor Day'),('2026-11-26','Thanksgiving'),
('2026-12-25','Christmas'),
('2027-01-01','New Year Day'),('2027-05-31','Memorial Day'),
('2027-06-18','Juneteenth (observed)'),
('2027-07-05','Independence Day (observed)'),
('2027-09-06','Labor Day'),('2027-11-25','Thanksgiving'),
('2027-12-24','Christmas (observed)');

DELETE FROM ref.State;
INSERT INTO ref.State (StateCode, StateName) VALUES
('OK','Oklahoma'),('TX','Texas'),('KS','Kansas'),
('AR','Arkansas'),('MO','Missouri'),('NM','New Mexico'),
('CO','Colorado'),('LA','Louisiana'),('AZ','Arizona'),
('TN','Tennessee');

DELETE FROM ref.Investor;
INSERT INTO ref.Investor
    (InvestorCode, InvestorName, InvestorTypeCode) VALUES
('FNMA','Fannie Mae','GSE'),
('FHLMC','Freddie Mac','GSE'),
('GNMA','Ginnie Mae','GOVT'),
('PRIV1','Palmetto Private Capital','PRIVATE'),
('OTH1','Flamingo Portfolio / Other','OTHER');

DELETE FROM ref.ServicingType;
INSERT INTO ref.ServicingType
    (ServicingTypeCode, ServicingTypeName, McrLineNote) VALUES
('WHOLLY_OWNED','Wholly Owned Loans Serviced','LS010 / S510'),
('MSR_OWNED','Loans Serviced Under MSRs','LS020 / S520'),
('SUBSERV_FOR','Subserviced for Others','LS030 / S530'),
('SUBSERV_BY','Serviced by Others (Subserviced Out)',
 'LS040 / S540');

DELETE FROM ref.RemittanceType;
INSERT INTO ref.RemittanceType
    (RemittanceTypeCode, RemittanceTypeName) VALUES
('AA','Actual/Actual'),('SS','Scheduled/Scheduled'),
('SA','Scheduled/Actual');

DELETE FROM ref.LoanStatus;
INSERT INTO ref.LoanStatus
    (LoanStatusCode, LoanStatusName, ActiveServicingFlag) VALUES
('ACT','Active',1),('FC','Active - In Foreclosure',1),
('BK','Active - In Bankruptcy',1),
('FB','Active - In Forbearance',1),
('PO','Paid Off / Liquidated',0),
('SR','Service Released',0);

DELETE FROM ref.DelinquencyBucket;
INSERT INTO ref.DelinquencyBucket
    (DelinquencyBucketCode, DelinquencyBucketName, MinDpd,
     MaxDpd, SortOrder, McrLineNote) VALUES
('CURRENT','Current (under 30 DPD)',0,29,1,'LS090 basis'),
('DPD30_59','30-59 Days Past Due',30,59,2,'LS200 / S300'),
('DPD60_89','60-89 Days Past Due',60,89,3,'LS210 / S305'),
('DPD90_PLUS','90+ Days Past Due',90,NULL,4,
 'LS220-LS230 / S310-S315');

DELETE FROM ref.LtvBand;
INSERT INTO ref.LtvBand
    (LtvBandCode, LtvBandName, MinLtvPct, MaxLtvPct, SortOrder)
VALUES
('LTV_LE80','LTV 80 or below',0,0.8001,1),
('LTV_80_90','LTV 80.01 to 90',0.8001,0.9001,2),
('LTV_90_100','LTV 90.01 to 100',0.9001,1.0001,3),
('LTV_GT100','LTV above 100',1.0001,NULL,4);

DELETE FROM ref.ConformingLoanLimit;
INSERT INTO ref.ConformingLoanLimit
    (LimitYear, UnitsCount, LimitAmount) VALUES
(2015,1,417000),(2016,1,417000),(2017,1,424100),
(2018,1,453100),(2019,1,484350),(2020,1,510400),
(2021,1,548250),(2022,1,647200),(2023,1,726200),
(2024,1,766550),(2025,1,806500),(2026,1,832750);

DELETE FROM ref.SlaPolicy;
INSERT INTO ref.SlaPolicy
    (SlaPolicyCode, SlaDays, SlaDescription, EffectiveFromDate)
VALUES
('BOARDING',5,
 'Loans board within 5 days of transfer effective date',
 '2023-01-01'),
('FC_REFERRAL',30,
 'Foreclosure referral within 30 days of first legal '
 + 'eligibility','2023-01-01'),
('LEAD_ATTRIB',90,
 'Lead-to-application attribution window in days',
 '2023-01-01'),
('PAY_POSTING',1,
 'Payments post by the next business day after receipt',
 '2023-01-01');

DELETE FROM ref.EscrowAnalysisCycle;
INSERT INTO ref.EscrowAnalysisCycle
    (StateCode, CycleMonth, CycleDescription) VALUES
('OK',3,'Annual analysis due end of March'),
('TX',4,'Annual analysis due end of April'),
('KS',5,'Annual analysis due end of May'),
('AR',6,'Annual analysis due end of June'),
('MO',7,'Annual analysis due end of July'),
('NM',8,'Annual analysis due end of August'),
('CO',9,'Annual analysis due end of September'),
('LA',10,'Annual analysis due end of October'),
('AZ',2,'Annual analysis due end of February'),
('TN',11,'Annual analysis due end of November');

DELETE FROM ref.TaxDueMonth;
INSERT INTO ref.TaxDueMonth
    (StateCode, InstallmentNo, DueMonth)
SELECT s.StateCode, i.InstallmentNo,
       CASE i.InstallmentNo WHEN 1 THEN 1 ELSE 7 END
FROM ref.State s
CROSS JOIN (VALUES (1),(2)) i(InstallmentNo);

DELETE FROM ref.WorkoutType;
INSERT INTO ref.WorkoutType
    (WorkoutTypeCode, WorkoutTypeName, RetentionFlag) VALUES
('MOD','Permanent Modification',1),
('TRIAL_MOD','Trial Modification Plan',1),
('REPAY','Repayment Plan',1),
('DEFER','Payment Deferral',1),
('FORB','Forbearance Plan',1),
('SHORTSALE','Short Sale',0),
('DIL','Deed in Lieu',0);

DELETE FROM ref.RunoffReason;
INSERT INTO ref.RunoffReason
    (RunoffReasonCode, RunoffReasonName, VoluntaryFlag) VALUES
('VOL_PAYOFF','Voluntary Payoff',1),
('REFINANCE','Refinance Payoff',1),
('SHORT_SALE','Short Sale',0),
('TRANSFER_OUT','Service Released / Transferred Out',0),
('FC_SALE','Foreclosure Sale',0);

DELETE FROM ref.ScorecardTarget;
INSERT INTO ref.ScorecardTarget
    (MetricCode, ScopeLevelCode, ScopeCode, TargetValue,
     DirectionCode, Weight, EffectiveFromDate) VALUES
('M021','COMPANY',NULL,1400000,'HIGHER',20,'2023-08-01'),
('M020','COMPANY',NULL,4.0,'HIGHER',15,'2023-08-01'),
('M001','COMPANY',NULL,0.76,'HIGHER',15,'2023-08-01'),
('M022','COMPANY',NULL,0.14,'HIGHER',10,'2023-08-01'),
('M023','COMPANY',NULL,0.62,'HIGHER',10,'2023-08-01'),
('M024','COMPANY',NULL,0.22,'LOWER',10,'2023-08-01'),
('M005','COMPANY',NULL,38,'LOWER',10,'2023-08-01'),
('M059','COMPANY',NULL,0.90,'HIGHER',5,'2023-08-01'),
('M214','COMPANY',NULL,1.00,'HIGHER',5,'2023-08-01');

PRINT 'Script 010 complete: 14 reference tables created and '
    + 'seeded.';
GO
