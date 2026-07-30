# MortgageGovernance

Mortgage servicing data governance, certified analytics, and
NMLS Mortgage Call Report FV7 regulatory readiness.

Portfolio Project 1 for Flamingo Financials LLC, a synthetic
mid-size mortgage servicer. Everything below is produced by
the scripts in this repository and is reproducible from them.
No number in this README is illustrative.

---

## What this is

An enterprise governance chain built end to end in Azure SQL
Database and carried all the way through to a regulatory
filing:

```
10 source systems
  -> governed dimensional warehouse
  -> governance metadata (elements, CDEs, ownership, RACI)
  -> MISMO v3.6.3 mapping
  -> executable data quality
  -> reconciliation controls
  -> certified pbi view layer
  -> NMLS MCR FV7 filing engine
  -> filing certification
```

The point of the build is not that the numbers are green.
The point is that when they are not green, the reason is
named, owned, dated and traceable to a source column.

---

## Start here: four findings

### 1. A passing DQ rule beside a $10.76M filing omission

In the same reporting period:

| Evidence | Value |
|---|---|
| DQR02 (blocking DQ rule) | **PASS**, 0.996333 vs 0.9900 threshold |
| Failed rows behind that PASS | 48 of 13,090 |
| Loans dropped from the MCR filing | **36** |
| UPB dropped from the MCR filing | **$10,764,820.72** |

The 36 loans carry a `PropertyStateCode` that is absent from
`ref.State`. `reg.usp_StageMcrServicingPortfolio` will not
invent a state for a regulatory filing, so it excludes them
and the reconciliation controls report the gap.

Threshold-based data quality reported this as acceptable.
Reconciliation control did not. That is the argument for
running both, and it is the single most useful thing in this
repository.

Tracked as `gov.DataIssue` 5. Status NEW, severity HIGH,
owner Marco Ibis, opened 2026-07-27, due 2026-08-26. It is
not closed by widening a threshold.

All 36 excluded loans were current at period end. That is why
the delinquency grid variance falls entirely on LS200 and the
three delinquency lines tie exactly.

### 2. Three certification scopes, three different answers

All three live in `gov.Certification` and none absolves
another.

| Scope | Entity | Status | Data as-of |
|---|---|---|---|
| REPORT | PBI_SVC_GOV | CERTIFIED_WITH_EXCEPTIONS | 2026-07-31 |
| REGULATORY_FILING | MCR_FV7_2026002 | **NOT_CERTIFIED** | 2026-06-30 |
| DATASET | DP_MCR_FV7 | CERTIFIED | 2026-07-27 |

The data product is certified because its metadata layer is
reconciled and every item is classified and owned. The
filing built on it is not certified, because six blocking
controls fail. A certified dataset does not certify a
filing, and the schema is built so the two cannot be
confused: filing controls execute at the filing period end,
never at the servicing as-of, and `gov.usp_CertifyReport`
filters reconciliation results on its own as-of date.

```sql
SELECT EntityTypeCode, EntityReference,
       CertificationStatusCode, DataAsOfDate
FROM gov.Certification
ORDER BY EntityTypeCode, EntityReference;
```

### 3. Coverage as classification, never as a bare ratio

513 of the 648 governed MCR FV7 items are lineage eligible.
120 of them are traceable to source today. The remaining 393
are not hidden and are not rounded away:

| Coverage status | Project | Items |
|---|---|---|
| SUPPORTED_NOW | PROJECT_1 | 120 |
| PLANNED | PROJECT_2 | 101 |
| PLANNED | PROJECT_3 | 263 |
| NOT_APPLICABLE | NONE | 26 |
| EXTERNAL_DEFERRED | NONE | 2 |
| NARRATIVE | NONE | 1 |

Every row carries a required domain, a written rationale and
a named accountable steward. `pbi.vw_McrCoverageSummary`
returns one row per status and never exposes a lone
percentage.

```sql
SELECT CoverageStatusCode, TargetProjectCode, Items,
       TraceableItems, RequiredDomains, StewardList
FROM pbi.vw_McrCoverageSummary
ORDER BY CoverageStatusCode, TargetProjectCode;
```

### 4. Regulatory line to source column, one result set

```sql
SELECT TOP 10 ItemCode, ItemLabel, ElementName,
       GovernedElement, CriticalDataElementFlag,
       SourceSystem, SourceColumn, WarehouseColumn,
       CoverageCode
FROM pbi.vw_McrElementLineage
WHERE CoverageCode = 'FULL'
ORDER BY ItemCode, ElementName;
```

`pbi.vw_McrFilingTieOut` does the same for values: the
regulatory line item, the governance-computed value, the
filed value, the signed variance and the registered
derivation rule that produced it, side by side.

---

## Environment

Azure SQL Database, serverless, General Purpose Gen5.
`SERVERPROPERTY('EngineEdition') = 5`.

Single database, `MortgageGovernance`. Consequences that are
enforced throughout the scripts:

- No `USE`, no `CREATE DATABASE`, no three-part names.
- No SQL Agent. Orchestration is stored procedures invoked
  by the operator.
- RCSI on by default.
- Serverless auto-pause keeps a portfolio database near zero
  cost between sessions.

Scripts 002 through 024 were authored against a local
instance and still carry `USE MortgageGovernance;`. They are
deployed and verified in Azure; the repo conversion is
pending. `tools/Convert-GovScriptsToAzure.ps1` performs it.

---

## Schemas

| Schema | Owns |
|---|---|
| src | Raw source-aligned data, 10 systems |
| stg | Transformation staging |
| ref | Controlled reference and crosswalk values |
| dw | Governed dimensional warehouse |
| gov | Governance metadata |
| dq | Data quality rules, executions, exceptions |
| audit | Load batches, errors, reconciliation controls |
| pbi | Certified views, the only Power BI surface |
| reg | Regulatory derivation and controlled outputs |
| ai | AI readiness metadata, Project 2 |
| mcr | MCR FV7 filing engine |
| mcrstg | Governed contract surface, warehouse to engine |
| mcrpbi | Engine-side review views |

Two architectural boundaries do the heavy lifting:

**Governance and engine do not cross.** Governance owns
`dw -> mcrstg` via `reg.usp_StageMcrServicingPortfolio`. The
engine owns `mcrstg -> mcr.*` via `mcr.usp_*`. Governance
never selects from `mcr.*` directly; all reads go through
seven `reg.vw_Mcr*` views.

**Two authorities, one bridge.** `mcr.FieldCatalog` owns
submission structure, generated from the NMLS XSD.
`gov.RegulatoryReportItem` owns business meaning. They are
reconciled in `reg.McrItemBridge`, which is closed:

| Match status | Count |
|---|---|
| MATCHED | 635 |
| MATCHED_LIST | 5 |
| GOV_ONLY | 8 |
| MCR_ONLY | **0** |

Zero MCR_ONLY is the assertion that nothing in the
submission structure lacks a governed business definition.

---

## What is built

**Synthetic enterprise data (script 014)**

13,090 loans, 86,540 leads, 13,956 applications, 345,484
month-end snapshots, 339,150 payment transactions. 11,293
active loans at 2026-07-31, roughly $4.0B UPB.

**Governance registry**

153 governed data elements, 27 CDEs, 148 SRC bindings, 140
DW bindings, 153 authoritative source assignments, 323
element RACI rows, 150 source-to-target rows, 35 approved
business terms, 72 derivation rules.

**Metric catalog**

221 governed metrics across 31 business domains. 68
SUPPORTED with calculation-ready specifications, 74 PLANNED,
79 DEFERRED, each with a project assignment. See
`docs/METRIC_COVERAGE_MATRIX.md`.

**MISMO**

All 153 elements mapped to MISMO Reference Model v3.6.3,
verified at mismo.org on 2026-07-23. The member-only Logical
Data Dictionary was not accessed, so 73 of the 153 mappings
are tagged CANDIDATE pending LDD confirmation and the rest
carry EXTENSION 49, PUBLIC_SOURCE 27 or NOT_APPLICABLE 4 in
`MappingNotes`.

This is MISMO-aligned and MISMO-mapped. It is not validated
for MISMO compliance and is not described as compliant.

**Data quality**

26 rules in `dq.Rule`. DQR21 through DQR26 are MCR rules and
are non-blocking by design, so a filing finding cannot drag
the servicing report certification to NOT_CERTIFIED. 33 open
rows in `dq.DataException`: 30 MCR findings plus 3
accepted-risk carryovers.

**Reconciliation**

10 MCR_TIEOUT controls, all EXACT tolerance, all blocking.
At the 2026-06-30 filing period end: 4 PASS, 6 FAIL.

| Control | Variance |
|---|---|
| RC_MCR_SVC_UPB | -10,764,902 |
| RC_MCR_SVC_CNT | -36 |
| RC_MCR_OWN_UPB | -10,764,902 |
| RC_MCR_OWN_CNT | -36 |
| RC_MCR_STG_COMPLETE | -36 |
| RC_MCR_ELEM_PRESENT | -2 |

Five of the six trace to `gov.DataIssue` 5. The sixth is
LS1330 Private Label, which has a zero population; the
loader emits no row for an empty category, so an absent line
is indistinguishable on the wire from an unreported one.

Tolerances are EXACT on purpose. NMLS requires whole
dollars, and `mcr_04` rejects a non-integer PositiveDollar,
so the whole-dollar conversion is a form requirement matched
on both sides through
`reg.McrInternalValue.NumValueFiledBasis`, not absorbed into
a control tolerance. The conversion is ROUND, not
truncation, confirmed by a +5.43 signed residual on LS230
that truncation cannot produce.

**Certified view layer**

41 views in `pbi`: 34 from script 022 and 7 from script 043.
Uncertified objects do not enter `pbi`. The seven MCR views
entered only after `DP_MCR_FV7` passed its own five-gate
certification, and every one of them carries
`FilingCertificationStatus` so a coverage figure cannot be
read without the filing state beside it.

---

## Filing 2026002

MCRQ2 2026, period 2026-04-01 to 2026-06-30, prior filing
2026001.

| | Loans | UPB |
|---|---|---|
| Warehouse at 2026-06-30 | 11,214 | $3,971,534,072.72 |
| Filed whole-dollar basis | 11,214 | $3,971,534,154 |
| Staged to mcrstg | 11,178 | $3,960,769,252 |
| Excluded | 36 | $10,764,820.72 |

Rounding effect across 11,214 loans is +$81.28.

Validation returns 30 ERROR findings, all COMPLETENESS. Only
AC010, AC020 and AC070 carry `IsRequired = 1` at STATE
scope, which is 3 findings per state across 10 filed states.
Zero WARNING.

---

## What is not claimed

- Not MISMO compliant. Mapped and aligned, with 73 of 153
  data point names recorded as unverified candidates.
- Filing 2026002 is NOT_CERTIFIED and is not fit to submit.
- 393 of 513 lineage-eligible MCR items are not traceable
  today. They are classified, not implemented.
- The report certification is CERTIFIED_WITH_EXCEPTIONS, not
  CERTIFIED.
- No Microsoft Fabric, OneLake or Purview component exists.
  Nothing is provisioned.

---

## Known limitations

- **Control taxonomy.** `RC_MCR_LS010_COUNT` and
  `RC_MCR_LS010_UPB` from script 021 are typed MCR_TIEOUT
  but compare src to dw and never touch `mcr.*`. They sit at
  as-of 2026-07-31, so the regulatory reconciliation metric
  returns 100% at that date and 40% at 2026-06-30. Any
  dashboard reading it must filter on as-of. Retyping them
  SRC_TO_DW is open.
- **Script 020 coupling.** 020 opens with
  `DELETE FROM dq.[Rule]` and `DELETE FROM dq.DataException`.
  Re-running it destroys DQR21 through DQR26 and all 30
  routed exceptions. Recovery is re-running 042.
- **Sparse detail lines.** Whether the loader should emit
  explicit zeros for all FV7 detail lines is undecided.
  `RC_MCR_ELEM_PRESENT` catches the gap today.
- **Filing entity name.** The filing header carries the MCR
  toolkit demo entity, not Flamingo Financials LLC.

---

## Run order

Scripts are idempotent and re-runnable. Run in numeric
order, verifying each before the next.

| Range | Builds |
|---|---|
| 001 | Schemas |
| 002 | Audit framework |
| 003-009 | Governance core, seeds, metric catalog, verify |
| 010-014 | ref tables, src DDL, source registry, DQ engine, synthetic data |
| 015-016 | Warehouse DDL and load procs |
| 017-019 | Bindings, MISMO mapping, regulatory mapping |
| 020 | DQ rules and execution engine |
| 021-024 | Reconciliation, pbi views, end-to-end verify, remediation |
| mcr_01-mcr_15 | MCR FV7 filing engine |
| 030-035 | Bridge, exception closure, element lineage, coverage classification |
| 036-043a | Staging contract, RMLA loader, internal values, filed basis, MCR controls, filing certification, MCR DQ rules, data product certification |

Verification scorecards: `007`, `009`, `023`, and the
verification block at the end of `043`.

---

## Repository layout

```
MortgageGovernance/
  README.md
  docs/
    README.md
    NAMING_STANDARDS.md
    METRIC_COVERAGE_MATRIX.md
    RUN_ORDER.md
    EVIDENCE_PACK.md
    INTERVIEW_WALKTHROUGH.md
    mcr/
      MCR_FV7_Master_SOP.docx
      MCR_Toolkit_StoredProc_Runbook.docx
      MCR_Toolkit_DOC_EDITS_SOP_Runbook.md
      MCR_Automation_Toolkit_Interview.docx
  sql/
    README.md
    001_create_schemas.sql ... 043a.sql
    mcr/
      README.md
      mcr_01_schema_and_source_tables.sql ... mcr_15
  tools/
    README.md
    Convert-GovScriptsToAzure.ps1
    Convert-McrToolkitToSingleDb.ps1
    build_catalog.py
  reference/
    README.md
    business_metrics_master_comprehensive_mortgage.xlsx
    MCR_FV7Definitions.pdf
    MCR_FV7Sample.xlsx
    MCR_FV7_Data_Dictionary.xlsx
    MCR_Sample_FV6.xlsx
    MCR_Data_Dictionary.xlsx
    MCR_Toolkit_Source_Mapping_Workbook.xlsx
    MCR_Toolkit_Governance_Log.xlsx
    model_v7.json
    filings/
      MCR_Toolkit_filing_1001_sample.xml
      MCR_Toolkit_filing_full_coverage_demo_v7.xml
  powerbi/
    README.md
    pbi_toolkit.html
    PBI_TOOLKIT_MANUAL.md
    measures/
      MCR_Toolkit_13_pbi_measures.txt
```

Every folder carries its own README. Each is an index of
what is in it and, where it applies, what is missing from it.

---

## Roadmap

**Project 2**, origination governance and AI readiness:
leads, applications, loan officers, rate locks, underwriting,
fair lending, NIST AI RMF, AI input governance. 101 MCR items
are classified PLANNED against it.

**Project 3**, regulatory reporting governance: RMLA
completion, Financial Condition, MLO reporting, repurchase,
warehouse lending. 263 MCR items are classified PLANNED
against it.

**Fabric**, decided but not built: mirror Azure SQL Database
into OneLake, Bronze to Silver to Gold, Direct Lake semantic
models, Purview domain. Requires provisioning and a cost
commitment first.
