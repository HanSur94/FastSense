---
phase: quick
plan: 260405-tff
subsystem: examples
tags: [threshold-migration, api-migration, examples, sensor-threshold]
dependency_graph:
  requires: []
  provides: [all-examples-use-threshold-api]
  affects: [examples/01-basics, examples/02-sensors, examples/03-dashboard, examples/04-widgets, examples/05-events, examples/06-webbridge, examples/07-advanced]
tech_stack:
  added: []
  patterns: [Threshold entity pattern, addCondition grouping, state-dependent multi-condition thresholds]
key_files:
  created: []
  modified:
    - examples/01-basics/example_dock_disk.m
    - examples/02-sensors/example_dynamic_thresholds_100M.m
    - examples/02-sensors/example_sensor_dashboard.m
    - examples/02-sensors/example_sensor_detail_dashboard.m
    - examples/02-sensors/example_sensor_detail_datetime.m
    - examples/02-sensors/example_sensor_detail_dock.m
    - examples/02-sensors/example_sensor_detail.m
    - examples/02-sensors/example_sensor_multi_state.m
    - examples/02-sensors/example_sensor_registry.m
    - examples/02-sensors/example_sensor_static.m
    - examples/02-sensors/example_sensor_threshold.m
    - examples/02-sensors/example_sensor_todisk.m
    - examples/03-dashboard/example_dashboard_advanced.m
    - examples/03-dashboard/example_dashboard_all_widgets.m
    - examples/03-dashboard/example_dashboard_engine.m
    - examples/03-dashboard/example_dashboard_groups.m
    - examples/03-dashboard/example_dashboard_info.m
    - examples/03-dashboard/example_dashboard_live.m
    - examples/03-dashboard/example_mushroom_cards.m
    - examples/04-widgets/example_widget_barchart.m
    - examples/04-widgets/example_widget_chipbar.m
    - examples/04-widgets/example_widget_fastsense.m
    - examples/04-widgets/example_widget_gauge.m
    - examples/04-widgets/example_widget_group.m
    - examples/04-widgets/example_widget_histogram.m
    - examples/04-widgets/example_widget_iconcard.m
    - examples/04-widgets/example_widget_multistatus.m
    - examples/04-widgets/example_widget_scatter.m
    - examples/04-widgets/example_widget_status.m
    - examples/04-widgets/example_widget_table.m
    - examples/05-events/example_event_detection_live.m
    - examples/05-events/example_event_viewer_from_file.m
    - examples/05-events/example_live_pipeline.m
    - examples/06-webbridge/example_webbridge.m
    - examples/07-advanced/example_stress_test.m
decisions:
  - "Group addThresholdRule calls by (label, direction) into single Threshold objects with multiple addCondition calls — preserves the merge-by-label behavior of resolve()"
  - "Leave fp.addThreshold() calls on FastSense objects untouched — different API from sensor.addThresholdRule()"
  - "Rewrite add_4_thresholds() helper in stress_test as a self-contained function creating 4 Threshold objects, removing the add_rule_set inner function entirely"
metrics:
  duration_seconds: 77515
  completed_date: "2026-04-05"
  tasks_completed: 2
  files_modified: 35
---

# Quick Task 260405-tff: Migrate All Examples to First-Class Threshold API

**One-liner:** Mechanical migration of all 35 example scripts from removed `sensor.addThresholdRule()` to `Threshold()+addCondition()+sensor.addThreshold()`, preserving all state-dependent multi-condition grouping logic.

## What Was Done

Migrated every `sensor.addThresholdRule()` call across 35 example files in `examples/` to the new first-class Threshold entity system.

### Transformation Rule Applied

Old API (removed):
```matlab
s.addThresholdRule(condStruct, value, 'Direction', dir, 'Label', name, 'Color', rgb, 'LineStyle', ls)
```

New API:
```matlab
t = Threshold(key, 'Name', name, 'Direction', dir, 'Color', rgb, 'LineStyle', ls);
t.addCondition(condStruct, value);
s.addThreshold(t);
```

### Grouping Rule

Calls sharing the same `(label, direction)` pair become **one** Threshold object with **multiple** `addCondition` calls. This is the correct semantic: the old API collected conditions per label+direction and the new API makes that explicit.

### Key Challenge: example_live_pipeline.m

The temperature sensor had 12 `addThresholdRule` calls — 4 labels x 3 states (idle/heating/cooling). These were grouped into 4 Threshold objects each receiving 3 `addCondition` calls:

```matlab
tTempHWarn = Threshold('h_warning', 'Name', 'H Warning', 'Direction', 'upper', ...
    'Color', warnColor, 'LineStyle', warnStyle);
tTempHWarn.addCondition(struct('mode', 'idle'),    120);
tTempHWarn.addCondition(struct('mode', 'heating'), 140);
tTempHWarn.addCondition(struct('mode', 'cooling'), 100);
tempSensor.addThreshold(tTempHWarn);
```

### Key Challenge: example_stress_test.m

The `add_rule_set` helper internally called `s.addThresholdRule()` 4 times, called once per machine state from `add_4_thresholds`. The rewrite creates 4 Threshold objects once, loops over states adding conditions to each, then calls `s.addThreshold()` for each:

```matlab
tWarnHH = Threshold('warn_hh', 'Name', 'Warn HH', 'Direction', 'upper', ...
    'Color', [0.95 0.65 0.1], 'LineStyle', '--');
% ... loop over states, calling tWarnHH.addCondition(...) per state
s.addThreshold(tWarnHH);
```

The `add_rule_set` function was removed entirely (subsumed by the rewrite).

### API Boundary Respected

`fp.addThreshold()` calls on `FastSense` plot objects in `example_event_detection_live.m` (lines 101-124) were left completely untouched — this is the FastSense visualization API, not the Sensor threshold API.

## Tasks Completed

| Task | Files | Commit |
|------|-------|--------|
| 1: Migrate examples/01-03 | 19 files | `6e10987` |
| 2: Migrate examples/04-07 | 16 files | `72893f9` |

## Verification

```
grep -r 'addThresholdRule' examples/ --include='*.m'
```

Returns empty — zero remaining calls across all 35 files.

## Deviations from Plan

None — plan executed exactly as written. Both tasks completed mechanically using the specified grouping rules.

## Known Stubs

None.

## Self-Check: PASSED

- Task 1 commit `6e10987` exists: confirmed
- Task 2 commit `72893f9` exists: confirmed
- Zero `addThresholdRule` calls in examples/: confirmed (grep returns empty)
- All 35 files modified: confirmed via git diff
