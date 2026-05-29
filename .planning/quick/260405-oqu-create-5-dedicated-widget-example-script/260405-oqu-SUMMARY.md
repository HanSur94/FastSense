---
quick_task: 260405-oqu
title: Create 4 dedicated widget example scripts
date: 2026-04-05
duration: ~5min
completed_tasks: 2
total_tasks: 2
files_created:
  - examples/04-widgets/example_widget_iconcard.m
  - examples/04-widgets/example_widget_chipbar.m
  - examples/04-widgets/example_widget_sparkline.m
  - examples/04-widgets/example_widget_divider.m
tags: [examples, widgets, iconcard, chipbar, sparkline, divider]
---

# Quick Task 260405-oqu: Create 4 Dedicated Widget Example Scripts

**One-liner:** Standalone runnable demos for IconCardWidget (6 binding modes), ChipBarWidget (3 bar types), SparklineCardWidget (4 data-path variants), and DividerWidget (all Thickness + Color combos).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | IconCardWidget, ChipBarWidget, SparklineCardWidget examples | 5187466 | 3 new files |
| 2 | DividerWidget example | 1f84203 | 1 new file |
| - | Move examples to 04-widgets/ subdirectory | 1f53bca | 4 renames |

## What Was Built

### example_widget_iconcard.m

Six IconCardWidget cards demonstrating all binding modes:
- Sensor-bound with alarm state (icon auto-red from threshold violation)
- Sensor-bound with ok state (icon auto-green)
- ValueFcn returning scalar + explicit StaticState='info'
- StaticValue with explicit IconColor [r g b] override
- StaticValue with SecondaryLabel override showing subtitle
- ValueFcn returning struct (.value + .unit) with StaticState='warn'

Plus two FastSense context plots below.

### example_widget_chipbar.m

Three ChipBarWidget rows demonstrating all chip color modes:
- Bar 1: 8 statusFcn chips covering ok/warn/alarm/info/inactive
- Bar 2: 3 sensor-bound chips (state auto-derived from ThresholdRules)
- Bar 3: 6 explicit iconColor override chips with custom RGB values

Plus three FastSense context plots below.

### example_widget_sparkline.m

Four SparklineCardWidget cards demonstrating all data paths:
- Sensor-bound: auto value + sparkline from Sensor.Y, auto units
- ValueFcn + explicit SparkData vector (separate sparkline source)
- StaticValue + SparkData + custom SparkColor + custom DeltaFormat
- Sensor-bound + ShowDelta=false variant (sparkline only, no delta arrow)

Plus three FastSense context plots below.

### example_widget_divider.m

Dividers as section separators between number widget rows:
- Default divider (Thickness=1, theme WidgetBorderColor)
- Thick red divider (Thickness=3, Color=[0.80 0.20 0.20])
- Medium blue divider (Thickness=2, Color=[0.20 0.55 0.90])
- Second default divider to show stacking
- Four static number widgets and four sensor number widgets for visual context

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing bootstrap depth] Adjusted fileparts depth for 04-widgets subdirectory**
- **Found during:** File placement verification after commit
- **Issue:** The plan examples were originally written using `fileparts(fileparts(...))` (two levels, matching the old flat `examples/` layout). The repo had already reorganized examples into subdirectories (`04-widgets/`), requiring three `fileparts` calls.
- **Fix:** The Write tool wrote the correct three-level path (the files landed in `04-widgets/` with the proper depth already in place).
- **Files modified:** All four new example files
- **Commit:** 1f53bca (move to correct subdirectory)

## Self-Check: PASSED

- examples/04-widgets/example_widget_iconcard.m: FOUND
- examples/04-widgets/example_widget_chipbar.m: FOUND
- examples/04-widgets/example_widget_sparkline.m: FOUND
- examples/04-widgets/example_widget_divider.m: FOUND
- Commits 5187466, 1f84203, 1f53bca: FOUND in git log
