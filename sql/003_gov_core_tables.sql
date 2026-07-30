/* ============================================================
   MortgageGovernance | Phase 2 | Script 003
   Governance core metadata: 30 tables in gov, plus the
   deferred FK from audit.ReconciliationControl to gov.Party.
   Standard audit columns on every table:
   LoadBatchId (soft ref), RowHash, CreatedDateUtc,
   ModifiedDateUtc.
   Idempotent: safe to re-run.
   ============================================================ */
USE MortgageGovernance;
GO

/* ============ 1. gov.Party ============ */
IF OBJECT_ID(N'gov.Party', N'U') IS NULL
BEGIN
CREATE TABLE gov.Party
(
    PartyId         INT IDENTITY(1,1) NOT NULL,
    PartyName       NVARCHAR(200) NOT NULL,
    PartyTypeCode   VARCHAR(20)   NOT NULL,
    JobTitle        NVARCHAR(200) NULL,
    Department      NVARCHAR(100) NULL,
    Email           NVARCHAR(200) NULL,
    ActiveFlag      BIT NOT NULL
        CONSTRAINT DF_Party_ActiveFlag DEFAULT 1,
    LoadBatchId     INT NULL,
    RowHash         VARBINARY(32) NULL,
    CreatedDateUtc  DATETIME2(3) NOT NULL
        CONSTRAINT DF_Party_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_Party PRIMARY KEY CLUSTERED (PartyId),
    CONSTRAINT UQ_Party_PartyName_PartyTypeCode
        UNIQUE (PartyName, PartyTypeCode),
    CONSTRAINT CK_Party_PartyTypeCode CHECK
        (PartyTypeCode IN ('PERSON','TEAM','SYSTEM'))
);
END
GO

/* ============ 2. gov.GovernanceRole ============ */
IF OBJECT_ID(N'gov.GovernanceRole', N'U') IS NULL
BEGIN
CREATE TABLE gov.GovernanceRole
(
    GovernanceRoleId INT IDENTITY(1,1) NOT NULL,
    RoleCode         VARCHAR(30)   NOT NULL,
    RoleName         NVARCHAR(100) NOT NULL,
    RoleDescription  NVARCHAR(500) NULL,
    LoadBatchId      INT NULL,
    RowHash          VARBINARY(32) NULL,
    CreatedDateUtc   DATETIME2(3) NOT NULL
        CONSTRAINT DF_GovernanceRole_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc  DATETIME2(3) NULL,
    CONSTRAINT PK_GovernanceRole
        PRIMARY KEY CLUSTERED (GovernanceRoleId),
    CONSTRAINT UQ_GovernanceRole_RoleCode UNIQUE (RoleCode)
);
END
GO

/* ============ 3. gov.RoleAssignment (RACI) ============
   EntityId is a soft reference resolved by EntityTypeCode.
   EntityReference covers non-tabular scopes (e.g. DOMAIN). */
IF OBJECT_ID(N'gov.RoleAssignment', N'U') IS NULL
BEGIN
CREATE TABLE gov.RoleAssignment
(
    RoleAssignmentId  INT IDENTITY(1,1) NOT NULL,
    EntityTypeCode    VARCHAR(40)   NOT NULL,
    EntityId          INT           NULL,
    EntityReference   NVARCHAR(300) NULL,
    GovernanceRoleId  INT           NOT NULL,
    PartyId           INT           NOT NULL,
    RaciCode          CHAR(1)       NULL,
    EffectiveFromDate DATE          NOT NULL
        CONSTRAINT DF_RoleAssignment_EffectiveFromDate
        DEFAULT CAST(GETDATE() AS DATE),
    EffectiveToDate   DATE          NULL,
    LoadBatchId       INT NULL,
    RowHash           VARBINARY(32) NULL,
    CreatedDateUtc    DATETIME2(3) NOT NULL
        CONSTRAINT DF_RoleAssignment_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc   DATETIME2(3) NULL,
    CONSTRAINT PK_RoleAssignment
        PRIMARY KEY CLUSTERED (RoleAssignmentId),
    CONSTRAINT FK_RoleAssignment_GovernanceRole
        FOREIGN KEY (GovernanceRoleId)
        REFERENCES gov.GovernanceRole (GovernanceRoleId),
    CONSTRAINT FK_RoleAssignment_Party
        FOREIGN KEY (PartyId) REFERENCES gov.Party (PartyId),
    CONSTRAINT CK_RoleAssignment_EntityTypeCode CHECK
        (EntityTypeCode IN ('DATA_ELEMENT','METRIC',
         'SOURCE_SYSTEM','SOURCE_OBJECT','REPORT','DQ_RULE',
         'RECON_CONTROL','REGULATORY_REPORT','DOMAIN')),
    CONSTRAINT CK_RoleAssignment_RaciCode CHECK
        (RaciCode IS NULL OR RaciCode IN ('R','A','C','I')),
    CONSTRAINT CK_RoleAssignment_Entity CHECK
        (EntityId IS NOT NULL OR EntityReference IS NOT NULL)
);
CREATE NONCLUSTERED INDEX IX_RoleAssignment_Entity
    ON gov.RoleAssignment (EntityTypeCode, EntityId);
END
GO

/* ============ 4. gov.SourceSystem ============ */
IF OBJECT_ID(N'gov.SourceSystem', N'U') IS NULL
BEGIN
CREATE TABLE gov.SourceSystem
(
    SourceSystemId   INT IDENTITY(1,1) NOT NULL,
    SourceSystemCode VARCHAR(10)   NOT NULL,
    SourceSystemName NVARCHAR(100) NOT NULL,
    SystemDescription NVARCHAR(500) NULL,
    SystemTypeCode   VARCHAR(30)   NOT NULL,
    DomainArea       NVARCHAR(100) NULL,
    AuthoritativeScopeSummary NVARCHAR(500) NULL,
    ActiveFlag       BIT NOT NULL
        CONSTRAINT DF_SourceSystem_ActiveFlag DEFAULT 1,
    LoadBatchId      INT NULL,
    RowHash          VARBINARY(32) NULL,
    CreatedDateUtc   DATETIME2(3) NOT NULL
        CONSTRAINT DF_SourceSystem_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc  DATETIME2(3) NULL,
    CONSTRAINT PK_SourceSystem
        PRIMARY KEY CLUSTERED (SourceSystemId),
    CONSTRAINT UQ_SourceSystem_SourceSystemCode
        UNIQUE (SourceSystemCode),
    CONSTRAINT CK_SourceSystem_SystemTypeCode CHECK
        (SystemTypeCode IN ('BOARDING','SERVICING_CORE',
         'PAYMENT','DEFAULT_MGMT','INVESTOR_RPT','VALUATION',
         'CRM','LOS','PPE','LICENSING','GOVERNANCE','OTHER'))
);
END
GO

/* ============ 5. gov.SourceObject ============
   GrainStatement is mandatory: the grain of every registered
   object is governed metadata, not tribal knowledge. */
IF OBJECT_ID(N'gov.SourceObject', N'U') IS NULL
BEGIN
CREATE TABLE gov.SourceObject
(
    SourceObjectId    INT IDENTITY(1,1) NOT NULL,
    SourceSystemId    INT           NOT NULL,
    SchemaName        VARCHAR(50)   NOT NULL,
    ObjectName        NVARCHAR(200) NOT NULL,
    ObjectTypeCode    VARCHAR(20)   NOT NULL,
    GrainStatement    NVARCHAR(500) NOT NULL,
    ObjectDescription NVARCHAR(500) NULL,
    LoadBatchId       INT NULL,
    RowHash           VARBINARY(32) NULL,
    CreatedDateUtc    DATETIME2(3) NOT NULL
        CONSTRAINT DF_SourceObject_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc   DATETIME2(3) NULL,
    CONSTRAINT PK_SourceObject
        PRIMARY KEY CLUSTERED (SourceObjectId),
    CONSTRAINT FK_SourceObject_SourceSystem
        FOREIGN KEY (SourceSystemId)
        REFERENCES gov.SourceSystem (SourceSystemId),
    CONSTRAINT UQ_SourceObject_System_Schema_Object
        UNIQUE (SourceSystemId, SchemaName, ObjectName),
    CONSTRAINT CK_SourceObject_ObjectTypeCode CHECK
        (ObjectTypeCode IN ('TABLE','VIEW','FEED','FILE'))
);
END
GO

/* ============ 6. gov.SourceField ============ */
IF OBJECT_ID(N'gov.SourceField', N'U') IS NULL
BEGIN
CREATE TABLE gov.SourceField
(
    SourceFieldId    INT IDENTITY(1,1) NOT NULL,
    SourceObjectId   INT           NOT NULL,
    FieldName        NVARCHAR(200) NOT NULL,
    OrdinalPosition  INT           NULL,
    DataTypeName     VARCHAR(100)  NULL,
    IsNullable       BIT           NULL,
    FieldDescription NVARCHAR(500) NULL,
    SampleValue      NVARCHAR(200) NULL,
    LoadBatchId      INT NULL,
    RowHash          VARBINARY(32) NULL,
    CreatedDateUtc   DATETIME2(3) NOT NULL
        CONSTRAINT DF_SourceField_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc  DATETIME2(3) NULL,
    CONSTRAINT PK_SourceField
        PRIMARY KEY CLUSTERED (SourceFieldId),
    CONSTRAINT FK_SourceField_SourceObject
        FOREIGN KEY (SourceObjectId)
        REFERENCES gov.SourceObject (SourceObjectId),
    CONSTRAINT UQ_SourceField_Object_Field
        UNIQUE (SourceObjectId, FieldName)
);
END
GO

/* ============ 7. gov.BusinessTerm ============ */
IF OBJECT_ID(N'gov.BusinessTerm', N'U') IS NULL
BEGIN
CREATE TABLE gov.BusinessTerm
(
    BusinessTermId     INT IDENTITY(1,1) NOT NULL,
    TermName           NVARCHAR(200)  NOT NULL,
    TermDefinition     NVARCHAR(2000) NOT NULL,
    TermAbbreviation   NVARCHAR(50)   NULL,
    Synonyms           NVARCHAR(500)  NULL,
    DomainArea         NVARCHAR(100)  NULL,
    ApprovalStatusCode VARCHAR(20)    NOT NULL
        CONSTRAINT DF_BusinessTerm_ApprovalStatusCode
        DEFAULT 'DRAFT',
    ApprovedByPartyId  INT            NULL,
    ApprovedDate       DATE           NULL,
    SourceOfDefinition NVARCHAR(200)  NULL,
    LoadBatchId        INT NULL,
    RowHash            VARBINARY(32) NULL,
    CreatedDateUtc     DATETIME2(3) NOT NULL
        CONSTRAINT DF_BusinessTerm_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc    DATETIME2(3) NULL,
    CONSTRAINT PK_BusinessTerm
        PRIMARY KEY CLUSTERED (BusinessTermId),
    CONSTRAINT UQ_BusinessTerm_TermName UNIQUE (TermName),
    CONSTRAINT FK_BusinessTerm_Party_ApprovedBy
        FOREIGN KEY (ApprovedByPartyId)
        REFERENCES gov.Party (PartyId),
    CONSTRAINT CK_BusinessTerm_ApprovalStatusCode CHECK
        (ApprovalStatusCode IN
         ('DRAFT','PROPOSED','APPROVED','DEPRECATED'))
);
END
GO

/* ============ 8. gov.DataElement ============ */
IF OBJECT_ID(N'gov.DataElement', N'U') IS NULL
BEGIN
CREATE TABLE gov.DataElement
(
    DataElementId       INT IDENTITY(1,1) NOT NULL,
    DataElementCode     VARCHAR(60)    NOT NULL,
    DataElementName     NVARCHAR(200)  NOT NULL,
    BusinessTermId      INT            NULL,
    BusinessDefinition  NVARCHAR(2000) NOT NULL,
    TechnicalDefinition NVARCHAR(2000) NULL,
    DomainArea          NVARCHAR(100)  NULL,
    DataTypeCategory    VARCHAR(30)    NULL,
    ClassificationLevelCode VARCHAR(20) NOT NULL
        CONSTRAINT DF_DataElement_ClassificationLevelCode
        DEFAULT 'INTERNAL',
    PiiTypeCode         VARCHAR(30)    NULL,
    CdeFlag             BIT NOT NULL
        CONSTRAINT DF_DataElement_CdeFlag DEFAULT 0,
    ActiveFlag          BIT NOT NULL
        CONSTRAINT DF_DataElement_ActiveFlag DEFAULT 1,
    LoadBatchId         INT NULL,
    RowHash             VARBINARY(32) NULL,
    CreatedDateUtc      DATETIME2(3) NOT NULL
        CONSTRAINT DF_DataElement_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc     DATETIME2(3) NULL,
    CONSTRAINT PK_DataElement
        PRIMARY KEY CLUSTERED (DataElementId),
    CONSTRAINT UQ_DataElement_DataElementCode
        UNIQUE (DataElementCode),
    CONSTRAINT FK_DataElement_BusinessTerm
        FOREIGN KEY (BusinessTermId)
        REFERENCES gov.BusinessTerm (BusinessTermId),
    CONSTRAINT CK_DataElement_DataTypeCategory CHECK
        (DataTypeCategory IS NULL OR DataTypeCategory IN
         ('AMOUNT','RATE','DATE','CODE','COUNT','TEXT',
          'FLAG','IDENTIFIER')),
    CONSTRAINT CK_DataElement_ClassificationLevelCode CHECK
        (ClassificationLevelCode IN
         ('PUBLIC','INTERNAL','CONFIDENTIAL','RESTRICTED')),
    CONSTRAINT CK_DataElement_PiiTypeCode CHECK
        (PiiTypeCode IS NULL OR PiiTypeCode IN
         ('DIRECT_IDENTIFIER','QUASI_IDENTIFIER',
          'SENSITIVE_FINANCIAL','NONE'))
);
END
GO

/* ============ 9. gov.CriticalDataElement ============ */
IF OBJECT_ID(N'gov.CriticalDataElement', N'U') IS NULL
BEGIN
CREATE TABLE gov.CriticalDataElement
(
    CriticalDataElementId INT IDENTITY(1,1) NOT NULL,
    DataElementId       INT            NOT NULL,
    CdeRationale        NVARCHAR(1000) NOT NULL,
    ApprovedByPartyId   INT            NULL,
    ApprovedDate        DATE           NULL,
    ReviewFrequencyCode VARCHAR(20)    NOT NULL
        CONSTRAINT DF_CriticalDataElement_ReviewFrequencyCode
        DEFAULT 'ANNUAL',
    NextReviewDate      DATE           NULL,
    LoadBatchId         INT NULL,
    RowHash             VARBINARY(32) NULL,
    CreatedDateUtc      DATETIME2(3) NOT NULL
        CONSTRAINT DF_CriticalDataElement_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc     DATETIME2(3) NULL,
    CONSTRAINT PK_CriticalDataElement
        PRIMARY KEY CLUSTERED (CriticalDataElementId),
    CONSTRAINT UQ_CriticalDataElement_DataElementId
        UNIQUE (DataElementId),
    CONSTRAINT FK_CriticalDataElement_DataElement
        FOREIGN KEY (DataElementId)
        REFERENCES gov.DataElement (DataElementId),
    CONSTRAINT FK_CriticalDataElement_Party_ApprovedBy
        FOREIGN KEY (ApprovedByPartyId)
        REFERENCES gov.Party (PartyId),
    CONSTRAINT CK_CriticalDataElement_ReviewFrequencyCode CHECK
        (ReviewFrequencyCode IN
         ('ANNUAL','SEMIANNUAL','QUARTERLY'))
);
END
GO

/* ============ 10. gov.DataElementBinding ============
   Physical binding of a logical element at each layer. */
IF OBJECT_ID(N'gov.DataElementBinding', N'U') IS NULL
BEGIN
CREATE TABLE gov.DataElementBinding
(
    DataElementBindingId INT IDENTITY(1,1) NOT NULL,
    DataElementId  INT           NOT NULL,
    LayerCode      VARCHAR(20)   NOT NULL,
    SchemaName     VARCHAR(50)   NULL,
    ObjectName     NVARCHAR(200) NOT NULL,
    ColumnName     NVARCHAR(200) NOT NULL,
    SourceSystemId INT           NULL,
    Notes          NVARCHAR(500) NULL,
    LoadBatchId    INT NULL,
    RowHash        VARBINARY(32) NULL,
    CreatedDateUtc DATETIME2(3) NOT NULL
        CONSTRAINT DF_DataElementBinding_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_DataElementBinding
        PRIMARY KEY CLUSTERED (DataElementBindingId),
    CONSTRAINT FK_DataElementBinding_DataElement
        FOREIGN KEY (DataElementId)
        REFERENCES gov.DataElement (DataElementId),
    CONSTRAINT FK_DataElementBinding_SourceSystem
        FOREIGN KEY (SourceSystemId)
        REFERENCES gov.SourceSystem (SourceSystemId),
    CONSTRAINT UQ_DataElementBinding_Element_Layer_Column
        UNIQUE (DataElementId, LayerCode, ObjectName,
                ColumnName),
    CONSTRAINT CK_DataElementBinding_LayerCode CHECK
        (LayerCode IN
         ('SRC','STG','DW','PBI_VIEW','SEMANTIC'))
);
CREATE NONCLUSTERED INDEX IX_DataElementBinding_DataElementId
    ON gov.DataElementBinding (DataElementId);
END
GO

/* ============ 11. gov.AuthoritativeSource ============
   Attribute-level authority incl. the boarding handoff. */
IF OBJECT_ID(N'gov.AuthoritativeSource', N'U') IS NULL
BEGIN
CREATE TABLE gov.AuthoritativeSource
(
    AuthoritativeSourceId INT IDENTITY(1,1) NOT NULL,
    DataElementId      INT           NOT NULL,
    SourceSystemId     INT           NOT NULL,
    AuthorityScopeCode VARCHAR(30)   NOT NULL,
    EffectiveFromDate  DATE          NOT NULL
        CONSTRAINT DF_AuthoritativeSource_EffectiveFromDate
        DEFAULT CAST(GETDATE() AS DATE),
    EffectiveToDate    DATE          NULL,
    HandoffRule        NVARCHAR(500) NULL,
    LoadBatchId        INT NULL,
    RowHash            VARBINARY(32) NULL,
    CreatedDateUtc     DATETIME2(3) NOT NULL
        CONSTRAINT DF_AuthoritativeSource_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc    DATETIME2(3) NULL,
    CONSTRAINT PK_AuthoritativeSource
        PRIMARY KEY CLUSTERED (AuthoritativeSourceId),
    CONSTRAINT FK_AuthoritativeSource_DataElement
        FOREIGN KEY (DataElementId)
        REFERENCES gov.DataElement (DataElementId),
    CONSTRAINT FK_AuthoritativeSource_SourceSystem
        FOREIGN KEY (SourceSystemId)
        REFERENCES gov.SourceSystem (SourceSystemId),
    CONSTRAINT UQ_AuthoritativeSource_Element_System_Scope
        UNIQUE (DataElementId, SourceSystemId,
                AuthorityScopeCode),
    CONSTRAINT CK_AuthoritativeSource_AuthorityScopeCode CHECK
        (AuthorityScopeCode IN ('FULL','AT_BOARDING',
         'POST_BOARDING','ORIGINATION','SERVICING'))
);
END
GO

/* ============ 12. gov.DerivationRule ============
   Business logic registered once; bindings live in
   gov.SourceToTargetMap. Source changes never touch rules. */
IF OBJECT_ID(N'gov.DerivationRule', N'U') IS NULL
BEGIN
CREATE TABLE gov.DerivationRule
(
    DerivationRuleId    INT IDENTITY(1,1) NOT NULL,
    RuleCode            VARCHAR(30)    NOT NULL,
    RuleName            NVARCHAR(200)  NOT NULL,
    BusinessDescription NVARCHAR(1000) NULL,
    CanonicalLogic      NVARCHAR(MAX)  NOT NULL,
    ImplementingObjectName NVARCHAR(200) NULL,
    ImplementationTypeCode VARCHAR(20)  NOT NULL,
    RuleVersion         INT NOT NULL
        CONSTRAINT DF_DerivationRule_RuleVersion DEFAULT 1,
    EffectiveFromDate   DATE NOT NULL
        CONSTRAINT DF_DerivationRule_EffectiveFromDate
        DEFAULT CAST(GETDATE() AS DATE),
    ActiveFlag          BIT NOT NULL
        CONSTRAINT DF_DerivationRule_ActiveFlag DEFAULT 1,
    LoadBatchId         INT NULL,
    RowHash             VARBINARY(32) NULL,
    CreatedDateUtc      DATETIME2(3) NOT NULL
        CONSTRAINT DF_DerivationRule_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc     DATETIME2(3) NULL,
    CONSTRAINT PK_DerivationRule
        PRIMARY KEY CLUSTERED (DerivationRuleId),
    CONSTRAINT UQ_DerivationRule_RuleCode UNIQUE (RuleCode),
    CONSTRAINT CK_DerivationRule_ImplementationTypeCode CHECK
        (ImplementationTypeCode IN ('INLINE_TVF','SCALAR_UDF',
         'PROC_SET_BASED','LOOKUP_JOIN','VIEW'))
);
END
GO

/* ============ 13. gov.DerivationRuleInput ============
   Logical inputs by staging-contract column name.
   DataElementId is bound in Phase 7. */
IF OBJECT_ID(N'gov.DerivationRuleInput', N'U') IS NULL
BEGIN
CREATE TABLE gov.DerivationRuleInput
(
    DerivationRuleInputId INT IDENTITY(1,1) NOT NULL,
    DerivationRuleId INT           NOT NULL,
    DataElementId    INT           NULL,
    InputReference   NVARCHAR(200) NOT NULL,
    InputRoleNote    NVARCHAR(300) NULL,
    LoadBatchId      INT NULL,
    RowHash          VARBINARY(32) NULL,
    CreatedDateUtc   DATETIME2(3) NOT NULL
        CONSTRAINT DF_DerivationRuleInput_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc  DATETIME2(3) NULL,
    CONSTRAINT PK_DerivationRuleInput
        PRIMARY KEY CLUSTERED (DerivationRuleInputId),
    CONSTRAINT FK_DerivationRuleInput_DerivationRule
        FOREIGN KEY (DerivationRuleId)
        REFERENCES gov.DerivationRule (DerivationRuleId),
    CONSTRAINT FK_DerivationRuleInput_DataElement
        FOREIGN KEY (DataElementId)
        REFERENCES gov.DataElement (DataElementId),
    CONSTRAINT UQ_DerivationRuleInput_Rule_Input
        UNIQUE (DerivationRuleId, InputReference)
);
END
GO

/* ============ 14. gov.SourceToTargetMap ============
   Field bindings by version. Replacing a source system is a
   mapping update here, never a logic rewrite. */
IF OBJECT_ID(N'gov.SourceToTargetMap', N'U') IS NULL
BEGIN
CREATE TABLE gov.SourceToTargetMap
(
    SourceToTargetMapId INT IDENTITY(1,1) NOT NULL,
    TargetSchemaName  VARCHAR(50)   NOT NULL,
    TargetObjectName  NVARCHAR(200) NOT NULL,
    TargetColumnName  NVARCHAR(200) NOT NULL,
    SourceSystemId    INT           NULL,
    SourceObjectName  NVARCHAR(200) NULL,
    SourceColumnName  NVARCHAR(200) NULL,
    TransformTypeCode VARCHAR(20)   NOT NULL,
    DerivationRuleId  INT           NULL,
    ConstantValue     NVARCHAR(200) NULL,
    ActiveFromDate    DATE NOT NULL
        CONSTRAINT DF_SourceToTargetMap_ActiveFromDate
        DEFAULT CAST(GETDATE() AS DATE),
    ActiveToDate      DATE          NULL,
    MappingNotes      NVARCHAR(500) NULL,
    LoadBatchId       INT NULL,
    RowHash           VARBINARY(32) NULL,
    CreatedDateUtc    DATETIME2(3) NOT NULL
        CONSTRAINT DF_SourceToTargetMap_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc   DATETIME2(3) NULL,
    CONSTRAINT PK_SourceToTargetMap
        PRIMARY KEY CLUSTERED (SourceToTargetMapId),
    CONSTRAINT FK_SourceToTargetMap_SourceSystem
        FOREIGN KEY (SourceSystemId)
        REFERENCES gov.SourceSystem (SourceSystemId),
    CONSTRAINT FK_SourceToTargetMap_DerivationRule
        FOREIGN KEY (DerivationRuleId)
        REFERENCES gov.DerivationRule (DerivationRuleId),
    CONSTRAINT UQ_SourceToTargetMap_Target_System_From
        UNIQUE (TargetSchemaName, TargetObjectName,
                TargetColumnName, SourceSystemId,
                ActiveFromDate),
    CONSTRAINT CK_SourceToTargetMap_TransformTypeCode CHECK
        (TransformTypeCode IN
         ('DIRECT','DERIVED','LOOKUP','CONSTANT')),
    CONSTRAINT CK_SourceToTargetMap_DerivedNeedsRule CHECK
        (TransformTypeCode <> 'DERIVED'
         OR DerivationRuleId IS NOT NULL),
    CONSTRAINT CK_SourceToTargetMap_ConstantNeedsValue CHECK
        (TransformTypeCode <> 'CONSTANT'
         OR ConstantValue IS NOT NULL)
);
CREATE NONCLUSTERED INDEX IX_SourceToTargetMap_Target
    ON gov.SourceToTargetMap
       (TargetSchemaName, TargetObjectName, TargetColumnName);
END
GO

/* ============ 15. gov.MetricDefinition ============
   The 220-metric enterprise catalog (loaded in Phase 3). */
IF OBJECT_ID(N'gov.MetricDefinition', N'U') IS NULL
BEGIN
CREATE TABLE gov.MetricDefinition
(
    MetricDefinitionId INT IDENTITY(1,1) NOT NULL,
    MetricCode         VARCHAR(40)    NOT NULL,
    MetricName         NVARCHAR(200)  NOT NULL,
    BusinessDefinition NVARCHAR(2000) NOT NULL,
    MetricCategory     NVARCHAR(100)  NULL,
    BusinessDomain     NVARCHAR(100)  NULL,
    StakeholderTeam    NVARCHAR(200)  NULL,
    WhyItMatters       NVARCHAR(1000) NULL,
    ExampleUsage       NVARCHAR(500)  NULL,
    NumeratorLogic     NVARCHAR(2000) NULL,
    DenominatorLogic   NVARCHAR(2000) NULL,
    CalculationLogic   NVARCHAR(2000) NULL,
    AggregationTypeCode VARCHAR(30)   NULL,
    RequiredGrain      NVARCHAR(200)  NULL,
    ReportingTimeBasisCode VARCHAR(30) NULL,
    PopulationLogic    NVARCHAR(2000) NULL,
    InclusionRules     NVARCHAR(2000) NULL,
    ExclusionRules     NVARCHAR(2000) NULL,
    NullHandling       NVARCHAR(500)  NULL,
    StatusHandling     NVARCHAR(500)  NULL,
    EffectiveDateLogic NVARCHAR(500)  NULL,
    AuthoritativeSourceSummary NVARCHAR(300) NULL,
    FormatString       VARCHAR(50)    NULL,
    DirectionCode      VARCHAR(10)    NULL,
    ProjectAssignmentCode VARCHAR(10) NOT NULL,
    CoverageStatusCode VARCHAR(20)    NOT NULL,
    ImplementationStatusCode VARCHAR(20) NOT NULL
        CONSTRAINT DF_MetricDefinition_ImplementationStatus
        DEFAULT 'NOT_STARTED',
    RegulatoryRelevanceFlag BIT NOT NULL
        CONSTRAINT DF_MetricDefinition_RegRelevanceFlag
        DEFAULT 0,
    McrRelevanceFlag   BIT NOT NULL
        CONSTRAINT DF_MetricDefinition_McrRelevanceFlag
        DEFAULT 0,
    MismoAlignmentNote NVARCHAR(300)  NULL,
    LoadBatchId        INT NULL,
    RowHash            VARBINARY(32) NULL,
    CreatedDateUtc     DATETIME2(3) NOT NULL
        CONSTRAINT DF_MetricDefinition_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc    DATETIME2(3) NULL,
    CONSTRAINT PK_MetricDefinition
        PRIMARY KEY CLUSTERED (MetricDefinitionId),
    CONSTRAINT UQ_MetricDefinition_MetricCode
        UNIQUE (MetricCode),
    CONSTRAINT UQ_MetricDefinition_MetricName
        UNIQUE (MetricName),
    CONSTRAINT CK_MetricDefinition_AggregationTypeCode CHECK
        (AggregationTypeCode IS NULL OR AggregationTypeCode IN
         ('SUM','COUNT','RATIO','AVERAGE','WEIGHTED_AVG',
          'DURATION','SNAPSHOT','COMPOSITE')),
    CONSTRAINT CK_MetricDefinition_ReportingTimeBasisCode
        CHECK (ReportingTimeBasisCode IS NULL
         OR ReportingTimeBasisCode IN ('POINT_IN_TIME',
            'PERIOD_ACTIVITY','ROLLING_12M','COHORT')),
    CONSTRAINT CK_MetricDefinition_DirectionCode CHECK
        (DirectionCode IS NULL
         OR DirectionCode IN ('HIGHER','LOWER','NEUTRAL')),
    CONSTRAINT CK_MetricDefinition_ProjectAssignmentCode CHECK
        (ProjectAssignmentCode IN
         ('P1','P1E1','P2','P3','FUTURE')),
    CONSTRAINT CK_MetricDefinition_CoverageStatusCode CHECK
        (CoverageStatusCode IN
         ('SUPPORTED','PLANNED','DEFERRED')),
    CONSTRAINT CK_MetricDefinition_ImplementationStatusCode
        CHECK (ImplementationStatusCode IN
         ('NOT_STARTED','SPEC_READY','BUILT','CERTIFIED'))
);
END
GO

/* ============ 16. gov.MetricDependency ============ */
IF OBJECT_ID(N'gov.MetricDependency', N'U') IS NULL
BEGIN
CREATE TABLE gov.MetricDependency
(
    MetricDependencyId INT IDENTITY(1,1) NOT NULL,
    MetricDefinitionId INT           NOT NULL,
    DependencyTypeCode VARCHAR(30)   NOT NULL,
    DependencyEntityId INT           NULL,
    DependencyReference NVARCHAR(300) NULL,
    RoleInMetricCode   VARCHAR(30)   NULL,
    Notes              NVARCHAR(500) NULL,
    LoadBatchId        INT NULL,
    RowHash            VARBINARY(32) NULL,
    CreatedDateUtc     DATETIME2(3) NOT NULL
        CONSTRAINT DF_MetricDependency_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc    DATETIME2(3) NULL,
    CONSTRAINT PK_MetricDependency
        PRIMARY KEY CLUSTERED (MetricDependencyId),
    CONSTRAINT FK_MetricDependency_MetricDefinition
        FOREIGN KEY (MetricDefinitionId)
        REFERENCES gov.MetricDefinition (MetricDefinitionId),
    CONSTRAINT CK_MetricDependency_DependencyTypeCode CHECK
        (DependencyTypeCode IN ('DATA_ELEMENT',
         'DERIVATION_RULE','DQ_RULE','SOURCE_OBJECT',
         'WAREHOUSE_OBJECT','SEMANTIC_COLUMN','DAX_MEASURE',
         'METRIC','REGULATORY_ITEM')),
    CONSTRAINT CK_MetricDependency_RoleInMetricCode CHECK
        (RoleInMetricCode IS NULL OR RoleInMetricCode IN
         ('NUMERATOR','DENOMINATOR','FILTER','POPULATION',
          'INPUT')),
    CONSTRAINT CK_MetricDependency_Target CHECK
        (DependencyEntityId IS NOT NULL
         OR DependencyReference IS NOT NULL)
);
CREATE NONCLUSTERED INDEX IX_MetricDependency_Metric
    ON gov.MetricDependency (MetricDefinitionId);
END
GO

/* ============ 17. gov.MismoMapping ============
   MISMO Reference Model v3.6.1 is the recorded project
   reference version (Candidate Recommendation, 2025-05-27).
   MismoVersion is per row so v3.6.2 can be adopted later. */
IF OBJECT_ID(N'gov.MismoMapping', N'U') IS NULL
BEGIN
CREATE TABLE gov.MismoMapping
(
    MismoMappingId    INT IDENTITY(1,1) NOT NULL,
    DataElementId     INT            NOT NULL,
    PhysicalColumnReference NVARCHAR(300) NULL,
    SourceSystemId    INT            NULL,
    MismoDataPointName NVARCHAR(200) NOT NULL,
    MismoLddTerm      NVARCHAR(300)  NULL,
    MismoPathOrIdentifier NVARCHAR(500) NULL,
    MismoVersion      VARCHAR(20)    NOT NULL
        CONSTRAINT DF_MismoMapping_MismoVersion
        DEFAULT '3.6.1',
    MappingTypeCode   VARCHAR(30)    NOT NULL,
    MappingNotes      NVARCHAR(1000) NULL,
    LoadBatchId       INT NULL,
    RowHash           VARBINARY(32) NULL,
    CreatedDateUtc    DATETIME2(3) NOT NULL
        CONSTRAINT DF_MismoMapping_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc   DATETIME2(3) NULL,
    CONSTRAINT PK_MismoMapping
        PRIMARY KEY CLUSTERED (MismoMappingId),
    CONSTRAINT FK_MismoMapping_DataElement
        FOREIGN KEY (DataElementId)
        REFERENCES gov.DataElement (DataElementId),
    CONSTRAINT FK_MismoMapping_SourceSystem
        FOREIGN KEY (SourceSystemId)
        REFERENCES gov.SourceSystem (SourceSystemId),
    CONSTRAINT UQ_MismoMapping_Element_DataPoint_Version
        UNIQUE (DataElementId, MismoDataPointName,
                MismoVersion),
    CONSTRAINT CK_MismoMapping_MappingTypeCode CHECK
        (MappingTypeCode IN ('EXACT_MATCH','TRANSFORMED',
         'DERIVED','INTERNAL_EXTENSION','NOT_APPLICABLE'))
);
END
GO

/* ============ 18. gov.RegulatoryFramework ============ */
IF OBJECT_ID(N'gov.RegulatoryFramework', N'U') IS NULL
BEGIN
CREATE TABLE gov.RegulatoryFramework
(
    RegulatoryFrameworkId INT IDENTITY(1,1) NOT NULL,
    FrameworkCode        VARCHAR(30)   NOT NULL,
    FrameworkName        NVARCHAR(200) NOT NULL,
    FrameworkDescription NVARCHAR(500) NULL,
    RegulatorName        NVARCHAR(200) NULL,
    ActiveFlag           BIT NOT NULL
        CONSTRAINT DF_RegulatoryFramework_ActiveFlag DEFAULT 1,
    LoadBatchId          INT NULL,
    RowHash              VARBINARY(32) NULL,
    CreatedDateUtc       DATETIME2(3) NOT NULL
        CONSTRAINT DF_RegulatoryFramework_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc      DATETIME2(3) NULL,
    CONSTRAINT PK_RegulatoryFramework
        PRIMARY KEY CLUSTERED (RegulatoryFrameworkId),
    CONSTRAINT UQ_RegulatoryFramework_FrameworkCode
        UNIQUE (FrameworkCode)
);
END
GO

/* ============ 19. gov.RegulatoryReport ============ */
IF OBJECT_ID(N'gov.RegulatoryReport', N'U') IS NULL
BEGIN
CREATE TABLE gov.RegulatoryReport
(
    RegulatoryReportId  INT IDENTITY(1,1) NOT NULL,
    RegulatoryFrameworkId INT          NOT NULL,
    ReportCode          VARCHAR(30)    NOT NULL,
    ReportName          NVARCHAR(200)  NOT NULL,
    ReportVersion       VARCHAR(20)    NOT NULL,
    FilingFrequencyCode VARCHAR(20)    NOT NULL,
    FirstEffectivePeriod VARCHAR(20)   NULL,
    FilingAuthority     NVARCHAR(200)  NULL,
    Notes               NVARCHAR(1000) NULL,
    LoadBatchId         INT NULL,
    RowHash             VARBINARY(32) NULL,
    CreatedDateUtc      DATETIME2(3) NOT NULL
        CONSTRAINT DF_RegulatoryReport_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc     DATETIME2(3) NULL,
    CONSTRAINT PK_RegulatoryReport
        PRIMARY KEY CLUSTERED (RegulatoryReportId),
    CONSTRAINT UQ_RegulatoryReport_ReportCode
        UNIQUE (ReportCode),
    CONSTRAINT FK_RegulatoryReport_RegulatoryFramework
        FOREIGN KEY (RegulatoryFrameworkId)
        REFERENCES gov.RegulatoryFramework
                   (RegulatoryFrameworkId),
    CONSTRAINT CK_RegulatoryReport_FilingFrequencyCode CHECK
        (FilingFrequencyCode IN
         ('QUARTERLY','ANNUAL','MONTHLY','EVENT'))
);
END
GO

/* ============ 20. gov.RegulatoryReportSection ============ */
IF OBJECT_ID(N'gov.RegulatoryReportSection', N'U') IS NULL
BEGIN
CREATE TABLE gov.RegulatoryReportSection
(
    RegulatoryReportSectionId INT IDENTITY(1,1) NOT NULL,
    RegulatoryReportId INT           NOT NULL,
    ComponentCode      VARCHAR(20)   NOT NULL,
    SectionCode        VARCHAR(20)   NOT NULL,
    SectionName        NVARCHAR(200) NOT NULL,
    ScopeLevelCode     VARCHAR(20)   NOT NULL,
    LoadBatchId        INT NULL,
    RowHash            VARBINARY(32) NULL,
    CreatedDateUtc     DATETIME2(3) NOT NULL
        CONSTRAINT DF_RegulatoryReportSection_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc    DATETIME2(3) NULL,
    CONSTRAINT PK_RegulatoryReportSection
        PRIMARY KEY CLUSTERED (RegulatoryReportSectionId),
    CONSTRAINT FK_RegulatoryReportSection_RegulatoryReport
        FOREIGN KEY (RegulatoryReportId)
        REFERENCES gov.RegulatoryReport (RegulatoryReportId),
    CONSTRAINT UQ_RegulatoryReportSection_Report_Section
        UNIQUE (RegulatoryReportId, SectionCode),
    CONSTRAINT CK_RegulatoryReportSection_ScopeLevelCode CHECK
        (ScopeLevelCode IN ('COMPANY','STATE'))
);
END
GO

/* ============ 21. gov.RegulatoryReportItem ============
   Seeded from the NMLS MCR FV7 data dictionary (script 006).
   NmlsInstruction and SourceMappingGuidance retain the full
   official text for filing workpapers. */
IF OBJECT_ID(N'gov.RegulatoryReportItem', N'U') IS NULL
BEGIN
CREATE TABLE gov.RegulatoryReportItem
(
    RegulatoryReportItemId INT IDENTITY(1,1) NOT NULL,
    RegulatoryReportSectionId INT        NOT NULL,
    ItemCode          VARCHAR(30)    NOT NULL,
    ItemName          NVARCHAR(300)  NULL,
    SubsectionName    NVARCHAR(300)  NULL,
    NmlsInstruction   NVARCHAR(MAX)  NULL,
    SourceMappingGuidance NVARCHAR(MAX) NULL,
    DataFormatNote    NVARCHAR(300)  NULL,
    CalculatedFlag    BIT NOT NULL
        CONSTRAINT DF_RegulatoryReportItem_CalculatedFlag
        DEFAULT 0,
    ExampleValue      NVARCHAR(300)  NULL,
    ItemSortOrder     INT            NULL,
    LoadBatchId       INT NULL,
    RowHash           VARBINARY(32) NULL,
    CreatedDateUtc    DATETIME2(3) NOT NULL
        CONSTRAINT DF_RegulatoryReportItem_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc   DATETIME2(3) NULL,
    CONSTRAINT PK_RegulatoryReportItem
        PRIMARY KEY CLUSTERED (RegulatoryReportItemId),
    CONSTRAINT FK_RegulatoryReportItem_Section
        FOREIGN KEY (RegulatoryReportSectionId)
        REFERENCES gov.RegulatoryReportSection
                   (RegulatoryReportSectionId),
    CONSTRAINT UQ_RegulatoryReportItem_Section_ItemCode
        UNIQUE (RegulatoryReportSectionId, ItemCode)
);
CREATE NONCLUSTERED INDEX IX_RegulatoryReportItem_ItemCode
    ON gov.RegulatoryReportItem (ItemCode);
END
GO

/* ============ 22. gov.RegulatoryMapping ============ */
IF OBJECT_ID(N'gov.RegulatoryMapping', N'U') IS NULL
BEGIN
CREATE TABLE gov.RegulatoryMapping
(
    RegulatoryMappingId INT IDENTITY(1,1) NOT NULL,
    RegulatoryReportItemId INT         NOT NULL,
    MappedEntityTypeCode VARCHAR(20)  NOT NULL,
    DataElementId       INT           NULL,
    MetricDefinitionId  INT           NULL,
    RegulatoryClassificationCode VARCHAR(40) NOT NULL,
    FilingInputTypeCode VARCHAR(20)   NULL,
    ReconciliationRequiredFlag BIT NOT NULL
        CONSTRAINT DF_RegulatoryMapping_ReconRequiredFlag
        DEFAULT 0,
    EvidenceRetentionNote NVARCHAR(300) NULL,
    MappingNotes        NVARCHAR(1000) NULL,
    LoadBatchId         INT NULL,
    RowHash             VARBINARY(32) NULL,
    CreatedDateUtc      DATETIME2(3) NOT NULL
        CONSTRAINT DF_RegulatoryMapping_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc     DATETIME2(3) NULL,
    CONSTRAINT PK_RegulatoryMapping
        PRIMARY KEY CLUSTERED (RegulatoryMappingId),
    CONSTRAINT FK_RegulatoryMapping_RegulatoryReportItem
        FOREIGN KEY (RegulatoryReportItemId)
        REFERENCES gov.RegulatoryReportItem
                   (RegulatoryReportItemId),
    CONSTRAINT FK_RegulatoryMapping_DataElement
        FOREIGN KEY (DataElementId)
        REFERENCES gov.DataElement (DataElementId),
    CONSTRAINT FK_RegulatoryMapping_MetricDefinition
        FOREIGN KEY (MetricDefinitionId)
        REFERENCES gov.MetricDefinition (MetricDefinitionId),
    CONSTRAINT UQ_RegulatoryMapping_Item_Element_Metric
        UNIQUE (RegulatoryReportItemId, DataElementId,
                MetricDefinitionId),
    CONSTRAINT CK_RegulatoryMapping_MappedEntityTypeCode CHECK
        (MappedEntityTypeCode IN ('DATA_ELEMENT','METRIC')),
    CONSTRAINT CK_RegulatoryMapping_EntityConsistency CHECK
        ((MappedEntityTypeCode = 'DATA_ELEMENT'
          AND DataElementId IS NOT NULL
          AND MetricDefinitionId IS NULL)
         OR
         (MappedEntityTypeCode = 'METRIC'
          AND MetricDefinitionId IS NOT NULL
          AND DataElementId IS NULL)),
    CONSTRAINT CK_RegulatoryMapping_ClassificationCode CHECK
        (RegulatoryClassificationCode IN ('DIRECT_FIELD',
         'DERIVED_FIELD','SUPPORTING_DATA','CONTROL_DATA',
         'NON_REGULATORY')),
    CONSTRAINT CK_RegulatoryMapping_FilingInputTypeCode CHECK
        (FilingInputTypeCode IS NULL
         OR FilingInputTypeCode IN ('DIRECT','DERIVED',
            'SUPPORTING','RECONCILIATION','CONTROL_EVIDENCE'))
);
END
GO

/* ============ 23. gov.LineageNode ============ */
IF OBJECT_ID(N'gov.LineageNode', N'U') IS NULL
BEGIN
CREATE TABLE gov.LineageNode
(
    LineageNodeId   INT IDENTITY(1,1) NOT NULL,
    NodeTypeCode    VARCHAR(30)   NOT NULL,
    NodeName        NVARCHAR(300) NOT NULL,
    EntityId        INT           NULL,
    NodeDescription NVARCHAR(500) NULL,
    LoadBatchId     INT NULL,
    RowHash         VARBINARY(32) NULL,
    CreatedDateUtc  DATETIME2(3) NOT NULL
        CONSTRAINT DF_LineageNode_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc DATETIME2(3) NULL,
    CONSTRAINT PK_LineageNode
        PRIMARY KEY CLUSTERED (LineageNodeId),
    CONSTRAINT UQ_LineageNode_Type_Name
        UNIQUE (NodeTypeCode, NodeName),
    CONSTRAINT CK_LineageNode_NodeTypeCode CHECK
        (NodeTypeCode IN ('SOURCE_SYSTEM','SOURCE_OBJECT',
         'SOURCE_FIELD','STAGING_OBJECT','TRANSFORMATION',
         'WAREHOUSE_OBJECT','WAREHOUSE_COLUMN','PBI_VIEW',
         'PBI_VIEW_COLUMN','SEMANTIC_TABLE','SEMANTIC_COLUMN',
         'DAX_MEASURE','METRIC','REPORT_PAGE','REPORT_VISUAL',
         'REGULATORY_ITEM'))
);
END
GO

/* ============ 24. gov.LineageEdge ============ */
IF OBJECT_ID(N'gov.LineageEdge', N'U') IS NULL
BEGIN
CREATE TABLE gov.LineageEdge
(
    LineageEdgeId     INT IDENTITY(1,1) NOT NULL,
    FromLineageNodeId INT            NOT NULL,
    ToLineageNodeId   INT            NOT NULL,
    EdgeTypeCode      VARCHAR(30)    NOT NULL,
    TransformationLogic NVARCHAR(2000) NULL,
    MappingTypeCode   VARCHAR(20)    NULL,
    CreatedByObject   NVARCHAR(200)  NULL,
    LoadBatchId       INT NULL,
    RowHash           VARBINARY(32) NULL,
    CreatedDateUtc    DATETIME2(3) NOT NULL
        CONSTRAINT DF_LineageEdge_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc   DATETIME2(3) NULL,
    CONSTRAINT PK_LineageEdge
        PRIMARY KEY CLUSTERED (LineageEdgeId),
    CONSTRAINT FK_LineageEdge_LineageNode_From
        FOREIGN KEY (FromLineageNodeId)
        REFERENCES gov.LineageNode (LineageNodeId),
    CONSTRAINT FK_LineageEdge_LineageNode_To
        FOREIGN KEY (ToLineageNodeId)
        REFERENCES gov.LineageNode (LineageNodeId),
    CONSTRAINT UQ_LineageEdge_From_To_Type
        UNIQUE (FromLineageNodeId, ToLineageNodeId,
                EdgeTypeCode),
    CONSTRAINT CK_LineageEdge_EdgeTypeCode CHECK
        (EdgeTypeCode IN ('FEEDS_INTO','TRANSFORMED_BY',
         'DERIVED_FROM','EXPOSED_AS','CALCULATED_FROM',
         'DISPLAYED_ON','REPORTED_TO')),
    CONSTRAINT CK_LineageEdge_MappingTypeCode CHECK
        (MappingTypeCode IS NULL OR MappingTypeCode IN
         ('DIRECT','DERIVED','AGGREGATED')),
    CONSTRAINT CK_LineageEdge_NoSelfLoop CHECK
        (FromLineageNodeId <> ToLineageNodeId)
);
CREATE NONCLUSTERED INDEX IX_LineageEdge_From
    ON gov.LineageEdge (FromLineageNodeId);
CREATE NONCLUSTERED INDEX IX_LineageEdge_To
    ON gov.LineageEdge (ToLineageNodeId);
END
GO

/* ============ 25. gov.ReportInventory ============ */
IF OBJECT_ID(N'gov.ReportInventory', N'U') IS NULL
BEGIN
CREATE TABLE gov.ReportInventory
(
    ReportInventoryId INT IDENTITY(1,1) NOT NULL,
    ReportCode        VARCHAR(30)   NOT NULL,
    ReportName        NVARCHAR(300) NOT NULL,
    ReportTypeCode    VARCHAR(20)   NOT NULL,
    WorkspaceOrPath   NVARCHAR(300) NULL,
    SemanticModelName NVARCHAR(200) NULL,
    OwnerPartyId      INT           NULL,
    ActiveFlag        BIT NOT NULL
        CONSTRAINT DF_ReportInventory_ActiveFlag DEFAULT 1,
    LoadBatchId       INT NULL,
    RowHash           VARBINARY(32) NULL,
    CreatedDateUtc    DATETIME2(3) NOT NULL
        CONSTRAINT DF_ReportInventory_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc   DATETIME2(3) NULL,
    CONSTRAINT PK_ReportInventory
        PRIMARY KEY CLUSTERED (ReportInventoryId),
    CONSTRAINT UQ_ReportInventory_ReportCode
        UNIQUE (ReportCode),
    CONSTRAINT FK_ReportInventory_Party_Owner
        FOREIGN KEY (OwnerPartyId)
        REFERENCES gov.Party (PartyId),
    CONSTRAINT CK_ReportInventory_ReportTypeCode CHECK
        (ReportTypeCode IN
         ('POWER_BI','PAGINATED','EXTRACT','OTHER'))
);
END
GO

/* ============ 26. gov.ReportDependency ============ */
IF OBJECT_ID(N'gov.ReportDependency', N'U') IS NULL
BEGIN
CREATE TABLE gov.ReportDependency
(
    ReportDependencyId INT IDENTITY(1,1) NOT NULL,
    ReportInventoryId  INT           NOT NULL,
    PageName           NVARCHAR(200) NULL,
    VisualName         NVARCHAR(200) NULL,
    DependencyTypeCode VARCHAR(30)   NOT NULL,
    DependencyReference NVARCHAR(300) NOT NULL,
    MetricDefinitionId INT           NULL,
    LoadBatchId        INT NULL,
    RowHash            VARBINARY(32) NULL,
    CreatedDateUtc     DATETIME2(3) NOT NULL
        CONSTRAINT DF_ReportDependency_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc    DATETIME2(3) NULL,
    CONSTRAINT PK_ReportDependency
        PRIMARY KEY CLUSTERED (ReportDependencyId),
    CONSTRAINT FK_ReportDependency_ReportInventory
        FOREIGN KEY (ReportInventoryId)
        REFERENCES gov.ReportInventory (ReportInventoryId),
    CONSTRAINT FK_ReportDependency_MetricDefinition
        FOREIGN KEY (MetricDefinitionId)
        REFERENCES gov.MetricDefinition (MetricDefinitionId),
    CONSTRAINT CK_ReportDependency_DependencyTypeCode CHECK
        (DependencyTypeCode IN
         ('DAX_MEASURE','SEMANTIC_COLUMN','METRIC'))
);
END
GO

/* ============ 27. gov.Certification ============ */
IF OBJECT_ID(N'gov.Certification', N'U') IS NULL
BEGIN
CREATE TABLE gov.Certification
(
    CertificationId   INT IDENTITY(1,1) NOT NULL,
    EntityTypeCode    VARCHAR(30)   NOT NULL,
    EntityId          INT           NULL,
    EntityReference   NVARCHAR(300) NOT NULL,
    CertificationStatusCode VARCHAR(30) NOT NULL
        CONSTRAINT DF_Certification_StatusCode
        DEFAULT 'NOT_CERTIFIED',
    CertifiedByPartyId INT          NULL,
    CertifiedDateUtc  DATETIME2(3)  NULL,
    DataAsOfDate      DATE          NULL,
    LoadBatchId       INT NULL,
    CertificationNotes NVARCHAR(1000) NULL,
    RowHash           VARBINARY(32) NULL,
    CreatedDateUtc    DATETIME2(3) NOT NULL
        CONSTRAINT DF_Certification_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc   DATETIME2(3) NULL,
    CONSTRAINT PK_Certification
        PRIMARY KEY CLUSTERED (CertificationId),
    CONSTRAINT FK_Certification_Party_CertifiedBy
        FOREIGN KEY (CertifiedByPartyId)
        REFERENCES gov.Party (PartyId),
    CONSTRAINT CK_Certification_EntityTypeCode CHECK
        (EntityTypeCode IN
         ('REPORT','METRIC','DATASET','SEMANTIC_MODEL')),
    CONSTRAINT CK_Certification_StatusCode CHECK
        (CertificationStatusCode IN ('NOT_CERTIFIED',
         'CERTIFIED','CERTIFIED_WITH_EXCEPTIONS','REVOKED'))
);
END
GO

/* ============ 28. gov.CertificationEvidence ============ */
IF OBJECT_ID(N'gov.CertificationEvidence', N'U') IS NULL
BEGIN
CREATE TABLE gov.CertificationEvidence
(
    CertificationEvidenceId INT IDENTITY(1,1) NOT NULL,
    CertificationId  INT           NOT NULL,
    EvidenceTypeCode VARCHAR(30)   NOT NULL,
    EvidenceEntityId INT           NULL,
    EvidenceReference NVARCHAR(500) NULL,
    EvidenceDateUtc  DATETIME2(3) NOT NULL
        CONSTRAINT DF_CertificationEvidence_EvidenceDateUtc
        DEFAULT SYSUTCDATETIME(),
    LoadBatchId      INT NULL,
    RowHash          VARBINARY(32) NULL,
    CreatedDateUtc   DATETIME2(3) NOT NULL
        CONSTRAINT DF_CertificationEvidence_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc  DATETIME2(3) NULL,
    CONSTRAINT PK_CertificationEvidence
        PRIMARY KEY CLUSTERED (CertificationEvidenceId),
    CONSTRAINT FK_CertificationEvidence_Certification
        FOREIGN KEY (CertificationId)
        REFERENCES gov.Certification (CertificationId),
    CONSTRAINT CK_CertificationEvidence_EvidenceTypeCode CHECK
        (EvidenceTypeCode IN ('DQ_RESULT','RECON_RESULT',
         'LOAD_EXECUTION','SCREENSHOT','QUERY_RESULT',
         'DOCUMENT'))
);
END
GO

/* ============ 29. gov.DataIssue ============
   Issue register. Feeds Data Issue Aging (DRV_ISSUEAGE). */
IF OBJECT_ID(N'gov.DataIssue', N'U') IS NULL
BEGIN
CREATE TABLE gov.DataIssue
(
    DataIssueId      INT IDENTITY(1,1) NOT NULL,
    IssueTitle       NVARCHAR(300)  NOT NULL,
    IssueDescription NVARCHAR(2000) NULL,
    DataElementId    INT            NULL,
    SourceSystemId   INT            NULL,
    DqRuleReference  NVARCHAR(100)  NULL,
    SeverityCode     VARCHAR(20)    NOT NULL,
    StatusCode       VARCHAR(30)    NOT NULL
        CONSTRAINT DF_DataIssue_StatusCode DEFAULT 'NEW',
    OpenedDate       DATE NOT NULL
        CONSTRAINT DF_DataIssue_OpenedDate
        DEFAULT CAST(GETDATE() AS DATE),
    TargetResolutionDate DATE       NULL,
    ClosedDate       DATE           NULL,
    OwnerPartyId     INT            NULL,
    ResolutionNotes  NVARCHAR(1000) NULL,
    LoadBatchId      INT NULL,
    RowHash          VARBINARY(32) NULL,
    CreatedDateUtc   DATETIME2(3) NOT NULL
        CONSTRAINT DF_DataIssue_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc  DATETIME2(3) NULL,
    CONSTRAINT PK_DataIssue PRIMARY KEY CLUSTERED (DataIssueId),
    CONSTRAINT FK_DataIssue_DataElement
        FOREIGN KEY (DataElementId)
        REFERENCES gov.DataElement (DataElementId),
    CONSTRAINT FK_DataIssue_SourceSystem
        FOREIGN KEY (SourceSystemId)
        REFERENCES gov.SourceSystem (SourceSystemId),
    CONSTRAINT FK_DataIssue_Party_Owner
        FOREIGN KEY (OwnerPartyId)
        REFERENCES gov.Party (PartyId),
    CONSTRAINT CK_DataIssue_SeverityCode CHECK
        (SeverityCode IN ('CRITICAL','HIGH','MEDIUM','LOW')),
    CONSTRAINT CK_DataIssue_StatusCode CHECK
        (StatusCode IN ('NEW','ACKNOWLEDGED','IN_REMEDIATION',
         'ACCEPTED_RISK','RESOLVED','CLOSED'))
);
END
GO

/* ============ 30. gov.ChangeLog ============ */
IF OBJECT_ID(N'gov.ChangeLog', N'U') IS NULL
BEGIN
CREATE TABLE gov.ChangeLog
(
    ChangeLogId       INT IDENTITY(1,1) NOT NULL,
    EntityTypeCode    VARCHAR(40)    NOT NULL,
    EntityId          INT            NULL,
    EntityReference   NVARCHAR(300)  NULL,
    ChangeTypeCode    VARCHAR(20)    NOT NULL,
    ChangeDescription NVARCHAR(2000) NOT NULL,
    ChangedBy         NVARCHAR(128)  NOT NULL
        CONSTRAINT DF_ChangeLog_ChangedBy
        DEFAULT SUSER_SNAME(),
    ChangeDateUtc     DATETIME2(3) NOT NULL
        CONSTRAINT DF_ChangeLog_ChangeDateUtc
        DEFAULT SYSUTCDATETIME(),
    LoadBatchId       INT NULL,
    RowHash           VARBINARY(32) NULL,
    CreatedDateUtc    DATETIME2(3) NOT NULL
        CONSTRAINT DF_ChangeLog_CreatedDateUtc
        DEFAULT SYSUTCDATETIME(),
    ModifiedDateUtc   DATETIME2(3) NULL,
    CONSTRAINT PK_ChangeLog PRIMARY KEY CLUSTERED (ChangeLogId),
    CONSTRAINT CK_ChangeLog_ChangeTypeCode CHECK
        (ChangeTypeCode IN
         ('INSERT','UPDATE','DELETE','DEPRECATE','VERSION'))
);
END
GO

/* ------------------------------------------------------------
   Deferred FK: audit.ReconciliationControl owner -> gov.Party
   ------------------------------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys
               WHERE name = N'FK_ReconciliationControl_Party_Owner')
BEGIN
    ALTER TABLE audit.ReconciliationControl
        ADD CONSTRAINT FK_ReconciliationControl_Party_Owner
        FOREIGN KEY (OwnerPartyId)
        REFERENCES gov.Party (PartyId);
END
GO

PRINT 'Script 003 complete: 30 governance core tables ready.';
GO
