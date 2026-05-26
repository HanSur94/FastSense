---
phase: 260508-n3u
plan: 01
subsystem: dashboard
tags: [dashboard, preview, fidelity, downsampling, threshold]
requires: []
provides:
  - "FastSenseWidget.PreviewRawThreshold_ private Constant (=100)"
  - "Threshold-aware nBucketsEff selection in FastSenseWidget.getPreviewSeries"
affects:
  - libs/Dashboard/FastSenseWidget.m
  - tests/test_dashboard_preview_envelope.m
tech-stack:
  added: []
  patterns:
    - "Private (Constant) properties block alongside SetAccess=private state"
    - "Branch-on-numel(x) before calling minmax_core_mex / localMinMaxBuckets_"
key-files:
  created: []
  modified:
    - libs/Dashboard/FastSenseWidget.m
    - tests/test_dashboard_preview_envelope.m
decisions:
  - "Threshold value = 100 — small enough that ~200 line vertices remain cheap to render; large enough that downsampling only kicks in once the slider preview is dense enough to genuinely benefit"
  - "Cache key shape unchanged — nBucketsEff already lives at index 4 of cacheKey, so crossing the threshold naturally invalidates the cache"
  - "DashboardEngine.computePreviewEnvelopeReturning_ intentionally NOT modified — its aggregate envelope drops series whose numel ~= nBuckets, but the per-widget LINE (which is the visible improvement) draws regardless"
metrics:
  completed: 2026-05-08
  commits: 1
  files_modified: 2
  test_cases_added: 5
requirements:
  - N3U-01
---

# Quick Task 260508-n3u: Preview Skips Downsampling Under 100 Samples Summary

Slider preview line now renders at full per-sample fidelity for `FastSenseWidget` instances bound to small / freshly-live datasets (numel(x) ≤ 100); legacy `floor(numel(x)/2)` downsampling kicks in only above the threshold.

## Implementation

### Files Changed

**`libs/Dashboard/FastSenseWidget.m`**
- Added a new `properties (Access = private, Constant)` block (immediately after the `SetAccess=private` block) declaring `PreviewRawThreshold_ = 100` with a 9-line header explaining the rationale (cheap render budget vs. meaningful downsampling cut-off).
- Site 1 (initial nBucketsEff computation, around former L478-481): replaced the unconditional `nBucketsEff = max(1, min(nBuckets, floor(numel(x)/2)))` with a branch that returns `nBucketsEff = numel(x)` when `numel(x) <= obj.PreviewRawThreshold_`, falling through to the legacy formula otherwise. Inline comment explains the WHY (downsampling artefacts dominate small datasets).
- Site 2 (post-NaN-drop recomputation, around former L494-503): same threshold branch, applied after the NaN mask has shrunk `x`/`y`. Ensures a 60-sample sensor with 5 NaNs renders 55 buckets (raw) rather than `floor(55/2)=27` (downsampled).

The `cacheKey` shape was deliberately left untouched — `nBucketsEff` is already its 4th element, so the cache invalidates automatically when crossing the threshold (verified implicitly by the existing `case_preview_cache_short_circuit` test, which still passes).

### Test Cases Added

`tests/test_dashboard_preview_envelope.m` was extended from 2 to 7 cases, all driving `FastSenseWidget.getPreviewSeries` directly (no `DashboardEngine.render()` overhead — keeps the threshold contract crisp and runtime-portable):

1. **case_small_dataset_no_downsample** — 50 samples → asserts `numel(xCenters) == 50`, `numel(yMin) == 50`, `numel(yMax) == 50`. (Pre-fix returned 25.)
2. **case_threshold_boundary_at_100** — 100 samples → `numel(xCenters) == 100`. Pins the inclusive boundary.
3. **case_threshold_boundary_at_101** — 101 samples → `numel(xCenters) == min(200, floor(101/2)) == 50`. Pins that the legacy branch kicks in just above 100.
4. **case_large_dataset_unchanged** — 500 samples → `numel(xCenters) == 200`. Guards against accidental regression of legacy behavior.
5. **case_small_with_nans** — 60 samples / 5 NaNs → 55 valid → `numel(xCenters) == 55`. Verifies Site 2 (post-NaN-drop) honors the threshold too.

The closing `fprintf('    All N tests passed.\n', ...)` line was bumped from `2` to `7`.

## Why 100 Was Chosen

- Below ~100 samples a downsampled preview produces visibly stair-stepped, coarse line segments — the very "preview line" the user sees on the slider during the first minute or two of live capture is degraded for no perceptual benefit.
- 100 samples × 2 vertices/bucket (min/max pairs from `minmax_core_mex`) = ~200 line vertices, well below any rendering hot-spot. Cheap regardless of MEX vs. fallback path.
- 101+ samples: `floor(101/2) = 50` buckets is enough to convey shape; 200 buckets is the slider's typical request budget. Downsampling at this scale starts paying for itself.
- Single class-level constant means future tuning is one-line, well-documented, and applied uniformly to both sites in `getPreviewSeries`.

## Verification

Regression sweep (5 tests, run on MATLAB R2025b — Home License):

| Test | Result |
|------|--------|
| `test_dashboard_preview_envelope` | 7/7 (incl. 5 new threshold cases) |
| `test_dashboard_preview_overlay`  | 10/10 |
| `test_dashboard_engine_event_markers` | 9/9 |
| `test_dashboard_widget_button_bar` | 5/5 |
| `test_dashboard_time_sync_all_pages` | 5/5 |

`mh_lint libs/Dashboard/FastSenseWidget.m` — clean ("everything seems fine").

Octave parity sweep confirms preview tests pass on Octave 9.2.0 too. The Octave run of `test_dashboard_time_sync_all_pages` fails on `addlistener('PostSet', …)` for a graphics axes property — a **pre-existing baseline failure** verified by re-running on the unmodified tree (`git stash`) and unrelated to this task.

## Deviations from Plan

### Auto-fixed Issues

None.

### Out-of-scope Deferrals

None.

The plan's optional Step 7 ("Verify nothing else in test_dashboard_preview_overlay.m relies on the old `floor(numel(x)/2)` behavior for small N") was checked: `case_small_dataset_adaptive_buckets` uses 50 samples and asserts `numel(s.xCenters) >= 4` — passes equally well with the new (50 buckets) and old (25 buckets) behavior. `case_preview_cache_short_circuit` uses 1000 samples (well above threshold). No edits required.

## Commits

| Hash | Message |
|------|---------|
| `4a260ef` | feat(260508-n3u): skip preview downsampling for sensors with <=100 samples |

## Self-Check: PASSED

- [x] FOUND: libs/Dashboard/FastSenseWidget.m (modified)
- [x] FOUND: tests/test_dashboard_preview_envelope.m (modified, 7 cases)
- [x] FOUND: commit 4a260ef
- [x] FOUND: PreviewRawThreshold_ = 100 (private Constant on FastSenseWidget)
- [x] FOUND: 5 new test cases (case_small_dataset_no_downsample, case_threshold_boundary_at_100, case_threshold_boundary_at_101, case_large_dataset_unchanged, case_small_with_nans)
- [x] All 5 regression-sweep tests pass on MATLAB
- [x] MISS_HIT lint clean
- [x] PreviewRawThreshold_ honored at both nBucketsEff sites (initial + post-NaN-drop)
