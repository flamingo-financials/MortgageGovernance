/* ============================================================
   MortgageGovernance | Phase 5b | Script 014
   Deterministic synthetic data generation for all 10 source
   systems: E1 production funnel (LO roster, licenses, leads,
   applications, locks) plus the servicing book (boarding,
   month-end snapshots, payments, escrow, default cases,
   investor reporting, valuations). 36 month-ends, Aug 2023
   through Jul 2026.

   No RAND(): every value derives from
   ABS(CHECKSUM('salt', key)), so the dataset regenerates
   deterministically. All 20 registered defects are injected
   here and their exact keys are written to
   dq.SyntheticDefectTruth for precision/recall scoring.

   Identity alignment: tables are truncated (identity reseeds
   to 1) and inserted with ORDER BY on a generated sequence,
   so surrogate ids equal the generation sequence. Defect
   truth formulas rely on that alignment.

   Amortization note: UPB paths use a deterministic 0.25%
   per month principal approximation, not payment-exact
   amortization. Controls and metrics are designed around
   the generated data, so reconciliations bind exactly.
   - DBCC CHECKIDENT RESEED 0 on a never-used identity starts
  at 0, not 1. Reseed conditionally: only when
  sys.identity_columns.last_value IS NOT NULL.
   Idempotent full regenerate. Runtime: 2-6 minutes local.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @LoadBatchId INT;
DECLARE @BatchNotes NVARCHAR(400) =
    N'Script 014: deterministic generation, 36 '
  + N'month-ends, 20 defects injected with truth.';
EXEC audit.usp_StartLoadBatch
     @BatchName = N'Synthetic enterprise data generation',
     @BatchTypeCode = 'FULL',
     @Notes = @BatchNotes,
     @LoadBatchId = @LoadBatchId OUTPUT;

BEGIN TRY

/* ---------------- reset ---------------- */
DELETE FROM src.BrdBoardingTape;
DELETE FROM src.BrdBoardingBatch;
IF (SELECT last_value FROM sys.identity_columns
    WHERE object_id =
          OBJECT_ID('src.BrdBoardingTape'))
   IS NOT NULL
    DBCC CHECKIDENT
        ('src.BrdBoardingTape', RESEED, 0);
IF (SELECT last_value FROM sys.identity_columns
    WHERE object_id =
          OBJECT_ID('src.BrdBoardingBatch'))
   IS NOT NULL
    DBCC CHECKIDENT
        ('src.BrdBoardingBatch', RESEED, 0);
TRUNCATE TABLE src.SvcLoanMonthEnd;
DELETE FROM src.SvcLoanMaster;
IF (SELECT last_value FROM sys.identity_columns
    WHERE object_id =
          OBJECT_ID('src.SvcLoanMaster'))
   IS NOT NULL
    DBCC CHECKIDENT
        ('src.SvcLoanMaster', RESEED, 0);
TRUNCATE TABLE src.SvcEscrowAnalysis;
TRUNCATE TABLE src.SvcEscrowDisbursement;
TRUNCATE TABLE src.SvcInsurancePolicy;
TRUNCATE TABLE src.SvcForbearancePlan;
TRUNCATE TABLE src.SvcLoanModification;
TRUNCATE TABLE src.PayPaymentTransaction;
TRUNCATE TABLE src.DmsLossMitigationCase;
TRUNCATE TABLE src.DmsForeclosureCase;
TRUNCATE TABLE src.DmsBankruptcyCase;
TRUNCATE TABLE src.InvLoanReport;
TRUNCATE TABLE src.InvRemittance;
TRUNCATE TABLE src.InvRepurchaseDemand;
TRUNCATE TABLE src.ValPropertyValuation;
TRUNCATE TABLE src.CrmLead;
TRUNCATE TABLE src.LosApplication;
TRUNCATE TABLE src.PpeRateLock;
TRUNCATE TABLE src.LicLoanOfficerRoster;
TRUNCATE TABLE src.LicLoanOfficerLicense;
TRUNCATE TABLE dq.SyntheticDefectTruth;

/* ---------------- helpers ---------------- */
DROP TABLE IF EXISTS #Num;
SELECT TOP (400000)
       ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N
INTO #Num
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

DROP TABLE IF EXISTS #Month;
SELECT N AS MonthIx,
       DATEADD(MONTH, N - 1, '2023-08-01') AS MonthStart,
       EOMONTH(DATEADD(MONTH, N - 1, '2023-08-01'))
           AS AsOfDate,
       YEAR(DATEADD(MONTH, N - 1, '2023-08-01')) * 100
         + MONTH(DATEADD(MONTH, N - 1, '2023-08-01'))
         AS PeriodKey
INTO #Month
FROM #Num WHERE N <= 36;

/* ============================================================
   1. LIC: LO roster (45) and licenses; 6 LOs change branch
   ============================================================ */
DROP TABLE IF EXISTS #Lo;
SELECT N AS LoSeq,
       'FL300' + RIGHT('0' + CAST(N AS VARCHAR(2)), 2)
           AS NmlsId,
       CHOOSE(1 + ABS(CHECKSUM('LOFN', N)) % 15,
        'Avery','Jordan','Riley','Casey','Morgan','Quinn',
        'Reese','Rowan','Skyler','Emerson','Finley','Harper',
        'Kendall','Logan','Parker') AS FirstName,
       CHOOSE(1 + ABS(CHECKSUM('LOLN', N)) % 15,
        'Ibisario','Egretson','Heronsby','Tealman','Cranewell',
        'Ploverton','Kitely','Bitterns','Curlewis','Whimbrell',
        'Sandpiper','Pelicano','Spoonhill','Stiltner',
        'Avocett') AS LastName,
       'B0' + CAST(1 + ABS(CHECKSUM('LOBR', N)) % 6
           AS VARCHAR(1)) AS BranchCode,
       DATEADD(MONTH, -(6 + ABS(CHECKSUM('LOHD', N)) % 90),
           '2023-08-01') AS HireDate
INTO #Lo
FROM #Num WHERE N <= 45;

INSERT INTO src.LicLoanOfficerRoster
    (NmlsId, FirstName, LastName, BranchCode, Region,
     ManagerNmlsId, ChannelCode, EmploymentStatusCode,
     HireDate, CrmUserId, LosUserId, RosterEffectiveDate,
     RosterEndDate, LoadBatchId)
SELECT NmlsId, FirstName, LastName, BranchCode,
       CASE WHEN BranchCode IN ('B01','B02') THEN 'Central'
            WHEN BranchCode IN ('B03','B04') THEN 'South'
            ELSE 'West' END,
       'FL30001', 'RETAIL', 'ACTIVE', HireDate,
       'CRM' + NmlsId, 'LOS' + NmlsId, HireDate,
       CASE WHEN LoSeq % 8 = 3 THEN '2024-12-31' END,
       @LoadBatchId
FROM #Lo ORDER BY LoSeq;

INSERT INTO src.LicLoanOfficerRoster
    (NmlsId, FirstName, LastName, BranchCode, Region,
     ManagerNmlsId, ChannelCode, EmploymentStatusCode,
     HireDate, CrmUserId, LosUserId, RosterEffectiveDate,
     RosterEndDate, LoadBatchId)
SELECT NmlsId, FirstName, LastName,
       'B0' + CAST(1 + (CAST(RIGHT(BranchCode,1) AS INT) % 6)
           AS VARCHAR(1)),
       CASE WHEN BranchCode IN ('B06','B01') THEN 'Central'
            WHEN BranchCode IN ('B02','B03') THEN 'South'
            ELSE 'West' END,
       'FL30001', 'RETAIL', 'ACTIVE', HireDate,
       'CRM' + NmlsId, 'LOS' + NmlsId,
       '2025-01-01', NULL, @LoadBatchId
FROM #Lo WHERE LoSeq % 8 = 3 ORDER BY LoSeq;

INSERT INTO src.LicLoanOfficerLicense
    (NmlsId, LicenseStateCode, LicenseTypeCode,
     LicenseStatusCode, IssueDate, ExpirationDate,
     RenewalDeadline, CeRequiredHours, CeCompletedHours,
     CeCompletedDate, LoadBatchId)
SELECT l.NmlsId, s.StateCode, 'MLO',
       CASE WHEN l.NmlsId IN ('FL30007','FL30021')
             AND s.StateCode = 'TX'
            THEN 'EXPIRED' ELSE 'ACTIVE' END,
       DATEADD(YEAR, -3, '2026-01-01'),
       CASE WHEN l.NmlsId IN ('FL30007','FL30021')
             AND s.StateCode = 'TX'
            THEN '2025-12-31' ELSE '2026-12-31' END,
       '2026-12-01', 8,
       CASE WHEN ABS(CHECKSUM('CE', l.NmlsId, s.StateCode))
                 % 100 < 90 THEN 8 ELSE 4 END,
       CASE WHEN ABS(CHECKSUM('CE', l.NmlsId, s.StateCode))
                 % 100 < 90 THEN '2025-11-15' END,
       @LoadBatchId
FROM #Lo l
JOIN ref.State s
  ON s.StateCode = 'OK'
  OR (s.StateCode = 'TX'
      AND ABS(CHECKSUM('LTX', l.NmlsId)) % 100 < 75)
  OR (s.StateCode = 'KS'
      AND ABS(CHECKSUM('LKS', l.NmlsId)) % 100 < 35)
  OR (s.StateCode = 'AR'
      AND ABS(CHECKSUM('LAR', l.NmlsId)) % 100 < 30)
  OR (s.StateCode = 'CO'
      AND ABS(CHECKSUM('LCO', l.NmlsId)) % 100 < 25)
  OR (s.StateCode = 'AZ'
      AND ABS(CHECKSUM('LAZ', l.NmlsId)) % 100 < 20)
ORDER BY l.LoSeq, s.StateCode;

INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
VALUES ('DEF19','FL30007'), ('DEF19','FL30021');

/* ============================================================
   2. CRM leads: 2,400 per month
      LeadId = LeadSeq (truncate + ordered insert)
   ============================================================ */
DROP TABLE IF EXISTS #Lead;
SELECT (m.MonthIx - 1) * 2400 + x.N AS LeadSeq,
       m.MonthIx,
       DATEADD(DAY, ABS(CHECKSUM('LDD', m.MonthIx, x.N)) % 28,
               m.MonthStart) AS LeadCreatedDate,
       CASE
         WHEN ABS(CHECKSUM('LSRC', m.MonthIx, x.N)) % 100 < 28
              THEN 'PAID_MEDIA'
         WHEN ABS(CHECKSUM('LSRC', m.MonthIx, x.N)) % 100 < 42
              THEN 'ORGANIC_WEB'
         WHEN ABS(CHECKSUM('LSRC', m.MonthIx, x.N)) % 100 < 58
              THEN 'AGGREGATOR'
         WHEN ABS(CHECKSUM('LSRC', m.MonthIx, x.N)) % 100 < 70
              THEN 'REF_AGENT'
         WHEN ABS(CHECKSUM('LSRC', m.MonthIx, x.N)) % 100 < 78
              THEN 'REF_BUILDER'
         WHEN ABS(CHECKSUM('LSRC', m.MonthIx, x.N)) % 100 < 86
              THEN 'REF_PASTCUST'
         ELSE 'SELF_SOURCED' END AS LeadSourceCode,
       'CMP' + CAST(1 + ABS(CHECKSUM('CMP', m.MonthIx, x.N))
           % 12 AS VARCHAR(2)) AS CampaignCode,
       'CT' + CAST((m.MonthIx - 1) * 2400 + x.N
           AS VARCHAR(10)) AS ContactKey,
       CASE
         WHEN ABS(CHECKSUM('LSTA', m.MonthIx, x.N)) % 100 < 24
              THEN 'OK'
         WHEN ABS(CHECKSUM('LSTA', m.MonthIx, x.N)) % 100 < 52
              THEN 'TX'
         WHEN ABS(CHECKSUM('LSTA', m.MonthIx, x.N)) % 100 < 60
              THEN 'KS'
         WHEN ABS(CHECKSUM('LSTA', m.MonthIx, x.N)) % 100 < 67
              THEN 'AR'
         WHEN ABS(CHECKSUM('LSTA', m.MonthIx, x.N)) % 100 < 75
              THEN 'MO'
         WHEN ABS(CHECKSUM('LSTA', m.MonthIx, x.N)) % 100 < 80
              THEN 'NM'
         WHEN ABS(CHECKSUM('LSTA', m.MonthIx, x.N)) % 100 < 88
              THEN 'CO'
         WHEN ABS(CHECKSUM('LSTA', m.MonthIx, x.N)) % 100 < 93
              THEN 'LA'
         WHEN ABS(CHECKSUM('LSTA', m.MonthIx, x.N)) % 100 < 97
              THEN 'AZ'
         ELSE 'TN' END AS PropertyStateCode,
       'FL300' + RIGHT('0' + CAST(1 +
           ABS(CHECKSUM('LLO', m.MonthIx, x.N)) % 45
           AS VARCHAR(2)), 2) AS AssignedLoanOfficerNmlsId,
       ABS(CHECKSUM('LCV', m.MonthIx, x.N)) % 1000 AS ConvH
INTO #Lead
FROM #Month m
CROSS JOIN (SELECT N FROM #Num WHERE N <= 2400) x;

INSERT INTO src.CrmLead
    (LeadCreatedDate, LeadSourceCode, CampaignCode,
     ContactKey, PropertyStateCode,
     AssignedLoanOfficerNmlsId, AssignedDate,
     FirstContactDate, LeadStatusCode, LoadBatchId)
SELECT LeadCreatedDate,
       CASE WHEN ABS(CHECKSUM('DEF20', LeadSeq)) % 1000 < 12
            THEN NULL ELSE LeadSourceCode END,
       CampaignCode, ContactKey, PropertyStateCode,
       AssignedLoanOfficerNmlsId,
       DATEADD(DAY, 1, LeadCreatedDate),
       DATEADD(DAY, 1 + ABS(CHECKSUM('FCD', LeadSeq)) % 4,
               LeadCreatedDate),
       CASE WHEN ConvH < 140 THEN 'CONVERTED'
            WHEN ConvH < 400 THEN 'CONTACTED'
            ELSE 'CLOSED_LOST' END,
       @LoadBatchId
FROM #Lead ORDER BY LeadSeq;

INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF20', CAST(LeadSeq AS NVARCHAR(20))
FROM #Lead
WHERE ABS(CHECKSUM('DEF20', LeadSeq)) % 1000 < 12;

/* DEF15: duplicate leads (same contact, same day) */
INSERT INTO src.CrmLead
    (LeadCreatedDate, LeadSourceCode, CampaignCode,
     ContactKey, PropertyStateCode,
     AssignedLoanOfficerNmlsId, AssignedDate,
     FirstContactDate, LeadStatusCode, LoadBatchId)
SELECT LeadCreatedDate, LeadSourceCode, CampaignCode,
       ContactKey, PropertyStateCode,
       AssignedLoanOfficerNmlsId,
       DATEADD(DAY, 1, LeadCreatedDate),
       DATEADD(DAY, 2, LeadCreatedDate),
       'CONTACTED', @LoadBatchId
FROM #Lead
WHERE ABS(CHECKSUM('DEF15', ContactKey)) % 1000 < 2
ORDER BY LeadSeq;

INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF15', ContactKey FROM #Lead
WHERE ABS(CHECKSUM('DEF15', ContactKey)) % 1000 < 2;

/* ============================================================
   3. LOS applications: converted leads + direct apps
      ApplicationId = AppSeq (truncate + ordered insert)
   ============================================================ */
DROP TABLE IF EXISTS #App0;
SELECT LeadSeq, MonthIx, LeadCreatedDate, PropertyStateCode,
       AssignedLoanOfficerNmlsId
INTO #App0
FROM #Lead WHERE ConvH < 140
UNION ALL
SELECT NULL, m.MonthIx,
       DATEADD(DAY, ABS(CHECKSUM('DAD', m.MonthIx, x.N)) % 27,
               m.MonthStart),
       CASE WHEN ABS(CHECKSUM('DAS', m.MonthIx, x.N)) % 100
                 < 30 THEN 'OK'
            WHEN ABS(CHECKSUM('DAS', m.MonthIx, x.N)) % 100
                 < 62 THEN 'TX'
            WHEN ABS(CHECKSUM('DAS', m.MonthIx, x.N)) % 100
                 < 75 THEN 'KS'
            WHEN ABS(CHECKSUM('DAS', m.MonthIx, x.N)) % 100
                 < 87 THEN 'CO'
            ELSE 'AR' END,
       'FL300' + RIGHT('0' + CAST(1 +
           ABS(CHECKSUM('DALO', m.MonthIx, x.N)) % 45
           AS VARCHAR(2)), 2)
FROM #Month m
CROSS JOIN (SELECT N FROM #Num WHERE N <= 26) x;

DROP TABLE IF EXISTS #App;
SELECT ROW_NUMBER() OVER (ORDER BY a.LeadCreatedDate,
           a.LeadSeq, a.AssignedLoanOfficerNmlsId) AS AppSeq,
       a.LeadSeq, a.LeadCreatedDate,
       a.PropertyStateCode,
       a.AssignedLoanOfficerNmlsId AS LoNmlsId,
       DATEADD(DAY,
           CASE WHEN a.LeadSeq IS NULL THEN 1
                ELSE 3 + ABS(CHECKSUM('ASD', a.LeadSeq)) % 80
           END, a.LeadCreatedDate) AS AppStartedDate,
       ABS(CHECKSUM('ARC', a.LeadCreatedDate, a.LeadSeq,
           a.AssignedLoanOfficerNmlsId)) % 1000 AS RecvH,
       ABS(CHECKSUM('ADS', a.LeadCreatedDate, a.LeadSeq,
           a.AssignedLoanOfficerNmlsId)) % 1000 AS DispH,
       ABS(CHECKSUM('AAM', a.LeadCreatedDate, a.LeadSeq,
           a.AssignedLoanOfficerNmlsId)) % 1000 AS AmtH,
       ABS(CHECKSUM('APR', a.LeadCreatedDate, a.LeadSeq,
           a.AssignedLoanOfficerNmlsId)) % 1000 AS PgmH
INTO #App
FROM #App0 a;

DROP TABLE IF EXISTS #AppF;
SELECT AppSeq, LeadSeq, LoNmlsId, PropertyStateCode,
       AppStartedDate,
       CASE WHEN RecvH < 920
            THEN DATEADD(DAY, 1 + RecvH % 7, AppStartedDate)
       END AS AppReceivedDate,
       CASE WHEN RecvH < 820
            THEN DATEADD(DAY, 1 + RecvH % 7, AppStartedDate)
       END AS AppCompletedDate,
       CAST(120000 + (AmtH % 240) * 2500 AS DECIMAL(18,2))
           AS LoanAmount,
       CASE WHEN AmtH % 100 < 58 THEN 'PURCHASE'
            ELSE 'REFINANCE' END AS LoanPurposeCode,
       CASE WHEN AmtH % 100 < 58 THEN 'PURCH_STD'
            WHEN AmtH % 100 < 82 THEN 'REFI_RT'
            ELSE 'REFI_CO' END AS PurposeDetailCode,
       CASE WHEN PgmH < 600 THEN 'CONV'
            WHEN PgmH < 800 THEN 'FHA'
            WHEN PgmH < 920 THEN 'VA'
            WHEN PgmH < 960 THEN 'USDA'
            ELSE 'OTH' END AS LoanProgramCode,
       CASE WHEN PgmH % 100 < 12 THEN 'ARM' ELSE 'FIXED' END
           AS InterestRateTypeCode,
       DispH,
       CASE
         WHEN RecvH >= 920 THEN 'INCOMPLETE'
         WHEN DispH < 540 THEN 'FUNDED'
         WHEN DispH < 660 THEN 'DENIED'
         WHEN DispH < 800 THEN 'WITHDRAWN'
         WHEN DispH < 840 THEN 'ANA'
         WHEN DispH < 900 THEN 'INCOMPLETE'
         ELSE 'OPEN' END AS DispRaw
INTO #AppF
FROM #App;

DROP TABLE IF EXISTS #AppX;
SELECT f.*,
       CASE WHEN f.AppReceivedDate IS NULL THEN NULL
            WHEN f.DispRaw = 'OPEN'
                 AND f.AppReceivedDate > '2026-04-30'
                 THEN NULL
            WHEN f.DispRaw = 'OPEN' THEN 'FUNDED'
            ELSE f.DispRaw END AS DispositionCode0,
       CASE WHEN f.AppReceivedDate IS NULL THEN NULL
            ELSE DATEADD(DAY, 18 + f.DispH % 42,
                 f.AppReceivedDate) END AS DispositionDate0
INTO #AppX
FROM #AppF f;

DROP TABLE IF EXISTS #AppZ;
SELECT x.AppSeq, x.LeadSeq, x.LoNmlsId, x.PropertyStateCode,
       x.AppStartedDate, x.AppReceivedDate,
       x.AppCompletedDate, x.LoanAmount, x.LoanPurposeCode,
       x.PurposeDetailCode, x.LoanProgramCode,
       x.InterestRateTypeCode,
       x.DispositionCode0 AS DispositionCode,
       CASE WHEN x.DispositionCode0 IS NULL THEN NULL
            ELSE x.DispositionDate0 END AS DispositionDate,
       CASE WHEN x.DispositionCode0 = 'FUNDED' THEN
            CASE WHEN ABS(CHECKSUM('DEF16', x.AppSeq))
                      % 1000 < 3
                 THEN DATEADD(DAY, -10, x.AppReceivedDate)
                 ELSE x.DispositionDate0 END
       END AS FundingDate,
       CASE WHEN x.DispositionCode0 = 'FUNDED' THEN 1 ELSE 0
       END AS FundedFlag,
       CASE WHEN x.DispositionCode0 = 'FUNDED'
             AND ABS(CHECKSUM('RET', x.AppSeq)) % 100 < 70
            THEN 'RETAINED'
            WHEN x.DispositionCode0 = 'FUNDED'
            THEN 'RELEASED' END
           AS ServicingDispositionIntentCode
INTO #AppZ
FROM #AppX x;

INSERT INTO src.LosApplication
    (LeadId, LoanOfficerNmlsId, AppStartedDate,
     AppCompletedDate, AppReceivedDate,
     LoanAmountAtApplication, CurrentLoanAmount,
     LoanPurposeCode, PurposeDetailCode, LoanProgramCode,
     InterestRateTypeCode, LienPosition, PropertyStateCode,
     ChannelCode, DispositionCode, DispositionDate,
     ScheduledClosingDate, ActualClosingDate, FundingDate,
     FundedFlag, ServicingDispositionIntentCode, LoanNumber,
     LoadBatchId)
SELECT z.LeadSeq,
       CASE WHEN ABS(CHECKSUM('DEF14', z.AppSeq)) % 1000 < 5
            THEN '999999' ELSE z.LoNmlsId END,
       z.AppStartedDate, z.AppCompletedDate,
       z.AppReceivedDate, z.LoanAmount,
       ROUND(z.LoanAmount
           * (1 + (ABS(CHECKSUM('AMD', z.AppSeq)) % 7 - 3)
             / 100.0), 0),
       z.LoanPurposeCode, z.PurposeDetailCode,
       z.LoanProgramCode, z.InterestRateTypeCode, 1,
       z.PropertyStateCode, 'RETAIL',
       CASE WHEN z.DispositionCode IN
                 ('DENIED','WITHDRAWN','ANA','INCOMPLETE')
             AND ABS(CHECKSUM('DEF17', z.AppSeq)) % 1000 < 8
            THEN NULL ELSE z.DispositionCode END,
       z.DispositionDate,
       CASE WHEN z.FundedFlag = 1 THEN
            DATEADD(DAY,
              CASE WHEN ABS(CHECKSUM('OTC', z.AppSeq)) % 100
                        < 90
                   THEN ABS(CHECKSUM('OTD', z.AppSeq)) % 3
                   ELSE -(1 + ABS(CHECKSUM('OTD', z.AppSeq))
                        % 3) END,
              DATEADD(DAY, -1, z.FundingDate)) END,
       CASE WHEN z.FundedFlag = 1
            THEN DATEADD(DAY, -1, z.FundingDate) END,
       z.FundingDate, z.FundedFlag,
       z.ServicingDispositionIntentCode, NULL, @LoadBatchId
FROM #AppZ z ORDER BY z.AppSeq;

UPDATE l SET l.ConvertedApplicationId = z.AppSeq
FROM src.CrmLead l
JOIN #AppZ z ON z.LeadSeq = l.LeadId;

INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF14', CAST(AppSeq AS NVARCHAR(20)) FROM #AppZ
WHERE ABS(CHECKSUM('DEF14', AppSeq)) % 1000 < 5;
INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF16', CAST(AppSeq AS NVARCHAR(20)) FROM #AppZ
WHERE FundedFlag = 1
  AND ABS(CHECKSUM('DEF16', AppSeq)) % 1000 < 3;
INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF17', CAST(AppSeq AS NVARCHAR(20)) FROM #AppZ
WHERE DispositionCode IN
      ('DENIED','WITHDRAWN','ANA','INCOMPLETE')
  AND ABS(CHECKSUM('DEF17', AppSeq)) % 1000 < 8;

/* ============================================================
   4. PPE rate locks: base locks + relocks
      RateLockId = LockSeq (truncate + ordered insert)
   ============================================================ */
DROP TABLE IF EXISTS #Lock0;
SELECT z.AppSeq, z.AppReceivedDate, z.LoanAmount,
       z.FundedFlag,
       DATEADD(DAY, 3 + ABS(CHECKSUM('LKD', z.AppSeq)) % 18,
               z.AppReceivedDate) AS LockDate,
       CHOOSE(1 + ABS(CHECKSUM('LKP', z.AppSeq)) % 3,
              30, 45, 60) AS LockPeriodDays,
       ABS(CHECKSUM('LKH', z.AppSeq)) % 1000 AS LockH
INTO #Lock0
FROM #AppZ z
WHERE z.AppReceivedDate IS NOT NULL
  AND ABS(CHECKSUM('LCK', z.AppSeq)) % 1000 < 620;

DROP TABLE IF EXISTS #Lock;
SELECT ROW_NUMBER() OVER (ORDER BY b.AppSeq, b.RelockOrd)
           AS LockSeq,
       b.*
INTO #Lock
FROM (
    SELECT l.AppSeq, l.AppReceivedDate, l.LoanAmount,
           l.FundedFlag, l.LockDate, l.LockPeriodDays,
           l.LockH, 1 AS RelockOrd,
           CASE WHEN l.LockH < 60 THEN 1 ELSE 0 END
               AS HasRelock
    FROM #Lock0 l
    UNION ALL
    SELECT l.AppSeq, l.AppReceivedDate, l.LoanAmount,
           l.FundedFlag,
           DATEADD(DAY, 20 + l.LockH % 15, l.LockDate),
           l.LockPeriodDays, l.LockH, 2, 0
    FROM #Lock0 l WHERE l.LockH < 60
) b;

INSERT INTO src.PpeRateLock
    (ApplicationId, LockDate, LockAmount, NoteRatePercent,
     LockPeriodDays, OriginalExpirationDate,
     CurrentExpirationDate, ExtensionCount,
     TotalExtensionDays, LockStatusCode, PriorLockId,
     LoadBatchId)
SELECT k.AppSeq, k.LockDate, k.LoanAmount,
       5.25 + (k.LockH % 250) / 100.0,
       k.LockPeriodDays,
       DATEADD(DAY, k.LockPeriodDays, k.LockDate),
       CASE
         WHEN ABS(CHECKSUM('DEF18', k.LockSeq)) % 1000 < 4
              THEN DATEADD(DAY, -5, k.LockDate)
         WHEN k.LockH % 100 < 18
              THEN DATEADD(DAY, k.LockPeriodDays + 15,
                   k.LockDate)
         ELSE DATEADD(DAY, k.LockPeriodDays, k.LockDate)
       END,
       CASE WHEN k.LockH % 100 < 18 THEN 1 ELSE 0 END,
       CASE WHEN k.LockH % 100 < 18 THEN 15 ELSE 0 END,
       CASE
         WHEN k.HasRelock = 1 THEN 'CANCELLED'
         WHEN k.FundedFlag = 1 THEN 'FUNDED'
         WHEN k.LockH % 100 < 5 THEN 'CANCELLED'
         WHEN DATEADD(DAY, k.LockPeriodDays, k.LockDate)
              < '2026-07-20' THEN 'EXPIRED'
         ELSE 'ACTIVE' END,
       CASE WHEN k.RelockOrd = 2 THEN k.LockSeq - 1 END,
       @LoadBatchId
FROM #Lock k ORDER BY k.LockSeq;

INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF18', CAST(LockSeq AS NVARCHAR(20)) FROM #Lock
WHERE ABS(CHECKSUM('DEF18', LockSeq)) % 1000 < 4;

/* ============================================================
   5. Loan population and boarding
      Bulk 7,200 at month 1; flow months 2-36: retained
      fundings board next month, purchased tops up to ~150.
   ============================================================ */
DROP TABLE IF EXISTS #Ret;
SELECT z.AppSeq, z.LoanAmount AS OrigAmt,
       z.FundingDate AS OrigDate,
       z.LoanProgramCode, z.InterestRateTypeCode,
       z.LoanPurposeCode, z.PropertyStateCode,
       m.MonthIx + 1 AS BoardMonthIx
INTO #Ret
FROM #AppZ z
JOIN #Month m
  ON z.FundingDate BETWEEN m.MonthStart AND m.AsOfDate
WHERE z.FundedFlag = 1
  AND z.ServicingDispositionIntentCode = 'RETAINED'
  AND m.MonthIx < 36;

DROP TABLE IF EXISTS #PurchCnt;
SELECT m.MonthIx,
       CASE WHEN m.MonthIx = 1 THEN 0
            ELSE CASE WHEN 150 - ISNULL(r.C, 0) > 0
                 THEN 150 - ISNULL(r.C, 0) ELSE 0 END END
           AS PurchN
INTO #PurchCnt
FROM #Month m
LEFT JOIN (SELECT BoardMonthIx, COUNT(*) AS C
           FROM #Ret GROUP BY BoardMonthIx) r
  ON r.BoardMonthIx = m.MonthIx;

DROP TABLE IF EXISTS #LoanRaw;
SELECT ROW_NUMBER() OVER (ORDER BY s.SortA, s.SortB)
           AS LoanSeq,
       s.BoardMonthIx, s.SourceType, s.AppSeq,
       s.OrigDate, s.OrigAmt, s.LoanProgramCode,
       s.InterestRateTypeCode, s.LoanPurposeCode,
       s.PropertyStateCode
INTO #LoanRaw
FROM (
    SELECT 1 AS SortA, CAST(n.N AS BIGINT) AS SortB,
        1 AS BoardMonthIx, 'BULK' AS SourceType,
        CAST(NULL AS BIGINT) AS AppSeq,
        DATEADD(MONTH,
            -(6 + ABS(CHECKSUM('BOD', n.N)) % 96),
            '2023-08-01') AS OrigDate,
        CAST(90000 + (ABS(CHECKSUM('BAM', n.N)) % 260) * 2500
            AS DECIMAL(18,2)) AS OrigAmt,
        CASE WHEN ABS(CHECKSUM('BPG', n.N)) % 100 < 62
                  THEN 'CONV'
             WHEN ABS(CHECKSUM('BPG', n.N)) % 100 < 82
                  THEN 'FHA'
             WHEN ABS(CHECKSUM('BPG', n.N)) % 100 < 92
                  THEN 'VA'
             WHEN ABS(CHECKSUM('BPG', n.N)) % 100 < 95
                  THEN 'USDA'
             ELSE 'OTH' END AS LoanProgramCode,
        CASE WHEN ABS(CHECKSUM('BRT', n.N)) % 100 < 12
             THEN 'ARM' ELSE 'FIXED' END
             AS InterestRateTypeCode,
        CASE WHEN ABS(CHECKSUM('BPP', n.N)) % 100 < 55
             THEN 'PURCHASE' ELSE 'REFINANCE' END
             AS LoanPurposeCode,
        CASE
          WHEN ABS(CHECKSUM('BST', n.N)) % 100 < 22 THEN 'OK'
          WHEN ABS(CHECKSUM('BST', n.N)) % 100 < 48 THEN 'TX'
          WHEN ABS(CHECKSUM('BST', n.N)) % 100 < 56 THEN 'KS'
          WHEN ABS(CHECKSUM('BST', n.N)) % 100 < 63 THEN 'AR'
          WHEN ABS(CHECKSUM('BST', n.N)) % 100 < 71 THEN 'MO'
          WHEN ABS(CHECKSUM('BST', n.N)) % 100 < 76 THEN 'NM'
          WHEN ABS(CHECKSUM('BST', n.N)) % 100 < 84 THEN 'CO'
          WHEN ABS(CHECKSUM('BST', n.N)) % 100 < 90 THEN 'LA'
          WHEN ABS(CHECKSUM('BST', n.N)) % 100 < 96 THEN 'AZ'
          ELSE 'TN' END AS PropertyStateCode
    FROM #Num n WHERE n.N <= 7200
    UNION ALL
    SELECT 2, r.AppSeq, r.BoardMonthIx, 'RETAINED',
        r.AppSeq, r.OrigDate, r.OrigAmt, r.LoanProgramCode,
        r.InterestRateTypeCode, r.LoanPurposeCode,
        r.PropertyStateCode
    FROM #Ret r
    UNION ALL
    SELECT 3, CAST(p.MonthIx AS BIGINT) * 1000 + x.N,
        p.MonthIx, 'PURCHASED', NULL,
        DATEADD(MONTH,
            -(12 + ABS(CHECKSUM('POD', p.MonthIx, x.N)) % 72),
            DATEADD(MONTH, p.MonthIx - 1, '2023-08-01')),
        CAST(90000 + (ABS(CHECKSUM('PAM', p.MonthIx, x.N))
            % 260) * 2500 AS DECIMAL(18,2)),
        CASE WHEN ABS(CHECKSUM('PPG', p.MonthIx, x.N)) % 100
                  < 62 THEN 'CONV'
             WHEN ABS(CHECKSUM('PPG', p.MonthIx, x.N)) % 100
                  < 82 THEN 'FHA'
             WHEN ABS(CHECKSUM('PPG', p.MonthIx, x.N)) % 100
                  < 92 THEN 'VA'
             WHEN ABS(CHECKSUM('PPG', p.MonthIx, x.N)) % 100
                  < 95 THEN 'USDA'
             ELSE 'OTH' END,
        CASE WHEN ABS(CHECKSUM('PRT', p.MonthIx, x.N)) % 100
             < 12 THEN 'ARM' ELSE 'FIXED' END,
        CASE WHEN ABS(CHECKSUM('PPP', p.MonthIx, x.N)) % 100
             < 55 THEN 'PURCHASE' ELSE 'REFINANCE' END,
        CASE
          WHEN ABS(CHECKSUM('PST', p.MonthIx, x.N)) % 100
               < 22 THEN 'OK'
          WHEN ABS(CHECKSUM('PST', p.MonthIx, x.N)) % 100
               < 48 THEN 'TX'
          WHEN ABS(CHECKSUM('PST', p.MonthIx, x.N)) % 100
               < 56 THEN 'KS'
          WHEN ABS(CHECKSUM('PST', p.MonthIx, x.N)) % 100
               < 63 THEN 'AR'
          WHEN ABS(CHECKSUM('PST', p.MonthIx, x.N)) % 100
               < 71 THEN 'MO'
          WHEN ABS(CHECKSUM('PST', p.MonthIx, x.N)) % 100
               < 76 THEN 'NM'
          WHEN ABS(CHECKSUM('PST', p.MonthIx, x.N)) % 100
               < 84 THEN 'CO'
          WHEN ABS(CHECKSUM('PST', p.MonthIx, x.N)) % 100
               < 90 THEN 'LA'
          WHEN ABS(CHECKSUM('PST', p.MonthIx, x.N)) % 100
               < 96 THEN 'AZ'
          ELSE 'TN' END
    FROM #PurchCnt p
    JOIN #Num x ON x.N <= p.PurchN
) s;

DROP TABLE IF EXISTS #Loan;
SELECT r.LoanSeq,
    'FL' + RIGHT('000000' + CAST(r.LoanSeq AS VARCHAR(7)), 7)
        AS LoanNumber,
    r.BoardMonthIx, r.SourceType, r.AppSeq, r.OrigDate,
    r.OrigAmt, r.LoanProgramCode, r.InterestRateTypeCode,
    r.LoanPurposeCode, r.PropertyStateCode,
    CAST(CASE WHEN YEAR(r.OrigDate) < 2022
         THEN 2.75 + (ABS(CHECKSUM('RTE', r.LoanSeq)) % 250)
              / 100.0
         ELSE 5.00 + (ABS(CHECKSUM('RTE', r.LoanSeq)) % 300)
              / 100.0 END AS DECIMAL(9,4)) AS NoteRate,
    CASE WHEN r.LoanProgramCode IN ('FHA','VA','USDA') THEN
         CASE WHEN ABS(CHECKSUM('INV', r.LoanSeq)) % 100 < 80
              THEN 'GNMA' ELSE 'OTH1' END
         ELSE
         CASE WHEN ABS(CHECKSUM('INV', r.LoanSeq)) % 100 < 45
                   THEN 'FNMA'
              WHEN ABS(CHECKSUM('INV', r.LoanSeq)) % 100 < 81
                   THEN 'FHLMC'
              WHEN ABS(CHECKSUM('INV', r.LoanSeq)) % 100 < 93
                   THEN 'PRIV1'
              ELSE 'OTH1' END END AS InvestorCode,
    CASE WHEN ABS(CHECKSUM('SVT', r.LoanSeq)) % 100 < 55
              THEN 'MSR_OWNED'
         WHEN ABS(CHECKSUM('SVT', r.LoanSeq)) % 100 < 67
              THEN 'WHOLLY_OWNED'
         WHEN ABS(CHECKSUM('SVT', r.LoanSeq)) % 100 < 95
              THEN 'SUBSERV_FOR'
         ELSE 'SUBSERV_BY' END AS ServicingTypeCode,
    CASE WHEN ABS(CHECKSUM('ESC', r.LoanSeq)) % 100 < 78
         THEN 1 ELSE 0 END AS EscrowInd,
    CASE WHEN ABS(CHECKSUM('FLD', r.LoanSeq)) % 100 < 6
         THEN 1 ELSE 0 END AS FloodZone,
    ABS(CHECKSUM('PROF', r.LoanSeq)) % 1000 AS ProfH,
    r.BoardMonthIx + 2
        + ABS(CHECKSUM('EPS', r.LoanSeq)) % 30 AS E,
    ABS(CHECKSUM('MODH', r.LoanSeq)) % 1000 AS ModH,
    ABS(CHECKSUM('RDH', r.LoanSeq)) % 1000 AS RedH,
    ABS(CHECKSUM('POFH', r.LoanSeq)) % 1000 AS PofH,
    r.BoardMonthIx + 5
        + ABS(CHECKSUM('POFI', r.LoanSeq)) % 60 AS PofIx0,
    ABS(CHECKSUM('MISC', r.LoanSeq)) % 1000 AS MiscH
INTO #Loan
FROM #LoanRaw r;

DROP TABLE IF EXISTS #Script;
SELECT l.*,
    CAST(ROUND(l.OrigAmt * POWER(0.9970,
        DATEDIFF(MONTH, l.OrigDate,
            DATEADD(MONTH, l.BoardMonthIx - 1, '2023-08-01'))
        ), 2) AS DECIMAL(18,2)) AS BoardUpb,
    CAST(CASE WHEN l.InvestorCode = 'GNMA' THEN 0.4400
         WHEN l.InvestorCode = 'PRIV1' THEN 0.3750
         ELSE 0.2500 END AS DECIMAL(9,4)) AS FeeRate,
    CASE WHEN l.InvestorCode IN ('FNMA','FHLMC') THEN
         CASE WHEN l.MiscH % 2 = 0 THEN 'SS' ELSE 'SA' END
         WHEN l.InvestorCode = 'GNMA' THEN 'SS'
         ELSE 'AA' END AS RemitType,
    CASE WHEN l.ProfH BETWEEN 825 AND 859 AND l.ModH < 500
              THEN l.E + 4
         WHEN l.ProfH BETWEEN 905 AND 919 AND l.ModH < 150
              THEN l.E + 3 + l.ModH % 4
    END AS ModIx,
    CASE WHEN l.ProfH BETWEEN 825 AND 859 AND l.ModH < 500
              AND l.RedH < 180
         THEN l.E + 4 + 3 + l.RedH % 8 END AS RedefIx,
    CASE WHEN l.ProfH BETWEEN 860 AND 889
         THEN l.E + 3 END AS FcRefIx,
    CASE WHEN l.ProfH BETWEEN 860 AND 889
         THEN l.E + 3 + 8 + l.MiscH % 12 END AS FcSaleIx,
    CASE WHEN l.ProfH BETWEEN 890 AND 904
         THEN l.E + 2 END AS BkIx,
    CASE WHEN l.ProfH BETWEEN 890 AND 904
         THEN l.E + 2 + 7 + l.MiscH % 12 END AS BkEndIx,
    CASE WHEN l.ProfH BETWEEN 905 AND 919
         THEN l.E END AS FbStartIx,
    CASE WHEN l.ProfH BETWEEN 905 AND 919
         THEN l.E + 3 + l.MiscH % 4 END AS FbEndIx
INTO #Script
FROM #Loan l;

DROP TABLE IF EXISTS #Term;
SELECT s.*,
    CASE WHEN s.PofH < 330 AND s.ProfH NOT BETWEEN 860
              AND 904
         THEN s.PofIx0 END AS PayoffIx,
    CASE WHEN s.MiscH < 18 AND s.ProfH < 690
              AND s.BoardMonthIx < 28
         THEN 30 END AS XferIx
INTO #Term
FROM #Script s;

DROP TABLE IF EXISTS #L;
SELECT t.*,
    (SELECT MIN(v) FROM (VALUES (t.PayoffIx), (t.FcSaleIx),
        (t.XferIx)) q(v)) AS TermIx,
    CASE
      WHEN (SELECT MIN(v) FROM (VALUES (t.PayoffIx),
           (t.FcSaleIx), (t.XferIx)) q(v)) = t.FcSaleIx
           THEN 'FC_SALE'
      WHEN (SELECT MIN(v) FROM (VALUES (t.PayoffIx),
           (t.FcSaleIx), (t.XferIx)) q(v)) = t.XferIx
           THEN 'TRANSFER_OUT'
      WHEN (SELECT MIN(v) FROM (VALUES (t.PayoffIx),
           (t.FcSaleIx), (t.XferIx)) q(v)) = t.PayoffIx
           THEN CASE WHEN t.LoanPurposeCode = 'REFINANCE'
                       OR t.MiscH % 100 < 55
                     THEN 'REFINANCE'
                     WHEN t.ProfH >= 690 AND t.MiscH % 100
                          > 96 THEN 'SHORT_SALE'
                     ELSE 'VOL_PAYOFF' END
    END AS RunoffReason
INTO #L
FROM #Term t;

/* ---- boarding batches: 1 bulk + 35 flow ---- */
INSERT INTO src.BrdBoardingBatch
    (BatchName, TransferTypeCode, TransferEffectiveDate,
     ScheduledBoardDate, PriorServicerName, LoadBatchId)
SELECT CASE WHEN m.MonthIx = 1
            THEN N'Bulk MSR acquisition: Sunbelt portfolio'
            ELSE N'Flow boarding '
                 + CONVERT(NVARCHAR(7), m.MonthStart, 126)
       END,
       CASE WHEN m.MonthIx = 1 THEN 'BULK' ELSE 'FLOW' END,
       m.MonthStart,
       DATEADD(DAY, 3, m.MonthStart),
       CASE WHEN m.MonthIx = 1
            THEN N'Sunbelt Home Loans LLC'
            ELSE N'Mixed: Flamingo retention + minibulk' END,
       @LoadBatchId
FROM #Month m ORDER BY m.MonthIx;
/* BoardingBatchId = MonthIx via ordered insert */

INSERT INTO src.BrdBoardingTape
    (BoardingBatchId, LoanNumber, BorrowerFirstName,
     BorrowerLastName, PropertyStreet, PropertyCity,
     PropertyStateCode, PropertyPostalCode, PropertyTypeCode,
     OccupancyTypeCode, UnitsCount, FloodZoneFlag,
     OriginalLoanAmount, OriginationDate, MaturityDate,
     NoteRatePercent, InterestRateTypeCode,
     AmortizationTermMonths, LienPosition, HelocFlag,
     ReverseMortgageFlag, LoanProgramCode, LoanPurposeCode,
     EscrowIndicator, ServicingTypeCode, RemittanceTypeCode,
     InvestorCode, InvestorLoanNumber, TapeUpbAmount,
     TapeInterestRatePercent, TapeNextPaymentDueDate,
     TapeEscrowBalanceAmount, TapeInvestorCode,
     BoardingCompletedDate, LoadBatchId)
SELECT L.BoardMonthIx, L.LoanNumber,
    CHOOSE(1 + L.MiscH % 12, 'Sam','Alex','Jamie','Taylor',
     'Drew','Blake','Cameron','Dana','Ellis','Frankie',
     'Gray','Hollis'),
    CHOOSE(1 + ABS(CHECKSUM('BLN', L.LoanSeq)) % 12,
     'Reyes','Nguyen','Okafor','Silva','Novak','Haddad',
     'Kim','Osei','Marsh','Iwu','Delgado','Barrett'),
    CAST(100 + L.LoanSeq % 8900 AS VARCHAR(5))
        + ' Lagoon Way',
    'Coral City', L.PropertyStateCode,
    CAST(73000 + L.LoanSeq % 900 AS VARCHAR(6)),
    CASE WHEN L.MiscH % 100 < 82 THEN 'SFR'
         WHEN L.MiscH % 100 < 93 THEN 'CONDO'
         ELSE 'PUD' END,
    CASE WHEN L.MiscH % 100 < 88 THEN 'PRIMARY'
         WHEN L.MiscH % 100 < 96 THEN 'INVESTMENT'
         ELSE 'SECOND' END,
    1, L.FloodZone, L.OrigAmt, L.OrigDate,
    DATEADD(MONTH, 360, L.OrigDate), L.NoteRate,
    L.InterestRateTypeCode, 360, 1, 0, 0,
    L.LoanProgramCode, L.LoanPurposeCode, L.EscrowInd,
    L.ServicingTypeCode, L.RemitType, L.InvestorCode,
    'IV' + RIGHT(L.LoanNumber, 7),
    L.BoardUpb, L.NoteRate,
    DATEFROMPARTS(
        YEAR(DATEADD(MONTH, L.BoardMonthIx - 1,
             '2023-08-01')),
        MONTH(DATEADD(MONTH, L.BoardMonthIx - 1,
             '2023-08-01')), 1),
    CASE WHEN L.EscrowInd = 1
         THEN ROUND(L.OrigAmt * 0.004, 2) ELSE 0 END,
    L.InvestorCode,
    DATEADD(DAY, 1 + ABS(CHECKSUM('BCD', L.LoanSeq)) % 9,
        DATEADD(MONTH, L.BoardMonthIx - 1, '2023-08-01')),
    @LoadBatchId
FROM #L L ORDER BY L.LoanSeq;

/* DEF04: duplicate tape rows in a second batch */
INSERT INTO src.BrdBoardingTape
    (BoardingBatchId, LoanNumber, OriginalLoanAmount,
     OriginationDate, NoteRatePercent, PropertyStateCode,
     InvestorCode, TapeUpbAmount, TapeInvestorCode,
     BoardingCompletedDate, LoadBatchId)
SELECT CASE WHEN L.BoardMonthIx < 36
            THEN L.BoardMonthIx + 1 ELSE 35 END,
       L.LoanNumber, L.OrigAmt, L.OrigDate, L.NoteRate,
       L.PropertyStateCode, L.InvestorCode, L.BoardUpb,
       L.InvestorCode,
       DATEADD(DAY, 4,
           DATEADD(MONTH, L.BoardMonthIx, '2023-08-01')),
       @LoadBatchId
FROM #L L
WHERE ABS(CHECKSUM('DEF04', L.LoanNumber)) % 1000 < 2
ORDER BY L.LoanSeq;

INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF04', LoanNumber FROM #L
WHERE ABS(CHECKSUM('DEF04', LoanNumber)) % 1000 < 2;

/* ---- SVC loan master (DEF01, DEF02, DEF10) ---- */
INSERT INTO src.SvcLoanMaster
    (LoanNumber, BorrowerFirstName, BorrowerLastName,
     PropertyStreet, PropertyCity, PropertyStateCode,
     PropertyPostalCode, PropertyTypeCode, OccupancyTypeCode,
     UnitsCount, FloodZoneFlag, OriginalLoanAmount,
     OriginationDate, MaturityDate, NoteRatePercent,
     InterestRateTypeCode, AmortizationTermMonths,
     LienPosition, HelocFlag, ReverseMortgageFlag,
     LoanProgramCode, LoanPurposeCode, EscrowIndicator,
     ServicingTypeCode, RemittanceTypeCode, InvestorCode,
     InvestorLoanNumber, BoardedDate,
     BoardInterestRatePercent, BoardNextPaymentDueDate,
     BoardUpbAmount, BoardEscrowBalanceAmount,
     MsrOwnerName, MsrOwnerNmlsId, PoolNumber, LoadBatchId)
SELECT t.LoanNumber, t.BorrowerFirstName,
    t.BorrowerLastName, t.PropertyStreet, t.PropertyCity,
    CASE WHEN ABS(CHECKSUM('DEF02', t.LoanNumber)) % 1000 < 4
         THEN 'ZZ' ELSE t.PropertyStateCode END,
    t.PropertyPostalCode, t.PropertyTypeCode,
    t.OccupancyTypeCode, t.UnitsCount, t.FloodZoneFlag,
    t.OriginalLoanAmount, t.OriginationDate, t.MaturityDate,
    CASE WHEN ABS(CHECKSUM('DEF01', t.LoanNumber)) % 1000 < 8
         THEN NULL
         WHEN ABS(CHECKSUM('DEF10', t.LoanNumber))
              % 1000 < 15
          AND ABS(CHECKSUM('D10P', t.LoanNumber)) % 3 = 0
         THEN t.NoteRatePercent + 0.1250
         ELSE t.NoteRatePercent END,
    t.InterestRateTypeCode, t.AmortizationTermMonths,
    t.LienPosition, t.HelocFlag, t.ReverseMortgageFlag,
    t.LoanProgramCode, t.LoanPurposeCode, t.EscrowIndicator,
    t.ServicingTypeCode, t.RemittanceTypeCode,
    t.InvestorCode, t.InvestorLoanNumber,
    t.BoardingCompletedDate,
    CASE WHEN ABS(CHECKSUM('DEF10', t.LoanNumber))
              % 1000 < 15
          AND ABS(CHECKSUM('D10P', t.LoanNumber)) % 3 = 0
         THEN t.TapeInterestRatePercent + 0.1250
         ELSE t.TapeInterestRatePercent END,
    CASE WHEN ABS(CHECKSUM('DEF10', t.LoanNumber))
              % 1000 < 15
          AND ABS(CHECKSUM('D10P', t.LoanNumber)) % 3 = 1
         THEN DATEADD(MONTH, 1, t.TapeNextPaymentDueDate)
         ELSE t.TapeNextPaymentDueDate END,
    t.TapeUpbAmount,
    CASE WHEN ABS(CHECKSUM('DEF10', t.LoanNumber))
              % 1000 < 15
          AND ABS(CHECKSUM('D10P', t.LoanNumber)) % 3 = 2
         THEN t.TapeEscrowBalanceAmount + 250.00
         ELSE t.TapeEscrowBalanceAmount END,
    CASE WHEN t.ServicingTypeCode = 'SUBSERV_FOR'
         THEN N'Pelican Capital Servicing LLC' END,
    CASE WHEN t.ServicingTypeCode = 'SUBSERV_FOR'
         THEN '2345671' END,
    CASE WHEN t.InvestorCode = 'GNMA'
         THEN 'GN' + CAST(3000 + ABS(CHECKSUM('POOL',
              t.LoanNumber)) % 60 AS VARCHAR(6))
         WHEN t.InvestorCode IN ('FNMA','FHLMC')
         THEN 'AG' + CAST(7000 + ABS(CHECKSUM('POOL',
              t.LoanNumber)) % 90 AS VARCHAR(6)) END,
    @LoadBatchId
FROM src.BrdBoardingTape t
JOIN #L L ON L.LoanNumber = t.LoanNumber
         AND L.BoardMonthIx = t.BoardingBatchId
ORDER BY t.BoardingTapeId;

INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF01', LoanNumber FROM #L
WHERE ABS(CHECKSUM('DEF01', LoanNumber)) % 1000 < 8;
INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF02', LoanNumber FROM #L
WHERE ABS(CHECKSUM('DEF02', LoanNumber)) % 1000 < 4;
INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF10', LoanNumber FROM #L
WHERE ABS(CHECKSUM('DEF10', LoanNumber)) % 1000 < 15;

UPDATE a SET a.LoanNumber = L.LoanNumber
FROM src.LosApplication a
JOIN #L L ON L.AppSeq = a.ApplicationId
WHERE L.SourceType = 'RETAINED';

/* ============================================================
   6. Month-end snapshots: scripted delinquency paths
   ============================================================ */
DROP TABLE IF EXISTS #Snap;
SELECT L.LoanSeq, L.LoanNumber, m.MonthIx, m.AsOfDate,
    m.PeriodKey,
    CAST(ROUND(L.BoardUpb
        * POWER(0.9975, m.MonthIx - L.BoardMonthIx), 2)
        AS DECIMAL(18,2)) AS Upb,
    CAST(ROUND(L.BoardUpb
        * POWER(0.9975,
          CASE WHEN m.MonthIx = L.BoardMonthIx THEN 0
               ELSE m.MonthIx - L.BoardMonthIx - 1 END), 2)
        AS DECIMAL(18,2)) AS BegUpb,
    CASE
      WHEN L.ProfH < 690 THEN 0
      WHEN L.ProfH < 780 THEN
           CASE WHEN m.MonthIx = L.E
                THEN 30 + L.MiscH % 15 ELSE 0 END
      WHEN L.ProfH < 825 THEN
           CASE WHEN m.MonthIx = L.E THEN 32 + L.MiscH % 12
                WHEN m.MonthIx = L.E + 1
                THEN 62 + L.MiscH % 18 ELSE 0 END
      WHEN L.ProfH < 860 THEN
           CASE WHEN m.MonthIx = L.E THEN 33
                WHEN m.MonthIx = L.E + 1 THEN 63
                WHEN m.MonthIx = L.E + 2 THEN 93
                WHEN m.MonthIx = L.E + 3 THEN 123
                WHEN m.MonthIx = L.E + 4 AND L.ModIx IS NULL
                     THEN 60
                WHEN m.MonthIx = L.E + 5 AND L.ModIx IS NULL
                     THEN 30
                WHEN L.RedefIx IS NOT NULL
                     AND m.MonthIx IN (L.RedefIx,
                         L.RedefIx + 1)
                     THEN 95 + 30 * (m.MonthIx - L.RedefIx)
                ELSE 0 END
      WHEN L.ProfH < 890 THEN
           CASE WHEN m.MonthIx < L.E THEN 0
                WHEN m.MonthIx = L.E THEN 31
                ELSE 31 + 30 * (m.MonthIx - L.E) END
      WHEN L.ProfH < 905 THEN
           CASE WHEN m.MonthIx < L.E THEN 0
                WHEN m.MonthIx = L.E THEN 32
                WHEN m.MonthIx = L.E + 1 THEN 62
                WHEN m.MonthIx >= L.BkIx
                     AND m.MonthIx < ISNULL(L.BkEndIx, 99)
                     THEN 95
                WHEN m.MonthIx >= ISNULL(L.BkEndIx, 99)
                     AND L.MiscH % 100 < 70 THEN 0
                WHEN m.MonthIx >= ISNULL(L.BkEndIx, 99)
                     THEN 95
                ELSE 92 END
      WHEN L.ProfH < 920 THEN
           CASE WHEN m.MonthIx < L.FbStartIx THEN 0
                WHEN m.MonthIx <= ISNULL(L.FbEndIx, 99)
                THEN CASE WHEN 30 * (m.MonthIx - L.FbStartIx
                          + 1) > 120 THEN 120
                          ELSE 30 * (m.MonthIx - L.FbStartIx
                          + 1) END
                ELSE 0 END
      ELSE
           CASE WHEN m.MonthIx IN (L.E, L.E + 9)
                THEN 30 + L.MiscH % 10 ELSE 0 END
    END AS Dpd,
    L.EscrowInd, L.InvestorCode, L.ServicingTypeCode,
    L.RemitType, L.FeeRate, L.NoteRate, L.OrigAmt,
    L.TermIx, L.RunoffReason, L.ModIx, L.FcRefIx,
    L.FcSaleIx, L.BkIx, L.BkEndIx, L.FbStartIx, L.FbEndIx,
    L.MiscH, L.ProfH, L.BoardMonthIx
INTO #Snap
FROM #L L
JOIN #Month m
  ON m.MonthIx >= L.BoardMonthIx
 AND m.MonthIx <= ISNULL(L.TermIx, 36);

INSERT INTO src.SvcLoanMonthEnd
    (LoanNumber, AsOfDate, CurrentUpbAmount,
     BeginningUpbAmount, ScheduledPrincipalAmount,
     VoluntaryPrepaidPrincipalAmount, InterestRatePercent,
     ServicingFeeRatePercent, NextPaymentDueDate,
     EscrowBalanceAmount, SuspenseBalanceAmount,
     LoanStatusCode, RunoffReasonCode,
     DelinquencyBucketCode, InvestorCode, ServicingTypeCode,
     RemittanceTypeCode, EscrowIndicator, ForbearanceFlag,
     LoadBatchId)
SELECT s.LoanNumber, s.AsOfDate,
    CASE
      WHEN s.MonthIx = s.TermIx
           AND s.RunoffReason <> 'TRANSFER_OUT' THEN 0
      WHEN s.MonthIx = 36 AND s.TermIx IS NULL
           AND ABS(CHECKSUM('DEF03', s.LoanNumber))
               % 1000 < 3
           AND s.ProfH < 690 AND s.ModIx IS NULL
           THEN ROUND(s.OrigAmt * 1.08, 2)
      ELSE s.Upb END,
    s.BegUpb,
    ROUND(s.BegUpb * 0.0025, 2),
    CASE WHEN s.MonthIx = s.TermIx AND s.RunoffReason IN
              ('VOL_PAYOFF','REFINANCE','SHORT_SALE')
         THEN s.Upb
         WHEN s.MiscH % 1000 < 20
         THEN 500 + s.MiscH % 2500 ELSE 0 END,
    s.NoteRate, s.FeeRate,
    CASE WHEN s.Dpd = 0
         THEN DATEADD(DAY, 1, s.AsOfDate)
         ELSE DATEADD(DAY, -s.Dpd, s.AsOfDate) END,
    CASE WHEN s.EscrowInd = 1
         THEN ROUND(s.OrigAmt * 0.004
              * (1 + (s.MonthIx % 12) / 24.0), 2)
         ELSE 0 END,
    CASE WHEN ABS(CHECKSUM('SUS', s.LoanNumber, s.MonthIx))
              % 1000 < 4
         THEN 200 + s.MiscH % 700 ELSE 0 END,
    CASE
      WHEN s.MonthIx = s.TermIx THEN
           CASE WHEN s.RunoffReason = 'TRANSFER_OUT'
                THEN 'SR' ELSE 'PO' END
      WHEN s.FcRefIx IS NOT NULL AND s.MonthIx >= s.FcRefIx
           THEN 'FC'
      WHEN s.BkIx IS NOT NULL AND s.MonthIx >= s.BkIx
           AND s.MonthIx < ISNULL(s.BkEndIx, 99) THEN 'BK'
      WHEN s.FbStartIx IS NOT NULL
           AND s.MonthIx BETWEEN s.FbStartIx
           AND ISNULL(s.FbEndIx, 99) THEN 'FB'
      ELSE 'ACT' END,
    CASE WHEN s.MonthIx = s.TermIx THEN s.RunoffReason END,
    CASE
      WHEN YEAR(s.AsOfDate) = 2026
           AND ABS(CHECKSUM('DEF05', s.LoanNumber,
               s.AsOfDate)) % 1000 < 7
           AND s.Dpd >= 30
      THEN CASE WHEN s.Dpd >= 90 THEN 'DPD60_89'
                WHEN s.Dpd >= 60 THEN 'DPD30_59'
                ELSE 'CURRENT' END
      ELSE CASE WHEN s.Dpd >= 90 THEN 'DPD90_PLUS'
                WHEN s.Dpd >= 60 THEN 'DPD60_89'
                WHEN s.Dpd >= 30 THEN 'DPD30_59'
                ELSE 'CURRENT' END END,
    CASE WHEN s.MonthIx = 36
              AND ABS(CHECKSUM('DEF12', s.LoanNumber))
                  % 1000 < 12
              AND s.InvestorCode = 'FNMA'
         THEN 'FNM' ELSE s.InvestorCode END,
    s.ServicingTypeCode, s.RemitType, s.EscrowInd,
    CASE WHEN s.FbStartIx IS NOT NULL
              AND s.MonthIx BETWEEN s.FbStartIx
              AND ISNULL(s.FbEndIx, 99)
         THEN 1 ELSE 0 END,
    @LoadBatchId
FROM #Snap s ORDER BY s.AsOfDate, s.LoanSeq;

/* DEF11: delete 2025-03 snapshot rows for a slice */
DELETE e
FROM src.SvcLoanMonthEnd e
WHERE e.AsOfDate = '2025-03-31'
  AND ABS(CHECKSUM('DEF11', e.LoanNumber)) % 1000 < 4;

INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT DISTINCT 'DEF11', s.LoanNumber FROM #Snap s
WHERE s.MonthIx = 20
  AND ABS(CHECKSUM('DEF11', s.LoanNumber)) % 1000 < 4;

INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF03', s.LoanNumber FROM #Snap s
WHERE s.MonthIx = 36 AND s.TermIx IS NULL
  AND ABS(CHECKSUM('DEF03', s.LoanNumber)) % 1000 < 3
  AND s.ProfH < 690 AND s.ModIx IS NULL;
INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT DISTINCT 'DEF05', s.LoanNumber + '|'
    + CONVERT(VARCHAR(10), s.AsOfDate, 120)
FROM #Snap s
WHERE YEAR(s.AsOfDate) = 2026 AND s.Dpd >= 30
  AND ABS(CHECKSUM('DEF05', s.LoanNumber, s.AsOfDate))
      % 1000 < 7
  AND s.MonthIx <> ISNULL(s.TermIx, -1);
INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF12', s.LoanNumber FROM #Snap s
WHERE s.MonthIx = 36 AND s.InvestorCode = 'FNMA'
  AND ABS(CHECKSUM('DEF12', s.LoanNumber)) % 1000 < 12;

/* ============================================================
   7. Payments: one payment per performing loan-month,
      DEF07 late slice, DEF08 reversal chains, DEF06
      orphans, sparse suspense partials
   ============================================================ */
DROP TABLE IF EXISTS #PayBase;
SELECT ROW_NUMBER() OVER (ORDER BY s.MonthIx, s.LoanSeq)
        AS PaySeq,
    s.LoanNumber, s.MonthIx,
    DATEFROMPARTS(YEAR(DATEADD(MONTH, s.MonthIx - 1,
        '2023-08-01')),
        MONTH(DATEADD(MONTH, s.MonthIx - 1, '2023-08-01')),
        1) AS DueDate,
    CAST(ROUND(s.BegUpb * s.NoteRate / 1200.0
        + s.BegUpb * 0.0025
        + CASE WHEN s.EscrowInd = 1
               THEN s.OrigAmt * 0.0005 ELSE 0 END, 2)
        AS DECIMAL(18,2)) AS PmtAmt,
    CAST(ROUND(s.BegUpb * 0.0025, 2) AS DECIMAL(18,2))
        AS PrinAmt,
    CAST(ROUND(s.BegUpb * s.NoteRate / 1200.0, 2)
        AS DECIMAL(18,2)) AS IntAmt,
    CAST(CASE WHEN s.EscrowInd = 1
         THEN ROUND(s.OrigAmt * 0.0005, 2) ELSE 0 END
         AS DECIMAL(18,2)) AS EscAmt,
    ABS(CHECKSUM('PYH', s.LoanNumber, s.MonthIx)) % 1000
        AS PayH
INTO #PayBase
FROM #Snap s
WHERE s.Dpd = 0
  AND NOT (s.MonthIx = ISNULL(s.TermIx, -1)
           AND s.RunoffReason = 'FC_SALE');

DROP TABLE IF EXISTS #Pay;
SELECT p.PaySeq, p.LoanNumber,
    DATEADD(DAY, -2 + p.PayH % 14, p.DueDate)
        AS ReceivedDate,
    p.PmtAmt, p.PrinAmt, p.IntAmt, p.EscAmt, p.PayH,
    CASE WHEN ABS(CHECKSUM('DEF07', p.PaySeq)) % 1000 < 25
         THEN 1 ELSE 0 END AS LateFlag,
    CASE WHEN ABS(CHECKSUM('DEF08', p.PaySeq)) % 1000 < 9
         THEN 1 ELSE 0 END AS RevFlag,
    CASE WHEN p.PayH % 1000 < 5 THEN 1 ELSE 0 END
        AS SuspFlag
INTO #Pay
FROM #PayBase p;

INSERT INTO src.PayPaymentTransaction
    (LoanNumber, ReceivedDate, PostedDate, EffectiveDate,
     PaymentAmount, PrincipalAmount, InterestAmount,
     EscrowAmount, FeeAmount, SuspenseFlag, ReversalFlag,
     OriginalTransactionId, ChannelCode, LoadBatchId)
SELECT p.LoanNumber, p.ReceivedDate,
    CASE WHEN p.LateFlag = 1
         THEN DATEADD(DAY, 3 + p.PayH % 3, p.ReceivedDate)
         ELSE CASE DATENAME(WEEKDAY, p.ReceivedDate)
              WHEN 'Friday'
                   THEN DATEADD(DAY, 3, p.ReceivedDate)
              WHEN 'Saturday'
                   THEN DATEADD(DAY, 2, p.ReceivedDate)
              ELSE DATEADD(DAY, 1, p.ReceivedDate) END END,
    p.ReceivedDate,
    CASE WHEN p.SuspFlag = 1
         THEN ROUND(p.PmtAmt * 0.4, 2) ELSE p.PmtAmt END,
    CASE WHEN p.RevFlag = 1 THEN p.IntAmt
         WHEN p.SuspFlag = 1 THEN 0 ELSE p.PrinAmt END,
    CASE WHEN p.RevFlag = 1 THEN p.PrinAmt
         WHEN p.SuspFlag = 1 THEN 0 ELSE p.IntAmt END,
    CASE WHEN p.SuspFlag = 1 THEN 0 ELSE p.EscAmt END,
    0, p.SuspFlag, 0, NULL,
    CASE WHEN p.PayH % 100 < 55 THEN 'ACH'
         WHEN p.PayH % 100 < 80 THEN 'WEB'
         WHEN p.PayH % 100 < 92 THEN 'MAIL'
         ELSE 'PHONE' END,
    @LoadBatchId
FROM #Pay p ORDER BY p.PaySeq;

/* DEF08 chains: reversal + corrected repost */
INSERT INTO src.PayPaymentTransaction
    (LoanNumber, ReceivedDate, PostedDate, EffectiveDate,
     PaymentAmount, PrincipalAmount, InterestAmount,
     EscrowAmount, FeeAmount, SuspenseFlag, ReversalFlag,
     OriginalTransactionId, ChannelCode, LoadBatchId)
SELECT p.LoanNumber,
    DATEADD(DAY, 3, p.ReceivedDate),
    DATEADD(DAY, 4, p.ReceivedDate),
    p.ReceivedDate, p.PmtAmt, p.IntAmt, p.PrinAmt, p.EscAmt,
    0, 0, 1, p.PaySeq, 'CORR', @LoadBatchId
FROM #Pay p WHERE p.RevFlag = 1 ORDER BY p.PaySeq;

INSERT INTO src.PayPaymentTransaction
    (LoanNumber, ReceivedDate, PostedDate, EffectiveDate,
     PaymentAmount, PrincipalAmount, InterestAmount,
     EscrowAmount, FeeAmount, SuspenseFlag, ReversalFlag,
     OriginalTransactionId, ChannelCode, LoadBatchId)
SELECT p.LoanNumber,
    DATEADD(DAY, 3, p.ReceivedDate),
    DATEADD(DAY, 4, p.ReceivedDate),
    p.ReceivedDate, p.PmtAmt, p.PrinAmt, p.IntAmt, p.EscAmt,
    0, 0, 0, p.PaySeq, 'CORR', @LoadBatchId
FROM #Pay p WHERE p.RevFlag = 1 ORDER BY p.PaySeq;

/* DEF06: orphan payments */
INSERT INTO src.PayPaymentTransaction
    (LoanNumber, ReceivedDate, PostedDate, EffectiveDate,
     PaymentAmount, PrincipalAmount, InterestAmount,
     EscrowAmount, FeeAmount, SuspenseFlag, ReversalFlag,
     OriginalTransactionId, ChannelCode, LoadBatchId)
SELECT 'FLORPHAN' + RIGHT('0' + CAST(n.N AS VARCHAR(2)), 2),
    DATEADD(MONTH, n.N, '2024-01-15'),
    DATEADD(MONTH, n.N, '2024-01-16'),
    DATEADD(MONTH, n.N, '2024-01-15'),
    1500.00, 900.00, 500.00, 100.00, 0, 0, 0, NULL,
    'MAIL', @LoadBatchId
FROM #Num n WHERE n.N <= 12 ORDER BY n.N;

INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF06',
       'FLORPHAN' + RIGHT('0' + CAST(n.N AS VARCHAR(2)), 2)
FROM #Num n WHERE n.N <= 12;
INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF07', CAST(p.PaySeq AS NVARCHAR(20))
FROM #Pay p WHERE p.LateFlag = 1;
INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF08', CAST(p.PaySeq AS NVARCHAR(20))
FROM #Pay p WHERE p.RevFlag = 1;

/* ============================================================
   8. Escrow: analyses, disbursements, policies
   ============================================================ */
DROP TABLE IF EXISTS #EscLoan;
SELECT L.LoanSeq, L.LoanNumber, L.BoardMonthIx,
       ISNULL(L.TermIx, 37) AS EndIx, L.PropertyStateCode,
       L.OrigAmt, L.FloodZone, L.MiscH,
       CASE WHEN ABS(CHECKSUM('LPI', L.LoanSeq)) % 1000 < 4
            THEN 1 ELSE 0 END AS LpiFlag
INTO #EscLoan
FROM #L L WHERE L.EscrowInd = 1;

INSERT INTO src.SvcEscrowAnalysis
    (LoanNumber, AnalysisDueDate, AnalysisCompletedDate,
     ShortageAmount, LoadBatchId)
SELECT e.LoanNumber,
    EOMONTH(DATEFROMPARTS(y.Yr, c.CycleMonth, 1)),
    CASE WHEN ABS(CHECKSUM('EAT', e.LoanSeq, y.Yr)) % 1000
              < 910
         THEN DATEADD(DAY,
              -(1 + ABS(CHECKSUM('EAD', e.LoanSeq, y.Yr))
              % 20),
              EOMONTH(DATEFROMPARTS(y.Yr, c.CycleMonth, 1)))
         ELSE DATEADD(DAY,
              1 + ABS(CHECKSUM('EAD', e.LoanSeq, y.Yr)) % 15,
              EOMONTH(DATEFROMPARTS(y.Yr, c.CycleMonth, 1)))
    END,
    CASE WHEN e.MiscH % 100 < 30
         THEN 100 + e.MiscH % 900 ELSE 0 END,
    @LoadBatchId
FROM #EscLoan e
JOIN ref.EscrowAnalysisCycle c
  ON c.StateCode = e.PropertyStateCode
JOIN (VALUES (2024),(2025),(2026)) y(Yr) ON 1 = 1
JOIN #Month m
  ON m.PeriodKey = y.Yr * 100 + c.CycleMonth
WHERE m.MonthIx BETWEEN e.BoardMonthIx AND e.EndIx
ORDER BY e.LoanSeq, y.Yr;

DROP TABLE IF EXISTS #Tax;
SELECT ROW_NUMBER() OVER (ORDER BY e.LoanSeq, y.Yr,
        t.InstallmentNo) AS TaxSeq,
    e.LoanNumber, e.LoanSeq,
    EOMONTH(DATEFROMPARTS(y.Yr, t.DueMonth, 1)) AS TaxDue,
    CAST(ROUND(e.OrigAmt * 0.006, 2) AS DECIMAL(18,2))
        AS TaxAmt,
    ABS(CHECKSUM('TXH', e.LoanSeq, y.Yr, t.InstallmentNo))
        % 1000 AS TxH
INTO #Tax
FROM #EscLoan e
JOIN ref.TaxDueMonth t ON t.StateCode = e.PropertyStateCode
JOIN (VALUES (2024),(2025),(2026)) y(Yr) ON 1 = 1
JOIN #Month m
  ON m.PeriodKey = y.Yr * 100 + t.DueMonth
WHERE m.MonthIx BETWEEN e.BoardMonthIx AND e.EndIx;

INSERT INTO src.SvcEscrowDisbursement
    (LoanNumber, DisbursementTypeCode, PayeeName,
     DisbursedAmount, DisbursedDate, TaxDueDate,
     PolicyExpirationDate, AmountMatchFlag, PayeeMatchFlag,
     LoanMatchFlag, LoadBatchId)
SELECT t.LoanNumber, 'TAX', N'County Treasurer',
    t.TaxAmt,
    CASE WHEN ABS(CHECKSUM('DEF09', t.TaxSeq)) % 1000 < 40
         THEN DATEADD(DAY, 3 + t.TxH % 18, t.TaxDue)
         ELSE DATEADD(DAY, -10 + t.TxH % 17, t.TaxDue) END,
    t.TaxDue, NULL,
    CASE WHEN t.TxH % 1000 < 985 THEN 1 ELSE 0 END,
    CASE WHEN t.TxH % 997 < 985 THEN 1 ELSE 0 END, 1,
    @LoadBatchId
FROM #Tax t ORDER BY t.TaxSeq;

INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT 'DEF09', CAST(t.TaxSeq AS NVARCHAR(20))
FROM #Tax t
WHERE ABS(CHECKSUM('DEF09', t.TaxSeq)) % 1000 < 40;

DROP TABLE IF EXISTS #Pol;
SELECT ROW_NUMBER() OVER (ORDER BY e.LoanSeq, y.Yr)
        AS PolSeq,
    e.LoanNumber, e.LoanSeq, e.OrigAmt,
    DATEFROMPARTS(y.Yr,
        1 + ABS(CHECKSUM('POLM', e.LoanSeq)) % 12, 15)
        AS PolExp,
    ABS(CHECKSUM('INH', e.LoanSeq, y.Yr)) % 1000 AS InH
INTO #Pol
FROM #EscLoan e
JOIN (VALUES (2024),(2025),(2026)) y(Yr) ON 1 = 1
JOIN #Month m
  ON m.PeriodKey = y.Yr * 100
     + (1 + ABS(CHECKSUM('POLM', e.LoanSeq)) % 12)
WHERE m.MonthIx BETWEEN e.BoardMonthIx AND e.EndIx;

INSERT INTO src.SvcInsurancePolicy
    (LoanNumber, PolicyTypeCode, PolicyEffectiveDate,
     PolicyExpirationDate, AnnualPremiumAmount, LoadBatchId)
SELECT p.LoanNumber, 'HAZ',
    DATEADD(YEAR, -1, p.PolExp), p.PolExp,
    ROUND(p.OrigAmt * 0.0035, 2), @LoadBatchId
FROM #Pol p ORDER BY p.PolSeq;

INSERT INTO src.SvcInsurancePolicy
    (LoanNumber, PolicyTypeCode, PolicyEffectiveDate,
     PolicyExpirationDate, AnnualPremiumAmount, LoadBatchId)
SELECT e.LoanNumber, 'LPI', '2025-08-01', '2026-08-01',
    ROUND(e.OrigAmt * 0.009, 2), @LoadBatchId
FROM #EscLoan e WHERE e.LpiFlag = 1 ORDER BY e.LoanSeq;

INSERT INTO src.SvcInsurancePolicy
    (LoanNumber, PolicyTypeCode, PolicyEffectiveDate,
     PolicyExpirationDate, AnnualPremiumAmount, LoadBatchId)
SELECT e.LoanNumber, 'FLOOD', '2024-01-01', '2027-01-01',
    650.00, @LoadBatchId
FROM #EscLoan e WHERE e.FloodZone = 1 ORDER BY e.LoanSeq;

INSERT INTO src.SvcEscrowDisbursement
    (LoanNumber, DisbursementTypeCode, PayeeName,
     DisbursedAmount, DisbursedDate, TaxDueDate,
     PolicyExpirationDate, AmountMatchFlag, PayeeMatchFlag,
     LoanMatchFlag, LoadBatchId)
SELECT p.LoanNumber, 'INS', N'Sunbelt Mutual Insurance',
    ROUND(p.OrigAmt * 0.0035, 2),
    CASE WHEN p.InH < 950
         THEN DATEADD(DAY, -(5 + p.InH % 20), p.PolExp)
         ELSE DATEADD(DAY, 1 + p.InH % 10, p.PolExp) END,
    NULL, p.PolExp, 1, 1, 1, @LoadBatchId
FROM #Pol p ORDER BY p.PolSeq;

/* ============================================================
   9. Default cases: forbearance, mods, LM, FC, BK
   ============================================================ */
INSERT INTO src.SvcForbearancePlan
    (LoanNumber, PlanStartDate, PlanEndDate, PlanStatusCode,
     ExitDestinationCode, LoadBatchId)
SELECT L.LoanNumber,
    DATEADD(DAY, L.MiscH % 10,
        DATEADD(MONTH, L.FbStartIx - 1, '2023-08-01')),
    CASE WHEN L.FbEndIx <= 36
         THEN EOMONTH(DATEADD(MONTH, L.FbEndIx - 1,
              '2023-08-01')) END,
    CASE WHEN L.FbEndIx <= 36 THEN 'COMPLETED'
         ELSE 'ACTIVE' END,
    CASE WHEN L.FbEndIx > 36 THEN NULL
         WHEN L.ModIx IS NOT NULL THEN 'MOD'
         WHEN L.MiscH % 100 < 60 THEN 'REINSTATED'
         ELSE 'DEFERRAL' END,
    @LoadBatchId
FROM #L L WHERE L.FbStartIx IS NOT NULL
ORDER BY L.LoanSeq;

INSERT INTO src.SvcLoanModification
    (LoanNumber, ModificationEffectiveDate,
     ModificationBookedDate, PreModRatePercent,
     PostModRatePercent, LoadBatchId)
SELECT L.LoanNumber,
    DATEADD(DAY, 1 + L.MiscH % 8,
        DATEADD(MONTH, L.ModIx - 1, '2023-08-01')),
    DATEADD(DAY, 4 + L.MiscH % 10,
        DATEADD(MONTH, L.ModIx - 1, '2023-08-01')),
    L.NoteRate, L.NoteRate - 1.25, @LoadBatchId
FROM #L L
WHERE L.ModIx IS NOT NULL AND L.ModIx <= 36
ORDER BY L.LoanSeq;

DROP TABLE IF EXISTS #Lm;
SELECT L.LoanSeq, L.LoanNumber, L.ProfH, L.MiscH,
    L.E, L.ModIx,
    DATEADD(DAY, 3 + L.MiscH % 12,
        DATEADD(MONTH, L.E, '2023-08-01')) AS LmRecv
INTO #Lm
FROM #L L
WHERE L.ProfH BETWEEN 780 AND 919
  AND L.E + 1 <= ISNULL(L.TermIx, 36);

INSERT INTO src.DmsLossMitigationCase
    (LoanNumber, AppReceivedDate, CompletePackageDate,
     DecisionDate, DecisionCode, WorkoutTypeCode,
     TrialStartDate, TrialCompletedDate, TrialConvertedFlag,
     LoadBatchId)
SELECT c.LoanNumber, c.LmRecv,
    CASE WHEN c.MiscH % 1000 < 780
         THEN DATEADD(DAY, 7 + c.MiscH % 15, c.LmRecv) END,
    CASE WHEN c.MiscH % 1000 < 780
         THEN DATEADD(DAY, 12 + c.MiscH % 21,
              DATEADD(DAY, 7 + c.MiscH % 15, c.LmRecv)) END,
    CASE WHEN c.MiscH % 1000 >= 780 THEN NULL
         WHEN c.ModIx IS NOT NULL THEN 'MOD'
         WHEN c.ProfH BETWEEN 780 AND 824 THEN 'REPAY'
         WHEN c.ProfH BETWEEN 905 AND 919 THEN 'FORB'
         WHEN c.ProfH BETWEEN 860 AND 889 THEN
              CASE WHEN c.MiscH % 100 < 70 THEN 'DENY'
                   ELSE 'SHORTSALE' END
         ELSE 'DENY' END,
    CASE WHEN c.ModIx IS NOT NULL THEN 'TRIAL_MOD'
         WHEN c.ProfH BETWEEN 780 AND 824 THEN 'REPAY'
         WHEN c.ProfH BETWEEN 905 AND 919 THEN 'FORB' END,
    CASE WHEN c.ModIx IS NOT NULL
         THEN DATEADD(MONTH, -3,
              DATEADD(DAY, 1,
              DATEADD(MONTH, c.ModIx - 1,
              '2023-08-01'))) END,
    CASE WHEN c.ModIx IS NOT NULL
         THEN DATEADD(DAY, 1,
              DATEADD(MONTH, c.ModIx - 1,
              '2023-08-01')) END,
    CASE WHEN c.ModIx IS NOT NULL THEN 1
         WHEN c.ProfH BETWEEN 825 AND 859 THEN 0 END,
    @LoadBatchId
FROM #Lm c ORDER BY c.LoanSeq;

INSERT INTO src.DmsForeclosureCase
    (LoanNumber, FirstLegalEligibleDate, ReferralDate,
     FirstLegalDate, SaleScheduledDate, SaleHeldDate,
     CaseStatusCode, ResolutionTypeCode, LoadBatchId)
SELECT L.LoanNumber,
    DATEADD(DAY, 1 + L.MiscH % 10,
        DATEADD(MONTH, L.FcRefIx - 1, '2023-08-01')),
    DATEADD(DAY, 1 + L.MiscH % 10 + 2 + L.MiscH % 38,
        DATEADD(MONTH, L.FcRefIx - 1, '2023-08-01')),
    DATEADD(DAY, 30 + L.MiscH % 20,
        DATEADD(DAY, 1 + L.MiscH % 10 + 2 + L.MiscH % 38,
        DATEADD(MONTH, L.FcRefIx - 1, '2023-08-01'))),
    CASE WHEN L.FcSaleIx <= 36
         THEN DATEADD(DAY, -15,
              DATEADD(DAY, 10 + L.MiscH % 12,
              DATEADD(MONTH, L.FcSaleIx - 1,
              '2023-08-01'))) END,
    CASE WHEN L.FcSaleIx <= 36
         THEN DATEADD(DAY, 10 + L.MiscH % 12,
              DATEADD(MONTH, L.FcSaleIx - 1,
              '2023-08-01')) END,
    CASE WHEN L.FcSaleIx <= 36 THEN 'CLOSED'
         ELSE 'OPEN' END,
    CASE WHEN L.FcSaleIx <= 36 THEN 'SALE' END,
    @LoadBatchId
FROM #L L WHERE L.FcRefIx IS NOT NULL
ORDER BY L.LoanSeq;

INSERT INTO src.DmsBankruptcyCase
    (LoanNumber, ChapterCode, PetitionDate, PocBarDate,
     PocFiledDate, CaseStatusCode, DispositionCode,
     LoadBatchId)
SELECT L.LoanNumber,
    CASE WHEN L.MiscH % 100 < 80 THEN '13' ELSE '7' END,
    DATEADD(DAY, 2 + L.MiscH % 12,
        DATEADD(MONTH, L.BkIx - 1, '2023-08-01')),
    DATEADD(DAY, 70,
        DATEADD(DAY, 2 + L.MiscH % 12,
        DATEADD(MONTH, L.BkIx - 1, '2023-08-01'))),
    CASE WHEN L.MiscH % 1000 < 920
         THEN DATEADD(DAY, 70 - (3 + L.MiscH % 25),
              DATEADD(DAY, 2 + L.MiscH % 12,
              DATEADD(MONTH, L.BkIx - 1, '2023-08-01')))
         ELSE DATEADD(DAY, 70 + 1 + L.MiscH % 10,
              DATEADD(DAY, 2 + L.MiscH % 12,
              DATEADD(MONTH, L.BkIx - 1, '2023-08-01')))
    END,
    CASE WHEN L.BkEndIx <= 36 THEN 'CLOSED' ELSE 'OPEN' END,
    CASE WHEN L.BkEndIx <= 36 THEN
         CASE WHEN L.MiscH % 100 < 70 THEN 'DISCHARGED'
              ELSE 'DISMISSED' END END,
    @LoadBatchId
FROM #L L WHERE L.BkIx IS NOT NULL
ORDER BY L.LoanSeq;

/* ============================================================
   10. Investor reporting, remittances, repurchase
   ============================================================ */
INSERT INTO src.InvLoanReport
    (LoanNumber, InvestorCode, ReportingPeriod,
     ReportingDeadlineDate, ReportSubmittedDate,
     AcceptedFlag, ErrorCount, ReportedTransactionCount,
     CorrectionResubmissionFlag, LoadBatchId)
SELECT s.LoanNumber, s.InvestorCode, s.PeriodKey,
    DATEFROMPARTS(YEAR(DATEADD(MONTH, 1, s.AsOfDate)),
        MONTH(DATEADD(MONTH, 1, s.AsOfDate)), 15),
    CASE WHEN ABS(CHECKSUM('IRT', s.LoanNumber, s.MonthIx))
              % 1000 < 960
         THEN DATEADD(DAY,
              -(1 + ABS(CHECKSUM('IRD', s.LoanNumber,
                s.MonthIx)) % 4),
              DATEFROMPARTS(
                YEAR(DATEADD(MONTH, 1, s.AsOfDate)),
                MONTH(DATEADD(MONTH, 1, s.AsOfDate)), 15))
         ELSE DATEADD(DAY,
              1 + ABS(CHECKSUM('IRD', s.LoanNumber,
                s.MonthIx)) % 3,
              DATEFROMPARTS(
                YEAR(DATEADD(MONTH, 1, s.AsOfDate)),
                MONTH(DATEADD(MONTH, 1, s.AsOfDate)), 15))
    END,
    CASE WHEN ABS(CHECKSUM('IER', s.LoanNumber, s.MonthIx))
              % 1000 < 25
          AND ABS(CHECKSUM('IAC', s.LoanNumber, s.MonthIx))
              % 100 < 50
         THEN 0 ELSE 1 END,
    CASE WHEN ABS(CHECKSUM('IER', s.LoanNumber, s.MonthIx))
              % 1000 < 25
         THEN 1 + ABS(CHECKSUM('IEC', s.LoanNumber,
              s.MonthIx)) % 3 ELSE 0 END,
    1 + ABS(CHECKSUM('ITC', s.LoanNumber, s.MonthIx)) % 4,
    CASE WHEN s.MonthIx IN (28, 31)
              AND ABS(CHECKSUM('DEF13', s.LoanNumber))
              % 1000 < 60 THEN 1
         WHEN ABS(CHECKSUM('ICR', s.LoanNumber, s.MonthIx))
              % 1000 < 15 THEN 1 ELSE 0 END,
    @LoadBatchId
FROM #Snap s
WHERE s.MonthIx <> ISNULL(s.TermIx, -1)
ORDER BY s.MonthIx, s.LoanSeq;

INSERT INTO dq.SyntheticDefectTruth (DefectCode, KeyValue1)
SELECT DISTINCT 'DEF13', s.LoanNumber FROM #Snap s
WHERE s.MonthIx IN (28, 31)
  AND s.MonthIx <> ISNULL(s.TermIx, -1)
  AND ABS(CHECKSUM('DEF13', s.LoanNumber)) % 1000 < 60;

INSERT INTO src.InvRemittance
    (InvestorCode, RemittancePeriod, RemittanceDueDate,
     RemittanceSentDate, RemittanceAmount, LoadBatchId)
SELECT s.InvestorCode, s.PeriodKey,
    DATEFROMPARTS(YEAR(DATEADD(MONTH, 1, s.AsOfDate)),
        MONTH(DATEADD(MONTH, 1, s.AsOfDate)), 18),
    CASE WHEN ABS(CHECKSUM('RMT', s.InvestorCode,
              s.PeriodKey)) % 100 < 95
         THEN DATEADD(DAY,
              -(1 + ABS(CHECKSUM('RMD', s.InvestorCode,
                s.PeriodKey)) % 3),
              DATEFROMPARTS(
                YEAR(DATEADD(MONTH, 1, s.AsOfDate)),
                MONTH(DATEADD(MONTH, 1, s.AsOfDate)), 18))
         ELSE DATEADD(DAY,
              1 + ABS(CHECKSUM('RMD', s.InvestorCode,
                s.PeriodKey)) % 3,
              DATEFROMPARTS(
                YEAR(DATEADD(MONTH, 1, s.AsOfDate)),
                MONTH(DATEADD(MONTH, 1, s.AsOfDate)), 18))
    END,
    SUM(ROUND(s.BegUpb * s.NoteRate / 1200.0
        + s.BegUpb * 0.0025, 2)),
    @LoadBatchId
FROM #Snap s
WHERE s.MonthIx <> ISNULL(s.TermIx, -1)
GROUP BY s.InvestorCode, s.PeriodKey, s.AsOfDate
ORDER BY s.PeriodKey, s.InvestorCode;

INSERT INTO src.InvRepurchaseDemand
    (LoanNumber, InvestorCode, DemandReceivedDate,
     DemandReasonCode, DemandAmount, ResolutionDate,
     ResolutionTypeCode, LoadBatchId)
SELECT L.LoanNumber, L.InvestorCode,
    DATEADD(DAY, ABS(CHECKSUM('RPD', L.LoanSeq)) % 1000,
        '2023-09-01'),
    CASE WHEN L.MiscH % 100 < 40 THEN 'DATA_DEFECT'
         WHEN L.MiscH % 100 < 70 THEN 'INCOME_DOC'
         ELSE 'APPRAISAL' END,
    L.OrigAmt,
    CASE WHEN L.MiscH % 100 < 60
         THEN DATEADD(DAY,
              40 + ABS(CHECKSUM('RPR', L.LoanSeq)) % 130,
              DATEADD(DAY,
              ABS(CHECKSUM('RPD', L.LoanSeq)) % 1000,
              '2023-09-01')) END,
    CASE WHEN L.MiscH % 100 < 60 THEN
         CASE WHEN L.MiscH % 10 < 6 THEN 'RESCINDED'
              WHEN L.MiscH % 10 < 9 THEN 'INDEMNIFIED'
              ELSE 'REPURCHASED' END END,
    @LoadBatchId
FROM #L L
WHERE L.InvestorCode IN ('FNMA','FHLMC','GNMA')
  AND ABS(CHECKSUM('RPX', L.LoanSeq)) % 1000 < 8
  AND DATEADD(DAY, ABS(CHECKSUM('RPD', L.LoanSeq)) % 1000,
      '2023-09-01') < '2026-07-01'
ORDER BY L.LoanSeq;

/* ============================================================
   11. Valuations: origination + annual AVM + BPO
   ============================================================ */
INSERT INTO src.ValPropertyValuation
    (LoanNumber, ValuationDate, ValuationMethodCode,
     PropertyValueAmount, LoadBatchId)
SELECT L.LoanNumber, L.OrigDate, 'APPRAISAL',
    ROUND(L.OrigAmt
        / (0.62 + (ABS(CHECKSUM('LTV', L.LoanSeq)) % 36)
        / 100.0), 0),
    @LoadBatchId
FROM #L L ORDER BY L.LoanSeq;

INSERT INTO src.ValPropertyValuation
    (LoanNumber, ValuationDate, ValuationMethodCode,
     PropertyValueAmount, LoadBatchId)
SELECT L.LoanNumber,
    DATEADD(YEAR, y.Yr - 2023,
        DATEFROMPARTS(2023, 9, 10 + L.MiscH % 15)),
    'AVM',
    ROUND(L.OrigAmt
        / (0.62 + (ABS(CHECKSUM('LTV', L.LoanSeq)) % 36)
        / 100.0)
        * POWER(1.0 + (ABS(CHECKSUM('DRF', L.LoanSeq, y.Yr))
          % 9 - 2) / 100.0, y.Yr - 2022), 0),
    @LoadBatchId
FROM #L L
JOIN (VALUES (2023),(2024),(2025)) y(Yr)
  ON DATEADD(YEAR, y.Yr - 2023,
     DATEFROMPARTS(2023, 9, 10)) >=
     DATEADD(MONTH, L.BoardMonthIx - 1, '2023-08-01')
 AND (L.TermIx IS NULL OR
      DATEADD(YEAR, y.Yr - 2023,
      DATEFROMPARTS(2023, 9, 10))
      <= EOMONTH(DATEADD(MONTH, L.TermIx - 1,
         '2023-08-01')))
ORDER BY L.LoanSeq, y.Yr;

INSERT INTO src.ValPropertyValuation
    (LoanNumber, ValuationDate, ValuationMethodCode,
     PropertyValueAmount, LoadBatchId)
SELECT L.LoanNumber,
    DATEADD(DAY, 10,
        DATEADD(MONTH, L.E + 1, '2023-08-01')),
    'BPO',
    ROUND(L.OrigAmt
        / (0.62 + (ABS(CHECKSUM('LTV', L.LoanSeq)) % 36)
        / 100.0) * 0.93, 0),
    @LoadBatchId
FROM #L L
WHERE L.ProfH BETWEEN 860 AND 904 AND L.E + 2 <= 36
ORDER BY L.LoanSeq;

/* ============================================================
   12. Completion + generation profile
   ============================================================ */
EXEC audit.usp_CompleteLoadBatch @LoadBatchId, 'SUCCESS';

SELECT 'src.CrmLead' AS TableName, COUNT(*) AS RowCnt
FROM src.CrmLead
UNION ALL SELECT 'src.LosApplication', COUNT(*)
FROM src.LosApplication
UNION ALL SELECT 'src.PpeRateLock', COUNT(*)
FROM src.PpeRateLock
UNION ALL SELECT 'src.LicLoanOfficerRoster', COUNT(*)
FROM src.LicLoanOfficerRoster
UNION ALL SELECT 'src.LicLoanOfficerLicense', COUNT(*)
FROM src.LicLoanOfficerLicense
UNION ALL SELECT 'src.BrdBoardingTape', COUNT(*)
FROM src.BrdBoardingTape
UNION ALL SELECT 'src.SvcLoanMaster', COUNT(*)
FROM src.SvcLoanMaster
UNION ALL SELECT 'src.SvcLoanMonthEnd', COUNT(*)
FROM src.SvcLoanMonthEnd
UNION ALL SELECT 'src.PayPaymentTransaction', COUNT(*)
FROM src.PayPaymentTransaction
UNION ALL SELECT 'src.SvcEscrowAnalysis', COUNT(*)
FROM src.SvcEscrowAnalysis
UNION ALL SELECT 'src.SvcEscrowDisbursement', COUNT(*)
FROM src.SvcEscrowDisbursement
UNION ALL SELECT 'src.SvcInsurancePolicy', COUNT(*)
FROM src.SvcInsurancePolicy
UNION ALL SELECT 'src.SvcForbearancePlan', COUNT(*)
FROM src.SvcForbearancePlan
UNION ALL SELECT 'src.SvcLoanModification', COUNT(*)
FROM src.SvcLoanModification
UNION ALL SELECT 'src.DmsLossMitigationCase', COUNT(*)
FROM src.DmsLossMitigationCase
UNION ALL SELECT 'src.DmsForeclosureCase', COUNT(*)
FROM src.DmsForeclosureCase
UNION ALL SELECT 'src.DmsBankruptcyCase', COUNT(*)
FROM src.DmsBankruptcyCase
UNION ALL SELECT 'src.InvLoanReport', COUNT(*)
FROM src.InvLoanReport
UNION ALL SELECT 'src.InvRemittance', COUNT(*)
FROM src.InvRemittance
UNION ALL SELECT 'src.InvRepurchaseDemand', COUNT(*)
FROM src.InvRepurchaseDemand
UNION ALL SELECT 'src.ValPropertyValuation', COUNT(*)
FROM src.ValPropertyValuation
UNION ALL SELECT 'dq.SyntheticDefectTruth', COUNT(*)
FROM dq.SyntheticDefectTruth
ORDER BY TableName;

SELECT e.AsOfDate,
       COUNT(*) AS ActiveLoans,
       SUM(e.CurrentUpbAmount) AS PortfolioUpb
FROM src.SvcLoanMonthEnd e
WHERE e.LoanStatusCode IN ('ACT','FC','BK','FB')
  AND e.AsOfDate IN
      ('2023-08-31','2025-03-31','2026-07-31')
GROUP BY e.AsOfDate
ORDER BY e.AsOfDate;

PRINT 'Script 014 complete: synthetic enterprise data '
    + 'generated with 20 defects and truth capture.';
END TRY
BEGIN CATCH
    EXEC audit.usp_LogError @LoadBatchId = @LoadBatchId,
         @ContextInfo = N'014_generate_synthetic_data.sql';
    EXEC audit.usp_CompleteLoadBatch @LoadBatchId, 'FAILED';
    THROW;
END CATCH
GO
