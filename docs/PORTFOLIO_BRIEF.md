# Mortgage Data Governance Portfolio

## Project 1: Servicing Governance, Certified Analytics and MCR Readiness

A written brief. Self-contained. No repository access
required to read it.

---

## Summary

This project builds a synthetic mid-size mortgage servicer in
Azure SQL Database and carries one quarter of its data from
ten source systems through to an NMLS Mortgage Call Report
FV7 filing, with a governance layer bound to the same columns
the warehouse loads rather than documented alongside it.

The build is deliberately not a dashboard. Its value is in
what the controls caught:

- A blocking data quality rule reported PASS at a 99.63
  percent rate in the same period that 36 loans and
  $10,764,820.72 were excluded from the regulatory filing.
- A delinquency crosswalk defect mapped every delinquency
  bucket one line toward severity. Uncorrected, it would have
  reported current loans as 30-day delinquent to a regulator.
- Six of ten blocking reconciliation controls fail. The
  filing carries a status of NOT_CERTIFIED and will keep it
  until the underlying data issue is remediated at source.

None of these were smoothed over. They are the deliverable.

---

## Scale

| | |
|---|---|
| Source systems | 10 |
| Loans | 13,090 |
| Month-end snapshots | 345,484 |
| Payment transactions | 339,150 |
| Active loans at 2026-07-31 | 11,293 |
| Unpaid principal balance | approximately $4.0B |
| Schemas | 13 |
| Platform | Azure SQL Database, serverless |

Data is synthetic and deterministic. Every figure in this
brief is reproducible from a query against the database, and
each query is published in the project evidence pack.

---

## The governance layer

Governance metadata is queryable, not documentary. It lives
in tables and is joined to, not filed away.

| Artifact | Count |
|---|---|
| Governed data elements | 153 |
| Critical data elements | 27 |
| Element bindings to source and warehouse columns | 288 |
| Approved business terms | 35 |
| Derivation rules | 72 |
| Element-level RACI assignments | 323 |
| Governed metrics | 221 |

The 220-metric business inventory that opened the project was
treated as a requirements artifact rather than a list of
report titles. Each metric was resolved to the source domain
that would legitimately own it, and only domains with a
metric behind them were built. That is why the source layer
holds ten systems rather than one wide loan table.

Of 221 catalogued metrics, 68 are supported now with
calculation-ready specifications, 74 are planned against a
later portfolio project, and 79 are deferred because they
require enterprise data outside the portfolio's scope. Each
status is recorded in the database. Claiming a metric is
implemented when its source domain does not exist is the
failure mode this classification prevents.

Business logic registers once, in a derivation rule
registry, and is referenced from there. Of 153 registered
rule inputs, 109 bind to a governed data element. The
remaining 44 are each assigned to a named category:
23 object references, 11 outputs of upstream rules, 3
parameters, and 7 warehouse-derived attributes such as a
business-day calendar flag or a slowly-changing-dimension
effective date. Those 7 could have been forced to bind. They
were not, because binding a warehouse-generated flag to a
governed element would assert a source system that does not
exist.

---

## Standards alignment

All 153 governed elements are mapped to the MISMO Reference
Model v3.6.3, verified at mismo.org on 2026-07-23.

The mapping is explicit about its own uncertainty. The MISMO
Logical Data Dictionary is a member-only resource and was not
accessed, so 73 of the 153 mappings are recorded in the
database as CANDIDATE, meaning the data point name follows
MISMO v3 naming convention but was not independently
verified. The remainder carry a public-source, extension, or
not-applicable basis.

The implementation is described as MISMO-aligned and
MISMO-mapped. It is not described as compliant, because
compliance would require validation the project did not
perform.

---

## Regulatory: reconciling two registries

The project inherited two independent NMLS MCR FV7
registries. The governance platform held 648 business line
items with NMLS instruction text. The filing engine held 635
items and 1,228 submittable elements generated from the NMLS
XSD.

Neither was wrong. One owns business meaning; the other owns
submission structure. Until they were reconciled, no coverage
claim about the report was defensible.

A bridge table reconciles them:

| Match status | Items |
|---|---|
| Matched | 635 |
| Matched as list detail | 5 |
| Governance only | 8 |
| **Engine only** | **0** |

Zero engine-only items is the material assertion: nothing the
filing engine can submit lacks a governed business
definition.

Each item then receives a lineage scope that states why it
does or does not qualify for source lineage: 508 source
lineage, 124 NMLS-calculated, and the remainder list details,
annotations, aliases, deferrals and one deprecation. 513
items are lineage eligible.

Of those 513, 120 are traceable to a source column today.
The other 393 are classified rather than omitted:

| Coverage status | Target | Items |
|---|---|---|
| Supported now | Project 1 | 120 |
| Planned | Project 2 | 101 |
| Planned | Project 3 | 263 |
| Not applicable | | 26 |
| External or deferred | | 2 |
| Narrative | | 1 |

Every row carries a required source domain, a written
rationale and a named accountable steward. The published
view returns one row per status and never exposes a lone
percentage, because the classification is the claim and the
ratio is not.

---

## The governed filing

A Q2 2026 filing was created from the warehouse rather than
from the engine's demonstration data, on the reasoning that a
control comparing demonstration data to demonstration data
cannot fail.

| | Loans | Balance |
|---|---|---|
| Warehouse at 2026-06-30 | 11,214 | $3,971,534,072.72 |
| Filed whole-dollar basis | 11,214 | $3,971,534,154 |
| Staged to the filing engine | 11,178 | $3,960,769,252 |
| **Excluded** | **36** | **$10,764,820.72** |

The 36 excluded loans carry a property state absent from the
governed state reference table. The staging procedure does
not substitute a value for a regulatory filing, so it
excludes them and the controls report the gap. The exclusion
is registered as a high-severity data issue with a named
owner and a target resolution date of 2026-08-26, and it
remains at intake status.

All 36 loans were current at period end. The consequence is
that the entire delinquency variance falls on the current
line while the three delinquency lines reconcile exactly,
which distinguishes a systematic reference gap from random
data loss.

Ten reconciliation controls execute against the filing. All
are blocking and all use exact tolerance. Six fail, five of
them tracing to the single root cause above and one to a
line item with a zero population that the engine omits
rather than filing as zero.

The exact tolerance is a considered decision. NMLS requires
whole-dollar amounts and the engine rejects non-integer
currency, so the whole-dollar conversion is a form
requirement matched on both sides of every control rather
than absorbed into a tolerance band. The conversion was
verified as rounding, not truncation, by the sign of the
residual: a positive variance on one line is impossible under
truncation, which can only lose value. Had it been treated as
truncation, the resulting tolerance would have been two
orders of magnitude too wide and every control would have
been blind.

---

## Certification

Three certification scopes exist simultaneously and none
absolves another.

| Scope | Subject | Status |
|---|---|---|
| Report | Servicing governance report | Certified with exceptions |
| Regulatory filing | MCR FV7, Q2 2026 | **Not certified** |
| Dataset | MCR FV7 data product | Certified |

The data product is certified because its metadata layer is
reconciled, every eligible item is classified and owned, and
the controls execute. It asserts nothing about whether any
given filing is fit to submit. Filing fitness is certified
separately, per filing, and currently fails.

The scopes cannot contaminate one another. Filing controls
execute at the filing period end; the report certification
procedure filters reconciliation results on its own as-of
date. Two different dates, two different answers, by design.

Forty-one views are published for business intelligence
consumption. Nothing uncertified enters that layer. The seven
regulatory views were admitted only after the data product
passed a five-gate certification, and each carries the filing
certification status as a column, so no coverage figure can
be read without the filing state beside it.

---

## Data quality, and its limits

Twenty-six executable rules run against the warehouse with
results, failure rows, exception routing and an effectiveness
scorer measured against a synthetic defect truth set.

The six regulatory rules are non-blocking by design, so that
a filing finding cannot cause the servicing report to lose
its certification. Thirty-three exceptions are currently
open, each with an owner and a due date.

The most instructive result is a rule that passed. The rule
covering the field behind the filing exclusion reported a
99.63 percent pass rate against a 99 percent threshold: 48
failed rows out of 13,090. It passed while $10.76 million
left the filing.

Both mechanisms were correct. They measure different
populations against different obligations. Tightening the
threshold would not have surfaced the filing gap, because
twelve of the failing rows belong to loans that were inactive
at period end and never reached the filing at all.

The conclusion the project draws is that threshold-based data
quality is not a substitute for reconciliation control, and a
governance program running only the first will report health
it does not have.

---

## Published limitations

The project publishes its own defects rather than resolving
them quietly.

- Two reconciliation controls from an earlier build stage are
  typed as regulatory tie-outs but compare source to
  warehouse. A dashboard reading the resulting metric returns
  a materially different figure depending on the as-of date
  selected. Retyping them is open.
- One build script reloads the data quality rule table on
  execution, destroying rules and exceptions created by a
  later script. Recovery is documented; the coupling is not
  yet removed.
- A zero-population line item is omitted from the submission
  rather than filed as zero, making an absent line
  indistinguishable from an unreported one. A control detects
  it; whether the loader should emit explicit zeros is
  undecided.
- The Power BI report is not built. The certified view layer
  that will serve it exists and is certified; the report is
  the next deliverable.

---

## What this demonstrates

The project is designed to answer, with a query rather than
an assertion, questions a governance function is expected to
answer:

Where did this number originate. Which system is
authoritative. What transformations occurred and where is
each one registered. What does the element mean in business
terms and in technical terms. Does it align to an industry
standard, and how confident is that alignment. Who owns it
and who stewards it. Is it critical. Is it used in a
regulatory filing, and in which line item. Which metrics and
which reports depend on it. What quality rules protect it,
what happens when one fails, and who is accountable for the
failure. Can an auditor trace the filed figure to source
data. Can this report be certified, and if not, what
specifically is blocking it.

The underlying skills are fifteen years of SQL Server,
dimensional modeling, T-SQL, and Power BI in mortgage
servicing and origination. The project's purpose is to show
those skills operating as governance infrastructure: the same
warehouse, with lineage bound to it, controls executing
against it, and certification gating what reaches the
business.

---

## Roadmap

**Project 2**, origination governance and AI readiness: leads,
applications, loan officers, rate locks, underwriting
decisions, closing and funding, fair lending data, AI input
governance and NIST AI Risk Management Framework controls.
101 regulatory items are already classified against it.

**Project 3**, regulatory reporting governance: RMLA
completion, financial condition reporting, mortgage loan
originator reporting, repurchase and warehouse lending. 263
regulatory items are already classified against it.

Both projects extend the same environment. The classification
table is the roadmap, which means the roadmap is queryable
too.
