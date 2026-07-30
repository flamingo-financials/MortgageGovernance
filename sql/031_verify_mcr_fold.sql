/* ============================================================
   MortgageGovernance | Script 031
   MCR fold verification scorecard.
   AZURE SQL DATABASE FORM. Connect directly to
   MortgageGovernance. No USE statement.
   Detects the optional HMDA (14) and MBFRF (15) layers and
   adjusts expected object counts automatically.
   Read-only. Safe to re-run.
   ============================================================ */
SET NOCOUNT ON;

DECLARE @Hmda  INT =
    CASE WHEN OBJECT_ID('mcr.HmdaMcrBridge') IS NOT NULL
         THEN 1 ELSE 0 END;
DECLARE @Mbfrf INT =
    CASE WHEN OBJECT_ID('mcr.MbfrfCatalog') IS NOT NULL
         THEN 1 ELSE 0 END;

/* Base = toolkit 01-08 plus 11.
   HMDA adds 1 table, 1 staging table, 1 view, 1 proc.
   MBFRF adds 6 tables, 1 view, 5 procs. */
DECLARE @ExpTables INT = 12 + @Hmda + (@Mbfrf * 6);
DECLARE @ExpStg    INT =  7 + @Hmda;
DECLARE @ExpViews  INT =  9 + @Hmda + @Mbfrf;
DECLARE @ExpProcs  INT = 14 + @Hmda + (@Mbfrf * 5);

SELECT * FROM (
SELECT 1 AS Seq, 'Schemas mcr/mcrstg/mcrpbi' AS Check_,
       COUNT(*) AS Actual, 3 AS Expected
FROM sys.schemas
WHERE name IN ('mcr','mcrstg','mcrpbi')
UNION ALL
SELECT 2, 'mcr tables', COUNT(*), @ExpTables
FROM sys.tables WHERE SCHEMA_NAME(schema_id) = 'mcr'
UNION ALL
SELECT 3, 'mcrstg staging tables', COUNT(*), @ExpStg
FROM sys.tables WHERE SCHEMA_NAME(schema_id) = 'mcrstg'
UNION ALL
SELECT 4, 'mcrpbi views', COUNT(*), @ExpViews
FROM sys.views WHERE SCHEMA_NAME(schema_id) = 'mcrpbi'
UNION ALL
SELECT 5, 'mcr procedures', COUNT(*), @ExpProcs
FROM sys.procedures WHERE SCHEMA_NAME(schema_id) = 'mcr'
UNION ALL
SELECT 6, 'FV7 catalog items', COUNT(*), 635
FROM mcr.FieldCatalog
UNION ALL
SELECT 7, 'FV7 submittable items', COUNT(*), 510
FROM mcr.FieldCatalog WHERE IsCalculated = 0
UNION ALL
SELECT 8, 'FV7 calculated items', COUNT(*), 125
FROM mcr.FieldCatalog WHERE IsCalculated = 1
UNION ALL
SELECT 9, 'FV7 submittable elements', COUNT(*), 1228
FROM mcr.FieldCatalogElement
UNION ALL
SELECT 10, 'FV7 repeating lists', COUNT(*), 5
FROM mcr.ListCatalog
UNION ALL
SELECT 11, 'Three-part name references', COUNT(*), 0
FROM sys.sql_modules
WHERE definition LIKE '%MCR[_]Toolkit.%'
UNION ALL
SELECT 12, 'Governed pbi views intact', COUNT(*), 34
FROM sys.views WHERE SCHEMA_NAME(schema_id) = 'pbi'
) c
CROSS APPLY (SELECT CASE WHEN c.Actual = c.Expected
                         THEN 'PASS' ELSE 'FAIL' END
             AS Result) r
ORDER BY Seq;

SELECT CASE WHEN @Hmda = 1 THEN 'deployed'
            ELSE 'not deployed' END AS HmdaLayer14,
       CASE WHEN @Mbfrf = 1 THEN 'deployed'
            ELSE 'not deployed' END AS MbfrfLayer15,
       @ExpTables AS ExpectedMcrTables,
       @ExpProcs  AS ExpectedMcrProcs;
