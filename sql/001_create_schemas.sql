/* ============================================================
   MortgageGovernance | Phase 1 | Script 001
   Creates the ten platform schemas.

   AZURE SQL DATABASE FORM (EngineEdition 5).
   Database provisioning moved to infrastructure; see README.
   Connect directly to MortgageGovernance. There is no USE.
   RECOVERY model is not settable on Azure SQL Database and
   RCSI is on by default, so 001 asserts rather than sets.
   Idempotent: safe to re-run.

   Supersedes 001_create_database_and_schemas.sql, which used
   USE master, CREATE DATABASE, ALTER DATABASE SET RECOVERY
   SIMPLE, and a named-database RCSI statement. None of those
   are valid on Azure SQL Database.
   ============================================================ */
SET NOCOUNT ON;
GO

/* ---- Assert the isolation level the platform assumes ---- */
IF EXISTS (SELECT 1 FROM sys.databases
           WHERE name = DB_NAME()
             AND is_read_committed_snapshot_on = 0)
BEGIN
    PRINT 'WARNING: RCSI is OFF. Run this once, then re-run:';
    PRINT '  ALTER DATABASE CURRENT';
    PRINT '    SET READ_COMMITTED_SNAPSHOT ON';
    PRINT '    WITH ROLLBACK IMMEDIATE;';
END
ELSE
    PRINT 'RCSI confirmed ON.';
GO

/* ---- Create the ten platform schemas ---- */
DECLARE @Schemas TABLE (SchemaName sysname NOT NULL);
INSERT INTO @Schemas (SchemaName) VALUES
 (N'src'),  -- raw source-aligned (system-code table prefix)
 (N'stg'),  -- staging contracts + source adapters
 (N'ref'),  -- controlled reference / enumerations
 (N'dw'),   -- dimensional warehouse
 (N'gov'),  -- governance metadata
 (N'dq'),   -- data quality rules, results, exceptions
 (N'audit'),-- load execution, reconciliation, evidence
 (N'pbi'),  -- certified views for Power BI (only interface)
 (N'reg'),  -- regulatory derivations (P3)
 (N'ai');   -- AI readiness (P2)

DECLARE @SchemaName sysname, @Sql nvarchar(300);

DECLARE SchemaCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT SchemaName FROM @Schemas;
OPEN SchemaCursor;
FETCH NEXT FROM SchemaCursor INTO @SchemaName;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.schemas
                   WHERE name = @SchemaName)
    BEGIN
        SET @Sql = N'CREATE SCHEMA ' + QUOTENAME(@SchemaName)
                 + N' AUTHORIZATION dbo;';
        EXEC sys.sp_executesql @Sql;
        PRINT 'Schema created: ' + @SchemaName;
    END
    FETCH NEXT FROM SchemaCursor INTO @SchemaName;
END
CLOSE SchemaCursor;
DEALLOCATE SchemaCursor;
GO

PRINT 'Script 001 complete: 10 schemas ready.';
GO
