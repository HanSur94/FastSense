---
quick_id: 260610-g0w
status: complete
date: 2026-06-10
---

# Summary: Preview-series shape fix + event extraction vectorization (perf round 2)

Profiler-driven (20 idle ticks, 8 Tag-bound widgets x 50k pts + 200 events).

## What changed
- `FastSenseWidget.getPreviewSeries`: bucket count derived from the minmax core's
  output length (odd = tail anchor). Root cause: 260512 bucket-math bumps nb inside
  minmax_core_mex; the old exact-shape check silently returned []. The MEX lives in
  libs/FastSense/private/ so production (no private path) always used the MATLAB
  fallback and was unaffected — but every TEST environment and any user session that
  ran a test (add_fastsense_private_path) lost slider previews AND the preview cache.
- `FastSenseWidget.getEventMarkers`: vectorized [raw.StartTime]/[raw.Severity]
  extraction + hoisted probes (isprop 8,280 -> 280 per 20 ticks).
- `DashboardEngine.computeEventMarkers`: per-class ismethod cache (6 ms/tick saved).
- `DashboardEngine.showStaleBanner`: skip redundant String/Visible sets.
- `TimeRangeSelector`: isLive_ guards on the three WindowButton callbacks — deleted
  selectors kept raising 'Invalid or deleted object' on mouse motion (chained
  motion-fcn closures outlive the object).

## Numbers (live R2025b)
- Profiled idle tick: 26.5 -> 22.5 ms; minmax recompute 320 -> 0 (cache hits).
- bench_dashboard_live: idle 34 ms, active 28 ms (vs 281/50 pre-v5p baseline) —
  now WITH preview lines actually drawing.

## Verification
- test_dashboard_perf_fixes 10/10 (new bucket-bump case), preview_envelope 7/7
  (case 6 updated to adaptive contract), preview_overlay 10/10,
  range_selector_integration 2/2, time_window 8/8.
- Code Analyzer: no new findings on the three lib files.
