/* ============================================================
   MortgageGovernance | Portfolio evidence capture
   Eight screenshots. Read-only. Nothing here writes.

   Run one section at a time. Highlight the section, press
   F5, capture the result grid. Do not run the whole file at
   once; SSMS will stack 12 grids and the screenshots become
   useless.

   Every section states its expected result. If a number
   disagrees, stop and note which one before capturing. A
   screenshot of a number you cannot explain is worse than no
   screenshot.

   Sections are separated by GO so a failure in one does not
   stop the rest.

   Servicing as-of is 2026-07-31. Filing period end is
   2026-06-30. Section 1 depends on using the right one.
   ============================================================ */
SET NOCOUNT ON;
GO


/* ============================================================
   SCREENSHOT 1 of 8
   The passing rule and the failing controls, same period.

   CAPTURE BOTH GRIDS IN ONE IMAGE. This is the single most
   important artifact in the portfolio and it only works as a
   pair. Run both statements together.
   ============================================================ */

/* 1a. Expected: StatusCode PASS, BlockingFlag 1,
       PassRatePct 0.996333, ThresholdValue 0.9900,
       FailedRowCount 48, EvaluatedRowCount 13090. */
SELECT AsOfDate, RuleCode, RuleName, BlockingFlag,
       DataElementCode, CdeFlag, EvaluatedRowCount,
       FailedRowCount, PassRatePct, ThresholdValue,
       StatusCode, RuleOwner, RuleSteward
FROM dq.vw_RuleResultLatest
WHERE RuleCode = 'DQR02';

/* 1b. Expected: 10 rows, 6 FAIL and 4 PASS, every row
       ToleranceTypeCode EXACT and BlockingFlag 1.
         RC_MCR_SVC_UPB       FAIL  -10,764,902
         RC_MCR_SVC_CNT       FAIL          -36
         RC_MCR_OWN_UPB       FAIL  -10,764,902
         RC_MCR_OWN_CNT       FAIL          -36
         RC_MCR_STG_COMPLETE  FAIL          -36
         RC_MCR_ELEM_PRESENT  FAIL           -2
         RC_MCR_GRID_UPB      PASS            0
         RC_MCR_GRID_CNT      PASS            0
         RC_MCR_FC_UPB        PASS            0
         RC_MCR_FC_CNT        PASS            0 */
SELECT ControlCode, ControlName, ControlTypeCode,
       ToleranceTypeCode, BlockingFlag, AsOfDate,
       SourceValue, TargetValue, VarianceValue,
       StatusCode, ControlOwner
FROM audit.vw_ReconciliationLatest
WHERE ControlTypeCode = 'MCR_TIEOUT'
  AND AsOfDate = '2026-06-30'
ORDER BY StatusCode, ControlCode;
GO


/* ============================================================
   SCREENSHOT 2 of 8
   Three certification scopes, three different answers.

   Expected 3 rows:
     DATASET            DP_MCR_FV7       CERTIFIED
     REGULATORY_FILING  MCR_FV7_2026002  NOT_CERTIFIED
                                         as-of 2026-06-30
     REPORT             PBI_SVC_GOV      CERTIFIED_WITH_
                                         EXCEPTIONS
                                         as-of 2026-07-31
   ============================================================ */
SELECT EntityTypeCode, EntityReference,
       CertificationStatusCode, DataAsOfDate
FROM gov.Certification
ORDER BY EntityTypeCode, EntityReference;
GO


/* ============================================================
   SCREENSHOT 3 of 8
   The filing tie-out. Regulatory line item, governance
   value, filed value, signed variance, derivation rule.

   Expected: every row carries a registered derivation rule.
   Company-scope filed values for filing 2026002:
     LS010   1,376 /   483,508,316
     LS020   6,147 / 2,163,770,615
     LS030   3,119 / 1,126,625,347
     LS040     536 /   186,864,974
     LS200  10,762 / 3,803,948,644
     LS210      98 /    35,864,769
     LS220      35 /    13,741,981
     LS230     283 /   107,213,858
   Governance recompute is higher on LS010, LS020, LS030,
   LS040 and LS200. Every difference is the same 36 loans.
   ============================================================ */
SELECT TOP 40 * FROM pbi.vw_McrFilingTieOut;
GO


/* ============================================================
   SCREENSHOT 4 of 8
   Coverage as classification. Capture both grids together.

   4a expected 6 rows summing to 513:
     SUPPORTED_NOW      PROJECT_1  120
     PLANNED            PROJECT_2  101
     PLANNED            PROJECT_3  263
     NOT_APPLICABLE     NONE        26
     EXTERNAL_DEFERRED  NONE         2
     NARRATIVE          NONE         1
   On the SUPPORTED_NOW row, Items must equal TraceableItems.

   4b expected 0. Non-zero means an eligible item has no
   coverage status or no accountable steward.
   ============================================================ */
SELECT * FROM pbi.vw_McrCoverageSummary
ORDER BY CoverageStatusCode, TargetProjectCode;

SELECT UnexplainedItems = COUNT(*)
FROM pbi.vw_McrItemCoverage
WHERE LineageEligibleFlag = 1
  AND (CoverageStatusCode IS NULL
    OR AccountableSteward IS NULL);
GO


/* ============================================================
   SCREENSHOT 5 of 8
   Regulatory line item to source column. The answer to
   "can an auditor trace the filed number to source data."

   Expected: every row carries a source system, a source
   column and a warehouse column.
   ============================================================ */
SELECT TOP 25 ItemCode, ItemLabel, ElementName,
       GovernedElement, CriticalDataElementFlag,
       SourceSystem, SourceColumn, WarehouseColumn,
       CoverageCode
FROM pbi.vw_McrElementLineage
WHERE CoverageCode = 'FULL'
ORDER BY ItemCode, ElementName;
GO


/* ============================================================
   SCREENSHOT 6 of 8
   Two registries reconciled. Capture both grids together.

   6a expected: MATCHED 635, MATCHED_LIST 5, GOV_ONLY 8,
       MCR_ONLY 0. Zero MCR_ONLY is the claim that nothing
       the engine can file lacks a governed definition.

   6b expected: SOURCE_LINEAGE 508, NMLS_DERIVED 124,
       ANNOTATION 5, LIST_DETAIL 5, ALIAS 3,
       COVERAGE_DEFERRED 2, DEPRECATED 1, and no
       UNRESOLVED row at all. Total 648.
   ============================================================ */
SELECT MatchStatusCode, Items = COUNT(*)
FROM reg.McrItemBridge
GROUP BY MatchStatusCode
ORDER BY Items DESC;

SELECT LineageScopeCode, Items = COUNT(*)
FROM reg.vw_McrBridgeReview
GROUP BY LineageScopeCode
ORDER BY Items DESC;
GO


/* ============================================================
   SCREENSHOT 7 of 8
   The open issue that owns six failing controls.

   Expected: DataIssueId 5, StatusCode OPEN, SeverityCode
   HIGH, Owner Marco Ibis, TargetResolutionDate 2026-08-26,
   ClosedDate NULL.

   This is the one that proves the failure is governed rather
   than merely present.
   ============================================================ */
SELECT i.DataIssueId, i.IssueTitle, i.SeverityCode,
       i.StatusCode, i.OpenedDate,
       i.TargetResolutionDate, i.ClosedDate,
       i.DqRuleReference, Owner = p.PartyName
FROM gov.DataIssue i
LEFT JOIN gov.Party p ON p.PartyId = i.OwnerPartyId
WHERE i.DataIssueId = 5;
GO


/* ============================================================
   SCREENSHOT 8 of 8
   MISMO mapped, not compliant. Capture both grids together.

   8a expected: 3.6.3 with 153 mappings.

   8b expected: four bases summing to 153, of which
       CANDIDATE is 73. The split among PUBLIC_SOURCE,
       EXTENSION and NOT_APPLICABLE is not predicted.

   CANDIDATE means the data point name follows MISMO v3
   convention but was never verified against the member-only
   Logical Data Dictionary. The uncertainty is recorded in
   the data, not in a footnote. That is the point of the
   screenshot.
   ============================================================ */
SELECT MismoVersion, Mappings = COUNT(*)
FROM gov.MismoMapping
GROUP BY MismoVersion;

SELECT Basis = LEFT(MappingNotes,
         CHARINDEX(':', MappingNotes + ':') - 1),
       Mappings = COUNT(*)
FROM gov.MismoMapping
GROUP BY LEFT(MappingNotes,
         CHARINDEX(':', MappingNotes + ':') - 1)
ORDER BY Mappings DESC;
GO


/* ============================================================
   OPTIONAL 9. Not a screenshot. A cross-check.

   Run this before you capture anything. If any row returns
   MISMATCH, the number in the evidence pack is stale and the
   screenshot would be wrong.
   ============================================================ */
WITH Chk AS (
    SELECT Metric = 'Supported now items',
           Actual = (SELECT COUNT(*)
                     FROM reg.McrCoverageClassification
                     WHERE CoverageStatusCode
                           = 'SUPPORTED_NOW'),
           Expected = 120
    UNION ALL
    SELECT 'Traceable items',
           (SELECT COUNT(DISTINCT ItemCode)
            FROM reg.McrElementLineage
            WHERE CoverageCode = 'FULL'), 120
    UNION ALL
    SELECT 'Classified items',
           (SELECT COUNT(*)
            FROM reg.McrCoverageClassification), 513
    UNION ALL
    SELECT 'Lineage eligible items',
           (SELECT COUNT(*) FROM reg.vw_McrBridgeReview
            WHERE LineageEligibleFlag = 1), 513
    UNION ALL
    SELECT 'Governed FV7 items',
           (SELECT COUNT(*) FROM reg.vw_McrBridgeReview),
           648
    UNION ALL
    SELECT 'Published pbi views',
           (SELECT COUNT(*) FROM sys.views v
            JOIN sys.schemas s
              ON s.schema_id = v.schema_id
            WHERE s.name = 'pbi'), 41
    UNION ALL
    SELECT 'Element bindings',
           (SELECT COUNT(*)
            FROM gov.DataElementBinding), 288
    UNION ALL
    SELECT 'Derivation rule inputs',
           (SELECT COUNT(*)
            FROM gov.DerivationRuleInput), 153
    UNION ALL
    SELECT 'Rule inputs bound',
           (SELECT COUNT(DataElementId)
            FROM gov.DerivationRuleInput), 109
    UNION ALL
    SELECT 'Open data exceptions',
           (SELECT COUNT(*) FROM dq.DataException), 33
    UNION ALL
    SELECT 'Active DQ rules',
           (SELECT COUNT(*) FROM dq.[Rule]), 26
)
SELECT Metric, Actual, Expected,
       Result = CASE WHEN Actual = Expected
                     THEN 'OK' ELSE 'MISMATCH' END
FROM Chk
ORDER BY Result, Metric;
GO
