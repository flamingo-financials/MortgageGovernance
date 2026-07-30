# Evidence Pack

Every claim this portfolio makes, the query that proves it,
and the result to expect. Run against `MortgageGovernance`.

Two rules govern this document. A claim with no query behind
it does not belong here. An expected result that cannot be
predicted honestly is written as unknown rather than
invented.

Servicing as-of date is 2026-07-31. Filing period end is
2026-06-30. They are different dates on purpose and several
results below only reconcile when the right one is used.

---

## 1. A blocking DQ rule passed while $10.76M left the filing

The single most useful finding in the build. Threshold data
quality and reconciliation control disagreed, and the
reconciliation control was right.

### 1a. The rule that passed

```sql
SELECT AsOfDate, RuleCode, RuleName, BlockingFlag,
       DataElementCode, CdeFlag, EvaluatedRowCount,
       FailedRowCount, PassRatePct, ThresholdValue,
       StatusCode, RuleOwner, RuleSteward
FROM dq.vw_RuleResultLatest
WHERE RuleCode = 'DQR02';
```

Expected: `StatusCode` PASS, `BlockingFlag` 1,
`PassRatePct` 0.996333 against `ThresholdValue` 0.9900,
`FailedRowCount` 48 of 13,090 evaluated.

`PassRatePct` is a rate, not a percentage, despite the
column name. Compare it to `ThresholdValue` on the same
scale.

### 1b. The controls that failed

```sql
SELECT ControlCode, ControlName, ControlTypeCode,
       ToleranceTypeCode, BlockingFlag, AsOfDate,
       SourceValue, TargetValue, VarianceValue,
       StatusCode, ControlOwner
FROM audit.vw_ReconciliationLatest
WHERE ControlTypeCode = 'MCR_TIEOUT'
  AND AsOfDate = '2026-06-30'
ORDER BY StatusCode, ControlCode;
```

Expected: 10 rows, 6 FAIL and 4 PASS, every row
`ToleranceTypeCode` EXACT and `BlockingFlag` 1.

| Control | Status | Variance |
|---|---|---|
| RC_MCR_SVC_UPB | FAIL | -10,764,902 |
| RC_MCR_SVC_CNT | FAIL | -36 |
| RC_MCR_OWN_UPB | FAIL | -10,764,902 |
| RC_MCR_OWN_CNT | FAIL | -36 |
| RC_MCR_STG_COMPLETE | FAIL | -36 |
| RC_MCR_ELEM_PRESENT | FAIL | -2 |
| RC_MCR_GRID_UPB | PASS | 0 |
| RC_MCR_GRID_CNT | PASS | 0 |
| RC_MCR_FC_UPB | PASS | 0 |
| RC_MCR_FC_CNT | PASS | 0 |

Filter on `AsOfDate`. At 2026-07-31 this returns a different
set and a different pass rate, because two controls carried
over from script 021 are typed MCR_TIEOUT but compare src to
dw. See section 9.

### 1c. The issue that owns the failure

```sql
SELECT i.DataIssueId, i.IssueTitle, i.SeverityCode,
       i.StatusCode, i.OpenedDate, i.TargetResolutionDate,
       i.ClosedDate, i.DqRuleReference,
       Owner = p.PartyName
FROM gov.DataIssue i
LEFT JOIN gov.Party p ON p.PartyId = i.OwnerPartyId
WHERE i.DataIssueId = 5;
```

Expected: `StatusCode` NEW, `SeverityCode` HIGH, owner
Marco Ibis, `OpenedDate` 2026-07-27,
`TargetResolutionDate` 2026-08-26, `ClosedDate` NULL.

NEW rather than OPEN. A high-severity issue holding six
blocking controls has not been triaged past intake, which is
itself worth saying out loud rather than editing away.

### 1d. DQR02 is absent from the blocking failure surface

```sql
SELECT AsOfDate, RuleCode, RuleName, SeverityCode,
       DataElementCode, FailedRowCount, PassRatePct,
       ThresholdValue
FROM dq.vw_BlockingFailureLatest
ORDER BY AsOfDate DESC, RuleCode;
```

Expected: DQR02 does not appear, because it passed. DQR21
does not appear either, because the six MCR rules are
non-blocking by design. If DQR21 appears here, the
non-blocking design has failed and `dw.usp_RunPipeline` can
drag the servicing report to NOT_CERTIFIED on a filing
finding.

### What a reviewer will push on

*"Your threshold was too loose."* Tightening it does not fix
this. At 100 percent DQR02 fails on 48 rows, 12 of which
never reached the filing at all because the loans were
inactive at period end. The rule and the control measure
different populations against different obligations. That is
the argument for running both, not for retuning one.

**Capture:** 1a and 1b side by side in one screenshot.

---

## 2. Three certification scopes, three different answers

```sql
SELECT c.EntityTypeCode, c.EntityReference,
       c.CertificationStatusCode, c.DataAsOfDate,
       EvidenceRows =
           (SELECT COUNT(*)
            FROM gov.CertificationEvidence e
            WHERE e.CertificationId = c.CertificationId)
FROM gov.Certification c
ORDER BY c.EntityTypeCode, c.EntityReference;
```

Expected:

| EntityTypeCode | EntityReference | Status | As-of | Evidence |
|---|---|---|---|---|
| DATASET | DP_MCR_FV7 | CERTIFIED | 2026-07-27 | |
| REGULATORY_FILING | MCR_FV7_2026002 | NOT_CERTIFIED | 2026-06-30 | 11 |
| REPORT | PBI_SVC_GOV | CERTIFIED_WITH_EXCEPTIONS | 2026-07-31 | 140 |

### What a reviewer will push on

*"How can the data product be certified when the filing
built on it is not?"* Because they certify different things.
The product certifies that the registry is reconciled, every
eligible item is classified and owned, and the controls
execute. The filing certifies that this quarter's numbers
tie out. `reg.usp_CertifyMcrDataProduct` runs five gates and
none of them is a filing tie-out.

The scopes cannot contaminate each other because filing
controls execute at the filing period end and
`gov.usp_CertifyReport` filters reconciliation results on
its own as-of date.

**Capture:** the three-row result.

---

## 3. Coverage stated as classification, never as a ratio

```sql
SELECT CoverageStatusCode, TargetProjectCode,
       CoverageStatusName, Items, TraceableItems,
       RequiredDomains, AccountableStewards, StewardList
FROM pbi.vw_McrCoverageSummary
ORDER BY CoverageStatusCode, TargetProjectCode;
```

Expected 6 rows summing to 513:

| Status | Project | Items |
|---|---|---|
| SUPPORTED_NOW | PROJECT_1 | 120 |
| PLANNED | PROJECT_2 | 101 |
| PLANNED | PROJECT_3 | 263 |
| NOT_APPLICABLE | NONE | 26 |
| EXTERNAL_DEFERRED | NONE | 2 |
| NARRATIVE | NONE | 1 |

`SUPPORTED_NOW` must equal `TraceableItems` on that row.
If they diverge, an item is classified as supported without
element lineage behind it.

### 3a. Internal consistency

```sql
SELECT
    SupportedNowItems =
        (SELECT COUNT(*)
         FROM reg.McrCoverageClassification
         WHERE CoverageStatusCode = 'SUPPORTED_NOW'),
    TraceableItems =
        (SELECT COUNT(DISTINCT ItemCode)
         FROM reg.McrElementLineage
         WHERE CoverageCode = 'FULL'),
    ClassifiedItems =
        (SELECT COUNT(*)
         FROM reg.McrCoverageClassification),
    EligibleItems =
        (SELECT COUNT(*) FROM reg.vw_McrBridgeReview
         WHERE LineageEligibleFlag = 1);
```

Expected 120, 120, 513, 513.

### 3b. No item is unexplained

```sql
SELECT UnexplainedItems = COUNT(*)
FROM pbi.vw_McrItemCoverage
WHERE LineageEligibleFlag = 1
  AND (CoverageStatusCode IS NULL
    OR AccountableSteward IS NULL);
```

Expected 0.

### What a reviewer will push on

*"So you covered 23 percent."* The percentage is not the
claim. The claim is that 393 items are named, assigned to a
project, given a required domain and a written rationale,
and attached to an accountable steward. A number that cannot
be produced yet and is documented as such is worth more than
one that is manufactured.

**Capture:** 3 and 3b together.

---

## 4. Regulatory line item to source column

```sql
SELECT TOP 20 ItemCode, ItemLabel, ElementName,
       GovernedElement, CriticalDataElementFlag,
       SourceSystem, SourceColumn, WarehouseColumn,
       CoverageCode
FROM pbi.vw_McrElementLineage
WHERE CoverageCode = 'FULL'
ORDER BY ItemCode, ElementName;
```

Expected: rows carrying a source system, a source column and
a warehouse column for every filed element.

Full lineage coverage distribution:

```sql
SELECT CoverageCode, Rows = COUNT(*),
       Items = COUNT(DISTINCT ItemCode)
FROM reg.McrElementLineage
GROUP BY CoverageCode
ORDER BY Rows DESC;
```

Expected: FULL 1,262 rows across 120 items, UNMAPPED 1,000
across 393, DW_ONLY 156 across 42, ELEMENT_ONLY 131 across
36.

**Capture:** the FULL sample. This is the answer to "can an
auditor trace the reported number to source data."

---

## 5. The filing tie-out in one result set

```sql
SELECT TOP 30 * FROM pbi.vw_McrFilingTieOut;
```

Regulatory line item, governance-computed value, filed
value, signed variance and the registered derivation rule
that produced it, on one row.

Expected 30 rows for filing 2026002, two per line item, one
AMOUNT and one COUNT. `TieOutStatus` takes three values:
MATCH, VARIANCE, and ABSENT FROM FILING.

Ownership grid, `DRV_MCROWNSHIP`. Every line carries a
variance, and the four decompose exactly into the aggregate
control:

| Line | Governance | Filed | Count variance | Amount variance |
|---|---|---|---|---|
| LS010 | 1,382 | 1,376 | -6 | -1,798,160 |
| LS020 | 6,155 | 6,147 | -8 | -2,689,228 |
| LS030 | 3,138 | 3,119 | -19 | -5,155,147 |
| LS040 | 539 | 536 | -3 | -1,122,367 |
| | | | **-36** | **-10,764,902** |

That the four lines sum to the control value is the check
worth pointing at. It means the aggregate failure is not an
independent calculation, it is the same 36 loans arriving
four different ways.

Delinquency grid, `DRV_MCRDELINQ`:

| Line | Governance | Filed | Status |
|---|---|---|---|
| LS200 Current | 10,798 | 10,762 | VARIANCE -36 |
| LS210 30-59 | 98 | 98 | MATCH |
| LS220 60-89 | 35 | 35 | MATCH |
| LS230 90+ | 283 | 283 | MATCH |

All 36 excluded loans were current at period end, so the
entire variance lands on LS200 and the three delinquency
lines tie to the cent. A reviewer who assumes the exclusion
was random will expect variance spread across all four. It is
not random; it is a state reference gap, and current loans
are the bulk of the book.

Foreclosure grid, `DRV_MCRFCINV`: LS1300 FNMA, LS1310 FHLMC,
LS1320 GNMA and LS1340 Other all MATCH. LS1330 Private Label
returns ABSENT FROM FILING at a zero population, because the
loader emits no row for an empty category. An absent line and
an unreported line are indistinguishable on the wire.
`RC_MCR_ELEM_PRESENT` catches it: 26 submittable elements
expected, 24 present, variance -2.

LS290 Total Loans Serviced and LS1390 Total Foreclosed Loans
also read ABSENT FROM FILING, but with `NmlsDerivedFlag` 1.
Those are calculated by NMLS and have no submittable element,
so absence is correct. LS1330 is absent with the flag at 0,
which is the defect. The column is what distinguishes them.

### The rounding proof

The `RoundingEffect` column runs in both directions:
LS230 +5.43, LS1320 -5.51, LS020 +38.42, LS290 +81.28.

Truncation can only lose value. A positive residual is
impossible under it. This is why the conversion is treated as
ROUND, matched on both sides through
`NumValueFiledBasis`, and why all ten controls are EXACT.

### What a reviewer will push on

*"Your variance is a rounding artifact."* It is not. NMLS
requires whole dollars and `mcr_04` rejects a non-integer
PositiveDollar, so the conversion is a form requirement,
matched on both sides through
`reg.McrInternalValue.NumValueFiledBasis` rather than
absorbed into a tolerance. Rounding across 11,214 loans
moves +$81.28. The variance is -$10,764,902. The conversion
is ROUND, not truncation, proved by a +5.43 signed residual
on LS230 that truncation cannot produce.

All ten MCR controls are EXACT for this reason. There is no
tolerance to hide in.

**Capture:** the tie-out result set. It is the single
strongest artifact in the portfolio.

---

## 6. The bridge is closed

Two independent FV7 registries reconciled to zero
unexplained items.

```sql
SELECT MatchStatusCode, Items = COUNT(*)
FROM reg.McrItemBridge
GROUP BY MatchStatusCode
ORDER BY Items DESC;
```

Expected: MATCHED 635, MATCHED_LIST 5, GOV_ONLY 8. MCR_ONLY
returns no row at all, which is the zero. A `GROUP BY` cannot
emit a row for a value that does not occur.

`MCR_ONLY` at zero is the assertion that nothing in the
submission structure lacks a governed business definition.
A non-zero value means the engine can file something the
governance layer has never defined.

### 6a. Lineage scope, why each item is or is not eligible

```sql
SELECT LineageScopeCode, Items = COUNT(*)
FROM reg.vw_McrBridgeReview
GROUP BY LineageScopeCode
ORDER BY Items DESC;
```

Expected: SOURCE_LINEAGE 508, NMLS_DERIVED 124,
ANNOTATION 5, LIST_DETAIL 5, ALIAS 3, COVERAGE_DEFERRED 2,
DEPRECATED 1. Total 648, eligible 513.

UNRESOLVED returns no row. Any UNRESOLVED row is a defect.

**Capture:** both results.

---

## 7. Derivation rule inputs, fully accounted

Business logic registers once, in `gov.DerivationRule`. Every
input is either bound to a governed data element or belongs
to a named category that cannot be.

```sql
SELECT LayerPrefix = LEFT(i.InputReference,
         CHARINDEX('.', i.InputReference + '.') - 1),
       Inputs = COUNT(*),
       Bound  = COUNT(i.DataElementId)
FROM gov.DerivationRuleInput i
GROUP BY LEFT(i.InputReference,
         CHARINDEX('.', i.InputReference + '.') - 1)
ORDER BY Inputs DESC;
```

Expected: 153 inputs, 109 bound, 44 unbound.

| Category | Inputs | Why unbound |
|---|---|---|
| Source layer columns | 101 | Bound |
| Warehouse columns, source-anchored | 8 | Bound |
| Warehouse-derived attributes | 7 | Calendar flags, SCD2 technical columns, ref-driven codes and population gates that originate in the warehouse and have no source-system element |
| Object references | 23 | `ref`, `gov`, `dq`, `audit` objects, not columns |
| Rule outputs | 11 | Produced by an upstream rule and consumed downstream |
| Parameters | 3 | `@AsOfDate`, `@FromDate` |

The bindable ceiling is 109 and it is met. The seven
warehouse-derived inputs are `dw.DimDate.IsBusinessDay`,
`dw.DimDelinquencyStatus.DelinquencyBucketCode`,
`dw.DimLeadSource.MarketingSourcedFlag`,
`dw.DimLeadSource.ReferralFlag`,
`dw.DimLoanOfficer.EffectiveStartDate`,
`dw.DimServicingType.ServicingTypeCode` and
`dw.FactLoanMonthEndSnapshot.ActiveServicingFlag`.

### What a reviewer will push on

*"Why not just bind everything?"* Because binding a
warehouse-generated calendar flag to a governed data element
would assert a source system that does not exist. The
category is the honest answer; a forced binding would be
fake lineage.

**Capture:** the layer result plus this table.

---

## 8. MISMO is mapped, not compliant

```sql
SELECT MismoVersion, Mappings = COUNT(*)
FROM gov.MismoMapping
GROUP BY MismoVersion;
```

Expected: 3.6.3, 153 rows.

```sql
SELECT Basis = LEFT(MappingNotes,
         CHARINDEX(':', MappingNotes + ':') - 1),
       Mappings = COUNT(*)
FROM gov.MismoMapping
GROUP BY LEFT(MappingNotes,
         CHARINDEX(':', MappingNotes + ':') - 1)
ORDER BY Mappings DESC;
```

Expected four categories summing to 153: CANDIDATE 73,
EXTENSION 49, PUBLIC_SOURCE 27, NOT_APPLICABLE 4.

CANDIDATE means the data point name follows MISMO v3 naming
convention but was not verified against the member-only
Logical Data Dictionary, which was not accessed. Version
verified at mismo.org on 2026-07-23.

### What a reviewer will push on

*"Is this MISMO compliant?"* No. It is MISMO-aligned and
MISMO-mapped, and 73 of 153 names are explicitly flagged as
unverified in the database itself. Compliance would require
validation against the LDD and is not claimed anywhere in
this repository.

**Capture:** the basis breakdown. A governance artifact that
records its own uncertainty is the point.

---

## 9. Known defects, published rather than hidden

### 9a. Control taxonomy

```sql
SELECT ControlCode, ControlTypeCode, AsOfDate, StatusCode
FROM audit.vw_ReconciliationLatest
WHERE ControlCode IN ('RC_MCR_LS010_COUNT',
                      'RC_MCR_LS010_UPB');
```

Expected: both typed MCR_TIEOUT, both at `AsOfDate`
2026-07-31. They compare src to dw and never touch `mcr.*`,
so they are mistyped. Consequence: the regulatory
reconciliation metric returns 100 percent at 2026-07-31 and
40 percent at 2026-06-30. Any dashboard reading it must
filter on as-of. Retyping them SRC_TO_DW is open.

### 9b. Exception register

```sql
SELECT StatusCode, Exceptions = COUNT(*)
FROM dq.DataException
GROUP BY StatusCode;
```

Expected 33 rows total: 30 MCR findings routed by
`reg.usp_RouteMcrExceptions` and 3 accepted-risk carryovers
from script 024.

```sql
SELECT RuleCode, RuleName, SeverityCode, BlockingFlag,
       StatusCode, OpenedDate, DueDate, AgeDays,
       OverdueFlag, ExceptionOwner,
       FilingCertificationStatus
FROM pbi.vw_McrExceptionRegister
ORDER BY RuleCode, KeyValue1;
```

Every row carries the filing certification status beside it.
A coverage or exception figure cannot be read here without
the filing state next to it.

### 9c. Script 020 destroys DQ state on re-run

Not a query. Script 020 opens with `DELETE FROM dq.[Rule]`
and `DELETE FROM dq.DataException`. Re-running it destroys
DQR21 through DQR26 and all 30 routed exceptions. Recovery
is re-running 042.

---

## 10. The published surface

```sql
SELECT PbiViews = COUNT(*)
FROM sys.views v
JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'pbi';
```

Expected 41: 34 from script 022 and 7 from script 043.

```sql
SELECT DataProductCode, ProductCertificationStatus,
       ProductCertifiedBy, TotalFv7Items,
       LineageEligibleItems, TraceableToSourceItems,
       LatestGovernedFilingId, FilingCertificationStatus,
       FilingBlockingFailures, FilingValidationErrors
FROM pbi.vw_McrDataProduct;

SELECT CoverageStatement, ScopeCaveat
FROM pbi.vw_McrDataProduct;
```

Expected: product CERTIFIED, filing NOT_CERTIFIED, 648 total
items, 513 eligible, 120 traceable, 6 blocking failures,
30 validation errors.

Uncertified objects do not enter `pbi`. The seven MCR views
entered only after `DP_MCR_FV7` passed its five gates, and
each carries `FilingCertificationStatus` so a coverage figure
cannot be read without the filing state beside it.

**Capture:** both result sets. The coverage statement and
scope caveat are written prose in the database, not in a
document, which is the difference between governance
metadata and governance documentation.

---

## Screenshot list

Minimum set for the portfolio, in this order:

1. DQR02 PASS and the six failing MCR controls, together
2. `gov.Certification`, three scopes
3. `pbi.vw_McrFilingTieOut`
4. `pbi.vw_McrCoverageSummary` with the unexplained-items
   check at zero
5. `pbi.vw_McrElementLineage` FULL sample
6. `reg.McrItemBridge` match status with MCR_ONLY at zero
7. `gov.DataIssue` 5, open and owned
8. MISMO basis breakdown showing 73 CANDIDATE

Eight images. Each answers a question a governance
interviewer will actually ask, and none of them requires the
verbal explanation to be true.
