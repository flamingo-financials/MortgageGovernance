/* ============================================================
   MortgageGovernance | Integration Phase 1 | Script 030
   MCR integration: source registration, the MCR access
   layer, and the FV7 item bridge.

   PROBLEM
   The governance platform and the MCR toolkit each held
   an independent NMLS MCR FV7 registry.
   gov.RegulatoryReportItem holds 641
   business line items with NMLS instruction text and source
   mapping guidance. mcr.FieldCatalog holds 635 items and
   1,228 submittable elements generated from the FV7 XSD.
   Neither is wrong; they describe different layers. Until
   they are reconciled, no coverage claim about MCR is
   defensible and nothing should move to Fabric.

   AUTHORITY SPLIT (registered in gov.ChangeLog by this
   script)
   mcr.FieldCatalog is authoritative for submission
   structure: element names, data types, column numbers,
   section paths, calculated flags, required flags.
   gov.RegulatoryReportItem is authoritative for business
   meaning: instruction text, source mapping guidance,
   ownership, CDE and metric linkage.

   FABRIC ISOLATION RULE
   All MCR access in the platform runs through the seven
   reg.vw_Mcr* views created here and nowhere else. When the
   MCR layer lands in OneLake, only these seven view bodies
   are replaced. Nothing downstream changes.

   AZURE SQL DATABASE FORM. Connect directly to
   MortgageGovernance. No USE statement.
   Requires the converted MCR toolkit (mcr_01 to mcr_11)
   already deployed into this same database.
   Idempotent: safe to re-run.
   ============================================================ */
SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   1. Preflight. The MCR engine must already live in this
      database. Run sql/mcr/mcr_01 through mcr_11 first.
   ------------------------------------------------------------ */
DECLARE @PreflightMsg NVARCHAR(400);

IF OBJECT_ID('mcr.FieldCatalog') IS NULL
BEGIN
    SET @PreflightMsg =
        N'mcr.FieldCatalog not found. Run the converted MCR '
      + N'toolkit scripts mcr_01 through mcr_11 against this '
      + N'database, then re-run 030.';
    THROW 50030, @PreflightMsg, 1;
END;
GO

/* ------------------------------------------------------------
   2. Register the MCR Toolkit as a governed source system
      and register its objects with mandatory grain
      statements. The toolkit stops being an orphan asset.
   ------------------------------------------------------------ */
DECLARE @LoadBatchId INT;
DECLARE @BatchNotes NVARCHAR(400) =
    N'Script 030: MCR Toolkit source registration, '
  + N'cross-database isolation views, FV7 item bridge.';

EXEC audit.usp_StartLoadBatch
     @BatchName     = N'MCR Toolkit integration phase 1',
     @BatchTypeCode = 'SEED',
     @Notes         = @BatchNotes,
     @LoadBatchId   = @LoadBatchId OUTPUT;

BEGIN TRY
BEGIN TRAN;

IF NOT EXISTS (SELECT 1 FROM gov.SourceSystem
               WHERE SourceSystemCode = 'MCR')
INSERT INTO gov.SourceSystem
    (SourceSystemCode, SourceSystemName, SystemDescription,
     SystemTypeCode, DomainArea,
     AuthoritativeScopeSummary, LoadBatchId)
VALUES
    ('MCR', N'McrFilingToolkit',
     N'NMLS Mortgage Call Report FV7 filing engine: XSD '
   + N'field catalog, value loader, filing validation, XML '
   + N'generation, immutable filing archive, HMDA and '
   + N'MBFRF reconciliation layers.',
     'GOVERNANCE', N'Regulatory Reporting',
     N'Authoritative for FV7 submission structure and for '
   + N'filed values, filing validation results, and '
   + N'archived submissions. Not authoritative for '
   + N'loan-level data; that authority stays with SVC, '
   + N'PAY, DMS, INV and the governed warehouse.',
     @LoadBatchId);

DECLARE @McrSystemId INT =
    (SELECT SourceSystemId FROM gov.SourceSystem
     WHERE SourceSystemCode = 'MCR');

INSERT INTO gov.SourceObject
    (SourceSystemId, SchemaName, ObjectName,
     ObjectTypeCode, GrainStatement, ObjectDescription,
     LoadBatchId)
SELECT @McrSystemId, v.Sch, v.Obj, v.Typ, v.Grain,
       v.Descr, @LoadBatchId
FROM (VALUES
 ('mcr', N'FieldCatalog', 'TABLE',
  N'One row per FV7 form item code.',
  N'XSD-generated FV7 item registry. 635 items, 510 '
+ N'submittable and 125 NMLS-calculated.'),
 ('mcr', N'FieldCatalogElement', 'TABLE',
  N'One row per FV7 submittable element within an item.',
  N'1,228 elements with data type and column number.'),
 ('mcr', N'ListCatalog', 'TABLE',
  N'One row per FV7 repeating list.',
  N'Five repeating lists: MLO detail, three Section III '
+ N'investor detail lists, warehouse lines of credit.'),
 ('mcr', N'Filing', 'TABLE',
  N'One row per filing period per company.',
  N'Filing register: period, form version, filer type, '
+ N'primary state, prior filing linkage.'),
 ('mcr', N'ReportValues', 'TABLE',
  N'One row per filing, scope key, and element.',
  N'Non-repeating filed values.'),
 ('mcr', N'ValidationResults', 'TABLE',
  N'One row per filing validation finding.',
  N'Output of usp_ValidateFiling rules 1 through 14, '
+ N'including HMDA and MBFRF reconciliation findings.'),
 ('mcr', N'FilingArchive', 'TABLE',
  N'One row per archived filing submission.',
  N'Immutable hash-verified archive of the submitted XML '
+ N'and the validation results at submission time.')
) v(Sch, Obj, Typ, Grain, Descr)
WHERE NOT EXISTS
      (SELECT 1 FROM gov.SourceObject o
       WHERE o.SourceSystemId = @McrSystemId
         AND o.SchemaName = v.Sch
         AND o.ObjectName = v.Obj);

DECLARE @AuthorityNote NVARCHAR(2000) =
    N'Integration phase 1 decision. Two independent MCR '
  + N'FV7 registries exist. mcr.FieldCatalog is '
  + N'authoritative for submission structure because it is '
  + N'generated from MCRBatchFileSchemaV7.xsd. '
  + N'gov.RegulatoryReportItem is authoritative for '
  + N'business meaning, instruction text, source mapping '
  + N'guidance, and downstream CDE and metric linkage. '
  + N'The two are reconciled in reg.McrItemBridge, not '
  + N'merged. Unmatched items on either side are exceptions '
  + N'for steward review, not silent gaps.';

IF NOT EXISTS (SELECT 1 FROM gov.ChangeLog
               WHERE EntityTypeCode = 'REGULATORY_REGISTRY'
                 AND EntityReference =
                     N'gov.RegulatoryReportItem | mcr.FieldCatalog')
INSERT INTO gov.ChangeLog
    (EntityTypeCode, EntityReference, ChangeTypeCode,
     ChangeDescription, LoadBatchId)
VALUES
    ('REGULATORY_REGISTRY',
     N'gov.RegulatoryReportItem | mcr.FieldCatalog',
     'VERSION', @AuthorityNote, @LoadBatchId);

COMMIT;

EXEC audit.usp_CompleteLoadBatch
     @LoadBatchId = @LoadBatchId,
     @StatusCode  = 'SUCCESS';

PRINT 'Script 030 step 2 complete: MCR source system and 7 '
    + 'objects registered.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    EXEC audit.usp_LogError
         @LoadBatchId = @LoadBatchId,
         @ContextInfo = N'030_reg_mcr_bridge.sql step 2';
    EXEC audit.usp_CompleteLoadBatch
         @LoadBatchId = @LoadBatchId,
         @StatusCode  = 'FAILED';
    THROW;
END CATCH
GO

/* ------------------------------------------------------------
   3. MCR access layer.
      Two-part names, single database. These seven views are
      the only interface between the governance platform and
      the MCR filing engine. At Fabric Gold their bodies
      repoint at Delta tables and nothing downstream changes.
   ------------------------------------------------------------ */
GO
CREATE OR ALTER VIEW reg.vw_McrFieldCatalog AS
SELECT ItemCode, SectionPath, Scope, IsCalculated,
       IsRequired, CrossFootNote, FormOrder, Label
FROM mcr.FieldCatalog;
GO
CREATE OR ALTER VIEW reg.vw_McrFieldCatalogElement AS
SELECT ElementName, ItemCode, DataType, ColumnNo, ElemOrder
FROM mcr.FieldCatalogElement;
GO
CREATE OR ALTER VIEW reg.vw_McrListCatalog AS
SELECT ListName, ParentPath, ItemElement, Scope, MaxItems
FROM mcr.ListCatalog;
GO
CREATE OR ALTER VIEW reg.vw_McrListElementCatalog AS
SELECT ListName, ElementName, DataType, ElemOrder
FROM mcr.ListElementCatalog;
GO
CREATE OR ALTER VIEW reg.vw_McrFiling AS
SELECT FilingId, CompanyNmlsId, CompanyName, FilerType,
       FormVersion, [Year], PeriodType, PeriodStart,
       PeriodEnd, PrimaryStateCode, PriorFilingId
FROM mcr.Filing;
GO
CREATE OR ALTER VIEW reg.vw_McrReportValues AS
SELECT FilingId, ScopeKey, ElementName, NumValue, TextValue
FROM mcr.ReportValues;
GO
CREATE OR ALTER VIEW reg.vw_McrValidationResults AS
SELECT ResultId, FilingId, Severity, RuleType, ScopeKey,
       ItemCode, Detail, CheckedAt
FROM mcr.ValidationResults;
GO

/* ------------------------------------------------------------
   4. Bridge tables.
      reg.McrListMap is steward-maintained. It carries the
      gov items that correspond to an mcr repeating list
      rather than to an mcr.FieldCatalog item. Seeded with
      the two verified correspondences; add rows here as
      GOV_ONLY exceptions are reviewed.
   ------------------------------------------------------------ */
IF OBJECT_ID('reg.McrListMap') IS NULL
BEGIN
    CREATE TABLE reg.McrListMap
    (
        McrListMapId  INT IDENTITY(1,1) NOT NULL,
        GovItemCode   VARCHAR(30)  NOT NULL,
        McrListName   VARCHAR(60)  NOT NULL,
        MappingNote   NVARCHAR(400) NULL,
        LoadBatchId   INT NULL,
        CreatedDateUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_McrListMap_CreatedDateUtc
            DEFAULT SYSUTCDATETIME(),
        ModifiedDateUtc DATETIME2(3) NULL,
        CONSTRAINT PK_McrListMap
            PRIMARY KEY CLUSTERED (McrListMapId),
        CONSTRAINT UQ_McrListMap_GovItemCode
            UNIQUE (GovItemCode)
    );
END;
GO

INSERT INTO reg.McrListMap
    (GovItemCode, McrListName, MappingNote)
SELECT v.GovCode, v.ListName, v.Note
FROM (VALUES
 ('LOC', 'LinesOfCreditItem',
  N'RMLA company-level warehouse lines of credit. One '
+ N'repeating row per provider.'),
 ('ACMLO1', 'SectionIMlosItem',
  N'RMLA Section I MLO detail. One repeating row per '
+ N'MLO NMLS ID.')
) v(GovCode, ListName, Note)
WHERE NOT EXISTS
      (SELECT 1 FROM reg.McrListMap m
       WHERE m.GovItemCode = v.GovCode);
GO

IF OBJECT_ID('reg.McrItemBridge') IS NULL
BEGIN
    CREATE TABLE reg.McrItemBridge
    (
        McrItemBridgeId INT IDENTITY(1,1) NOT NULL,
        ItemCode        VARCHAR(30)   NOT NULL,
        RegulatoryReportItemId INT     NULL,
        GovComponentCode VARCHAR(20)  NULL,
        GovSectionCode  VARCHAR(20)   NULL,
        GovScopeLevelCode VARCHAR(20) NULL,
        GovItemName     NVARCHAR(300) NULL,
        GovCalculatedFlag BIT         NULL,
        McrSectionPath  VARCHAR(120)  NULL,
        McrScope        VARCHAR(10)   NULL,
        McrIsCalculated BIT           NULL,
        McrIsRequired   BIT           NULL,
        McrLabel        VARCHAR(240)  NULL,
        McrElementCount INT           NULL,
        McrListName     VARCHAR(60)   NULL,
        MatchStatusCode VARCHAR(20)   NOT NULL,
        ComponentAlignedFlag BIT      NULL,
        CalcFlagAlignedFlag  BIT      NULL,
        ReviewNote      NVARCHAR(400) NULL,
        LoadBatchId     INT NULL,
        CreatedDateUtc  DATETIME2(3) NOT NULL
            CONSTRAINT DF_McrItemBridge_CreatedDateUtc
            DEFAULT SYSUTCDATETIME(),
        ModifiedDateUtc DATETIME2(3) NULL,
        CONSTRAINT PK_McrItemBridge
            PRIMARY KEY CLUSTERED (McrItemBridgeId),
        CONSTRAINT FK_McrItemBridge_RegulatoryReportItem
            FOREIGN KEY (RegulatoryReportItemId)
            REFERENCES gov.RegulatoryReportItem
                       (RegulatoryReportItemId),
        CONSTRAINT CK_McrItemBridge_MatchStatusCode CHECK
            (MatchStatusCode IN
             ('MATCHED','MATCHED_LIST','GOV_ONLY',
              'MCR_ONLY','AMBIGUOUS'))
    );
    CREATE NONCLUSTERED INDEX IX_McrItemBridge_ItemCode
        ON reg.McrItemBridge (ItemCode);
    CREATE NONCLUSTERED INDEX IX_McrItemBridge_Status
        ON reg.McrItemBridge (MatchStatusCode);
END;
GO

/* ------------------------------------------------------------
   5. Bridge refresh procedure.
      Reads only reg.vw_Mcr* views and gov tables. No
      three-part names. Portable to Fabric unchanged.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE reg.usp_RefreshMcrItemBridge
    @LoadBatchId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @McrReportId INT =
        (SELECT RegulatoryReportId FROM gov.RegulatoryReport
         WHERE ReportCode = 'MCR_FV7');

    DECLARE @NoReportMsg NVARCHAR(400) =
        N'MCR_FV7 not registered in gov.RegulatoryReport. '
      + N'Run scripts 004 and 006 first.';

    IF @McrReportId IS NULL
        THROW 50031, @NoReportMsg, 1;

    DELETE FROM reg.McrItemBridge;

    ;WITH GovItem AS
    (
        SELECT i.RegulatoryReportItemId,
               i.ItemCode,
               i.ItemName,
               i.CalculatedFlag,
               s.ComponentCode,
               s.SectionCode,
               s.ScopeLevelCode,
               COUNT(*) OVER (PARTITION BY i.ItemCode)
                   AS CodeCount
        FROM gov.RegulatoryReportItem i
        JOIN gov.RegulatoryReportSection s
          ON s.RegulatoryReportSectionId =
             i.RegulatoryReportSectionId
        WHERE s.RegulatoryReportId = @McrReportId
    ),
    McrItem AS
    (
        SELECT c.ItemCode,
               c.SectionPath,
               c.Scope,
               c.IsCalculated,
               c.IsRequired,
               c.Label,
               ec.ElementCount
        FROM reg.vw_McrFieldCatalog c
        OUTER APPLY
        (
            SELECT COUNT(*) AS ElementCount
            FROM reg.vw_McrFieldCatalogElement e
            WHERE e.ItemCode = c.ItemCode
        ) ec
    )
    INSERT INTO reg.McrItemBridge
        (ItemCode, RegulatoryReportItemId, GovComponentCode,
         GovSectionCode, GovScopeLevelCode, GovItemName,
         GovCalculatedFlag, McrSectionPath, McrScope,
         McrIsCalculated, McrIsRequired, McrLabel,
         McrElementCount, MatchStatusCode,
         ComponentAlignedFlag, CalcFlagAlignedFlag,
         ReviewNote, LoadBatchId)
    SELECT
        COALESCE(g.ItemCode, m.ItemCode),
        g.RegulatoryReportItemId,
        g.ComponentCode,
        g.SectionCode,
        g.ScopeLevelCode,
        g.ItemName,
        g.CalculatedFlag,
        m.SectionPath,
        m.Scope,
        m.IsCalculated,
        m.IsRequired,
        m.Label,
        m.ElementCount,
        CASE
            WHEN g.ItemCode IS NULL THEN 'MCR_ONLY'
            WHEN m.ItemCode IS NULL THEN 'GOV_ONLY'
            WHEN g.CodeCount > 1    THEN 'AMBIGUOUS'
            ELSE 'MATCHED'
        END,
        CASE
            WHEN g.ComponentCode IS NULL
              OR m.Scope IS NULL THEN NULL
            WHEN g.ComponentCode = 'FC'
             AND m.Scope = 'FC' THEN 1
            WHEN g.ComponentCode = 'SSSF'
             AND m.Scope = 'SSSF' THEN 1
            WHEN g.ComponentCode = 'RMLA'
             AND m.Scope IN ('STATE','COMPANY')
             AND g.ScopeLevelCode = m.Scope THEN 1
            ELSE 0
        END,
        CASE
            WHEN g.CalculatedFlag IS NULL
              OR m.IsCalculated IS NULL THEN NULL
            WHEN g.CalculatedFlag = m.IsCalculated THEN 1
            ELSE 0
        END,
        CASE
            WHEN g.ItemCode IS NULL THEN
                N'Present in the XSD catalog only. No '
              + N'business definition registered in '
              + N'gov.RegulatoryReportItem.'
            WHEN m.ItemCode IS NULL THEN
                N'Present in the business registry only. '
              + N'Not a submittable FV7 item code. Check '
              + N'reg.McrListMap for a repeating list '
              + N'correspondence.'
            WHEN g.CodeCount > 1 THEN
                N'Item code appears in more than one gov '
              + N'section. Steward must confirm which '
              + N'section owns the FV7 item.'
            ELSE NULL
        END,
        @LoadBatchId
    FROM GovItem g
    FULL OUTER JOIN McrItem m
      ON m.ItemCode = g.ItemCode;

    /* Resolve gov-only rows that map to a repeating list. */
    UPDATE b
       SET b.MatchStatusCode      = 'MATCHED_LIST',
           b.McrListName          = lm.McrListName,
           b.McrScope             = l.Scope,
           b.McrSectionPath       = l.ParentPath,
           b.McrElementCount      = le.ElementCount,
           b.ComponentAlignedFlag =
               CASE WHEN b.GovScopeLevelCode = l.Scope
                    THEN 1 ELSE 0 END,
           b.ReviewNote           = lm.MappingNote,
           b.ModifiedDateUtc      = SYSUTCDATETIME()
    FROM reg.McrItemBridge b
    JOIN reg.McrListMap lm
      ON lm.GovItemCode = b.ItemCode
    JOIN reg.vw_McrListCatalog l
      ON l.ListName = lm.McrListName
    OUTER APPLY
    (
        SELECT COUNT(*) AS ElementCount
        FROM reg.vw_McrListElementCatalog e
        WHERE e.ListName = lm.McrListName
    ) le
    WHERE b.MatchStatusCode = 'GOV_ONLY';

    RETURN 0;
END
GO

/* ------------------------------------------------------------
   6. Coverage view. Portfolio-facing summary.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW reg.vw_McrBridgeCoverage
AS
SELECT
    MatchStatusCode,
    COUNT(*)                              AS ItemCount,
    SUM(CASE WHEN McrIsCalculated = 0 THEN 1 ELSE 0 END)
                                          AS SubmittableCount,
    SUM(CASE WHEN McrIsCalculated = 1 THEN 1 ELSE 0 END)
                                          AS CalculatedCount,
    SUM(ISNULL(McrElementCount, 0))       AS ElementCount,
    SUM(CASE WHEN ComponentAlignedFlag = 0 THEN 1 ELSE 0 END)
                                          AS ComponentMismatchCount,
    SUM(CASE WHEN CalcFlagAlignedFlag = 0 THEN 1 ELSE 0 END)
                                          AS CalcFlagMismatchCount
FROM reg.McrItemBridge
GROUP BY MatchStatusCode;
GO

/* ------------------------------------------------------------
   7. Execute and report.
   ------------------------------------------------------------ */
DECLARE @RunBatchId INT;
DECLARE @RunNotes NVARCHAR(400) =
    N'Script 030: FV7 item bridge refresh.';

EXEC audit.usp_StartLoadBatch
     @BatchName     = N'MCR FV7 item bridge refresh',
     @BatchTypeCode = 'SEED',
     @Notes         = @RunNotes,
     @LoadBatchId   = @RunBatchId OUTPUT;

BEGIN TRY
    EXEC reg.usp_RefreshMcrItemBridge
         @LoadBatchId = @RunBatchId;

    EXEC audit.usp_CompleteLoadBatch
         @LoadBatchId = @RunBatchId,
         @StatusCode  = 'SUCCESS';
END TRY
BEGIN CATCH
    EXEC audit.usp_LogError
         @LoadBatchId = @RunBatchId,
         @ContextInfo = N'030_reg_mcr_bridge.sql step 7';
    EXEC audit.usp_CompleteLoadBatch
         @LoadBatchId = @RunBatchId,
         @StatusCode  = 'FAILED';
    THROW;
END CATCH
GO

/* Result set 1: coverage scorecard */
SELECT MatchStatusCode, ItemCount, SubmittableCount,
       CalculatedCount, ElementCount,
       ComponentMismatchCount, CalcFlagMismatchCount
FROM reg.vw_McrBridgeCoverage
ORDER BY CASE MatchStatusCode
              WHEN 'MATCHED'      THEN 1
              WHEN 'MATCHED_LIST' THEN 2
              WHEN 'AMBIGUOUS'    THEN 3
              WHEN 'GOV_ONLY'     THEN 4
              WHEN 'MCR_ONLY'     THEN 5
         END;

/* Result set 2: every exception requiring steward review */
SELECT ItemCode, MatchStatusCode, GovComponentCode,
       GovSectionCode, GovItemName, McrScope, McrLabel,
       ComponentAlignedFlag, CalcFlagAlignedFlag, ReviewNote
FROM reg.McrItemBridge
WHERE MatchStatusCode <> 'MATCHED'
   OR ISNULL(ComponentAlignedFlag, 1) = 0
   OR ISNULL(CalcFlagAlignedFlag, 1) = 0
ORDER BY MatchStatusCode, ItemCode;

PRINT 'Script 030 complete.';
GO
