/* ============================================================
   MortgageGovernance | Phase 1-2 | Script 007
   Verification: structural counts, seed counts, referential
   spot checks, and audit evidence.
   Result set 1 is the PASS/FAIL scorecard. Result sets 2-4
   are supporting evidence. All checks must PASS before
   moving to Phase 3.
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

/* ---- Structure ---- */
INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Platform schemas', 10,
       (SELECT COUNT(*) FROM sys.schemas
        WHERE name IN ('src','stg','ref','dw','gov','dq',
                       'audit','pbi','reg','ai'));

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Audit tables', 5,
       (SELECT COUNT(*) FROM sys.tables t
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name = 'audit');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Audit procedures', 5,
       (SELECT COUNT(*) FROM sys.procedures p
        JOIN sys.schemas s ON s.schema_id = p.schema_id
        WHERE s.name = 'audit');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Governance core tables', 30,
       (SELECT COUNT(*) FROM sys.tables t
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name = 'gov');

/* ---- Core seed (script 004) ---- */
INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Source systems', 10,
       (SELECT COUNT(*) FROM gov.SourceSystem);

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Governance roles', 8,
       (SELECT COUNT(*) FROM gov.GovernanceRole);

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Parties (15 people, 2 teams)', 17,
       (SELECT COUNT(*) FROM gov.Party);

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'RACI role assignments', 33,
       (SELECT COUNT(*) FROM gov.RoleAssignment);

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Regulatory frameworks', 9,
       (SELECT COUNT(*) FROM gov.RegulatoryFramework);

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Regulatory reports (MCR FV7)', 1,
       (SELECT COUNT(*) FROM gov.RegulatoryReport
        WHERE ReportCode = 'MCR_FV7');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'MCR FV7 sections', 6,
       (SELECT COUNT(*) FROM gov.RegulatoryReportSection s
        JOIN gov.RegulatoryReport r
          ON r.RegulatoryReportId = s.RegulatoryReportId
        WHERE r.ReportCode = 'MCR_FV7');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Report inventory (PBI_SVC_GOV)', 1,
       (SELECT COUNT(*) FROM gov.ReportInventory
        WHERE ReportCode = 'PBI_SVC_GOV');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Initial certification record', 1,
       (SELECT COUNT(*) FROM gov.Certification
        WHERE EntityReference = 'PBI_SVC_GOV'
          AND CertificationStatusCode = 'NOT_CERTIFIED');

/* ---- Derivation rules (script 005) ---- */
INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Derivation rules (DRV)', 67,
       (SELECT COUNT(*) FROM gov.DerivationRule
        WHERE RuleCode LIKE 'DRV[_]%');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Derivation rule inputs', 142,
       (SELECT COUNT(*)
        FROM gov.DerivationRuleInput ri
        JOIN gov.DerivationRule r
          ON r.DerivationRuleId = ri.DerivationRuleId
        WHERE r.RuleCode LIKE 'DRV[_]%');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Rules missing inputs', 0,
       (SELECT COUNT(*) FROM gov.DerivationRule r
        WHERE r.RuleCode LIKE 'DRV[_]%'
          AND NOT EXISTS
              (SELECT 1 FROM gov.DerivationRuleInput ri
               WHERE ri.DerivationRuleId =
                     r.DerivationRuleId));

/* ---- MCR FV7 items (script 006) ---- */
INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'FV7 line items (all sections)', 641,
       (SELECT COUNT(*)
        FROM gov.RegulatoryReportItem i
        JOIN gov.RegulatoryReportSection s
          ON s.RegulatoryReportSectionId =
             i.RegulatoryReportSectionId
        JOIN gov.RegulatoryReport r
          ON r.RegulatoryReportId = s.RegulatoryReportId
        WHERE r.ReportCode = 'MCR_FV7');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'FV7 items: RMLA Company', 64,
       (SELECT COUNT(*)
        FROM gov.RegulatoryReportItem i
        JOIN gov.RegulatoryReportSection s
          ON s.RegulatoryReportSectionId =
             i.RegulatoryReportSectionId
        WHERE s.SectionCode = 'RMLA_COMPANY');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'FV7 items: RMLA Section I', 52,
       (SELECT COUNT(*)
        FROM gov.RegulatoryReportItem i
        JOIN gov.RegulatoryReportSection s
          ON s.RegulatoryReportSectionId =
             i.RegulatoryReportSectionId
        WHERE s.SectionCode = 'RMLA_SEC1');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'FV7 items: RMLA Section II', 71,
       (SELECT COUNT(*)
        FROM gov.RegulatoryReportItem i
        JOIN gov.RegulatoryReportSection s
          ON s.RegulatoryReportSectionId =
             i.RegulatoryReportSectionId
        WHERE s.SectionCode = 'RMLA_SEC2');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'FV7 items: RMLA Section III', 75,
       (SELECT COUNT(*)
        FROM gov.RegulatoryReportItem i
        JOIN gov.RegulatoryReportSection s
          ON s.RegulatoryReportSectionId =
             i.RegulatoryReportSectionId
        WHERE s.SectionCode = 'RMLA_SEC3');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'FV7 items: SSSF', 40,
       (SELECT COUNT(*)
        FROM gov.RegulatoryReportItem i
        JOIN gov.RegulatoryReportSection s
          ON s.RegulatoryReportSectionId =
             i.RegulatoryReportSectionId
        WHERE s.SectionCode = 'SSSF');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'FV7 items: Financial Condition', 339,
       (SELECT COUNT(*)
        FROM gov.RegulatoryReportItem i
        JOIN gov.RegulatoryReportSection s
          ON s.RegulatoryReportSectionId =
             i.RegulatoryReportSectionId
        WHERE s.SectionCode = 'FC');

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'FV7 glossary terms (approved)', 35,
       (SELECT COUNT(*) FROM gov.BusinessTerm
        WHERE SourceOfDefinition =
              N'NMLS MCR FV7 Field Definitions'
          AND ApprovalStatusCode = 'APPROVED');

/* ---- Referential spot checks ---- */
INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Orphan system role assignments', 0,
       (SELECT COUNT(*) FROM gov.RoleAssignment ra
        WHERE ra.EntityTypeCode = 'SOURCE_SYSTEM'
          AND NOT EXISTS
              (SELECT 1 FROM gov.SourceSystem ss
               WHERE ss.SourceSystemId = ra.EntityId));

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Duplicate FV7 item codes in section', 0,
       (SELECT COUNT(*) FROM
        (SELECT i.RegulatoryReportSectionId, i.ItemCode
         FROM gov.RegulatoryReportItem i
         GROUP BY i.RegulatoryReportSectionId, i.ItemCode
         HAVING COUNT(*) > 1) d);

INSERT INTO @Checks (CheckName, Expected, Actual)
SELECT N'Failed seed batches', 0,
       (SELECT COUNT(*) FROM audit.LoadBatch
        WHERE BatchTypeCode = 'SEED'
          AND StatusCode <> 'SUCCESS');

/* ============ Result 1: scorecard ============ */
SELECT CheckOrder,
       CheckName,
       Expected,
       Actual,
       CASE WHEN Expected = Actual THEN 'PASS'
            ELSE 'FAIL' END AS CheckResult
FROM @Checks
ORDER BY CheckOrder;

SELECT CASE WHEN EXISTS
            (SELECT 1 FROM @Checks
             WHERE Expected <> Actual)
       THEN 'PHASE 1-2 VERIFICATION: FAIL. Review the '
          + 'scorecard above.'
       ELSE 'PHASE 1-2 VERIFICATION: ALL CHECKS PASS. '
          + 'Ready for Phase 3 (metric catalog).'
       END AS OverallResult;

/* ============ Result 2: seed batch evidence ============
   The seeds ran through the audit framework. This listing
   is certification-style evidence of the metadata load. */
SELECT b.LoadBatchId, b.BatchName, b.BatchTypeCode,
       b.StatusCode, b.StartDateUtc, b.EndDateUtc,
       b.InitiatedBy
FROM audit.LoadBatch b
WHERE b.BatchTypeCode = 'SEED'
ORDER BY b.LoadBatchId;

/* ============ Result 3: RACI coverage by system ============ */
SELECT ss.SourceSystemCode,
       ss.SourceSystemName,
       gr.RoleCode,
       p.PartyName,
       ra.RaciCode
FROM gov.RoleAssignment ra
JOIN gov.SourceSystem ss ON ss.SourceSystemId = ra.EntityId
JOIN gov.GovernanceRole gr
  ON gr.GovernanceRoleId = ra.GovernanceRoleId
JOIN gov.Party p ON p.PartyId = ra.PartyId
WHERE ra.EntityTypeCode = 'SOURCE_SYSTEM'
ORDER BY ss.SourceSystemCode,
         CASE gr.RoleCode
              WHEN 'DATA_OWNER' THEN 1
              WHEN 'DATA_STEWARD' THEN 2
              ELSE 3 END;

/* ============ Result 4: FV7 registry profile ============ */
SELECT s.ComponentCode,
       s.SectionCode,
       s.SectionName,
       s.ScopeLevelCode,
       COUNT(i.RegulatoryReportItemId) AS ItemCount,
       SUM(CAST(i.CalculatedFlag AS INT)) AS CalculatedItems
FROM gov.RegulatoryReportSection s
JOIN gov.RegulatoryReport r
  ON r.RegulatoryReportId = s.RegulatoryReportId
LEFT JOIN gov.RegulatoryReportItem i
  ON i.RegulatoryReportSectionId =
     s.RegulatoryReportSectionId
WHERE r.ReportCode = 'MCR_FV7'
GROUP BY s.ComponentCode, s.SectionCode, s.SectionName,
         s.ScopeLevelCode
ORDER BY MIN(s.RegulatoryReportSectionId);
GO
