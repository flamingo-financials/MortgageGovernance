/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_11_pbi_views.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT - ADD-ON
   11 - Power BI semantic layer: star-schema views (pbi schema)
   ----------------------------------------------------------------------------
   Prereq: 01 + 02 installed (reads mcr.Filing, catalog, staging, source).
   Import every pbi.* view into Power BI (Import mode).

   STAR SCHEMA / RELATIONSHIPS (create in the model):
     DimFiling[FilingId]  1 -> * every fact's [FilingId]
     DimScope[ScopeKey]   1 -> * FactReportValues, FactVariance,
                                 FactValidation [ScopeKey]
     DimScope[ScopeKey]   1 -> * FactClosedLoans, FactServicing,
                                 FactMloProduction [StateCode]
     DimField[ItemCode]   1 -> * FactReportValues, FactVariance [ItemCode]
       (leave FactValidation[ItemCode] unrelated: it carries pseudo-codes
        like LS_TOTALS that are not catalog items)

   Facts are element-grain or loan-grain; all math lives in DAX measures
   (see 13_pbi_measures.tmdl). No calculated columns needed.
   ============================================================================ */
IF SCHEMA_ID('mcrpbi') IS NULL EXEC('CREATE SCHEMA mcrpbi;');
GO

/* ------------------------------------------------------------ DimFiling */
CREATE OR ALTER VIEW mcrpbi.DimFiling AS
SELECT
    f.FilingId,
    f.CompanyNmlsId,
    f.CompanyName,
    f.[Year],
    f.PeriodType,
    PeriodLabel = CAST(f.[Year] AS VARCHAR(4)) + ' '
                + CASE f.PeriodType
                      WHEN 'MCRANNUAL' THEN 'Annual'
                      ELSE RIGHT(f.PeriodType, 2) END,
    f.PeriodStart,
    f.PeriodEnd,
    f.PrimaryStateCode,
    f.PriorFilingId,
    f.FormVersion,
    IsTestFiling = CASE WHEN f.FilingId BETWEEN 9000 AND 9999
                        THEN 1 ELSE 0 END
FROM mcr.Filing f;
GO

/* ------------------------------------------------------------- DimField */
CREATE OR ALTER VIEW mcrpbi.DimField AS
SELECT
    fc.ItemCode,
    fc.Label,
    fc.Scope,
    fc.IsCalculated,
    fc.IsRequired,
    fc.FormOrder,
    fc.SectionPath,
    Component = CASE
        WHEN fc.SectionPath LIKE 'Mcr/Rmlag%' THEN 'RMLA Company'
        WHEN fc.SectionPath LIKE 'Mcr/Rmla/%' THEN 'RMLA State'
        WHEN fc.SectionPath LIKE 'Mcr/Fc%'    THEN 'Financial Condition'
        WHEN fc.SectionPath LIKE 'Mcr/Sssf%'  THEN 'SSSF'
        ELSE 'Other' END,
    Section = CASE
        WHEN fc.SectionPath = '' THEN '(schema-only)'
        ELSE RIGHT(fc.SectionPath,
                   CHARINDEX('/', REVERSE(fc.SectionPath)) - 1) END
FROM mcr.FieldCatalog fc;
GO

/* ------------------------------------------------------------- DimScope */
CREATE OR ALTER VIEW mcrpbi.DimScope AS
SELECT
    s.ScopeKey,
    ScopeType = CASE s.ScopeKey
                    WHEN 'COMPANY' THEN 'Company'
                    WHEN 'FC'      THEN 'Financial Condition'
                    ELSE 'State' END,
    StateCode = CASE WHEN s.ScopeKey NOT IN ('COMPANY','FC')
                     THEN s.ScopeKey END
FROM (
    SELECT DISTINCT ScopeKey FROM mcr.ReportValues
    UNION
    SELECT DISTINCT ScopeKey FROM mcr.RepeatingValues
) s;
GO

/* ---------------------------------------------------- FactReportValues */
CREATE OR ALTER VIEW mcrpbi.FactReportValues AS
SELECT
    rv.FilingId,
    rv.ScopeKey,
    rv.ElementName,
    e.ItemCode,
    e.DataType,
    Kind = CASE WHEN e.DataType = 'Count' THEN 'COUNT' ELSE 'AMOUNT' END,
    rv.NumValue,
    rv.TextValue
FROM mcr.ReportValues rv
JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName;
GO

/* -------------------------------------------------------- FactVariance *
   Same pairing logic as mcr.usp_QaVariance, exposed as a view keyed by
   the CURRENT FilingId so it slices with DimFiling. Fixed 25% flag
   threshold (strictly greater, matching usp_QaVariance's default);
   PctChange is exposed so DAX can apply its own threshold.             */
CREATE OR ALTER VIEW mcrpbi.FactVariance AS
WITH pairs AS (
    SELECT FilingId, PriorFilingId
    FROM mcr.Filing
    WHERE PriorFilingId IS NOT NULL
),
cur AS (
    SELECT p.FilingId, rv.ScopeKey, rv.ElementName, rv.NumValue
    FROM pairs p
    JOIN mcr.ReportValues rv ON rv.FilingId = p.FilingId
    WHERE rv.NumValue IS NOT NULL
),
pri AS (
    SELECT p.FilingId, rv.ScopeKey, rv.ElementName, rv.NumValue
    FROM pairs p
    JOIN mcr.ReportValues rv ON rv.FilingId = p.PriorFilingId
    WHERE rv.NumValue IS NOT NULL
),
j AS (
    SELECT
        FilingId    = COALESCE(c.FilingId, q.FilingId),
        ScopeKey    = COALESCE(c.ScopeKey, q.ScopeKey),
        ElementName = COALESCE(c.ElementName, q.ElementName),
        PriorVal    = q.NumValue,
        CurrentVal  = c.NumValue
    FROM cur c
    FULL OUTER JOIN pri q
      ON q.FilingId = c.FilingId
     AND q.ScopeKey = c.ScopeKey
     AND q.ElementName = c.ElementName
)
SELECT
    j.FilingId,
    j.ScopeKey,
    j.ElementName,
    e.ItemCode,
    Kind = CASE WHEN e.DataType = 'Count' THEN 'COUNT' ELSE 'AMOUNT' END,
    PriorVal   = ISNULL(j.PriorVal, 0),
    CurrentVal = ISNULL(j.CurrentVal, 0),
    VarianceVal = ISNULL(j.CurrentVal, 0) - ISNULL(j.PriorVal, 0),
    PctChange = CASE WHEN ISNULL(j.PriorVal, 0) = 0 THEN NULL
                     ELSE CAST((ISNULL(j.CurrentVal, 0) - j.PriorVal)
                          * 100.0 / ABS(j.PriorVal) AS DECIMAL(15,2)) END,
    Flag = CASE
        WHEN ISNULL(j.PriorVal, 0) = 0 AND ISNULL(j.CurrentVal, 0) <> 0
            THEN 'NEW'
        WHEN ISNULL(j.CurrentVal, 0) = 0 AND ISNULL(j.PriorVal, 0) <> 0
            THEN 'DROPPED'
        WHEN ABS((ISNULL(j.CurrentVal, 0) - j.PriorVal)
                 * 100.0 / ABS(NULLIF(j.PriorVal, 0))) > 25.0
            THEN 'FLAG'
        ELSE 'OK' END
FROM j
JOIN mcr.FieldCatalogElement e ON e.ElementName = j.ElementName;
GO

/* ------------------------------------------------------ FactValidation */
CREATE OR ALTER VIEW mcrpbi.FactValidation AS
SELECT
    v.FilingId,
    v.Severity,
    v.RuleType,
    v.ScopeKey,
    v.ItemCode,
    v.Detail
FROM mcr.ValidationResults v;
GO

/* --------------------------------------------------- FactMloProduction *
   Pivots the SectionIMlosItem repeating list to one row per MLO/state.  */
CREATE OR ALTER VIEW mcrpbi.FactMloProduction AS
SELECT
    r.FilingId,
    StateCode = r.ScopeKey,
    r.ItemSeq,
    MloNmlsId = MAX(CASE WHEN r.ElementName = 'ACMLO'
                         THEN CAST(r.NumValue AS BIGINT) END),
    Amount    = MAX(CASE WHEN r.ElementName = 'ACMLO_2'
                         THEN r.NumValue END),
    LoanCount = MAX(CASE WHEN r.ElementName = 'ACMLO_3'
                         THEN CAST(r.NumValue AS INT) END)
FROM mcr.RepeatingValues r
WHERE r.ListName = 'SectionIMlosItem'
GROUP BY r.FilingId, r.ScopeKey, r.ItemSeq;
GO

/* ------------------------------------------------------ FactClosedLoans *
   Loan grain for drill-through; LTV precomputed so DAX stays measure-only */
CREATE OR ALTER VIEW mcrpbi.FactClosedLoans AS
SELECT
    c.LoanId,
    c.FilingId,
    c.StateCode,
    c.CloseDate,
    c.Channel,
    c.LoanType,
    c.PropertyType,
    c.Purpose,
    c.LienStatus,
    c.HoepaStatus,
    c.AmortType,
    c.Conforming,
    c.QmStatus,
    c.ServicingDispo,
    c.UPB,
    c.NoteAmount,
    c.AppraisedValue,
    c.FicoScore,
    c.NoteRatePct,
    c.MloNmlsId,
    LtvPct = CAST(c.NoteAmount * 100.0
                  / NULLIF(c.AppraisedValue, 0) AS DECIMAL(9,2))
FROM mcrstg.ClosedLoans c;
GO

/* -------------------------------------------------------- FactServicing */
CREATE OR ALTER VIEW mcrpbi.FactServicing AS
SELECT
    s.ServiceId,
    s.FilingId,
    s.StateCode,
    s.OwnershipType,
    s.Investor,
    s.DelinquencyBucket,
    s.InForeclosure,
    s.UPB,
    IsDelinquent = CASE WHEN s.DelinquencyBucket <> 'LT30'
                        THEN 1 ELSE 0 END
FROM mcrstg.ServicingPortfolio s;
GO

PRINT '11 complete: pbi.* views created (import all into Power BI).';
GO
