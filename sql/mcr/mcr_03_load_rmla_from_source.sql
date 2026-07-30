/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_03_load_rmla_from_source.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT (FULL SCHEMA)
   03 - Loader: aggregate loan-level source data into MCR elements
   ----------------------------------------------------------------------------
   mcr.usp_LoadReportValues @FilingId
     Writes element-level mcr.ReportValues + mcr.RepeatingValues.

   VERSION NOTE: the LS300-340 by-investor mapping targets items introduced
   in FV7 and is active under the current V7 catalog. Under an older catalog
   (e.g. the archived V6 baseline) those elements do not exist, so the
   FieldCatalogElement join skips them automatically - the mapping is
   version-safe in both directions. Same for any other version-specific item.

   COLUMN-PAIR CONVENTION (from the form):
     Element suffix pairs (1,2)(3,4)(5,6) are (amount,count) for form column
     group g = 1,2,3. Application data: g1 = Directly from Borrower,
     g2 = Received from 3rd Party. Closed-loan grids: g1 = Brokered,
     g2 = Closed-Retail, g3 = Closed-Wholesale.
   Every insert joins mcr.FieldCatalogElement, so elements the XSD does not
   define are silently skipped and nothing invalid can be staged.

   NOT loaded here (no loan-level source in this fictional model - these are
   catalog-supported and load the same way once a source exists):
     fees AC600-630, reverse AC700-890, Section II I220/I270-I341/I430/I450/
     I460 and secondary-market I400s, Section III modification S1xx/S2xx,
     foreclosure S4xx detail beyond flags, rate/type-on-serviced S6xx-S8xx,
     serviced LTV S1000s, FC Schedules B/C/D (finance-fed from the GL), SSSF.
   ============================================================================ */
IF OBJECT_ID('mcr.usp_LoadReportValues') IS NOT NULL DROP PROCEDURE mcr.usp_LoadReportValues;
GO
CREATE PROCEDURE mcr.usp_LoadReportValues @FilingId INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM mcr.ReportValues    WHERE FilingId = @FilingId;
    DELETE FROM mcr.RepeatingValues WHERE FilingId = @FilingId;

    /* =============== helper: aggregate -> elements ====================== *
       Pattern used throughout: build (ScopeKey, ItemCode, Grp, Amt, Cnt)
       aggregates, then join FieldCatalogElement on ColumnNo IN (2g-1, 2g)
       and pick Amt or Cnt by DataType.                                      */

    /* ---- Section I: application pipeline, 2 column groups ---- */
    ;WITH agg AS (
        SELECT a.StateCode,
            ItemCode = CASE a.DecisionStatus
                WHEN 'InProcessBOP'        THEN 'AC010'
                WHEN 'Received'            THEN 'AC020'
                WHEN 'ApprovedNotAccepted' THEN 'AC030'
                WHEN 'Denied'              THEN 'AC040'
                WHEN 'Withdrawn'           THEN 'AC050'
                WHEN 'FileClosedIncomplete'THEN 'AC060'
                WHEN 'ClosedFunded'        THEN 'AC070'
                WHEN 'InProcessEOP'        THEN 'AC080' END,
            Grp = CASE a.SourceChannel WHEN 'DirectBorrower' THEN 1 ELSE 2 END,
            Amt = SUM(a.AppAmount), Cnt = COUNT(*)
        FROM mcrstg.Applications a
        WHERE a.FilingId = @FilingId
          AND a.DecisionStatus IN ('InProcessBOP','Received','ApprovedNotAccepted','Denied',
                                   'Withdrawn','FileClosedIncomplete','ClosedFunded','InProcessEOP')
        GROUP BY a.StateCode,
            CASE a.DecisionStatus
                WHEN 'InProcessBOP'        THEN 'AC010'
                WHEN 'Received'            THEN 'AC020'
                WHEN 'ApprovedNotAccepted' THEN 'AC030'
                WHEN 'Denied'              THEN 'AC040'
                WHEN 'Withdrawn'           THEN 'AC050'
                WHEN 'FileClosedIncomplete'THEN 'AC060'
                WHEN 'ClosedFunded'        THEN 'AC070'
                WHEN 'InProcessEOP'        THEN 'AC080' END,
            CASE a.SourceChannel WHEN 'DirectBorrower' THEN 1 ELSE 2 END
    )
    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, NumValue)
    SELECT @FilingId, agg.StateCode, e.ElementName,
           CASE WHEN e.DataType = 'Count' THEN agg.Cnt ELSE agg.Amt END
    FROM agg
    JOIN mcr.FieldCatalogElement e
      ON e.ItemCode = agg.ItemCode AND e.ColumnNo IN (agg.Grp*2-1, agg.Grp*2);

    /* ---- Closed-loan grids: 3 channel column groups ---- *
       LoanType AC100-130, PropertyType AC200/210, Purpose AC300-320,
       HOEPA AC400, Lien AC500-520, QM AC920-940.
       Amount basis: NoteAmount (closed-loan amount).                        */
    ;WITH cl AS (
        SELECT c.StateCode, c.NoteAmount,
            Grp = CASE c.Channel WHEN 'Brokered' THEN 1 WHEN 'ClosedRetail' THEN 2 ELSE 3 END,
            TypeItem = CASE c.LoanType WHEN 'Conventional' THEN 'AC100' WHEN 'FHA' THEN 'AC110'
                                       WHEN 'VA' THEN 'AC120' WHEN 'FSARHS' THEN 'AC130' END,
            PropItem = CASE c.PropertyType WHEN 'OneToFour' THEN 'AC200' WHEN 'Manufactured' THEN 'AC210' END,
            PurpItem = CASE c.Purpose WHEN 'Purchase' THEN 'AC300' WHEN 'HomeImprovement' THEN 'AC310'
                                      WHEN 'Refinance' THEN 'AC320' END,
            HoepaItem = CASE c.HoepaStatus WHEN 'HOEPA' THEN 'AC400' END,
            LienItem = CASE c.LienStatus WHEN 'First' THEN 'AC500' WHEN 'Subordinate' THEN 'AC510'
                                         WHEN 'NoLien' THEN 'AC520' END,
            QmItem   = CASE c.QmStatus WHEN 'QM' THEN 'AC920' WHEN 'NonQM' THEN 'AC930'
                                       WHEN 'NotSubject' THEN 'AC940' END
        FROM mcrstg.ClosedLoans c
        WHERE c.FilingId = @FilingId
    ),
    unp AS (
        SELECT StateCode, Grp, ItemCode, NoteAmount
        FROM cl
        CROSS APPLY (VALUES (TypeItem),(PropItem),(PurpItem),(HoepaItem),(LienItem),(QmItem)) v(ItemCode)
        WHERE v.ItemCode IS NOT NULL
    ),
    agg AS (
        SELECT StateCode, ItemCode, Grp, Amt = SUM(NoteAmount), Cnt = COUNT(*)
        FROM unp GROUP BY StateCode, ItemCode, Grp
    )
    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, NumValue)
    SELECT @FilingId, agg.StateCode, e.ElementName,
           CASE WHEN e.DataType = 'Count' THEN agg.Cnt ELSE agg.Amt END
    FROM agg
    JOIN mcr.FieldCatalogElement e
      ON e.ItemCode = agg.ItemCode AND e.ColumnNo IN (agg.Grp*2-1, agg.Grp*2);

    /* ---- Section I: repurchases AC1000, servicing disposition AC1200/1210,
            gross origination revenue AC1100 (single column group) ---- */
    ;WITH agg AS (
        SELECT r.StateCode, ItemCode='AC1000', Amt=SUM(r.UPB), Cnt=SUM(r.LoanCount)
        FROM mcrstg.Repurchases r WHERE r.FilingId=@FilingId GROUP BY r.StateCode
        UNION ALL
        SELECT c.StateCode,
               CASE c.ServicingDispo WHEN 'Retained' THEN 'AC1200' WHEN 'Released' THEN 'AC1210' END,
               SUM(c.NoteAmount), COUNT(*)
        FROM mcrstg.ClosedLoans c
        WHERE c.FilingId=@FilingId AND c.ServicingDispo IN ('Retained','Released')
        GROUP BY c.StateCode, CASE c.ServicingDispo WHEN 'Retained' THEN 'AC1200' WHEN 'Released' THEN 'AC1210' END
    )
    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, NumValue)
    SELECT @FilingId, agg.StateCode, e.ElementName,
           CASE WHEN e.DataType = 'Count' THEN agg.Cnt ELSE agg.Amt END
    FROM agg
    JOIN mcr.FieldCatalogElement e ON e.ItemCode = agg.ItemCode AND e.ColumnNo IN (1,2);

    /* ---- Section II: first-mortgage grid, mapped source dimensions ---- *
       I010-I080 type/amort grid; I110 closed-end seconds; I210/I230 how
       originated; I250/251 rate type; I260/261 jumbo; I310/I312 purpose;
       I370-375 LTV distribution. First liens only except I110.             */
    ;WITH fl AS (
        SELECT c.StateCode, c.NoteAmount, c.AppraisedValue,
            Ltv = CASE WHEN c.AppraisedValue > 0
                       THEN CAST(c.NoteAmount AS DECIMAL(18,4)) / c.AppraisedValue * 100.0 END,
            GridItem = CASE
                WHEN c.LoanType IN ('FHA','VA','FSARHS') AND c.AmortType='Fixed' THEN 'I010'
                WHEN c.LoanType IN ('FHA','VA','FSARHS') AND c.AmortType='ARM'   THEN 'I020'
                WHEN c.Conforming='Conforming' AND c.AmortType='Fixed' THEN 'I030'
                WHEN c.Conforming='Conforming' AND c.AmortType='ARM'   THEN 'I040'
                WHEN c.Conforming='Jumbo'      AND c.AmortType='Fixed' THEN 'I050'
                WHEN c.Conforming='Jumbo'      AND c.AmortType='ARM'   THEN 'I060'
                WHEN c.AmortType='Fixed' THEN 'I070' ELSE 'I080' END,
            HowItem  = CASE c.Channel WHEN 'ClosedRetail' THEN 'I210' WHEN 'Brokered' THEN 'I230' END,
            RateItem = CASE c.AmortType WHEN 'Fixed' THEN 'I250' ELSE 'I251' END,
            JumboItem= CASE WHEN c.Conforming='Jumbo' THEN 'I260' ELSE 'I261' END,
            PurpItem = CASE c.Purpose WHEN 'Purchase' THEN 'I310'
                                      WHEN 'Refinance' THEN 'I312' ELSE NULL END
        FROM mcrstg.ClosedLoans c
        WHERE c.FilingId = @FilingId AND c.LienStatus = 'First'
    ),
    withLtv AS (
        SELECT *, LtvItem = CASE
            WHEN Ltv IS NULL   THEN NULL
            WHEN Ltv <= 60.0   THEN 'I370'
            WHEN Ltv <= 70.0   THEN 'I371'
            WHEN Ltv <= 80.0   THEN 'I372'
            WHEN Ltv <= 90.0   THEN 'I373'
            WHEN Ltv <= 100.0  THEN 'I374'
            ELSE 'I375' END
        FROM fl
    ),
    unp AS (
        SELECT StateCode, ItemCode, NoteAmount
        FROM withLtv
        CROSS APPLY (VALUES (GridItem),(HowItem),(RateItem),(JumboItem),(PurpItem),(LtvItem)) v(ItemCode)
        WHERE v.ItemCode IS NOT NULL
    ),
    agg AS (
        SELECT StateCode, ItemCode, Amt = SUM(NoteAmount), Cnt = COUNT(*)
        FROM unp GROUP BY StateCode, ItemCode
    )
    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, NumValue)
    SELECT @FilingId, agg.StateCode, e.ElementName,
           CASE WHEN e.DataType = 'Count' THEN agg.Cnt ELSE agg.Amt END
    FROM agg
    JOIN mcr.FieldCatalogElement e ON e.ItemCode = agg.ItemCode AND e.ColumnNo IN (1,2);

    /* ---- Section II: weighted averages (Hundredth; count element is _2) -- */
    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, NumValue)
    SELECT @FilingId, c.StateCode, 'I380_2',
        CAST( SUM( (CAST(c.NoteAmount AS DECIMAL(18,4)) / NULLIF(c.AppraisedValue,0) * 100.0) * c.NoteAmount )
              / NULLIF(SUM(c.NoteAmount),0) AS DECIMAL(15,2) )
    FROM mcrstg.ClosedLoans c
    WHERE c.FilingId = @FilingId AND c.LienStatus = 'First' AND c.AppraisedValue > 0
    GROUP BY c.StateCode;

    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, NumValue)
    SELECT @FilingId, c.StateCode, 'I390_2',
        CAST( SUM(c.NoteRatePct * c.NoteAmount) / NULLIF(SUM(c.NoteAmount),0) AS DECIMAL(15,2) )
    FROM mcrstg.ClosedLoans c
    WHERE c.FilingId = @FilingId AND c.LienStatus = 'First' AND c.NoteRatePct IS NOT NULL
    GROUP BY c.StateCode;

    /* ---- Section III: delinquency (All Loans grid S300-S315), ownership
            S510-540, and foreclosure flag count into S400 group ---- */
    ;WITH agg AS (
        SELECT s.StateCode,
            ItemCode = CASE s.DelinquencyBucket WHEN 'LT30' THEN 'S300' WHEN 'D30_59' THEN 'S305'
                                                WHEN 'D60_89' THEN 'S310' WHEN 'D90Plus' THEN 'S315' END,
            Amt = SUM(s.UPB), Cnt = COUNT(*)
        FROM mcrstg.ServicingPortfolio s WHERE s.FilingId = @FilingId
        GROUP BY s.StateCode, CASE s.DelinquencyBucket WHEN 'LT30' THEN 'S300' WHEN 'D30_59' THEN 'S305'
                                                       WHEN 'D60_89' THEN 'S310' WHEN 'D90Plus' THEN 'S315' END
        UNION ALL
        SELECT s.StateCode,
            CASE s.OwnershipType WHEN 'WhollyOwned' THEN 'S510' WHEN 'UnderMSR' THEN 'S520'
                                 WHEN 'SubservicingForOthers' THEN 'S530' WHEN 'SubservicedByOthers' THEN 'S540' END,
            SUM(s.UPB), COUNT(*)
        FROM mcrstg.ServicingPortfolio s WHERE s.FilingId = @FilingId
        GROUP BY s.StateCode, CASE s.OwnershipType WHEN 'WhollyOwned' THEN 'S510' WHEN 'UnderMSR' THEN 'S520'
                                                   WHEN 'SubservicingForOthers' THEN 'S530' WHEN 'SubservicedByOthers' THEN 'S540' END
        UNION ALL
        SELECT s.StateCode, 'S400', SUM(s.UPB), COUNT(*)
        FROM mcrstg.ServicingPortfolio s WHERE s.FilingId = @FilingId AND s.InForeclosure = 1
        GROUP BY s.StateCode
    )
    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, NumValue)
    SELECT @FilingId, agg.StateCode, e.ElementName,
           CASE WHEN e.DataType = 'Count' THEN agg.Cnt ELSE agg.Amt END
    FROM agg
    JOIN mcr.FieldCatalogElement e ON e.ItemCode = agg.ItemCode AND e.ColumnNo IN (1,2);

    /* ---- Company-level LS: ownership, transfers, payment status, investor - */
    ;WITH agg AS (
        SELECT ItemCode = CASE s.OwnershipType WHEN 'WhollyOwned' THEN 'LS010' WHEN 'UnderMSR' THEN 'LS020'
                              WHEN 'SubservicingForOthers' THEN 'LS030' WHEN 'SubservicedByOthers' THEN 'LS040' END,
               Amt = SUM(s.UPB), Cnt = COUNT(*)
        FROM mcrstg.ServicingPortfolio s WHERE s.FilingId=@FilingId
        GROUP BY CASE s.OwnershipType WHEN 'WhollyOwned' THEN 'LS010' WHEN 'UnderMSR' THEN 'LS020'
                     WHEN 'SubservicingForOthers' THEN 'LS030' WHEN 'SubservicedByOthers' THEN 'LS040' END
        UNION ALL
        SELECT CASE t.Direction WHEN 'In' THEN 'LS100' ELSE 'LS110' END, SUM(t.UPB), SUM(t.LoanCount)
        FROM mcrstg.ServicingTransfers t WHERE t.FilingId=@FilingId GROUP BY t.Direction
        UNION ALL
        SELECT CASE s.DelinquencyBucket WHEN 'LT30' THEN 'LS200' WHEN 'D30_59' THEN 'LS210'
                                        WHEN 'D60_89' THEN 'LS220' WHEN 'D90Plus' THEN 'LS230' END,
               SUM(s.UPB), COUNT(*)
        FROM mcrstg.ServicingPortfolio s WHERE s.FilingId=@FilingId
        GROUP BY CASE s.DelinquencyBucket WHEN 'LT30' THEN 'LS200' WHEN 'D30_59' THEN 'LS210'
                     WHEN 'D60_89' THEN 'LS220' WHEN 'D90Plus' THEN 'LS230' END
        UNION ALL
        SELECT CASE s.Investor WHEN 'FNMA' THEN 'LS300' WHEN 'FHLMC' THEN 'LS310' WHEN 'GNMA' THEN 'LS320'
                               WHEN 'PrivateLabel' THEN 'LS330' ELSE 'LS340' END,
               SUM(s.UPB), COUNT(*)
        FROM mcrstg.ServicingPortfolio s WHERE s.FilingId=@FilingId
        GROUP BY CASE s.Investor WHEN 'FNMA' THEN 'LS300' WHEN 'FHLMC' THEN 'LS310' WHEN 'GNMA' THEN 'LS320'
                     WHEN 'PrivateLabel' THEN 'LS330' ELSE 'LS340' END
    )
    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, NumValue)
    SELECT @FilingId, 'COMPANY', e.ElementName,
           CASE WHEN e.DataType = 'Count' THEN agg.Cnt ELSE agg.Amt END
    FROM agg
    JOIN mcr.FieldCatalogElement e ON e.ItemCode = agg.ItemCode AND e.ColumnNo IN (1,2);

    /* ---- FC: A/O stubs (finance-fed from the GL in production; Schedules
            B/C/D load the same way: INSERT element rows with ScopeKey='FC') */
    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, NumValue) VALUES
    (@FilingId,'FC','A010_1', 8500000),
    (@FilingId,'FC','A038_1', 2200000),
    (@FilingId,'FC','O310_1', 1000000),
    (@FilingId,'FC','O320_1',  250000),
    (@FilingId,'FC','O330_1', -180000),
    (@FilingId,'FC','O340_1',       0);

    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, NumValue)
    SELECT @FilingId, 'FC', 'O360_1', SUM(r.UPB)
    FROM mcrstg.Repurchases r WHERE r.FilingId=@FilingId HAVING COUNT(*) > 0;
    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, NumValue)
    SELECT @FilingId, 'FC', 'O370_1', SUM(r.LoanCount)
    FROM mcrstg.Repurchases r WHERE r.FilingId=@FilingId HAVING COUNT(*) > 0;

    /* ---- Repeating lists ---- */
    /* MLO detail (per state) */
    INSERT INTO mcr.RepeatingValues (FilingId, ScopeKey, ListName, ItemSeq, ElementName, NumValue)
    SELECT @FilingId, x.StateCode, 'SectionIMlosItem', x.rn, v.ElementName, v.NumValue
    FROM (
        SELECT c.StateCode, c.MloNmlsId, SUM(c.NoteAmount) Amt, COUNT(*) Cnt,
               rn = ROW_NUMBER() OVER (PARTITION BY c.StateCode ORDER BY c.MloNmlsId)
        FROM mcrstg.ClosedLoans c WHERE c.FilingId=@FilingId
        GROUP BY c.StateCode, c.MloNmlsId
    ) x
    CROSS APPLY (VALUES ('ACMLO',   CAST(x.MloNmlsId AS DECIMAL(15,2))),
                        ('ACMLO_2', CAST(x.Amt       AS DECIMAL(15,2))),
                        ('ACMLO_3', CAST(x.Cnt       AS DECIMAL(15,2)))) v(ElementName, NumValue);

    /* Lines of credit (company) */
    INSERT INTO mcr.RepeatingValues (FilingId, ScopeKey, ListName, ItemSeq, ElementName, NumValue, TextValue)
    SELECT @FilingId, 'COMPANY', 'LinesOfCreditItem', x.rn, v.ElementName, v.NumValue, v.TextValue
    FROM (
        SELECT w.ProviderName, w.CreditLimit, w.RemainingCredit,
               rn = ROW_NUMBER() OVER (ORDER BY w.LineId)
        FROM mcrstg.WarehouseLines w WHERE w.FilingId=@FilingId
    ) x
    CROSS APPLY (VALUES ('LOC',   NULL,                                x.ProviderName),
                        ('LOC_1', CAST(x.CreditLimit  AS DECIMAL(15,2)), NULL),
                        ('LOC_2', CAST(x.RemainingCredit AS DECIMAL(15,2)), NULL)
                ) v(ElementName, NumValue, TextValue);

    /* Section III investor detail lists (per state, by ownership category):
       S520 = under MSRs, S530 = subservicing for others, S540 = by others.
       Elements: _1 owner NMLS ID, _2 owner name, _3 pool #, _4 UPB, _5 count */
    INSERT INTO mcr.RepeatingValues (FilingId, ScopeKey, ListName, ItemSeq, ElementName, NumValue, TextValue)
    SELECT @FilingId, x.StateCode, x.ListName, x.rn,
           x.Base + v.Suffix,
           v.NumValue, v.TextValue
    FROM (
        SELECT s.StateCode, i.InvestorNmlsId, i.InvestorName, i.PoolNumber,
               SUM(s.UPB) Upb, COUNT(*) Cnt,
               Base = CASE s.OwnershipType WHEN 'UnderMSR' THEN 'S520'
                          WHEN 'SubservicingForOthers' THEN 'S530' ELSE 'S540' END,
               ListName = CASE s.OwnershipType
                          WHEN 'UnderMSR' THEN 'SectionIIILoansServicedUnderMsrsItem'
                          WHEN 'SubservicingForOthers' THEN 'SectionIIILoansServicedForOthersItem'
                          ELSE 'SectionIIILoansServicedByOthersItem' END,
               rn = ROW_NUMBER() OVER (PARTITION BY s.StateCode, s.OwnershipType ORDER BY i.InvestorNmlsId)
        FROM mcrstg.ServicingPortfolio s
        JOIN mcrstg.Investors i ON i.InvestorCode = s.Investor
        WHERE s.FilingId=@FilingId
          AND s.OwnershipType IN ('UnderMSR','SubservicingForOthers','SubservicedByOthers')
        GROUP BY s.StateCode, s.OwnershipType, i.InvestorNmlsId, i.InvestorName, i.PoolNumber
    ) x
    CROSS APPLY (VALUES ('_1', CAST(x.InvestorNmlsId AS DECIMAL(15,2)), NULL),
                        ('_2', NULL, x.InvestorName),
                        ('_3', NULL, x.PoolNumber),
                        ('_4', CAST(x.Upb AS DECIMAL(15,2)), NULL),
                        ('_5', CAST(x.Cnt AS DECIMAL(15,2)), NULL)
                ) v(Suffix, NumValue, TextValue)
    WHERE NOT (v.Suffix='_3' AND x.PoolNumber IS NULL);

    /* ---- Explanatory notes (demonstration) ---- */
    INSERT INTO mcr.ReportValues (FilingId, ScopeKey, ElementName, TextValue) VALUES
    (@FilingId, 'FC', 'FCNOTE_1', N'Fictional filing generated by the MCR FV7 SQL toolkit.');

    DECLARE @nVals INT, @nRep INT;
    SELECT @nVals = COUNT(*) FROM mcr.ReportValues    WHERE FilingId=@FilingId;
    SELECT @nRep  = COUNT(*) FROM mcr.RepeatingValues WHERE FilingId=@FilingId;
    PRINT 'Loaded filing ' + CAST(@FilingId AS VARCHAR(10)) + ': '
        + CAST(@nVals AS VARCHAR(10)) + ' element values, '
        + CAST(@nRep  AS VARCHAR(10)) + ' repeating-list values.';
END;
GO
PRINT '03 complete: mcr.usp_LoadReportValues created.';
GO
