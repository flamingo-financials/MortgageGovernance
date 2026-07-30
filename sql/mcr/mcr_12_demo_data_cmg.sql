/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_12_demo_data_cmg.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT - ADD-ON
   12 - Demo data extract: CMG Financial (Fictional Demo)
   ----------------------------------------------------------------------------
   Prereq: scripts 01-10 installed. Safe to re-run (idempotent cleanup).
   Deploy 14_hmda_recon.sql and/or 15_mbfrf_layer.sql FIRST if you want
   the demo to stage a HMDA LAR and MBFRF values and exercise rules
   12-14.

   Generates TWO filings in the 9000-9999 test range:
     9210 = Q4 2025 (prior baseline)
     9211 = Q1 2026 (current)
   5 states (CA, TX, OK, GA, NY), 10 MLOs (2 per state, 9900001-9900010).

   ALL DATA IS FICTIONAL. NMLS ID 9990001 is fake by design; do not
   substitute the real CMG NMLS ID.

   Deterministic generation (modular arithmetic, no RAND) so rebuilds are
   identical. Shaped to pass usp_ValidateFiling with 0 errors:
     - ClosedLoans generated 1:1 from ClosedFunded apps, NoteAmount =
       AppAmount  -> rules 5 (QM=AC070) and 7 (MLO=AC070) tie exactly
     - ServicingPortfolio drives ownership/status/investor partitions from
       the same rows -> rules 8, 9, 10 tie exactly
   GA closed volume is +55% QoQ on purpose: the variance report flags it.

   If 14_hmda_recon.sql is installed, a matching HMDA LAR is staged BEFORE
   the pipeline runs, so the pipeline's stage 3a reconciles it for 9211
   automatically (findings land ahead of any archive snapshot). If
   15_mbfrf_layer.sql is installed, MBFRF values (loader-derived plus
   tying manual balance-sheet entries) are staged the same way and
   stage 3b runs rules 13/14 - expected all-PASS. The script then runs
   both explicitly for prior filing 9210, which never goes through the
   pipeline. Two extra TX LAR rows are injected on purpose so the
   HMDA01/HMDA04 checks produce a real WARNING to demo the control.
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CompanyName VARCHAR(150) = 'CMG Financial (Fictional Demo)';
DECLARE @CompanyNmls BIGINT       = 9990001;   -- fictional
DECLARE @PriorId     INT          = 9210;
DECLARE @CurId       INT          = 9211;

/* ---------------------------------------------------------- cleanup ---- */
DELETE FROM mcr.RepeatingValues   WHERE FilingId IN (@PriorId, @CurId);
DELETE FROM mcr.ReportValues      WHERE FilingId IN (@PriorId, @CurId);
DELETE FROM mcr.ValidationResults WHERE FilingId IN (@PriorId, @CurId);
DELETE FROM mcrstg.Applications      WHERE FilingId IN (@PriorId, @CurId);
DELETE FROM mcrstg.ClosedLoans       WHERE FilingId IN (@PriorId, @CurId);
DELETE FROM mcrstg.ServicingPortfolio WHERE FilingId IN (@PriorId, @CurId);
DELETE FROM mcrstg.ServicingTransfers WHERE FilingId IN (@PriorId, @CurId);
DELETE FROM mcrstg.WarehouseLines    WHERE FilingId IN (@PriorId, @CurId);
DELETE FROM mcrstg.Repurchases       WHERE FilingId IN (@PriorId, @CurId);
IF OBJECT_ID('mcrstg.HmdaLar') IS NOT NULL
    DELETE FROM mcrstg.HmdaLar       WHERE FilingId IN (@PriorId, @CurId);
IF OBJECT_ID('mcr.MbfrfValues') IS NOT NULL
    DELETE FROM mcr.MbfrfValues   WHERE FilingId IN (@PriorId, @CurId);
DELETE FROM mcr.Filing            WHERE FilingId IN (@PriorId, @CurId);

/* ---------------------------------------------------------- filings ---- */
EXEC mcr.usp_CreateFiling
    @FilingId = @PriorId, @CompanyNmlsId = @CompanyNmls,
    @CompanyName = @CompanyName, @Year = 2025, @PeriodType = 'MCRQ4',
    @PeriodStart = '2025-10-01', @PeriodEnd = '2025-12-31',
    @PrimaryStateCode = 'CA';

EXEC mcr.usp_CreateFiling
    @FilingId = @CurId, @CompanyNmlsId = @CompanyNmls,
    @CompanyName = @CompanyName, @Year = 2026, @PeriodType = 'MCRQ1',
    @PeriodStart = '2026-01-01', @PeriodEnd = '2026-03-31',
    @PrimaryStateCode = 'CA', @PriorFilingId = @PriorId;

/* ------------------------------------------------ investors (guarded) -- */
INSERT INTO mcrstg.Investors (InvestorCode, InvestorNmlsId, InvestorName, PoolNumber)
SELECT v.InvestorCode, v.InvestorNmlsId, v.InvestorName, v.PoolNumber
FROM (VALUES
    ('FNMA',        900001, 'Fictional National Mtg Assoc', 'FN-2026-01'),
    ('FHLMC',       900002, 'Fictional Home Loan Corp',     'FH-2026-01'),
    ('GNMA',        900003, 'Fictional Gov Mtg Assoc',      'GN-2026-01'),
    ('PrivateLabel',900004, 'Fictional Private Investor',   'PL-2026-01'),
    ('Other',       900005, 'Fictional Other Investor',     NULL)
) v(InvestorCode, InvestorNmlsId, InvestorName, PoolNumber)
WHERE NOT EXISTS (SELECT 1 FROM mcrstg.Investors i
                  WHERE i.InvestorCode = v.InvestorCode);

/* ----------------------------------------------------- state config ---- *
   ClosedCur / ClosedPri = closed-loan counts per quarter.
   GA jumps 9 -> 14 (+55%) to exercise the variance flag.                  */
DECLARE @States TABLE (
    StateIdx  INT         NOT NULL,
    StateCode CHAR(2)     NOT NULL,
    ClosedCur INT         NOT NULL,
    ClosedPri INT         NOT NULL,
    BaseAmt   BIGINT      NOT NULL
);
INSERT INTO @States VALUES
(1, 'CA', 40, 36, 550000),
(2, 'TX', 30, 28, 380000),
(3, 'OK', 12, 11, 280000),
(4, 'GA', 14,  9, 320000),
(5, 'NY',  8,  8, 500000);

/* ------------------------------------------------------ applications --- *
   Disjoint status rows per state (same pattern as the 01 sample data).
   Counts derived from the closed count c:
     BOP = c/2   ANA = c/10   Denied = c/8   WD = c/8   FCI = c/20
     Received = c + ANA + Denied + WD + FCI + c/4     EOP = c/2 + c/4
   ApplicationId = FilingId*1000000 + StateIdx*100000
                 + StatusIdx*10000 + n  (unique, decodable)                 */
;WITH t0 AS (
    SELECT n = 1
    FROM (VALUES (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) x(n)
),
tally AS (
    SELECT n = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
    FROM t0 a CROSS JOIN t0 b CROSS JOIN t0 c
),
fil AS (
    SELECT FilingId = @CurId,   Which = 'CUR'
    UNION ALL
    SELECT FilingId = @PriorId, Which = 'PRI'
),
base AS (
    SELECT f.FilingId, s.StateIdx, s.StateCode, s.BaseAmt,
           Closed = CASE f.Which WHEN 'CUR' THEN s.ClosedCur
                                 ELSE s.ClosedPri END
    FROM fil f CROSS JOIN @States s
),
cfg AS (
    SELECT b.FilingId, b.StateIdx, b.StateCode, b.BaseAmt,
           st.StatusIdx, st.DecisionStatus,
           Cnt = CASE st.DecisionStatus
               WHEN 'InProcessBOP'         THEN b.Closed / 2
               WHEN 'Received'             THEN b.Closed + b.Closed/10
                                              + b.Closed/8 + b.Closed/8
                                              + b.Closed/20 + b.Closed/4
               WHEN 'ApprovedNotAccepted'  THEN b.Closed / 10
               WHEN 'Denied'               THEN b.Closed / 8
               WHEN 'Withdrawn'            THEN b.Closed / 8
               WHEN 'FileClosedIncomplete' THEN b.Closed / 20
               WHEN 'ClosedFunded'         THEN b.Closed
               WHEN 'InProcessEOP'         THEN b.Closed/2 + b.Closed/4
           END
    FROM base b
    CROSS JOIN (VALUES
        (1,'InProcessBOP'), (2,'Received'), (3,'ApprovedNotAccepted'),
        (4,'Denied'), (5,'Withdrawn'), (6,'FileClosedIncomplete'),
        (7,'ClosedFunded'), (8,'InProcessEOP')
    ) st(StatusIdx, DecisionStatus)
)
INSERT INTO mcrstg.Applications
    (ApplicationId, FilingId, StateCode, AppDate, DecisionStatus,
     SourceChannel, AppAmount)
SELECT
    CAST(cfg.FilingId AS BIGINT) * 1000000
        + cfg.StateIdx * 100000 + cfg.StatusIdx * 10000 + t.n,
    cfg.FilingId,
    cfg.StateCode,
    CASE WHEN cfg.DecisionStatus = 'InProcessBOP'
         THEN DATEADD(DAY, -1, fl.PeriodStart)
         ELSE DATEADD(DAY, (t.n * 7) % 85, fl.PeriodStart) END,
    cfg.DecisionStatus,
    CASE WHEN (t.n + cfg.StateIdx) % 20 < 13
         THEN 'DirectBorrower' ELSE 'ThirdParty' END,
    cfg.BaseAmt + ((t.n * 37) % 9) * 10000 - 40000
FROM cfg
JOIN mcr.Filing fl ON fl.FilingId = cfg.FilingId
JOIN tally t       ON t.n <= cfg.Cnt;

/* ------------------------------------------------------- closed loans -- *
   1:1 from ClosedFunded apps; NoteAmount = AppAmount so the QM split
   and MLO list reconcile to AC070 in dollars and count.
   MLO assignment: 2 per state, 9900001-9900010.                            */
;WITH src AS (
    SELECT a.ApplicationId, a.FilingId, a.StateCode, a.AppDate, a.AppAmount,
           StateIdx = CAST(a.ApplicationId / 100000 % 10 AS INT),
           n = ROW_NUMBER() OVER (PARTITION BY a.FilingId, a.StateCode
                                  ORDER BY a.ApplicationId)
    FROM mcrstg.Applications a
    WHERE a.FilingId IN (@PriorId, @CurId)
      AND a.DecisionStatus = 'ClosedFunded'
)
INSERT INTO mcrstg.ClosedLoans
    (LoanId, FilingId, StateCode, CloseDate, Channel, LoanType,
     PropertyType, Purpose, LienStatus, HoepaStatus, AmortType, Conforming,
     QmStatus, ServicingDispo, UPB, NoteAmount, AppraisedValue, FicoScore,
     NoteRatePct, MloNmlsId)
SELECT
    s.ApplicationId,                             -- reuse as unique LoanId
    s.FilingId,
    s.StateCode,
    s.AppDate,
    ch.Channel,
    lt.LoanType,
    CASE WHEN s.n % 20 = 19 THEN 'Manufactured' ELSE 'OneToFour' END,
    CASE WHEN s.n % 20 < 12 THEN 'Purchase'
         WHEN s.n % 20 < 19 THEN 'Refinance'
         ELSE 'HomeImprovement' END,
    CASE WHEN s.n % 25 = 23 THEN 'Subordinate'
         WHEN s.n % 25 = 24 THEN 'NoLien'
         ELSE 'First' END,
    'NotHOEPA',
    CASE WHEN s.n % 5 = 4 THEN 'ARM' ELSE 'Fixed' END,
    cf.Conforming,
    CASE WHEN s.n % 20 < 17 THEN 'QM'
         WHEN s.n % 20 < 19 THEN 'NonQM'
         ELSE 'NotSubject' END,
    CASE WHEN ch.Channel = 'Brokered' THEN 'NA'
         WHEN s.n % 5 < 2 THEN 'Retained'
         ELSE 'Released' END,
    s.AppAmount,                                 -- UPB
    s.AppAmount,                                 -- NoteAmount = AppAmount
    CAST(s.AppAmount * 100.0 / lv.LtvPct AS BIGINT),
    660 + (s.n * 7) % 140,
    CAST(6.000 + ((s.n * 13) % 150) / 100.0 AS DECIMAL(6,3)),
    9900001 + (s.StateIdx - 1) * 2 + s.n % 2
FROM src s
CROSS APPLY (SELECT Channel =
    CASE WHEN s.n % 20 < 3  THEN 'Brokered'
         WHEN s.n % 20 < 16 THEN 'ClosedRetail'
         ELSE 'ClosedWholesale' END) ch
CROSS APPLY (SELECT LoanType =
    CASE WHEN s.n % 20 < 14 THEN 'Conventional'
         WHEN s.n % 20 < 18 THEN 'FHA'
         WHEN s.n % 20 < 19 THEN 'VA'
         ELSE 'FSARHS' END) lt
CROSS APPLY (SELECT Conforming =
    CASE WHEN lt.LoanType <> 'Conventional' THEN 'Government'
         WHEN s.n % 20 < 15 THEN 'Conforming'
         WHEN s.n % 20 < 19 THEN 'Jumbo'
         ELSE 'Other' END) cf
CROSS APPLY (SELECT LtvPct = 55 + (s.n % 6) * 10) lv;  -- 55..105 fills I370-I375

/* -------------------------------------------------- servicing portfolio *
   Rows per (filing, state) = that state's closed count. Ownership /
   investor / delinquency partitions all derive from the same rows, so
   validation rules 8-10 tie by construction.                              */
;WITH t0 AS (
    SELECT n = 1
    FROM (VALUES (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) x(n)
),
tally AS (
    SELECT n = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
    FROM t0 a CROSS JOIN t0 b
),
fil AS (
    SELECT FilingId = @CurId,   Which = 'CUR'
    UNION ALL
    SELECT FilingId = @PriorId, Which = 'PRI'
),
base AS (
    SELECT f.FilingId, s.StateIdx, s.StateCode,
           Rows_ = CASE f.Which WHEN 'CUR' THEN s.ClosedCur
                                ELSE s.ClosedPri END
    FROM fil f CROSS JOIN @States s
)
INSERT INTO mcrstg.ServicingPortfolio
    (ServiceId, FilingId, StateCode, OwnershipType, Investor,
     DelinquencyBucket, InForeclosure, UPB)
SELECT
    CAST(b.FilingId AS BIGINT) * 100000 + b.StateIdx * 1000 + t.n,
    b.FilingId,
    b.StateCode,
    CASE WHEN t.n % 10 < 4 THEN 'WhollyOwned'
         WHEN t.n % 10 < 7 THEN 'UnderMSR'
         WHEN t.n % 10 < 9 THEN 'SubservicingForOthers'
         ELSE 'SubservicedByOthers' END,
    CASE t.n % 5 WHEN 0 THEN 'FNMA' WHEN 1 THEN 'FHLMC'
                 WHEN 2 THEN 'GNMA' WHEN 3 THEN 'PrivateLabel'
                 ELSE 'Other' END,
    CASE WHEN t.n % 25 < 21 THEN 'LT30'
         WHEN t.n % 25 < 23 THEN 'D30_59'
         WHEN t.n % 25 < 24 THEN 'D60_89'
         ELSE 'D90Plus' END,
    CASE WHEN t.n % 25 = 24 THEN 1 ELSE 0 END,
    150000 + ((t.n * 31) % 300) * 1000
FROM base b
JOIN tally t ON t.n <= b.Rows_;

/* --------------------------------------- transfers / lines / repurchase */
INSERT INTO mcrstg.ServicingTransfers
    (TransferId, FilingId, Direction, UPB, LoanCount) VALUES
(CAST(@CurId AS BIGINT)*100 + 1, @CurId,   'In',  2400000, 9),
(CAST(@CurId AS BIGINT)*100 + 2, @CurId,   'Out', 1100000, 4),
(CAST(@PriorId AS BIGINT)*100 + 1, @PriorId, 'In',  1800000, 7),
(CAST(@PriorId AS BIGINT)*100 + 2, @PriorId, 'Out', 1500000, 6);

INSERT INTO mcrstg.WarehouseLines
    (LineId, FilingId, ProviderName, CreditLimit, RemainingCredit) VALUES
(@CurId*10 + 1, @CurId, 'Fictional Warehouse Bank A', 75000000, 61000000),
(@CurId*10 + 2, @CurId, 'Fictional Warehouse Bank B', 50000000, 44000000),
(@CurId*10 + 3, @CurId, 'Fictional Warehouse Bank C', 25000000, 25000000),
(@PriorId*10 + 1, @PriorId, 'Fictional Warehouse Bank A', 75000000, 58000000),
(@PriorId*10 + 2, @PriorId, 'Fictional Warehouse Bank B', 50000000, 41000000);

INSERT INTO mcrstg.Repurchases
    (RepurchaseId, FilingId, StateCode, Investor, UPB, LoanCount) VALUES
(CAST(@CurId AS BIGINT)*10 + 1, @CurId,   'CA', 'FNMA',  410000, 1),
(CAST(@CurId AS BIGINT)*10 + 2, @CurId,   'TX', 'FHLMC', 355000, 1),
(CAST(@PriorId AS BIGINT)*10 + 1, @PriorId, 'CA', 'FNMA', 380000, 1);

/* ------------------------------------------------- HMDA LAR (rule 12) -- *
   Requires 14_hmda_recon.sql. Staged BEFORE the pipeline so stage 3a
   reconciles it for the current filing. LAR rows derive from the same
   apps/loans:
     ActionTaken 1 = funded loans EXCLUDING Brokered channel (the funding
                     lender reports those on its LAR, not you)
     ActionTaken 2/3/4/5 = ANA / Denied / Withdrawn / Incomplete apps
   Plus 2 synthetic TX originations to breach the 5% tolerance and demo
   the WARNING path.                                                      */
IF OBJECT_ID('mcrstg.HmdaLar') IS NOT NULL
BEGIN
    INSERT INTO mcrstg.HmdaLar
        (LarId, FilingId, Uli, ActionTaken, ActionDate, StateCode,
         LoanAmount, LoanPurpose)
    SELECT
        c.LoanId,
        c.FilingId,
        'DEMOULI' + CAST(c.LoanId AS VARCHAR(19)),
        1,
        c.CloseDate,
        c.StateCode,
        c.NoteAmount,
        CASE c.Purpose WHEN 'Purchase' THEN 1
                       WHEN 'HomeImprovement' THEN 2
                       ELSE 31 END
    FROM mcrstg.ClosedLoans c
    WHERE c.FilingId IN (@PriorId, @CurId)
      AND c.Channel <> 'Brokered';

    INSERT INTO mcrstg.HmdaLar
        (LarId, FilingId, Uli, ActionTaken, ActionDate, StateCode,
         LoanAmount, LoanPurpose)
    SELECT
        a.ApplicationId,
        a.FilingId,
        'DEMOULI' + CAST(a.ApplicationId AS VARCHAR(19)),
        CASE a.DecisionStatus
            WHEN 'ApprovedNotAccepted'  THEN 2
            WHEN 'Denied'               THEN 3
            WHEN 'Withdrawn'            THEN 4
            WHEN 'FileClosedIncomplete' THEN 5 END,
        a.AppDate,
        a.StateCode,
        a.AppAmount,
        CASE WHEN a.ApplicationId % 2 = 0 THEN 1 ELSE 31 END
    FROM mcrstg.Applications a
    WHERE a.FilingId IN (@PriorId, @CurId)
      AND a.DecisionStatus IN ('ApprovedNotAccepted','Denied',
                               'Withdrawn','FileClosedIncomplete');

    /* intentional drift: 2 extra TX originations, current quarter only */
    INSERT INTO mcrstg.HmdaLar
        (LarId, FilingId, Uli, ActionTaken, ActionDate, StateCode,
         LoanAmount, LoanPurpose)
    VALUES
    (CAST(@CurId AS BIGINT) * 1000000 + 999001, @CurId,
     'DEMOULI-DRIFT-1', 1, '2026-03-30', 'TX', 385000, 1),
    (CAST(@CurId AS BIGINT) * 1000000 + 999002, @CurId,
     'DEMOULI-DRIFT-2', 1, '2026-03-31', 'TX', 402000, 31);
END
ELSE
    PRINT 'mcrstg.HmdaLar not installed (run 14_hmda_recon.sql); '
        + 'LAR demo rows skipped.';

/* -------------------------------------------- MBFRF (rules 13/14) ------ *
   Requires 15_mbfrf_layer.sql. Staged BEFORE the pipeline so stage 3b
   checks and reconciles it for the current filing. Derived fields come
   from the same ClosedLoans / ServicingPortfolio / Repurchases rows the
   MCR uses, and the manual balance-sheet entries tie by construction
   (A100 = L100 + E100; A010 = the 8,500,000 the loader stages into MCR
   FC A010_1), so rules 13 and 14 come back all-PASS - this layer demos
   the clean-grid path, the HMDA layer demos the WARNING path.          */
IF OBJECT_ID('mcr.MbfrfValues') IS NOT NULL
BEGIN
    EXEC mcr.usp_LoadMbfrfFromSource @FilingId = @CurId;
    EXEC mcr.usp_LoadMbfrfFromSource @FilingId = @PriorId;

    INSERT INTO mcr.MbfrfValues (FilingId, FieldCode, NumValue)
    SELECT f.FilingId, m.FieldCode, m.NumValue
    FROM (VALUES (@CurId), (@PriorId)) f(FilingId)
    CROSS JOIN (VALUES
        ('A010',   8500000),   -- ties MCR FC A010_1 (MBF01)
        ('A030A',  2200000),
        ('A060',  42000000),
        ('A100',  65000000),   -- = L100 + E100 (CHK01)
        ('L100',  48000000),
        ('E100',  17000000),
        ('I100',   1850000)
    ) m(FieldCode, NumValue);
END
ELSE
    PRINT 'mcr.MbfrfValues not installed (run 15_mbfrf_layer.sql); '
        + 'MBFRF demo values skipped.';

/* ---------------------------------------------------------- pipeline --- *
   Stage 3a inside the pipeline runs the rule 12 reconciliation for 9211
   when the 14 layer is deployed (LAR was staged above).
   Expected demo result: TX WARNs on HMDA01 (27 LAR vs 25 MCR = 8% >
   5% tolerance) and HMDA04 (one drift row is purchase-purpose, ~5.9%);
   HMDA02 stays inside its 10% amount tolerance; everything else PASSes. */
DECLARE @Xml NVARCHAR(MAX);
EXEC mcr.usp_RunFilingPipeline
    @FilingId = @CurId, @BlockOnError = 1, @RunVariance = 1, @Xml = @Xml OUTPUT;

PRINT 'Demo build complete. Filing ' + CAST(@CurId AS VARCHAR(10))
    + ' XML length: '
    + ISNULL(CAST(LEN(@Xml) AS VARCHAR(12)), 'NULL (blocked on error)');

/* Prior filing 9210 never runs through the pipeline (it is only staged
   as the variance baseline), so its reconciliations run explicitly.
   Expected: HMDA all PASS (no drift rows in the prior quarter);
   MBFRF rules 13/14 all PASS.                                          */
IF OBJECT_ID('mcr.usp_ReconcileHmda') IS NOT NULL
    EXEC mcr.usp_ReconcileHmda @FilingId = @PriorId;
IF OBJECT_ID('mcr.usp_ValidateMbfrf') IS NOT NULL
    EXEC mcr.usp_ValidateMbfrf @FilingId = @PriorId;

/* Optional next steps:
   EXEC mcr.usp_ReconcileHmda @FilingId = 9211;  -- rerun rule 12 grid
   EXEC mcr.usp_ValidateMbfrf @FilingId = 9211;  -- rerun rules 13/14
   EXEC mcr.usp_GetMbfrfKeyingPackage @FilingId = 9211; -- WebMB grid
   EXEC mcr.usp_ArchiveMbfrf @FilingId = 9211;   -- freeze MBFRF values
   EXEC mcr.usp_QaVariance @FilingId = 9211;     -- rerun variance grid
   EXEC mcr.usp_ArchiveFiling @FilingId = 9211;  -- freeze for sign-off
*/
