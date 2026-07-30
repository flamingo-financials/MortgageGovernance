/* ============================================================
   MortgageGovernance | Phase 2 | Script 032A
   MCR bridge reviewer surface.

   WHAT THIS IS
   Reconstructed from the deployed view definition. The file
   previously carried under this name was a byte-identical
   copy of 030_reg_mcr_bridge.sql, so no script in the
   repository created reg.vw_McrBridgeReview even though
   033, 034, 035 and 043 all read from it. A clean rebuild
   failed at 033. This closes that gap.

   The view body below is the definition running in the
   database, recovered with OBJECT_DEFINITION and rewritten
   in CREATE OR ALTER form. If the original file did
   anything beyond creating this view, that work is not
   recovered here. Nothing in 033 onward depends on anything
   else from 032A.

   WHAT IT DOES
   Resolves the bridge into the single review surface the
   lineage and coverage layers key on. Two decisions are
   made here and nowhere else:

     ResolvedNote      Steward judgment in
                       reg.McrBridgeDisposition supersedes
                       the generated ReviewNote. The
                       generated note is a starting point,
                       not a verdict.

     LineageScopeCode  Why an item does or does not get
                       source lineage. An item is not
                       eligible because it is NMLS
                       calculated, annotated, aliased,
                       deprecated or deferred. Ineligible
                       is a stated reason, never a silent
                       omission.

   LineageEligibleFlag is the gate. Only eligible items are
   classified in reg.McrCoverageClassification, so an item
   cannot be dropped from the denominator without a named
   disposition behind it.

   DEPENDENCIES
   reg.McrItemBridge          030
   reg.McrBridgeDisposition   032
   gov.Party                  004

   Run after 032. Azure SQL Database form: no USE, no
   three-part names. Read-only object. Idempotent.
   ============================================================ */
SET NOCOUNT ON;
GO

CREATE OR ALTER VIEW reg.vw_McrBridgeReview
AS
SELECT
    b.ItemCode,
    b.MatchStatusCode,
    b.GovComponentCode,
    b.GovSectionCode,
    b.GovItemName,
    b.McrScope,
    b.McrLabel,
    b.McrIsCalculated,
    b.McrIsRequired,
    b.McrElementCount,
    b.McrListName,
    b.ComponentAlignedFlag,
    b.CalcFlagAlignedFlag,
    d.DispositionCode,
    d.TargetItemCode,
    d.DispositionedByPartyId,
    DispositionedByName = p.PartyName,

    /* Steward judgment supersedes the generated note. */
    ResolvedNote =
        CASE
            WHEN d.Rationale IS NOT NULL THEN d.Rationale
            ELSE b.ReviewNote
        END,

    /* Single signal 033 keys on. */
    LineageScopeCode =
        CASE
            WHEN d.DispositionCode IN
                 ('ANNOTATION','ALIAS','DEPRECATED',
                  'COVERAGE_DEFERRED')
                 THEN d.DispositionCode
            WHEN b.MatchStatusCode = 'MATCHED_LIST'
                 THEN 'LIST_DETAIL'
            WHEN b.McrIsCalculated = 1 THEN 'NMLS_DERIVED'
            WHEN b.McrIsCalculated = 0 THEN 'SOURCE_LINEAGE'
            ELSE 'UNRESOLVED'
        END,

    LineageEligibleFlag =
        CASE
            WHEN d.DispositionCode IN
                 ('ANNOTATION','ALIAS','DEPRECATED',
                  'COVERAGE_DEFERRED') THEN 0
            WHEN b.MatchStatusCode = 'MATCHED_LIST' THEN 1
            WHEN ISNULL(b.McrIsCalculated, 1) = 1 THEN 0
            ELSE 1
        END
FROM reg.McrItemBridge b
LEFT JOIN reg.McrBridgeDisposition d
       ON d.GovItemCode = b.ItemCode
LEFT JOIN gov.Party p
       ON p.PartyId = d.DispositionedByPartyId;
GO

/* ------------------------------------------------------------
   Verification. Expected results are stated so a deviation
   is visible without consulting another document.
   ------------------------------------------------------------ */

/* 1. Row count. Expected 648, one per governed FV7 item. */
SELECT Items = COUNT(*) FROM reg.vw_McrBridgeReview;

/* 2. Lineage scope distribution. Expected:
        SOURCE_LINEAGE      508
        NMLS_DERIVED        124
        LIST_DETAIL           5
        ANNOTATION            5
        ALIAS                 3
        COVERAGE_DEFERRED     2
        DEPRECATED            1
        UNRESOLVED            0
   Any UNRESOLVED row is a defect: it means an item is
   neither dispositioned nor carries a calculated flag. */
SELECT LineageScopeCode, Items = COUNT(*)
FROM reg.vw_McrBridgeReview
GROUP BY LineageScopeCode
ORDER BY Items DESC;

/* 3. Eligibility gate. Expected 513 eligible, 135 not. */
SELECT LineageEligibleFlag, Items = COUNT(*)
FROM reg.vw_McrBridgeReview
GROUP BY LineageEligibleFlag
ORDER BY LineageEligibleFlag DESC;

/* 4. Every eligible item is classified downstream.
      Expected 0. Non-zero means 035 has not run or an item
      entered the bridge after it did. */
SELECT UnclassifiedEligible = COUNT(*)
FROM reg.vw_McrBridgeReview r
WHERE r.LineageEligibleFlag = 1
  AND NOT EXISTS
      (SELECT 1
       FROM reg.McrCoverageClassification c
       WHERE c.ItemCode = r.ItemCode);

/* 5. Ineligible items carry a stated reason, never a
      silent drop. Expected 0. */
SELECT IneligibleWithoutReason = COUNT(*)
FROM reg.vw_McrBridgeReview
WHERE LineageEligibleFlag = 0
  AND LineageScopeCode = 'UNRESOLVED';
GO
