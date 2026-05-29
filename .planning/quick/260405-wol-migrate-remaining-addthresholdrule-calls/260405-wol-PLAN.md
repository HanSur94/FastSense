---
phase: quick
plan: 260405-wol
type: execute
wave: 1
depends_on: []
files_modified:
  - install.m
  - benchmarks/benchmark_resolve_stress.m
  - benchmarks/benchmark_resolve.m
  - benchmarks/benchmark_memory.m
  - docs/generate_readme_images.m
  - libs/SensorThreshold/ThresholdRule.m
autonomous: true
requirements: []
must_haves:
  truths:
    - "Zero addThresholdRule calls remain in codebase outside libs/SensorThreshold/Sensor.m"
    - "Zero ThresholdRules property references remain in codebase"
    - "All migrated files use Threshold+addCondition+addThreshold pattern"
    - "Stale comment in ThresholdRule.m references Sensor.addThreshold not addThresholdRule"
  artifacts:
    - path: "install.m"
      provides: "Warmup smoke test using Threshold API"
      contains: "Threshold("
    - path: "benchmarks/benchmark_resolve_stress.m"
      provides: "Stress benchmark using Threshold API"
      contains: "Threshold("
    - path: "benchmarks/benchmark_resolve.m"
      provides: "Resolve benchmark using Threshold API"
      contains: "Threshold("
    - path: "benchmarks/benchmark_memory.m"
      provides: "Memory benchmark using Threshold API"
      contains: "Threshold("
    - path: "docs/generate_readme_images.m"
      provides: "README image generator using Threshold API"
      contains: "Threshold("
    - path: "libs/SensorThreshold/ThresholdRule.m"
      provides: "Updated See also comment"
      contains: "Sensor.addThreshold"
  key_links: []
---

<objective>
Migrate all remaining addThresholdRule calls to the first-class Threshold API (Threshold + addCondition + sensor.addThreshold pattern). Also fix ThresholdRules property references and stale comments.

Purpose: Complete the Phase 1001 Threshold entity migration across the entire codebase.
Output: Six files updated with zero remaining addThresholdRule references outside deprecated compatibility code.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@install.m
@benchmarks/benchmark_resolve_stress.m
@benchmarks/benchmark_resolve.m
@benchmarks/benchmark_memory.m
@docs/generate_readme_images.m
@libs/SensorThreshold/ThresholdRule.m
</context>

<tasks>

<task type="auto">
  <name>Task 1: Migrate addThresholdRule calls in install.m and all 3 benchmark files</name>
  <files>install.m, benchmarks/benchmark_resolve_stress.m, benchmarks/benchmark_resolve.m, benchmarks/benchmark_memory.m</files>
  <action>
Mechanical replacement of addThresholdRule -> Threshold+addCondition+addThreshold in 4 files.

**Migration pattern** (from Phase 1001):
```matlab
% OLD:
s.addThresholdRule(struct('machine', 1), 75, 'Direction', 'upper', 'Label', 'HH', 'Color', [0.9 0.1 0.1], 'LineStyle', '--');

% NEW:
tHH = Threshold('hh', 'Name', 'HH', 'Direction', 'upper', 'Color', [0.9 0.1 0.1], 'LineStyle', '--');
tHH.addCondition(struct('machine', 1), 75);
s.addThreshold(tHH);
```

Key rules:
- Threshold key: derive from lowercased label with spaces->underscores; if no Label use `upper_N`/`lower_N` pattern
- State struct from first arg of addThresholdRule becomes first arg of addCondition
- Value (second arg of addThresholdRule) becomes second arg of addCondition
- Direction, Label->Name, Color, LineStyle move to Threshold constructor as name-value pairs
- Label becomes Name in the Threshold constructor
- For multi-condition thresholds (same sensor, related rules), group conditions under one Threshold if they share direction/label; otherwise create separate Threshold objects

**install.m** (lines 204-207): 4 calls on sensor `sw`. These have 2 upper + 2 lower with different state combos. Create 4 separate Threshold objects since each has distinct direction or state conditions.

**benchmark_resolve_stress.m**: 
- Lines 115-134: 4 calls on sensor `s` — create 4 Threshold objects with their labels/colors/linestyles preserved
- Line 138: Replace `numel(s.ThresholdRules)` with `numel(s.Thresholds)`
- Lines 173-176: 4 calls on sensor `sw` — create 4 Threshold objects
- Lines 194-200: 4 calls on sensor `sr` in a loop — create 4 Threshold objects
- Line 222: Replace `numel(s.ThresholdRules)` with `numel(s.Thresholds)`

**benchmark_resolve.m** (lines 73-79): 4 calls on sensor `s` inside a loop — create 4 Threshold objects

**benchmark_memory.m** (lines 98, 108, 120): 3 separate sensors each with 1 addThresholdRule call — create 1 Threshold per sensor

IMPORTANT: Do NOT touch any fp.addThreshold() calls on FastSense plot objects — that is a different API.
  </action>
  <verify>
    <automated>cd /Users/hannessuhr/FastPlot && grep -rn 'addThresholdRule' install.m benchmarks/benchmark_resolve_stress.m benchmarks/benchmark_resolve.m benchmarks/benchmark_memory.m; echo "EXIT:$?"</automated>
  </verify>
  <done>Zero addThresholdRule calls in install.m and 3 benchmark files. Zero ThresholdRules property refs in benchmarks. All use Threshold+addCondition+addThreshold pattern.</done>
</task>

<task type="auto">
  <name>Task 2: Migrate docs/generate_readme_images.m and fix ThresholdRule.m stale comment</name>
  <files>docs/generate_readme_images.m, libs/SensorThreshold/ThresholdRule.m</files>
  <action>
**docs/generate_readme_images.m** (lines 159-161): 3 addThresholdRule calls on sensor `s`. Each has Label, Direction, and state struct. Migrate using same pattern:
- Line 159: `s.addThresholdRule(struct('machine', 1), 70, 'Direction', 'upper', 'Label', 'Run HI')` -> Threshold('run_hi', 'Name', 'Run HI', 'Direction', 'upper') + addCondition(struct('machine', 1), 70) + s.addThreshold(...)
- Line 160: similar for 'Boost HI'
- Line 161: similar for 'Run LO'

**libs/SensorThreshold/ThresholdRule.m** line 74: Change stale comment from:
  `%   See also ThresholdRule.matchesState, Sensor.addThresholdRule.`
to:
  `%   See also ThresholdRule.matchesState, Sensor.addThreshold.`

**Final codebase sweep**: After edits, verify zero remaining addThresholdRule references exist anywhere in the repo (excluding Sensor.m itself which may retain the deprecated method).
  </action>
  <verify>
    <automated>cd /Users/hannessuhr/FastPlot && grep -rn 'addThresholdRule' --include='*.m' | grep -v 'Sensor\.m' | grep -v 'test_' | grep -v 'Test'; echo "EXIT:$?"</automated>
  </verify>
  <done>Zero addThresholdRule references in docs/ and ThresholdRule.m comment updated. Full codebase sweep confirms no remaining legacy calls outside Sensor.m deprecated compatibility method.</done>
</task>

</tasks>

<verification>
Full codebase grep for addThresholdRule returns zero hits outside libs/SensorThreshold/Sensor.m (which retains the deprecated method for backward compat).
Full codebase grep for ThresholdRules property access returns zero hits outside Sensor.m.
</verification>

<success_criteria>
- `grep -rn 'addThresholdRule' --include='*.m' . | grep -v Sensor.m` returns empty
- `grep -rn 'ThresholdRules' --include='*.m' . | grep -v Sensor.m` returns empty
- All 6 files contain the new Threshold() constructor pattern
</success_criteria>

<output>
After completion, create `.planning/quick/260405-wol-migrate-remaining-addthresholdrule-calls/260405-wol-SUMMARY.md`
</output>
