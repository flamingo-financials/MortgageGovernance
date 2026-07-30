/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_07_orchestration_procs.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT (FULL SCHEMA)
   07 - Orchestration stored procedures
   ----------------------------------------------------------------------------
   Wraps the pipeline in callable procedures so quarterly operation is
   EXEC statements, not script-running. DDL (01/02) stays as deployment
   scripts by design - schema changes belong in controlled deployments,
   not procedures.

     mcr.usp_CreateFiling          register a filing (validated insert)
     mcr.usp_RunFilingPipeline     load -> validate -> HMDA recon (3a,
                                   if 14 deployed) -> MBFRF checks (3b,
                                   if 15 deployed) -> variance ->
                                   generate; one call, TRY/CATCH,
                                   gated on ERRORs
     mcr.usp_StageFullCoverageDemo stage every catalog element (10 as a proc)

   Run after 01-06. 09/10 are thin EXEC wrappers around these.
   ============================================================================ */

/* ---------------------------------------------------------------- create */
IF OBJECT_ID('mcr.usp_CreateFiling') IS NOT NULL DROP PROCEDURE mcr.usp_CreateFiling;
GO
CREATE PROCEDURE mcr.usp_CreateFiling
    @FilingId         INT,
    @CompanyNmlsId    BIGINT,
    @CompanyName      VARCHAR(150),
    @Year             INT,
    @PeriodType       VARCHAR(10),      -- MCRQ1..MCRQ4, MCRANNUAL
    @PeriodStart      DATE,
    @PeriodEnd        DATE,
    @PrimaryStateCode CHAR(2),
    @PriorFilingId    INT          = NULL,
    @FilerType        CHAR(1)      = 'E',
    @FormVersion      VARCHAR(5)   = 'v7'
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM mcr.Filing WHERE FilingId = @FilingId)
    BEGIN
        RAISERROR('Filing %d already exists.', 16, 1, @FilingId);
        RETURN;
    END
    IF @PriorFilingId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM mcr.Filing WHERE FilingId = @PriorFilingId)
    BEGIN
        RAISERROR('PriorFilingId %d does not exist.', 16, 1, @PriorFilingId);
        RETURN;
    END
    IF @PeriodEnd <= @PeriodStart
    BEGIN
        RAISERROR('PeriodEnd must be after PeriodStart.', 16, 1);
        RETURN;
    END

    INSERT INTO mcr.Filing
    (FilingId, CompanyNmlsId, CompanyName, FilerType, FormVersion, [Year],
     PeriodType, PeriodStart, PeriodEnd, PrimaryStateCode, PriorFilingId)
    VALUES
    (@FilingId, @CompanyNmlsId, @CompanyName, @FilerType, @FormVersion, @Year,
     @PeriodType, @PeriodStart, @PeriodEnd, @PrimaryStateCode, @PriorFilingId);

    PRINT 'Filing ' + CAST(@FilingId AS VARCHAR(10)) + ' created ('
        + @PeriodType + ' ' + CAST(@Year AS VARCHAR(4)) + ', ' + @FormVersion + ').';
END;
GO

/* -------------------------------------------------------------- pipeline */
IF OBJECT_ID('mcr.usp_RunFilingPipeline') IS NOT NULL DROP PROCEDURE mcr.usp_RunFilingPipeline;
GO
CREATE PROCEDURE mcr.usp_RunFilingPipeline
    @FilingId      INT,
    @BlockOnError  BIT           = 1,
    @RunVariance   BIT           = 1,
    @Reload        BIT           = 1,      -- 0 = keep existing staged values (e.g. manual FC entries)
    @Xml           NVARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Xml = NULL;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM mcr.Filing WHERE FilingId = @FilingId)
        BEGIN
            RAISERROR('Filing %d not found. Call mcr.usp_CreateFiling first.', 16, 1, @FilingId);
            RETURN;
        END

        /* 1. stage prior filing if variance needs a baseline */
        DECLARE @PriorId INT;
        SELECT @PriorId = PriorFilingId FROM mcr.Filing WHERE FilingId = @FilingId;
        IF @PriorId IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM mcr.ReportValues WHERE FilingId = @PriorId)
        BEGIN
            PRINT '=== Stage 1: staging prior filing ' + CAST(@PriorId AS VARCHAR(10)) + ' ===';
            EXEC mcr.usp_LoadReportValues @FilingId = @PriorId;
        END

        /* 2. load */
        IF @Reload = 1
        BEGIN
            PRINT '=== Stage 2: load ===';
            EXEC mcr.usp_LoadReportValues @FilingId = @FilingId;
        END
        ELSE
            PRINT '=== Stage 2: load skipped (@Reload = 0; existing staging kept) ===';

        /* 3. validate (proc returns the results grid) */
        PRINT '=== Stage 3: validate ===';
        EXEC mcr.usp_ValidateFiling @FilingId = @FilingId;

        /* 3a. HMDA reconciliation (rule 12). Runs INSIDE the pipeline,
           after validate (which wipes the filing's validation rows) and
           before usp_ArchiveFiling snapshots mcr.ValidationResults - so
           rule 12 findings are part of the immutable archive record.
           No-op unless 14_hmda_recon.sql is deployed; the proc itself
           skips quietly if no LAR rows are staged for the filing. */
        IF OBJECT_ID('mcr.usp_ReconcileHmda') IS NOT NULL
        BEGIN
            PRINT '=== Stage 3a: HMDA reconciliation (rule 12) ===';
            EXEC mcr.usp_ReconcileHmda @FilingId = @FilingId;
        END

        /* 3b. MBFRF checks + MCR reconciliation (rules 13/14). Same
           rationale as 3a: findings must exist before the archive
           snapshot. No-op unless 15_mbfrf_layer.sql is deployed; the
           proc skips quietly if no MBFRF values are staged. Findings
           are WARNING severity so they never block MCR generation -
           their hard gate is the MBFRF keying package and MBFRF
           archive procs. */
        IF OBJECT_ID('mcr.usp_ValidateMbfrf') IS NOT NULL
        BEGIN
            PRINT '=== Stage 3b: MBFRF checks (rules 13/14) ===';
            EXEC mcr.usp_ValidateMbfrf @FilingId = @FilingId;
        END

        DECLARE @Errs INT;
        SELECT @Errs = COUNT(*) FROM mcr.ValidationResults
        WHERE FilingId = @FilingId AND Severity = 'ERROR';

        /* 4. variance */
        IF @RunVariance = 1
        BEGIN
            PRINT '=== Stage 4: variance ===';
            EXEC mcr.usp_QaVariance @FilingId = @FilingId;
        END

        /* 5. generate (gated) */
        IF @Errs > 0 AND @BlockOnError = 1
        BEGIN
            PRINT '=== Stage 5: generation BLOCKED - ' + CAST(@Errs AS VARCHAR(10))
                + ' validation ERROR(s). Fix and rerun. ===';
            RETURN;
        END
        PRINT '=== Stage 5: generate ===';
        EXEC mcr.usp_GenerateMcrXml @FilingId = @FilingId,
                                    @BlockOnError = @BlockOnError,
                                    @Xml = @Xml OUTPUT;

        IF @Xml IS NOT NULL
        BEGIN
            SELECT CAST(@Xml AS XML) AS McrFilingXml;
            SELECT N'<?xml version="1.0" encoding="utf-8"?>' + @Xml AS McrFilingText;
            DECLARE @len INT = LEN(@Xml);
            PRINT '=== Done: ' + CAST(@len AS VARCHAR(12)) + ' characters of XML. '
                + 'Save McrFilingText as .xml (UTF-8) and schema-validate before upload. ===';
        END
    END TRY
    BEGIN CATCH
        DECLARE @msg NVARCHAR(2048) = ERROR_MESSAGE(), @sev INT = ERROR_SEVERITY();
        RAISERROR('Pipeline failed for filing %d: %s', @sev, 1, @FilingId, @msg);
    END CATCH
END;
GO

/* -------------------------------------------------- full-coverage demo */
IF OBJECT_ID('mcr.usp_StageFullCoverageDemo') IS NOT NULL DROP PROCEDURE mcr.usp_StageFullCoverageDemo;
GO
CREATE PROCEDURE mcr.usp_StageFullCoverageDemo
    @FilingId  INT        = 9999,
    @StateCode VARCHAR(2) = 'OK'
AS
BEGIN
    /* Stages a demo value into EVERY submittable element and one item per
       repeating list, straight from the catalog, then generates with the
       error gate off (uniform demo values fail the reconciles by design).
       This is a schema-coverage proof and element-name reference, not a
       filing path. */
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM mcr.Filing WHERE FilingId = @FilingId)
        INSERT INTO mcr.Filing
        (FilingId, CompanyNmlsId, CompanyName, FilerType, FormVersion, [Year],
         PeriodType, PeriodStart, PeriodEnd, PrimaryStateCode, PriorFilingId)
        SELECT @FilingId, 1820999, 'Fictional Mortgage Co - COVERAGE DEMO', 'E',
               (SELECT TOP 1 FormVersion FROM mcr.Filing WHERE FilingId <> @FilingId
                ORDER BY FilingId DESC),   -- inherit current version; falls back below
               2026, 'MCRQ1', '2026-01-01', '2026-03-31', @StateCode, NULL;
    UPDATE mcr.Filing SET FormVersion = ISNULL(FormVersion, 'v7') WHERE FilingId = @FilingId;

    DELETE FROM mcr.ReportValues    WHERE FilingId = @FilingId;
    DELETE FROM mcr.RepeatingValues WHERE FilingId = @FilingId;

    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, NumValue, TextValue)
    SELECT @FilingId,
        CASE fc.Scope WHEN 'COMPANY' THEN 'COMPANY' WHEN 'FC' THEN 'FC' ELSE @StateCode END,
        e.ElementName,
        CASE e.DataType WHEN 'Hundredth' THEN 12.34 WHEN 'Count' THEN 5
                        WHEN 'Number' THEN 1234567
                        WHEN 'ShortText' THEN NULL WHEN 'ExplanatoryText' THEN NULL
                        ELSE 100000 END,
        CASE WHEN e.DataType IN ('ShortText','ExplanatoryText') THEN N'Demo text' END
    FROM mcr.FieldCatalogElement e
    JOIN mcr.FieldCatalog fc ON fc.ItemCode = e.ItemCode
    WHERE fc.IsCalculated = 0;

    INSERT INTO mcr.RepeatingValues
        (FilingId, ScopeKey, ListName, ItemSeq, ElementName, NumValue, TextValue)
    SELECT @FilingId,
        CASE lc.Scope WHEN 'COMPANY' THEN 'COMPANY' ELSE @StateCode END,
        lec.ListName, 1, lec.ElementName,
        CASE lec.DataType WHEN 'Hundredth' THEN 12.34 WHEN 'Count' THEN 5
                          WHEN 'Number' THEN 1234567 WHEN 'ShortText' THEN NULL
                          ELSE 100000 END,
        CASE WHEN lec.DataType = 'ShortText' THEN N'Demo text' END
    FROM mcr.ListElementCatalog lec
    JOIN mcr.ListCatalog lc ON lc.ListName = lec.ListName;

    DECLARE @nEls INT, @nLst INT;
    SELECT @nEls = COUNT(*) FROM mcr.ReportValues    WHERE FilingId = @FilingId;
    SELECT @nLst = COUNT(*) FROM mcr.RepeatingValues WHERE FilingId = @FilingId;
    PRINT 'Coverage demo staged: ' + CAST(@nEls AS VARCHAR(10)) + ' elements, '
        + CAST(@nLst AS VARCHAR(10)) + ' list elements (catalog-driven).';

    DECLARE @Xml NVARCHAR(MAX);
    EXEC mcr.usp_GenerateMcrXml @FilingId = @FilingId, @BlockOnError = 0, @Xml = @Xml OUTPUT;
    SELECT CAST(@Xml AS XML) AS FullCoverageXml;
    SELECT N'<?xml version="1.0" encoding="utf-8"?>' + @Xml AS FullCoverageText;
    PRINT 'Save FullCoverageText as .xml and schema-validate against the current XSD.';
END;
GO

PRINT '07 complete: usp_CreateFiling, usp_RunFilingPipeline, usp_StageFullCoverageDemo created.';
GO
