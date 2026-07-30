/* ============================================================
   MortgageGovernance | Phase 8 | Script 018
   MISMO mapping layer. Maps every governed data element to the
   MISMO Reference Model, records mapping type, and captures
   mapping provenance so the alignment claim is falsifiable.

   VERSION DECISION
   Recorded MISMO version: 3.6.3.
   Verified against mismo.org on 2026-07-23. v3.6.3 was
   released 2026-06-03 and is a backward-compatible, additive
   release; v3.6.2 (2025-10-29) and v3.6.1 (May 2025) are
   likewise additive and backward compatible, so mappings
   authored against v3.6.x naming remain valid. 003 set the
   column DEFAULT to '3.6.1' but made MismoVersion per row
   precisely so a later version could be adopted without
   rewriting history; this script writes '3.6.3' explicitly.

   PROVENANCE AND VERIFICATION POLICY
   The MISMO Logical Data Dictionary is a member-only
   resource and was NOT accessed. Data point names here are
   sourced from publicly published specifications that
   reproduce MISMO v3 LDD names (GSE ULDD Appendix A, UCD,
   and MISMO public product pages). Every row records its
   basis in MappingNotes with one of four prefixes:

     PUBLIC_SOURCE  Name corroborated by a public GSE or
                    MISMO specification.
     CANDIDATE      Name follows MISMO v3 naming convention
                    but is NOT independently verified;
                    confirm against the member LDD before
                    any certification claim.
     EXTENSION      No MISMO equivalent; modeled as a
                    proprietary extension in the FLAM
                    namespace.
     NOT_APPLICABLE Operational or control data with no
                    mortgage-business meaning in MISMO.

   MISMO Unique IDs and full XPaths were not verified, so
   MismoPathOrIdentifier carries container-level paths only
   where publicly documented and is NULL otherwise.

   This is a MISMO-ALIGNED and MISMO-MAPPED implementation.
   It is NOT validated for MISMO compliance and must not be
   described as compliant.

   Idempotent: owned rows delete and reload by version.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

DECLARE @LoadBatchId INT;
DECLARE @MismoVersion VARCHAR(20) = '3.6.3';
DECLARE @BatchNotes NVARCHAR(400) =
    N'Script 018: MISMO v3.6.3 element mappings with mapping '
  + N'type and provenance tagging.';

EXEC audit.usp_StartLoadBatch
     @BatchName     = N'Phase 8 MISMO mapping seed',
     @BatchTypeCode = 'SEED',
     @Notes         = @BatchNotes,
     @LoadBatchId   = @LoadBatchId OUTPUT;

BEGIN TRY
BEGIN TRAN;

DECLARE @Map TABLE
(
    Code      VARCHAR(60)    NOT NULL,
    DataPoint NVARCHAR(200)  NOT NULL,
    LddTerm   NVARCHAR(300)  NULL,
    MPath     NVARCHAR(500)  NULL,
    MapType   VARCHAR(30)    NOT NULL,
    Note      NVARCHAR(1000) NOT NULL,
    PRIMARY KEY (Code, DataPoint)
);

/* ------------------------------------------------------------
   1. Loan identity and terms. This block is the strongest
      publicly corroborated set: the GSE ULDD reproduces MISMO
      v3 LDD names and container paths verbatim.
   ------------------------------------------------------------ */
INSERT INTO @Map (Code, DataPoint, LddTerm, MPath, MapType, Note)
VALUES
('DE_LOAN_NUMBER','LoanIdentifier',
 N'The unique identifier assigned to the loan by the party '
 + N'identified in LoanIdentifierType.',
 N'DEAL/LOANS/LOAN/LOAN_IDENTIFIERS/LOAN_IDENTIFIER',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A. Requires the '
 + N'LoanIdentifierType qualifier (ServicerLoan) to '
 + N'disambiguate from investor and seller identifiers.'),
('DE_INVESTOR_LOAN_NUMBER','LoanIdentifier',
 N'Loan identifier assigned by the investor.',
 N'DEAL/LOANS/LOAN/LOAN_IDENTIFIERS/LOAN_IDENTIFIER',
 'TRANSFORMED',
 N'PUBLIC_SOURCE: same MISMO data point as the servicer '
 + N'number, distinguished by LoanIdentifierType = Investor. '
 + N'Internal model carries the two as separate columns.'),
('DE_ORIGINATION_DATE','NoteDate',
 N'The date of the note.',
 N'DEAL/LOANS/LOAN/TERMS_OF_LOAN',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A.'),
('DE_MATURITY_DATE','LoanMaturityDate',
 N'The date the final payment is contractually due.',
 N'DEAL/LOANS/LOAN/MATURITY/MATURITY_RULE',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A.'),
('DE_ORIGINAL_LOAN_AMOUNT','NoteAmount',
 N'The original principal amount stated on the note.',
 N'DEAL/LOANS/LOAN/TERMS_OF_LOAN',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A.'),
('DE_NOTE_RATE','NoteRatePercent',
 N'The interest rate stated on the note.',
 N'DEAL/LOANS/LOAN/TERMS_OF_LOAN',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A.'),
('DE_INTEREST_RATE_SNAP','NoteRatePercent',
 N'The interest rate in effect at the reporting period.',
 N'DEAL/LOANS/LOAN/TERMS_OF_LOAN',
 'TRANSFORMED',
 N'CANDIDATE: same MISMO data point evaluated at a '
 + N'point in time. MISMO carries current rate on the loan; '
 + N'the internal model snapshots it monthly.'),
('DE_INTEREST_RATE_TYPE','AmortizationType',
 N'The classification of the interest rate as fixed or '
 + N'adjustable.',
 N'DEAL/LOANS/LOAN/AMORTIZATION/AMORTIZATION_RULE',
 'TRANSFORMED',
 N'PUBLIC_SOURCE: ULDD Appendix A. Internal FIXED/ARM codes '
 + N'translate to the MISMO enumeration (Fixed, '
 + N'AdjustableRate).'),
('DE_AMORT_TERM_MONTHS','LoanAmortizationPeriodCount',
 N'The number of periods in the amortization term.',
 N'DEAL/LOANS/LOAN/AMORTIZATION/AMORTIZATION_RULE',
 'TRANSFORMED',
 N'PUBLIC_SOURCE: ULDD Appendix A. Requires the companion '
 + N'LoanAmortizationPeriodType = Month; the internal column '
 + N'is months-only by contract.'),
('DE_LIEN_POSITION','LienPriorityType',
 N'The priority of the lien against the subject property.',
 N'DEAL/LOANS/LOAN/TERMS_OF_LOAN',
 'TRANSFORMED',
 N'PUBLIC_SOURCE: ULDD Appendix A. Internal integer 1/2 '
 + N'translates to FirstLien / SecondLien.'),
('DE_LOAN_PROGRAM','MortgageType',
 N'The category of mortgage insurer or guarantor.',
 N'DEAL/LOANS/LOAN/TERMS_OF_LOAN',
 'TRANSFORMED',
 N'PUBLIC_SOURCE: ULDD Appendix A. CONV/FHA/VA/USDA map to '
 + N'Conventional, FHA, VA, USDARuralDevelopment. Internal '
 + N'JUMBO is not a MISMO MortgageType; it maps to '
 + N'Conventional and is distinguished by conforming test.'),
('DE_LOAN_PURPOSE','LoanPurposeType',
 N'The purpose for which the loan proceeds will be used.',
 N'DEAL/LOANS/LOAN/TERMS_OF_LOAN',
 'TRANSFORMED',
 N'PUBLIC_SOURCE: ULDD Appendix A. Internal purchase and '
 + N'refinance codes map to Purchase and Refinance.'),
('DE_HELOC_FLAG','HELOCIndicator',
 N'Indicates the loan is a home equity line of credit.',
 NULL,
 'TRANSFORMED',
 N'CANDIDATE: MISMO models HELOC through HELOC_RULES and '
 + N'LoanProductType rather than a single indicator; the '
 + N'exact data point requires LDD confirmation.'),
('DE_REVERSE_MORTGAGE_FLAG','ReverseMortgageIndicator',
 N'Indicates the loan is a reverse mortgage.',
 NULL,
 'TRANSFORMED',
 N'CANDIDATE: v3.6.1 expanded reverse mortgage support; '
 + N'the governing container and data point name require '
 + N'LDD confirmation.'),
('DE_ESCROWED_FLAG','EscrowIndicator',
 N'Indicates an escrow account is established for the loan.',
 N'DEAL/LOANS/LOAN/ESCROW',
 'EXACT_MATCH',
 N'CANDIDATE: name follows MISMO escrow container '
 + N'convention; not independently verified.'),
('DE_SERVICING_FEE_RATE','ServicingFeeRatePercent',
 N'The rate used to calculate the servicing fee.',
 NULL,
 'EXACT_MATCH',
 N'CANDIDATE: MISMO servicing fee data points exist under '
 + N'the servicing containers; exact name unverified.');

/* ------------------------------------------------------------
   2. Borrower, property, and collateral. Party and address
      containers are publicly documented in ULDD.
   ------------------------------------------------------------ */
INSERT INTO @Map (Code, DataPoint, LddTerm, MPath, MapType, Note)
VALUES
('DE_BORROWER_FIRST_NAME','FirstName',
 N'The given name of the individual.',
 N'DEAL/PARTIES/PARTY/INDIVIDUAL/NAME',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A. Borrower role is set on '
 + N'the PARTY ROLE container.'),
('DE_BORROWER_LAST_NAME','LastName',
 N'The surname of the individual.',
 N'DEAL/PARTIES/PARTY/INDIVIDUAL/NAME',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A.'),
('DE_PROPERTY_STREET','AddressLineText',
 N'The street address of the subject property.',
 N'DEAL/COLLATERALS/COLLATERAL/SUBJECT_PROPERTY/ADDRESS',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A.'),
('DE_PROPERTY_CITY','CityName',
 N'The city of the subject property address.',
 N'DEAL/COLLATERALS/COLLATERAL/SUBJECT_PROPERTY/ADDRESS',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A.'),
('DE_PROPERTY_STATE','StateCode',
 N'The two-character state code of the property address.',
 N'DEAL/COLLATERALS/COLLATERAL/SUBJECT_PROPERTY/ADDRESS',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A. Drives MCR state '
 + N'apportionment; see 019.'),
('DE_PROPERTY_POSTAL','PostalCode',
 N'The postal code of the property address.',
 N'DEAL/COLLATERALS/COLLATERAL/SUBJECT_PROPERTY/ADDRESS',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A.'),
('DE_OCCUPANCY_TYPE','PropertyUsageType',
 N'The manner in which the borrower occupies the property.',
 N'DEAL/COLLATERALS/COLLATERAL/SUBJECT_PROPERTY/PROPERTY_DETAIL',
 'TRANSFORMED',
 N'PUBLIC_SOURCE: ULDD Appendix A. Internal codes map to '
 + N'PrimaryResidence, SecondHome, Investment.'),
('DE_UNITS_COUNT','FinancedUnitCount',
 N'The number of units in the financed property.',
 N'DEAL/COLLATERALS/COLLATERAL/SUBJECT_PROPERTY/PROPERTY_DETAIL',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A.'),
('DE_PROPERTY_TYPE','ConstructionMethodType',
 N'The construction method of the subject property.',
 N'DEAL/COLLATERALS/COLLATERAL/SUBJECT_PROPERTY/PROPERTY_DETAIL',
 'TRANSFORMED',
 N'CANDIDATE: MISMO splits internal property type across '
 + N'ConstructionMethodType and AttachmentType; a single '
 + N'internal code maps to a pair. Confirm against the LDD '
 + N'before relying on the split.'),
('DE_FLOOD_ZONE_FLAG','SpecialFloodHazardAreaIndicator',
 N'Indicates the property is in a special flood hazard '
 + N'area.',
 NULL,
 'EXACT_MATCH',
 N'CANDIDATE: aligns to the MISMO flood determination '
 + N'concept; exact data point name unverified.'),
('DE_PROPERTY_VALUE','PropertyValuationAmount',
 N'The value of the property as established by the '
 + N'valuation method.',
 N'DEAL/COLLATERALS/COLLATERAL/SUBJECT_PROPERTY/PROPERTY_VALUATIONS/PROPERTY_VALUATION/PROPERTY_VALUATION_DETAIL',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A.'),
('DE_VALUATION_DATE','PropertyValuationEffectiveDate',
 N'The effective date of the property valuation.',
 N'DEAL/COLLATERALS/COLLATERAL/SUBJECT_PROPERTY/PROPERTY_VALUATIONS/PROPERTY_VALUATION/PROPERTY_VALUATION_DETAIL',
 'EXACT_MATCH',
 N'PUBLIC_SOURCE: ULDD Appendix A.'),
('DE_VALUATION_METHOD','PropertyValuationMethodType',
 N'The method used to derive the property value.',
 N'DEAL/COLLATERALS/COLLATERAL/SUBJECT_PROPERTY/PROPERTY_VALUATIONS/PROPERTY_VALUATION/PROPERTY_VALUATION_DETAIL',
 'TRANSFORMED',
 N'PUBLIC_SOURCE: ULDD Appendix A. Internal AVM/BPO/APPR '
 + N'codes map to the MISMO valuation method enumeration.'),
('DE_CURRENT_LTV','LTVRatioPercent',
 N'The ratio of the loan amount to the property value.',
 N'DEAL/LOANS/LOAN/LTV',
 'DERIVED',
 N'PUBLIC_SOURCE: ULDD Appendix A. Internal value is '
 + N'recomputed monthly as current UPB over latest '
 + N'valuation, so it is a derived point-in-time measure, '
 + N'not the delivered origination LTV.');

/* ------------------------------------------------------------
   3. Servicing snapshot and portfolio state. MISMO servicing
      datasets are not published to the same public depth as
      ULDD, so most of this block is CANDIDATE.
   ------------------------------------------------------------ */
INSERT INTO @Map (Code, DataPoint, LddTerm, MPath, MapType, Note)
VALUES
('DE_CURRENT_UPB','UPBAmount',
 N'The outstanding principal balance of the loan.',
 NULL,
 'EXACT_MATCH',
 N'CANDIDATE: MISMO carries unpaid principal balance in the '
 + N'servicing and delivery datasets; confirm whether the '
 + N'v3.6.3 name is UPBAmount or '
 + N'UnpaidPrincipalBalanceAmount before certification.'),
('DE_BEGINNING_UPB','UPBAmount',
 N'The outstanding principal balance at period start.',
 NULL,
 'TRANSFORMED',
 N'CANDIDATE: same MISMO concept evaluated at the start of '
 + N'the reporting period. MISMO has no separate '
 + N'beginning-balance point; the period qualifier is '
 + N'internal.'),
('DE_ASOF_DATE','ReportingPeriodEndDate',
 N'The end date of the reporting period.',
 NULL,
 'EXACT_MATCH',
 N'CANDIDATE: aligns to the MISMO investor reporting period '
 + N'concept; exact name unverified.'),
('DE_NEXT_PAYMENT_DUE_DATE','LoanPaymentDueDate',
 N'The date the next contractual payment is due.',
 NULL,
 'EXACT_MATCH',
 N'CANDIDATE: MISMO payment containers carry a due date; '
 + N'exact name unverified. This is a CDE and the anchor '
 + N'for all delinquency derivation.'),
('DE_DAYS_PAST_DUE','LoanDelinquencyDaysCount',
 N'The number of days the loan is contractually '
 + N'delinquent.',
 NULL,
 'DERIVED',
 N'CANDIDATE: derived internally from LoanPaymentDueDate '
 + N'and the evaluation date rather than sourced. See '
 + N'gov.DerivationRule DRV_DPD.'),
('DE_DELINQUENCY_BUCKET','LoanDelinquencyStatusType',
 N'The classification of the loan delinquency status.',
 NULL,
 'DERIVED',
 N'CANDIDATE: derived from days past due against '
 + N'ref.DelinquencyBucket. MISMO enumerations differ from '
 + N'the MCR FV7 buckets, so this is not a value-level '
 + N'match. See DRV_DQBUCKET.'),
('DE_SOURCE_BUCKET','FLAM:SourceReportedDelinquencyBucket',
 N'Delinquency bucket as asserted by the source system.',
 NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: no MISMO equivalent. Retained solely to test '
 + N'the source assertion against the governed derivation; '
 + N'a control field, not a business fact.'),
('DE_LOAN_STATUS','LoanStatusType',
 N'The current status of the loan.',
 NULL,
 'TRANSFORMED',
 N'CANDIDATE: internal servicing status codes are narrower '
 + N'than the MISMO status enumeration.'),
('DE_ESCROW_BALANCE','EscrowBalanceAmount',
 N'The balance of the escrow account.',
 NULL,
 'EXACT_MATCH',
 N'CANDIDATE: MISMO escrow containers carry a balance '
 + N'amount; exact name unverified.'),
('DE_SUSPENSE_BALANCE','SuspenseBalanceAmount',
 N'Funds received but not yet applied.',
 NULL,
 'EXACT_MATCH',
 N'CANDIDATE: aligns to the MISMO unapplied funds concept; '
 + N'exact name unverified.'),
('DE_SCHEDULED_PRINCIPAL','ScheduledPrincipalAmount',
 N'The scheduled principal reduction for the period.',
 NULL,
 'EXACT_MATCH',
 N'CANDIDATE: aligns to MISMO payment allocation; exact '
 + N'name unverified.'),
('DE_VOLUNTARY_PREPAID_PRINCIPAL','CurtailmentAmount',
 N'Unscheduled principal applied to reduce the balance.',
 NULL,
 'EXACT_MATCH',
 N'CANDIDATE: MISMO models unscheduled principal as a '
 + N'curtailment; exact name unverified. SMM numerator.'),
('DE_SERVICING_TYPE','FLAM:ServicingArrangementType',
 N'Servicing arrangement classification per '
 + N'ref.ServicingType.',
 NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: the internal taxonomy is built to MCR FV7 '
 + N'servicing-type lines (LS010-LS040), not to a MISMO '
 + N'enumeration. Mapped to the regulatory model in 019 '
 + N'rather than forced onto a MISMO point.'),
('DE_INVESTOR_CODE','InvestorName',
 N'The name of the investor holding the loan.',
 NULL,
 'TRANSFORMED',
 N'CANDIDATE: internal short codes (FNMA, FHLMC, GNMA) '
 + N'translate to MISMO investor identification. Confirm '
 + N'whether v3.6.3 prefers a coded identifier.'),
('DE_POOL_NUMBER','PoolIdentifier',
 N'The identifier of the security pool.',
 NULL,
 'EXACT_MATCH',
 N'CANDIDATE: aligns to MISMO pool identification; exact '
 + N'name unverified.'),
('DE_REMITTANCE_TYPE','InvestorRemittanceType',
 N'The remittance schedule type for the investor.',
 NULL,
 'TRANSFORMED',
 N'PUBLIC_SOURCE: ULDD Appendix A carries an investor '
 + N'remittance type; internal codes map to that '
 + N'enumeration.'),
('DE_MSR_OWNER_NMLS','FLAM:MsrOwnerNmlsIdentifier',
 N'NMLS identifier of the servicing rights owner.',
 NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: NMLS identifiers are an NMLS construct. '
 + N'Required by MCR FV7 S520A; mapped in 019.'),
('DE_BOARDED_DATE','ServicingTransferEffectiveDate',
 N'The effective date servicing transferred.',
 NULL,
 'TRANSFORMED',
 N'CANDIDATE: internal board date is the date the loan '
 + N'landed on the servicing system, which may differ from '
 + N'the contractual transfer effective date.'),
('DE_RUNOFF_REASON','FLAM:RunoffReasonType',
 N'Reason the loan left the active portfolio.',
 NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: internal portfolio-exit taxonomy per '
 + N'ref.RunoffReason. MISMO models payoff and liquidation '
 + N'events separately rather than as one reason code.'),
('DE_CONFORMING_FLAG','FLAM:ConformingIndicator',
 N'Indicates the loan is within the conforming limit.',
 NULL,
 'DERIVED',
 N'EXTENSION: derived from NoteAmount against '
 + N'ref.ConformingLoanLimit by unit count, year, and '
 + N'high-cost area. See DRV_CONFORMING.'),
('DE_MCR_LOAN_TYPE','FLAM:McrLoanTypeCode',
 N'MCR loan type classification for FV7 line mapping.',
 NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: an NMLS Mortgage Call Report classification, '
 + N'not a MISMO concept. Regulatory mapping lives in 019.');

/* ------------------------------------------------------------
   4. Payments, escrow administration, and insurance.
   ------------------------------------------------------------ */
INSERT INTO @Map (Code, DataPoint, LddTerm, MPath, MapType, Note)
VALUES
('DE_PAY_RECEIVED_DATE','PaymentReceivedDate',
 N'The date the payment was received.', NULL, 'EXACT_MATCH',
 N'CANDIDATE: MISMO payment containers carry receipt and '
 + N'posting dates; exact names unverified.'),
('DE_PAY_POSTED_DATE','PaymentPostedDate',
 N'The date the payment was posted.', NULL, 'EXACT_MATCH',
 N'CANDIDATE: exact name unverified. CDE for posting '
 + N'timeliness.'),
('DE_PAY_EFFECTIVE_DATE','PaymentEffectiveDate',
 N'The effective date of the payment application.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_PAY_AMOUNT','PaymentAmount',
 N'The total amount of the payment transaction.', NULL,
 'EXACT_MATCH',
 N'CANDIDATE: PaymentAmount is a common MISMO point but '
 + N'appears in several containers; confirm the servicing '
 + N'transaction context.'),
('DE_PAY_PRINCIPAL','PaymentPrincipalAmount',
 N'The principal portion of the payment.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_PAY_INTEREST','PaymentInterestAmount',
 N'The interest portion of the payment.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_PAY_ESCROW','PaymentEscrowAmount',
 N'The escrow portion of the payment.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_PAY_REVERSAL_FLAG','FLAM:PaymentReversalIndicator',
 N'Indicates the payment transaction was reversed.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: MISMO models a reversal as a transaction '
 + N'type rather than a flag on the original row.'),
('DE_PAY_ORIGINAL_TXN','FLAM:OriginalTransactionIdentifier',
 N'Link from a reversal to the original posting.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: internal reversal-chain key supporting '
 + N'payment accuracy measurement.'),
('DE_PAY_SUSPENSE_FLAG','FLAM:SuspensePostingIndicator',
 N'Indicates funds posted to suspense.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: internal cash-handling control flag.'),
('DE_DISB_TYPE','EscrowDisbursementType',
 N'The type of escrow disbursement.', NULL, 'TRANSFORMED',
 N'CANDIDATE: internal tax and insurance codes map to the '
 + N'MISMO escrow disbursement enumeration.'),
('DE_DISB_DATE','EscrowDisbursementDate',
 N'The date the escrow disbursement was made.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_DISB_AMOUNT','EscrowDisbursementAmount',
 N'The amount of the escrow disbursement.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_TAX_DUE_DATE','PropertyTaxDueDate',
 N'The date property taxes are due.', NULL, 'EXACT_MATCH',
 N'CANDIDATE: exact name unverified. CDE anchoring tax '
 + N'disbursement timeliness.'),
('DE_DISB_AMOUNT_MATCH','FLAM:DisbursementAmountMatchIndicator',
 N'Indicates the disbursed amount matched the obligation.',
 NULL, 'INTERNAL_EXTENSION',
 N'EXTENSION: internal escrow control outcome, not a '
 + N'business fact carried in MISMO.'),
('DE_DISB_PAYEE_MATCH','FLAM:DisbursementPayeeMatchIndicator',
 N'Indicates the payee matched the obligation.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: internal control flag.'),
('DE_DISB_LOAN_MATCH','FLAM:DisbursementLoanMatchIndicator',
 N'Indicates the disbursement matched the correct loan.',
 NULL, 'INTERNAL_EXTENSION',
 N'EXTENSION: internal control flag.'),
('DE_ESC_ANALYSIS_DUE','EscrowAnalysisDueDate',
 N'The date the escrow analysis is due.', NULL,
 'EXACT_MATCH',
 N'CANDIDATE: RESPA Regulation X drives the cycle; exact '
 + N'MISMO name unverified.'),
('DE_ESC_ANALYSIS_COMPLETED','EscrowAnalysisCompletedDate',
 N'The date the escrow analysis was completed.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_ESC_SHORTAGE_AMOUNT','EscrowShortageAmount',
 N'The escrow shortage identified at analysis.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_INS_POLICY_TYPE','HazardInsurancePolicyType',
 N'The type of insurance coverage on the property.', NULL,
 'TRANSFORMED',
 N'CANDIDATE: internal HAZ/FLOOD/LPI codes span hazard, '
 + N'flood, and lender-placed concepts that MISMO models in '
 + N'separate containers.'),
('DE_INS_EFFECTIVE_DATE','InsurancePolicyEffectiveDate',
 N'The start of the insurance coverage span.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_INS_EXPIRATION_DATE','InsurancePolicyExpirationDate',
 N'The end of the insurance coverage span.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_INS_ANNUAL_PREMIUM','InsurancePolicyPremiumAmount',
 N'The annual premium billed for the policy.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.');

/* ------------------------------------------------------------
   5. Default management. MISMO added federal government
      housing agency servicing content in v3.6.3; that dataset
      is member-gated, so this block stays CANDIDATE and is
      the first place to revisit once LDD access exists.
   ------------------------------------------------------------ */
INSERT INTO @Map (Code, DataPoint, LddTerm, MPath, MapType, Note)
VALUES
('DE_LM_APP_RECEIVED','LossMitigationApplicationReceivedDate',
 N'The date a loss mitigation application was received.',
 NULL, 'EXACT_MATCH',
 N'CANDIDATE: Regulation X drives the concept; MISMO loss '
 + N'mitigation containers exist but names are unverified.'),
('DE_LM_COMPLETE_PACKAGE','CompleteApplicationReceivedDate',
 N'The date a complete loss mitigation package was '
 + N'received.', NULL, 'EXACT_MATCH',
 N'CANDIDATE: CDE anchoring the Regulation X evaluation '
 + N'clock; exact name unverified.'),
('DE_LM_DECISION_DATE','LossMitigationDecisionDate',
 N'The date the workout decision was issued.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_LM_DECISION_CODE','LossMitigationDecisionType',
 N'The workout decision classification.', NULL,
 'TRANSFORMED',
 N'CANDIDATE: internal decision codes are narrower than the '
 + N'MISMO enumeration.'),
('DE_LM_WORKOUT_TYPE','LossMitigationType',
 N'The type of workout offered or completed.', NULL,
 'TRANSFORMED',
 N'CANDIDATE: internal ref.WorkoutType maps to the MISMO '
 + N'loss mitigation type enumeration.'),
('DE_MOD_EFFECTIVE_DATE','ModificationEffectiveDate',
 N'The effective date of the loan modification.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_MOD_BOOKED_DATE','FLAM:ModificationBookedDate',
 N'The date the permanent modification was booked.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: booking is an internal servicing-system '
 + N'event distinct from the contractual effective date.'),
('DE_FC_FIRST_LEGAL_ELIGIBLE','FirstLegalActionEligibleDate',
 N'The date the loan became eligible for first legal '
 + N'action.', NULL, 'EXACT_MATCH',
 N'CANDIDATE: an investor and Regulation X timeline '
 + N'concept; exact MISMO name unverified. CDE.'),
('DE_FC_REFERRAL_DATE','ForeclosureReferralDate',
 N'The date the loan was referred to foreclosure.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_FC_SALE_HELD_DATE','ForeclosureSaleDate',
 N'The date the foreclosure sale was held.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_FC_CASE_STATUS','ForeclosureStatusType',
 N'The status of the foreclosure case.', NULL,
 'TRANSFORMED',
 N'CANDIDATE: internal OPEN/CLOSED is coarser than the '
 + N'MISMO foreclosure status enumeration.'),
('DE_FC_RESOLUTION_TYPE','ForeclosureResolutionType',
 N'How the foreclosure case resolved.', NULL, 'TRANSFORMED',
 N'CANDIDATE: exact name and enumeration unverified.'),
('DE_BK_CHAPTER','BankruptcyChapterType',
 N'The bankruptcy chapter under which the case was filed.',
 NULL, 'TRANSFORMED',
 N'CANDIDATE: internal 7/13 codes map to the MISMO chapter '
 + N'enumeration.'),
('DE_BK_PETITION_DATE','BankruptcyPetitionDate',
 N'The date the bankruptcy petition was filed.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_BK_POC_BAR_DATE','ProofOfClaimBarDate',
 N'The court bar date for filing the proof of claim.',
 NULL, 'EXACT_MATCH',
 N'CANDIDATE: exact name unverified. CDE.'),
('DE_BK_POC_FILED_DATE','ProofOfClaimFiledDate',
 N'The date the proof of claim was filed.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_FORBEARANCE_FLAG','FLAM:ForbearanceActiveIndicator',
 N'Indicates an active forbearance plan at the snapshot.',
 NULL, 'INTERNAL_EXTENSION',
 N'EXTENSION: a point-in-time snapshot flag derived from '
 + N'plan dates; MISMO carries the plan, not the flag.'),
('DE_FORB_START_DATE','ForbearancePlanStartDate',
 N'The start date of the forbearance plan.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_FORB_END_DATE','ForbearancePlanEndDate',
 N'The end date of the forbearance plan.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_FORB_STATUS','ForbearancePlanStatusType',
 N'The status of the forbearance plan.', NULL,
 'TRANSFORMED', N'CANDIDATE: exact enumeration unverified.');

/* ------------------------------------------------------------
   6. Boarding and transfers. Tape fields carry the prior
      servicer assertion of the same MISMO concepts; the
      mapping type records that they are transfer-context
      copies, not the servicing system of record.
   ------------------------------------------------------------ */
INSERT INTO @Map (Code, DataPoint, LddTerm, MPath, MapType, Note)
VALUES
('DE_TRANSFER_EFFECTIVE_DATE','ServicingTransferEffectiveDate',
 N'The effective date servicing transferred to the new '
 + N'servicer.', NULL, 'EXACT_MATCH',
 N'CANDIDATE: MISMO servicing transfer containers carry '
 + N'this concept; exact name unverified.'),
('DE_BOARDING_COMPLETED_DATE','FLAM:BoardingCompletedDate',
 N'The date boarding completed on the servicing system.',
 NULL, 'INTERNAL_EXTENSION',
 N'EXTENSION: an internal operational milestone measured '
 + N'against the boarding SLA, not a transfer contract '
 + N'term.'),
('DE_TRANSFER_TYPE','FLAM:TransferType',
 N'Bulk or flow boarding classification.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: internal acquisition taxonomy.'),
('DE_TAPE_UPB','UPBAmount',
 N'UPB asserted by the prior servicer on the transfer '
 + N'tape.', NULL, 'TRANSFORMED',
 N'CANDIDATE: same MISMO concept as current UPB, carried '
 + N'in the transfer context. Retained separately as the '
 + N'boarding accuracy baseline.'),
('DE_TAPE_RATE','NoteRatePercent',
 N'Note rate asserted on the transfer tape.', NULL,
 'TRANSFORMED',
 N'PUBLIC_SOURCE: same data point as the core note rate, '
 + N'in transfer context.'),
('DE_TAPE_NEXT_DUE','LoanPaymentDueDate',
 N'Next payment due date asserted on the transfer tape.',
 NULL, 'TRANSFORMED',
 N'CANDIDATE: same concept as the core next due date, in '
 + N'transfer context.'),
('DE_TAPE_ESCROW_BALANCE','EscrowBalanceAmount',
 N'Escrow balance asserted on the transfer tape.', NULL,
 'TRANSFORMED',
 N'CANDIDATE: same concept as the core escrow balance, in '
 + N'transfer context.'),
('DE_TAPE_INVESTOR','InvestorName',
 N'Investor asserted on the transfer tape.', NULL,
 'TRANSFORMED',
 N'CANDIDATE: same concept as the core investor, in '
 + N'transfer context. Target of defect DEF12.');

/* ------------------------------------------------------------
   7. Investor reporting and repurchase.
   ------------------------------------------------------------ */
INSERT INTO @Map (Code, DataPoint, LddTerm, MPath, MapType, Note)
VALUES
('DE_INV_REPORTING_DEADLINE','FLAM:ReportingDeadlineDate',
 N'The investor loan-level reporting deadline.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: a servicer operational deadline derived from '
 + N'the investor contract, not a MISMO data point. CDE.'),
('DE_INV_REPORT_SUBMITTED','FLAM:ReportSubmittedDate',
 N'The date investor reporting was submitted.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: operational event.'),
('DE_INV_ACCEPTED_FLAG','FLAM:ReportAcceptedIndicator',
 N'Indicates the investor accepted the submission.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: operational outcome.'),
('DE_INV_ERROR_COUNT','FLAM:ReportErrorCount',
 N'Count of loan-level reporting errors.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: operational quality '
 + N'measure.'),
('DE_INV_CORRECTION_FLAG','FLAM:CorrectionResubmissionIndicator',
 N'Indicates a correction resubmission.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: operational rework signal, defect DEF13.'),
('DE_REMIT_DUE_DATE','InvestorRemittanceDueDate',
 N'The date the investor remittance is due.', NULL,
 'EXACT_MATCH',
 N'CANDIDATE: MISMO carries remittance terms; exact name '
 + N'unverified. CDE.'),
('DE_REMIT_SENT_DATE','FLAM:RemittanceSentDate',
 N'The date the remittance was sent.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: operational execution date.'),
('DE_REMIT_AMOUNT','InvestorRemittanceAmount',
 N'The amount remitted to the investor.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_REPO_DEMAND_RECEIVED','RepurchaseDemandDate',
 N'The date a repurchase demand was received.', NULL,
 'EXACT_MATCH',
 N'CANDIDATE: MISMO models repurchase in the quality and '
 + N'delivery datasets; exact name unverified.'),
('DE_REPO_RESOLUTION_DATE','RepurchaseResolutionDate',
 N'The date the repurchase demand was resolved.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_REPO_DEMAND_AMOUNT','RepurchaseDemandAmount',
 N'The amount demanded in the repurchase request.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.');

/* ------------------------------------------------------------
   8. Production: leads, applications, locks. MISMO covers
      application through ULAD and URLA; lead management and
      lock administration are largely outside the model.
   ------------------------------------------------------------ */
INSERT INTO @Map (Code, DataPoint, LddTerm, MPath, MapType, Note)
VALUES
('DE_LEAD_CREATED_DATE','FLAM:LeadCreatedDate',
 N'The date a CRM lead was created.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: MISMO begins at application. Pre-application '
 + N'lead management has no MISMO representation.'),
('DE_LEAD_SOURCE','FLAM:LeadSourceType',
 N'The attribution source of the lead.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: marketing attribution.'),
('DE_LEAD_CONTACT_KEY','FLAM:LeadContactKey',
 N'Contact identifier used for lead de-duplication.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: internal de-duplication key, defect DEF15.'),
('DE_LEAD_STATUS','FLAM:LeadStatusType',
 N'The lifecycle status of the lead.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: CRM lifecycle.'),
('DE_LEAD_CONVERTED_APP','FLAM:ConvertedApplicationIdentifier',
 N'Link from a lead to the resulting application.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: CRM-to-LOS conversion linkage.'),
('DE_APP_RECEIVED_DATE','ApplicationReceivedDate',
 N'The date the application was received by the lender.',
 NULL, 'EXACT_MATCH',
 N'CANDIDATE: the concept is defined consistently across '
 + N'MISMO, Regulation B, and the MCR glossary; exact v3.6.3 '
 + N'name unverified. CDE and the AC020 basis.'),
('DE_APP_STARTED_DATE','FLAM:ApplicationStartedDate',
 N'The date the application was started.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: an LOS workflow timestamp preceding the '
 + N'regulatory application date.'),
('DE_APP_COMPLETED_DATE','FLAM:ApplicationCompletedDate',
 N'The date the application became complete.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: LOS workflow state.'),
('DE_APP_DISPOSITION','FLAM:ApplicationDispositionType',
 N'The terminal disposition of the application.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: internal taxonomy built to MCR FV7 lines '
 + N'AC030-AC080. HMDA action taken is a related but '
 + N'distinct enumeration; both map in 019.'),
('DE_APP_DISPOSITION_DATE','FLAM:ApplicationDispositionDate',
 N'The date the terminal disposition was recorded.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: LOS workflow event.'),
('DE_APP_LOAN_AMOUNT','LoanAmount',
 N'The loan amount requested on the application.', NULL,
 'TRANSFORMED',
 N'CANDIDATE: at application this precedes NoteAmount; '
 + N'confirm whether v3.6.3 distinguishes requested from '
 + N'note amount.'),
('DE_APP_FUNDING_DATE','LoanFundingDate',
 N'The date loan proceeds were disbursed.', NULL,
 'EXACT_MATCH', N'CANDIDATE: exact name unverified.'),
('DE_APP_SCHEDULED_CLOSING','FLAM:ScheduledClosingDate',
 N'The scheduled closing date.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: a pipeline management date, not a delivered '
 + N'term.'),
('DE_APP_ACTUAL_CLOSING','ClosingDate',
 N'The date the loan closed.', NULL, 'EXACT_MATCH',
 N'CANDIDATE: UCD carries a closing date; exact v3.6.3 '
 + N'name unverified.'),
('DE_APP_FUNDED_FLAG','FLAM:FundedIndicator',
 N'Indicates the application funded.', NULL,
 'DERIVED',
 N'EXTENSION: derived from funding date and disposition '
 + N'rather than sourced. See DRV_ACTIVEPOP.'),
('DE_APP_CHANNEL','FLAM:ProductionChannelType',
 N'The production channel of the application.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: internal retail, wholesale, and '
 + N'correspondent taxonomy aligned to MCR FV7 rather than '
 + N'to a MISMO enumeration.'),
('DE_APP_SERVICING_INTENT','FLAM:ServicingDispositionIntentType',
 N'Retained or released servicing intent.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: supports the MCR AC1200 family; mapped in '
 + N'019.'),
('DE_APP_LO_NMLS','LoanOriginatorIdentifier',
 N'The NMLS identifier of the loan originator.', NULL,
 'TRANSFORMED',
 N'CANDIDATE: MISMO carries originator identification on '
 + N'the PARTY role; the NMLS qualifier is required. CDE '
 + N'and the ACMLO1 basis.'),
('DE_LOCK_DATE','FLAM:RateLockDate',
 N'The date the rate lock was executed.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: MISMO carries lock terms in pricing '
 + N'contexts; the internal lock event model is secondary '
 + N'marketing specific.'),
('DE_LOCK_AMOUNT','FLAM:LockAmount',
 N'The locked loan amount.', NULL, 'INTERNAL_EXTENSION',
 N'EXTENSION: pull-through denominator basis.'),
('DE_LOCK_CURRENT_EXPIRATION','FLAM:LockCurrentExpirationDate',
 N'The current expiration date of the lock.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: defect DEF18 target.'),
('DE_LOCK_ORIGINAL_EXPIRATION','FLAM:LockOriginalExpirationDate',
 N'The original expiration date of the lock.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: extension measurement '
 + N'baseline.'),
('DE_LOCK_STATUS','FLAM:LockStatusType',
 N'The terminal status of the lock.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: secondary marketing '
 + N'lifecycle.'),
('DE_LOCK_EXTENSION_COUNT','FLAM:LockExtensionCount',
 N'The number of extensions applied to the lock.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: operational measure.'),
('DE_LOCK_PRIOR_LOCK','FLAM:PriorLockIdentifier',
 N'Relock chain link to a prior lock.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: relock chain key.'),
('DE_LOCK_APPLICATION_LINK','FLAM:LockApplicationIdentifier',
 N'Application linkage for lock pull-through.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: internal join key.');

/* ------------------------------------------------------------
   9. Workforce and licensing. NMLS licensing is an SRR and
      state regulator construct, not a MISMO one. Recorded
      as NOT_APPLICABLE where there is no mortgage-data
      meaning in MISMO at all.
   ------------------------------------------------------------ */
INSERT INTO @Map (Code, DataPoint, LddTerm, MPath, MapType, Note)
VALUES
('DE_LO_NMLS_ID','LoanOriginatorIdentifier',
 N'The NMLS identifier of the loan originator.', NULL,
 'TRANSFORMED',
 N'CANDIDATE: MISMO identifies the originator party; the '
 + N'NMLS identifier type qualifier is required.'),
('DE_LO_FIRST_NAME','FirstName',
 N'The given name of the loan originator.',
 N'DEAL/PARTIES/PARTY/INDIVIDUAL/NAME', 'EXACT_MATCH',
 N'PUBLIC_SOURCE: same NAME container as the borrower, '
 + N'distinguished by PARTY role.'),
('DE_LO_LAST_NAME','LastName',
 N'The surname of the loan originator.',
 N'DEAL/PARTIES/PARTY/INDIVIDUAL/NAME', 'EXACT_MATCH',
 N'PUBLIC_SOURCE: distinguished by PARTY role.'),
('DE_LO_BRANCH','FLAM:BranchCode',
 N'The branch assignment of the loan originator.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: internal org structure.'),
('DE_LO_REGION','FLAM:Region',
 N'The region assignment of the loan originator.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: internal org structure.'),
('DE_LO_EMPLOYMENT_STATUS','FLAM:EmploymentStatusType',
 N'The employment status of the loan originator.', NULL,
 'NOT_APPLICABLE',
 N'NOT_APPLICABLE: employment administration is HR data '
 + N'with no mortgage-transaction meaning in MISMO.'),
('DE_LIC_STATE','FLAM:LicenseStateCode',
 N'The state of the originator license.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: NMLS licensing construct; regulatory mapping '
 + N'in 019.'),
('DE_LIC_STATUS','FLAM:LicenseStatusType',
 N'The status of the originator license.', NULL,
 'INTERNAL_EXTENSION',
 N'EXTENSION: NMLS licensing construct. CDE gating MLO '
 + N'compliance; defect DEF19 target.'),
('DE_LIC_EXPIRATION','FLAM:LicenseExpirationDate',
 N'The expiration date of the license.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: NMLS licensing.'),
('DE_LIC_RENEWAL_DEADLINE','FLAM:LicenseRenewalDeadline',
 N'The renewal deadline of the license.', NULL,
 'INTERNAL_EXTENSION', N'EXTENSION: NMLS licensing.'),
('DE_CE_REQUIRED_HOURS','FLAM:CeRequiredHours',
 N'Continuing education hours required.', NULL,
 'NOT_APPLICABLE',
 N'NOT_APPLICABLE: SAFE Act continuing education '
 + N'administration, outside the MISMO transaction model.'),
('DE_CE_COMPLETED_HOURS','FLAM:CeCompletedHours',
 N'Continuing education hours completed.', NULL,
 'NOT_APPLICABLE', N'NOT_APPLICABLE: see CE required '
 + N'hours.'),
('DE_CE_COMPLETED_DATE','FLAM:CeCompletedDate',
 N'The date continuing education was completed.', NULL,
 'NOT_APPLICABLE', N'NOT_APPLICABLE: see CE required '
 + N'hours.');

/* ------------------------------------------------------------
   10. Load. Physical column reference and source system come
       from the SRC binding established in 017, so the mapping
       row carries the full chain: MISMO data point to internal
       element to physical source column to owning system.
       018 owns gov.MismoMapping outright; reload it.
   ------------------------------------------------------------ */
DELETE FROM gov.MismoMapping;

INSERT INTO gov.MismoMapping
    (DataElementId, PhysicalColumnReference, SourceSystemId,
     MismoDataPointName, MismoLddTerm, MismoPathOrIdentifier,
     MismoVersion, MappingTypeCode, MappingNotes, LoadBatchId)
SELECT de.DataElementId,
       b.SchemaName + N'.' + b.ObjectName + N'.'
         + b.ColumnName,
       b.SourceSystemId,
       m.DataPoint, m.LddTerm, m.MPath,
       @MismoVersion, m.MapType, m.Note, @LoadBatchId
FROM @Map m
JOIN gov.DataElement de ON de.DataElementCode = m.Code
OUTER APPLY (
    SELECT TOP 1 x.SchemaName, x.ObjectName, x.ColumnName,
           x.SourceSystemId
    FROM gov.DataElementBinding x
    WHERE x.DataElementId = de.DataElementId
      AND x.LayerCode = 'SRC'
    ORDER BY x.DataElementBindingId
) b;

/* ------------------------------------------------------------
   11. Change log
   ------------------------------------------------------------ */
IF NOT EXISTS
   (SELECT 1 FROM gov.ChangeLog
    WHERE EntityTypeCode = 'GOVERNANCE_PLATFORM'
      AND EntityReference = N'gov.MismoMapping')
BEGIN
INSERT INTO gov.ChangeLog
    (EntityTypeCode, EntityReference, ChangeTypeCode,
     ChangeDescription, LoadBatchId)
VALUES
    ('GOVERNANCE_PLATFORM', N'gov.MismoMapping', 'INSERT',
     N'Phase 8 MISMO mapping: every governed data element '
     + N'mapped to MISMO Reference Model v3.6.3 with mapping '
     + N'type and provenance tagging. Version verified at '
     + N'mismo.org on 2026-07-23; v3.6.3 released 2026-06-03 '
     + N'and is backward compatible with v3.6.1 and v3.6.2. '
     + N'The member-only Logical Data Dictionary was not '
     + N'accessed, so 73 of 153 mappings are recorded as '
     + N'CANDIDATE pending LDD confirmation. This is a '
     + N'MISMO-aligned mapping, not a validated compliance '
     + N'claim.',
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
         @ContextInfo = N'018_gov_mismo_mappings.sql';
    EXEC audit.usp_CompleteLoadBatch
         @LoadBatchId = @LoadBatchId,
         @StatusCode  = 'FAILED';
    THROW;
END CATCH
GO

/* ============================================================
   Section 12. Generation views.
   ============================================================ */

/* ---- 12a. gov.vw_MismoMapping: the mapping artifact. The
        provenance prefix is parsed out of MappingNotes so
        verification status is a filterable column rather
        than buried in prose. ---- */
CREATE OR ALTER VIEW gov.vw_MismoMapping
AS
SELECT
    de.DataElementCode,
    de.DataElementName,
    de.BusinessDefinition   AS InternalDefinition,
    de.DomainArea,
    de.CdeFlag,
    mm.PhysicalColumnReference,
    ss.SourceSystemCode,
    mm.MismoDataPointName,
    mm.MismoLddTerm,
    mm.MismoPathOrIdentifier,
    mm.MismoVersion,
    mm.MappingTypeCode,
    LEFT(mm.MappingNotes,
         CHARINDEX(':', mm.MappingNotes + ':') - 1)
                            AS ProvenanceCode,
    CASE WHEN LEFT(mm.MappingNotes, 13) = 'PUBLIC_SOURCE'
         THEN 1 ELSE 0 END  AS PubliclyCorroboratedFlag,
    mm.MappingNotes
FROM gov.MismoMapping mm
JOIN gov.DataElement de
  ON de.DataElementId = mm.DataElementId
LEFT JOIN gov.SourceSystem ss
  ON ss.SourceSystemId = mm.SourceSystemId;
GO

/* ---- 12b. gov.vw_MismoCoverage: coverage by domain. Feeds
        the MISMO coverage tile on the Power BI project
        governance page. Deliberately reports the CANDIDATE
        share so the dashboard cannot overstate alignment. ---- */
CREATE OR ALTER VIEW gov.vw_MismoCoverage
AS
SELECT
    v.DomainArea,
    COUNT(*)                       AS ElementCount,
    SUM(CASE WHEN v.MappingTypeCode
             IN ('EXACT_MATCH','TRANSFORMED','DERIVED')
             THEN 1 ELSE 0 END)    AS MismoMappedCount,
    SUM(CASE WHEN v.MappingTypeCode = 'INTERNAL_EXTENSION'
             THEN 1 ELSE 0 END)    AS InternalExtensionCount,
    SUM(CASE WHEN v.MappingTypeCode = 'NOT_APPLICABLE'
             THEN 1 ELSE 0 END)    AS NotApplicableCount,
    SUM(v.PubliclyCorroboratedFlag) AS PublicSourceCount,
    SUM(CASE WHEN v.ProvenanceCode = 'CANDIDATE'
             THEN 1 ELSE 0 END)    AS CandidateCount,
    SUM(CASE WHEN v.CdeFlag = 1 AND v.MappingTypeCode
             IN ('EXACT_MATCH','TRANSFORMED','DERIVED')
             THEN 1 ELSE 0 END)    AS MappedCdeCount,
    SUM(CASE WHEN v.CdeFlag = 1 THEN 1 ELSE 0 END)
                                   AS CdeCount
FROM gov.vw_MismoMapping v
GROUP BY v.DomainArea;
GO

/* ------------------------------------------------------------
   Section 13. Load summary
   ------------------------------------------------------------ */
DECLARE @Total INT = (SELECT COUNT(*) FROM gov.MismoMapping);
DECLARE @Exact INT = (SELECT COUNT(*) FROM gov.MismoMapping
                      WHERE MappingTypeCode = 'EXACT_MATCH');
DECLARE @Trans INT = (SELECT COUNT(*) FROM gov.MismoMapping
                      WHERE MappingTypeCode = 'TRANSFORMED');
DECLARE @Deriv INT = (SELECT COUNT(*) FROM gov.MismoMapping
                      WHERE MappingTypeCode = 'DERIVED');
DECLARE @Ext INT = (SELECT COUNT(*) FROM gov.MismoMapping
                    WHERE MappingTypeCode = 'INTERNAL_EXTENSION');
DECLARE @Na INT = (SELECT COUNT(*) FROM gov.MismoMapping
                   WHERE MappingTypeCode = 'NOT_APPLICABLE');
DECLARE @Pub INT = (SELECT COUNT(*) FROM gov.vw_MismoMapping
                    WHERE PubliclyCorroboratedFlag = 1);
DECLARE @Cand INT = (SELECT COUNT(*) FROM gov.vw_MismoMapping
                     WHERE ProvenanceCode = 'CANDIDATE');
DECLARE @NoPhys INT = (SELECT COUNT(*) FROM gov.MismoMapping
                       WHERE PhysicalColumnReference IS NULL);

PRINT 'Script 018 complete (MISMO v3.6.3):';
PRINT '  Mappings: ' + CAST(@Total AS VARCHAR(10));
PRINT '    EXACT_MATCH: ' + CAST(@Exact AS VARCHAR(10));
PRINT '    TRANSFORMED: ' + CAST(@Trans AS VARCHAR(10));
PRINT '    DERIVED: ' + CAST(@Deriv AS VARCHAR(10));
PRINT '    INTERNAL_EXTENSION: ' + CAST(@Ext AS VARCHAR(10));
PRINT '    NOT_APPLICABLE: ' + CAST(@Na AS VARCHAR(10));
PRINT '  Publicly corroborated: ' + CAST(@Pub AS VARCHAR(10));
PRINT '  CANDIDATE (needs LDD confirmation): '
    + CAST(@Cand AS VARCHAR(10));
PRINT '  Mappings with no SRC physical binding: '
    + CAST(@NoPhys AS VARCHAR(10))
    + ' (expected 5: derived-only elements)';
GO
