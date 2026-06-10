---
quick_id: 260610-hwj
description: Review-sweep fixes batch 2 - widget serialization round-trips, disk-backed export, stale marker test helper
date: 2026-06-10
mode: quick-inline
---

# Quick Task 260610-hwj: Review-sweep fixes batch 2

Second batch of fixes from the 2026-06-09 three-agent review sweep, branched off main
(claude/review-fixes-batch2) so PR #197 stays scoped to the perf pass.

## Fixes (all reviewer claims re-verified against source before editing)
1. GaugeWidget.fromStruct 'threshold' source -> obj.Threshold (was obj.Tag).
   Bonus find while testing: constructor range derivation called allValues(),
   which only existed pre-v2.0 — MonitorTag-bound gauges crashed at construction.
2. GroupWidget ExpandedHeight round-trip (omit-when-empty).
3. Central themeOverride backfill in DashboardWidgetRegistry.fromStruct
   (only GroupWidget restored it; every other widget dropped it on load).
4. FastSense.buildExportStruct_ -> lineFullData (disk-backed lines exported empty).
5. test_dashboard_engine_event_markers markerXData parses batched NaN-separated
   marker polylines (stale since 260508-slider-stuck).

## Verification
- New tests/test_review_fixes_batch2.m: 4/4 MATLAB R2025b, 3/3 + 1 gated Octave 11.
- test_dashboard_engine_event_markers: 9/9 on MATLAB (first pass ever on MATLAB).
- TestDashboardSerializerRoundTrip 15/15, TestDashboardSerializer 12/12, test_toolbar 19/19.
