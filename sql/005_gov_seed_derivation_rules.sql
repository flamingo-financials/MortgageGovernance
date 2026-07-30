/* ============================================================
   MortgageGovernance | Phase 2 | Script 005
   Derivation rule registry: 67 DRV rules with canonical
   logic, plus logical inputs by staging-contract column.
   Logic is registered once here; physical bindings arrive
   in Phase 7 (gov.SourceToTargetMap). Implementing objects
   are attached in Phase 6.
   Idempotent: deletes and reloads all DRV rules.
   Note: after Phase 7, re-run the binding script following
   any reseed of this file.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

DECLARE @LoadBatchId INT;

EXEC audit.usp_StartLoadBatch
     @BatchName     = N'Phase 2 derivation rule seed',
     @BatchTypeCode = 'SEED',
     @Notes         = N'Script 005: 67 DRV rules and inputs.',
     @LoadBatchId   = @LoadBatchId OUTPUT;

BEGIN TRY
BEGIN TRAN;

DELETE ri
FROM gov.DerivationRuleInput ri
JOIN gov.DerivationRule r
  ON r.DerivationRuleId = ri.DerivationRuleId
WHERE r.RuleCode LIKE 'DRV[_]%';

DELETE FROM gov.DerivationRule
WHERE RuleCode LIKE 'DRV[_]%';

/* ------------------------------------------------------------
   Group 1: Portfolio, delinquency, and credit (16)
   ------------------------------------------------------------ */
INSERT INTO gov.DerivationRule
    (RuleCode, RuleName, BusinessDescription, CanonicalLogic,
     ImplementationTypeCode, LoadBatchId)
VALUES
('DRV_DPD','Days Past Due',
 'Contractual days past due at the as-of date.',
 'DaysPastDue =
  CASE WHEN NextPaymentDueDate IS NULL THEN 0
       WHEN NextPaymentDueDate >= @AsOfDate THEN 0
       ELSE DATEDIFF(DAY, NextPaymentDueDate, @AsOfDate)
  END',
 'INLINE_TVF', @LoadBatchId),

('DRV_DQBUCKET','Delinquency Bucket',
 'MBA-style bucket aligned to MCR FV7 breakpoints.',
 'SELECT b.DelinquencyBucketCode
FROM ref.DelinquencyBucket b
WHERE @DaysPastDue >= b.MinDpd
  AND (@DaysPastDue <= b.MaxDpd OR b.MaxDpd IS NULL);
Buckets: CURRENT (<30), DPD30_59, DPD60_89, DPD90_PLUS.
Breakpoints live in ref.DelinquencyBucket, never in CASE
expressions.',
 'LOOKUP_JOIN', @LoadBatchId),

('DRV_ACTIVEPOP','Active Servicing Population',
 'Population gate for all servicing rate metrics.',
 'ActiveServicingFlag =
  CASE WHEN LoanStatusCode IN (''ACT'',''FC'',''BK'',''FB'')
       THEN 1 ELSE 0 END',
 'INLINE_TVF', @LoadBatchId),

('DRV_ROLL3060','Roll Rate 30 to 60',
 'Loans rolling from the 30-59 bucket to 60 or worse '
 + 'between consecutive month-ends.',
 'Roll30to60Flag =
  CASE WHEN prior.DelinquencyBucketCode = ''DPD30_59''
        AND curr.DelinquencyBucketCode IN
            (''DPD60_89'',''DPD90_PLUS'')
       THEN 1 ELSE 0 END
Join: consecutive month-end snapshots on LoanId.',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_CURE','Cure',
 'Delinquent last month-end, current this month-end.',
 'CureFlag =
  CASE WHEN prior.DelinquencyBucketCode <> ''CURRENT''
        AND curr.DelinquencyBucketCode = ''CURRENT''
       THEN 1 ELSE 0 END',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_RUNOFF','Portfolio Runoff',
 'Terminal exits between month-ends with governed '
 + 'reason codes.',
 'RunoffFlag = 1 when a loan present at the prior
month-end is terminal or absent at the current month-end.
RunoffReasonCode IN (''VOL_PAYOFF'',''REFINANCE'',
''SHORT_SALE'',''TRANSFER_OUT'',''FC_SALE'').
Portfolio Runoff Rate = runoff UPB / beginning UPB.',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_SMM_CPR','SMM and CPR',
 'Voluntary prepayment speed, annualized.',
 'SMM = VoluntaryPrepaidPrincipal
      / NULLIF(BeginningUpb - ScheduledPrincipal, 0);
CPR = 1 - POWER(1 - SMM, 12)',
 'VIEW', @LoadBatchId),

('DRV_MODSEASON','Modification Seasoning',
 'Splits modified loans at 12 months for RMLA III '
 + 'S320-S359 alignment.',
 'ModSeasoningCode =
  CASE WHEN ModificationEffectiveDate IS NULL THEN NULL
       WHEN DATEDIFF(MONTH, ModificationEffectiveDate,
            @AsOfDate) < 12 THEN ''MOD_LT_1YR''
       ELSE ''MOD_GE_1YR'' END',
 'INLINE_TVF', @LoadBatchId),

('DRV_REDEFAULT','Modification Redefault',
 'Modified loans reaching 90+ within 12 months of the '
 + 'modification effective date.',
 'ModRedefaultFlag = 1 when a modified loan reaches
DPD90_PLUS within 12 months of
ModificationEffectiveDate.
Cohort: modifications effective in the trailing
12 months.',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_CLTV','Current LTV',
 'UPB over the latest property valuation.',
 'CurrentLtvPct = CurrentUpb
  / NULLIF(v.PropertyValue, 0)
using the latest valuation per loan:
ROW_NUMBER() OVER (PARTITION BY LoanId
ORDER BY ValuationDate DESC,
         PropertyValuationId DESC) = 1',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_LTVBAND','LTV Band',
 'Band assignment from the governed reference table.',
 'SELECT b.LtvBandCode
FROM ref.LtvBand b
WHERE @CurrentLtvPct >= b.MinLtvPct
  AND (@CurrentLtvPct < b.MaxLtvPct
       OR b.MaxLtvPct IS NULL)
Aligns to RMLA III S1000-S1090 bands.',
 'LOOKUP_JOIN', @LoadBatchId),

('DRV_CONFORMING','Conforming Flag',
 'Original amount versus the conforming limit for the '
 + 'origination year and unit count.',
 'ConformingFlag =
  CASE WHEN OriginalLoanAmount <= l.LimitAmount
       THEN 1 ELSE 0 END
via ref.ConformingLoanLimit matched on origination
year and unit count.',
 'LOOKUP_JOIN', @LoadBatchId),

('DRV_MCRLOANTYPE','MCR Loan Type Class',
 'Loan type classification for RMLA III S700-S790.',
 'McrLoanTypeCode =
  CASE WHEN LoanProgramCode IN (''FHA'',''VA'',''USDA'')
            THEN ''GOVT''
       WHEN LoanProgramCode = ''CONV''
            AND ConformingFlag = 1 THEN ''CONV_CONF''
       WHEN LoanProgramCode = ''CONV''
            AND ConformingFlag = 0 THEN ''CONV_NONCONF''
       ELSE ''OTHER'' END',
 'INLINE_TVF', @LoadBatchId),

('DRV_RATETYPE','Rate Type',
 'Fixed versus ARM for RMLA III S600-S690.',
 'RateTypeCode =
  CASE WHEN InterestRateTypeCode = ''ARM'' THEN ''ARM''
       ELSE ''FIXED'' END',
 'INLINE_TVF', @LoadBatchId),

('DRV_PRODCLASS','Product Class',
 'Product classification for RMLA III S790-S890.',
 'ProductClassCode =
  CASE WHEN ReverseMortgageFlag = 1 THEN ''REVERSE''
       WHEN HelocFlag = 1 THEN ''HELOC''
       WHEN LienPosition = 1 THEN ''FIRST''
       WHEN LienPosition > 1 THEN ''CE_SECOND''
       ELSE ''OTHER'' END',
 'INLINE_TVF', @LoadBatchId),

('DRV_FORBFLAG','Forbearance Flag',
 'Active forbearance plan covering the snapshot date. '
 + 'Aligns to LS1500-LS1590 and S470-S474.',
 'ForbearanceFlag = 1 when an approved plan span covers
the snapshot date:
PlanStartDate <= @AsOfDate
AND (PlanEndDate IS NULL OR PlanEndDate >= @AsOfDate)
AND PlanStatusCode = ''ACTIVE''',
 'PROC_SET_BASED', @LoadBatchId);

/* ------------------------------------------------------------
   Group 2: Payments, escrow, boarding, investor, default (24)
   ------------------------------------------------------------ */
INSERT INTO gov.DerivationRule
    (RuleCode, RuleName, BusinessDescription, CanonicalLogic,
     ImplementationTypeCode, LoadBatchId)
VALUES
('DRV_NEXTBIZDAY','Next Business Day',
 'Business-day resolution from the date dimension, '
 + 'never from weekday math.',
 'NextBusinessDate =
  (SELECT MIN(d.CalendarDate)
   FROM dw.DimDate d
   WHERE d.CalendarDate > @FromDate
     AND d.IsBusinessDay = 1)',
 'INLINE_TVF', @LoadBatchId),

('DRV_PAYTIMELY','Payment Posting Timeliness',
 'Posted no later than the next business day after '
 + 'receipt.',
 'PostedTimelyFlag =
  CASE WHEN PostedDate <=
       dw.ufn_NextBusinessDate(ReceivedDate)
       THEN 1 ELSE 0 END
Population: payments received in period.',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_PAYACC','Payment Posting Accuracy',
 'Original postings later reversed and reapplied count '
 + 'as inaccurate.',
 'PostedAccuratelyFlag = 0 when the transaction is later
reversed and reapplied (ReversalFlag = 1 chained by
OriginalTransactionId), else 1.
Accuracy rate counts original postings only.',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_SUSPENSE','Unapplied Funds Rate',
 'Dollar-based suspense exposure at month-end.',
 'UnappliedFundsRate =
  SUM(SuspenseBalance)
  / NULLIF(SUM(PaymentsReceivedAmount), 0)
Dollar basis at the month-end snapshot.',
 'INLINE_TVF', @LoadBatchId),

('DRV_ESCTIMELY','Escrow Analysis Timeliness',
 'Analysis completed by the governed cycle due date.',
 'EscrowAnalysisTimelyFlag =
  CASE WHEN AnalysisCompletedDate <= c.AnalysisDueDate
       THEN 1 ELSE 0 END
Due date from ref.EscrowAnalysisCycle by state and
cycle month.',
 'INLINE_TVF', @LoadBatchId),

('DRV_DISBACC','Escrow Disbursement Accuracy',
 'Amount, payee, and loan must all match the presented '
 + 'bill.',
 'DisbursementAccurateFlag =
  CASE WHEN AmountMatchFlag = 1
        AND PayeeMatchFlag = 1
        AND LoanMatchFlag = 1
       THEN 1 ELSE 0 END',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_TAXTIMELY','Tax Disbursement Timeliness',
 'Tax paid on or before the taxing authority due date.',
 'TaxDisbursedTimelyFlag =
  CASE WHEN DisbursementTypeCode = ''TAX''
        AND DisbursedDate <= TaxDueDate THEN 1
       WHEN DisbursementTypeCode = ''TAX'' THEN 0
  END',
 'INLINE_TVF', @LoadBatchId),

('DRV_INSTIMELY','Insurance Disbursement Timeliness',
 'Premium paid before policy expiration.',
 'InsuranceDisbursedTimelyFlag =
  CASE WHEN DisbursementTypeCode = ''INS''
        AND DisbursedDate <= PolicyExpirationDate THEN 1
       WHEN DisbursementTypeCode = ''INS'' THEN 0
  END',
 'INLINE_TVF', @LoadBatchId),

('DRV_LPI','Lender Placed Insurance',
 'Active lender placed policy at the snapshot date.',
 'LenderPlacedFlag = 1 when an active policy with
PolicyTypeCode = ''LPI'' covers the snapshot date.
LPI Rate = loans with LenderPlacedFlag = 1
/ active escrowed loans.',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_BOARDONTIME','Boarding Timeliness',
 'Boarded within the SLA window after transfer '
 + 'effective date.',
 'BoardedOnTimeFlag =
  CASE WHEN BoardingCompletedDate <=
       DATEADD(DAY, sla.SlaDays, TransferEffectiveDate)
       THEN 1 ELSE 0 END
SLA days from ref.SlaPolicy code ''BOARDING''.',
 'INLINE_TVF', @LoadBatchId),

('DRV_BOARDACC','Boarding Data Accuracy',
 'Five critical fields compared tape versus core after '
 + 'boarding.',
 'BoardingAccuracyScore = matched critical fields / 5.
Critical fields: CurrentUpb, InterestRate,
NextPaymentDueDate, EscrowBalance, InvestorCode.
BoardingAccurateFlag = 1 when all 5 match.',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_INVTIMELY','Investor Reporting Timeliness',
 'Report submitted by the investor deadline.',
 'InvestorReportTimelyFlag =
  CASE WHEN ReportSubmittedDate <= ReportingDeadlineDate
       THEN 1 ELSE 0 END',
 'INLINE_TVF', @LoadBatchId),

('DRV_INVACC','Investor Reporting Accuracy',
 'Accepted, error free, and never resubmitted.',
 'InvestorReportAccurateFlag =
  CASE WHEN AcceptedFlag = 1
        AND ErrorCount = 0
        AND CorrectionResubmissionFlag = 0
       THEN 1 ELSE 0 END
Loan-Level Transaction Error Rate = SUM(ErrorCount)
/ NULLIF(SUM(ReportedTransactionCount), 0).',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_REMITTIMELY','Cash Remittance Timeliness',
 'Remittance sent by the investor due date.',
 'RemittanceTimelyFlag =
  CASE WHEN RemittanceSentDate <= RemittanceDueDate
       THEN 1 ELSE 0 END
Due date per investor remittance calendar.',
 'INLINE_TVF', @LoadBatchId),

('DRV_REPODAYS','Repurchase Resolution Days',
 'Demand receipt to resolution.',
 'RepurchaseResolutionDays =
  DATEDIFF(DAY, DemandReceivedDate, ResolutionDate)
Open demands are excluded from turn time and aged in
the pipeline view.',
 'INLINE_TVF', @LoadBatchId),

('DRV_FCREFTIMELY','Foreclosure Referral Timeliness',
 'Referral within SLA of first legal eligibility.',
 'FcReferralTimelyFlag =
  CASE WHEN ReferralDate <=
       DATEADD(DAY, sla.SlaDays, FirstLegalEligibleDate)
       THEN 1 ELSE 0 END
SLA days from ref.SlaPolicy code ''FC_REFERRAL''.',
 'LOOKUP_JOIN', @LoadBatchId),

('DRV_FCTIMELINE','Foreclosure Timeline Days',
 'Referral to sale; open cases age to the as-of date.',
 'FcTimelineDays =
  DATEDIFF(DAY, ReferralDate,
           ISNULL(SaleHeldDate, @AsOfDate))',
 'INLINE_TVF', @LoadBatchId),

('DRV_SHERIFF','Foreclosure Sale Held',
 'Sale held within the reporting period.',
 'FcSaleHeldFlag =
  CASE WHEN SaleHeldDate IS NOT NULL
        AND SaleHeldDate BETWEEN @PeriodStart
            AND @PeriodEnd
       THEN 1 ELSE 0 END',
 'INLINE_TVF', @LoadBatchId),

('DRV_FCACTIVE','Active Foreclosure Flag',
 'Open case at the snapshot date. Aligns to S400-S440 '
 + 'and LS1400-LS1490.',
 'FcActiveFlag = 1 when an open foreclosure case
(CaseStatusCode = ''OPEN'') exists for the loan at the
snapshot date.',
 'INLINE_TVF', @LoadBatchId),

('DRV_POCTIMELY','Proof of Claim Timeliness',
 'Proof of claim filed by the bar date.',
 'ProofOfClaimTimelyFlag =
  CASE WHEN PocFiledDate <= PocBarDate
       THEN 1 ELSE 0 END
Population: bankruptcy cases with a bar date in period.',
 'INLINE_TVF', @LoadBatchId),

('DRV_LMCOMPLETE','Loss Mitigation App Completeness',
 'Complete package received.',
 'LossMitAppCompleteFlag =
  CASE WHEN CompletePackageDate IS NOT NULL
       THEN 1 ELSE 0 END
Completion Rate = complete apps / apps received in
period.',
 'INLINE_TVF', @LoadBatchId),

('DRV_LMTURN','Loss Mitigation Evaluation Turn Time',
 'Complete package to decision.',
 'EvalTurnTimeDays =
  DATEDIFF(DAY, CompletePackageDate, DecisionDate)
Population: decisions issued in period with a complete
package date.',
 'INLINE_TVF', @LoadBatchId),

('DRV_LMAPPROVE','Workout Approval',
 'Approved workout decision codes.',
 'WorkoutApprovedFlag =
  CASE WHEN DecisionCode IN (''MOD'',''REPAY'',''DEFER'',
       ''FORB'',''SHORTSALE'',''DIL'') THEN 1
       WHEN DecisionCode = ''DENY'' THEN 0
  END
Approval Rate = approved / decisioned.',
 'INLINE_TVF', @LoadBatchId),

('DRV_TRIALCONV','Trial Plan Conversion',
 'Trial modification followed by a booked permanent '
 + 'modification.',
 'TrialConvertedFlag = 1 when a trial plan
(WorkoutTypeCode = ''TRIAL_MOD'') is followed by a
permanent modification booked for the same loan within
plan terms.
Conversion Rate = converted trials / completed trials.',
 'PROC_SET_BASED', @LoadBatchId);

/* ------------------------------------------------------------
   Group 3: Governance program metrics (8)
   ------------------------------------------------------------ */
INSERT INTO gov.DerivationRule
    (RuleCode, RuleName, BusinessDescription, CanonicalLogic,
     ImplementationTypeCode, LoadBatchId)
VALUES
('DRV_CDECOMPLETE','CDE Completeness',
 'Non-null rate across bound critical data element '
 + 'columns.',
 'CdeCompletenessPct = non-null values in bound CDE
columns / total rows evaluated, per element, then
averaged. Bindings resolve from gov.DataElementBinding
where the element is registered in
gov.CriticalDataElement.',
 'VIEW', @LoadBatchId),

('DRV_DQDEFECT','Data Quality Defect Rate',
 'Failed rows over evaluated rows for the latest DQ '
 + 'batch.',
 'DqDefectRatePct =
  SUM(FailedRowCount)
  / NULLIF(SUM(EvaluatedRowCount), 0)
from dq.RuleExecutionResult for the latest DQ batch.',
 'VIEW', @LoadBatchId),

('DRV_LINEAGECOV','Data Lineage Coverage',
 'CDEs with a complete source-to-report path.',
 'LineageCoveragePct = CDEs with a complete
source-to-report path / total CDEs.
Path test: recursive traversal over gov.LineageEdge
from a SOURCE_FIELD node to a DAX_MEASURE or
REPORT_VISUAL node.',
 'VIEW', @LoadBatchId),

('DRV_GLOSSCOV','Business Glossary Coverage',
 'Elements linked to approved terms.',
 'GlossaryCoveragePct = data elements linked to an
APPROVED gov.BusinessTerm / total active data
elements.',
 'VIEW', @LoadBatchId),

('DRV_KPICOV','KPI Definition Coverage',
 'Supported metrics with a complete specification.',
 'KpiDefinitionCoveragePct = metrics with RequiredGrain,
ReportingTimeBasisCode, PopulationLogic, and numerator
or calculation logic populated / metrics with
CoverageStatusCode = ''SUPPORTED''.',
 'VIEW', @LoadBatchId),

('DRV_REGRECON','Regulatory Reconciliation Accuracy',
 'Pass rate of MCR tie-out controls.',
 'RegulatoryReconAccuracyPct = PASS results / executed
results in audit.ReconciliationResult for controls of
ControlTypeCode = ''MCR_TIEOUT'' at the as-of date.',
 'VIEW', @LoadBatchId),

('DRV_ISSUEAGE','Data Issue Aging',
 'Issue age with standard aging buckets.',
 'IssueAgeDays = DATEDIFF(DAY, OpenedDate,
ISNULL(ClosedDate, @AsOfDate)) on gov.DataIssue.
Aging buckets: 0-30, 31-60, 61-90, 90+.',
 'VIEW', @LoadBatchId),

('DRV_JOBSUCCESS','Batch Job Success Rate',
 'Successful executions over completed executions.',
 'BatchJobSuccessRatePct = executions with
StatusCode = ''SUCCESS'' / executions with StatusCode
IN (''SUCCESS'',''FAILED'') from audit.LoadExecution in
period. SKIPPED is excluded.',
 'VIEW', @LoadBatchId);

/* ------------------------------------------------------------
   Group 4: E1 loan officer production governance (19)
   ------------------------------------------------------------ */
INSERT INTO gov.DerivationRule
    (RuleCode, RuleName, BusinessDescription, CanonicalLogic,
     ImplementationTypeCode, LoadBatchId)
VALUES
('DRV_LOATTRIB','Loan Officer Attribution',
 'Point-in-time SCD2 key resolution. Credit follows the '
 + 'LO of record; branch resolves as of the event date.',
 'Resolve LoanOfficerKey and BranchKey from
dw.DimLoanOfficer (SCD2) as of the event date:
lo.NmlsId = stg.LoanOfficerNmlsId
AND EventDate >= lo.EffectiveStartDate
AND EventDate <  lo.EffectiveEndDate.
Funding metrics use FundingDate; application-stage
metrics use AppReceivedDate. Resolved in load
procedures, never in DAX.',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_LEADCONV','Lead Conversion',
 'Lead to application conversion inside the governed '
 + 'attribution window.',
 'ConvertedFlag =
  CASE WHEN ConvertedApplicationId IS NOT NULL
       THEN 1 ELSE 0 END;
ConvertedInWindowFlag = 1 when AppReceivedDate <=
DATEADD(DAY, sla.SlaDays, LeadCreatedDate)
using ref.SlaPolicy code ''LEAD_ATTRIB'' (90 days).',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_APPPIPELINE','Application Pipeline Status As Of',
 'Point-in-time status reconstruction; powers MCR I '
 + 'AC010 and AC080 without a snapshot table.',
 'PipelineStatusAsOf =
  CASE WHEN AppReceivedDate > @AsOfDate THEN ''NOT_YET''
       WHEN FundingDate <= @AsOfDate THEN ''FUNDED''
       WHEN DispositionDate <= @AsOfDate
            AND DispositionCode = ''DENIED''
            THEN ''DENIED''
       WHEN DispositionDate <= @AsOfDate
            AND DispositionCode = ''WITHDRAWN''
            THEN ''WITHDRAWN''
       WHEN DispositionDate <= @AsOfDate
            AND DispositionCode = ''ANA''
            THEN ''APPR_NOT_ACC''
       WHEN DispositionDate <= @AsOfDate
            AND DispositionCode = ''INCOMPLETE''
            THEN ''INCOMPLETE''
       ELSE ''IN_PROCESS'' END',
 'INLINE_TVF', @LoadBatchId),

('DRV_APPCOMPLETE','Application Completed',
 'Signed and complete application package.',
 'AppCompletedFlag =
  CASE WHEN AppCompletedDate IS NOT NULL
       THEN 1 ELSE 0 END',
 'INLINE_TVF', @LoadBatchId),

('DRV_APPTOLOCK','Application Ever Locked',
 'Any lock event exists for the application.',
 'EverLockedFlag = 1 when EXISTS
(SELECT 1 FROM stg.RateLock k
 WHERE k.ApplicationId = a.ApplicationId).
Application-to-Lock Conversion = ever-locked apps /
apps received in period.',
 'PROC_SET_BASED', @LoadBatchId),

('DRV_PULLTHRU_LOCK','Pull-Through Rate (Lock Basis)',
 'Internal definition: funded lock volume over locked '
 + 'volume reaching terminal status.',
 'PullThroughLockBasis =
  SUM(LockAmount of funded locks)
  / NULLIF(SUM(LockAmount of locks reaching terminal
    status in period), 0)',
 'VIEW', @LoadBatchId),

('DRV_PULLTHRU_MCR','Pull-Through Ratio (Application Basis)',
 'MCR I430 definition. Derived Regulatory Field, '
 + 'reconciled separately from the lock basis metric.',
 'PullThroughApplicationBasis =
  COUNT(applications funded in period)
  / NULLIF(COUNT(applications received in period), 0)',
 'VIEW', @LoadBatchId),

('DRV_FALLOUT','Loan Officer Fallout',
 'Terminal non-funding dispositions. NULL while open.',
 'FallenOutFlag =
  CASE WHEN DispositionCode IN (''DENIED'',
       ''WITHDRAWN'',''ANA'',''INCOMPLETE'') THEN 1
       WHEN FundedFlag = 1 THEN 0
  END
Period basis per catalog definition; the cohort
variant is documented in the metric specification.',
 'INLINE_TVF', @LoadBatchId),

('DRV_DENIAL','Denial Rate Basis',
 'Decisioned-application basis; withdrawn and '
 + 'incomplete excluded.',
 'DenialEligibleFlag =
  CASE WHEN DispositionCode IN (''DENIED'',''ANA'')
        OR FundedFlag = 1 THEN 1 ELSE 0 END;
DeniedFlag =
  CASE WHEN DispositionCode = ''DENIED''
       THEN 1 ELSE 0 END;
Denial Rate = denied / (funded + denied +
approved-not-accepted).',
 'INLINE_TVF', @LoadBatchId),

('DRV_CYCLETIME','Origination Cycle Time',
 'Application received to funding, funded loans only.',
 'CycleTimeDays =
  CASE WHEN FundedFlag = 1 THEN
       DATEDIFF(DAY, AppReceivedDate, FundingDate)
  END',
 'INLINE_TVF', @LoadBatchId),

('DRV_ONTIMECLOSE','On-Time Closing',
 'Actual close on or before scheduled close.',
 'OnTimeCloseFlag =
  CASE WHEN ActualClosingDate IS NULL THEN NULL
       WHEN ActualClosingDate <= ScheduledClosingDate
       THEN 1 ELSE 0 END',
 'INLINE_TVF', @LoadBatchId),

('DRV_LOCKEXT','Lock Extension',
 'Any extension on the lock.',
 'ExtendedFlag =
  CASE WHEN ExtensionCount > 0 THEN 1 ELSE 0 END
Lock Extension Rate = extended locks / locks taken.',
 'INLINE_TVF', @LoadBatchId),

('DRV_LOCKEXP','Lock Expiration Without Funding',
 'Expired unfunded and never extended.',
 'ExpiredWithoutFundingFlag =
  CASE WHEN LockStatusCode = ''EXPIRED''
        AND FundedFlag = 0
        AND ExtensionCount = 0 THEN 1 ELSE 0 END',
 'INLINE_TVF', @LoadBatchId),

('DRV_RELOCK','Relock Identification',
 'Lock rows chained to a prior lock on the same '
 + 'application.',
 'RelockFlag = 1 on lock rows with
PriorLockId IS NOT NULL for the same application.
Relock Rate = relock rows / funded loans in period.',
 'INLINE_TVF', @LoadBatchId),

('DRV_MLOLIC','MLO License Compliance',
 'Active unexpired license in every state the LO '
 + 'funded in.',
 'LicenseCompliantFlag =
  CASE WHEN LicenseStatusCode = ''ACTIVE''
        AND ExpirationDate >= @AsOfDate
       THEN 1 ELSE 0 END
MLO License Compliance Rate = LOs compliant in every
state they funded in / LOs who funded in period.',
 'INLINE_TVF', @LoadBatchId),

('DRV_CE','Continuing Education Completion',
 'Required hours completed by the renewal deadline.',
 'CeCompliantFlag =
  CASE WHEN CeCompletedHours >= CeRequiredHours
        AND CeCompletedDate <= RenewalDeadline
       THEN 1 ELSE 0 END',
 'INLINE_TVF', @LoadBatchId),

('DRV_MKTSRC','Marketing-Sourced Funded Volume',
 'Funded volume attributed to marketing-sourced leads.',
 'MarketingSourcedFundedVolume =
  SUM(CurrentLoanAmount) for funded applications whose
originating lead carries MarketingSourcedFlag = 1 on
dw.DimLeadSource.',
 'VIEW', @LoadBatchId),

('DRV_REFSHARE','Referral Lead Share',
 'Referral-flagged leads over all leads created.',
 'ReferralLeadSharePct =
  leads with ReferralFlag = 1 / all leads created in
period, via dw.DimLeadSource.',
 'VIEW', @LoadBatchId),

('DRV_LOSCORE','Loan Officer Composite Score',
 'Weighted capped attainment against governed targets. '
 + 'License failure suppresses the composite.',
 'AttainmentPct =
  CASE t.DirectionCode
    WHEN ''HIGHER'' THEN m.ActualValue
         / NULLIF(t.TargetValue, 0)
    WHEN ''LOWER''  THEN t.TargetValue
         / NULLIF(m.ActualValue, 0)
  END;
CappedAttainment = capped to the range 0 to 1.5;
CompositeScore =
  100 * SUM(t.Weight * CappedAttainment)
      / NULLIF(SUM(t.Weight), 0)
from ref.ScorecardTarget. The composite is suppressed
when MLO license compliance fails: governance over
performance.',
 'PROC_SET_BASED', @LoadBatchId);

/* ------------------------------------------------------------
   Logical inputs (staging-contract column references).
   DataElementId binds in Phase 7.
   ------------------------------------------------------------ */
INSERT INTO gov.DerivationRuleInput
    (DerivationRuleId, InputReference, InputRoleNote,
     LoadBatchId)
SELECT r.DerivationRuleId, v.InputReference, v.RoleNote,
       @LoadBatchId
FROM (VALUES
 ('DRV_DPD','stg.LoanMonthEnd.NextPaymentDueDate',
  'Contractual due date'),
 ('DRV_DPD','@AsOfDate','Snapshot date parameter'),
 ('DRV_DQBUCKET','DaysPastDue','Output of DRV_DPD'),
 ('DRV_DQBUCKET','ref.DelinquencyBucket',
  'Governed breakpoints'),
 ('DRV_ACTIVEPOP','stg.LoanMonthEnd.LoanStatusCode',
  'Servicing status'),
 ('DRV_ROLL3060','Prior.DelinquencyBucketCode',
  'Prior month-end bucket'),
 ('DRV_ROLL3060','Current.DelinquencyBucketCode',
  'Current month-end bucket'),
 ('DRV_CURE','Prior.DelinquencyBucketCode',
  'Prior month-end bucket'),
 ('DRV_CURE','Current.DelinquencyBucketCode',
  'Current month-end bucket'),
 ('DRV_RUNOFF','stg.LoanMonthEnd.LoanStatusCode',
  'Terminal status detection'),
 ('DRV_RUNOFF','stg.LoanMonthEnd.RunoffReasonCode',
  'Governed exit reason'),
 ('DRV_RUNOFF','stg.LoanMonthEnd.CurrentUpb',
  'Runoff UPB numerator'),
 ('DRV_SMM_CPR','stg.LoanMonthEnd.VoluntaryPrepaidPrincipal',
  'Voluntary prepay in period'),
 ('DRV_SMM_CPR','stg.LoanMonthEnd.BeginningUpb',
  'Beginning balance'),
 ('DRV_SMM_CPR','stg.LoanMonthEnd.ScheduledPrincipal',
  'Scheduled amortization'),
 ('DRV_MODSEASON','stg.LoanModification.ModificationEffectiveDate',
  'Modification effective date'),
 ('DRV_MODSEASON','@AsOfDate','Snapshot date parameter'),
 ('DRV_REDEFAULT','stg.LoanModification.ModificationEffectiveDate',
  'Cohort anchor'),
 ('DRV_REDEFAULT','DelinquencyBucketCode',
  'Post-mod bucket path'),
 ('DRV_CLTV','stg.LoanMonthEnd.CurrentUpb','Numerator'),
 ('DRV_CLTV','stg.PropertyValuation.PropertyValue',
  'Latest valuation denominator'),
 ('DRV_CLTV','stg.PropertyValuation.ValuationDate',
  'Latest valuation ordering'),
 ('DRV_LTVBAND','CurrentLtvPct','Output of DRV_CLTV'),
 ('DRV_LTVBAND','ref.LtvBand','Governed bands'),
 ('DRV_CONFORMING','stg.LoanMaster.OriginalLoanAmount',
  'Amount tested'),
 ('DRV_CONFORMING','stg.LoanMaster.OriginationDate',
  'Limit year match'),
 ('DRV_CONFORMING','ref.ConformingLoanLimit',
  'Limit by year and units'),
 ('DRV_MCRLOANTYPE','stg.LoanMaster.LoanProgramCode',
  'Program classification'),
 ('DRV_MCRLOANTYPE','ConformingFlag',
  'Output of DRV_CONFORMING'),
 ('DRV_RATETYPE','stg.LoanMaster.InterestRateTypeCode',
  'Fixed or ARM'),
 ('DRV_PRODCLASS','stg.LoanMaster.LienPosition',
  'Lien position'),
 ('DRV_PRODCLASS','stg.LoanMaster.HelocFlag','HELOC flag'),
 ('DRV_PRODCLASS','stg.LoanMaster.ReverseMortgageFlag',
  'Reverse flag'),
 ('DRV_FORBFLAG','stg.ForbearancePlan.PlanStartDate',
  'Span start'),
 ('DRV_FORBFLAG','stg.ForbearancePlan.PlanEndDate',
  'Span end'),
 ('DRV_FORBFLAG','stg.ForbearancePlan.PlanStatusCode',
  'Active plan gate'),
 ('DRV_NEXTBIZDAY','dw.DimDate.IsBusinessDay',
  'Business calendar'),
 ('DRV_NEXTBIZDAY','@FromDate','Anchor date parameter'),
 ('DRV_PAYTIMELY','stg.PaymentTransaction.ReceivedDate',
  'Receipt date'),
 ('DRV_PAYTIMELY','stg.PaymentTransaction.PostedDate',
  'Posting date'),
 ('DRV_PAYACC','stg.PaymentTransaction.ReversalFlag',
  'Reversal marker'),
 ('DRV_PAYACC','stg.PaymentTransaction.OriginalTransactionId',
  'Reversal chain'),
 ('DRV_SUSPENSE','stg.LoanMonthEnd.SuspenseBalance',
  'Suspense exposure'),
 ('DRV_SUSPENSE','stg.PaymentTransaction.PaymentAmount',
  'Payments received denominator'),
 ('DRV_ESCTIMELY','stg.EscrowAnalysis.AnalysisCompletedDate',
  'Completion date'),
 ('DRV_ESCTIMELY','ref.EscrowAnalysisCycle',
  'Governed cycle due dates'),
 ('DRV_DISBACC','stg.EscrowDisbursement.AmountMatchFlag',
  'Amount match'),
 ('DRV_DISBACC','stg.EscrowDisbursement.PayeeMatchFlag',
  'Payee match'),
 ('DRV_DISBACC','stg.EscrowDisbursement.LoanMatchFlag',
  'Loan match'),
 ('DRV_TAXTIMELY','stg.EscrowDisbursement.DisbursedDate',
  'Disbursement date'),
 ('DRV_TAXTIMELY','stg.EscrowDisbursement.TaxDueDate',
  'Authority due date'),
 ('DRV_INSTIMELY','stg.EscrowDisbursement.DisbursedDate',
  'Disbursement date'),
 ('DRV_INSTIMELY','stg.InsurancePolicy.PolicyExpirationDate',
  'Policy expiration'),
 ('DRV_LPI','stg.InsurancePolicy.PolicyTypeCode',
  'LPI type gate'),
 ('DRV_LPI','stg.InsurancePolicy.PolicyEffectiveDate',
  'Coverage span start'),
 ('DRV_LPI','stg.InsurancePolicy.PolicyExpirationDate',
  'Coverage span end'),
 ('DRV_BOARDONTIME','stg.BoardingTape.TransferEffectiveDate',
  'SLA anchor'),
 ('DRV_BOARDONTIME','stg.BoardingTape.BoardingCompletedDate',
  'Completion date'),
 ('DRV_BOARDONTIME','ref.SlaPolicy','SLA code BOARDING'),
 ('DRV_BOARDACC','CriticalFieldMatchCount',
  'Tape versus core: 5 critical fields'),
 ('DRV_INVTIMELY','stg.InvestorLoanReport.ReportSubmittedDate',
  'Submission date'),
 ('DRV_INVTIMELY','stg.InvestorLoanReport.ReportingDeadlineDate',
  'Investor deadline'),
 ('DRV_INVACC','stg.InvestorLoanReport.AcceptedFlag',
  'Acceptance'),
 ('DRV_INVACC','stg.InvestorLoanReport.ErrorCount',
  'Loan-level errors'),
 ('DRV_INVACC','stg.InvestorLoanReport.CorrectionResubmissionFlag',
  'Resubmission marker'),
 ('DRV_REMITTIMELY','stg.InvestorRemittance.RemittanceSentDate',
  'Sent date'),
 ('DRV_REMITTIMELY','stg.InvestorRemittance.RemittanceDueDate',
  'Due date'),
 ('DRV_REPODAYS','stg.RepurchaseDemand.DemandReceivedDate',
  'Clock start'),
 ('DRV_REPODAYS','stg.RepurchaseDemand.ResolutionDate',
  'Clock end'),
 ('DRV_FCREFTIMELY','stg.ForeclosureCase.FirstLegalEligibleDate',
  'SLA anchor'),
 ('DRV_FCREFTIMELY','stg.ForeclosureCase.ReferralDate',
  'Referral date'),
 ('DRV_FCREFTIMELY','ref.SlaPolicy','SLA code FC_REFERRAL'),
 ('DRV_FCTIMELINE','stg.ForeclosureCase.ReferralDate',
  'Timeline start'),
 ('DRV_FCTIMELINE','stg.ForeclosureCase.SaleHeldDate',
  'Timeline end when held'),
 ('DRV_SHERIFF','stg.ForeclosureCase.SaleHeldDate',
  'Sale date in period'),
 ('DRV_FCACTIVE','stg.ForeclosureCase.CaseStatusCode',
  'Open case gate'),
 ('DRV_POCTIMELY','stg.BankruptcyCase.PocFiledDate',
  'Filing date'),
 ('DRV_POCTIMELY','stg.BankruptcyCase.PocBarDate',
  'Bar date'),
 ('DRV_LMCOMPLETE','stg.LossMitigationCase.CompletePackageDate',
  'Complete package'),
 ('DRV_LMTURN','stg.LossMitigationCase.CompletePackageDate',
  'Clock start'),
 ('DRV_LMTURN','stg.LossMitigationCase.DecisionDate',
  'Clock end'),
 ('DRV_LMAPPROVE','stg.LossMitigationCase.DecisionCode',
  'Decision classification'),
 ('DRV_TRIALCONV','stg.LossMitigationCase.WorkoutTypeCode',
  'Trial identification'),
 ('DRV_TRIALCONV','stg.LoanModification.ModificationBookedDate',
  'Permanent mod booking'),
 ('DRV_CDECOMPLETE','gov.DataElementBinding',
  'CDE column bindings'),
 ('DRV_CDECOMPLETE','gov.CriticalDataElement',
  'CDE register'),
 ('DRV_DQDEFECT','dq.RuleExecutionResult.FailedRowCount',
  'Failure numerator'),
 ('DRV_DQDEFECT','dq.RuleExecutionResult.EvaluatedRowCount',
  'Evaluation denominator'),
 ('DRV_LINEAGECOV','gov.LineageEdge','Lineage graph'),
 ('DRV_LINEAGECOV','gov.CriticalDataElement',
  'Coverage population'),
 ('DRV_GLOSSCOV','gov.DataElement.BusinessTermId',
  'Term linkage'),
 ('DRV_GLOSSCOV','gov.BusinessTerm.ApprovalStatusCode',
  'Approved gate'),
 ('DRV_KPICOV','gov.MetricDefinition',
  'Spec completeness columns'),
 ('DRV_REGRECON','audit.ReconciliationResult.StatusCode',
  'Control outcomes'),
 ('DRV_ISSUEAGE','gov.DataIssue.OpenedDate','Clock start'),
 ('DRV_ISSUEAGE','gov.DataIssue.ClosedDate',
  'Clock end when closed'),
 ('DRV_JOBSUCCESS','audit.LoadExecution.StatusCode',
  'Execution outcomes'),
 ('DRV_LOATTRIB','stg.Application.LoanOfficerNmlsId',
  'Business key'),
 ('DRV_LOATTRIB','EventDate',
  'FundingDate or AppReceivedDate'),
 ('DRV_LOATTRIB','dw.DimLoanOfficer.EffectiveStartDate',
  'SCD2 as-of resolution'),
 ('DRV_LEADCONV','stg.Lead.LeadCreatedDate','Window anchor'),
 ('DRV_LEADCONV','stg.Lead.ConvertedApplicationId',
  'Conversion linkage'),
 ('DRV_LEADCONV','stg.Application.AppReceivedDate',
  'Window test'),
 ('DRV_LEADCONV','ref.SlaPolicy','SLA code LEAD_ATTRIB'),
 ('DRV_APPPIPELINE','stg.Application.AppReceivedDate',
  'Pipeline entry'),
 ('DRV_APPPIPELINE','stg.Application.DispositionCode',
  'Terminal classification'),
 ('DRV_APPPIPELINE','stg.Application.DispositionDate',
  'Terminal timing'),
 ('DRV_APPPIPELINE','stg.Application.FundingDate',
  'Funding timing'),
 ('DRV_APPCOMPLETE','stg.Application.AppCompletedDate',
  'Completion marker'),
 ('DRV_APPTOLOCK','stg.RateLock.ApplicationId',
  'Lock existence'),
 ('DRV_PULLTHRU_LOCK','stg.RateLock.LockAmount',
  'Volume basis'),
 ('DRV_PULLTHRU_LOCK','stg.RateLock.LockStatusCode',
  'Terminal status gate'),
 ('DRV_PULLTHRU_LOCK','stg.Application.FundedFlag',
  'Funded numerator'),
 ('DRV_PULLTHRU_MCR','stg.Application.AppReceivedDate',
  'Denominator population'),
 ('DRV_PULLTHRU_MCR','stg.Application.FundingDate',
  'Numerator population'),
 ('DRV_FALLOUT','stg.Application.DispositionCode',
  'Terminal classification'),
 ('DRV_FALLOUT','stg.Application.FundedFlag',
  'Funded exclusion'),
 ('DRV_DENIAL','stg.Application.DispositionCode',
  'Decision classification'),
 ('DRV_DENIAL','stg.Application.FundedFlag',
  'Decisioned population'),
 ('DRV_CYCLETIME','stg.Application.AppReceivedDate',
  'Clock start'),
 ('DRV_CYCLETIME','stg.Application.FundingDate',
  'Clock end'),
 ('DRV_ONTIMECLOSE','stg.Application.ScheduledClosingDate',
  'Commitment'),
 ('DRV_ONTIMECLOSE','stg.Application.ActualClosingDate',
  'Actual'),
 ('DRV_LOCKEXT','stg.RateLock.ExtensionCount',
  'Extension marker'),
 ('DRV_LOCKEXP','stg.RateLock.LockStatusCode',
  'Expired gate'),
 ('DRV_LOCKEXP','stg.Application.FundedFlag',
  'Unfunded gate'),
 ('DRV_LOCKEXP','stg.RateLock.ExtensionCount',
  'Never extended gate'),
 ('DRV_RELOCK','stg.RateLock.PriorLockId','Relock chain'),
 ('DRV_MLOLIC','stg.LoanOfficerLicense.LicenseStatusCode',
  'Active gate'),
 ('DRV_MLOLIC','stg.LoanOfficerLicense.ExpirationDate',
  'Unexpired gate'),
 ('DRV_CE','stg.LoanOfficerLicense.CeRequiredHours',
  'Requirement'),
 ('DRV_CE','stg.LoanOfficerLicense.CeCompletedHours',
  'Completion'),
 ('DRV_CE','stg.LoanOfficerLicense.CeCompletedDate',
  'Completion timing'),
 ('DRV_CE','stg.LoanOfficerLicense.RenewalDeadline',
  'Deadline'),
 ('DRV_MKTSRC','stg.Application.CurrentLoanAmount',
  'Funded volume'),
 ('DRV_MKTSRC','dw.DimLeadSource.MarketingSourcedFlag',
  'Attribution gate'),
 ('DRV_REFSHARE','dw.DimLeadSource.ReferralFlag',
  'Referral gate'),
 ('DRV_REFSHARE','stg.Lead.LeadCreatedDate',
  'Period population'),
 ('DRV_LOSCORE','ref.ScorecardTarget.TargetValue',
  'Governed target'),
 ('DRV_LOSCORE','ref.ScorecardTarget.DirectionCode',
  'Higher or lower is better'),
 ('DRV_LOSCORE','ref.ScorecardTarget.Weight',
  'Governed weight'),
 ('DRV_LOSCORE','Metric.ActualValue',
  'Measured attainment input')
) v(RuleCode, InputReference, RoleNote)
JOIN gov.DerivationRule r
  ON r.RuleCode = v.RuleCode;

COMMIT;

EXEC audit.usp_CompleteLoadBatch
     @LoadBatchId = @LoadBatchId,
     @StatusCode  = 'SUCCESS';

DECLARE @RuleCount INT =
    (SELECT COUNT(*) FROM gov.DerivationRule
     WHERE RuleCode LIKE 'DRV[_]%');
DECLARE @InputCount INT =
    (SELECT COUNT(*)
     FROM gov.DerivationRuleInput ri
     JOIN gov.DerivationRule r
       ON r.DerivationRuleId = ri.DerivationRuleId
     WHERE r.RuleCode LIKE 'DRV[_]%');

PRINT 'Script 005 complete: '
    + CAST(@RuleCount AS VARCHAR(10))
    + ' derivation rules, '
    + CAST(@InputCount AS VARCHAR(10))
    + ' inputs registered.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    EXEC audit.usp_LogError
         @LoadBatchId = @LoadBatchId,
         @ContextInfo = N'005_gov_seed_derivation_rules.sql';
    EXEC audit.usp_CompleteLoadBatch
         @LoadBatchId = @LoadBatchId,
         @StatusCode  = 'FAILED';
    THROW;
END CATCH
GO
