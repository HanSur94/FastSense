---
phase: 1045
slug: cross-machine-comparison-view
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-10
---

# Phase 1045 — Validation Strategy

> Per-phase validation contract. Derived from 1045-RESEARCH.md `## Validation Architecture`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB `matlab.unittest.TestCase` (class suites) + Octave flat `test_*.m` |
| **Config file** | `tests/run_all_tests.m` |
| **Quick run command** | `mcp__matlab__run_matlab_test_file('tests/suite/TestFastSenseCompanion.m')` / `mcp__matlab__evaluate_matlab_code` `install; run('tests/test_compare_resolution.m')` |
| **Full suite command** | `mcp__matlab__run_matlab_file('tests/run_all_tests.m')` |
| **Estimated runtime** | flat tests seconds; companion suite ~4 min |

Session hygiene (from 1044 experience): clean `timerfindall` + stray figures between suite runs in the live MCP session — leaked suite timers cause graphics storms.

---

## Sampling Rate

- **After every task commit:** relevant flat test (`test_compare_resolution.m`, `test_companion_open_ad_hoc_plot.m`) run via the MATLAB MCP test runner on logic tasks; `check_matlab_code` on UI tasks. Logic-task `<verify>` blocks invoke the real test runner (not a file-shape grep) so a broken test fails the gate.
- **After every plan wave:** flat tests + `TestFastSenseCompanion.m`
- **Before `/gsd-verify-work`:** companion suite green at the 1044 baseline (82/84 — PerTag/ADHOC05 = documented pre-existing flake) + flat tests green
- **Max feedback latency:** ~4 min (suite); seconds (flat)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | mapper resolve + Fleet.mapper | 1 | CMP-05 seam | — | N/A | unit (flat) | `install; run('tests/test_compare_resolution.m')` | ❌ W1 | ⬜ pending |
| TBD | resolution assembly | 1 | CMP-03/04 | T-1045-01 | LOW never auto-included | unit (flat) | `install; run('tests/test_compare_resolution.m')` | ❌ W1 | ⬜ pending |
| TBD | color index + theme path | 1 | CMP-02 | — | N/A | unit (flat) | same | ❌ W1 | ⬜ pending |
| TBD | openAdHocPlot NV args | 1 | CMP-02 | T-1045-02 | legacy calls byte-compat | unit (flat MATLAB-only) | `install; run('tests/test_companion_open_ad_hoc_plot.m')` | ✅ extend | ⬜ pending |
| TBD | CompareBuilderDialog | 2 | CMP-01/03/04/05/06 | T-1045-03a/b/c | N/A | class suite | `run_matlab_test_file TestFastSenseCompanion` | ❌ W3 | ⬜ pending |
| TBD | toolbar + wiring | 4 | CMP-01 | T-1045-05a | fleet-only button; legacy [1 10] | class suite | same | ❌ W3 | ⬜ pending |
| TBD | CMP-03 skip-graceful | 4 | CMP-03 | T-1045-05d | 'none' machine skipped + opens with rest | class suite | `testCMP03_SkipGraceful` | ❌ W3 | ⬜ pending |
| TBD | CMP-05 cache invariant | 4 | CMP-05 | T-1045-05c | no resolve in tick path | class suite | `testCMP05_NoResolveInTick` | ❌ W3 | ⬜ pending |
| TBD | promote flow | 4 | CMP-06 | — | in-memory only, never auto-save | class suite | `testPromoteUpdatesMapper` | ❌ W3 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**CMP-05 invariant test shape (no profiler):** open comparison → cache (`ResolvedTags_`, test-access via `struct(dlg)`) populated; simulate one live tick; assert cache handles identical + `CanonicalMapper.Entries_` unmutated. Proves resolve-once without profiler nondeterminism.

**CMP-03 skip-graceful test shape:** 3-machine fleet, one machine lacks the shared sensor ('none'); drive Open → assert the missing machine is surfaced as skipped (alert/events-log/`ResolvedTags_` exclusion) AND the overlay opens with the remaining machines (`numel(ResolvedTags_)==2`, tracked figure present).

---

## Wave 0 Requirements

- [ ] `CanonicalMapper.resolve(logicalId, machineId) → entry|[]` — METHOD MISSING today (research finding #1); prerequisite for everything
- [ ] `Fleet.mapper() → CanonicalMapper` — public accessor (Plan 01 Task 1) so helpers/tests reach the mapper without the private `Mapper_` field
- [ ] `tests/test_compare_resolution.m` — CMP-02/03/04 pure logic (Octave-safe); runner-invoked (T1-T4 + Tmapper + Ttheme + color)
- [ ] `tests/test_companion_open_ad_hoc_plot.m` (flat wrapper) — SeriesColors/SeriesLabels + legacy byte-compat; runner-invoked (T-NV1/2/3)
- [ ] `TestFastSenseCompanion.m` extensions — `testOpenComparisonLaunchesOverlay`, `testCompareButtonFleetOnly`, `testCMP03_SkipGraceful`, `testCMP05_NoResolveInTick`, `testPromoteUpdatesMapper`, legacy-unchanged assertion

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Dialog visual polish (600×480 grid, badges, swatches) | CMP-01/06 | On-screen aesthetics | Open Compare in a 3-machine fleet; check rows/badges/swatch colors |
| Overlay legend readability (`[machineName]: [sensor]`, per-machine colors) | CMP-02 | Visual | Open a 3-machine comparison; verify colors match selector order + legend strings |

---

## Validation Sign-Off

- [x] All tasks have automated verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 4 min
- [x] Logic/test tasks invoke the real test runner (not file-shape grep); `nyquist_compliant: true` set in frontmatter

**Approval:** pending
