/* ============================================================
   MortgageGovernance | Phase 2 | Script 004
   Core governance seed: source systems, roles, parties,
   RACI assignments, regulatory frameworks, MCR FV7 report
   and section registry, report inventory, initial
   certification record.
   The seed runs through the audit framework on purpose:
   every load, including metadata, leaves evidence.
   Idempotent: safe to re-run (NOT EXISTS guards).
   ============================================================ */
USE MortgageGovernance;
GO
SET NOCOUNT ON;

DECLARE @LoadBatchId INT;
DECLARE @BatchNotes NVARCHAR(400) =
    N'Script 004: systems, roles, parties, '
  + N'RACI, frameworks, MCR FV7 registry.';


EXEC audit.usp_StartLoadBatch
     @BatchName     = N'Phase 2 governance core seed',
     @BatchTypeCode = 'SEED',
     @Notes         = @BatchNotes,
     @LoadBatchId   = @LoadBatchId OUTPUT;

BEGIN TRY
BEGIN TRAN;

/* ------------------------------------------------------------
   1. Source systems (10)
   ------------------------------------------------------------ */
INSERT INTO gov.SourceSystem
    (SourceSystemCode, SourceSystemName, SystemDescription,
     SystemTypeCode, DomainArea, AuthoritativeScopeSummary,
     LoadBatchId)
SELECT v.Code, v.SysName, v.Descr, v.SysType, v.Domain,
       v.AuthScope, @LoadBatchId
FROM (VALUES
 ('BRD','BoardingTape',
  'Acquisition and transfer boarding tape intake',
  'BOARDING','Boarding & Transfers',
  'Authoritative for loan attributes at boarding only; '
  + 'authority passes to CoreServ after board date'),
 ('SVC','CoreServ',
  'Servicing system of record',
  'SERVICING_CORE','Servicing',
  'Authoritative for loan, escrow, and status attributes '
  + 'post-boarding'),
 ('PAY','PayStream',
  'Payment intake and posting platform',
  'PAYMENT','Payments & Cash',
  'Authoritative for payment transactions, reversals, '
  + 'and suspense activity'),
 ('DMS','DefaultTrack',
  'Default management: loss mitigation, foreclosure, '
  + 'bankruptcy',
  'DEFAULT_MGMT','Default Management',
  'Authoritative for workout, foreclosure, and '
  + 'bankruptcy case data'),
 ('INV','InvestorLink',
  'Investor reporting and remittance platform',
  'INVESTOR_RPT','Investor Reporting',
  'Authoritative for investor report submissions, '
  + 'remittances, and repurchase demands'),
 ('VAL','CollateralVal',
  'Property valuation feed',
  'VALUATION','Collateral',
  'Authoritative for property valuations and '
  + 'valuation dates'),
 ('CRM','LagoonCRM',
  'Lead management and contact platform',
  'CRM','Production & Marketing',
  'Authoritative for leads, lead sources, and initial '
  + 'loan officer assignment'),
 ('LOS','MangoLOS',
  'Loan origination system',
  'LOS','Production',
  'Authoritative for applications, dispositions, '
  + 'closing and funding events, servicing intent'),
 ('PPE','PalmLock',
  'Product pricing and rate lock engine',
  'PPE','Production',
  'Authoritative for lock terms, extensions, '
  + 'expirations, and relocks'),
 ('LIC','NmlsFeed',
  'NMLS roster and license feed',
  'LICENSING','Workforce & Licensing',
  'Authoritative for loan officer identity, state '
  + 'licenses, and continuing education')
) v(Code, SysName, Descr, SysType, Domain, AuthScope)
WHERE NOT EXISTS
      (SELECT 1 FROM gov.SourceSystem s
       WHERE s.SourceSystemCode = v.Code);

/* ------------------------------------------------------------
   2. Governance roles (8)
   ------------------------------------------------------------ */
INSERT INTO gov.GovernanceRole
    (RoleCode, RoleName, RoleDescription, LoadBatchId)
SELECT v.RoleCode, v.RoleName, v.Descr, @LoadBatchId
FROM (VALUES
 ('DATA_OWNER','Data Owner',
  'Accountable for definition, quality, and access of a '
  + 'data domain or system'),
 ('DATA_STEWARD','Data Steward',
  'Responsible for day-to-day definitions, quality '
  + 'monitoring, and issue triage'),
 ('TECHNICAL_STEWARD','Technical Steward',
  'Responsible for pipelines, schemas, and technical '
  + 'controls'),
 ('EXECUTIVE_SPONSOR','Executive Sponsor',
  'Champions the governance program and resolves '
  + 'cross-domain escalations'),
 ('DQ_ANALYST','Data Quality Analyst',
  'Builds and monitors data quality rules and '
  + 'exception workflows'),
 ('REPORT_OWNER','Report Owner',
  'Accountable for a published report and its '
  + 'certification state'),
 ('CERTIFIER','Certifier',
  'Authorized to certify reports and metrics after '
  + 'controls pass'),
 ('REGULATORY_OWNER','Regulatory Report Owner',
  'Accountable for a regulatory filing and its '
  + 'supporting data controls')
) v(RoleCode, RoleName, Descr)
WHERE NOT EXISTS
      (SELECT 1 FROM gov.GovernanceRole g
       WHERE g.RoleCode = v.RoleCode);

/* ------------------------------------------------------------
   3. Parties (17): 15 people, 2 teams
   ------------------------------------------------------------ */
INSERT INTO gov.Party
    (PartyName, PartyTypeCode, JobTitle, Department, Email,
     LoadBatchId)
SELECT v.PartyName, v.PType, v.Title, v.Dept, v.Email,
       @LoadBatchId
FROM (VALUES
 ('Camille Flamingo','PERSON','Chief Executive Officer',
  'Executive','camille.flamingo@flamingofin.example'),
 ('Paige Justice','PERSON','VP, Data Governance',
  'Data Governance Office',
  'paige.justice@flamingofin.example'),
 ('Marco Ibis','PERSON','SVP, Servicing Operations',
  'Servicing','marco.ibis@flamingofin.example'),
 ('Sofia Egret','PERSON','Servicing Data Steward',
  'Servicing','sofia.egret@flamingofin.example'),
 ('Dana Heron','PERSON','Director, Cash and Payment Ops',
  'Payments','dana.heron@flamingofin.example'),
 ('Victor Teal','PERSON','Payments Data Steward',
  'Payments','victor.teal@flamingofin.example'),
 ('Lena Spoonbill','PERSON','Director, Escrow Administration',
  'Escrow','lena.spoonbill@flamingofin.example'),
 ('Omar Pelican','PERSON','Director, Default Management',
  'Default Management','omar.pelican@flamingofin.example'),
 ('Ruth Sandpiper','PERSON','Default Data Steward',
  'Default Management','ruth.sandpiper@flamingofin.example'),
 ('Felix Crane','PERSON','Director, Investor Reporting',
  'Investor Reporting','felix.crane@flamingofin.example'),
 ('Ana Plover','PERSON','Investor Reporting Data Steward',
  'Investor Reporting','ana.plover@flamingofin.example'),
 ('Diego Kite','PERSON','SVP, Loan Production',
  'Production','diego.kite@flamingofin.example'),
 ('Mira Bittern','PERSON','Production Data Steward',
  'Production','mira.bittern@flamingofin.example'),
 ('Noah Curlew','PERSON','Director, Data Engineering',
  'Technology','noah.curlew@flamingofin.example'),
 ('Iris Whimbrel','PERSON','Director, Regulatory Reporting',
  'Compliance','iris.whimbrel@flamingofin.example'),
 ('Data Governance Office','TEAM',NULL,
  'Data Governance Office',
  'dgo@flamingofin.example'),
 ('Servicing Analytics','TEAM',NULL,
  'Servicing','servicing.analytics@flamingofin.example')
) v(PartyName, PType, Title, Dept, Email)
WHERE NOT EXISTS
      (SELECT 1 FROM gov.Party p
       WHERE p.PartyName = v.PartyName
         AND p.PartyTypeCode = v.PType);

/* ------------------------------------------------------------
   4. Regulatory frameworks (9)
   ------------------------------------------------------------ */
INSERT INTO gov.RegulatoryFramework
    (FrameworkCode, FrameworkName, FrameworkDescription,
     RegulatorName, LoadBatchId)
SELECT v.Code, v.FName, v.Descr, v.Reg, @LoadBatchId
FROM (VALUES
 ('MCR','NMLS Mortgage Call Report',
  'Quarterly RMLA, SSSF, and FC components filed through '
  + 'NMLS. FV7 mandatory beginning Q1 2026 activity.',
  'NMLS / CSBS'),
 ('RESPA_REGX','RESPA Regulation X',
  'Servicing rules: escrow, error resolution, loss '
  + 'mitigation timelines.',
  'CFPB'),
 ('TILA_TRID','TILA and TRID',
  'Origination disclosure rules. Reserved for Project 2 '
  + 'origination depth.',
  'CFPB'),
 ('HMDA','Home Mortgage Disclosure Act',
  'Loan application register reporting. Reserved for '
  + 'Project 2.',
  'CFPB'),
 ('ECOA_REGB','ECOA Regulation B',
  'Fair lending and adverse action. Reserved for '
  + 'Project 2.',
  'CFPB'),
 ('FLOOD','Flood Disaster Protection Act',
  'Flood determination and insurance requirements.',
  'FDIC / OCC / FRB'),
 ('SAFE_ACT','SAFE Act',
  'MLO licensing and NMLS registration requirements. '
  + 'Drives the E1 licensing metrics.',
  'NMLS / State Regulators'),
 ('INVESTOR_AGENCY','Investor and Agency Guides',
  'FNMA, FHLMC, GNMA servicing guide reporting and '
  + 'remittance requirements.',
  'FNMA / FHLMC / GNMA'),
 ('STATE_SERVICING','State Servicing Regulations',
  'State-level servicing requirements and examinations.',
  'State Regulators')
) v(Code, FName, Descr, Reg)
WHERE NOT EXISTS
      (SELECT 1 FROM gov.RegulatoryFramework f
       WHERE f.FrameworkCode = v.Code);

/* ------------------------------------------------------------
   5. MCR FV7 report and section registry
   ------------------------------------------------------------ */
DECLARE @McrFrameworkId INT =
    (SELECT RegulatoryFrameworkId
     FROM gov.RegulatoryFramework
     WHERE FrameworkCode = 'MCR');

IF NOT EXISTS (SELECT 1 FROM gov.RegulatoryReport
               WHERE ReportCode = 'MCR_FV7')
BEGIN
    INSERT INTO gov.RegulatoryReport
        (RegulatoryFrameworkId, ReportCode, ReportName,
         ReportVersion, FilingFrequencyCode,
         FirstEffectivePeriod, FilingAuthority, Notes,
         LoadBatchId)
    VALUES
        (@McrFrameworkId, 'MCR_FV7',
         N'Mortgage Call Report Form Version 7',
         'FV7', 'QUARTERLY', '2026-Q1', N'NMLS',
         N'FV7 mandatory for Q1 2026 activity. Filing window '
         + N'opened 2026-04-01; first standard due date '
         + N'2026-05-15. Some states granted grace periods.',
         @LoadBatchId);
END

DECLARE @McrReportId INT =
    (SELECT RegulatoryReportId FROM gov.RegulatoryReport
     WHERE ReportCode = 'MCR_FV7');

INSERT INTO gov.RegulatoryReportSection
    (RegulatoryReportId, ComponentCode, SectionCode,
     SectionName, ScopeLevelCode, LoadBatchId)
SELECT @McrReportId, v.Comp, v.Sect, v.SName, v.Scope,
       @LoadBatchId
FROM (VALUES
 ('RMLA','RMLA_COMPANY',
  N'RMLA Company-Level Information','COMPANY'),
 ('RMLA','RMLA_SEC1',
  N'RMLA Section I: Application Data','STATE'),
 ('RMLA','RMLA_SEC2',
  N'RMLA Section II: Closed Loan and MLO Data','STATE'),
 ('RMLA','RMLA_SEC3',
  N'RMLA Section III: Servicing Data','STATE'),
 ('SSSF','SSSF',
  N'Standard Servicer Supplemental Form','STATE'),
 ('FC','FC',
  N'Financial Condition','COMPANY')
) v(Comp, Sect, SName, Scope)
WHERE NOT EXISTS
      (SELECT 1 FROM gov.RegulatoryReportSection s
       WHERE s.RegulatoryReportId = @McrReportId
         AND s.SectionCode = v.Sect);

/* ------------------------------------------------------------
   6. Report inventory and initial certification
   ------------------------------------------------------------ */
DECLARE @PaigeId INT =
    (SELECT PartyId FROM gov.Party
     WHERE PartyName = 'Paige Justice'
       AND PartyTypeCode = 'PERSON');

IF NOT EXISTS (SELECT 1 FROM gov.ReportInventory
               WHERE ReportCode = 'PBI_SVC_GOV')
BEGIN
    INSERT INTO gov.ReportInventory
        (ReportCode, ReportName, ReportTypeCode,
         WorkspaceOrPath, SemanticModelName, OwnerPartyId,
         LoadBatchId)
    VALUES
        ('PBI_SVC_GOV',
         N'Flamingo Financials | Servicing Governance and '
         + N'Certified Analytics',
         'POWER_BI',
         N'PBIP: MortgageServicingGovernance (Git)',
         N'Mortgage Servicing Governance',
         @PaigeId, @LoadBatchId);
END

DECLARE @ReportInvId INT =
    (SELECT ReportInventoryId FROM gov.ReportInventory
     WHERE ReportCode = 'PBI_SVC_GOV');

IF NOT EXISTS (SELECT 1 FROM gov.Certification
               WHERE EntityTypeCode = 'REPORT'
                 AND EntityReference = 'PBI_SVC_GOV')
BEGIN
    INSERT INTO gov.Certification
        (EntityTypeCode, EntityId, EntityReference,
         CertificationStatusCode, CertificationNotes,
         LoadBatchId)
    VALUES
        ('REPORT', @ReportInvId, 'PBI_SVC_GOV',
         'NOT_CERTIFIED',
         N'Awaiting Phase 14 certification run: DQ blocking '
         + N'rules and reconciliation controls must pass.',
         @LoadBatchId);
END

/* ------------------------------------------------------------
   7. RACI role assignments (33)
      Owner + steward per system (20), technical steward
      on all systems (10), sponsor, certifier, regulatory
      owner (3).
   ------------------------------------------------------------ */
INSERT INTO gov.RoleAssignment
    (EntityTypeCode, EntityId, EntityReference,
     GovernanceRoleId, PartyId, RaciCode, LoadBatchId)
SELECT 'SOURCE_SYSTEM', ss.SourceSystemId,
       ss.SourceSystemCode, gr.GovernanceRoleId, p.PartyId,
       v.Raci, @LoadBatchId
FROM (VALUES
 ('BRD','DATA_OWNER','Marco Ibis','A'),
 ('BRD','DATA_STEWARD','Sofia Egret','R'),
 ('SVC','DATA_OWNER','Marco Ibis','A'),
 ('SVC','DATA_STEWARD','Sofia Egret','R'),
 ('VAL','DATA_OWNER','Marco Ibis','A'),
 ('VAL','DATA_STEWARD','Sofia Egret','R'),
 ('PAY','DATA_OWNER','Dana Heron','A'),
 ('PAY','DATA_STEWARD','Victor Teal','R'),
 ('DMS','DATA_OWNER','Omar Pelican','A'),
 ('DMS','DATA_STEWARD','Ruth Sandpiper','R'),
 ('INV','DATA_OWNER','Felix Crane','A'),
 ('INV','DATA_STEWARD','Ana Plover','R'),
 ('CRM','DATA_OWNER','Diego Kite','A'),
 ('CRM','DATA_STEWARD','Mira Bittern','R'),
 ('LOS','DATA_OWNER','Diego Kite','A'),
 ('LOS','DATA_STEWARD','Mira Bittern','R'),
 ('PPE','DATA_OWNER','Diego Kite','A'),
 ('PPE','DATA_STEWARD','Mira Bittern','R'),
 ('LIC','DATA_OWNER','Iris Whimbrel','A'),
 ('LIC','DATA_STEWARD','Mira Bittern','R'),
 ('BRD','TECHNICAL_STEWARD','Noah Curlew','R'),
 ('SVC','TECHNICAL_STEWARD','Noah Curlew','R'),
 ('PAY','TECHNICAL_STEWARD','Noah Curlew','R'),
 ('DMS','TECHNICAL_STEWARD','Noah Curlew','R'),
 ('INV','TECHNICAL_STEWARD','Noah Curlew','R'),
 ('VAL','TECHNICAL_STEWARD','Noah Curlew','R'),
 ('CRM','TECHNICAL_STEWARD','Noah Curlew','R'),
 ('LOS','TECHNICAL_STEWARD','Noah Curlew','R'),
 ('PPE','TECHNICAL_STEWARD','Noah Curlew','R'),
 ('LIC','TECHNICAL_STEWARD','Noah Curlew','R')
) v(SysCode, RoleCode, PartyName, Raci)
JOIN gov.SourceSystem ss
  ON ss.SourceSystemCode = v.SysCode
JOIN gov.GovernanceRole gr
  ON gr.RoleCode = v.RoleCode
JOIN gov.Party p
  ON p.PartyName = v.PartyName
 AND p.PartyTypeCode = 'PERSON'
WHERE NOT EXISTS
      (SELECT 1 FROM gov.RoleAssignment ra
       WHERE ra.EntityTypeCode = 'SOURCE_SYSTEM'
         AND ra.EntityId = ss.SourceSystemId
         AND ra.GovernanceRoleId = gr.GovernanceRoleId
         AND ra.PartyId = p.PartyId);

/* Executive sponsor on the enterprise governance domain */
INSERT INTO gov.RoleAssignment
    (EntityTypeCode, EntityId, EntityReference,
     GovernanceRoleId, PartyId, RaciCode, LoadBatchId)
SELECT 'DOMAIN', NULL, N'Enterprise Data Governance',
       gr.GovernanceRoleId, p.PartyId, 'A', @LoadBatchId
FROM gov.GovernanceRole gr
CROSS JOIN gov.Party p
WHERE gr.RoleCode = 'EXECUTIVE_SPONSOR'
  AND p.PartyName = 'Camille Flamingo'
  AND p.PartyTypeCode = 'PERSON'
  AND NOT EXISTS
      (SELECT 1 FROM gov.RoleAssignment ra
       WHERE ra.EntityTypeCode = 'DOMAIN'
         AND ra.EntityReference = N'Enterprise Data Governance'
         AND ra.GovernanceRoleId = gr.GovernanceRoleId
         AND ra.PartyId = p.PartyId);

/* Certifier on the Power BI report */
INSERT INTO gov.RoleAssignment
    (EntityTypeCode, EntityId, EntityReference,
     GovernanceRoleId, PartyId, RaciCode, LoadBatchId)
SELECT 'REPORT', @ReportInvId, 'PBI_SVC_GOV',
       gr.GovernanceRoleId, p.PartyId, 'A', @LoadBatchId
FROM gov.GovernanceRole gr
CROSS JOIN gov.Party p
WHERE gr.RoleCode = 'CERTIFIER'
  AND p.PartyName = 'Paige Justice'
  AND p.PartyTypeCode = 'PERSON'
  AND NOT EXISTS
      (SELECT 1 FROM gov.RoleAssignment ra
       WHERE ra.EntityTypeCode = 'REPORT'
         AND ra.EntityId = @ReportInvId
         AND ra.GovernanceRoleId = gr.GovernanceRoleId
         AND ra.PartyId = p.PartyId);

/* Regulatory owner on the MCR FV7 filing */
INSERT INTO gov.RoleAssignment
    (EntityTypeCode, EntityId, EntityReference,
     GovernanceRoleId, PartyId, RaciCode, LoadBatchId)
SELECT 'REGULATORY_REPORT', @McrReportId, 'MCR_FV7',
       gr.GovernanceRoleId, p.PartyId, 'A', @LoadBatchId
FROM gov.GovernanceRole gr
CROSS JOIN gov.Party p
WHERE gr.RoleCode = 'REGULATORY_OWNER'
  AND p.PartyName = 'Iris Whimbrel'
  AND p.PartyTypeCode = 'PERSON'
  AND NOT EXISTS
      (SELECT 1 FROM gov.RoleAssignment ra
       WHERE ra.EntityTypeCode = 'REGULATORY_REPORT'
         AND ra.EntityId = @McrReportId
         AND ra.GovernanceRoleId = gr.GovernanceRoleId
         AND ra.PartyId = p.PartyId);

/* ------------------------------------------------------------
   8. Change log entry
   ------------------------------------------------------------ */
IF NOT EXISTS
   (SELECT 1 FROM gov.ChangeLog
    WHERE EntityTypeCode = 'GOVERNANCE_PLATFORM'
      AND ChangeDescription LIKE N'Phase 2 core seed%')
BEGIN
    INSERT INTO gov.ChangeLog
        (EntityTypeCode, EntityReference, ChangeTypeCode,
         ChangeDescription, LoadBatchId)
    VALUES
        ('GOVERNANCE_PLATFORM', N'MortgageGovernance',
         'INSERT',
         N'Phase 2 core seed: 10 source systems, 8 roles, '
         + N'17 parties, 33 RACI assignments, 9 regulatory '
         + N'frameworks, MCR FV7 report with 6 sections, '
         + N'report inventory, initial certification record.',
         @LoadBatchId);
END

COMMIT;

EXEC audit.usp_CompleteLoadBatch
     @LoadBatchId = @LoadBatchId,
     @StatusCode  = 'SUCCESS';

PRINT 'Script 004 complete: governance core seed loaded '
    + '(batch ' + CAST(@LoadBatchId AS VARCHAR(10)) + ').';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    EXEC audit.usp_LogError
         @LoadBatchId = @LoadBatchId,
         @ContextInfo = N'004_gov_seed_core.sql';
    EXEC audit.usp_CompleteLoadBatch
         @LoadBatchId = @LoadBatchId,
         @StatusCode  = 'FAILED';
    THROW;
END CATCH
GO
