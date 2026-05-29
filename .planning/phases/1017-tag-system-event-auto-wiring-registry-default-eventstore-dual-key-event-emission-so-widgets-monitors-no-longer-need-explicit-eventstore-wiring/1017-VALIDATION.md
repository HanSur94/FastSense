---
phase: 1017
slug: tag-system-event-auto-wiring
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-28
---

# Phase 1017 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB suite tests (`tests/suite/Test*.m`) + Octave function tests (`tests/test_*.m`) — dual-target per project convention |
| **Config file** | `tests/run_all_tests.m` (custom test runner) |
| **Quick run command** | `matlab -batch "addpath('.'); install(); runtests('tests/suite/TestDashboardEventsToggle.m')"` (or equivalent Octave: `octave --no-gui --eval "addpath('.'); install(); test_dashboard_events_toggle"`) |
| **Full suite command** | `matlab -batch "addpath('.'); install(); cd tests; run_all_tests"` |
| **Estimated runtime** | ~5s for the focused EventsToggle file; ~3min for the full suite |

---

## Sampling Rate

- **After every task commit:** Run the focused EventsToggle test (quick command above)
- **After every plan wave:** Run the full SensorThreshold subset (`runtests('tests/suite/TestMonitorTag.m')` + `tests/suite/TestTagRegistry.m` if present)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~10s per task commit

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----------|-----------|-------------------|-------------|--------|
| 1017-01-01 | 01 | 1 | TagRegistry.setEventStore/getEventStore round-trip | unit | `matlab -batch "addpath('.'); install(); runtests('tests/suite/TestDashboardEventsToggle.m')"` | ✅ extend existing | ⬜ pending |
| 1017-01-02 | 01 | 1 | TagRegistry.clear() resets the EventStore slot | unit | same | ✅ extend existing | ⬜ pending |
| 1017-02-01 | 02 | 1 | MonitorTag ctor falls back to TagRegistry.getEventStore() when no NV-pair | unit | same | ✅ extend existing | ⬜ pending |
| 1017-02-02 | 02 | 1 | Explicit `'EventStore', es` NV-pair on MonitorTag overrides registry default | unit | same | ✅ extend existing | ⬜ pending |
| 1017-02-03 | 02 | 1 | MonitorTag emits events with `ev.TagKeys = {monitor.Key, parent.Key}` (already in code; regression test) | unit | same | ✅ extend existing | ⬜ pending |
| 1017-02-04 | 02 | 1 | `EventStore.getEventsForTag(parent.Key)` returns events emitted by child MonitorTag | unit | same | ✅ extend existing | ⬜ pending |
| 1017-03-01 | 03 | 2 | FastSense.renderEventLayer_ falls back to TagRegistry.getEventStore() when bound tag's EventStore is empty | unit | same | ✅ extend existing | ⬜ pending |
| 1017-03-02 | 03 | 2 | FastSenseWidget delegates registry-default fallback through to inner FastSense | unit | same | ✅ extend existing | ⬜ pending |
| 1017-04-01 | 04 | 2 | EventTimelineWidget falls back to TagRegistry.getEventStore() when EventStoreObj empty | unit | same | ✅ extend existing | ⬜ pending |
| 1017-04-02 | 04 | 2 | TableWidget(events) falls back to TagRegistry.getEventStore() when EventStoreObj empty | unit | same | ✅ extend existing | ⬜ pending |
| 1017-05-01 | 05 | 3 | Demo `registerPlantTags.m` migrated: zero `'EventStore', store` MonitorTag wirings; one `TagRegistry.setEventStore` call | grep | `grep -c "'EventStore'" demo/industrial_plant/private/registerPlantTags.m` returns `0`; `grep -c "TagRegistry.setEventStore" demo/industrial_plant/private/registerPlantTags.m` returns `1` | ✅ existing | ⬜ pending |
| 1017-05-02 | 05 | 3 | `buildEventsPage.m` no longer passes `'EventStoreObj', ctx.store` on EventTimelineWidget (relies on registry default) | grep | `grep -c "'EventStoreObj'" demo/industrial_plant/private/buildEventsPage.m` returns `0` | ✅ existing | ⬜ pending |
| 1017-05-03 | 05 | 3 | Misleading comment in `buildEventsPage.m` ("FastSense auto-discovers from any bound MonitorTag") fixed | grep | `grep -c "auto-discovers EventStore from any bound MonitorTag" demo/industrial_plant/private/buildEventsPage.m` returns `0` | ✅ existing | ⬜ pending |
| 1017-06-01 | 06 | 3 | `examples/example_event_markers.m` migrated to registry-default pattern with TagRegistry.setEventStore + TagRegistry.register for both SensorTags | grep | `grep -c "TagRegistry.setEventStore\|TagRegistry.register" examples/example_event_markers.m` returns `>= 3` (1 setEventStore + 2 register); `grep -c "'EventStore'" examples/example_event_markers.m` returns `<= 1` (allowed only inside FastSenseWidget if intentionally kept as test of explicit override) | ✅ existing | ⬜ pending |
| 1017-07-01 | 07 | 4 | Existing TestDashboardEventsToggle still passes (no regression) | suite | `matlab -batch "addpath('.'); install(); runtests('tests/suite/TestDashboardEventsToggle.m')"` exits 0 | ✅ existing | ⬜ pending |
| 1017-07-02 | 07 | 4 | example_event_markers.m runs without errors after migration | smoke | `matlab -batch "addpath('.'); install(); example_event_markers"` exits 0 | ✅ existing | ⬜ pending |
| 1017-07-03 | 07 | 4 | demo/industrial_plant/run_demo.m headless smoke test still passes | suite | `matlab -batch "addpath('.'); install(); runtests('tests/suite/TestDemoIndustrialPlantHeadless.m')"` exits 0 | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- No new test infrastructure needed. All tests extend the existing dual-target pair:
  - `tests/suite/TestDashboardEventsToggle.m` (MATLAB class-based)
  - `tests/test_dashboard_events_toggle.m` (Octave function-based — must be kept in sync)
- Existing `tests/suite/TestDemoIndustrialPlantHeadless.m` covers regression for demo migration.
- Existing `examples/example_event_markers.m` serves as a manual smoke-test surface.

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visible event markers on FastSense plots in the live demo | "events surface in the demo" goal | Requires interactive figure display; CI runs headless | (1) `close all force; clear all; clear classes` (2) `cd demo/industrial_plant; run_demo` (3) Wait ~30s for live ticks (4) Verify round event markers appear on the reactor.pressure FastSense plot in the Overview page (5) Verify the Events toolbar button toggles markers off/on without losing the plot data |
| Demo Events button visible on toolbar | Side issue surfaced in conversation | Class-cache verification only meaningful on a fresh MATLAB session | After `clear classes`, run the demo and verify the toolbar shows: Info … Config Image Export Live Sync **Events** [last-update label]. Border around Events highlights blue when active. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or grep-based acceptance criteria
- [ ] Sampling continuity: focused EventsToggle test runs after every task in Plans 01-04
- [ ] Wave 0 not needed (existing infrastructure sufficient)
- [ ] No watch-mode flags
- [ ] Feedback latency ~10s per task commit
- [ ] `nyquist_compliant: true` set in frontmatter (after planner verifies coverage)

**Approval:** pending
