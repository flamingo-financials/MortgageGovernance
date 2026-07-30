# MCR FV7 SQL Toolkit

Complete FV7-targeted toolkit: 635 items (510 submittable + 125 NMLS-calculated),
1,228 submittable elements, 5 repeating lists — generated from the official
`MCRBatchFileSchemaV7.xsd` + `MCR_FV7Sample.xlsx`.

All data is fictional. SQL Server 2017+.

**The file numbers are the run order.** Run 01 through 08 (plus 11, and
14/15 for the optional HMDA and MBFRF layers) to deploy, 09 to
smoke-test, 10 to prove schema coverage. 12 is an optional demo dataset
(deploy 14/15 first to exercise rules 12-14); 13 is Power BI TMDL, not
SQL — it is pasted into the Power BI model, not run in SSMS.

The official XSDs are licensed NMLS content and are NOT redistributed with this
toolkit. Download `MCRBatchFileSchemaV7.xsd` from the NMLS Resource Center and
keep it beside the toolkit for schema validation.

## Quick start (fresh install)

```
-- if rebuilding, drop the old database first:
DROP DATABASE IF EXISTS MCR_Toolkit;
```

1. Run `01` … `08`, then `11` (plus `14` if a HMDA reporter and `15` if
   an agency seller/servicer), in order in SSMS; confirm each completion
   PRINT.
2. Run `09`; save the `McrFilingText` grid value as
   `filing_2026001_sample.xml` (UTF-8).
3. `xmllint --noout --schema MCRBatchFileSchemaV7.xsd filing_2026001_sample.xml`
4. Run `10`; schema-validate its `FullCoverageText` output the same way.
   Its reconcile failures are by design — schema validity is the pass criterion.
5. Optional: run `12` for the multi-state demo dataset (exercises rules
   12-14 when 14/15 are deployed), then build the Power BI model per SOP
   3.4 (import the `pbi.*` views, paste `13`).

Full procedure: `MCR_FV7_Master_SOP.docx`. Proc-by-proc examples:
`MCR_StoredProc_Runbook.docx`.

## Files

| File | Notes |
|---|---|
| `01_schema_and_source_tables.sql` | DB, `mcr` schema, filing register (`FormVersion` defaults `'v7'`), 7 `dbo` staging tables, sample filings 2026001 (v7, current) / 2025004 (v7, prior) |
| `02_field_catalog_full.sql` | **Generated from the V7 XSD + V7 workbook** (635 items, 125 calculated, 1,228 elements, 5 lists). Wipes staging on rerun |
| `03_load_rmla_from_source.sql` | Loader. LS300-340 by-investor mapping is active under the V7 catalog |
| `04_validation_rules.sql` | Rules 1-11, type-driven. Rule 8's by-investor partition participates because LS300-340 exist in V7 |
| `05_generate_mcr_xml.sql` | Catalog-driven generator; emits `<Mcr formVersion="v7" ...>` from `mcr.Filing`. No XML prolog in the string (Msg 9402); drivers prepend it at output |
| `06_qa_variance.sql` | QoQ variance |
| `07_orchestration_procs.sql` | `usp_CreateFiling`, `usp_RunFilingPipeline` (runs rule 12 as stage 3a when 14 is deployed), `usp_StageFullCoverageDemo` |
| `08_filing_archive.sql` | Immutable archive + `usp_RunAndArchiveFiling`, `usp_RecordSubmission`, verify/export/restore/compare. Snapshots the validation results — including rule 12 findings — per archive |
| `09_run_end_to_end.sql` | Smoke test: one pipeline EXEC for sample filing 2026001. Save `McrFilingText` as `filing_2026001_sample.xml` |
| `10_full_coverage_demo.sql` | Stages every submittable element into filing 9999 and generates (`@BlockOnError = 0`; uniform demo values fail reconciles by design) |
| `11_pbi_views.sql` | Power BI semantic layer: nine star-schema views in the `pbi` schema (`14` adds `pbi.FactHmdaRecon`, `15` adds `pbi.FactMbfrf`) |
| `12_demo_data_cmg.sql` | Optional fictional demo dataset: 5 states, 10 MLOs, two quarters, filings 9210/9211, deterministic, 0 validation ERRORs, intentional GA variance flag and TX HMDA warnings; MBFRF checks tie all-PASS. Deploy `14`/`15` first to exercise rules 12-14 |
| `13_pbi_measures.tmdl` | The 25 Power BI report measures as a TMDL Measures table. Paste into the model's TMDL view; not a SQL file |
| `14_hmda_recon.sql` | Optional HMDA reconciliation control (rule 12): `dbo.HmdaLar` staging, compliance-owned `mcr.HmdaMcrBridge` checks/tolerances, `mcr.usp_ReconcileHmda`, `pbi.FactHmdaRecon`. Once deployed, the pipeline runs it automatically as stage 3a |
| `15_mbfrf_layer.sql` | Optional MBFRF layer (Fannie 1002 / Freddie 1055 / Ginnie HUD-11750, quarterly via WebMB): staged values, compliance-owned internal checks (rule 13) and MCR reconciliation bridge (rule 14), gated keying package in rounded $000s, hash-verified append-only MBFRF archive, `pbi.FactMbfrf`. Pipeline runs the checks automatically as stage 3b. WebMB is keyed, not uploaded — this is a controls layer, not a filing engine |
| `build_catalog.py` | Catalog regenerator; `--sheets` for per-version workbook layouts, `--diff` for model comparison |
| `old_02.sql`, `model_v6.json` | The V6 baseline catalog and model, kept for diffing and amendment of pre-upgrade periods |
| `model_v7.json` | Current model; source of truth for the Data Dictionary tabs |
| `filing_full_coverage_demo_v7.xml` | All 1,228 V7 elements populated — validates against the V7 XSD |
| `filing_full_coverage_demo.xml` | V6-era coverage artifact (1,117 elements, `formVersion="v6"`); historical, validates against the V6 XSD only |

## Verified

- Catalog set-equal to `model_v7.json`: 510 submittable items / 1,228 elements /
  125 calc-only / 5 lists; Data Dictionary tabs match exactly.
- Full-coverage V7 XML populates every catalog element; `<Sssf>` carries only
  `stateCode` (the FV6-era attribute-leak bug is covered by 10).
- Cross-file object references resolve across 01-10 (14 procedures; 20
  with the optional HMDA and MBFRF layers).
- Rules 12-14 findings are written before `usp_ArchiveFiling` snapshots
  `mcr.ValidationResults` (pipeline stages 3a/3b), so the immutable
  archive record includes the HMDA and MBFRF results. The MBFRF keying
  package and MBFRF archive are hard-gated on rule 13 failures.

## Regenerating after a form-version change (V7 -> V8)

Follow SOP Phase 5 (`MCR_FV7_Master_SOP.docx`, section 7):

```
python build_catalog.py MCRBatchFileSchemaV8.xsd MCR_FV8Sample.xlsx \
    -o 02_field_catalog_full.sql -m model_v8.json
python build_catalog.py --diff model_v7.json model_v8.json
```

Then: archive the old `02` as `old_02.sql`, run the new `02` (wipes staging),
update `01`'s `FormVersion` default and sample-filing seeds to the new version,
review `03`/`04`/`05` against every line of the diff — plus `14`'s and
`15`'s bridge checks if the diff touches AC920-940, AC030-060, AC300,
A010/O360, the LS010-040 block, or the column-pair convention — run `10`,
and schema-validate the coverage output against the new XSD. Do not patch version fixes into generated files — they are lost on
regeneration.

Reference: the V6 -> V7 diff was 63 items / 119 elements added (O380-384,
S170/S270/S470-474, the LS300-LS1590 servicing build-out), AC710 and I311
demoted to NMLS-calculated, and five new calculated totals (O390, LS390,
LS1390, LS1490, LS1590).
