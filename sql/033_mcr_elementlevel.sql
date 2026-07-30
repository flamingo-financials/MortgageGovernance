/* ============================================================
   MortgageGovernance | Phase 2 | Script 033
   MCR element-level lineage spine.
   Establishes the column tier of the lineage graph and
   connects it to FV7 submission elements:
     SOURCE_SYSTEM -> SOURCE_FIELD -> WAREHOUSE_COLUMN
                   -> REGULATORY_ELEMENT -> REGULATORY_ITEM
   Scoped to the 513 lineage-eligible items from
   reg.vw_McrBridgeReview. Reports unmapped coverage rather
   than manufacturing edges.
   Azure SQL Database form. Idempotent.
   ============================================================ */
SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   1. Extend the node type domain.
   ------------------------------------------------------------ */
IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_LineageNode_NodeTypeCode')
    ALTER TABLE gov.LineageNode
        DROP CONSTRAINT CK_LineageNode_NodeTypeCode;
GO

ALTER TABLE gov.LineageNode WITH CHECK
    ADD CONSTRAINT CK_LineageNode_NodeTypeCode CHECK
        (NodeTypeCode IN ('SOURCE_SYSTEM','SOURCE_OBJECT',
         'SOURCE_FIELD','STAGING_OBJECT','TRANSFORMATION',
         'WAREHOUSE_OBJECT','WAREHOUSE_COLUMN','PBI_VIEW',
         'PBI_VIEW_COLUMN','SEMANTIC_TABLE','SEMANTIC_COLUMN',
         'DAX_MEASURE','METRIC','REPORT_PAGE','REPORT_VISUAL',
         'REGULATORY_ITEM','REGULATORY_ELEMENT'));
GO

/* ------------------------------------------------------------
   2. Resolved element lineage table.
   ------------------------------------------------------------ */
IF OBJECT_ID('reg.McrElementLineage') IS NULL
BEGIN
    CREATE TABLE reg.McrElementLineage
    (
        McrElementLineageId INT IDENTITY(1,1) NOT NULL,
        CatalogCode     VARCHAR(10)   NOT NULL,
        ParentKey       VARCHAR(60)   NOT NULL,
        ElementName     VARCHAR(60)   NOT NULL,
        ElementNodeName NVARCHAR(300) NOT NULL,
        ItemCode        VARCHAR(30)   NOT NULL,
        DataType        VARCHAR(30)   NULL,
        ElemOrder       INT           NULL,
        LineageScopeCode VARCHAR(20)  NOT NULL,
        DataElementId   INT           NULL,
        DataElementName NVARCHAR(200) NULL,
        CriticalFlag    BIT           NULL,
        DwSchemaName    VARCHAR(50)   NULL,
        DwObjectName    NVARCHAR(200) NULL,
        DwColumnName    NVARCHAR(200) NULL,
        SrcSchemaName   VARCHAR(50)   NULL,
        SrcObjectName   NVARCHAR(200) NULL,
        SrcColumnName   NVARCHAR(200) NULL,
        SourceSystemId  INT           NULL,
        SourceSystemName NVARCHAR(200) NULL,
        CoverageCode    VARCHAR(20)   NOT NULL,
        LoadBatchId     INT NULL,
        CreatedDateUtc  DATETIME2(3) NOT NULL
            CONSTRAINT DF_McrElementLineage_CreatedDateUtc
            DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_McrElementLineage
            PRIMARY KEY CLUSTERED (McrElementLineageId),
        CONSTRAINT UQ_McrElementLineage_Node_Element
            UNIQUE (ElementNodeName, DataElementId),
        CONSTRAINT CK_McrElementLineage_CoverageCode CHECK
            (CoverageCode IN
             ('FULL','DW_ONLY','ELEMENT_ONLY','UNMAPPED'))
    );
    CREATE NONCLUSTERED INDEX IX_McrElementLineage_ItemCode
        ON reg.McrElementLineage (ItemCode);
END;
GO

DECLARE @LoadBatchId INT,
        @Rows INT,
        @Detail NVARCHAR(2000),
        @Context NVARCHAR(1000),
        @ByObj NVARCHAR(200),
        @FromType VARCHAR(30),
        @FromName NVARCHAR(300),
        @ToType   VARCHAR(30),
        @ToName   NVARCHAR(300),
        @EdgeType VARCHAR(30),
        @MapType  VARCHAR(20),
        @Logic    NVARCHAR(2000);

SET @ByObj = N'033_mcr_element_lineage.sql';

EXEC audit.usp_StartLoadBatch
    @BatchName = N'MCR element-level lineage spine',
    @BatchTypeCode = 'ADHOC',
    @Notes = N'Establishes the column tier of the lineage graph and connects it to FV7 submission elements.',
    @LoadBatchId = @LoadBatchId OUTPUT;

BEGIN TRY

/* ------------------------------------------------------------
   3. Resolve elements to gov elements and physical columns.
      Catalog-qualified node names defuse the ElementName
      collision (S520_1 exists under both catalogs).
      Only lineage-eligible items participate.
   ------------------------------------------------------------ */
DELETE FROM reg.McrElementLineage;

;WITH Elems AS
(
    SELECT 'FC' AS CatalogCode,
           e.ItemCode  AS ParentKey,
           e.ElementName,
           e.ItemCode,
           e.DataType,
           e.ElemOrder
    FROM reg.vw_McrFieldCatalogElement e
    UNION ALL
    SELECT 'LIST',
           le.ListName,
           le.ElementName,
           lm.GovItemCode,
           le.DataType,
           le.ElemOrder
    FROM reg.vw_McrListElementCatalog le
    JOIN reg.McrListMap lm
      ON lm.McrListName = le.ListName
),
Scoped AS
(
    SELECT x.*, r.LineageScopeCode
    FROM Elems x
    JOIN reg.vw_McrBridgeReview r
      ON r.ItemCode = x.ItemCode
    WHERE r.LineageEligibleFlag = 1
)
INSERT INTO reg.McrElementLineage
    (CatalogCode, ParentKey, ElementName, ElementNodeName,
     ItemCode, DataType, ElemOrder, LineageScopeCode,
     DataElementId, DataElementName, CriticalFlag,
     DwSchemaName, DwObjectName, DwColumnName,
     SrcSchemaName, SrcObjectName, SrcColumnName,
     SourceSystemId, SourceSystemName, CoverageCode,
     LoadBatchId)
SELECT
    s.CatalogCode,
    s.ParentKey,
    s.ElementName,
    s.CatalogCode + ':' + s.ParentKey + '.' + s.ElementName,
    s.ItemCode,
    s.DataType,
    s.ElemOrder,
    s.LineageScopeCode,
    de.DataElementId,
    de.DataElementName,
    CASE WHEN cde.DataElementId IS NULL THEN 0 ELSE 1 END,
    bdw.SchemaName, bdw.ObjectName, bdw.ColumnName,
    bsrc.SchemaName, bsrc.ObjectName, bsrc.ColumnName,
    ss.SourceSystemId, ss.SourceSystemName,
    CASE
        WHEN de.DataElementId IS NULL THEN 'UNMAPPED'
        WHEN bsrc.ColumnName IS NOT NULL
         AND bdw.ColumnName IS NOT NULL THEN 'FULL'
        WHEN bdw.ColumnName IS NOT NULL THEN 'DW_ONLY'
        ELSE 'ELEMENT_ONLY'
    END,
    @LoadBatchId
FROM Scoped s
JOIN gov.RegulatoryReportItem ri
  ON ri.ItemCode = s.ItemCode
LEFT JOIN gov.RegulatoryMapping rm
  ON rm.RegulatoryReportItemId = ri.RegulatoryReportItemId
 AND rm.MappedEntityTypeCode = 'DATA_ELEMENT'
 AND rm.DataElementId IS NOT NULL
LEFT JOIN gov.DataElement de
  ON de.DataElementId = rm.DataElementId
LEFT JOIN gov.CriticalDataElement cde
  ON cde.DataElementId = de.DataElementId
OUTER APPLY
(
    SELECT TOP (1) b.SchemaName, b.ObjectName, b.ColumnName
    FROM gov.DataElementBinding b
    WHERE b.DataElementId = de.DataElementId
      AND b.LayerCode = 'DW'
    ORDER BY b.DataElementBindingId
) bdw
OUTER APPLY
(
    SELECT TOP (1) b.SchemaName, b.ObjectName, b.ColumnName,
           b.SourceSystemId
    FROM gov.DataElementBinding b
    WHERE b.DataElementId = de.DataElementId
      AND b.LayerCode = 'SRC'
    ORDER BY b.DataElementBindingId
) bsrc
LEFT JOIN gov.SourceSystem ss
  ON ss.SourceSystemId = bsrc.SourceSystemId;
SET @Rows = @@ROWCOUNT;

/* ------------------------------------------------------------
   4. Stage every edge set-based. No concatenation occurs
      inside the cursor, so no EXEC argument is an expression.
   ------------------------------------------------------------ */
IF OBJECT_ID('tempdb..#Edge') IS NOT NULL DROP TABLE #Edge;
CREATE TABLE #Edge
(
    EdgeSeq   INT IDENTITY(1,1) NOT NULL,
    FromType  VARCHAR(30)   NOT NULL,
    FromName  NVARCHAR(300) NOT NULL,
    ToType    VARCHAR(30)   NOT NULL,
    ToName    NVARCHAR(300) NOT NULL,
    EdgeType  VARCHAR(30)   NOT NULL,
    MapType   VARCHAR(20)   NULL,
    Logic     NVARCHAR(2000) NULL
);

/* source system -> source field */
INSERT INTO #Edge
    (FromType, FromName, ToType, ToName, EdgeType, MapType)
SELECT DISTINCT
    'SOURCE_SYSTEM', l.SourceSystemName,
    'SOURCE_FIELD',
    l.SrcSchemaName + '.' + l.SrcObjectName + '.'
        + l.SrcColumnName,
    'FEEDS_INTO', 'DIRECT'
FROM reg.McrElementLineage l
WHERE l.CoverageCode = 'FULL'
  AND l.SourceSystemName IS NOT NULL;

/* source field -> warehouse column */
INSERT INTO #Edge
    (FromType, FromName, ToType, ToName, EdgeType, MapType)
SELECT DISTINCT
    'SOURCE_FIELD',
    l.SrcSchemaName + '.' + l.SrcObjectName + '.'
        + l.SrcColumnName,
    'WAREHOUSE_COLUMN',
    l.DwSchemaName + '.' + l.DwObjectName + '.'
        + l.DwColumnName,
    'FEEDS_INTO', 'DIRECT'
FROM reg.McrElementLineage l
WHERE l.CoverageCode = 'FULL';

/* warehouse column -> regulatory element */
INSERT INTO #Edge
    (FromType, FromName, ToType, ToName, EdgeType, MapType,
     Logic)
SELECT DISTINCT
    'WAREHOUSE_COLUMN',
    l.DwSchemaName + '.' + l.DwObjectName + '.'
        + l.DwColumnName,
    'REGULATORY_ELEMENT', l.ElementNodeName,
    'REPORTED_TO', 'DIRECT',
    N'FV7 element ' + l.ElementName + N' of item '
        + l.ItemCode + N'; governed element '
        + ISNULL(l.DataElementName, N'(unmapped)')
FROM reg.McrElementLineage l
WHERE l.CoverageCode IN ('FULL','DW_ONLY');

/* regulatory element -> regulatory item */
INSERT INTO #Edge
    (FromType, FromName, ToType, ToName, EdgeType, MapType)
SELECT DISTINCT
    'REGULATORY_ELEMENT', l.ElementNodeName,
    'REGULATORY_ITEM',
    N'MCR FV7 ' + l.ItemCode,
    'FEEDS_INTO', 'DIRECT'
FROM reg.McrElementLineage l
WHERE l.CoverageCode IN ('FULL','DW_ONLY');

/* ------------------------------------------------------------
   5. Register edges. Declarations hoisted above the loop.
   ------------------------------------------------------------ */
DECLARE EdgeCur CURSOR LOCAL FAST_FORWARD FOR
    SELECT FromType, FromName, ToType, ToName,
           EdgeType, MapType, Logic
    FROM #Edge ORDER BY EdgeSeq;

OPEN EdgeCur;
FETCH NEXT FROM EdgeCur INTO
    @FromType, @FromName, @ToType, @ToName,
    @EdgeType, @MapType, @Logic;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC gov.usp_RegisterLineageEdge
        @FromNodeTypeCode = @FromType,
        @FromNodeName = @FromName,
        @ToNodeTypeCode = @ToType,
        @ToNodeName = @ToName,
        @EdgeTypeCode = @EdgeType,
        @MappingTypeCode = @MapType,
        @TransformationLogic = @Logic,
        @CreatedByObject = @ByObj,
        @LoadBatchId = @LoadBatchId;

    FETCH NEXT FROM EdgeCur INTO
        @FromType, @FromName, @ToType, @ToName,
        @EdgeType, @MapType, @Logic;
END;

CLOSE EdgeCur;
DEALLOCATE EdgeCur;

SET @Detail = N'Element lineage spine built. '
    + CAST(@Rows AS NVARCHAR(10))
    + N' element rows resolved across the lineage-eligible '
    + N'FV7 items. Node type REGULATORY_ELEMENT added to '
    + N'gov.LineageNode. Column tier of the lineage graph '
    + N'established.';

INSERT INTO gov.ChangeLog
    (EntityTypeCode, EntityReference, ChangeTypeCode,
     ChangeDescription, LoadBatchId)
VALUES
    ('LINEAGE_GRAPH', N'gov.LineageNode', 'VERSION',
     @Detail, @LoadBatchId);

EXEC audit.usp_CompleteLoadBatch
    @LoadBatchId = @LoadBatchId,
    @StatusCode = 'SUCCESS';

END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','EdgeCur') >= 0
    BEGIN
        CLOSE EdgeCur;
        DEALLOCATE EdgeCur;
    END;
    SET @Context = N'Script 033 MCR element lineage spine';
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
   6. Reviewer surface.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW reg.vw_McrElementLineage
AS
SELECT
    l.ItemCode,
    l.CatalogCode,
    l.ParentKey,
    l.ElementName,
    l.ElementNodeName,
    l.DataType,
    l.LineageScopeCode,
    l.CoverageCode,
    l.DataElementName,
    l.CriticalFlag,
    l.SourceSystemName,
    l.SrcSchemaName + '.' + l.SrcObjectName + '.'
        + l.SrcColumnName AS SourceColumn,
    l.DwSchemaName + '.' + l.DwObjectName + '.'
        + l.DwColumnName  AS WarehouseColumn,
    ri.ItemName,
    ri.SubsectionName
FROM reg.McrElementLineage l
JOIN gov.RegulatoryReportItem ri
  ON ri.ItemCode = l.ItemCode;
GO

/* ------------------------------------------------------------
   Verification
   ------------------------------------------------------------ */
SELECT CoverageCode, COUNT(*) AS Elements,
       COUNT(DISTINCT ItemCode) AS Items
FROM reg.McrElementLineage
GROUP BY CoverageCode
ORDER BY CoverageCode;

SELECT NodeTypeCode, COUNT(*) AS Nodes
FROM gov.LineageNode
GROUP BY NodeTypeCode
ORDER BY NodeTypeCode;

SELECT EdgeTypeCode, COUNT(*) AS Edges
FROM gov.LineageEdge
GROUP BY EdgeTypeCode
ORDER BY EdgeTypeCode;

SELECT 'Traceable to source system' AS Check_,
       COUNT(*) AS Elements
FROM reg.McrElementLineage
WHERE CoverageCode = 'FULL';
GO