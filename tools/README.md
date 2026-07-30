# tools/

Build and conversion utilities. None of these run as part of
normal operation. They exist for platform moves and for
regenerating a script that must never be hand-edited.

---

## Convert-GovScriptsToAzure.ps1

Converts the governance scripts from local SQL Server form to
Azure SQL Database form. Strips `USE MortgageGovernance;` and
the `GO` that follows it, and flags three-part names.

Scripts 002 through 024 still carry the local form. They are
deployed and verified in Azure, but a clean rebuild from the
repository requires this conversion first. Scripts 030 onward
were authored in Azure form and are unaffected.

Run from the repository root:

```powershell
.\tools\Convert-GovScriptsToAzure.ps1
```

Review the diff before committing. The conversion is
mechanical; a script that fails afterward is failing for a
different reason.

---

## Convert-McrToolkitToSingleDb.ps1

Rewrites the MCR FV7 filing engine scripts to run inside
`MortgageGovernance` rather than in a database of their own.
The engine ships assuming a dedicated database and uses
three-part names in places; this collapses it to one
database and the `mcr`, `mcrstg` and `mcrpbi` schemas.

This is why the engine can be reconciled against governance
metadata at all. Two databases would have meant a linked
server or a copy, and either would have broken the
`reg.McrItemBridge` reconciliation.

Run once, before deploying `sql/mcr/`.

---

## build_catalog.py

Generates `sql/mcr/mcr_02_field_catalog_full.sql` and the
model JSON from the NMLS FV7 XSD and the NMLS sample
workbook. The field catalog is 635 items and 1,228 elements
and is never edited by hand.

```bash
python build_catalog.py MCRBatchFileSchemaV7.xsd \
    MCR_FV7Sample.xlsx -o mcr_02_field_catalog_full.sql \
    -m model_v7.json
```

Diff two form versions:

```bash
python build_catalog.py --diff model_v7.json model_v8.json
```

The diff reports items added, items removed, elements
retyped, items moved between sections, and lists added or
removed. It must agree with the added and removed list NMLS
publishes. A disagreement is investigated before any SQL
changes.

**Never patch a fix into the generated catalog.** It is lost
on the next regeneration. Fix the generator or the source
workbook.

Inputs live in `reference/`. The XSD is shipped by NMLS and
is not redistributed here.

---

## Excluded from this repository

`Paige_Justice_Software_Tools_Account_Reference.docx` is a
personal account and credential reference. It is not part of
the portfolio and must not be committed or included in a
release zip.
