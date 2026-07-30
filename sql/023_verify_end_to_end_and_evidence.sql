/* ============================================================
   MortgageGovernance | Phase 7 | Script 023
   End-to-end verification and portfolio evidence pack.
   Read-only. No DDL, no DML, no EXEC. Safe to run at any
   point after 022, before or after the 024 remediation, and
   safe to re-run as many times as needed.

   Result 1  Platform scorecard (PASS/FAIL)
   Result 2  Overall verdict
   Result 3  Object inventory by schema
   Result 4  Source to warehouse volume parity
   Result 5  Governance scorecard (one row)
   Result 6  Data quality results, latest batch
   Result 7  Data quality effectiveness, latest batch
   Result 8  Reconciliation results at the as-of date
   Result 9  Report certification and evidence profile
   Result 10 End-to-end lineage trace for one element
   Result 11 MCR FV7 coverage by section
   Result 12 MISMO coverage by domain
   Result 13 Open exceptions and issues
   Result 14 Audit batch trail
   Result 15 Governance change log
   Result 16 Portfolio evidence capture checklist

   Expected counts are the canonical constants established
   by the 014 generation run and the 017 to 021 loads.
   A FAIL means the platform drifted from those constants,
   not that the check is wrong. Two checks are expected to
   change across remediation: DQ rule FAIL counts and the
   certification status. Everything else is stable.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

DECLARE @AsOfDate     DATE        = '2026-07-31';
DECLARE @TraceElement VARCHAR(60) = 'DE_CURRENT_UPB';
DECLARE @ReportCode   VARCHAR(30) = 'PBI_SVC_GOV';

DECLARE @LatestDqBatch INT =
    (SELECT MAX(RuleExecutionBatchId)
     FROM dq.RuleExecutionBatch);

DECLARE @Checks TABLE
(
    CheckOrder  INT IDENTITY(1,1),
    CheckGroup  VARCHAR(20),
    CheckName   NVARCHAR(200),
    CompareMode CHAR(2),
    Expected    INT,
    Actual      INT
);

/* ------------------------------------------------------------
   A1. Structure
   ------------------------------------------------------------ */
INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'STRUCTURE', N'Platform schemas', 'EQ', 10,
       (SELECT COUNT(*) FROM sys.schemas
        WHERE name IN ('src','stg','ref','dw','gov','dq',
                       'audit','pbi','reg','ai'));

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'STRUCTURE', N'Governance core tables', 'EQ', 30,
       (SELECT COUNT(*) FROM sys.tables t
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name = 'gov');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'STRUCTURE', N'Source tables', 'EQ', 22,
       (SELECT COUNT(*) FROM sys.tables t
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name = 'src');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'STRUCTURE', N'Warehouse tables', 'EQ', 28,
       (SELECT COUNT(*) FROM sys.tables t
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name = 'dw');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'STRUCTURE', N'Data quality tables', 'EQ', 9,
       (SELECT COUNT(*) FROM sys.tables t
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name = 'dq');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'STRUCTURE', N'Audit tables', 'EQ', 5,
       (SELECT COUNT(*) FROM sys.tables t
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name = 'audit');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'STRUCTURE', N'Certified pbi views', 'EQ', 34,
       (SELECT COUNT(*) FROM sys.views v
        JOIN sys.schemas s ON s.schema_id = v.schema_id
        WHERE s.name = 'pbi');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'STRUCTURE', N'Source systems registered', 'EQ', 10,
       (SELECT COUNT(*) FROM gov.SourceSystem);

/* ------------------------------------------------------------
   A2. Canonical data volumes (014 generation constants)
   ------------------------------------------------------------ */
INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'VOLUME', N'Loans boarded (src.SvcLoanMaster)',
       'EQ', 13090, (SELECT COUNT(*) FROM src.SvcLoanMaster);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'VOLUME', N'Month-end snapshots (src)',
       'EQ', 345484,
       (SELECT COUNT(*) FROM src.SvcLoanMonthEnd);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'VOLUME', N'Payment transactions (src)',
       'EQ', 339150,
       (SELECT COUNT(*) FROM src.PayPaymentTransaction);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'VOLUME', N'Leads (src.CrmLead)',
       'EQ', 86540, (SELECT COUNT(*) FROM src.CrmLead);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'VOLUME', N'Applications (src.LosApplication)',
       'EQ', 13956, (SELECT COUNT(*) FROM src.LosApplication);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'VOLUME', N'Synthetic defect truth rows',
       'EQ', 15712,
       (SELECT COUNT(*) FROM dq.SyntheticDefectTruth);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'VOLUME', N'Registered synthetic defects',
       'EQ', 20,
       (SELECT COUNT(*) FROM dq.SyntheticDefectRegister);

/* ------------------------------------------------------------
   A3. Source to warehouse parity. Expected is the source
       count, Actual is the warehouse count. Loaders never
       drop rows, so any variance is a load defect.
   ------------------------------------------------------------ */
INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'PARITY', N'Snapshots src to dw', 'EQ',
       (SELECT COUNT(*) FROM src.SvcLoanMonthEnd),
       (SELECT COUNT(*) FROM dw.FactLoanMonthEndSnapshot);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'PARITY', N'Payments src to dw', 'EQ',
       (SELECT COUNT(*) FROM src.PayPaymentTransaction),
       (SELECT COUNT(*) FROM dw.FactPaymentTransaction);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'PARITY', N'Leads src to dw', 'EQ',
       (SELECT COUNT(*) FROM src.CrmLead),
       (SELECT COUNT(*) FROM dw.FactLead);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'PARITY', N'Applications src to dw', 'EQ',
       (SELECT COUNT(*) FROM src.LosApplication),
       (SELECT COUNT(*) FROM dw.FactApplication);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'PARITY', N'Rate locks src to dw', 'EQ',
       (SELECT COUNT(*) FROM src.PpeRateLock),
       (SELECT COUNT(*) FROM dw.FactRateLock);

/* ------------------------------------------------------------
   A4. Governance metadata coverage (017 to 019 constants)
   ------------------------------------------------------------ */
INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'METADATA', N'Governed data elements', 'EQ', 153,
       (SELECT COUNT(*) FROM gov.DataElement);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'METADATA', N'Critical data elements', 'EQ', 27,
       (SELECT COUNT(*) FROM gov.CriticalDataElement);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'METADATA', N'SRC layer bindings', 'EQ', 148,
       (SELECT COUNT(*) FROM gov.DataElementBinding
        WHERE LayerCode = 'SRC');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'METADATA', N'DW layer bindings', 'EQ', 140,
       (SELECT COUNT(*) FROM gov.DataElementBinding
        WHERE LayerCode = 'DW');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'METADATA', N'Authoritative source rows', 'EQ', 153,
       (SELECT COUNT(*) FROM gov.AuthoritativeSource);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'METADATA', N'Element RACI assignments', 'EQ', 323,
       (SELECT COUNT(*) FROM gov.RoleAssignment
        WHERE EntityTypeCode = 'DATA_ELEMENT');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'METADATA', N'Metric to element dependencies',
       'EQ', 103,
       (SELECT COUNT(*) FROM gov.MetricDependency
        WHERE DependencyTypeCode = 'DATA_ELEMENT');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'METADATA', N'Source-to-target rows (dw targets)',
       'EQ', 150,
       (SELECT COUNT(*) FROM gov.SourceToTargetMap
        WHERE TargetSchemaName = 'dw');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'METADATA', N'MISMO v3.6.3 mappings', 'EQ', 153,
       (SELECT COUNT(*) FROM gov.MismoMapping);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'METADATA', N'Metric definitions', 'EQ', 220,
       (SELECT COUNT(*) FROM gov.MetricDefinition);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'METADATA', N'MCR FV7 line items seeded', 'EQ', 641,
       (SELECT COUNT(*) FROM gov.RegulatoryReportItem i
        JOIN gov.RegulatoryReportSection s
          ON s.RegulatoryReportSectionId =
             i.RegulatoryReportSectionId
        JOIN gov.RegulatoryReport r
          ON r.RegulatoryReportId = s.RegulatoryReportId
        WHERE r.ReportCode = 'MCR_FV7');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'METADATA', N'MCR FV7 mapping rows', 'EQ', 448,
       (SELECT COUNT(*) FROM gov.RegulatoryMapping);

/* ------------------------------------------------------------
   A5. Controls and execution state
   ------------------------------------------------------------ */
INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'CONTROL', N'Active DQ rules', 'EQ', 20,
       (SELECT COUNT(*) FROM dq.[Rule] WHERE ActiveFlag = 1);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'CONTROL', N'Active reconciliation controls',
       'EQ', 10,
       (SELECT COUNT(*) FROM audit.ReconciliationControl
        WHERE ActiveFlag = 1);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'CONTROL', N'Rules executed in latest DQ batch',
       'EQ', 20,
       (SELECT COUNT(*) FROM dq.RuleResult
        WHERE RuleExecutionBatchId = @LatestDqBatch);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'CONTROL', N'Effectiveness rows in latest DQ batch',
       'GE', 20,
       (SELECT COUNT(*) FROM dq.RuleEffectiveness
        WHERE RuleExecutionBatchId = @LatestDqBatch);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'CONTROL', N'Reconciliation results at as-of date',
       'EQ', 10,
       (SELECT COUNT(*) FROM audit.vw_ReconciliationLatest
        WHERE AsOfDate = @AsOfDate);

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'CONTROL', N'Failed load batches', 'EQ', 0,
       (SELECT COUNT(*) FROM audit.LoadBatch
        WHERE StatusCode = 'FAILED');

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'CONTROL',
       N'CDE-flagged elements missing register row',
       'EQ', 0,
       (SELECT COUNT(*) FROM gov.DataElement de
        WHERE de.CdeFlag = 1
          AND NOT EXISTS
              (SELECT 1 FROM gov.CriticalDataElement c
               WHERE c.DataElementId = de.DataElementId));

INSERT INTO @Checks
    (CheckGroup, CheckName, CompareMode, Expected, Actual)
SELECT 'CONTROL', N'Certification row for governed report',
       'EQ', 1,
       (SELECT COUNT(*) FROM gov.Certification
        WHERE EntityTypeCode = 'REPORT'
          AND EntityReference = @ReportCode);

/* ============================================================
   Result 1: platform scorecard
   ============================================================ */
SELECT CheckOrder, CheckGroup, CheckName, CompareMode,
       Expected, Actual,
       CASE WHEN CompareMode = 'GE' AND Actual >= Expected
                 THEN 'PASS'
            WHEN CompareMode = 'EQ' AND Actual = Expected
                 THEN 'PASS'
            ELSE 'FAIL' END AS CheckResult
FROM @Checks
ORDER BY CheckOrder;

/* ============================================================
   Result 2: overall verdict
   ============================================================ */
SELECT
    (SELECT COUNT(*) FROM @Checks) AS ChecksRun,
    (SELECT COUNT(*) FROM @Checks
     WHERE (CompareMode = 'EQ' AND Actual = Expected)
        OR (CompareMode = 'GE' AND Actual >= Expected))
        AS ChecksPassed,
    CASE WHEN EXISTS
        (SELECT 1 FROM @Checks
         WHERE (CompareMode = 'EQ' AND Actual <> Expected)
            OR (CompareMode = 'GE' AND Actual < Expected))
    THEN 'END-TO-END VERIFICATION: FAIL. Review the '
       + 'scorecard above.'
    ELSE 'END-TO-END VERIFICATION: ALL CHECKS PASS.'
    END AS OverallResult;

/* ============================================================
   Result 3: object inventory by schema
   ============================================================ */
SELECT s.name AS SchemaName,
       SUM(CASE WHEN o.type = 'U' THEN 1 ELSE 0 END)
           AS Tables,
       SUM(CASE WHEN o.type = 'V' THEN 1 ELSE 0 END)
           AS Views,
       SUM(CASE WHEN o.type = 'P' THEN 1 ELSE 0 END)
           AS Procedures,
       SUM(CASE WHEN o.type IN ('FN','IF','TF') THEN 1
                ELSE 0 END) AS Functions
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE s.name IN ('src','stg','ref','dw','gov','dq',
                 'audit','pbi','reg','ai')
  AND o.type IN ('U','V','P','FN','IF','TF')
GROUP BY s.name
ORDER BY s.name;

/* ============================================================
   Result 4: source to warehouse volume parity
   ============================================================ */
SELECT v.Domain, v.SourceObject, v.SourceRows,
       v.WarehouseObject, v.WarehouseRows,
       v.WarehouseRows - v.SourceRows AS Variance
FROM (
    SELECT 'Servicing snapshots' AS Domain,
           'src.SvcLoanMonthEnd' AS SourceObject,
           (SELECT COUNT(*) FROM src.SvcLoanMonthEnd)
               AS SourceRows,
           'dw.FactLoanMonthEndSnapshot'
               AS WarehouseObject,
           (SELECT COUNT(*)
            FROM dw.FactLoanMonthEndSnapshot)
               AS WarehouseRows
    UNION ALL
    SELECT 'Payments', 'src.PayPaymentTransaction',
           (SELECT COUNT(*) FROM src.PayPaymentTransaction),
           'dw.FactPaymentTransaction',
           (SELECT COUNT(*) FROM dw.FactPaymentTransaction)
    UNION ALL
    SELECT 'Leads', 'src.CrmLead',
           (SELECT COUNT(*) FROM src.CrmLead),
           'dw.FactLead',
           (SELECT COUNT(*) FROM dw.FactLead)
    UNION ALL
    SELECT 'Applications', 'src.LosApplication',
           (SELECT COUNT(*) FROM src.LosApplication),
           'dw.FactApplication',
           (SELECT COUNT(*) FROM dw.FactApplication)
    UNION ALL
    SELECT 'Rate locks', 'src.PpeRateLock',
           (SELECT COUNT(*) FROM src.PpeRateLock),
           'dw.FactRateLock',
           (SELECT COUNT(*) FROM dw.FactRateLock)
    UNION ALL
    SELECT 'Boarding tape', 'src.BrdBoardingTape',
           (SELECT COUNT(*) FROM src.BrdBoardingTape),
           'dw.FactBoardingEvent',
           (SELECT COUNT(*) FROM dw.FactBoardingEvent)
) v
ORDER BY v.Domain;

/* ============================================================
   Result 5: governance scorecard, plus portfolio position
   ============================================================ */
SELECT g.*,
       (SELECT COUNT(*) FROM dw.FactLoanMonthEndSnapshot
        WHERE AsOfDate = @AsOfDate
          AND ActiveServicingFlag = 1) AS ActiveLoansAtAsOf,
       (SELECT SUM(CurrentUpbAmount)
        FROM dw.FactLoanMonthEndSnapshot
        WHERE AsOfDate = @AsOfDate
          AND ActiveServicingFlag = 1) AS UpbAtAsOf
FROM pbi.vw_GovernanceScorecard g;

/* ============================================================
   Result 6: data quality results, latest batch
   ============================================================ */
SELECT RuleCode, RuleName, DqDimensionCode, SeverityCode,
       BlockingFlag, DataElementCode, CdeFlag,
       EvaluatedRowCount, FailedRowCount, PassRatePct,
       ThresholdValue, StatusCode, RuleOwner, RuleSteward
FROM dq.vw_RuleResultLatest
ORDER BY CASE WHEN StatusCode = 'FAIL' THEN 0 ELSE 1 END,
         BlockingFlag DESC, RuleCode;

/* ============================================================
   Result 7: data quality effectiveness, latest batch.
   Precision is NULL by design on broad-condition rules.
   ============================================================ */
SELECT RuleCode, DefectCode, DefectName, SeverityCode,
       TruePositive AS TP, FalsePositive AS FP,
       FalseNegative AS FN, BroadConditionFlag,
       PrecisionPct, RecallPct, F1Score,
       BroadConditionRationale
FROM dq.vw_RuleEffectivenessLatest
ORDER BY RuleCode;

/* ============================================================
   Result 8: reconciliation results at the as-of date
   ============================================================ */
SELECT ControlCode, ControlName, ControlTypeCode,
       BlockingFlag, SourceValue, TargetValue,
       VarianceValue, VariancePct, StatusCode,
       ControlOwner, Details
FROM audit.vw_ReconciliationLatest
WHERE AsOfDate = @AsOfDate
ORDER BY CASE WHEN StatusCode = 'FAIL' THEN 0
              WHEN StatusCode = 'WARN' THEN 1
              ELSE 2 END, ControlCode;

/* ============================================================
   Result 9: certification status and evidence profile
   ============================================================ */
SELECT c.ReportCode, c.ReportName, c.SemanticModelName,
       c.ReportOwner, c.CertificationStatusCode,
       c.CertifiedBy, c.CertifiedDateUtc, c.DataAsOfDate,
       c.EvidenceRowCount, c.CertificationNotes,
       ev.DqEvidence, ev.ReconEvidence, ev.LoadEvidence
FROM gov.vw_ReportCertificationStatus c
OUTER APPLY (
    SELECT
        SUM(CASE WHEN e.EvidenceTypeCode = 'DQ_RESULT'
                 THEN 1 ELSE 0 END) AS DqEvidence,
        SUM(CASE WHEN e.EvidenceTypeCode = 'RECON_RESULT'
                 THEN 1 ELSE 0 END) AS ReconEvidence,
        SUM(CASE WHEN e.EvidenceTypeCode = 'LOAD_EXECUTION'
                 THEN 1 ELSE 0 END) AS LoadEvidence
    FROM gov.CertificationEvidence e
    JOIN gov.Certification cert
      ON cert.CertificationId = e.CertificationId
    WHERE cert.EntityTypeCode = 'REPORT'
      AND cert.EntityReference = c.ReportCode
) ev
WHERE c.ReportCode = @ReportCode;

/* ============================================================
   Result 10: end-to-end lineage trace for one element.
   Source system to source column to warehouse column to
   certified view to metric to regulatory line item, plus
   the rules and owners that protect it. This is the
   "can an auditor trace the number" demonstration.
   ============================================================ */
SELECT t.StepNo, t.LayerName, t.ObjectName, t.Detail
FROM (
    SELECT 1 AS StepNo,
           CAST('1 ELEMENT' AS NVARCHAR(30)) AS LayerName,
           CAST(de.DataElementCode AS NVARCHAR(300))
               AS ObjectName,
           CAST(de.DataElementName + N' | CDE='
                + CAST(de.CdeFlag AS NVARCHAR(1))
                + N' | ' + de.ClassificationLevelCode
                AS NVARCHAR(300)) AS Detail
    FROM gov.DataElement de
    WHERE de.DataElementCode = @TraceElement

    UNION ALL
    SELECT 2, '2 AUTHORITY',
           CAST(ss.SourceSystemCode AS NVARCHAR(300)),
           CAST(ss.SourceSystemName + N' | scope '
                + a.AuthorityScopeCode AS NVARCHAR(300))
    FROM gov.AuthoritativeSource a
    JOIN gov.DataElement de
      ON de.DataElementId = a.DataElementId
    JOIN gov.SourceSystem ss
      ON ss.SourceSystemId = a.SourceSystemId
    WHERE de.DataElementCode = @TraceElement

    UNION ALL
    SELECT 3, '3 SOURCE',
           CAST(b.SchemaName + N'.' + b.ObjectName + N'.'
                + b.ColumnName AS NVARCHAR(300)),
           CAST(ISNULL(o.GrainStatement, N'')
                AS NVARCHAR(300))
    FROM gov.DataElementBinding b
    JOIN gov.DataElement de
      ON de.DataElementId = b.DataElementId
    LEFT JOIN gov.SourceObject o
      ON o.ObjectName = b.ObjectName
     AND o.SchemaName = b.SchemaName
    WHERE de.DataElementCode = @TraceElement
      AND b.LayerCode = 'SRC'

    UNION ALL
    SELECT 4, '4 TRANSFORM',
           CAST(m.TargetSchemaName + N'.'
                + m.TargetObjectName + N'.'
                + m.TargetColumnName AS NVARCHAR(300)),
           CAST(m.TransformTypeCode + N' from '
                + ISNULL(m.SourceObjectName, N'n/a')
                + N'.'
                + ISNULL(m.SourceColumnName, N'n/a')
                AS NVARCHAR(300))
    FROM gov.SourceToTargetMap m
    WHERE EXISTS (
        SELECT 1 FROM gov.DataElementBinding b
        JOIN gov.DataElement de
          ON de.DataElementId = b.DataElementId
        WHERE de.DataElementCode = @TraceElement
          AND b.LayerCode = 'DW'
          AND b.ObjectName = m.TargetObjectName
          AND b.ColumnName = m.TargetColumnName)

    UNION ALL
    SELECT 5, '5 WAREHOUSE',
           CAST(b.SchemaName + N'.' + b.ObjectName + N'.'
                + b.ColumnName AS NVARCHAR(300)),
           CAST(N'Governed dimensional model'
                AS NVARCHAR(300))
    FROM gov.DataElementBinding b
    JOIN gov.DataElement de
      ON de.DataElementId = b.DataElementId
    WHERE de.DataElementCode = @TraceElement
      AND b.LayerCode = 'DW'

    UNION ALL
    SELECT DISTINCT 6, '6 PBI VIEW',
           CAST(s.name + N'.' + v.name AS NVARCHAR(300)),
           CAST(N'Certified view exposing '
                + d.referenced_entity_name
                AS NVARCHAR(300))
    FROM sys.sql_expression_dependencies d
    JOIN sys.views v ON v.object_id = d.referencing_id
    JOIN sys.schemas s ON s.schema_id = v.schema_id
    WHERE s.name = 'pbi'
      AND d.referenced_entity_name IN (
          SELECT b.ObjectName
          FROM gov.DataElementBinding b
          JOIN gov.DataElement de
            ON de.DataElementId = b.DataElementId
          WHERE de.DataElementCode = @TraceElement
            AND b.LayerCode = 'DW')

    UNION ALL
    SELECT 7, '7 METRIC',
           CAST(md.MetricCode AS NVARCHAR(300)),
           CAST(md.MetricName + N' | '
                + md.CoverageStatusCode + N' | '
                + md.ImplementationStatusCode
                AS NVARCHAR(300))
    FROM gov.MetricDefinition md
    JOIN gov.MetricDependency dep
      ON dep.MetricDefinitionId = md.MetricDefinitionId
     AND dep.DependencyTypeCode = 'DATA_ELEMENT'
    JOIN gov.DataElement de
      ON de.DataElementId = dep.DependencyEntityId
    WHERE de.DataElementCode = @TraceElement

    UNION ALL
    SELECT 8, '8 REGULATORY',
           CAST(i.ItemCode AS NVARCHAR(300)),
           CAST(i.ItemName + N' | '
                + rm.RegulatoryClassificationCode + N' | '
                + rm.FilingInputTypeCode AS NVARCHAR(300))
    FROM gov.RegulatoryMapping rm
    JOIN gov.RegulatoryReportItem i
      ON i.RegulatoryReportItemId = rm.RegulatoryReportItemId
    JOIN gov.DataElement de
      ON de.DataElementId = rm.DataElementId
    WHERE de.DataElementCode = @TraceElement

    UNION ALL
    SELECT 9, '9 DQ RULE',
           CAST(r.RuleCode AS NVARCHAR(300)),
           CAST(r.RuleName + N' | ' + r.SeverityCode
                + N' | blocking='
                + CAST(r.BlockingFlag AS NVARCHAR(1))
                AS NVARCHAR(300))
    FROM dq.[Rule] r
    WHERE r.DataElementCode = @TraceElement
      AND r.ActiveFlag = 1

    UNION ALL
    SELECT 10, '10 OWNERSHIP',
           CAST(gr.RoleCode AS NVARCHAR(300)),
           CAST(p.PartyName + N' (' + ra.RaciCode + N')'
                AS NVARCHAR(300))
    FROM gov.RoleAssignment ra
    JOIN gov.GovernanceRole gr
      ON gr.GovernanceRoleId = ra.GovernanceRoleId
    JOIN gov.Party p ON p.PartyId = ra.PartyId
    JOIN gov.DataElement de
      ON de.DataElementId = ra.EntityId
    WHERE ra.EntityTypeCode = 'DATA_ELEMENT'
      AND de.DataElementCode = @TraceElement
) t
ORDER BY t.StepNo, t.ObjectName;

/* ============================================================
   Result 11: MCR FV7 coverage by section, with the honest
   unmapped reason. Proves the platform does not overclaim.
   ============================================================ */
SELECT ComponentCode, SectionCode, SectionName,
       ScopeLevelCode, ItemCount, MappedItemCount,
       UnmappedItemCount,
       CAST(100.0 * MappedItemCount
            / NULLIF(ItemCount, 0) AS DECIMAL(5,1))
           AS MappedPct,
       UnmappedReason
FROM gov.vw_RegulatoryCoverage
ORDER BY ComponentCode, SectionCode;

/* ============================================================
   Result 12: MISMO v3.6.3 coverage by domain
   ============================================================ */
SELECT DomainArea, ElementCount, MismoMappedCount,
       InternalExtensionCount, NotApplicableCount,
       PublicSourceCount, CandidateCount,
       CdeCount, MappedCdeCount
FROM gov.vw_MismoCoverage
ORDER BY DomainArea;

/* ============================================================
   Result 13: open exceptions and issues. Empty before 024.
   ============================================================ */
SELECT 'DQ_EXCEPTION' AS RecordType,
       r.RuleCode AS Reference,
       CAST(e.KeyValue1 AS NVARCHAR(300)) AS KeyValue,
       e.StatusCode, p.PartyName AS Owner,
       e.OpenedDate, e.DueDate, e.ClosedDate,
       CAST(e.ResolutionNote AS NVARCHAR(1000)) AS Notes
FROM dq.DataException e
JOIN dq.[Rule] r ON r.DqRuleId = e.DqRuleId
LEFT JOIN gov.Party p ON p.PartyId = e.OwnerPartyId
UNION ALL
SELECT 'DATA_ISSUE', i.DqRuleReference,
       CAST(i.IssueTitle AS NVARCHAR(300)),
       i.StatusCode, p.PartyName, i.OpenedDate,
       i.TargetResolutionDate, i.ClosedDate,
       CAST(i.ResolutionNotes AS NVARCHAR(1000))
FROM gov.DataIssue i
LEFT JOIN gov.Party p ON p.PartyId = i.OwnerPartyId
ORDER BY RecordType, Reference;

/* ============================================================
   Result 14: audit batch trail, most recent 25
   ============================================================ */
SELECT TOP 25 b.LoadBatchId, b.BatchName, b.BatchTypeCode,
       b.StatusCode, b.StartDateUtc, b.EndDateUtc,
       DATEDIFF(SECOND, b.StartDateUtc,
                ISNULL(b.EndDateUtc, SYSUTCDATETIME()))
           AS ElapsedSeconds,
       (SELECT COUNT(*) FROM audit.LoadExecution x
        WHERE x.LoadBatchId = b.LoadBatchId) AS Steps,
       (SELECT ISNULL(SUM(x.RowsInserted), 0)
        FROM audit.LoadExecution x
        WHERE x.LoadBatchId = b.LoadBatchId) AS RowsInserted
FROM audit.LoadBatch b
ORDER BY b.LoadBatchId DESC;

/* ============================================================
   Result 15: governance change log, most recent 25
   ============================================================ */
SELECT TOP 25 ChangeLogId, EntityTypeCode, EntityReference,
       ChangeTypeCode, ChangeDescription, ChangedBy,
       ChangeDateUtc
FROM gov.ChangeLog
ORDER BY ChangeLogId DESC;

/* ============================================================
   Result 16: portfolio evidence capture checklist.
   Run this script, then capture each item below.
   ============================================================ */
SELECT v.EvidenceNo, v.Artifact, v.CaptureFrom, v.WhyItMatters
FROM (VALUES
 (1, N'Platform scorecard',
  N'Result 1 and 2 of this script',
  N'Shows the environment matches its documented '
  + N'constants and is reproducible.'),
 (2, N'Object inventory by schema',
  N'Result 3',
  N'Evidence of a layered architecture, not a single '
  + N'flat database.'),
 (3, N'Source to warehouse parity',
  N'Result 4',
  N'Proves loaders drop no rows; the base claim behind '
  + N'every downstream number.'),
 (4, N'Governance scorecard',
  N'Result 5',
  N'One-slide summary of governed elements, CDEs, '
  + N'mappings, rules, and lineage.'),
 (5, N'DQ results before remediation',
  N'Result 6, run before 024',
  N'Captures the blocking failures that hold '
  + N'certification. Half of the certification story.'),
 (6, N'DQ effectiveness grid',
  N'Result 7',
  N'Precision and recall against planted defects. This '
  + N'is what separates real DQ from rule theater.'),
 (7, N'Reconciliation grid',
  N'Result 8',
  N'Control-level evidence including the documented '
  + N'snapshot continuity WARN.'),
 (8, N'Certification NOT_CERTIFIED',
  N'Result 9, run before 024',
  N'Shows the gate actually blocks. A gate that never '
  + N'blocks proves nothing.'),
 (9, N'Certification CERTIFIED_WITH_EXCEPTIONS',
  N'Result 9, run after 024',
  N'Shows remediation moved the state honestly, with '
  + N'exceptions documented rather than hidden.'),
 (10, N'End-to-end lineage trace',
  N'Result 10',
  N'The auditor question answered in one result set: '
  + N'source system to regulatory line item.'),
 (11, N'MCR FV7 coverage by section',
  N'Result 11',
  N'Regulatory readiness with explicit unmapped '
  + N'reasons. Demonstrates scope honesty.'),
 (12, N'MISMO coverage by domain',
  N'Result 12',
  N'MISMO-aligned mapping coverage including '
  + N'candidate and extension counts.'),
 (13, N'Exception and issue register',
  N'Result 13, run after 024',
  N'Accepted-risk exceptions with owners and due '
  + N'dates. Governance follow-through.'),
 (14, N'Audit batch trail',
  N'Result 14',
  N'Every load, DQ run, reconciliation, and '
  + N'certification is traceable to a batch.'),
 (15, N'Governance change log',
  N'Result 15',
  N'Metadata changes are versioned, not silently '
  + N'overwritten.')
) v(EvidenceNo, Artifact, CaptureFrom, WhyItMatters)
ORDER BY v.EvidenceNo;

PRINT 'Script 023 complete: end-to-end verification and '
    + 'evidence pack produced. Read-only, nothing changed.';
GO
