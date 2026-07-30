/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_05_generate_mcr_xml.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT (FULL SCHEMA)
   05 - Generator: emit schema-valid FV7 XML from element-level staging
   ----------------------------------------------------------------------------
   mcr.usp_GenerateMcrXml @FilingId, @BlockOnError = 1, @Xml OUTPUT

   Fully catalog-driven: sections are keyed by mcr.FieldCatalog.SectionPath,
   elements render in XSD document order (ElemOrder), repeating lists come
   from mcr.ListCatalog/mcr.RepeatingValues. Every FV7 section is supported:
     <Mcr>                              (xs:sequence)
       <Fc> ScheduleA/B/C/D/O + ExplanatoryNotes </Fc>
       <Rmla stateCode>  SectionI, MLO list, SectionII, SectionIII,
                         3 investor lists, ExplanatoryNotes </Rmla>  (per state)
       <Rmlag> LOC list, LoansServicedNationwideTotals, Notes </Rmlag>
       <Sssf stateCode> ScheduleA </Sssf>                        (per state)
     </Mcr>
   All XSD content models here are xs:all / xs:sequence-of-one, so section
   order inside parents is flexible; Mcr's top-level sequence order is kept.
   No XML prolog in @Xml (UTF-16/Msg 9402); prepend it at file-write time.
   ============================================================================ */
IF OBJECT_ID('mcr.usp_GenerateMcrXml') IS NOT NULL DROP PROCEDURE mcr.usp_GenerateMcrXml;
GO
CREATE PROCEDURE mcr.usp_GenerateMcrXml
    @FilingId     INT,
    @BlockOnError BIT = 1,
    @Xml          NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @BlockOnError = 1 AND EXISTS (
        SELECT 1 FROM mcr.ValidationResults WHERE FilingId=@FilingId AND Severity='ERROR')
    BEGIN
        SET @Xml = NULL;
        RAISERROR('Filing %d has validation ERROR(s). Fix them or call with @BlockOnError = 0.', 16, 1, @FilingId);
        RETURN;
    END

    DECLARE @Year VARCHAR(4), @Period VARCHAR(10), @Type CHAR(1), @FormVer VARCHAR(5);
    SELECT @Year = CAST([Year] AS VARCHAR(4)), @Period = PeriodType, @Type = FilerType,
           @FormVer = FormVersion
    FROM mcr.Filing WHERE FilingId = @FilingId;
    IF @Year IS NULL BEGIN RAISERROR('Filing %d not found.',16,1,@FilingId); RETURN; END

    /* ---- 1. section inner XML: one row per (ScopeKey, SectionPath) ---- */
    IF OBJECT_ID('tempdb..#sec') IS NOT NULL DROP TABLE #sec;
    SELECT rv.ScopeKey, fc.SectionPath,
        InnerXml = STRING_AGG(CONVERT(NVARCHAR(MAX),
            '<' + e.ElementName + '>'
            + CASE
                WHEN e.DataType = 'Hundredth'
                    THEN CONVERT(VARCHAR(30), CAST(rv.NumValue AS DECIMAL(15,2)))
                WHEN e.DataType IN ('ShortText','ExplanatoryText')
                    THEN REPLACE(REPLACE(REPLACE(REPLACE(rv.TextValue,
                         '&','&amp;'),'<',''),'>',''),'%','')
                ELSE CONVERT(VARCHAR(30), CAST(rv.NumValue AS BIGINT))
              END
            + '</' + e.ElementName + '>'), N'') WITHIN GROUP (ORDER BY e.ElemOrder)
    INTO #sec
    FROM mcr.ReportValues rv
    JOIN mcr.FieldCatalogElement e ON e.ElementName = rv.ElementName
    JOIN mcr.FieldCatalog fc       ON fc.ItemCode   = e.ItemCode
    WHERE rv.FilingId = @FilingId
      AND fc.IsCalculated = 0
      AND (rv.NumValue IS NOT NULL OR rv.TextValue IS NOT NULL)
    GROUP BY rv.ScopeKey, fc.SectionPath;

    /* ---- 2. repeating lists: one row per (ScopeKey, ListName) ---- */
    IF OBJECT_ID('tempdb..#lst') IS NOT NULL DROP TABLE #lst;
    ;WITH itemEls AS (
        SELECT r.ScopeKey, r.ListName, r.ItemSeq,
            ElXml = STRING_AGG(CONVERT(NVARCHAR(MAX),
                '<' + r.ElementName + '>'
                + CASE
                    WHEN lec.DataType = 'ShortText'
                        THEN REPLACE(REPLACE(REPLACE(REPLACE(r.TextValue,
                             '&','&amp;'),'<',''),'>',''),'%','')
                    ELSE CONVERT(VARCHAR(30), CAST(r.NumValue AS BIGINT))
                  END
                + '</' + r.ElementName + '>'), N'') WITHIN GROUP (ORDER BY lec.ElemOrder)
        FROM mcr.RepeatingValues r
        JOIN mcr.ListElementCatalog lec
          ON lec.ListName = r.ListName AND lec.ElementName = r.ElementName
        WHERE r.FilingId = @FilingId
          AND (r.NumValue IS NOT NULL OR r.TextValue IS NOT NULL)
        GROUP BY r.ScopeKey, r.ListName, r.ItemSeq
    )
    SELECT i.ScopeKey, i.ListName,
        ListXml = STRING_AGG(CONVERT(NVARCHAR(MAX),
            '<' + lc.ItemElement + '><ItemId>' + CONVERT(VARCHAR(10), i.ItemSeq) + '</ItemId>'
            + i.ElXml + '</' + lc.ItemElement + '>'), N'') WITHIN GROUP (ORDER BY i.ItemSeq)
    INTO #lst
    FROM itemEls i
    JOIN mcr.ListCatalog lc ON lc.ListName = i.ListName
    GROUP BY i.ScopeKey, i.ListName;

    /* helper wrappers */
    DECLARE @s NVARCHAR(MAX);

    /* ---- 3. <Fc> ---- */
    DECLARE @fc NVARCHAR(MAX) = N'';
    SELECT @s = NULL; SELECT @s = InnerXml FROM #sec WHERE ScopeKey='FC' AND SectionPath='Mcr/Fc/ScheduleASection';
    IF @s IS NOT NULL SET @fc += '<ScheduleASection>'+@s+'</ScheduleASection>';
    SELECT @s = NULL; SELECT @s = InnerXml FROM #sec WHERE ScopeKey='FC' AND SectionPath='Mcr/Fc/ScheduleBSection';
    IF @s IS NOT NULL SET @fc += '<ScheduleBSection>'+@s+'</ScheduleBSection>';
    SELECT @s = NULL; SELECT @s = InnerXml FROM #sec WHERE ScopeKey='FC' AND SectionPath='Mcr/Fc/ScheduleCSection';
    IF @s IS NOT NULL SET @fc += '<ScheduleCSection>'+@s+'</ScheduleCSection>';
    SELECT @s = NULL; SELECT @s = InnerXml FROM #sec WHERE ScopeKey='FC' AND SectionPath='Mcr/Fc/ScheduleDSection';
    IF @s IS NOT NULL SET @fc += '<ScheduleDSection>'+@s+'</ScheduleDSection>';
    SELECT @s = NULL; SELECT @s = InnerXml FROM #sec WHERE ScopeKey='FC' AND SectionPath='Mcr/Fc/ScheduleOSection';
    IF @s IS NOT NULL SET @fc += '<ScheduleOSection>'+@s+'</ScheduleOSection>';
    SELECT @s = NULL; SELECT @s = InnerXml FROM #sec WHERE ScopeKey='FC' AND SectionPath='Mcr/Fc/ExplanatoryNotesSection';
    IF @s IS NOT NULL SET @fc += '<ExplanatoryNotesSection>'+@s+'</ExplanatoryNotesSection>';
    IF LEN(@fc) > 0 SET @fc = '<Fc>'+@fc+'</Fc>';

    /* ---- 4. <Rmla> per state ---- */
    DECLARE @rmla NVARCHAR(MAX) = N'', @block NVARCHAR(MAX), @st VARCHAR(10);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT ScopeKey FROM (
            SELECT ScopeKey FROM #sec WHERE SectionPath LIKE 'Mcr/Rmla/%'
            UNION SELECT ScopeKey FROM #lst WHERE ListName <> 'LinesOfCreditItem'
        ) u ORDER BY ScopeKey;
    OPEN c; FETCH NEXT FROM c INTO @st;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @block = '<Rmla stateCode="'+@st+'">';
        SELECT @s = NULL; SELECT @s = InnerXml FROM #sec WHERE ScopeKey=@st AND SectionPath='Mcr/Rmla/SectionISection';
        IF @s IS NOT NULL SET @block += '<SectionISection>'+@s+'</SectionISection>';
        SELECT @s = NULL; SELECT @s = ListXml FROM #lst WHERE ScopeKey=@st AND ListName='SectionIMlosItem';
        IF @s IS NOT NULL SET @block += '<ListSectionOfSectionIMlosItem><DetailItemList>'+@s+'</DetailItemList></ListSectionOfSectionIMlosItem>';
        SELECT @s = NULL; SELECT @s = InnerXml FROM #sec WHERE ScopeKey=@st AND SectionPath='Mcr/Rmla/SectionIISection';
        IF @s IS NOT NULL SET @block += '<SectionIISection>'+@s+'</SectionIISection>';
        SELECT @s = NULL; SELECT @s = InnerXml FROM #sec WHERE ScopeKey=@st AND SectionPath='Mcr/Rmla/SectionIIISection';
        IF @s IS NOT NULL SET @block += '<SectionIIISection>'+@s+'</SectionIIISection>';
        SELECT @s = NULL; SELECT @s = ListXml FROM #lst WHERE ScopeKey=@st AND ListName='SectionIIILoansServicedUnderMsrsItem';
        IF @s IS NOT NULL SET @block += '<ListSectionOfSectionIIILoansServicedUnderMsrsItem><DetailItemList>'+@s+'</DetailItemList></ListSectionOfSectionIIILoansServicedUnderMsrsItem>';
        SELECT @s = NULL; SELECT @s = ListXml FROM #lst WHERE ScopeKey=@st AND ListName='SectionIIILoansServicedForOthersItem';
        IF @s IS NOT NULL SET @block += '<ListSectionOfSectionIIILoansServicedForOthersItem><DetailItemList>'+@s+'</DetailItemList></ListSectionOfSectionIIILoansServicedForOthersItem>';
        SELECT @s = NULL; SELECT @s = ListXml FROM #lst WHERE ScopeKey=@st AND ListName='SectionIIILoansServicedByOthersItem';
        IF @s IS NOT NULL SET @block += '<ListSectionOfSectionIIILoansServicedByOthersItem><DetailItemList>'+@s+'</DetailItemList></ListSectionOfSectionIIILoansServicedByOthersItem>';
        SELECT @s = NULL; SELECT @s = InnerXml FROM #sec WHERE ScopeKey=@st AND SectionPath='Mcr/Rmla/ExplanatoryNotesSection';
        IF @s IS NOT NULL SET @block += '<ExplanatoryNotesSection>'+@s+'</ExplanatoryNotesSection>';
        SET @block += '</Rmla>';
        SET @rmla += @block;
        FETCH NEXT FROM c INTO @st;
    END
    CLOSE c; DEALLOCATE c;

    /* ---- 5. <Rmlag> ---- */
    DECLARE @rmlag NVARCHAR(MAX) = N'';
    SELECT @s = NULL; SELECT @s = ListXml FROM #lst WHERE ScopeKey='COMPANY' AND ListName='LinesOfCreditItem';
    IF @s IS NOT NULL SET @rmlag += '<ListSectionOfLinesOfCreditItem><DetailItemList>'+@s+'</DetailItemList></ListSectionOfLinesOfCreditItem>';
    SELECT @s = NULL; SELECT @s = InnerXml FROM #sec WHERE ScopeKey='COMPANY' AND SectionPath='Mcr/Rmlag/LoansServicedNationwideTotalsSection';
    IF @s IS NOT NULL SET @rmlag += '<LoansServicedNationwideTotalsSection>'+@s+'</LoansServicedNationwideTotalsSection>';
    SELECT @s = NULL; SELECT @s = InnerXml FROM #sec WHERE ScopeKey='COMPANY' AND SectionPath='Mcr/Rmlag/ExplanatoryNotesSection';
    IF @s IS NOT NULL SET @rmlag += '<ExplanatoryNotesSection>'+@s+'</ExplanatoryNotesSection>';
    IF LEN(@rmlag) > 0 SET @rmlag = '<Rmlag>'+@rmlag+'</Rmlag>';

    /* ---- 6. <Sssf> per state (state-specific supplemental, SF items) ---- */
    DECLARE @sssf NVARCHAR(MAX) = N'';
    DECLARE cs CURSOR LOCAL FAST_FORWARD FOR
        SELECT ScopeKey, InnerXml FROM #sec
        WHERE SectionPath = 'Mcr/Sssf/ScheduleASection' ORDER BY ScopeKey;
    OPEN cs; FETCH NEXT FROM cs INTO @st, @s;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sssf += '<Sssf stateCode="'+@st+'">'
                   + '<ScheduleASection>'+@s+'</ScheduleASection></Sssf>';
        FETCH NEXT FROM cs INTO @st, @s;
    END
    CLOSE cs; DEALLOCATE cs;

    /* ---- 7. assemble in Mcr sequence order: Fc, Rmla(s), Rmlag, Sssf(s) ---- */
    SET @Xml = '<Mcr formVersion="'+@FormVer+'" type="'+@Type+'" year="'+@Year+'" periodType="'+@Period+'">'
             + @fc + @rmla + @rmlag + @sssf
             + '</Mcr>';
END;
GO
PRINT '05 complete: mcr.usp_GenerateMcrXml created.';
GO
