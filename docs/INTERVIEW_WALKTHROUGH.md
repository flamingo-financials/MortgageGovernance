# Interview Walkthrough

Talk track. First person. For saying out loud.

The written version a hiring manager reads without you in
the room is `PORTFOLIO_BRIEF.md`. Do not read this one
aloud verbatim; it is structured so you can find the thread
again after an interruption.

One rule throughout: lead with what failed. A governance
portfolio where everything passes is a portfolio where
nothing was tested.

---

## 60 seconds

I built a synthetic mortgage servicer in Azure SQL and ran
one quarter of its data all the way from ten source systems
to an NMLS Mortgage Call Report filing, with the governance
layer wired in rather than bolted on.

The useful part is what it caught. A blocking data quality
rule reported PASS at 99.6 percent in the same period that
36 loans and $10.8 million dropped out of the regulatory
filing. Threshold data quality said fine. The reconciliation
control said no. The control was right.

That gap is the whole argument. It is why I built
reconciliation controls and certification scopes rather than
a data quality dashboard.

---

## 3 minutes

**What it is.** Ten source systems, a governed dimensional
warehouse, 13,090 loans and 345,484 month-end snapshots,
roughly $4 billion UPB. On top of that a governance layer
that is queryable rather than documented: 153 governed data
elements, 27 CDEs, ownership and RACI, MISMO mappings, 221
metrics, 26 executable data quality rules, reconciliation
controls, and three separate certification scopes.

Then I took it further than most portfolio projects go. I
folded in a full NMLS MCR FV7 filing engine and produced a
governed quarterly filing from the warehouse.

**What it caught.** Three things, all real.

First, a delinquency crosswalk defect. The dimension mapping
delinquency buckets to MCR line items had every bucket
shifted one line toward severity. Current loans were mapping
to the 30-day line. If that had filed, we would have
reported roughly 10,800 current loans as delinquent to a
regulator.

Second, the state reference gap. 36 active loans carry a
property state that does not exist in the state reference
table. The staging procedure refuses to invent a state for a
regulatory filing, so it excludes them. Six of ten blocking
controls fail on that one root cause. All 36 were current
loans, so the entire delinquency variance lands on the
current line and the three delinquency lines tie exactly,
which is how you know the exclusion was systematic rather
than random. The filing is
NOT_CERTIFIED and stays that way until the issue is closed
at source. It is not closed by widening a threshold.

Third, and this is the one I like, the data quality rule
covering that same field reported PASS. 48 failed rows out
of 13,090, a 99.63 percent pass rate against a 99 percent
threshold. Both mechanisms were correct. They measure
different populations against different obligations. That is
the case for running both.

**What it demonstrates.** I can trace a number on a
regulatory filing back to the source column that produced
it, name the rule that derived it, name the person
accountable for it, and tell you honestly which parts of the
report I cannot support yet and why.

---

## 15 minutes

Five movements. Roughly three minutes each. Take questions
between them, not during.

### 1. The problem I set up for myself

Fifteen years in mortgage BI, mostly servicing and
origination. I have built the reporting that governance
programs later come along and audit. I wanted a portfolio
that showed the transition, not a career restart, so the
build had to use SQL, dimensional modeling and Power BI as
the substrate and put governance on top of it.

The requirements artifact was a 220-metric business inventory
I had already assembled. I did not copy metric names into a
dashboard. I resolved every metric to the source domain that
would legitimately own it, and built only the domains that
had a metric behind them. That produced ten source systems
rather than one wide loan table.

221 metrics are catalogued. 68 are SUPPORTED with
calculation-ready specifications. 74 are PLANNED against a
later project. 79 are DEFERRED because they need enterprise
data outside portfolio scope, like a general ledger. Each one
carries its status in the database.

The reason to publish 68 rather than 221 is that claiming a
metric is implemented when the source domain does not exist
is exactly the thing governance is supposed to prevent.

### 2. Governance as queryable metadata

Everything is a table, not a Word document.

153 governed data elements, each bound to a physical source
column and a warehouse column. 27 flagged as critical.
Ownership and stewardship as RACI rows, not a slide. 35
approved business terms. 72 derivation rules, because
business logic registers once and is referenced, never
copied into a second script.

Derivation rule inputs are worth a minute. There are 153
inputs. 109 are bound to a governed element. The other 44
are not, and every one belongs to a named category: 23 are
object references rather than columns, 11 are outputs of an
upstream rule consumed downstream, 3 are parameters, and 7
are warehouse-derived attributes like a business-day
calendar flag or an SCD2 effective date.

Those last 7 could be forced to bind. I did not, because
binding a calendar flag to a governed data element asserts a
source system that does not exist. That is fake lineage. The
category is the honest answer.

### 3. Two registries, one bridge

This is the part that would not fit in a tutorial.

The governance platform had its own NMLS MCR FV7 registry,
648 line items with instruction text. The filing engine had
its own, 635 items and 1,228 elements generated from the
NMLS XSD. Neither was wrong. They describe different layers:
one owns business meaning, the other owns submission
structure.

Until they were reconciled, no coverage claim about MCR was
defensible. So I built a bridge table and reconciled them.
MATCHED 635, MATCHED_LIST 5, GOV_ONLY 8, MCR_ONLY zero.

Zero MCR_ONLY is the assertion that matters: nothing the
engine can file lacks a governed business definition.

Then every item gets a lineage scope explaining why it does
or does not get source lineage. 508 source lineage, 124
NMLS-calculated, and the remainder annotations, aliases,
deprecations and deferrals. 513 items are lineage eligible.

Of those 513, 120 are traceable to source today. The other
393 are classified, not hidden: coverage status, target
project, required domain, written rationale, accountable
steward. If someone asks for the coverage percentage, the
answer is that the percentage is not the claim.

### 4. The filing, and what broke

I created a governed Q2 2026 filing from the warehouse
rather than from the engine's demo data, because a control
comparing demo data to demo data cannot fail.

At 2026-06-30 the warehouse held 11,214 active loans and
$3,971,534,072.72. NMLS requires whole dollars, so the filed
basis is $3,971,534,154. Staging moved 11,178 loans and
$3,960,769,252. The difference is those 36 loans.

Ten reconciliation controls, all blocking, all EXACT
tolerance. Six fail.

I want to be specific about the tolerance decision, because
I got it wrong first. I initially described the whole-dollar
conversion as truncation. If I had built the controls on
that reasoning I would have set an absolute-amount tolerance
two orders of magnitude too wide, and every MCR control
would have been blind. I checked the sign of the residual
before building anything. A +5.43 variance on one line is
impossible under truncation, which only ever loses value. It
is ROUND. So the conversion is matched on both sides as a
form requirement, and the tolerances stay EXACT. There is no
tolerance to hide in.

Validation returns 30 completeness errors, three per state
across ten states, on the three fields NMLS marks required
at state scope.

### 5. Three certifications, three answers

The report is CERTIFIED_WITH_EXCEPTIONS at the servicing
as-of date. The filing is NOT_CERTIFIED at the filing period
end. The data product is CERTIFIED.

They do not absolve each other, and the schema prevents them
from contaminating each other: filing controls execute at
the filing period end, never at the servicing as-of, and the
report certification procedure filters reconciliation results
on its own date.

The data product is certified because its metadata layer is
reconciled and every eligible item is classified and owned.
It certifies nothing about whether this quarter's numbers
are fit to submit. Those are different questions and I did
not let one answer the other.

41 views are published for Power BI. Nothing uncertified
enters that schema. The seven MCR views got there only after
the data product passed its own five gates, and every one of
them carries the filing certification status as a column, so
nobody can read a coverage number without the filing state
sitting next to it.

---

## Whiteboard version

Draw it top to bottom, talk while drawing. Six boxes and two
annotations. Do not draw the schema.

```
  10 source systems
        |
        v
  governed warehouse  ---- gov metadata
        |                  elements, CDEs, RACI,
        |                  MISMO, 72 derivation rules
        v
  dq rules (26)  ----  DQR02 PASS 99.63%   <-- (A)
        |
        v
  mcrstg  (governed contract surface)
        |                  36 loans / $10.76M
        |                  excluded here      <-- (B)
        v
  mcr filing engine
        |
        v
  10 reconciliation controls, EXACT, blocking
        6 FAIL
        |
        v
  3 certification scopes
     REPORT     CERTIFIED_WITH_EXCEPTIONS
     FILING     NOT_CERTIFIED
     DATASET    CERTIFIED
```

Annotation A and annotation B are the same field in the same
period. That is the entire point, and it is one sentence
once the picture is up.

The horizontal line into gov metadata is the second point:
governance is not a downstream document, it is bound to the
same columns the warehouse loads.

---

## Questions you will get

**"Did you build this alone or is it generated?"**
I designed the architecture and made every governance
decision. I used AI assistance for code generation the way
I would use any tool, and I ran and verified every script
myself. Three real defects were caught because I stated the
expected result before running and the actual result
disagreed. The delinquency crosswalk shift is the clearest
example. That is the workflow, and it is the same discipline
I would apply reviewing a contractor's work.

**"Why synthetic data?"**
Because real servicing data cannot go in a portfolio. The
generator is deterministic and the counts are canonical, so
every number in the evidence pack is reproducible. It also
let me inject known defects and test whether the rules
caught them, which is the part you cannot do with production
data.

**"Isn't 120 of 513 low?"**
It is the honest number. 393 items are classified against a
future project with a required domain and an accountable
steward. I could have claimed a higher number by mapping
items to elements that do not carry the right business
meaning. The bridge and the lineage table exist specifically
so that kind of claim is checkable.

**"Your DQ threshold was too loose."**
Tightening it does not fix this. At 100 percent the rule
fails on 48 rows, twelve of which never reached the filing
because those loans were inactive at period end. The rule
and the control measure different populations against
different obligations. The lesson is not to retune the rule.
It is that threshold data quality is not a substitute for
reconciliation.

**"Is this MISMO compliant?"**
No, and I am careful about that word. It is MISMO-aligned and
MISMO-mapped against v3.6.3. 73 of 153 mappings are flagged
CANDIDATE in the database because the Logical Data Dictionary
is member-only and I did not access it. Compliance would
require validation against the LDD. The flag is in the data,
not a footnote.

**"What would you do differently?"**
Three things, and they are documented as open items. Two
controls from an earlier script are typed as MCR tie-outs but
actually compare source to warehouse, which makes a
dashboard metric read 100 percent or 40 percent depending on
the as-of date. One script deletes and reloads the data
quality rule table, so re-running it destroys exceptions
routed by a later script. And the engine emits no row for a
zero-population line, so an absent line is
indistinguishable from an unreported one on the wire; a
control catches it today but the loader should probably emit
explicit zeros.

**"What is Project 2 and 3?"**
Origination governance and AI readiness, then regulatory
reporting governance. 101 MCR items are already classified
against Project 2 and 263 against Project 3, so the roadmap
is not aspirational, it is in the coverage table.

---

## Things not to say

Do not say the filing is certified. It is not, and the
database will contradict you.

Do not say MISMO compliant.

Do not quote a coverage percentage without the classification
behind it. The number invites the wrong question.

Do not present the data quality pass rate as a success
metric. It is the setup for the failure.

Do not claim a Power BI report exists. It does not yet. The
certified view layer exists; the report is the next build.

If you do not know a number, say so and open the query. The
whole portfolio is built on being able to do that.
