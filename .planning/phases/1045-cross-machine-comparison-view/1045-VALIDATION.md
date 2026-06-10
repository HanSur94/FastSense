---
phase: 1045
slug: cross-machine-comparison-view
status: draft
nyquist_compliant: false
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
| **Quick run command** | `mcp__matlab__run_matlab_test_file('tests/suite/TestFastSenseCompanion.m')` / `mcp__matlab__evaluate_matlab_code` `run('tests/test_compare_resolution.m')` |
| **Full suite command** | `mcp__matlab__run_matlab_file('tests/run_all_tests.m')` |
| **Estimated runtime** | flat tests seconds; companion suite ~4 min |

Session hygiene (from 1044 experience): clean `timerfindall` + stray figures between suite runs in the live MCP session — leaked suite timers cause graphics storms.

---

## Sampling Rate

- **After every task commit:** relevant flat test (`test_compare_resolution.m`, `test_companion_open_ad_hoc_plot.m` + series-colors extension) on logic tasks; `check_matlab_code` on UI tasks
- **After every plan wave:** flat tests + `TestFastSenseCompanion.m`
- **Before `/gsd-verify-work`:** companion suite green at the 1044 baseline (82/84 — PerTag/ADHOC05 = documented pre-existing flake) + flat tests green
- **Max feedback latency:** ~4 min (suite); seconds (flat)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | mapper resolve | 1 | CMP-05 seam | — | N/A | unit (flat) | `run('tests/test_canonical_mapper.m')` ext | ✅ extend | ⬜ pending |
| TBD | resolution assembly | 1 | CMP-03/04 | — | LOW never auto-included | unit (flat) | `run('tests/test_compare_resolution.m')` | ❌ W1 | ⬜ pending |
| TBD | color index + labels | 1 | CMP-02 | — | N/A | unit (flat) | same | ❌ W1 | ⬜ pending |
| TBD | openAdHocPlot NV args | 1 | CMP-02 | — | legacy calls byte-compat | unit (flat MATLAB-only) | `run('tests/test_companion_open_ad_hoc_plot.m')` ext | ✅ extend | ⬜ pending |
| TBD | CompareBuilderDialog | 2 | CMP-01/06 | — | N/A | class suite | `run_matlab_test_file TestFastSenseCompanion` | ❌ W3 | ⬜ pending |
| TBD | toolbar + wiring | 3 | CMP-01 | — | fleet-only button; legacy [1 10] | class suite | same | ❌ W3 | ⬜ pending |
| TBD | CMP-05 cache invariant | 3 | CMP-05 | — | no resolve in tick path | class suite | `testCMP05_NoResolveInTick` | ❌ W3 | ⬜ pending |
| TBD | promote flow | 3 | CMP-06 | — | in-memory only, never auto-save | class suite | `testPromoteUpdatesMapper` | ❌ W3 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**CMP-05 invariant test shape (no profiler):** open comparison → cache (`ResolvedTags_`, test-access attribute) populated; simulate one live tick; assert cache handles identical + `CanonicalMapper.Entries_` unmutated. Proves resolve-once without profiler nondeterminism.

---

## Wave 0 Requirements

- [ ] `CanonicalMapper.resolve(logicalId, machineId) → entry|[]` — METHOD MISSING today (research finding #1); prerequisite for everything
- [ ] `tests/test_compare_resolution.m` — CMP-02/03/04 pure logic (Octave-safe)
- [ ] `tests/test_companion_open_ad_hoc_plot.m` extension (or sibling) — SeriesColors/SeriesLabels + legacy byte-compat
- [ ] `TestFastSenseCompanion.m` extensions — `testOpenComparisonLaunchesOverlay`, `testCompareButtonFleetOnly`, `testCMP05_NoResolveInTick`, `testPromoteUpdatesMapper`, legacy-unchanged assertion

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Dialog visual polish (600×480 grid, badges, swatches) | CMP-01/06 | On-screen aesthetics | Open Compare in a 3-machine fleet; check rows/badges/swatch colors |
| Overlay legend readability (`[machineName]: [sensor]`, per-machine colors) | CMP-02 | Visual | Open a 3-machine comparison; verify colors match selector order + legend strings |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 4 min
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
