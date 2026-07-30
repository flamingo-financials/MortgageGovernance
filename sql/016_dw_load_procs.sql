/* ============================================================
   MortgageGovernance | Phase 4 | Script 016
   Warehouse load procedures. Lineage registration helper,
   DimDate loader, type 1 dimension loader, SCD2 loan officer
   loader, 15 fact loaders implementing gov.DerivationRule
   canonical logic, and master dw.usp_RunFullLoad.
   Dimensions upsert in place (facts hold FKs to them); facts
   truncate and reload. Every loader wraps
   audit.usp_StartLoadExecution / usp_CompleteLoadExecution
   and self-registers its lineage edges.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   gov.usp_RegisterLineageEdge
   Get-or-create both lineage nodes, then get-or-create the
   edge. Idempotent; safe to call on every load run.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE gov.usp_RegisterLineageEdge
    @FromNodeTypeCode    VARCHAR(30),
    @FromNodeName        NVARCHAR(300),
    @ToNodeTypeCode      VARCHAR(30),
    @ToNodeName          NVARCHAR(300),
    @EdgeTypeCode        VARCHAR(30),
    @MappingTypeCode     VARCHAR(20)   = NULL,
    @TransformationLogic NVARCHAR(2000) = NULL,
    @CreatedByObject     NVARCHAR(200) = NULL,
    @LoadBatchId         INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FromNodeId INT, @ToNodeId INT;

    SELECT @FromNodeId = LineageNodeId
    FROM gov.LineageNode
    WHERE NodeTypeCode = @FromNodeTypeCode
      AND NodeName = @FromNodeName;

    IF @FromNodeId IS NULL
    BEGIN
        INSERT INTO gov.LineageNode
            (NodeTypeCode, NodeName, LoadBatchId)
        VALUES
            (@FromNodeTypeCode, @FromNodeName, @LoadBatchId);
        SET @FromNodeId = SCOPE_IDENTITY();
    END

    SELECT @ToNodeId = LineageNodeId
    FROM gov.LineageNode
    WHERE NodeTypeCode = @ToNodeTypeCode
      AND NodeName = @ToNodeName;

    IF @ToNodeId IS NULL
    BEGIN
        INSERT INTO gov.LineageNode
            (NodeTypeCode, NodeName, LoadBatchId)
        VALUES
            (@ToNodeTypeCode, @ToNodeName, @LoadBatchId);
        SET @ToNodeId = SCOPE_IDENTITY();
    END

    IF NOT EXISTS
       (SELECT 1 FROM gov.LineageEdge
        WHERE FromLineageNodeId = @FromNodeId
          AND ToLineageNodeId = @ToNodeId
          AND EdgeTypeCode = @EdgeTypeCode)
    BEGIN
        INSERT INTO gov.LineageEdge
            (FromLineageNodeId, ToLineageNodeId, EdgeTypeCode,
             TransformationLogic, MappingTypeCode,
             CreatedByObject, LoadBatchId)
        VALUES
            (@FromNodeId, @ToNodeId, @EdgeTypeCode,
             @TransformationLogic, @MappingTypeCode,
             @CreatedByObject, @LoadBatchId);
    END
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadDimDate
   Populates 2015-01-01 through 2027-12-31. HolidayFlag from
   ref.Holiday; BusinessDayFlag = not weekend and not holiday
   (DRV_NEXTBIZDAY resolves against this column, never from
   weekday math).
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadDimDate
    @LoadBatchId INT,
    @StartDate   DATE = '2015-01-01',
    @EndDate     DATE = '2030-12-31'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT, @RowsUpdated INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load DimDate',
        @TargetObject = N'dw.DimDate',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        ;WITH n AS
        (
            SELECT TOP (DATEDIFF(DAY, @StartDate, @EndDate) + 1)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
                       - 1 AS Offs
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        ),
        d AS
        (
            SELECT DATEADD(DAY, n.Offs, @StartDate) AS FullDate
            FROM n
        )
        INSERT INTO dw.DimDate
            (DateKey, FullDate, CalendarYear, CalendarQuarter,
             QuarterName, CalendarMonth, MonthName, YearMonth,
             CalendarDay, DayOfWeekNo, DayName, MonthStartDate,
             MonthEndDate, MonthEndFlag, WeekendFlag,
             HolidayFlag, HolidayName, BusinessDayFlag,
             LoadBatchId)
        SELECT
            CONVERT(INT, CONVERT(CHAR(8), d.FullDate, 112)),
            d.FullDate,
            YEAR(d.FullDate),
            DATEPART(QUARTER, d.FullDate),
            'Q' + CAST(DATEPART(QUARTER, d.FullDate)
                AS CHAR(1)),
            MONTH(d.FullDate),
            DATENAME(MONTH, d.FullDate),
            YEAR(d.FullDate) * 100 + MONTH(d.FullDate),
            DAY(d.FullDate),
            DATEPART(WEEKDAY, d.FullDate),
            DATENAME(WEEKDAY, d.FullDate),
            DATEFROMPARTS(YEAR(d.FullDate),
                MONTH(d.FullDate), 1),
            EOMONTH(d.FullDate),
            CASE WHEN d.FullDate = EOMONTH(d.FullDate)
                 THEN 1 ELSE 0 END,
            CASE WHEN DATENAME(WEEKDAY, d.FullDate)
                      IN ('Saturday','Sunday')
                 THEN 1 ELSE 0 END,
            CASE WHEN h.HolidayDate IS NOT NULL
                 THEN 1 ELSE 0 END,
            h.HolidayName,
            CASE WHEN DATENAME(WEEKDAY, d.FullDate)
                      IN ('Saturday','Sunday')
                   OR h.HolidayDate IS NOT NULL
                 THEN 0 ELSE 1 END,
            @LoadBatchId
        FROM d
        LEFT JOIN ref.Holiday h
          ON h.HolidayDate = d.FullDate
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimDate x
               WHERE x.FullDate = d.FullDate);

        SET @RowsInserted = @@ROWCOUNT;

        /* refresh holiday and business day flags on rerun */
        UPDATE x
        SET x.HolidayFlag =
                CASE WHEN h.HolidayDate IS NOT NULL
                     THEN 1 ELSE 0 END,
            x.HolidayName = h.HolidayName,
            x.BusinessDayFlag =
                CASE WHEN x.WeekendFlag = 1
                       OR h.HolidayDate IS NOT NULL
                     THEN 0 ELSE 1 END,
            x.ModifiedDateUtc = SYSUTCDATETIME()
        FROM dw.DimDate x
        LEFT JOIN ref.Holiday h
          ON h.HolidayDate = x.FullDate
        WHERE x.HolidayFlag <>
                CASE WHEN h.HolidayDate IS NOT NULL
                     THEN 1 ELSE 0 END
           OR ISNULL(x.HolidayName, N'~') <>
              ISNULL(h.HolidayName, N'~');

        SET @RowsUpdated = @@ROWCOUNT;
        SET @RowsRead =
            DATEDIFF(DAY, @StartDate, @EndDate) + 1;

        SET @Xform = N'HolidayFlag and BusinessDayFlag per '
            + N'DRV_NEXTBIZDAY';
        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'SOURCE_OBJECT',
            @FromNodeName = N'ref.Holiday',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.DimDate',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DIRECT',
            @TransformationLogic = @Xform,
            @CreatedByObject = N'dw.usp_LoadDimDate',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted,
            @RowsUpdated = @RowsUpdated;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo = N'dw.usp_LoadDimDate';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadDimensions
   Type 1 dimensions. Upsert in place: facts hold foreign keys
   to these tables, so rows are never deleted. UNKNOWN members
   absorb unmapped codes so defects stay countable (DEF06
   orphan loans, DEF12 invalid investor, DEF14 unmapped LO
   handled in the SCD2 loader, DEF20 null lead source).
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadDimensions
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsInserted INT = 0, @RowsUpdated INT = 0,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load type 1 dimensions',
        @TargetObject = N'dw type 1 dimensions',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        /* ---- DimInvestor: UNKNOWN + ref.Investor ---- */
        IF NOT EXISTS (SELECT 1 FROM dw.DimInvestor
                       WHERE InvestorCode = 'UNKNOWN')
        INSERT INTO dw.DimInvestor
            (InvestorCode, InvestorName, InvestorTypeCode,
             LoadBatchId)
        VALUES ('UNKNOWN', N'Unknown Investor', 'UNKNOWN',
                @LoadBatchId);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        INSERT INTO dw.DimInvestor
            (InvestorCode, InvestorName, InvestorTypeCode,
             LoadBatchId)
        SELECT r.InvestorCode, r.InvestorName,
               r.InvestorTypeCode, @LoadBatchId
        FROM ref.Investor r
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimInvestor d
               WHERE d.InvestorCode = r.InvestorCode);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        UPDATE d
        SET d.InvestorName = r.InvestorName,
            d.InvestorTypeCode = r.InvestorTypeCode,
            d.ModifiedDateUtc = SYSUTCDATETIME()
        FROM dw.DimInvestor d
        JOIN ref.Investor r
          ON r.InvestorCode = d.InvestorCode
        WHERE d.InvestorName <> r.InvestorName
           OR d.InvestorTypeCode <> r.InvestorTypeCode;
        SET @RowsUpdated = @RowsUpdated + @@ROWCOUNT;

        /* ---- DimServicingType ---- */
        INSERT INTO dw.DimServicingType
            (ServicingTypeCode, ServicingTypeName,
             McrLineNote, LoadBatchId)
        SELECT r.ServicingTypeCode, r.ServicingTypeName,
               r.McrLineNote, @LoadBatchId
        FROM ref.ServicingType r
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimServicingType d
               WHERE d.ServicingTypeCode = r.ServicingTypeCode);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        UPDATE d
        SET d.ServicingTypeName = r.ServicingTypeName,
            d.McrLineNote = r.McrLineNote,
            d.ModifiedDateUtc = SYSUTCDATETIME()
        FROM dw.DimServicingType d
        JOIN ref.ServicingType r
          ON r.ServicingTypeCode = d.ServicingTypeCode
        WHERE d.ServicingTypeName <> r.ServicingTypeName
           OR ISNULL(d.McrLineNote, N'~') <>
              ISNULL(r.McrLineNote, N'~');
        SET @RowsUpdated = @RowsUpdated + @@ROWCOUNT;

        /* ---- DimRemittanceType ---- */
        INSERT INTO dw.DimRemittanceType
            (RemittanceTypeCode, RemittanceTypeName,
             LoadBatchId)
        SELECT r.RemittanceTypeCode, r.RemittanceTypeName,
               @LoadBatchId
        FROM ref.RemittanceType r
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimRemittanceType d
               WHERE d.RemittanceTypeCode =
                     r.RemittanceTypeCode);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        /* ---- DimLoanStatus ---- */
        INSERT INTO dw.DimLoanStatus
            (LoanStatusCode, LoanStatusName,
             ActiveServicingFlag, LoadBatchId)
        SELECT r.LoanStatusCode, r.LoanStatusName,
               r.ActiveServicingFlag, @LoadBatchId
        FROM ref.LoanStatus r
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimLoanStatus d
               WHERE d.LoanStatusCode = r.LoanStatusCode);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        /* ---- DimDelinquencyStatus: buckets live in ref,
               never in CASE expressions (DRV_DQBUCKET) ---- */
        INSERT INTO dw.DimDelinquencyStatus
            (DelinquencyBucketCode, DelinquencyBucketName,
             MinDpd, MaxDpd, SortOrder, DelinquentFlag,
             SeriousDelinquencyFlag, McrLineNote, LoadBatchId)
        SELECT r.DelinquencyBucketCode,
               r.DelinquencyBucketName,
               r.MinDpd, r.MaxDpd, r.SortOrder,
               CASE WHEN r.DelinquencyBucketCode = 'CURRENT'
                    THEN 0 ELSE 1 END,
               CASE WHEN r.DelinquencyBucketCode =
                         'DPD90_PLUS'
                    THEN 1 ELSE 0 END,
               r.McrLineNote, @LoadBatchId
        FROM ref.DelinquencyBucket r
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimDelinquencyStatus d
               WHERE d.DelinquencyBucketCode =
                     r.DelinquencyBucketCode);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        /* ---- DimWorkoutType ---- */
        INSERT INTO dw.DimWorkoutType
            (WorkoutTypeCode, WorkoutTypeName, RetentionFlag,
             LoadBatchId)
        SELECT r.WorkoutTypeCode, r.WorkoutTypeName,
               r.RetentionFlag, @LoadBatchId
        FROM ref.WorkoutType r
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimWorkoutType d
               WHERE d.WorkoutTypeCode = r.WorkoutTypeCode);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        /* ---- DimLeadSource: UNKNOWN + observed codes.
               Marketing versus referral classification is a
               governed dimension attribute (DRV_MKTSRC,
               DRV_REFSHARE). ---- */
        IF NOT EXISTS (SELECT 1 FROM dw.DimLeadSource
                       WHERE LeadSourceCode = 'UNKNOWN')
        INSERT INTO dw.DimLeadSource
            (LeadSourceCode, LeadSourceName,
             MarketingSourcedFlag, ReferralFlag, LoadBatchId)
        VALUES ('UNKNOWN', N'Unknown Lead Source', 0, 0,
                @LoadBatchId);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        INSERT INTO dw.DimLeadSource
            (LeadSourceCode, LeadSourceName,
             MarketingSourcedFlag, ReferralFlag, LoadBatchId)
        SELECT s.LeadSourceCode,
               CASE s.LeadSourceCode
                 WHEN 'PAID_MEDIA' THEN N'Paid Media'
                 WHEN 'ORGANIC_WEB' THEN N'Organic Web'
                 WHEN 'AGGREGATOR' THEN N'Lead Aggregator'
                 WHEN 'REF_AGENT' THEN N'Agent Referral'
                 WHEN 'REF_BUILDER' THEN N'Builder Referral'
                 WHEN 'REF_PASTCUST'
                      THEN N'Past Customer Referral'
                 WHEN 'SELF_SOURCED' THEN N'LO Self Sourced'
                 ELSE s.LeadSourceCode END,
               CASE WHEN s.LeadSourceCode IN
                    ('PAID_MEDIA','ORGANIC_WEB','AGGREGATOR')
                    THEN 1 ELSE 0 END,
               CASE WHEN s.LeadSourceCode LIKE 'REF_%'
                    THEN 1 ELSE 0 END,
               @LoadBatchId
        FROM (SELECT DISTINCT LeadSourceCode
              FROM stg.vw_CrmLead
              WHERE LeadSourceCode IS NOT NULL) s
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimLeadSource d
               WHERE d.LeadSourceCode = s.LeadSourceCode);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        /* ---- DimBranch: UNKNOWN + roster branches ---- */
        IF NOT EXISTS (SELECT 1 FROM dw.DimBranch
                       WHERE BranchCode = 'UNK')
        INSERT INTO dw.DimBranch
            (BranchCode, BranchName, Region, LoadBatchId)
        VALUES ('UNK', N'Unknown Branch', NULL, @LoadBatchId);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        INSERT INTO dw.DimBranch
            (BranchCode, BranchName, Region, LoadBatchId)
        SELECT s.BranchCode,
               N'Branch ' + s.BranchCode,
               s.Region, @LoadBatchId
        FROM (SELECT BranchCode, MAX(Region) AS Region
              FROM stg.vw_LicLoanOfficerRoster
              GROUP BY BranchCode) s
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimBranch d
               WHERE d.BranchCode = s.BranchCode);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        /* ---- DimLoan: UNKNOWN + loan master.
               ConformingFlag per DRV_CONFORMING with the
               origination year clamped to the seeded
               ref.ConformingLoanLimit range (2015-2026) and
               units clamped to 1-4; seasoned pre 2015 loans
               evaluate against the 2015 limit and the clamp
               is documented here rather than hidden.
               McrLoanTypeCode per DRV_MCRLOANTYPE.
               ProductClassCode per DRV_PRODCLASS. ---- */
        IF NOT EXISTS (SELECT 1 FROM dw.DimLoan
                       WHERE LoanNumber = 'UNKNOWN')
        INSERT INTO dw.DimLoan
            (LoanNumber, LoadBatchId)
        VALUES ('UNKNOWN', @LoadBatchId);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        ;WITH m AS
        (
            SELECT s.*,
                   CASE WHEN YEAR(s.OriginationDate) < 2015
                        THEN 2015
                        WHEN YEAR(s.OriginationDate) > 2026
                        THEN 2026
                        ELSE YEAR(s.OriginationDate)
                   END AS LimitYearClamped,
                   CASE WHEN ISNULL(s.UnitsCount, 1) < 1
                        THEN 1
                        WHEN ISNULL(s.UnitsCount, 1) > 4
                        THEN 4
                        ELSE ISNULL(s.UnitsCount, 1)
                   END AS UnitsClamped
            FROM stg.vw_SvcLoanMaster s
        ),
        e AS
        (
            SELECT m.*,
                   CASE WHEN m.OriginalLoanAmount IS NULL
                          OR m.OriginationDate IS NULL
                        THEN NULL
                        WHEN m.OriginalLoanAmount <=
                             c.LimitAmount
                        THEN 1 ELSE 0
                   END AS ConformingFlag
            FROM m
            LEFT JOIN ref.ConformingLoanLimit c
              ON c.LimitYear = m.LimitYearClamped
             AND c.UnitsCount = m.UnitsClamped
        )
        INSERT INTO dw.DimLoan
            (LoanNumber, OriginationDate, MaturityDate,
             OriginalLoanAmount, NoteRatePercent,
             InterestRateTypeCode, AmortizationTermMonths,
             LienPosition, HelocFlag, ReverseMortgageFlag,
             LoanProgramCode, LoanPurposeCode, EscrowedFlag,
             ConformingFlag, McrLoanTypeCode,
             ProductClassCode, InvestorLoanNumber,
             BoardedDate, LoadBatchId)
        SELECT e.LoanNumber, e.OriginationDate,
               e.MaturityDate, e.OriginalLoanAmount,
               e.NoteRatePercent, e.InterestRateTypeCode,
               e.AmortizationTermMonths, e.LienPosition,
               e.HelocFlag, e.ReverseMortgageFlag,
               e.LoanProgramCode, e.LoanPurposeCode,
               e.EscrowIndicator, e.ConformingFlag,
               CASE WHEN e.LoanProgramCode IN
                         ('FHA','VA','USDA') THEN 'GOVT'
                    WHEN e.LoanProgramCode = 'CONV'
                     AND e.ConformingFlag = 1
                         THEN 'CONV_CONF'
                    WHEN e.LoanProgramCode = 'CONV'
                     AND e.ConformingFlag = 0
                         THEN 'CONV_NONCONF'
                    ELSE 'OTHER' END,
               CASE WHEN e.ReverseMortgageFlag = 1
                         THEN 'REVERSE'
                    WHEN e.HelocFlag = 1 THEN 'HELOC'
                    WHEN e.LienPosition = 1 THEN 'FIRST'
                    WHEN e.LienPosition > 1
                         THEN 'CE_SECOND'
                    ELSE 'OTHER' END,
               e.InvestorLoanNumber, e.BoardedDate,
               @LoadBatchId
        FROM e
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimLoan d
               WHERE d.LoanNumber = e.LoanNumber);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        /* ---- DimBorrower (PII: names restricted) ---- */
        INSERT INTO dw.DimBorrower
            (LoanNumber, BorrowerFirstName, BorrowerLastName,
             BorrowerFullName, LoadBatchId)
        SELECT s.LoanNumber, s.BorrowerFirstName,
               s.BorrowerLastName,
               LTRIM(RTRIM(ISNULL(s.BorrowerFirstName, N'')
                   + N' '
                   + ISNULL(s.BorrowerLastName, N''))),
               @LoadBatchId
        FROM stg.vw_SvcLoanMaster s
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimBorrower d
               WHERE d.LoanNumber = s.LoanNumber);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        /* ---- DimProperty: loaded as received. DEF02
               invalid state ZZ is preserved so DQR02 can
               catch it; cleansing here would hide the
               defect from the control. ---- */
        INSERT INTO dw.DimProperty
            (LoanNumber, PropertyStreet, PropertyCity,
             PropertyStateCode, PropertyPostalCode,
             PropertyTypeCode, OccupancyTypeCode, UnitsCount,
             FloodZoneFlag, LoadBatchId)
        SELECT s.LoanNumber, s.PropertyStreet, s.PropertyCity,
               s.PropertyStateCode, s.PropertyPostalCode,
               s.PropertyTypeCode, s.OccupancyTypeCode,
               s.UnitsCount, s.FloodZoneFlag, @LoadBatchId
        FROM stg.vw_SvcLoanMaster s
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimProperty d
               WHERE d.LoanNumber = s.LoanNumber);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        SET @Xform = N'DRV_CONFORMING, DRV_MCRLOANTYPE, '
            + N'DRV_PRODCLASS';
        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_SvcLoanMaster',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.DimLoan',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = @Xform,
            @CreatedByObject = N'dw.usp_LoadDimensions',
            @LoadBatchId = @LoadBatchId;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_SvcLoanMaster',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.DimBorrower',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DIRECT',
            @TransformationLogic = NULL,
            @CreatedByObject = N'dw.usp_LoadDimensions',
            @LoadBatchId = @LoadBatchId;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_SvcLoanMaster',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.DimProperty',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DIRECT',
            @TransformationLogic =
                N'As received; DEF02 preserved for DQR02',
            @CreatedByObject = N'dw.usp_LoadDimensions',
            @LoadBatchId = @LoadBatchId;

        SET @Xform = N'Observed codes classified marketing '
            + N'versus referral';
        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_CrmLead',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.DimLeadSource',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = @Xform,
            @CreatedByObject = N'dw.usp_LoadDimensions',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsInserted = @RowsInserted,
            @RowsUpdated = @RowsUpdated;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo = N'dw.usp_LoadDimensions';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadDimLoanOfficer
   SCD2 from the roster feed. The source is already effective
   dated (RosterEffectiveDate / RosterEndDate, inclusive end,
   contiguous periods), so the loader upserts version rows on
   the natural key (NmlsId, EffectiveFromDate) and maintains
   CurrentRowFlag. Rows are never deleted (facts FK them).
   UNKNOWN member absorbs unmapped ids (DEF14 LO 999999).
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadDimLoanOfficer
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT = 0,
            @RowsUpdated INT = 0,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load DimLoanOfficer SCD2',
        @TargetObject = N'dw.DimLoanOfficer',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_LicLoanOfficerRoster;

        IF NOT EXISTS (SELECT 1 FROM dw.DimLoanOfficer
                       WHERE NmlsId = 'UNKNOWN')
        INSERT INTO dw.DimLoanOfficer
            (NmlsId, FirstName, LastName, FullName,
             BranchCode, EffectiveFromDate, EffectiveToDate,
             CurrentRowFlag, LoadBatchId)
        VALUES ('UNKNOWN', N'Unknown', N'Loan Officer',
                N'Unknown Loan Officer', 'UNK',
                '1900-01-01', NULL, 1, @LoadBatchId);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        /* update changed attributes on existing versions */
        UPDATE d
        SET d.FirstName = s.FirstName,
            d.LastName = s.LastName,
            d.FullName = s.FirstName + N' ' + s.LastName,
            d.BranchCode = s.BranchCode,
            d.Region = s.Region,
            d.ManagerNmlsId = s.ManagerNmlsId,
            d.ChannelCode = s.ChannelCode,
            d.EmploymentStatusCode = s.EmploymentStatusCode,
            d.HireDate = s.HireDate,
            d.TerminationDate = s.TerminationDate,
            d.EffectiveToDate = s.RosterEndDate,
            d.CurrentRowFlag =
                CASE WHEN s.RosterEndDate IS NULL
                     THEN 1 ELSE 0 END,
            d.ModifiedDateUtc = SYSUTCDATETIME()
        FROM dw.DimLoanOfficer d
        JOIN stg.vw_LicLoanOfficerRoster s
          ON s.NmlsId = d.NmlsId
         AND s.RosterEffectiveDate = d.EffectiveFromDate
        WHERE ISNULL(d.FirstName, N'~') <> s.FirstName
           OR ISNULL(d.LastName, N'~') <> s.LastName
           OR ISNULL(d.BranchCode, '~') <> s.BranchCode
           OR ISNULL(d.Region, N'~') <> s.Region
           OR ISNULL(d.EmploymentStatusCode, '~') <>
              s.EmploymentStatusCode
           OR ISNULL(d.EffectiveToDate, '9999-12-31') <>
              ISNULL(s.RosterEndDate, '9999-12-31');
        SET @RowsUpdated = @RowsUpdated + @@ROWCOUNT;

        /* insert missing version rows */
        INSERT INTO dw.DimLoanOfficer
            (NmlsId, FirstName, LastName, FullName,
             BranchCode, Region, ManagerNmlsId, ChannelCode,
             EmploymentStatusCode, HireDate, TerminationDate,
             EffectiveFromDate, EffectiveToDate,
             CurrentRowFlag, LoadBatchId)
        SELECT s.NmlsId, s.FirstName, s.LastName,
               s.FirstName + N' ' + s.LastName,
               s.BranchCode, s.Region, s.ManagerNmlsId,
               s.ChannelCode, s.EmploymentStatusCode,
               s.HireDate, s.TerminationDate,
               s.RosterEffectiveDate, s.RosterEndDate,
               CASE WHEN s.RosterEndDate IS NULL
                    THEN 1 ELSE 0 END,
               @LoadBatchId
        FROM stg.vw_LicLoanOfficerRoster s
        WHERE NOT EXISTS
              (SELECT 1 FROM dw.DimLoanOfficer d
               WHERE d.NmlsId = s.NmlsId
                 AND d.EffectiveFromDate =
                     s.RosterEffectiveDate);
        SET @RowsInserted = @RowsInserted + @@ROWCOUNT;

        SET @Xform = N'SCD2 version rows from effective dated '
            + N'roster feed';
        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_LicLoanOfficerRoster',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.DimLoanOfficer',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DIRECT',
            @TransformationLogic = @Xform,
            @CreatedByObject = N'dw.usp_LoadDimLoanOfficer',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted,
            @RowsUpdated = @RowsUpdated;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo = N'dw.usp_LoadDimLoanOfficer';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactLoanMonthEndSnapshot
   Implements DRV_DPD, DRV_DQBUCKET (ref.DelinquencyBucket
   lookup, never CASE breakpoints), DRV_ACTIVEPOP,
   DRV_ROLL3060, DRV_CURE, DRV_RUNOFF (prior month self join),
   DRV_MODSEASON, DRV_CLTV (latest valuation), DRV_LTVBAND.
   SourceReportedBucketCode preserves the source claimed
   bucket so the claimed versus derived control can expose
   DEF05. Invalid investor codes (DEF12) map to the UNKNOWN
   investor member; the LS300 reconciliation control flags
   them. Missing 2025-03-31 rows (DEF11) stay missing; the
   continuity control catches the gap.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactLoanMonthEndSnapshot
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactLoanMonthEndSnapshot',
        @TargetObject = N'dw.FactLoanMonthEndSnapshot',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_SvcLoanMonthEnd;

        TRUNCATE TABLE dw.FactLoanMonthEndSnapshot;

        /* stage: DPD and derived bucket per DRV_DPD and
           DRV_DQBUCKET */
        DROP TABLE IF EXISTS #Snap;
        SELECT
            m.LoanNumber,
            m.AsOfDate,
            CONVERT(INT, CONVERT(CHAR(8), m.AsOfDate, 112))
                AS SnapshotDateKey,
            m.CurrentUpbAmount,
            m.BeginningUpbAmount,
            m.ScheduledPrincipalAmount,
            m.VoluntaryPrepaidPrincipalAmount,
            m.InterestRatePercent,
            m.ServicingFeeRatePercent,
            m.NextPaymentDueDate,
            v.DaysPastDue,
            b.DelinquencyBucketCode,
            m.DelinquencyBucketCode
                AS SourceReportedBucketCode,
            m.EscrowBalanceAmount,
            m.SuspenseBalanceAmount,
            m.EscrowIndicator,
            m.ForbearanceFlag,
            m.LoanStatusCode,
            m.RunoffReasonCode,
            m.InvestorCode,
            m.ServicingTypeCode,
            m.RemittanceTypeCode
        INTO #Snap
        FROM stg.vw_SvcLoanMonthEnd m
        CROSS APPLY
        (
            SELECT CASE
                WHEN m.NextPaymentDueDate IS NULL THEN 0
                WHEN m.NextPaymentDueDate >= m.AsOfDate
                     THEN 0
                ELSE DATEDIFF(DAY, m.NextPaymentDueDate,
                              m.AsOfDate)
            END AS DaysPastDue
        ) v
        JOIN ref.DelinquencyBucket b
          ON v.DaysPastDue >= b.MinDpd
         AND (v.DaysPastDue <= b.MaxDpd
              OR b.MaxDpd IS NULL);

        CREATE CLUSTERED INDEX IXC_Snap
            ON #Snap (LoanNumber, AsOfDate);

        INSERT INTO dw.FactLoanMonthEndSnapshot
            (LoanKey, SnapshotDateKey, AsOfDate, LoanNumber,
             InvestorKey, ServicingTypeKey, RemittanceTypeKey,
             LoanStatusKey, DelinquencyStatusKey,
             CurrentUpbAmount, BeginningUpbAmount,
             ScheduledPrincipalAmount,
             VoluntaryPrepaidPrincipalAmount,
             InterestRatePercent, ServicingFeeRatePercent,
             NextPaymentDueDate, DaysPastDue,
             SourceReportedBucketCode, EscrowBalanceAmount,
             SuspenseBalanceAmount, EscrowedFlag,
             ForbearanceFlag, ActiveServicingFlag,
             Roll30to60Flag, CureFlag, RunoffFlag,
             RunoffReasonCode, ModSeasoningCode,
             CurrentLtvPct, LtvBandCode, LoadBatchId)
        SELECT
            dl.LoanKey,
            s.SnapshotDateKey,
            s.AsOfDate,
            s.LoanNumber,
            ISNULL(di.InvestorKey, du.InvestorKey),
            dst.ServicingTypeKey,
            drt.RemittanceTypeKey,
            dls.LoanStatusKey,
            dds.DelinquencyStatusKey,
            s.CurrentUpbAmount,
            s.BeginningUpbAmount,
            s.ScheduledPrincipalAmount,
            s.VoluntaryPrepaidPrincipalAmount,
            s.InterestRatePercent,
            s.ServicingFeeRatePercent,
            s.NextPaymentDueDate,
            s.DaysPastDue,
            s.SourceReportedBucketCode,
            s.EscrowBalanceAmount,
            s.SuspenseBalanceAmount,
            s.EscrowIndicator,
            s.ForbearanceFlag,
            dls.ActiveServicingFlag,
            /* DRV_ROLL3060 */
            CASE WHEN p.DelinquencyBucketCode = 'DPD30_59'
                  AND s.DelinquencyBucketCode IN
                      ('DPD60_89','DPD90_PLUS')
                 THEN 1 ELSE 0 END,
            /* DRV_CURE */
            CASE WHEN p.DelinquencyBucketCode IS NOT NULL
                  AND p.DelinquencyBucketCode <> 'CURRENT'
                  AND s.DelinquencyBucketCode = 'CURRENT'
                 THEN 1 ELSE 0 END,
            /* DRV_RUNOFF: terminal this month, active at the
               prior month end */
            CASE WHEN dls.ActiveServicingFlag = 0
                  AND p.LoanNumber IS NOT NULL
                  AND pls.ActiveServicingFlag = 1
                 THEN 1 ELSE 0 END,
            s.RunoffReasonCode,
            /* DRV_MODSEASON */
            CASE WHEN md.ModificationEffectiveDate IS NULL
                 THEN NULL
                 WHEN DATEDIFF(MONTH,
                      md.ModificationEffectiveDate,
                      s.AsOfDate) < 12
                 THEN 'MOD_LT_1YR'
                 ELSE 'MOD_GE_1YR' END,
            lv.CurrentLtvPct,
            lb.LtvBandCode,
            @LoadBatchId
        FROM #Snap s
        JOIN dw.DimLoan dl
          ON dl.LoanNumber = s.LoanNumber
        LEFT JOIN dw.DimInvestor di
          ON di.InvestorCode = s.InvestorCode
        CROSS JOIN
        (
            SELECT InvestorKey FROM dw.DimInvestor
            WHERE InvestorCode = 'UNKNOWN'
        ) du
        JOIN dw.DimServicingType dst
          ON dst.ServicingTypeCode = s.ServicingTypeCode
        JOIN dw.DimRemittanceType drt
          ON drt.RemittanceTypeCode = s.RemittanceTypeCode
        JOIN dw.DimLoanStatus dls
          ON dls.LoanStatusCode = s.LoanStatusCode
        JOIN dw.DimDelinquencyStatus dds
          ON dds.DelinquencyBucketCode =
             s.DelinquencyBucketCode
        LEFT JOIN #Snap p
          ON p.LoanNumber = s.LoanNumber
         AND p.AsOfDate =
             EOMONTH(DATEADD(MONTH, -1, s.AsOfDate))
        LEFT JOIN dw.DimLoanStatus pls
          ON pls.LoanStatusCode = p.LoanStatusCode
        OUTER APPLY
        (
            SELECT TOP (1) md.ModificationEffectiveDate
            FROM stg.vw_SvcLoanModification md
            WHERE md.LoanNumber = s.LoanNumber
              AND md.ModificationEffectiveDate <= s.AsOfDate
            ORDER BY md.ModificationEffectiveDate DESC
        ) md
        OUTER APPLY
        (
            SELECT TOP (1)
                CAST(s.CurrentUpbAmount
                  / NULLIF(pv.PropertyValueAmount, 0)
                  AS DECIMAL(9,4)) AS CurrentLtvPct
            FROM stg.vw_ValPropertyValuation pv
            WHERE pv.LoanNumber = s.LoanNumber
              AND pv.ValuationDate <= s.AsOfDate
            ORDER BY pv.ValuationDate DESC,
                     pv.PropertyValuationId DESC
        ) lv
        LEFT JOIN ref.LtvBand lb
          ON lv.CurrentLtvPct IS NOT NULL
         AND lv.CurrentLtvPct >= lb.MinLtvPct
         AND (lv.CurrentLtvPct < lb.MaxLtvPct
              OR lb.MaxLtvPct IS NULL);

        SET @RowsInserted = @@ROWCOUNT;
        DROP TABLE IF EXISTS #Snap;

        SET @Xform = N'DRV_DPD, DRV_DQBUCKET, DRV_ACTIVEPOP, '
            + N'DRV_ROLL3060, DRV_CURE, DRV_RUNOFF, '
            + N'DRV_MODSEASON';
        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_SvcLoanMonthEnd',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactLoanMonthEndSnapshot',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = @Xform,
            @CreatedByObject =
                N'dw.usp_LoadFactLoanMonthEndSnapshot',
            @LoadBatchId = @LoadBatchId;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_ValPropertyValuation',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactLoanMonthEndSnapshot',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic =
                N'DRV_CLTV latest valuation, DRV_LTVBAND',
            @CreatedByObject =
                N'dw.usp_LoadFactLoanMonthEndSnapshot',
            @LoadBatchId = @LoadBatchId;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_SvcLoanModification',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactLoanMonthEndSnapshot',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = N'DRV_MODSEASON',
            @CreatedByObject =
                N'dw.usp_LoadFactLoanMonthEndSnapshot',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo =
                N'dw.usp_LoadFactLoanMonthEndSnapshot';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactPaymentTransaction
   Implements DRV_PAYTIMELY (next business day via
   dw.ufn_NextBusinessDate; ref.SlaPolicy PAY_POSTING governs
   the standard), DRV_PAYACC (originals later reversed are
   inaccurate; reversal rows themselves are excluded from the
   accuracy population and carry NULL). Orphan payments
   (DEF06) map to the UNKNOWN loan member with
   UnmatchedLoanFlag = 1 so the exposure is countable.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactPaymentTransaction
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactPaymentTransaction',
        @TargetObject = N'dw.FactPaymentTransaction',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_PayPaymentTransaction;

        TRUNCATE TABLE dw.FactPaymentTransaction;

        INSERT INTO dw.FactPaymentTransaction
            (PaymentTransactionId, LoanKey, LoanNumber,
             ReceivedDateKey, ReceivedDate, PostedDate,
             EffectiveDate, PaymentAmount, PrincipalAmount,
             InterestAmount, EscrowAmount, FeeAmount,
             SuspenseFlag, ReversalFlag,
             OriginalTransactionId, ChannelCode, DaysToPost,
             PostedTimelyFlag, PostedAccuratelyFlag,
             UnmatchedLoanFlag, LoadBatchId)
        SELECT
            t.PaymentTransactionId,
            ISNULL(dl.LoanKey, ul.LoanKey),
            t.LoanNumber,
            CONVERT(INT,
                CONVERT(CHAR(8), t.ReceivedDate, 112)),
            t.ReceivedDate,
            t.PostedDate,
            t.EffectiveDate,
            t.PaymentAmount,
            t.PrincipalAmount,
            t.InterestAmount,
            t.EscrowAmount,
            t.FeeAmount,
            t.SuspenseFlag,
            t.ReversalFlag,
            t.OriginalTransactionId,
            t.ChannelCode,
            DATEDIFF(DAY, t.ReceivedDate, t.PostedDate),
            /* DRV_PAYTIMELY */
            CASE WHEN t.PostedDate IS NULL THEN NULL
                 WHEN t.PostedDate <= nb.NextBusinessDate
                 THEN 1 ELSE 0 END,
            /* DRV_PAYACC: originals only */
            CASE WHEN t.ReversalFlag = 1 THEN NULL
                 WHEN EXISTS
                      (SELECT 1
                       FROM stg.vw_PayPaymentTransaction r
                       WHERE r.ReversalFlag = 1
                         AND r.OriginalTransactionId =
                             t.PaymentTransactionId)
                 THEN 0 ELSE 1 END,
            CASE WHEN dl.LoanKey IS NULL THEN 1 ELSE 0 END,
            @LoadBatchId
        FROM stg.vw_PayPaymentTransaction t
        LEFT JOIN dw.DimLoan dl
          ON dl.LoanNumber = t.LoanNumber
        CROSS JOIN
        (
            SELECT LoanKey FROM dw.DimLoan
            WHERE LoanNumber = 'UNKNOWN'
        ) ul
        OUTER APPLY dw.ufn_NextBusinessDate(t.ReceivedDate)
            nb;

        SET @RowsInserted = @@ROWCOUNT;

        SET @Xform = N'DRV_PAYTIMELY, DRV_PAYACC, DEF06 orphans '
            + N'to UNKNOWN loan';
        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_PayPaymentTransaction',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactPaymentTransaction',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = @Xform,
            @CreatedByObject =
                N'dw.usp_LoadFactPaymentTransaction',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo =
                N'dw.usp_LoadFactPaymentTransaction';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactEscrowDisbursement
   DRV_TAXTIMELY and DRV_INSTIMELY combined into
   DisbursedTimelyFlag by disbursement type. DEF09 late tax
   disbursements surface as DisbursedTimelyFlag = 0.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactEscrowDisbursement
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactEscrowDisbursement',
        @TargetObject = N'dw.FactEscrowDisbursement',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_SvcEscrowDisbursement;

        TRUNCATE TABLE dw.FactEscrowDisbursement;

        INSERT INTO dw.FactEscrowDisbursement
            (EscrowDisbursementId, LoanKey, LoanNumber,
             DisbursementTypeCode, PayeeName,
             DisbursedAmount, DisbursedDateKey,
             DisbursedDate, TaxDueDate,
             PolicyExpirationDate, DisbursedTimelyFlag,
             AmountMatchFlag, PayeeMatchFlag, LoanMatchFlag,
             LoadBatchId)
        SELECT
            e.EscrowDisbursementId,
            dl.LoanKey,
            e.LoanNumber,
            e.DisbursementTypeCode,
            e.PayeeName,
            e.DisbursedAmount,
            CONVERT(INT,
                CONVERT(CHAR(8), e.DisbursedDate, 112)),
            e.DisbursedDate,
            e.TaxDueDate,
            e.PolicyExpirationDate,
            CASE
              WHEN e.DisbursedDate IS NULL THEN NULL
              WHEN e.DisbursementTypeCode = 'TAX'
                   AND e.TaxDueDate IS NULL THEN NULL
              WHEN e.DisbursementTypeCode = 'TAX'
                THEN CASE WHEN e.DisbursedDate <=
                          e.TaxDueDate
                     THEN 1 ELSE 0 END
              WHEN e.DisbursementTypeCode = 'INS'
                   AND e.PolicyExpirationDate IS NULL
                THEN NULL
              WHEN e.DisbursementTypeCode = 'INS'
                THEN CASE WHEN e.DisbursedDate <=
                          e.PolicyExpirationDate
                     THEN 1 ELSE 0 END
            END,
            e.AmountMatchFlag,
            e.PayeeMatchFlag,
            e.LoanMatchFlag,
            @LoadBatchId
        FROM stg.vw_SvcEscrowDisbursement e
        JOIN dw.DimLoan dl
          ON dl.LoanNumber = e.LoanNumber;

        SET @RowsInserted = @@ROWCOUNT;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_SvcEscrowDisbursement',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactEscrowDisbursement',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic =
                N'DRV_TAXTIMELY, DRV_INSTIMELY, DRV_DISBACC',
            @CreatedByObject =
                N'dw.usp_LoadFactEscrowDisbursement',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo =
                N'dw.usp_LoadFactEscrowDisbursement';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactEscrowAnalysis
   DRV_ESCTIMELY: completed by the governed due date.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactEscrowAnalysis
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactEscrowAnalysis',
        @TargetObject = N'dw.FactEscrowAnalysis',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_SvcEscrowAnalysis;

        TRUNCATE TABLE dw.FactEscrowAnalysis;

        INSERT INTO dw.FactEscrowAnalysis
            (EscrowAnalysisId, LoanKey, LoanNumber,
             AnalysisDueDateKey, AnalysisDueDate,
             AnalysisCompletedDate, CompletedOnTimeFlag,
             ShortageAmount, ShortageFlag, LoadBatchId)
        SELECT
            a.EscrowAnalysisId,
            dl.LoanKey,
            a.LoanNumber,
            CONVERT(INT,
                CONVERT(CHAR(8), a.AnalysisDueDate, 112)),
            a.AnalysisDueDate,
            a.AnalysisCompletedDate,
            CASE WHEN a.AnalysisCompletedDate IS NULL
                 THEN NULL
                 WHEN a.AnalysisCompletedDate <=
                      a.AnalysisDueDate
                 THEN 1 ELSE 0 END,
            a.ShortageAmount,
            CASE WHEN a.ShortageAmount IS NULL THEN NULL
                 WHEN a.ShortageAmount > 0 THEN 1
                 ELSE 0 END,
            @LoadBatchId
        FROM stg.vw_SvcEscrowAnalysis a
        JOIN dw.DimLoan dl
          ON dl.LoanNumber = a.LoanNumber;

        SET @RowsInserted = @@ROWCOUNT;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_SvcEscrowAnalysis',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactEscrowAnalysis',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = N'DRV_ESCTIMELY',
            @CreatedByObject =
                N'dw.usp_LoadFactEscrowAnalysis',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo = N'dw.usp_LoadFactEscrowAnalysis';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactLossMitigationCase
   DRV_LMTURN, DRV_LMAPPROVE. TrialConvertedFlag arrives
   pre-resolved from the source (DRV_TRIALCONV applied at
   case closure in DefaultTrack).
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactLossMitigationCase
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactLossMitigationCase',
        @TargetObject = N'dw.FactLossMitigationCase',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_DmsLossMitigationCase;

        TRUNCATE TABLE dw.FactLossMitigationCase;

        INSERT INTO dw.FactLossMitigationCase
            (LossMitCaseId, LoanKey, LoanNumber,
             WorkoutTypeKey, AppReceivedDateKey,
             AppReceivedDate, CompletePackageDate,
             DecisionDate, DecisionCode, WorkoutTypeCode,
             TrialStartDate, TrialCompletedDate,
             EvalTurnTimeDays, WorkoutApprovedFlag,
             TrialConvertedFlag, LoadBatchId)
        SELECT
            c.LossMitCaseId,
            dl.LoanKey,
            c.LoanNumber,
            wt.WorkoutTypeKey,
            CONVERT(INT,
                CONVERT(CHAR(8), c.AppReceivedDate, 112)),
            c.AppReceivedDate,
            c.CompletePackageDate,
            c.DecisionDate,
            c.DecisionCode,
            c.WorkoutTypeCode,
            c.TrialStartDate,
            c.TrialCompletedDate,
            CASE WHEN c.CompletePackageDate IS NOT NULL
                  AND c.DecisionDate IS NOT NULL
                 THEN DATEDIFF(DAY, c.CompletePackageDate,
                               c.DecisionDate) END,
            CASE WHEN c.DecisionCode IN
                      ('MOD','REPAY','DEFER','FORB',
                       'SHORTSALE','DIL') THEN 1
                 WHEN c.DecisionCode = 'DENY' THEN 0
            END,
            c.TrialConvertedFlag,
            @LoadBatchId
        FROM stg.vw_DmsLossMitigationCase c
        JOIN dw.DimLoan dl
          ON dl.LoanNumber = c.LoanNumber
        LEFT JOIN dw.DimWorkoutType wt
          ON wt.WorkoutTypeCode = c.WorkoutTypeCode;

        SET @RowsInserted = @@ROWCOUNT;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_DmsLossMitigationCase',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactLossMitigationCase',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic =
                N'DRV_LMTURN, DRV_LMAPPROVE',
            @CreatedByObject =
                N'dw.usp_LoadFactLossMitigationCase',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo =
                N'dw.usp_LoadFactLossMitigationCase';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactForeclosureCase
   DRV_FCREFTIMELY with SLA days read from ref.SlaPolicy
   FC_REFERRAL, never hardcoded.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactForeclosureCase
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @SlaDays INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactForeclosureCase',
        @TargetObject = N'dw.FactForeclosureCase',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_DmsForeclosureCase;

        SELECT @SlaDays = SlaDays
        FROM ref.SlaPolicy
        WHERE SlaPolicyCode = 'FC_REFERRAL';

        TRUNCATE TABLE dw.FactForeclosureCase;

        INSERT INTO dw.FactForeclosureCase
            (ForeclosureCaseId, LoanKey, LoanNumber,
             FirstLegalEligibleDateKey,
             FirstLegalEligibleDate, ReferralDate,
             FirstLegalDate, SaleScheduledDate, SaleHeldDate,
             CaseStatusCode, ResolutionTypeCode,
             ReferralDays, FcReferralTimelyFlag, LoadBatchId)
        SELECT
            f.ForeclosureCaseId,
            dl.LoanKey,
            f.LoanNumber,
            CONVERT(INT, CONVERT(CHAR(8),
                f.FirstLegalEligibleDate, 112)),
            f.FirstLegalEligibleDate,
            f.ReferralDate,
            f.FirstLegalDate,
            f.SaleScheduledDate,
            f.SaleHeldDate,
            f.CaseStatusCode,
            f.ResolutionTypeCode,
            DATEDIFF(DAY, f.FirstLegalEligibleDate,
                     f.ReferralDate),
            CASE WHEN f.ReferralDate IS NULL THEN NULL
                 WHEN f.ReferralDate <=
                      DATEADD(DAY, @SlaDays,
                              f.FirstLegalEligibleDate)
                 THEN 1 ELSE 0 END,
            @LoadBatchId
        FROM stg.vw_DmsForeclosureCase f
        JOIN dw.DimLoan dl
          ON dl.LoanNumber = f.LoanNumber;

        SET @RowsInserted = @@ROWCOUNT;

        SET @Xform = N'DRV_FCREFTIMELY via ref.SlaPolicy '
            + N'FC_REFERRAL';
        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_DmsForeclosureCase',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactForeclosureCase',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = @Xform,
            @CreatedByObject =
                N'dw.usp_LoadFactForeclosureCase',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo = N'dw.usp_LoadFactForeclosureCase';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactBankruptcyCase
   DRV_POCTIMELY: bar date present and no filing counts as
   missed (0); no bar date recorded stays NULL.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactBankruptcyCase
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactBankruptcyCase',
        @TargetObject = N'dw.FactBankruptcyCase',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_DmsBankruptcyCase;

        TRUNCATE TABLE dw.FactBankruptcyCase;

        INSERT INTO dw.FactBankruptcyCase
            (BankruptcyCaseId, LoanKey, LoanNumber,
             ChapterCode, PetitionDateKey, PetitionDate,
             PocBarDate, PocFiledDate, CaseStatusCode,
             DispositionCode, PocTimelyFlag, LoadBatchId)
        SELECT
            b.BankruptcyCaseId,
            dl.LoanKey,
            b.LoanNumber,
            b.ChapterCode,
            CONVERT(INT,
                CONVERT(CHAR(8), b.PetitionDate, 112)),
            b.PetitionDate,
            b.PocBarDate,
            b.PocFiledDate,
            b.CaseStatusCode,
            b.DispositionCode,
            CASE WHEN b.PocBarDate IS NULL THEN NULL
                 WHEN b.PocFiledDate IS NULL THEN 0
                 WHEN b.PocFiledDate <= b.PocBarDate
                 THEN 1 ELSE 0 END,
            @LoadBatchId
        FROM stg.vw_DmsBankruptcyCase b
        JOIN dw.DimLoan dl
          ON dl.LoanNumber = b.LoanNumber;

        SET @RowsInserted = @@ROWCOUNT;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_DmsBankruptcyCase',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactBankruptcyCase',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = N'DRV_POCTIMELY',
            @CreatedByObject =
                N'dw.usp_LoadFactBankruptcyCase',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo = N'dw.usp_LoadFactBankruptcyCase';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactBoardingEvent
   Grain collapses duplicate tape rows (DEF04) to one row per
   loan per batch with TapeRowCount preserving the duplicate
   evidence. DRV_BOARDONTIME via ref.SlaPolicy BOARDING.
   DRV_BOARDACC: five tape versus core critical field
   comparisons (DEF10), NULL safe with sentinels so a NULL on
   either side never hides a mismatch.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactBoardingEvent
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @SlaDays INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactBoardingEvent',
        @TargetObject = N'dw.FactBoardingEvent',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_BrdBoardingTape;

        SELECT @SlaDays = SlaDays
        FROM ref.SlaPolicy
        WHERE SlaPolicyCode = 'BOARDING';

        TRUNCATE TABLE dw.FactBoardingEvent;

        /* collapse duplicate tape rows per loan per batch */
        DROP TABLE IF EXISTS #Tape;
        SELECT
            t.LoanNumber,
            t.BoardingBatchId,
            COUNT(*) AS TapeRowCount,
            MAX(t.TapeUpbAmount) AS TapeUpbAmount,
            MAX(t.TapeInterestRatePercent)
                AS TapeInterestRatePercent,
            MAX(t.TapeNextPaymentDueDate)
                AS TapeNextPaymentDueDate,
            MAX(t.TapeEscrowBalanceAmount)
                AS TapeEscrowBalanceAmount,
            MAX(t.TapeInvestorCode) AS TapeInvestorCode,
            MAX(t.BoardingCompletedDate)
                AS BoardingCompletedDate
        INTO #Tape
        FROM stg.vw_BrdBoardingTape t
        GROUP BY t.LoanNumber, t.BoardingBatchId;

        INSERT INTO dw.FactBoardingEvent
            (LoanKey, LoanNumber, BoardingBatchId,
             TransferTypeCode, TransferEffectiveDateKey,
             TransferEffectiveDate, ScheduledBoardDate,
             BoardingCompletedDate, BoardingDays,
             BoardedOnTimeFlag, TapeRowCount,
             UpbMismatchFlag, RateMismatchFlag,
             NextDueDateMismatchFlag,
             EscrowBalanceMismatchFlag, InvestorMismatchFlag,
             MismatchCount, BoardingAccuracyScore,
             LoadBatchId)
        SELECT
            dl.LoanKey,
            tp.LoanNumber,
            tp.BoardingBatchId,
            bb.TransferTypeCode,
            CONVERT(INT, CONVERT(CHAR(8),
                bb.TransferEffectiveDate, 112)),
            bb.TransferEffectiveDate,
            bb.ScheduledBoardDate,
            tp.BoardingCompletedDate,
            DATEDIFF(DAY, bb.TransferEffectiveDate,
                     tp.BoardingCompletedDate),
            CASE WHEN tp.BoardingCompletedDate IS NULL
                 THEN NULL
                 WHEN tp.BoardingCompletedDate <=
                      DATEADD(DAY, @SlaDays,
                              bb.TransferEffectiveDate)
                 THEN 1 ELSE 0 END,
            tp.TapeRowCount,
            mm.UpbMismatchFlag,
            mm.RateMismatchFlag,
            mm.NextDueDateMismatchFlag,
            mm.EscrowBalanceMismatchFlag,
            mm.InvestorMismatchFlag,
            mm.UpbMismatchFlag + mm.RateMismatchFlag
              + mm.NextDueDateMismatchFlag
              + mm.EscrowBalanceMismatchFlag
              + mm.InvestorMismatchFlag,
            CAST((5.0
              - (mm.UpbMismatchFlag + mm.RateMismatchFlag
                 + mm.NextDueDateMismatchFlag
                 + mm.EscrowBalanceMismatchFlag
                 + mm.InvestorMismatchFlag)) / 5.0
              AS DECIMAL(9,4)),
            @LoadBatchId
        FROM #Tape tp
        JOIN stg.vw_BrdBoardingBatch bb
          ON bb.BoardingBatchId = tp.BoardingBatchId
        JOIN dw.DimLoan dl
          ON dl.LoanNumber = tp.LoanNumber
        JOIN stg.vw_SvcLoanMaster lm
          ON lm.LoanNumber = tp.LoanNumber
        CROSS APPLY
        (
            SELECT
              CASE WHEN ISNULL(tp.TapeUpbAmount, -1) <>
                        ISNULL(lm.BoardUpbAmount, -1)
                   THEN 1 ELSE 0 END AS UpbMismatchFlag,
              CASE WHEN ISNULL(tp.TapeInterestRatePercent,
                        -1) <>
                        ISNULL(lm.BoardInterestRatePercent,
                        -1)
                   THEN 1 ELSE 0 END AS RateMismatchFlag,
              CASE WHEN ISNULL(tp.TapeNextPaymentDueDate,
                        '1900-01-01') <>
                        ISNULL(lm.BoardNextPaymentDueDate,
                        '1900-01-01')
                   THEN 1 ELSE 0
              END AS NextDueDateMismatchFlag,
              CASE WHEN ISNULL(tp.TapeEscrowBalanceAmount,
                        -999999) <>
                        ISNULL(lm.BoardEscrowBalanceAmount,
                        -999999)
                   THEN 1 ELSE 0
              END AS EscrowBalanceMismatchFlag,
              CASE WHEN ISNULL(tp.TapeInvestorCode, '~') <>
                        ISNULL(lm.InvestorCode, '~')
                   THEN 1 ELSE 0 END AS InvestorMismatchFlag
        ) mm;

        SET @RowsInserted = @@ROWCOUNT;
        DROP TABLE IF EXISTS #Tape;

        SET @Xform =
            N'DRV_BOARDONTIME, DRV_BOARDACC; DEF04 '
            + N'duplicates collapse to TapeRowCount';
        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_BrdBoardingTape',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactBoardingEvent',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = @Xform,
            @CreatedByObject =
                N'dw.usp_LoadFactBoardingEvent',
            @LoadBatchId = @LoadBatchId;

        SET @Xform = N'Core side of the DRV_BOARDACC five field '
            + N'comparison (DEF10)';
        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_SvcLoanMaster',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactBoardingEvent',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = @Xform,
            @CreatedByObject =
                N'dw.usp_LoadFactBoardingEvent',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo = N'dw.usp_LoadFactBoardingEvent';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactInvestorLoanReporting
   DRV_INVTIMELY. Accuracy inputs (AcceptedFlag, ErrorCount,
   CorrectionResubmissionFlag) load as received; DEF13
   correction spikes stay visible and intentionally have no
   DQ rule (business signal, not a data defect).
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactInvestorLoanReporting
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactInvestorLoanReporting',
        @TargetObject = N'dw.FactInvestorLoanReporting',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_InvLoanReport;

        TRUNCATE TABLE dw.FactInvestorLoanReporting;

        INSERT INTO dw.FactInvestorLoanReporting
            (InvLoanReportId, LoanKey, LoanNumber,
             InvestorKey, ReportingPeriod,
             ReportingDeadlineDateKey, ReportingDeadlineDate,
             ReportSubmittedDate, SubmittedOnTimeFlag,
             AcceptedFlag, ErrorCount,
             ReportedTransactionCount,
             CorrectionResubmissionFlag, LoadBatchId)
        SELECT
            r.InvLoanReportId,
            dl.LoanKey,
            r.LoanNumber,
            ISNULL(di.InvestorKey, du.InvestorKey),
            r.ReportingPeriod,
            CONVERT(INT, CONVERT(CHAR(8),
                r.ReportingDeadlineDate, 112)),
            r.ReportingDeadlineDate,
            r.ReportSubmittedDate,
            CASE WHEN r.ReportSubmittedDate IS NULL
                 THEN NULL
                 WHEN r.ReportSubmittedDate <=
                      r.ReportingDeadlineDate
                 THEN 1 ELSE 0 END,
            r.AcceptedFlag,
            r.ErrorCount,
            r.ReportedTransactionCount,
            r.CorrectionResubmissionFlag,
            @LoadBatchId
        FROM stg.vw_InvLoanReport r
        JOIN dw.DimLoan dl
          ON dl.LoanNumber = r.LoanNumber
        LEFT JOIN dw.DimInvestor di
          ON di.InvestorCode = r.InvestorCode
        CROSS JOIN
        (
            SELECT InvestorKey FROM dw.DimInvestor
            WHERE InvestorCode = 'UNKNOWN'
        ) du;

        SET @RowsInserted = @@ROWCOUNT;

        SET @Xform =
            N'DRV_INVTIMELY; DRV_INVACC inputs as '
            + N'received';
        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_InvLoanReport',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactInvestorLoanReporting',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = @Xform,
            @CreatedByObject =
                N'dw.usp_LoadFactInvestorLoanReporting',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo =
                N'dw.usp_LoadFactInvestorLoanReporting';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactInvestorRemittance
   DRV_REMITTIMELY.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactInvestorRemittance
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactInvestorRemittance',
        @TargetObject = N'dw.FactInvestorRemittance',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_InvRemittance;

        TRUNCATE TABLE dw.FactInvestorRemittance;

        INSERT INTO dw.FactInvestorRemittance
            (InvRemittanceId, InvestorKey, RemittancePeriod,
             RemittanceDueDateKey, RemittanceDueDate,
             RemittanceSentDate, RemittanceAmount,
             RemittedOnTimeFlag, LoadBatchId)
        SELECT
            r.InvRemittanceId,
            ISNULL(di.InvestorKey, du.InvestorKey),
            r.RemittancePeriod,
            CONVERT(INT, CONVERT(CHAR(8),
                r.RemittanceDueDate, 112)),
            r.RemittanceDueDate,
            r.RemittanceSentDate,
            r.RemittanceAmount,
            CASE WHEN r.RemittanceSentDate IS NULL
                 THEN NULL
                 WHEN r.RemittanceSentDate <=
                      r.RemittanceDueDate
                 THEN 1 ELSE 0 END,
            @LoadBatchId
        FROM stg.vw_InvRemittance r
        LEFT JOIN dw.DimInvestor di
          ON di.InvestorCode = r.InvestorCode
        CROSS JOIN
        (
            SELECT InvestorKey FROM dw.DimInvestor
            WHERE InvestorCode = 'UNKNOWN'
        ) du;

        SET @RowsInserted = @@ROWCOUNT;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_InvRemittance',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactInvestorRemittance',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = N'DRV_REMITTIMELY',
            @CreatedByObject =
                N'dw.usp_LoadFactInvestorRemittance',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo =
                N'dw.usp_LoadFactInvestorRemittance';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactRepurchaseDemand
   DRV_REPODAYS. Open demands carry NULL resolution days.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactRepurchaseDemand
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactRepurchaseDemand',
        @TargetObject = N'dw.FactRepurchaseDemand',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_InvRepurchaseDemand;

        TRUNCATE TABLE dw.FactRepurchaseDemand;

        INSERT INTO dw.FactRepurchaseDemand
            (RepurchaseDemandId, LoanKey, LoanNumber,
             InvestorKey, DemandReceivedDateKey,
             DemandReceivedDate, DemandReasonCode,
             DemandAmount, ResolutionDate,
             ResolutionTypeCode, ResolutionDays,
             ResolvedFlag, LoadBatchId)
        SELECT
            d.RepurchaseDemandId,
            dl.LoanKey,
            d.LoanNumber,
            ISNULL(di.InvestorKey, du.InvestorKey),
            CONVERT(INT, CONVERT(CHAR(8),
                d.DemandReceivedDate, 112)),
            d.DemandReceivedDate,
            d.DemandReasonCode,
            d.DemandAmount,
            d.ResolutionDate,
            d.ResolutionTypeCode,
            DATEDIFF(DAY, d.DemandReceivedDate,
                     d.ResolutionDate),
            CASE WHEN d.ResolutionDate IS NOT NULL
                 THEN 1 ELSE 0 END,
            @LoadBatchId
        FROM stg.vw_InvRepurchaseDemand d
        JOIN dw.DimLoan dl
          ON dl.LoanNumber = d.LoanNumber
        LEFT JOIN dw.DimInvestor di
          ON di.InvestorCode = d.InvestorCode
        CROSS JOIN
        (
            SELECT InvestorKey FROM dw.DimInvestor
            WHERE InvestorCode = 'UNKNOWN'
        ) du;

        SET @RowsInserted = @@ROWCOUNT;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_InvRepurchaseDemand',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactRepurchaseDemand',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = N'DRV_REPODAYS',
            @CreatedByObject =
                N'dw.usp_LoadFactRepurchaseDemand',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo =
                N'dw.usp_LoadFactRepurchaseDemand';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactLead
   DRV_LOATTRIB: SCD2 as-of AssignedDate with LeadCreatedDate
   fallback, resolved with a deterministic TOP 1. DRV_LEADCONV
   with the window from ref.SlaPolicy LEAD_ATTRIB. DEF20 null
   lead sources map to the UNKNOWN member. DEF15 duplicate
   leads load at grain (one row per lead) and are caught by
   DQR15, not suppressed here.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactLead
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @SlaDays INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactLead',
        @TargetObject = N'dw.FactLead',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_CrmLead;

        SELECT @SlaDays = SlaDays
        FROM ref.SlaPolicy
        WHERE SlaPolicyCode = 'LEAD_ATTRIB';

        TRUNCATE TABLE dw.FactLead;

        INSERT INTO dw.FactLead
            (LeadId, LeadCreatedDateKey, LeadCreatedDate,
             LeadSourceKey, CampaignCode, ContactKey,
             PropertyStateCode, LoanOfficerKey, AssignedDate,
             FirstContactDate, LeadStatusCode,
             ConvertedApplicationId, ConvertedFlag,
             ConvertedInWindowFlag, DaysToConvert,
             LoadBatchId)
        SELECT
            l.LeadId,
            CONVERT(INT, CONVERT(CHAR(8),
                l.LeadCreatedDate, 112)),
            l.LeadCreatedDate,
            ISNULL(ls.LeadSourceKey, us.LeadSourceKey),
            l.CampaignCode,
            l.ContactKey,
            l.PropertyStateCode,
            ISNULL(lo.LoanOfficerKey, uo.LoanOfficerKey),
            l.AssignedDate,
            l.FirstContactDate,
            l.LeadStatusCode,
            l.ConvertedApplicationId,
            CASE WHEN l.ConvertedApplicationId IS NOT NULL
                 THEN 1 ELSE 0 END,
            CASE WHEN a.AppReceivedDate IS NOT NULL
                  AND a.AppReceivedDate <=
                      DATEADD(DAY, @SlaDays,
                              l.LeadCreatedDate)
                 THEN 1 ELSE 0 END,
            CASE WHEN a.AppReceivedDate IS NOT NULL
                 THEN DATEDIFF(DAY, l.LeadCreatedDate,
                               a.AppReceivedDate) END,
            @LoadBatchId
        FROM stg.vw_CrmLead l
        LEFT JOIN dw.DimLeadSource ls
          ON ls.LeadSourceCode = l.LeadSourceCode
        CROSS JOIN
        (
            SELECT LeadSourceKey FROM dw.DimLeadSource
            WHERE LeadSourceCode = 'UNKNOWN'
        ) us
        OUTER APPLY
        (
            SELECT TOP (1) d.LoanOfficerKey
            FROM dw.DimLoanOfficer d
            WHERE d.NmlsId = l.AssignedLoanOfficerNmlsId
              AND ISNULL(l.AssignedDate, l.LeadCreatedDate)
                  BETWEEN d.EffectiveFromDate
                      AND ISNULL(d.EffectiveToDate,
                                 '9999-12-31')
            ORDER BY d.EffectiveFromDate DESC
        ) lo
        CROSS JOIN
        (
            SELECT LoanOfficerKey FROM dw.DimLoanOfficer
            WHERE NmlsId = 'UNKNOWN'
        ) uo
        LEFT JOIN stg.vw_LosApplication a
          ON a.ApplicationId = l.ConvertedApplicationId;

        SET @RowsInserted = @@ROWCOUNT;

        SET @Xform = N'DRV_LOATTRIB as of AssignedDate, '
            + N'DRV_LEADCONV via LEAD_ATTRIB window';
        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_CrmLead',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactLead',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = @Xform,
            @CreatedByObject = N'dw.usp_LoadFactLead',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo = N'dw.usp_LoadFactLead';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactApplication
   DRV_LOATTRIB: SCD2 as-of COALESCE(FundingDate,
   AppReceivedDate, AppStartedDate); funding metrics attribute
   at funding, application stage metrics at receipt, resolved
   here in the loader, never in DAX. Unmapped NMLS ids (DEF14
   LO 999999) resolve to the UNKNOWN member; BranchKey follows
   the attributed LO version row. DRV_CYCLETIME preserves
   DEF16 negative cycle times for DQR16. DRV_ONTIMECLOSE,
   DRV_APPTOLOCK, DRV_DENIAL as canonical. DRV_FALLOUT
   deviation: the column is NOT NULL so open applications and
   DEF17 nulled dispositions carry 0 rather than NULL; the
   fallout rate counts FallenOutFlag = 1 only, so the metric
   is unchanged, and the AC066 = AC090 identity control still
   exposes DEF17.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactApplication
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactApplication',
        @TargetObject = N'dw.FactApplication',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_LosApplication;

        TRUNCATE TABLE dw.FactApplication;

        INSERT INTO dw.FactApplication
            (ApplicationId, LeadId, LoanOfficerKey,
             BranchKey, LoanOfficerNmlsId,
             AppStartedDateKey, AppStartedDate,
             AppCompletedDate, AppReceivedDateKey,
             AppReceivedDate, LoanAmountAtApplication,
             CurrentLoanAmount, LoanPurposeCode,
             PurposeDetailCode, LoanProgramCode,
             InterestRateTypeCode, LienPosition,
             PropertyStateCode, ChannelCode,
             DispositionCode, DispositionDate,
             ScheduledClosingDate, ActualClosingDate,
             FundingDateKey, FundingDate, LoanNumber,
             FundedFlag, CycleTimeDays, OnTimeCloseFlag,
             EverLockedFlag, FallenOutFlag,
             DenialEligibleFlag, DeniedFlag, LoadBatchId)
        SELECT
            a.ApplicationId,
            a.LeadId,
            ISNULL(lo.LoanOfficerKey, uo.LoanOfficerKey),
            ISNULL(br.BranchKey, ub.BranchKey),
            a.LoanOfficerNmlsId,
            CONVERT(INT, CONVERT(CHAR(8),
                a.AppStartedDate, 112)),
            a.AppStartedDate,
            a.AppCompletedDate,
            CONVERT(INT, CONVERT(CHAR(8),
                a.AppReceivedDate, 112)),
            a.AppReceivedDate,
            a.LoanAmountAtApplication,
            a.CurrentLoanAmount,
            a.LoanPurposeCode,
            a.PurposeDetailCode,
            a.LoanProgramCode,
            a.InterestRateTypeCode,
            a.LienPosition,
            a.PropertyStateCode,
            a.ChannelCode,
            a.DispositionCode,
            a.DispositionDate,
            a.ScheduledClosingDate,
            a.ActualClosingDate,
            CONVERT(INT, CONVERT(CHAR(8),
                a.FundingDate, 112)),
            a.FundingDate,
            a.LoanNumber,
            ISNULL(a.FundedFlag, 0),
            /* DRV_CYCLETIME: funded only; DEF16 negatives
               preserved for DQR16 */
            CASE WHEN a.FundedFlag = 1
                  AND a.AppReceivedDate IS NOT NULL
                 THEN DATEDIFF(DAY, a.AppReceivedDate,
                               a.FundingDate) END,
            /* DRV_ONTIMECLOSE */
            CASE WHEN a.ActualClosingDate IS NULL THEN NULL
                 WHEN a.ActualClosingDate <=
                      a.ScheduledClosingDate
                 THEN 1 ELSE 0 END,
            /* DRV_APPTOLOCK */
            CASE WHEN EXISTS
                      (SELECT 1 FROM stg.vw_PpeRateLock k
                       WHERE k.ApplicationId =
                             a.ApplicationId)
                 THEN 1 ELSE 0 END,
            /* DRV_FALLOUT (see header note) */
            CASE WHEN a.DispositionCode IN
                      ('DENIED','WITHDRAWN','ANA',
                       'INCOMPLETE')
                 THEN 1 ELSE 0 END,
            /* DRV_DENIAL */
            CASE WHEN a.DispositionCode IN ('DENIED','ANA')
                   OR a.FundedFlag = 1
                 THEN 1 ELSE 0 END,
            CASE WHEN a.DispositionCode = 'DENIED'
                 THEN 1 ELSE 0 END,
            @LoadBatchId
        FROM stg.vw_LosApplication a
        OUTER APPLY
        (
            SELECT TOP (1) d.LoanOfficerKey, d.BranchCode
            FROM dw.DimLoanOfficer d
            WHERE d.NmlsId = a.LoanOfficerNmlsId
              AND COALESCE(a.FundingDate,
                           a.AppReceivedDate,
                           a.AppStartedDate)
                  BETWEEN d.EffectiveFromDate
                      AND ISNULL(d.EffectiveToDate,
                                 '9999-12-31')
            ORDER BY d.EffectiveFromDate DESC
        ) lo
        CROSS JOIN
        (
            SELECT LoanOfficerKey FROM dw.DimLoanOfficer
            WHERE NmlsId = 'UNKNOWN'
        ) uo
        LEFT JOIN dw.DimBranch br
          ON br.BranchCode = lo.BranchCode
        CROSS JOIN
        (
            SELECT BranchKey FROM dw.DimBranch
            WHERE BranchCode = 'UNK'
        ) ub;

        SET @RowsInserted = @@ROWCOUNT;

        SET @Xform = N'DRV_LOATTRIB, DRV_CYCLETIME, '
            + N'DRV_ONTIMECLOSE, DRV_FALLOUT, '
            + N'DRV_DENIAL';
        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_LosApplication',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactApplication',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic = @Xform,
            @CreatedByObject =
                N'dw.usp_LoadFactApplication',
            @LoadBatchId = @LoadBatchId;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_PpeRateLock',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactApplication',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic =
                N'DRV_APPTOLOCK EverLockedFlag',
            @CreatedByObject =
                N'dw.usp_LoadFactApplication',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo = N'dw.usp_LoadFactApplication';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactRateLock
   DRV_LOCKEXT, DRV_LOCKEXP (funding status joined from the
   application), DRV_RELOCK. DEF18 backwards expirations load
   as received for DQR18.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactRateLock
    @LoadBatchId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactRateLock',
        @TargetObject = N'dw.FactRateLock',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_PpeRateLock;

        TRUNCATE TABLE dw.FactRateLock;

        INSERT INTO dw.FactRateLock
            (RateLockId, ApplicationId, LockDateKey,
             LockDate, LockAmount, NoteRatePercent,
             LockPeriodDays, OriginalExpirationDate,
             CurrentExpirationDate, ExtensionCount,
             TotalExtensionDays, LockStatusCode,
             PriorLockId, ExtendedFlag,
             ExpiredWithoutFundingFlag, RelockFlag,
             LoadBatchId)
        SELECT
            k.RateLockId,
            k.ApplicationId,
            CONVERT(INT, CONVERT(CHAR(8),
                k.LockDate, 112)),
            k.LockDate,
            k.LockAmount,
            k.NoteRatePercent,
            k.LockPeriodDays,
            k.OriginalExpirationDate,
            k.CurrentExpirationDate,
            k.ExtensionCount,
            k.TotalExtensionDays,
            k.LockStatusCode,
            k.PriorLockId,
            /* DRV_LOCKEXT */
            CASE WHEN k.ExtensionCount > 0
                 THEN 1 ELSE 0 END,
            /* DRV_LOCKEXP */
            CASE WHEN k.LockStatusCode = 'EXPIRED'
                  AND ISNULL(a.FundedFlag, 0) = 0
                  AND ISNULL(k.ExtensionCount, 0) = 0
                 THEN 1 ELSE 0 END,
            /* DRV_RELOCK */
            CASE WHEN k.PriorLockId IS NOT NULL
                 THEN 1 ELSE 0 END,
            @LoadBatchId
        FROM stg.vw_PpeRateLock k
        LEFT JOIN stg.vw_LosApplication a
          ON a.ApplicationId = k.ApplicationId;

        SET @RowsInserted = @@ROWCOUNT;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_PpeRateLock',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactRateLock',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic =
                N'DRV_LOCKEXT, DRV_LOCKEXP, DRV_RELOCK',
            @CreatedByObject = N'dw.usp_LoadFactRateLock',
            @LoadBatchId = @LoadBatchId;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_LosApplication',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactRateLock',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic =
                N'FundedFlag input to DRV_LOCKEXP',
            @CreatedByObject = N'dw.usp_LoadFactRateLock',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo = N'dw.usp_LoadFactRateLock';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_LoadFactLoanOfficerLicense
   License compliance snapshot at @AsOfDate. DRV_MLOLIC and
   DRV_CE as canonical; missing CE hours or completion date
   fails compliance (0, not NULL) because the obligation
   exists regardless of recording. DEF19 expired TX licenses
   surface as LicenseCompliantFlag = 0. LoanOfficerKey links
   the current SCD2 row for roster context; NULL when the
   NmlsId has no roster row.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_LoadFactLoanOfficerLicense
    @LoadBatchId INT,
    @AsOfDate    DATE = '2026-07-31'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadExecutionId INT,
            @RowsRead INT, @RowsInserted INT,
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    EXEC audit.usp_StartLoadExecution
        @LoadBatchId = @LoadBatchId,
        @StepName = N'Load FactLoanOfficerLicense',
        @TargetObject = N'dw.FactLoanOfficerLicense',
        @LoadExecutionId = @LoadExecutionId OUTPUT;

    BEGIN TRY
        SELECT @RowsRead = COUNT(*)
        FROM stg.vw_LicLoanOfficerLicense;

        TRUNCATE TABLE dw.FactLoanOfficerLicense;

        INSERT INTO dw.FactLoanOfficerLicense
            (LoanOfficerLicenseId, NmlsId, LoanOfficerKey,
             LicenseStateCode, LicenseTypeCode,
             LicenseStatusCode, IssueDate, ExpirationDate,
             RenewalDeadline, CeRequiredHours,
             CeCompletedHours, CeCompletedDate, AsOfDate,
             AsOfDateKey, CeCompliantFlag,
             LicenseCompliantFlag, LoadBatchId)
        SELECT
            c.LoanOfficerLicenseId,
            c.NmlsId,
            d.LoanOfficerKey,
            c.LicenseStateCode,
            c.LicenseTypeCode,
            c.LicenseStatusCode,
            c.IssueDate,
            c.ExpirationDate,
            c.RenewalDeadline,
            c.CeRequiredHours,
            c.CeCompletedHours,
            c.CeCompletedDate,
            @AsOfDate,
            CONVERT(INT, CONVERT(CHAR(8), @AsOfDate, 112)),
            /* DRV_CE */
            CASE WHEN c.CeCompletedHours IS NULL
                   OR c.CeCompletedDate IS NULL THEN 0
                 WHEN c.CeCompletedHours >=
                      ISNULL(c.CeRequiredHours, 0)
                  AND c.CeCompletedDate <=
                      c.RenewalDeadline
                 THEN 1 ELSE 0 END,
            /* DRV_MLOLIC */
            CASE WHEN c.LicenseStatusCode = 'ACTIVE'
                  AND c.ExpirationDate >= @AsOfDate
                 THEN 1 ELSE 0 END,
            @LoadBatchId
        FROM stg.vw_LicLoanOfficerLicense c
        LEFT JOIN dw.DimLoanOfficer d
          ON d.NmlsId = c.NmlsId
         AND d.CurrentRowFlag = 1;

        SET @RowsInserted = @@ROWCOUNT;

        EXEC gov.usp_RegisterLineageEdge
            @FromNodeTypeCode = 'STAGING_OBJECT',
            @FromNodeName = N'stg.vw_LicLoanOfficerLicense',
            @ToNodeTypeCode = 'WAREHOUSE_OBJECT',
            @ToNodeName = N'dw.FactLoanOfficerLicense',
            @EdgeTypeCode = 'FEEDS_INTO',
            @MappingTypeCode = 'DERIVED',
            @TransformationLogic =
                N'DRV_MLOLIC, DRV_CE at @AsOfDate',
            @CreatedByObject =
                N'dw.usp_LoadFactLoanOfficerLicense',
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'SUCCESS',
            @RowsRead = @RowsRead,
            @RowsInserted = @RowsInserted;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = @LoadExecutionId,
            @ContextInfo =
                N'dw.usp_LoadFactLoanOfficerLicense';
        EXEC audit.usp_CompleteLoadExecution
            @LoadExecutionId = @LoadExecutionId,
            @StatusCode = 'FAILED',
            @ErrorMessage = @Err;
        THROW;
    END CATCH
END
GO

/* ------------------------------------------------------------
   dw.usp_RunFullLoad
   Master orchestration. One load batch wraps the whole run;
   each loader records its own execution row. Any loader
   failure marks the batch FAILED and rethrows.
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dw.usp_RunFullLoad
    @BatchName NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LoadBatchId INT,
            @BatchNotes NVARCHAR(1000),
            @Err NVARCHAR(4000),
            @Xform NVARCHAR(2000);

    IF @BatchName IS NULL
        SET @BatchName = N'DW full load';
    SET @BatchNotes =
        N'Dimensions upserted, facts truncated and '
        + N'reloaded by dw.usp_RunFullLoad';

    EXEC audit.usp_StartLoadBatch
        @BatchName = @BatchName,
        @BatchTypeCode = 'FULL',
        @Notes = @BatchNotes,
        @LoadBatchId = @LoadBatchId OUTPUT;

    BEGIN TRY
        EXEC dw.usp_LoadDimDate
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadDimensions
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadDimLoanOfficer
            @LoadBatchId = @LoadBatchId;

        EXEC dw.usp_LoadFactLoanMonthEndSnapshot
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactPaymentTransaction
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactEscrowDisbursement
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactEscrowAnalysis
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactLossMitigationCase
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactForeclosureCase
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactBankruptcyCase
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactBoardingEvent
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactInvestorLoanReporting
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactInvestorRemittance
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactRepurchaseDemand
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactLead
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactApplication
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactRateLock
            @LoadBatchId = @LoadBatchId;
        EXEC dw.usp_LoadFactLoanOfficerLicense
            @LoadBatchId = @LoadBatchId;

        EXEC audit.usp_CompleteLoadBatch
            @LoadBatchId = @LoadBatchId,
            @StatusCode = 'SUCCESS';
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        EXEC audit.usp_LogError
            @LoadBatchId = @LoadBatchId,
            @LoadExecutionId = NULL,
            @ContextInfo = N'dw.usp_RunFullLoad';
        EXEC audit.usp_CompleteLoadBatch
            @LoadBatchId = @LoadBatchId,
            @StatusCode = 'FAILED';
        THROW;
    END CATCH
END
GO

PRINT '016_dw_load_procs.sql complete: lineage helper, 3 '
    + 'dimension loaders, 15 fact loaders, master '
    + 'dw.usp_RunFullLoad.';
GO
