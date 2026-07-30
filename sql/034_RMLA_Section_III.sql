/* ============================================================
   MortgageGovernance | Phase 2 | Script 034
   RMLA Section III servicing mapping gap closure.
   Script 019 mapped 12 of 60 eligible Section III items.
   The remaining 48 are servicing facts the warehouse already
   holds. This maps the 39 whose concept families are
   identifiable and reports the residual rather than
   asserting full closure.
   Azure SQL Database form. Idempotent.
   ============================================================ */
SET NOCOUNT ON;
GO

DECLARE @LoadBatchId INT,
        @Rows INT,
        @Residual INT,
        @Detail NVARCHAR(2000),
        @Context NVARCHAR(1000);

DECLARE @ItemFamily TABLE
    (ItemCode VARCHAR(30) NOT NULL,
     Family   VARCHAR(30) NOT NULL);

DECLARE @FamilyElement TABLE
    (Family         VARCHAR(30)  NOT NULL,
     ElementCode    VARCHAR(60)  NOT NULL,
     Classification VARCHAR(40)  NOT NULL,
     InputType      VARCHAR(20)  NOT NULL,
     Recon          BIT          NOT NULL,
     Note           NVARCHAR(300) NOT NULL);

EXEC audit.usp_StartLoadBatch
    @BatchName = N'RMLA Section III mapping gap closure',
    @BatchTypeCode = 'ADHOC',
    @Notes = N'Maps the servicing items script 019 left unmapped in RMLA Section III.',
    @LoadBatchId = @LoadBatchId OUTPUT;

BEGIN TRY

INSERT INTO @ItemFamily (ItemCode, Family) VALUES
 ('S300','DELINQ_BUCKET'),('S305','DELINQ_BUCKET'),
 ('S310','DELINQ_BUCKET'),('S315','DELINQ_BUCKET'),
 ('S320','DELINQ_BUCKET'),('S325','DELINQ_BUCKET'),
 ('S330','DELINQ_BUCKET'),('S335','DELINQ_BUCKET'),
 ('S340','DELINQ_BUCKET'),('S345','DELINQ_BUCKET'),
 ('S350','DELINQ_BUCKET'),('S355','DELINQ_BUCKET'),
 ('S400','FC_STATUS'),('S410','FC_STATUS'),
 ('S420','FC_STATUS'),('S430','FC_STATUS'),
 ('S450','REO_SHORTSALE'),('S460','REO_SHORTSALE'),
 ('S470','FORBEARANCE'),('S471','FORBEARANCE'),
 ('S472','FORBEARANCE'),('S473','FORBEARANCE'),
 ('S474','FORBEARANCE'),
 ('S510','SERVICING_CATEGORY'),
 ('S520','SERVICING_CATEGORY'),
 ('S520A','SERVICING_CATEGORY'),
 ('S530','SERVICING_CATEGORY'),
 ('S530A','SERVICING_CATEGORY'),
 ('S540','SERVICING_CATEGORY'),
 ('S540A','SERVICING_CATEGORY'),
 ('S600','RATE_TYPE'),('S610','RATE_TYPE'),
 ('S1000','LTV_BAND'),('S1010','LTV_BAND'),
 ('S1020','LTV_BAND'),('S1030','LTV_BAND'),
 ('S1040','LTV_BAND'),('S1050','LTV_BAND'),
 ('S270','LOAN_MOD');

INSERT INTO @FamilyElement
    (Family, ElementCode, Classification, InputType, Recon,
     Note) VALUES
 ('DELINQ_BUCKET','DE_DELINQUENCY_BUCKET','DERIVED_FIELD',
  'DERIVED',0,
  N'Determines which delinquency line the loan falls on. '
+ N'Bucket boundaries resolve from ref, never from inline '
+ N'CASE logic.'),
 ('DELINQ_BUCKET','DE_DAYS_PAST_DUE','SUPPORTING_DATA',
  'SUPPORTING',0,
  N'Input to the bucket derivation. Retained so the bucket '
+ N'assignment is reproducible.'),
 ('DELINQ_BUCKET','DE_CURRENT_UPB','DIRECT_FIELD','DIRECT',1,
  N'Filed dollar measure for the line.'),
 ('DELINQ_BUCKET','DE_SERVICING_TYPE','DERIVED_FIELD',
  'DERIVED',0,
  N'Discriminates the three parallel Section III delinquency '
+ N'blocks by servicing category.'),
 ('DELINQ_BUCKET','DE_LOAN_NUMBER','SUPPORTING_DATA',
  'SUPPORTING',0, N'Filed count grain.'),
 ('DELINQ_BUCKET','DE_PROPERTY_STATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'State allocation for STATE scope.'),
 ('DELINQ_BUCKET','DE_ASOF_DATE','CONTROL_DATA',
  'CONTROL_EVIDENCE',0, N'Period-end anchor.'),

 ('FC_STATUS','DE_FC_CASE_STATUS','DERIVED_FIELD','DERIVED',0,
  N'Determines foreclosure line membership at period end.'),
 ('FC_STATUS','DE_FC_REFERRAL_DATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'Drives moved-into-foreclosure in period.'),
 ('FC_STATUS','DE_FC_SALE_HELD_DATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'Drives sheriff sale in period.'),
 ('FC_STATUS','DE_FC_RESOLUTION_TYPE','DERIVED_FIELD',
  'DERIVED',0,
  N'Separates resolution other than sheriff sale from sale.'),
 ('FC_STATUS','DE_CURRENT_UPB','DIRECT_FIELD','DIRECT',1,
  N'Filed dollar measure for the line.'),
 ('FC_STATUS','DE_PROPERTY_STATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'State allocation for STATE scope.'),
 ('FC_STATUS','DE_ASOF_DATE','CONTROL_DATA',
  'CONTROL_EVIDENCE',0, N'Period-end anchor.'),

 ('REO_SHORTSALE','DE_FC_RESOLUTION_TYPE','DERIVED_FIELD',
  'DERIVED',0, N'Identifies REO and short sale outcomes.'),
 ('REO_SHORTSALE','DE_RUNOFF_REASON','DERIVED_FIELD',
  'DERIVED',0, N'Identifies loans paid through short sale.'),
 ('REO_SHORTSALE','DE_CURRENT_UPB','DIRECT_FIELD','DIRECT',1,
  N'Filed dollar measure for the line.'),
 ('REO_SHORTSALE','DE_PROPERTY_STATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'State allocation for STATE scope.'),
 ('REO_SHORTSALE','DE_ASOF_DATE','CONTROL_DATA',
  'CONTROL_EVIDENCE',0, N'Period-end anchor.'),

 ('FORBEARANCE','DE_FORB_STATUS','DERIVED_FIELD','DERIVED',0,
  N'Determines forbearance line membership.'),
 ('FORBEARANCE','DE_FORBEARANCE_FLAG','SUPPORTING_DATA',
  'SUPPORTING',0, N'Beginning-of-period population.'),
 ('FORBEARANCE','DE_FORB_START_DATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'Drives entering forbearance in period.'),
 ('FORBEARANCE','DE_FORB_END_DATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'Drives the three exit lines.'),
 ('FORBEARANCE','DE_LM_WORKOUT_TYPE','DERIVED_FIELD',
  'DERIVED',0,
  N'Separates exit to loss mitigation from exit to '
+ N'contractual payment.'),
 ('FORBEARANCE','DE_FC_CASE_STATUS','SUPPORTING_DATA',
  'SUPPORTING',0, N'Separates exit into foreclosure.'),
 ('FORBEARANCE','DE_PROPERTY_STATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'State allocation for STATE scope.'),
 ('FORBEARANCE','DE_ASOF_DATE','CONTROL_DATA',
  'CONTROL_EVIDENCE',0, N'Period-end anchor.'),

 ('SERVICING_CATEGORY','DE_SERVICING_TYPE','DERIVED_FIELD',
  'DERIVED',0,
  N'Separates wholly owned, serviced under MSRs, '
+ N'subservicing for others, and subserviced by others.'),
 ('SERVICING_CATEGORY','DE_INVESTOR_CODE','SUPPORTING_DATA',
  'SUPPORTING',0, N'Repeating detail row grain.'),
 ('SERVICING_CATEGORY','DE_MSR_OWNER_NMLS','SUPPORTING_DATA',
  'SUPPORTING',0,
  N'Counterparty NMLS ID on the repeating detail rows.'),
 ('SERVICING_CATEGORY','DE_CURRENT_UPB','DIRECT_FIELD',
  'DIRECT',1, N'Filed dollar measure for the line.'),
 ('SERVICING_CATEGORY','DE_LOAN_NUMBER','SUPPORTING_DATA',
  'SUPPORTING',0, N'Filed count grain.'),
 ('SERVICING_CATEGORY','DE_PROPERTY_STATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'State allocation for STATE scope.'),
 ('SERVICING_CATEGORY','DE_ASOF_DATE','CONTROL_DATA',
  'CONTROL_EVIDENCE',0, N'Period-end anchor.'),

 ('RATE_TYPE','DE_INTEREST_RATE_TYPE','DERIVED_FIELD',
  'DERIVED',0, N'Separates fixed from ARM serviced.'),
 ('RATE_TYPE','DE_LOAN_PROGRAM','SUPPORTING_DATA',
  'SUPPORTING',0, N'Corroborates amortization type.'),
 ('RATE_TYPE','DE_CURRENT_UPB','DIRECT_FIELD','DIRECT',1,
  N'Filed dollar measure for the line.'),
 ('RATE_TYPE','DE_PROPERTY_STATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'State allocation for STATE scope.'),
 ('RATE_TYPE','DE_ASOF_DATE','CONTROL_DATA',
  'CONTROL_EVIDENCE',0, N'Period-end anchor.'),

 ('LTV_BAND','DE_CURRENT_LTV','DERIVED_FIELD','DERIVED',0,
  N'Determines LTV band membership. Band boundaries resolve '
+ N'from ref, never from inline CASE logic.'),
 ('LTV_BAND','DE_CURRENT_UPB','DIRECT_FIELD','DIRECT',1,
  N'Numerator of the LTV derivation and the filed measure.'),
 ('LTV_BAND','DE_PROPERTY_VALUE','SUPPORTING_DATA',
  'SUPPORTING',0, N'Denominator of the LTV derivation.'),
 ('LTV_BAND','DE_VALUATION_DATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'Establishes valuation currency.'),
 ('LTV_BAND','DE_VALUATION_METHOD','CONTROL_DATA',
  'CONTROL_EVIDENCE',0,
  N'Valuation basis retained as filing evidence.'),
 ('LTV_BAND','DE_PROPERTY_STATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'State allocation for STATE scope.'),
 ('LTV_BAND','DE_ASOF_DATE','CONTROL_DATA',
  'CONTROL_EVIDENCE',0, N'Period-end anchor.'),

 ('LOAN_MOD','DE_MOD_EFFECTIVE_DATE','DERIVED_FIELD',
  'DERIVED',0, N'Establishes in-period modification activity.'),
 ('LOAN_MOD','DE_MOD_BOOKED_DATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'Booking date for reconciliation.'),
 ('LOAN_MOD','DE_LM_WORKOUT_TYPE','DERIVED_FIELD','DERIVED',0,
  N'Restricts to modification workouts.'),
 ('LOAN_MOD','DE_LM_DECISION_CODE','SUPPORTING_DATA',
  'SUPPORTING',0, N'Decision outcome supporting the change.'),
 ('LOAN_MOD','DE_CURRENT_UPB','DIRECT_FIELD','DIRECT',1,
  N'Filed dollar measure for the net change.'),
 ('LOAN_MOD','DE_PROPERTY_STATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'State allocation for STATE scope.'),
 ('LOAN_MOD','DE_ASOF_DATE','CONTROL_DATA',
  'CONTROL_EVIDENCE',0, N'Period-end anchor.');

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
 AND s.SectionCode = 'RMLA_SEC3'
JOIN gov.DataElement de
  ON de.DataElementCode = fe.ElementCode
WHERE NOT EXISTS
      (SELECT 1 FROM gov.RegulatoryMapping m
       WHERE m.RegulatoryReportItemId = i.RegulatoryReportItemId
         AND m.DataElementId = de.DataElementId);
SET @Rows = @@ROWCOUNT;

SELECT @Residual = COUNT(DISTINCT r.ItemCode)
FROM reg.vw_McrBridgeReview r
JOIN gov.RegulatoryReportItem i ON i.ItemCode = r.ItemCode
JOIN gov.RegulatoryReportSection s
  ON s.RegulatoryReportSectionId = i.RegulatoryReportSectionId
 AND s.SectionCode = 'RMLA_SEC3'
WHERE r.LineageEligibleFlag = 1
  AND NOT EXISTS
      (SELECT 1 FROM gov.RegulatoryMapping m
       WHERE m.RegulatoryReportItemId = i.RegulatoryReportItemId
         AND m.MappedEntityTypeCode = 'DATA_ELEMENT');

SET @Detail = N'RMLA Section III mapping gap closure. '
    + CAST(@Rows AS NVARCHAR(10))
    + N' element mappings added across 39 servicing items in '
    + N'8 concept families. Residual unmapped Section III '
    + N'items: ' + CAST(@Residual AS NVARCHAR(10)) + N'.';

INSERT INTO gov.ChangeLog
    (EntityTypeCode, EntityReference, ChangeTypeCode,
     ChangeDescription, LoadBatchId)
VALUES
    ('REGULATORY_MAPPING', N'gov.RegulatoryMapping',
     'INSERT', @Detail, @LoadBatchId);

EXEC audit.usp_CompleteLoadBatch
    @LoadBatchId = @LoadBatchId,
    @StatusCode = 'SUCCESS';

END TRY
BEGIN CATCH
    SET @Context = N'Script 034 RMLA Section III mapping';
    EXEC audit.usp_LogError
        @LoadBatchId = @LoadBatchId,
        @ContextInfo = @Context;
    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'FAILED';
    THROW;
END CATCH;
GO