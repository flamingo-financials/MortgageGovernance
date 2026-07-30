# Naming Standards

MortgageGovernance database. Locked at Phase 1. All objects in
scripts 001+ follow these rules. Deviations are defects.

## Schemas

| Schema | Purpose |
|--------|---------|
| src   | Raw source-aligned tables, one set per source system |
| stg   | Staging contracts and source adapter views |
| ref   | Controlled reference tables (buckets, bands, SLAs, limits, targets) |
| dw    | Dimensional warehouse (facts, dimensions) |
| gov   | Governance metadata (catalog, lineage, regulatory registry) |
| dq    | Data quality rules, executions, results, exceptions |
| audit | Load batches, executions, errors, reconciliation |
| pbi   | Certified views. The only interface Power BI reads |
| reg   | Regulatory derivations (Project 3) |
| ai    | AI readiness objects (Project 2) |

## Tables and columns

- PascalCase, singular: `dw.FactLoanMonthEndSnapshot`,
  `gov.MetricDefinition`.
- src tables carry the system code prefix:
  `src.SvcLoanMonthEnd`, `src.PayTransaction`,
  `src.LosApplication`.
- Code columns end in `Code`, flags in `Flag`, dates in
  `Date` (DATE) or `DateUtc` (DATETIME2), amounts in
  `Amount` or `Upb`, rates in `Rate` or `Pct`.
- Surrogate keys: `<Table>Id` (INT IDENTITY) in gov/audit,
  `<Entity>Key` in dw dimensions and facts.
- Snapshot grain columns: `SnapshotDateKey` INT yyyymmdd
  plus `AsOfDate` DATE.

## Constraints and indexes

| Prefix | Pattern | Example |
|--------|---------|---------|
| PK_ | PK_Table | PK_MetricDefinition |
| FK_ | FK_Child_Parent[_Role] | FK_LineageEdge_LineageNode_From |
| UQ_ | UQ_Table_Cols | UQ_DerivationRule_RuleCode |
| CK_ | CK_Table_Col | CK_LoadBatch_StatusCode |
| DF_ | DF_Table_Col | DF_Party_ActiveFlag |
| IX_ | IX_Table_Cols | IX_LineageEdge_From |
| UX_ | UX_Table_Cols (unique filtered) | UX_DimLoanOfficer_CurrentRow |

## Programmable objects

- Procedures: `usp_` + Verb + Object.
  `audit.usp_StartLoadBatch`, `dw.usp_LoadFactPaymentTransaction`.
- Functions: `ufn_` + noun. `dw.ufn_NextBusinessDate`.
- Power BI views: `pbi.vw_` + subject. `pbi.vw_LoanMonthEnd`.
- Derivation rules: `DRV_` + short code, registered in
  `gov.DerivationRule`.
- Reconciliation controls: `RC_` + short code in
  `audit.ReconciliationControl.ControlCode`.

## Standard audit columns

Every dw and gov table carries:

- `LoadBatchId` INT NULL. Soft reference to
  `audit.LoadBatch` by design. No FK constraint: audit rows
  are never blocked or deleted by data-table dependencies,
  and cross-schema circular FK ordering is avoided. Loaders
  always populate it.
- `RowHash` VARBINARY(32) NULL. Change detection for
  incremental loads (SHA2_256 over business columns).
- `CreatedDateUtc` DATETIME2(3) NOT NULL default
  SYSUTCDATETIME().
- `ModifiedDateUtc` DATETIME2(3) NULL, set on update.

## Rules of engagement

- Business logic lives once, in `gov.DerivationRule`
  canonical logic, implemented by the registered object.
  Never duplicated in views, procs, and DAX.
- Buckets, bands, SLAs, and limits live in ref tables,
  never in CASE expressions.
- Grain is declared metadata: `gov.SourceObject.GrainStatement`
  is NOT NULL on every registered object.
- Power BI reads pbi views only. No direct dw access from
  the semantic model.
