# Run Order

Two sequences. A **clean rebuild** from an empty database,
and the **quarterly cycle** run against a built one.

Target platform is Azure SQL Database, serverless. Connect
directly to `MortgageGovernance`. There is no SQL Agent, so
nothing here is scheduled; every step is invoked by the
operator.

Every script is idempotent and re-runnable except where
flagged under Hazards. Read that section before running
anything twice.

---

## Clean rebuild

### Step 0. Provision

```bash
az sql db create \
  --resource-group  rg-flamingo-gov \
  --server          sql-flamingo-gov \
  --name            MortgageGovernance \
  --edition         GeneralPurpose \
  --compute-model   Serverless \
  --family          Gen5 \
  --capacity        2 \
  --auto-pause-delay 60
```

Sixty-minute auto-pause keeps a portfolio database near zero
cost between sessions. Expect a cold-start delay on the first
query after a pause.

Confirm the platform before proceeding:

```sql
SELECT EngineEdition = SERVERPROPERTY('EngineEdition');
```

Expected 5. If it returns anything else, the scripts from 030
onward will not behave as written.

### Step 1. Convert script form

Scripts 002 through 024 still carry `USE MortgageGovernance;`
from their original local-instance authoring. Azure SQL
Database rejects it.

```powershell
.\tools\Convert-GovScriptsToAzure.ps1
```

Scripts 030 onward are already in Azure form and are
unaffected. Review the diff before committing.

### Step 2. Convert the filing engine

```powershell
.\tools\Convert-McrToolkitToSingleDb.ps1
```

The engine ships assuming a dedicated database. This collapses
it into `MortgageGovernance` under the `mcr`, `mcrstg` and
`mcrpbi` schemas. Two databases would have forced a linked
server or a copy, and either would have broken the bridge
reconciliation the whole regulatory layer depends on.

### Step 3. Platform and governance core

Run in order. Each prints a completion message.

```
001_create_schemas.sql
002_audit_framework.sql
003_gov_core_tables.sql
004_gov_seed_core.sql
005_gov_seed_derivation_rules.sql
006_gov_seed_mcr_fv7_items.sql
007_verify_phase1_phase2.sql          <- gate
008_gov_seed_metric_catalog.sql
009_verify_phase3.sql                 <- gate
```

**Gate 007** returns 26 checks. **Gate 009** returns 21.
Both must read ALL CHECKS PASS before continuing. A failure
here compounds; do not proceed past it.

### Step 4. Reference, source and data

```
010_ref_tables.sql
011_src_ddl.sql
012_gov_register_sources.sql
013_dq_engine_and_defect_register.sql
014_generate_synthetic_data.sql
```

014 is the longest-running script in the build. Expected
output: 13,090 loans, 86,540 leads, 13,956 applications,
345,484 month-end snapshots, 339,150 payment transactions.

Whatever the generator produces is canonical. Do not adjust
it to match a previously recorded figure; adjust the recorded
figure.

### Step 5. Warehouse and bindings

```
015_dw_ddl.sql
016_dw_load_procs.sql
017_gov_bindings.sql
018_gov_mismo_mappings.sql
019_gov_regulatory_mapping.sql
```

After 017, expect 288 element bindings, 148 SRC and 140 DW.
After 018, expect 153 MISMO mappings at version 3.6.3, of
which 73 are tagged CANDIDATE.

### Step 6. Quality, control, certification

```
020_dq_rules_and_execution.sql        <- see Hazards
021_reconciliation_and_certification.sql
022_pbi_views_and_pipeline.sql
023_verify_end_to_end_and_evidence.sql <- gate
024_remediation_and_recertification.sql
```

022 publishes 34 views into `pbi`.

### Step 7. Filing engine

```
mcr_01_schema_and_source_tables.sql
mcr_02_field_catalog_full.sql         <- wipes engine staging
mcr_03_load_rmla_from_source.sql
mcr_04_validation_rules.sql
mcr_05_generate_mcr_xml.sql
mcr_06_qa_variance.sql
mcr_07_orchestration_procs.sql
mcr_08_filing_archive.sql
mcr_09_run_end_to_end.sql             <- smoke test
mcr_10_full_coverage_demo.sql         <- schema proof
mcr_11_pbi_views.sql
mcr_12_demo_data_cmg.sql              <- optional
mcr_14_hmda_recon.sql                 <- optional
mcr_15_mbfrf_layer.sql                <- optional
```

The engine must be deployed before step 8, because 030
registers `mcr` as a source and builds the isolation views
over it.

`mcr_13` is not a SQL script. It is a TMDL measures file and
lives in `powerbi/measures/`.

`mcr_12` creates demonstration filings 9210 and 9211. They
are unrelated to the governed filing and exist only to prove
the engine end to end. Skip it if you do not want demo
filings in the archive.

`mcr_14` and `mcr_15` are optional layers. Script 031 detects
their presence and adjusts its expected object counts, so
skipping them does not fail verification.

### Step 8. The MCR fold

```
030_reg_mcr_bridge.sql
031_verify_mcr_fold.sql               <- gate, read-only
032_MCR_bridge_exception_closure.sql
032A_mcr_bridge_reviewer_surface.sql  <- see Hazards
033_mcr_elementlevel.sql
034_RMLA_Section_III.sql
035_Regulatory_coverage_classification.sql
```

After 030, expect the bridge at MATCHED 635, MATCHED_LIST 5,
GOV_ONLY 8, MCR_ONLY 0.

After 032A, expect 648 review rows with 513 lineage eligible
and zero UNRESOLVED.

After 035, expect 513 classified items across six coverage
statuses.

### Step 9. Governed filing and data product

```
036-PRE2.sql                          <- read-only probe
036.sql
037.sql
038.sql
039.sql
040.sql
041.sql
042.sql
043.sql                               <- gate, section 10
043a.sql
```

036-PRE2 is a read-only dimension and linkage probe. Run it
first; it costs nothing and confirms the warehouse shape 036
assumes.

After 043a, expect 41 views in `pbi` and three certification
scopes at three different statuses.

---

## Hazards

**020 destroys later DQ state.** Script 020 opens with
`DELETE FROM dq.[Rule]` and `DELETE FROM dq.DataException`.
Re-running it after 042 destroys DQR21 through DQR26 and all
30 routed MCR exceptions.

Recovery is re-running 042. Nothing is hand-maintained, so
nothing is unrecoverable, but the order is not free. This is
the only place in the build where it is not.

**mcr_02 wipes engine staging.** The field catalog script
reloads the catalog and clears staged report values. Never
patch a fix into it by hand; it is generated by
`tools/build_catalog.py` and edits are lost on the next
regeneration.

**032A must be the reconstructed script.** The file
previously shipped under that name was a byte-identical copy
of 030 and created nothing. Without the correct version, the
rebuild fails at 033 because `reg.vw_McrBridgeReview` does
not exist. Confirm the file creates a view before running
step 8.

**Filing controls run at the filing period end.** Not at the
servicing as-of. Running a reconciliation at 2026-07-31 and
reading it as a filing result returns a materially different
and wrong answer. See the control taxonomy note in
`EVIDENCE_PACK.md` section 9a.

---

## Verification gates

Five. Each returns a PASS/FAIL scorecard as its first result
set. Do not proceed past a failing gate.

| Gate | Script | Scope | Expected |
|---|---|---|---|
| 1 | 007 | Platform and governance core | 26 checks, all pass |
| 2 | 009 | Seed and metric catalog | 21 checks, all pass |
| 3 | 023 | End to end, servicing | All pass |
| 4 | 031 | MCR fold, read-only | Adjusts for optional layers |
| 5 | 043 section 10 | Data product and coverage | See below |

Gate 5 expected values:

- Supported now 120, traceable 120, classified 513,
  eligible 513
- Unexplained items 0
- `pbi` view count 41
- Three certification rows: report certified with
  exceptions, filing not certified, dataset certified

Note that gate 5 passing does **not** mean the filing is
clean. It means the metadata layer is sound. The filing is
NOT_CERTIFIED by design, on six failing blocking controls
attributable to an open data issue.

---

## Quarterly cycle

Run against a built database at each filing period end.

1. **Load the warehouse.** `dw.usp_RunPipeline`.
2. **Stage the filing.**
   `reg.usp_StageMcrServicingPortfolio`. Governance owns
   `dw -> mcrstg` and stops there.
3. **Load the engine.** `mcr.usp_LoadReportValues` and
   `mcr.usp_LoadRmlaForeclosureByInvestor`. The engine owns
   `mcrstg -> mcr.*`. Neither side crosses the other.
4. **Validate the submission.** Engine validation and
   variance QA. The engine's own orchestration procedures
   are in `mcr_07`; see `docs/mcr/MCR_FV7_Master_SOP.docx`
   for the operating procedure.
5. **Recompute independently.**
   `reg.usp_ComputeMcrInternalValue`. This is the governance
   side of every tie-out and must not read the engine's
   output.
6. **Reconcile.** `reg.usp_RunMcrReconciliation`. Ten
   controls, all blocking, all exact tolerance.
7. **Execute data quality.** `dq.usp_ExecuteRules`.
8. **Route exceptions.** `reg.usp_RouteMcrExceptions`.
9. **Certify the filing.** `reg.usp_CertifyMcrFiling`.
10. **Certify the data product.**
    `reg.usp_CertifyMcrDataProduct`.
11. **Certify the report.** `gov.usp_CertifyReport`, at the
    servicing as-of date, not the filing period end.

Steps 9, 10 and 11 are three independent decisions. None of
them makes the others true.

No single orchestrator spans governance and engine today, and
that is deliberate: the boundary at `mcrstg` is the contract,
and an orchestrator that reached across it would erase the
separation the architecture depends on.

---

## Form version upgrades

When NMLS publishes a new MCR form version, do not edit the
field catalog. Regenerate it, diff the models, and work the
diff. The full procedure, including the parallel-prove step
and the effective-date discipline for filings that straddle
the cutover, is in
`docs/mcr/MCR_FV7_Master_SOP.docx`.

The one rule worth repeating here: two catalogs cannot
coexist in one database, because regenerating replaces the
catalog. Hold the cutover until the last old-version filing
is submitted.
