/* ============================================================
   Flamingo Mortgage Governance
   Tabular Editor 2 C# script: build the measure set.

   HOW TO RUN
   Tabular Editor -> C# Script tab -> paste -> F5.
   Then File -> Save (or Ctrl+S) to write back to the model.
   Back in Power BI Desktop, click Refresh now if prompted.

   Safe to re-run. Existing measures of the same name are
   overwritten, not duplicated.

   Two of the four tables have column lists I have not seen
   directly. Every measure is guarded: if a column is missing
   the measure is skipped and named in the output rather than
   throwing. Read the output before saving.
   ============================================================ */

var created = new List<string>();
var skipped = new List<string>();

// --- helpers -------------------------------------------------

Func<string, string, bool> Has = (t, c) =>
{
    var tab = Model.Tables.FirstOrDefault(x => x.Name == t);
    if (tab == null) return false;
    return tab.Columns.Any(x => x.Name == c);
};

Table mt = Model.Tables.FirstOrDefault(x => x.Name == "_Measures");
if (mt == null)
{
    Error("Table '_Measures' not found. Create it first.");
    return;
}

Action<string, string, string, string, string, string>
Add = (name, dax, folder, format, desc, need) =>
{
    // need is "Table|Col1,Col2" or "" for no dependency
    if (need != "")
    {
        var parts = need.Split('|');
        var tbl = parts[0];
        foreach (var c in parts[1].Split(','))
        {
            if (!Has(tbl, c))
            {
                skipped.Add(name + "  (missing " + tbl
                            + "[" + c + "])");
                return;
            }
        }
    }

    var existing = mt.Measures
        .FirstOrDefault(x => x.Name == name);
    if (existing != null) existing.Delete();

    var m = mt.AddMeasure(name, dax, folder);
    if (format != "") m.FormatString = format;
    m.Description = desc;
    created.Add(name);
};

// --- Certification -------------------------------------------

Add("Filing Certification Status",
    @"MAX ( 'Data Product'[FilingCertificationStatus] )",
    "Certification", "",
    "Certification status of the latest governed MCR filing. "
    + "Source: pbi.vw_McrDataProduct.",
    "Data Product|FilingCertificationStatus");

Add("Product Certification Status",
    @"MAX ( 'Data Product'[ProductCertificationStatus] )",
    "Certification", "",
    "Certification status of the MCR FV7 data product. "
    + "Certifies the metadata layer, not any filing.",
    "Data Product|ProductCertificationStatus");

Add("Blocking Control Failures",
    @"MAX ( 'Data Product'[FilingBlockingFailures] )",
    "Certification", "#,0",
    "Count of blocking reconciliation controls failing at "
    + "the filing period end. Any value above zero blocks "
    + "filing certification.",
    "Data Product|FilingBlockingFailures");

Add("Validation Errors",
    @"MAX ( 'Data Product'[FilingValidationErrors] )",
    "Certification", "#,0",
    "Count of ERROR-severity findings from MCR submission "
    + "validation.",
    "Data Product|FilingValidationErrors");

// --- Coverage ------------------------------------------------

Add("Governed FV7 Items",
    @"MAX ( 'Data Product'[TotalFv7Items] )",
    "Coverage", "#,0",
    "Total governed MCR FV7 line items in "
    + "gov.RegulatoryReportItem.",
    "Data Product|TotalFv7Items");

Add("Lineage Eligible Items",
    @"MAX ( 'Data Product'[LineageEligibleItems] )",
    "Coverage", "#,0",
    "Items eligible for source lineage. Excludes "
    + "NMLS-calculated, annotated, aliased, deprecated and "
    + "deferred items, each of which carries a stated "
    + "reason.",
    "Data Product|LineageEligibleItems");

Add("Traceable Items",
    @"MAX ( 'Data Product'[TraceableToSourceItems] )",
    "Coverage", "#,0",
    "Items traceable to a source column today.",
    "Data Product|TraceableToSourceItems");

Add("Coverage Items",
    @"SUM ( 'Coverage Summary'[Items] )",
    "Coverage", "#,0",
    "Items in the selected coverage classification.",
    "Coverage Summary|Items");

Add("Coverage Traceable Items",
    @"SUM ( 'Coverage Summary'[TraceableItems] )",
    "Coverage", "#,0",
    "Traceable items in the selected coverage "
    + "classification. Equals Coverage Items only for "
    + "SUPPORTED_NOW.",
    "Coverage Summary|TraceableItems");

Add("Accountable Stewards",
    @"SUM ( 'Coverage Summary'[AccountableStewards] )",
    "Coverage", "#,0",
    "Distinct stewards accountable for the selected "
    + "classification.",
    "Coverage Summary|AccountableStewards");

// --- Filing Tie-Out ------------------------------------------

Add("Governance Value",
    @"SUM ( 'Filing Tie-Out'[GovernanceValueFiledBasis] )",
    "Filing Tie-Out", "#,0",
    "Governance-computed value on the whole-dollar filed "
    + "basis. Computed independently of the filing engine.",
    "Filing Tie-Out|GovernanceValueFiledBasis");

Add("Filed Value",
    @"SUM ( 'Filing Tie-Out'[FiledValue] )",
    "Filing Tie-Out", "#,0",
    "Value as submitted in the MCR filing.",
    "Filing Tie-Out|FiledValue");

Add("Filing Variance",
    @"SUM ( 'Filing Tie-Out'[Variance] )",
    "Filing Tie-Out", "#,0;(#,0)",
    "Filed value less governance value. Negative means the "
    + "filing understates the governed position.",
    "Filing Tie-Out|Variance");

Add("Rounding Effect",
    @"SUM ( 'Filing Tie-Out'[RoundingEffect] )",
    "Filing Tie-Out", "#,0.00;(#,0.00)",
    "Effect of whole-dollar conversion. Runs in both "
    + "directions, which is why the conversion is ROUND and "
    + "not truncation.",
    "Filing Tie-Out|RoundingEffect");

Add("Lines Matched",
    @"CALCULATE (
    COUNTROWS ( 'Filing Tie-Out' ),
    'Filing Tie-Out'[TieOutStatus] = ""MATCH""
)",
    "Filing Tie-Out", "#,0",
    "Line item and measure rows where governance and filed "
    + "values agree exactly.",
    "Filing Tie-Out|TieOutStatus");

Add("Lines With Variance",
    @"CALCULATE (
    COUNTROWS ( 'Filing Tie-Out' ),
    'Filing Tie-Out'[TieOutStatus] = ""VARIANCE""
)",
    "Filing Tie-Out", "#,0",
    "Rows where governance and filed values disagree.",
    "Filing Tie-Out|TieOutStatus");

Add("Lines Absent From Filing",
    @"CALCULATE (
    COUNTROWS ( 'Filing Tie-Out' ),
    'Filing Tie-Out'[TieOutStatus] = ""ABSENT FROM FILING""
)",
    "Filing Tie-Out", "#,0",
    "Rows with no filed value. Correct for NMLS-calculated "
    + "lines, a defect for a zero-population detail line.",
    "Filing Tie-Out|TieOutStatus");

Add("Tie-Out Match Rate",
    @"VAR Total = COUNTROWS ( 'Filing Tie-Out' )
VAR Matched =
    CALCULATE (
        COUNTROWS ( 'Filing Tie-Out' ),
        'Filing Tie-Out'[TieOutStatus] = ""MATCH""
    )
RETURN
    DIVIDE ( Matched, Total )",
    "Filing Tie-Out", "0.0%",
    "Share of tie-out rows matching exactly. Read beside "
    + "Filing Certification Status, never alone.",
    "Filing Tie-Out|TieOutStatus");

// --- Exceptions ----------------------------------------------

Add("Open Exceptions",
    @"COUNTROWS ( 'Exception Register' )",
    "Exceptions", "#,0",
    "Data quality exceptions routed from MCR filing "
    + "findings.",
    "");

Add("Overdue Exceptions",
    @"SUM ( 'Exception Register'[OverdueFlag] )",
    "Exceptions", "#,0",
    "Exceptions past their due date.",
    "Exception Register|OverdueFlag");

Add("Blocking Exceptions",
    @"SUM ( 'Exception Register'[BlockingFlag] )",
    "Exceptions", "#,0",
    "Exceptions raised by a blocking rule. MCR rules are "
    + "non-blocking by design so a filing finding cannot "
    + "decertify the servicing report.",
    "Exception Register|BlockingFlag");

// --- tidy ----------------------------------------------------

var dummy = mt.Columns.FirstOrDefault(c => c.Name == "Column1");
if (dummy != null) dummy.IsHidden = true;

foreach (var t in Model.Tables)
    foreach (var c in t.Columns)
        if (c.Name.EndsWith("Id") || c.Name.EndsWith("Key"))
            c.IsHidden = true;

// --- report --------------------------------------------------

var sb = new System.Text.StringBuilder();
sb.AppendLine("CREATED " + created.Count);
foreach (var n in created) sb.AppendLine("  " + n);
sb.AppendLine();
sb.AppendLine("SKIPPED " + skipped.Count);
foreach (var n in skipped) sb.AppendLine("  " + n);
sb.ToString().Output();
