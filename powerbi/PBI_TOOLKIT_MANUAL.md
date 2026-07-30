# PBI Toolkit Manual

User manual for the current build: `pbi_toolkit.html`. Covers the batch Tabular Editor generators, theme pipeline, profiles, snippet vault, and data safety rules.

---

## 1. Where the tool lives

```
PRIMARY   pbi_toolkit.html
          Single self-contained file. Double-click to open in a browser.
          Works offline. No CDN, no install, no chat.

HOSTED    www.justiceinstallations.com/pbi_toolkit.html
          Same file uploaded to your site. Bookmark the www URL and
          ALWAYS use www (see section 12 for why).

STALE     https://pbi-toolkit.netlify.app
          Old build, pre-batch generators. Ignore it or ask for a
          redeploy in chat.
```

The file and the hosted copy do not share data. Each browser on each machine keeps its own saved data. JSON export/import is how data moves (sections 5 and 11).

---

## 2. 30-second orientation

```
1. Header: profile dropdown (placeholder set), theme toggle, gear (settings)
2. Main tabs: DAX, Time, PQ, Model, Visuals, Design, Tools, Learn, Mine
3. Pill row under the tabs: click a pill to SCROLL to that section.
   Pills do not filter. All sections of a tab are stacked on one page.
4. Search box: filters snippets inside every section, including yours
5. Every code block has a Copy button. Placeholders are already resolved
   using the active profile.
```

---

## 3. Placeholders and profiles

Built-in snippets use tokens instead of hardcoded names. The active profile decides what each token renders as:

```
{FACT}          Fact table              default: Sales
{MEASURE}       Numeric column          default: Amount
{DATE_TABLE}    Date dimension          default: DimDate
{DATE_COL}      Date column             default: Date
{CUSTOMER}      Customer dimension      default: DimCustomer
{CUSTKEY}       Customer key            default: CustomerKey
{PRODUCT}       Product dimension       default: DimProduct
```

Profile workflow per client:

```
1. Mine tab > Profiles > New
2. Name it after the client, fill in their real table/column names
3. Activate from the header dropdown
4. Every snippet and every generator prefill now uses that client's names
5. Export (Mine > Profiles > Export) after creating profiles:
   downloads pbi-profiles-YYYY-MM-DD.json
6. Import merges profiles from a backup file. The built-in Default
   profile can't be deleted or overwritten by import.
```

The gear icon edits the active profile's placeholders in place without leaving your current tab.

---

## 4. The batch Tabular Editor workflow

This is the core loop the Model tab is built around. Prerequisites: Tabular Editor 2 (free) or TE3, connected to your model via External Tools ribbon in Power BI Desktop.

### Step 1: Create the measures table (once per model)

```
Model tab > Measures Tbl section
1. Set table name (default _Measures)
2. Pick a format: DAX Table is fastest (paste in Desktop as new table)
3. Hide the placeholder column "_"
```

### Step 2: Batch generate measures

```
Model tab > Batch Measures section

1. Paste base measures, ONE PER LINE:

   Total Amount = SUM(FactSales[Amount])
   Order Count = COUNTROWS(FactSales)

   Rules: first "=" splits name from expression.
   Lines starting with // or # are ignored.

2. Tick variants. Each base measure gets each ticked variant:

   PY       {Base} PY       CALCULATE + SAMEPERIODLASTYEAR
   YoY      {Base} YoY      base minus PY          fmt +#,0;-#,0;0
   YoY %    {Base} YoY %    DIVIDE(delta, PY)      fmt +0.0%;-0.0%;0.0%
   YTD      {Base} YTD      TOTALYTD
   PYTD     {Base} PYTD     YTD shifted back a year
   MTD      {Base} MTD      TOTALMTD
   QTD      {Base} QTD      TOTALQTD
   R12M     {Base} R12M     DATESINPERIOD rolling 12 months

   YoY and YoY % auto-include PY. PYTD auto-includes YTD.
   The live counter shows total measures that will be generated.

3. Confirm Date Table / Date Column (prefilled from active profile)
   and Target Table (default _Measures).

4. Options:
   Overwrite existing        ON: existing measures get updated and
                             moved to the target table.
                             OFF: existing measures are left untouched.
   Folder per base measure   Each base + its variants share a
                             display folder named after the base.

5. Copy the TE C# Script output.

6. Tabular Editor > Advanced Scripting tab > paste > Run.
   Then Ctrl+S to write the changes back to the model.
```

The script is idempotent. Run it twice, nothing duplicates. It reports the processed count when done. The TMDL output toggle gives the same measure set as TMDL blocks for PBIP files instead.

### Step 3: Batch RLS

```
Model tab > RLS Batch section

One line per table permission:

   RoleName | Table | DAX filter expression

   RLS_East | DimCustomer | 'DimCustomer'[Region] = "East"
   RLS_East | DimProduct  | 'DimProduct'[Line] = "Retail"
   RLS_Dyn  | SecUserMap  | 'SecUserMap'[Email] = USERPRINCIPALNAME()

Repeat a role name to give one role multiple table filters.
Only the FIRST TWO pipes split the line, so pipes inside the DAX
(including ||) are safe.

Copy the C# script > TE Advanced Scripting > Run > Ctrl+S.
All roles created or updated in one pass, ModelPermission set to Read.

Dynamic mapping roles: set the mapping-to-dimension relationship to
"Apply security filter in both directions" or the filter never
reaches the fact table.

Test: Desktop > Modeling > View as > pick role.
Deploy members: Service > semantic model > Security.
```

### Step 4: Batch TMDL

```
Model tab > TMDL Batch section

One line per object:

   Table | M or C | Name | Expression | FormatString (M) or DataType (C)

   FactSales | M | Total Amount | SUM(FactSales[Amount]) | #,0
   FactSales | C | Amount Band  | IF(FactSales[Amount] > 1000, "High", "Low") | string

Output is grouped by table. These are PARTIAL table blocks: merge the
measure/column lines into existing .tmdl table files (PBIP) or paste
into TE3's TMDL view inside the right table.

EDGE CASE: if an expression contains || and you omit the 5th field,
the tail of the expression gets misread as the format. Always include
the 5th field when the expression contains ||.
```

---

## 5. My Snippets (personal vault)

```
Mine tab > My Snippets

New       Title, description, language (dax/m/tmdl/csharp), tags, code
Edit      Gear icon on the snippet
Delete    X icon, confirms first
Search    The global search box covers your snippets too

Export    Downloads pbi-snippets-YYYY-MM-DD.json
Import    Merges a backup file. Same-id snippets get overwritten.

Storage meter at the top of the section. Red warning at 80% of the
5 MB browser cap. Export and prune when you see it.
```

Write your snippets with placeholder tokens and they resolve per profile like the built-ins.

---

## 6. Theme pipeline (Design tab)

Sections run in workflow order: Palette first, Theme below it.

```
1. PALETTE section
   Pick a base color and a harmony mode. 12 swatches generate with
   WCAG contrast scores. Click any swatch to copy its hex.

2. Click "Send to Theme Builder"
   Pushes the 12 colors into the Theme section and scrolls you there.
   Green "Synced" banner confirms. Edit any swatch after to override.

3. THEME section
   - Light Theme / Dark Theme preset buttons set page background,
     text, good/bad colors, and visual card styling in one click
   - Font Family dropdown: Segoe UI is the safe default. Non-Segoe
     fonts skip the Semibold title variant because Power BI only
     ships Semibold for Segoe UI.
   - Reset button restores the 12 default data colors

4. Click "Download theme.json"
   Filename comes from the theme name, sanitized.

5. Power BI Desktop > View > Themes > Browse for themes > pick the file
```

The JSON covers data colors, text classes, page background, universal visual styles, slicers, cards, tables, and matrix formatting. Expect to manually tweak 3 to 5 visual-specific settings per report anyway; Power BI's theme engine doesn't expose everything.

---

## 7. Other generators

```
Date Table (PQ tab)         M-code date table. Start/end year, fiscal
                            start month, ISO weeks.
Field Params (Visuals)      Field parameter DAX from a measure list.
Conditional Fmt (Visuals)   Conditional formatting JSON from rules.
```

---

## 8. Reference tabs

```
DAX      Basics, Filters, Ranking, Stats, Financial, Advanced,
         Patterns, Visual Calcs
Time     Standard, Rolling, Fiscal, Calc Groups
PQ       Date Table generator, M transform library
Visuals  Format reference, CF library, Tooltips, Bookmarks,
         Visual Picker
Tools    External tools guide, TE C# script library, BPA rules
Learn    2026 features, Workflows, PL-300, Licensing, Performance,
         Troubleshooting, Shortcuts
```

Dependency tags: financial and time measures show clickable [Dep] tags under the code. Clicking navigates to that measure's section.

---

## 9. Search behavior

```
- Case-insensitive substring match. No operators, no regex.
- Hits title, description, code body, and tags.
- Filters within each section; empty sections collapse to their header.
- Clicking a dependency tag auto-fills the search box.
```

---

## 10. Updating the tool

```
1. Get the new pbi_toolkit.html from chat
2. DELETE old copies from Downloads first (Windows renames duplicate
   downloads to "file (1).html" and you will open the wrong one)
3. Replace the file on your website if hosted
4. Hard refresh the hosted page: Ctrl+Shift+R
5. Your saved data survives updates. It lives in the browser, not
   the file.
```

---

## 11. Backup discipline

```
WHAT       Profiles (Mine > Profiles > Export)
           Snippets (Mine > My Snippets > Export)
WHEN       After any session where you added or changed either.
           Monthly minimum.
WHERE      OneDrive / Drive / repo. Anywhere that is not only
           the browser.
RESTORE    Import buttons in the same sections. Imports merge.
```

Auto-save handles day-to-day persistence. The JSON exports exist because "Clear browsing data" in any browser wipes localStorage without asking which sites matter to you.

---

## 12. Data storage rules (read once, avoid pain)

```
1. LOCAL FILE: do not move or rename the HTML file after you start
   using it. Chrome/Edge key local-file storage to the file path.
   Moving the file orphans your data. If you must move it:
   Export both JSONs > move > Import.

2. HOSTED: always use ONE exact URL. www.justiceinstallations.com and
   justiceinstallations.com are different storage origins. Alternate
   between them and your data appears to vanish (it is split across
   two stores). Standardize on www.

3. Hosted beats local for durability: on your domain, storage is keyed
   to the domain, so you can rename or move the file on the server
   freely without losing data.

4. Different browsers = different data. Edge and Chrome on the same
   machine do not share.

5. The Copy buttons need clipboard permission. Browsers grant it
   automatically for user-initiated clicks; if copy ever fails on the
   hosted version, check the site permission in the address bar.
```

---

## 13. Known limitations

```
- Favorites (stars) reset per session. Use tags on your own snippets
  for anything you need to find again.
- TMDL Batch: the || edge case in section 4, step 4.
- Netlify site is a stale pre-batch build.
- Custom fonts (JetBrains Mono, Manrope) load from Google Fonts when
  online. Offline, the tool falls back to system fonts. Cosmetic only.
- Theme JSON cannot control every Power BI visual property. Some
  per-visual manual formatting is normal.
- The generated TE C# targets TE2-compatible syntax and also runs
  in TE3. It does not use TE3-only APIs.
```
