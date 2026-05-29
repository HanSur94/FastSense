---
phase: quick
plan: 260405-tff
type: execute
wave: 1
depends_on: []
files_modified:
  # 01-basics (1 file)
  - examples/01-basics/example_dock_disk.m
  # 02-sensors (11 files)
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
  # 03-dashboard (6 files)
  - examples/03-dashboard/example_dashboard_advanced.m
  - examples/03-dashboard/example_dashboard_all_widgets.m
  - examples/03-dashboard/example_dashboard_engine.m
  - examples/03-dashboard/example_dashboard_groups.m
  - examples/03-dashboard/example_dashboard_info.m
  - examples/03-dashboard/example_dashboard_live.m
  - examples/03-dashboard/example_mushroom_cards.m
  # 04-widgets (10 files)
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
  # 05-events (3 files)
  - examples/05-events/example_event_detection_live.m
  - examples/05-events/example_event_viewer_from_file.m
  - examples/05-events/example_live_pipeline.m
  # 06-webbridge (1 file)
  - examples/06-webbridge/example_webbridge.m
  # 07-advanced (1 file)
  - examples/07-advanced/example_stress_test.m
autonomous: true
requirements: []

must_haves:
  truths:
    - "Zero addThresholdRule calls remain in any examples/*.m file"
    - "All examples use Threshold() + addCondition() + sensor.addThreshold() pattern"
    - "Existing fp.addThreshold() calls on FastSense objects are left untouched"
    - "All example scripts remain syntactically valid MATLAB"
  artifacts:
    - path: "examples/"
      provides: "35 migrated example scripts"
      contains: "Threshold\\("
  key_links:
    - from: "examples/**/*.m"
      to: "libs/SensorThreshold/Threshold.m"
      via: "Threshold() constructor calls"
      pattern: "Threshold\\('"
---

<objective>
Migrate all 35 example scripts from the removed `sensor.addThresholdRule()` API to the new first-class Threshold entity system (`Threshold()` + `addCondition()` + `sensor.addThreshold()`).

Purpose: Phase 1001 removed `addThresholdRule` from Sensor. All example scripts still use the old API and will crash at runtime.
Output: 35 updated example scripts with zero `addThresholdRule` calls remaining.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@libs/SensorThreshold/Threshold.m
@libs/SensorThreshold/Sensor.m
@tests/test_event_config.m (reference for new pattern)
@tests/test_resolve_segments.m (reference for multi-condition pattern)

<interfaces>
<!-- The migration pattern: -->

OLD API (removed):
```matlab
s.addThresholdRule(struct('machine', 0), 75, 'Direction', 'upper', 'Label', 'Hi Warn', 'Color', [1 0.5 0]);
s.addThresholdRule(struct('machine', 1), 60, 'Direction', 'upper', 'Label', 'Hi Warn', 'Color', [1 0.5 0]);
```

NEW API (Threshold entity):
```matlab
tHiWarn = Threshold('hi_warn', 'Name', 'Hi Warn', 'Direction', 'upper', 'Color', [1 0.5 0]);
tHiWarn.addCondition(struct('machine', 0), 75);
tHiWarn.addCondition(struct('machine', 1), 60);
s.addThreshold(tHiWarn);
```

KEY RULES:
1. Threshold key = lowercased label with spaces replaced by underscores. No-label = 'upper_N' or 'lower_N'.
2. Group addThresholdRule calls that share the SAME label AND direction into ONE Threshold with multiple addCondition calls.
3. addThresholdRule calls with DIFFERENT labels or directions become SEPARATE Threshold objects.
4. Static thresholds (struct() condition) still use addCondition(struct(), value).
5. Metadata (Color, LineStyle) moves to the Threshold() constructor, NOT addCondition.
6. DO NOT touch fp.addThreshold() calls on FastSense objects -- those are a DIFFERENT API for visual threshold lines on plots. Only migrate sensor.addThresholdRule() calls.
7. Threshold constructor: Threshold(key, 'Name', name, 'Direction', dir, 'Color', color, 'LineStyle', style)
8. addCondition signature: t.addCondition(stateStruct, numericValue)
9. sensor.addThreshold(thresholdObj) -- accepts a Threshold handle object
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Migrate examples/01-basics, examples/02-sensors, and examples/03-dashboard</name>
  <files>
    examples/01-basics/example_dock_disk.m
    examples/02-sensors/example_dynamic_thresholds_100M.m
    examples/02-sensors/example_sensor_dashboard.m
    examples/02-sensors/example_sensor_detail_dashboard.m
    examples/02-sensors/example_sensor_detail_datetime.m
    examples/02-sensors/example_sensor_detail_dock.m
    examples/02-sensors/example_sensor_detail.m
    examples/02-sensors/example_sensor_multi_state.m
    examples/02-sensors/example_sensor_registry.m
    examples/02-sensors/example_sensor_static.m
    examples/02-sensors/example_sensor_threshold.m
    examples/02-sensors/example_sensor_todisk.m
    examples/03-dashboard/example_dashboard_advanced.m
    examples/03-dashboard/example_dashboard_all_widgets.m
    examples/03-dashboard/example_dashboard_engine.m
    examples/03-dashboard/example_dashboard_groups.m
    examples/03-dashboard/example_dashboard_info.m
    examples/03-dashboard/example_dashboard_live.m
    examples/03-dashboard/example_mushroom_cards.m
  </files>
  <action>
For each file, replace every `sensor.addThresholdRule(condition, value, ...)` call with the new Threshold pattern:

1. Read the file and identify all addThresholdRule calls.
2. Group calls by (sensorVariable, label, direction) tuple -- calls sharing these become one Threshold with multiple addCondition lines.
3. For each group, create a Threshold object with a key derived from the label (lowercased, spaces to underscores). If no label, use direction + incrementing counter (e.g., 'upper_1', 'lower_2').
4. Move Color, LineStyle from addThresholdRule kwargs to Threshold constructor kwargs.
5. Each former addThresholdRule becomes a t.addCondition(condStruct, value) call.
6. Add s.addThreshold(t) after all conditions are added.
7. Place Threshold definitions BEFORE the sensor.addThreshold() call, keeping them near the original addThresholdRule location.
8. Update header comments that reference addThresholdRule to mention the new Threshold pattern.

IMPORTANT: Leave ALL `fp.addThreshold()` / `fpN.addThreshold()` calls on FastSense plot objects completely untouched. These are a different API. Only migrate `sensorVar.addThresholdRule()` calls where the variable is a Sensor object.

Special cases:
- example_dock_disk.m has 61 calls across many sensors -- group carefully per sensor and per threshold identity.
- example_dynamic_thresholds_100M.m uses loop-generated thresholds -- adapt the loop to create Threshold objects.
- example_sensor_multi_state.m has 5 rules across 3 state conditions with a joint condition (machine+zone) -- each unique label/direction becomes one Threshold.
  </action>
  <verify>
    <automated>grep -r 'addThresholdRule' examples/01-basics/ examples/02-sensors/ examples/03-dashboard/ --include='*.m' | grep -v '^--$' | wc -l | xargs test 0 -eq</automated>
  </verify>
  <done>Zero addThresholdRule calls remain in examples/01-basics/, examples/02-sensors/, and examples/03-dashboard/. All files use Threshold()+addCondition()+addThreshold() pattern.</done>
</task>

<task type="auto">
  <name>Task 2: Migrate examples/04-widgets, 05-events, 06-webbridge, 07-advanced</name>
  <files>
    examples/04-widgets/example_widget_barchart.m
    examples/04-widgets/example_widget_chipbar.m
    examples/04-widgets/example_widget_fastsense.m
    examples/04-widgets/example_widget_group.m
    examples/04-widgets/example_widget_gauge.m
    examples/04-widgets/example_widget_histogram.m
    examples/04-widgets/example_widget_iconcard.m
    examples/04-widgets/example_widget_multistatus.m
    examples/04-widgets/example_widget_scatter.m
    examples/04-widgets/example_widget_status.m
    examples/04-widgets/example_widget_table.m
    examples/05-events/example_event_detection_live.m
    examples/05-events/example_event_viewer_from_file.m
    examples/05-events/example_live_pipeline.m
    examples/06-webbridge/example_webbridge.m
    examples/07-advanced/example_stress_test.m
  </files>
  <action>
Apply the same mechanical transformation as Task 1 to the remaining 16 files.

Same rules apply:
1. Group addThresholdRule calls by (sensorVariable, label, direction).
2. Create Threshold objects with key = lowercased label, spaces to underscores.
3. Move Color/LineStyle to Threshold constructor.
4. Each old call becomes t.addCondition(condStruct, value).
5. Add s.addThreshold(t) after conditions.
6. DO NOT touch fp.addThreshold() on FastSense objects.

Special cases:
- example_widget_multistatus.m has 17 calls across 8 sensors -- each sensor gets its own Threshold objects.
- example_live_pipeline.m has 20 calls with state-dependent thresholds (idle/heating/cooling) -- group by sensor+label+direction; each Threshold gets multiple addCondition calls for different states.
- example_stress_test.m uses dynamic variables in a loop -- adapt loop to create Threshold objects.
- example_event_detection_live.m has BOTH sensor.addThresholdRule AND fp.addThreshold calls -- only migrate the sensor ones.

After all files are migrated, run a final grep to confirm zero addThresholdRule calls remain anywhere in examples/.
  </action>
  <verify>
    <automated>grep -r 'addThresholdRule' examples/ --include='*.m' | wc -l | xargs test 0 -eq</automated>
  </verify>
  <done>Zero addThresholdRule calls remain in any examples/*.m file. All 35 files use the new Threshold entity pattern. fp.addThreshold() calls on FastSense objects are untouched.</done>
</task>

</tasks>

<verification>
- `grep -r 'addThresholdRule' examples/ --include='*.m'` returns empty (zero matches)
- `grep -r "Threshold('" examples/ --include='*.m' | wc -l` returns > 0 (new pattern present)
- `grep -r 'fp.*\.addThreshold(' examples/ --include='*.m' | head -5` still shows FastSense threshold calls (untouched)
</verification>

<success_criteria>
- All 35 example files migrated from addThresholdRule to Threshold+addCondition+addThreshold
- Zero addThresholdRule calls remain in examples/
- All fp.addThreshold() calls on FastSense objects are preserved unchanged
- Threshold keys follow convention: lowercased label with underscores
- Multi-condition thresholds (same label/direction, different states) properly grouped into single Threshold objects
</success_criteria>

<output>
After completion, create `.planning/quick/260405-tff-integrate-new-threshold-system-into-all-/260405-tff-SUMMARY.md`
</output>
