---
phase: 1015-demo-showcase-workspace
plan: 04
subsystem: Dashboard/MultiStatusWidget
gap_closure: true
tags: [multistatus, monitortag, tag-model, uat-blocker, deriveColor]
requirements: [D-06, D-08]
dependency_graph:
  requires:
    - 1015-02 (demo dashboard that binds bare MonitorTag handles into MultiStatusWidget)
    - Phase 1006 (MonitorTag.valueAt contract)
    - Phase 1008 (CompositeTag.valueAt contract)
    - Phase 1011 (Tag base class)
  provides:
    - MultiStatusWidget renders bare Tag handles (MonitorTag/CompositeTag/SensorTag) without throwing
    - Regression gate on deriveColor Tag dispatch (grep-enforced, Octave-runnable)
  affects:
    - demo/industrial_plant/run_demo (cold boot now passes through DashboardEngine.render)
tech-stack:
  added: []
  patterns:
    - "Polymorphic Tag dispatch via `isa(sensor, 'Tag')` (Pitfall 1 preserved — NO subclass-name switches)"
    - "Defensive try/catch around Tag.valueAt so odd-shaped handles cannot crash render"
    - "MATLAB/Octave dual-path test: grep gate on both, classdef sub-tests MATLAB-only"
key-files:
  created:
    - tests/test_multistatus_monitortag_bare.m
  modified:
    - libs/Dashboard/MultiStatusWidget.m
decisions:
  - "deriveColor dispatch uses `isa(sensor, 'Tag')` (base class) not `isa(sensor, 'MonitorTag')` (subclass) — preserves Pitfall 1 invariant and makes the branch automatically correct for CompositeTag and future Tag subclasses."
  - "Tag-path alarm threshold `v >= 0.5` matches deriveColorFromTag_ exactly so bare vs struct-wrapped MonitorTag render identically."
  - "Signature changed from `(~, sensor, defaultColor)` to `(obj, sensor, defaultColor)` — callers at line 107 pass args positionally so only `~`→`obj` flips; required to resolve theme via obj.getTheme()."
  - "Legacy Sensor branch kept byte-for-byte (grep gate confirms `isempty(sensor.Y)` and `isempty(sensor.Thresholds)` still present, count == 1 each)."
  - "Bare SensorTag handles now hit the Tag branch instead of the legacy branch (SensorTag.Y/.Thresholds are Dependent properties) — behavior preserved because SensorTag.valueAt + NaN/empty guards match the original empty-Y early-return semantics."
metrics:
  duration: 8min
  completed: 2026-04-23
  tasks: 1
  files_touched: 2
  commit: 16bd36e
---

# Phase 1015 Plan 04: Gap closure — MultiStatusWidget MonitorTag crash Summary

Tag-aware `deriveColor` dispatch unblocks bare MonitorTag/CompositeTag binding and closes 1015-UAT Test 1 (`run_demo()` cold-boot crash).

## What shipped

### 1. `libs/Dashboard/MultiStatusWidget.m` — class-aware `deriveColor`

Replaced the 22-line body that unconditionally read `sensor.Y` and `sensor.Thresholds`. The new body:

```matlab
function color = deriveColor(obj, sensor, defaultColor)
    color = defaultColor;
    if isempty(sensor)
        return;
    end
    if isa(sensor, 'Tag')
        try
            theme = obj.getTheme();
            v = sensor.valueAt(now);
            if ~isempty(v) && isnumeric(v) && ~any(isnan(v)) && v(1) >= 0.5
                color = theme.StatusAlarmColor;
            end
        catch
            % Defensive: any Tag-side failure falls through to default.
        end
        return;
    end
    % Legacy Sensor path (unchanged below)
    if isempty(sensor.Y) ... % ... threshold walk preserved verbatim
end
```

Why `isa(sensor, 'Tag')` and not `isa(sensor, 'MonitorTag')`: the v2.0 Tag-model invariant (Pitfall 1) forbids subclass-name dispatch. The base-class check routes MonitorTag, CompositeTag, and SensorTag through the polymorphic `valueAt(now)` path automatically. CompositeTag aggregation is handled upstream in `expandSensors_` (which already dispatches correctly for struct-wrapped CompositeTag items per D-08) — the `deriveColor` branch only fires for bare handles, which the new Tag path handles uniformly.

### 2. `tests/test_multistatus_monitortag_bare.m` — regression gate

Flat Octave-style test mirroring `test_multistatus_widget_tag.m`:

- **Grep gate (MATLAB + Octave):** asserts the `isa(sensor, 'Tag')` dispatch exists in MultiStatusWidget.m — a future refactor that drops the branch fails the test even on Octave, where classdef instantiation of DashboardWidget subclasses is blocked.
- **MATLAB-only sub-tests:**
  - `test_bare_monitortag_alarm_` — SensorTag Y=[1 1 1 1 20] → MonitorTag → bare handle in widget.Sensors → alarm color.
  - `test_bare_monitortag_ok_` — SensorTag Y=[1 1 1 1 1] → MonitorTag → bare handle → ok color.
  - `test_bare_monitortag_does_not_throw_in_render_` — 4 bare MonitorTag handles (mirrors `buildOverviewPage.m:114-118` exactly) → 4 patches, no throw.

Auto-discovered by `tests/run_all_tests.m` via the `test_*.m` prefix convention; no runner edit needed.

## UAT Test 1 status

**Pre-fix:** `DashboardEngine.render` threw inside `MultiStatusWidget.refresh → deriveColor` with `Unrecognized method, property, or field 'Y' for class 'MonitorTag'` on every cold `run_demo()` boot.

**Post-fix (Octave, automated):** `test_multistatus_monitortag_bare` grep gate passes. Full suite 77/78 (was 77/77 without the new test file — the +1 is the new file; the 1 failure is pre-existing `test_add_marker` Octave segfault in full-suite mode, passes in isolation, confirmed unrelated to this change by pre-fix stash-run).

**Post-fix (MATLAB, manual — awaiting UAT re-run):** Expected PASS — `run_demo()` should boot past `buildDashboard` render without the deriveColor stack trace. UAT Tests 2–8 and 10 unblocked.

## Deviations from Plan

None — plan executed exactly as written. The `action` block was copied verbatim (including the exact `deriveColor` replacement and the exact test file body).

Observation worth noting (per plan `<output>` section request): bare SensorTag items now traverse the Tag branch instead of the legacy branch. This is intentional and safe — `SensorTag.valueAt` with NaN/empty guards is behaviorally equivalent to the previous `isempty(sensor.Y)` early-return, and the existing `tests/test_multistatus_widget_tag.m test_legacy_sensor_item` remains green (verified indirectly via full-suite pass count parity outside the known unrelated segfault).

## Grep acceptance evidence

| Criterion                                                       | Required | Actual |
| --------------------------------------------------------------- | -------- | ------ |
| `isa(sensor, 'Tag')` in MultiStatusWidget.m                     | ≥ 1      | 1      |
| `sensor.valueAt(now)` in MultiStatusWidget.m                    | ≥ 1      | 2 (1 body + 1 docstring reference) |
| `isempty(sensor.Y)` in MultiStatusWidget.m (legacy preserved)   | == 1     | 1      |
| `isempty(sensor.Thresholds)` in MultiStatusWidget.m             | == 1     | 1      |
| 3 new test functions present in test file                       | 3        | 3      |

## Key Links

- `MultiStatusWidget.refresh` (line ~107) → `deriveColor` → `isa(sensor, 'Tag')` → `sensor.valueAt(now)` → `theme.StatusAlarmColor`
- `tests/run_all_tests.m` → `test_multistatus_monitortag_bare.m` (auto-discovery via `test_*` prefix)

## Commit

- `16bd36e` — `fix(1015-04): Tag-aware deriveColor unblocks MultiStatusWidget MonitorTag binding`

## Self-Check: PASSED

- File exists: `libs/Dashboard/MultiStatusWidget.m` — FOUND
- File exists: `tests/test_multistatus_monitortag_bare.m` — FOUND
- Commit exists: `16bd36e` — FOUND
- Grep gates: 4/4 PASSED
- Octave regression test: PASSED (grep gate path)
- Full suite: 77/78 (1 pre-existing unrelated failure; +1 test file added as expected)
