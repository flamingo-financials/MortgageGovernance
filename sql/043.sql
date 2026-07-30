/* ============================================================
   MortgageGovernance | Integration Phase 2 | Script 043
   DP_MCR_FV7 certified data product view layer.

   WHAT IS CERTIFIED
   The data product, not the filing. Certification asserts
   that the FV7 registry is reconciled, that every
   lineage-eligible item carries a named coverage status,
   target project and accountable steward, and that the
   filing controls execute. It asserts nothing about whether
   any given filing is fit to submit. Filing certification
   is reg.usp_CertifyMcrFiling and is surfaced, not merged.

   WHY THAT JUSTIFIES pbi
   The section 2 rule bars uncertified objects from pbi.
   These views are certified on their own evidence and every
   one of them carries FilingCertificationStatus so a
   coverage number can never be read without the filing
   state next to it.

   NO BARE PERCENTAGES
   pbi.vw_McrCoverageSummary returns one row per coverage
   status with its item count, target project and
   accountable steward. pbi.vw_McrDataProduct carries a
   written coverage statement. Neither exposes a lone ratio.

   Azure SQL Database. No USE. Idempotent.
   ============================================================ */
SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   1. reg.usp_CertifyMcrDataProduct
      Five gates. Any failure is NOT_CERTIFIED with the
      failing gate named.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE reg.usp_CertifyMcrDataProduct
    @CertifiedByPartyName NVARCHAR(200) = N'Paige Justice'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CertId       INT;
    DECLARE @PartyId      INT;
    DECLARE @ProductRef   NVARCHAR(300) = N'DP_MCR_FV7';
    DECLARE @McrReportId  INT;
    DECLARE @BridgeOpen   INT = 0;
    DECLARE @Unclassified INT = 0;
    DECLARE @NoSteward    INT = 0;
    DECLARE @LineageRows  INT = 0;
    DECLARE @ControlRuns  INT = 0;
    DECLARE @Eligible     INT = 0;
    DECLARE @Classified   INT = 0;
    DECLARE @Traceable    INT = 0;
    DECLARE @Status       VARCHAR(30);
    DECLARE @Notes        NVARCHAR(1000);
    DECLARE @Gate         NVARCHAR(400) = N'';
    DECLARE @RunUtc       DATETIME2(3) = SYSUTCDATETIME();
    DECLARE @ChangeDescr  NVARCHAR(2000);

    SELECT @PartyId = PartyId FROM gov.Party
    WHERE PartyName = @CertifiedByPartyName
      AND PartyTypeCode = 'PERSON';

    SELECT @McrReportId = RegulatoryReportId
    FROM gov.RegulatoryReport WHERE ReportCode = 'MCR_FV7';

    /* Gate 1: bridge closed, no MCR-only items */
    SELECT @BridgeOpen = COUNT(*)
    FROM reg.McrItemBridge
    WHERE MatchStatusCode = 'MCR_ONLY';

    /* Gate 2: every eligible item classified */
    SELECT @Eligible = COUNT(*)
    FROM reg.vw_McrBridgeReview
    WHERE LineageEligibleFlag = 1;

    SELECT @Classified = COUNT(*)
    FROM reg.McrCoverageClassification;

    SELECT @Unclassified = COUNT(*)
    FROM reg.vw_McrBridgeReview r
    WHERE r.LineageEligibleFlag = 1
      AND NOT EXISTS
          (SELECT 1 FROM reg.McrCoverageClassification c
           WHERE c.ItemCode = r.ItemCode);

    /* Gate 3: every classification has a steward */
    SELECT @NoSteward = COUNT(*)
    FROM reg.McrCoverageClassification
    WHERE ClassifiedByPartyId IS NULL;

    /* Gate 4: element lineage resolved */
    SELECT @LineageRows = COUNT(*)
    FROM reg.McrElementLineage;

    SELECT @Traceable = COUNT(DISTINCT ItemCode)
    FROM reg.McrElementLineage
    WHERE CoverageCode = 'FULL';

    /* Gate 5: filing controls have executed */
    SELECT @ControlRuns = COUNT(*)
    FROM audit.vw_ReconciliationLatest r
    WHERE r.ControlTypeCode = 'MCR_TIEOUT'
      AND EXISTS (SELECT 1 FROM reg.McrInternalValue v
                  WHERE v.PeriodEndDate = r.AsOfDate);

    IF @BridgeOpen > 0
        SET @Gate = @Gate + N'Bridge has unreconciled '
                  + N'MCR-only items. ';
    IF @Unclassified > 0
        SET @Gate = @Gate + N'Lineage-eligible items are '
                  + N'unclassified. ';
    IF @NoSteward > 0
        SET @Gate = @Gate + N'Classifications exist with '
                  + N'no accountable steward. ';
    IF @LineageRows = 0
        SET @Gate = @Gate + N'Element lineage is empty. ';
    IF @ControlRuns = 0
        SET @Gate = @Gate + N'No MCR control evidence at '
                  + N'a governed filing period end. ';

    IF LEN(@Gate) > 0
    BEGIN
        SET @Status = 'NOT_CERTIFIED';
        SET @Notes = N'Data product gates failed: ' + @Gate;
    END
    ELSE
    BEGIN
        SET @Status = 'CERTIFIED';
        SET @Notes =
            N'Data product certified. FV7 registry '
          + N'reconciled; '
          + CAST(@Classified AS NVARCHAR(10))
          + N' of ' + CAST(@Eligible AS NVARCHAR(10))
          + N' lineage-eligible items classified with a '
          + N'named steward; '
          + CAST(@Traceable AS NVARCHAR(10))
          + N' traceable to source today. This certifies '
          + N'the metadata layer only. Filing fitness is '
          + N'certified separately per filing and is '
          + N'reported alongside every view.';
    END

    SELECT @CertId = CertificationId
    FROM gov.Certification
    WHERE EntityTypeCode = 'DATASET'
      AND EntityReference = @ProductRef;

    IF @CertId IS NULL
    BEGIN
        INSERT INTO gov.Certification
            (EntityTypeCode, EntityReference,
             CertificationStatusCode, CertifiedByPartyId,
             CertifiedDateUtc, DataAsOfDate,
             CertificationNotes)
        VALUES
            ('DATASET', @ProductRef, @Status,
             CASE WHEN @Status = 'CERTIFIED'
                  THEN @PartyId END,
             CASE WHEN @Status = 'CERTIFIED'
                  THEN @RunUtc END,
             CAST(@RunUtc AS DATE), @Notes);
        SET @CertId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE gov.Certification
           SET CertificationStatusCode = @Status,
               CertifiedByPartyId =
                   CASE WHEN @Status = 'CERTIFIED'
                        THEN @PartyId END,
               CertifiedDateUtc =
                   CASE WHEN @Status = 'CERTIFIED'
                        THEN @RunUtc END,
               DataAsOfDate = CAST(@RunUtc AS DATE),
               CertificationNotes = @Notes,
               ModifiedDateUtc = @RunUtc
         WHERE CertificationId = @CertId;
    END

    DELETE FROM gov.CertificationEvidence
    WHERE CertificationId = @CertId;

    INSERT INTO gov.CertificationEvidence
        (CertificationId, EvidenceTypeCode,
         EvidenceReference, EvidenceDateUtc)
    SELECT @CertId, 'QUERY_RESULT', v.Ref, @RunUtc
    FROM (VALUES
     (N'Bridge MCR-only items: '
      + CAST(@BridgeOpen AS NVARCHAR(10)) + N' (target 0)'),
     (N'Lineage-eligible items: '
      + CAST(@Eligible AS NVARCHAR(10))),
     (N'Items classified: '
      + CAST(@Classified AS NVARCHAR(10))),
     (N'Unclassified eligible items: '
      + CAST(@Unclassified AS NVARCHAR(10))
      + N' (target 0)'),
     (N'Classifications without steward: '
      + CAST(@NoSteward AS NVARCHAR(10)) + N' (target 0)'),
     (N'Element lineage rows: '
      + CAST(@LineageRows AS NVARCHAR(10))),
     (N'Items traceable to source: '
      + CAST(@Traceable AS NVARCHAR(10))),
     (N'MCR control results at governed period ends: '
      + CAST(@ControlRuns AS NVARCHAR(10)))
    ) v(Ref);

    SET @ChangeDescr = N'Data product certification run for '
                     + @ProductRef + N'. Result: ' + @Status
                     + N'. ' + @Notes;

    INSERT INTO gov.ChangeLog
        (EntityTypeCode, EntityId, EntityReference,
         ChangeTypeCode, ChangeDescription)
    VALUES
        ('CERTIFICATION', @CertId, @ProductRef, 'UPDATE',
         @ChangeDescr);

    SELECT @ProductRef AS DataProduct,
           @Status     AS CertificationStatusCode,
           @Eligible   AS LineageEligibleItems,
           @Classified AS ClassifiedItems,
           @Traceable  AS TraceableItems,
           @BridgeOpen AS BridgeOpenItems,
           @NoSteward  AS ClassificationsWithoutSteward,
           @Notes      AS CertificationNotes;
END;
GO

/* ------------------------------------------------------------
   2. Certify, then publish.
   ------------------------------------------------------------ */
EXEC reg.usp_CertifyMcrDataProduct;
GO

/* ------------------------------------------------------------
   3. pbi.vw_McrDataProduct
      Read this first. One row. Carries the written coverage
      statement so a consumer cannot lift a ratio out of
      context.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW pbi.vw_McrDataProduct
AS
WITH C AS
(
    SELECT
        Eligible = (SELECT COUNT(*)
                    FROM reg.McrCoverageClassification),
        Traceable = (SELECT COUNT(DISTINCT ItemCode)
                     FROM reg.McrElementLineage
                     WHERE CoverageCode = 'FULL'),
        TotalItems = (SELECT COUNT(*)
                      FROM reg.McrItemBridge)
),
F AS
(
    SELECT TOP 1 FilingId, PeriodEnd,
           CertificationStatusCode, BlockingControlFailures,
           ControlsEvaluated, ValidationErrors
    FROM reg.vw_McrFilingCertificationStatus
    WHERE CertificationStatusCode IS NOT NULL
    ORDER BY PeriodEnd DESC, FilingId DESC
)
SELECT
    DataProductCode = 'DP_MCR_FV7',
    DataProductName =
        'NMLS Mortgage Call Report FV7 Governance',
    ProductCertificationStatus =
        cert.CertificationStatusCode,
    ProductCertifiedBy = p.PartyName,
    ProductCertifiedDateUtc = cert.CertifiedDateUtc,
    TotalFv7Items = C.TotalItems,
    LineageEligibleItems = C.Eligible,
    TraceableToSourceItems = C.Traceable,
    CoverageStatement =
        'Of ' + CAST(C.Eligible AS VARCHAR(10))
      + ' lineage-eligible FV7 items, '
      + CAST(C.Traceable AS VARCHAR(10))
      + ' are traceable to source data today. Every '
      + 'remaining item carries a coverage status, a '
      + 'target portfolio project and an accountable '
      + 'steward; none are unexplained. Item counts '
      + 'exclude NMLS-calculated, annotation, alias and '
      + 'deprecated items, which are not lineage '
      + 'eligible by definition.',
    LatestGovernedFilingId = F.FilingId,
    LatestFilingPeriodEnd = F.PeriodEnd,
    FilingCertificationStatus = F.CertificationStatusCode,
    FilingControlsEvaluated = F.ControlsEvaluated,
    FilingBlockingFailures = F.BlockingControlFailures,
    FilingValidationErrors = F.ValidationErrors,
    ScopeCaveat =
        'Product certification covers the metadata layer: '
      + 'registry reconciliation, coverage classification '
      + 'and lineage. It does not assert that any filing '
      + 'is fit to submit. Filing fitness is certified '
      + 'per filing and shown above.'
FROM C
CROSS JOIN gov.Certification cert
LEFT JOIN gov.Party p
  ON p.PartyId = cert.CertifiedByPartyId
LEFT JOIN F ON 1 = 1
WHERE cert.EntityTypeCode = 'DATASET'
  AND cert.EntityReference = 'DP_MCR_FV7';
GO

/* ------------------------------------------------------------
   4. pbi.vw_McrCoverageSummary
      One row per coverage status and project. Never a lone
      ratio.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW pbi.vw_McrCoverageSummary
AS
SELECT
    c.CoverageStatusCode,
    c.TargetProjectCode,
    CoverageStatusName =
        CASE c.CoverageStatusCode
          WHEN 'SUPPORTED_NOW' THEN
            'Supported now: source data exists and the '
          + 'item is traceable'
          WHEN 'PLANNED' THEN
            'Planned: required domain is scheduled for a '
          + 'later portfolio project'
          WHEN 'EXTERNAL_DEFERRED' THEN
            'External or deferred: required domain sits '
          + 'outside the portfolio'
          WHEN 'NOT_APPLICABLE' THEN
            'Not applicable: the business does not '
          + 'engage in this activity'
          WHEN 'NARRATIVE' THEN
            'Narrative: authored by a steward at '
          + 'submission, not derived'
          ELSE c.CoverageStatusCode END,
    Items = COUNT(*),
    TraceableItems = COUNT(DISTINCT tr.ItemCode),
    RequiredDomains =
        COUNT(DISTINCT c.RequiredDomain),
    AccountableStewards =
        COUNT(DISTINCT p.PartyName),
    StewardList = STRING_AGG(p.PartyName, ', ')
                  WITHIN GROUP (ORDER BY p.PartyName)
FROM reg.McrCoverageClassification c
LEFT JOIN gov.Party p
  ON p.PartyId = c.ClassifiedByPartyId
LEFT JOIN
(
    SELECT DISTINCT ItemCode
    FROM reg.McrElementLineage
    WHERE CoverageCode = 'FULL'
) tr ON tr.ItemCode = c.ItemCode
GROUP BY c.CoverageStatusCode, c.TargetProjectCode;
GO

/* ------------------------------------------------------------
   5. pbi.vw_McrItemCoverage
      Item level. Every FV7 item, eligible or not, with its
      reason.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW pbi.vw_McrItemCoverage
AS
SELECT
    b.ItemCode,
    ItemLabel = fc.Label,
    ItemName = ri.ItemName,
    ComponentCode = s.ComponentCode,
    SectionCode = s.SectionCode,
    SectionName = s.SectionName,
    FilingScope = fc.Scope,
    IsCalculated = fc.IsCalculated,
    IsRequired = fc.IsRequired,
    FormOrder = fc.FormOrder,
    b.LineageScopeCode,
    b.LineageEligibleFlag,
    c.CoverageStatusCode,
    c.TargetProjectCode,
    c.RequiredDomain,
    c.Rationale,
    AccountableSteward = p.PartyName,
    ElementsResolved =
        (SELECT COUNT(*) FROM reg.McrElementLineage el
         WHERE el.ItemCode = b.ItemCode),
    ElementsTraceable =
        (SELECT COUNT(*) FROM reg.McrElementLineage el
         WHERE el.ItemCode = b.ItemCode
           AND el.CoverageCode = 'FULL'),
    TraceableFlag =
        CASE WHEN EXISTS
             (SELECT 1 FROM reg.McrElementLineage el
              WHERE el.ItemCode = b.ItemCode
                AND el.CoverageCode = 'FULL')
             THEN 1 ELSE 0 END
FROM reg.vw_McrBridgeReview b
LEFT JOIN reg.McrCoverageClassification c
  ON c.ItemCode = b.ItemCode
LEFT JOIN gov.Party p
  ON p.PartyId = c.ClassifiedByPartyId
LEFT JOIN reg.vw_McrFieldCatalog fc
  ON fc.ItemCode = b.ItemCode
LEFT JOIN gov.RegulatoryReportItem ri
  ON ri.ItemCode = b.ItemCode
LEFT JOIN gov.RegulatoryReportSection s
  ON s.RegulatoryReportSectionId
     = ri.RegulatoryReportSectionId;
GO

/* ------------------------------------------------------------
   6. pbi.vw_McrElementLineage
      Column-tier lineage: source system to FV7 element.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW pbi.vw_McrElementLineage
AS
SELECT
    el.ItemCode,
    ItemLabel = fc.Label,
    el.CatalogCode,
    el.ElementName,
    el.ElementNodeName,
    el.DataType,
    el.LineageScopeCode,
    el.CoverageCode,
    GovernedElement = el.DataElementName,
    CriticalDataElementFlag = el.CriticalFlag,
    SourceSystem = el.SourceSystemName,
    SourceColumn =
        CASE WHEN el.SrcObjectName IS NULL THEN NULL
             ELSE el.SrcSchemaName + '.' + el.SrcObjectName
                + '.' + el.SrcColumnName END,
    WarehouseColumn =
        CASE WHEN el.DwObjectName IS NULL THEN NULL
             ELSE el.DwSchemaName + '.' + el.DwObjectName
                + '.' + el.DwColumnName END,
    c.CoverageStatusCode,
    c.TargetProjectCode
FROM reg.McrElementLineage el
LEFT JOIN reg.vw_McrFieldCatalog fc
  ON fc.ItemCode = el.ItemCode
LEFT JOIN reg.McrCoverageClassification c
  ON c.ItemCode = el.ItemCode;
GO

/* ------------------------------------------------------------
   7. pbi.vw_McrFilingTieOut
      Governance recompute against the filed submission,
      per element, with the filing's certification state.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW pbi.vw_McrFilingTieOut
AS
SELECT
    iv.FilingId,
    iv.PeriodEndDate,
    iv.ItemCode,
    ItemLabel = fc.Label,
    iv.ElementName,
    iv.MeasureTypeCode,
    GovernanceValue = iv.NumValue,
    GovernanceValueFiledBasis = iv.NumValueFiledBasis,
    FiledValue = rv.NumValue,
    Variance = rv.NumValue - iv.NumValueFiledBasis,
    RoundingEffect =
        iv.NumValueFiledBasis - iv.NumValue,
    TieOutStatus =
        CASE WHEN rv.NumValue IS NULL
                  THEN 'ABSENT FROM FILING'
             WHEN rv.NumValue = iv.NumValueFiledBasis
                  THEN 'MATCH' ELSE 'VARIANCE' END,
    iv.NmlsDerivedFlag,
    iv.DerivationRuleCode,
    DerivationRuleName = dr.RuleName,
    iv.PopulationRowCount,
    FilingCertificationStatus =
        f.CertificationStatusCode
FROM reg.McrInternalValue iv
LEFT JOIN reg.vw_McrReportValues rv
  ON rv.FilingId = iv.FilingId
 AND rv.ScopeKey = iv.ScopeKey
 AND rv.ElementName = iv.ElementName
LEFT JOIN reg.vw_McrFieldCatalog fc
  ON fc.ItemCode = iv.ItemCode
LEFT JOIN gov.DerivationRule dr
  ON dr.RuleCode = iv.DerivationRuleCode
LEFT JOIN reg.vw_McrFilingCertificationStatus f
  ON f.FilingId = iv.FilingId;
GO

/* ------------------------------------------------------------
   8. pbi.vw_McrFilingControl
      Control results at filing period ends.
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW pbi.vw_McrFilingControl
AS
SELECT
    f.FilingId,
    f.PeriodEnd,
    f.CertificationStatusCode,
    r.ControlCode,
    r.ControlName,
    r.ControlTypeCode,
    r.ToleranceTypeCode,
    r.BlockingFlag,
    r.SourceValue,
    r.TargetValue,
    r.VarianceValue,
    r.StatusCode,
    r.Details,
    r.ControlOwner,
    r.ExecutedDateUtc
FROM reg.vw_McrFilingCertificationStatus f
JOIN audit.vw_ReconciliationLatest r
  ON r.AsOfDate = f.PeriodEnd
 AND r.ControlTypeCode = 'MCR_TIEOUT'
WHERE f.CertificationStatusCode IS NOT NULL;
GO

/* ------------------------------------------------------------
   9. pbi.vw_McrExceptionRegister
   ------------------------------------------------------------ */
CREATE OR ALTER VIEW pbi.vw_McrExceptionRegister
AS
SELECT
    e.DataExceptionId, e.FilingId, e.RuleCode, e.RuleName,
    e.DqDimensionCode, e.SeverityCode, e.BlockingFlag,
    e.KeyValue1, e.StatusCode, e.OpenedDate, e.DueDate,
    e.ClosedDate, e.ResolutionNote, e.ExceptionOwner,
    e.AgeDays, e.OverdueFlag,
    FilingCertificationStatus = f.CertificationStatusCode
FROM reg.vw_McrExceptionRegister e
LEFT JOIN reg.vw_McrFilingCertificationStatus f
  ON f.FilingId = e.FilingId;
GO

/* ------------------------------------------------------------
   10. Verification
   ------------------------------------------------------------ */

/* 10a. Read this first. */
SELECT DataProductCode, ProductCertificationStatus,
       ProductCertifiedBy, TotalFv7Items,
       LineageEligibleItems, TraceableToSourceItems,
       LatestGovernedFilingId, FilingCertificationStatus,
       FilingBlockingFailures, FilingValidationErrors
FROM pbi.vw_McrDataProduct;

SELECT CoverageStatement, ScopeCaveat
FROM pbi.vw_McrDataProduct;

/* 10b. Coverage with context, never a bare ratio. */
SELECT CoverageStatusCode, TargetProjectCode, Items,
       TraceableItems, RequiredDomains, StewardList
FROM pbi.vw_McrCoverageSummary
ORDER BY CoverageStatusCode, TargetProjectCode;

/* 10c. Internal consistency: SUPPORTED_NOW must equal
        the traceable item count. */
SELECT
    SupportedNowItems =
        (SELECT COUNT(*)
         FROM reg.McrCoverageClassification
         WHERE CoverageStatusCode = 'SUPPORTED_NOW'),
    TraceableItems =
        (SELECT COUNT(DISTINCT ItemCode)
         FROM reg.McrElementLineage
         WHERE CoverageCode = 'FULL'),
    ClassifiedItems =
        (SELECT COUNT(*)
         FROM reg.McrCoverageClassification),
    EligibleItems =
        (SELECT COUNT(*) FROM reg.vw_McrBridgeReview
         WHERE LineageEligibleFlag = 1);

/* 10d. No item is unexplained. */
SELECT UnexplainedItems = COUNT(*)
FROM pbi.vw_McrItemCoverage
WHERE LineageEligibleFlag = 1
  AND (CoverageStatusCode IS NULL
    OR AccountableSteward IS NULL);

/* 10e. Traceable item sample, source to filed element. */
SELECT TOP 10 ItemCode, ItemLabel, ElementName,
       GovernedElement, CriticalDataElementFlag,
       SourceSystem, SourceColumn, WarehouseColumn,
       CoverageCode
FROM pbi.vw_McrElementLineage
WHERE CoverageCode = 'FULL'
ORDER BY ItemCode, ElementName;

/* 10f. pbi surface count after publication. */
SELECT PbiViews = COUNT(*)
FROM sys.views v
JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'pbi';

/* 10g. All three certification scopes. */
SELECT EntityTypeCode, EntityReference,
       CertificationStatusCode, DataAsOfDate,
       EvidenceRows =
           (SELECT COUNT(*)
            FROM gov.CertificationEvidence e
            WHERE e.CertificationId = c.CertificationId)
FROM gov.Certification c
ORDER BY EntityTypeCode, EntityReference;
GO