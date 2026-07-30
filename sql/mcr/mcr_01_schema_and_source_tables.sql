/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_01_schema_and_source_tables.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT (FULL SCHEMA)
   01 - Database, schema, fictional source tables, and sample data
   ----------------------------------------------------------------------------
   Target: SQL Server 2017+ (uses STRING_AGG).
   Run order: file numbers are the run order (01 -> 10; see 00_README.md).
   Everything here is FICTIONAL sample data.

   Changes vs the subset toolkit:
     - mcrstg.ClosedLoans.HoepaStatus       (drives AC400 HOEPA)
     - mcrstg.Investors                     (NMLS ID + name for the Section III
                                          investor detail lists S520/S530/S540)
   ============================================================================ */

IF SCHEMA_ID('mcr') IS NULL EXEC('CREATE SCHEMA mcr;');
GO
IF SCHEMA_ID('mcrstg') IS NULL EXEC('CREATE SCHEMA mcrstg;');
GO
IF SCHEMA_ID('mcrpbi') IS NULL EXEC('CREATE SCHEMA mcrpbi;');
GO

IF OBJECT_ID('mcr.Filing') IS NOT NULL DROP TABLE mcr.Filing;
GO
CREATE TABLE mcr.Filing (
    FilingId         INT          NOT NULL PRIMARY KEY,
    CompanyNmlsId    BIGINT       NOT NULL,
    CompanyName      VARCHAR(150) NOT NULL,
    FilerType        CHAR(1)      NOT NULL,   -- Mcr 'type' attribute; XSD permits 'E' (company) only
    FormVersion      VARCHAR(5)   NOT NULL DEFAULT 'v7',  -- Mcr formVersion attribute
    [Year]           INT          NOT NULL,
    PeriodType       VARCHAR(10)  NOT NULL,
    PeriodStart      DATE         NOT NULL,
    PeriodEnd        DATE         NOT NULL,
    PrimaryStateCode CHAR(2)      NOT NULL,
    PriorFilingId    INT          NULL,
    CONSTRAINT CK_Filing_FilerType CHECK (FilerType IN ('E')),
    CONSTRAINT CK_Filing_Period CHECK (PeriodType IN ('MCRQ1','MCRQ2','MCRQ3','MCRQ4','MCRANNUAL'))
);
GO

IF OBJECT_ID('mcrstg.Applications') IS NOT NULL DROP TABLE mcrstg.Applications;
GO
CREATE TABLE mcrstg.Applications (
    ApplicationId    BIGINT       NOT NULL PRIMARY KEY,
    FilingId         INT          NOT NULL,
    StateCode        CHAR(2)      NOT NULL,
    AppDate          DATE         NOT NULL,
    DecisionStatus   VARCHAR(30)  NOT NULL,   -- InProcessBOP, Received, ApprovedNotAccepted,
                                              -- Denied, Withdrawn, FileClosedIncomplete,
                                              -- ClosedFunded, InProcessEOP
    SourceChannel    VARCHAR(20)  NOT NULL,   -- DirectBorrower (cols 1/2), ThirdParty (cols 3/4)
    AppAmount        BIGINT       NOT NULL
);
GO

IF OBJECT_ID('mcrstg.ClosedLoans') IS NOT NULL DROP TABLE mcrstg.ClosedLoans;
GO
CREATE TABLE mcrstg.ClosedLoans (
    LoanId           BIGINT       NOT NULL PRIMARY KEY,
    FilingId         INT          NOT NULL,
    StateCode        CHAR(2)      NOT NULL,
    CloseDate        DATE         NOT NULL,
    Channel          VARCHAR(20)  NOT NULL,   -- Brokered (cols 1/2), ClosedRetail (3/4), ClosedWholesale (5/6)
    LoanType         VARCHAR(20)  NOT NULL,   -- Conventional, FHA, VA, FSARHS
    PropertyType     VARCHAR(20)  NOT NULL,   -- OneToFour, Manufactured
    Purpose          VARCHAR(20)  NOT NULL,   -- Purchase, HomeImprovement, Refinance
    LienStatus       VARCHAR(20)  NOT NULL,   -- First, Subordinate, NoLien
    HoepaStatus      VARCHAR(10)  NOT NULL,   -- HOEPA, NotHOEPA
    AmortType        VARCHAR(10)  NOT NULL,   -- Fixed, ARM
    Conforming       VARCHAR(20)  NOT NULL,   -- Conforming, Jumbo, Government, Other
    QmStatus         VARCHAR(20)  NOT NULL,   -- QM, NonQM, NotSubject
    ServicingDispo   VARCHAR(20)  NOT NULL,   -- Retained (AC1200), Released (AC1210), NA (brokered)
    UPB              BIGINT       NOT NULL,
    NoteAmount       BIGINT       NOT NULL,
    AppraisedValue   BIGINT       NOT NULL,
    FicoScore        INT          NULL,
    NoteRatePct      DECIMAL(6,3) NULL,
    MloNmlsId        BIGINT       NOT NULL
);
GO

IF OBJECT_ID('mcrstg.Investors') IS NOT NULL DROP TABLE mcrstg.Investors;
GO
CREATE TABLE mcrstg.Investors (
    InvestorCode     VARCHAR(20)  NOT NULL PRIMARY KEY,  -- FNMA, FHLMC, GNMA, PrivateLabel, Other
    InvestorNmlsId   BIGINT       NOT NULL,              -- fictional
    InvestorName     VARCHAR(150) NOT NULL,
    PoolNumber       VARCHAR(30)  NULL
);
GO

IF OBJECT_ID('mcrstg.ServicingPortfolio') IS NOT NULL DROP TABLE mcrstg.ServicingPortfolio;
GO
CREATE TABLE mcrstg.ServicingPortfolio (
    ServiceId        BIGINT       NOT NULL PRIMARY KEY,
    FilingId         INT          NOT NULL,
    StateCode        CHAR(2)      NOT NULL,
    OwnershipType    VARCHAR(30)  NOT NULL,   -- WhollyOwned, UnderMSR, SubservicingForOthers, SubservicedByOthers
    Investor         VARCHAR(20)  NOT NULL REFERENCES mcrstg.Investors(InvestorCode),
    DelinquencyBucket VARCHAR(10) NOT NULL,   -- LT30, D30_59, D60_89, D90Plus
    InForeclosure    BIT          NOT NULL DEFAULT 0,
    UPB              BIGINT       NOT NULL
);
GO

IF OBJECT_ID('mcrstg.ServicingTransfers') IS NOT NULL DROP TABLE mcrstg.ServicingTransfers;
GO
CREATE TABLE mcrstg.ServicingTransfers (
    TransferId       BIGINT       NOT NULL PRIMARY KEY,
    FilingId         INT          NOT NULL,
    Direction        VARCHAR(4)   NOT NULL,   -- In, Out
    UPB              BIGINT       NOT NULL,
    LoanCount        INT          NOT NULL
);
GO

IF OBJECT_ID('mcrstg.WarehouseLines') IS NOT NULL DROP TABLE mcrstg.WarehouseLines;
GO
CREATE TABLE mcrstg.WarehouseLines (
    LineId           INT          NOT NULL PRIMARY KEY,
    FilingId         INT          NOT NULL,
    ProviderName     VARCHAR(150) NOT NULL,
    CreditLimit      BIGINT       NOT NULL,
    RemainingCredit  BIGINT       NOT NULL
);
GO

IF OBJECT_ID('mcrstg.Repurchases') IS NOT NULL DROP TABLE mcrstg.Repurchases;
GO
CREATE TABLE mcrstg.Repurchases (
    RepurchaseId     BIGINT       NOT NULL PRIMARY KEY,
    FilingId         INT          NOT NULL,
    StateCode        CHAR(2)      NOT NULL,
    Investor         VARCHAR(20)  NOT NULL,
    UPB              BIGINT       NOT NULL,
    LoanCount        INT          NOT NULL
);
GO

/* ============================================================================
   SAMPLE DATA - filing 2026001 (Q1 2026, OK + TX), prior filing 2025004
   FilingId convention: YYYYQ0N (2026001 = 2026 Q1); 9000-9999 reserved for tests
   ============================================================================ */
INSERT INTO mcr.Filing
(FilingId, CompanyNmlsId, CompanyName, FilerType, FormVersion, [Year], PeriodType, PeriodStart, PeriodEnd, PrimaryStateCode, PriorFilingId)
VALUES
(2026001, 1820999, 'Fictional Mortgage Co', 'E', 'v7', 2026, 'MCRQ1', '2026-01-01', '2026-03-31', 'OK', 2025004),
(2025004, 1820999, 'Fictional Mortgage Co', 'E', 'v7', 2025, 'MCRQ4', '2025-10-01', '2025-12-31', 'OK', NULL);

INSERT INTO mcrstg.Investors (InvestorCode, InvestorNmlsId, InvestorName, PoolNumber) VALUES
('FNMA',        900001, 'Fictional National Mtg Assoc', 'FN-2026-01'),
('FHLMC',       900002, 'Fictional Home Loan Corp',     'FH-2026-01'),
('GNMA',        900003, 'Fictional Gov Mtg Assoc',      'GN-2026-01'),
('PrivateLabel',900004, 'Fictional Private Investor',   'PL-2026-01'),
('Other',       900005, 'Fictional Other Investor',     NULL);

INSERT INTO mcrstg.Applications (ApplicationId, FilingId, StateCode, AppDate, DecisionStatus, SourceChannel, AppAmount) VALUES
(1, 2026001,'OK','2025-12-31','InProcessBOP','DirectBorrower', 250000),
(2, 2026001,'OK','2026-01-10','Received','DirectBorrower',      300000),
(3, 2026001,'OK','2026-01-15','Received','ThirdParty',          280000),
(4, 2026001,'OK','2026-02-01','Denied','DirectBorrower',        150000),
(5, 2026001,'OK','2026-02-12','Withdrawn','DirectBorrower',     220000),
(6, 2026001,'OK','2026-02-20','ClosedFunded','DirectBorrower',  300000),
(7, 2026001,'OK','2026-03-05','ClosedFunded','ThirdParty',      280000),
(8, 2026001,'OK','2026-03-28','InProcessEOP','DirectBorrower',  250000),
(9, 2026001,'TX','2025-12-31','InProcessBOP','DirectBorrower',  400000),
(10,2026001,'TX','2026-01-08','Received','ThirdParty',          500000),
(11,2026001,'TX','2026-02-02','ApprovedNotAccepted','DirectBorrower', 350000),
(12,2026001,'TX','2026-02-18','ClosedFunded','DirectBorrower',  400000),
(13,2026001,'TX','2026-03-22','InProcessEOP','ThirdParty',      500000);

INSERT INTO mcrstg.ClosedLoans
(LoanId, FilingId, StateCode, CloseDate, Channel, LoanType, PropertyType, Purpose, LienStatus, HoepaStatus, AmortType, Conforming, QmStatus, ServicingDispo, UPB, NoteAmount, AppraisedValue, FicoScore, NoteRatePct, MloNmlsId) VALUES
(101,2026001,'OK','2026-02-20','ClosedRetail','Conventional','OneToFour','Purchase','First','NotHOEPA','Fixed','Conforming','QM','Retained', 300000,300000,375000,742,6.625,55501),
(102,2026001,'OK','2026-03-05','ClosedWholesale','FHA','OneToFour','Refinance','First','NotHOEPA','Fixed','Government','QM','Released', 280000,280000,330000,701,6.875,55502),
(103,2026001,'TX','2026-02-18','ClosedRetail','Conventional','OneToFour','Purchase','First','NotHOEPA','ARM','Jumbo','NonQM','Retained', 400000,400000,560000,780,7.125,55503);

INSERT INTO mcrstg.ServicingPortfolio (ServiceId, FilingId, StateCode, OwnershipType, Investor, DelinquencyBucket, InForeclosure, UPB) VALUES
(201,2026001,'OK','WhollyOwned','FNMA','LT30',   0, 1200000),
(202,2026001,'OK','WhollyOwned','FNMA','D30_59', 0,  150000),
(203,2026001,'OK','UnderMSR','FHLMC','LT30',     0,  900000),
(204,2026001,'OK','UnderMSR','FHLMC','D90Plus',  1,  120000),
(205,2026001,'TX','WhollyOwned','GNMA','LT30',   0,  800000),
(206,2026001,'TX','SubservicingForOthers','PrivateLabel','D60_89', 0, 200000);

INSERT INTO mcrstg.ServicingTransfers (TransferId, FilingId, Direction, UPB, LoanCount) VALUES
(301,2026001,'In', 500000, 4),
(302,2026001,'Out',300000, 2);

INSERT INTO mcrstg.WarehouseLines (LineId, FilingId, ProviderName, CreditLimit, RemainingCredit) VALUES
(401,2026001,'Fictional Warehouse Bank A',50000000,42000000),
(402,2026001,'Fictional Warehouse Bank B',25000000,25000000);

INSERT INTO mcrstg.Repurchases (RepurchaseId, FilingId, StateCode, Investor, UPB, LoanCount) VALUES
(501,2026001,'OK','FNMA',180000,1);

/* prior quarter so QoQ variance has a baseline */
INSERT INTO mcrstg.Applications (ApplicationId, FilingId, StateCode, AppDate, DecisionStatus, SourceChannel, AppAmount) VALUES
(9001,2025004,'OK','2025-12-15','ClosedFunded','DirectBorrower',295000),
(9002,2025004,'OK','2025-12-20','ClosedFunded','DirectBorrower',310000);
INSERT INTO mcrstg.ClosedLoans
(LoanId, FilingId, StateCode, CloseDate, Channel, LoanType, PropertyType, Purpose, LienStatus, HoepaStatus, AmortType, Conforming, QmStatus, ServicingDispo, UPB, NoteAmount, AppraisedValue, FicoScore, NoteRatePct, MloNmlsId) VALUES
(9101,2025004,'OK','2025-12-15','ClosedRetail','Conventional','OneToFour','Purchase','First','NotHOEPA','Fixed','Conforming','QM','Retained',295000,295000,360000,738,6.500,55501),
(9102,2025004,'OK','2025-12-20','ClosedRetail','Conventional','OneToFour','Purchase','First','NotHOEPA','Fixed','Conforming','QM','Retained',310000,310000,388000,755,6.550,55501);
GO

PRINT '01 complete: database, schema, source tables, and sample data created.';
GO
