---
phase: quick-260526-pqz
plan: 01
subsystem: Dashboard
tags: [preview, slider, fastsense-widget, cap-raise]
requires: []
provides:
  - "Raised per-signal slider-preview cap from 400 -> 1000 buckets"
affects:
  - "libs/Dashboard/DashboardEngine.m::computePreviewEnvelopeReturning_"
  - "libs/Dashboard/DashboardEngine.m::computePreviewEnvelope (doc-comment)"
  - "tests/test_dashboard_preview_overlay.m (doc-comment consistency)"
tech-stack:
  added: []
  patterns:
    - "Surgical 3-edit cap-raise in clamp expression + 2 documenting comments"
    - "Test-side comment kept in sync (no assertion change)"
key-files:
  created: []
  modified:
    - libs/Dashboard/DashboardEngine.m
    - tests/test_dashboard_preview_overlay.m
decisions:
  - "Deliberately did NOT invalidate the cached PreviewNBuckets_; running demos must restart (or resize) to pick up the new cap. This keeps the diff surgical and avoids touching the live-tick caching path."
metrics:
  duration: "~3m"
  completed: "2026-05-26T16:39:29Z"
---

# Phase quick-260526-pqz Plan 01: Raise Preview Line Cap per Signal from 400 -> 1000 Summary

Raised the per-signal slider-preview bucket cap in `DashboardEngine.computePreviewEnvelopeReturning_` from `min(400, ...)` to `min(1000, ...)` so wide windows (>=2000 px) drive proportionally more preview detail; three textual edits in `DashboardEngine.m` (1 code line + 2 comments) plus one consistency comment in the overlay test.

## Changes

### `libs/Dashboard/DashboardEngine.m` (3 edits — all within the same method body, lines ~3520-3560)

1. **Line 3524 — doc-comment on `computePreviewEnvelope`:**
   - `%   [50, 400]. Silently no-ops...` -> `%   [50, 1000]. Silently no-ops...`

2. **Line 3542 — inline comment in `computePreviewEnvelopeReturning_`:**
   - `% Derive nBuckets from figure pixel width; clamp to [50, 400].` -> `% Derive nBuckets from figure pixel width; clamp to [50, 1000].`

3. **Line 3555 — the actual clamp expression:**
   - `nBuckets = max(50, min(400, floor(axWpx / 2)));` -> `nBuckets = max(50, min(1000, floor(axWpx / 2)));`

### `tests/test_dashboard_preview_overlay.m` (1 edit — comment-only, no assertion change)

4. **Line 95 — test doc-comment in `case_small_dataset_adaptive_buckets`:**
   - `%   Default aggregator picks nBuckets in [50, 400]; with 50 samples,` -> `%   Default aggregator picks nBuckets in [50, 1000]; with 50 samples,`

The assertion below (`numel(xd) >= 4`) is independent of the cap, so no test logic was touched.

## Verification

### Static analysis

- `grep -n "\b400\b" libs/Dashboard/DashboardEngine.m` -> **empty** (no matches)
- `grep -n "\b400\b" tests/test_dashboard_preview_overlay.m` -> **empty** (no matches)
- `grep -n "\b1000\b" libs/Dashboard/DashboardEngine.m` near preview function -> **3 matches at lines 3524, 3542, 3555**
- `mh_lint libs/Dashboard/DashboardEngine.m` -> "everything seems fine" (no new diagnostics)
- `mh_style libs/Dashboard/DashboardEngine.m` -> clean
- `mh_style tests/test_dashboard_preview_overlay.m` -> clean

### Test runs

**MATLAB (R2025a on macOS ARM64):**

| Test file | Result |
|---|---|
| `tests/test_dashboard_preview_envelope.m` | **7/7 passed** |
| `tests/test_dashboard_preview_overlay.m` | **10/10 passed** |

**Octave (11.1.0 on macOS ARM64):**

| Test file | Result |
|---|---|
| `tests/test_dashboard_preview_envelope.m` | **2/2 passed, 5 skipped** (`TimeRangeSelector` guard — patch+FaceAlpha+NaN crashes Octave xvfb; pre-existing) |
| `tests/test_dashboard_preview_overlay.m` | **skipped entirely** (TimeRangeSelector unavailable on Octave — pre-existing) |

The Octave skips are pre-existing and not affected by this change.

### Regression sweep

`grep -rn "\b400\b" tests/ | grep -iE "(preview\|bucket\|envelope)"` -> empty. No stale `400` literal remains anywhere in the test suite that mentions the preview / bucket / envelope concept.

## Deviations from Plan

None — plan executed exactly as written. All four edit sites were applied at the line numbers documented in the plan's `<grep_verification>` block.

## Important: cache reminder

The cached `PreviewNBuckets_` on `DashboardEngine` is **intentionally** left alone (out of scope per the plan's "Out of scope" note). For users with a running industrial-plant demo, the new cap will only take effect on:

  (a) restart of the demo (`run demo/industrial_plant/run_demo.m`), or
  (b) a dashboard window resize (the existing path at `DashboardEngine.m` line ~2241 invalidates `PreviewNBuckets_` on resize).

After either event, wide windows (>800 px / ~94% = >752 px of axes width -> nBuckets > 376) will see denser preview detail per signal in the bottom slider strip, up to a new ceiling of 1000 points per signal (achievable at ~2128 px of figure width and above).

## Forward-looking note

If a future user requests "the slider should always reflect the configured cap immediately without restart", the fix is one of:

  (a) call `obj.PreviewNBuckets_ = 0` at the end of `DashboardEngine` setup (or after `render()`), or
  (b) extend the cache-invalidation path at `DashboardEngine.m` line ~2241 to also re-derive on construct / initial render.

This was deliberately out of scope for this quick task.

## Commits

| Task | Commit | Files |
|---|---|---|
| 1 — Raise cap + sync comments | `834b43c` | `libs/Dashboard/DashboardEngine.m`, `tests/test_dashboard_preview_overlay.m` |
| 2 — Verification only (no edits) | — | (no commit; verification confirmed Task 1 edits) |

## Self-Check: PASSED

- File `libs/Dashboard/DashboardEngine.m` exists and contains `min(1000, floor(axWpx / 2))` at line 3555.
- File `tests/test_dashboard_preview_overlay.m` exists and contains `[50, 1000]` at line 95.
- Commit `834b43c` exists in the worktree branch log.
- `mh_lint` and `mh_style` both clean.
- Both preview test files pass in MATLAB (7/7 and 10/10).
