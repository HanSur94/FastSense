---
phase: 1045-cross-machine-comparison-view
plan: "03"
subsystem: companion-ui
tags: [uifigure, dialog, row-state-machine, resolve-once-cache, cmp]
requirements: [CMP-01, CMP-03, CMP-04, CMP-05, CMP-06]

dependency_graph:
  requires: ["1045-01", "1045-02"]
  provides:
    - "CompareBuilderDialog (modeless 600x480 second uifigure, CompanionSettingsDialog lifecycle)"
    - "Quick-fill sensor dropdown -> buildCompareResolution_ -> four-state per-machine rows"
    - "onOpenComparison_ resolve-once cache + consolidated mismatch/skip alerts + tracked overlay (CMP-05 invariant #5)"
    - "FastSenseCompanion.fleet() public read accessor"
  affects:
    - libs/FastSenseCompanion/CompareBuilderDialog.m
    - libs/FastSenseCompanion/FastSenseCompanion.m

tech_stack:
  added: []
  patterns:
    - "CompanionSettingsDialog uifigure+grid+CloseRequestFcn+friend-class-writeback lifecycle"
    - "ValueChangedFcn/ButtonPushedFcn closures invoke private callbacks (test/smoke seam)"
    - "resolve-once-at-open cache: Machine.get() lookups only, zero CanonicalMapper calls post-cache"

key_files:
  created:
    - libs/FastSenseCompanion/CompareBuilderDialog.m
  modified:
    - libs/FastSenseCompanion/FastSenseCompanion.m

decisions:
  - "Reached the companion through PUBLIC seams (fleet() accessor + the existing public trackOpenedFigure()) instead of the plan's literal private app.Fleet_ / app.trackOpenedFigure_ reads — a separate class cannot read private members, and the CompanionSettingsDialog idiom is dialogs-call-only-public-app-methods. Added one accessor (fleet()); trackOpenedFigure() already existed public."
  - "renderCenteredHint_ shows a neutral 'Select a shared sensor to compare' placeholder when machines exist but no sensor is picked (the UI-SPEC locks only 'No machines in fleet'); flagged for the human-verify checkpoint."
  - "onRowAction_ left an inert bounds-guarded stub (uses obj+i so the analyzer stays clean); Plan 04 fills the Confirm/Promote dispatch."
  - "badgeSpec_ is the single source of truth for badge text+FontColor per state, shared by rebuild, in-place updates, and (Plan 04) applyTheme_."

metrics:
  commit: 7d2fcf91
  tests: "check_matlab_code clean on CompareBuilderDialog.m + FastSenseCompanion.m; live smoke 10/10 (shell+invalidApp; four-state {auto,confirm_needed,auto,none} with LOW+none unchecked + Open gating; resolve-once cache numel(ResolvedTags_)==2; tracked overlay; per-machine legends correct); timers 0 after teardown"
---

# Plan 1045-03 Summary

`CompareBuilderDialog` — the modeless cross-machine comparison builder — now renders the quick-fill sensor dropdown, the scrollable per-machine row grid (swatch + checkbox + name + override dropdown + action slot + status badge), the four-state row state machine (auto / confirm_needed / override / none), and the `onOpenComparison_` path that resolves each included tag **once** into `ResolvedTags_` and opens a tracked overlay via the extended `openAdHocPlot` with per-machine colors and `[machineName]: [sensorDisplayName]` legends. The confidence gate (LOW+AUTO never auto-included — invariant #4) lives in `buildCompareResolution_`; the resolve-once cache (no `CanonicalMapper` call after Open — invariant #5) lives in `onOpenComparison_`.

**Verification (live MATLAB, worktree on path):** a 4-machine fleet (M01/M03 HIGH `temperature`, M02 LOW `temp`, M04 unmapped `rpm`) drove the dialog through `check_matlab_code` (clean) and a 10/10 smoke: shell + `CompareBuilderDialog:invalidApp` guard; the row states resolved to exactly `{auto, confirm_needed, auto, none}` with the LOW and none rows unchecked and the Open button enabled at 2 included; Open populated `ResolvedTags_` with 2 handles, spawned one tracked overlay, and the overlay lines carried the machine-qualified legends. Session timers returned to 0 after teardown.

**Deviations:**
1. **Public seams instead of private member access.** The plan wrote `app.Fleet_` and `app.trackOpenedFigure_`; both are private to `FastSenseCompanion` and unreachable from a separate class. The dialog instead calls the public `fleet()` accessor (added this plan, mirroring `Fleet.mapper()`/`machineIds()`) and the **already-public** `trackOpenedFigure()`. This matches the `CompanionSettingsDialog` idiom (sub-dialogs touch only public app methods) and leaves the private `Fleet_` field and its internal readers untouched. The Plan 05 class-suite tests read state via `struct(dlg)`, unaffected.
2. **Neutral empty-state copy.** `renderCenteredHint_` shows `Select a shared sensor to compare` when machines exist but no sensor is selected — the UI-SPEC locks only the `No machines in fleet` string; flagged for the Plan 05 human-verify checkpoint.

**Teardown note for Plan 05 tests:** spawned overlay figures must be torn down with `close(fig)` (fires the engine's `CloseRequestFcn` -> `stopLive`), **not** `delete(fig)`, which bypasses the live-timer cleanup and leaks a timer.
