/* ============================================================
   MortgageGovernance | Phase 3 | Script 009
   Verification: metric catalog counts, classification
   distribution, specification completeness for SUPPORTED
   metrics, dual pull-through governance, and dependency
   integrity. All checks must PASS before Phase 4.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

DECLARE @Checks TABLE
(
    CheckOrder INT IDENTITY(1,1),
    CheckName  NVARCHAR(200),
    Expected   INT,
    Actual     INT
);

/* ---- Catalog totals ---- */
INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Governed metrics (220 workbook + M221)', 221,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE MetricCode LIKE 'M[0-9][0-9][0-9]');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Duplicate metric names', 0,
       (SELECT COUNT(*) FROM
        (SELECT MetricName FROM gov.MetricDefinition
         GROUP BY MetricName HAVING COUNT(*) > 1) d);

/* ---- Coverage distribution ---- */
INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Coverage: SUPPORTED (44 P1 + 24 E1)', 68,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE CoverageStatusCode = 'SUPPORTED');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Coverage: PLANNED', 74,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE CoverageStatusCode = 'PLANNED');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Coverage: DEFERRED', 79,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE CoverageStatusCode = 'DEFERRED');

/* ---- Project distribution ---- */
INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Project P1 (44 supported + 17 planned)', 61,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE ProjectAssignmentCode = 'P1');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Project P1E1 (23 workbook + M221)', 24,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE ProjectAssignmentCode = 'P1E1');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Project P2', 53,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE ProjectAssignmentCode = 'P2');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Project P3', 4,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE ProjectAssignmentCode = 'P3');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Project FUTURE', 79,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE ProjectAssignmentCode = 'FUTURE');

/* ---- Specification completeness (the KPI coverage test) ---- */
INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'SUPPORTED metrics marked SPEC_READY', 68,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE CoverageStatusCode = 'SUPPORTED'
          AND ImplementationStatusCode = 'SPEC_READY');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'SUPPORTED missing grain/basis/population/logic', 0,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE CoverageStatusCode = 'SUPPORTED'
          AND (RequiredGrain IS NULL
               OR ReportingTimeBasisCode IS NULL
               OR PopulationLogic IS NULL
               OR (NumeratorLogic IS NULL
                   AND CalculationLogic IS NULL)));

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Non-supported metrics carrying spec fields', 0,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE CoverageStatusCode <> 'SUPPORTED'
          AND ImplementationStatusCode <> 'NOT_STARTED');

/* ---- Dual pull-through governance ---- */
INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Dual pull-through metrics (M001 + M221)', 2,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE MetricName IN
              (N'Pull-Through Rate (Lock Basis)',
               N'Pull-Through Ratio (Application Basis)'));

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'M221 flagged MCR-relevant', 1,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE MetricCode = 'M221'
          AND McrRelevanceFlag = 1
          AND RegulatoryRelevanceFlag = 1);

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Change log entry for the dual definition', 1,
       (SELECT COUNT(*) FROM gov.ChangeLog
        WHERE EntityReference = N'M001'
          AND ChangeTypeCode = 'VERSION');

/* ---- Regulatory flags ---- */
INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'SUPPORTED metrics flagged MCR-relevant', 20,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE CoverageStatusCode = 'SUPPORTED'
          AND McrRelevanceFlag = 1);

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'SUPPORTED metrics flagged regulatory-relevant', 37,
       (SELECT COUNT(*) FROM gov.MetricDefinition
        WHERE CoverageStatusCode = 'SUPPORTED'
          AND RegulatoryRelevanceFlag = 1);

/* ---- Dependency integrity ---- */
INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Metric dependencies (78 rule + 3 element)', 81,
       (SELECT COUNT(*)
        FROM gov.MetricDependency d
        JOIN gov.MetricDefinition m
          ON m.MetricDefinitionId = d.MetricDefinitionId
        WHERE m.MetricCode LIKE 'M[0-9][0-9][0-9]');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'SUPPORTED metrics without any dependency', 0,
       (SELECT COUNT(*) FROM gov.MetricDefinition m
        WHERE m.CoverageStatusCode = 'SUPPORTED'
          AND NOT EXISTS
              (SELECT 1 FROM gov.MetricDependency d
               WHERE d.MetricDefinitionId =
                     m.MetricDefinitionId));

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Rule dependencies with unresolved rule id', 0,
       (SELECT COUNT(*) FROM gov.MetricDependency
        WHERE DependencyTypeCode = 'DERIVATION_RULE'
          AND DependencyEntityId IS NULL);

/* ============ Result 1: scorecard ============ */
SELECT CheckOrder, CheckName, Expected, Actual,
       CASE WHEN Expected = Actual THEN 'PASS'
            ELSE 'FAIL' END AS CheckResult
FROM @Checks
ORDER BY CheckOrder;

SELECT CASE WHEN EXISTS
            (SELECT 1 FROM @Checks WHERE Expected <> Actual)
       THEN 'PHASE 3 VERIFICATION: FAIL. Review the scorecard.'
       ELSE 'PHASE 3 VERIFICATION: ALL CHECKS PASS. Ready for '
          + 'Phase 4 (reference and source layer).'
       END AS OverallResult;

/* ============ Result 2: coverage by project matrix ========= */
SELECT ProjectAssignmentCode,
       SUM(CASE WHEN CoverageStatusCode = 'SUPPORTED'
                THEN 1 ELSE 0 END) AS Supported,
       SUM(CASE WHEN CoverageStatusCode = 'PLANNED'
                THEN 1 ELSE 0 END) AS Planned,
       SUM(CASE WHEN CoverageStatusCode = 'DEFERRED'
                THEN 1 ELSE 0 END) AS Deferred,
       COUNT(*) AS Total
FROM gov.MetricDefinition
GROUP BY ProjectAssignmentCode
ORDER BY CASE ProjectAssignmentCode
              WHEN 'P1' THEN 1 WHEN 'P1E1' THEN 2
              WHEN 'P2' THEN 3 WHEN 'P3' THEN 4
              ELSE 5 END;

/* ============ Result 3: coverage by business domain ======== */
SELECT BusinessDomain,
       COUNT(*) AS Metrics,
       SUM(CASE WHEN CoverageStatusCode = 'SUPPORTED'
                THEN 1 ELSE 0 END) AS Supported
FROM gov.MetricDefinition
GROUP BY BusinessDomain
ORDER BY Supported DESC, BusinessDomain;

/* ============ Result 4: supported catalog preview ========== */
SELECT m.MetricCode, m.MetricName, m.BusinessDomain,
       m.AggregationTypeCode, m.ReportingTimeBasisCode,
       m.DirectionCode, m.McrRelevanceFlag,
       STRING_AGG(d.DependencyReference, ', ')
           WITHIN GROUP (ORDER BY d.DependencyReference)
           AS Dependencies
FROM gov.MetricDefinition m
LEFT JOIN gov.MetricDependency d
  ON d.MetricDefinitionId = m.MetricDefinitionId
WHERE m.CoverageStatusCode = 'SUPPORTED'
GROUP BY m.MetricCode, m.MetricName, m.BusinessDomain,
         m.AggregationTypeCode, m.ReportingTimeBasisCode,
         m.DirectionCode, m.McrRelevanceFlag
ORDER BY m.MetricCode;
GO
