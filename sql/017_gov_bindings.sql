/* ============================================================
   MortgageGovernance | Phase 7 | Script 017
   Governance bindings. Creates the logical data element
   catalog, links glossary terms, classifies every element
   (classification level + PII), registers the CDE register
   with rationale and approval, binds elements to physical
   columns at the SRC layer (per 011 names) and DW layer (per
   015), seeds the attribute-level authoritative source
   register including the BRD-to-SVC boarding handoff deferred
   by 012, binds gov.DerivationRuleInput.DataElementId for the
   stg-contract inputs deferred by 003/005, inherits per-CDE
   RACI from system RACI (004), derives metric-to-element
   dependencies, loads the column-level SourceToTargetMap, and
   publishes three generation views (dictionary, CDE register,
   metric lineage). Requires SQL Server 2017+ (STRING_AGG).
   Idempotent: elements upsert by code; owned child sets
   (CDE register, bindings, auth source, element RACI, derived
   metric deps, S2T map) delete and reload.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

DECLARE @LoadBatchId INT;
DECLARE @BatchNotes NVARCHAR(400) =
    N'Script 017: elements, glossary links, CDE register, '
  + N'layer bindings, authoritative sources, rule-input '
  + N'binding, element RACI, metric-element lineage, '
  + N'source-to-target map.';

EXEC audit.usp_StartLoadBatch
     @BatchName     = N'Phase 7 governance bindings seed',
     @BatchTypeCode = 'SEED',
     @Notes         = @BatchNotes,
     @LoadBatchId   = @LoadBatchId OUTPUT;

BEGIN TRY
BEGIN TRAN;

/* ------------------------------------------------------------
   1. Glossary supplement: 13 servicing / production terms.
      006 loaded 35 NMLS FV7 terms; these are the internal
      operating terms elements link to. APPROVED by the DGO.
   ------------------------------------------------------------ */
DECLARE @PaigeId INT =
    (SELECT PartyId FROM gov.Party
     WHERE PartyName = 'Paige Justice'
       AND PartyTypeCode = 'PERSON');

INSERT INTO gov.BusinessTerm
    (TermName, TermDefinition, DomainArea,
     ApprovalStatusCode, ApprovedByPartyId, ApprovedDate,
     SourceOfDefinition, LoadBatchId)
SELECT v.TermName, v.TermDef, v.Domain, 'APPROVED',
       @PaigeId, '2026-07-15',
       N'Flamingo Financials Data Governance Office',
       @LoadBatchId
FROM (VALUES
 (N'Days Past Due',
  N'Calendar days between the contractual next payment due '
  + N'date and the evaluation date; 0 when not yet due.',
  N'Servicing'),
 (N'Delinquency Bucket',
  N'Days-past-due band per ref.DelinquencyBucket, aligned '
  + N'to MCR FV7 definitions (current <30, 30-59, 60-89, '
  + N'90+).',
  N'Servicing'),
 (N'Suspense Balance',
  N'Funds received but not yet applied to principal, '
  + N'interest, escrow, or fees.',
  N'Payments & Cash'),
 (N'Servicing Type',
  N'Servicing arrangement classification per '
  + N'ref.ServicingType; basis for FV7 LS010-LS040.',
  N'Servicing'),
 (N'Loan Boarding',
  N'Transfer of a loan onto the servicing system of record '
  + N'from an acquisition or transfer tape.',
  N'Boarding & Transfers'),
 (N'Escrow Analysis',
  N'Periodic recalculation of the escrow account under '
  + N'RESPA Regulation X.',
  N'Escrow'),
 (N'Loss Mitigation',
  N'Evaluation of a delinquent borrower for workout '
  + N'alternatives under Regulation X timelines.',
  N'Default Management'),
 (N'Foreclosure Referral',
  N'Handoff of an eligible defaulted loan to foreclosure '
  + N'counsel; first-legal eligibility anchors the SLA.',
  N'Default Management'),
 (N'Proof of Claim',
  N'Creditor claim filed in a bankruptcy case; must be '
  + N'filed by the court bar date.',
  N'Default Management'),
 (N'Investor Remittance',
  N'Scheduled transfer of collected funds to an investor '
  + N'per the remittance type contract.',
  N'Investor Reporting'),
 (N'Lead',
  N'A prospect contact record created in CRM prior to any '
  + N'application.',
  N'Production & Marketing'),
 (N'NMLS ID',
  N'Nationwide Multistate Licensing System unique '
  + N'identifier for an individual or company.',
  N'Workforce & Licensing'),
 (N'Rate Lock',
  N'Commitment of a note rate and price for a defined '
  + N'period; relocks create new lock events.',
  N'Production')
) v(TermName, TermDef, Domain)
WHERE NOT EXISTS
      (SELECT 1 FROM gov.BusinessTerm t
       WHERE t.TermName = v.TermName);

/* ------------------------------------------------------------
   2. Data element catalog. Upsert by DataElementCode so
      re-runs refresh definitions without breaking downstream
      FKs (018 MISMO mappings, gov.DataIssue). CdeFlag is set
      in section 3 from the CDE register seed.
   ------------------------------------------------------------ */
DECLARE @Element TABLE
(
    Code     VARCHAR(60)    NOT NULL PRIMARY KEY,
    ElemName NVARCHAR(200)  NOT NULL,
    TermName NVARCHAR(200)  NULL,
    BizDef   NVARCHAR(2000) NOT NULL,
    Domain   NVARCHAR(100)  NOT NULL,
    TypeCat  VARCHAR(30)    NOT NULL,
    ClassCd  VARCHAR(20)    NOT NULL,
    PiiCd    VARCHAR(30)    NOT NULL
);

INSERT INTO @Element
 (Code, ElemName, TermName, BizDef, Domain, TypeCat,
  ClassCd, PiiCd)
VALUES
/* ---- Loan identity and terms (SVC / BRD) ---- */
('DE_LOAN_NUMBER', N'Loan Number',
 N'Loan / Residential Mortgage Loan',
 N'Servicer-assigned loan number; the enterprise business '
 + N'key across all systems and warehouse facts.',
 N'Servicing','IDENTIFIER','CONFIDENTIAL',
 'QUASI_IDENTIFIER'),
('DE_ORIGINATION_DATE', N'Origination Date', N'Originated',
 N'Date the loan was originated (note date).',
 N'Servicing','DATE','INTERNAL','NONE'),
('DE_MATURITY_DATE', N'Maturity Date', NULL,
 N'Contractual final payment date of the loan.',
 N'Servicing','DATE','INTERNAL','NONE'),
('DE_ORIGINAL_LOAN_AMOUNT', N'Original Loan Amount',
 N'Amount', N'Original note amount at origination.',
 N'Servicing','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL'),
('DE_NOTE_RATE', N'Note Rate', NULL,
 N'Current note interest rate of the loan.',
 N'Servicing','RATE','INTERNAL','NONE'),
('DE_INTEREST_RATE_TYPE', N'Interest Rate Type', NULL,
 N'Fixed or adjustable rate classification.',
 N'Servicing','CODE','INTERNAL','NONE'),
('DE_AMORT_TERM_MONTHS', N'Amortization Term Months', NULL,
 N'Amortization term of the loan in months.',
 N'Servicing','COUNT','INTERNAL','NONE'),
('DE_LIEN_POSITION', N'Lien Position', N'First Lien',
 N'Lien priority of the mortgage (1 = first lien).',
 N'Servicing','CODE','INTERNAL','NONE'),
('DE_HELOC_FLAG', N'HELOC Flag', NULL,
 N'Indicates a home equity line of credit.',
 N'Servicing','FLAG','INTERNAL','NONE'),
('DE_REVERSE_MORTGAGE_FLAG', N'Reverse Mortgage Flag',
 N'Reverse Mortgage', N'Indicates a reverse mortgage.',
 N'Servicing','FLAG','INTERNAL','NONE'),
('DE_LOAN_PROGRAM', N'Loan Program', NULL,
 N'Loan program (CONV, FHA, VA, USDA, JUMBO).',
 N'Servicing','CODE','INTERNAL','NONE'),
('DE_LOAN_PURPOSE', N'Loan Purpose', NULL,
 N'Purchase, refinance, or other loan purpose.',
 N'Production','CODE','INTERNAL','NONE'),
('DE_ESCROWED_FLAG', N'Escrowed Flag', NULL,
 N'Indicates an active escrow account on the loan.',
 N'Servicing','FLAG','INTERNAL','NONE'),
('DE_SERVICING_TYPE', N'Servicing Type', N'Servicing Type',
 N'Servicing arrangement classification per '
 + N'ref.ServicingType.',
 N'Servicing','CODE','INTERNAL','NONE'),
('DE_REMITTANCE_TYPE', N'Remittance Type', NULL,
 N'Investor remittance schedule type per '
 + N'ref.RemittanceType.',
 N'Investor Reporting','CODE','INTERNAL','NONE'),
('DE_INVESTOR_CODE', N'Investor Code', NULL,
 N'Investor of record identifier; drives investor and MCR '
 + N'servicing splits.',
 N'Servicing','CODE','INTERNAL','NONE'),
('DE_INVESTOR_LOAN_NUMBER', N'Investor Loan Number', NULL,
 N'Investor-assigned loan identifier.',
 N'Investor Reporting','IDENTIFIER','CONFIDENTIAL',
 'QUASI_IDENTIFIER'),
('DE_POOL_NUMBER', N'Pool Number', N'Pool Number',
 N'Security pool identifier for pooled loans.',
 N'Investor Reporting','IDENTIFIER','INTERNAL','NONE'),
('DE_MSR_OWNER_NMLS', N'MSR Owner NMLS ID', N'NMLS ID',
 N'NMLS ID of the mortgage servicing rights owner; FV7 '
 + N'S520A detail.',
 N'Servicing','IDENTIFIER','INTERNAL','NONE'),
('DE_BOARDED_DATE', N'Boarded Date', N'Loan Boarding',
 N'Date the loan boarded to the servicing system of '
 + N'record.',
 N'Boarding & Transfers','DATE','INTERNAL','NONE'),
('DE_CONFORMING_FLAG', N'Conforming Flag', NULL,
 N'Indicates the loan meets the applicable conforming loan '
 + N'limit; derived against ref.ConformingLoanLimit.',
 N'Servicing','FLAG','INTERNAL','NONE'),
('DE_MCR_LOAN_TYPE', N'MCR Loan Type', N'Forward Mortgage',
 N'MCR loan type classification (forward, reverse, etc.) '
 + N'derived for FV7 line mapping.',
 N'Regulatory Reporting','CODE','INTERNAL','NONE')
,
/* ---- Borrower and property ---- */
('DE_BORROWER_FIRST_NAME', N'Borrower First Name', NULL,
 N'Primary borrower given name.',
 N'Servicing','TEXT','RESTRICTED','DIRECT_IDENTIFIER'),
('DE_BORROWER_LAST_NAME', N'Borrower Last Name', NULL,
 N'Primary borrower surname.',
 N'Servicing','TEXT','RESTRICTED','DIRECT_IDENTIFIER'),
('DE_PROPERTY_STREET', N'Property Street', N'Dwelling',
 N'Street address of the collateral property.',
 N'Servicing','TEXT','RESTRICTED','DIRECT_IDENTIFIER'),
('DE_PROPERTY_CITY', N'Property City', NULL,
 N'City of the collateral property.',
 N'Servicing','TEXT','CONFIDENTIAL','QUASI_IDENTIFIER'),
('DE_PROPERTY_STATE', N'Property State', NULL,
 N'State of the collateral property; drives MCR state '
 + N'splits.',
 N'Servicing','CODE','INTERNAL','QUASI_IDENTIFIER'),
('DE_PROPERTY_POSTAL', N'Property Postal Code', NULL,
 N'Postal code of the collateral property.',
 N'Servicing','CODE','CONFIDENTIAL','QUASI_IDENTIFIER'),
('DE_PROPERTY_TYPE', N'Property Type', N'Dwelling',
 N'Property type (single family, condo, 2-4 unit).',
 N'Servicing','CODE','INTERNAL','NONE'),
('DE_OCCUPANCY_TYPE', N'Occupancy Type', NULL,
 N'Owner-occupied, second home, or investment.',
 N'Servicing','CODE','INTERNAL','NONE'),
('DE_UNITS_COUNT', N'Units Count', NULL,
 N'Number of dwelling units on the property.',
 N'Servicing','COUNT','INTERNAL','NONE'),
('DE_FLOOD_ZONE_FLAG', N'Flood Zone Flag', NULL,
 N'Indicates the property is in a designated flood zone.',
 N'Servicing','FLAG','INTERNAL','NONE'),
('DE_PROPERTY_VALUE', N'Property Value', NULL,
 N'Current property value from the latest valuation; CLTV '
 + N'denominator.',
 N'Collateral','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL'),
('DE_VALUATION_DATE', N'Valuation Date', NULL,
 N'Effective date of a property valuation; latest-value '
 + N'ordering key.',
 N'Collateral','DATE','INTERNAL','NONE'),
('DE_VALUATION_METHOD', N'Valuation Method', NULL,
 N'Valuation method (AVM, BPO, appraisal).',
 N'Collateral','CODE','INTERNAL','NONE'),
/* ---- Month-end snapshot ---- */
('DE_ASOF_DATE', N'Snapshot As-Of Date', NULL,
 N'Month-end date of a servicing snapshot; period grain.',
 N'Servicing','DATE','INTERNAL','NONE'),
('DE_CURRENT_UPB', N'Current UPB', N'UPB',
 N'Unpaid principal balance at the snapshot date.',
 N'Servicing','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL'),
('DE_BEGINNING_UPB', N'Beginning UPB', N'UPB',
 N'Unpaid principal balance at the start of the period; '
 + N'CPR/SMM basis.',
 N'Servicing','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL'),
('DE_SCHEDULED_PRINCIPAL', N'Scheduled Principal', NULL,
 N'Scheduled principal reduction for the period.',
 N'Servicing','AMOUNT','INTERNAL','NONE'),
('DE_VOLUNTARY_PREPAID_PRINCIPAL',
 N'Voluntary Prepaid Principal', NULL,
 N'Unscheduled principal prepayment for the period; SMM '
 + N'numerator.',
 N'Servicing','AMOUNT','INTERNAL','NONE'),
('DE_INTEREST_RATE_SNAP', N'Snapshot Interest Rate', NULL,
 N'Note rate in effect at the snapshot date.',
 N'Servicing','RATE','INTERNAL','NONE'),
('DE_SERVICING_FEE_RATE', N'Servicing Fee Rate', NULL,
 N'Servicing fee rate; fee yield input.',
 N'Servicing','RATE','INTERNAL','NONE'),
('DE_NEXT_PAYMENT_DUE_DATE', N'Next Payment Due Date', NULL,
 N'Contractual next payment due date; days-past-due '
 + N'anchor.',
 N'Servicing','DATE','INTERNAL','NONE'),
('DE_DAYS_PAST_DUE', N'Days Past Due', N'Days Past Due',
 N'Calendar days delinquent at the snapshot date; derived '
 + N'from next payment due date.',
 N'Servicing','COUNT','INTERNAL','NONE'),
('DE_DELINQUENCY_BUCKET', N'Delinquency Bucket',
 N'Delinquency Bucket',
 N'Derived days-past-due band per ref.DelinquencyBucket.',
 N'Servicing','CODE','INTERNAL','NONE'),
('DE_SOURCE_BUCKET', N'Source Reported Bucket', NULL,
 N'Source-claimed delinquency bucket; consistency-tested '
 + N'against the derived bucket.',
 N'Servicing','CODE','INTERNAL','NONE'),
('DE_LOAN_STATUS', N'Loan Status', NULL,
 N'Servicing status; active population gate.',
 N'Servicing','CODE','INTERNAL','NONE'),
('DE_ESCROW_BALANCE', N'Escrow Balance', NULL,
 N'Escrow account balance at the snapshot date.',
 N'Escrow','AMOUNT','CONFIDENTIAL','SENSITIVE_FINANCIAL'),
('DE_SUSPENSE_BALANCE', N'Suspense Balance',
 N'Suspense Balance',
 N'Unapplied funds balance at the snapshot date.',
 N'Payments & Cash','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL'),
('DE_FORBEARANCE_FLAG', N'Forbearance Flag', NULL,
 N'Indicates an active forbearance plan at the snapshot.',
 N'Default Management','FLAG','INTERNAL','NONE'),
('DE_RUNOFF_REASON', N'Runoff Reason', NULL,
 N'Reason a loan left the active portfolio '
 + N'per ref.RunoffReason.',
 N'Servicing','CODE','INTERNAL','NONE'),
('DE_CURRENT_LTV', N'Current LTV',
 N'Loan-to-Value Ratio (LTV)',
 N'Current loan-to-value ratio; UPB over latest property '
 + N'value.',
 N'Servicing','RATE','INTERNAL','NONE')
,
/* ---- Boarding tape (BRD, critical fields) ---- */
('DE_TAPE_UPB', N'Tape UPB', N'UPB',
 N'UPB per the prior servicer boarding tape; boarding '
 + N'accuracy baseline (critical field 1 of 5).',
 N'Boarding & Transfers','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL'),
('DE_TAPE_RATE', N'Tape Interest Rate', NULL,
 N'Note rate per tape; boarding critical field 2 of 5.',
 N'Boarding & Transfers','RATE','INTERNAL','NONE'),
('DE_TAPE_NEXT_DUE', N'Tape Next Payment Due Date', NULL,
 N'Next due per tape; boarding critical field 3 of 5.',
 N'Boarding & Transfers','DATE','INTERNAL','NONE'),
('DE_TAPE_ESCROW_BALANCE', N'Tape Escrow Balance', NULL,
 N'Escrow balance per tape; boarding critical field 4 of '
 + N'5.',
 N'Boarding & Transfers','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL'),
('DE_TAPE_INVESTOR', N'Tape Investor Code', NULL,
 N'Investor per tape; boarding critical field 5 of 5.',
 N'Boarding & Transfers','CODE','INTERNAL','NONE'),
('DE_BOARDING_COMPLETED_DATE', N'Boarding Completed Date',
 N'Loan Boarding',
 N'Date boarding completed; boarding SLA input.',
 N'Boarding & Transfers','DATE','INTERNAL','NONE'),
('DE_TRANSFER_EFFECTIVE_DATE', N'Transfer Effective Date',
 NULL,
 N'Effective date of a boarding transfer; SLA anchor.',
 N'Boarding & Transfers','DATE','INTERNAL','NONE'),
('DE_TRANSFER_TYPE', N'Transfer Type', NULL,
 N'Bulk transfer or monthly flow boarding classification.',
 N'Boarding & Transfers','CODE','INTERNAL','NONE'),
/* ---- Payments (PAY) ---- */
('DE_PAY_RECEIVED_DATE', N'Payment Received Date', NULL,
 N'Payment receipt date; posting timeliness clock start.',
 N'Payments & Cash','DATE','INTERNAL','NONE'),
('DE_PAY_POSTED_DATE', N'Payment Posted Date', NULL,
 N'Payment posting date; posting timeliness clock end.',
 N'Payments & Cash','DATE','INTERNAL','NONE'),
('DE_PAY_EFFECTIVE_DATE', N'Payment Effective Date', NULL,
 N'Effective date of the payment application.',
 N'Payments & Cash','DATE','INTERNAL','NONE'),
('DE_PAY_AMOUNT', N'Payment Amount', N'Amount',
 N'Total payment transaction amount.',
 N'Payments & Cash','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL'),
('DE_PAY_PRINCIPAL', N'Payment Principal Split', NULL,
 N'Principal portion of the payment.',
 N'Payments & Cash','AMOUNT','INTERNAL','NONE'),
('DE_PAY_INTEREST', N'Payment Interest Split', NULL,
 N'Interest portion of the payment.',
 N'Payments & Cash','AMOUNT','INTERNAL','NONE'),
('DE_PAY_ESCROW', N'Payment Escrow Split', NULL,
 N'Escrow portion of the payment.',
 N'Payments & Cash','AMOUNT','INTERNAL','NONE'),
('DE_PAY_REVERSAL_FLAG', N'Payment Reversal Flag', NULL,
 N'Indicates a reversed payment transaction; accuracy '
 + N'input.',
 N'Payments & Cash','FLAG','INTERNAL','NONE'),
('DE_PAY_ORIGINAL_TXN', N'Original Transaction Reference',
 NULL,
 N'Reversal chain link to the original posting.',
 N'Payments & Cash','IDENTIFIER','INTERNAL','NONE'),
('DE_PAY_SUSPENSE_FLAG', N'Payment Suspense Flag', NULL,
 N'Indicates funds posted to suspense.',
 N'Payments & Cash','FLAG','INTERNAL','NONE'),
/* ---- Escrow disbursement / analysis (SVC) ---- */
('DE_DISB_TYPE', N'Disbursement Type', NULL,
 N'Escrow disbursement type (tax, insurance).',
 N'Escrow','CODE','INTERNAL','NONE'),
('DE_DISB_DATE', N'Disbursement Date', NULL,
 N'Date an escrow disbursement was made; timeliness clock '
 + N'end.',
 N'Escrow','DATE','INTERNAL','NONE'),
('DE_DISB_AMOUNT', N'Disbursement Amount', NULL,
 N'Amount of an escrow disbursement.',
 N'Escrow','AMOUNT','INTERNAL','NONE'),
('DE_TAX_DUE_DATE', N'Tax Due Date', NULL,
 N'Property tax due date; disbursement timeliness anchor.',
 N'Escrow','DATE','INTERNAL','NONE'),
('DE_DISB_AMOUNT_MATCH', N'Disbursement Amount Match Flag',
 NULL,
 N'Indicates the disbursed amount matched the obligation.',
 N'Escrow','FLAG','INTERNAL','NONE'),
('DE_DISB_PAYEE_MATCH', N'Disbursement Payee Match Flag',
 NULL,
 N'Indicates the payee matched the obligation.',
 N'Escrow','FLAG','INTERNAL','NONE'),
('DE_DISB_LOAN_MATCH', N'Disbursement Loan Match Flag',
 NULL,
 N'Indicates the disbursement matched to the correct '
 + N'loan.',
 N'Escrow','FLAG','INTERNAL','NONE'),
('DE_ESC_ANALYSIS_DUE', N'Escrow Analysis Due Date',
 N'Escrow Analysis',
 N'Date the escrow analysis is due per cycle.',
 N'Escrow','DATE','INTERNAL','NONE'),
('DE_ESC_ANALYSIS_COMPLETED',
 N'Escrow Analysis Completed Date', N'Escrow Analysis',
 N'Date the escrow analysis completed; timeliness clock '
 + N'end.',
 N'Escrow','DATE','INTERNAL','NONE'),
('DE_ESC_SHORTAGE_AMOUNT', N'Escrow Shortage Amount', NULL,
 N'Escrow shortage identified at analysis.',
 N'Escrow','AMOUNT','INTERNAL','NONE')
,
/* ---- Default management (DMS) ---- */
('DE_LM_APP_RECEIVED', N'Loss Mit App Received Date',
 N'Loss Mitigation',
 N'Date a loss mitigation application was received.',
 N'Default Management','DATE','INTERNAL','NONE'),
('DE_LM_COMPLETE_PACKAGE', N'Complete Package Date',
 N'Loss Mitigation',
 N'Date a complete loss mitigation package was received; '
 + N'Reg X evaluation clock anchor.',
 N'Default Management','DATE','INTERNAL','NONE'),
('DE_LM_DECISION_DATE', N'Loss Mit Decision Date',
 N'Loss Mitigation',
 N'Date a workout decision was issued; evaluation clock '
 + N'end.',
 N'Default Management','DATE','INTERNAL','NONE'),
('DE_LM_DECISION_CODE', N'Loss Mit Decision Code',
 N'Loss Mitigation',
 N'Workout decision classification (mod, repay, deny).',
 N'Default Management','CODE','INTERNAL','NONE'),
('DE_LM_WORKOUT_TYPE', N'Workout Type', NULL,
 N'Workout type per ref.WorkoutType.',
 N'Default Management','CODE','INTERNAL','NONE'),
('DE_FC_FIRST_LEGAL_ELIGIBLE',
 N'First Legal Eligible Date', N'Foreclosure Referral',
 N'Date the loan became eligible for first legal action; '
 + N'referral SLA anchor.',
 N'Default Management','DATE','INTERNAL','NONE'),
('DE_FC_REFERRAL_DATE', N'Foreclosure Referral Date',
 N'Foreclosure Referral',
 N'Date the loan was referred to foreclosure; timeline '
 + N'start.',
 N'Default Management','DATE','INTERNAL','NONE'),
('DE_FC_SALE_HELD_DATE', N'Foreclosure Sale Held Date',
 NULL,
 N'Date a foreclosure sale was held; timeline end.',
 N'Default Management','DATE','INTERNAL','NONE'),
('DE_FC_CASE_STATUS', N'Foreclosure Case Status', NULL,
 N'Foreclosure case status; open-case gate for active '
 + N'foreclosure.',
 N'Default Management','CODE','INTERNAL','NONE'),
('DE_FC_RESOLUTION_TYPE', N'Foreclosure Resolution Type',
 NULL,
 N'How a foreclosure case resolved (sale, reinstated, '
 + N'workout).',
 N'Default Management','CODE','INTERNAL','NONE'),
('DE_BK_CHAPTER', N'Bankruptcy Chapter', NULL,
 N'Bankruptcy chapter (7, 11, 13).',
 N'Default Management','CODE','INTERNAL','NONE'),
('DE_BK_PETITION_DATE', N'Bankruptcy Petition Date', NULL,
 N'Date the bankruptcy petition was filed.',
 N'Default Management','DATE','INTERNAL','NONE'),
('DE_BK_POC_BAR_DATE', N'Proof of Claim Bar Date',
 N'Proof of Claim',
 N'Court bar date by which the proof of claim must be '
 + N'filed.',
 N'Default Management','DATE','INTERNAL','NONE'),
('DE_BK_POC_FILED_DATE', N'Proof of Claim Filed Date',
 N'Proof of Claim',
 N'Date the proof of claim was filed.',
 N'Default Management','DATE','INTERNAL','NONE'),
('DE_FORB_START_DATE', N'Forbearance Start Date', NULL,
 N'Start date of a forbearance plan.',
 N'Default Management','DATE','INTERNAL','NONE'),
('DE_FORB_END_DATE', N'Forbearance End Date', NULL,
 N'End date of a forbearance plan.',
 N'Default Management','DATE','INTERNAL','NONE'),
('DE_FORB_STATUS', N'Forbearance Status', NULL,
 N'Forbearance plan status.',
 N'Default Management','CODE','INTERNAL','NONE'),
('DE_MOD_EFFECTIVE_DATE', N'Modification Effective Date',
 NULL,
 N'Effective date of a completed loan modification.',
 N'Default Management','DATE','INTERNAL','NONE'),
('DE_MOD_BOOKED_DATE', N'Modification Booked Date', NULL,
 N'Date a permanent modification was booked; trial '
 + N'conversion marker.',
 N'Default Management','DATE','INTERNAL','NONE'),
/* ---- Investor reporting (INV) ---- */
('DE_INV_REPORTING_DEADLINE', N'Reporting Deadline Date',
 NULL,
 N'Investor loan-level reporting deadline.',
 N'Investor Reporting','DATE','INTERNAL','NONE'),
('DE_INV_REPORT_SUBMITTED', N'Report Submitted Date', NULL,
 N'Date investor loan-level reporting was submitted; '
 + N'timeliness clock end.',
 N'Investor Reporting','DATE','INTERNAL','NONE'),
('DE_INV_ACCEPTED_FLAG', N'Report Accepted Flag', NULL,
 N'Indicates the investor accepted the submitted report.',
 N'Investor Reporting','FLAG','INTERNAL','NONE'),
('DE_INV_ERROR_COUNT', N'Report Error Count', NULL,
 N'Count of loan-level reporting errors.',
 N'Investor Reporting','COUNT','INTERNAL','NONE'),
('DE_INV_CORRECTION_FLAG', N'Correction Resubmission Flag',
 NULL,
 N'Indicates a correction resubmission (DEF13 signal).',
 N'Investor Reporting','FLAG','INTERNAL','NONE'),
('DE_REMIT_DUE_DATE', N'Remittance Due Date',
 N'Investor Remittance',
 N'Investor remittance due date.',
 N'Investor Reporting','DATE','INTERNAL','NONE'),
('DE_REMIT_SENT_DATE', N'Remittance Sent Date',
 N'Investor Remittance',
 N'Date the investor remittance was sent; timeliness '
 + N'clock end.',
 N'Investor Reporting','DATE','INTERNAL','NONE'),
('DE_REMIT_AMOUNT', N'Remittance Amount',
 N'Investor Remittance',
 N'Amount remitted to the investor.',
 N'Investor Reporting','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL'),
('DE_REPO_DEMAND_RECEIVED', N'Repurchase Demand Received',
 N'Repurchase',
 N'Date a repurchase demand was received; resolution '
 + N'clock start.',
 N'Investor Reporting','DATE','INTERNAL','NONE'),
('DE_REPO_RESOLUTION_DATE', N'Repurchase Resolution Date',
 N'Repurchase',
 N'Date a repurchase demand was resolved; clock end.',
 N'Investor Reporting','DATE','INTERNAL','NONE'),
('DE_REPO_DEMAND_AMOUNT', N'Repurchase Demand Amount',
 N'Repurchase',
 N'Amount demanded in a repurchase request.',
 N'Investor Reporting','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL')
,
/* ---- Production: leads, applications, locks (CRM/LOS/PPE) ---- */
('DE_LEAD_CREATED_DATE', N'Lead Created Date', N'Lead',
 N'Date a CRM lead was created; funnel anchor.',
 N'Production & Marketing','DATE','INTERNAL','NONE'),
('DE_LEAD_SOURCE', N'Lead Source', NULL,
 N'Lead attribution source (DEF20 null-source target).',
 N'Production & Marketing','CODE','INTERNAL','NONE'),
('DE_LEAD_CONTACT_KEY', N'Lead Contact Key', NULL,
 N'Contact identifier for de-duplication (DEF15).',
 N'Production & Marketing','IDENTIFIER','CONFIDENTIAL',
 'QUASI_IDENTIFIER'),
('DE_LEAD_CONVERTED_APP', N'Converted Application Link',
 NULL,
 N'CRM-to-LOS conversion linkage.',
 N'Production & Marketing','IDENTIFIER','INTERNAL','NONE'),
('DE_LEAD_STATUS', N'Lead Status', NULL,
 N'Lead lifecycle status.',
 N'Production & Marketing','CODE','INTERNAL','NONE'),
('DE_APP_RECEIVED_DATE', N'Application Received Date',
 N'Application',
 N'Signed application date per the MCR glossary; AC020 '
 + N'basis.',
 N'Production','DATE','INTERNAL','NONE'),
('DE_APP_STARTED_DATE', N'Application Started Date', NULL,
 N'Date the application was started.',
 N'Production','DATE','INTERNAL','NONE'),
('DE_APP_COMPLETED_DATE', N'Application Completed Date',
 NULL,
 N'Date the application became complete.',
 N'Production','DATE','INTERNAL','NONE'),
('DE_APP_DISPOSITION', N'Application Disposition',
 N'Closed',
 N'Terminal application disposition; AC030-AC080 (DEF17 '
 + N'target).',
 N'Production','CODE','INTERNAL','NONE'),
('DE_APP_DISPOSITION_DATE', N'Application Disposition Date',
 NULL,
 N'Date the terminal disposition was recorded.',
 N'Production','DATE','INTERNAL','NONE'),
('DE_APP_FUNDING_DATE', N'Application Funding Date', NULL,
 N'Funding date; AC070 and cycle-time clock end.',
 N'Production','DATE','INTERNAL','NONE'),
('DE_APP_SCHEDULED_CLOSING', N'Scheduled Closing Date',
 NULL,
 N'Scheduled closing date; on-time-close basis.',
 N'Production','DATE','INTERNAL','NONE'),
('DE_APP_ACTUAL_CLOSING', N'Actual Closing Date', NULL,
 N'Actual closing date.',
 N'Production','DATE','INTERNAL','NONE'),
('DE_APP_LOAN_AMOUNT', N'Application Loan Amount', N'Amount',
 N'Current loan amount on the application; production '
 + N'volume.',
 N'Production','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL'),
('DE_APP_LO_NMLS', N'Application Loan Officer NMLS ID',
 N'NMLS ID',
 N'NMLS ID of the loan officer of record; ACMLO1 (DEF14 '
 + N'target).',
 N'Production','IDENTIFIER','INTERNAL','NONE'),
('DE_APP_SERVICING_INTENT', N'Servicing Disposition Intent',
 NULL,
 N'Retained or released servicing intent; AC1200 family.',
 N'Production','CODE','INTERNAL','NONE'),
('DE_APP_FUNDED_FLAG', N'Application Funded Flag', NULL,
 N'Indicates the application funded.',
 N'Production','FLAG','INTERNAL','NONE'),
('DE_APP_CHANNEL', N'Application Channel', NULL,
 N'Production channel (retail, wholesale, correspondent).',
 N'Production','CODE','INTERNAL','NONE'),
('DE_LOCK_DATE', N'Lock Date', N'Rate Lock',
 N'Rate lock event date.',
 N'Production','DATE','INTERNAL','NONE'),
('DE_LOCK_AMOUNT', N'Lock Amount', N'Rate Lock',
 N'Locked loan amount; pull-through basis.',
 N'Production','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL'),
('DE_LOCK_CURRENT_EXPIRATION', N'Lock Current Expiration',
 N'Rate Lock',
 N'Current lock expiration date (DEF18 target).',
 N'Production','DATE','INTERNAL','NONE'),
('DE_LOCK_ORIGINAL_EXPIRATION', N'Lock Original Expiration',
 N'Rate Lock',
 N'Original lock expiration date.',
 N'Production','DATE','INTERNAL','NONE'),
('DE_LOCK_STATUS', N'Lock Status', N'Rate Lock',
 N'Terminal lock status.',
 N'Production','CODE','INTERNAL','NONE'),
('DE_LOCK_EXTENSION_COUNT', N'Lock Extension Count',
 N'Rate Lock',
 N'Number of extensions applied to the lock.',
 N'Production','COUNT','INTERNAL','NONE'),
('DE_LOCK_PRIOR_LOCK', N'Prior Lock Reference', N'Rate Lock',
 N'Relock chain link to a prior lock.',
 N'Production','IDENTIFIER','INTERNAL','NONE'),
('DE_LOCK_APPLICATION_LINK', N'Lock Application Link', NULL,
 N'Application linkage for lock pull-through.',
 N'Production','IDENTIFIER','INTERNAL','NONE'),
/* ---- Loan officer / licensing (LIC) ---- */
('DE_LO_NMLS_ID', N'Loan Officer NMLS ID', N'NMLS ID',
 N'NMLS identifier; loan officer business key across CRM, '
 + N'LOS, and LIC.',
 N'Workforce & Licensing','IDENTIFIER','INTERNAL','NONE'),
('DE_LO_FIRST_NAME', N'Loan Officer First Name', NULL,
 N'Loan officer given name.',
 N'Workforce & Licensing','TEXT','CONFIDENTIAL',
 'DIRECT_IDENTIFIER'),
('DE_LO_LAST_NAME', N'Loan Officer Last Name', NULL,
 N'Loan officer surname.',
 N'Workforce & Licensing','TEXT','CONFIDENTIAL',
 'DIRECT_IDENTIFIER'),
('DE_LO_BRANCH', N'Loan Officer Branch', NULL,
 N'Branch assignment; SCD2 tracked attribute.',
 N'Workforce & Licensing','CODE','INTERNAL','NONE'),
('DE_LO_REGION', N'Loan Officer Region', NULL,
 N'Region assignment of the loan officer.',
 N'Workforce & Licensing','TEXT','INTERNAL','NONE'),
('DE_LO_EMPLOYMENT_STATUS', N'Loan Officer Employment '
 + N'Status', NULL,
 N'Employment status of the loan officer.',
 N'Workforce & Licensing','CODE','INTERNAL','NONE'),
('DE_LIC_STATE', N'License State', NULL,
 N'State of a loan officer license.',
 N'Workforce & Licensing','CODE','INTERNAL','NONE'),
('DE_LIC_STATUS', N'License Status', NULL,
 N'License status; MLO compliance gate.',
 N'Workforce & Licensing','CODE','INTERNAL','NONE'),
('DE_LIC_EXPIRATION', N'License Expiration Date', NULL,
 N'License expiration date (DEF19 input).',
 N'Workforce & Licensing','DATE','INTERNAL','NONE'),
('DE_LIC_RENEWAL_DEADLINE', N'License Renewal Deadline',
 NULL,
 N'License renewal deadline.',
 N'Workforce & Licensing','DATE','INTERNAL','NONE'),
('DE_CE_REQUIRED_HOURS', N'CE Required Hours', NULL,
 N'Continuing education hours required.',
 N'Workforce & Licensing','COUNT','INTERNAL','NONE'),
('DE_CE_COMPLETED_HOURS', N'CE Completed Hours', NULL,
 N'Continuing education hours completed; CE compliance '
 + N'input.',
 N'Workforce & Licensing','COUNT','INTERNAL','NONE'),
('DE_CE_COMPLETED_DATE', N'CE Completed Date', NULL,
 N'Date continuing education requirements were completed; '
 + N'CE compliance timing input.',
 N'Workforce & Licensing','DATE','INTERNAL','NONE'),
/* ---- Insurance (SVC) ---- */
('DE_INS_POLICY_TYPE', N'Insurance Policy Type', NULL,
 N'Hazard, flood, or lender-placed coverage type; the '
 + N'lender-placed gate for DRV_LPI.',
 N'Insurance','CODE','INTERNAL','NONE'),
('DE_INS_EFFECTIVE_DATE', N'Policy Effective Date', NULL,
 N'Start of the insurance coverage span.',
 N'Insurance','DATE','INTERNAL','NONE'),
('DE_INS_EXPIRATION_DATE', N'Policy Expiration Date', NULL,
 N'End of the insurance coverage span; anchors insurance '
 + N'disbursement timeliness (DRV_INSTIMELY).',
 N'Insurance','DATE','INTERNAL','NONE'),
('DE_INS_ANNUAL_PREMIUM', N'Annual Premium Amount', NULL,
 N'Annual premium billed for the policy; escrow '
 + N'projection input.',
 N'Insurance','AMOUNT','CONFIDENTIAL',
 'SENSITIVE_FINANCIAL');

/* ---- Upsert elements by code (link approved term where the
        element names one) ---- */
MERGE gov.DataElement AS tgt
USING (
    SELECT e.Code, e.ElemName, e.BizDef, e.Domain,
           e.TypeCat, e.ClassCd, e.PiiCd,
           bt.BusinessTermId
    FROM @Element e
    LEFT JOIN gov.BusinessTerm bt
      ON bt.TermName = e.TermName
) AS src
ON tgt.DataElementCode = src.Code
WHEN MATCHED THEN UPDATE SET
    tgt.DataElementName = src.ElemName,
    tgt.BusinessTermId  = src.BusinessTermId,
    tgt.BusinessDefinition = src.BizDef,
    tgt.DomainArea      = src.Domain,
    tgt.DataTypeCategory = src.TypeCat,
    tgt.ClassificationLevelCode = src.ClassCd,
    tgt.PiiTypeCode     = src.PiiCd,
    tgt.ModifiedDateUtc = SYSUTCDATETIME(),
    tgt.LoadBatchId     = @LoadBatchId
WHEN NOT MATCHED THEN INSERT
    (DataElementCode, DataElementName, BusinessTermId,
     BusinessDefinition, DomainArea, DataTypeCategory,
     ClassificationLevelCode, PiiTypeCode, CdeFlag,
     LoadBatchId)
    VALUES
    (src.Code, src.ElemName, src.BusinessTermId,
     src.BizDef, src.Domain, src.TypeCat, src.ClassCd,
     src.PiiCd, 0, @LoadBatchId);

/* ------------------------------------------------------------
   3. Critical Data Element register.
      27 CDEs: fields whose defect directly distorts a
      certified metric, an MCR line, a delinquency/default
      number, or a control. Rationale ties each to its
      business/regulatory impact. Reload owned rows.
   ------------------------------------------------------------ */
DELETE FROM gov.CriticalDataElement;

INSERT INTO gov.CriticalDataElement
    (DataElementId, CdeRationale, ApprovedByPartyId,
     ApprovedDate, ReviewFrequencyCode, NextReviewDate,
     LoadBatchId)
SELECT de.DataElementId, v.Rationale, @PaigeId,
       '2026-07-15', v.Freq, '2027-07-15', @LoadBatchId
FROM (VALUES
 ('DE_LOAN_NUMBER',
  N'Enterprise join key; a defect breaks lineage, '
  + N'reconciliation, and every loan-grain metric.',
  'ANNUAL'),
 ('DE_CURRENT_UPB',
  N'Portfolio UPB and every UPB-weighted metric and MCR '
  + N'servicing line depend on it.',
  'QUARTERLY'),
 ('DE_BEGINNING_UPB',
  N'CPR/SMM runoff numerator basis; a defect distorts '
  + N'prepayment reporting.',
  'ANNUAL'),
 ('DE_NEXT_PAYMENT_DUE_DATE',
  N'Anchors days-past-due and every delinquency bucket; '
  + N'drives FV7 delinquency lines.',
  'QUARTERLY'),
 ('DE_DAYS_PAST_DUE',
  N'Derived delinquency measure feeding serious '
  + N'delinquency, default, and MCR lines.',
  'QUARTERLY'),
 ('DE_DELINQUENCY_BUCKET',
  N'Certified delinquency distribution and FV7 buckets '
  + N'depend on the derived value.',
  'QUARTERLY'),
 ('DE_LOAN_STATUS',
  N'Active-portfolio gate for nearly all servicing '
  + N'metrics.',
  'ANNUAL'),
 ('DE_INVESTOR_CODE',
  N'Investor splits and MCR servicing-by-investor detail; '
  + N'DEF12 typo target.',
  'ANNUAL'),
 ('DE_SERVICING_TYPE',
  N'MCR LS010-LS040 servicing-type basis.',
  'ANNUAL'),
 ('DE_PROPERTY_STATE',
  N'State-level MCR splits and state supplemental forms; '
  + N'DEF02 target.',
  'ANNUAL'),
 ('DE_ORIGINAL_LOAN_AMOUNT',
  N'Conforming test and production volume basis.',
  'ANNUAL'),
 ('DE_NOTE_RATE',
  N'Weighted-average coupon and boarding accuracy; DEF01 '
  + N'null target.',
  'ANNUAL'),
 ('DE_PROPERTY_VALUE',
  N'CLTV denominator; a defect distorts LTV-band '
  + N'reporting.',
  'ANNUAL'),
 ('DE_ESCROW_BALANCE',
  N'Escrow reporting and boarding accuracy critical '
  + N'field.',
  'ANNUAL'),
 ('DE_SUSPENSE_BALANCE',
  N'Unapplied-funds reporting and payment accuracy.',
  'ANNUAL'),
 ('DE_PAY_RECEIVED_DATE',
  N'Payment posting timeliness clock start.',
  'ANNUAL'),
 ('DE_PAY_POSTED_DATE',
  N'Payment posting timeliness clock end; DEF07 target.',
  'ANNUAL'),
 ('DE_PAY_AMOUNT',
  N'Cash accuracy and payment application integrity.',
  'ANNUAL'),
 ('DE_TAX_DUE_DATE',
  N'Escrow disbursement timeliness anchor; DEF09 target.',
  'ANNUAL'),
 ('DE_LM_COMPLETE_PACKAGE',
  N'Reg X loss mitigation evaluation clock anchor.',
  'ANNUAL'),
 ('DE_FC_FIRST_LEGAL_ELIGIBLE',
  N'Foreclosure referral SLA anchor.',
  'ANNUAL'),
 ('DE_BK_POC_BAR_DATE',
  N'Proof-of-claim timeliness bar date.',
  'ANNUAL'),
 ('DE_INV_REPORTING_DEADLINE',
  N'Investor reporting timeliness basis.',
  'ANNUAL'),
 ('DE_REMIT_DUE_DATE',
  N'Investor remittance timeliness basis.',
  'ANNUAL'),
 ('DE_APP_RECEIVED_DATE',
  N'MCR AC020 application-received basis and cycle time.',
  'ANNUAL'),
 ('DE_APP_LO_NMLS',
  N'MLO attribution (ACMLO1) and licensing compliance; '
  + N'DEF14 target.',
  'ANNUAL'),
 ('DE_LIC_STATUS',
  N'MLO license compliance gate; DEF19 expired-license '
  + N'target.',
  'ANNUAL')
) v(Code, Rationale, Freq)
JOIN gov.DataElement de ON de.DataElementCode = v.Code;

/* Flip CdeFlag on registered elements; clear it elsewhere */
UPDATE de SET CdeFlag = 1, ModifiedDateUtc = SYSUTCDATETIME()
FROM gov.DataElement de
WHERE EXISTS (SELECT 1 FROM gov.CriticalDataElement c
              WHERE c.DataElementId = de.DataElementId)
  AND de.CdeFlag = 0;

UPDATE de SET CdeFlag = 0, ModifiedDateUtc = SYSUTCDATETIME()
FROM gov.DataElement de
WHERE NOT EXISTS (SELECT 1 FROM gov.CriticalDataElement c
                  WHERE c.DataElementId = de.DataElementId)
  AND de.CdeFlag = 1;

/* ------------------------------------------------------------
   4. Physical bindings. Element to physical column at each
      layer. SRC per 011 names; DW per 015. Reload owned rows.
      One binding row per (element, layer, object, column).
   ------------------------------------------------------------ */
DELETE FROM gov.DataElementBinding;

DECLARE @Bind TABLE
(
    Code    VARCHAR(60)   NOT NULL,
    Layer   VARCHAR(20)   NOT NULL,
    Schm    VARCHAR(50)   NOT NULL,
    Obj     NVARCHAR(200) NOT NULL,
    Col     NVARCHAR(200) NOT NULL,
    SysCode VARCHAR(10)   NULL
);

/* ---- SRC layer bindings (authoritative physical source) ---- */
INSERT INTO @Bind (Code, Layer, Schm, Obj, Col, SysCode)
VALUES
('DE_LOAN_NUMBER','SRC','src','SvcLoanMaster','LoanNumber','SVC'),
('DE_ORIGINATION_DATE','SRC','src','SvcLoanMaster','OriginationDate','SVC'),
('DE_MATURITY_DATE','SRC','src','SvcLoanMaster','MaturityDate','SVC'),
('DE_ORIGINAL_LOAN_AMOUNT','SRC','src','SvcLoanMaster','OriginalLoanAmount','SVC'),
('DE_NOTE_RATE','SRC','src','SvcLoanMaster','NoteRatePercent','SVC'),
('DE_INTEREST_RATE_TYPE','SRC','src','SvcLoanMaster','InterestRateTypeCode','SVC'),
('DE_AMORT_TERM_MONTHS','SRC','src','SvcLoanMaster','AmortizationTermMonths','SVC'),
('DE_LIEN_POSITION','SRC','src','SvcLoanMaster','LienPosition','SVC'),
('DE_HELOC_FLAG','SRC','src','SvcLoanMaster','HelocFlag','SVC'),
('DE_REVERSE_MORTGAGE_FLAG','SRC','src','SvcLoanMaster','ReverseMortgageFlag','SVC'),
('DE_LOAN_PROGRAM','SRC','src','SvcLoanMaster','LoanProgramCode','SVC'),
('DE_LOAN_PURPOSE','SRC','src','SvcLoanMaster','LoanPurposeCode','SVC'),
('DE_ESCROWED_FLAG','SRC','src','SvcLoanMaster','EscrowIndicator','SVC'),
('DE_SERVICING_TYPE','SRC','src','SvcLoanMaster','ServicingTypeCode','SVC'),
('DE_REMITTANCE_TYPE','SRC','src','SvcLoanMaster','RemittanceTypeCode','SVC'),
('DE_INVESTOR_CODE','SRC','src','SvcLoanMaster','InvestorCode','SVC'),
('DE_INVESTOR_LOAN_NUMBER','SRC','src','SvcLoanMaster','InvestorLoanNumber','SVC'),
('DE_POOL_NUMBER','SRC','src','SvcLoanMaster','PoolNumber','SVC'),
('DE_MSR_OWNER_NMLS','SRC','src','SvcLoanMaster','MsrOwnerNmlsId','SVC'),
('DE_BOARDED_DATE','SRC','src','SvcLoanMaster','BoardedDate','SVC'),
('DE_BORROWER_FIRST_NAME','SRC','src','SvcLoanMaster','BorrowerFirstName','SVC'),
('DE_BORROWER_LAST_NAME','SRC','src','SvcLoanMaster','BorrowerLastName','SVC'),
('DE_PROPERTY_STREET','SRC','src','SvcLoanMaster','PropertyStreet','SVC'),
('DE_PROPERTY_CITY','SRC','src','SvcLoanMaster','PropertyCity','SVC'),
('DE_PROPERTY_STATE','SRC','src','SvcLoanMaster','PropertyStateCode','SVC'),
('DE_PROPERTY_POSTAL','SRC','src','SvcLoanMaster','PropertyPostalCode','SVC'),
('DE_PROPERTY_TYPE','SRC','src','SvcLoanMaster','PropertyTypeCode','SVC'),
('DE_OCCUPANCY_TYPE','SRC','src','SvcLoanMaster','OccupancyTypeCode','SVC'),
('DE_UNITS_COUNT','SRC','src','SvcLoanMaster','UnitsCount','SVC'),
('DE_FLOOD_ZONE_FLAG','SRC','src','SvcLoanMaster','FloodZoneFlag','SVC'),
('DE_ASOF_DATE','SRC','src','SvcLoanMonthEnd','AsOfDate','SVC'),
('DE_CURRENT_UPB','SRC','src','SvcLoanMonthEnd','CurrentUpbAmount','SVC'),
('DE_BEGINNING_UPB','SRC','src','SvcLoanMonthEnd','BeginningUpbAmount','SVC'),
('DE_SCHEDULED_PRINCIPAL','SRC','src','SvcLoanMonthEnd','ScheduledPrincipalAmount','SVC'),
('DE_VOLUNTARY_PREPAID_PRINCIPAL','SRC','src','SvcLoanMonthEnd','VoluntaryPrepaidPrincipalAmount','SVC'),
('DE_INTEREST_RATE_SNAP','SRC','src','SvcLoanMonthEnd','InterestRatePercent','SVC'),
('DE_SERVICING_FEE_RATE','SRC','src','SvcLoanMonthEnd','ServicingFeeRatePercent','SVC'),
('DE_NEXT_PAYMENT_DUE_DATE','SRC','src','SvcLoanMonthEnd','NextPaymentDueDate','SVC'),
('DE_SOURCE_BUCKET','SRC','src','SvcLoanMonthEnd','DelinquencyBucketCode','SVC'),
('DE_LOAN_STATUS','SRC','src','SvcLoanMonthEnd','LoanStatusCode','SVC'),
('DE_ESCROW_BALANCE','SRC','src','SvcLoanMonthEnd','EscrowBalanceAmount','SVC'),
('DE_SUSPENSE_BALANCE','SRC','src','SvcLoanMonthEnd','SuspenseBalanceAmount','SVC'),
('DE_FORBEARANCE_FLAG','SRC','src','SvcLoanMonthEnd','ForbearanceFlag','SVC'),
('DE_RUNOFF_REASON','SRC','src','SvcLoanMonthEnd','RunoffReasonCode','SVC'),
('DE_PROPERTY_VALUE','SRC','src','ValPropertyValuation','PropertyValueAmount','VAL'),
('DE_VALUATION_DATE','SRC','src','ValPropertyValuation','ValuationDate','VAL'),
('DE_VALUATION_METHOD','SRC','src','ValPropertyValuation','ValuationMethodCode','VAL'),
('DE_TAPE_UPB','SRC','src','BrdBoardingTape','TapeUpbAmount','BRD'),
('DE_TAPE_RATE','SRC','src','BrdBoardingTape','TapeInterestRatePercent','BRD'),
('DE_TAPE_NEXT_DUE','SRC','src','BrdBoardingTape','TapeNextPaymentDueDate','BRD'),
('DE_TAPE_ESCROW_BALANCE','SRC','src','BrdBoardingTape','TapeEscrowBalanceAmount','BRD'),
('DE_TAPE_INVESTOR','SRC','src','BrdBoardingTape','TapeInvestorCode','BRD'),
('DE_BOARDING_COMPLETED_DATE','SRC','src','BrdBoardingTape','BoardingCompletedDate','BRD'),
('DE_TRANSFER_EFFECTIVE_DATE','SRC','src','BrdBoardingBatch','TransferEffectiveDate','BRD'),
('DE_TRANSFER_TYPE','SRC','src','BrdBoardingBatch','TransferTypeCode','BRD'),
('DE_PAY_RECEIVED_DATE','SRC','src','PayPaymentTransaction','ReceivedDate','PAY'),
('DE_PAY_POSTED_DATE','SRC','src','PayPaymentTransaction','PostedDate','PAY'),
('DE_PAY_EFFECTIVE_DATE','SRC','src','PayPaymentTransaction','EffectiveDate','PAY'),
('DE_PAY_AMOUNT','SRC','src','PayPaymentTransaction','PaymentAmount','PAY'),
('DE_PAY_PRINCIPAL','SRC','src','PayPaymentTransaction','PrincipalAmount','PAY'),
('DE_PAY_INTEREST','SRC','src','PayPaymentTransaction','InterestAmount','PAY'),
('DE_PAY_ESCROW','SRC','src','PayPaymentTransaction','EscrowAmount','PAY'),
('DE_PAY_REVERSAL_FLAG','SRC','src','PayPaymentTransaction','ReversalFlag','PAY'),
('DE_PAY_ORIGINAL_TXN','SRC','src','PayPaymentTransaction','OriginalTransactionId','PAY'),
('DE_PAY_SUSPENSE_FLAG','SRC','src','PayPaymentTransaction','SuspenseFlag','PAY'),
('DE_DISB_TYPE','SRC','src','SvcEscrowDisbursement','DisbursementTypeCode','SVC'),
('DE_DISB_DATE','SRC','src','SvcEscrowDisbursement','DisbursedDate','SVC'),
('DE_DISB_AMOUNT','SRC','src','SvcEscrowDisbursement','DisbursedAmount','SVC'),
('DE_TAX_DUE_DATE','SRC','src','SvcEscrowDisbursement','TaxDueDate','SVC'),
('DE_DISB_AMOUNT_MATCH','SRC','src','SvcEscrowDisbursement','AmountMatchFlag','SVC'),
('DE_DISB_PAYEE_MATCH','SRC','src','SvcEscrowDisbursement','PayeeMatchFlag','SVC'),
('DE_DISB_LOAN_MATCH','SRC','src','SvcEscrowDisbursement','LoanMatchFlag','SVC'),
('DE_ESC_ANALYSIS_DUE','SRC','src','SvcEscrowAnalysis','AnalysisDueDate','SVC'),
('DE_ESC_ANALYSIS_COMPLETED','SRC','src','SvcEscrowAnalysis','AnalysisCompletedDate','SVC'),
('DE_ESC_SHORTAGE_AMOUNT','SRC','src','SvcEscrowAnalysis','ShortageAmount','SVC'),
('DE_LM_APP_RECEIVED','SRC','src','DmsLossMitigationCase','AppReceivedDate','DMS'),
('DE_LM_COMPLETE_PACKAGE','SRC','src','DmsLossMitigationCase','CompletePackageDate','DMS'),
('DE_LM_DECISION_DATE','SRC','src','DmsLossMitigationCase','DecisionDate','DMS'),
('DE_LM_DECISION_CODE','SRC','src','DmsLossMitigationCase','DecisionCode','DMS'),
('DE_LM_WORKOUT_TYPE','SRC','src','DmsLossMitigationCase','WorkoutTypeCode','DMS'),
('DE_FC_FIRST_LEGAL_ELIGIBLE','SRC','src','DmsForeclosureCase','FirstLegalEligibleDate','DMS'),
('DE_FC_REFERRAL_DATE','SRC','src','DmsForeclosureCase','ReferralDate','DMS'),
('DE_FC_SALE_HELD_DATE','SRC','src','DmsForeclosureCase','SaleHeldDate','DMS'),
('DE_FC_CASE_STATUS','SRC','src','DmsForeclosureCase','CaseStatusCode','DMS'),
('DE_FC_RESOLUTION_TYPE','SRC','src','DmsForeclosureCase','ResolutionTypeCode','DMS'),
('DE_BK_CHAPTER','SRC','src','DmsBankruptcyCase','ChapterCode','DMS'),
('DE_BK_PETITION_DATE','SRC','src','DmsBankruptcyCase','PetitionDate','DMS'),
('DE_BK_POC_BAR_DATE','SRC','src','DmsBankruptcyCase','PocBarDate','DMS'),
('DE_BK_POC_FILED_DATE','SRC','src','DmsBankruptcyCase','PocFiledDate','DMS'),
('DE_FORB_START_DATE','SRC','src','SvcForbearancePlan','PlanStartDate','SVC'),
('DE_FORB_END_DATE','SRC','src','SvcForbearancePlan','PlanEndDate','SVC'),
('DE_FORB_STATUS','SRC','src','SvcForbearancePlan','PlanStatusCode','SVC'),
('DE_MOD_EFFECTIVE_DATE','SRC','src','SvcLoanModification','ModificationEffectiveDate','SVC'),
('DE_MOD_BOOKED_DATE','SRC','src','SvcLoanModification','ModificationBookedDate','SVC'),
('DE_INV_REPORTING_DEADLINE','SRC','src','InvLoanReport','ReportingDeadlineDate','INV'),
('DE_INV_REPORT_SUBMITTED','SRC','src','InvLoanReport','ReportSubmittedDate','INV'),
('DE_INV_ACCEPTED_FLAG','SRC','src','InvLoanReport','AcceptedFlag','INV'),
('DE_INV_ERROR_COUNT','SRC','src','InvLoanReport','ErrorCount','INV'),
('DE_INV_CORRECTION_FLAG','SRC','src','InvLoanReport','CorrectionResubmissionFlag','INV'),
('DE_REMIT_DUE_DATE','SRC','src','InvRemittance','RemittanceDueDate','INV'),
('DE_REMIT_SENT_DATE','SRC','src','InvRemittance','RemittanceSentDate','INV'),
('DE_REMIT_AMOUNT','SRC','src','InvRemittance','RemittanceAmount','INV'),
('DE_REPO_DEMAND_RECEIVED','SRC','src','InvRepurchaseDemand','DemandReceivedDate','INV'),
('DE_REPO_RESOLUTION_DATE','SRC','src','InvRepurchaseDemand','ResolutionDate','INV'),
('DE_REPO_DEMAND_AMOUNT','SRC','src','InvRepurchaseDemand','DemandAmount','INV'),
('DE_LEAD_CREATED_DATE','SRC','src','CrmLead','LeadCreatedDate','CRM'),
('DE_LEAD_SOURCE','SRC','src','CrmLead','LeadSourceCode','CRM'),
('DE_LEAD_CONTACT_KEY','SRC','src','CrmLead','ContactKey','CRM'),
('DE_LEAD_CONVERTED_APP','SRC','src','CrmLead','ConvertedApplicationId','CRM'),
('DE_LEAD_STATUS','SRC','src','CrmLead','LeadStatusCode','CRM'),
('DE_APP_RECEIVED_DATE','SRC','src','LosApplication','AppReceivedDate','LOS'),
('DE_APP_STARTED_DATE','SRC','src','LosApplication','AppStartedDate','LOS'),
('DE_APP_COMPLETED_DATE','SRC','src','LosApplication','AppCompletedDate','LOS'),
('DE_APP_DISPOSITION','SRC','src','LosApplication','DispositionCode','LOS'),
('DE_APP_DISPOSITION_DATE','SRC','src','LosApplication','DispositionDate','LOS'),
('DE_APP_FUNDING_DATE','SRC','src','LosApplication','FundingDate','LOS'),
('DE_APP_SCHEDULED_CLOSING','SRC','src','LosApplication','ScheduledClosingDate','LOS'),
('DE_APP_ACTUAL_CLOSING','SRC','src','LosApplication','ActualClosingDate','LOS'),
('DE_APP_LOAN_AMOUNT','SRC','src','LosApplication','CurrentLoanAmount','LOS'),
('DE_APP_LO_NMLS','SRC','src','LosApplication','LoanOfficerNmlsId','LOS'),
('DE_APP_SERVICING_INTENT','SRC','src','LosApplication','ServicingDispositionIntentCode','LOS'),
('DE_APP_FUNDED_FLAG','SRC','src','LosApplication','FundedFlag','LOS'),
('DE_APP_CHANNEL','SRC','src','LosApplication','ChannelCode','LOS'),
('DE_LOCK_DATE','SRC','src','PpeRateLock','LockDate','PPE'),
('DE_LOCK_AMOUNT','SRC','src','PpeRateLock','LockAmount','PPE'),
('DE_LOCK_CURRENT_EXPIRATION','SRC','src','PpeRateLock','CurrentExpirationDate','PPE'),
('DE_LOCK_ORIGINAL_EXPIRATION','SRC','src','PpeRateLock','OriginalExpirationDate','PPE'),
('DE_LOCK_STATUS','SRC','src','PpeRateLock','LockStatusCode','PPE'),
('DE_LOCK_EXTENSION_COUNT','SRC','src','PpeRateLock','ExtensionCount','PPE'),
('DE_LOCK_PRIOR_LOCK','SRC','src','PpeRateLock','PriorLockId','PPE'),
('DE_LOCK_APPLICATION_LINK','SRC','src','PpeRateLock','ApplicationId','PPE'),
('DE_LO_NMLS_ID','SRC','src','LicLoanOfficerRoster','NmlsId','LIC'),
('DE_LO_FIRST_NAME','SRC','src','LicLoanOfficerRoster','FirstName','LIC'),
('DE_LO_LAST_NAME','SRC','src','LicLoanOfficerRoster','LastName','LIC'),
('DE_LO_BRANCH','SRC','src','LicLoanOfficerRoster','BranchCode','LIC'),
('DE_LO_REGION','SRC','src','LicLoanOfficerRoster','Region','LIC'),
('DE_LO_EMPLOYMENT_STATUS','SRC','src','LicLoanOfficerRoster','EmploymentStatusCode','LIC'),
('DE_LIC_STATE','SRC','src','LicLoanOfficerLicense','LicenseStateCode','LIC'),
('DE_LIC_STATUS','SRC','src','LicLoanOfficerLicense','LicenseStatusCode','LIC'),
('DE_LIC_EXPIRATION','SRC','src','LicLoanOfficerLicense','ExpirationDate','LIC'),
('DE_LIC_RENEWAL_DEADLINE','SRC','src','LicLoanOfficerLicense','RenewalDeadline','LIC'),
('DE_CE_REQUIRED_HOURS','SRC','src','LicLoanOfficerLicense','CeRequiredHours','LIC'),
('DE_CE_COMPLETED_HOURS','SRC','src','LicLoanOfficerLicense','CeCompletedHours','LIC'),
('DE_CE_COMPLETED_DATE','SRC','src','LicLoanOfficerLicense','CeCompletedDate','LIC'),
('DE_INS_POLICY_TYPE','SRC','src','SvcInsurancePolicy','PolicyTypeCode','SVC'),
('DE_INS_EFFECTIVE_DATE','SRC','src','SvcInsurancePolicy','PolicyEffectiveDate','SVC'),
('DE_INS_EXPIRATION_DATE','SRC','src','SvcInsurancePolicy','PolicyExpirationDate','SVC'),
('DE_INS_ANNUAL_PREMIUM','SRC','src','SvcInsurancePolicy','AnnualPremiumAmount','SVC');

/* ---- DW layer bindings (conformed warehouse columns) ---- */
INSERT INTO @Bind (Code, Layer, Schm, Obj, Col, SysCode)
VALUES
('DE_LOAN_NUMBER','DW','dw','DimLoan','LoanNumber',NULL),
('DE_ORIGINATION_DATE','DW','dw','DimLoan','OriginationDate',NULL),
('DE_MATURITY_DATE','DW','dw','DimLoan','MaturityDate',NULL),
('DE_ORIGINAL_LOAN_AMOUNT','DW','dw','DimLoan','OriginalLoanAmount',NULL),
('DE_NOTE_RATE','DW','dw','DimLoan','NoteRatePercent',NULL),
('DE_INTEREST_RATE_TYPE','DW','dw','DimLoan','InterestRateTypeCode',NULL),
('DE_AMORT_TERM_MONTHS','DW','dw','DimLoan','AmortizationTermMonths',NULL),
('DE_LIEN_POSITION','DW','dw','DimLoan','LienPosition',NULL),
('DE_HELOC_FLAG','DW','dw','DimLoan','HelocFlag',NULL),
('DE_REVERSE_MORTGAGE_FLAG','DW','dw','DimLoan','ReverseMortgageFlag',NULL),
('DE_LOAN_PROGRAM','DW','dw','DimLoan','LoanProgramCode',NULL),
('DE_LOAN_PURPOSE','DW','dw','DimLoan','LoanPurposeCode',NULL),
('DE_ESCROWED_FLAG','DW','dw','DimLoan','EscrowedFlag',NULL),
('DE_CONFORMING_FLAG','DW','dw','DimLoan','ConformingFlag',NULL),
('DE_MCR_LOAN_TYPE','DW','dw','DimLoan','McrLoanTypeCode',NULL),
('DE_INVESTOR_LOAN_NUMBER','DW','dw','DimLoan','InvestorLoanNumber',NULL),
('DE_BOARDED_DATE','DW','dw','DimLoan','BoardedDate',NULL),
('DE_INVESTOR_CODE','DW','dw','DimInvestor','InvestorCode',NULL),
('DE_SERVICING_TYPE','DW','dw','DimServicingType','ServicingTypeCode',NULL),
('DE_REMITTANCE_TYPE','DW','dw','DimRemittanceType','RemittanceTypeCode',NULL),
('DE_BORROWER_FIRST_NAME','DW','dw','DimBorrower','BorrowerFirstName',NULL),
('DE_BORROWER_LAST_NAME','DW','dw','DimBorrower','BorrowerLastName',NULL),
('DE_PROPERTY_STREET','DW','dw','DimProperty','PropertyStreet',NULL),
('DE_PROPERTY_CITY','DW','dw','DimProperty','PropertyCity',NULL),
('DE_PROPERTY_STATE','DW','dw','DimProperty','PropertyStateCode',NULL),
('DE_PROPERTY_POSTAL','DW','dw','DimProperty','PropertyPostalCode',NULL),
('DE_PROPERTY_TYPE','DW','dw','DimProperty','PropertyTypeCode',NULL),
('DE_OCCUPANCY_TYPE','DW','dw','DimProperty','OccupancyTypeCode',NULL),
('DE_UNITS_COUNT','DW','dw','DimProperty','UnitsCount',NULL),
('DE_FLOOD_ZONE_FLAG','DW','dw','DimProperty','FloodZoneFlag',NULL),
('DE_ASOF_DATE','DW','dw','FactLoanMonthEndSnapshot','AsOfDate',NULL),
('DE_CURRENT_UPB','DW','dw','FactLoanMonthEndSnapshot','CurrentUpbAmount',NULL),
('DE_BEGINNING_UPB','DW','dw','FactLoanMonthEndSnapshot','BeginningUpbAmount',NULL),
('DE_SCHEDULED_PRINCIPAL','DW','dw','FactLoanMonthEndSnapshot','ScheduledPrincipalAmount',NULL),
('DE_VOLUNTARY_PREPAID_PRINCIPAL','DW','dw','FactLoanMonthEndSnapshot','VoluntaryPrepaidPrincipalAmount',NULL),
('DE_INTEREST_RATE_SNAP','DW','dw','FactLoanMonthEndSnapshot','InterestRatePercent',NULL),
('DE_SERVICING_FEE_RATE','DW','dw','FactLoanMonthEndSnapshot','ServicingFeeRatePercent',NULL),
('DE_NEXT_PAYMENT_DUE_DATE','DW','dw','FactLoanMonthEndSnapshot','NextPaymentDueDate',NULL),
('DE_DAYS_PAST_DUE','DW','dw','FactLoanMonthEndSnapshot','DaysPastDue',NULL),
('DE_DELINQUENCY_BUCKET','DW','dw','DimDelinquencyStatus','DelinquencyBucketCode',NULL),
('DE_SOURCE_BUCKET','DW','dw','FactLoanMonthEndSnapshot','SourceReportedBucketCode',NULL),
('DE_LOAN_STATUS','DW','dw','DimLoanStatus','LoanStatusCode',NULL),
('DE_ESCROW_BALANCE','DW','dw','FactLoanMonthEndSnapshot','EscrowBalanceAmount',NULL),
('DE_SUSPENSE_BALANCE','DW','dw','FactLoanMonthEndSnapshot','SuspenseBalanceAmount',NULL),
('DE_FORBEARANCE_FLAG','DW','dw','FactLoanMonthEndSnapshot','ForbearanceFlag',NULL),
('DE_RUNOFF_REASON','DW','dw','FactLoanMonthEndSnapshot','RunoffReasonCode',NULL),
('DE_CURRENT_LTV','DW','dw','FactLoanMonthEndSnapshot','CurrentLtvPct',NULL),
('DE_PROPERTY_VALUE','DW','dw','FactLoanMonthEndSnapshot','CurrentLtvPct',NULL),
('DE_TAPE_UPB','DW','dw','FactBoardingEvent','UpbMismatchFlag',NULL),
('DE_TAPE_RATE','DW','dw','FactBoardingEvent','RateMismatchFlag',NULL),
('DE_TAPE_NEXT_DUE','DW','dw','FactBoardingEvent','NextDueDateMismatchFlag',NULL),
('DE_TAPE_ESCROW_BALANCE','DW','dw','FactBoardingEvent','EscrowBalanceMismatchFlag',NULL),
('DE_TAPE_INVESTOR','DW','dw','FactBoardingEvent','InvestorMismatchFlag',NULL),
('DE_BOARDING_COMPLETED_DATE','DW','dw','FactBoardingEvent','BoardingCompletedDate',NULL),
('DE_TRANSFER_EFFECTIVE_DATE','DW','dw','FactBoardingEvent','TransferEffectiveDate',NULL),
('DE_TRANSFER_TYPE','DW','dw','FactBoardingEvent','TransferTypeCode',NULL),
('DE_PAY_RECEIVED_DATE','DW','dw','FactPaymentTransaction','ReceivedDate',NULL),
('DE_PAY_POSTED_DATE','DW','dw','FactPaymentTransaction','PostedDate',NULL),
('DE_PAY_EFFECTIVE_DATE','DW','dw','FactPaymentTransaction','EffectiveDate',NULL),
('DE_PAY_AMOUNT','DW','dw','FactPaymentTransaction','PaymentAmount',NULL),
('DE_PAY_PRINCIPAL','DW','dw','FactPaymentTransaction','PrincipalAmount',NULL),
('DE_PAY_INTEREST','DW','dw','FactPaymentTransaction','InterestAmount',NULL),
('DE_PAY_ESCROW','DW','dw','FactPaymentTransaction','EscrowAmount',NULL),
('DE_PAY_REVERSAL_FLAG','DW','dw','FactPaymentTransaction','ReversalFlag',NULL),
('DE_PAY_ORIGINAL_TXN','DW','dw','FactPaymentTransaction','OriginalTransactionId',NULL),
('DE_PAY_SUSPENSE_FLAG','DW','dw','FactPaymentTransaction','SuspenseFlag',NULL),
('DE_DISB_TYPE','DW','dw','FactEscrowDisbursement','DisbursementTypeCode',NULL),
('DE_DISB_DATE','DW','dw','FactEscrowDisbursement','DisbursedDate',NULL),
('DE_DISB_AMOUNT','DW','dw','FactEscrowDisbursement','DisbursedAmount',NULL),
('DE_TAX_DUE_DATE','DW','dw','FactEscrowDisbursement','TaxDueDate',NULL),
('DE_DISB_AMOUNT_MATCH','DW','dw','FactEscrowDisbursement','AmountMatchFlag',NULL),
('DE_DISB_PAYEE_MATCH','DW','dw','FactEscrowDisbursement','PayeeMatchFlag',NULL),
('DE_DISB_LOAN_MATCH','DW','dw','FactEscrowDisbursement','LoanMatchFlag',NULL),
('DE_ESC_ANALYSIS_DUE','DW','dw','FactEscrowAnalysis','AnalysisDueDate',NULL),
('DE_ESC_ANALYSIS_COMPLETED','DW','dw','FactEscrowAnalysis','AnalysisCompletedDate',NULL),
('DE_ESC_SHORTAGE_AMOUNT','DW','dw','FactEscrowAnalysis','ShortageAmount',NULL),
('DE_LM_APP_RECEIVED','DW','dw','FactLossMitigationCase','AppReceivedDate',NULL),
('DE_LM_COMPLETE_PACKAGE','DW','dw','FactLossMitigationCase','CompletePackageDate',NULL),
('DE_LM_DECISION_DATE','DW','dw','FactLossMitigationCase','DecisionDate',NULL),
('DE_LM_DECISION_CODE','DW','dw','FactLossMitigationCase','DecisionCode',NULL),
('DE_LM_WORKOUT_TYPE','DW','dw','FactLossMitigationCase','WorkoutTypeCode',NULL),
('DE_FC_FIRST_LEGAL_ELIGIBLE','DW','dw','FactForeclosureCase','FirstLegalEligibleDate',NULL),
('DE_FC_REFERRAL_DATE','DW','dw','FactForeclosureCase','ReferralDate',NULL),
('DE_FC_SALE_HELD_DATE','DW','dw','FactForeclosureCase','SaleHeldDate',NULL),
('DE_FC_CASE_STATUS','DW','dw','FactForeclosureCase','CaseStatusCode',NULL),
('DE_FC_RESOLUTION_TYPE','DW','dw','FactForeclosureCase','ResolutionTypeCode',NULL),
('DE_BK_CHAPTER','DW','dw','FactBankruptcyCase','ChapterCode',NULL),
('DE_BK_PETITION_DATE','DW','dw','FactBankruptcyCase','PetitionDate',NULL),
('DE_BK_POC_BAR_DATE','DW','dw','FactBankruptcyCase','PocBarDate',NULL),
('DE_BK_POC_FILED_DATE','DW','dw','FactBankruptcyCase','PocFiledDate',NULL),
('DE_MOD_EFFECTIVE_DATE','DW','dw','FactLoanMonthEndSnapshot','ModSeasoningCode',NULL),
('DE_INV_REPORTING_DEADLINE','DW','dw','FactInvestorLoanReporting','ReportingDeadlineDate',NULL),
('DE_INV_REPORT_SUBMITTED','DW','dw','FactInvestorLoanReporting','ReportSubmittedDate',NULL),
('DE_INV_ACCEPTED_FLAG','DW','dw','FactInvestorLoanReporting','AcceptedFlag',NULL),
('DE_INV_ERROR_COUNT','DW','dw','FactInvestorLoanReporting','ErrorCount',NULL),
('DE_INV_CORRECTION_FLAG','DW','dw','FactInvestorLoanReporting','CorrectionResubmissionFlag',NULL),
('DE_REMIT_DUE_DATE','DW','dw','FactInvestorRemittance','RemittanceDueDate',NULL),
('DE_REMIT_SENT_DATE','DW','dw','FactInvestorRemittance','RemittanceSentDate',NULL),
('DE_REMIT_AMOUNT','DW','dw','FactInvestorRemittance','RemittanceAmount',NULL),
('DE_REPO_DEMAND_RECEIVED','DW','dw','FactRepurchaseDemand','DemandReceivedDate',NULL),
('DE_REPO_RESOLUTION_DATE','DW','dw','FactRepurchaseDemand','ResolutionDate',NULL),
('DE_REPO_DEMAND_AMOUNT','DW','dw','FactRepurchaseDemand','DemandAmount',NULL),
('DE_LEAD_CREATED_DATE','DW','dw','FactLead','LeadCreatedDate',NULL),
('DE_LEAD_SOURCE','DW','dw','DimLeadSource','LeadSourceCode',NULL),
('DE_LEAD_CONTACT_KEY','DW','dw','FactLead','ContactKey',NULL),
('DE_LEAD_CONVERTED_APP','DW','dw','FactLead','ConvertedApplicationId',NULL),
('DE_LEAD_STATUS','DW','dw','FactLead','LeadStatusCode',NULL),
('DE_APP_RECEIVED_DATE','DW','dw','FactApplication','AppReceivedDate',NULL),
('DE_APP_STARTED_DATE','DW','dw','FactApplication','AppStartedDate',NULL),
('DE_APP_COMPLETED_DATE','DW','dw','FactApplication','AppCompletedDate',NULL),
('DE_APP_DISPOSITION','DW','dw','FactApplication','DispositionCode',NULL),
('DE_APP_DISPOSITION_DATE','DW','dw','FactApplication','DispositionDate',NULL),
('DE_APP_FUNDING_DATE','DW','dw','FactApplication','FundingDate',NULL),
('DE_APP_SCHEDULED_CLOSING','DW','dw','FactApplication','ScheduledClosingDate',NULL),
('DE_APP_ACTUAL_CLOSING','DW','dw','FactApplication','ActualClosingDate',NULL),
('DE_APP_LOAN_AMOUNT','DW','dw','FactApplication','CurrentLoanAmount',NULL),
('DE_APP_LO_NMLS','DW','dw','FactApplication','LoanOfficerNmlsId',NULL),
('DE_APP_FUNDED_FLAG','DW','dw','FactApplication','FundedFlag',NULL),
('DE_APP_CHANNEL','DW','dw','FactApplication','ChannelCode',NULL),
('DE_LOCK_DATE','DW','dw','FactRateLock','LockDate',NULL),
('DE_LOCK_AMOUNT','DW','dw','FactRateLock','LockAmount',NULL),
('DE_LOCK_CURRENT_EXPIRATION','DW','dw','FactRateLock','CurrentExpirationDate',NULL),
('DE_LOCK_ORIGINAL_EXPIRATION','DW','dw','FactRateLock','OriginalExpirationDate',NULL),
('DE_LOCK_STATUS','DW','dw','FactRateLock','LockStatusCode',NULL),
('DE_LOCK_EXTENSION_COUNT','DW','dw','FactRateLock','ExtensionCount',NULL),
('DE_LOCK_PRIOR_LOCK','DW','dw','FactRateLock','PriorLockId',NULL),
('DE_LOCK_APPLICATION_LINK','DW','dw','FactRateLock','ApplicationId',NULL),
('DE_LO_NMLS_ID','DW','dw','DimLoanOfficer','NmlsId',NULL),
('DE_LO_FIRST_NAME','DW','dw','DimLoanOfficer','FirstName',NULL),
('DE_LO_LAST_NAME','DW','dw','DimLoanOfficer','LastName',NULL),
('DE_LO_BRANCH','DW','dw','DimLoanOfficer','BranchCode',NULL),
('DE_LO_REGION','DW','dw','DimLoanOfficer','Region',NULL),
('DE_LO_EMPLOYMENT_STATUS','DW','dw','DimLoanOfficer','EmploymentStatusCode',NULL),
('DE_LIC_STATE','DW','dw','FactLoanOfficerLicense','LicenseStateCode',NULL),
('DE_LIC_STATUS','DW','dw','FactLoanOfficerLicense','LicenseStatusCode',NULL),
('DE_LIC_EXPIRATION','DW','dw','FactLoanOfficerLicense','ExpirationDate',NULL),
('DE_LIC_RENEWAL_DEADLINE','DW','dw','FactLoanOfficerLicense','RenewalDeadline',NULL),
('DE_CE_REQUIRED_HOURS','DW','dw','FactLoanOfficerLicense','CeRequiredHours',NULL),
('DE_CE_COMPLETED_HOURS','DW','dw','FactLoanOfficerLicense','CeCompletedHours',NULL),
('DE_CE_COMPLETED_DATE','DW','dw','FactLoanOfficerLicense','CeCompletedDate',NULL);

/* ---- Insert all bindings from the staging table ---- */
INSERT INTO gov.DataElementBinding
    (DataElementId, LayerCode, SchemaName, ObjectName,
     ColumnName, SourceSystemId, LoadBatchId)
SELECT de.DataElementId, b.Layer, b.Schm, b.Obj, b.Col,
       ss.SourceSystemId, @LoadBatchId
FROM @Bind b
JOIN gov.DataElement de ON de.DataElementCode = b.Code
LEFT JOIN gov.SourceSystem ss ON ss.SourceSystemCode = b.SysCode;

/* ------------------------------------------------------------
   5. Authoritative source register. Attribute-level authority
      including the BRD-to-SVC boarding handoff deferred by
      012. Boarding-static loan attributes are authoritative
      at BRD on the board date and pass to SVC afterward; all
      other elements have a single authoritative system.
      Reload owned rows.
   ------------------------------------------------------------ */
DELETE FROM gov.AuthoritativeSource;

/* -- 5a. Boarding handoff: dual rows per boarding-static
      element (AT_BOARDING = BRD, POST_BOARDING = SVC) -- */
INSERT INTO gov.AuthoritativeSource
    (DataElementId, SourceSystemId, AuthorityScopeCode,
     EffectiveFromDate, HandoffRule, LoadBatchId)
SELECT de.DataElementId, ss.SourceSystemId, v.Scope,
       '2015-01-01', v.Handoff, @LoadBatchId
FROM (VALUES
 ('DE_LOAN_NUMBER','BRD','AT_BOARDING',
  N'BRD authoritative at boarding; SVC authoritative from '
  + N'the board date forward.'),
 ('DE_LOAN_NUMBER','SVC','POST_BOARDING',
  N'SVC is the system of record post-boarding.'),
 ('DE_ORIGINAL_LOAN_AMOUNT','BRD','AT_BOARDING',
  N'Tape value governs at boarding; SVC thereafter.'),
 ('DE_ORIGINAL_LOAN_AMOUNT','SVC','POST_BOARDING',
  N'SVC master governs post-boarding.'),
 ('DE_NOTE_RATE','BRD','AT_BOARDING',
  N'Tape note rate governs at boarding; SVC thereafter.'),
 ('DE_NOTE_RATE','SVC','POST_BOARDING',
  N'SVC governs the current note rate post-boarding.'),
 ('DE_ORIGINATION_DATE','BRD','AT_BOARDING',
  N'Origination-static; captured at boarding, retained by '
  + N'SVC.'),
 ('DE_ORIGINATION_DATE','SVC','POST_BOARDING',
  N'SVC retains the origination date post-boarding.'),
 ('DE_INVESTOR_CODE','BRD','AT_BOARDING',
  N'Tape investor governs at boarding; SVC thereafter '
  + N'(DEF12 typo enters at SVC).'),
 ('DE_INVESTOR_CODE','SVC','POST_BOARDING',
  N'SVC governs investor of record post-boarding.')
) v(Code, SysCode, Scope, Handoff)
JOIN gov.DataElement de ON de.DataElementCode = v.Code
JOIN gov.SourceSystem ss ON ss.SourceSystemCode = v.SysCode;

/* -- 5b. Single-authority elements: derive the authoritative
      system from the SRC binding's SourceSystemId. Scope
      FULL, with a system-specific note. Excludes the five
      handoff elements already seeded above. -- */
INSERT INTO gov.AuthoritativeSource
    (DataElementId, SourceSystemId, AuthorityScopeCode,
     EffectiveFromDate, HandoffRule, LoadBatchId)
SELECT DISTINCT de.DataElementId, b.SourceSystemId, 'FULL',
       '2015-01-01',
       N'Single authoritative system: '
       + ss.SourceSystemName + N' (' + ss.SourceSystemCode
       + N').',
       @LoadBatchId
FROM gov.DataElementBinding b
JOIN gov.DataElement de ON de.DataElementId = b.DataElementId
JOIN gov.SourceSystem ss ON ss.SourceSystemId = b.SourceSystemId
WHERE b.LayerCode = 'SRC'
  AND b.SourceSystemId IS NOT NULL
  AND de.DataElementCode NOT IN
      ('DE_LOAN_NUMBER','DE_ORIGINAL_LOAN_AMOUNT',
       'DE_NOTE_RATE','DE_ORIGINATION_DATE','DE_INVESTOR_CODE');

/* ------------------------------------------------------------
   6. Bind gov.DerivationRuleInput.DataElementId. 005 seeded
      inputs as stg-contract references (deferred binding).
      The stg contract mirrors src table/column names, so we
      resolve InputReference stg.<Object>.<Column> to the
      element bound to the matching src column. Only unbound
      inputs are touched.
   ------------------------------------------------------------ */
UPDATE ri
SET ri.DataElementId = de.DataElementId,
    ri.ModifiedDateUtc = SYSUTCDATETIME()
FROM gov.DerivationRuleInput ri
CROSS APPLY (
    SELECT
      PARSENAME(REPLACE(ri.InputReference, 'stg.', 'x.'), 2)
        AS ObjName,
      PARSENAME(ri.InputReference, 1) AS ColName
) p
JOIN gov.DataElementBinding b
  ON b.LayerCode = 'SRC'
 AND b.ObjectName = CASE
        /* stg contract object -> src physical object */
        WHEN p.ObjName = 'LoanMaster' THEN 'SvcLoanMaster'
        WHEN p.ObjName = 'LoanMonthEnd' THEN 'SvcLoanMonthEnd'
        WHEN p.ObjName = 'EscrowAnalysis' THEN 'SvcEscrowAnalysis'
        WHEN p.ObjName = 'EscrowDisbursement' THEN 'SvcEscrowDisbursement'
        WHEN p.ObjName = 'InsurancePolicy' THEN 'SvcInsurancePolicy'
        WHEN p.ObjName = 'ForbearancePlan' THEN 'SvcForbearancePlan'
        WHEN p.ObjName = 'LoanModification' THEN 'SvcLoanModification'
        WHEN p.ObjName = 'PaymentTransaction' THEN 'PayPaymentTransaction'
        WHEN p.ObjName = 'LossMitigationCase' THEN 'DmsLossMitigationCase'
        WHEN p.ObjName = 'ForeclosureCase' THEN 'DmsForeclosureCase'
        WHEN p.ObjName = 'BankruptcyCase' THEN 'DmsBankruptcyCase'
        WHEN p.ObjName = 'InvestorLoanReport' THEN 'InvLoanReport'
        WHEN p.ObjName = 'InvestorRemittance' THEN 'InvRemittance'
        WHEN p.ObjName = 'RepurchaseDemand' THEN 'InvRepurchaseDemand'
        WHEN p.ObjName = 'PropertyValuation' THEN 'ValPropertyValuation'
        /* stg contract denormalizes the boarding batch onto
           the tape; the SLA anchor is physically on the
           batch table. */
        WHEN p.ObjName = 'BoardingTape'
         AND p.ColName = 'TransferEffectiveDate'
             THEN 'BrdBoardingBatch'
        WHEN p.ObjName = 'BoardingTape' THEN 'BrdBoardingTape'
        WHEN p.ObjName = 'Lead' THEN 'CrmLead'
        WHEN p.ObjName = 'Application' THEN 'LosApplication'
        WHEN p.ObjName = 'RateLock' THEN 'PpeRateLock'
        WHEN p.ObjName = 'LoanOfficerLicense' THEN 'LicLoanOfficerLicense'
        ELSE p.ObjName END
 AND b.ColumnName = CASE
        /* stg contract column -> src physical column */
        WHEN p.ColName = 'CurrentUpb' THEN 'CurrentUpbAmount'
        WHEN p.ColName = 'BeginningUpb' THEN 'BeginningUpbAmount'
        WHEN p.ColName = 'ScheduledPrincipal' THEN 'ScheduledPrincipalAmount'
        WHEN p.ColName = 'VoluntaryPrepaidPrincipal' THEN 'VoluntaryPrepaidPrincipalAmount'
        WHEN p.ColName = 'SuspenseBalance' THEN 'SuspenseBalanceAmount'
        WHEN p.ColName = 'PropertyValue' THEN 'PropertyValueAmount'
        WHEN p.ColName = 'ApplicationId' AND p.ObjName = 'RateLock' THEN 'ApplicationId'
        ELSE p.ColName END
JOIN gov.DataElement de ON de.DataElementId = b.DataElementId
WHERE ri.DataElementId IS NULL;

/* ------------------------------------------------------------
   7. Element-level RACI. Each element inherits the data owner
      (A) and data steward (R) of its authoritative source
      system from the system RACI seeded in 004. Technical
      steward (Noah Curlew, R) attaches to every CDE.
      Reload owned rows (DATA_ELEMENT scope only).
   ------------------------------------------------------------ */
DELETE FROM gov.RoleAssignment
WHERE EntityTypeCode = 'DATA_ELEMENT';

/* -- 7a. Owner + steward inherited from the element's SRC
      system. For handoff elements, SVC (post-boarding
      system of record) governs stewardship. -- */
;WITH ElementSystem AS (
    SELECT de.DataElementId,
           MIN(COALESCE(b.SourceSystemId, 0)) AS SrcSystemId
    FROM gov.DataElement de
    JOIN gov.DataElementBinding b
      ON b.DataElementId = de.DataElementId
     AND b.LayerCode = 'SRC'
    WHERE b.SourceSystemId IS NOT NULL
    GROUP BY de.DataElementId
)
INSERT INTO gov.RoleAssignment
    (EntityTypeCode, EntityId, EntityReference,
     GovernanceRoleId, PartyId, RaciCode, LoadBatchId)
SELECT 'DATA_ELEMENT', es.DataElementId, de.DataElementCode,
       sys_ra.GovernanceRoleId, sys_ra.PartyId,
       sys_ra.RaciCode, @LoadBatchId
FROM ElementSystem es
JOIN gov.DataElement de ON de.DataElementId = es.DataElementId
JOIN gov.RoleAssignment sys_ra
  ON sys_ra.EntityTypeCode = 'SOURCE_SYSTEM'
 AND sys_ra.EntityId = es.SrcSystemId
JOIN gov.GovernanceRole gr
  ON gr.GovernanceRoleId = sys_ra.GovernanceRoleId
 AND gr.RoleCode IN ('DATA_OWNER','DATA_STEWARD');

/* -- 7b. Technical steward on every CDE -- */
INSERT INTO gov.RoleAssignment
    (EntityTypeCode, EntityId, EntityReference,
     GovernanceRoleId, PartyId, RaciCode, LoadBatchId)
SELECT 'DATA_ELEMENT', de.DataElementId, de.DataElementCode,
       gr.GovernanceRoleId, p.PartyId, 'R', @LoadBatchId
FROM gov.DataElement de
JOIN gov.CriticalDataElement c
  ON c.DataElementId = de.DataElementId
CROSS JOIN gov.GovernanceRole gr
CROSS JOIN gov.Party p
WHERE gr.RoleCode = 'TECHNICAL_STEWARD'
  AND p.PartyName = 'Noah Curlew'
  AND p.PartyTypeCode = 'PERSON';

/* ------------------------------------------------------------
   8. Metric-to-element lineage. 008 seeded metric-to-rule
      dependencies (DERIVATION_RULE) and three direct
      metric-to-element references. This derives DATA_ELEMENT
      dependencies transitively: for every metric that depends
      on a rule, attach the elements bound to that rule's
      inputs (section 6). RoleInMetric carries INPUT. Skips
      any metric-element pair 008 already inserted. Reload
      only the transitively derived rows (identify them by a
      sentinel note).
   ------------------------------------------------------------ */
DELETE FROM gov.MetricDependency
WHERE DependencyTypeCode = 'DATA_ELEMENT'
  AND Notes = N'Derived in 017 from rule-input bindings.';

INSERT INTO gov.MetricDependency
    (MetricDefinitionId, DependencyTypeCode,
     DependencyEntityId, DependencyReference, RoleInMetricCode,
     Notes, LoadBatchId)
SELECT DISTINCT md.MetricDefinitionId, 'DATA_ELEMENT',
       de.DataElementId, de.DataElementCode, 'INPUT',
       N'Derived in 017 from rule-input bindings.',
       @LoadBatchId
FROM gov.MetricDependency md
JOIN gov.DerivationRule dr
  ON dr.DerivationRuleId = md.DependencyEntityId
 AND md.DependencyTypeCode = 'DERIVATION_RULE'
JOIN gov.DerivationRuleInput ri
  ON ri.DerivationRuleId = dr.DerivationRuleId
 AND ri.DataElementId IS NOT NULL
JOIN gov.DataElement de
  ON de.DataElementId = ri.DataElementId
WHERE NOT EXISTS (
    SELECT 1 FROM gov.MetricDependency x
    WHERE x.MetricDefinitionId = md.MetricDefinitionId
      AND x.DependencyTypeCode = 'DATA_ELEMENT'
      AND x.DependencyEntityId = de.DataElementId
);

/* ------------------------------------------------------------
   9. Column-level SourceToTargetMap. Documents how each bound
      DW column is populated from source: DIRECT copy or
      DERIVED (rule-governed). Reload owned rows. This is the
      field-binding layer 016's loaders implement; replacing a
      source system is a mapping change here, not a logic
      rewrite. One row per DW-bound element with a known SRC
      binding; DERIVED where the element is a rule output.
   ------------------------------------------------------------ */
DELETE FROM gov.SourceToTargetMap
WHERE TargetSchemaName = 'dw';

/* -- 9a. DIRECT maps: element has both a SRC and DW binding
      and is not a derived output -- */
;WITH DerivedElements AS (
    /* elements that are rule outputs, not direct copies */
    SELECT DISTINCT de.DataElementCode
    FROM gov.DataElement de
    WHERE de.DataElementCode IN
      ('DE_DAYS_PAST_DUE','DE_DELINQUENCY_BUCKET',
       'DE_CURRENT_LTV','DE_CONFORMING_FLAG',
       'DE_MCR_LOAN_TYPE','DE_PROPERTY_VALUE',
       'DE_APP_FUNDED_FLAG')
),
SrcBind AS (
    SELECT b.DataElementId, b.SchemaName AS SrcSchema,
           b.ObjectName AS SrcObject, b.ColumnName AS SrcColumn,
           b.SourceSystemId
    FROM gov.DataElementBinding b
    WHERE b.LayerCode = 'SRC'
),
DwBind AS (
    SELECT b.DataElementId, b.SchemaName AS TgtSchema,
           b.ObjectName AS TgtObject, b.ColumnName AS TgtColumn
    FROM gov.DataElementBinding b
    WHERE b.LayerCode = 'DW'
)
INSERT INTO gov.SourceToTargetMap
    (TargetSchemaName, TargetObjectName, TargetColumnName,
     SourceSystemId, SourceObjectName, SourceColumnName,
     TransformTypeCode, DerivationRuleId, ActiveFromDate,
     MappingNotes, LoadBatchId)
SELECT d.TgtSchema, d.TgtObject, d.TgtColumn,
       s.SourceSystemId, s.SrcObject, s.SrcColumn,
       'DIRECT', NULL, '2015-01-01',
       N'Direct load from source column.', @LoadBatchId
FROM DwBind d
JOIN SrcBind s ON s.DataElementId = d.DataElementId
JOIN gov.DataElement de ON de.DataElementId = d.DataElementId
WHERE de.DataElementCode NOT IN
      (SELECT DataElementCode FROM DerivedElements)
  AND NOT EXISTS (
      SELECT 1 FROM gov.SourceToTargetMap m
      WHERE m.TargetSchemaName = d.TgtSchema
        AND m.TargetObjectName = d.TgtObject
        AND m.TargetColumnName = d.TgtColumn
        AND m.SourceSystemId = s.SourceSystemId
        AND m.ActiveFromDate = '2015-01-01');

/* -- 9b. DERIVED maps: rule-governed DW columns tied to the
      registered DerivationRule -- */
INSERT INTO gov.SourceToTargetMap
    (TargetSchemaName, TargetObjectName, TargetColumnName,
     SourceSystemId, SourceObjectName, SourceColumnName,
     TransformTypeCode, DerivationRuleId, ActiveFromDate,
     MappingNotes, LoadBatchId)
SELECT v.TgtObj, v.TgtCol2, v.TgtCol, ss.SourceSystemId,
       v.SrcObj, v.SrcCol, 'DERIVED', dr.DerivationRuleId,
       '2015-01-01', v.Note, @LoadBatchId
FROM (VALUES
 ('dw','FactLoanMonthEndSnapshot','DaysPastDue',
  'SVC','SvcLoanMonthEnd','NextPaymentDueDate','DRV_DPD',
  N'Days past due derived from next payment due date.'),
 ('dw','FactLoanMonthEndSnapshot','DelinquencyStatusKey',
  'SVC','SvcLoanMonthEnd','NextPaymentDueDate','DRV_DQBUCKET',
  N'Derived bucket via ref.DelinquencyBucket.'),
 ('dw','FactLoanMonthEndSnapshot','CurrentLtvPct',
  'VAL','ValPropertyValuation','PropertyValueAmount','DRV_CLTV',
  N'CLTV: UPB over latest property value.'),
 ('dw','FactLoanMonthEndSnapshot','LtvBandCode',
  'VAL','ValPropertyValuation','PropertyValueAmount','DRV_LTVBAND',
  N'LTV band via ref.LtvBand.'),
 ('dw','DimLoan','ConformingFlag',
  'SVC','SvcLoanMaster','OriginalLoanAmount','DRV_CONFORMING',
  N'Conforming test vs ref.ConformingLoanLimit.'),
 ('dw','DimLoan','McrLoanTypeCode',
  'SVC','SvcLoanMaster','LoanProgramCode','DRV_MCRLOANTYPE',
  N'MCR loan type derived for FV7 mapping.'),
 ('dw','FactLoanMonthEndSnapshot','Roll30to60Flag',
  'SVC','SvcLoanMonthEnd','NextPaymentDueDate','DRV_ROLL3060',
  N'30-to-60 roll via prior-month self join.'),
 ('dw','FactLoanMonthEndSnapshot','CureFlag',
  'SVC','SvcLoanMonthEnd','NextPaymentDueDate','DRV_CURE',
  N'Cure via prior-month self join.'),
 ('dw','FactLoanMonthEndSnapshot','RunoffFlag',
  'SVC','SvcLoanMonthEnd','RunoffReasonCode','DRV_RUNOFF',
  N'Runoff flag from runoff reason.'),
 ('dw','FactPaymentTransaction','PostedTimelyFlag',
  'PAY','PayPaymentTransaction','PostedDate','DRV_PAYTIMELY',
  N'Posting timeliness vs next business day.'),
 ('dw','FactPaymentTransaction','PostedAccuratelyFlag',
  'PAY','PayPaymentTransaction','ReversalFlag','DRV_PAYACC',
  N'Accuracy via reversal-chain logic.'),
 ('dw','FactEscrowDisbursement','DisbursedTimelyFlag',
  'SVC','SvcEscrowDisbursement','TaxDueDate','DRV_TAXTIMELY',
  N'Tax disbursement timeliness vs due date.'),
 ('dw','FactBoardingEvent','BoardingAccuracyScore',
  'BRD','BrdBoardingTape','TapeUpbAmount','DRV_BOARDACC',
  N'Five-field tape-vs-master accuracy score.'),
 ('dw','FactApplication','FundedFlag',
  'LOS','LosApplication','FundingDate','DRV_ACTIVEPOP',
  N'Funded status from funding date and disposition.'),
 ('dw','FactApplication','CycleTimeDays',
  'LOS','LosApplication','FundingDate','DRV_CYCLETIME',
  N'Cycle time from application received to funding.'),
 ('dw','FactRateLock','ExpiredWithoutFundingFlag',
  'PPE','PpeRateLock','CurrentExpirationDate','DRV_LOCKEXP',
  N'Lock expiry without funded application.'),
 ('dw','FactLoanOfficerLicense','LicenseCompliantFlag',
  'LIC','LicLoanOfficerLicense','LicenseStatusCode','DRV_MLOLIC',
  N'License compliance as of the evaluation date.')
) v(TgtObj, TgtCol2, TgtCol, SysCode, SrcObj, SrcCol,
    RuleCode, Note)
JOIN gov.SourceSystem ss ON ss.SourceSystemCode = v.SysCode
JOIN gov.DerivationRule dr ON dr.RuleCode = v.RuleCode
WHERE NOT EXISTS (
    SELECT 1 FROM gov.SourceToTargetMap m
    WHERE m.TargetSchemaName = v.TgtObj
      AND m.TargetObjectName = v.TgtCol2
      AND m.TargetColumnName = v.TgtCol
      AND m.SourceSystemId = ss.SourceSystemId
      AND m.ActiveFromDate = '2015-01-01');

/* ------------------------------------------------------------
   10. Change log
   ------------------------------------------------------------ */
IF NOT EXISTS
   (SELECT 1 FROM gov.ChangeLog
    WHERE EntityTypeCode = 'GOVERNANCE_PLATFORM'
      AND ChangeDescription LIKE N'Phase 7 governance bindings%')
BEGIN
    INSERT INTO gov.ChangeLog
        (EntityTypeCode, EntityReference, ChangeTypeCode,
         ChangeDescription, LoadBatchId)
    VALUES
        ('GOVERNANCE_PLATFORM', N'MortgageGovernance',
         'INSERT',
         N'Phase 7 governance bindings: data element catalog, '
         + N'glossary links, CDE register, SRC/DW bindings, '
         + N'authoritative source register with BRD-to-SVC '
         + N'boarding handoff, rule-input element binding, '
         + N'element RACI inheritance, transitive '
         + N'metric-to-element lineage, and the column-level '
         + N'source-to-target map.',
         @LoadBatchId);
END

COMMIT;

EXEC audit.usp_CompleteLoadBatch
     @LoadBatchId = @LoadBatchId,
     @StatusCode  = 'SUCCESS';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    EXEC audit.usp_LogError
         @LoadBatchId = @LoadBatchId,
         @ContextInfo = N'017_gov_bindings.sql';
    EXEC audit.usp_CompleteLoadBatch
         @LoadBatchId = @LoadBatchId,
         @StatusCode  = 'FAILED';
    THROW;
END CATCH
GO

/* ============================================================
   Section 11. Generation views. Human-readable governance
   artifacts are generated from SQL metadata, never
   hand-maintained. These three feed the data dictionary
   export, the CDE register, and the metric-to-source lineage
   walk demonstrated in the Power BI Data Lineage page.
   CREATE OR ALTER: safe to re-run.
   ============================================================ */

/* ---- 11a. gov.vw_DataDictionary: one row per element with
        its term, classification, CDE status, authoritative
        system, and SRC/DW physical bindings collapsed. ---- */
CREATE OR ALTER VIEW gov.vw_DataDictionary
AS
SELECT
    de.DataElementCode,
    de.DataElementName,
    de.BusinessDefinition,
    bt.TermName            AS GlossaryTerm,
    de.DomainArea,
    de.DataTypeCategory,
    de.ClassificationLevelCode,
    de.PiiTypeCode,
    de.CdeFlag,
    cde.CdeRationale,
    auth.AuthoritativeSystems,
    src.SrcBinding,
    dw.DwBinding
FROM gov.DataElement de
LEFT JOIN gov.BusinessTerm bt
  ON bt.BusinessTermId = de.BusinessTermId
LEFT JOIN gov.CriticalDataElement cde
  ON cde.DataElementId = de.DataElementId
OUTER APPLY (
    SELECT STRING_AGG(
      ss.SourceSystemCode + N' (' + a.AuthorityScopeCode
      + N')', N', ')
      WITHIN GROUP (ORDER BY a.AuthorityScopeCode)
      AS AuthoritativeSystems
    FROM gov.AuthoritativeSource a
    JOIN gov.SourceSystem ss
      ON ss.SourceSystemId = a.SourceSystemId
    WHERE a.DataElementId = de.DataElementId
) auth
OUTER APPLY (
    SELECT STRING_AGG(
      b.SchemaName + N'.' + b.ObjectName + N'.'
      + b.ColumnName, N'; ')
      AS SrcBinding
    FROM gov.DataElementBinding b
    WHERE b.DataElementId = de.DataElementId
      AND b.LayerCode = 'SRC'
) src
OUTER APPLY (
    SELECT STRING_AGG(
      b.SchemaName + N'.' + b.ObjectName + N'.'
      + b.ColumnName, N'; ')
      AS DwBinding
    FROM gov.DataElementBinding b
    WHERE b.DataElementId = de.DataElementId
      AND b.LayerCode = 'DW'
) dw
WHERE de.ActiveFlag = 1;
GO

/* ---- 11b. gov.vw_CdeRegister: the CDE register with owner,
        steward, and quality-rule coverage count. ---- */
CREATE OR ALTER VIEW gov.vw_CdeRegister
AS
SELECT
    de.DataElementCode,
    de.DataElementName,
    de.DomainArea,
    de.ClassificationLevelCode,
    de.PiiTypeCode,
    cde.CdeRationale,
    cde.ReviewFrequencyCode,
    cde.NextReviewDate,
    owner_p.PartyName      AS DataOwner,
    steward_p.PartyName    AS DataSteward,
    ISNULL(dq.RuleCount, 0) AS DqRuleCount
FROM gov.CriticalDataElement cde
JOIN gov.DataElement de
  ON de.DataElementId = cde.DataElementId
OUTER APPLY (
    SELECT TOP 1 p.PartyName
    FROM gov.RoleAssignment ra
    JOIN gov.GovernanceRole gr
      ON gr.GovernanceRoleId = ra.GovernanceRoleId
     AND gr.RoleCode = 'DATA_OWNER'
    JOIN gov.Party p ON p.PartyId = ra.PartyId
    WHERE ra.EntityTypeCode = 'DATA_ELEMENT'
      AND ra.EntityId = de.DataElementId
) owner_p
OUTER APPLY (
    SELECT TOP 1 p.PartyName
    FROM gov.RoleAssignment ra
    JOIN gov.GovernanceRole gr
      ON gr.GovernanceRoleId = ra.GovernanceRoleId
     AND gr.RoleCode = 'DATA_STEWARD'
    JOIN gov.Party p ON p.PartyId = ra.PartyId
    WHERE ra.EntityTypeCode = 'DATA_ELEMENT'
      AND ra.EntityId = de.DataElementId
) steward_p
OUTER APPLY (
    SELECT COUNT(*) AS RuleCount
    FROM dq.[Rule] r
    WHERE r.DataElementCode = de.DataElementCode
      AND r.ActiveFlag = 1
) dq;
GO

/* ---- 11c. gov.vw_MetricElementLineage: metric to element
        to authoritative source, the walk shown on the Power
        BI lineage page (Source -> Warehouse -> Metric). ---- */
CREATE OR ALTER VIEW gov.vw_MetricElementLineage
AS
SELECT DISTINCT
    m.MetricCode,
    m.MetricName,
    m.CoverageStatusCode,
    de.DataElementCode,
    de.DataElementName,
    de.CdeFlag,
    srcb.SchemaName + N'.' + srcb.ObjectName + N'.'
      + srcb.ColumnName AS SourceColumn,
    ss.SourceSystemCode AS SourceSystem,
    dwb.SchemaName + N'.' + dwb.ObjectName + N'.'
      + dwb.ColumnName  AS WarehouseColumn
FROM gov.MetricDefinition m
JOIN gov.MetricDependency md
  ON md.MetricDefinitionId = m.MetricDefinitionId
 AND md.DependencyTypeCode = 'DATA_ELEMENT'
JOIN gov.DataElement de
  ON de.DataElementId = md.DependencyEntityId
LEFT JOIN gov.DataElementBinding srcb
  ON srcb.DataElementId = de.DataElementId
 AND srcb.LayerCode = 'SRC'
LEFT JOIN gov.SourceSystem ss
  ON ss.SourceSystemId = srcb.SourceSystemId
LEFT JOIN gov.DataElementBinding dwb
  ON dwb.DataElementId = de.DataElementId
 AND dwb.LayerCode = 'DW';
GO

/* ------------------------------------------------------------
   Section 12. Load summary
   ------------------------------------------------------------ */
DECLARE @Elem INT = (SELECT COUNT(*) FROM gov.DataElement);
DECLARE @Cde  INT = (SELECT COUNT(*) FROM gov.CriticalDataElement);
DECLARE @BindSrc INT = (SELECT COUNT(*) FROM gov.DataElementBinding WHERE LayerCode = 'SRC');
DECLARE @BindDw INT = (SELECT COUNT(*) FROM gov.DataElementBinding WHERE LayerCode = 'DW');
DECLARE @Auth INT = (SELECT COUNT(*) FROM gov.AuthoritativeSource);
DECLARE @RiBound INT = (SELECT COUNT(*) FROM gov.DerivationRuleInput WHERE DataElementId IS NOT NULL);
DECLARE @RiTotal INT = (SELECT COUNT(*) FROM gov.DerivationRuleInput);
DECLARE @ElemRaci INT = (SELECT COUNT(*) FROM gov.RoleAssignment WHERE EntityTypeCode = 'DATA_ELEMENT');
DECLARE @MetElem INT = (SELECT COUNT(*) FROM gov.MetricDependency WHERE DependencyTypeCode = 'DATA_ELEMENT');
DECLARE @S2T INT = (SELECT COUNT(*) FROM gov.SourceToTargetMap WHERE TargetSchemaName = 'dw');

PRINT 'Script 017 complete:';
PRINT '  Elements: ' + CAST(@Elem AS VARCHAR(10))
    + ' (' + CAST(@Cde AS VARCHAR(10)) + ' CDEs)';
PRINT '  Bindings: ' + CAST(@BindSrc AS VARCHAR(10))
    + ' SRC, ' + CAST(@BindDw AS VARCHAR(10)) + ' DW';
PRINT '  Authoritative source rows: ' + CAST(@Auth AS VARCHAR(10));
PRINT '  Rule inputs bound: ' + CAST(@RiBound AS VARCHAR(10))
    + ' of ' + CAST(@RiTotal AS VARCHAR(10));
PRINT '  Element RACI rows: ' + CAST(@ElemRaci AS VARCHAR(10));
PRINT '  Metric-element deps: ' + CAST(@MetElem AS VARCHAR(10));
PRINT '  Source-to-target (dw) rows: ' + CAST(@S2T AS VARCHAR(10));
GO
