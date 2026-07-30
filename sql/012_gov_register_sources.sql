/* ============================================================
   MortgageGovernance | Phase 4 | Script 012
   Source registration: every src table into gov.SourceObject
   with a mandatory grain statement, governed key fields into
   gov.SourceField, and the attribute-level authoritative
   source register (including the BRD-to-SVC boarding
   handoff). Data elements referenced here are created in
   Phase 7; AuthoritativeSource rows are seeded there against
   elements. This script covers objects and fields.
   Idempotent: deletes and reloads registered rows.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

DECLARE @LoadBatchId INT;
DECLARE @BatchNotes NVARCHAR(400) =
    N'Script 012: SourceObject grains + SourceField '
  + N'registry for all 10 systems.';

EXEC audit.usp_StartLoadBatch
     @BatchName = N'Phase 4 source registration seed',
     @BatchTypeCode = 'SEED',
     @Notes = @BatchNotes,
     @LoadBatchId = @LoadBatchId OUTPUT;

BEGIN TRY
BEGIN TRAN;

DELETE f FROM gov.SourceField f
JOIN gov.SourceObject o ON o.SourceObjectId = f.SourceObjectId;
DELETE FROM gov.SourceObject;

INSERT INTO gov.SourceObject
    (SourceSystemId, SchemaName, ObjectName, ObjectTypeCode,
     GrainStatement, ObjectDescription, LoadBatchId)
SELECT ss.SourceSystemId, 'src', v.ObjName, 'TABLE',
       v.Grain, v.Descr, @LoadBatchId
FROM (VALUES
 ('BRD','BrdBoardingBatch',
  '1 row per boarding batch (bulk transfer or monthly flow)',
  'Boarding batch header with transfer and schedule dates'),
 ('BRD','BrdBoardingTape',
  '1 row per loan per boarding event',
  'Boarding tape detail: origination-static attributes and '
  + 'tape values for the 5 critical fields'),
 ('SVC','SvcLoanMaster',
  '1 row per loan (current state)',
  'Servicing system of record loan master'),
 ('SVC','SvcLoanMonthEnd',
  '1 row per loan per month-end',
  'Month-end servicing snapshot: UPB, status, buckets, '
  + 'balances'),
 ('SVC','SvcEscrowAnalysis',
  '1 row per loan per annual analysis',
  'Escrow analysis due and completion events'),
 ('SVC','SvcEscrowDisbursement',
  '1 row per escrow disbursement',
  'Tax and insurance disbursements with match flags'),
 ('SVC','SvcInsurancePolicy',
  '1 row per policy per loan',
  'Hazard, flood, and lender placed policies'),
 ('SVC','SvcForbearancePlan',
  '1 row per forbearance plan',
  'Forbearance plan spans and exits'),
 ('SVC','SvcLoanModification',
  '1 row per completed modification',
  'Completed modification terms; workflow lives in DMS'),
 ('PAY','PayPaymentTransaction',
  '1 row per payment transaction event',
  'Payment receipts, postings, splits, reversals, suspense'),
 ('DMS','DmsLossMitigationCase',
  '1 row per loss mitigation case',
  'Workout application through decision and trial outcome'),
 ('DMS','DmsForeclosureCase',
  '1 row per foreclosure case',
  'Referral eligibility through sale or resolution'),
 ('DMS','DmsBankruptcyCase',
  '1 row per bankruptcy case',
  'Petition, proof of claim, disposition'),
 ('INV','InvLoanReport',
  '1 row per loan per reporting cycle (month)',
  'Investor loan-level reporting outcomes'),
 ('INV','InvRemittance',
  '1 row per investor per remittance cycle',
  'Investor cash remittance timing and amounts'),
 ('INV','InvRepurchaseDemand',
  '1 row per repurchase demand',
  'Demand receipt through resolution'),
 ('VAL','ValPropertyValuation',
  '1 row per valuation event per loan',
  'AVM, BPO, and appraisal values with dates'),
 ('CRM','CrmLead',
  '1 row per lead',
  'Lead creation, source, assignment, conversion linkage'),
 ('LOS','LosApplication',
  '1 row per application (accumulating funnel state)',
  'Application lifecycle: received, disposition, closing, '
  + 'funding, servicing intent'),
 ('PPE','PpeRateLock',
  '1 row per lock event (relocks are new rows)',
  'Lock terms, extensions, expirations, relock chains'),
 ('LIC','LicLoanOfficerRoster',
  '1 row per LO per roster effective period (SCD2 source)',
  'LO identity, branch, region, employment'),
 ('LIC','LicLoanOfficerLicense',
  '1 row per LO per state license',
  'License status, expiration, renewal, continuing '
  + 'education')
) v(SysCode, ObjName, Grain, Descr)
JOIN gov.SourceSystem ss ON ss.SourceSystemCode = v.SysCode;

/* ---- governed key fields (CDE-relevant and metric-driving,
       not an exhaustive column dump) ---- */
INSERT INTO gov.SourceField
    (SourceObjectId, FieldName, DataTypeName, IsNullable,
     FieldDescription, LoadBatchId)
SELECT o.SourceObjectId, v.FieldName, v.TypeName, v.Nullable,
       v.Descr, @LoadBatchId
FROM (VALUES
 ('BrdBoardingTape','LoanNumber','VARCHAR(20)',0,
  'Servicer loan number, enterprise business key'),
 ('BrdBoardingTape','TapeUpbAmount','DECIMAL(18,2)',1,
  'UPB per prior servicer tape; boarding accuracy baseline'),
 ('BrdBoardingTape','TapeInterestRatePercent','DECIMAL(9,4)',1,
  'Note rate per tape; critical field 2 of 5'),
 ('BrdBoardingTape','TapeNextPaymentDueDate','DATE',1,
  'Next due per tape; critical field 3 of 5'),
 ('BrdBoardingTape','TapeEscrowBalanceAmount','DECIMAL(18,2)',
  1,'Escrow balance per tape; critical field 4 of 5'),
 ('BrdBoardingTape','TapeInvestorCode','VARCHAR(10)',1,
  'Investor per tape; critical field 5 of 5'),
 ('BrdBoardingTape','NoteRatePercent','DECIMAL(9,4)',1,
  'Origination note rate; defect 1 target'),
 ('BrdBoardingTape','PropertyStateCode','VARCHAR(4)',1,
  'Property state; defect 2 target, MCR state splits'),
 ('BrdBoardingTape','OriginalLoanAmount','DECIMAL(18,2)',1,
  'Original amount; conforming test input'),
 ('BrdBoardingTape','BoardingCompletedDate','DATE',1,
  'Boarding completion; SLA input'),
 ('SvcLoanMaster','LoanNumber','VARCHAR(20)',0,
  'Loan business key, authoritative post-boarding'),
 ('SvcLoanMaster','InvestorCode','VARCHAR(10)',1,
  'Investor of record'),
 ('SvcLoanMaster','ServicingTypeCode','VARCHAR(30)',1,
  'MCR servicing type classification'),
 ('SvcLoanMaster','MsrOwnerNmlsId','VARCHAR(12)',1,
  'MSR owner NMLS ID; S520A detail'),
 ('SvcLoanMonthEnd','AsOfDate','DATE',0,
  'Snapshot month-end date'),
 ('SvcLoanMonthEnd','CurrentUpbAmount','DECIMAL(18,2)',1,
  'Unpaid principal balance at snapshot'),
 ('SvcLoanMonthEnd','NextPaymentDueDate','DATE',1,
  'Contractual next due; DPD input'),
 ('SvcLoanMonthEnd','LoanStatusCode','VARCHAR(10)',0,
  'Servicing status; active population gate'),
 ('SvcLoanMonthEnd','DelinquencyBucketCode','VARCHAR(20)',1,
  'Source-claimed bucket; consistency-tested vs derived'),
 ('SvcLoanMonthEnd','SuspenseBalanceAmount','DECIMAL(18,2)',1,
  'Unapplied funds at snapshot'),
 ('SvcLoanMonthEnd','ServicingFeeRatePercent','DECIMAL(9,4)',
  1,'Fee rate; fee yield input'),
 ('PayPaymentTransaction','ReceivedDate','DATE',0,
  'Payment receipt date; timeliness clock start'),
 ('PayPaymentTransaction','PostedDate','DATE',1,
  'Posting date; timeliness clock end'),
 ('PayPaymentTransaction','ReversalFlag','BIT',0,
  'Reversal marker; accuracy input'),
 ('PayPaymentTransaction','OriginalTransactionId','BIGINT',1,
  'Reversal chain to original posting'),
 ('DmsLossMitigationCase','CompletePackageDate','DATE',1,
  'Complete package; Reg X clock anchor'),
 ('DmsLossMitigationCase','DecisionCode','VARCHAR(20)',1,
  'Workout decision classification'),
 ('DmsForeclosureCase','FirstLegalEligibleDate','DATE',0,
  'Referral SLA anchor'),
 ('DmsForeclosureCase','ReferralDate','DATE',1,
  'Referral; timeline start'),
 ('DmsForeclosureCase','SaleHeldDate','DATE',1,
  'Sale held; timeline end'),
 ('DmsBankruptcyCase','PocBarDate','DATE',1,
  'Proof of claim bar date'),
 ('DmsBankruptcyCase','PocFiledDate','DATE',1,
  'Proof of claim filed date'),
 ('InvLoanReport','ReportingDeadlineDate','DATE',0,
  'Investor deadline'),
 ('InvLoanReport','ReportSubmittedDate','DATE',1,
  'Submission date'),
 ('InvLoanReport','ErrorCount','INT',1,
  'Loan-level reporting errors'),
 ('InvRemittance','RemittanceDueDate','DATE',0,
  'Remittance due date'),
 ('InvRemittance','RemittanceSentDate','DATE',1,
  'Remittance sent date'),
 ('InvRepurchaseDemand','DemandReceivedDate','DATE',0,
  'Repurchase clock start'),
 ('InvRepurchaseDemand','ResolutionDate','DATE',1,
  'Repurchase clock end'),
 ('ValPropertyValuation','PropertyValueAmount',
  'DECIMAL(18,2)',0,'Property value; CLTV denominator'),
 ('ValPropertyValuation','ValuationDate','DATE',0,
  'Valuation date; latest-value ordering'),
 ('CrmLead','LeadCreatedDate','DATE',0,
  'Lead creation; funnel anchor'),
 ('CrmLead','LeadSourceCode','VARCHAR(30)',1,
  'Attribution source; defect 20 target'),
 ('CrmLead','ConvertedApplicationId','INT',1,
  'CRM to LOS conversion linkage'),
 ('LosApplication','AppReceivedDate','DATE',1,
  'Signed application date per MCR glossary; AC020 basis'),
 ('LosApplication','DispositionCode','VARCHAR(20)',1,
  'Terminal disposition; AC030-AC080, defect 17 target'),
 ('LosApplication','FundingDate','DATE',1,
  'Funding date; AC070 and cycle time'),
 ('LosApplication','CurrentLoanAmount','DECIMAL(18,2)',1,
  'Current amount; production volume'),
 ('LosApplication','LoanOfficerNmlsId','VARCHAR(12)',0,
  'LO of record; defect 14 target, ACMLO1'),
 ('LosApplication','ServicingDispositionIntentCode',
  'VARCHAR(20)',1,'Retained or released; AC1200 family'),
 ('PpeRateLock','LockDate','DATE',0,'Lock event date'),
 ('PpeRateLock','LockAmount','DECIMAL(18,2)',0,
  'Locked amount; pull-through basis'),
 ('PpeRateLock','CurrentExpirationDate','DATE',0,
  'Current expiration; defect 18 target'),
 ('PpeRateLock','LockStatusCode','VARCHAR(20)',0,
  'Terminal lock status'),
 ('PpeRateLock','PriorLockId','INT',1,'Relock chain'),
 ('LicLoanOfficerRoster','NmlsId','VARCHAR(12)',0,
  'LO business key across CRM, LOS, LIC'),
 ('LicLoanOfficerRoster','BranchCode','VARCHAR(10)',0,
  'Branch; SCD2 attribute'),
 ('LicLoanOfficerLicense','LicenseStatusCode','VARCHAR(20)',0,
  'License status; compliance gate'),
 ('LicLoanOfficerLicense','ExpirationDate','DATE',0,
  'License expiration; defect 19 input'),
 ('LicLoanOfficerLicense','CeCompletedHours','DECIMAL(6,2)',1,
  'CE hours completed')
) v(ObjName, FieldName, TypeName, Nullable, Descr)
JOIN gov.SourceObject o ON o.ObjectName = v.ObjName;

COMMIT;
EXEC audit.usp_CompleteLoadBatch @LoadBatchId, 'SUCCESS';

DECLARE @O INT = (SELECT COUNT(*) FROM gov.SourceObject);
DECLARE @F INT = (SELECT COUNT(*) FROM gov.SourceField);
PRINT 'Script 012 complete: ' + CAST(@O AS VARCHAR(10))
    + ' source objects, ' + CAST(@F AS VARCHAR(10))
    + ' governed fields registered.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    EXEC audit.usp_LogError @LoadBatchId = @LoadBatchId,
         @ContextInfo = N'012_gov_register_sources.sql';
    EXEC audit.usp_CompleteLoadBatch @LoadBatchId, 'FAILED';
    THROW;
END CATCH
GO
