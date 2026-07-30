/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_10_full_coverage_demo.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT (FULL SCHEMA)
   10 - Full-coverage exerciser (thin wrapper around mcr.usp_StageFullCoverageDemo)
   ----------------------------------------------------------------------------
   Requires 07_orchestration_procs.sql. Stages every submittable element +
   every list from the catalog and generates (@BlockOnError = 0 inside the
   proc; uniform demo values fail reconciles by design). Schema-coverage
   proof, not a filing path.
   ============================================================================ */
EXEC mcr.usp_StageFullCoverageDemo @FilingId = 9999, @StateCode = 'OK';
GO
