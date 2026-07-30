# powerbi/

**The report is not built.** This folder holds the toolkit
and the measures that will build it, and the contract the
model must read against. There is no .pbip, no semantic
model and no report file here yet.

Stating that plainly matters more than filling the folder.
The database claims a report certification of
CERTIFIED_WITH_EXCEPTIONS for `PBI_SVC_GOV`; that
certification covers the certified view layer and its
evidence rows, not a published report.

---

## The contract

Power BI reads `pbi` views only. Nothing else. 41 views,
34 from script 022 and 7 from script 043.

An uncertified object does not enter `pbi`. The seven MCR
views entered only after `DP_MCR_FV7` passed its five gates,
and each carries `FilingCertificationStatus` so no coverage
figure can be read without the filing state beside it.

Consequences for the model:

- No direct reads from `dw`, `gov`, `reg` or `mcr`.
- No calculated columns where a warehouse column or a
  derivation rule would do. Business logic registers once,
  in `gov.DerivationRule`, not twice.
- Business-friendly table names. `dw.FactLoanSnapshot`
  surfaces as Loan Snapshot, `dw.DimInvestor` as Investor.
  Fact and Dim prefixes stay out of the user-facing model.
- Explicit measures in a dedicated `_Measures` table.
  Auto Date/Time off. Governed date table. Surrogate keys
  hidden. Single-direction relationships unless a documented
  case requires otherwise.

---

## Toolkit

**pbi_toolkit.html** and **PBI_TOOLKIT_MANUAL.md**

The manual is the source of truth for what the toolkit
actually does. Do not assume a capability that is not in it.

Supported and intended for use here: model profiles,
measures table generation, batch measures, batch RLS, TMDL
generation, Tabular Editor workflows, BPA and model-quality
snippets, reusable snippets, theme generation.

Complementary tooling: Power BI Desktop, Tabular Editor,
DAX Studio, VertiPaq Analyzer, ALM Toolkit.

---

## measures/

**MCR_Toolkit_13_pbi_measures.txt**

25 TMDL measures from the MCR filing engine: values,
variance, controls, production, servicing. All math is in
measures; no calculated columns. Pasted into the model as a
Measures table.

These cover the filing engine's own review model. The
governance report measures are not written yet.

---

## What goes here when it is built

Power BI Project (.pbip) format, so the model and report are
diffable and reviewable in source control rather than a
binary .pbix.

- Semantic model reading the `pbi` views
- Report with pages for executive overview, portfolio health,
  delinquency and default, data quality, metric governance,
  data lineage, regulatory readiness, certification and
  controls, and a project governance summary
- `_Measures` table with display folders
- Theme JSON
- RLS role definitions

The report has a specific job in this portfolio: it is not a
KPI dashboard, it is the visual demonstration of the
governance chain. A certification indicator that reads
CERTIFIED_WITH_EXCEPTIONS, next to a control that reads FAIL,
next to the data issue that owns it, is the deliverable.
