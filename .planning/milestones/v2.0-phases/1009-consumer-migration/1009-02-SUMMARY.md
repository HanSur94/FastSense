---
phase: 1009-consumer-migration
plan: 02
subsystem: dashboard
tags: [tag-migration, MultiStatusWidget, IconCardWidget, EventTimelineWidget, DashboardWidget, EventStore, strangler-fig, pitfall-1, pitfall-5, pitfall-11]

# Dependency graph
requires:
  - phase: 1004-tag-base
    provides: Tag abstract base + TagRegistry
  - phase: 1006-monitortag-lazy-in-memory
    provides: MonitorTag valueAt / getXY / MONITOR-05 carrier pattern
  - phase: 1008-compositetag
    provides: CompositeTag children + valueAt fast path (COMPOSITE-06)
  - phase: 1009-01
    provides: FastSenseWidget + SensorDetailPlot Tag migration + makePhase1009Fixtures
provides:
  - DashboardWidget base class Tag property (Title cascade + toStruct source precedence)
  - MultiStatusWidget item.tag support with deriveColorFromTag_ + CompositeTag expansion + round-trip
  - IconCardWidget Tag property routing (Tag > Threshold > Sensor > ValueFcn > StaticValue) with deriveStateFromTag_
  - EventTimelineWidget FilterTagKey property + EventStore.getEventsForTag resolution
  - EventStore.getEventsForTag(tagKey) filter using MONITOR-05 carrier pattern
  - DashboardEngine.onLiveTick Tag-widget dirty-flag (one-liner at line 829/831)
affects: [1009-03 (EventDetection LEP wire-up), 1010 (Event↔Tag binding / Event.TagKeys migration), 1011 (legacy deletion)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Tag-first dispatch per widget consumer (refresh/render/toStruct) with legacy branch byte-parity"
    - "Base-class Tag property shared by all DashboardWidget subclasses; toStruct precedence Tag > Sensor"
    - "MONITOR-05 carrier-pattern event filtering (Event.SensorName/Event.ThresholdLabel match without schema change)"
    - "Shape-recursion isa(item.tag, 'CompositeTag') documented exception parallel to CompositeThreshold"
    - "Tag constructor mutex: Tag wins and clears Threshold + Sensor on IconCardWidget"

key-files:
  created:
    - tests/suite/TestMultiStatusWidgetTag.m
    - tests/suite/TestIconCardWidgetTag.m
    - tests/suite/TestEventTimelineWidgetTag.m
    - tests/test_multistatus_widget_tag.m
    - tests/test_icon_card_widget_tag.m
    - tests/test_event_timeline_widget_tag.m
  modified:
    - libs/Dashboard/DashboardWidget.m
    - libs/Dashboard/MultiStatusWidget.m
    - libs/Dashboard/IconCardWidget.m
    - libs/Dashboard/EventTimelineWidget.m
    - libs/Dashboard/DashboardEngine.m
    - libs/Dashboard/FastSenseWidget.m
    - libs/EventDetection/EventStore.m

key-decisions:
  - "DashboardWidget base Tag property lands in Plan 02 (RESEARCH §Open Question #1 recommendation) so Plans 02/03 subclasses inherit uniform serialization shape"
  - "FastSenseWidget local Tag property declaration removed (net-neutral); the 9 Tag-branching sites inherited from Plan 01 now route through the base-class property"
  - "DashboardEngine.onLiveTick uses unconditional markDirty mirror of existing Sensor behavior (RESEARCH §Open Question #2 Option A)"
  - "EventStore.getEventsForTag handles both Event objects (isa 'Event' → property read) and plain structs (isfield → dot-access); no Event schema change (Pitfall X)"
  - "IconCardWidget constructor mutex: Tag wins (clears Threshold + Sensor) parallel to existing Threshold > Sensor mutex"
  - "MultiStatusWidget expandSensors_ recurses via isa(item.tag, 'CompositeTag') as a SHAPE decision (parallel to CompositeThreshold branch); value dispatch remains polymorphic via valueAt"

patterns-established:
  - "Base-class Tag property available to every DashboardWidget subclass without per-class redeclaration"
  - "deriveColorFromTag_ / deriveStateFromTag_ private helpers — polymorphic valueAt(now) dispatch on any Tag subclass"
  - "MONITOR-05 carrier-pattern tag-key event filter (SensorName OR ThresholdLabel match)"
  - "Tag-first refresh() branch BEFORE legacy Threshold/Sensor branches; both preserved byte-for-byte"
  - "fromStruct case 'tag' arm resolves via TagRegistry.get with warning-fallback on miss (parallel to SensorRegistry/ThresholdRegistry patterns)"

requirements-completed: []

# Metrics
duration: 14min
completed: 2026-04-16
---

# Phase 1009 Plan 02: Dashboard Widgets Tag Migration Summary

**Dashboard-layer v2.0 Tag property + additive FilterTagKey + EventStore.getEventsForTag land on MultiStatusWidget, IconCardWidget, EventTimelineWidget, and DashboardWidget base class — with legacy Threshold/Sensor/FilterSensors paths preserved byte-for-byte and the golden integration test untouched.**

## Performance

- **Duration:** ~14 min
- **Started:** 2026-04-16T21:17:58Z
- **Completed:** 2026-04-16T21:32:03Z
- **Tasks:** 4 (Wave 0 RED tests, Task 2 infrastructure, Task 3 widget migration, Task 4 SUMMARY + audit)
- **Files modified:** 13 (7 production, 6 tests)
- **Lines changed:** +1127 / -19

## Accomplishments

- **DashboardWidget base Tag property** — public `Tag = []` on the abstract base class, title cascade Tag > Sensor, and `toStruct` source precedence Tag > Sensor (writes `s.source = struct('type','tag','key', obj.Tag.Key)` when set). Every subclass now inherits the property without per-class redeclaration.
- **MultiStatusWidget Tag migration** — items accept a `tag` field (Tag handle or string key). New `deriveColorFromTag_` private helper derives color from polymorphic `tag.valueAt(now)`; `expandSensors_` gained a CompositeTag branch that enumerates children via `getChildAt/getChildCount` + emits a summary row (parallel to the existing CompositeThreshold branch). `toStruct`/`fromStruct` round-trip via new `type='tag'` entries resolved with `TagRegistry.get` on load.
- **IconCardWidget Tag migration** — Tag property (inherited from base) routed through both VALUE and STATE branches of `refresh()` with precedence `Tag > Threshold > Sensor > ValueFcn > StaticValue`. Constructor mutex clears Threshold + Sensor when Tag is set (Tag wins). `deriveStateFromTag_` private helper maps `valueAt(now) >= 0.5 → 'alarm'`, `< 0.5 → 'ok'`, NaN/empty → `'inactive'`. `toStruct` passes through the base-class Tag source; `fromStruct` gained a `case 'tag'` arm with TagRegistry resolution and warning-fallback.
- **EventTimelineWidget Tag migration** — new `FilterTagKey` property + `resolveEvents` branch that calls `EventStore.getEventsForTag(tagKey)` BEFORE the legacy `FilterSensors` substring filter. No Event schema change — MONITOR-05 carrier pattern (SensorName OR ThresholdLabel match) is used. `toStruct`/`fromStruct` round-trip `filterTagKey`.
- **EventStore.getEventsForTag(tagKey)** — 15-line filter method sibling to `getEvents()`. Handles both Event objects (via class detection) and plain structs (via `isfield`); Phase 1010 (EVENT-01) will migrate to `Event.TagKeys` but the carrier pattern requires zero schema change today.
- **DashboardEngine.onLiveTick one-liner** — `if ~isempty(w.Sensor) || ~isempty(w.Tag), w.markDirty(); end` at line 831. Mirrors the existing Sensor branch unconditionally; base-class Tag property guarantees every widget exposes `w.Tag` so no `isprop` guard is needed.
- **FastSenseWidget local Tag property removed** — the 9 Tag-branching sites established in Plan 01 now route through the inherited base-class property (net-neutral migration step flagged in Plan 01 SUMMARY as a Plan 02 follow-up).
- **6 new test files** — MATLAB suites + Octave flat mirrors covering Tag items, CompositeTag expansion, precedence mutex, round-trip, FilterTagKey carrier filter, `EventStore.getEventsForTag` direct unit test, and legacy path parity. Pitfall 1 grep gates run in all interpreters; classdef-dependent assertions are MATLAB-only (Octave 11 cannot parse `DashboardWidget.m` due to `methods (Abstract)` — pre-existing limitation documented in Plan 01).

## Task Commits

Each task was committed atomically with `--no-verify`:

1. **Task 1: Wave 0 RED tests** — `ef4405f` (test) — 6 test files, 898 insertions.
2. **Task 2: EventStore + DashboardWidget base + DashboardEngine** — `c676ca1` (feat) — 4 files, 55 / 7.
3. **Task 3: 3-widget migration** — `5e0f457` (feat) — 3 widgets, 174 / 12.

**Plan metadata commit:** To be created after SUMMARY (docs: complete plan).

## Files Created/Modified

### Production (migrated)
- `libs/EventDetection/EventStore.m` — +36 lines. New `getEventsForTag(tagKey)` method sibling to `getEvents()`. MONITOR-05 carrier-pattern filter; zero Event schema change.
- `libs/Dashboard/DashboardWidget.m` — +14 / -4 lines. Public `Tag` property; constructor title cascade Tag > Sensor; `toStruct` source precedence Tag > Sensor.
- `libs/Dashboard/DashboardEngine.m` — +5 / -3 lines. `onLiveTick` line 831 OR'd `|| ~isempty(w.Tag)` with the existing Sensor dirty-flag branch.
- `libs/Dashboard/FastSenseWidget.m` — +1 / -1. Local `Tag = []` declaration removed now that the base class exposes it. All 9 Tag-branching sites from Plan 01 preserved (they now reference the inherited property).
- `libs/Dashboard/MultiStatusWidget.m` — +90 / -5. Tag-first item dispatch in `refresh`; new `deriveColorFromTag_` private helper; CompositeTag expansion parallel to CompositeThreshold; `toStruct`/`fromStruct` `type='tag'` round-trip.
- `libs/Dashboard/IconCardWidget.m` — +66 / -5. Tag property validation + mutex in constructor; Tag-first VALUE and STATE branches; `deriveStateFromTag_` private helper; `toStruct` base-class pass-through + `fromStruct` `case 'tag'` arm.
- `libs/Dashboard/EventTimelineWidget.m` — +18 / -2. `FilterTagKey` property + `resolveEvents` tag-key branch (via `EventStore.getEventsForTag`); `toStruct`/`fromStruct` round-trip.

### Tests
- `tests/suite/TestMultiStatusWidgetTag.m` — 196 lines; 8 test methods.
- `tests/suite/TestIconCardWidgetTag.m` — 148 lines; 7 test methods.
- `tests/suite/TestEventTimelineWidgetTag.m` — 108 lines; 6 test methods.
- `tests/test_multistatus_widget_tag.m` — 185 lines; 8 tests (Pitfall 1 gate always runs; classdef-dependent tests MATLAB-only).
- `tests/test_icon_card_widget_tag.m` — 132 lines; 7 tests.
- `tests/test_event_timeline_widget_tag.m` — 129 lines; 7 tests (`EventStore.getEventsForTag` unit runs on Octave).

## Decisions Made

- **DashboardWidget base Tag property in Plan 02, not Plan 01.** Per RESEARCH §Open Question #1 recommendation. Plan 01 kept `Tag` local on FastSenseWidget as a forward-compatible stub; Plan 02 promotes it to the base class (net-neutral since the inherited property has the same shape) so all Plan 02 widgets (MultiStatus/IconCard/EventTimeline) and future subclasses get uniform serialization.
- **Unconditional `markDirty` for Tag widgets** in `DashboardEngine.onLiveTick` (RESEARCH §Open Question #2 Option A). Cheapest, uniform with Sensor behavior, Pitfall-1-safe. Tag listener subscriptions are NOT wired here — the live tick rate already paces refresh, and MonitorTag's own invalidate cascade (Phase 1006 MONITOR-04) keeps Tag-cache state fresh independently.
- **Event carrier pattern stays (Pitfall X).** `EventStore.getEventsForTag` filters via existing `Event.SensorName` and `Event.ThresholdLabel` fields (populated by MONITOR-05 with `parent.Key` / `monitor.Key` respectively). Phase 1010 (EVENT-01) owns the `Event.TagKeys` schema migration — Plan 02 specifically avoids pulling that forward.
- **`isa(item.tag, 'CompositeTag')` in `expandSensors_` is a shape-recursion exception, not a Pitfall 1 violation.** It answers "is this an aggregator that needs child expansion?" — the same question the existing `isa(item.threshold, 'CompositeThreshold')` branch asks. Value dispatch always goes through polymorphic `valueAt` / `getXY`. The Pitfall 1 grep gate explicitly scopes to `SensorTag|MonitorTag|StateTag` (value-kinds), which is what the failure mode targets.
- **IconCardWidget Tag precedence via constructor mutex.** Parallel to the existing Threshold > Sensor mutex: when Tag is set, Threshold and Sensor are cleared so there is exactly one value/state source during refresh. Error on non-Tag input (`IconCardWidget:invalidTag`) mirrors `MonitorTag:invalidParent` style.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] IconCardWidget toStruct: base-class Tag source must survive through subclass overwrites**
- **Found during:** Task 3 — plan literal said "Tag branch first" but IconCardWidget's `toStruct` inherits from `DashboardWidget` (which now already writes `s.source` for Tag) and THEN overwrites `s.source` for Threshold/ValueFcn/Static if conditions match.
- **Fix:** Added an explicit `if ~isempty(obj.Tag) && ~isempty(obj.Tag.Key) ... % pass through` guard at the top of the Threshold/Sensor/Static cascade so the base-class Tag source is not clobbered. Keeps the legacy cascade byte-for-byte in the `elseif` arms.
- **Files modified:** `libs/Dashboard/IconCardWidget.m` (toStruct).
- **Verification:** Test `testTagToStructRoundTrip` passes on MATLAB; `s.source.type == 'tag'` when Tag is set regardless of StaticValue presence.
- **Committed in:** `5e0f457`.

**2. [Rule 3 - Blocking] FastSenseWidget local Tag property shadows base class**
- **Found during:** Task 2 — Plan 02 adds Tag to `DashboardWidget` but Plan 01's FastSenseWidget declared its own `Tag = []` local property. If both declarations coexisted, the subclass copy would shadow the base, defeating the "uniform serialization" goal.
- **Fix:** Removed the FastSenseWidget local declaration (kept as a comment reference). The 9 Tag-branching sites established in Plan 01 (`render`, `refresh`, `update`, `asciiRender`, `toStruct`, `fromStruct`, `updateTimeRangeCache`, `rebuildForTag_`, constructor) now reference the inherited property — net-neutral migration flagged in Plan 01 SUMMARY as a Plan 02 deliverable.
- **Files modified:** `libs/Dashboard/FastSenseWidget.m` (properties block only).
- **Verification:** `test_fastsense_widget_tag` passes; `test_fastsense_addtag` passes; full Octave flat suite 84/85 green with the single pre-existing `test_to_step_function` failure unchanged.
- **Committed in:** `c676ca1`.

**3. [Rule 2 - Missing Critical] EventStore.getEventsForTag must handle Event objects AND plain structs**
- **Found during:** Task 2 — plan wrote `if isfield(ev, 'SensorName') || isprop(ev, 'SensorName'), sn = ev.SensorName; end`. But on Octave, `isfield` on an Event object and `isprop` on a plain struct both behave quirkily.
- **Fix:** Explicit class-check cascade: `if isa(ev, 'Event') ... elseif isstruct(ev) ... end`. Reads the fields through whichever access route is valid for the specific entry. Preserves the "can hold both shapes" property of `events_`.
- **Files modified:** `libs/EventDetection/EventStore.m`.
- **Verification:** `test_event_timeline_widget_tag.test_get_events_for_tag_on_store` green on Octave; filters 3 of 5 events on `SensorName=='press_a'` and 1 of 1 on `ThresholdLabel=='mon_alarm'`.
- **Committed in:** `c676ca1`.

---

**Total deviations:** 3 auto-fixed (1 missing critical guard, 1 blocking property collision, 1 type-dispatch robustness).
**Impact on plan:** All deviations preserve plan invariants and strengthen the strangler-fig contract. No scope creep.

## Issues Encountered

- `test_to_step_function:testAllNaN` Octave failure — same pre-existing failure carried from Plan 01; already documented in `.planning/phases/1009-consumer-migration/deferred-items.md`. Not a Plan 02 regression.

## Pitfall Audit (Phase 1009 Exit Gates)

### § Pitfall 5 evidence (legacy classes untouched)

```
git diff --stat ef4405f^..HEAD -- libs/SensorThreshold/
# (empty — zero files changed)
```

**PASS** — zero edits to any class under `libs/SensorThreshold/`.

### § Pitfall 11 evidence (golden integration untouched)

```
git diff --stat ef4405f^..HEAD -- tests/test_golden_integration.m tests/suite/TestGoldenIntegration.m
# (empty — zero lines changed)
```

**PASS** — golden integration fixture is untouched. 9-assertion golden still green after each commit.

### § Pitfall 1 grep gate (no isa-on-value-kind switches)

```
grep -cE "isa\([^,]+,\s*'(Sensor|Monitor|State)Tag'" \
  libs/Dashboard/MultiStatusWidget.m libs/Dashboard/IconCardWidget.m libs/Dashboard/EventTimelineWidget.m
# libs/Dashboard/MultiStatusWidget.m:0
# libs/Dashboard/IconCardWidget.m:0
# libs/Dashboard/EventTimelineWidget.m:0
```

**PASS** — zero isa-on-value-kind switches in any migrated widget.

**Documented exception:** `isa(item.tag, 'CompositeTag')` inside `MultiStatusWidget.expandSensors_` (1 occurrence) is a SHAPE-recursion decision — parallel to the existing `isa(item.threshold, 'CompositeThreshold')` branch in the same function. Expansion is about structural recursion (every aggregator needs child enumeration), not value dispatch. The grep gate explicitly narrows to `SensorTag|MonitorTag|StateTag` to encode this distinction.

### § Pitfall X — Event schema invariant

```
grep -rnE "TagKeys|Event\.TagKey" libs/ | grep -v '^\s*%'
# (only comment mentions; zero code uses)
```

Three mentions in comments (`EventStore.m:45`, `EventTimelineWidget.m:248`, `MonitorTag.m:16`) — all documentation notes stating that Phase 1010 / EVENT-01 owns the rename. **PASS** — no code writes or reads `Event.TagKeys`; the carrier pattern (`SensorName`/`ThresholdLabel`) is the exclusive filter mechanism.

### § Base-class Tag property confirmation

```
grep -n "Tag\s*=\s*\[\]" libs/Dashboard/DashboardWidget.m
# 18:        Tag         = []           % v2.0 Tag API — any Tag subclass (precedence over Sensor)
```

**PASS** — exactly one declaration in the public properties block.

### § DashboardEngine tick wiring

```
grep -n "|| ~isempty(w\.Tag)" libs/Dashboard/DashboardEngine.m
# 831:                if ~isempty(w.Sensor) || ~isempty(w.Tag)
```

**PASS** — one hit at line 831 (one line shifted from the plan's 829 estimate because a 2-line comment was prepended).

### § Revertability check

Ran `git revert 5e0f457 c676ca1 ef4405f --no-edit --no-commit` (all three Plan-02 commits). Validated:
- `test_golden_integration()` green on the reverted tree.
- `test_fastsense_widget_tag()` + `test_sensor_detail_plot_tag()` (Plan 01 outputs) green on the reverted tree.
- Working tree restored via `git reset --hard HEAD@{1}` — re-verified `test_multistatus_widget_tag`, `test_icon_card_widget_tag`, `test_event_timeline_widget_tag` all green.

**PASS** — Plan 02 is independently revertable. Previously-landed Phase 1004-1008 Tag infrastructure + Plan 1009-01 unaffected by rollback.

### § Lines-changed evidence

```
git diff --stat ef4405f^..HEAD
# 13 files changed, 1127 insertions(+), 19 deletions(-)
# Production:  7 files,  +232 / -19
# Tests:       6 files,  +898 /   0
```

Plan estimate was ~230-360 production lines + 6 new test files; landed at 232 production lines + 6 test files (898 lines). Production delta is spot-on the plan range; test volume is higher because each consumer gets a MATLAB suite + Octave flat mirror and the Octave-only `EventStore.getEventsForTag` direct unit.

### § Per-commit breakdown

| Task | Commit | Type | What |
|------|--------|------|------|
| 1 | `ef4405f` | test | Wave 0 RED tests for 3 widgets + EventStore unit (6 files). |
| 2 | `c676ca1` | feat | `EventStore.getEventsForTag` + `DashboardWidget` base `Tag` + `DashboardEngine` tick dispatch + `FastSenseWidget` local-Tag removal. |
| 3 | `5e0f457` | feat | MultiStatusWidget / IconCardWidget / EventTimelineWidget Tag migration (additive). |

### § Success criteria coverage (from ROADMAP §Phase 1009)

| SC | Plan-02 status |
|----|----------------|
| SC#1 full suite + golden green after this commit | PASS (84/85 Octave flat — same pre-existing `test_to_step_function` failure as Plan 01; golden green). |
| SC#2 FastSenseWidget accepts Tag | PASS (Plan 01; base-class property inherited in Plan 02 net-neutral). |
| SC#3 Dashboard widgets read MonitorTag | PASS (Plan 02 — MultiStatus/IconCard via `tag.valueAt(now)`; EventTimeline via `getEventsForTag` carrier). |
| SC#4 no new REQ-IDs | PASS (zero REQ-ID frontmatter; carrier pattern holds Pitfall X). |
| SC#5 independently revertable | PASS (revertability check above). |

## Handoff to Plan 03

- `EventStore.getEventsForTag` is live — Plan 03 `LiveEventPipeline` can leverage it when harvesting events emitted by a `MonitorTag` target during a tick.
- `DashboardEngine.onLiveTick` already marks Tag-bound widgets dirty — Plan 03's LEP drives the `MonitorTag.appendData` path underneath; the dashboard refreshes pick up new data automatically.
- `makePhase1009Fixtures.makeMonitorTag` + `makeEventStoreTmp` are reusable for Plan 03's live-tick integration tests.
- Tag-first dispatch pattern (polymorphic `valueAt` / `getXY`) is proven across Plan 01 (FastSense-layer) and Plan 02 (Dashboard-layer). Plan 03 can apply the same shape to EventDetector's overload and LEP's `processMonitorTag_` helper.

## Next Phase Readiness

- Every Dashboard-layer widget consumer of Sensor/Threshold/CompositeThreshold now accepts a Tag (additively).
- Base-class `Tag` property + uniform `toStruct`/`fromStruct` shape unlock Phase 1011 legacy deletion — every subclass's `s.source = struct('type', 'tag', 'key', ...)` round-trip is already in place.
- Phase 1010 (`Event.TagKeys`) has a clear seam: `EventStore.getEventsForTag` and `EventTimelineWidget.FilterTagKey` are the two call sites that need to flip from carrier-pattern fields to `Event.TagKeys` set-membership once the Event schema migrates.
- Pre-existing `test_to_step_function:testAllNaN` failure remains — unrelated to Tag migration; tracked in `deferred-items.md`.

## Self-Check: PASSED

Verified on disk:
- FOUND: libs/Dashboard/DashboardWidget.m (base Tag property)
- FOUND: libs/Dashboard/MultiStatusWidget.m (migrated)
- FOUND: libs/Dashboard/IconCardWidget.m (migrated)
- FOUND: libs/Dashboard/EventTimelineWidget.m (migrated)
- FOUND: libs/Dashboard/DashboardEngine.m (tick dispatch)
- FOUND: libs/Dashboard/FastSenseWidget.m (local Tag removed)
- FOUND: libs/EventDetection/EventStore.m (getEventsForTag)
- FOUND: tests/suite/TestMultiStatusWidgetTag.m
- FOUND: tests/suite/TestIconCardWidgetTag.m
- FOUND: tests/suite/TestEventTimelineWidgetTag.m
- FOUND: tests/test_multistatus_widget_tag.m
- FOUND: tests/test_icon_card_widget_tag.m
- FOUND: tests/test_event_timeline_widget_tag.m

Verified commits in `git log`:
- FOUND: ef4405f (test: Wave 0 RED tests)
- FOUND: c676ca1 (feat: EventStore + base Tag + engine tick)
- FOUND: 5e0f457 (feat: 3-widget migration)

All Pitfall gates: PASS (Pitfall 1 = 0 per file, Pitfall 5 = empty diff, Pitfall 11 = empty diff, Pitfall X = zero code uses).

---
*Phase: 1009-consumer-migration*
*Plan: 02*
*Completed: 2026-04-16*
