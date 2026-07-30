/* ============================================================
   MortgageGovernance | Integration Phase 2 | Script 042
   MCR findings as first-class DQ rules, routed into the
   shared exception register.

   DESIGN
   DQR21 to DQR26 are real dq.Rule rows with executable
   RuleSql following the /*POP*/ /*DETECT*/ contract from
   020, so dq.usp_ExecuteRules runs them alongside DQR01 to
   DQR20 with no engine change.

   NON-BLOCKING BY DESIGN
   dw.usp_RunPipeline runs the DQ engine then certifies
   PBI_SVC_GOV. A blocking MCR rule would drag the servicing
   report to NOT_CERTIFIED on filing findings that have
   nothing to do with it. MCR findings block the filing via
   reg.usp_CertifyMcrFiling, which reads mcr validation
   errors directly and is unaffected by BlockingFlag here.

   GOVERNED FILINGS ONLY
   Every rule scopes to filings present in
   reg.McrInternalValue. That excludes the CMG demo filings
   and the 9999 coverage fixture without hardcoding ids: a
   filing the governance layer has not recomputed is not a
   filing it will raise exceptions against.

   DQR26 CATCH-ALL
   Any finding whose RuleType is not mapped is caught by
   DQR26 rather than silently dropped. An unrouted finding
   is worse than a failing rule.

   KNOWN COUPLING
   Script 020 opens with DELETE FROM dq.[Rule] and DELETE
   FROM dq.DataException. Re-running 020 destroys DQR21 to
   DQR26 and every routed exception. Recovery is re-running
   this script; nothing here is hand-maintained.

   Azure SQL Database. No USE. Idempotent.
   ============================================================ */
SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   1. Crosswalk: mcr RuleType to DQ rule.
   ------------------------------------------------------------ */
IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_McrStagingCodeMap_MapTypeCode'
             AND parent_object_id =
                 OBJECT_ID('ref.McrStagingCodeMap')
             AND definition NOT LIKE '%MCR_FINDING_RULE%')
BEGIN
    ALTER TABLE ref.McrStagingCodeMap
        DROP CONSTRAINT CK_McrStagingCodeMap_MapTypeCode;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name =
                     'CK_McrStagingCodeMap_MapTypeCode'
                 AND parent_object_id =
                     OBJECT_ID('ref.McrStagingCodeMap'))
BEGIN
    ALTER TABLE ref.McrStagingCodeMap
        ADD CONSTRAINT CK_McrStagingCodeMap_MapTypeCode
        CHECK (MapTypeCode IN ('SERVICING_TYPE','INVESTOR',
               'DELINQ_BUCKET','FC_INVESTOR_ITEM',
               'OWNERSHIP_ITEM','DELINQ_ITEM',
               'MCR_FINDING_RULE'));
END;
GO

INSERT INTO ref.McrStagingCodeMap
    (MapTypeCode, SourceCode, TargetCode, MappingNote)
SELECT v.MapType, v.Src, v.Tgt, v.Note
FROM (VALUES
 ('MCR_FINDING_RULE','COMPLETENESS','DQR21',
  N'Required FV7 item absent for a filed scope.'),
 ('MCR_FINDING_RULE','DATATYPE','DQR22',
  N'Element violates its XSD type, sign or magnitude.'),
 ('MCR_FINDING_RULE','CROSSFOOT','DQR23',
  N'Filed subtotals do not sum to their stated total.'),
 ('MCR_FINDING_RULE','RECONCILE','DQR24',
  N'Filed grids disagree with each other.'),
 ('MCR_FINDING_RULE','HMDA_RECON','DQR25',
  N'MCR closed loan data disagrees with the HMDA LAR.')
) v(MapType, Src, Tgt, Note)
WHERE NOT EXISTS
      (SELECT 1 FROM ref.McrStagingCodeMap m
       WHERE m.MapTypeCode = v.MapType
         AND m.SourceCode = v.Src);
GO

/* ------------------------------------------------------------
   2. Seed DQR21 to DQR26. Guarded insert only: 020 owns
      the delete-and-reload of this table, not this script.
   ------------------------------------------------------------ */
DECLARE @PaigeId INT =
    (SELECT PartyId FROM gov.Party
     WHERE PartyName = 'Paige Justice'
       AND PartyTypeCode = 'PERSON');
DECLARE @NoahId INT =
    (SELECT PartyId FROM gov.Party
     WHERE PartyName = 'Noah Curlew'
       AND PartyTypeCode = 'PERSON');

DECLARE @Pop NVARCHAR(MAX) =
    N'/*POP*/ SELECT DISTINCT '
  + N'CAST(rv.FilingId AS VARCHAR(12)) + ''|'' + '
  + N'e.ItemCode + ''|'' + rv.ScopeKey AS KeyValue1 '
  + N'FROM reg.vw_McrReportValues rv '
  + N'JOIN reg.vw_McrFieldCatalogElement e '
  + N'ON e.ElementName = rv.ElementName '
  + N'WHERE rv.FilingId IN (SELECT FilingId '
  + N'FROM reg.McrInternalValue) /*DETECT*/ ';

DECLARE @DetHead NVARCHAR(MAX) =
    N'SELECT DISTINCT '
  + N'CAST(v.FilingId AS VARCHAR(12)) + ''|'' + '
  + N'v.ItemCode + ''|'' + v.ScopeKey AS KeyValue1 '
  + N'FROM reg.vw_McrValidationResults v '
  + N'WHERE v.FilingId IN (SELECT FilingId '
  + N'FROM reg.McrInternalValue) ';

INSERT INTO dq.[Rule]
    (RuleCode, RuleName, DqDimensionCode, SeverityCode,
     BlockingFlag, TargetObjectName, TargetFilter,
     ThresholdTypeCode, ThresholdValue, RuleSql,
     ExpectedDefectCode, OwnerPartyId, StewardPartyId,
     ActiveFlag)
SELECT v.Code, v.Nm, v.Dim, v.Sev, 0,
       N'reg.vw_McrValidationResults', v.Filt,
       'PCT_PASS_MIN', 1.0000,
       @Pop + @DetHead + v.Pred,
       NULL, @PaigeId, @NoahId, 1
FROM (VALUES
 ('DQR21', N'MCR filing completeness of required items',
  'COMPLETENESS','CRITICAL',
  N'RuleType = COMPLETENESS on governed filings',
  N'AND v.RuleType = ''COMPLETENESS'''),
 ('DQR22', N'MCR element conforms to its FV7 XSD type',
  'VALIDITY','HIGH',
  N'RuleType = DATATYPE on governed filings',
  N'AND v.RuleType = ''DATATYPE'''),
 ('DQR23', N'MCR filed subtotals cross-foot to totals',
  'CONSISTENCY','HIGH',
  N'RuleType = CROSSFOOT on governed filings',
  N'AND v.RuleType = ''CROSSFOOT'''),
 ('DQR24', N'MCR filed grids reconcile to each other',
  'CONSISTENCY','HIGH',
  N'RuleType = RECONCILE on governed filings',
  N'AND v.RuleType = ''RECONCILE'''),
 ('DQR25', N'MCR closed loan data agrees with HMDA LAR',
  'CONSISTENCY','MEDIUM',
  N'RuleType = HMDA_RECON on governed filings',
  N'AND v.RuleType = ''HMDA_RECON'''),
 ('DQR26', N'MCR finding of an unmapped rule type',
  'CONSISTENCY','HIGH',
  N'Catch-all: any RuleType with no DQ rule mapping',
  N'AND NOT EXISTS (SELECT 1 FROM ref.McrStagingCodeMap m '
+ N'WHERE m.MapTypeCode = ''MCR_FINDING_RULE'' '
+ N'AND m.SourceCode = v.RuleType AND m.ActiveFlag = 1)')
) v(Code, Nm, Dim, Sev, Filt, Pred)
WHERE NOT EXISTS
      (SELECT 1 FROM dq.[Rule] r WHERE r.RuleCode = v.Code);
GO

/* ------------------------------------------------------------
   3. reg.usp_RouteMcrExceptions
      One exception per finding, keyed
      FilingId|ItemCode|ScopeKey. Re-runnable: existing
      open exceptions are left alone, findings that no
      longer exist are closed as remediated.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE reg.usp_RouteMcrExceptions
    @FilingId    INT,
    @LoadBatchId INT = NULL,
    @Opened      INT = NULL OUTPUT,
    @Closed      INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OwnerId INT =
        (SELECT PartyId FROM gov.Party
         WHERE PartyName = 'Paige Justice'
           AND PartyTypeCode = 'PERSON');
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @Prefix NVARCHAR(20) =
        CAST(@FilingId AS NVARCHAR(12)) + N'|';

    IF OBJECT_ID('tempdb..#Finding') IS NOT NULL
        DROP TABLE #Finding;

    CREATE TABLE #Finding
    (
        DqRuleId  INT           NOT NULL,
        KeyValue1 NVARCHAR(100) NOT NULL,
        Severity  VARCHAR(10)   NOT NULL,
        Detail    NVARCHAR(1000) NULL,
        PRIMARY KEY (DqRuleId, KeyValue1)
    );

    INSERT INTO #Finding
        (DqRuleId, KeyValue1, Severity, Detail)
    SELECT
        r.DqRuleId,
        CAST(v.FilingId AS NVARCHAR(12)) + N'|'
            + v.ItemCode + N'|' + v.ScopeKey,
        MIN(v.Severity),
        MIN(v.Detail)
    FROM reg.vw_McrValidationResults v
    LEFT JOIN ref.McrStagingCodeMap m
      ON m.MapTypeCode = 'MCR_FINDING_RULE'
     AND m.SourceCode = v.RuleType
     AND m.ActiveFlag = 1
    JOIN dq.[Rule] r
      ON r.RuleCode = ISNULL(m.TargetCode, 'DQR26')
    WHERE v.FilingId = @FilingId
    GROUP BY r.DqRuleId, v.FilingId, v.ItemCode,
             v.ScopeKey;

    /* ---- Open new exceptions ---- */
    INSERT INTO dq.DataException
        (DqRuleId, KeyValue1, StatusCode, OwnerPartyId,
         OpenedDate, DueDate, ResolutionNote)
    SELECT f.DqRuleId, f.KeyValue1, 'NEW', @OwnerId,
           @Today,
           DATEADD(DAY, CASE WHEN f.Severity = 'ERROR'
                             THEN 30 ELSE 90 END, @Today),
           N'Finding pending resolution: ' + f.Detail
    FROM #Finding f
    WHERE NOT EXISTS
          (SELECT 1 FROM dq.DataException e
           WHERE e.DqRuleId = f.DqRuleId
             AND e.KeyValue1 = f.KeyValue1);

    SET @Opened = @@ROWCOUNT;

    /* ---- Close exceptions whose finding is gone ---- */
    UPDATE e
       SET e.StatusCode = 'REMEDIATED',
           e.ClosedDate = @Today,
           e.ResolutionNote =
               N'Finding no longer reported by the FV7 '
             + N'validator on re-validation of this '
             + N'filing.'
    FROM dq.DataException e
    JOIN dq.[Rule] r ON r.DqRuleId = e.DqRuleId
    WHERE r.RuleCode LIKE 'DQR2[1-6]'
      AND e.KeyValue1 LIKE @Prefix + N'%'
      AND e.StatusCode IN ('NEW','ACKNOWLEDGED')
      AND NOT EXISTS
          (SELECT 1 FROM #Finding f
           WHERE f.DqRuleId = e.DqRuleId
             AND f.KeyValue1 = e.KeyValue1);

    SET @Closed = @@ROWCOUNT;

    DROP TABLE #Finding;
END;
GO

/* ------------------------------------------------------------
   4. reg.vw_McrExceptionRegister
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW reg.vw_McrExceptionRegister
AS
SELECT
    e.DataExceptionId,
    FilingId = TRY_CAST(
        LEFT(e.KeyValue1,
             CHARINDEX('|', e.KeyValue1) - 1) AS INT),
    r.RuleCode, r.RuleName, r.DqDimensionCode,
    r.SeverityCode, r.BlockingFlag,
    e.KeyValue1, e.StatusCode, e.OpenedDate, e.DueDate,
    e.ClosedDate, e.ResolutionNote,
    ExceptionOwner = p.PartyName,
    AgeDays = DATEDIFF(DAY, e.OpenedDate,
                       ISNULL(e.ClosedDate,
                              CAST(GETDATE() AS DATE))),
    OverdueFlag = CASE WHEN e.ClosedDate IS NULL
                        AND e.DueDate < CAST(GETDATE()
                            AS DATE)
                       THEN 1 ELSE 0 END
FROM dq.DataException e
JOIN dq.[Rule] r ON r.DqRuleId = e.DqRuleId
LEFT JOIN gov.Party p ON p.PartyId = e.OwnerPartyId
WHERE r.RuleCode IN ('DQR21','DQR22','DQR23','DQR24',
                     'DQR25','DQR26');
GO

/* ------------------------------------------------------------
   5. Route the findings for filing 2026002.
   ------------------------------------------------------------ */
DECLARE @FilingId    INT = 2026002;
DECLARE @LoadBatchId INT;
DECLARE @LoadExecId  INT;
DECLARE @Opened      INT;
DECLARE @Closed      INT;
DECLARE @BatchName   NVARCHAR(200);
DECLARE @StepName    NVARCHAR(200);
DECLARE @TargetObj   NVARCHAR(200);
DECLARE @BatchNotes  NVARCHAR(1000);
DECLARE @Detail      NVARCHAR(2000);

SET @BatchName  = N'MCR exception routing';
SET @StepName   = N'Route FV7 findings to dq.DataException';
SET @TargetObj  = N'dq.DataException';
SET @BatchNotes =
    N'Script 042: register MCR validation findings as DQ '
  + N'rules DQR21 to DQR26 and route them into the shared '
  + N'exception register.';

EXEC audit.usp_StartLoadBatch
    @BatchName = @BatchName,
    @BatchTypeCode = 'DQ',
    @Notes = @BatchNotes,
    @LoadBatchId = @LoadBatchId OUTPUT;

BEGIN TRY

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = @StepName,
        @TargetObject = @TargetObj,
        @LoadExecutionId = @LoadExecId OUTPUT;

    EXEC reg.usp_RouteMcrExceptions
        @FilingId = @FilingId,
        @LoadBatchId = @LoadBatchId,
        @Opened = @Opened OUTPUT,
        @Closed = @Closed OUTPUT;

    EXEC audit.usp_CompleteLoadExecution
        @LoadExecutionId = @LoadExecId,
        @StatusCode = 'SUCCESS',
        @RowsInserted = @Opened,
        @RowsUpdated = @Closed;

    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'SUCCESS';

    SET @Detail =
        N'Registered DQR21 to DQR26 as non-blocking MCR '
      + N'rules and routed FV7 findings for filing 2026002 '
      + N'into dq.DataException. Opened '
      + CAST(ISNULL(@Opened, 0) AS NVARCHAR(10))
      + N', closed ' + CAST(ISNULL(@Closed, 0)
                       AS NVARCHAR(10)) + N'.';

    INSERT INTO gov.ChangeLog
        (EntityTypeCode, EntityReference, ChangeTypeCode,
         ChangeDescription, LoadBatchId)
    VALUES
        ('DQ_RULE', N'DQR21-DQR26', 'INSERT', @Detail,
         @LoadBatchId);

END TRY
BEGIN CATCH
    EXEC audit.usp_LogError
        @LoadBatchId = @LoadBatchId,
        @LoadExecutionId = @LoadExecId,
        @ContextInfo = N'042 MCR exception routing';
    EXEC audit.usp_CompleteLoadBatch
        @LoadBatchId = @LoadBatchId,
        @StatusCode = 'FAILED';
    THROW;
END CATCH
GO

/* ------------------------------------------------------------
   6. Verification
   ------------------------------------------------------------ */

/* 6a. The new rules, and confirmation none of them block. */
SELECT RuleCode, RuleName, DqDimensionCode, SeverityCode,
       BlockingFlag, ThresholdValue, ActiveFlag
FROM dq.[Rule]
WHERE RuleCode IN ('DQR21','DQR22','DQR23','DQR24',
                   'DQR25','DQR26')
ORDER BY RuleCode;

/* 6b. Routed exceptions by rule. */
SELECT RuleCode, RuleName, SeverityCode,
       Exceptions = COUNT(*),
       Open_ = SUM(CASE WHEN ClosedDate IS NULL
                        THEN 1 ELSE 0 END),
       EarliestDue = MIN(DueDate)
FROM reg.vw_McrExceptionRegister
GROUP BY RuleCode, RuleName, SeverityCode
ORDER BY RuleCode;

/* 6c. One unified exception register, both sources. */
SELECT
    Source = CASE WHEN r.RuleCode IN ('DQR21','DQR22',
                       'DQR23','DQR24','DQR25','DQR26')
                  THEN 'MCR filing validation'
                  ELSE 'Warehouse DQ rules' END,
    Exceptions = COUNT(*),
    Open_ = SUM(CASE WHEN e.ClosedDate IS NULL
                     THEN 1 ELSE 0 END)
FROM dq.DataException e
JOIN dq.[Rule] r ON r.DqRuleId = e.DqRuleId
GROUP BY CASE WHEN r.RuleCode IN ('DQR21','DQR22',
                   'DQR23','DQR24','DQR25','DQR26')
              THEN 'MCR filing validation'
              ELSE 'Warehouse DQ rules' END;

/* 6d. Sample of the routed detail. */
SELECT TOP 5 FilingId, RuleCode, KeyValue1, StatusCode,
       DueDate, ExceptionOwner, ResolutionNote
FROM reg.vw_McrExceptionRegister
ORDER BY DataExceptionId;

/* 6e. The rules execute cleanly under the DQ engine. */
DECLARE @TestBatch INT;
EXEC dq.usp_ExecuteRules
    @AsOfDate = '2026-07-31',
    @RuleExecutionBatchId = @TestBatch OUTPUT;

SELECT RuleCode, StatusCode, BlockingFlag,
       EvaluatedRowCount, FailedRowCount, PassRatePct,
       ThresholdValue
FROM dq.vw_RuleResultLatest
WHERE RuleCode LIKE 'DQR2[1-6]'
ORDER BY RuleCode;

/* 6f. The servicing certification must not have moved. */
SELECT ReportCode, CertificationStatusCode, DataAsOfDate,
       EvidenceRowCount
FROM gov.vw_ReportCertificationStatus
WHERE ReportCode = 'PBI_SVC_GOV';
GO