/* ============================================================
   MortgageGovernance | Phase 9 | Script 019
   Regulatory mapping. Binds governed data elements and
   metrics to NMLS Mortgage Call Report Form Version 7 line
   items, classifies each mapping, and records which lines
   Project 1 can actually support.

   MCR VERSION VERIFICATION
   Current form: MCR FV7. Verified against NMLS and state
   regulator publications on 2026-07-24. FV7 is effective
   beginning the Q1 2026 reporting period; the submission
   window opened 2026-04-01 and Q1 filings were due
   2026-05-15. CSBS published the XML upload schema and
   field definitions on 2025-10-31. The State-Specific
   Supplemental Form carries forward from FV6 into FV7. No
   version change is required: 004 and 006 already record
   FV7 and 006 seeded 641 line items across six sections.

   SCOPE
   Project 1 is a servicing portfolio. This script maps the
   servicing and loss mitigation lines that the implemented
   synthetic data genuinely supports, plus the production
   lines supported by the CRM, LOS, and PPE domains. The
   Financial Condition component is general-ledger and
   treasury data that this platform does not hold; those
   lines are recorded as unmapped with an explicit reason
   and are Project 3 scope. No line is mapped unless a real
   element or metric backs it.

   CLASSIFICATION
   RegulatoryClassificationCode distinguishes DIRECT_FIELD,
   DERIVED_FIELD, SUPPORTING_DATA, CONTROL_DATA, and
   NON_REGULATORY, per the 003 check constraint.
   FilingInputTypeCode records how the value reaches the
   filing: DIRECT, DERIVED, SUPPORTING, RECONCILIATION, or
   CONTROL_EVIDENCE.

   Idempotent: 019 owns gov.RegulatoryMapping and reloads it.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

DECLARE @LoadBatchId INT;
DECLARE @BatchNotes NVARCHAR(400) =
    N'Script 019: MCR FV7 element and metric mappings with '
  + N'regulatory classification.';
EXEC audit.usp_StartLoadBatch
     @BatchName     = N'Phase 9 regulatory mapping seed',
     @BatchTypeCode = 'SEED',
     @Notes         = @BatchNotes,
     @LoadBatchId   = @LoadBatchId OUTPUT;

BEGIN TRY
BEGIN TRAN;

DECLARE @McrReportId INT =
    (SELECT RegulatoryReportId FROM gov.RegulatoryReport
     WHERE ReportCode = 'MCR_FV7');
IF @McrReportId IS NULL
    THROW 50019,
      'MCR_FV7 report row missing. Run 004 and 006 first.', 1;

/* ------------------------------------------------------------
   1. Item families. Each FV7 line is assigned to a family
      that shares a common data basis. Mapping at the family
      level keeps the rule auditable: one documented basis per
      family rather than 300 unexplained rows.
   ------------------------------------------------------------ */
DECLARE @ItemFamily TABLE
(
    ItemCode VARCHAR(30) NOT NULL PRIMARY KEY,
    Family   VARCHAR(30) NOT NULL
);

INSERT INTO @ItemFamily (ItemCode, Family)
SELECT v.ItemCode, v.Family FROM (VALUES
 ('LS010','SVC_TYPE'),('LS020','SVC_TYPE'),
 ('LS030','SVC_TYPE'),('LS040','SVC_TYPE'),
 ('LS090','SVC_TYPE'),
 ('LS100','SVC_XFER'),('LS110','SVC_XFER'),
 ('LS190','SVC_XFER'),
 ('LS200','SVC_DQ_TOTAL'),('LS210','SVC_DQ_TOTAL'),
 ('LS220','SVC_DQ_TOTAL'),('LS230','SVC_DQ_TOTAL'),
 ('LS290','SVC_DQ_TOTAL'),
 ('LS300','SVC_INVESTOR'),('LS310','SVC_INVESTOR'),
 ('LS320','SVC_INVESTOR'),('LS330','SVC_INVESTOR'),
 ('LS340','SVC_INVESTOR'),('LS390','SVC_INVESTOR'),
 ('LS400','SVC_REMIT'),('LS410','SVC_REMIT'),
 ('LS420','SVC_REMIT'),('LS500','SVC_REMIT'),
 ('LS510','SVC_REMIT'),('LS520','SVC_REMIT'),
 ('LS600','SVC_REMIT'),('LS610','SVC_REMIT'),
 ('LS620','SVC_REMIT'),('LS700','SVC_REMIT'),
 ('LS710','SVC_REMIT'),('LS720','SVC_REMIT'),
 ('LS800','SVC_REMIT'),('LS810','SVC_REMIT'),
 ('LS820','SVC_REMIT'),
 ('LS900','SVC_DQ_BY_TYPE'),('LS910','SVC_DQ_BY_TYPE'),
 ('LS920','SVC_DQ_BY_TYPE'),('LS930','SVC_DQ_BY_TYPE'),
 ('LS1000','SVC_DQ_BY_TYPE'),('LS1010','SVC_DQ_BY_TYPE'),
 ('LS1020','SVC_DQ_BY_TYPE'),('LS1030','SVC_DQ_BY_TYPE'),
 ('LS1100','SVC_DQ_BY_TYPE'),('LS1110','SVC_DQ_BY_TYPE'),
 ('LS1120','SVC_DQ_BY_TYPE'),('LS1130','SVC_DQ_BY_TYPE'),
 ('LS1200','SVC_DQ_BY_TYPE'),('LS1210','SVC_DQ_BY_TYPE'),
 ('LS1220','SVC_DQ_BY_TYPE'),('LS1230','SVC_DQ_BY_TYPE'),
 ('LS1400','SVC_FC'),('LS1410','SVC_FC'),
 ('LS1420','SVC_FC'),('LS1430','SVC_FC'),
 ('LS1440','SVC_FC'),('LS1490','SVC_FC'),
 ('LS1500','SVC_FORB'),('LS1510','SVC_FORB'),
 ('LS1520','SVC_FORB'),('LS1530','SVC_FORB'),
 ('LS1540','SVC_FORB'),('LS1590','SVC_FORB'),
 ('S100','LOSS_MIT'),('S110','LOSS_MIT'),
 ('S115','LOSS_MIT'),('S120','LOSS_MIT'),
 ('S130','LOSS_MIT'),('S140','LOSS_MIT'),
 ('S150','LOSS_MIT'),('S160','LOSS_MIT'),
 ('S170','LOSS_MIT'),('S200','LOSS_MIT'),
 ('S210','LOSS_MIT'),('S220','LOSS_MIT'),
 ('S230','LOSS_MIT')
) v(ItemCode, Family);

/* ------------------------------------------------------------
   2. Family to element basis. Classification reflects how the
      element reaches the line, not merely that it is related.
      A category selector that determines which line a loan
      lands on is a DIRECT_FIELD. A value computed by a
      governed rule is a DERIVED_FIELD. Population gates and
      join keys are SUPPORTING_DATA. Fields that exist only to
      evidence a control are CONTROL_DATA.
   ------------------------------------------------------------ */
DECLARE @FamilyElement TABLE
(
    Family      VARCHAR(30) NOT NULL,
    ElementCode VARCHAR(60) NOT NULL,
    Classification VARCHAR(40) NOT NULL,
    InputType   VARCHAR(20) NOT NULL,
    Recon       BIT NOT NULL,
    Note        NVARCHAR(1000) NOT NULL,
    PRIMARY KEY (Family, ElementCode)
);

INSERT INTO @FamilyElement
 (Family, ElementCode, Classification, InputType, Recon, Note)
VALUES
/* ---- Loans serviced by servicing type (LS010-LS090) ---- */
('SVC_TYPE','DE_SERVICING_TYPE','DIRECT_FIELD','DIRECT',1,
 N'Selects which servicing-type line the loan reports on.'),
('SVC_TYPE','DE_CURRENT_UPB','DERIVED_FIELD','DERIVED',1,
 N'UPB measure is SUM of current UPB over the active '
 + N'population at period end. Reconciled src to dw.'),
('SVC_TYPE','DE_LOAN_NUMBER','SUPPORTING_DATA','SUPPORTING',1,
 N'Distinct loan count measure and the reconciliation key.'),
('SVC_TYPE','DE_LOAN_STATUS','SUPPORTING_DATA','SUPPORTING',0,
 N'Active population gate; excludes liquidated loans.'),
('SVC_TYPE','DE_ASOF_DATE','SUPPORTING_DATA','SUPPORTING',0,
 N'Period-end grain selector.'),
/* ---- Servicing transferred in and out (LS100-LS190) ---- */
('SVC_XFER','DE_TRANSFER_EFFECTIVE_DATE','DIRECT_FIELD','DIRECT',1,
 N'Determines whether a transfer falls in the period.'),
('SVC_XFER','DE_TRANSFER_TYPE','SUPPORTING_DATA','SUPPORTING',0,
 N'Bulk versus flow classification of the transfer.'),
('SVC_XFER','DE_BOARDED_DATE','SUPPORTING_DATA','SUPPORTING',1,
 N'Transferred-in population basis.'),
('SVC_XFER','DE_RUNOFF_REASON','SUPPORTING_DATA','SUPPORTING',0,
 N'Distinguishes servicing transferred out from other '
 + N'portfolio exits such as payoff and liquidation.'),
('SVC_XFER','DE_CURRENT_UPB','DERIVED_FIELD','DERIVED',1,
 N'UPB of loans transferred during the period.'),
('SVC_XFER','DE_LOAN_NUMBER','SUPPORTING_DATA','SUPPORTING',1,
 N'Loan count measure and reconciliation key.'),
/* ---- Delinquency buckets, portfolio total (LS200-LS290) ---- */
('SVC_DQ_TOTAL','DE_DELINQUENCY_BUCKET','DERIVED_FIELD','DERIVED',1,
 N'Governed bucket from DRV_DQBUCKET selects the line. FV7 '
 + N'buckets are under 30, 30-59, 60-89, and 90 or more.'),
('SVC_DQ_TOTAL','DE_DAYS_PAST_DUE','DERIVED_FIELD','DERIVED',1,
 N'Bucket input from DRV_DPD.'),
('SVC_DQ_TOTAL','DE_NEXT_PAYMENT_DUE_DATE','DIRECT_FIELD','DIRECT',1,
 N'CDE anchoring all delinquency derivation. A defect here '
 + N'misstates every FV7 delinquency line.'),
('SVC_DQ_TOTAL','DE_CURRENT_UPB','DERIVED_FIELD','DERIVED',1,
 N'UPB measure for the bucket.'),
('SVC_DQ_TOTAL','DE_LOAN_NUMBER','SUPPORTING_DATA','SUPPORTING',1,
 N'Loan count measure and reconciliation key.'),
('SVC_DQ_TOTAL','DE_SOURCE_BUCKET','CONTROL_DATA','CONTROL_EVIDENCE',0,
 N'Source-asserted bucket retained solely to test the '
 + N'governed derivation. Never filed; it is control '
 + N'evidence that the derived bucket was independently '
 + N'verified.'),
/* ---- Investor category (LS300-LS390) ---- */
('SVC_INVESTOR','DE_INVESTOR_CODE','DIRECT_FIELD','DIRECT',1,
 N'Selects the investor line. CDE and the target of '
 + N'defect DEF12.'),
('SVC_INVESTOR','DE_CURRENT_UPB','DERIVED_FIELD','DERIVED',1,
 N'UPB measure by investor.'),
('SVC_INVESTOR','DE_LOAN_NUMBER','SUPPORTING_DATA','SUPPORTING',1,
 N'Loan count measure and reconciliation key.'),
/* ---- Remittance type by servicing category (LS400-LS820) ---- */
('SVC_REMIT','DE_REMITTANCE_TYPE','DIRECT_FIELD','DIRECT',1,
 N'Selects the remittance-type line.'),
('SVC_REMIT','DE_SERVICING_TYPE','DIRECT_FIELD','DIRECT',1,
 N'Selects the servicing-category block within which the '
 + N'remittance split reports.'),
('SVC_REMIT','DE_CURRENT_UPB','DERIVED_FIELD','DERIVED',1,
 N'UPB measure for the remittance split.'),
('SVC_REMIT','DE_LOAN_NUMBER','SUPPORTING_DATA','SUPPORTING',1,
 N'Loan count measure.'),
/* ---- Delinquency by servicing type (LS900-LS1230) ---- */
('SVC_DQ_BY_TYPE','DE_DELINQUENCY_BUCKET','DERIVED_FIELD','DERIVED',1,
 N'Bucket selector within the servicing-type block.'),
('SVC_DQ_BY_TYPE','DE_SERVICING_TYPE','DIRECT_FIELD','DIRECT',1,
 N'Selects which servicing-type delinquency block applies.'),
('SVC_DQ_BY_TYPE','DE_DAYS_PAST_DUE','DERIVED_FIELD','DERIVED',1,
 N'Bucket input.'),
('SVC_DQ_BY_TYPE','DE_NEXT_PAYMENT_DUE_DATE','DIRECT_FIELD','DIRECT',1,
 N'Delinquency anchor CDE.'),
('SVC_DQ_BY_TYPE','DE_CURRENT_UPB','DERIVED_FIELD','DERIVED',1,
 N'UPB measure.'),
('SVC_DQ_BY_TYPE','DE_LOAN_NUMBER','SUPPORTING_DATA','SUPPORTING',1,
 N'Loan count measure. These lines must foot to the '
 + N'LS200-LS290 totals; that tie is a filing control.'),
/* ---- Foreclosure by servicing type (LS1400-LS1490) ---- */
('SVC_FC','DE_FC_CASE_STATUS','DIRECT_FIELD','DIRECT',1,
 N'Open-case gate determining loans in foreclosure at '
 + N'period end.'),
('SVC_FC','DE_SERVICING_TYPE','DIRECT_FIELD','DIRECT',1,
 N'Selects the servicing-type foreclosure line.'),
('SVC_FC','DE_FC_REFERRAL_DATE','SUPPORTING_DATA','SUPPORTING',0,
 N'Foreclosure timeline start; establishes case existence '
 + N'during the period.'),
('SVC_FC','DE_FC_SALE_HELD_DATE','SUPPORTING_DATA','SUPPORTING',0,
 N'Closes the case; excludes completed sales from the '
 + N'period-end open population.'),
('SVC_FC','DE_CURRENT_UPB','DERIVED_FIELD','DERIVED',1,
 N'UPB of loans in foreclosure.'),
('SVC_FC','DE_LOAN_NUMBER','SUPPORTING_DATA','SUPPORTING',1,
 N'Loan count measure.'),
/* ---- Forbearance flow (LS1500-LS1590) ---- */
('SVC_FORB','DE_FORB_START_DATE','DIRECT_FIELD','DIRECT',1,
 N'Determines plans entering forbearance during the '
 + N'period.'),
('SVC_FORB','DE_FORB_END_DATE','DIRECT_FIELD','DIRECT',1,
 N'Determines plans exiting during the period.'),
('SVC_FORB','DE_FORB_STATUS','DIRECT_FIELD','DIRECT',1,
 N'Classifies the exit reason across the resumed-payment, '
 + N'loss mitigation, and foreclosure exit lines.'),
('SVC_FORB','DE_FORBEARANCE_FLAG','DERIVED_FIELD','DERIVED',1,
 N'Point-in-time active flag for beginning and end of '
 + N'period counts.'),
('SVC_FORB','DE_LM_APP_RECEIVED','SUPPORTING_DATA','SUPPORTING',0,
 N'Evidences the exit-to-loss-mitigation path.'),
('SVC_FORB','DE_FC_REFERRAL_DATE','SUPPORTING_DATA','SUPPORTING',0,
 N'Evidences the exit-to-foreclosure path.'),
('SVC_FORB','DE_LOAN_NUMBER','SUPPORTING_DATA','SUPPORTING',1,
 N'Loan count measure. Beginning plus entering minus '
 + N'exiting must equal ending; that roll-forward is a '
 + N'filing control.'),
/* ---- Loss mitigation and modification (S100-S230) ---- */
('LOSS_MIT','DE_LM_APP_RECEIVED','DIRECT_FIELD','DIRECT',1,
 N'Applications received during the period.'),
('LOSS_MIT','DE_LM_COMPLETE_PACKAGE','SUPPORTING_DATA','SUPPORTING',0,
 N'CDE anchoring the Regulation X evaluation clock; '
 + N'establishes in-process status.'),
('LOSS_MIT','DE_LM_DECISION_CODE','DIRECT_FIELD','DIRECT',1,
 N'Classifies denied, terminated, and completed outcomes '
 + N'across the S110 through S140 lines.'),
('LOSS_MIT','DE_LM_DECISION_DATE','DIRECT_FIELD','DIRECT',1,
 N'Places the outcome in the reporting period.'),
('LOSS_MIT','DE_LM_WORKOUT_TYPE','DIRECT_FIELD','DIRECT',1,
 N'Distinguishes modification from other workout types.'),
('LOSS_MIT','DE_MOD_EFFECTIVE_DATE','DIRECT_FIELD','DIRECT',1,
 N'Completed modifications during the period.'),
('LOSS_MIT','DE_MOD_BOOKED_DATE','SUPPORTING_DATA','SUPPORTING',0,
 N'Trial-to-permanent conversion evidence.'),
('LOSS_MIT','DE_LOAN_NUMBER','SUPPORTING_DATA','SUPPORTING',1,
 N'Case count measure. In-process beginning plus received '
 + N'minus resolved must equal in-process ending.'),
('LOSS_MIT','DE_CURRENT_UPB','DERIVED_FIELD','DERIVED',0,
 N'Supports the S170 net change in modified amount.');

/* ------------------------------------------------------------
   3. Load element mappings by expanding family to item.
      019 owns gov.RegulatoryMapping; reload it.
   ------------------------------------------------------------ */
DELETE FROM gov.RegulatoryMapping;

INSERT INTO gov.RegulatoryMapping
    (RegulatoryReportItemId, MappedEntityTypeCode,
     DataElementId, MetricDefinitionId,
     RegulatoryClassificationCode, FilingInputTypeCode,
     ReconciliationRequiredFlag, EvidenceRetentionNote,
     MappingNotes, LoadBatchId)
SELECT i.RegulatoryReportItemId, 'DATA_ELEMENT',
       de.DataElementId, NULL,
       fe.Classification, fe.InputType, fe.Recon,
       N'Retain the period-end snapshot extract, the rule '
       + N'execution log, and the reconciliation result for '
       + N'the filed quarter.',
       N'Family ' + fe.Family + N'. ' + fe.Note,
       @LoadBatchId
FROM @ItemFamily f
JOIN @FamilyElement fe ON fe.Family = f.Family
JOIN gov.RegulatoryReportItem i ON i.ItemCode = f.ItemCode
JOIN gov.RegulatoryReportSection s
  ON s.RegulatoryReportSectionId = i.RegulatoryReportSectionId
 AND s.RegulatoryReportId = @McrReportId
JOIN gov.DataElement de
  ON de.DataElementCode = fe.ElementCode;

/* ------------------------------------------------------------
   4. Metric mappings. A metric maps to a line only where the
      metric IS the filed measure or directly reconciles to
      it. Metrics that merely describe the same domain are not
      mapped; that distinction is the difference between a
      regulatory mapping and a topic tag.
   ------------------------------------------------------------ */
DECLARE @ItemMetric TABLE
(
    ItemCode   VARCHAR(30) NOT NULL,
    MetricCode VARCHAR(40) NOT NULL,
    Classification VARCHAR(40) NOT NULL,
    InputType  VARCHAR(20) NOT NULL,
    Recon      BIT NOT NULL,
    Note       NVARCHAR(1000) NOT NULL,
    PRIMARY KEY (ItemCode, MetricCode)
);

INSERT INTO @ItemMetric
 (ItemCode, MetricCode, Classification, InputType, Recon, Note)
SELECT v.ItemCode, v.MetricCode, v.Class, v.Input, v.Recon,
       v.Note
FROM (VALUES
 ('LS290','M006','DERIVED_FIELD','RECONCILIATION',1,
  N'Servicing Portfolio UPB. The certified UPB measure and '
  + N'the FV7 total loans serviced UPB must agree; a '
  + N'variance is a blocking control failure.'),
 ('LS210','M137','SUPPORTING_DATA','RECONCILIATION',1,
  N'30-Day Delinquency Rate. The rate is not the filed '
  + N'value: FV7 files UPB and count. The rate numerator '
  + N'population must equal the LS210 count, so it '
  + N'reconciles to the line rather than supplying it.'),
 ('LS220','M138','SUPPORTING_DATA','RECONCILIATION',1,
  N'60-Day Delinquency Rate. Reconciles to the LS220 '
  + N'count; not the filed value.'),
 ('LS230','M139','SUPPORTING_DATA','RECONCILIATION',1,
  N'90+ Day Delinquency Rate. Reconciles to the LS230 '
  + N'count; not the filed value. Also the serious '
  + N'delinquency basis reported to executives.'),
 ('LS210','M008','SUPPORTING_DATA','RECONCILIATION',1,
  N'30-89 Day Delinquency Rate spans the 30-59 and 60-89 '
  + N'lines; its numerator must equal LS210 plus LS220.'),
 ('LS220','M008','SUPPORTING_DATA','RECONCILIATION',1,
  N'Second leg of the 30-89 span; see LS210.')
) v(ItemCode, MetricCode, Class, Input, Recon, Note)
WHERE EXISTS (SELECT 1 FROM gov.MetricDefinition m
              WHERE m.MetricCode = v.MetricCode);

INSERT INTO gov.RegulatoryMapping
    (RegulatoryReportItemId, MappedEntityTypeCode,
     DataElementId, MetricDefinitionId,
     RegulatoryClassificationCode, FilingInputTypeCode,
     ReconciliationRequiredFlag, EvidenceRetentionNote,
     MappingNotes, LoadBatchId)
SELECT i.RegulatoryReportItemId, 'METRIC',
       NULL, m.MetricDefinitionId,
       im.Classification, im.InputType, im.Recon,
       N'Retain the certified measure value, the metric '
       + N'definition version, and the reconciliation '
       + N'result for the filed quarter.',
       im.Note, @LoadBatchId
FROM @ItemMetric im
JOIN gov.RegulatoryReportItem i ON i.ItemCode = im.ItemCode
JOIN gov.RegulatoryReportSection s
  ON s.RegulatoryReportSectionId = i.RegulatoryReportSectionId
 AND s.RegulatoryReportId = @McrReportId
JOIN gov.MetricDefinition m ON m.MetricCode = im.MetricCode;

/* ------------------------------------------------------------
   5. Propagate regulatory relevance to the element catalog so
      a steward querying gov.DataElement sees the flag without
      joining the regulatory model.
   ------------------------------------------------------------ */
UPDATE de
SET de.ModifiedDateUtc = SYSUTCDATETIME()
FROM gov.DataElement de
WHERE EXISTS (SELECT 1 FROM gov.RegulatoryMapping rm
              WHERE rm.DataElementId = de.DataElementId);

/* ------------------------------------------------------------
   6. Change log
   ------------------------------------------------------------ */
IF NOT EXISTS
   (SELECT 1 FROM gov.ChangeLog
    WHERE EntityTypeCode = 'GOVERNANCE_PLATFORM'
      AND EntityReference = N'gov.RegulatoryMapping')
BEGIN
    INSERT INTO gov.ChangeLog
        (EntityTypeCode, EntityReference, ChangeTypeCode,
         ChangeDescription, LoadBatchId)
    VALUES
        ('GOVERNANCE_PLATFORM', N'gov.RegulatoryMapping',
         'INSERT',
         N'Phase 9 regulatory mapping: MCR FV7 servicing, '
         + N'forbearance, foreclosure, and loss mitigation '
         + N'lines mapped to governed elements and certified '
         + N'metrics with regulatory classification and '
         + N'filing input type. FV7 verified current on '
         + N'2026-07-24 (effective Q1 2026, first filing due '
         + N'2026-05-15). Financial Condition lines are '
         + N'deliberately unmapped: that data is not held by '
         + N'this platform and is Project 3 scope.',
         @LoadBatchId);
END

COMMIT;

EXEC audit.usp_CompleteLoadBatch
     @LoadBatchId = @LoadBatchId, @StatusCode = 'SUCCESS';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    EXEC audit.usp_LogError
         @LoadBatchId = @LoadBatchId,
         @ContextInfo = N'019_gov_regulatory_mapping.sql';
    EXEC audit.usp_CompleteLoadBatch
         @LoadBatchId = @LoadBatchId, @StatusCode = 'FAILED';
    THROW;
END CATCH
GO

/* ============================================================
   Section 7. Generation views.
   ============================================================ */

/* ---- 7a. The regulatory mapping artifact: line item to
        element or metric, with owner and steward resolved
        from the element RACI seeded in 017. ---- */
CREATE OR ALTER VIEW gov.vw_RegulatoryMapping
AS
SELECT
    rr.ReportCode, rr.ReportVersion, rr.FilingFrequencyCode,
    s.ComponentCode, s.SectionCode, s.ScopeLevelCode,
    i.ItemCode, i.ItemName, i.SubsectionName,
    rm.MappedEntityTypeCode,
    COALESCE(de.DataElementCode, m.MetricCode) AS MappedCode,
    COALESCE(de.DataElementName, m.MetricName) AS MappedName,
    de.CdeFlag,
    rm.RegulatoryClassificationCode,
    rm.FilingInputTypeCode,
    rm.ReconciliationRequiredFlag,
    own.PartyName  AS DataOwner,
    stw.PartyName  AS DataSteward,
    rm.EvidenceRetentionNote,
    rm.MappingNotes
FROM gov.RegulatoryMapping rm
JOIN gov.RegulatoryReportItem i
  ON i.RegulatoryReportItemId = rm.RegulatoryReportItemId
JOIN gov.RegulatoryReportSection s
  ON s.RegulatoryReportSectionId = i.RegulatoryReportSectionId
JOIN gov.RegulatoryReport rr
  ON rr.RegulatoryReportId = s.RegulatoryReportId
LEFT JOIN gov.DataElement de
  ON de.DataElementId = rm.DataElementId
LEFT JOIN gov.MetricDefinition m
  ON m.MetricDefinitionId = rm.MetricDefinitionId
OUTER APPLY (
    SELECT TOP 1 p.PartyName FROM gov.RoleAssignment ra
    JOIN gov.GovernanceRole gr
      ON gr.GovernanceRoleId = ra.GovernanceRoleId
     AND gr.RoleCode = 'DATA_OWNER'
    JOIN gov.Party p ON p.PartyId = ra.PartyId
    WHERE ra.EntityTypeCode = 'DATA_ELEMENT'
      AND ra.EntityId = rm.DataElementId
) own
OUTER APPLY (
    SELECT TOP 1 p.PartyName FROM gov.RoleAssignment ra
    JOIN gov.GovernanceRole gr
      ON gr.GovernanceRoleId = ra.GovernanceRoleId
     AND gr.RoleCode = 'DATA_STEWARD'
    JOIN gov.Party p ON p.PartyId = ra.PartyId
    WHERE ra.EntityTypeCode = 'DATA_ELEMENT'
      AND ra.EntityId = rm.DataElementId
) stw;
GO

/* ---- 7b. Coverage by section, including the unmapped lines
        and why. This view is the honest counterweight to the
        mapping view: it prevents the dashboard from implying
        FV7 is fully implemented. ---- */
CREATE OR ALTER VIEW gov.vw_RegulatoryCoverage
AS
SELECT
    s.ComponentCode, s.SectionCode, s.SectionName,
    s.ScopeLevelCode,
    COUNT(DISTINCT i.RegulatoryReportItemId) AS ItemCount,
    COUNT(DISTINCT CASE WHEN rm.RegulatoryMappingId IS NOT NULL
          THEN i.RegulatoryReportItemId END) AS MappedItemCount,
    COUNT(DISTINCT CASE WHEN rm.RegulatoryMappingId IS NULL
          THEN i.RegulatoryReportItemId END) AS UnmappedItemCount,
    CASE s.SectionCode
      WHEN 'FC' THEN
        N'Financial Condition requires general ledger and '
        + N'treasury data not held by this platform. '
        + N'Project 3 scope.'
      WHEN 'SSSF' THEN
        N'State-Specific Supplemental Form varies by state '
        + N'and requires per-state configuration. '
        + N'Project 3 scope.'
      ELSE
        N'Mapped where Project 1 servicing and production '
        + N'data supports the line; remaining lines are '
        + N'origination or state-level detail in Project 2 '
        + N'and Project 3 scope.'
    END AS UnmappedReason
FROM gov.RegulatoryReportSection s
JOIN gov.RegulatoryReportItem i
  ON i.RegulatoryReportSectionId = s.RegulatoryReportSectionId
LEFT JOIN gov.RegulatoryMapping rm
  ON rm.RegulatoryReportItemId = i.RegulatoryReportItemId
GROUP BY s.ComponentCode, s.SectionCode, s.SectionName,
         s.ScopeLevelCode;
GO

/* ------------------------------------------------------------
   Section 8. Load summary
   ------------------------------------------------------------ */
DECLARE @Rows INT = (SELECT COUNT(*) FROM gov.RegulatoryMapping);
DECLARE @Items INT = (SELECT COUNT(DISTINCT RegulatoryReportItemId)
                      FROM gov.RegulatoryMapping);
DECLARE @Elems INT = (SELECT COUNT(DISTINCT DataElementId)
                      FROM gov.RegulatoryMapping
                      WHERE DataElementId IS NOT NULL);
DECLARE @Mets INT = (SELECT COUNT(DISTINCT MetricDefinitionId)
                     FROM gov.RegulatoryMapping
                     WHERE MetricDefinitionId IS NOT NULL);

PRINT 'Script 019 complete (MCR FV7):';
PRINT '  Mapping rows: ' + CAST(@Rows AS VARCHAR(10));
PRINT '  FV7 items mapped: ' + CAST(@Items AS VARCHAR(10))
    + ' of 641 seeded';
PRINT '  Distinct elements mapped: ' + CAST(@Elems AS VARCHAR(10));
PRINT '  Distinct metrics mapped: ' + CAST(@Mets AS VARCHAR(10));
GO
