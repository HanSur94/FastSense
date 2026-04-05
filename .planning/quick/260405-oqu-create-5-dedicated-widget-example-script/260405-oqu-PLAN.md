---
phase: quick
plan: 260405-oqu
type: execute
wave: 1
depends_on: []
files_modified:
  - examples/example_widget_iconcard.m
  - examples/example_widget_chipbar.m
  - examples/example_widget_sparkline.m
  - examples/example_widget_divider.m
autonomous: true
requirements: []
must_haves:
  truths:
    - "Each example runs standalone after install.m"
    - "Each example demonstrates all data-binding modes of its widget"
    - "Header comments document all key properties"
  artifacts:
    - path: "examples/example_widget_iconcard.m"
      provides: "IconCardWidget standalone example"
    - path: "examples/example_widget_chipbar.m"
      provides: "ChipBarWidget standalone example"
    - path: "examples/example_widget_sparkline.m"
      provides: "SparklineCardWidget standalone example"
    - path: "examples/example_widget_divider.m"
      provides: "DividerWidget standalone example"
  key_links: []
---

<objective>
Create 4 dedicated example scripts for widgets that lack them: IconCardWidget, ChipBarWidget, SparklineCardWidget, and DividerWidget. (EventTimelineWidget already has examples/example_widget_timeline.m.)

Purpose: Complete the example coverage so every widget type has a runnable demo.
Output: 4 new example_widget_*.m files in examples/
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@examples/example_widget_number.m (header + structure reference)
@examples/example_widget_status.m (sensor + threshold data pattern)
@libs/Dashboard/IconCardWidget.m (properties: IconColor, StaticValue, ValueFcn, StaticState, Units, Format, SecondaryLabel; binding: Sensor > ValueFcn > StaticValue)
@libs/Dashboard/ChipBarWidget.m (properties: Chips cell array of structs with label, sensor, statusFcn, iconColor)
@libs/Dashboard/SparklineCardWidget.m (properties: StaticValue, ValueFcn, Units, Format, NSparkPoints, ShowDelta, DeltaFormat, SparkColor, SparkData)
@libs/Dashboard/DividerWidget.m (properties: Thickness, Color)
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create IconCardWidget, ChipBarWidget, SparklineCardWidget examples</name>
  <files>examples/example_widget_iconcard.m, examples/example_widget_chipbar.m, examples/example_widget_sparkline.m</files>
  <action>
Create three example scripts following the exact header/bootstrap pattern from example_widget_number.m:

1. **example_widget_iconcard.m** — Header lists all IconCardWidget properties. Create 2-3 sensors with thresholds. Show all binding modes:
   - Sensor-bound (auto state color from thresholds): one in alarm, one ok
   - ValueFcn returning scalar + explicit StaticState
   - StaticValue with custom IconColor [r g b] override
   - StaticValue with SecondaryLabel override
   - Include a fastsense widget below for visual context
   - Default position [1 1 6 2] per widget, arrange in a single row of 4-5 cards

2. **example_widget_chipbar.m** — Header lists ChipBarWidget properties and chip struct fields. Show:
   - ChipBar with statusFcn chips (mix of ok/warn/alarm/info/inactive)
   - ChipBar with sensor-bound chips (reuse sensors with thresholds so colors auto-derive)
   - ChipBar with explicit iconColor overrides on each chip
   - Each chipbar spans full width [1 row 24 1]; stack 3 bars vertically
   - Include fastsense widgets below for visual context

3. **example_widget_sparkline.m** — Header lists SparklineCardWidget properties. Create sensors. Show:
   - Sensor-bound (auto value + sparkline from Sensor.Y, auto units)
   - ValueFcn + explicit SparkData vector
   - StaticValue + SparkData with custom SparkColor and DeltaFormat
   - ShowDelta=false variant
   - Arrange as row of 4 cards [6 wide, 3 tall each]

Each script: `close all force; clear functions;` preamble, `projectRoot` + `install.m` bootstrap, rng(42), sensor creation with thresholds where needed, DashboardEngine build, render(), fprintf summary.
  </action>
  <verify>
    <automated>cd /Users/hannessuhr/FastPlot && for f in examples/example_widget_iconcard.m examples/example_widget_chipbar.m examples/example_widget_sparkline.m; do test -f "$f" && echo "OK: $f" || echo "MISSING: $f"; done</automated>
  </verify>
  <done>Three example files exist, each standalone with header comments, all widget binding modes demonstrated, consistent style with existing examples</done>
</task>

<task type="auto">
  <name>Task 2: Create DividerWidget example</name>
  <files>examples/example_widget_divider.m</files>
  <action>
Create **example_widget_divider.m** following the same pattern:

- Header comment listing DividerWidget properties (Thickness, Color)
- Same bootstrap preamble (close all, install.m)
- Build a dashboard that uses dividers as visual separators between content sections:
  - Row 1: Two number widgets
  - Row 2: Default divider (Thickness=1, theme color)
  - Row 3: Two more number widgets
  - Row 4: Thick divider (Thickness=3) with custom Color [0.8 0.2 0.2]
  - Row 5: Medium divider (Thickness=2) with a different custom color
- Create simple sensors for the number widgets so the dashboard has real content
- render() and fprintf summary showing widget count
  </action>
  <verify>
    <automated>cd /Users/hannessuhr/FastPlot && test -f examples/example_widget_divider.m && echo "OK" || echo "MISSING"</automated>
  </verify>
  <done>DividerWidget example exists, shows all Thickness levels and custom Color usage, consistent style</done>
</task>

</tasks>

<verification>
All 4 files exist in examples/ with consistent naming and header style.
</verification>

<success_criteria>
- 4 new example_widget_*.m files created
- Each is standalone (runs with just install.m)
- Each demonstrates all key properties/binding modes of its widget
- Header comment style matches existing examples (property list in header block)
</success_criteria>

<output>
After completion, create `.planning/quick/260405-oqu-create-5-dedicated-widget-example-script/260405-oqu-SUMMARY.md`
</output>
