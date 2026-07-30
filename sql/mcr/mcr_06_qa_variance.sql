/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_06_qa_variance.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT (FULL SCHEMA)
   06 - QA: quarter-over-quarter variance at element level
   ----------------------------------------------------------------------------
   mcr.usp_QaVariance @FilingId, @AmtThresholdPct = 25.0, @CntThresholdPct = 25.0
     Compares every staged element against the prior filing (mcr.Filing.
     PriorFilingId). Flags $ and count swings separately. Regulators read
     these reports quarter over quarter; investigate every flag before
     submission and attach an explanatory note where a swing is real.
   ============================================================================ */
IF OBJECT_ID('mcr.usp_QaVariance') IS NOT NULL DROP PROCEDURE mcr.usp_QaVariance;
GO
CREATE PROCEDURE mcr.usp_QaVariance
    @FilingId        INT,
    @AmtThresholdPct DECIMAL(9,2) = 25.0,
    @CntThresholdPct DECIMAL(9,2) = 25.0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PriorId INT;
    SELECT @PriorId = PriorFilingId FROM mcr.Filing WHERE FilingId = @FilingId;
    IF @PriorId IS NULL
    BEGIN
        PRINT 'Filing ' + CAST(@FilingId AS VARCHAR(10)) + ' has no PriorFilingId; variance skipped.';
        RETURN;
    END

    ;WITH cur AS (
        SELECT ScopeKey, ElementName, NumValue
        FROM mcr.ReportValues WHERE FilingId = @FilingId AND NumValue IS NOT NULL
    ),
    pri AS (
        SELECT ScopeKey, ElementName, NumValue
        FROM mcr.ReportValues WHERE FilingId = @PriorId AND NumValue IS NOT NULL
    ),
    j AS (
        SELECT ScopeKey   = COALESCE(c.ScopeKey, p.ScopeKey),
               ElementName= COALESCE(c.ElementName, p.ElementName),
               PriorVal   = p.NumValue,
               CurrentVal = c.NumValue
        FROM cur c
        FULL OUTER JOIN pri p
          ON p.ScopeKey = c.ScopeKey AND p.ElementName = c.ElementName
    )
    SELECT
        j.ScopeKey,
        e.ItemCode,
        fc.Label,
        j.ElementName,
        Kind      = CASE WHEN e.DataType = 'Count' THEN 'COUNT' ELSE 'AMOUNT' END,
        PriorVal  = ISNULL(j.PriorVal, 0),
        CurrentVal= ISNULL(j.CurrentVal, 0),
        PctChange = CASE WHEN ISNULL(j.PriorVal,0) = 0 THEN NULL
                         ELSE CAST((ISNULL(j.CurrentVal,0) - j.PriorVal) * 100.0
                              / ABS(j.PriorVal) AS DECIMAL(15,2)) END,
        Flag = CASE
            WHEN ISNULL(j.PriorVal,0) = 0 AND ISNULL(j.CurrentVal,0) <> 0 THEN 'NEW'
            WHEN ISNULL(j.PriorVal,0) <> 0 AND ISNULL(j.CurrentVal,0) = 0 THEN 'DROPPED'
            WHEN ISNULL(j.PriorVal,0) = 0 THEN ''   -- both zero; avoid divide-by-zero
            WHEN e.DataType = 'Count'
                 AND ABS(ISNULL(j.CurrentVal,0) - j.PriorVal) * 100.0 / ABS(j.PriorVal) > @CntThresholdPct
                THEN 'COUNT SWING'
            WHEN e.DataType <> 'Count'
                 AND ABS(ISNULL(j.CurrentVal,0) - j.PriorVal) * 100.0 / ABS(j.PriorVal) > @AmtThresholdPct
                THEN '$ SWING'
            ELSE '' END
    FROM j
    JOIN mcr.FieldCatalogElement e ON e.ElementName = j.ElementName
    JOIN mcr.FieldCatalog fc       ON fc.ItemCode   = e.ItemCode
    ORDER BY CASE WHEN j.ScopeKey='FC' THEN 2 WHEN j.ScopeKey='COMPANY' THEN 1 ELSE 0 END,
             j.ScopeKey, e.ElemOrder;

    PRINT 'Variance filing ' + CAST(@FilingId AS VARCHAR(10))
        + ' vs prior ' + CAST(@PriorId AS VARCHAR(10))
        + ' (thresholds: $ ' + CAST(@AmtThresholdPct AS VARCHAR(10))
        + '%, count ' + CAST(@CntThresholdPct AS VARCHAR(10)) + '%).';
END;
GO
PRINT '06 complete: mcr.usp_QaVariance created.';
GO
