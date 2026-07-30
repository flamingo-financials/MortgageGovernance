/* ============================================================
   MortgageGovernance | Phase 2 | Script 035
   Regulatory coverage classification.
   Part A maps the 13 remaining items whose governed elements
   already exist, including the LS1300-LS1340 block registered
   in 032 but never mapped.
   Part B classifies every lineage-eligible FV7 item into the
   SUPPORTED NOW / PLANNED / EXTERNAL-DEFERRED pattern the
   portfolio already uses for metrics, plus NOT_APPLICABLE for
   activity the business does not engage in.
   Azure SQL Database form. Idempotent.
   ============================================================ */
SET NOCOUNT ON;
GO

IF OBJECT_ID('reg.McrCoverageClassification') IS NULL
BEGIN
    CREATE TABLE reg.McrCoverageClassification
    (
        McrCoverageClassificationId INT IDENTITY(1,1) NOT NULL,
        ItemCode           VARCHAR(30)   NOT NULL,
        CoverageStatusCode VARCHAR(20)   NOT NULL,
        TargetProjectCode  VARCHAR(20)   NOT NULL,
        RequiredDomain     NVARCHAR(120) NULL,
        Rationale          NVARCHAR(600) NOT NULL,
        ClassifiedByPartyId INT          NULL,
        LoadBatchId        INT NULL,
        CreatedDateUtc     DATETIME2(3) NOT NULL
            CONSTRAINT DF_McrCoverageClassification_Created
            DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_McrCoverageClassification
            PRIMARY KEY CLUSTERED (McrCoverageClassificationId),
        CONSTRAINT UQ_McrCoverageClassification_ItemCode
            UNIQUE (ItemCode),
        CONSTRAINT CK_McrCoverageClassification_Status CHECK
            (CoverageStatusCode IN
             ('SUPPORTED_NOW','PLANNED','EXTERNAL_DEFERRED',
              'NOT_APPLICABLE','NARRATIVE')),
        CONSTRAINT CK_McrCoverageClassification_Project CHECK
            (TargetProjectCode IN
             ('PROJECT_1','PROJECT_2','PROJECT_3','NONE'))
    );
END;
GO

DECLARE @LoadBatchId INT,
        @Mapped INT,
        @Classified INT,
        @Detail NVARCHAR(2000),
        @Context NVARCHAR(1000),
        @NoahId INT,
        @MarcoId INT,
        @SofiaId INT;

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

SELECT @NoahId = PartyId FROM gov.Party
WHERE PartyName = 'Noah Curlew' AND PartyTypeCode = 'PERSON';
SELECT @MarcoId = PartyId FROM gov.Party
WHERE PartyName = 'Marco Ibis' AND PartyTypeCode = 'PERSON';
SELECT @SofiaId = PartyId FROM gov.Party
WHERE PartyName = 'Sofia Egret' AND PartyTypeCode = 'PERSON';

EXEC audit.usp_StartLoadBatch
    @BatchName = N'MCR regulatory coverage classification',
    @BatchTypeCode = 'ADHOC',
    @Notes = N'Maps the remaining mappable items and classifies every lineage-eligible FV7 item by coverage status.',
    @LoadBatchId = @LoadBatchId OUTPUT;

BEGIN TRY

/* ------------------------------------------------------------
   PART A. Close the 13 mappable items.
   ------------------------------------------------------------ */
INSERT INTO @ItemFamily (ItemCode, Family) VALUES
 ('LS1300','FC_BY_INVESTOR'),('LS1310','FC_BY_INVESTOR'),
 ('LS1320','FC_BY_INVESTOR'),('LS1330','FC_BY_INVESTOR'),
 ('LS1340','FC_BY_INVESTOR'),
 ('S700','LOAN_TYPE_SERVICED'),
 ('S710','LOAN_TYPE_SERVICED'),
 ('S720','LOAN_TYPE_SERVICED'),
 ('S730','LOAN_TYPE_SERVICED'),
 ('S800','OTHER_RESIDENTIAL'),
 ('S810','OTHER_RESIDENTIAL'),
 ('S820','OTHER_RESIDENTIAL'),
 ('S840','OTHER_RESIDENTIAL');

INSERT INTO @FamilyElement
    (Family, ElementCode, Classification, InputType, Recon,
     Note) VALUES
 ('FC_BY_INVESTOR','DE_INVESTOR_CODE','DERIVED_FIELD',
  'DERIVED',0,
  N'Determines the investor category line. Nationwide '
+ N'company-level scope, so no state allocation applies.'),
 ('FC_BY_INVESTOR','DE_FC_CASE_STATUS','DERIVED_FIELD',
  'DERIVED',0,
  N'Restricts the population to loans in active foreclosure '
+ N'at period end.'),
 ('FC_BY_INVESTOR','DE_CURRENT_UPB','DIRECT_FIELD','DIRECT',1,
  N'Filed dollar measure for the line.'),
 ('FC_BY_INVESTOR','DE_LOAN_NUMBER','SUPPORTING_DATA',
  'SUPPORTING',0, N'Filed count grain.'),
 ('FC_BY_INVESTOR','DE_ASOF_DATE','CONTROL_DATA',
  'CONTROL_EVIDENCE',0, N'Period-end anchor.'),

 ('LOAN_TYPE_SERVICED','DE_MCR_LOAN_TYPE','DERIVED_FIELD',
  'DERIVED',0,
  N'Primary discriminator for government, conventional '
+ N'conforming, conventional non-conforming and other.'),
 ('LOAN_TYPE_SERVICED','DE_CONFORMING_FLAG','DERIVED_FIELD',
  'DERIVED',0,
  N'Separates conforming from non-conforming within the '
+ N'conventional population.'),
 ('LOAN_TYPE_SERVICED','DE_LOAN_PROGRAM','SUPPORTING_DATA',
  'SUPPORTING',0,
  N'Corroborates the loan type assignment.'),
 ('LOAN_TYPE_SERVICED','DE_CURRENT_UPB','DIRECT_FIELD',
  'DIRECT',1, N'Filed dollar measure for the line.'),
 ('LOAN_TYPE_SERVICED','DE_LOAN_NUMBER','SUPPORTING_DATA',
  'SUPPORTING',0, N'Filed count grain.'),
 ('LOAN_TYPE_SERVICED','DE_PROPERTY_STATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'State allocation for STATE scope.'),
 ('LOAN_TYPE_SERVICED','DE_ASOF_DATE','CONTROL_DATA',
  'CONTROL_EVIDENCE',0, N'Period-end anchor.'),

 ('OTHER_RESIDENTIAL','DE_LIEN_POSITION','DERIVED_FIELD',
  'DERIVED',0, N'Identifies closed-end second mortgages.'),
 ('OTHER_RESIDENTIAL','DE_HELOC_FLAG','DERIVED_FIELD',
  'DERIVED',0, N'Identifies HELOC loans serviced.'),
 ('OTHER_RESIDENTIAL','DE_REVERSE_MORTGAGE_FLAG',
  'DERIVED_FIELD','DERIVED',0,
  N'Identifies reverse mortgages serviced.'),
 ('OTHER_RESIDENTIAL','DE_CURRENT_UPB','DIRECT_FIELD',
  'DIRECT',1, N'Filed dollar measure for the line.'),
 ('OTHER_RESIDENTIAL','DE_LOAN_NUMBER','SUPPORTING_DATA',
  'SUPPORTING',0, N'Filed count grain.'),
 ('OTHER_RESIDENTIAL','DE_PROPERTY_STATE','SUPPORTING_DATA',
  'SUPPORTING',0, N'State allocation for STATE scope.'),
 ('OTHER_RESIDENTIAL','DE_ASOF_DATE','CONTROL_DATA',
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
JOIN gov.DataElement de
  ON de.DataElementCode = fe.ElementCode
WHERE NOT EXISTS
      (SELECT 1 FROM gov.RegulatoryMapping m
       WHERE m.RegulatoryReportItemId = i.RegulatoryReportItemId
         AND m.DataElementId = de.DataElementId);
SET @Mapped = @@ROWCOUNT;

/* ------------------------------------------------------------
   PART B. Classify every lineage-eligible item.
   Explicit dispositions first, then rule-based by section,
   then SUPPORTED_NOW for anything now carrying a mapping.
   ------------------------------------------------------------ */
DELETE FROM reg.McrCoverageClassification;

/* B1. Items the business does not engage in. */
INSERT INTO reg.McrCoverageClassification
    (ItemCode, CoverageStatusCode, TargetProjectCode,
     RequiredDomain, Rationale, ClassifiedByPartyId,
     LoadBatchId)
SELECT v.Code, 'NOT_APPLICABLE', 'NONE',
       N'Commercial and consumer lending',
       N'Flamingo Financials originates and services '
     + N'residential mortgages only. It does not engage in '
     + N'commercial real estate, commercial and industrial, '
     + N'or consumer installment lending. The state '
     + N'supplemental line is filed as zero. This is an '
     + N'absence of activity, not an absence of data.',
       @SofiaId, @LoadBatchId
FROM (VALUES
 ('SF010'),('SF020'),('SF030'),('SF035'),('SF040'),('SF050'),
 ('SF100'),('SF110'),('SF120'),
 ('SF200'),('SF210'),('SF220'),('SF230'),
 ('SF300'),('SF310'),('SF320'),('SF325'),('SF330'),('SF340'),
 ('SF400'),('SF410'),('SF420'),
 ('SF500'),('SF510'),('SF520'),('SF530')
) v(Code);

/* B2. No general ledger domain in any portfolio project. */
INSERT INTO reg.McrCoverageClassification
    (ItemCode, CoverageStatusCode, TargetProjectCode,
     RequiredDomain, Rationale, ClassifiedByPartyId,
     LoadBatchId)
SELECT v.Code, 'EXTERNAL_DEFERRED', 'NONE',
       N'Finance / General Ledger',
       N'Revenue recognition originates in the general '
     + N'ledger. No Finance/GL source domain exists in any '
     + N'of the three portfolio projects, so no source '
     + N'lineage is asserted rather than manufactured.',
       @NoahId, @LoadBatchId
FROM (VALUES ('S1100'),('SF1100')) v(Code);

/* B3. Narrative field, authored by a steward. */
INSERT INTO reg.McrCoverageClassification
    (ItemCode, CoverageStatusCode, TargetProjectCode,
     RequiredDomain, Rationale, ClassifiedByPartyId,
     LoadBatchId)
VALUES
 ('NOTE', 'NARRATIVE', 'NONE', N'Steward authored',
  N'Free-text company-level explanatory note. Populated by '
+ N'the filing steward at submission, not derived from any '
+ N'governed data element. Element-level lineage does not '
+ N'apply.', @SofiaId, @LoadBatchId);

/* B4. Warehouse lending, Project 3. */
INSERT INTO reg.McrCoverageClassification
    (ItemCode, CoverageStatusCode, TargetProjectCode,
     RequiredDomain, Rationale, ClassifiedByPartyId,
     LoadBatchId)
VALUES
 ('LOC', 'PLANNED', 'PROJECT_3', N'Warehouse Lending',
  N'Repeating list of warehouse lines of credit at period '
+ N'end. Requires a warehouse lending and treasury source '
+ N'domain, scheduled with the Financial Condition build in '
+ N'Project 3.', @NoahId, @LoadBatchId);

/* B5. Licensed processor and underwriter volumes. */
INSERT INTO reg.McrCoverageClassification
    (ItemCode, CoverageStatusCode, TargetProjectCode,
     RequiredDomain, Rationale, ClassifiedByPartyId,
     LoadBatchId)
SELECT v.Code, 'PLANNED', 'PROJECT_2',
       N'Loan Origination',
       N'Application processing and underwriting volumes '
     + N'reported under a processor or underwriter license. '
     + N'Depends on the origination pipeline scheduled for '
     + N'Project 2.', @MarcoId, @LoadBatchId
FROM (VALUES
 ('SF600'),('SF610'),('SF620'),('SF630'),('SF640'),('SF650')
) v(Code);

/* B6. Rule-based by section for everything still unclassified. */
INSERT INTO reg.McrCoverageClassification
    (ItemCode, CoverageStatusCode, TargetProjectCode,
     RequiredDomain, Rationale, ClassifiedByPartyId,
     LoadBatchId)
SELECT r.ItemCode,
       CASE
           WHEN EXISTS (SELECT 1 FROM gov.RegulatoryMapping m
                        WHERE m.RegulatoryReportItemId
                              = ri.RegulatoryReportItemId
                          AND m.MappedEntityTypeCode
                              = 'DATA_ELEMENT')
                THEN 'SUPPORTED_NOW'
           ELSE 'PLANNED'
       END,
       CASE
           WHEN EXISTS (SELECT 1 FROM gov.RegulatoryMapping m
                        WHERE m.RegulatoryReportItemId
                              = ri.RegulatoryReportItemId
                          AND m.MappedEntityTypeCode
                              = 'DATA_ELEMENT')
                THEN 'PROJECT_1'
           WHEN s.SectionCode = 'FC' THEN 'PROJECT_3'
           WHEN s.SectionCode IN ('RMLA_SEC1','RMLA_SEC2')
                THEN 'PROJECT_2'
           ELSE 'PROJECT_1'
       END,
       CASE
           WHEN s.SectionCode = 'FC'
                THEN N'Finance / General Ledger'
           WHEN s.SectionCode IN ('RMLA_SEC1','RMLA_SEC2')
                THEN N'Loan Origination'
           ELSE N'Servicing Core'
       END,
       CASE
           WHEN EXISTS (SELECT 1 FROM gov.RegulatoryMapping m
                        WHERE m.RegulatoryReportItemId
                              = ri.RegulatoryReportItemId
                          AND m.MappedEntityTypeCode
                              = 'DATA_ELEMENT')
                THEN N'Governed elements are mapped and bound '
                   + N'through the warehouse to source '
                   + N'systems. Traceable end to end today.'
           WHEN s.SectionCode = 'FC'
                THEN N'Financial Condition schedules depend '
                   + N'on a general ledger and treasury '
                   + N'source domain. Scheduled for the '
                   + N'Project 3 regulatory reporting build.'
           WHEN s.SectionCode IN ('RMLA_SEC1','RMLA_SEC2')
                THEN N'State-level origination volumes '
                   + N'depend on the lead, application, '
                   + N'lock and funding domains scheduled '
                   + N'for Project 2.'
           ELSE N'Servicing item without a governed element '
              + N'mapping. Steward review required.'
       END,
       @NoahId, @LoadBatchId
FROM reg.vw_McrBridgeReview r
JOIN gov.RegulatoryReportItem ri ON ri.ItemCode = r.ItemCode
JOIN gov.RegulatoryReportSection s
  ON s.RegulatoryReportSectionId
     = ri.RegulatoryReportSectionId
WHERE r.LineageEligibleFlag = 1
  AND NOT EXISTS
      (SELECT 1 FROM reg.McrCoverageClassification c
       WHERE c.ItemCode = r.ItemCode);
SET @Classified = @@ROWCOUNT;

SET @Detail = N'Regulatory coverage classification complete. '
    + CAST(@Mapped AS NVARCHAR(10))
    + N' element mappings added across 13 items. '
    + N'All lineage-eligible FV7 items classified by '
    + N'coverage status and target project.';

INSERT INTO gov.ChangeLog
    (EntityTypeCode, EntityReference, ChangeTypeCode,
     ChangeDescription, LoadBatchId)
VALUES
    ('REGULATORY_COVERAGE',
     N'reg.McrCoverageClassification', 'INSERT',
     @Detail, @LoadBatchId);

EXEC audit.usp_CompleteLoadBatch
    @LoadBatchId = @LoadBatchId,
    @StatusCode = 'SUCCESS';

END TRY
BEGIN CATCH
    SET @Context = N'Script 035 regulatory coverage classification';
    EXEC audit.usp_LogError
        @LoadBatchId = @LoadBatchId,
        @ContextInfo = @Context;
    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'FAILED';
    THROW;
END CATCH;
GO

/* ------------------------------------------------------------
   Verification
   ------------------------------------------------------------ */
SELECT CoverageStatusCode, TargetProjectCode,
       COUNT(*) AS Items
FROM reg.McrCoverageClassification
GROUP BY CoverageStatusCode, TargetProjectCode
ORDER BY CoverageStatusCode, TargetProjectCode;

SELECT 'Eligible items classified' AS Check_,
       (SELECT COUNT(*) FROM reg.McrCoverageClassification)
           AS Actual,
       513 AS Expected;

SELECT 'Unclassified eligible items' AS Check_,
       COUNT(*) AS Actual, 0 AS Expected
FROM reg.vw_McrBridgeReview r
WHERE r.LineageEligibleFlag = 1
  AND NOT EXISTS
      (SELECT 1 FROM reg.McrCoverageClassification c
       WHERE c.ItemCode = r.ItemCode);
GO