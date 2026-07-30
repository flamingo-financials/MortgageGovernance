# docs/

Written artifacts. Everything here is either a standard the
build follows, a generated matrix, or evidence a reviewer can
check against the database.

Nothing in this folder is the system of record. Governance
metadata lives in SQL Server and is queryable. These
documents index it and explain it.

---

## Standards and generated matrices

**NAMING_STANDARDS.md**
The naming convention every object in `sql/` follows.
Schemas, PascalCase, surrogate key form, procedure prefixes,
constraint and index naming, audit column conventions.
Written once, applied throughout. Read this before adding an
object.

**METRIC_COVERAGE_MATRIX.md**
Generated from `gov.MetricDefinition`. 221 governed metrics
across 31 business domains, each with a project assignment
and a coverage status of SUPPORTED, PLANNED or DEFERRED.
68 are SUPPORTED with calculation-ready specifications.

The matrix exists so the portfolio cannot claim a metric is
implemented when the source domain does not exist. If it
says DEFERRED, no data supports it and none is pretended.

**RUN_ORDER.md**
Execution sequence for a clean rebuild, including the MCR
engine and the order dependency at script 020.

---

## Evidence and walkthrough

**EVIDENCE_PACK.md**
Each portfolio claim paired with the query that proves it and
the result to expect. Written so a reviewer can run it
against the database, and so screenshots can be regenerated
deterministically rather than recovered from memory.

**INTERVIEW_WALKTHROUGH.md**
The build narrated in the order it should be told out loud.
Leads with the failures, because the failures are the
evidence that the controls work. Includes the questions the
architecture is designed to answer and where each answer
comes from.

---

## docs/mcr/

Operating documentation for the NMLS MCR FV7 filing engine,
carried over from the toolkit it came from.

| File | Purpose |
|---|---|
| MCR_FV7_Master_SOP.docx | Quarterly filing standard operating procedure, environment setup, upgrade path to a new form version |
| MCR_Toolkit_StoredProc_Runbook.docx | Procedure-level runbook for the engine |
| MCR_Toolkit_DOC_EDITS_SOP_Runbook.md | Edit log for the SOP and runbook |
| MCR_Automation_Toolkit_Interview.docx | Interview framing for the filing engine specifically |

The engine's own script index is `sql/mcr/README.md`. These
documents cover operating it, not building it.

---

## Conventions

- Line width roughly 72 characters.
- Counts and dollar figures are taken from the database, not
  estimated. If a number appears here it is reproducible
  from a query in EVIDENCE_PACK.md.
- Claims about compliance are stated as mapping or alignment
  unless validated. MISMO is mapped, not compliant. The
  Q2 2026 filing is governed, not certified.
