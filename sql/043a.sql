/* 043a: StewardList distinct fix. Replaces the view only. */
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
    RequiredDomains = COUNT(DISTINCT c.RequiredDomain),
    AccountableStewards =
        COUNT(DISTINCT c.ClassifiedByPartyId),
    StewardList =
        (SELECT STRING_AGG(x.PartyName, ', ')
                WITHIN GROUP (ORDER BY x.PartyName)
         FROM (SELECT DISTINCT p2.PartyName
               FROM reg.McrCoverageClassification c2
               JOIN gov.Party p2
                 ON p2.PartyId = c2.ClassifiedByPartyId
               WHERE c2.CoverageStatusCode
                     = c.CoverageStatusCode
                 AND c2.TargetProjectCode
                     = c.TargetProjectCode) x)
FROM reg.McrCoverageClassification c
LEFT JOIN
(
    SELECT DISTINCT ItemCode
    FROM reg.McrElementLineage
    WHERE CoverageCode = 'FULL'
) tr ON tr.ItemCode = c.ItemCode
GROUP BY c.CoverageStatusCode, c.TargetProjectCode;
GO

SELECT CoverageStatusCode, TargetProjectCode, Items,
       TraceableItems, AccountableStewards, StewardList
FROM pbi.vw_McrCoverageSummary
ORDER BY CoverageStatusCode, TargetProjectCode;