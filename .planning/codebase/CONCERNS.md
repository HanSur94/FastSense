# Codebase Concerns

**Analysis Date:** 2026-04-01

## Tech Debt

**GroupWidget collapse/expand does not trigger layout reflow:**
- Issue: When a `GroupWidget` collapses or expands, `DashboardLayout.reflow()` is not called. The widget's `Position(4)` is updated but the surrounding grid is not re-compacted. Two TODO comments explicitly track this.
- Files: `libs/Dashboard/GroupWidget.m` (lines 241, 260)
- Impact: Collapsible/tabbed widgets leave visual gaps in the dashboard grid after collapse. Other widgets do not fill the freed space.
- Fix approach: Add a `LayoutRef` or `FigureRef` handle to `GroupWidget` and call `DashboardEngine.rerenderWidgets()` (or equivalent reflow method) after toggling `Collapsed`.

**Extreme complexity limits in MISS_HIT config:**
- Issue: `miss_hit.cfg` sets `cyc` (cyclomatic complexity) limit to 80 and `function_length` limit to 520 lines. The stated aspirational targets are 20 and 200 respectively. Many rules are suppressed (`indentation`, `operator_whitespace`, `whitespace_keywords`, etc.).
- Files: `miss_hit.cfg`, `libs/FastSense/FastSense.m` (3297 lines), `libs/FastSense/FastSenseToolbar.m` (1270 lines), `libs/Dashboard/DashboardBuilder.m` (1044 lines), `libs/FastSense/FastSenseDataStore.m` (963 lines)
- Impact: Static analysis is not enforcing meaningful quality gates. Complex methods are hard to test in isolation and easy to regress.
- Fix approach: Incrementally tighten limits as functions are extracted. Re-enable suppressed rules one by one.

**`FastSense.m` is a 3297-line god class:**
- Issue: The `FastSense` class handles rendering, downsampling, threshold management, live mode, link group coordination, zoom/pan callbacks, loupe tool, figure export, and more. Internal `IsPropagating` flag guards re-entrancy manually.
- Files: `libs/FastSense/FastSense.m`
- Impact: Any change risks breaking unrelated features. Test coverage calls `render()` but cannot isolate individual subsystems.
- Fix approach: Extract live-mode, link-group registry, and loupe tool into separate helper classes.

**Pervasive `datenum`/`datestr`/`now` usage (deprecated since MATLAB R2014b):**
- Issue: `datestr(now, ...)`, `info.datenum`, `datenum(...)` are used across multiple files for file modification tracking and timestamp stamping. These functions are legacy and may not work correctly with newer datetime types.
- Files: `libs/EventDetection/EventStore.m` (lines 95, 129, 140), `libs/EventDetection/NotificationService.m` (line 114), `libs/EventDetection/generateEventSnapshot.m` (line 28), `libs/EventDetection/NotificationRule.m` (lines 61–62), `libs/FastSense/FastSenseToolbar.m` (lines 1021, 1261), `libs/FastSense/FastSenseGrid.m` (line 604), `libs/SensorThreshold/loadModuleMetadata.m` (line 49)
- Impact: Inconsistent time handling; `now` is not timezone-aware and mixing datenum with `datetime` causes silent precision loss.
- Fix approach: Migrate to `datetime('now')` and `posixtime`/`seconds` for durations. Replace `info.datenum` checks with `datetime(info.date)` comparisons.

**Persistent link registry accumulates dead handles:**
- Issue: `FastSense.getLinkRegistry` stores FastSense handles in a `persistent` struct. Dead entries (closed figures) are only pruned when `cleanup` action is called explicitly. Normal `get` and `register` operations do not prune.
- Files: `libs/FastSense/FastSense.m` (lines 3154–3183)
- Impact: Long-running sessions accumulate dead object references in the persistent registry. Memory leaks in interactive use.
- Fix approach: Prune dead handles on every `get` call, not just explicit `cleanup` calls.

**`EventStore.loadFile` uses a static persistent cache shared across all instances:**
- Issue: `loadFile` is a static method with `persistent lastModTime lastData` maps keyed by file path. All `EventStore` instances share this cache and there is no mechanism to invalidate it except by clearing the function.
- Files: `libs/EventDetection/EventStore.m` (lines 82–123)
- Impact: In multi-pipeline scenarios where two `EventStore` objects write to the same path, the second writer's changes may not be seen by readers that already cached the file.
- Fix approach: Move the cache to an instance property or add an explicit `invalidate(filePath)` static method.

**Hardcoded 1M-point chunk sizes in `FastSense.m`:**
- Issue: `chunkSize = 1000000` appears at three separate call sites in `FastSense.m` for in-memory pyramid computation. This is independent of and inconsistent with the `PyramidReduction` property.
- Files: `libs/FastSense/FastSense.m` (lines 456, 857, 2857)
- Impact: Users who tune `PyramidReduction` will not see any change in in-memory pyramid chunking.
- Fix approach: Replace hardcoded values with `obj.PyramidReduction`-derived calculation or a named constant.

## Known Bugs

**`IsPropagating` is not reset if `propagateXLim` throws:**
- Symptoms: If an exception occurs inside the `for` loop in `propagateXLim` after setting `other.IsPropagating = true`, it is never reset to `false`. Subsequent zoom/pan on that group member silently does nothing.
- Files: `libs/FastSense/FastSense.m` (lines 3113–3125)
- Trigger: Any error in `other.updateLines()`, `updateShadings()`, or `updateViolations()` on a linked plot.
- Workaround: Clear and re-render affected `FastSense` instances.

**`runLive` blocking loop swallows all errors silently:**
- Symptoms: In the Octave compatibility loop (`runLive`), the inner `catch` block has no variable and no log message. Any error in `LiveUpdateFcn` or `load()` is silently discarded.
- Files: `libs/FastSense/FastSenseGrid.m` (lines 718–728), `libs/FastSense/FastSense.m` (similar pattern at line 1904)
- Trigger: Malformed `LiveFile` or exception in `LiveUpdateFcn`.
- Workaround: Set `Verbose = true` (does not help here as the catch block is unconditional).

## Security Considerations

**`system()` call in `DashboardEngine.showInfo` uses string concatenation:**
- Risk: On Octave, the file path passed to `open`/`xdg-open`/`cmd /c start` comes from `obj.InfoTempFile`, which is a `tempname`-generated path. While not user-controllable in normal use, the pattern of building shell commands via string concatenation is fragile if the temp directory path contains special characters.
- Files: `libs/Dashboard/DashboardEngine.m` (lines 380–384)
- Current mitigation: Quotes are added around the path, limiting exposure. MATLAB path uses `web()` instead.
- Recommendations: Use `system` only when `web()` is unavailable; consider escaping the path with `strrep(path, '"', '\"')`.

**`feval(funcname)` on user-supplied `.m` file paths in `DashboardEngine.load`:**
- Risk: Loading a dashboard from an `.m` file calls `addpath(fdir)` and `feval(funcname)` where `funcname` is derived from the file basename. Any MATLAB function in that directory becomes callable.
- Files: `libs/Dashboard/DashboardEngine.m` (lines 810–813), `libs/Dashboard/DashboardSerializer.m` (lines 144–146)
- Current mitigation: `onCleanup` removes the path after the call. The function must return a `DashboardEngine`.
- Recommendations: Validate that `funcname` matches `[A-Za-z][A-Za-z0-9_]*` before calling `feval`. Document the trust boundary explicitly.

**WebBridge TCP server bound only to `localhost`:**
- Risk: The bridge server listens on `localhost:0` (random port) and the Python bridge is launched on the same machine. If an attacker has local code execution, they can connect to any open port.
- Files: `libs/WebBridge/WebBridge.m` (line 34), `bridge/python/fastsense_bridge/__main__.py`
- Current mitigation: Binding to `localhost` prevents network-level access. No auth on TCP channel.
- Recommendations: Add a nonce/token to the init handshake so the Python bridge must prove it received the MATLAB-generated token.

## Performance Bottlenecks

**`FastSenseDataStore.getColumnRange` reads entire column into memory:**
- Problem: For extra columns (labels, categoricals, etc.), `getColumnRange` assembles all relevant chunks and trims in MATLAB. For columns with many chunks, this loads much more data than needed.
- Files: `libs/FastSense/FastSenseDataStore.m` (lines 155–185)
- Cause: SQLite query fetches all column chunks that overlap the X range, then MATLAB trims. No server-side filtering on column values is possible without an index.
- Improvement path: Add a point-offset index to extra-column tables mirroring the main data table, enabling SQLite range queries on `pt_offset`.

**`DashboardLayout.allocatePanels` destroys and re-creates all panels on every rerender:**
- Problem: Every call to `rerenderWidgets` in `DashboardEngine` triggers `allocatePanels`, which deletes the entire viewport/canvas hierarchy and rebuilds it from scratch.
- Files: `libs/Dashboard/DashboardLayout.m` (lines 198–232), `libs/Dashboard/DashboardEngine.m`
- Cause: No incremental update path; full rebuild is simpler but expensive for large dashboards.
- Improvement path: Add dirty-flag logic so only widgets with changed positions are moved rather than all panels being deleted and recreated.

## Fragile Areas

**MEX binary/mksqlite fallback chain:**
- Files: `libs/FastSense/FastSenseDataStore.m` (lines 68, 542–550), `libs/FastSense/private/minmax_downsample.m`, `libs/FastSense/private/lttb_downsample.m`, `libs/FastSense/private/binary_search.m`, `libs/FastSense/private/violation_cull.m`, `libs/SensorThreshold/private/compute_violations_batch.m`, `libs/SensorThreshold/private/compute_violations_disk.m`, `libs/SensorThreshold/private/toStepFunction.m`
- Why fragile: Seven distinct persistent-variable MEX detection points. Each uses `exist('xxx_mex', 'file') == 3` and caches the result forever in `persistent useMex`. If a MEX file is recompiled mid-session (without clearing functions), the cache is stale.
- Safe modification: After calling `build_mex`, always `clear functions` before running tests. The cache is invalidated by function clear.
- Test coverage: `tests/test_violations_mex_parity.m`, `tests/suite/TestMexParity.m` cover correctness parity but not the fallback detection logic itself.

**`EventViewer` uses `findjobj` (undocumented Java API):**
- Files: `libs/EventDetection/EventViewer.m` (lines 742–748)
- Why fragile: `findjobj` is not a MathWorks-documented function. It relies on MATLAB's internal Java component tree, which changes between releases. The code has a graceful catch but the scroll-to-row feature silently breaks on newer MATLAB versions or in compiled apps.
- Safe modification: Wrap in a try/catch (already done). Consider replacing with `uitable` `SelectionChangedFcn` and `scroll` in R2021b+.
- Test coverage: Not tested.

**`WebBridge.launchBridge` polls with a 10-second busy loop:**
- Files: `libs/WebBridge/WebBridge.m` (lines 226–242)
- Why fragile: Uses `system(fullCmd)` to launch the Python bridge as a background process, then busy-polls `obj.HttpPort > 0` in a `drawnow/pause(0.1)` loop. On Windows, `start /B` does not cd to `bridgeDir` first, so the Python module path may be wrong.
- Safe modification: Test on Windows before shipping bridge-dependent features. Add a timeout error with actionable diagnostic message (already done for the 10s case).
- Test coverage: `tests/suite/TestWebBridgeE2E.m` exists but likely requires a live Python environment.

**Dual-format test suite (legacy scripts + `matlab.unittest`):**
- Files: `tests/*.m` (legacy function-based), `tests/suite/Test*.m` (class-based `matlab.unittest`)
- Why fragile: Two test runners are maintained. `tests/run_all_tests.m` likely does not run `tests/suite/` classes, creating coverage gaps. Changes must be verified in both harnesses.
- Safe modification: Prefer adding new tests to `tests/suite/` only. Consider migrating legacy tests incrementally.
- Test coverage: No CI verification that both suites pass together.

## Scaling Limits

**SQLite connection slot exhaustion:**
- Current capacity: mksqlite allows a limited number of simultaneous open connections (typically 10–64 depending on build).
- Limit: Each `FastSenseDataStore` consumes one connection slot. A dashboard with many `FastSenseWidget` instances can exhaust the pool. `ensureOpen`/`closeDb` partially mitigates this by reopening on demand, but slot tracking is per-process.
- Scaling path: Pool connections across DataStore instances, or use WAL mode + connection sharing where reads are concurrent.

**`FastSense` pyramid cache held entirely in memory:**
- Current capacity: Each `FastSense` instance holds a multi-level in-memory pyramid (levels computed at PyramidReduction=100). For a 10M-point series this is ~100K + ~1K + ... points per level per line.
- Limit: With many lines or high `PyramidReduction`, aggregate pyramid memory can exceed available RAM before the `FastSenseDataStore` disk offload threshold is reached.
- Scaling path: Offload pyramid levels to the SQLite store or compute them lazily on first zoom to that level.

## Dependencies at Risk

**`mksqlite` is a bundled, locally-compiled MEX wrapper:**
- Risk: `mksqlite` is not a standard MATLAB toolbox. The project bundles `mksqlite.c` and compiles it locally via `build_mex.m`. If the bundled source becomes incompatible with a future MATLAB C API version, the entire disk-storage path breaks.
- Impact: `FastSenseDataStore` falls back to binary file storage (no extra columns), and violation caching is unavailable.
- Migration plan: Track upstream mksqlite releases. Consider using MATLAB's `database` toolbox SQLite support (introduced R2021a) as a long-term alternative.

**Python bridge requires Python ≥ 3.11 and specific package versions:**
- Risk: `pyproject.toml` pins `fastapi>=0.104`, `uvicorn[standard]>=0.24`, `websockets>=12.0`, `numpy>=1.24`. These are lower bounds only. Upper bounds are missing, so future breaking changes in any dependency will silently break the bridge.
- Impact: Web-based dashboard visualization (`WebBridge.serve()`) stops working.
- Migration plan: Add upper bounds or use a lockfile (`uv.lock` / `requirements.txt`) to pin exact versions.

## Missing Critical Features

**No `DashboardLayout.reflow()` call from GroupWidget:**
- Problem: Collapse/expand of collapsible `GroupWidget` tiles does not reflow the grid. This is explicitly tracked as a TODO but blocks a key UX feature of the dashboard system.
- Blocks: Usable collapsible and tabbed widget groups in live dashboards.

**No authentication on WebBridge TCP channel:**
- Problem: Any process on localhost can connect to the MATLAB TCP server and receive the full dashboard init message including all SQLite DB file paths.
- Blocks: Safe deployment in shared-workstation or CI environments.

## Test Coverage Gaps

**`WebBridge.launchBridge` system call is not unit-tested:**
- What's not tested: The `system()` launch of the Python bridge process, port acquisition, and `bridge_ready` handshake on Windows.
- Files: `libs/WebBridge/WebBridge.m` (lines 226–242)
- Risk: Silent failures on Windows due to missing `cd` before `start /B`.
- Priority: Medium

**`EventViewer.scrollToRow` (findjobj path) has no test:**
- What's not tested: The Java scroll-to-selected-row path in `EventViewer`.
- Files: `libs/EventDetection/EventViewer.m` (lines 742–748)
- Risk: Breaks silently on newer MATLAB versions without detection.
- Priority: Low

**GroupWidget collapse/expand layout side effects are not tested:**
- What's not tested: Visual grid state after collapsing a `GroupWidget` inside a rendered `DashboardEngine`.
- Files: `libs/Dashboard/GroupWidget.m`, `libs/Dashboard/DashboardEngine.m`
- Risk: When reflow is eventually wired up, regressions will not be caught.
- Priority: Medium

**Live mode error recovery has no test:**
- What's not tested: Behaviour when `LiveUpdateFcn` throws inside the polling loop (both timer-based and Octave blocking loop paths).
- Files: `libs/FastSense/FastSense.m` (onLiveTimer), `libs/FastSense/FastSenseGrid.m` (runLive)
- Risk: Silent data loss or frozen UI in production.
- Priority: High

**MEX detection cache staleness after `build_mex` mid-session:**
- What's not tested: Calling `build_mex` and then running a function that uses the cached `persistent useMex = false` value.
- Files: All `private/*.m` files using `persistent useMex`, `libs/FastSense/binary_search.m`
- Risk: Users who compile MEX after an initial run get no benefit until they restart MATLAB.
- Priority: Medium

---

*Concerns audit: 2026-04-01*
