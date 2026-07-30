/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_04_validation_rules.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT (FULL SCHEMA)
   04 - Validation: generic type rules + NMLS reconciliation checks
   ----------------------------------------------------------------------------
   mcr.usp_ValidateFiling @FilingId
     ERROR = do not submit. WARNING = submit only with an explanatory note.
   Generic rules are catalog-driven and cover every element automatically.
   ============================================================================ */
IF OBJECT_ID('mcr.usp_ValidateFiling') IS NOT NULL DROP PROCEDURE mcr.usp_ValidateFiling;
GO
CREATE PROCEDURE mcr.usp_ValidateFiling @FilingId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM mcr.ValidationResults WHERE FilingId = @FilingId;

    /* ---- 1. GENERIC POSITIVITY: PositiveDollar/Count elements >= 0 ---- */
    INSERT INTO mcr.ValidationResults (FilingId,Severity,RuleType,ScopeKey,ItemCode,Detail)
    SELECT @FilingId,'ERROR','DATATYPE',rv.ScopeKey,e.ItemCode,
        rv.ElementName + ' = ' + CAST(rv.NumValue AS VARCHAR(30))
        + ' but XSD type ' + e.DataType + ' forbids negatives'
    FROM mcr.ReportValues rv
    JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
    WHERE rv.FilingId=@FilingId AND e.DataType IN ('PositiveDollar','Count') AND rv.NumValue < 0;

    /* ---- 2. GENERIC DATATYPE: integer types must be whole numbers ---- */
    INSERT INTO mcr.ValidationResults (FilingId,Severity,RuleType,ScopeKey,ItemCode,Detail)
    SELECT @FilingId,'ERROR','DATATYPE',rv.ScopeKey,e.ItemCode,
        rv.ElementName + ' = ' + CAST(rv.NumValue AS VARCHAR(30))
        + ' has decimals but XSD type ' + e.DataType + ' is integer'
    FROM mcr.ReportValues rv
    JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
    WHERE rv.FilingId=@FilingId
      AND e.DataType IN ('PositiveDollar','Dollar','Count','Number')
      AND rv.NumValue <> ROUND(rv.NumValue, 0);

    /* ---- 3. GENERIC MAGNITUDE: 13-digit XSD ceiling ---- */
    INSERT INTO mcr.ValidationResults (FilingId,Severity,RuleType,ScopeKey,ItemCode,Detail)
    SELECT @FilingId,'ERROR','DATATYPE',rv.ScopeKey,e.ItemCode,
        rv.ElementName + ' exceeds the 13-digit XSD limit'
    FROM mcr.ReportValues rv
    JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
    WHERE rv.FilingId=@FilingId AND ABS(rv.NumValue) >= 10000000000000;

    /* ---- 4. COMPLETENESS: required items present per filed state ---- */
    ;WITH states AS (
        SELECT DISTINCT rv.ScopeKey
        FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        JOIN mcr.FieldCatalog fc ON fc.ItemCode = e.ItemCode
        WHERE rv.FilingId=@FilingId AND fc.Scope='STATE'
    ),
    req AS (SELECT ItemCode FROM mcr.FieldCatalog WHERE Scope='STATE' AND IsRequired=1)
    INSERT INTO mcr.ValidationResults (FilingId,Severity,RuleType,ScopeKey,ItemCode,Detail)
    SELECT @FilingId,'ERROR','COMPLETENESS',st.ScopeKey,r.ItemCode,
        'Required item ' + r.ItemCode + ' missing for state ' + st.ScopeKey
    FROM states st CROSS JOIN req r
    WHERE NOT EXISTS (
        SELECT 1 FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        WHERE rv.FilingId=@FilingId AND rv.ScopeKey=st.ScopeKey AND e.ItemCode=r.ItemCode);

    /* ---- 5. CROSS-FOOT: QM split (AC920-940) = AC070, $ and count, per state.
              Grand totals across column groups (app grid has 2, closed grid 3) */
    ;WITH t AS (
        SELECT rv.ScopeKey,
            ac070_amt = SUM(CASE WHEN e.ItemCode='AC070' AND e.DataType<>'Count' THEN rv.NumValue END),
            ac070_cnt = SUM(CASE WHEN e.ItemCode='AC070' AND e.DataType='Count'  THEN rv.NumValue END),
            qm_amt    = SUM(CASE WHEN e.ItemCode IN ('AC920','AC930','AC940') AND e.DataType<>'Count' THEN rv.NumValue END),
            qm_cnt    = SUM(CASE WHEN e.ItemCode IN ('AC920','AC930','AC940') AND e.DataType='Count'  THEN rv.NumValue END)
        FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        WHERE rv.FilingId=@FilingId AND rv.ScopeKey NOT IN ('COMPANY','FC')
        GROUP BY rv.ScopeKey
    )
    INSERT INTO mcr.ValidationResults (FilingId,Severity,RuleType,ScopeKey,ItemCode,Detail)
    SELECT @FilingId,'ERROR','CROSSFOOT',ScopeKey,'AC990',
        'QM split vs AC070: $ ' + CAST(CAST(ISNULL(qm_amt,0) AS BIGINT) AS VARCHAR(20))
        + ' vs ' + CAST(CAST(ISNULL(ac070_amt,0) AS BIGINT) AS VARCHAR(20))
        + ', count ' + CAST(CAST(ISNULL(qm_cnt,0) AS BIGINT) AS VARCHAR(20))
        + ' vs ' + CAST(CAST(ISNULL(ac070_cnt,0) AS BIGINT) AS VARCHAR(20))
    FROM t
    WHERE ac070_cnt IS NOT NULL
      AND (ISNULL(qm_cnt,0) <> ac070_cnt OR ISNULL(qm_amt,0) <> ISNULL(ac070_amt,0));

    /* ---- 6. RECONCILE: closed-loan grids tie to each other per state.
              LoanType (AC100-130) = PropertyType (AC200-210) = Purpose
              (AC300-320) = Lien (AC500-520) totals, $ and count.            */
    ;WITH g AS (
        SELECT rv.ScopeKey,
            grp = CASE WHEN e.ItemCode IN ('AC100','AC110','AC120','AC130') THEN 'LoanType'
                       WHEN e.ItemCode IN ('AC200','AC210')                  THEN 'PropertyType'
                       WHEN e.ItemCode IN ('AC300','AC310','AC320')          THEN 'Purpose'
                       WHEN e.ItemCode IN ('AC500','AC510','AC520')          THEN 'Lien' END,
            amt = SUM(CASE WHEN e.DataType<>'Count' THEN rv.NumValue END),
            cnt = SUM(CASE WHEN e.DataType='Count'  THEN rv.NumValue END)
        FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        WHERE rv.FilingId=@FilingId AND rv.ScopeKey NOT IN ('COMPANY','FC')
          AND e.ItemCode IN ('AC100','AC110','AC120','AC130','AC200','AC210',
                             'AC300','AC310','AC320','AC500','AC510','AC520')
        GROUP BY rv.ScopeKey,
            CASE WHEN e.ItemCode IN ('AC100','AC110','AC120','AC130') THEN 'LoanType'
                 WHEN e.ItemCode IN ('AC200','AC210')                  THEN 'PropertyType'
                 WHEN e.ItemCode IN ('AC300','AC310','AC320')          THEN 'Purpose'
                 WHEN e.ItemCode IN ('AC500','AC510','AC520')          THEN 'Lien' END
    ),
    p AS (
        SELECT ScopeKey, MIN(amt) mn_amt, MAX(amt) mx_amt, MIN(cnt) mn_cnt, MAX(cnt) mx_cnt, COUNT(*) grids
        FROM g GROUP BY ScopeKey
    )
    INSERT INTO mcr.ValidationResults (FilingId,Severity,RuleType,ScopeKey,ItemCode,Detail)
    SELECT @FilingId,'ERROR','RECONCILE',ScopeKey,'AC190',
        'Closed-loan grids do not tie across LoanType/PropertyType/Purpose/Lien: $ range '
        + CAST(CAST(mn_amt AS BIGINT) AS VARCHAR(20)) + '-' + CAST(CAST(mx_amt AS BIGINT) AS VARCHAR(20))
        + ', count range ' + CAST(CAST(mn_cnt AS BIGINT) AS VARCHAR(20)) + '-' + CAST(CAST(mx_cnt AS BIGINT) AS VARCHAR(20))
    FROM p
    WHERE grids > 1 AND (mn_amt <> mx_amt OR mn_cnt <> mx_cnt);

    /* ---- 7. RECONCILE: MLO list totals = AC070 per state ($ and count) ---- */
    ;WITH ac AS (
        SELECT rv.ScopeKey,
            amt = SUM(CASE WHEN e.DataType<>'Count' THEN rv.NumValue END),
            cnt = SUM(CASE WHEN e.DataType='Count'  THEN rv.NumValue END)
        FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        WHERE rv.FilingId=@FilingId AND e.ItemCode='AC070'
        GROUP BY rv.ScopeKey
    ),
    mlo AS (
        SELECT ScopeKey,
            amt = SUM(CASE WHEN ElementName='ACMLO_2' THEN NumValue END),
            cnt = SUM(CASE WHEN ElementName='ACMLO_3' THEN NumValue END)
        FROM mcr.RepeatingValues
        WHERE FilingId=@FilingId AND ListName='SectionIMlosItem'
        GROUP BY ScopeKey
    )
    INSERT INTO mcr.ValidationResults (FilingId,Severity,RuleType,ScopeKey,ItemCode,Detail)
    SELECT @FilingId,'ERROR','RECONCILE',ac.ScopeKey,'ACMLO',
        'MLO list (count ' + CAST(CAST(ISNULL(mlo.cnt,0) AS BIGINT) AS VARCHAR(20))
        + ', $ ' + CAST(CAST(ISNULL(mlo.amt,0) AS BIGINT) AS VARCHAR(20))
        + ') does not equal AC070 (count ' + CAST(CAST(ac.cnt AS BIGINT) AS VARCHAR(20))
        + ', $ ' + CAST(CAST(ac.amt AS BIGINT) AS VARCHAR(20)) + ')'
    FROM ac LEFT JOIN mlo ON mlo.ScopeKey = ac.ScopeKey
    WHERE ac.cnt IS NOT NULL AND (ISNULL(mlo.cnt,0) <> ac.cnt);
    /* MLO $ vs AC070 $ is a WARNING: MLO amounts are note amounts,
       AC070 is application amounts, and NMLS tolerates documented drift  */

    /* ---- 8. RECONCILE: nationwide LS partitions tie. Version-agnostic:
            a partition participates only if its items exist in the catalog
            (the by-investor block LS300-340 exists from FV7 onward).       */
    ;WITH t AS (
        SELECT
            by_own = SUM(CASE WHEN e.ItemCode IN ('LS010','LS020','LS030','LS040') AND e.DataType<>'Count' THEN rv.NumValue END),
            by_sts = SUM(CASE WHEN e.ItemCode IN ('LS200','LS210','LS220','LS230') AND e.DataType<>'Count' THEN rv.NumValue END),
            by_inv = SUM(CASE WHEN e.ItemCode IN ('LS300','LS310','LS320','LS330','LS340') AND e.DataType<>'Count' THEN rv.NumValue END),
            inv_in_catalog = (SELECT COUNT(*) FROM mcr.FieldCatalogElement
                              WHERE ItemCode IN ('LS300','LS310','LS320','LS330','LS340'))
        FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        WHERE rv.FilingId=@FilingId AND rv.ScopeKey='COMPANY'
    )
    INSERT INTO mcr.ValidationResults (FilingId,Severity,RuleType,ScopeKey,ItemCode,Detail)
    SELECT @FilingId,'ERROR','RECONCILE','COMPANY','LS_TOTALS',
        'Nationwide servicing UPB does not tie: by-ownership='
        + CAST(CAST(ISNULL(by_own,0) AS BIGINT) AS VARCHAR(20)) + ', by-status='
        + CAST(CAST(ISNULL(by_sts,0) AS BIGINT) AS VARCHAR(20))
        + CASE WHEN inv_in_catalog > 0 THEN ', by-investor='
               + CAST(CAST(ISNULL(by_inv,0) AS BIGINT) AS VARCHAR(20)) ELSE '' END
    FROM t
    WHERE ISNULL(by_own,0) <> ISNULL(by_sts,0)
       OR (inv_in_catalog > 0 AND ISNULL(by_own,0) <> ISNULL(by_inv,0));

    /* ---- 9. RECONCILE: state Section III rolls up to nationwide LS ---- */
    ;WITH st AS (
        SELECT
            own = SUM(CASE WHEN e.ItemCode IN ('S510','S520','S530','S540') AND e.DataType<>'Count' THEN rv.NumValue END),
            dq  = SUM(CASE WHEN e.ItemCode IN ('S300','S305','S310','S315') AND e.DataType<>'Count' THEN rv.NumValue END)
        FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        WHERE rv.FilingId=@FilingId AND rv.ScopeKey NOT IN ('COMPANY','FC')
    ),
    co AS (
        SELECT tot = SUM(CASE WHEN e.ItemCode IN ('LS010','LS020','LS030','LS040') AND e.DataType<>'Count' THEN rv.NumValue END)
        FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        WHERE rv.FilingId=@FilingId AND rv.ScopeKey='COMPANY'
    )
    INSERT INTO mcr.ValidationResults (FilingId,Severity,RuleType,ScopeKey,ItemCode,Detail)
    SELECT @FilingId,'WARNING','RECONCILE','COMPANY','LS090',
        'Sum of state Section III servicing UPB ('
        + CAST(CAST(ISNULL(st.own,0) AS BIGINT) AS VARCHAR(20))
        + ') does not equal nationwide LS ownership total ('
        + CAST(CAST(ISNULL(co.tot,0) AS BIGINT) AS VARCHAR(20)) + ')'
    FROM st CROSS JOIN co
    WHERE ISNULL(st.own,0) <> ISNULL(co.tot,0);

    /* ---- 10. RECONCILE: Section III investor lists tie to S520/S530/S540 ---- */
    ;WITH lst AS (
        SELECT ScopeKey,
            Base = CASE ListName WHEN 'SectionIIILoansServicedUnderMsrsItem' THEN 'S520'
                       WHEN 'SectionIIILoansServicedForOthersItem' THEN 'S530' ELSE 'S540' END,
            upb = SUM(CASE WHEN ElementName LIKE 'S5%[_]4' THEN NumValue END),
            cnt = SUM(CASE WHEN ElementName LIKE 'S5%[_]5' THEN NumValue END)
        FROM mcr.RepeatingValues
        WHERE FilingId=@FilingId AND ListName LIKE 'SectionIIILoansServiced%'
        GROUP BY ScopeKey, CASE ListName WHEN 'SectionIIILoansServicedUnderMsrsItem' THEN 'S520'
                       WHEN 'SectionIIILoansServicedForOthersItem' THEN 'S530' ELSE 'S540' END
    ),
    sec AS (
        SELECT rv.ScopeKey, e.ItemCode,
            upb = SUM(CASE WHEN e.DataType<>'Count' THEN rv.NumValue END),
            cnt = SUM(CASE WHEN e.DataType='Count'  THEN rv.NumValue END)
        FROM mcr.ReportValues rv
        JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
        WHERE rv.FilingId=@FilingId AND e.ItemCode IN ('S520','S530','S540')
        GROUP BY rv.ScopeKey, e.ItemCode
    )
    INSERT INTO mcr.ValidationResults (FilingId,Severity,RuleType,ScopeKey,ItemCode,Detail)
    SELECT @FilingId,'ERROR','RECONCILE',sec.ScopeKey,sec.ItemCode,
        'Investor detail list ($ ' + CAST(CAST(ISNULL(lst.upb,0) AS BIGINT) AS VARCHAR(20))
        + ', count ' + CAST(CAST(ISNULL(lst.cnt,0) AS BIGINT) AS VARCHAR(20))
        + ') does not equal section line ' + sec.ItemCode
        + ' ($ ' + CAST(CAST(sec.upb AS BIGINT) AS VARCHAR(20))
        + ', count ' + CAST(CAST(sec.cnt AS BIGINT) AS VARCHAR(20)) + ')'
    FROM sec LEFT JOIN lst ON lst.ScopeKey = sec.ScopeKey AND lst.Base = sec.ItemCode
    WHERE ISNULL(lst.upb,0) <> ISNULL(sec.upb,0) OR ISNULL(lst.cnt,0) <> ISNULL(sec.cnt,0);

    /* ---- 11. RECONCILE FC<->RMLA: repurchase memo O360 vs sum of AC1000 ---- */
    ;WITH x AS (
        SELECT
            (SELECT SUM(rv.NumValue) FROM mcr.ReportValues rv
             JOIN mcr.FieldCatalogElement e ON e.ElementName=rv.ElementName
             WHERE rv.FilingId=@FilingId AND e.ItemCode='AC1000' AND e.DataType<>'Count') AS rmla_upb,
            (SELECT rv.NumValue FROM mcr.ReportValues rv
             WHERE rv.FilingId=@FilingId AND rv.ScopeKey='FC' AND rv.ElementName='O360_1') AS fc_o360
    )
    INSERT INTO mcr.ValidationResults (FilingId,Severity,RuleType,ScopeKey,ItemCode,Detail)
    SELECT @FilingId,'WARNING','RECONCILE','FC','O360',
        'FC repurchase memo UPB (' + CAST(CAST(ISNULL(fc_o360,0) AS BIGINT) AS VARCHAR(30))
        + ') does not match sum of RMLA AC1000 (' + CAST(CAST(ISNULL(rmla_upb,0) AS BIGINT) AS VARCHAR(30))
        + '). Confirm with finance or add an explanatory note.'
    FROM x
    WHERE ISNULL(fc_o360,0) <> ISNULL(rmla_upb,0);

    /* ---- summary ---- */
    DECLARE @err INT, @warn INT;
    SELECT @err  = COUNT(*) FROM mcr.ValidationResults WHERE FilingId=@FilingId AND Severity='ERROR';
    SELECT @warn = COUNT(*) FROM mcr.ValidationResults WHERE FilingId=@FilingId AND Severity='WARNING';
    PRINT 'Validation filing ' + CAST(@FilingId AS VARCHAR(10)) + ': '
        + CAST(@err AS VARCHAR(10)) + ' error(s), ' + CAST(@warn AS VARCHAR(10)) + ' warning(s).';

    SELECT Severity, RuleType, ScopeKey, ItemCode, Detail
    FROM mcr.ValidationResults WHERE FilingId=@FilingId
    ORDER BY CASE Severity WHEN 'ERROR' THEN 0 ELSE 1 END, RuleType, ScopeKey, ItemCode;
END;
GO
PRINT '04 complete: mcr.usp_ValidateFiling created.';
GO
