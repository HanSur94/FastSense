---
status: resolved
trigger: "260512-live-mode-companion-adhoc-tail-spike — FastSenseCompanion ad-hoc plot shows tail-spike artifact in live mode only"
created: 2026-05-12T00:00:00Z
updated: 2026-05-12T12:30:00Z
symptoms_prefilled: true
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: CONFIRMED — buildPyramidFromMemory allocates px/py as exactly 2*nb and never appends a tail anchor; the last bucket's min and max land at their actual sample X positions (which are interior to the bucket), so the pyramid's final X is not x(end); FastSense.buildPyramidLevel uses ds.PyramidX directly (line 3736-3738); on every live tick updateData() creates a new FastSenseDataStore which calls buildPyramidFromMemory with the fresh data — the unanchored tail flows directly into the pyramid and then into the renderer as a spike
test: Compare the 2*nb allocation at line 867 with no tail-anchor append — vs the patched pattern in minmax_downsample.m which appends (x(end), y(end)) when px(end) < x(end)
expecting: Fix: after line 881 (obj.PyramidY = py), add tail-anchor logic mirroring minmax_downsample.m
next_action: Report ROOT CAUSE FOUND

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: Right edge of companion ad-hoc plot for "Cooling Out temp" shows bounded oscillation ~32-38 degC up to live timestamp, no synthetic spike
actual: Sharp sawtooth at right edge — drops to ~32, spikes to ~38, descends to ~34; tooltip showed "May 12 04:47:13, Cooling Out temp: 37" at apex; bulk of historic line (May 06-11) renders cleanly; artifact only appears at rightmost segment in live mode
errors: None — purely visual
reproduction: Run demo, open companion, double-click "Cooling Out temp" tag, enable live mode, observe right edge
started: Discovered 2026-05-12 after merging PR #133; existed all along in this code path — yesterday's fix didn't reach it

## Eliminated
<!-- APPEND only - prevents re-investigating -->

- hypothesis: MEX-level minmax_core_mex.c still has the unpatched interior-X pattern
  evidence: PR #133 (commit 31d04b7) is confirmed in main; user verified 9/9 MEX files compiled; dashboard FastSenseWidget reactor.pressure is now clean
  timestamp: 2026-05-12

- hypothesis: minmax_downsample.m (pure-MATLAB) still has the unpatched interior-X pattern
  evidence: PR #133 explicitly patched minmax_downsample.m with the same tail-anchor pattern
  timestamp: 2026-05-12

- hypothesis: FastSenseWidget.localMinMaxBuckets_ still has the unpatched interior-X pattern
  evidence: PR #133 explicitly patched FastSenseWidget.m localMinMaxBuckets_ with tail anchor
  timestamp: 2026-05-12

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-05-12T00:00:00Z
  checked: PR #133 commit 31d04b7 contents
  found: minmax_core_mex.c, minmax_downsample.m, FastSenseWidget.m all patched; FastSenseDataStore.m::buildPyramidFromMemory explicitly deferred as known-untouched location
  implication: Prime suspect is buildPyramidFromMemory; ad-hoc plot uses different data path than dashboard FastSenseWidget

- timestamp: 2026-05-12T00:01:00Z
  checked: openAdHocPlot.m
  found: For a single tag, mode is coerced to 'LinkedGrid' — spawns a DashboardEngine with engine.addWidget('fastsense', ...) containing the tag. The engine calls engine.startLive() which drives FastSenseWidget.refresh() on each tick, which calls tag.getXY() and FastSenseObj.updateData(1, x, y).
  implication: Code path is: companion live tick → FastSenseWidget.refresh() → updateData() → new FastSenseDataStore(newX, newY) → buildPyramidFromMemory() — the pyramid is rebuilt on every live tick with the new data

- timestamp: 2026-05-12T00:02:00Z
  checked: FastSenseDataStore.m lines 822-884 (buildPyramidFromMemory)
  found: Allocates px = zeros(1, 2*nb) and py = zeros(1, 2*nb) at lines 867-868. Fills them by interleaving actual min/max sample X coordinates (gMin, gMax indices into x[]). Sets obj.PyramidX = px at line 882. NO tail-anchor logic — function ends there. The last bucket's two points land at x(gMin(nb)) and x(gMax(nb)), both of which are interior to the last bucket when the global min/max happen before the bucket's last sample. In live mode the last bucket is always partial so this interior-X emission always creates a spike.
  implication: Exact same bug class as the pre-fix minmax_downsample.m — the pyramid tail X < x(end), so the renderer draws a synthetic segment from the pyramid tail to the actual data tail, creating the sawtooth spike

- timestamp: 2026-05-12T00:03:00Z
  checked: FastSense.m::buildPyramidLevel lines 3732-3761
  found: At line 3736-3738, if ds.PyramidX is non-empty, the pre-built pyramid is used directly as px/py — no re-downsampling. So the unanchored PyramidX flows straight into Pyramid{1}.X and then into the renderer. The fallback path (lines 3744-3760) calls minmax_downsample.m which IS patched — but that path is only taken when ds.PyramidX is empty (i.e., when buildPyramidFromMemory was not called).
  implication: On every live tick, buildPyramidFromMemory creates an unanchored pyramid, buildPyramidLevel picks it up verbatim, and updateLines renders it — producing the tail spike

- timestamp: 2026-05-12T00:04:00Z
  checked: FastSense.m::updateData lines 1742-1764
  found: On each live tick, updateData() calls FastSenseDataStore(newX, newY) (line 1751) which triggers buildPyramidFromMemory in the constructor, then clears Pyramid (line 1764). buildPyramidLevel is called lazily by updateLines → renderLine_ path.
  implication: The bug fires on every live tick, not just once — hence the persistent spike that moves with time

## Resolution
<!-- OVERWRITE as understanding evolves -->

falsified_hypothesis: FastSenseDataStore.buildPyramidFromMemory was NOT the root cause. For the 604,889-sample Cooling Out temp tag the demo never instantiates a FastSenseDataStore — `obj.shouldUseDisk(n)` returned false (data fits in memory), so `buildPyramidLevel` took the memory branch and called the already-patched `minmax_downsample` directly. The prior fix to `buildPyramidFromMemory` was reverted (it only addresses the disk-backed path, which this scenario never enters).

second_hypothesis_falsified: Inserting NaN at gaps in the displayed XData broke the line at the artifact, but the underlying tag data is fully continuous (n=604889, median dX=1.000s, max dX=4.9s). The "gap" was downstream of downsampling, not in the source — and the user's hover-crosshair correctly reported continuous values where my synthetic NaN-breaks were hiding the line. Reverted `breakAtGaps_` + `GapFactor`.

root_cause: TWO INDEPENDENT BUGS in the live ad-hoc plot path:
  1. **Wide-last-bucket sawtooth.** `minmax_core` (and the MEX twin) computed `bucketSize = floor(n/nb)` and folded the entire remainder `(n - bucketSize*nb)` into the last bucket. For n=604889, nb=6049 (typical pyramid call for 7-day 1Hz data), bucketSize=99 left a 6038-sample remainder ≈ 1.7 hours. The last bucket's interior min/max emissions sprawled across that window, producing the visible sawtooth. The yesterday's tail-anchor merely pinned the final X to the data tail; it did not stop the second-to-last and third-to-last interior emissions from creating the synthetic spike.
  2. **Live-mode XLim hijack.** `TimeRangeSelector.setDataRange` rescaled the selection proportionally on every live tick, which combined with `FastSenseWidget.LiveViewMode='reset'` (the dashboard default that openAdHocPlot was inheriting) pushed the chart's XLim right edge forward 1s/tick — preventing the user from panning back to inspect history.

fix:
  - `libs/FastSense/private/mex_src/minmax_core_mex.c` + `libs/FastSense/private/minmax_downsample.m` (nested `minmax_core`): bump `nb` to `floor(n / bucketSize)` so the remainder is strictly less than one bucket. Keeps every bucket the same time-width and the last bucket's emissions stay close to the data tail.
  - `libs/Dashboard/TimeRangeSelector.m::setDataRange`: when the new range fully contains the current selection (live-extension case), keep the selection unchanged — only rescale proportionally when the range contracts or the selection falls outside.
  - `libs/FastSenseCompanion/private/openAdHocPlot.m` (LinkedGrid path): pass `'LiveViewMode', 'preserve'` to each addWidget so each FastSense in an ad-hoc plot inherits preserve-XLim behavior. Dashboard widgets keep the `'reset'` default (the dashboard's expected behavior is unchanged).

verification: Live demo restart (`clear classes; install; run_demo`) followed by a programmatic ad-hoc plot on cooling.out_temp. Displayed line on the AdHoc Test figure: n=3025 points, dense oscillation reaching the live tail (`X[end]=12:28:33, Y=36.653`), max/median dX ratio = **3.94x** (was 66x with the bug). XLim stable across 5 ticks at `[05-05 12:20:30, 05-12 12:20:37]` (width = 7.000083 days, no drift). User visually confirmed: "yes that works now!"

files_changed:
  - libs/FastSense/private/mex_src/minmax_core_mex.c   (+13 -5)
  - libs/FastSense/private/minmax_core_mex.mexmaca64   (rebuilt)
  - libs/FastSense/private/minmax_downsample.m         (+22 -2)
  - libs/Dashboard/TimeRangeSelector.m                 (+18 -3)
  - libs/FastSenseCompanion/private/openAdHocPlot.m    (+10 -1)

deferred:
  - `FastSenseDataStore.buildPyramidFromMemory` inherits the same wide-last-bucket math; not patched here because no demo scenario currently exercises that path with a remainder large enough to be visible. Worth a follow-up sweep if the disk-backed pipeline becomes hot.
