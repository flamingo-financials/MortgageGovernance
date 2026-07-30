/* ============================================================
   MortgageGovernance | Phase 2 | Script 006
   MCR FV7 line item registry, generated from the NMLS
   Mortgage Call Report FV7 data dictionary workbook.
   Loads all 641 line items across the six components and
   35 official glossary terms into gov.BusinessTerm.
   GENERATED FILE. Do not hand-edit; regenerate from the
   dictionary if the source workbook changes.
   Idempotent: deletes and reloads MCR_FV7 items; glossary
   terms guarded by NOT EXISTS.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

DECLARE @LoadBatchId INT;
DECLARE @BatchNotes NVARCHAR(400) =
    N'Script 006: 641 FV7 line items and '
  + N'35 glossary terms from the NMLS data dictionary.';

EXEC audit.usp_StartLoadBatch
     @BatchName     = N'MCR FV7 item registry seed',
     @BatchTypeCode = 'SEED',
     @Notes         = @BatchNotes,
     @LoadBatchId   = @LoadBatchId OUTPUT;

BEGIN TRY
BEGIN TRAN;

DECLARE @McrReportId INT =
    (SELECT RegulatoryReportId FROM gov.RegulatoryReport
     WHERE ReportCode = 'MCR_FV7');
IF @McrReportId IS NULL
    THROW 50010,
      'MCR_FV7 report row missing. Run script 004 first.', 1;

DECLARE @SecCompany INT =
    (SELECT RegulatoryReportSectionId
     FROM gov.RegulatoryReportSection
     WHERE RegulatoryReportId = @McrReportId
       AND SectionCode = 'RMLA_COMPANY');
DECLARE @SecOne INT =
    (SELECT RegulatoryReportSectionId
     FROM gov.RegulatoryReportSection
     WHERE RegulatoryReportId = @McrReportId
       AND SectionCode = 'RMLA_SEC1');
DECLARE @SecTwo INT =
    (SELECT RegulatoryReportSectionId
     FROM gov.RegulatoryReportSection
     WHERE RegulatoryReportId = @McrReportId
       AND SectionCode = 'RMLA_SEC2');
DECLARE @SecThree INT =
    (SELECT RegulatoryReportSectionId
     FROM gov.RegulatoryReportSection
     WHERE RegulatoryReportId = @McrReportId
       AND SectionCode = 'RMLA_SEC3');
DECLARE @SecSssf INT =
    (SELECT RegulatoryReportSectionId
     FROM gov.RegulatoryReportSection
     WHERE RegulatoryReportId = @McrReportId
       AND SectionCode = 'SSSF');
DECLARE @SecFc INT =
    (SELECT RegulatoryReportSectionId
     FROM gov.RegulatoryReportSection
     WHERE RegulatoryReportId = @McrReportId
       AND SectionCode = 'FC');

IF @SecCompany IS NULL OR @SecOne IS NULL
   OR @SecTwo IS NULL OR @SecThree IS NULL
   OR @SecSssf IS NULL OR @SecFc IS NULL
    THROW 50011,
      'One or more FV7 sections missing. Run script 004 first.',
      1;

DELETE i
FROM gov.RegulatoryReportItem i
JOIN gov.RegulatoryReportSection s
  ON s.RegulatoryReportSectionId = i.RegulatoryReportSectionId
WHERE s.RegulatoryReportId = @McrReportId;

/* ---- RMLA_COMPANY: items from sheet [RMLA Company] ---- */
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LOC', N'Warehouse Lines of Credit',
    N'Lines of Credit at Period End',
    N'Enter your Warehouse Line providers, the limit on each line of credit for each provider and the amount you have available on each line of credit at the end of the period. This must reflect all warehouse line providers your company has a relationship with. [All warehouse line providers, credit limit per line, and remaining credit available at period end.]',
    N'Population: all active warehouse line agreements (relationship exists, even if unused) | Filters: none - include every provider relationship | Timing: as of period end | Measures: provider name, committed credit limit, remaining available (limit minus drawn) | Source: treasury/warehouse mgmt system or facility agreements; drawn balance ties to GL B009',
    N'Provider: text 150 max; Limit: positive dollar; Remaining: dollar', 0, N'Texas Capital Bank | 25000000 | 11350000', 1,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS010', N'Wholly Owned Loans Serviced',
    N'Loans Serviced - Nationwide Totals',
    N'Enter the UPB and Loan Count for loans fitting this category. Report your company''s nationwide totals of all loans serviced regardless of whether or not your company is licensed in a particular state or if your company is required to submit a state-specific RMLA for a particular state. [UPB and count of loans serviced with all ownership rights retained. Nationwide totals regardless of state licensure.]',
    N'Population: wholly owned serviced loans (you retain all ownership rights) | Filters: servicing_type = ''Wholly Owned''; active loans only; NATIONWIDE - no state filter | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 187500000 | Count 812', 2,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS020', N'Loans Serviced Under MSRs',
    N'Loans Serviced - Nationwide Totals',
    N'Enter the UPB and Loan Count for loans fitting this category. Report your company''s nationwide totals of all loans serviced regardless of whether or not your company is licensed in a particular state or if your company is required to submit a state-specific RMLA for a particular state. [UPB and count of loans serviced where only the MSRs are owned. Nationwide totals.]',
    N'Population: loans serviced where you own only the MSRs | Filters: servicing_type = ''MSR Owned''; active loans only; NATIONWIDE - no state filter | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 1240000000 | Count 5361', 3,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS030', N'Subservicing for Others',
    N'Loans Serviced - Nationwide Totals',
    N'Enter the UPB and Loan Count for loans fitting this category. Report your company''s nationwide totals of all loans serviced regardless of whether or not your company is licensed in a particular state or if your company is required to submit a state-specific RMLA for a particular state. [UPB and count of loans subserviced on behalf of others. Nationwide totals.]',
    N'Population: loans subserviced on behalf of others (you do not own loan or MSR) | Filters: servicing_type = ''Subservicing for Others''; active loans only; NATIONWIDE - no state filter | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 96200000 | Count 447', 4,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS040', N'Subservicing by Others',
    N'Loans Serviced - Nationwide Totals',
    N'Enter the UPB and Loan Count for loans fitting this category. Report your company''s nationwide totals of all loans serviced regardless of whether or not your company is licensed in a particular state or if your company is required to submit a state-specific RMLA for a particular state. [UPB and count of wholly owned/MSR-owned loans contracted to a third-party subservicer. Nationwide totals.]',
    N'Population: wholly owned / MSR-owned loans serviced by a contracted third party | Filters: servicing_type = ''Subserviced by Others''; active loans only; NATIONWIDE - no state filter | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 54800000 | Count 231', 5,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS090', N'Total Servicing Activity',
    N'Loans Serviced - Nationwide Totals',
    N'Sum of LS010 to LS040 per column.',
    N'Calculated: LS010+LS020+LS030+LS040. Validate against total active serviced portfolio.',
    N'UPB: dollar; Count: whole number', 1, N'UPB 1578500000 | Count 6851', 6,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS100', N'Loan Servicing Transferred In During the Period',
    N'Servicing Transfers During the Quarter',
    N'A mortgage servicer collects and processes loan payments on behalf of the owner of the mortgage note. Servicing transfers may occur via sale of MSRs separately from note ownership, hiring a subservicer, outright MSR asset sales, or whole loan servicing/portfolio transfers. For MCR purposes ''transfer'' is used broadly to cover transfers of servicing rights AND transfers of servicing responsibilities through subservicing or whole loan arrangements. For LS100, report transfers INTO the entity. [Transfers of servicing rights or responsibilities (MSR sales, subservicing, whole loan servicing) INTO the entity.]',
    N'Population: loans boarded via servicing transfer (MSR purchase, subservicing onboard, whole-loan transfer) | Filters: board_reason/transfer_type in transfer-in codes; exclude new originations | Timing: activity DURING the period (transfer effective date in quarter) | Measures: SUM(upb at transfer), COUNT(loan_id) | Source: servicing transfer/boarding tables; loan boarding log',
    N'UPB: dollar; Count: whole number', 0, N'UPB 42750000 | Count 189', 7,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS110', N'Loan Servicing Transferred Out During the Period',
    N'Servicing Transfers During the Quarter',
    N'A mortgage servicer collects and processes loan payments on behalf of the owner of the mortgage note. Servicing transfers may occur via sale of MSRs separately from note ownership, hiring a subservicer, outright MSR asset sales, or whole loan servicing/portfolio transfers. For MCR purposes ''transfer'' is used broadly to cover transfers of servicing rights AND transfers of servicing responsibilities through subservicing or whole loan arrangements. For LS110, report transfers FROM the entity. [Transfers of servicing rights or responsibilities OUT of the entity.]',
    N'Population: loans de-boarded via servicing transfer out (MSR sale, subservicer release, whole-loan transfer) | Filters: deboard_reason in transfer-out codes; exclude payoffs/liquidations | Timing: activity DURING the period | Measures: SUM(upb at transfer), COUNT(loan_id) | Source: servicing transfer/de-boarding tables',
    N'UPB: dollar; Count: whole number', 0, N'UPB 18300000 | Count 84', 8,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS190', N'Total Loans Transferred In and Out During the Period',
    N'Servicing Transfers During the Quarter',
    N'Sum of LS100 to LS110 per column.',
    N'Calculated: LS100+LS110.',
    N'UPB: dollar; Count: whole number', 1, N'UPB 61050000 | Count 273', 9,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS200', N'Less than 30 Days Delinquent (incl. current)',
    N'Nationwide Payment Status - All Loans',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are current. [UPB and count of serviced loans that are current.]',
    N'Population: all serviced loans (all servicing types), nationwide | Filters: delinquency bucket: current: DPD < 30 (0-29); document DPD method (MBA vs contractual) in workpapers | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 1483200000 | Count 6402', 10,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS210', N'30 to 59 Days Delinquent',
    N'Nationwide Payment Status - All Loans',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 30 to 59 days delinquent. [UPB and count of serviced loans 30-59 days delinquent.]',
    N'Population: all serviced loans (all servicing types), nationwide | Filters: delinquency bucket: DPD between 30 and 59; document DPD method (MBA vs contractual) in workpapers | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 52100000 | Count 251', 11,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS220', N'60 to 89 Days Delinquent',
    N'Nationwide Payment Status - All Loans',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 60 to 89 days delinquent. [UPB and count of serviced loans 60-89 days delinquent.]',
    N'Population: all serviced loans (all servicing types), nationwide | Filters: delinquency bucket: DPD between 60 and 89; document DPD method (MBA vs contractual) in workpapers | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 21400000 | Count 108', 12,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS230', N'90 or more Days Delinquent',
    N'Nationwide Payment Status - All Loans',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 90 or more days delinquent. [UPB and count of serviced loans 90+ days delinquent.]',
    N'Population: all serviced loans (all servicing types), nationwide | Filters: delinquency bucket: DPD >= 90; document DPD method (MBA vs contractual) in workpapers | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 21800000 | Count 90', 13,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS290', N'Total Loans Serviced',
    N'Nationwide Payment Status - All Loans',
    N'Sum of LS200 to LS230 per column.',
    N'Calculated: LS200+LS210+LS220+LS230. Must reconcile to LS090 total.',
    N'UPB: dollar; Count: whole number', 1, N'UPB 1578500000 | Count 6851', 14,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS300', N'FNMA',
    N'Servicing Activity by Investor/Counterparty',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the investor/counterparty is FNMA. [UPB and count of serviced loans where investor/counterparty is FNMA.]',
    N'Population: all serviced loans | Filters: investor_code = ''FNMA'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); investor master mapping table',
    N'UPB: dollar; Count: whole number', 0, N'UPB 655000000 | Count 2870', 15,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS310', N'FHLMC',
    N'Servicing Activity by Investor/Counterparty',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the investor/counterparty is FHLMC. [UPB and count of serviced loans where investor/counterparty is FHLMC.]',
    N'Population: all serviced loans | Filters: investor_code = ''FHLMC'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); investor master mapping table',
    N'UPB: dollar; Count: whole number', 0, N'UPB 411300000 | Count 1795', 16,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS320', N'GNMA',
    N'Servicing Activity by Investor/Counterparty',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the investor/counterparty is GNMA. [UPB and count of serviced loans where investor/counterparty is GNMA.]',
    N'Population: all serviced loans | Filters: investor_code = ''GNMA'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); investor master mapping table',
    N'UPB: dollar; Count: whole number', 0, N'UPB 302800000 | Count 1454', 17,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS330', N'Private Label',
    N'Servicing Activity by Investor/Counterparty',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the investor/counterparty is Private Label. [UPB and count of serviced loans where investor/counterparty is a private label issuer.]',
    N'Population: all serviced loans | Filters: investor_code = ''Private Label'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); investor master mapping table',
    N'UPB: dollar; Count: whole number', 0, N'UPB 121900000 | Count 501', 18,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS340', N'Other',
    N'Servicing Activity by Investor/Counterparty',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the investor/counterparty is Other (not matching above). [UPB and count of serviced loans not matching categories above.]',
    N'Population: all serviced loans | Filters: investor_code = ''Other (not matching above)'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); investor master mapping table',
    N'UPB: dollar; Count: whole number', 0, N'UPB 87500000 | Count 231', 19,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS390', N'Total Servicing Activity',
    N'Servicing Activity by Investor/Counterparty',
    N'Sum of LS300 to LS340 per column.',
    N'Calculated: LS300+...+LS340. Must reconcile to LS090/LS290 totals.',
    N'UPB: dollar; Count: whole number', 1, N'UPB 1578500000 | Count 6851', 20,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS400', N'Actual/Actual',
    N'Remittance Type - FNMA',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is actual/actual. [UPB and count of FNMA serviced loans with actual/actual remittance.]',
    N'Population: serviced loans with investor = FNMA | Filters: investor_code = ''FNMA'' AND remittance_type = ''A/A'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'UPB 214500000 | Count 940', 21,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS410', N'Scheduled/Scheduled',
    N'Remittance Type - FNMA',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is scheduled/scheduled. [UPB and count of FNMA serviced loans with scheduled/scheduled remittance.]',
    N'Population: serviced loans with investor = FNMA | Filters: investor_code = ''FNMA'' AND remittance_type = ''S/S'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'UPB 388200000 | Count 1701', 22,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS420', N'Scheduled/Actual',
    N'Remittance Type - FNMA',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is scheduled/actual. [UPB and count of FNMA serviced loans with scheduled/actual remittance.]',
    N'Population: serviced loans with investor = FNMA | Filters: investor_code = ''FNMA'' AND remittance_type = ''S/A'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'UPB 52300000 | Count 229', 23,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS500', N'Actual/Actual',
    N'Remittance Type - FHLMC',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is actual/actual. [UPB and count of FHLMC serviced loans with actual/actual remittance.]',
    N'Population: serviced loans with investor = FHLMC | Filters: investor_code = ''FHLMC'' AND remittance_type = ''A/A'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'UPB 96400000 | Count 421', 24,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS510', N'Scheduled/Scheduled',
    N'Remittance Type - FHLMC',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is scheduled/scheduled. [UPB and count of FHLMC serviced loans with scheduled/scheduled remittance.]',
    N'Population: serviced loans with investor = FHLMC | Filters: investor_code = ''FHLMC'' AND remittance_type = ''S/S'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'UPB 271600000 | Count 1186', 25,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS520', N'Scheduled/Actual',
    N'Remittance Type - FHLMC',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is scheduled/actual. [UPB and count of FHLMC serviced loans with scheduled/actual remittance.]',
    N'Population: serviced loans with investor = FHLMC | Filters: investor_code = ''FHLMC'' AND remittance_type = ''S/A'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'UPB 43300000 | Count 188', 26,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS600', N'Actual/Actual',
    N'Remittance Type - GNMA',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is actual/actual. [UPB and count of GNMA serviced loans with actual/actual remittance.]',
    N'Population: serviced loans with investor = GNMA | Filters: investor_code = ''GNMA'' AND remittance_type = ''A/A'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'UPB 302800000 | Count 1454', 27,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS610', N'Scheduled/Scheduled',
    N'Remittance Type - GNMA',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is scheduled/scheduled. [UPB and count of GNMA serviced loans with scheduled/scheduled remittance.]',
    N'Population: serviced loans with investor = GNMA | Filters: investor_code = ''GNMA'' AND remittance_type = ''S/S'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'0 | 0', 28,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS620', N'Scheduled/Actual',
    N'Remittance Type - GNMA',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is scheduled/actual. [UPB and count of GNMA serviced loans with scheduled/actual remittance.]',
    N'Population: serviced loans with investor = GNMA | Filters: investor_code = ''GNMA'' AND remittance_type = ''S/A'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'0 | 0', 29,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS700', N'Actual/Actual',
    N'Remittance Type - Private',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is actual/actual. [UPB and count of private label serviced loans with actual/actual remittance.]',
    N'Population: serviced loans with investor = Private Label | Filters: investor_code = ''Private Label'' AND remittance_type = ''A/A'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'UPB 121900000 | Count 501', 30,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS710', N'Scheduled/Scheduled',
    N'Remittance Type - Private',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is scheduled/scheduled. [UPB and count of private label serviced loans with scheduled/scheduled remittance.]',
    N'Population: serviced loans with investor = Private Label | Filters: investor_code = ''Private Label'' AND remittance_type = ''S/S'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'0 | 0', 31,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS720', N'Scheduled/Actual',
    N'Remittance Type - Private',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is scheduled/actual. [UPB and count of private label serviced loans with scheduled/actual remittance.]',
    N'Population: serviced loans with investor = Private Label | Filters: investor_code = ''Private Label'' AND remittance_type = ''S/A'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'0 | 0', 32,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS800', N'Actual/Actual',
    N'Remittance Type - Other',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is actual/actual. [UPB and count of other serviced loans with actual/actual remittance.]',
    N'Population: serviced loans with investor = Other | Filters: investor_code = ''Other'' AND remittance_type = ''A/A'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'UPB 87500000 | Count 231', 33,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS810', N'Scheduled/Scheduled',
    N'Remittance Type - Other',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is scheduled/scheduled. [UPB and count of other serviced loans with scheduled/scheduled remittance.]',
    N'Population: serviced loans with investor = Other | Filters: investor_code = ''Other'' AND remittance_type = ''S/S'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'0 | 0', 34,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS820', N'Scheduled/Actual',
    N'Remittance Type - Other',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period where the remittance type is scheduled/actual. [UPB and count of other serviced loans with scheduled/actual remittance.]',
    N'Population: serviced loans with investor = Other | Filters: investor_code = ''Other'' AND remittance_type = ''S/A'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); remittance_type from investor accounting setup',
    N'UPB: dollar; Count: whole number', 0, N'0 | 0', 35,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS900', N'Less than 30 Days Delinquent (incl. current)',
    N'Payment Status - Wholly Owned',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are current. [UPB and count of wholly owned serviced loans that are current.]',
    N'Population: wholly owned serviced loans | Filters: servicing_type = ''Wholly Owned'' AND current: DPD < 30 (0-29) | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 178100000 | Count 771', 36,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS910', N'30 to 59 Days Delinquent',
    N'Payment Status - Wholly Owned',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 30 to 59 days delinquent. [UPB and count of wholly owned serviced loans 30-59 days delinquent.]',
    N'Population: wholly owned serviced loans | Filters: servicing_type = ''Wholly Owned'' AND DPD between 30 and 59 | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 5600000 | Count 24', 37,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS920', N'60 to 89 Days Delinquent',
    N'Payment Status - Wholly Owned',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 60 to 89 days delinquent. [UPB and count of wholly owned serviced loans 60-89 days delinquent.]',
    N'Population: wholly owned serviced loans | Filters: servicing_type = ''Wholly Owned'' AND DPD between 60 and 89 | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 2100000 | Count 10', 38,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS930', N'90 or more Days Delinquent',
    N'Payment Status - Wholly Owned',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 90 or more days delinquent. [UPB and count of wholly owned serviced loans 90+ days delinquent.]',
    N'Population: wholly owned serviced loans | Filters: servicing_type = ''Wholly Owned'' AND DPD >= 90 | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 1700000 | Count 7', 39,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1000', N'Less than 30 Days Delinquent (incl. current)',
    N'Payment Status - Serviced Under MSRs',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are current. [UPB and count of MSR-serviced loans that are current.]',
    N'Population: loans serviced under MSRs | Filters: servicing_type = ''MSR Owned'' AND current: DPD < 30 (0-29) | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 1167800000 | Count 5049', 40,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1010', N'30 to 59 Days Delinquent',
    N'Payment Status - Serviced Under MSRs',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 30 to 59 days delinquent. [UPB and count of MSR-serviced loans 30-59 days delinquent.]',
    N'Population: loans serviced under MSRs | Filters: servicing_type = ''MSR Owned'' AND DPD between 30 and 59 | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 40200000 | Count 189', 41,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1020', N'60 to 89 Days Delinquent',
    N'Payment Status - Serviced Under MSRs',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 60 to 89 days delinquent. [UPB and count of MSR-serviced loans 60-89 days delinquent.]',
    N'Population: loans serviced under MSRs | Filters: servicing_type = ''MSR Owned'' AND DPD between 60 and 89 | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 16600000 | Count 79', 42,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1030', N'90 or more Days Delinquent',
    N'Payment Status - Serviced Under MSRs',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 90 or more days delinquent. [UPB and count of MSR-serviced loans 90+ days delinquent.]',
    N'Population: loans serviced under MSRs | Filters: servicing_type = ''MSR Owned'' AND DPD >= 90 | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 15400000 | Count 44', 43,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1100', N'Less than 30 Days Delinquent (incl. current)',
    N'Payment Status - Subservicing for Others',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are current. [UPB and count of loans subserviced for others that are current.]',
    N'Population: loans subserviced for others | Filters: servicing_type = ''Subservicing for Others'' AND current: DPD < 30 (0-29) | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 89400000 | Count 415', 44,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1110', N'30 to 59 Days Delinquent',
    N'Payment Status - Subservicing for Others',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 30 to 59 days delinquent. [UPB and count of loans subserviced for others 30-59 days delinquent.]',
    N'Population: loans subserviced for others | Filters: servicing_type = ''Subservicing for Others'' AND DPD between 30 and 59 | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 4200000 | Count 21', 45,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1120', N'60 to 89 Days Delinquent',
    N'Payment Status - Subservicing for Others',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 60 to 89 days delinquent. [UPB and count of loans subserviced for others 60-89 days delinquent.]',
    N'Population: loans subserviced for others | Filters: servicing_type = ''Subservicing for Others'' AND DPD between 60 and 89 | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 1500000 | Count 7', 46,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1130', N'90 or more Days Delinquent',
    N'Payment Status - Subservicing for Others',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 90 or more days delinquent. [UPB and count of loans subserviced for others 90+ days delinquent.]',
    N'Population: loans subserviced for others | Filters: servicing_type = ''Subservicing for Others'' AND DPD >= 90 | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 1100000 | Count 4', 47,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1200', N'Less than 30 Days Delinquent (incl. current)',
    N'Payment Status - Subservicing by Others',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are current. [UPB and count of loans subserviced by others that are current.]',
    N'Population: loans subserviced by others | Filters: servicing_type = ''Subserviced by Others'' AND current: DPD < 30 (0-29) | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 51900000 | Count 219', 48,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1210', N'30 to 59 Days Delinquent',
    N'Payment Status - Subservicing by Others',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 30 to 59 days delinquent. [UPB and count of loans subserviced by others 30-59 days delinquent.]',
    N'Population: loans subserviced by others | Filters: servicing_type = ''Subserviced by Others'' AND DPD between 30 and 59 | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 2100000 | Count 9', 49,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1220', N'60 to 89 Days Delinquent',
    N'Payment Status - Subservicing by Others',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 60 to 89 days delinquent. [UPB and count of loans subserviced by others 60-89 days delinquent.]',
    N'Population: loans subserviced by others | Filters: servicing_type = ''Subserviced by Others'' AND DPD between 60 and 89 | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 500000 | Count 2', 50,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1230', N'90 or more Days Delinquent',
    N'Payment Status - Subservicing by Others',
    N'Enter the UPB and Count of Mortgage Loans you serviced during the period that are 90 or more days delinquent. [UPB and count of loans subserviced by others 90+ days delinquent.]',
    N'Population: loans subserviced by others | Filters: servicing_type = ''Subserviced by Others'' AND DPD >= 90 | Timing: delinquency status AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 300000 | Count 1', 51,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1400', N'Wholly Owned',
    N'Count and Amount of Foreclosed Loans',
    N'Enter the UPB and Count of Mortgage Loans in foreclosure status during the period. [UPB and count of wholly owned loans in foreclosure status during period.]',
    N'Population: serviced loans in active foreclosure | Filters: servicing_type = ''Wholly Owned'' AND foreclosure_flag = Y / loan_status = ''FCL'' | Timing: in foreclosure status at any point DURING the period | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system foreclosure workflow/status tables',
    N'UPB: dollar; Count: whole number', 0, N'UPB 950000 | Count 4', 52,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1410', N'Serviced Under MSRs',
    N'Count and Amount of Foreclosed Loans',
    N'Enter the UPB and Count of Mortgage Loans in foreclosure status during the period. [UPB and count of MSR-serviced loans in foreclosure status during period.]',
    N'Population: serviced loans in active foreclosure | Filters: servicing_type = ''MSR Owned'' AND foreclosure_flag = Y / loan_status = ''FCL'' | Timing: in foreclosure status at any point DURING the period | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system foreclosure workflow/status tables',
    N'UPB: dollar; Count: whole number', 0, N'UPB 7200000 | Count 27', 53,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1420', N'Subservicing for Others',
    N'Count and Amount of Foreclosed Loans',
    N'Enter the UPB and Count of Mortgage Loans in foreclosure status during the period. [UPB and count of loans subserviced for others in foreclosure status during period.]',
    N'Population: serviced loans in active foreclosure | Filters: servicing_type = ''Subservicing for Others'' AND foreclosure_flag = Y / loan_status = ''FCL'' | Timing: in foreclosure status at any point DURING the period | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system foreclosure workflow/status tables',
    N'UPB: dollar; Count: whole number', 0, N'UPB 600000 | Count 3', 54,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1430', N'Subservicing by Others',
    N'Count and Amount of Foreclosed Loans',
    N'Enter the UPB and Count of Mortgage Loans in foreclosure status during the period. [UPB and count of loans subserviced by others in foreclosure status during period.]',
    N'Population: serviced loans in active foreclosure | Filters: servicing_type = ''Subserviced by Others'' AND foreclosure_flag = Y / loan_status = ''FCL'' | Timing: in foreclosure status at any point DURING the period | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system foreclosure workflow/status tables',
    N'UPB: dollar; Count: whole number', 0, N'UPB 200000 | Count 1', 55,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1440', N'Other',
    N'Count and Amount of Foreclosed Loans',
    N'Enter the UPB and Count of Mortgage Loans in foreclosure status during the period. [UPB and count of other loans in foreclosure status during period.]',
    N'Population: serviced loans in active foreclosure | Filters: servicing_type not in the four categories above AND foreclosure_flag = Y / loan_status = ''FCL'' | Timing: in foreclosure status at any point DURING the period | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system foreclosure workflow/status tables',
    N'UPB: dollar; Count: whole number', 0, N'0 | 0', 56,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1490', N'Total Foreclosed Loans',
    N'Count and Amount of Foreclosed Loans',
    N'Total of LS1400 to LS1440.',
    N'Calculated: LS1400+...+LS1440.',
    N'UPB: dollar; Count: whole number', 1, N'UPB 8950000 | Count 35', 57,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1500', N'Loans in Forbearance at Beginning of Period',
    N'Forbearance & Foreclosure Volume',
    N'Enter the UPB and Count of Mortgage Loans that in forbearance at BEGINNING of period. [UPB and count of loans in forbearance at beginning of period.]',
    N'Population: serviced loans with forbearance activity | Filters: forbearance_flag = Y as of prior period end | Timing: activity DURING the period (LS1500 = beginning-of-period snapshot) | Measures: SUM(current_upb), COUNT(loan_id) | Source: loss mitigation / forbearance plan tables (plan_start, plan_end, exit_code)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 12400000 | Count 51', 58,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1510', N'Loans Entering Forbearance During Period',
    N'Forbearance & Foreclosure Volume',
    N'Enter the UPB and Count of Mortgage Loans that entered forbearance during period. [UPB and count of loans that entered forbearance during period.]',
    N'Population: serviced loans with forbearance activity | Filters: forbearance_start_date within quarter | Timing: activity DURING the period (LS1500 = beginning-of-period snapshot) | Measures: SUM(current_upb), COUNT(loan_id) | Source: loss mitigation / forbearance plan tables (plan_start, plan_end, exit_code)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 3800000 | Count 16', 59,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1520', N'Exiting Forbearance - Resumed Contractual Payment',
    N'Forbearance & Foreclosure Volume',
    N'Enter the UPB and Count of Mortgage Loans that exited forbearance and resumed contractual payment. [UPB and count exiting forbearance and resuming contractual payment.]',
    N'Population: serviced loans with forbearance activity | Filters: forbearance_end_date within quarter AND exit_disposition = ''Reinstated/Contractual'' | Timing: activity DURING the period (LS1500 = beginning-of-period snapshot) | Measures: SUM(current_upb), COUNT(loan_id) | Source: loss mitigation / forbearance plan tables (plan_start, plan_end, exit_code)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 4100000 | Count 17', 60,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1530', N'Exiting Forbearance - Entering Loss Mitigation',
    N'Forbearance & Foreclosure Volume',
    N'Enter the UPB and Count of Mortgage Loans that exited forbearance into loss mitigation. [UPB and count exiting forbearance and entering loss mitigation.]',
    N'Population: serviced loans with forbearance activity | Filters: forbearance_end_date within quarter AND exit_disposition = ''Loss Mit'' (mod, repayment plan, deferral) | Timing: activity DURING the period (LS1500 = beginning-of-period snapshot) | Measures: SUM(current_upb), COUNT(loan_id) | Source: loss mitigation / forbearance plan tables (plan_start, plan_end, exit_code)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 2300000 | Count 10', 61,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1540', N'Exiting Forbearance - Entering Foreclosure',
    N'Forbearance & Foreclosure Volume',
    N'Enter the UPB and Count of Mortgage Loans that exited forbearance into foreclosure. [UPB and count exiting forbearance and entering foreclosure.]',
    N'Population: serviced loans with forbearance activity | Filters: forbearance_end_date within quarter AND exit_disposition = ''Foreclosure'' | Timing: activity DURING the period (LS1500 = beginning-of-period snapshot) | Measures: SUM(current_upb), COUNT(loan_id) | Source: loss mitigation / forbearance plan tables (plan_start, plan_end, exit_code)',
    N'UPB: dollar; Count: whole number', 0, N'UPB 700000 | Count 3', 62,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'LS1590', N'Total Loans in Forbearance at End of Period',
    N'Forbearance & Foreclosure Volume',
    N'Ending forbearance population.',
    N'Calculated ending forbearance population: LS1500+LS1510-LS1520-LS1530-LS1540.',
    N'UPB: dollar; Count: whole number', 1, N'UPB 9100000 | Count 37', 63,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecCompany, N'NOTE', N'Company-Level Explanatory Note',
    N'Explanatory Notes',
    N'Free-text explanations for company-level information requiring clarification. Permanent part of the MCR filing.',
    N'Free text. Gather from filing analyst; explain any period-over-period anomalies (bulk transfers, data corrections).',
    N'Free text', 0, N'LS100 increase reflects bulk MSR acquisition of 189 loans effective 02/01/2026.', 64,
    @LoadBatchId);

/* ---- RMLA_SEC1: items from sheet [RMLA Sec I] ---- */
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC010', N'Applications In Process at Beginning of Period',
    N'Application Pipeline',
    N'Applications in process at end of prior period, including approved-not-closed.',
    N'Population: open application pipeline at prior quarter end (incl. approved-not-closed) | Filters: app status in open codes (in-process, approved, conditioned) as of prior period end | Timing: snapshot at BEGINNING of period; must equal prior quarter AC080 | Measures: SUM(app_amount), COUNT(app_id) | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 41200000 | Cnt 152', 1,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC020', N'Applications Received',
    N'Application Pipeline',
    N'Applications received during period (3rd party or direct from borrower).',
    N'Population: applications received during quarter (3rd party + direct) | Filters: app_date within quarter; 1-4 unit residential, consumer purpose only (exclude commercial/business/investment); state = filing state | Timing: activity DURING period; app date = signed initial 1003 or oral request date | Measures: SUM(app_amount), COUNT(app_id) | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 68400000 | Cnt 247', 2,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC030', N'Applications Approved but not Accepted',
    N'Application Pipeline',
    N'Approved but applicant/broker/correspondent failed to respond to approval or commitment within specified time.',
    N'Population: approved applications not accepted by applicant/broker/correspondent | Filters: action_code = ''Approved Not Accepted'' AND action_date within quarter | Timing: action DURING period | Measures: SUM(app_amount), COUNT(app_id) | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 3100000 | Cnt 11', 3,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC040', N'Applications Denied',
    N'Application Pipeline',
    N'Applications denied during period.',
    N'Population: denied applications | Filters: action_code = ''Denied'' AND action_date within quarter | Timing: action DURING period | Measures: SUM(app_amount), COUNT(app_id) | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 7900000 | Cnt 31', 4,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC050', N'Applications Withdrawn',
    N'Application Pipeline',
    N'Applications expressly withdrawn by applicant before credit decision, regardless of period received.',
    N'Population: applications withdrawn by applicant before credit decision | Filters: action_code = ''Withdrawn'' AND action_date within quarter (regardless of period received) | Timing: action DURING period | Measures: SUM(app_amount), COUNT(app_id) | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 5200000 | Cnt 19', 5,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC060', N'File Closed for Incompleteness',
    N'Application Pipeline',
    N'Written notice of incompleteness sent under Reg B 1002.9(c)(2); applicant did not respond in time specified.',
    N'Population: files closed for incompleteness under Reg B 1002.9(c)(2) | Filters: action_code = ''Incomplete/NOI expired'' AND action_date within quarter | Timing: action DURING period | Measures: SUM(app_amount), COUNT(app_id) | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 1800000 | Cnt 7', 6,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC065', N'Net Changes in Application Amount',
    N'Application Pipeline',
    N'Net changes in application dollar amounts during quarter. Negative aggregate entered as negative.',
    N'Population: application amount changes on open pipeline | Filters: delta between current app_amount and amount at receipt, for apps changed during quarter | Timing: net change DURING period; negative aggregate entered negative | Measures: SUM(amount_change) - dollar only, no count | Source: LOS amount-change audit/history table',
    N'Dollar (may be negative)', 0, N'-425000', 7,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC063', N'Net Application Changes',
    N'Application Pipeline',
    N'Add/remove count and amount in application data. Negative aggregate entered as negative. Retain detailed support. Requires commentary explanation.',
    N'Population: manual pipeline reconciliation adjustments (adds/removals) | Filters: analyst-identified corrections (duplicates, misqueued apps) | Timing: DURING period; negative allowed; commentary REQUIRED in ACNOTE | Measures: SUM(adj_amount), SUM(adj_count) | Source: reconciliation workpapers; retain support for exams',
    N'Amount: dollar (may be negative); Count: whole number', 0, N'Amt -310000 | Cnt -2 (duplicate apps removed; see commentary)', 8,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC066', N'Total Application Pipeline',
    N'Application Pipeline',
    N'(AC010+AC020)-(AC030+AC040+AC050+AC060)+AC065+AC063. Must equal AC090.',
    N'Calculated: (AC010+AC020)-(AC030+AC040+AC050+AC060)+AC065+AC063. Completeness check: must equal AC090.',
    N'Amount: dollar; Count: whole number', 1, N'Amt 90865000 | Cnt 329', 9,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC070', N'Loans Closed and Funded',
    N'Application Pipeline Results',
    N'Applications received in any period, originated this period. Must equal AC990 and MLO data total.',
    N'Population: loans closed AND funded this quarter (received any period) | Filters: funding_date within quarter; consumer-purpose 1-4 unit residential | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id). Completeness: must equal AC990 and MLO section total | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding table',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 52300000 | Cnt 191', 10,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC080', N'Applications in Process at End of Period',
    N'Application Pipeline Results',
    N'Open pipeline at end of period.',
    N'Population: open pipeline at quarter end | Filters: app status in open codes as of period end | Timing: snapshot at END of period; becomes next quarter AC010 | Measures: SUM(app_amount), COUNT(app_id) | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 38565000 | Cnt 138', 11,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC090', N'Total Application Pipeline Results',
    N'Application Pipeline Results',
    N'Sum of AC070 to AC080. Must equal AC066.',
    N'Calculated: AC070+AC080. Completeness check: must equal AC066.',
    N'Amount: dollar; Count: whole number', 1, N'Amt 90865000 | Cnt 329', 12,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC100', N'Conventional',
    N'Closed Loan Data - Loan Type (Forward)',
    N'Any loan other than FHA, VA, FSA or RHS. Report by Brokered / Closed-Retail / Closed-Wholesale.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: loan_type = ''Conventional'' (not FHA/VA/FSA/RHS); split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 29800000 | Cnt 104', 13,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC110', N'FHA-Insured',
    N'Closed Loan Data - Loan Type (Forward)',
    N'Federal Housing Administration insured.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: loan_type = ''FHA''; split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 11400000 | Cnt 47', 14,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC120', N'VA-Guaranteed',
    N'Closed Loan Data - Loan Type (Forward)',
    N'Veterans Administration guaranteed.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: loan_type = ''VA''; split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 7600000 | Cnt 28', 15,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC130', N'FSA/RHS-Guaranteed',
    N'Closed Loan Data - Loan Type (Forward)',
    N'Farm Service Agency or Rural Housing Service guaranteed.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: loan_type in (''FSA'',''RHS''); split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 2100000 | Cnt 9', 16,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC190', N'Total Loan Type - Forward Mortgages',
    N'Closed Loan Data - Loan Type (Forward)',
    N'Sum of AC100 to AC130 per column.',
    N'Calculated section total per column. Cross-foot: AC190=AC290=AC390=AC590 (same closed population).',
    N'Amount: dollar; Count: whole number', 1, N'Retail: Amt 50900000 | Cnt 188', 17,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC200', N'One to Four Family Dwelling',
    N'Closed Loan Data - Property Type',
    N'Property type of 1-4 family dwelling, other than manufactured housing.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: property_type = 1-4 family dwelling, excluding manufactured; split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 48600000 | Cnt 176', 18,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC210', N'Manufactured Housing',
    N'Closed Loan Data - Property Type',
    N'Manufactured housing property type.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: property_type = ''Manufactured''; split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 2300000 | Cnt 12', 19,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC290', N'Total Property Type',
    N'Closed Loan Data - Property Type',
    N'Sum of AC200 to AC220 per column.',
    N'Calculated section total per column. Cross-foot: AC190=AC290=AC390=AC590 (same closed population).',
    N'Amount: dollar; Count: whole number', 1, N'Retail: Amt 50900000 | Cnt 188', 20,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC300', N'Home Purchase',
    N'Closed Loan Data - Purpose',
    N'Loan secured by and made for purchase of a dwelling.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: loan_purpose = ''Purchase''; split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 36400000 | Cnt 129', 21,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC310', N'Home Improvement',
    N'Closed Loan Data - Purpose',
    N'Dwelling-secured loan used at least in part for repair/rehab/remodel/improvement, or unsecured loan classified as home improvement by institution.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: loan_purpose = ''Home Improvement''; split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 2800000 | Cnt 14', 22,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC320', N'Refinancing',
    N'Closed Loan Data - Purpose',
    N'Dwelling-secured loan replacing and satisfying another dwelling-secured loan to the same borrower.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: loan_purpose = ''Refinance'' (replaces+satisfies prior dwelling-secured loan, same borrower); split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 11700000 | Cnt 45', 23,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC390', N'Total Purpose of Loan or Application',
    N'Closed Loan Data - Purpose',
    N'Sum of AC300 to AC320 per column.',
    N'Calculated section total per column. Cross-foot: AC190=AC290=AC390=AC590 (same closed population).',
    N'Amount: dollar; Count: whole number', 1, N'Retail: Amt 50900000 | Cnt 188', 24,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC400', N'HOEPA',
    N'Closed Loan Data - HOEPA',
    N'Loans subject to HOEPA (Reg Z 12 CFR 1026.32) due to APR or points/fees exceeding triggers. Retail = you originated; wholesale = you funded.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: HOEPA flag = Y (APR or points/fees exceed 12 CFR 1026.32 triggers); split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 0 | Cnt 0', 25,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC500', N'First Lien',
    N'Closed Loan Data - Lien Status',
    N'Secured by a first lien on real property.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: lien_position = 1 (real property); split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 47300000 | Cnt 168', 26,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC510', N'Subordinate Lien',
    N'Closed Loan Data - Lien Status',
    N'Secured by subordinate lien on real property. Report full exposure amount.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: lien_position >= 2 (real property; report FULL exposure); split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 1300000 | Cnt 8', 27,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC520', N'Not Secured by a Lien',
    N'Closed Loan Data - Lien Status',
    N'Not secured by lien on real property (chattel dwellings: manufactured homes, houseboats, trailers).',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: no real-property lien (chattel: manufactured, houseboat, trailer); split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 2300000 | Cnt 12', 28,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC590', N'Total Lien Status',
    N'Closed Loan Data - Lien Status',
    N'Sum of AC500 to AC520 per column.',
    N'Calculated section total per column. Cross-foot: AC190=AC290=AC390=AC590 (same closed population).',
    N'Amount: dollar; Count: whole number', 1, N'Retail: Amt 50900000 | Cnt 188', 29,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC600', N'Broker Fees Collected - Forward Mortgages',
    N'Closed Loan Data - Fees',
    N'Gross broker fees (YSP, application, doc prep, admin) collected on forward mortgages. Exclude pass-through fees.',
    N'Population: gross broker fees on forward mortgages collected this quarter | Filters: fee retained = Y AND fee_role = ''Broker'' AND product = forward; EXCLUDE pass-through fees (appraisal, credit report, flood cert) | Timing: collected DURING period | Measures: SUM(fee_amount) - dollar only | Source: LOS/closing fee itemization (HUD/CD fee lines) with retained-vs-pass-through flag',
    N'Positive dollar', 0, N'148500', 30,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC610', N'Lender Fees Collected - Forward Mortgages',
    N'Closed Loan Data - Fees',
    N'Gross lender fees (application, doc prep, admin) collected on forward mortgages. Exclude pass-through fees.',
    N'Population: gross lender fees on forward mortgages collected this quarter | Filters: fee retained = Y AND fee_role = ''Lender'' AND product = forward; EXCLUDE pass-through fees (appraisal, credit report, flood cert) | Timing: collected DURING period | Measures: SUM(fee_amount) - dollar only | Source: LOS/closing fee itemization (HUD/CD fee lines) with retained-vs-pass-through flag',
    N'Positive dollar', 0, N'312400', 31,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC700', N'HECM-Standard',
    N'Closed Loan Data - Reverse Mortgages',
    N'Reverse loans in HECM Standard category. Report full exposure amount.',
    N'Population: closed reverse mortgages this quarter | Filters: reverse_product = ''HECM Standard''; report FULL exposure amount (max claim / total line) | Timing: funded DURING period | Measures: SUM(exposure_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 1850000 | Cnt 6', 32,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC720', N'Proprietary/Other',
    N'Closed Loan Data - Reverse Mortgages',
    N'Reverse loans in any category other than HECM Standard or Saver. Report full exposure amount.',
    N'Population: closed reverse mortgages this quarter | Filters: reverse_product not in (''HECM Standard'',''HECM Saver''); report FULL exposure amount (max claim / total line) | Timing: funded DURING period | Measures: SUM(exposure_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 420000 | Cnt 1', 33,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC790', N'Total Loan Type - Reverse Mortgages',
    N'Closed Loan Data - Reverse Mortgages',
    N'Sum of AC700 to AC720 per column.',
    N'Calculated: AC700+AC720.',
    N'Amount: dollar; Count: whole number', 1, N'Retail: Amt 2270000 | Cnt 7', 34,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC800', N'Home Purchase (Reverse)',
    N'Closed Loan Data - Reverse Purpose',
    N'Reverse mortgages from AC700-AC720 with home purchase purpose.',
    N'Population: closed reverse mortgages this quarter | Filters: reverse purpose = ''Purchase''; report FULL exposure amount (max claim / total line) | Timing: funded DURING period | Measures: SUM(exposure_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 380000 | Cnt 1', 35,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC810', N'Other (Reverse)',
    N'Closed Loan Data - Reverse Purpose',
    N'Reverse mortgages from AC700-AC720 whose purpose was not home purchase.',
    N'Population: closed reverse mortgages this quarter | Filters: reverse purpose <> ''Purchase''; report FULL exposure amount (max claim / total line) | Timing: funded DURING period | Measures: SUM(exposure_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Retail: Amt 1890000 | Cnt 6', 36,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC890', N'Total Purpose of Reverse Mortgage',
    N'Closed Loan Data - Reverse Purpose',
    N'Sum of AC800 to AC810 per column.',
    N'Calculated: AC800+AC810. Must tie to AC790.',
    N'Amount: dollar; Count: whole number', 1, N'Retail: Amt 2270000 | Cnt 7', 37,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC620', N'Broker Fees Collected - Reverse Mortgages',
    N'Closed Loan Data - Fees',
    N'Gross broker fees collected on reverse mortgages. Exclude pass-through fees.',
    N'Population: gross broker fees on reverse mortgages collected this quarter | Filters: fee retained = Y AND fee_role = ''Broker'' AND product = reverse; EXCLUDE pass-through fees (appraisal, credit report, flood cert) | Timing: collected DURING period | Measures: SUM(fee_amount) - dollar only | Source: LOS/closing fee itemization (HUD/CD fee lines) with retained-vs-pass-through flag',
    N'Positive dollar', 0, N'6200', 38,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC630', N'Lender Fees Collected - Reverse Mortgages',
    N'Closed Loan Data - Fees',
    N'Gross lender fees collected on reverse mortgages. Exclude pass-through fees.',
    N'Population: gross lender fees on reverse mortgages collected this quarter | Filters: fee retained = Y AND fee_role = ''Lender'' AND product = reverse; EXCLUDE pass-through fees (appraisal, credit report, flood cert) | Timing: collected DURING period | Measures: SUM(fee_amount) - dollar only | Source: LOS/closing fee itemization (HUD/CD fee lines) with retained-vs-pass-through flag',
    N'Positive dollar', 0, N'14800', 39,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC900', N'Total Loans Brokered by your Company',
    N'Closed Loan Data - Totals',
    N'Total loans brokered in period (app taken by your company in any period, closed this period).',
    N'Population: loans you brokered (app taken any period, closed this period, funded by another) | Filters: column = brokered | Timing: closed DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 1400000 | Cnt 3', 40,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC910', N'Total Loans Funded by your Company',
    N'Closed Loan Data - Totals',
    N'Total loans funded in period.',
    N'Population: loans you funded (retail + wholesale + table funded) | Filters: funding_entity = your company | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 51770000 | Cnt 195', 41,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC920', N'Qualified Mortgage (QM)',
    N'Closed Loan Data - QM Status',
    N'Closed and funded loans that are QM under Reg Z 12 CFR 1026 (general definition, GSE/agency-eligible, or small creditor provision).',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: qm_status = ''QM'' (general / GSE-agency-eligible / small creditor); split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 49100000 | Cnt 179', 42,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC930', N'Non-Qualified Mortgage',
    N'Closed Loan Data - QM Status',
    N'Closed and funded loans that are non-QM; all loans not reported in AC920.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: qm_status = ''Non-QM''; split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 2900000 | Cnt 9', 43,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC940', N'Not Subject to QM',
    N'Closed Loan Data - QM Status',
    N'Closed and funded loans not subject to QM standards.',
    N'Population: closed+funded forward loans this quarter (reverse handled in AC700-890) | Filters: qm_status = ''Not Subject'' (e.g., investment-purpose exempt, HELOC, reverse); split by column: brokered / closed-retail / closed-wholesale | Timing: funded DURING period. Closed loans = executed legally binding agreement + funded (not necessarily by your company). Column logic: BROKERED = you took app, did not fund; CLOSED-RETAIL = took app AND funded; CLOSED-WHOLESALE = did not take app, did fund. | Measures: SUM(loan_amount), COUNT(loan_id) per column | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); funding source and app-taken flags drive column assignment',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 1170000 | Cnt 3', 44,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC990', N'Total Closed Loans',
    N'Closed Loan Data - QM Status',
    N'Sum of AC920 to AC940. Must equal AC070 and MLO data total.',
    N'Calculated: AC920+AC930+AC940. Completeness: must equal AC070 and MLO section total.',
    N'Amount: dollar; Count: whole number', 1, N'Amt 53170000 | Cnt 191', 45,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC1000', N'Loans Made and Assigned but Required to Repurchase in Period',
    N'Repurchase',
    N'Loans required to be repurchased during the period regardless of when made/assigned.',
    N'Population: loans repurchased this quarter (regardless of origination/assignment date) | Filters: repurchase_settlement_date within quarter; state = filing state | Timing: settled DURING period | Measures: SUM(repurchase_upb), COUNT(loan_id) | Source: repurchase demand tracking / investor claims system',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 487000 | Cnt 2', 46,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC1100', N'Gross Revenue from Mortgage Origination Operations',
    N'Revenue Data',
    N'All origination revenue received in this state during period, before expenses.',
    N'Population: gross mortgage origination revenue attributable to this state | Filters: revenue GL accounts tagged origination; state allocation by subject property state | Timing: earned DURING period, BEFORE expenses | Measures: SUM(revenue) | Source: GL + state allocation logic',
    N'Positive dollar', 0, N'1642000', 47,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC1200', N'Closed Loans with Servicing Retained During the Quarter',
    N'Servicing Disposition on Closed Loans',
    N'Closed/funded loans on which MSRs are intended to be retained, per intent at time loan made. Brokered loans excluded; non-funding brokers skip.',
    N'Population: funded loans with intent to RETAIN servicing | Filters: servicing_disposition_intent = ''Retained'' at time loan made; EXCLUDE brokered | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type); commitment/lock data',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 21500000 | Cnt 78', 48,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC1210', N'Closed Loans with Servicing Released During the Quarter',
    N'Servicing Disposition on Closed Loans',
    N'Closed/funded loans on which MSRs are intended to be sold, per intent at time loan made. Brokered loans excluded.',
    N'Population: funded loans with intent to RELEASE servicing | Filters: servicing_disposition_intent = ''Released'' at time loan made; EXCLUDE brokered | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS application/loan table (app_id, app_date, app_amount, action_code, action_date, channel, loan_purpose, loan_type, lien_position, property_type)',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 30270000 | Cnt 117', 49,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'AC1290', N'Servicing Disposition Total',
    N'Servicing Disposition on Closed Loans',
    N'Sum of AC1200 to AC1210. Must equal AC990 retail + wholesale columns.',
    N'Calculated: AC1200+AC1210. Completeness: must equal AC990 retail+wholesale columns.',
    N'Amount: dollar; Count: whole number', 1, N'Amt 51770000 | Cnt 195', 50,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'ACMLO1', N'MLO NMLS ID, Amount, Count',
    N'Mortgage Loan Originator Data',
    N'Per state-licensed MLO with originations: NMLS ID, amount, count of loans originated. NMLS retrieves legal name from ID. MLOs with no closed loans omitted.',
    N'Population: state-licensed MLOs with >= 1 closed loan this quarter | Filters: originating MLO on funded loans; state = filing state; omit zero-production MLOs | Timing: funded DURING period | Measures: per MLO: NMLS_ID, SUM(loan_amount), COUNT(loan_id); detail must sum to AC070/AC990 | Source: LOS originator assignment + NMLS ID crosswalk',
    N'MLO NMLS ID: positive whole number; Amount: positive dollar; Count: positive whole number', 0, N'1234567 | 8450000 | 31', 51,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecOne, N'ACNOTE', N'State-Specific Explanatory Note',
    N'Explanatory Notes',
    N'Free-text state-specific RMLA explanations. Permanent part of the MCR filing.',
    N'Free text. Required when AC063 <> 0; explain state-specific anomalies.',
    N'Free text', 0, N'AC063 reflects removal of 2 duplicate applications entered in error in Q4 2025.', 52,
    @LoadBatchId);

/* ---- RMLA_SEC2: items from sheet [RMLA Sec II] ---- */
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I010', N'Government (FHA/VA/RHS) Fixed',
    N'Residential First Mortgages (1-4 Unit)',
    N'Government guaranteed/insured (FHA/VA/RHS incl. bond/state assisted) fixed-rate loans.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: loan_type in (FHA,VA,RHS,bond/state-assisted) AND rate_type = ''Fixed'' | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 14200000 | Cnt 58', 1,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I020', N'Government (FHA/VA/RHS) ARM',
    N'Residential First Mortgages (1-4 Unit)',
    N'Government guaranteed/insured adjustable-rate loans. HECMs reported in I130.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: loan_type in (FHA,VA,RHS) AND rate_type = ''ARM'' (HECM ARMs go to I130) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 900000 | Cnt 3', 2,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I030', N'Conventional Conforming Fixed',
    N'Residential First Mortgages (1-4 Unit)',
    N'GSE-eligible (FNMA/FHLMC) fixed-rate first mortgages. Excludes FHA/VA.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: conventional AND conforming (GSE-eligible) AND rate_type = ''Fixed'' | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 24700000 | Cnt 91', 3,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I040', N'Conventional Conforming ARM',
    N'Residential First Mortgages (1-4 Unit)',
    N'GSE-eligible adjustable-rate first mortgages. Excludes FHA/VA.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: conventional AND conforming AND rate_type = ''ARM'' | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 2100000 | Cnt 6', 4,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I050', N'Conventional Non-Conforming (Jumbo) Fixed',
    N'Residential First Mortgages (1-4 Unit)',
    N'Non Alt-A/non-prime loans exceeding FNMA/FHLMC limits, fixed rate.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: conventional AND amount > GSE limit AND credit_grade prime AND ''Fixed'' | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 4300000 | Cnt 4', 5,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I060', N'Conventional Non-Conforming (Jumbo) ARM',
    N'Residential First Mortgages (1-4 Unit)',
    N'Non Alt-A/non-prime loans exceeding FNMA/FHLMC limits, adjustable rate.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: conventional AND amount > GSE limit AND credit_grade prime AND ''ARM'' | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 1200000 | Cnt 1', 6,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I070', N'Other Fixed',
    N'Residential First Mortgages (1-4 Unit)',
    N'All other fixed-rate firsts incl. Alt-A and non-prime (<620 FICO, high LTV, limited doc).',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: all other firsts (Alt-A, non-prime <620 FICO) AND ''Fixed'' | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 2600000 | Cnt 11', 7,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I080', N'Other ARM',
    N'Residential First Mortgages (1-4 Unit)',
    N'All other ARM firsts incl. Alt-A and non-prime.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: all other firsts (Alt-A, non-prime) AND ''ARM'' | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 400000 | Cnt 2', 8,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I100', N'Total Residential First Mortgages',
    N'Residential First Mortgages (1-4 Unit)',
    N'Sum of I010 to I080 per column.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 50400000 | Cnt 176', 9,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I110', N'Closed-End Second Mortgages',
    N'Other Mortgages',
    N'Subordinate-rights mortgages, fixed and ARM. Excludes lines of credit.',
    N'Population: other mortgages originated this period | Filters: closed-end second liens (fixed + ARM); exclude lines of credit | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 850000 | Cnt 6', 10,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I120', N'HELOCs',
    N'Other Mortgages',
    N'Home equity lines permitting cash advances against approved limit. Report max credit amount.',
    N'Population: other mortgages originated this period | Filters: HELOCs; amount = MAX approved credit line | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 1400000 | Cnt 8', 11,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I130', N'Reverse Mortgages',
    N'Other Mortgages',
    N'Home equity loans for homeowners 62+, lump sum/regular payments/LOC, no repayment while principal residence. Includes HECM.',
    N'Population: other mortgages originated this period | Filters: reverse mortgages incl. HECM (borrower 62+) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 2270000 | Cnt 7', 12,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I140', N'Construction Loans, 1-4 Unit Residential',
    N'Other Mortgages',
    N'1-4 unit construction-to-permanent loans to home buyers.',
    N'Population: other mortgages originated this period | Filters: 1-4 unit construction-to-perm to home buyers | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 1900000 | Cnt 5', 13,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I170', N'Other Residential Mortgage Loans',
    N'Other Mortgages',
    N'All other mortgages not reported above.',
    N'Population: other mortgages originated this period | Filters: all other mortgages not classified above | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 350000 | Cnt 2', 14,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I180', N'Total Other Mortgage Loans',
    N'Other Mortgages',
    N'Sum of I110 to I170 per column.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 6770000 | Cnt 28', 15,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I200', N'Total Mortgage Loans Originated',
    N'Totals',
    N'Sum of I100 and I180. Must equal retail+wholesale columns of AC190 and AC790.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 57170000 | Cnt 204', 16,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I210', N'Retail',
    N'Origination Channel (Firsts Only)',
    N'Loans in I100 originated through retail channel (employee LOs, branch network, direct sales incl. internet/telemarketing/direct mail).',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: channel = ''Retail'' (employee LOs, branches, direct/internet/telemarketing/mail) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 42800000 | Cnt 151', 17,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I220', N'Table Funded',
    N'Origination Channel (Firsts Only)',
    N'Loans in I100 where you provided closing funds; originated and closed in another company''s name, assigned to you.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: channel = ''Table Funded'' (closed in other company''s name with your funds, assigned to you) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 2100000 | Cnt 7', 18,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I230', N'Wholesale Brokered',
    N'Origination Channel (Firsts Only)',
    N'Loans in I100 obtained from mortgage brokers; broker-originated, funded by you.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: channel = ''Wholesale'' (broker-originated, you funded) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 5500000 | Cnt 18', 19,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I240', N'Total Residential First Mortgages',
    N'Origination Channel (Firsts Only)',
    N'Sum of I210 to I230. Must equal I100.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 50400000 | Cnt 176', 20,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I250', N'Fixed Rate',
    N'Rate Type (Firsts Only)',
    N'Fixed-rate 1-4 unit loans. Auto-sum of fixed rows (I010+I030+I050+I070).',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: rate_type = ''Fixed'' (auto: I010+I030+I050+I070) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 45800000 | Cnt 164', 21,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I251', N'ARM',
    N'Rate Type (Firsts Only)',
    N'ARM 1-4 unit loans incl. fixed-period ARMs, two-step, adjustable IO. Auto-sum of ARM rows.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: rate_type = ''ARM'' incl. fixed-period ARMs, two-step, adjustable IO (auto: ARM rows) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 4600000 | Cnt 12', 22,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I259', N'Total Residential First Mortgages',
    N'Rate Type (Firsts Only)',
    N'Sum of I250 and I251. Must equal I100.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 50400000 | Cnt 176', 23,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I260', N'Jumbo',
    N'Jumbo Status (Firsts Only)',
    N'First liens exceeding FNMA/FHLMC conforming limits; all jumbos (agency-eligible, Alt-A, subprime). >= I050+I060.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: amount > GSE conforming limit (ALL jumbos: agency-eligible, Alt-A, subprime); >= I050+I060 | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 5500000 | Cnt 5', 24,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I261', N'Non-Jumbo',
    N'Jumbo Status (Firsts Only)',
    N'First liens not exceeding conforming limits.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: amount <= GSE conforming limit | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 44900000 | Cnt 171', 25,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I269', N'Total Residential First Mortgages',
    N'Jumbo Status (Firsts Only)',
    N'Sum of I260 and I261. Must equal I100.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 50400000 | Cnt 176', 26,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I270', N'Alt Doc',
    N'Documentation (Firsts Only)',
    N'Reduced-doc loans without full income/asset documentation (SISA, stated income, NINA).',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: doc_type reduced (Stated/SISA/NINA) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 1600000 | Cnt 5', 27,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I271', N'Full Doc',
    N'Documentation (Firsts Only)',
    N'Loans with full income and asset documentation.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: doc_type = ''Full'' | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 48800000 | Cnt 171', 28,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I279', N'Total Residential First Mortgages',
    N'Documentation (Firsts Only)',
    N'Sum of I270 and I271. Must equal I100.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 50400000 | Cnt 176', 29,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I280', N'Interest Only',
    N'Interest Only (Firsts Only)',
    N'Loans with initial IO period converting to amortizing P&I; rate fixed or adjustable.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: io_flag = Y (initial IO period then amortizing) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 900000 | Cnt 2', 30,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I281', N'Not Interest Only',
    N'Interest Only (Firsts Only)',
    N'Loans not meeting I280 definition.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: io_flag = N | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 49500000 | Cnt 174', 31,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I289', N'Total Residential First Mortgages',
    N'Interest Only (Firsts Only)',
    N'Sum of I280 and I281. Must equal I100.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 50400000 | Cnt 176', 32,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I290', N'Option ARMs',
    N'Option ARM (Firsts Only)',
    N'Flexible payment-option loans (min payment / IO / 30-yr P&I / 15-yr P&I); Pick-a-Payment, Pay Option ARM, etc.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: product = Option ARM (payment-option: min/IO/30P&I/15P&I) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 0 | Cnt 0', 33,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I291', N'Not Option ARMs',
    N'Option ARM (Firsts Only)',
    N'Loans not meeting I290 definition.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: not Option ARM | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 50400000 | Cnt 176', 34,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I299', N'Total Residential First Mortgages',
    N'Option ARM (Firsts Only)',
    N'Sum of I290 and I291. Must equal I100.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 50400000 | Cnt 176', 35,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I300', N'Loans with Prepayment Penalties',
    N'Prepayment Penalty (Firsts Only)',
    N'Loans requiring penalty if paid off before a specified date.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: prepay_penalty_flag = Y | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 700000 | Cnt 2', 36,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I301', N'Loans without Prepayment Penalties',
    N'Prepayment Penalty (Firsts Only)',
    N'Loans with no prepayment penalty.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: prepay_penalty_flag = N | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 49700000 | Cnt 174', 37,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I309', N'Total Residential First Mortgages',
    N'Prepayment Penalty (Firsts Only)',
    N'Sum of I300 and I301. Must equal I100.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 50400000 | Cnt 176', 38,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I310', N'Purchase',
    N'Purpose Detail (Firsts Only)',
    N'Loans for borrower purchase.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: purpose = ''Purchase'' | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 36100000 | Cnt 127', 39,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I311', N'Refinance Rate-Term',
    N'Purpose Detail (Firsts Only)',
    N'Rate-term refinance loans.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: purpose = ''Refi Rate-Term'' | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 7200000 | Cnt 25', 40,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I312', N'Refinance Cash-Out',
    N'Purpose Detail (Firsts Only)',
    N'Cash-out refinance loans.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: purpose = ''Refi Cash-Out'' | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 5900000 | Cnt 20', 41,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I313', N'Refinance Restructure',
    N'Purpose Detail (Firsts Only)',
    N'Refinances for restructuring loan terms (rate, amortization period, etc.).',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: purpose = ''Refi Restructure'' (term/rate/amortization change) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 800000 | Cnt 3', 42,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I314', N'Refinance Other/Unknown',
    N'Purpose Detail (Firsts Only)',
    N'Refinances for other or unknown purposes.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: purpose = ''Refi Other/Unknown'' | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 400000 | Cnt 1', 43,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I319', N'Total Residential First Mortgages',
    N'Purpose Detail (Firsts Only)',
    N'Sum of I310 through I314. Must equal I100.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 50400000 | Cnt 176', 44,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I330', N'Loans with Mortgage Insurance',
    N'Mortgage Insurance (Firsts Only)',
    N'Loans insured with MI.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: mi_flag = Y | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 12800000 | Cnt 51', 45,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I331', N'Loans without Mortgage Insurance',
    N'Mortgage Insurance (Firsts Only)',
    N'Loans not insured with MI.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: mi_flag = N | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 37600000 | Cnt 125', 46,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I339', N'Total Residential First Mortgages',
    N'Mortgage Insurance (Firsts Only)',
    N'Sum of I330 and I331. Must equal I100.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 50400000 | Cnt 176', 47,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I340', N'Loans with Piggyback Seconds',
    N'Piggyback (Firsts Only)',
    N'Firsts with simultaneous subordinate piggyback seconds (usually to avoid MI). Excludes HELOCs.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: simultaneous piggyback second exists (exclude HELOC piggybacks) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 1100000 | Cnt 4', 48,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I341', N'Loans without Piggyback Seconds',
    N'Piggyback (Firsts Only)',
    N'Firsts without piggyback seconds.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: no piggyback second | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 49300000 | Cnt 172', 49,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I349', N'Total Residential First Mortgages',
    N'Piggyback (Firsts Only)',
    N'Sum of I340 and I341. Must equal I100.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 50400000 | Cnt 176', 50,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I370', N'LTV <= 60%',
    N'First Mortgage LTV Distribution',
    N'Loans with LTV equal to or less than 60%.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: orig LTV <= 60 | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 4900000 | Cnt 21', 51,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I371', N'LTV > 60% and <= 70%',
    N'First Mortgage LTV Distribution',
    N'Loans with LTV >60% and <=70%.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: orig LTV > 60 AND <= 70 | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 6300000 | Cnt 24', 52,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I372', N'LTV > 70% and <= 80%',
    N'First Mortgage LTV Distribution',
    N'Loans with LTV >70% and <=80%.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: orig LTV > 70 AND <= 80 | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 17200000 | Cnt 57', 53,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I373', N'LTV > 80% and <= 90%',
    N'First Mortgage LTV Distribution',
    N'Loans with LTV >80% and <=90%.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: orig LTV > 80 AND <= 90 | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 9600000 | Cnt 33', 54,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I374', N'LTV > 90% and <= 100%',
    N'First Mortgage LTV Distribution',
    N'Loans with LTV >90% and <=100%.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: orig LTV > 90 AND <= 100 | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 12000000 | Cnt 40', 55,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I375', N'LTV > 100%',
    N'First Mortgage LTV Distribution',
    N'Loans with LTV greater than 100%.',
    N'Population: 1-4 unit residential FIRST mortgages originated this period (subset of I100) | Filters: orig LTV > 100 | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 400000 | Cnt 1', 56,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I379', N'Total First Mortgage Volume',
    N'First Mortgage LTV Distribution',
    N'Sum of I370 to I375. Must equal I100.',
    N'Calculated total; each stratification block must foot to I100 (I200 must equal AC190+AC790 retail+wholesale).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 50400000 | Cnt 176', 57,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I380', N'Weighted Average LTV on First Mortgages',
    N'Weighted Averages',
    N'Dollar-weighted average LTV of first-lien originations.',
    N'Population: first-lien originations | Filters: none | Timing: at origination | Measures: SUMPRODUCT(ltv, loan_amount)/SUM(loan_amount), 2 decimals | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'Two-decimal number (87.65 = 87.645%)', 0, N'81.42', 58,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I385', N'Weighted Average CLTV Combined First and Second',
    N'Weighted Averages',
    N'Dollar-weighted average CLTV of all first-lien and second mortgage loans.',
    N'Population: first + second lien originations | Filters: none | Timing: at origination | Measures: dollar-weighted CLTV, 2 decimals | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'Two-decimal number', 0, N'83.17', 59,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I390', N'Weighted Average Coupon at Origination on Firsts',
    N'Weighted Averages',
    N'Dollar-weighted gross note rate of first mortgage originations during period.',
    N'Population: first-lien originations | Filters: none | Timing: at origination | Measures: SUMPRODUCT(note_rate, loan_amount)/SUM(loan_amount), 2 decimals | Source: LOS closed-loan table with product attributes (loan_type, amortization_type, conforming_flag, doc_type, io_flag, ltv, cltv, note_rate, channel, mi_flag)',
    N'Two-decimal number (6.78 = 6.775%)', 0, N'6.62', 60,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I400', N'Production Sold to Secondary Market Agencies',
    N'First Mortgages Sold by Investor Type',
    N'Loans sold to FNMA/FHLMC/GNMA or with agency guarantee; sold this period regardless of origination quarter.',
    N'Population: 1-4 unit loans SOLD this period (any origination quarter) | Filters: sale_investor in (FNMA,FHLMC,GNMA) or agency-guaranteed execution | Timing: sale settlement DURING period | Measures: SUM(sale_upb), COUNT(loan_id) | Source: secondary marketing commitment/sale tables (trade_id, investor, settle_date, servicing_disposition)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 31200000 | Cnt 118', 61,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I401', N'Production Sold to Others (Non-Affiliate)',
    N'First Mortgages Sold by Investor Type',
    N'Loans sold to unaffiliated wholesalers/brokers/correspondents/conduits. Excludes servicing-released sales in I410.',
    N'Population: 1-4 unit loans SOLD this period (any origination quarter) | Filters: sold to unaffiliated wholesalers/brokers/correspondents/conduits (exclude servicing-released -> I410) | Timing: sale settlement DURING period | Measures: SUM(sale_upb), COUNT(loan_id) | Source: secondary marketing commitment/sale tables (trade_id, investor, settle_date, servicing_disposition)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 8400000 | Cnt 30', 62,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I402', N'Production Sold to Others (Affiliate)',
    N'First Mortgages Sold by Investor Type',
    N'Loans sold to affiliated companies. Excludes servicing-released sales in I410.',
    N'Population: 1-4 unit loans SOLD this period (any origination quarter) | Filters: sold to affiliates (exclude servicing-released -> I410) | Timing: sale settlement DURING period | Measures: SUM(sale_upb), COUNT(loan_id) | Source: secondary marketing commitment/sale tables (trade_id, investor, settle_date, servicing_disposition)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 0 | Cnt 0', 63,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I404', N'Sold through Non-Agency Securitizations with Sale Treatment',
    N'First Mortgages Sold by Investor Type',
    N'Non-agency securitizations achieving FAS 140 sale treatment.',
    N'Population: 1-4 unit loans SOLD this period (any origination quarter) | Filters: non-agency securitization WITH FAS 140 sale treatment | Timing: sale settlement DURING period | Measures: SUM(sale_upb), COUNT(loan_id) | Source: secondary marketing commitment/sale tables (trade_id, investor, settle_date, servicing_disposition)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 0 | Cnt 0', 64,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I405', N'Sold through Non-Agency Securitizations without Sale Treatment',
    N'First Mortgages Sold by Investor Type',
    N'Non-agency securitizations without FAS 140 sale treatment; accounted for as financings.',
    N'Population: 1-4 unit loans SOLD this period (any origination quarter) | Filters: non-agency securitization WITHOUT sale treatment (financing) | Timing: sale settlement DURING period | Measures: SUM(sale_upb), COUNT(loan_id) | Source: secondary marketing commitment/sale tables (trade_id, investor, settle_date, servicing_disposition)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 0 | Cnt 0', 65,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I409', N'Total 1-4 Unit Residential Loans Sold this Period',
    N'First Mortgages Sold by Investor Type',
    N'Sum of I400, I401, I402, I404, I405 per column.',
    N'Calculated: I400+I401+I402+I404+I405.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'Amt 39600000 | Cnt 148', 66,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I410', N'Production Sold Servicing Released',
    N'Other 1-4 Unit Residential Information',
    N'Loans sold with servicing released.',
    N'Population: 1-4 unit loans SOLD this period (any origination quarter) | Filters: sold servicing released | Timing: sale settlement DURING period | Measures: SUM(sale_upb), COUNT(loan_id) | Source: secondary marketing commitment/sale tables (trade_id, investor, settle_date, servicing_disposition)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 28900000 | Cnt 110', 67,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I421', N'Production Kept in Portfolio/Held for Investment',
    N'Other 1-4 Unit Residential Information',
    N'Loans kept in portfolio or held for investment.',
    N'Population: 1-4 unit loans designated HFI this period | Filters: retained in portfolio / HFI designation | Timing: sale settlement DURING period | Measures: SUM(sale_upb), COUNT(loan_id) | Source: secondary marketing commitment/sale tables (trade_id, investor, settle_date, servicing_disposition)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 3200000 | Cnt 13', 68,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I430', N'Pull-Through Ratio',
    N'Other 1-4 Unit Residential Information',
    N'Closings count divided by applications count during period.',
    N'Population: closings vs applications | Filters: none | Timing: period ratio | Measures: COUNT(closings)/COUNT(applications) x 100, 2 decimals | Source: AC070 count / AC020 count',
    N'Two-decimal number (67.55 = 67.545%)', 0, N'77.33', 69,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I450', N'Average Days in Warehouse (1-4 Unit Only)',
    N'Warehouse Period',
    N'Average days loans were warehoused before investor sale. HFS loans only.',
    N'Population: HFS loans sold to investors this period | Filters: HFS only | Timing: days from funding to investor sale | Measures: AVG(sale_date - funding_date), whole days | Source: warehouse aging report',
    N'Positive whole number', 0, N'23', 70,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecTwo, N'I460', N'Production Warehoused in Excess of 90 Days at Period End',
    N'Warehouse Period',
    N'Principal balance and count of loans in warehouse >90 days at period end before investor sale.',
    N'Population: HFS loans in warehouse > 90 days | Filters: days_in_warehouse > 90 AND not yet sold | Timing: as of period end | Measures: SUM(upb), COUNT(loan_id) | Source: warehouse aging report',
    N'UPB: positive dollar; Count: positive whole number', 0, N'Amt 640000 | Cnt 2', 71,
    @LoadBatchId);

/* ---- RMLA_SEC3: items from sheet [RMLA Sec III] ---- */
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S100', N'Loan Modification Applications in Process at Beginning of Period',
    N'Modifications - Contracted by Lienholder/Servicer',
    N'Mods on loans you do NOT hold or service. UPB and count in process at period start.',
    N'Population: mod applications in process at period start - LOANS YOU DO NOT HOLD OR SERVICE (contracted for by lienholder/servicer) | Filters: open mod apps as of prior period end | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 3400000 | Cnt 14', 1,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S150', N'Loan Modification Applications Received During Period',
    N'Modifications - Contracted by Lienholder/Servicer',
    N'Mod applications received during period.',
    N'Population: mod applications received during period - LOANS YOU DO NOT HOLD OR SERVICE (contracted for by lienholder/servicer) | Filters: received_date within quarter | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 2100000 | Cnt 9', 2,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S130', N'Loan Modification Applications Denied by Lender/Servicer',
    N'Modifications - Contracted by Lienholder/Servicer',
    N'Mod applications denied during period.',
    N'Population: mod applications denied - LOANS YOU DO NOT HOLD OR SERVICE (contracted for by lienholder/servicer) | Filters: decision = ''Denied'' within quarter | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 800000 | Cnt 3', 3,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S120', N'Loan Modification Applications Terminated by Borrower',
    N'Modifications - Contracted by Lienholder/Servicer',
    N'Mod applications terminated by borrower during period.',
    N'Population: mod applications terminated by borrower - LOANS YOU DO NOT HOLD OR SERVICE (contracted for by lienholder/servicer) | Filters: termination_source = ''Borrower'' within quarter | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 500000 | Cnt 2', 4,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S140', N'Loan Modification Applications Terminated by Other',
    N'Modifications - Contracted by Lienholder/Servicer',
    N'Mod applications terminated by other party during period.',
    N'Population: mod applications terminated by other - LOANS YOU DO NOT HOLD OR SERVICE (contracted for by lienholder/servicer) | Filters: termination_source = ''Other'' within quarter | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 200000 | Cnt 1', 5,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S110', N'Loan Modifications Completed (non-HAMP)',
    N'Modifications - Contracted by Lienholder/Servicer',
    N'Non-HAMP mods completed during period.',
    N'Population: non-HAMP mods completed - LOANS YOU DO NOT HOLD OR SERVICE (contracted for by lienholder/servicer) | Filters: completed within quarter AND hamp_flag = N | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 1900000 | Cnt 8', 6,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S115', N'Mortgage Loans Modified Under HAMP',
    N'Modifications - Contracted by Lienholder/Servicer',
    N'HAMP mods completed during period.',
    N'Population: HAMP mods completed - LOANS YOU DO NOT HOLD OR SERVICE (contracted for by lienholder/servicer) | Filters: completed within quarter AND hamp_flag = Y | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 0 | Cnt 0', 7,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S160', N'Loan Modification Applications in Process at End of Period',
    N'Modifications - Contracted by Lienholder/Servicer',
    N'Mod applications in process at period end.',
    N'Population: mod applications in process at period end - LOANS YOU DO NOT HOLD OR SERVICE (contracted for by lienholder/servicer) | Filters: open mod apps as of period end | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 2100000 | Cnt 9', 8,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S170', N'Net Changes in Loan Modification Amount',
    N'Modifications - Contracted by Lienholder/Servicer',
    N'Rectifies loan amount changes during period; negative aggregate entered negative.',
    N'Net loan-amount changes during period on the S100-S160 population; negative allowed.',
    N'Dollar (may be negative)', 0, N'-115000', 9,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S200', N'Loans to be Modified at Beginning of Period',
    N'Modifications - Loans You Hold or Service',
    N'Mods on loans you hold or service. UPB and count pending at period start.',
    N'Population: pending mods at period start - LOANS YOU HOLD OR SERVICE | Filters: per description | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 5800000 | Cnt 24', 10,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S210', N'Loan Modifications Completed',
    N'Modifications - Loans You Hold or Service',
    N'Mods completed during period.',
    N'Population: mods completed during period - LOANS YOU HOLD OR SERVICE | Filters: per description | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 2700000 | Cnt 11', 11,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S220', N'Loan Modification Attempts Terminated',
    N'Modifications - Loans You Hold or Service',
    N'Mod attempts terminated for any reason during period.',
    N'Population: mod attempts terminated (any reason) during period - LOANS YOU HOLD OR SERVICE | Filters: per description | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 1200000 | Cnt 5', 12,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S230', N'New Loans Received for Modification',
    N'Modifications - Loans You Hold or Service',
    N'New loans received for modification during period.',
    N'Population: new loans received for modification during period - LOANS YOU HOLD OR SERVICE | Filters: per description | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 3100000 | Cnt 13', 13,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S240', N'Loans to be Modified at End of Period',
    N'Modifications - Loans You Hold or Service',
    N'Loans pending modification at period end.',
    N'Population: pending mods at period end - LOANS YOU HOLD OR SERVICE | Filters: per description | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: loss mitigation / mod workflow tables (mod_app_id, received_date, decision_code, decision_date, completed_date, hamp_flag)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 5000000 | Cnt 21', 14,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S270', N'Net Changes in Loan Modification Amount',
    N'Modifications - Loans You Hold or Service',
    N'Rectifies loan amount changes during period; negative aggregate entered negative.',
    N'Net loan-amount changes during period on the S200-S240 population; negative allowed.',
    N'Dollar (may be negative)', 0, N'-84000', 15,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S300', N'Current Loans',
    N'Payment Status (All Loans)',
    N'UPB and count of serviced loans that are current.',
    N'Population: all serviced loans in this state | Filters: current: DPD < 30 | Timing: AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); mod history for the modified-loan blocks',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 296400000 | Cnt 1291', 16,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S305', N'30 to 59 Days Delinquent',
    N'Payment Status (All Loans)',
    N'Serviced loans 30-59 days delinquent.',
    N'Population: all serviced loans in this state | Filters: DPD 30-59 | Timing: AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); mod history for the modified-loan blocks',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 10400000 | Cnt 51', 17,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S310', N'60 to 89 Days Delinquent',
    N'Payment Status (All Loans)',
    N'Serviced loans 60-89 days delinquent.',
    N'Population: all serviced loans in this state | Filters: DPD 60-89 | Timing: AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); mod history for the modified-loan blocks',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 4300000 | Cnt 22', 18,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S315', N'90+ Days Delinquent',
    N'Payment Status (All Loans)',
    N'Serviced loans 90+ days delinquent.',
    N'Population: all serviced loans in this state | Filters: DPD >= 90 | Timing: AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); mod history for the modified-loan blocks',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 4400000 | Cnt 18', 19,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S319', N'Total Loans Serviced',
    N'Payment Status (All Loans)',
    N'Sum of S300 to S315 per column.',
    N'Calculated bucket total per column.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 315500000 | Cnt 1382', 20,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S320', N'Current Loans',
    N'Payment Status (Modified Within 1 Year)',
    N'Current serviced loans modified within last 12 months.',
    N'Population: serviced loans MODIFIED within last 12 months | Filters: mod_completed_date within trailing 12 months AND current: DPD < 30 | Timing: AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); mod history for the modified-loan blocks',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 2600000 | Cnt 11', 21,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S325', N'30 to 59 Days Delinquent',
    N'Payment Status (Modified Within 1 Year)',
    N'Loans modified within 12 months, 30-59 days delinquent.',
    N'Population: serviced loans MODIFIED within last 12 months | Filters: mod_completed_date within trailing 12 months AND DPD 30-59 | Timing: AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); mod history for the modified-loan blocks',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 700000 | Cnt 3', 22,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S330', N'60 to 89 Days Delinquent',
    N'Payment Status (Modified Within 1 Year)',
    N'Loans modified within 12 months, 60-89 days delinquent.',
    N'Population: serviced loans MODIFIED within last 12 months | Filters: mod_completed_date within trailing 12 months AND DPD 60-89 | Timing: AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); mod history for the modified-loan blocks',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 300000 | Cnt 1', 23,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S335', N'90+ Days Delinquent',
    N'Payment Status (Modified Within 1 Year)',
    N'Loans modified within 12 months, 90+ days delinquent.',
    N'Population: serviced loans MODIFIED within last 12 months | Filters: mod_completed_date within trailing 12 months AND DPD >= 90 | Timing: AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); mod history for the modified-loan blocks',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 250000 | Cnt 1', 24,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S339', N'Total Loans Serviced (Modified Within 1 Year)',
    N'Payment Status (Modified Within 1 Year)',
    N'Sum of S320 to S335 per column.',
    N'Calculated bucket total per column.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 3850000 | Cnt 16', 25,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S340', N'Current Loans',
    N'Payment Status (Modified Over 1 Year Ago)',
    N'Current serviced loans modified more than 12 months ago.',
    N'Population: serviced loans MODIFIED more than 12 months ago | Filters: mod_completed_date older than 12 months AND current: DPD < 30 | Timing: AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); mod history for the modified-loan blocks',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 4900000 | Cnt 22', 26,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S345', N'30 to 59 Days Delinquent',
    N'Payment Status (Modified Over 1 Year Ago)',
    N'Loans modified >12 months ago, 30-59 days delinquent.',
    N'Population: serviced loans MODIFIED more than 12 months ago | Filters: mod_completed_date older than 12 months AND DPD 30-59 | Timing: AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); mod history for the modified-loan blocks',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 900000 | Cnt 4', 27,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S350', N'60 to 89 Days Delinquent',
    N'Payment Status (Modified Over 1 Year Ago)',
    N'Loans modified >12 months ago, 60-89 days delinquent.',
    N'Population: serviced loans MODIFIED more than 12 months ago | Filters: mod_completed_date older than 12 months AND DPD 60-89 | Timing: AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); mod history for the modified-loan blocks',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 400000 | Cnt 2', 28,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S355', N'90+ Days Delinquent',
    N'Payment Status (Modified Over 1 Year Ago)',
    N'Loans modified >12 months ago, 90+ days delinquent.',
    N'Population: serviced loans MODIFIED more than 12 months ago | Filters: mod_completed_date older than 12 months AND DPD >= 90 | Timing: AS OF period end date | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); mod history for the modified-loan blocks',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 350000 | Cnt 2', 29,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S359', N'Total Loans Serviced (Modified Over 1 Year Ago)',
    N'Payment Status (Modified Over 1 Year Ago)',
    N'Sum of S340 to S355 per column.',
    N'Calculated bucket total per column.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 6550000 | Cnt 30', 30,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S400', N'In Foreclosure Status as of Last Period End Date',
    N'Foreclosure Status',
    N'Serviced loans in foreclosure at prior period end.',
    N'Population: in foreclosure at PRIOR period end | Filters: fcl_status = active as of prior period end | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: foreclosure/REO workflow tables',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 2800000 | Cnt 12', 31,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S410', N'Moved into Foreclosure Status in Period',
    N'Foreclosure Status',
    N'Serviced loans entering foreclosure during period.',
    N'Population: moved into foreclosure during period | Filters: fcl_referral/first_legal_date within quarter | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: foreclosure/REO workflow tables',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 1100000 | Cnt 5', 32,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S420', N'Foreclosure Resolved Other Than Sheriff Sale in Period',
    N'Foreclosure Status',
    N'Foreclosures resolved by means other than sheriff sale.',
    N'Population: foreclosure resolved other than sheriff sale | Filters: fcl_removed within quarter, resolution <> ''Sheriff Sale'' (reinstated, mod, paid off) | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: foreclosure/REO workflow tables',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 900000 | Cnt 4', 33,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S430', N'Foreclosure Resulting in Sheriff Sale in Period',
    N'Foreclosure Status',
    N'Foreclosures completed via sheriff sale.',
    N'Population: foreclosure completed via sheriff sale | Filters: sheriff_sale_date within quarter | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: foreclosure/REO workflow tables',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 500000 | Cnt 2', 34,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S440', N'In Foreclosure Status as of End Date',
    N'Foreclosure Status',
    N'S400 + S410 - S420 - S430 per column.',
    N'Calculated: S400 + S410 - S420 - S430.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 2500000 | Cnt 11', 35,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S450', N'REOs as of End Date',
    N'Foreclosure Status',
    N'UPB and count of real estate owned at period end.',
    N'Population: REO inventory | Filters: REO status as of period end | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: foreclosure/REO workflow tables',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 620000 | Cnt 3', 36,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S460', N'Loans Paid Through Short Sale',
    N'Foreclosure Status',
    N'Loans paid via short sale during quarter.',
    N'Population: short sale payoffs | Filters: payoff_type = ''Short Sale'' within quarter | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: foreclosure/REO workflow tables',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 310000 | Cnt 2', 37,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S470', N'Loans in Forbearance at Beginning of Period',
    N'Forbearance',
    N'Loans in forbearance at period start.',
    N'Population: state-level serviced loans with forbearance activity: forbearance snapshot at period start | Filters: same logic as LS1500-LS1540 but filtered to filing state | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: forbearance plan tables',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 2400000 | Cnt 10', 38,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S471', N'Loans Entering Forbearance During Period',
    N'Forbearance',
    N'Loans entering forbearance during period.',
    N'Population: state-level serviced loans with forbearance activity: entered during period | Filters: same logic as LS1500-LS1540 but filtered to filing state | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: forbearance plan tables',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 800000 | Cnt 4', 39,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S472', N'Exiting Forbearance - Resuming Contractual Payment',
    N'Forbearance',
    N'Loans exiting forbearance and resuming contractual payment.',
    N'Population: state-level serviced loans with forbearance activity: exited -> resumed contractual | Filters: same logic as LS1500-LS1540 but filtered to filing state | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: forbearance plan tables',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 900000 | Cnt 4', 40,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S473', N'Exiting Forbearance - Entering Loss Mitigation',
    N'Forbearance',
    N'Loans exiting forbearance into loss mitigation.',
    N'Population: state-level serviced loans with forbearance activity: exited -> loss mitigation | Filters: same logic as LS1500-LS1540 but filtered to filing state | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: forbearance plan tables',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 500000 | Cnt 2', 41,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S474', N'Exiting Forbearance - Entering Foreclosure',
    N'Forbearance',
    N'Loans exiting forbearance into foreclosure.',
    N'Population: state-level serviced loans with forbearance activity: exited -> foreclosure | Filters: same logic as LS1500-LS1540 but filtered to filing state | Timing: per description | Measures: SUM(upb), COUNT(loan_id) | Source: forbearance plan tables',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 150000 | Cnt 1', 42,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S510', N'Wholly Owned Loans Serviced',
    N'Servicing Activity (State)',
    N'State-level UPB and count of loans serviced with full ownership.',
    N'Population: serviced loans in filing state | Filters: servicing_type = ''Wholly Owned'' AND property_state = filing state | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 37500000 | Cnt 163', 43,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S520', N'Loans Serviced Under MSRs',
    N'Servicing Activity (State)',
    N'Loans serviced where only MSRs owned. Report owner of loan, not MSR owner.',
    N'Population: serviced loans in filing state | Filters: servicing_type = ''MSR Owned'' - report LOAN owner, not MSR owner AND property_state = filing state | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 248000000 | Cnt 1073', 44,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S530', N'Subservicing for Others',
    N'Servicing Activity (State)',
    N'Loans subserviced on behalf of others.',
    N'Population: serviced loans in filing state | Filters: servicing_type = ''Subservicing for Others'' AND property_state = filing state | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 19200000 | Cnt 89', 45,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S540', N'Subservicing by Others',
    N'Servicing Activity (State)',
    N'Wholly owned/MSR-owned loans subserviced by a contracted third party.',
    N'Population: serviced loans in filing state | Filters: servicing_type = ''Subserviced by Others'' AND property_state = filing state | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 10800000 | Cnt 57', 46,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S590', N'Total Loans Serviced',
    N'Servicing Activity (State)',
    N'Sum of S510 to S540 per column.',
    N'Calculated: S510+...+S540. State-level analog of LS090.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 315500000 | Cnt 1382', 47,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S600', N'Fixed Loans Serviced',
    N'Rate Type on Loans Serviced',
    N'All serviced loans (incl. serviced for others) with fixed rate.',
    N'Population: ALL serviced loans in state incl. serviced for others | Filters: rate_type = ''Fixed'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 287100000 | Cnt 1269', 48,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S610', N'ARM Loans Serviced',
    N'Rate Type on Loans Serviced',
    N'All serviced loans with adjustable rate.',
    N'Population: ALL serviced loans in state incl. serviced for others | Filters: rate_type = ''ARM'' | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 28400000 | Cnt 113', 49,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S690', N'Total Rate Type',
    N'Rate Type on Loans Serviced',
    N'Sum of S600 to S610 per column.',
    N'Calculated: S600+S610. Must tie to S590.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 315500000 | Cnt 1382', 50,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S700', N'Government (FHA/VA/RHS) Loans Serviced',
    N'Loan Type on Loans Serviced',
    N'Serviced 1-4 unit firsts guaranteed/insured by government incl. bond/state assisted.',
    N'Population: serviced 1-4 unit FIRST mortgages in state | Filters: loan_type in (FHA,VA,RHS,bond/state-assisted) | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 82100000 | Cnt 391', 51,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S710', N'Conventional Conforming Loans Serviced',
    N'Loan Type on Loans Serviced',
    N'Serviced 1-4 unit firsts eligible for sale to FNMA/FHLMC.',
    N'Population: serviced 1-4 unit FIRST mortgages in state | Filters: conventional conforming (GSE-eligible) | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 195400000 | Cnt 836', 52,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S720', N'Conventional Non-Conforming Loans Serviced',
    N'Loan Type on Loans Serviced',
    N'Serviced firsts exceeding GSE limits incl. Alt-A/non-prime (<620 FICO).',
    N'Population: serviced 1-4 unit FIRST mortgages in state | Filters: conventional non-conforming incl. Alt-A/non-prime (<620) | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 18700000 | Cnt 41', 53,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S730', N'Other Loans Serviced',
    N'Loan Type on Loans Serviced',
    N'All other serviced 1-4 unit firsts not reported above.',
    N'Population: serviced 1-4 unit FIRST mortgages in state | Filters: all other firsts | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 9300000 | Cnt 52', 54,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S790', N'Total Residential First Mortgage Loans Serviced',
    N'Loan Type on Loans Serviced',
    N'Sum of S700 to S730 per column.',
    N'Calculated: S700+...+S730.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 305500000 | Cnt 1320', 55,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S800', N'Closed-End Second Mortgages Loans Serviced',
    N'Other Residential Mortgages Serviced',
    N'Serviced subordinate closed-end seconds. Excludes HELOC commitments.',
    N'Population: serviced OTHER (non-first) mortgages in state | Filters: closed-end seconds (exclude HELOC commitments) | Timing: as of period end | Measures: SUM(upb or max line), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 3100000 | Cnt 27', 56,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S810', N'HELOC Loans Serviced',
    N'Other Residential Mortgages Serviced',
    N'Serviced HELOCs; report maximum credit line.',
    N'Population: serviced OTHER (non-first) mortgages in state | Filters: HELOCs - report MAX credit line | Timing: as of period end | Measures: SUM(upb or max line), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 4200000 | Cnt 22', 57,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S820', N'Reverse Mortgages Loans Serviced',
    N'Other Residential Mortgages Serviced',
    N'Serviced reverse mortgages (62+, no repayment while principal residence).',
    N'Population: serviced OTHER (non-first) mortgages in state | Filters: reverse mortgages | Timing: as of period end | Measures: SUM(upb or max line), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 2200000 | Cnt 9', 58,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S840', N'Other Loans Serviced',
    N'Other Residential Mortgages Serviced',
    N'All other serviced mortgages not reported above.',
    N'Population: serviced OTHER (non-first) mortgages in state | Filters: all other | Timing: as of period end | Measures: SUM(upb or max line), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 500000 | Cnt 4', 59,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S890', N'Total Other Mortgage Loans Serviced',
    N'Other Residential Mortgages Serviced',
    N'Sum of S800 to S840 per column.',
    N'Calculated: S800+...+S840.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 10000000 | Cnt 62', 60,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S900', N'Total Mortgages Serviced',
    N'Other Residential Mortgages Serviced',
    N'Sum of S790 and S890. Must equal S590 total.',
    N'Calculated: S790+S890. Completeness: must equal S590.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 315500000 | Cnt 1382', 61,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S1000', N'Current LTV <= 60%',
    N'Serviced Loans LTV Distribution',
    N'Serviced firsts with current LTV <=60% using most recent appraised value.',
    N'Population: serviced 1-4 unit first mortgages in state | Filters: CURRENT LTV <= 60: current_upb / most_recent_appraised_value | Timing: as of period end; use MOST RECENT appraisal (AVM/BPO per policy - document) | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); valuation table (latest appraisal/AVM value + date)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 92400000 | Cnt 486', 62,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S1010', N'Current LTV > 60% and <= 70%',
    N'Serviced Loans LTV Distribution',
    N'Serviced firsts with current LTV >60% and <=70%.',
    N'Population: serviced 1-4 unit first mortgages in state | Filters: CURRENT LTV > 60 and <= 70: current_upb / most_recent_appraised_value | Timing: as of period end; use MOST RECENT appraisal (AVM/BPO per policy - document) | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); valuation table (latest appraisal/AVM value + date)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 67800000 | Cnt 294', 63,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S1020', N'Current LTV > 70% and <= 80%',
    N'Serviced Loans LTV Distribution',
    N'Serviced firsts with current LTV >70% and <=80%.',
    N'Population: serviced 1-4 unit first mortgages in state | Filters: CURRENT LTV > 70 and <= 80: current_upb / most_recent_appraised_value | Timing: as of period end; use MOST RECENT appraisal (AVM/BPO per policy - document) | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); valuation table (latest appraisal/AVM value + date)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 74600000 | Cnt 281', 64,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S1030', N'Current LTV > 80% and <= 90%',
    N'Serviced Loans LTV Distribution',
    N'Serviced firsts with current LTV >80% and <=90%.',
    N'Population: serviced 1-4 unit first mortgages in state | Filters: CURRENT LTV > 80 and <= 90: current_upb / most_recent_appraised_value | Timing: as of period end; use MOST RECENT appraisal (AVM/BPO per policy - document) | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); valuation table (latest appraisal/AVM value + date)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 41300000 | Cnt 147', 65,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S1040', N'Current LTV > 90% and <= 100%',
    N'Serviced Loans LTV Distribution',
    N'Serviced firsts with current LTV >90% and <=100%.',
    N'Population: serviced 1-4 unit first mortgages in state | Filters: CURRENT LTV > 90 and <= 100: current_upb / most_recent_appraised_value | Timing: as of period end; use MOST RECENT appraisal (AVM/BPO per policy - document) | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); valuation table (latest appraisal/AVM value + date)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 26900000 | Cnt 98', 66,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S1050', N'Current LTV > 100%',
    N'Serviced Loans LTV Distribution',
    N'Serviced firsts with current LTV >100%.',
    N'Population: serviced 1-4 unit first mortgages in state | Filters: CURRENT LTV > 100: current_upb / most_recent_appraised_value | Timing: as of period end; use MOST RECENT appraisal (AVM/BPO per policy - document) | Measures: SUM(current_upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); valuation table (latest appraisal/AVM value + date)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 2500000 | Cnt 14', 67,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S1090', N'Total Mortgages Serviced',
    N'Serviced Loans LTV Distribution',
    N'Sum of S1000 to S1050 per column.',
    N'Calculated: S1000+...+S1050. Ties to S790 (firsts only).',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 305500000 | Cnt 1320', 68,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S1100', N'Gross Revenue from Mortgage Servicing Operations',
    N'Revenue',
    N'All servicing revenue received in this state during period, before expenses.',
    N'Population: gross servicing revenue attributable to this state | Filters: servicing revenue GL accounts; state allocation by property state | Timing: earned DURING period, BEFORE expenses | Measures: SUM(revenue) | Source: GL + allocation logic',
    N'Positive dollar', 0, N'418000', 69,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S520A', N'Loans Serviced Under MSRs Detail',
    N'MSR Owner Detail',
    N'Per owner: NMLS ID, Owner Name, Pool #, UPB, Count. NMLS ID blank if owner has none.',
    N'Population: MSR-owned loans grouped by loan OWNER | Filters: group by counterparty; NMLS ID blank if none; Pool # blank if unknown (S540A) | Timing: as of period end | Measures: per row: NMLS_ID, name, pool_number, SUM(upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); counterparty master with NMLS ID crosswalk',
    N'NMLS ID: whole number; Name: text; Pool #: text; UPB: dollar; Count: whole number', 0, N'1071 | Wilshire Capital LLC | FN-2026-0413 | 84200000 | 361', 70,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S520TOT', N'Total Loans Serviced Under MSRs',
    N'MSR Owner Detail',
    N'Sum of S520A rows per column.',
    N'Calculated detail total; must tie to corresponding S520/S530/S540 line.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 248000000 | Cnt 1073', 71,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S530A', N'Loans Serviced for Others (Subservicing) Detail',
    N'Subservicing Detail',
    N'Per owner: NMLS ID, Owner Name, Pool #, UPB, Count. NMLS ID blank if owner has none.',
    N'Population: subserviced-for-others loans grouped by OWNER | Filters: group by counterparty; NMLS ID blank if none; Pool # blank if unknown (S540A) | Timing: as of period end | Measures: per row: NMLS_ID, name, pool_number, SUM(upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); counterparty master with NMLS ID crosswalk',
    N'NMLS ID: whole number; Name: text; Pool #: text; UPB: dollar; Count: whole number', 0, N'22884 | Prairie Servicing Corp | PSC-118 | 19200000 | 89', 72,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S530TOT', N'Total Loans Serviced for Others (Subservicing)',
    N'Subservicing Detail',
    N'Sum of S530A rows per column.',
    N'Calculated detail total; must tie to corresponding S520/S530/S540 line.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 19200000 | Cnt 89', 73,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S540A', N'Loans Serviced by Others Detail',
    N'Serviced-by-Others Detail',
    N'Per servicer: NMLS ID, Servicer Name, Pool #, UPB, Count. NMLS ID and Pool # may be blank if unknown.',
    N'Population: subserviced-by-others loans grouped by SERVICER | Filters: group by counterparty; NMLS ID blank if none; Pool # blank if unknown (S540A) | Timing: as of period end | Measures: per row: NMLS_ID, name, pool_number, SUM(upb), COUNT(loan_id) | Source: servicing system loan master (loan_id, current_upb, dpd/next_due_date, servicing_type, investor_code, remittance_type, loan_status); counterparty master with NMLS ID crosswalk',
    N'NMLS ID: whole number; Name: text; Pool #: text; UPB: dollar; Count: whole number', 0, N'2119 | Cenlar FSB | (blank) | 10800000 | 57', 74,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecThree, N'S540TOT', N'Total Loans Serviced by Others',
    N'Serviced-by-Others Detail',
    N'Sum of S540A rows per column.',
    N'Calculated detail total; must tie to corresponding S520/S530/S540 line.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 10800000 | Cnt 57', 75,
    @LoadBatchId);

/* ---- SSSF: items from sheet [SSSF] ---- */
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF010', N'Construction',
    N'Commercial Loan Origination - Commercial Real Estate',
    N'Loans funding commercial real estate development, incl. loans to builders for residential/commercial/industrial construction. Not direct consumer construction loans.',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: purpose = commercial RE development / builder construction (residential, commercial, industrial); EXCLUDE direct-to-consumer home construction | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 4800000 | Cnt 3', 1,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF020', N'Multifamily Residential Properties (5 or More)',
    N'Commercial Loan Origination - Commercial Real Estate',
    N'Loans secured by residential real estate with 5+ units, incl. primarily-residential mixed use.',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: collateral = residential 5+ units incl. primarily-residential mixed use | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 6200000 | Cnt 2', 2,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF030', N'1-4 Family Residential Investment Properties, Business Ownership',
    N'Commercial Loan Origination - Commercial Real Estate',
    N'Non-owner-occupied 1-4 family investment properties; repayment from property cash flow; borrower is a business entity.',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: collateral = 1-4 family non-owner-occupied investment; borrower_entity_type = business | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 2900000 | Cnt 11', 3,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF035', N'1-4 Family Residential Investment Properties, Natural Person Ownership',
    N'Commercial Loan Origination - Commercial Real Estate',
    N'Non-owner-occupied 1-4 family investment properties; borrower is a natural person.',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: collateral = 1-4 family non-owner-occupied investment; borrower_entity_type = natural person | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 1700000 | Cnt 7', 4,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF040', N'Commercial Nonresidential Properties',
    N'Commercial Loan Origination - Commercial Real Estate',
    N'Loans secured by CRE with no residential components.',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: collateral = commercial RE, no residential component | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 3500000 | Cnt 2', 5,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF050', N'Other Secured Commercial Real Estate Loans',
    N'Commercial Loan Origination - Commercial Real Estate',
    N'CRE loans not fitting above categories.',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: other secured CRE not fitting above | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 600000 | Cnt 1', 6,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF090', N'Total Commercial Real Estate',
    N'Commercial Loan Origination - Commercial Real Estate',
    N'Sum of SF010 to SF050.',
    N'Calculated section total.',
    N'Loan Amount: positive dollar; Count: positive whole number', 1, N'Amt 19700000 | Cnt 26', 7,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF100', N'Secured by 1-4 Family Residential Properties',
    N'Commercial Loan Origination - Commercial and Industrial',
    N'C&I loans to businesses primarily secured by liens on 1-4 family residential real estate.',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: C&I loan primarily secured by 1-4 family residential lien | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 1200000 | Cnt 4', 8,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF110', N'Secured',
    N'Commercial Loan Origination - Commercial and Industrial',
    N'C&I loans secured by non-real-estate liens (e.g., UCC-1 on equipment or receivables).',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: C&I secured by non-RE liens (UCC-1 equipment/receivables) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 900000 | Cnt 3', 9,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF120', N'Unsecured',
    N'Commercial Loan Origination - Commercial and Industrial',
    N'C&I loans not secured.',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: C&I unsecured | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 300000 | Cnt 2', 10,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF190', N'Total Commercial and Industrial',
    N'Commercial Loan Origination - Commercial and Industrial',
    N'Sum of SF100 to SF120.',
    N'Calculated section total.',
    N'Loan Amount: positive dollar; Count: positive whole number', 1, N'Amt 2400000 | Cnt 9', 11,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF200', N'Motor Vehicle Installment Sale Contracts',
    N'Consumer Loan Origination',
    N'Transactions where buyer purchases a motor vehicle from a retail seller under a retail installment sales contract.',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: motor vehicle retail installment sale contracts | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 1850000 | Cnt 62', 12,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF210', N'Non-Motor Vehicle, Non-Residential Installment Sale Contracts',
    N'Consumer Loan Origination',
    N'Retail installment sale contracts for goods/services other than motor vehicles or a residence.',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: non-vehicle, non-residential retail installment sale contracts | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 420000 | Cnt 38', 13,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF220', N'Non-Mortgage Secured Direct Loans',
    N'Consumer Loan Origination',
    N'Direct loans secured by non-mortgage collateral (direct auto, watercraft, equipment).',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: direct loans secured by non-mortgage collateral (direct auto, watercraft, equipment) | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 760000 | Cnt 29', 14,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF230', N'Unsecured Direct Loans',
    N'Consumer Loan Origination',
    N'Direct loans not secured by any collateral.',
    N'Population: commercial/consumer loans ORIGINATED this period in filing state | Filters: direct unsecured loans | Timing: funded DURING period | Measures: SUM(loan_amount), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'Loan Amount: positive dollar; Count: positive whole number', 0, N'Amt 310000 | Cnt 41', 15,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF290', N'Total Consumer',
    N'Consumer Loan Origination',
    N'Sum of SF200 to SF230.',
    N'Calculated section total.',
    N'Loan Amount: positive dollar; Count: positive whole number', 1, N'Amt 3340000 | Cnt 170', 16,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF300', N'Construction',
    N'Commercial Loan Servicing - Commercial Real Estate',
    N'Serviced loans funding CRE development, incl. builder construction loans.',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF010 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 8100000 | Cnt 5', 17,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF310', N'Multifamily Residential Properties (5 or More)',
    N'Commercial Loan Servicing - Commercial Real Estate',
    N'Serviced loans secured by 5+ unit residential real estate, incl. primarily-residential mixed use.',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF020 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 11400000 | Cnt 4', 18,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF320', N'1-4 Family Residential Investment Properties, Business Ownership',
    N'Commercial Loan Servicing - Commercial Real Estate',
    N'Serviced non-owner-occupied 1-4 family investment loans; borrower is a business entity.',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF030 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 5200000 | Cnt 19', 19,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF325', N'1-4 Family Residential Investment Properties, Natural Person Ownership',
    N'Commercial Loan Servicing - Commercial Real Estate',
    N'Serviced non-owner-occupied 1-4 family investment loans; borrower is a natural person.',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF035 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 3100000 | Cnt 13', 20,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF330', N'Commercial Nonresidential Properties',
    N'Commercial Loan Servicing - Commercial Real Estate',
    N'Serviced loans secured by CRE with no residential components.',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF040 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 6800000 | Cnt 3', 21,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF340', N'Other Secured Commercial Real Estate Loans',
    N'Commercial Loan Servicing - Commercial Real Estate',
    N'Serviced CRE loans not fitting above categories.',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF050 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 900000 | Cnt 1', 22,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF390', N'Total Commercial Real Estate',
    N'Commercial Loan Servicing - Commercial Real Estate',
    N'Sum of SF300 to SF350.',
    N'Calculated section total.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 35500000 | Cnt 45', 23,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF400', N'Secured by 1-4 Family Residential Properties',
    N'Commercial Loan Servicing - Commercial and Industrial',
    N'Serviced C&I loans primarily secured by liens on 1-4 family residential real estate.',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF100 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 2100000 | Cnt 7', 24,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF410', N'Secured',
    N'Commercial Loan Servicing - Commercial and Industrial',
    N'Serviced C&I loans secured by non-real-estate liens (UCC-1 on equipment/receivables).',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF110 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 1400000 | Cnt 5', 25,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF420', N'Unsecured',
    N'Commercial Loan Servicing - Commercial and Industrial',
    N'Serviced C&I loans that are not secured.',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF120 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 500000 | Cnt 3', 26,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF490', N'Total Commercial and Industrial',
    N'Commercial Loan Servicing - Commercial and Industrial',
    N'Sum of SF400 to SF420.',
    N'Calculated section total.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 4000000 | Cnt 15', 27,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF500', N'Motor Vehicle Installment Sale Contracts',
    N'Consumer Loan Servicing',
    N'Serviced motor vehicle retail installment sale contracts.',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF200 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 3600000 | Cnt 148', 28,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF510', N'Non-Motor Vehicle, Non-Residential Installment Sale Contracts',
    N'Consumer Loan Servicing',
    N'Serviced retail installment contracts for goods/services other than vehicles or residence.',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF210 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 810000 | Cnt 74', 29,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF520', N'Non-Mortgage Secured Direct Loans',
    N'Consumer Loan Servicing',
    N'Serviced direct loans secured by non-mortgage collateral.',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF220 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 1450000 | Cnt 58', 30,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF530', N'Unsecured Direct Loans',
    N'Consumer Loan Servicing',
    N'Serviced direct loans with no collateral.',
    N'Population: commercial/consumer loans SERVICED in filing state | Filters: same classification logic as SF230 applied to the servicing portfolio | Timing: as of period end | Measures: SUM(current_upb), COUNT(loan_id) | Source: commercial LOS / loan accounting (loan_id, amount/upb, collateral_type, unit_count, borrower_entity_type, occupancy, lien_class)',
    N'UPB: positive dollar; Count: positive whole number', 0, N'UPB 590000 | Cnt 82', 31,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF590', N'Total Consumer',
    N'Consumer Loan Servicing',
    N'Sum of SF500 to SF530.',
    N'Calculated section total.',
    N'UPB: positive dollar; Count: positive whole number', 1, N'UPB 6450000 | Cnt 362', 32,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF600', N'Applications In Process at Beginning of Quarter',
    N'Licensed Processors and Underwriters',
    N'Third-party-assigned processing/underwriting applications outstanding at end of prior period.',
    N'Population: third-party-assigned processing/underwriting apps open at period start (contract processor/underwriter activity only) | Filters: open as of prior period end | Timing: per description | Measures: SUM(app_amount), COUNT(app_id) | Source: contract processing/UW work-order system',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 5400000 | Cnt 21', 33,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF610', N'Applications Received for Processing/Underwriting During the Quarter',
    N'Licensed Processors and Underwriters',
    N'Applications received from a third-party entity for processing/underwriting, contracted for return for lending decision.',
    N'Population: apps received from third parties for processing/underwriting (contract processor/underwriter activity only) | Filters: received_date within quarter; contracted for return to assignor for lending decision | Timing: per description | Measures: SUM(app_amount), COUNT(app_id) | Source: contract processing/UW work-order system',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 12800000 | Cnt 49', 34,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF620', N'Applications Returned to Creditor, Incomplete',
    N'Licensed Processors and Underwriters',
    N'Assigned applications returned incomplete due to non-responsive borrower.',
    N'Population: assigned apps returned incomplete (contract processor/underwriter activity only) | Filters: returned within quarter, reason = non-responsive borrower | Timing: per description | Measures: SUM(app_amount), COUNT(app_id) | Source: contract processing/UW work-order system',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 1100000 | Cnt 4', 35,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF630', N'Net Changes in Application Amount',
    N'Licensed Processors and Underwriters',
    N'Loan amount changes while assigned for processing/underwriting; positive or negative adjustment; amount only.',
    N'Net application AMOUNT changes while assigned; positive or negative; amount only, no count.',
    N'Dollar (may be negative)', 0, N'-260000', 36,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF640', N'Other Changes to Applications',
    N'Licensed Processors and Underwriters',
    N'Other changes directed by assigning third party not meeting SF630 definition.',
    N'Other assignor-directed changes not meeting SF630; amount and count; negative allowed.',
    N'Amount: dollar; Count: whole number', 0, N'Amt -150000 | Cnt -1', 37,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF650', N'Applications Processed/Underwritten, Completed',
    N'Licensed Processors and Underwriters',
    N'Assigned applications returned complete and ready for lending decision.',
    N'Population: assigned apps returned complete/ready for decision (contract processor/underwriter activity only) | Filters: returned within quarter, status = complete | Timing: per description | Measures: SUM(app_amount), COUNT(app_id) | Source: contract processing/UW work-order system',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 11200000 | Cnt 43', 38,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF660', N'Applications In Process at End of Quarter',
    N'Licensed Processors and Underwriters',
    N'Third-party-assigned applications outstanding at period end.',
    N'Population: assigned apps open at period end (contract processor/underwriter activity only) | Filters: open as of period end | Timing: per description | Measures: SUM(app_amount), COUNT(app_id) | Source: contract processing/UW work-order system',
    N'Amount: positive dollar; Count: positive whole number', 0, N'Amt 5490000 | Cnt 22', 39,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecSssf, N'SF1100', N'Gross Revenue from All Mortgage Operations',
    N'Revenue Data',
    N'All mortgage revenue from any source in this state during period, before expenses; incl. gross revenue from mortgage sales at/after closing and any other mortgage-related activity.',
    N'Population: ALL mortgage revenue in filing state, any source | Filters: incl. gross revenue from mortgage sales at/after closing and any other mortgage-related activity | Timing: earned DURING period, BEFORE expenses | Measures: SUM(revenue) | Source: GL revenue accounts + state allocation; superset of AC1100 + S1100',
    N'Positive dollar', 0, N'2214000', 40,
    @LoadBatchId);

/* ---- FC: items from sheet [FC] ---- */
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A010', N'Cash and Cash Equivalents, Unrestricted',
    N'Sch A - Current Assets - Cash and Current Securities',
    N'Cash/equivalents per FAS 95 para 7-8, unrestricted only. Excludes escrow/fiduciary funds.',
    N'Source: GL cash accounts | Timing: AS OF period end | Filter: UNRESTRICTED only; exclude restricted cash (A020), escrow/custodial/fiduciary funds (A250 memo)',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'4820000', 1,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A034', N'Securities Available for Sale',
    N'Sch A - Current Assets - Cash and Current Securities',
    N'Securities not intended to hold to maturity or actively trade; at FMV (FAS 115/140), value changes in OCI. Sum of Sch A-030 items.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Securities Available for Sale'' | Notes: map GL accounts to line; document account-to-line crosswalk',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'1650000', 2,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A036', N'Trading Account Securities',
    N'Sch A - Current Assets - Cash and Current Securities',
    N'Routinely traded securities incl. MBS for near-term sale; at FMV with unrealized gain/loss in earnings. Sum of Sch A-030 items.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Trading Account Securities'' | Notes: map GL accounts to line; document account-to-line crosswalk',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'740000', 3,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A038', N'Marketable Equity Securities',
    N'Sch A - Current Assets - Cash and Current Securities',
    N'Exchange-traded common stock with quoted market prices.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Marketable Equity Securities'' | Notes: map GL accounts to line; document account-to-line crosswalk',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'125000', 4,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A039', N'Total Cash and Current Securities',
    N'Sch A - Current Assets - Cash and Current Securities',
    N'A010 + A034 + A036 + A038.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: balance AS OF period end. | Notes: map GL accounts to line; document account-to-line crosswalk',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'7335000', 5,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060', N'Mortgage Loans HFS, at LOCOM',
    N'Sch A - Current Assets - Mortgage Loans HFS',
    N'Residential/multifamily/commercial (incl. farm) HFS loans at lower of cost or market. Excludes FAS 159 FV-elected loans (A062). Net of valuation allowances and deferred fees/costs.',
    N'Source: loan subledger, HFS designation | Timing: UPB AS OF period end | Filter: carrying = LOCOM (exclude FAS 159 FV loans -> A062); net of valuation allowance and deferred fees/costs',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'18400000', 6,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A062', N'Mortgage Loans HFS, at Fair Value',
    N'Sch A - Current Assets - Mortgage Loans HFS',
    N'HFS loans where FAS 159 fair value option elected. Sum of Sch A-060 items.',
    N'Source: loan subledger, HFS + FAS 159 FV election flag | Timing: fair value AS OF period end',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'9200000', 7,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A063', N'Total Mortgage Loans - Held for Sale',
    N'Sch A - Current Assets - Mortgage Loans HFS',
    N'A060 + A062.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: balance AS OF period end. | Notes: map GL accounts to line; document account-to-line crosswalk',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'27600000', 8,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230B', N'Accrued Interest Receivable',
    N'Sch A - Current Assets',
    N'Accrued interest due on loans, securities, and other investments.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Accrued Interest Receivable'' | Notes: map GL accounts to line; document account-to-line crosswalk',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'310000', 9,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230C', N'Accounts Receivable',
    N'Sch A - Current Assets',
    N'Trade accounts receivable.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Accounts Receivable'' | Notes: map GL accounts to line; document account-to-line crosswalk',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'185000', 10,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A190', N'Receivables from Related Parties',
    N'Sch A - Current Assets',
    N'Receivables due within a year from affiliates, officers, stockholders, employees. Excludes loan interest receivable (A230B) and A/R (A230C).',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Receivables from Related Parties'' | Notes: map GL accounts to line; document account-to-line crosswalk',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'95000', 11,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A050', N'Receivables from Unrelated Parties',
    N'Sch A - Current Assets',
    N'Non-mortgage notes/advances/receivables from unrelated parties, collectable in normal course, not reported elsewhere.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Receivables from Unrelated Parties'' | Notes: map GL accounts to line; document account-to-line crosswalk',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'142000', 12,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A040', N'Reverse Repurchase Agreements',
    N'Sch A - Current Assets',
    N'Outstanding balance on repos where institution is buyer-lender.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Reverse Repurchase Agreements'' | Notes: map GL accounts to line; document account-to-line crosswalk',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 13,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A237', N'Total Current Assets',
    N'Sch A - Current Assets',
    N'A039 + A063 + A230C + A190 + A050 + A040.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: balance AS OF period end. | Notes: map GL accounts to line; document account-to-line crosswalk',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'35357000', 14,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A020', N'Cash and Cash Equivalents, Restricted',
    N'Sch A - Long-Term Assets',
    N'Cash/equivalents restricted for specific purposes under contract. Excludes escrow/fiduciary funds.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Cash and Cash Equivalents, Restricted'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'600000', 15,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030', N'Securities Held to Maturity, at Amortized Cost',
    N'Sch A - Long-Term Assets',
    N'HTM securities at amortized cost (unless FAS 159 elected), subject to OTTI write-downs. Net of unamortized deferred fees/costs.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Securities Held to Maturity, at Amortized Cost'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'820000', 16,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A032', N'Securities Held to Maturity, at Fair Value',
    N'Sch A - Long-Term Assets',
    N'HTM securities where FAS 159 FV option elected; carried at fair value.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Securities Held to Maturity, at Fair Value'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 17,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A033', N'Total Cash and Long-Term Securities',
    N'Sch A - Long-Term Assets',
    N'A020 + A030 + A032.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: balance AS OF period end. | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'1420000', 18,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A064', N'Mortgage Loans HFI, at Amortized Cost',
    N'Sch A - Long-Term Assets',
    N'UPB of HFI loans incl. undisbursed funds, net of premiums/discounts and amortization, credit loss reserves, and deferred fees/costs.',
    N'Source: loan subledger, HFI designation, amortized cost | Timing: AS OF period end | Net of credit loss reserve (A060AF/O060) and deferred fees/costs',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'22100000', 19,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A066', N'Mortgage Loans HFI, at Fair Value',
    N'Sch A - Long-Term Assets',
    N'HFI loans where FAS 159 FV option elected.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Mortgage Loans HFI, at Fair Value'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 20,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A067', N'Total Mortgage Loans - Held for Investment',
    N'Sch A - Long-Term Assets',
    N'A064 + A066.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: balance AS OF period end. | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'22100000', 21,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A160', N'Mortgage Servicing Rights',
    N'Sch A - Long-Term Assets',
    N'From Sch A-160; amortized MSRs net of valuation allowance plus fair-value MSRs.',
    N'Source: MSR valuation system | Timing: AS OF period end | = A160T from Sch A-120R (amortized net of allowance + FV MSRs)',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'16800000', 22,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A080', N'Non-Mortgage Long-Term Investments',
    N'Sch A - Long-Term Assets',
    N'UPB of investments not mortgage-secured and not elsewhere: consumer loans, CDs, annuities, stocks, bonds. Excludes A070 items.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Non-Mortgage Long-Term Investments'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'450000', 23,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A070', N'Other Financial Instruments, at Fair Value',
    N'Sch A - Long-Term Assets',
    N'FV of other FAS 159-elected instruments where FV is an asset. Excludes HFS/HFI at FV.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Other Financial Instruments, at Fair Value'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 24,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A090', N'Other Real Estate Owned, at Net Realizable Value',
    N'Sch A - Long-Term Assets',
    N'A090A + A090B; real estate acquired via foreclosure/deed-in-lieu, net of valuation allowances.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Other Real Estate Owned, at Net Realizable Value'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'540000', 25,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A100', N'Investment in Joint Ventures, Partnerships, Other Entities',
    N'Sch A - Long-Term Assets',
    N'Equity in unconsolidated entities accounted for using equity method.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Investment in Joint Ventures, Partnerships, Other Entities'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 26,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A110', N'Real Estate Investments',
    N'Sch A - Long-Term Assets',
    N'Carrying value of purchased real estate owned; excludes foreclosure-acquired REO (A090).',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Real Estate Investments'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 27,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A170', N'Reserve for Other Losses - Contra',
    N'Sch A - Long-Term Assets',
    N'Reserves/allowances for assets not reported elsewhere (e.g., uncollectible receivables). Excludes A060AF, A060AE, A090B. Must equal O250; must be <= 0.',
    N'Source: other-loss reserve GL contra | Must equal O250 | Must be <= 0',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'-45000', 28,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A180', N'Property, Equipment, Leasehold, Net',
    N'Sch A - Long-Term Assets',
    N'Fixed assets at cost net of accumulated depreciation/amortization. Complete A250 memo.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Property, Equipment, Leasehold, Net'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'1230000', 29,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A210', N'Goodwill and Other Intangible Assets',
    N'Sch A - Long-Term Assets',
    N'Unamortized goodwill net of impairment; incl. organization costs and other intangibles.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Goodwill and Other Intangible Assets'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'300000', 30,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A220', N'Derivative Assets',
    N'Sch A - Long-Term Assets',
    N'Total from Sch A-220; derivatives carried as assets per FAS 133.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Derivative Assets'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'410000', 31,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A200', N'Deferred Tax Assets',
    N'Sch A - Long-Term Assets',
    N'Positive if taxes receivable; payable balance goes to B200. Current taxes receivable in A230G; current payable in B120.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Deferred Tax Assets'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'275000', 32,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230D', N'Servicing Advances',
    N'Sch A - Long-Term Assets',
    N'P&I, T&I, and foreclosure advances on serviced loans made for mortgagors/investors.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Servicing Advances'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'890000', 33,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230F', N'Foreclosure Claims Receivable',
    N'Sch A - Long-Term Assets',
    N'Claims receivable from FNMA, FHLMC, VA, FHA, MI companies, or other guarantors.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Foreclosure Claims Receivable'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'160000', 34,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230', N'Other Assets',
    N'Sch A - Long-Term Assets',
    N'All other tangible assets not elsewhere; total from Sch A-230.',
    N'Source: GL trial balance / subledger balances | Timing: balance AS OF period end | Filter/classification: per definition - ''Other Assets'' | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'520000', 35,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A239', N'Total Long-Term Assets',
    N'Sch A - Long-Term Assets',
    N'A033+A067+A160+A080+A070+A090+A100+A110+A170+A180+A210+A220+A200+A230D+A230F+A230.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: balance AS OF period end. | Notes: map GL accounts to line',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'44850000', 36,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A240', N'Total Assets',
    N'Sch A',
    N'A237 + A239.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'80207000', 37,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A250', N'MEMO: Escrow Funds (Held in Trust)',
    N'Sch A - Memo',
    N'P&I and T&I custodial/fiduciary funds held in trust; not owned by institution; excluded from assets/liabilities.',
    N'Source: custodial bank statements (P&I + T&I accounts) | Timing: AS OF period end | Memo only - NOT in total assets; enter once',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'6100000', 38,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A260', N'MEMO: Capitalized Hardware and Telecom Property/Equipment',
    N'Sch A - Memo',
    N'Capitalized hardware/telecom equipment included in A180, net of depreciation.',
    N'Source: GL memo/off-balance-sheet accounts or fixed asset subledger | Timing: AS OF period end | Filter/classification: per definition - ''MEMO: Capitalized Hardware and Telecom Property/Equipment'' | Notes: memo only - excluded from totals',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'180000', 39,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A262', N'MEMO: Capitalized Software',
    N'Sch A - Memo',
    N'Capitalized software included in A180, net of depreciation/amortization.',
    N'Source: GL memo/off-balance-sheet accounts or fixed asset subledger | Timing: AS OF period end | Filter/classification: per definition - ''MEMO: Capitalized Software'' | Notes: memo only - excluded from totals',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'240000', 40,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A264', N'MEMO: Watercraft',
    N'Sch A - Memo',
    N'Watercraft assets included in A180, net of depreciation.',
    N'Source: GL memo/off-balance-sheet accounts or fixed asset subledger | Timing: AS OF period end | Filter/classification: per definition - ''MEMO: Watercraft'' | Notes: memo only - excluded from totals',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 41,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A266', N'MEMO: Aircraft',
    N'Sch A - Memo',
    N'Aircraft assets included in A180, net of depreciation.',
    N'Source: GL memo/off-balance-sheet accounts or fixed asset subledger | Timing: AS OF period end | Filter/classification: per definition - ''MEMO: Aircraft'' | Notes: memo only - excluded from totals',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 42,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030A', N'Agency MBS',
    N'Sch A-030 - Investment-Grade Securities',
    N'MBS (residential and multifamily) issued by FNMA/FHLMC/GNMA etc.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Agency MBS'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'1450000', 43,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030B', N'Non-Agency MBS',
    N'Sch A-030 - Investment-Grade Securities',
    N'Residential non-agency MBS rated AAA/AA/A/BBB by an NRSRO.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Non-Agency MBS'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'200000', 44,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030C', N'Commercial MBS Investment Grade',
    N'Sch A-030 - Investment-Grade Securities',
    N'CMBS rated AAA/AA/A/BBB by an NRSRO.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Commercial MBS Investment Grade'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 45,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030D', N'Non-Mortgage ABS Investment Grade',
    N'Sch A-030 - Investment-Grade Securities',
    N'Non-mortgage ABS rated investment grade by an NRSRO.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Non-Mortgage ABS Investment Grade'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 46,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030E', N'Obligations of Government Sponsored Enterprise',
    N'Sch A-030 - Investment-Grade Securities',
    N'Debt securities issued by a GSE (FNMA, FHLMC, FHLB).',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Obligations of Government Sponsored Enterprise'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'350000', 47,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030F', N'U.S. Treasury Obligations',
    N'Sch A-030 - Investment-Grade Securities',
    N'Securities backed by U.S. Treasury obligations.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''U.S. Treasury Obligations'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'800000', 48,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030G', N'Other Securities Investment Grade',
    N'Sch A-030 - Investment-Grade Securities',
    N'All other investment-grade securities not included above.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other Securities Investment Grade'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'60000', 49,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030H', N'Total Investment-Grade Securities',
    N'Sch A-030 - Investment-Grade Securities',
    N'Sum of A030A to A030G per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'2860000', 50,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030L', N'Non-Agency MBS Non-Investment Grade',
    N'Sch A-030 - Non-Investment Grade Securities',
    N'Non-agency MBS rated BB or below by an NRSRO.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Non-Agency MBS Non-Investment Grade'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'90000', 51,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030M', N'Principal Only Securities Non-Investment Grade',
    N'Sch A-030 - Non-Investment Grade Securities',
    N'PO securities (predominantly principal payments), BB or below only.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Principal Only Securities Non-Investment Grade'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 52,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030N', N'Interest Only Strips Non-Investment Grade',
    N'Sch A-030 - Non-Investment Grade Securities',
    N'IO strips, BB or below. Excess servicing without legal form as a security goes to Sch A-160 MSRs.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Interest Only Strips Non-Investment Grade'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 53,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030O', N'Commercial MBS Non-Investment Grade',
    N'Sch A-030 - Non-Investment Grade Securities',
    N'CMBS rated BB or below by an NRSRO.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Commercial MBS Non-Investment Grade'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 54,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030P', N'Debt Securities Non-Investment Grade',
    N'Sch A-030 - Non-Investment Grade Securities',
    N'Debt securities rated BB or below by an NRSRO.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Debt Securities Non-Investment Grade'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 55,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030Q', N'Other Securities Non-Investment Grade',
    N'Sch A-030 - Non-Investment Grade Securities',
    N'All other securities rated BB or below.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other Securities Non-Investment Grade'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 56,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030R', N'Total Non-Investment Grade Securities',
    N'Sch A-030 - Non-Investment Grade Securities',
    N'Sum of A030L to A030Q per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'90000', 57,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030S', N'Non-Rated Retained Interests',
    N'Sch A-030',
    N'Retained securitization interests not rated by an NRSRO.',
    N'Source: investment/securities subledger with NRSRO ratings and issuer type | Timing: carrying amount AS OF period end | Filter/classification: per definition - ''Non-Rated Retained Interests'' | Notes: classify by issuer (agency/non-agency), rating bucket (IG = BBB+, non-IG = BB-), security type; split AFS / Trading / HTM columns per FAS 115 designation',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 58,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030U', N'Other Securities',
    N'Sch A-030',
    N'Other non-rated securities and all others not included above.',
    N'Source: investment/securities subledger with NRSRO ratings and issuer type | Timing: carrying amount AS OF period end | Filter/classification: per definition - ''Other Securities'' | Notes: classify by issuer (agency/non-agency), rating bucket (IG = BBB+, non-IG = BB-), security type; split AFS / Trading / HTM columns per FAS 115 designation',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'260000', 59,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030V', N'Total Securities',
    N'Sch A-030',
    N'Sum of A030H, A030R, A030S, A030U per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: carrying amount AS OF period end. | Notes: classify by issuer (agency/non-agency), rating bucket (IG = BBB+, non-IG = BB-), security type; split AFS / Trading / HTM columns per FAS 115 designation',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'3210000', 60,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030W', N'Unamortized Deferred Fees and Costs, if Not Included Above',
    N'Sch A-030',
    N'Unamortized deferred fees/costs on securities not already included.',
    N'Source: investment/securities subledger with NRSRO ratings and issuer type | Timing: carrying amount AS OF period end | Filter/classification: per definition - ''Unamortized Deferred Fees and Costs, if Not Included Above'' | Notes: classify by issuer (agency/non-agency), rating bucket (IG = BBB+, non-IG = BB-), security type; split AFS / Trading / HTM columns per FAS 115 designation',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 61,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A030T', N'Net Securities',
    N'Sch A-030',
    N'Sum of A030V and A030W per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: carrying amount AS OF period end. | Notes: classify by issuer (agency/non-agency), rating bucket (IG = BBB+, non-IG = BB-), security type; split AFS / Trading / HTM columns per FAS 115 designation',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'3210000', 62,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060A', N'Government (FHA/VA/RHS) Fixed',
    N'Sch A-060 - Residential First Mortgages, UPB',
    N'UPB of government fixed-rate 1-4 unit loans (incl. bond/state assisted).',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Government (FHA/VA/RHS) Fixed'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'7100000', 63,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060B', N'Government (FHA/VA/RHS) ARM',
    N'Sch A-060 - Residential First Mortgages, UPB',
    N'UPB of government ARM 1-4 unit loans. HECMs go to A060N.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Government (FHA/VA/RHS) ARM'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'300000', 64,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060C', N'Conventional Conforming Fixed',
    N'Sch A-060 - Residential First Mortgages, UPB',
    N'UPB of GSE-eligible fixed-rate firsts. Excludes FHA/VA.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Conventional Conforming Fixed'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'13800000', 65,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060D', N'Conventional Conforming ARM',
    N'Sch A-060 - Residential First Mortgages, UPB',
    N'UPB of GSE-eligible ARM firsts. Excludes FHA/VA.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Conventional Conforming ARM'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'1100000', 66,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060E', N'Conventional Non-Conforming (Jumbo) Fixed',
    N'Sch A-060 - Residential First Mortgages, UPB',
    N'UPB of non Alt-A/non-prime firsts exceeding GSE limits, fixed rate.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Conventional Non-Conforming (Jumbo) Fixed'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'2600000', 67,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060F', N'Conventional Non-Conforming (Jumbo) ARM',
    N'Sch A-060 - Residential First Mortgages, UPB',
    N'UPB of non Alt-A/non-prime firsts exceeding GSE limits, ARM.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Conventional Non-Conforming (Jumbo) ARM'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'700000', 68,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060G', N'Other Fixed',
    N'Sch A-060 - Residential First Mortgages, UPB',
    N'UPB of all other fixed firsts incl. Alt-A and non-prime (<620 FICO, high LTV, limited doc).',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other Fixed'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'1400000', 69,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060H', N'Other ARM',
    N'Sch A-060 - Residential First Mortgages, UPB',
    N'UPB of all other ARM firsts incl. Alt-A and non-prime.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other ARM'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'200000', 70,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060I', N'Total Residential First Mortgage Loans',
    N'Sch A-060 - Residential First Mortgages, UPB',
    N'Sum of A060A to A060H per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'27200000', 71,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060L', N'Closed-End Second Mortgages',
    N'Sch A-060 - Other Mortgages, UPB',
    N'UPB of subordinate closed-end seconds, fixed and ARM. Excludes lines of credit.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Closed-End Second Mortgages'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'450000', 72,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060M', N'HELOCs',
    N'Sch A-060 - Other Mortgages, UPB',
    N'Subordinate home equity lines allowing advances against approved limit. Report full credit line.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''HELOCs'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'800000', 73,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060N', N'Reverse Mortgages',
    N'Sch A-060 - Other Mortgages, UPB',
    N'UPB of reverse mortgages incl. HECM.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Reverse Mortgages'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'1200000', 74,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060O', N'Construction and Land Development Loans',
    N'Sch A-060 - Other Mortgages, UPB',
    N'UPB of 1-4 unit construction-to-perm loans and consumer lot loans.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Construction and Land Development Loans'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'950000', 75,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060P', N'Multifamily Loans Agency',
    N'Sch A-060 - Other Mortgages, UPB',
    N'UPB of 5+ unit mortgages guaranteed/insured by government or agencies.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Multifamily Loans Agency'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 76,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060Q', N'Commercial Mortgage Loans',
    N'Sch A-060 - Other Mortgages, UPB',
    N'UPB of commercial property mortgages (apartments, office, industrial, hotel, retail). Excludes agency multifamily (A060P).',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Commercial Mortgage Loans'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'600000', 77,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060R', N'Other Mortgage Loans',
    N'Sch A-060 - Other Mortgages, UPB',
    N'UPB of all other mortgages incl. land development loans to builders.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other Mortgage Loans'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'100000', 78,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060V', N'Total Other Loans',
    N'Sch A-060 - Other Mortgages, UPB',
    N'Sum of A060L to A060R per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'4100000', 79,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060W', N'Total Mortgage Loans, UPB (before adjustments)',
    N'Sch A-060',
    N'Sum of A060I and A060V per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: UPB AS OF period end. | Notes: classify by loan_type / lien / rate_type / conforming status; split HFS vs HFI columns per accounting designation; adjustments rows come from GL contra accounts',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'31300000', 80,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060W1', N'Qualified Mortgage (QM)',
    N'Sch A-060 - QM Status (HFI)',
    N'HFI loans that are QM under Reg Z 12 CFR 1026.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Qualified Mortgage (QM)'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'19800000', 81,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060W2', N'Non-Qualified Mortgage',
    N'Sch A-060 - QM Status (HFI)',
    N'HFI loans that are non-QM.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Non-Qualified Mortgage'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'1600000', 82,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060W3', N'Not Subject to QM',
    N'Sch A-060 - QM Status (HFI)',
    N'HFI portfolio loans originated before QM standards effective date.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Not Subject to QM'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'700000', 83,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060W9', N'Total Loans (QM Status)',
    N'Sch A-060 - QM Status (HFI)',
    N'Sum of A060W1 to A060W3 per column. Must tie to A060W column totals.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'22100000', 84,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060X', N'Fair Value Adjustments for Loans HFS (FAS 159)',
    N'Sch A-060 - Adjustments',
    N'Basis adjustments for FV changes on HFS loans carried at fair value.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Fair Value Adjustments for Loans HFS (FAS 159)'' | Notes: verify roll-up',
    N'Dollar (may be negative)', 0, N'185000', 85,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060Y', N'(Discount)/Premium on Loans Contra',
    N'Sch A-060 - Adjustments',
    N'Discounts or premiums on loans.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''(Discount)/Premium on Loans Contra'' | Notes: verify roll-up',
    N'Dollar (may be negative)', 0, N'-62000', 86,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060Z', N'Other Deferred Fees on Loans Contra',
    N'Sch A-060 - Adjustments',
    N'FAS 91 deferred fees (origination, underwriting fees from borrowers). N/A for FV loans. Must be <= 0.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other Deferred Fees on Loans Contra'' | Notes: verify roll-up',
    N'Dollar <= 0', 0, N'-118000', 87,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060AA', N'Deferred Costs on Loans Contra',
    N'Sch A-060 - Adjustments',
    N'FAS 91 deferred direct origination costs. N/A for FV loans. Must be <= 0.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Deferred Costs on Loans Contra'' | Notes: verify roll-up',
    N'Dollar <= 0', 0, N'-74000', 88,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060AB', N'Basis Adjustments from Hedging',
    N'Sch A-060 - Adjustments',
    N'Effective-portion hedge basis adjustments per FAS 133. N/A for FV loans.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Basis Adjustments from Hedging'' | Notes: verify roll-up',
    N'Dollar (may be negative)', 0, N'0', 89,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060AC', N'Other Basis Adjustments',
    N'Sch A-060 - Adjustments',
    N'Other basis adjustments not reported separately.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other Basis Adjustments'' | Notes: verify roll-up',
    N'Dollar (may be negative)', 0, N'0', 90,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060AD', N'Accum. Amort. of Discounts/Premiums, Deferred Fees/Costs, Basis Adj.',
    N'Sch A-060 - Adjustments',
    N'Accumulated FAS 91 amortization; HFI at amortized cost only.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Accum. Amort. of Discounts/Premiums, Deferred Fees/Costs, Basis Adj.'' | Notes: verify roll-up',
    N'Dollar (may be negative)', 0, N'41000', 91,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060AE', N'LOCOM Valuation Allowance Contra',
    N'Sch A-060 - Adjustments',
    N'Net unrealized loss on HFS loans per FAS 65. Must be <= 0.',
    N'Source: LOCOM valuation allowance GL | FAS 65 net unrealized loss on HFS | Must be <= 0',
    N'Dollar <= 0', 0, N'-95000', 92,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060AF', N'Reserve For Credit Losses On Loans',
    N'Sch A-060 - Adjustments',
    N'Credit loss reserve on HFI loans at amortized cost. N/A for HFS or FV loans. Must equal O060.',
    N'Source: ALLL GL contra | Filter: HFI at amortized cost only | Must equal O060 | Negative',
    N'Dollar (negative contra)', 0, N'-310000', 93,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060AG', N'Total Adjustments',
    N'Sch A-060 - Adjustments',
    N'Sum of A060X to A060AF per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: verify roll-up',
    N'Dollar', 1, N'-433000', 94,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060T', N'Total Mortgage Loans, UPB (after adjustments)',
    N'Sch A-060',
    N'Sum of A060W and A060AG per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: UPB AS OF period end. | Notes: classify by loan_type / lien / rate_type / conforming status; split HFS vs HFI columns per accounting designation; adjustments rows come from GL contra accounts',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'30867000', 95,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060AH', N'MEMO: UPB of Loans Accounted for as Financings',
    N'Sch A-060 - Memo',
    N'UPB in A060W from securitizations treated as financings under FAS 140 (not sales). Related debt on B020.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''MEMO: UPB of Loans Accounted for as Financings'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 96,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060AHNOTE', N'A060AH Explanatory Note',
    N'Sch A-060 - Memo',
    N'Free text.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''A060AH Explanatory Note'' | Notes: verify roll-up',
    N'Free text', 0, N'N/A - no financing-treatment securitizations.', 97,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060AI', N'MEMO: UPB of Loans on Non-Accrual Status',
    N'Sch A-060 - Memo',
    N'UPB in A060W on non-accrual (interest no longer accrued due to delinquency).',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''MEMO: UPB of Loans on Non-Accrual Status'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'480000', 98,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A060AINOTE', N'A060AI Explanatory Notes',
    N'Sch A-060 - Memo',
    N'Free text.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''A060AI Explanatory Notes'' | Notes: verify roll-up',
    N'Free text', 0, N'Non-accrual = 90+ days delinquent per company policy.', 99,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A090A', N'Other Real Estate Owned, at Cost',
    N'Sch A-090 - Other Real Estate Owned',
    N'Investment in real estate acquired via foreclosure, deed-in-lieu, or similar.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other Real Estate Owned, at Cost'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'580000', 100,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A090B', N'Valuation Allowance Contra',
    N'Sch A-090 - Other Real Estate Owned',
    N'Net unrealized loss (cost over market) on REO in A090A. Must be <= 0. Must equal O130.',
    N'Source: REO allowance GL | Must be <= 0 | Must equal O130',
    N'Dollar <= 0', 0, N'-40000', 101,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A090T', N'Other Real Estate Owned at Net Realizable Value',
    N'Sch A-090 - Other Real Estate Owned',
    N'A090A + A090B.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'540000', 102,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A120A', N'Balance at Beginning of Period',
    N'Sch A-120R - Rollforward of Amortized MSRs',
    N'Net Amortized MSR asset at period start; equals prior period ending net Amortized MSR (FAS 156/140 method).',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Balance at Beginning of Period'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'9400000', 103,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A120B', N'Additions: from Transfers of Financial Assets',
    N'Sch A-120R - Rollforward of Amortized MSRs',
    N'Amortized MSRs capitalized with loan sale/securitization during period.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Additions: from Transfers of Financial Assets'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'620000', 104,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A120C', N'Additions: From Purchases and Other Assumptions',
    N'Sch A-120R - Rollforward of Amortized MSRs',
    N'Amortized MSRs purchased or otherwise assumed during period.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Additions: From Purchases and Other Assumptions'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 105,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A120D', N'Disposals: Sales and Other',
    N'Sch A-120R - Rollforward of Amortized MSRs',
    N'MSRs written off due to MSR sale. Servicing-released premiums go to C330. Must be <= 0.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Disposals: Sales and Other'' | Notes: verify roll-up',
    N'Dollar <= 0', 0, N'-150000', 106,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A120E', N'Amortization',
    N'Sch A-120R - Rollforward of Amortized MSRs',
    N'MSR amortization during quarter. Must be <= 0.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Amortization'' | Notes: verify roll-up',
    N'Dollar <= 0', 0, N'-280000', 107,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A120F', N'Other Than Temporary Impairment (OTTI)',
    N'Sch A-120R - Rollforward of Amortized MSRs',
    N'Amortized MSRs written off for OTTI during period. Must be <= 0.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other Than Temporary Impairment (OTTI)'' | Notes: verify roll-up',
    N'Dollar <= 0', 0, N'0', 108,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A120G', N'Basis Adjustments from Net Hedging Activity',
    N'Sch A-120R - Rollforward of Amortized MSRs',
    N'Effective-portion hedge basis adjustments per FAS 133.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Basis Adjustments from Net Hedging Activity'' | Notes: verify roll-up',
    N'Dollar (may be negative)', 0, N'0', 109,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A120H', N'Other Changes',
    N'Sch A-120R - Rollforward of Amortized MSRs',
    N'Other changes not reported above.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other Changes'' | Notes: verify roll-up',
    N'Dollar (may be negative)', 0, N'0', 110,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A120T', N'Balance at End of Period',
    N'Sch A-120R - Rollforward of Amortized MSRs',
    N'Sum of A120A through A120H.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'9590000', 111,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A130A', N'Balance at Beginning of Period',
    N'Sch A-120R - MSR Valuation Allowance',
    N'Amortized MSR valuation allowance at period start (stratified impairment/LOCOM). N/A for FV MSRs.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Balance at Beginning of Period'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'120000', 112,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A130B', N'Change in Valuation Allowance',
    N'Sch A-120R - MSR Valuation Allowance',
    N'Change in Amortized MSR valuation allowance; positive or negative. N/A for FV MSRs.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Change in Valuation Allowance'' | Notes: verify roll-up',
    N'Dollar (may be negative)', 0, N'-30000', 113,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A130T', N'Balance at End of Period',
    N'Sch A-120R - MSR Valuation Allowance',
    N'A130A + A130B.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'90000', 114,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A140T', N'Total Amortized MSRs, Net of Valuation Allowance, at End of Period',
    N'Sch A-120R',
    N'A120T minus A130T; net carrying value of Amortized MSRs at period end.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: activity DURING period; balances at start/end. | Notes: beginning balance must equal prior quarter ending; separate Amortized-method vs FV-method populations per FAS 156 election',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'9500000', 115,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A130E', N'MEMO: Fair Value of Amortized MSRs at End of Period',
    N'Sch A-120R - Memo',
    N'Fair value of entire Amortized MSR portfolio; should be >= A140T.',
    N'Source: MSR fair value from valuation model | Memo | Should be >= A140T (otherwise impairment indicated)',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'10400000', 116,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A150A', N'Balance at Beginning of Period',
    N'Sch A-120R - Rollforward of Fair Value MSRs',
    N'Net FV MSR asset at period start; equals prior ending or zero if FV option first elected this period (FAS 156).',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Balance at Beginning of Period'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'6900000', 117,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A150B', N'Remeasurement of MSRs to FV upon Adoption of FAS 156',
    N'Sch A-120R - Rollforward of Fair Value MSRs',
    N'Pretax cumulative-effect adjustment to retained earnings from FAS 156 FV election; beginning of fiscal year only.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Remeasurement of MSRs to FV upon Adoption of FAS 156'' | Notes: verify roll-up',
    N'Dollar (may be negative)', 0, N'0', 118,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A150C', N'Additions: from Transfers of Financial Assets',
    N'Sch A-120R - Rollforward of Fair Value MSRs',
    N'FV MSRs capitalized with loan sale/securitization.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Additions: from Transfers of Financial Assets'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'540000', 119,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A150D', N'Additions: from Purchases and Other Assumptions',
    N'Sch A-120R - Rollforward of Fair Value MSRs',
    N'FV MSRs purchased or assumed during period.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Additions: from Purchases and Other Assumptions'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 120,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A150E', N'Reductions: from MSRs Sold',
    N'Sch A-120R - Rollforward of Fair Value MSRs',
    N'FV MSRs written off due to MSR sale. SRPs go to C330. Must be <= 0.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Reductions: from MSRs Sold'' | Notes: verify roll-up',
    N'Dollar <= 0', 0, N'0', 121,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A150F', N'Change in Value Due to Realization of Cash Flows',
    N'Sch A-120R - Rollforward of Fair Value MSRs',
    N'FV MSR value change from realized cash flows per FAS 156.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Change in Value Due to Realization of Cash Flows'' | Notes: verify roll-up',
    N'Dollar (may be negative)', 0, N'-190000', 122,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A150G', N'Change in Value Due to Market and Model Changes',
    N'Sch A-120R - Rollforward of Fair Value MSRs',
    N'FV MSR value change from market/model changes per FAS 156.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Change in Value Due to Market and Model Changes'' | Notes: verify roll-up',
    N'Dollar (may be negative)', 0, N'50000', 123,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A150H', N'Other Changes',
    N'Sch A-120R - Rollforward of Fair Value MSRs',
    N'Other FV MSR changes not reported separately.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other Changes'' | Notes: verify roll-up',
    N'Dollar (may be negative)', 0, N'0', 124,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A150T', N'Balance at End of Period',
    N'Sch A-120R - Rollforward of Fair Value MSRs',
    N'Sum of A150A to A150H.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'7300000', 125,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A160T', N'Total MSRs at End of Period',
    N'Sch A-120R',
    N'A140T + A150T.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: activity DURING period; balances at start/end. | Notes: beginning balance must equal prior quarter ending; separate Amortized-method vs FV-method populations per FAS 156 election',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'16800000', 126,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A220A', N'Interest Rate Lock Commitments (IRLCs)',
    N'Sch A-220 - Derivatives',
    N'IRLCs meeting FAS 133 derivative definition. Report in asset or liability column as applicable.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Interest Rate Lock Commitments (IRLCs)'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'Assets 210000 | Liabilities 45000', 127,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A220B', N'Other Loan Commitments Classified as Derivatives',
    N'Sch A-220 - Derivatives',
    N'Other loan commitments meeting FAS 133 derivative definition.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other Loan Commitments Classified as Derivatives'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0 | 0', 128,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A220C', N'Derivatives Designated as Hedges of Funded Loans',
    N'Sch A-220 - Derivatives',
    N'Derivatives designated as hedges of closed loans.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Derivatives Designated as Hedges of Funded Loans'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0 | 0', 129,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A220D', N'Derivatives Designated as Hedges of MSRs',
    N'Sch A-220 - Derivatives',
    N'Derivatives designated as MSR hedges per FAS 133.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Derivatives Designated as Hedges of MSRs'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'85000 | 0', 130,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A220E', N'Derivatives Designated As Hedges Other',
    N'Sch A-220 - Derivatives',
    N'Other designated hedge derivatives per FAS 133, excluding those reported separately.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Derivatives Designated As Hedges Other'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0 | 0', 131,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A220F', N'Derivatives Not Designated as Hedges',
    N'Sch A-220 - Derivatives',
    N'Free-standing derivatives incl. economic hedges of FV items (IRLCs, HFS at FV).',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Derivatives Not Designated as Hedges'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'115000 | 30000', 132,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A220T', N'Total Derivatives',
    N'Sch A-220 - Derivatives',
    N'Sum of A220A to A220F per column. Asset total = A220; liability total = B180.',
    N'Calculated per column | Asset column total = A220; liability column total = B180',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'Assets 410000 | Liabilities 75000', 133,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A220G', N'MEMO: UPB of IRLCs before Fallout Adjustments',
    N'Sch A-220 - Memo',
    N'Gross IRLC UPB before excluding locks not expected to close.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''MEMO: UPB of IRLCs before Fallout Adjustments'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'14600000', 134,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A220H', N'MEMO: UPB of IRLCs after Fallout Adjustments',
    N'Sch A-220 - Memo',
    N'IRLC UPB after estimated fallout adjustment.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''MEMO: UPB of IRLCs after Fallout Adjustments'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'11300000', 135,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230A', N'Securities Borrowed',
    N'Sch A-230 - Other Assets',
    N'Carrying value of securities borrowed under repurchase agreements.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Securities Borrowed'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 136,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230E', N'Advances Other',
    N'Sch A-230 - Other Assets',
    N'All other advances not reportable separately. Employee advances go to A190.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Advances Other'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'35000', 137,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230G', N'Current Income Taxes Receivable',
    N'Sch A-230 - Other Assets',
    N'Current taxes receivable. Deferred taxes receivable go to A200.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Current Income Taxes Receivable'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'60000', 138,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230GNOTE', N'A230G Explanatory Notes',
    N'Sch A-230 - Other Assets',
    N'Free text.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''A230G Explanatory Notes'' | Notes: verify roll-up',
    N'Free text', 0, N'Q1 federal overpayment applied to Q2.', 139,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230H', N'Other Assets Other',
    N'Sch A-230 - Other Assets',
    N'All other tangible assets: deposits (lease, utility, tax), FSA receivables, licenses, prepaids, clearing/suspense accounts, commitment fees, etc.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Other Assets Other'' | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'425000', 140,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230HNOTE', N'A230H Explanatory Notes',
    N'Sch A-230 - Other Assets',
    N'Free text.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''A230H Explanatory Notes'' | Notes: verify roll-up',
    N'Free text', 0, N'Primarily prepaid E&O insurance and lease deposits.', 141,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230T', N'Total Other Assets',
    N'Sch A-230 - Other Assets',
    N'Sum of A230A through A230H, excluding A230C, A230D, A230F.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: verify roll-up',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'520000', 142,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230I', N'Other Assets Other as Percentage of Total Assets',
    N'Sch A-230 - Other Assets',
    N'A230H / A240. Explanation required in A230J if >= 5%.',
    N'Calculated: A230H / A240 | If >= 5%, A230J explanation REQUIRED',
    N'Two-decimal %', 1, N'0.53', 143,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'A230J', N'Explanation of Amounts in Other Assets Other',
    N'Sch A-230 - Other Assets',
    N'Required if A230I >= 5%.',
    N'Source: calculated from Schedule A lines | Timing: AS OF period end | Filter/classification: per definition - ''Explanation of Amounts in Other Assets Other'' | Notes: verify roll-up',
    N'Text, 4000 char max', 0, N'N/A - below 5% threshold.', 144,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B009', N'Outstanding Balance on Warehouse Lines of Credit',
    N'Sch B - Current Liabilities',
    N'Outstanding warehouse LOC balance used to fund mortgages.',
    N'Source: warehouse facility system drawn balances | Timing: AS OF period end | Must be consistent with LOC section remaining-available math (limit - drawn)',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'13650000', 145,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B010', N'Outstanding Balance on Debt Facilities',
    N'Sch B - Current Liabilities',
    N'Outstanding LOC balances incl. repurchase-loan and MSR financing lines, reverse repo facilities (seller/borrower side), ABCP; affiliate and non-affiliate.',
    N'Source: GL trial balance / debt subledger | Timing: balance AS OF period end | Filter/classification: per definition - ''Outstanding Balance on Debt Facilities'' | Notes: B009 warehouse draws must tie to warehouse system used for LOC section',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'5200000', 146,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B070', N'Commercial Paper',
    N'Sch B - Current Liabilities',
    N'Unsecured short-term corporate debt for receivables/inventory/short-term liabilities.',
    N'Source: GL trial balance / debt subledger | Timing: balance AS OF period end | Filter/classification: per definition - ''Commercial Paper'' | Notes: B009 warehouse draws must tie to warehouse system used for LOC section',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 147,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B080', N'Other Short-Term Payables to Related Parties',
    N'Sch B - Current Liabilities',
    N'Short-term related-party payables maturing within a year, incl. accrued interest to related parties. Accrued payroll goes to B100.',
    N'Source: GL trial balance / debt subledger | Timing: balance AS OF period end | Filter/classification: per definition - ''Other Short-Term Payables to Related Parties'' | Notes: B009 warehouse draws must tie to warehouse system used for LOC section',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'110000', 148,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B090', N'Other Short-Term Notes Payable to Unrelated Parties',
    N'Sch B - Current Liabilities',
    N'Short-term unrelated-party notes maturing within a year, not included above.',
    N'Source: GL trial balance / debt subledger | Timing: balance AS OF period end | Filter/classification: per definition - ''Other Short-Term Notes Payable to Unrelated Parties'' | Notes: B009 warehouse draws must tie to warehouse system used for LOC section',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'250000', 149,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B100', N'Accrued Expenses',
    N'Sch B - Current Liabilities',
    N'Accrued liabilities to unrelated parties (rent, utilities, sales taxes); all accrued payroll.',
    N'Source: GL trial balance / debt subledger | Timing: balance AS OF period end | Filter/classification: per definition - ''Accrued Expenses'' | Notes: B009 warehouse draws must tie to warehouse system used for LOC section',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'640000', 150,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B120', N'Other Current Liabilities',
    N'Sch B - Current Liabilities',
    N'Other short-term liabilities: unearned revenue, deferred non-loan fees, undisbursed mortgage principal, current tax liabilities.',
    N'Source: GL trial balance / debt subledger | Timing: balance AS OF period end | Filter/classification: per definition - ''Other Current Liabilities'' | Notes: B009 warehouse draws must tie to warehouse system used for LOC section',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'480000', 151,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B217', N'Total Current Liabilities',
    N'Sch B - Current Liabilities',
    N'B009 + B010 + B070 + B080 + B090 + B100 + B120.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: balance AS OF period end. | Notes: B009 warehouse draws must tie to warehouse system used for LOC section',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'20330000', 152,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B020', N'Collateralized Mortgage Debt Relating to Financings',
    N'Sch B - Long-Term Liabilities',
    N'Debt from securitizations treated as financings under FAS 140; related loans on Sch A-060.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Collateralized Mortgage Debt Relating to Financings'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 153,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B030', N'Collateralized Mortgage Debt Other',
    N'Sch B - Long-Term Liabilities',
    N'Collateralized mortgage debt not reported separately.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Collateralized Mortgage Debt Other'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 154,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B040', N'Trust Preferred Securities',
    N'Sch B - Long-Term Liabilities',
    N'Securities created via trust issuing debt; counted toward regulatory capital.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Trust Preferred Securities'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 155,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B050', N'Deposits',
    N'Sch B - Long-Term Liabilities',
    N'Demand accounts, money market accounts, CD balances.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Deposits'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 156,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B060', N'Advances from Federal Home Loan Banks',
    N'Sch B - Long-Term Liabilities',
    N'FHLB advances.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Advances from Federal Home Loan Banks'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 157,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B110', N'Estimated Future Loss Liability (Recourse)',
    N'Sch B - Long-Term Liabilities',
    N'Allowance for losses on off-balance-sheet items: recourse obligations, guarantees, litigation.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Estimated Future Loss Liability (Recourse)'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'175000', 158,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B130', N'Other Long-Term Liabilities to Related Parties',
    N'Sch B - Long-Term Liabilities',
    N'Total long-term related-party liabilities.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Other Long-Term Liabilities to Related Parties'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 159,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B140', N'Other Long-Term Liabilities to Unrelated Parties',
    N'Sch B - Long-Term Liabilities',
    N'All other long-term liabilities not included above.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Other Long-Term Liabilities to Unrelated Parties'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'900000', 160,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B150', N'Servicing Liabilities',
    N'Sch B - Long-Term Liabilities',
    N'Servicing liabilities recognized per FAS 125/140/156 and other pronouncements.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Servicing Liabilities'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'60000', 161,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B160', N'Guaranty Liabilities under FIN 45',
    N'Sch B - Long-Term Liabilities',
    N'Carrying amount of FIN 45 guaranty liabilities.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Guaranty Liabilities under FIN 45'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 162,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B170', N'Other Financial Instrument Liabilities, at Fair Value',
    N'Sch B - Long-Term Liabilities',
    N'FV of FAS 159-elected instruments where FV is a liability. Excludes HFS/HFI at FV.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Other Financial Instrument Liabilities, at Fair Value'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 163,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B180', N'Derivative Liabilities',
    N'Sch B - Long-Term Liabilities',
    N'Total from Sch A-220 liability column; derivatives carried as liabilities per FAS 133.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Derivative Liabilities'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'75000', 164,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B190', N'Taxes Payable',
    N'Sch B - Long-Term Liabilities',
    N'Current income taxes payable on taxable income.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Taxes Payable'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'140000', 165,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B200', N'Deferred Tax Liability',
    N'Sch B - Long-Term Liabilities',
    N'Deferred income taxes payable; income earned for book but not yet for tax.',
    N'Source: GL trial balance | Timing: AS OF period end | Filter/classification: per definition - ''Deferred Tax Liability'' | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'820000', 166,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B210', N'Repurchase Reserves',
    N'Sch B - Long-Term Liabilities',
    N'Liabilities for reps/warranties, EPD, FPD, premium recapture, other repurchase obligations. Must equal O350.',
    N'Source: repurchase reserve GL | Timing: AS OF period end | Completeness: must equal O350',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'390000', 167,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B219', N'Total Long-Term Liabilities',
    N'Sch B - Long-Term Liabilities',
    N'B020+B030+B040+B050+B060+B110+B130+B140+B150+B160+B170+B180+B190+B200+B210.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: reserve lines tie to Schedule O endings',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'2560000', 168,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B220', N'Total Liabilities',
    N'Sch B',
    N'B217 + B219.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: A240 must equal B360',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'22890000', 169,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B250', N'Preferred Stock, Issued and Outstanding',
    N'Sch B - Equity (Corporations)',
    N'Par value of preferred stock issued/outstanding incl. unretired preferred treasury stock.',
    N'Source: equity GL accounts / cap table | Timing: AS OF period end | Filter/classification: per definition - ''Preferred Stock, Issued and Outstanding'' | Notes: par vs APIC split from stock records',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 170,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B260', N'Common Stock, Issued and Outstanding',
    N'Sch B - Equity (Corporations)',
    N'Par value of common stock issued/outstanding incl. ESOP set-asides.',
    N'Source: equity GL accounts / cap table | Timing: AS OF period end | Filter/classification: per definition - ''Common Stock, Issued and Outstanding'' | Notes: par vs APIC split from stock records',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'100000', 171,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B270', N'Additional Paid-In Capital',
    N'Sch B - Equity (Corporations)',
    N'Paid-in capital in excess of par plus capital contributions.',
    N'Source: equity GL accounts / cap table | Timing: AS OF period end | Filter/classification: per definition - ''Additional Paid-In Capital'' | Notes: par vs APIC split from stock records',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'18400000', 172,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B280', N'Retained Earnings',
    N'Sch B - Equity (Corporations)',
    N'Retained earnings less par value of ESOP set-aside stock.',
    N'Source: equity GL accounts / cap table | Timing: AS OF period end | Filter/classification: per definition - ''Retained Earnings'' | Notes: par vs APIC split from stock records',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'38200000', 173,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B290', N'Treasury Stock',
    N'Sch B - Equity (Corporations)',
    N'Non-preferred treasury stock not retired.',
    N'Source: equity GL accounts / cap table | Timing: AS OF period end | Filter/classification: per definition - ''Treasury Stock'' | Notes: par vs APIC split from stock records',
    N'Dollar (contra)', 0, N'-450000', 174,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B300', N'Other Comprehensive Income (OCI)',
    N'Sch B - Equity (Corporations)',
    N'Non-owner equity changes: after-tax unrealized gains/losses on securities, FX translation, per FAS 130.',
    N'Source: equity GL accounts / cap table | Timing: AS OF period end | Filter/classification: per definition - ''Other Comprehensive Income (OCI)'' | Notes: par vs APIC split from stock records',
    N'Dollar (may be negative)', 0, N'67000', 175,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B310', N'Noncontrolling Interest',
    N'Sch B - Equity (Corporations)',
    N'Noncontrolling interests in consolidated subsidiaries per FAS 160.',
    N'Source: equity GL accounts / cap table | Timing: AS OF period end | Filter/classification: per definition - ''Noncontrolling Interest'' | Notes: par vs APIC split from stock records',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 176,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B240', N'Subordinated Debt',
    N'Sch B - Equity (Corporations)',
    N'Debt subordinated to all other debt.',
    N'Source: equity GL accounts / cap table | Timing: AS OF period end | Filter/classification: per definition - ''Subordinated Debt'' | Notes: par vs APIC split from stock records',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'1000000', 177,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B319', N'Total Corporate Equity',
    N'Sch B - Equity (Corporations)',
    N'B250+B260+B270+B280+B290+B300+B310+B240.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: par vs APIC split from stock records',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'57317000', 178,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B320', N'General Partners'' Capital',
    N'Sch B - Equity (Partnerships/Sole Prop)',
    N'Total capital of general partners or sole proprietor.',
    N'Source: capital accounts | Timing: AS OF period end | Filter/classification: per definition - ''General Partners'' Capital''',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 179,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B330', N'Limited Partners'' Capital',
    N'Sch B - Equity (Partnerships)',
    N'Total capital of limited partners.',
    N'Source: capital accounts | Timing: AS OF period end | Filter/classification: per definition - ''Limited Partners'' Capital''',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 180,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B340', N'Members'' Capital',
    N'Sch B - Equity (Partnerships)',
    N'Total capital of unincorporated companies without partners (LLC members).',
    N'Source: capital accounts | Timing: AS OF period end | Filter/classification: per definition - ''Members'' Capital''',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 181,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B349', N'Total Limited Partnership and Members Capital',
    N'Sch B - Equity (Partnerships)',
    N'B330 + B340.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end.',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'0', 182,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350', N'Total Equity',
    N'Sch B - Equity (All Companies)',
    N'B319 + B320 + B349.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end.',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'57317000', 183,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B360', N'Total Liabilities and Equity',
    N'Sch B',
    N'B220 + B350.',
    N'Calculated: B220 + B350. Completeness: must equal A240 (balance sheet must balance)',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'80207000', 184,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350A', N'Balance at Beginning of Period',
    N'Sch B-350R - Equity Rollforward',
    N'Total equity at quarter start; equals prior period B350.',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''Balance at Beginning of Period'' | Notes: A240 must equal B360',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'55950000', 185,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350B', N'Net Income / (Loss)',
    N'Sch B-350R - Equity Rollforward',
    N'Must equal D600.',
    N'Source: income statement | Completeness: must equal D600',
    N'Dollar (may be negative)', 0, N'1367000', 186,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350C', N'Issuance of New Stock or Conversions of Preferred to Common',
    N'Sch B-350R - Equity Rollforward',
    N'Proceeds from common/preferred stock issued during period.',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''Issuance of New Stock or Conversions of Preferred to Common'' | Notes: A240 must equal B360',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 187,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350D', N'Stock Repurchases',
    N'Sch B-350R - Equity Rollforward',
    N'Cost of non-preferred treasury stock repurchased during period.',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''Stock Repurchases'' | Notes: A240 must equal B360',
    N'Dollar (contra)', 0, N'0', 188,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350E', N'Other Capital Contributions',
    N'Sch B-350R - Equity Rollforward',
    N'Capital contributions received (parent, stockholders, partners).',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''Other Capital Contributions'' | Notes: A240 must equal B360',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 189,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350F', N'OCI: Unrealized Gains/(Losses) from Assets Available-for-Sale',
    N'Sch B-350R - Equity Rollforward',
    N'Unrealized AFS gain/loss for the quarter per FAS 115/134/130.',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''OCI: Unrealized Gains/(Losses) from Assets Available-for-Sale'' | Notes: A240 must equal B360',
    N'Dollar (may be negative)', 0, N'12000', 190,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350G', N'OCI: Unrealized Gains/(Losses) from Derivatives Designated as Cash Flow Hedges',
    N'Sch B-350R - Equity Rollforward',
    N'Cash-flow-hedge gains/losses in OCI per FAS 133.',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''OCI: Unrealized Gains/(Losses) from Derivatives Designated as Cash Flow Hedges'' | Notes: A240 must equal B360',
    N'Dollar (may be negative)', 0, N'0', 191,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350H', N'OCI: Other Changes in OCI',
    N'Sch B-350R - Equity Rollforward',
    N'All other OCI changes (e.g., pension adjustments).',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''OCI: Other Changes in OCI'' | Notes: A240 must equal B360',
    N'Dollar (may be negative)', 0, N'0', 192,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350I', N'Cumulative Effect from Adoption of FAS 156',
    N'Sch B-350R - Equity Rollforward',
    N'After-tax cumulative-effect adjustment to retained earnings from FAS 156 election; fiscal-year start only.',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''Cumulative Effect from Adoption of FAS 156'' | Notes: A240 must equal B360',
    N'Dollar (may be negative)', 0, N'0', 193,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350J', N'Cumulative Effect from Adoption of FAS 159',
    N'Sch B-350R - Equity Rollforward',
    N'After-tax cumulative-effect adjustment from FAS 159 election; fiscal-year start only.',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''Cumulative Effect from Adoption of FAS 159'' | Notes: A240 must equal B360',
    N'Dollar (may be negative)', 0, N'0', 194,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350K', N'Cumulative Effect Adjustments to Retained Earnings Other',
    N'Sch B-350R - Equity Rollforward',
    N'Other cumulative-effect adjustments not reported separately.',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''Cumulative Effect Adjustments to Retained Earnings Other'' | Notes: A240 must equal B360',
    N'Dollar (may be negative)', 0, N'0', 195,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350L', N'Dividends/Distributions',
    N'Sch B-350R - Equity Rollforward',
    N'Dividends/distributions paid during period. Must be <= 0.',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''Dividends/Distributions'' | Notes: A240 must equal B360',
    N'Dollar <= 0', 0, N'-12000', 196,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350M', N'Changes in Carrying Amount of Noncontrolling Interest',
    N'Sch B-350R - Equity Rollforward',
    N'Equity changes for noncontrolling interests per FAS 160.',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''Changes in Carrying Amount of Noncontrolling Interest'' | Notes: A240 must equal B360',
    N'Dollar (may be negative)', 0, N'0', 197,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350N', N'Equity Adjustments',
    N'Sch B-350R - Equity Rollforward',
    N'Changes/adjustments not reported on other lines.',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''Equity Adjustments'' | Notes: A240 must equal B360',
    N'Dollar (may be negative)', 0, N'0', 198,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350NNOTE', N'B350N Explanatory Notes',
    N'Sch B-350R - Equity Rollforward',
    N'Free text.',
    N'Source: calculated | Timing: AS OF period end | Filter/classification: per definition - ''B350N Explanatory Notes'' | Notes: A240 must equal B360',
    N'Free text', 0, N'N/A', 199,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'B350T', N'Balance at End of Period',
    N'Sch B-350R - Equity Rollforward',
    N'Sum of B350A to B350N.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF period end. | Notes: A240 must equal B360',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'57317000', 200,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C010', N'Residential Loans Held For Sale',
    N'Sch C - Interest Income',
    N'Interest earned on warehousing of 1-4 unit and MF/commercial loans incl. warehouse LOC, collateralized repo LOC, ABCP, other origination-financing debt.',
    N'Source: GL interest income accounts by asset class | Timing: earned DURING period | Filter/classification: per definition - ''Residential Loans Held For Sale'' | Notes: column split: production vs servicing vs portfolio per form columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'412000', 201,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C020', N'Loans Held for Investment',
    N'Sch C - Interest Income',
    N'Total interest income on HFI loans.',
    N'Source: GL interest income accounts by asset class | Timing: earned DURING period | Filter/classification: per definition - ''Loans Held for Investment'' | Notes: column split: production vs servicing vs portfolio per form columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'365000', 202,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C030', N'Securities Held to Maturity',
    N'Sch C - Interest Income',
    N'Interest income from HTM securities.',
    N'Source: GL interest income accounts by asset class | Timing: earned DURING period | Filter/classification: per definition - ''Securities Held to Maturity'' | Notes: column split: production vs servicing vs portfolio per form columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'9000', 203,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C040', N'Securities Available for Sale',
    N'Sch C - Interest Income',
    N'Interest income from AFS securities; MF/commercial AFS in MF/commercial column, all other in Residential Portfolio Mgmt and All Other column.',
    N'Source: GL interest income accounts by asset class | Timing: earned DURING period | Filter/classification: per definition - ''Securities Available for Sale'' | Notes: column split: production vs servicing vs portfolio per form columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'18000', 204,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C050', N'Trading Securities',
    N'Sch C - Interest Income',
    N'Interest income from trading securities, by column as in C040.',
    N'Source: GL interest income accounts by asset class | Timing: earned DURING period | Filter/classification: per definition - ''Trading Securities'' | Notes: column split: production vs servicing vs portfolio per form columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'7000', 205,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C060', N'Other Interest Income',
    N'Sch C - Interest Income',
    N'Interest income not reported above.',
    N'Source: GL interest income accounts by asset class | Timing: earned DURING period | Filter/classification: per definition - ''Other Interest Income'' | Notes: column split: production vs servicing vs portfolio per form columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'11000', 206,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C070', N'Recognition of Yield Adjustment',
    N'Sch C - Interest Income',
    N'Amortization of FAS 91 deferred amounts.',
    N'Source: GL interest income accounts by asset class | Timing: earned DURING period | Filter/classification: per definition - ''Recognition of Yield Adjustment'' | Notes: column split: production vs servicing vs portfolio per form columns',
    N'Dollar (may be negative)', 0, N'24000', 207,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C080', N'Servicing-Related/Escrow',
    N'Sch C - Interest Income',
    N'Interest income from servicing-related P&I and T&I custodial accounts.',
    N'Source: GL interest income accounts by asset class | Timing: earned DURING period | Filter/classification: per definition - ''Servicing-Related/Escrow'' | Notes: column split: production vs servicing vs portfolio per form columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'58000', 208,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C090', N'Total Interest Income',
    N'Sch C - Interest Income',
    N'Sum of C010 to C080 per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: earned DURING period. | Notes: column split: production vs servicing vs portfolio per form columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'904000', 209,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C200', N'Discounts on FV of LHS',
    N'Sch C - Origination-Related Non-Interest Income',
    N'Income effect of discounts received/premiums paid on FAS 159 FV-elected originated loans held for sale.',
    N'Source: GL fee income accounts + LOS fee detail | Timing: earned DURING period | Filter/classification: per definition - ''Discounts on FV of LHS'' | Notes: FAS 91 reclass contra (C250) offsets to gain-on-sale',
    N'Dollar (may be negative)', 0, N'31000', 210,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C210', N'Origination Fees',
    N'Sch C - Origination-Related Non-Interest Income',
    N'Origination fee income from retail and direct marketing production.',
    N'Source: GL fee income accounts + LOS fee detail | Timing: earned DURING period | Filter/classification: per definition - ''Origination Fees'' | Notes: FAS 91 reclass contra (C250) offsets to gain-on-sale',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'487000', 211,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C220', N'Fees Received from Correspondents and Brokers',
    N'Sch C - Origination-Related Non-Interest Income',
    N'Fee income on loans acquired from correspondents and brokers.',
    N'Source: GL fee income accounts + LOS fee detail | Timing: earned DURING period | Filter/classification: per definition - ''Fees Received from Correspondents and Brokers'' | Notes: FAS 91 reclass contra (C250) offsets to gain-on-sale',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'64000', 212,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C230', N'Broker Fees Received on Loans Brokered Out',
    N'Sch C - Origination-Related Non-Interest Income',
    N'Fees for loans brokered out; balance/count excluded from origination volume, reported in I420.',
    N'Source: GL fee income accounts + LOS fee detail | Timing: earned DURING period | Filter/classification: per definition - ''Broker Fees Received on Loans Brokered Out'' | Notes: FAS 91 reclass contra (C250) offsets to gain-on-sale',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'18000', 213,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C240', N'Other Origination Related Income',
    N'Sch C - Origination-Related Non-Interest Income',
    N'Other origination income (borrower-paid credit report, appraisal, photo fees). Offsetting expenses in D280.',
    N'Source: GL fee income accounts + LOS fee detail | Timing: earned DURING period | Filter/classification: per definition - ''Other Origination Related Income'' | Notes: FAS 91 reclass contra (C250) offsets to gain-on-sale',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'42000', 214,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C250', N'Contra: Amounts Reclassified',
    N'Sch C - Origination-Related Non-Interest Income',
    N'Fee income from C210-C240 reclassified as gain on sale or deferred per FAS 91.',
    N'Source: GL fee income accounts + LOS fee detail | Timing: earned DURING period | Filter/classification: per definition - ''Contra: Amounts Reclassified'' | Notes: FAS 91 reclass contra (C250) offsets to gain-on-sale',
    N'Dollar (contra)', 0, N'-96000', 215,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C260', N'Total Origination Related Non-Interest Income',
    N'Sch C - Origination-Related Non-Interest Income',
    N'Sum of C200 to C250 per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: earned DURING period. | Notes: FAS 91 reclass contra (C250) offsets to gain-on-sale',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'546000', 216,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C300', N'Gain on Loans/MBS Sold with Servicing Retained',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'Sales price vs carrying value on servicing-retained sales, loan/MBS portion only. Servicing capitalization in C310; FAS 91 fees in C210/C220; option premiums in C380.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Gain on Loans/MBS Sold with Servicing Retained'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'218000', 217,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C310', N'Capitalized Servicing on Loans/MBS Sold with Servicing Retained',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'Gain/loss portion allocated to servicing rights capitalization.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Capitalized Servicing on Loans/MBS Sold with Servicing Retained'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'620000', 218,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C320', N'Gain on Loans/MBS Sold with Servicing Released',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'Sales price vs carrying value on servicing-released sales, loan portion only. SRP in C330; fees in C210/C220; hedge costs in C380.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Gain on Loans/MBS Sold with Servicing Released'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'341000', 219,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C330', N'Servicing Released Premiums on Loans/MBS Sold',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'Gain/loss portion related to servicing released premium received.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Servicing Released Premiums on Loans/MBS Sold'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'296000', 220,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C340', N'Fees Paid to Brokers',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'YSP and other broker fees if not reported separately; direct gain-on-sale adjustment method. Must be <= 0.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Fees Paid to Brokers'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar <= 0', 0, N'-118000', 221,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C350', N'Direct Fees Reclassified as Gain on Sale',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'Fee income reclassified to gain on sale per FAS 91.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Direct Fees Reclassified as Gain on Sale'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'96000', 222,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C360', N'Direct Expenses Reclassified as Gain on Sale',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'Direct expenses reclassified to gain on sale per FAS 91.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Direct Expenses Reclassified as Gain on Sale'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'-71000', 223,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C370', N'Recognition of Retained Interests',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'Initial basis of retained securitization interests (residuals) via relative FV (FAS 140) or FV (FAS 159). Excludes MSRs.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Recognition of Retained Interests'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'0', 224,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C380', N'Pair-Off Expenses and Other Hedge Costs',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'Hedge costs incl. pair-off gains/losses and option premiums.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Pair-Off Expenses and Other Hedge Costs'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'-52000', 225,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C390', N'Provision for Repurchase Reserve',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'Provision for reps/warranties, EPD, FPD, premium recapture, other repurchase obligations. Must equal O320.',
    N'Source: repurchase provision | Completeness: must equal O320',
    N'Dollar (may be negative)', 0, N'-35000', 226,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C400', N'LOCOM Adjustments on Loans Held for Sale',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'P&L impact of LOCOM adjustments on certain HFS loans. N/A for HFS at FV.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''LOCOM Adjustments on Loans Held for Sale'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'-22000', 227,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C410', N'Income Relating to Interest Rate Lock Commitments (IRLCs)',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'IRLC gains/losses at inception (SAB 109) or after, per FAS 133. MSR-hedge derivatives in servicing section; other-instrument derivatives in other section.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Income Relating to Interest Rate Lock Commitments (IRLCs)'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'44000', 228,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C420', N'Gains on Derivatives Hedging Interest Rate Locks and Loans HFS',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'FAS 133 valuation gains/losses on derivatives hedging inventory/pipeline loans, regardless of hedge-accounting qualification.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Gains on Derivatives Hedging Interest Rate Locks and Loans HFS'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'-16000', 229,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C430', N'Gain on Changes in Fair Value of Loans HFS',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'Gains/losses from FV changes on HFS loans carried at FV (FAS 159).',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Gain on Changes in Fair Value of Loans HFS'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'58000', 230,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C440', N'Other Secondary Market Gains',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'Other gains/losses on loan sale or securitization.',
    N'Source: secondary marketing P&L / trade accounting + GL | Timing: settled/recognized DURING period | Filter/classification: per definition - ''Other Secondary Market Gains'' | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar (may be negative)', 0, N'0', 231,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C450', N'Net Secondary Marketing Income',
    N'Sch C - Secondary Marketing Gains/(Losses)',
    N'Sum of C300 to C440 per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: settled/recognized DURING period. | Notes: decompose gain on sale into loan gain, capitalized servicing (C310), SRP (C330), broker fees (C340 <= 0), hedge cost (C380); C390 ties to O320',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'1359000', 232,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C500', N'Servicing Fees on First Mortgages',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'Servicing fees on all first mortgages (1-4 unit, commercial, MF) before MSR amortization. Excludes subservicing fees. Net of guarantee fees.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Servicing Fees on First Mortgages'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'512000', 233,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C510', N'Servicing Fees on Other Mortgages',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'Servicing fees on seconds, reverse, and loans not in C500, before amortization.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Servicing Fees on Other Mortgages'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'21000', 234,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C520', N'Subservicing Fees (include Intercompany)',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'Fees earned servicing loans whose servicing rights you do not own, incl. affiliates.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Subservicing Fees (include Intercompany)'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'48000', 235,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C530', N'Subservicing Fees (Intracompany Only)',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'Formal internal arrangement: positive in Servicing column, negative in other columns; line total must be zero.',
    N'Source: intracompany servicing fee allocation | Rule: positive in Servicing column, negative in others; LINE TOTAL MUST BE ZERO across columns',
    N'Dollar (nets to zero across columns)', 0, N'Servicing +15000 | Other columns -15000', 236,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C540', N'Late Fees and Other Ancillary Fees',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'Loan admin income not above: late charges, borrower-paid processing fees.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Late Fees and Other Ancillary Fees'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'36000', 237,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C550', N'Amortization of MSRs',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'MSR amortization for the quarter. Enter as negative.',
    N'Source: MSR amortization from A120E | Enter as NEGATIVE | Ties to Sch A-120R',
    N'Dollar <= 0', 0, N'-280000', 238,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C560', N'Other Than Temporary Impairment of MSRs',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'Amortized MSRs written off for OTTI. Enter as negative.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Other Than Temporary Impairment of MSRs'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar <= 0', 0, N'0', 239,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C570', N'Changes in MSR Valuation Allowance',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'Amortized MSR valuation allowance change; gain or loss. N/A for FV MSRs.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Changes in MSR Valuation Allowance'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar (may be negative)', 0, N'30000', 240,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C580', N'Changes in MSR Value Due to Realized Cash Flows',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'FV MSR value change from realized cash flows per FAS 156.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Changes in MSR Value Due to Realized Cash Flows'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar (may be negative)', 0, N'-190000', 241,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C590', N'Changes in MSR Value Due to Market/Model Changes',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'FV MSR value change from market/model changes per FAS 156.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Changes in MSR Value Due to Market/Model Changes'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar (may be negative)', 0, N'50000', 242,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C600', N'Gains(Losses) on Derivatives Used to Hedge MSRs',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'FAS 133 gains/losses on MSR-hedging derivatives.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Gains(Losses) on Derivatives Used to Hedge MSRs'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar (may be negative)', 0, N'-12000', 243,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C610', N'Other Changes in MSR Value',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'Other FV MSR changes not reported separately.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Other Changes in MSR Value'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar (may be negative)', 0, N'0', 244,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C620', N'Net Gain on Bulk Sale of MSRs',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'Net gain/loss on bulk MSR sales. SRPs go to C330.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Net Gain on Bulk Sale of MSRs'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar (may be negative)', 0, N'0', 245,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C630', N'Net Gain on Sale of REO',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'Net gain/loss on REO sales.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Net Gain on Sale of REO'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar (may be negative)', 0, N'-8000', 246,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C640', N'Other Servicing-Related Income',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'Other servicing income not reported elsewhere.',
    N'Source: servicing fee income GL + MSR valuation output | Timing: earned DURING period | Filter/classification: per definition - ''Other Servicing-Related Income'' | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'14000', 247,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C650', N'Total Servicing-Related Non-Interest Income',
    N'Sch C - Servicing-Related Non-Interest Income',
    N'Sum of C500 to C640 per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: earned DURING period. | Notes: C550 ties to A120E; C570 ties to A130B; C580/C590 tie to A150F/A150G; C530 must net to zero across columns',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'221000', 248,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C720', N'Gain from Sale of Securities',
    N'Sch C - Other Non-Interest Income',
    N'Realized/unrealized gain (loss) on security sales (HTM, AFS, trading). Origination/secondary-marketing security gains go to C300/C320; trading unrealized to C730; AFS unrealized to B350F.',
    N'Source: GL | Timing: DURING period | Filter/classification: per definition - ''Gain from Sale of Securities''',
    N'Dollar (may be negative)', 0, N'6000', 249,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C730', N'Unrealized Gain on Trading Securities',
    N'Sch C - Other Non-Interest Income',
    N'Unrealized FV gains/losses on trading securities.',
    N'Source: GL | Timing: DURING period | Filter/classification: per definition - ''Unrealized Gain on Trading Securities''',
    N'Dollar (may be negative)', 0, N'3000', 250,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C740', N'Gain on Other Derivatives/Financial Instruments',
    N'Sch C - Other Non-Interest Income',
    N'FAS 133 gains/losses on free-standing and other derivatives not elsewhere; plus FAS 159 FV changes not reported elsewhere.',
    N'Source: GL | Timing: DURING period | Filter/classification: per definition - ''Gain on Other Derivatives/Financial Instruments''',
    N'Dollar (may be negative)', 0, N'0', 251,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C750', N'Gain on FV of Loans HFI',
    N'Sch C - Other Non-Interest Income',
    N'Gains/losses from FV changes on HFI loans at FV (FAS 159).',
    N'Source: GL | Timing: DURING period | Filter/classification: per definition - ''Gain on FV of Loans HFI''',
    N'Dollar (may be negative)', 0, N'0', 252,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C760', N'Income from JV/Partnerships/Other Entities',
    N'Sch C - Other Non-Interest Income',
    N'Equity-method income from unconsolidated entities; excluded from all other income lines.',
    N'Source: GL | Timing: DURING period | Filter/classification: per definition - ''Income from JV/Partnerships/Other Entities''',
    N'Dollar (may be negative)', 0, N'0', 253,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C770', N'Other Non-Interest Income',
    N'Sch C - Other Non-Interest Income',
    N'Any other non-interest income not reported above.',
    N'Source: GL | Timing: DURING period | Filter/classification: per definition - ''Other Non-Interest Income''',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'9000', 254,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C780', N'Total Other Non-Interest Income',
    N'Sch C - Other Non-Interest Income',
    N'Sum of C720 to C770 per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period.',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'18000', 255,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C800', N'Total Gross Income',
    N'Sch C',
    N'Sum of C090, C260, C450, C650, C780 per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period.',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'3048000', 256,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C100', N'Warehousing Interest Expense',
    N'Sch C - Interest Expense',
    N'Interest expense on warehouse/other debt for 1-4 unit and MF/commercial originations (warehouse LOC, collateralized repo LOC, ABCP). Positive number.',
    N'Source: GL interest expense accounts by facility | Timing: incurred DURING period | Filter/classification: per definition - ''Warehousing Interest Expense'' | Notes: enter positive; warehouse expense pairs with C010 income',
    N'Positive dollar', 0, N'356000', 257,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C110', N'Income Property Interest Expense',
    N'Sch C - Interest Expense',
    N'Interest expense on income-property loan debt. Positive number.',
    N'Source: GL interest expense accounts by facility | Timing: incurred DURING period | Filter/classification: per definition - ''Income Property Interest Expense'' | Notes: enter positive; warehouse expense pairs with C010 income',
    N'Positive dollar', 0, N'0', 258,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C120', N'Interest Expense on MBS Pools/Prepayment Interest Shortfall',
    N'Sch C - Interest Expense',
    N'Uncollected interest passed to security holders on payoffs not on the 1st; incl. SCRA-absorbed GNMA interest losses. Positive number.',
    N'Source: GL interest expense accounts by facility | Timing: incurred DURING period | Filter/classification: per definition - ''Interest Expense on MBS Pools/Prepayment Interest Shortfall'' | Notes: enter positive; warehouse expense pairs with C010 income',
    N'Positive dollar', 0, N'14000', 259,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C130', N'Interest Expense on Residential MSR Asset',
    N'Sch C - Interest Expense',
    N'Interest expense on debt financing residential MSR assets. Positive number.',
    N'Source: GL interest expense accounts by facility | Timing: incurred DURING period | Filter/classification: per definition - ''Interest Expense on Residential MSR Asset'' | Notes: enter positive; warehouse expense pairs with C010 income',
    N'Positive dollar', 0, N'62000', 260,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C140', N'Interest Expense Debt Issuance',
    N'Sch C - Interest Expense',
    N'Interest expense on debt issuances (bonds, subordinated debt). Positive number.',
    N'Source: GL interest expense accounts by facility | Timing: incurred DURING period | Filter/classification: per definition - ''Interest Expense Debt Issuance'' | Notes: enter positive; warehouse expense pairs with C010 income',
    N'Positive dollar', 0, N'20000', 261,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C150', N'Other Interest Expense',
    N'Sch C - Interest Expense',
    N'Interest expense not elsewhere: credit card debt, lease imputed interest, MF/commercial MSR interest. Positive number.',
    N'Source: GL interest expense accounts by facility | Timing: incurred DURING period | Filter/classification: per definition - ''Other Interest Expense'' | Notes: enter positive; warehouse expense pairs with C010 income',
    N'Positive dollar', 0, N'8000', 262,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C160', N'Total Interest Expense',
    N'Sch C - Interest Expense',
    N'Sum of C100 to C150 per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: incurred DURING period. | Notes: enter positive; warehouse expense pairs with C010 income',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'460000', 263,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'CF010', N'Net Cash (Used)/Provided by Operating Activities',
    N'Sch CF - Selected Cash Flow Data',
    N'Operating section total from GAAP statement of cash flows.',
    N'Source: GAAP statement of cash flows | Timing: DURING period | Filter/classification: per definition - ''Net Cash (Used)/Provided by Operating Activities'' | Notes: pull section totals directly; CF040 = sum',
    N'Dollar (may be negative)', 0, N'-2140000', 264,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'CF020', N'Cash Flows from Investing Activities',
    N'Sch CF - Selected Cash Flow Data',
    N'Investing section total from GAAP statement of cash flows.',
    N'Source: GAAP statement of cash flows | Timing: DURING period | Filter/classification: per definition - ''Cash Flows from Investing Activities'' | Notes: pull section totals directly; CF040 = sum',
    N'Dollar (may be negative)', 0, N'-380000', 265,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'CF030', N'Cash Flows from Financing Activities',
    N'Sch CF - Selected Cash Flow Data',
    N'Financing section total from GAAP statement of cash flows.',
    N'Source: GAAP statement of cash flows | Timing: DURING period | Filter/classification: per definition - ''Cash Flows from Financing Activities'' | Notes: pull section totals directly; CF040 = sum',
    N'Dollar (may be negative)', 0, N'2760000', 266,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'CF040', N'Total Increase/(Decrease) in Cash',
    N'Sch CF - Selected Cash Flow Data',
    N'CF010 + CF020 + CF030.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period. | Notes: pull section totals directly; CF040 = sum',
    N'Dollar (may be negative)', 1, N'240000', 267,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D010', N'Loan Production Officers (Sales Employees)',
    N'Sch D - Origination Personnel',
    N'Compensation of retail LOs and broker/wholesale sales account executives.',
    N'Source: payroll/HR system with cost-center or function coding | Timing: incurred DURING period | Filter/classification: per definition - ''Loan Production Officers (Sales Employees)'' | Notes: allocate multi-function staff; FAS 91 deferral contra in D120',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'486000', 268,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D020', N'Loan Origination (Fulfillment/Non-Sales)',
    N'Sch D - Origination Personnel',
    N'Compensation of processors, underwriters, closers, and other retail origination staff. Excludes D010 and D030.',
    N'Source: payroll/HR system with cost-center or function coding | Timing: incurred DURING period | Filter/classification: per definition - ''Loan Origination (Fulfillment/Non-Sales)'' | Notes: allocate multi-function staff; FAS 91 deferral contra in D120',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'294000', 269,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D030', N'Warehousing/Secondary Marketing',
    N'Sch D - Origination Personnel',
    N'Compensation of staff principally in warehousing, secondary marketing, loan sales.',
    N'Source: payroll/HR system with cost-center or function coding | Timing: incurred DURING period | Filter/classification: per definition - ''Warehousing/Secondary Marketing'' | Notes: allocate multi-function staff; FAS 91 deferral contra in D120',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'72000', 270,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D040', N'Post-Close and Other Production Support',
    N'Sch D - Origination Personnel',
    N'Compensation of post-close, shipping/delivery, QC, marketing, tech support, interim servicing staff.',
    N'Source: payroll/HR system with cost-center or function coding | Timing: incurred DURING period | Filter/classification: per definition - ''Post-Close and Other Production Support'' | Notes: allocate multi-function staff; FAS 91 deferral contra in D120',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'68000', 271,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D050', N'Origination-Related Management and Directors',
    N'Sch D - Origination Personnel',
    N'Compensation of origination-function managers, directors, executives, admin staff; allocate multi-function managers appropriately.',
    N'Source: payroll/HR system with cost-center or function coding | Timing: incurred DURING period | Filter/classification: per definition - ''Origination-Related Management and Directors'' | Notes: allocate multi-function staff; FAS 91 deferral contra in D120',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'118000', 272,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D060', N'Other Origination-Related',
    N'Sch D - Origination Personnel',
    N'Compensation of other origination-function personnel (commercial, MF, portfolio investment).',
    N'Source: payroll/HR system with cost-center or function coding | Timing: incurred DURING period | Filter/classification: per definition - ''Other Origination-Related'' | Notes: allocate multi-function staff; FAS 91 deferral contra in D120',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'24000', 273,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D070', N'Total Origination Compensation',
    N'Sch D - Origination Personnel',
    N'Sum of D010 to D060 per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: incurred DURING period. | Notes: allocate multi-function staff; FAS 91 deferral contra in D120',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'1062000', 274,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D080', N'Servicing-Related Management and Directors',
    N'Sch D - Servicing Personnel',
    N'Compensation of servicing-function managers, directors, executives, admin staff.',
    N'Source: payroll by cost center | Timing: DURING period | Filter/classification: per definition - ''Servicing-Related Management and Directors'' | Notes: corporate support goes to D400, not here',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'52000', 275,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D090', N'Other Servicing-Related Personnel',
    N'Sch D - Servicing Personnel',
    N'Compensation of servicing/REO staff for residential, commercial, MF loans. Excludes acquisitions/originations/loan set-up/personal/commercial areas; corporate support in D400.',
    N'Source: payroll by cost center | Timing: DURING period | Filter/classification: per definition - ''Other Servicing-Related Personnel'' | Notes: corporate support goes to D400, not here',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'134000', 276,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D100', N'Total Servicing Compensation',
    N'Sch D - Servicing Personnel',
    N'Sum of D080 and D090 per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period. | Notes: corporate support goes to D400, not here',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'186000', 277,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D110', N'Other Personnel',
    N'Sch D - Other Personnel',
    N'Compensation of portfolio investment management staff incl. related management/support. Excludes corporate allocations (D400).',
    N'Source: payroll by cost center | Timing: DURING period | Filter/classification: per definition - ''Other Personnel'' | Notes: D120 must be <= 0',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'31000', 278,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D120', N'Contra: Direct Personnel Expenses Reclassified/Deferred',
    N'Sch D - Other Personnel',
    N'Direct personnel expenses reclassified to gain on sale or deferred per FAS 91. Must be <= 0.',
    N'Source: payroll by cost center | Timing: DURING period | Filter/classification: per definition - ''Contra: Direct Personnel Expenses Reclassified/Deferred'' | Notes: D120 must be <= 0',
    N'Dollar <= 0', 0, N'-59000', 279,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D129', N'Total Other Personnel Compensation',
    N'Sch D - Other Personnel',
    N'Sum of D110 and D120.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period. | Notes: D120 must be <= 0',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'-28000', 280,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D130', N'Total Non-Corporate Personnel Compensation',
    N'Sch D',
    N'Sum of D070 and D110.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period. | Notes: D600 ties to B350B',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'1093000', 281,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D150', N'Employee Benefits (including Education and Training)',
    N'Sch D - Other Personnel Expenses',
    N'Benefits: profit sharing, pension, group health/life, payroll taxes, education/training.',
    N'Source: payroll/benefits GL | Timing: DURING period | Filter/classification: per definition - ''Employee Benefits (including Education and Training)'' | Notes: incl. payroll taxes and training',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'247000', 282,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D160', N'Other Personnel Expenses',
    N'Sch D - Other Personnel Expenses',
    N'All other personnel expenses.',
    N'Source: payroll/benefits GL | Timing: DURING period | Filter/classification: per definition - ''Other Personnel Expenses'' | Notes: incl. payroll taxes and training',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'38000', 283,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D170', N'Total Other Personnel Expenses',
    N'Sch D - Other Personnel Expenses',
    N'Sum of D150 and D160 per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period. | Notes: incl. payroll taxes and training',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'285000', 284,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D180', N'Total Personnel Expenses',
    N'Sch D',
    N'Sum of D130 and D170 per column.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period. | Notes: D600 ties to B350B',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'1378000', 285,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D200', N'Occupancy and Equipment',
    N'Sch D - Other Non-Interest Expenses',
    N'Rent, utilities, hazard insurance, fax, telephone, furniture/fixtures incl. depreciation.',
    N'Source: GL expense accounts | Timing: DURING period | Filter/classification: per definition - ''Occupancy and Equipment'' | Notes: D260 ties O120; D270 ties O220; C700 ties O020 (negative); D290 <= 0',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'112000', 286,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D210', N'Technology-Related Expenses',
    N'Sch D - Other Non-Interest Expenses',
    N'Non-personnel tech hardware/software: LOS, servicing systems, tech service bureau fees. Corporate tech allocations go to D410.',
    N'Source: GL expense accounts | Timing: DURING period | Filter/classification: per definition - ''Technology-Related Expenses'' | Notes: D260 ties O120; D270 ties O220; C700 ties O020 (negative); D290 <= 0',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'96000', 287,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D220', N'Outsourcing Fees',
    N'Sch D - Other Non-Interest Expenses',
    N'Third-party services (fulfillment processing, call center, tax/escrow). Excludes D210 tech, per-transaction fees (AUS, credit bureau), subservicing fees (D240).',
    N'Source: GL expense accounts | Timing: DURING period | Filter/classification: per definition - ''Outsourcing Fees'' | Notes: D260 ties O120; D270 ties O220; C700 ties O020 (negative); D290 <= 0',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'41000', 288,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D230', N'Professional Fees',
    N'Sch D - Other Non-Interest Expenses',
    N'Legal, accounting, consulting, advisory; audit and tax fees.',
    N'Source: GL expense accounts | Timing: DURING period | Filter/classification: per definition - ''Professional Fees'' | Notes: D260 ties O120; D270 ties O220; C700 ties O020 (negative); D290 <= 0',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'64000', 289,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D240', N'Subservicing Fees (Including Intercompany)',
    N'Sch D - Other Non-Interest Expenses',
    N'Fees paid to subservicers incl. affiliates for loans whose servicing rights you own. Intracompany goes to C530.',
    N'Source: GL expense accounts | Timing: DURING period | Filter/classification: per definition - ''Subservicing Fees (Including Intercompany)'' | Notes: D260 ties O120; D270 ties O220; C700 ties O020 (negative); D290 <= 0',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'28000', 290,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D250', N'Unreimbursed Servicing Expenses for Foreclosure/REO',
    N'Sch D - Other Non-Interest Expenses',
    N'Non-recoverable foreclosure/REO expenses (maintenance, taxes, insurance) not in a loss provision.',
    N'Source: GL expense accounts | Timing: DURING period | Filter/classification: per definition - ''Unreimbursed Servicing Expenses for Foreclosure/REO'' | Notes: D260 ties O120; D270 ties O220; C700 ties O020 (negative); D290 <= 0',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'19000', 291,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D260', N'Change in REO Valuation Allowance',
    N'Sch D - Other Non-Interest Expenses',
    N'REO valuation allowance changes during period. Must equal O120.',
    N'Source: REO allowance change | Completeness: must equal O120',
    N'Dollar (may be negative)', 0, N'12000', 292,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D270', N'Provision For Other Losses',
    N'Sch D - Other Non-Interest Expenses',
    N'Current period provision for other losses (P&L impact of increasing reserve). Must equal O220 on E-FC.',
    N'Source: other-loss provision | Completeness: must equal O220 (E-FC)',
    N'Dollar (may be negative)', 0, N'8000', 293,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D280', N'All Other Non-Interest Expenses',
    N'Sch D - Other Non-Interest Expenses',
    N'Non-interest expenses not elsewhere and not in D540. Guarantee fees net on C500; brokered loan fees paid on C340.',
    N'Source: GL expense accounts | Timing: DURING period | Filter/classification: per definition - ''All Other Non-Interest Expenses'' | Notes: D260 ties O120; D270 ties O220; C700 ties O020 (negative); D290 <= 0',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'87000', 294,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D290', N'Contra: Direct Operating Expenses Reclassified',
    N'Sch D - Other Non-Interest Expenses',
    N'Direct operating expenses reclassified to gain on sale or deferred per FAS 91. Must be <= 0.',
    N'Source: GL expense accounts | Timing: DURING period | Filter/classification: per definition - ''Contra: Direct Operating Expenses Reclassified'' | Notes: D260 ties O120; D270 ties O220; C700 ties O020 (negative); D290 <= 0',
    N'Dollar <= 0', 0, N'-33000', 295,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C700', N'Provision for Credit Losses on Loans Held For Investment',
    N'Sch D - Other Non-Interest Expenses',
    N'Current period HFI credit loss provision. Must equal O020. Reflect as negative.',
    N'Source: HFI credit loss provision | Completeness: must equal O020 | Reflect as NEGATIVE',
    N'Dollar (negative)', 0, N'-26000', 296,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'C710', N'Permanent Impairment (non-MSR) and Other Credit Related Losses',
    N'Sch D - Other Non-Interest Expenses',
    N'OTTI permanent write-downs and other credit losses not elsewhere; excludes MSR impairments. Enter as negative.',
    N'Source: GL expense accounts | Timing: DURING period | Filter/classification: per definition - ''Permanent Impairment (non-MSR) and Other Credit Related Losses'' | Notes: D260 ties O120; D270 ties O220; C700 ties O020 (negative); D290 <= 0',
    N'Dollar (negative)', 0, N'-4000', 297,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D300', N'Total - Other Non-Interest Expenses',
    N'Sch D - Other Non-Interest Expenses',
    N'Calculated total of other non-interest expense lines.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period. | Notes: D260 ties O120; D270 ties O220; C700 ties O020 (negative); D290 <= 0',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'404000', 298,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D400', N'Corporate Management/Support/Other Personnel',
    N'Sch D - Corporate Administration/Overhead',
    N'Corporate/parent charges for management and support staff compensation, benefits, other personnel expenses.',
    N'Source: corporate allocation schedules from parent | Timing: DURING period | Filter/classification: per definition - ''Corporate Management/Support/Other Personnel'' | Notes: keep separate from direct function expense',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'104000', 299,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D410', N'Corporate Technology Charges',
    N'Sch D - Corporate Administration/Overhead',
    N'Corporate/parent non-personnel tech charges incl. corporate support and help desk.',
    N'Source: corporate allocation schedules from parent | Timing: DURING period | Filter/classification: per definition - ''Corporate Technology Charges'' | Notes: keep separate from direct function expense',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'36000', 300,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D420', N'Goodwill Impairment',
    N'Sch D - Corporate Administration/Overhead',
    N'Goodwill impairment per FAS 142.',
    N'Source: corporate allocation schedules from parent | Timing: DURING period | Filter/classification: per definition - ''Goodwill Impairment'' | Notes: keep separate from direct function expense',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'0', 301,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D430', N'Other Corporate Expenses (not Included Above)',
    N'Sch D - Corporate Administration/Overhead',
    N'Other corporate/parent charges incl. litigation settlements and unusual items.',
    N'Source: corporate allocation schedules from parent | Timing: DURING period | Filter/classification: per definition - ''Other Corporate Expenses (not Included Above)'' | Notes: keep separate from direct function expense',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'21000', 302,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D440', N'Total Corporate Administration/Allocation',
    N'Sch D - Corporate Administration/Overhead',
    N'Sum of D400 to D430.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period. | Notes: keep separate from direct function expense',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'161000', 303,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D310', N'Total Gross Expenses',
    N'Sch D',
    N'Sum of C160, D180, D300, D440.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period. | Notes: D600 ties to B350B',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'2403000', 304,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D510', N'Pre-Tax Net Operating Income',
    N'Sch D',
    N'C800 - D310.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period. | Notes: D600 ties to B350B',
    N'Dollar (may be negative)', 1, N'645000', 305,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D520', N'Income Taxes',
    N'Sch D - Taxes and Other',
    N'Income tax expense (benefit).',
    N'Source: tax provision workpapers / GL | Timing: DURING period | Filter/classification: per definition - ''Income Taxes''',
    N'Dollar (may be negative)', 0, N'158000', 306,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D530', N'Net Income before Extraordinary Items and Noncontrolling Interest',
    N'Sch D - Taxes and Other',
    N'D510 minus D520.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period.',
    N'Dollar (may be negative)', 1, N'487000', 307,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D540', N'Extraordinary Items',
    N'Sch D - Taxes and Other',
    N'After-tax gain/loss on nonrecurring items: extraordinary items, discontinued ops, cumulative accounting changes.',
    N'Source: tax provision workpapers / GL | Timing: DURING period | Filter/classification: per definition - ''Extraordinary Items''',
    N'Dollar (may be negative)', 0, N'0', 308,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D550', N'Net Income before Noncontrolling Interest',
    N'Sch D - Taxes and Other',
    N'D530 + D540.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: DURING period.',
    N'Dollar (may be negative)', 1, N'487000', 309,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D560', N'Noncontrolling Interest',
    N'Sch D - Taxes and Other',
    N'After-tax income/loss attributed to minority (noncontrolling) interests per FAS 160.',
    N'Source: tax provision workpapers / GL | Timing: DURING period | Filter/classification: per definition - ''Noncontrolling Interest''',
    N'Dollar (may be negative)', 0, N'0', 310,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'D600', N'Net Income',
    N'Sch D',
    N'D550 + D560.',
    N'Calculated: D550 + D560. Completeness: must equal B350B',
    N'Dollar (may be negative)', 1, N'487000', 311,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O010', N'Beginning Balance',
    N'Sch O - Credit Loss Reserves on HFI Rollforward',
    N'Credit loss reserve at period start.',
    N'Source: ALLL/reserve GL rollforward | Timing: activity DURING period | Filter/classification: per definition - ''Beginning Balance'' | Notes: O060 ties A060AF; O020 ties C700',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'296000', 312,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O020', N'Provision for Credit Losses on Loans Held for Investment',
    N'Sch O - Credit Loss Reserves on HFI Rollforward',
    N'Current period HFI credit loss provision (P&L impact of increasing reserve).',
    N'Source: ALLL/reserve GL rollforward | Timing: activity DURING period | Filter/classification: per definition - ''Provision for Credit Losses on Loans Held for Investment'' | Notes: O060 ties A060AF; O020 ties C700',
    N'Dollar (may be negative)', 0, N'26000', 313,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O030', N'Charge-offs, Net of Recoveries',
    N'Sch O - Credit Loss Reserves on HFI Rollforward',
    N'Charge-offs against reserve, net of recoveries.',
    N'Source: ALLL/reserve GL rollforward | Timing: activity DURING period | Filter/classification: per definition - ''Charge-offs, Net of Recoveries'' | Notes: O060 ties A060AF; O020 ties C700',
    N'Dollar (may be negative)', 0, N'-12000', 314,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O040', N'Adjustments upon Adoption of FAS 159',
    N'Sch O - Credit Loss Reserves on HFI Rollforward',
    N'Reserve impact of FAS 159 election to record HFI class at FV.',
    N'Source: ALLL/reserve GL rollforward | Timing: activity DURING period | Filter/classification: per definition - ''Adjustments upon Adoption of FAS 159'' | Notes: O060 ties A060AF; O020 ties C700',
    N'Dollar (may be negative)', 0, N'0', 315,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O050', N'Other Changes',
    N'Sch O - Credit Loss Reserves on HFI Rollforward',
    N'Other changes not reported separately.',
    N'Source: ALLL/reserve GL rollforward | Timing: activity DURING period | Filter/classification: per definition - ''Other Changes'' | Notes: O060 ties A060AF; O020 ties C700',
    N'Dollar (may be negative)', 0, N'0', 316,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O060', N'Ending Balance',
    N'Sch O - Credit Loss Reserves on HFI Rollforward',
    N'Credit loss reserve at period end. Ties to A060AF.',
    N'Rollforward ending balance | Completeness: must equal A060AF (as contra)',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'310000', 317,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O110', N'Beginning REO Valuation Allowance',
    N'Sch O - REO Valuation Allowance Rollforward',
    N'REO valuation allowance at period start.',
    N'Source: REO allowance GL rollforward | Timing: DURING period | Filter/classification: per definition - ''Beginning REO Valuation Allowance'' | Notes: O130 ties A090B; O120 ties D260',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'28000', 318,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O120', N'Changes in REO Valuation Allowance',
    N'Sch O - REO Valuation Allowance Rollforward',
    N'REO valuation allowance changes during period. Ties to D260.',
    N'Source: REO allowance GL rollforward | Timing: DURING period | Filter/classification: per definition - ''Changes in REO Valuation Allowance'' | Notes: O130 ties A090B; O120 ties D260',
    N'Dollar (may be negative)', 0, N'12000', 319,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O130', N'Ending REO Valuation Allowance',
    N'Sch O - REO Valuation Allowance Rollforward',
    N'REO valuation allowance at period end. Ties to A090B (as contra).',
    N'Rollforward ending balance | Completeness: must equal A090B (as contra)',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'40000', 320,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O210', N'Beginning Reserve for Other Losses',
    N'Sch O - Reserve for Other Losses Rollforward',
    N'Reserve for other losses at period start.',
    N'Source: other-loss reserve GL rollforward | Timing: DURING period | Filter/classification: per definition - ''Beginning Reserve for Other Losses'' | Notes: O250 ties A170; O220 ties D270',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'39000', 321,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O220', N'Provision For Other Losses',
    N'Sch O - Reserve for Other Losses Rollforward',
    N'Current period provision for other losses. Ties to D270.',
    N'Source: other-loss reserve GL rollforward | Timing: DURING period | Filter/classification: per definition - ''Provision For Other Losses'' | Notes: O250 ties A170; O220 ties D270',
    N'Dollar (may be negative)', 0, N'8000', 322,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O230', N'Charge-Offs, Net of Recoveries',
    N'Sch O - Reserve for Other Losses Rollforward',
    N'Charge-offs against reserve for other losses, net of recoveries.',
    N'Source: other-loss reserve GL rollforward | Timing: DURING period | Filter/classification: per definition - ''Charge-Offs, Net of Recoveries'' | Notes: O250 ties A170; O220 ties D270',
    N'Dollar (may be negative)', 0, N'-2000', 323,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O240', N'Other Changes',
    N'Sch O - Reserve for Other Losses Rollforward',
    N'Other changes not reported separately.',
    N'Source: other-loss reserve GL rollforward | Timing: DURING period | Filter/classification: per definition - ''Other Changes'' | Notes: O250 ties A170; O220 ties D270',
    N'Dollar (may be negative)', 0, N'0', 324,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O250', N'Ending Reserve for Other Losses',
    N'Sch O - Reserve for Other Losses Rollforward',
    N'Reserve for other losses at period end. Ties to A170 (as contra).',
    N'Rollforward ending balance | Completeness: must equal A170 (as contra, <= 0)',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'45000', 325,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O310', N'Beginning Repurchase Reserve',
    N'Sch O - Repurchase Reserves Rollforward',
    N'Repurchase reserve at period start (reps/warranties, EPD, FPD, premium recapture, other).',
    N'Source: repurchase reserve GL rollforward + demand pipeline | Timing: DURING period | Filter/classification: per definition - ''Beginning Repurchase Reserve'' | Notes: O350 ties B210; O320 ties C390',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'372000', 326,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O320', N'Provision for Repurchases (EPD, FPD, etc.)',
    N'Sch O - Repurchase Reserves Rollforward',
    N'Repurchase reserve provision. Ties to C390.',
    N'Source: repurchase reserve GL rollforward + demand pipeline | Timing: DURING period | Filter/classification: per definition - ''Provision for Repurchases (EPD, FPD, etc.)'' | Notes: O350 ties B210; O320 ties C390',
    N'Dollar (may be negative)', 0, N'35000', 327,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O330', N'Charge-Offs, Net of Recoveries',
    N'Sch O - Repurchase Reserves Rollforward',
    N'Charge-offs against repurchase reserve, net of recoveries.',
    N'Source: repurchase reserve GL rollforward + demand pipeline | Timing: DURING period | Filter/classification: per definition - ''Charge-Offs, Net of Recoveries'' | Notes: O350 ties B210; O320 ties C390',
    N'Dollar (may be negative)', 0, N'-17000', 328,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O340', N'Other Changes',
    N'Sch O - Repurchase Reserves Rollforward',
    N'Other repurchase reserve changes not reported separately.',
    N'Source: repurchase reserve GL rollforward + demand pipeline | Timing: DURING period | Filter/classification: per definition - ''Other Changes'' | Notes: O350 ties B210; O320 ties C390',
    N'Dollar (may be negative)', 0, N'0', 329,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O350', N'Ending Repurchase Reserve',
    N'Sch O - Repurchase Reserves Rollforward',
    N'Repurchase reserve at period end. Ties to B210.',
    N'Rollforward ending balance | Completeness: must equal B210',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'390000', 330,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O360', N'MEMO: UPB of Loans Repurchased or Indemnified During the Quarter',
    N'Sch O - Memo',
    N'UPB of loans repurchased or indemnified during quarter.',
    N'Source: repurchase demand tracking | Timing: settled DURING quarter | Filter/classification: per definition - ''MEMO: UPB of Loans Repurchased or Indemnified During the Quarter'' | Notes: UPB and count of repurchased/indemnified loans',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'487000', 331,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O370', N'MEMO: Number of Loans Repurchased or Indemnified During the Quarter',
    N'Sch O - Memo',
    N'Count of loans repurchased or indemnified during quarter.',
    N'Source: repurchase demand tracking | Timing: settled DURING quarter | Filter/classification: per definition - ''MEMO: Number of Loans Repurchased or Indemnified During the Quarter'' | Notes: UPB and count of repurchased/indemnified loans',
    N'Positive whole number', 0, N'2', 332,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O380', N'FNMA',
    N'Sch O - EOQ Loan Prepayment Custodial Float by Investor',
    N'Mortgage payments incl. full/partial principal prepayments held by servicer at quarter end, FNMA loans.',
    N'Source: custodial bank account balances by investor clearing account | Timing: AS OF quarter end | Filter/classification: per definition - ''FNMA'' | Notes: P&I float incl. full/partial prepayments held pending remittance; split by investor_code',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'1840000', 333,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O381', N'FHLMC',
    N'Sch O - EOQ Loan Prepayment Custodial Float by Investor',
    N'Custodial float held at quarter end, FHLMC loans.',
    N'Source: custodial bank account balances by investor clearing account | Timing: AS OF quarter end | Filter/classification: per definition - ''FHLMC'' | Notes: P&I float incl. full/partial prepayments held pending remittance; split by investor_code',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'1120000', 334,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O382', N'GNMA',
    N'Sch O - EOQ Loan Prepayment Custodial Float by Investor',
    N'Custodial float held at quarter end, GNMA loans.',
    N'Source: custodial bank account balances by investor clearing account | Timing: AS OF quarter end | Filter/classification: per definition - ''GNMA'' | Notes: P&I float incl. full/partial prepayments held pending remittance; split by investor_code',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'860000', 335,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O383', N'Private Label',
    N'Sch O - EOQ Loan Prepayment Custodial Float by Investor',
    N'Custodial float held at quarter end, private label loans.',
    N'Source: custodial bank account balances by investor clearing account | Timing: AS OF quarter end | Filter/classification: per definition - ''Private Label'' | Notes: P&I float incl. full/partial prepayments held pending remittance; split by investor_code',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'340000', 336,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O384', N'Other',
    N'Sch O - EOQ Loan Prepayment Custodial Float by Investor',
    N'Custodial float held at quarter end, other investor/counterparty loans.',
    N'Source: custodial bank account balances by investor clearing account | Timing: AS OF quarter end | Filter/classification: per definition - ''Other'' | Notes: P&I float incl. full/partial prepayments held pending remittance; split by investor_code',
    N'Dollar, nearest dollar (no $, commas, decimals)', 0, N'215000', 337,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'O390', N'Total Loan Prepayment Custodial Float Balance',
    N'Sch O - EOQ Loan Prepayment Custodial Float by Investor',
    N'Total of O380 to O384.',
    N'Calculated by NMLS. Verify inputs roll up correctly. Timing: AS OF quarter end. | Notes: P&I float incl. full/partial prepayments held pending remittance; split by investor_code',
    N'Dollar, nearest dollar (no $, commas, decimals)', 1, N'4375000', 338,
    @LoadBatchId);
INSERT INTO gov.RegulatoryReportItem
    (RegulatoryReportSectionId, ItemCode, ItemName,
     SubsectionName, NmlsInstruction,
     SourceMappingGuidance, DataFormatNote,
     CalculatedFlag, ExampleValue, ItemSortOrder,
     LoadBatchId)
VALUES (@SecFc, N'FCNOTE', N'FC Explanatory Notes',
    N'Explanatory Notes',
    N'Free-text explanations for the Financial Condition component. Permanent part of the MCR filing.',
    N'Source: filing analyst | Timing: per filing | Filter/classification: per definition - ''FC Explanatory Notes'' | Notes: permanent record - review before submit',
    N'Free text', 0, N'A130B decrease reflects recovery of prior MSR impairment on 2021 vintage stratum.', 339,
    @LoadBatchId);

/* ---- Glossary terms from the FV7 dictionary ---- */
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Absolute Value')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Absolute Value',
        N'Magnitude of a quantity without regard to sign; distance from zero.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Amount')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Amount',
        N'Total loan amount of applications received or closed loans brokered/retail/wholesale.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Application')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Application',
        N'Oral or written request for credit encumbering a 1-4 unit residential property. Date = initial signed 1003 or oral request date. Excludes commercial/business/investment purpose.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Broker Fee')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Broker Fee',
        N'Any fee collected in conjunction with brokering a loan, excluding pass-through fees.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Closed')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Closed',
        N'Loans funded with legally binding agreements establishing a residential mortgage loan.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Closed Retail')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Closed Retail',
        N'Closed loan originated/funded by the institution that took the application.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Closed Wholesale')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Closed Wholesale',
        N'Closed loan where application taken by one party but funded by another.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Count')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Count',
        N'Total number of applications or closed loans.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Directly Received from Borrower')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Directly Received from Borrower',
        N'Applications received directly from the borrower.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Dwelling')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Dwelling',
        N'Residential structure with 1-4 units, attached to real property or not. Includes condo unit, co-op unit, mobile home, trailer, houseboat used as residence.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'FC (Financial Condition)')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'FC (Financial Condition)',
        N'MCR component containing company-level financial information.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'First Lien')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'First Lien',
        N'Mortgage loan with priority over all other liens/claims on the property in default.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Forward Mortgage')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Forward Mortgage',
        N'Loan secured by lien on residential real estate requiring regular payments.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'FV (Fair Value Option)')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'FV (Fair Value Option)',
        N'Fair Value Option per FAS 159.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'HFI')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'HFI',
        N'Held for Investment.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'HFS')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'HFS',
        N'Held for Sale.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Lender Fee')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Lender Fee',
        N'Any fee collected in conjunction with closing/funding a retail or wholesale loan, excluding pass-through fees.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Loan / Residential Mortgage Loan')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Loan / Residential Mortgage Loan',
        N'Loan primarily for personal/family/household use secured by mortgage, deed of trust, or equivalent on a dwelling (TILA 103(v)) or residential real estate.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'LOCOM')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'LOCOM',
        N'Lower of Cost or Market.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Loan-to-Value Ratio (LTV)')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Loan-to-Value Ratio (LTV)',
        N'Loan amount or UPB divided by most recent appraised value. Report current LTV using most recent appraisal.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Originated')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Originated',
        N'A closed/funded loan.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Pass-through Fee')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Pass-through Fee',
        N'Fees not retained by your company (appraisal, credit report, flood cert, etc.).',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Pool Number')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Pool Number',
        N'Number assigned to a group of loans serviced and/or sold in secondary market. Use in-house number if none assigned; retain work papers.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Pre-Approval')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Pre-Approval',
        N'Application where a binding credit decision is expected and communicated before a specific property is identified.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Qualified Mortgage (QM)')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Qualified Mortgage (QM)',
        N'Loan meeting Regulation Z (12 CFR 1026) QM requirements.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Received from 3rd Party')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Received from 3rd Party',
        N'Application received from a broker or lender.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Repurchase')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Repurchase',
        N'Loans you were required to buy back from an investor or securitizer during the period.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Residential First Mortgage (1-4 Unit)')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Residential First Mortgage (1-4 Unit)',
        N'First position lien on a 1-4 unit residential dwelling, real estate or non-real-estate secured (chattel: trailers, manufactured homes, boats).',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'RMLA')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'RMLA',
        N'MCR component with application, closed loan, MLO, LOC, repurchase, origination, servicing and note info reported by state.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Reverse Mortgage')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Reverse Mortgage',
        N'Loan secured by lien on residential real estate where homeowner is not required to pay until a specific event occurs.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'REO')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'REO',
        N'Real Estate Owned.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'SRP')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'SRP',
        N'Service Release Premium.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'Subordinate Lien')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'Subordinate Lien',
        N'Mortgage junior to first liens: home equity, second mortgage, DPA/closing assistance programs.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'UPB')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'UPB',
        N'Unpaid Principal Balance.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);
IF NOT EXISTS (SELECT 1 FROM gov.BusinessTerm
               WHERE TermName = N'YSP')
    INSERT INTO gov.BusinessTerm
        (TermName, TermDefinition, DomainArea,
         ApprovalStatusCode, ApprovedDate,
         SourceOfDefinition, LoadBatchId)
    VALUES (N'YSP',
        N'Yield Spread Premium.',
        N'Regulatory Reporting', 'APPROVED',
        CAST(GETDATE() AS DATE),
        N'NMLS MCR FV7 Field Definitions',
        @LoadBatchId);

COMMIT;

EXEC audit.usp_CompleteLoadBatch
     @LoadBatchId = @LoadBatchId,
     @StatusCode  = 'SUCCESS';

DECLARE @ItemCount INT =
    (SELECT COUNT(*)
     FROM gov.RegulatoryReportItem i
     JOIN gov.RegulatoryReportSection s
       ON s.RegulatoryReportSectionId =
          i.RegulatoryReportSectionId
     WHERE s.RegulatoryReportId = @McrReportId);

PRINT 'Script 006 complete: '
    + CAST(@ItemCount AS VARCHAR(10))
    + ' FV7 items loaded (expected 641), '
    + '35 glossary terms ensured.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    EXEC audit.usp_LogError
         @LoadBatchId = @LoadBatchId,
         @ContextInfo = N'006_gov_seed_mcr_fv7_items.sql';
    EXEC audit.usp_CompleteLoadBatch
         @LoadBatchId = @LoadBatchId,
         @StatusCode  = 'FAILED';
    THROW;
END CATCH
GO
