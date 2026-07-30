# sql/

Every database object in this portfolio is created by a
script in this folder. Nothing is hand-maintained in the
database. Run the scripts in numeric order.

All scripts are idempotent and re-runnable, with two
exceptions noted under Known gaps.

Target platform: Azure SQL Database, serverless. Connect
directly to `MortgageGovernance`. No `USE`, no
`CREATE DATABASE`, no three-part names, no SQL Agent.

---

## Script form

Scripts 002 through 024 were authored against a local SQL
Server instance and still open with `USE MortgageGovernance;`.
They are deployed and verified in Azure, but the files in
this folder are not yet in Azure form. Convert before a clean
rebuild:

```powershell
.\tools\Convert-GovScriptsToAzure.ps1
```

Scripts 030 onward are already in Azure form.

---

## Foundation

| Script | Builds |
|---|---|
| 001_create_schemas.sql | 13 schemas |
| 002_audit_framework.sql | LoadBatch, LoadExecution, ErrorLog, reconciliation tables, 7 reusable procs |
| 003_gov_core_tables.sql | 30 governance metadata tables |
| 004_gov_seed_core.sql | Source systems, roles, parties, RACI, regulatory frameworks |
| 005_gov_seed_derivation_rules.sql | Derivation rule registry and rule inputs |
| 006_gov_seed_mcr_fv7_items.sql | NMLS MCR FV7 line item dictionary with instruction text |
| 007_verify_phase1_phase2.sql | Verification scorecard, 26 checks |
| 008_gov_seed_metric_catalog.sql | 221 governed metrics with coverage and project assignment |
| 009_verify_phase3.sql | Verification scorecard, 21 checks |

## Reference, source and synthetic data

| Script | Builds |
|---|---|
| 010_ref_tables.sql | Controlled reference domains and seeds |
| 011_src_ddl.sql | Source-aligned DDL for 10 systems |
| 012_gov_register_sources.sql | Source object and field registry, grain statements, authoritative source register |
| 013_dq_engine_and_defect_register.sql | DQ execution engine, synthetic defect register and truth set |
| 014_generate_synthetic_data.sql | 13,090 loans, 345,484 snapshots, 339,150 payments |

## Warehouse and governance binding

| Script | Builds |
|---|---|
| 015_dw_ddl.sql | Dimensional warehouse DDL |
| 016_dw_load_procs.sql | Warehouse load procedures and pipeline |
| 017_gov_bindings.sql | Element to SRC and DW column bindings, RACI, source-to-target map |
| 018_gov_mismo_mappings.sql | MISMO v3.6.3 mapping with provenance tagging |
| 019_gov_regulatory_mapping.sql | Regulatory item to element mapping |

## Quality, control and certification

| Script | Builds |
|---|---|
| 020_dq_rules_and_execution.sql | DQR01-DQR20, execution engine, effectiveness scorer |
| 021_reconciliation_and_certification.sql | Reconciliation controls, report certification |
| 022_pbi_views_and_pipeline.sql | 34 certified pbi views, orchestration pipeline |
| 023_verify_end_to_end_and_evidence.sql | End-to-end verification and evidence capture |
| 024_remediation_and_recertification.sql | Exception remediation and recertification cycle |

## MCR fold: reconciling two registries

| Script | Builds |
|---|---|
| 030_reg_mcr_bridge.sql | MCR source registration, the 7 reg.vw_Mcr* isolation views, reg.McrItemBridge |
| 031_verify_mcr_fold.sql | MCR fold verification scorecard, read-only |
| 032_MCR_bridge_exception_closure.sql | Bridge exception closure, reg.McrBridgeDisposition |
| 032A_mcr_bridge_reviewer_surface.sql | See Known gaps. This file is a duplicate of 030 |
| 033_mcr_elementlevel.sql | Element-level lineage spine, source field to warehouse column to regulatory element |
| 034_RMLA_Section_III.sql | RMLA Section III servicing mapping gap closure, 39 of 48 residual items |
| 035_Regulatory_coverage_classification.sql | Coverage classification of all 513 lineage-eligible items |

## Governed filing, controls and data product

| Script | Builds |
|---|---|
| 036-PRE2.sql | Read-only dimension and linkage probe run before 036 |
| 036.sql | ref.McrStagingCodeMap, reg.usp_StageMcrServicingPortfolio, filing 2026002 created and staged from the warehouse |
| 037.sql | mcr.usp_LoadRmlaForeclosureByInvestor for LS1300-LS1340, DimDelinquencyStatus McrLineNote correction, gov.DataIssue 5 |
| 038.sql | reg.McrInternalValue, reg.usp_ComputeMcrInternalValue, 5 DRV_MCR* derivation rules |
| 039.sql | NumValueFiledBasis whole-dollar column and recompute |
| 040.sql | 10 MCR_TIEOUT controls, reg.usp_RunMcrReconciliation |
| 041.sql | reg.usp_CertifyMcrFiling, reg.vw_McrFilingCertificationStatus |
| 042.sql | DQR21-DQR26, reg.usp_RouteMcrExceptions, reg.vw_McrExceptionRegister |
| 043.sql | reg.usp_CertifyMcrDataProduct with 5 gates, 7 MCR pbi views |
| 043a.sql | StewardList DISTINCT correction on pbi.vw_McrCoverageSummary |

## sql/mcr/

The NMLS MCR FV7 filing engine, `mcr_01` through `mcr_15`.
It has its own README, run order and upgrade procedure. The
engine is a separate authority from the governance platform
and the two meet only at `mcrstg`. See `sql/mcr/README.md`.

`mcr_13` is not a SQL script. It is a TMDL measures file and
lives in `powerbi/measures/`.

---

## Known gaps

**`032A_mcr_bridge_reviewer_surface.sql` is a duplicate.**
It is byte-identical to `030_reg_mcr_bridge.sql`, same MD5.
No script in this folder creates `reg.vw_McrBridgeReview`,
yet 033, 034, 035 and 043 all read from it. The view is
deployed and correct in the database; its source is missing
from the repository. A clean rebuild from this folder fails
at 033. Recover the definition before relying on the repo as
a build source.

**`020` deletes DQ state.** Script 020 opens with
`DELETE FROM dq.[Rule]` and `DELETE FROM dq.DataException`.
Re-running it destroys DQR21 through DQR26 and all routed
MCR exceptions. Recovery is re-running 042. This is the one
place in the build where run order is not free.

**Scripts 036 through 043a carry no descriptive filename.**
Functional, but a reviewer opening the folder learns nothing
from the names. Proposed renames:

| Current | Proposed |
|---|---|
| 036-PRE2.sql | 036_pre_dimension_probe.sql |
| 036.sql | 036_reg_mcr_staging_contract.sql |
| 037.sql | 037_mcr_rmla_foreclosure_loader.sql |
| 038.sql | 038_reg_mcr_internal_values.sql |
| 039.sql | 039_reg_mcr_filed_basis.sql |
| 040.sql | 040_mcr_reconciliation_controls.sql |
| 041.sql | 041_mcr_filing_certification.sql |
| 042.sql | 042_mcr_dq_rules_and_exception_routing.sql |
| 043.sql | 043_mcr_data_product_certification.sql |
| 043a.sql | 043a_coverage_summary_steward_fix.sql |

**Numbers 025 through 029 are unused.** Reserved during the
Phase 1 to Phase 2 transition and never assigned. Not a gap
in the build.

---

## Verification

| Script | Scope |
|---|---|
| 007 | Foundation, 26 checks |
| 009 | Governance seed and metric catalog, 21 checks |
| 023 | End to end |
| 031 | MCR fold, read-only, adjusts for optional HMDA and MBFRF layers |
| 043 section 10 | Data product certification and coverage consistency |

Each returns a PASS/FAIL scorecard as its first result set.
