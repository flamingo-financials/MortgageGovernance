/* ============================================================
   MortgageGovernance | Script 036-PRE2
   Dimension member and linkage read. Read-only.
   ============================================================ */
SET NOCOUNT ON;

/* 1. How property (and therefore state) reaches a loan */
SELECT c.name AS ColumnName,
       TYPE_NAME(c.user_type_id) AS DataTypeName,
       c.max_length AS MaxLength, c.is_nullable AS IsNullable
FROM sys.columns c
WHERE c.object_id = OBJECT_ID('dw.DimProperty')
ORDER BY c.column_id;

/* 2. Investor members */
SELECT InvestorKey, InvestorCode, InvestorName,
       InvestorTypeCode
FROM dw.DimInvestor
ORDER BY InvestorKey;

/* 3. Servicing type members */
SELECT * FROM dw.DimServicingType
ORDER BY 1;

/* 4. Delinquency bucket members */
SELECT DelinquencyStatusKey, DelinquencyBucketCode,
       DelinquencyBucketName, MinDpd, MaxDpd,
       DelinquentFlag, SeriousDelinquencyFlag, McrLineNote
FROM dw.DimDelinquencyStatus
ORDER BY SortOrder;

/* 5. Loan status members (active population gate) */
SELECT * FROM dw.DimLoanStatus
ORDER BY 1;

/* 6. Q2 2026 grain and whether a Q2 filing already exists */
SELECT AsOfDate,
       COUNT(*) AS SnapshotRows,
       SUM(CAST(ActiveServicingFlag AS INT)) AS ActiveRows,
       SUM(CASE WHEN ActiveServicingFlag = 1
                THEN CurrentUpbAmount END) AS ActiveUpb
FROM dw.FactLoanMonthEndSnapshot
WHERE AsOfDate IN ('2026-05-31','2026-06-30','2026-07-31')
GROUP BY AsOfDate
ORDER BY AsOfDate;

SELECT FilingId, CompanyName, [Year], PeriodType,
       PeriodStart, PeriodEnd
FROM reg.vw_McrFiling
WHERE PeriodEnd >= '2026-04-01'
ORDER BY FilingId;