# Word document edits - apply in your Word originals

Reason for most of these: rule 12 now runs INSIDE the pipeline (stage 3a
in 07), so its findings exist before usp_ArchiveFiling snapshots
mcr.ValidationResults. The old documented order (archive first, reconcile
after) meant the immutable archive never contained the HMDA findings.
Remaining edits fix the "nine views" wording and stage lists.

---

## MCR_FV7_Master_SOP.docx (6 edits)

**Edit 1 - Section 2 file inventory, 14_hmda_recon.sql row.**
Find:
> Deploy if the company is a HMDA reporter; run before 12 to exercise the demo.

Replace with:
> Deploy if the company is a HMDA reporter (before 12 to exercise the demo). Once deployed, mcr.usp_RunFilingPipeline runs the reconciliation automatically as stage 3a, so rule 12 findings are captured in the archive snapshot.

**Edit 2 - Section 2 script table, 14_hmda_recon.sql row, last column.**
Find:
> Once (deploy, optional); proc runs each quarter after the pipeline

Replace with:
> Once (deploy, optional); runs automatically inside the pipeline (stage 3a) each quarter; standalone EXEC for reruns after restaging the LAR

**Edit 3 - Section 3.3, Step 2.**
Find:
> Confirm the stage prints appear (stage 1 prior staging, 2 load, 3 validate, 4 variance, 5 generate)

Replace with:
> Confirm the stage prints appear (stage 1 prior staging, 2 load, 3 validate, 3a HMDA reconciliation if 14 is deployed, 4 variance, 5 generate)

**Edit 4 - Section 3.4, Power BI import bullet.**
Find:
> Power BI Desktop: Get Data > SQL Server > MCR_Toolkit, select all nine pbi.* views, Import mode.

Replace with:
> Power BI Desktop: Get Data > SQL Server > MCR_Toolkit, select all nine pbi.* views from 11 (plus pbi.FactHmdaRecon if 14 is deployed), Import mode.

**Edit 5 - Section 6.3, the HMDA bullet after the usp_RunAndArchiveFiling
description.**
Find (whole bullet):
> If the HMDA layer (14) is deployed: EXEC mcr.usp_ReconcileHmda @FilingId = <id> AFTER the pipeline. Order matters - usp_ValidateFiling deletes every validation row for the filing, so the reconciliation must run last or its findings are wiped. It returns a PASS/WARN grid per state and check and writes breaches as rule 12 WARNINGs (RuleType HMDA_RECON); it never blocks generation.

Replace with:
> If the HMDA layer (14) is deployed, the pipeline runs the reconciliation automatically as stage 3a - after validate (which wipes the filing's validation rows) and before the archive snapshot, so rule 12 findings are part of the immutable archive record. Stage the period's dbo.HmdaLar rows BEFORE running the pipeline. It returns a PASS/WARN grid per state and check and writes breaches as rule 12 WARNINGs (RuleType HMDA_RECON); it never blocks generation. Standalone EXEC mcr.usp_ReconcileHmda @FilingId = <id> remains valid for reruns after restaging the LAR - always after usp_ValidateFiling, never before.

**Edit 6 - Section 8.1 quarterly quick card.**
Row 3, add HMDA staging. Find:
> Run population layer; unmapped-value check

Replace with:
> Run population layer (incl. dbo.HmdaLar if a HMDA reporter); unmapped-value check

Row 5, remove the trailing recon EXEC. Find:
> EXEC mcr.usp_RunAndArchiveFiling (@BlockOnError = 1); note ArchiveId; EXEC mcr.usp_ReconcileHmda (if HMDA layer deployed)

Replace with:
> EXEC mcr.usp_RunAndArchiveFiling (@BlockOnError = 1); note ArchiveId (rule 12 runs automatically as stage 3a if the HMDA layer is deployed)

**Optional - Section 6.4 rule table, rule 12 row:** change "runs after the
pipeline" to "runs inside the pipeline (stage 3a)".

---

## MCR_StoredProc_Runbook.docx (5 edits)

**Edit 1 - Section 1 procedure inventory, usp_ReconcileHmda row, last
column.**
Find:
> Quarterly, step 3a (HMDA reporters)

Replace with:
> Automatic inside the pipeline, stage 3a (HMDA reporters); standalone for reruns

**Edit 2 - Step 3 expected output.** Between the "=== Stage 3: validate ==="
block (validation grid line) and "=== Stage 4: variance ===", insert:

> === Stage 3a: HMDA reconciliation (rule 12) ===   (only if 14 deployed)
>
>   [result grid: PASS/WARN per state and check; WARNINGs written as
>    RuleType HMDA_RECON]

Also update the bold lead-in "stage prints, three result grids, archive
confirmation" to "stage prints, three to four result grids, archive
confirmation".

**Edit 3 - Step 3a heading and body.** Retitle to:
> Step 3a - HMDA reconciliation (automatic in the pipeline; standalone for reruns)

Replace the first body line:
> Run AFTER the pipeline, never before: usp_ValidateFiling deletes every validation row for the filing, so a reconciliation run first is wiped.

with:
> Once 14 is deployed, the pipeline runs this automatically as stage 3a - after validate and before the archive snapshot, so findings are in the immutable archive record. Stage dbo.HmdaLar for the period BEFORE running the pipeline. Run the proc standalone only to rerun after restaging the LAR - always AFTER usp_ValidateFiling, never before (validate deletes every validation row for the filing, including these).

Keep the EXEC example and the NOTE as they are.

**Edit 4 - Section 6.2 demo expected-output comments.**
Find:
> -- If 14 is installed, the script also stages a matching HMDA LAR and
> -- runs rule 12: TX WARNs on HMDA01 (8% > 5% tolerance) and HMDA04

Replace with:
> -- If 14 is installed, the script stages a matching HMDA LAR before the
> -- pipeline, so stage 3a runs rule 12 for 9211 (and the script runs it
> -- explicitly for prior filing 9210, which never pipelines):
> -- TX WARNs on HMDA01 (8% > 5% tolerance) and HMDA04

**Edit 5 - Section 6.3 first bullet.**
Find:
> select all nine pbi.* views, Import mode.

Replace with:
> select all nine pbi.* views from 11 (plus pbi.FactHmdaRecon if 14 is deployed), Import mode.

---

## Version bump
Bump both documents to version 1.3 and add a Record of Changes row:
"Rule 12 moved inside the pipeline (stage 3a) so HMDA findings are
captured in the archive snapshot; PBI import wording covers FactHmdaRecon."

===============================================================================
# PART 2 - MBFRF layer (15_mbfrf_layer.sql, rules 13/14)

Apply after Part 1. Reason: the toolkit now covers the Mortgage Bankers'
Financial Reporting Form (Fannie 1002 / Freddie 1055 / Ginnie HUD-11750),
the quarterly agency financial report every nonbank seller/servicer files
via WebMB. WebMB is a keyed web form (no upload), so the layer produces a
checked, reconciled, archived KEYING PACKAGE: rule 13 = internal
consistency (gates the keying package and MBFRF archive), rule 14 =
MCR-to-MBFRF reconciliation (WARNING, dispositioned). The pipeline runs
both automatically as stage 3b.

---

## MCR_FV7_Master_SOP.docx (7 edits)

**Edit 1 - Section 2 file inventory.** After the 14_hmda_recon.sql row,
add:
> | 15_mbfrf_layer.sql | Optional MBFRF layer (rules 13/14): mcr.MbfrfCatalog field reference (representative subset - complete against current WebMB definitions), mcr.MbfrfValues staging, compliance-owned mcr.MbfrfCheck internal checks and mcr.McrMbfrfBridge reconciliation config, usp_LoadMbfrfFromSource, usp_ValidateMbfrf, usp_GetMbfrfKeyingPackage, usp_ArchiveMbfrf / usp_VerifyMbfrfArchive, pbi.FactMbfrf. Deploy if an agency seller/servicer (before 12 to exercise the demo). The pipeline runs the checks automatically as stage 3b. |

**Edit 2 - Section 2 script table.** After the 14 row, add:
> | 15_mbfrf_layer.sql | mcr.MbfrfCatalog/Values/Check, mcr.McrMbfrfBridge, mcr.MbfrfArchive/ValuesHistory, 5 procs, pbi.FactMbfrf | MBFRF controls layer: internal consistency checks (rule 13 - balance sheet ties, detail sums to totals; the pre-keying equivalent of the automated validations Ginnie runs on submissions) and MCR reconciliation (rule 14 - same GL and loan population, one story). Values staged in whole dollars; the keying package converts to the rounded $000s WebMB expects. Rule 13 failures hard-gate the keying package and the MBFRF archive but never block MCR generation. | Once (deploy, optional); checks run automatically in pipeline stage 3b; keying package + archive each quarter |

**Edit 3 - Section 3.2 deploy table.** After the 14 step, add:
> | 11 | 15_mbfrf_layer.sql (optional - agency seller/servicers) | 15 complete: mcr.MbfrfCatalog/Values/Check, mcr.McrMbfrfBridge, usp_LoadMbfrfFromSource, usp_ValidateMbfrf, usp_GetMbfrfKeyingPackage, usp_ArchiveMbfrf, usp_VerifyMbfrfArchive, pbi.FactMbfrf created |

**Edit 4 - Section 3.3 Step 2 stage list** (Part 1 Edit 3 already added
3a). Change to:
> (stage 1 prior staging, 2 load, 3 validate, 3a HMDA reconciliation if 14 is deployed, 3b MBFRF checks if 15 is deployed, 4 variance, 5 generate)

**Edit 5 - Section 3.4 Power BI import bullet** (supersedes Part 1
Edit 4). Final wording:
> Power BI Desktop: Get Data > SQL Server > MCR_Toolkit, select all nine pbi.* views from 11 (plus pbi.FactHmdaRecon if 14 is deployed and pbi.FactMbfrf if 15 is deployed), Import mode. FactMbfrf relates to DimFiling on FilingId; add it to the Controls page.

**Edit 6 - Section 6, new subsection after the HMDA bullet (6.3a or
similar): "MBFRF quarterly cycle (if 15 is deployed)".** Body:
> Stage the quarter's MBFRF values BEFORE running the pipeline: EXEC mcr.usp_LoadMbfrfFromSource @FilingId = <id> derives the production, servicing, and repurchase fields from the same staging tables the MCR uses; balance-sheet and income fields are controlled manual INSERTs into mcr.MbfrfValues (whole dollars), same posture as the MCR FC schedules. The pipeline then runs rule 13 (internal consistency - mcr.MbfrfCheck config) and rule 14 (MCR reconciliation - mcr.McrMbfrfBridge config) automatically as stage 3b, ahead of the archive snapshot. Findings are WARNING severity and never block MCR generation; rule 13 failures instead hard-gate the MBFRF side: mcr.usp_GetMbfrfKeyingPackage and mcr.usp_ArchiveMbfrf both refuse until the staged values tie. When clean: EXEC mcr.usp_GetMbfrfKeyingPackage @FilingId = <id> returns the WebMB entry grid in order, with KeyAs in rounded thousands; key it into WebMB (due 30 days after quarter end, 60 for Q4; CEO/CFO certification at submission); then EXEC mcr.usp_ArchiveMbfrf @FilingId = <id> to freeze the certified values append-only with a SHA-256 hash (verify any time with usp_VerifyMbfrfArchive). Log the WebMB submission and certifier in the Governance Log Filing_Log, and disposition rule 14 WARNINGs on the Validation_Exceptions tab like any other reconciliation finding. The mcr.MbfrfCatalog seed is a representative subset - compliance must complete and verify field codes against the current WebMB definitions before production use, and owns changes to MbfrfCheck and McrMbfrfBridge like the other bridges.

**Edit 7 - Section 6.4 rule table.** After row 12, add:
> | 13 | MBFRF internal consistency: balance sheet ties, schedule detail sums to totals (config-driven, compliance-owned) - gates the MBFRF keying package and archive, never MCR generation | MBFRF checks (15) |
> | 14 | MBFRF ties to MCR within documented tolerances: FC cash, originations $ (funded channels), nationwide servicing UPB (excl. LS040), quarterly repurchase UPB - WARNING-only, dispositioned | Cross-filing reconciliation (15) |

**Quick card (8.1).** Row 3 (supersedes Part 1 Edit 6 row-3 wording):
> Run population layer (incl. dbo.HmdaLar if a HMDA reporter; MBFRF loader + manual entries if an agency seller/servicer); unmapped-value check
Row 5: append "(rules 12-14 run automatically as stages 3a/3b if the layers are deployed)".
New row after the NMLS upload row:
> | 9 | If 15 deployed: EXEC mcr.usp_GetMbfrfKeyingPackage; key into WebMB by day 30 (60 for Q4); CEO/CFO certification; EXEC mcr.usp_ArchiveMbfrf; log in Filing_Log | Rule 13 clean; MBFRF archived |

---

## MCR_StoredProc_Runbook.docx (5 edits)

**Edit 1 - Section 1 procedure inventory.** Add rows:
> | mcr.usp_LoadMbfrfFromSource | 15 | Derives MBFRF production/servicing/repurchase fields from the dbo staging tables; manual GL fields entered directly into mcr.MbfrfValues | Quarterly, before the pipeline (agency seller/servicers) |
> | mcr.usp_ValidateMbfrf | 15 | MBFRF internal checks (rule 13) + MCR reconciliation (rule 14); WARNING-only in mcr.ValidationResults | Automatic in pipeline stage 3b; standalone for reruns |
> | mcr.usp_GetMbfrfKeyingPackage | 15 | Ordered WebMB entry grid, KeyAs in rounded $000s; REFUSES while rule 13 failures exist | Quarterly, after a clean stage 3b |
> | mcr.usp_ArchiveMbfrf | 15 | Freezes the keyed values append-only with SHA-256; refuses on rule 13 failures | Quarterly, after WebMB submission |
> | mcr.usp_VerifyMbfrfArchive | 15 | Recomputes and compares each MBFRF archive hash | Quarter-end integrity control, with usp_VerifyFilingArchive |

**Edit 2 - Step 3 expected output.** After the stage 3a insert from
Part 1, also insert:
> === Stage 3b: MBFRF checks (rules 13/14) ===   (only if 15 deployed)
>
>   [two result grids: internal checks PASS/FAIL; MCR reconciliation
>    PASS/WARN. Findings written as MBFRF_CHECK / MBFRF_RECON]
And change the lead-in to "stage prints, three to five result grids,
archive confirmation".

**Edit 3 - new Step 3b section after Step 3a:**
> Step 3b - MBFRF checks and keying package (if the MBFRF layer is deployed)
>
> Stage before the pipeline; the pipeline runs the checks as stage 3b:
>
> EXEC mcr.usp_LoadMbfrfFromSource @FilingId = 2026002;
> -- plus manual INSERTs into mcr.MbfrfValues (whole dollars) for the
> -- balance-sheet and income fields, per the GL close
>
> After a clean run (no MBFRF_CHECK findings):
>
> EXEC mcr.usp_GetMbfrfKeyingPackage @FilingId = 2026002;
> -- key the KeyAs column into WebMB in grid order ($000s);
> -- CEO/CFO certification at submission
> EXEC mcr.usp_ArchiveMbfrf @FilingId = 2026002,
>      @Notes = N'Q2 2026 WebMB submission';
> EXEC mcr.usp_VerifyMbfrfArchive;
>
> NOTE: rule 13 failures hard-gate the keying package and the MBFRF
> archive but never block MCR XML generation - the MCR error gate reads
> only ERROR severity and MBFRF findings are WARNINGs. Rerun
> usp_ValidateMbfrf standalone after restaging values - always AFTER
> usp_ValidateFiling, which wipes the filing's validation rows.

**Edit 4 - Section 6.2 demo expected output.** After the HMDA comment
block, add:
> -- If 15 is installed, the script also stages MBFRF values (loader +
> -- tying manual entries) before the pipeline, so stage 3b runs rules
> -- 13/14 for 9211 and the script runs them for 9210: expected all
> -- PASS on both grids (the MBFRF layer demos the clean path; HMDA
> -- demos the WARNING path).

**Edit 5 - Section 6.3 first bullet** (supersedes Part 1 Edit 5). Final
wording:
> select all nine pbi.* views from 11 (plus pbi.FactHmdaRecon if 14 is deployed and pbi.FactMbfrf if 15 is deployed), Import mode.

---

## Version bump (supersedes Part 1 note)
Bump both documents to version 1.3. Record of Changes:
"Rules 12-14 run inside the pipeline (stages 3a/3b) so HMDA and MBFRF
findings are captured in the archive snapshot; MBFRF layer added
(15_mbfrf_layer.sql): internal checks, MCR reconciliation, gated WebMB
keying package, hash-verified MBFRF archive; PBI import wording covers
FactHmdaRecon and FactMbfrf."

## Governance Log
Add Change_Log rows for: (1) pipeline stages 3a/3b control change,
(2) MBFRF layer deployment. Add the WebMB submission + certifier columns
usage note to the Filing_Log ReadMe if desired.
