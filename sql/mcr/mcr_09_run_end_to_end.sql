/* ============================================================
   GENERATED FILE. Do not hand-edit.
   Converted from MCR_Toolkit_09_run_end_to_end.sql
   Target: MortgageGovernance on Azure SQL Database.
   Schemas: mcr (engine), mcrstg (staging, to retire),
   mcrpbi (toolkit views, uncertified).
   No USE. No CREATE DATABASE. No three-part names.
   Connect directly to MortgageGovernance.
   ============================================================ */

/* ============================================================================
   MCR FV7 SQL TOOLKIT (FULL SCHEMA)
   09 - End-to-end driver (thin wrapper around mcr.usp_RunFilingPipeline)
   ----------------------------------------------------------------------------
   Requires 07_orchestration_procs.sql. Quarterly operation is one EXEC:
   load -> validate -> variance -> generate, gated on validation ERRORs.
   Save the McrFilingText result as .xml (UTF-8) and schema-validate before
   NMLS upload.
   ============================================================================ */
DECLARE @Xml NVARCHAR(MAX);
EXEC mcr.usp_RunFilingPipeline
     @FilingId     = 2026001,
     @BlockOnError = 1,
     @RunVariance  = 1,
     @Reload       = 1,
     @Xml          = @Xml OUTPUT;
GO
