/* ============================================================
   MortgageGovernance | Phase 7 | Script 022
   PBI semantic layer views and end-to-end pipeline.
   Creates the certified pbi.* views Power BI imports (star
   schema: dims, facts, governance panels) and
   dw.usp_RunPipeline, the single command that runs
   DW load -> DQ execution -> effectiveness scoring ->
   reconciliation -> certification.
   Technical columns (keys stay for relationships;
   LoadBatchId, RowHash, audit timestamps are excluded).
   PII (DimBorrower names, property street) is not exposed.
   Idempotent: safe to re-run.
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;
GO

/* ============================================================
   1. Dimension views
   ============================================================ */
CREATE OR ALTER VIEW pbi.vw_DimDate
AS
SELECT DateKey, FullDate, CalendarYear, CalendarQuarter,
       QuarterName, CalendarMonth, MonthName, YearMonth,
       CalendarDay, DayOfWeekNo, DayName, MonthStartDate,
       MonthEndDate, MonthEndFlag, WeekendFlag, HolidayFlag,
       HolidayName, BusinessDayFlag
FROM dw.DimDate;
GO

CREATE OR ALTER VIEW pbi.vw_DimLoan
AS
SELECT LoanKey, LoanNumber, OriginationDate, MaturityDate,
       OriginalLoanAmount, NoteRatePercent,
       InterestRateTypeCode, AmortizationTermMonths,
       LienPosition, HelocFlag, ReverseMortgageFlag,
       LoanProgramCode, LoanPurposeCode, EscrowedFlag,
       ConformingFlag, McrLoanTypeCode, ProductClassCode,
       BoardedDate
FROM dw.DimLoan;
GO

/* Property: state and type only. Street address is PII
   scoped out of the semantic model. */
CREATE OR ALTER VIEW pbi.vw_DimProperty
AS
SELECT PropertyKey, LoanNumber, PropertyStateCode,
       PropertyTypeCode, OccupancyTypeCode, UnitsCount,
       FloodZoneFlag
FROM dw.DimProperty;
GO

CREATE OR ALTER VIEW pbi.vw_DimInvestor
AS
SELECT InvestorKey, InvestorCode, InvestorName,
       InvestorTypeCode
FROM dw.DimInvestor;
GO

CREATE OR ALTER VIEW pbi.vw_DimServicingType
AS
SELECT ServicingTypeKey, ServicingTypeCode,
       ServicingTypeName, McrLineNote
FROM dw.DimServicingType;
GO

CREATE OR ALTER VIEW pbi.vw_DimRemittanceType
AS
SELECT RemittanceTypeKey, RemittanceTypeCode,
       RemittanceTypeName
FROM dw.DimRemittanceType;
GO

CREATE OR ALTER VIEW pbi.vw_DimLoanStatus
AS
SELECT LoanStatusKey, LoanStatusCode, LoanStatusName,
       ActiveServicingFlag
FROM dw.DimLoanStatus;
GO

CREATE OR ALTER VIEW pbi.vw_DimDelinquencyStatus
AS
SELECT DelinquencyStatusKey, DelinquencyBucketCode,
       DelinquencyBucketName, MinDpd, MaxDpd, SortOrder,
       DelinquentFlag, SeriousDelinquencyFlag, McrLineNote
FROM dw.DimDelinquencyStatus;
GO

CREATE OR ALTER VIEW pbi.vw_DimWorkoutType
AS
SELECT WorkoutTypeKey, WorkoutTypeCode, WorkoutTypeName,
       RetentionFlag
FROM dw.DimWorkoutType;
GO

CREATE OR ALTER VIEW pbi.vw_DimLeadSource
AS
SELECT LeadSourceKey, LeadSourceCode, LeadSourceName,
       MarketingSourcedFlag, ReferralFlag
FROM dw.DimLeadSource;
GO

CREATE OR ALTER VIEW pbi.vw_DimBranch
AS
SELECT BranchKey, BranchCode, BranchName, Region
FROM dw.DimBranch;
GO

CREATE OR ALTER VIEW pbi.vw_DimLoanOfficer
AS
SELECT LoanOfficerKey, NmlsId, FullName, BranchCode,
       Region, ChannelCode, EmploymentStatusCode,
       EffectiveFromDate, EffectiveToDate, CurrentRowFlag
FROM dw.DimLoanOfficer;
GO

/* ============================================================
   2. Fact views
   ============================================================ */
CREATE OR ALTER VIEW pbi.vw_FactLoanSnapshot
AS
SELECT LoanMonthEndSnapshotKey, LoanKey, SnapshotDateKey,
       AsOfDate, LoanNumber, InvestorKey, ServicingTypeKey,
       RemittanceTypeKey, LoanStatusKey,
       DelinquencyStatusKey, CurrentUpbAmount,
       BeginningUpbAmount, ScheduledPrincipalAmount,
       VoluntaryPrepaidPrincipalAmount, InterestRatePercent,
       ServicingFeeRatePercent, NextPaymentDueDate,
       DaysPastDue, SourceReportedBucketCode,
       EscrowBalanceAmount, SuspenseBalanceAmount,
       EscrowedFlag, ForbearanceFlag, ActiveServicingFlag,
       Roll30to60Flag, CureFlag, RunoffFlag,
       RunoffReasonCode, ModSeasoningCode, CurrentLtvPct,
       LtvBandCode
FROM dw.FactLoanMonthEndSnapshot;
GO

CREATE OR ALTER VIEW pbi.vw_FactPaymentTransaction
AS
SELECT PaymentTransactionKey, PaymentTransactionId,
       LoanKey, LoanNumber, ReceivedDateKey, ReceivedDate,
       PostedDate, EffectiveDate, PaymentAmount,
       PrincipalAmount, InterestAmount, EscrowAmount,
       FeeAmount, SuspenseFlag, ReversalFlag, ChannelCode,
       DaysToPost, PostedTimelyFlag, PostedAccuratelyFlag,
       UnmatchedLoanFlag
FROM dw.FactPaymentTransaction;
GO

CREATE OR ALTER VIEW pbi.vw_FactLossMitigationCase
AS
SELECT LossMitigationCaseKey, LossMitCaseId, LoanKey,
       LoanNumber, WorkoutTypeKey, AppReceivedDateKey,
       AppReceivedDate, CompletePackageDate, DecisionDate,
       DecisionCode, WorkoutTypeCode, TrialStartDate,
       TrialCompletedDate, EvalTurnTimeDays,
       WorkoutApprovedFlag, TrialConvertedFlag
FROM dw.FactLossMitigationCase;
GO

CREATE OR ALTER VIEW pbi.vw_FactForeclosureCase
AS
SELECT ForeclosureCaseKey, ForeclosureCaseId, LoanKey,
       LoanNumber, FirstLegalEligibleDateKey,
       FirstLegalEligibleDate, ReferralDate, FirstLegalDate,
       SaleScheduledDate, SaleHeldDate, CaseStatusCode,
       ResolutionTypeCode, ReferralDays,
       FcReferralTimelyFlag
FROM dw.FactForeclosureCase;
GO

CREATE OR ALTER VIEW pbi.vw_FactBankruptcyCase
AS
SELECT BankruptcyCaseKey, BankruptcyCaseId, LoanKey,
       LoanNumber, ChapterCode, PetitionDateKey,
       PetitionDate, PocBarDate, PocFiledDate,
       CaseStatusCode, DispositionCode, PocTimelyFlag
FROM dw.FactBankruptcyCase;
GO

CREATE OR ALTER VIEW pbi.vw_FactBoardingEvent
AS
SELECT BoardingEventKey, LoanKey, LoanNumber,
       BoardingBatchId, TransferTypeCode,
       TransferEffectiveDateKey, TransferEffectiveDate,
       ScheduledBoardDate, BoardingCompletedDate,
       BoardingDays, BoardedOnTimeFlag, TapeRowCount,
       UpbMismatchFlag, RateMismatchFlag,
       NextDueDateMismatchFlag, EscrowBalanceMismatchFlag,
       InvestorMismatchFlag, MismatchCount,
       BoardingAccuracyScore
FROM dw.FactBoardingEvent;
GO

CREATE OR ALTER VIEW pbi.vw_FactLead
AS
SELECT LeadKey, LeadId, LeadCreatedDateKey,
       LeadCreatedDate, LeadSourceKey, CampaignCode,
       PropertyStateCode, LoanOfficerKey, AssignedDate,
       FirstContactDate, LeadStatusCode,
       ConvertedApplicationId, ConvertedFlag,
       ConvertedInWindowFlag, DaysToConvert
FROM dw.FactLead;
GO

CREATE OR ALTER VIEW pbi.vw_FactApplication
AS
SELECT ApplicationKey, ApplicationId, LeadId,
       LoanOfficerKey, BranchKey, LoanOfficerNmlsId,
       AppStartedDateKey, AppStartedDate, AppCompletedDate,
       AppReceivedDate, LoanAmountAtApplication,
       CurrentLoanAmount, LoanPurposeCode, LoanProgramCode,
       InterestRateTypeCode, PropertyStateCode, ChannelCode,
       DispositionCode, DispositionDate,
       ScheduledClosingDate, ActualClosingDate
FROM dw.FactApplication;
GO

CREATE OR ALTER VIEW pbi.vw_FactRateLock
AS
SELECT RateLockKey, RateLockId, ApplicationId, LockDateKey,
       LockDate, LockAmount, NoteRatePercent,
       LockPeriodDays, OriginalExpirationDate,
       CurrentExpirationDate, ExtensionCount,
       TotalExtensionDays, LockStatusCode, ExtendedFlag,
       ExpiredWithoutFundingFlag, RelockFlag
FROM dw.FactRateLock;
GO

/* ============================================================
   3. Governance panel views (DQ, recon, certification,
      metrics, lineage, regulatory, project overview)
   ============================================================ */
CREATE OR ALTER VIEW pbi.vw_DataQualityResult
AS
SELECT AsOfDate, RuleCode, RuleName, DqDimensionCode,
       SeverityCode, BlockingFlag, TargetObjectName,
       DataElementCode, CdeFlag, EvaluatedRowCount,
       FailedRowCount, PassRatePct, ThresholdValue,
       StatusCode, RuleOwner, RuleSteward
FROM dq.vw_RuleResultLatest;
GO

CREATE OR ALTER VIEW pbi.vw_DataQualityEffectiveness
AS
SELECT RuleCode, RuleName, DqDimensionCode, SeverityCode,
       DefectCode, DefectName, TruePositive, FalsePositive,
       FalseNegative, BroadConditionFlag, PrecisionPct,
       RecallPct, F1Score, BroadConditionRationale
FROM dq.vw_RuleEffectivenessLatest;
GO

CREATE OR ALTER VIEW pbi.vw_ReconciliationResult
AS
SELECT ControlCode, ControlName, ControlTypeCode,
       ToleranceTypeCode, BlockingFlag, AsOfDate,
       ExecutedDateUtc, SourceValue, TargetValue,
       VarianceValue, VariancePct, StatusCode, Details,
       ControlOwner
FROM audit.vw_ReconciliationLatest;
GO

CREATE OR ALTER VIEW pbi.vw_ReportCertification
AS
SELECT ReportCode, ReportName, ReportTypeCode,
       SemanticModelName, ReportOwner,
       CertificationStatusCode, CertifiedBy,
       CertifiedDateUtc, DataAsOfDate, CertificationNotes,
       EvidenceRowCount
FROM gov.vw_ReportCertificationStatus;
GO

CREATE OR ALTER VIEW pbi.vw_MetricCatalog
AS
SELECT MetricCode, MetricName, BusinessDefinition,
       MetricCategory, BusinessDomain, StakeholderTeam,
       AggregationTypeCode, RequiredGrain,
       ReportingTimeBasisCode, AuthoritativeSourceSummary,
       FormatString, DirectionCode, ProjectAssignmentCode,
       CoverageStatusCode, ImplementationStatusCode,
       RegulatoryRelevanceFlag, McrRelevanceFlag,
       MismoAlignmentNote
FROM gov.MetricDefinition;
GO

CREATE OR ALTER VIEW pbi.vw_DataDictionary
AS
SELECT * FROM gov.vw_DataDictionary;
GO

CREATE OR ALTER VIEW pbi.vw_CdeRegister
AS
SELECT * FROM gov.vw_CdeRegister;
GO

CREATE OR ALTER VIEW pbi.vw_MetricElementLineage
AS
SELECT * FROM gov.vw_MetricElementLineage;
GO

CREATE OR ALTER VIEW pbi.vw_LineageEdge
AS
SELECT
    e.LineageEdgeId,
    fn.NodeTypeCode AS FromNodeTypeCode,
    fn.NodeName     AS FromNodeName,
    tn.NodeTypeCode AS ToNodeTypeCode,
    tn.NodeName     AS ToNodeName,
    e.EdgeTypeCode, e.MappingTypeCode,
    e.TransformationLogic, e.CreatedByObject
FROM gov.LineageEdge e
JOIN gov.LineageNode fn
  ON fn.LineageNodeId = e.FromLineageNodeId
JOIN gov.LineageNode tn
  ON tn.LineageNodeId = e.ToLineageNodeId;
GO

CREATE OR ALTER VIEW pbi.vw_MismoCoverage
AS
SELECT * FROM gov.vw_MismoCoverage;
GO

CREATE OR ALTER VIEW pbi.vw_RegulatoryMapping
AS
SELECT * FROM gov.vw_RegulatoryMapping;
GO

CREATE OR ALTER VIEW pbi.vw_RegulatoryCoverage
AS
SELECT * FROM gov.vw_RegulatoryCoverage;
GO

/* Project governance overview: one-row scorecard for the
   portfolio-facing summary page. */
CREATE OR ALTER VIEW pbi.vw_GovernanceScorecard
AS
SELECT
    (SELECT COUNT(*) FROM gov.DataElement)
        AS GovernedDataElements,
    (SELECT COUNT(*) FROM gov.CriticalDataElement)
        AS CriticalDataElements,
    (SELECT COUNT(*) FROM gov.DataElementBinding)
        AS ElementBindings,
    (SELECT COUNT(*) FROM gov.MismoMapping)
        AS MismoMappings,
    (SELECT COUNT(*) FROM gov.RegulatoryMapping)
        AS RegulatoryMappings,
    (SELECT COUNT(*) FROM gov.MetricDefinition)
        AS MetricDefinitions,
    (SELECT COUNT(*) FROM gov.MetricDefinition
     WHERE CoverageStatusCode = 'SUPPORTED')
        AS MetricsSupportedNow,
    (SELECT COUNT(*) FROM dq.[Rule]
     WHERE ActiveFlag = 1) AS ActiveDqRules,
    (SELECT COUNT(*) FROM audit.ReconciliationControl
     WHERE ActiveFlag = 1) AS ActiveReconControls,
    (SELECT COUNT(*) FROM gov.LineageEdge) AS LineageEdges,
    (SELECT COUNT(*) FROM gov.SourceSystem)
        AS SourceSystems;
GO

/* ============================================================
   4. dw.usp_RunPipeline
      End-to-end: DW load -> DQ rules -> effectiveness ->
      reconciliation -> certification. One command, one
      batch trail. This is the demo entry point.
   ============================================================ */
CREATE OR ALTER PROCEDURE dw.usp_RunPipeline
    @AsOfDate DATE = '2026-07-31'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @DqBatchId INT, @ReconBatchId INT;

    EXEC dw.usp_RunFullLoad
        @BatchName = N'Pipeline: DW full load';

    EXEC dq.usp_ExecuteRules
        @AsOfDate = @AsOfDate,
        @RuleExecutionBatchId = @DqBatchId OUTPUT;

    EXEC dq.usp_ScoreRuleEffectiveness
        @RuleExecutionBatchId = @DqBatchId;

    EXEC audit.usp_RunReconciliation
        @AsOfDate = @AsOfDate,
        @LoadBatchId = @ReconBatchId OUTPUT;

    EXEC gov.usp_CertifyReport
        @ReportCode = 'PBI_SVC_GOV',
        @AsOfDate = @AsOfDate;
END
GO

/* ============================================================
   5. Verification
   ============================================================ */
SELECT s.name AS SchemaName, COUNT(*) AS ViewCount
FROM sys.views v
JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'pbi'
GROUP BY s.name;

SELECT * FROM pbi.vw_GovernanceScorecard;
GO

PRINT 'Script 022 complete: 31 pbi views and '
    + 'dw.usp_RunPipeline created.';
GO
