/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_08_filing_archive.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT (FULL SCHEMA)
   08 - Filing archive: immutable in-database record of every generated XML
   ----------------------------------------------------------------------------
   Objects:
     mcr.FilingArchive             one row per XML generation (append-only)
     mcr.ReportValuesHistory       element-level data frozen per archive
     mcr.RepeatingValuesHistory    repeating-list data frozen per archive
     mcr.ValidationResultsHistory  validation snapshot frozen per archive
     mcr.usp_ArchiveFiling         archive XML + data + validation snapshot
     mcr.usp_RunAndArchiveFiling   pipeline (07) + auto-archive, one EXEC
     mcr.usp_RecordSubmission      stamp submitted date / NMLS confirmation
     mcr.usp_VerifyFilingArchive   recompute hash, prove integrity
     mcr.usp_ExportArchivedFiling  re-emit the exact archived text
     mcr.usp_RestoreFilingData     rehydrate staging from an archive
                                   (amendment / resubmission workflow)

   Integrity model:
     XmlHash = SHA2_256 over the archived NVARCHAR text (UTF-16 bytes,
     SQL Server's internal encoding). Verification recomputes in-database
     and compares - this proves the archived text is unaltered since
     generation. Note the hash will NOT equal a SHA-256 of the UTF-8 .xml
     file on disk (different byte encoding); the archived text itself is
     the authoritative copy, and usp_ExportArchivedFiling regenerates the
     file from it at any time.

   Immutability:
     INSTEAD OF triggers block DELETE on the archive and all three history
     tables, and block UPDATE of everything except SubmittedDate /
     NmlsConfirmation / Notes on the archive row. Corrections are new
     archive rows, never edits.

   Amendment workflow (append/correct a report after submission):
     1. EXEC mcr.usp_RestoreFilingData @ArchiveId = N
        - rehydrates mcr.ReportValues / mcr.RepeatingValues with the exact
          data behind the submitted XML (survives @Reload runs, staging
          wipes, and 02 redeploys)
     2. Apply the correction / append the additional values by INSERT or
        UPDATE against the restored staging rows
     3. EXEC mcr.usp_ValidateFiling, then usp_GenerateMcrXml +
        usp_ArchiveFiling (or usp_RunAndArchiveFiling with @Reload = 0)
        - the amended filing becomes a NEW archive row; the original
          submission remains intact for comparison
     4. mcr.usp_CompareArchives shows exactly what changed between the
        two archive rows - the amendment audit trail.

   Run after 01-07. SQL Server 2017+ (HASHBYTES accepts LOB input
   from 2016).
   ============================================================================ */

/* ------------------------------------------------------------- tables */
IF OBJECT_ID('mcr.ValidationResultsHistory') IS NOT NULL
    DROP TABLE mcr.ValidationResultsHistory;
IF OBJECT_ID('mcr.ReportValuesHistory') IS NOT NULL
    DROP TABLE mcr.ReportValuesHistory;
IF OBJECT_ID('mcr.RepeatingValuesHistory') IS NOT NULL
    DROP TABLE mcr.RepeatingValuesHistory;
IF OBJECT_ID('mcr.FilingArchive') IS NOT NULL
    DROP TABLE mcr.FilingArchive;
GO

CREATE TABLE mcr.FilingArchive (
    ArchiveId          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    FilingId           INT            NOT NULL,
    ArchivedUtc        DATETIME2(0)   NOT NULL
                       CONSTRAINT DF_FA_When DEFAULT SYSUTCDATETIME(),
    ArchivedBy         SYSNAME        NOT NULL
                       CONSTRAINT DF_FA_Who DEFAULT SUSER_SNAME(),
    FormVersion        VARCHAR(5)     NOT NULL,
    [Year]             INT            NOT NULL,
    PeriodType         VARCHAR(10)    NOT NULL,
    XmlText            NVARCHAR(MAX)  NOT NULL,  -- prolog included
    XmlLength          INT            NOT NULL,
    XmlHash            BINARY(32)     NOT NULL,  -- SHA2_256, UTF-16 bytes
    ErrorCount         INT            NOT NULL,
    WarningCount       INT            NOT NULL,
    ElementValueCount  INT            NOT NULL,
    RepeatingRowCount  INT            NOT NULL,
    SubmittedDate      DATE           NULL,      -- set by usp_RecordSubmission
    NmlsConfirmation   VARCHAR(50)    NULL,
    Notes              NVARCHAR(500)  NULL,
    CONSTRAINT FK_FA_Filing
        FOREIGN KEY (FilingId) REFERENCES mcr.Filing(FilingId)
);
GO
CREATE INDEX IX_FA_Filing ON mcr.FilingArchive (FilingId, ArchivedUtc DESC);
GO

CREATE TABLE mcr.ValidationResultsHistory (
    ArchiveId   INT           NOT NULL
                REFERENCES mcr.FilingArchive(ArchiveId),
    FilingId    INT           NOT NULL,
    Severity    VARCHAR(10)   NOT NULL,
    RuleType    VARCHAR(30)   NOT NULL,
    ScopeKey    VARCHAR(10)   NULL,
    ItemCode    VARCHAR(20)   NULL,
    Detail      NVARCHAR(500) NULL
);
GO
CREATE INDEX IX_VRH_Archive ON mcr.ValidationResultsHistory (ArchiveId);
GO

CREATE TABLE mcr.ReportValuesHistory (
    ArchiveId   INT            NOT NULL
                REFERENCES mcr.FilingArchive(ArchiveId),
    FilingId    INT            NOT NULL,
    ScopeKey    VARCHAR(10)    NOT NULL,
    ElementName VARCHAR(20)    NOT NULL,
    NumValue    DECIMAL(15,2)  NULL,
    TextValue   NVARCHAR(4000) NULL,
    CONSTRAINT PK_RVH
        PRIMARY KEY (ArchiveId, FilingId, ScopeKey, ElementName)
);
GO

CREATE TABLE mcr.RepeatingValuesHistory (
    ArchiveId   INT            NOT NULL
                REFERENCES mcr.FilingArchive(ArchiveId),
    FilingId    INT            NOT NULL,
    ScopeKey    VARCHAR(10)    NOT NULL,
    ListName    VARCHAR(60)    NOT NULL,
    ItemSeq     INT            NOT NULL,
    ElementName VARCHAR(20)    NOT NULL,
    NumValue    DECIMAL(15,2)  NULL,
    TextValue   NVARCHAR(400)  NULL,
    CONSTRAINT PK_RPVH
        PRIMARY KEY (ArchiveId, FilingId, ScopeKey, ListName,
                     ItemSeq, ElementName)
);
GO

/* history tables are append-only: inserts happen only via
   usp_ArchiveFiling; nothing edits or deletes archived data */
CREATE OR ALTER TRIGGER mcr.trg_RVH_Immutable
ON mcr.ReportValuesHistory INSTEAD OF UPDATE, DELETE
AS
BEGIN
    RAISERROR('mcr.ReportValuesHistory is append-only.', 16, 1);
END;
GO
CREATE OR ALTER TRIGGER mcr.trg_RPVH_Immutable
ON mcr.RepeatingValuesHistory INSTEAD OF UPDATE, DELETE
AS
BEGIN
    RAISERROR('mcr.RepeatingValuesHistory is append-only.', 16, 1);
END;
GO
CREATE OR ALTER TRIGGER mcr.trg_VRH_Immutable
ON mcr.ValidationResultsHistory INSTEAD OF UPDATE, DELETE
AS
BEGIN
    RAISERROR('mcr.ValidationResultsHistory is append-only.', 16, 1);
END;
GO

/* ------------------------------------------- immutability trigger */
CREATE OR ALTER TRIGGER mcr.trg_FilingArchive_Immutable
ON mcr.FilingArchive
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted)   -- DELETE
    BEGIN
        RAISERROR('mcr.FilingArchive is append-only. Rows are never deleted.',
                  16, 1);
        RETURN;
    END

    IF UPDATE(XmlText) OR UPDATE(XmlHash) OR UPDATE(XmlLength)
       OR UPDATE(FilingId) OR UPDATE(ArchivedUtc) OR UPDATE(ArchivedBy)
       OR UPDATE(FormVersion) OR UPDATE([Year]) OR UPDATE(PeriodType)
       OR UPDATE(ErrorCount) OR UPDATE(WarningCount)
       OR UPDATE(ElementValueCount) OR UPDATE(RepeatingRowCount)
    BEGIN
        DECLARE @msg NVARCHAR(300) =
            N'Only SubmittedDate, NmlsConfirmation, and Notes are '
          + N'updatable on mcr.FilingArchive. Archive a new row for '
          + N'corrections.';
        RAISERROR(@msg, 16, 1);
        RETURN;
    END

    UPDATE fa
       SET fa.SubmittedDate    = i.SubmittedDate,
           fa.NmlsConfirmation = i.NmlsConfirmation,
           fa.Notes            = i.Notes
    FROM mcr.FilingArchive fa
    JOIN inserted i ON i.ArchiveId = fa.ArchiveId;
END;
GO

/* --------------------------------------------------- archive proc */
IF OBJECT_ID('mcr.usp_ArchiveFiling') IS NOT NULL
    DROP PROCEDURE mcr.usp_ArchiveFiling;
GO
CREATE PROCEDURE mcr.usp_ArchiveFiling
    @FilingId  INT,
    @Xml       NVARCHAR(MAX),           -- generator output, no prolog
    @Notes     NVARCHAR(500) = NULL,
    @ArchiveId INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Xml IS NULL OR LEN(@Xml) = 0
    BEGIN
        RAISERROR('Nothing to archive: @Xml is empty for filing %d.',
                  16, 1, @FilingId);
        RETURN;
    END

    DECLARE @FormVer VARCHAR(5), @Year INT, @Period VARCHAR(10);
    SELECT @FormVer = FormVersion, @Year = [Year], @Period = PeriodType
    FROM mcr.Filing WHERE FilingId = @FilingId;
    IF @FormVer IS NULL
    BEGIN
        RAISERROR('Filing %d not found.', 16, 1, @FilingId);
        RETURN;
    END

    /* archive exactly what gets saved to file: prolog + document */
    DECLARE @Text NVARCHAR(MAX) =
        N'<?xml version="1.0" encoding="utf-8"?>' + @Xml;

    DECLARE @Errs INT, @Warns INT, @Vals INT, @Reps INT;
    SELECT @Errs  = SUM(CASE WHEN Severity = 'ERROR'   THEN 1 ELSE 0 END),
           @Warns = SUM(CASE WHEN Severity = 'WARNING' THEN 1 ELSE 0 END)
    FROM mcr.ValidationResults WHERE FilingId = @FilingId;
    SELECT @Errs = ISNULL(@Errs, 0), @Warns = ISNULL(@Warns, 0);
    SELECT @Vals = COUNT(*) FROM mcr.ReportValues
    WHERE FilingId = @FilingId;
    SELECT @Reps = COUNT(*) FROM mcr.RepeatingValues
    WHERE FilingId = @FilingId;

    INSERT INTO mcr.FilingArchive
        (FilingId, FormVersion, [Year], PeriodType, XmlText, XmlLength,
         XmlHash, ErrorCount, WarningCount, ElementValueCount,
         RepeatingRowCount, Notes)
    VALUES
        (@FilingId, @FormVer, @Year, @Period, @Text, LEN(@Text),
         HASHBYTES('SHA2_256', @Text), @Errs, @Warns, @Vals, @Reps,
         @Notes);

    SET @ArchiveId = SCOPE_IDENTITY();

    /* freeze the validation state that accompanied this generation */
    INSERT INTO mcr.ValidationResultsHistory
        (ArchiveId, FilingId, Severity, RuleType, ScopeKey, ItemCode, Detail)
    SELECT @ArchiveId, FilingId, Severity, RuleType, ScopeKey, ItemCode,
           Detail
    FROM mcr.ValidationResults
    WHERE FilingId = @FilingId;

    /* freeze the element-level data behind this XML - the source of
       truth for any post-submission amendment or append */
    INSERT INTO mcr.ReportValuesHistory
        (ArchiveId, FilingId, ScopeKey, ElementName, NumValue, TextValue)
    SELECT @ArchiveId, FilingId, ScopeKey, ElementName, NumValue, TextValue
    FROM mcr.ReportValues
    WHERE FilingId = @FilingId;

    INSERT INTO mcr.RepeatingValuesHistory
        (ArchiveId, FilingId, ScopeKey, ListName, ItemSeq, ElementName,
         NumValue, TextValue)
    SELECT @ArchiveId, FilingId, ScopeKey, ListName, ItemSeq, ElementName,
           NumValue, TextValue
    FROM mcr.RepeatingValues
    WHERE FilingId = @FilingId;

    PRINT 'Archived filing ' + CAST(@FilingId AS VARCHAR(10))
        + ' as archive ' + CAST(@ArchiveId AS VARCHAR(10)) + ' ('
        + CAST(LEN(@Text) AS VARCHAR(12)) + ' chars, '
        + CAST(@Vals AS VARCHAR(10)) + ' element values, '
        + CAST(@Reps AS VARCHAR(10)) + ' list rows, '
        + CAST(@Errs AS VARCHAR(10)) + ' errors, '
        + CAST(@Warns AS VARCHAR(10)) + ' warnings).';
END;
GO

/* --------------------------------------- pipeline + archive wrapper */
IF OBJECT_ID('mcr.usp_RunAndArchiveFiling') IS NOT NULL
    DROP PROCEDURE mcr.usp_RunAndArchiveFiling;
GO
CREATE PROCEDURE mcr.usp_RunAndArchiveFiling
    @FilingId     INT,
    @BlockOnError BIT           = 1,
    @RunVariance  BIT           = 1,
    @Reload       BIT           = 1,
    @Notes        NVARCHAR(500) = NULL,
    @ArchiveId    INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Xml NVARCHAR(MAX);

    EXEC mcr.usp_RunFilingPipeline
         @FilingId     = @FilingId,
         @BlockOnError = @BlockOnError,
         @RunVariance  = @RunVariance,
         @Reload       = @Reload,
         @Xml          = @Xml OUTPUT;

    IF @Xml IS NULL
    BEGIN
        PRINT 'No XML produced (validation blocked or pipeline failed); '
            + 'nothing archived.';
        RETURN;
    END

    EXEC mcr.usp_ArchiveFiling
         @FilingId  = @FilingId,
         @Xml       = @Xml,
         @Notes     = @Notes,
         @ArchiveId = @ArchiveId OUTPUT;
END;
GO

/* ------------------------------------------------ record submission */
IF OBJECT_ID('mcr.usp_RecordSubmission') IS NOT NULL
    DROP PROCEDURE mcr.usp_RecordSubmission;
GO
CREATE PROCEDURE mcr.usp_RecordSubmission
    @ArchiveId        INT,
    @SubmittedDate    DATE,
    @NmlsConfirmation VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM mcr.FilingArchive
                   WHERE ArchiveId = @ArchiveId)
    BEGIN
        RAISERROR('Archive %d not found.', 16, 1, @ArchiveId);
        RETURN;
    END

    UPDATE mcr.FilingArchive
       SET SubmittedDate    = @SubmittedDate,
           NmlsConfirmation = @NmlsConfirmation
    WHERE ArchiveId = @ArchiveId;

    PRINT 'Archive ' + CAST(@ArchiveId AS VARCHAR(10))
        + ' marked submitted ' + CONVERT(VARCHAR(10), @SubmittedDate, 120)
        + ', confirmation ' + @NmlsConfirmation + '.';
END;
GO

/* ------------------------------------------------------ verification */
IF OBJECT_ID('mcr.usp_VerifyFilingArchive') IS NOT NULL
    DROP PROCEDURE mcr.usp_VerifyFilingArchive;
GO
CREATE PROCEDURE mcr.usp_VerifyFilingArchive
    @ArchiveId INT = NULL      -- NULL = verify every archived row
AS
BEGIN
    SET NOCOUNT ON;

    SELECT fa.ArchiveId, fa.FilingId, fa.[Year], fa.PeriodType,
           fa.ArchivedUtc, fa.SubmittedDate, fa.NmlsConfirmation,
           Status = CASE
               WHEN HASHBYTES('SHA2_256', fa.XmlText) = fa.XmlHash
                    AND LEN(fa.XmlText) = fa.XmlLength
               THEN 'VERIFIED'
               ELSE '*** INTEGRITY FAILURE ***'
           END
    FROM mcr.FilingArchive fa
    WHERE @ArchiveId IS NULL OR fa.ArchiveId = @ArchiveId
    ORDER BY fa.ArchiveId;
END;
GO

/* ------------------------------------------------------------ export */
IF OBJECT_ID('mcr.usp_ExportArchivedFiling') IS NOT NULL
    DROP PROCEDURE mcr.usp_ExportArchivedFiling;
GO
CREATE PROCEDURE mcr.usp_ExportArchivedFiling
    @ArchiveId INT
AS
BEGIN
    SET NOCOUNT ON;

    /* verify before export - never re-emit a corrupted archive */
    IF NOT EXISTS (
        SELECT 1 FROM mcr.FilingArchive
        WHERE ArchiveId = @ArchiveId
          AND HASHBYTES('SHA2_256', XmlText) = XmlHash)
    BEGIN
        DECLARE @msg NVARCHAR(200) =
            N'Archive %d failed integrity verification or does not '
          + N'exist. Do not export.';
        RAISERROR(@msg, 16, 1, @ArchiveId);
        RETURN;
    END

    SELECT XmlText AS McrFilingText
    FROM mcr.FilingArchive
    WHERE ArchiveId = @ArchiveId;

    PRINT 'Integrity VERIFIED. Save McrFilingText as .xml (UTF-8).';
END;
GO


/* ---------------------------------------------- restore for amendment */
IF OBJECT_ID('mcr.usp_RestoreFilingData') IS NOT NULL
    DROP PROCEDURE mcr.usp_RestoreFilingData;
GO
CREATE PROCEDURE mcr.usp_RestoreFilingData
    @ArchiveId INT
AS
BEGIN
    /* Rehydrates mcr.ReportValues / mcr.RepeatingValues for the archive's
       FilingId with the exact archived data. REPLACES current staging for
       that filing. Amend, revalidate, regenerate, and archive again -
       with @Reload = 0 so the pipeline does not re-stage from source.
       Note: restore requires the catalog (02) matching the archive's
       FormVersion; under a later-version catalog, retired element names
       fail the staging FK by design. The archived history itself is
       version-independent and always readable. */
    SET NOCOUNT ON;

    DECLARE @FilingId INT;
    SELECT @FilingId = FilingId
    FROM mcr.FilingArchive WHERE ArchiveId = @ArchiveId;
    IF @FilingId IS NULL
    BEGIN
        RAISERROR('Archive %d not found.', 16, 1, @ArchiveId);
        RETURN;
    END

    DELETE FROM mcr.ReportValues    WHERE FilingId = @FilingId;
    DELETE FROM mcr.RepeatingValues WHERE FilingId = @FilingId;

    INSERT INTO mcr.ReportValues
        (FilingId, ScopeKey, ElementName, NumValue, TextValue)
    SELECT FilingId, ScopeKey, ElementName, NumValue, TextValue
    FROM mcr.ReportValuesHistory
    WHERE ArchiveId = @ArchiveId;

    INSERT INTO mcr.RepeatingValues
        (FilingId, ScopeKey, ListName, ItemSeq, ElementName,
         NumValue, TextValue)
    SELECT FilingId, ScopeKey, ListName, ItemSeq, ElementName,
           NumValue, TextValue
    FROM mcr.RepeatingValuesHistory
    WHERE ArchiveId = @ArchiveId;

    DECLARE @nVals INT = (SELECT COUNT(*) FROM mcr.ReportValues
                          WHERE FilingId = @FilingId);
    DECLARE @nReps INT = (SELECT COUNT(*) FROM mcr.RepeatingValues
                          WHERE FilingId = @FilingId);
    PRINT 'Restored filing ' + CAST(@FilingId AS VARCHAR(10))
        + ' staging from archive ' + CAST(@ArchiveId AS VARCHAR(10))
        + ': ' + CAST(@nVals AS VARCHAR(10)) + ' element values, '
        + CAST(@nReps AS VARCHAR(10)) + ' list rows. Amend, then '
        + 'validate/generate/archive with @Reload = 0.';
END;
GO

/* -------------------------------------------------- amendment diff */
IF OBJECT_ID('mcr.usp_CompareArchives') IS NOT NULL
    DROP PROCEDURE mcr.usp_CompareArchives;
GO
CREATE PROCEDURE mcr.usp_CompareArchives
    @ArchiveIdA INT,     -- original (e.g. the submitted archive)
    @ArchiveIdB INT      -- amended
AS
BEGIN
    /* Element-level diff between two archives - the audit trail for what
       an amendment changed. Returns ADDED / REMOVED / CHANGED rows for
       both scalar elements and repeating lists. */
    SET NOCOUNT ON;

    SELECT
        Change = CASE WHEN a.ElementName IS NULL THEN 'ADDED'
                      WHEN b.ElementName IS NULL THEN 'REMOVED'
                      ELSE 'CHANGED' END,
        Kind     = 'Element',
        ScopeKey = COALESCE(a.ScopeKey, b.ScopeKey),
        ListName = CAST(NULL AS VARCHAR(60)),
        ItemSeq  = CAST(NULL AS INT),
        ElementName = COALESCE(a.ElementName, b.ElementName),
        OldNum = a.NumValue,  NewNum = b.NumValue,
        OldText = a.TextValue, NewText = b.TextValue
    FROM (SELECT * FROM mcr.ReportValuesHistory
          WHERE ArchiveId = @ArchiveIdA) a
    FULL JOIN (SELECT * FROM mcr.ReportValuesHistory
               WHERE ArchiveId = @ArchiveIdB) b
      ON b.ScopeKey = a.ScopeKey AND b.ElementName = a.ElementName
    WHERE a.ElementName IS NULL OR b.ElementName IS NULL
       OR ISNULL(a.NumValue, -999999999999) <>
          ISNULL(b.NumValue, -999999999999)
       OR ISNULL(a.TextValue, N'') <> ISNULL(b.TextValue, N'')

    UNION ALL

    SELECT
        CASE WHEN a.ElementName IS NULL THEN 'ADDED'
             WHEN b.ElementName IS NULL THEN 'REMOVED'
             ELSE 'CHANGED' END,
        'ListRow',
        COALESCE(a.ScopeKey, b.ScopeKey),
        COALESCE(a.ListName, b.ListName),
        COALESCE(a.ItemSeq,  b.ItemSeq),
        COALESCE(a.ElementName, b.ElementName),
        a.NumValue,  b.NumValue,
        a.TextValue, b.TextValue
    FROM (SELECT * FROM mcr.RepeatingValuesHistory
          WHERE ArchiveId = @ArchiveIdA) a
    FULL JOIN (SELECT * FROM mcr.RepeatingValuesHistory
               WHERE ArchiveId = @ArchiveIdB) b
      ON  b.ScopeKey = a.ScopeKey AND b.ListName = a.ListName
      AND b.ItemSeq  = a.ItemSeq  AND b.ElementName = a.ElementName
    WHERE a.ElementName IS NULL OR b.ElementName IS NULL
       OR ISNULL(a.NumValue, -999999999999) <>
          ISNULL(b.NumValue, -999999999999)
       OR ISNULL(a.TextValue, N'') <> ISNULL(b.TextValue, N'')

    ORDER BY Kind, ScopeKey, ElementName, ItemSeq;
END;
GO

PRINT '08 complete: mcr.FilingArchive, ReportValuesHistory, '
    + 'RepeatingValuesHistory, ValidationResultsHistory, usp_ArchiveFiling, '
    + 'usp_RunAndArchiveFiling, usp_RecordSubmission, usp_VerifyFilingArchive, '
    + 'usp_ExportArchivedFiling, usp_RestoreFilingData, usp_CompareArchives '
    + 'created.';
GO

/* ============================================================================
   QUARTERLY USAGE (replaces the bare pipeline call in the SOP, 6.3):

     DECLARE @ArchiveId INT;
     EXEC mcr.usp_RunAndArchiveFiling
          @FilingId  = 2026002,
          @Notes     = N'Q2 2026 production run',
          @ArchiveId = @ArchiveId OUTPUT;

     -- save the returned McrFilingText result as UTF-8 .xml, then after
     -- NMLS upload:
     EXEC mcr.usp_RecordSubmission
          @ArchiveId        = @ArchiveId,
          @SubmittedDate    = '2026-08-10',
          @NmlsConfirmation = 'NMLS-XXXXXXXX';

     -- any time, prove nothing has changed since generation:
     EXEC mcr.usp_VerifyFilingArchive;

     -- reproduce the exact submitted file years later:
     EXEC mcr.usp_ExportArchivedFiling @ArchiveId = 12;

   AMENDING AFTER SUBMISSION (append / correct a report):

     -- 1. rehydrate staging with the exact submitted data
     EXEC mcr.usp_RestoreFilingData @ArchiveId = 12;

     -- 2. apply the amendment against mcr.ReportValues /
     --    mcr.RepeatingValues (INSERT the appended elements, or UPDATE
     --    the corrected values) for the filing

     -- 3. revalidate, regenerate, archive as a NEW row; @Reload = 0 is
     --    critical or the load stage overwrites the restored data
     DECLARE @ArchiveId2 INT;
     EXEC mcr.usp_RunAndArchiveFiling
          @FilingId  = 2026002,
          @Reload    = 0,
          @Notes     = N'Amended: appended <what> per <reason>',
          @ArchiveId = @ArchiveId2 OUTPUT;

     -- 4. audit trail: exactly what changed vs the submitted version
     EXEC mcr.usp_CompareArchives
          @ArchiveIdA = 12, @ArchiveIdB = @ArchiveId2;
   ============================================================================ */
