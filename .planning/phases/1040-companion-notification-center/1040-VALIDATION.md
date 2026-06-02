---
phase: 1040
slug: companion-notification-center
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-02
---

# Phase 1040 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB `unittest` (class-based `tests/suite/Test*.m`) + flat function-based tests (`tests/test_*.m`); custom runner `tests/run_all_tests.m` |
| **Config file** | none — paths added by `install.m`; toolbox-free |
| **Quick run command** | class suite: `mcp__matlab__run_matlab_test_file tests/suite/TestNotificationCenterPane.m` · flat: call `test_notification_center_pane` via `mcp__matlab__evaluate_matlab_code` |
| **Full suite command** | `tests/run_all_tests.m` (via `mcp__matlab__run_matlab_file`) |
| **Estimated runtime** | single test file ~5–15 s · full suite several minutes |

---

## Sampling Rate

- **After every task commit:** Run the relevant single test file (`TestNotificationCenterPane` and/or `TestFastSenseCompanion`).
- **After every plan wave:** Run this phase's tests (pane suite + Companion integration test).
- **Before `/gsd:verify-work`:** Full suite (`tests/run_all_tests.m`) must be green.
- **Max feedback latency:** ~15 s for the quick per-task run.

---

## Per-Task Verification Map

> No REQ-IDs are mapped to this phase (`phase_req_ids: null`). Verification is keyed to plan tasks. **This table is populated by `gsd-planner`** once `PLAN.md` tasks exist; each task's `<acceptance_criteria>` must be grep-/test-verifiable.

| Task ID | Plan | Wave | Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----------|-----------|-------------------|-------------|--------|
| 01-1 | 01 | 1 | StubEventStore getEvents/numEvents/acknowledgeEvent + ThrowOnAck/ThrowOnGet | unit (double) | covered by `test_notification_center_pane` (01-3) | `tests/StubEventStore.m` | ⬜ pending |
| 01-2 | 01 | 1 | Static pure-logic helpers: filterUnacked_ (incl. NaN), sortNewestFirst_, maxSeverity_, idsOf_, diffIds_, badgeText_, badgeColor_ | unit | covered by `test_notification_center_pane` (01-3) | `libs/FastSenseCompanion/NotificationCenterPane.m` | ⬜ pending |
| 01-3 | 01 | 1 | Flat headless pure-logic test (stub round-trip + 7 helpers) | unit | `evaluate_matlab_code: test_notification_center_pane` | `tests/test_notification_center_pane.m` | ⬜ pending |
| 02-1 | 02 | 2 | Pane attach/detach/applyTheme lifecycle + header + inbox uitable | integration (headless) | `run_matlab_test_file tests/suite/TestNotificationCenterPane.m` | `libs/FastSenseCompanion/NotificationCenterPane.m` | ⬜ pending |
| 02-2 | 02 | 2 | refresh unacked+diff+cap+render; ack/ack-comment/bulk; stale guard; empty state | integration (headless) | `run_matlab_test_file tests/suite/TestNotificationCenterPane.m` | `libs/FastSenseCompanion/NotificationCenterPane.m` | ⬜ pending |
| 02-3 | 02 | 2 | Class suite: lifecycle, detach-reattach state, filter, diff-no-flicker, ack→removal, ack-race no-op, stale, empty, theme, DetachRequested | integration (headless) | `run_matlab_test_file tests/suite/TestNotificationCenterPane.m` | `tests/suite/TestNotificationCenterPane.m` | ⬜ pending |
| 03-1 | 03 | 3 | Root grid [3 4] + toolbar bell col 8 (gear→10); bell disabled w/o store | integration smoke | `evaluate_matlab_code` headless snippet | `libs/FastSenseCompanion/FastSenseCompanion.m` | ⬜ pending |
| 03-2 | 03 | 3 | Pane instantiation/wiring; column toggle 320↔0; detach-to-uifigure; badge update | integration smoke | `evaluate_matlab_code` headless snippet | `libs/FastSenseCompanion/FastSenseCompanion.m` | ⬜ pending |
| 03-3 | 03 | 3 | onLiveTick_ refreshes pane + updates badge (after scan, before cluster block) | integration smoke | `evaluate_matlab_code` headless tick snippet | `libs/FastSenseCompanion/FastSenseCompanion.m` | ⬜ pending |
| 04-1 | 04 | 4 | Toolbar assertions: Wiki stays col 7; gear col 9→10 (name preserved) | integration | `run_matlab_test_file tests/suite/TestFastSenseCompanion.m` | `tests/suite/TestFastSenseCompanion.m` | ⬜ pending |
| 04-2 | 04 | 4 | 9 integration tests: bell col 8, 4-col grid, toggle, enable/disable, badge count+color, onLiveTick refresh, detach/re-inline | integration | `run_matlab_test_file tests/suite/TestFastSenseCompanion.m` | `tests/suite/TestFastSenseCompanion.m` | ⬜ pending |
| 04-3 | 04 | 4 | Full-suite green gate (no new failures vs baseline) | suite | `run_matlab_file tests/run_all_tests.m` | — | ⬜ pending |
| 04-4 | 04 | 4 | Human verify: live pop-in + badge color + ack-clears + bulk + detach + theme | manual (checkpoint) | manual via matlab MCP on plant demo | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/suite/TestNotificationCenterPane.m` — pane-logic suite (unacked filtering, diff-by-Id, ack → removal, badge count + severity color, severity filter, empty state) driven headlessly via `uifigure('Visible','off')` + `addTeardown`.
- [ ] `tests/StubEventStore.m` (or equivalent) — fake `EventStore` handle exposing `getEvents()` / `acknowledgeEvent()`, modeled on `tests/CaptureNotificationService.m`.
- [ ] Companion integration coverage — extend `tests/suite/TestFastSenseCompanion.m` (bell toggles 4th column; badge reflects store; bell disabled with no EventStore; updated gear-column assertions per RESEARCH.md).

*Existing infrastructure (`run_all_tests.m`, suite runner) otherwise covers execution.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live pop-in + visual badge color under a real violation stream | — | Requires a rendered `uifigure` + live pipeline; visual confirmation | Run a Companion with an EventStore + mock `LiveEventPipeline` via the matlab MCP; trigger a threshold violation; confirm the item appears, badge increments/colors by severity, and Acknowledge clears it. |

*Automated tests cover all logic; only live visual rendering is manual.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
