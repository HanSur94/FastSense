# Phase 1006: Fix MATLAB test failures — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 1006-fix-137-matlab-test-failures-surfaced-by-matlab-on-every-push-ci-enablement-7-categories-from-r2025b-drift
**Areas discussed:** MATLAB version pinning (G), mksqlite fix strategy (A), headless image export (F), ROI split / phase boundary

---

## MATLAB Version Pinning (MATLABFIX-G)

| Option | Description | Selected |
|--------|-------------|----------|
| Pin to R2020b | Matches CLAUDE.md target. Likely eliminates B (TestData removed post-R2020b), C (private access post-R2020b), D (API changes post-R2020b) — ~71 tests. Mildly conservative — won't catch R2025b-only issues. | ✓ |
| Pin to R2024a/b (LTS-ish) | Middle ground. Probably still has D1 (table char names). Unpredictable scope reduction. | |
| Accept R2025b, fix everything | Most honest. Forces all B/C/D fixes (~71 tests of extra work). Updates CLAUDE.md to "R2020b+ supported, R2025b tested". Significantly larger phase. | |
| Matrix: R2020b + R2025b | Runs both. 2x cost, maximum coverage. | |

**User's choice:** Pin to R2020b (recommended)
**Notes:** Reshapes the phase significantly. Categories B (TestData migration, ~41 tests), C (private access, ~12 tests), and D (R2025b API changes, ~18 tests) drop out of scope. Phase 1006 scope shrinks from 137 → ~75 tests.

---

## mksqlite Fix Strategy (MATLABFIX-A)

| Option | Description | Selected |
|--------|-------------|----------|
| Investigate first, then fix | Planner adds a diagnostic plan that checks whether mksqlite.mexa64 is in the artifact, whether MATLAB can find it, and why build_mex.m behavior under MATLAB produces (or doesn't) the binary. Only after diagnosis, apply the matching fix. | ✓ |
| Add skipUnless guard (quick) | Mirror TestMexEdgeCases pattern. ~15 min fix. Loses coverage when mksqlite isn't there — but those tests can't run then anyway. | |
| Force rebuild under MATLAB | Assume the artifact lacks mksqlite and fix install.m / build_mex.m. Risk: if the real issue is something else (path, ABI), effort wasted. | |

**User's choice:** Investigate first, then fix
**Notes:** Two-plan structure: plan 1 diagnostic, plan 2 fix based on diagnostic outcome. The skipUnless guard remains a fallback if rebuild proves infeasible.

---

## Headless Image Export (MATLABFIX-F)

| Option | Description | Selected |
|--------|-------------|----------|
| Fix exportImage() in the library | Replace `print()` with `exportgraphics()` (MATLAB R2020a+). Library self-sufficient, non-CI headless users benefit. Slight risk of visual output difference. Recommended. | ✓ |
| Add xvfb-run to MATLAB CI step | CI-only fix; non-CI headless users still broken. Simpler than changing library. Octave job already uses this pattern. | |
| Tag tests as 'RequiresDisplay', skip in CI | Loses CI coverage of a phase-1004 feature. Not recommended. | |

**User's choice:** Fix exportImage() in the library
**Notes:** Library-level fix is the most robust. Need a visual parity check (compare print vs exportgraphics output) to catch rendering differences.

---

## ROI Split / Phase Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as one phase (A + E + F) | Post-G-pin scope: ~75 tests across 3 requirements. Manageable as a single phase with 3-5 plans. | ✓ |
| Split 1006 (A + F quick) + 1007 (E cleanup) | 1006 quick wins ~54 tests. 1007 E cluster ~21 tests. Cleaner PRs but two phases to plan separately. | |
| Shrink 1006 to A only, defer E + F | Most conservative. Small win first, more phases later. | |

**User's choice:** Keep as one phase (A + E + F)
**Notes:** Single phase, 3-5 plans estimated. Progress metric: failure count reduction.

---

## Claude's Discretion

- Exact plan file structure for A (diagnostic → fix) + E (cluster of ~10 small fixes) + F (library swap)
- Whether E10 drag/resize diagnostic is its own plan or a sub-task within the E plan
- Ordering within wave 1 (G pin can ship first as plan 0 or bundled with A plan 1)
- Commit granularity within each plan

## Deferred Ideas

- Newer MATLAB support (resurrect B/C/D) — future phase if users report R2025b issues
- Matrix CI (R2020b + R2025b) — pending real user demand
- `_build-mex-matlab.yml` reusable workflow extraction — only 1 caller today; revisit if Phase 1005 adds more
- MATLAB Lint 17 style issues — separate quick task (not test failures)
- Codecov for Octave — blocked on Octave Cobertura exporter (already deferred in 260416-jfo)
- `TestNumberWidget/testComputeTrend` — uncategorized, may be genuine logic bug — flag during plan execution
