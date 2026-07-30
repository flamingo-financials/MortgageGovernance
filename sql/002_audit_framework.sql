/* ============================================================
   MortgageGovernance | Phase 1 | Script 002
   Audit framework: load batches, step execution, error log,
   reconciliation controls and results, plus reusable
   procedures every loader will call.
   Idempotent: safe to re-run.
   ============================================================ */
USE MortgageGovernance;
GO

/* ------------------------------------------------------------
   audit.LoadBatch : one row per orchestration run
   ------------------------------------------------------------ */
IF OBJECT_ID(N'audit.LoadBatch', N'U') IS NULL
BEGIN
CREATE TABLE audit.LoadBatch
(
    LoadBatchId     INT IDENTITY(1,1) NOT NULL,
    BatchName       NVARCHAR(200)     NOT NULL,
    BatchTypeCode   VARCHAR(30)       NOT NULL,
    StartDateUtc    DATETIME2(3)      NOT NULL
        CONSTRAINT DF_LoadBatch_StartDateUtc
        DEFAULT SYSUTCDATETIME(),
    EndDateUtc      DATETIME2(3)      NULL,
    StatusCode      VARCHAR(20)       NOT NULL
        CONSTRAINT DF_LoadBatch_StatusCode DEFAULT 'RUNNING',
    InitiatedBy     NVARCHAR(128)     NOT NULL
        CONSTRAINT DF_LoadBatch_InitiatedBy
        DEFAULT SUSER_SNAME(),
    Notes           NVARCHAR(1000)    NULL,
    CONSTRAINT PK_LoadBatch PRIMARY KEY CLUSTERED (LoadBatchId),
    CONSTRAINT CK_LoadBatch_BatchTypeCode CHECK
        (BatchTypeCode IN ('FULL','INCREMENTAL','SEED','DQ',
                           'RECON','CERT','ADHOC')),
    CONSTRAINT CK_LoadBatch_StatusCode CHECK
        (StatusCode IN ('RUNNING','SUCCESS','FAILED','PARTIAL'))
);
END
GO

/* ------------------------------------------------------------
   audit.LoadExecution : one row per step (proc / object load).
   Feeds the Batch Job Success Rate metric (DRV_JOBSUCCESS).
   ------------------------------------------------------------ */
IF OBJECT_ID(N'audit.LoadExecution', N'U') IS NULL
BEGIN
CREATE TABLE audit.LoadExecution
(
    LoadExecutionId INT IDENTITY(1,1) NOT NULL,
    LoadBatchId     INT               NOT NULL,
    StepName        NVARCHAR(200)     NOT NULL,
    TargetObject    NVARCHAR(300)     NULL,
    StartDateUtc    DATETIME2(3)      NOT NULL
        CONSTRAINT DF_LoadExecution_StartDateUtc
        DEFAULT SYSUTCDATETIME(),
    EndDateUtc      DATETIME2(3)      NULL,
    StatusCode      VARCHAR(20)       NOT NULL
        CONSTRAINT DF_LoadExecution_StatusCode
        DEFAULT 'RUNNING',
    RowsRead        INT               NULL,
    RowsInserted    INT               NULL,
    RowsUpdated     INT               NULL,
    RowsDeleted     INT               NULL,
    RowsRejected    INT               NULL,
    ErrorMessage    NVARCHAR(4000)    NULL,
    CONSTRAINT PK_LoadExecution
        PRIMARY KEY CLUSTERED (LoadExecutionId),
    CONSTRAINT FK_LoadExecution_LoadBatch
        FOREIGN KEY (LoadBatchId)
        REFERENCES audit.LoadBatch (LoadBatchId),
    CONSTRAINT CK_LoadExecution_StatusCode CHECK
        (StatusCode IN ('RUNNING','SUCCESS','FAILED','SKIPPED'))
);
CREATE NONCLUSTERED INDEX IX_LoadExecution_LoadBatchId
    ON audit.LoadExecution (LoadBatchId);
END
GO

/* ------------------------------------------------------------
   audit.ErrorLog : CATCH-block error capture
   ------------------------------------------------------------ */
IF OBJECT_ID(N'audit.ErrorLog', N'U') IS NULL
BEGIN
CREATE TABLE audit.ErrorLog
(
    ErrorLogId      INT IDENTITY(1,1) NOT NULL,
    LoadBatchId     INT               NULL,
    LoadExecutionId INT               NULL,
    ErrorDateUtc    DATETIME2(3)      NOT NULL
        CONSTRAINT DF_ErrorLog_ErrorDateUtc
        DEFAULT SYSUTCDATETIME(),
    ErrorNumber     INT               NULL,
    ErrorSeverity   INT               NULL,
    ErrorState      INT               NULL,
    ErrorProcedure  NVARCHAR(200)     NULL,
    ErrorLine       INT               NULL,
    ErrorMessage    NVARCHAR(4000)    NULL,
    ContextInfo     NVARCHAR(1000)    NULL,
    CONSTRAINT PK_ErrorLog PRIMARY KEY CLUSTERED (ErrorLogId)
);
END
GO

/* ------------------------------------------------------------
   audit.ReconciliationControl : control definitions.
   OwnerPartyId FK to gov.Party is added by script 003
   (gov schema is built after the audit framework).
   ------------------------------------------------------------ */
IF OBJECT_ID(N'audit.ReconciliationControl', N'U') IS NULL
BEGIN
CREATE TABLE audit.ReconciliationControl
(
    ReconciliationControlId INT IDENTITY(1,1) NOT NULL,
    ControlCode        VARCHAR(50)    NOT NULL,
    ControlName        NVARCHAR(200)  NOT NULL,
    ControlDescription NVARCHAR(1000) NULL,
    ControlTypeCode    VARCHAR(30)    NOT NULL,
    SourceExpression   NVARCHAR(2000) NULL,
    TargetExpression   NVARCHAR(2000) NULL,
    ImplementingObject NVARCHAR(200)  NULL,
    ToleranceTypeCode  VARCHAR(20)    NOT NULL
        CONSTRAINT DF_ReconciliationControl_ToleranceTypeCode
        DEFAULT 'EXACT',
    ToleranceValue     DECIMAL(18,4)  NULL,
    BlockingFlag       BIT            NOT NULL
        CONSTRAINT DF_ReconciliationControl_BlockingFlag
        DEFAULT 1,
    OwnerPartyId       INT            NULL,
    ActiveFlag         BIT            NOT NULL
        CONSTRAINT DF_ReconciliationControl_ActiveFlag
        DEFAULT 1,
    CreatedDateUtc     DATETIME2(3)   NOT NULL
        CONSTRAINT DF_ReconciliationControl_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc    DATETIME2(3)   NULL,
    CONSTRAINT PK_ReconciliationControl
        PRIMARY KEY CLUSTERED (ReconciliationControlId),
    CONSTRAINT UQ_ReconciliationControl_ControlCode
        UNIQUE (ControlCode),
    CONSTRAINT CK_ReconciliationControl_ControlTypeCode CHECK
        (ControlTypeCode IN ('SRC_TO_DW','SNAPSHOT_CONTINUITY',
         'MCR_TIEOUT','CROSS_SYSTEM','SEMANTIC_TO_SQL')),
    CONSTRAINT CK_ReconciliationControl_ToleranceTypeCode CHECK
        (ToleranceTypeCode IN ('EXACT','ABS_AMOUNT','PCT'))
);
END
GO

/* ------------------------------------------------------------
   audit.ReconciliationResult : one row per control execution
   per as-of date. Feeds Regulatory Report Reconciliation
   Accuracy (DRV_REGRECON) and certification evidence.
   ------------------------------------------------------------ */
IF OBJECT_ID(N'audit.ReconciliationResult', N'U') IS NULL
BEGIN
CREATE TABLE audit.ReconciliationResult
(
    ReconciliationResultId  INT IDENTITY(1,1) NOT NULL,
    ReconciliationControlId INT           NOT NULL,
    LoadBatchId             INT           NULL,
    AsOfDate                DATE          NOT NULL,
    ExecutedDateUtc         DATETIME2(3)  NOT NULL
        CONSTRAINT DF_ReconciliationResult_ExecutedDateUtc
        DEFAULT SYSUTCDATETIME(),
    SourceValue             DECIMAL(18,2) NULL,
    TargetValue             DECIMAL(18,2) NULL,
    VarianceValue AS
        (ISNULL(TargetValue,0) - ISNULL(SourceValue,0))
        PERSISTED,
    VariancePct AS
        (CASE WHEN ISNULL(SourceValue,0) = 0 THEN NULL
              ELSE (ISNULL(TargetValue,0) - SourceValue)
                   / SourceValue END),
    StatusCode              VARCHAR(20)   NOT NULL,
    Details                 NVARCHAR(2000) NULL,
    CONSTRAINT PK_ReconciliationResult
        PRIMARY KEY CLUSTERED (ReconciliationResultId),
    CONSTRAINT FK_ReconciliationResult_ReconciliationControl
        FOREIGN KEY (ReconciliationControlId)
        REFERENCES audit.ReconciliationControl
                   (ReconciliationControlId),
    CONSTRAINT CK_ReconciliationResult_StatusCode CHECK
        (StatusCode IN ('PASS','FAIL','WARN'))
);
CREATE NONCLUSTERED INDEX IX_ReconciliationResult_Control_AsOf
    ON audit.ReconciliationResult
       (ReconciliationControlId, AsOfDate);
END
GO

/* ============================================================
   Reusable procedures. Loaders call these; audit is never
   optional. LoadBatchId columns elsewhere are soft references
   by design (see docs/NAMING_STANDARDS.md).
   ============================================================ */

CREATE OR ALTER PROCEDURE audit.usp_StartLoadBatch
    @BatchName     NVARCHAR(200),
    @BatchTypeCode VARCHAR(30) = 'INCREMENTAL',
    @Notes         NVARCHAR(1000) = NULL,
    @LoadBatchId   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO audit.LoadBatch (BatchName, BatchTypeCode, Notes)
    VALUES (@BatchName, @BatchTypeCode, @Notes);
    SET @LoadBatchId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE audit.usp_CompleteLoadBatch
    @LoadBatchId INT,
    @StatusCode  VARCHAR(20) = 'SUCCESS'
AS
BEGIN
    SET NOCOUNT ON;
    IF @StatusCode NOT IN ('SUCCESS','FAILED','PARTIAL')
        THROW 50001,
          'Invalid batch StatusCode. Use SUCCESS, FAILED, or PARTIAL.',
          1;
    UPDATE audit.LoadBatch
       SET EndDateUtc = SYSUTCDATETIME(),
           StatusCode = @StatusCode
     WHERE LoadBatchId = @LoadBatchId;
    IF @@ROWCOUNT = 0
        THROW 50002, 'LoadBatchId not found.', 1;
END
GO

CREATE OR ALTER PROCEDURE audit.usp_StartLoadExecution
    @LoadBatchId     INT,
    @StepName        NVARCHAR(200),
    @TargetObject    NVARCHAR(300) = NULL,
    @LoadExecutionId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO audit.LoadExecution
        (LoadBatchId, StepName, TargetObject)
    VALUES (@LoadBatchId, @StepName, @TargetObject);
    SET @LoadExecutionId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE audit.usp_CompleteLoadExecution
    @LoadExecutionId INT,
    @StatusCode      VARCHAR(20) = 'SUCCESS',
    @RowsRead        INT = NULL,
    @RowsInserted    INT = NULL,
    @RowsUpdated     INT = NULL,
    @RowsDeleted     INT = NULL,
    @RowsRejected    INT = NULL,
    @ErrorMessage    NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @StatusCode NOT IN ('SUCCESS','FAILED','SKIPPED')
        THROW 50003,
          'Invalid execution StatusCode. Use SUCCESS, FAILED, or SKIPPED.',
          1;
    UPDATE audit.LoadExecution
       SET EndDateUtc   = SYSUTCDATETIME(),
           StatusCode   = @StatusCode,
           RowsRead     = @RowsRead,
           RowsInserted = @RowsInserted,
           RowsUpdated  = @RowsUpdated,
           RowsDeleted  = @RowsDeleted,
           RowsRejected = @RowsRejected,
           ErrorMessage = @ErrorMessage
     WHERE LoadExecutionId = @LoadExecutionId;
    IF @@ROWCOUNT = 0
        THROW 50004, 'LoadExecutionId not found.', 1;
END
GO

/* Call inside CATCH blocks only. */
CREATE OR ALTER PROCEDURE audit.usp_LogError
    @LoadBatchId     INT = NULL,
    @LoadExecutionId INT = NULL,
    @ContextInfo     NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO audit.ErrorLog
        (LoadBatchId, LoadExecutionId, ErrorNumber,
         ErrorSeverity, ErrorState, ErrorProcedure,
         ErrorLine, ErrorMessage, ContextInfo)
    VALUES
        (@LoadBatchId, @LoadExecutionId, ERROR_NUMBER(),
         ERROR_SEVERITY(), ERROR_STATE(), ERROR_PROCEDURE(),
         ERROR_LINE(), ERROR_MESSAGE(), @ContextInfo);
END
GO

PRINT 'Script 002 complete: audit framework ready (5 tables, 5 procedures).';
GO
