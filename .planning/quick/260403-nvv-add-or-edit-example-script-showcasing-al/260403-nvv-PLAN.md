---
phase: quick
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - examples/example_dashboard_advanced.m
  - examples/run_all_examples.m
autonomous: true
requirements: []
must_haves:
  truths:
    - "Script runs without error from a clean MATLAB session"
    - "All 9 new features from phases 01-08 are exercised in the script"
    - "run_all_examples.m includes the new script"
  artifacts:
    - path: "examples/example_dashboard_advanced.m"
      provides: "Comprehensive advanced dashboard example"
      min_lines: 120
    - path: "examples/run_all_examples.m"
      provides: "Updated example runner with new entry"
  key_links:
    - from: "examples/example_dashboard_advanced.m"
      to: "libs/Dashboard/DashboardEngine.m"
      via: "DashboardEngine constructor and addPage/switchPage/addWidget/addCollapsible/save"
      pattern: "DashboardEngine\\("
---

<objective>
Create a comprehensive example script `examples/example_dashboard_advanced.m` that demonstrates all new dashboard features added in phases 01-08 (multi-page navigation, widget info tooltips, detachable widgets, DividerWidget, CollapsibleWidget convenience, Y-axis limits, GroupWidget modes, JSON save/load roundtrip with multi-page, and InfoFile). Add it to `run_all_examples.m`.

Purpose: Give users a single reference script showing every advanced dashboard feature in action.
Output: One new example script plus updated example runner.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@examples/example_dashboard_all_widgets.m (reference for style, sensor setup, widget patterns)
@examples/example_dashboard_groups.m (reference for GroupWidget modes)
@examples/example_dashboard_engine.m (reference for save/load pattern)
@examples/example_dashboard_info.m (reference for InfoFile usage)
@examples/run_all_examples.m (add new entry)
@libs/Dashboard/DashboardEngine.m (API reference)
@libs/Dashboard/DashboardPage.m (addPage API)
@libs/Dashboard/DividerWidget.m (divider API)
@libs/Dashboard/FastSenseWidget.m (YLimits property)
@libs/Dashboard/DashboardWidget.m (Description property for tooltips)
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create example_dashboard_advanced.m</name>
  <files>examples/example_dashboard_advanced.m</files>
  <action>
Create `examples/example_dashboard_advanced.m` following the established example script conventions:

**Header block:**
- Standard close/clear/install preamble matching other examples
- Cell-mode sections (`%%`) for each feature group
- Comprehensive header comment listing all 9 features demonstrated

**Data setup section:**
- Use `rng(42)` for reproducibility
- Generate 10000-point time series (24h) for 2-3 sensors
- Create Sensor objects with StateChannels and ThresholdRules (follow example_dashboard_all_widgets.m pattern)

**Dashboard construction — Page 1 "Overview":**
- `d = DashboardEngine('Advanced Dashboard Demo', 'Theme', 'dark', 'InfoFile', fullfile(projectRoot, 'examples', 'example_dashboard_info.md'))` — demonstrates InfoFile (feature 9)
- `d.addPage('Overview')` — first page (feature 1)
- Add a FastSenseWidget with `'Sensor', s1, 'YLimits', [0 100], 'Description', 'Primary sensor with fixed Y-axis range'` — demonstrates YLimits (feature 6) and Description tooltip (feature 2). Position: `[1 1 24 4]`
- Add a DividerWidget: `d.addWidget('divider', 'Position', [1 5 24 1])` — demonstrates DividerWidget (feature 4)
- Add a row of NumberWidget + GaugeWidget + StatusWidget below the divider, each with `'Description'` tooltips
- Add a collapsible group: `d.addCollapsible('Sensor Details', {child1, child2}, 'Position', [1 8 24 4])` where children are a TableWidget and TextWidget — demonstrates CollapsibleWidget convenience (feature 5)

**Dashboard construction — Page 2 "Analysis":**
- `d.addPage('Analysis')` then `d.switchPage(2)` — demonstrates page switching (feature 1)
- Add a GroupWidget in tabbed mode: `d.addWidget('group', 'Title', 'Charts', 'Mode', 'tabbed', 'Children', {child1, child2}, 'Position', [1 1 24 6])` with BarChartWidget and HistogramWidget tabs — demonstrates GroupWidget tabbed mode (feature 7)
- Add a second FastSenseWidget with `'Description'` tooltip and `'YLimits'`
- Add a custom-styled DividerWidget: `d.addWidget('divider', 'Thickness', 2, 'Color', [0.8 0.2 0.2], 'Position', [1 8 24 1])` — demonstrates custom divider styling

**Render and demonstrate detach (feature 3):**
- `d.render()` then add a comment noting the "^" detach button visible in each widget header
- Add `fprintf` output explaining the detach feature for users reading console

**Save/load roundtrip (feature 8):**
- `jsonPath = fullfile(tempdir, 'advanced_dashboard_demo.json')`
- `d.save(jsonPath)` then `d2 = DashboardEngine.load(jsonPath)`
- `fprintf` confirming roundtrip success with page count
- Clean up temp file

**Footer:**
- `fprintf` summary of all 9 features demonstrated
- Comment listing each feature with a brief description

Ensure all widget positions use the 24-column grid and do not overlap. Use realistic position values that create a clean layout.
  </action>
  <verify>
    <automated>cd /Users/hannessuhr/FastPlot && grep -c 'addPage\|addCollapsible\|DividerWidget\|divider\|YLimits\|Description\|InfoFile\|switchPage\|\.save\|\.load' examples/example_dashboard_advanced.m | xargs test 9 -le</automated>
  </verify>
  <done>Script exists with all 9 features exercised: multi-page (addPage+switchPage), tooltips (Description), detachable (comment/fprintf), DividerWidget (two instances), CollapsibleWidget (addCollapsible), YLimits, GroupWidget tabbed mode, JSON save/load, InfoFile</done>
</task>

<task type="auto">
  <name>Task 2: Add to run_all_examples.m</name>
  <files>examples/run_all_examples.m</files>
  <action>
Add `example_dashboard_advanced` to the `examples` cell array in `run_all_examples.m`. Insert it after the `example_mixed_tiles` entry (last current entry) with the description string: `'Advanced dashboard: multi-page, tooltips, detach, dividers, collapsible, YLimits, save/load'`.

The new line should be:
```
'example_dashboard_advanced', 'Advanced dashboard: multi-page, tooltips, detach, dividers, collapsible, YLimits, save/load'
```
  </action>
  <verify>
    <automated>cd /Users/hannessuhr/FastPlot && grep 'example_dashboard_advanced' examples/run_all_examples.m</automated>
  </verify>
  <done>run_all_examples.m includes the new example_dashboard_advanced entry</done>
</task>

</tasks>

<verification>
- `grep -c 'addPage' examples/example_dashboard_advanced.m` returns >= 2 (two pages)
- `grep -c 'Description' examples/example_dashboard_advanced.m` returns >= 3 (multiple tooltips)
- `grep 'example_dashboard_advanced' examples/run_all_examples.m` finds the entry
- Script follows standard preamble pattern (close all force; clear functions; install)
</verification>

<success_criteria>
- example_dashboard_advanced.m exists and demonstrates all 9 new features from phases 01-08
- Each feature is clearly labeled with a cell-mode section comment
- Script follows existing example conventions (preamble, rng, realistic data, 24-col grid)
- run_all_examples.m updated with the new entry
</success_criteria>

<output>
After completion, create `.planning/quick/260403-nvv-add-or-edit-example-script-showcasing-al/260403-nvv-SUMMARY.md`
</output>
