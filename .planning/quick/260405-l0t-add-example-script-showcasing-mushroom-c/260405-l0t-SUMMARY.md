---
phase: quick
plan: 260405-l0t
subsystem: examples
tags: [dashboard, mushroom-cards, iconcard, chipbar, sparkline, example]
dependency_graph:
  requires: [libs/Dashboard/IconCardWidget.m, libs/Dashboard/ChipBarWidget.m, libs/Dashboard/SparklineCardWidget.m]
  provides: [examples/example_mushroom_cards.m]
  affects: []
tech_stack:
  added: []
  patterns: [sensor-binding, static-value, callback-valuefcn, sparkline-history]
key_files:
  created: [examples/example_mushroom_cards.m]
  modified: []
decisions:
  - "Used dark theme to contrast with example_dashboard_advanced.m light theme, making icon circles visually distinct"
  - "ChipBarWidget constructed manually then d.addWidget(w) to demonstrate direct Chips property assignment pattern"
  - "SparklineCardWidget StaticValue+SparkData example uses cumsum(randn) history to guarantee non-trivial delta arrow"
metrics:
  duration: 4min
  completed: 2026-04-05
  tasks_completed: 1
  files_changed: 1
---

# Quick Task 260405-l0t: Add Example Script Showcasing Mushroom Card Widgets — Summary

**One-liner:** Runnable 242-line MATLAB example demonstrating all three mushroom card widgets (IconCardWidget, ChipBarWidget, SparklineCardWidget) with sensor binding, static values, ValueFcn callbacks, and all StaticState variants.

## Objective

Create a complete, self-contained example script at `examples/example_mushroom_cards.m` that showcases all three new mushroom card widget types with practical usage patterns.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create example_mushroom_cards.m | c32b2aa | examples/example_mushroom_cards.m |

## What Was Built

`examples/example_mushroom_cards.m` (242 lines) — a dark-themed dashboard example with:

**Row 1 — IconCardWidget (3 cards):**
- Sensor-bound card (T-401 temperature, state auto-derived from threshold rules)
- StaticValue + explicit StaticState 'ok' + custom IconColor `[0.2 0.8 0.4]` override
- ValueFcn returning `struct('value', 67.3, 'unit', '%')` with StaticState 'warn'

**Row 3 — ChipBarWidget (full width, 6 chips):**
- 2 sensor-bound chips (sTemp, sPress)
- 2 statusFcn chips (Pump ok, Fan warn)
- 1 statusFcn chip with alarm state (Network)
- 1 fixed-color chip (Custom, purple `[0.4 0.2 0.9]`)

**Row 4 — SparklineCardWidget (3 cards):**
- Sensor-bound with 80-pt tail and custom SparkColor `[1 0.4 0.2]`
- StaticValue + SparkData (cumsum history) with ShowDelta and DeltaFormat '%+.0f'
- Sensor-bound pressure with 50-pt NSparkPoints and ShowDelta enabled

**Row 7 — Divider separator**

**Row 8 — Three more IconCardWidget states:**
- StaticState 'alarm' (Fire Alarm), 'info' (Firmware v3.2), 'inactive' (Offline)

## Verification

- File exists: `examples/example_mushroom_cards.m` — 242 lines (min_lines: 100 — PASS)
- Contains all three widget type strings: 'iconcard', 'chipbar', 'sparkline' — PASS
- No lines exceed 160 characters — PASS
- Uses DashboardEngine with render() call — PASS
- Follows example_dashboard_advanced.m style: header comment block, install() bootstrap, rng(42), sensor setup, render, fprintf summary — PASS

## Deviations from Plan

None — plan executed exactly as written. ChipBarWidget `addWidget(w)` pattern matched plan spec. All property names verified against source widget files before writing.

## Self-Check: PASSED

- `examples/example_mushroom_cards.m` exists: FOUND
- Commit c32b2aa exists: FOUND
