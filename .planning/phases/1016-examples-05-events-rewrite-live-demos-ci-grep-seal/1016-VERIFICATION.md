---
phase: 1016-examples-05-events-rewrite-live-demos-ci-grep-seal
verified: 2026-04-29T00:00:00Z
status: passed
score: 10/10 must-haves verified
re_verification:
  is_re_verification: false
human_verification:
  - test: "Run example_event_detection_live.m in MATLAB R2020b (interactive mode)"
    expected: "3-sensor dashboard renders; bounded 5-tick timer fires pipeline.runCycle() at 1s spacing; onCleanup wraps timer cleanup; final 'Demo complete: N events in store' line prints; no leftover timers in timerfindall()"
    why_human: "Requires real MATLAB runtime — no MATLAB locally. Visual verification of dashboard widgets + live tick behavior cannot be grepped"
  - test: "Run example_event_viewer_from_file.m in MATLAB R2020b"
    expected: "Synthetic data with 7 planted violations triggers events; store.save() writes .mat file under tempdir; EventViewer.fromFile reopens; Gantt timeline + click-to-plot detail flow works"
    why_human: "Requires GUI runtime to verify viewer figure opens and click-to-plot detail flow"
  - test: "Run example_live_pipeline.m in MATLAB R2020b or Octave"
    expected: "3 manual cycles run via pipeline.runCycle(); events flow into shared EventStore; NotificationService dry-run logs print; snapshot PNGs land in tempdir; EventViewer opens at the end"
    why_human: "Requires runtime to verify event flow through MonitorTag-valued monitors map; visual confirmation of snapshot PNGs and viewer"
  - test: "Push to a branch and observe DIFF-01 grep seal firing in CI"
    expected: "lint job 'Phase-1011 deleted-class regression seal (DIFF-01)' step runs the self-test (1 hit + 3 misses) then the real scan; exits 0 on clean tip; would exit 1 if any of the 8 deleted classes were re-introduced"
    why_human: "Requires GitHub Actions runtime to confirm CI step actually fires and passes; deferred to next CI run (precedent: Phase 1013/1015 Gate E)"
  - test: "Run tests/test_examples_smoke.m once Phase 1012 P02 lands the smoke harness on this branch"
    expected: "Curated Octave smoke suite runs all examples not in SKIP_LIST_BEGIN/END block; the 3 rewritten 05-events demos appear in both skip lists once populated byte-identically"
    why_human: "Smoke harness file does not exist on this branch yet (Phase 1012 P02 lands it on main); parity is currently vacuous"
---

# Phase 1016: Examples 05-events rewrite (live demos + CI grep seal) Verification Report

**Phase Goal:** User running `examples/05-events/example_event_detection_live.m` and `example_event_viewer_from_file.m` sees full SensorTag + MonitorTag + EventStore + LiveEventPipeline + EventBinding pipelines (no deprecation stubs, no EventConfig references), and CI fails on any future re-introduction of the 8 Phase-1011 deleted classes via a grep gate baked into `.github/workflows/tests.yml`.

**Verified:** 2026-04-29
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | example_event_detection_live.m runs full Tag-API live pipeline with bounded timer | ✓ VERIFIED | TasksToExecute=5 at line 131; onCleanup at line 135; 3 SensorTag + 3 MonitorTag + EventStore + LiveEventPipeline + DashboardEngine all present |
| 2 | example_event_detection_live.m wires NotificationService(DryRun=true) | ✓ VERIFIED | Line 100: `NotificationService('DryRun', true, 'SnapshotDir', ...)` exact NV-pair literal |
| 3 | example_event_viewer_from_file.m has EventStore.save + EventViewer.fromFile, no live timer | ✓ VERIFIED | `store.save()` line 101; `EventViewer.fromFile` line 109; 0 `timer(` calls in file |
| 4 | example_live_pipeline.m monitors map keyed/valued with MonitorTag (not SensorTag) | ✓ VERIFIED | 6 MonitorTag(...) constructors (lines 51-56); 6 `monitors('key') = m...` assignments (lines 69-74); containers.Map present |
| 5 | All 3 demos start with TagRegistry.clear(); EventBinding.clear(); | ✓ VERIFIED | Lines 25-26 in detection_live, 24-25 in viewer_from_file, 23-24 in live_pipeline |
| 6 | No datetime/table/categorical/duration tokens in any of 3 demos | ✓ VERIFIED | grep `\b(datetime\|categorical\|duration\|table)\b` returns NONE for all 3 files |
| 7 | Distinct pedagogical headers; no copy-paste with example_sensor_threshold.m | ✓ VERIFIED | Three different framings: "LIVE pipeline", "PERSISTENCE narrative", "FULL feature surface". example_sensor_threshold.m is single-sentence, no "pedagogical purpose" framing |
| 8 | examples/run_all_examples.m has SKIP_LIST_BEGIN/END markers; parity script returns 0 | ✓ VERIFIED | SKIP_LIST_BEGIN line 32, SKIP_LIST_END line 33; `bash scripts/check_skip_list_parity.sh` exits 0 ("vacuously holds") |
| 9 | No persistent vars; bounded timer caps where present | ✓ VERIFIED | 0 `\bpersistent\b` matches across all 3 demos; only timer is in detection_live with TasksToExecute=5 |
| 10 | DIFF-01 grep seal in tests.yml; pre-flight clean; YAML valid | ✓ VERIFIED | Line 146 of tests.yml; positioned between metrics (143) and parity (205); local pre-flight scan returns exit 1 (no hits = clean); Python yaml.safe_load OK |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `examples/05-events/example_event_detection_live.m` | 3-sensor live demo with bounded timer + dry-run notif | ✓ VERIFIED | 158 lines, 3 SensorTag + 3 MonitorTag + LiveEventPipeline + NotificationService + DashboardEngine + onCleanup-wrapped bounded timer |
| `examples/05-events/example_event_viewer_from_file.m` | Batch detect → save → fromFile demo | ✓ VERIFIED | 112 lines, planted violations on 3 sensors, store.save() + EventViewer.fromFile(), no timer |
| `examples/05-events/example_live_pipeline.m` | Full notification-rule taxonomy with MonitorTag-valued map | ✓ VERIFIED | 222 lines, 6 MonitorTag (3 sensors × 2 severities), 3 NotificationRule priority tiers, manual runCycle x3 |
| `examples/run_all_examples.m` | SKIP_LIST_BEGIN/END marker block | ✓ VERIFIED | Lines 25-34: explanatory text outside markers (Option C); body empty (vacuous parity) |
| `.github/workflows/tests.yml` | DIFF-01 grep seal step in lint job | ✓ VERIFIED | Lines 146-203: 8-class alternation, lookbehind regex, inline self-test, exit-2/exit-1 distinction |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| example_event_detection_live.m | LiveEventPipeline | monitors containers.Map keyed by MonitorTag.Key | ✓ WIRED | Line 70-73 build map; line 97 pipeline = LiveEventPipeline(monitors, ...) |
| example_event_detection_live.m | NotificationService | pipeline.NotificationService = NotificationService(DryRun, true, ...) | ✓ WIRED | Line 100 |
| example_event_viewer_from_file.m | EventStore.save | store.append (via MonitorTag.getXY) + store.save() | ✓ WIRED | mPres/mTemp/mVib.getXY() lines 91-93 trigger event emission; store.save() line 101 |
| example_event_viewer_from_file.m | EventViewer | EventViewer.fromFile(eventFile) | ✓ WIRED | Line 109 |
| example_live_pipeline.m | LiveEventPipeline.runCycle | monitors map keyed with MonitorTag values | ✓ WIRED | Lines 68-74 build map with 6 MonitorTag values; for cycle = 1:3 / pipeline.runCycle() lines 166-170 |
| examples/run_all_examples.m | scripts/check_skip_list_parity.sh | SKIP_LIST_BEGIN/END marker block | ✓ WIRED | Lines 32-33; parity script exits 0 |
| .github/workflows/tests.yml lint job | 8 Phase-1011 deleted classes | grep -rE with word-boundary lookbehind | ✓ WIRED | Lines 161 (PATTERN literal), 192 (real scan); positioned between Run complexity metrics (143) and Skip-list parity gate (205) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Pre-flight: regex over current state returns 0 hits | `grep -rE '(^\|[^.a-zA-Z_])(Threshold\|CompositeThreshold\|StateChannel\|ThresholdRule\|Sensor\|SensorRegistry\|ThresholdRegistry\|ExternalSensorRegistry)\(' libs tests examples benchmarks` | exit 1 (no matches) | ✓ PASS |
| DIFF-01 hit-case: legacy Sensor( triggers regex | `echo 's = Sensor(1, 2, 3);' \| grep -E '<pattern>'` | exit 0 (matched) | ✓ PASS |
| DIFF-01 miss-case: surviving APIs do NOT match | `echo 'SensorTag(); MonitorTag(); fp.addThreshold(50); obj.addThreshold(50);' \| grep -E '<pattern>'` | exit 1 (no matches) | ✓ PASS |
| Skip-list parity script exits 0 | `bash scripts/check_skip_list_parity.sh` | "no skip-list blocks found... parity vacuously holds (exit 0)" | ✓ PASS |
| YAML well-formedness | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/tests.yml'))"` | YAML OK | ✓ PASS |
| MonitorTag count in live_pipeline = 6 | `grep -cE 'MonitorTag\s*\(' examples/05-events/example_live_pipeline.m` | 6 | ✓ PASS |
| MonitorTag count in detection_live = 3 | `grep -cE 'MonitorTag\s*\(' examples/05-events/example_event_detection_live.m` | 3 | ✓ PASS |
| MonitorTag count in viewer_from_file = 3 | `grep -cE 'MonitorTag\s*\(' examples/05-events/example_event_viewer_from_file.m` | 3 | ✓ PASS |
| Demo execution in real MATLAB/Octave | n/a | n/a | ? SKIP — deferred to next CI run |

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| DEMO-01 | 3-sensor live demo with SensorTag + MonitorTag + EventStore + LiveEventPipeline + DashboardEngine, TasksToExecute=5 + onCleanup | ✓ SATISFIED | example_event_detection_live.m: 3 SensorTag (lines 38-40), 3 MonitorTag (62-64), EventStore (56), LiveEventPipeline (97), DashboardEngine (113), TasksToExecute=5 (131), onCleanup (135) |
| DEMO-02 | NotificationService(DryRun=true) wired in example_event_detection_live.m | ✓ SATISFIED | Line 100: `NotificationService('DryRun', true, 'SnapshotDir', ...)` |
| DEMO-03 | example_event_viewer_from_file.m: batch-build → EventStore.save → EventViewer.fromFile, no live timer | ✓ SATISFIED | store.save() at 101; EventViewer.fromFile at 109; 0 `timer(` calls |
| DEMO-04 | example_live_pipeline.m: orphan blocks removed; monitors map MonitorTag-valued | ✓ SATISFIED | 6 MonitorTag values (lines 68-74); no orphan "% H Warning (upper):" comment blocks |
| DEMO-05 | All 3 demos call TagRegistry.clear(); EventBinding.clear(); at top | ✓ SATISFIED | Verified at lines 25-26, 24-25, 23-24 respectively |
| DEMO-06 | Octave-portable APIs only (no datetime/table/categorical/duration) | ✓ SATISFIED | grep returns NONE across all 3 files |
| DEMO-07 | Each demo's header documents distinct pedagogical purpose | ✓ SATISFIED | 3 distinct framings: "LIVE pipeline", "PERSISTENCE narrative", "FULL feature surface"; example_sensor_threshold.m has different style (no "pedagogical purpose" framing) |
| DEMO-08 | tests/test_examples_smoke.m and run_all_examples.m skip lists byte-identical (parity script returns 0) | ✓ SATISFIED | Markers present (lines 32-33); parity script exits 0 (vacuous PASS — both sides empty until smoke harness lands) |
| DEMO-09 | No persistent variables; no unbounded timers | ✓ SATISFIED | 0 `persistent` matches across all 3; only timer in detection_live is bounded by TasksToExecute=5 |
| DIFF-01 | tests.yml grep seal locks 8 deleted classes; surviving APIs allow-listed | ✓ SATISFIED | tests.yml lines 146-203; pre-flight clean (exit 1 = no hits); hit-case test passes; miss-case test passes; YAML valid |

**No orphaned requirements** — all 10 declared requirement IDs from PLAN frontmatter are mapped, and REQUIREMENTS.md confirms phase 1016 ships exactly DEMO-01..09 + DIFF-01.

### Anti-Patterns Found

None blocker. The verification gates already filtered out the cosmetic deviations documented in 1016-SUMMARY.md (header-token sanitization for `MonitorTag (alarm)`, `Duration: {duration}` template field, `persistent variables` prose). Current files are clean.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | — |

### Gates Verdict (ROADMAP 6 Success Criteria)

| # | ROADMAP Success Criterion | Verdict | Evidence |
|---|---------------------------|---------|----------|
| 1 | example_event_detection_live.m: 3-sensor live demo, bounded timer, NotificationService(DryRun=true) (DEMO-01, DEMO-02) | ✓ PASS | DEMO-01 + DEMO-02 verdicts above |
| 2 | example_event_viewer_from_file.m: batch-build → save → fromFile → click-to-plot, no live timer (DEMO-03) | ✓ PASS | DEMO-03 verdict above |
| 3 | example_live_pipeline.m: no orphan comment blocks; monitors map MonitorTag-valued (DEMO-04) | ✓ PASS | DEMO-04 verdict above |
| 4 | All 3 demos: TagRegistry.clear + EventBinding.clear preamble; Octave-portable APIs; distinct pedagogical headers (DEMO-05, DEMO-06, DEMO-07) | ✓ PASS | DEMO-05 + DEMO-06 + DEMO-07 verdicts above |
| 5 | Skip-list parity; no persistent vars or unbounded timers (DEMO-08, DEMO-09) | ✓ PASS | DEMO-08 + DEMO-09 verdicts above |
| 6 | tests.yml lint job grep gate fails CI on re-introduction of 8 deleted classes; addThreshold( allow-listed (DIFF-01) | ✓ PASS | DIFF-01 verdict above |

**Score: 6/6 PASS.**

### Human Verification Required

See frontmatter `human_verification:` block (5 deferred items).

Summary:
1. Real MATLAB/Octave runtime execution of the 3 demos (visual + behavioral verification of bounded timer firing, dashboard rendering, viewer opening, click-to-plot flow, snapshot PNGs)
2. DIFF-01 CI step actually firing in GitHub Actions on next push (precedent: Phase 1013/1015 deferred Gate E to next CI run)
3. Smoke-list parity activates byte-identical population once Phase 1012 P02 lands the smoke harness on this branch

These items are explicitly DEFERRED per the user prompt's "Deferral guidance" — no MATLAB locally, same precedent as Phase 1013/1015.

### Gaps Summary

None. All 10 requirements satisfied locally. All 6 ROADMAP success criteria pass. The DIFF-01 grep seal is present, well-formed, and the pre-flight scan against the current v2.1 tip returns 0 hits — meaning the seal will fire only on regressions, not immediately on commit.

The phase achieves its stated goal end-to-end:
- The 3 demo files use only the v2.0 Tag API surface (SensorTag, MonitorTag, EventStore, LiveEventPipeline, EventBinding, NotificationService, DashboardEngine)
- Zero `EventConfig` references
- Zero references to any of the 8 Phase-1011 deleted classes
- The CI grep seal locks this state forever — any future re-introduction fails the lint job

---

_Verified: 2026-04-29_
_Verifier: Claude (gsd-verifier)_
