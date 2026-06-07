---
phase: 1043
slug: dashboardserializer-resolver-seam-backward-compat
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-07
---

# Phase 1043 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Validation Architecture derived in `1043-RESEARCH.md` §"Validation Architecture". Per-task map filled by the planner.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB `matlab.unittest` class suites (`tests/suite/Test*.m`, MATLAB-only) + Octave function tests (`tests/test_*.m`, Octave-only) |
| **Config file** | none — custom runner `tests/run_all_tests.m` |
| **Quick run command** | single file via MCP `run_matlab_test_file` (e.g. `tests/suite/TestDashboardSerializer.m`) |
| **Full suite command** | `tests/run_all_tests.m` |
| **Estimated runtime** | ~2–5 min full suite |

**Octave-CI note:** the resolver-threading + `FastSenseWidget:tagResolverMissing` warning logic runs in `fromStruct`/`configToWidgets` WITHOUT figure/uipanel rendering → Octave-safe. Add a flat `tests/test_*.m` companion (warning-as-error idiom `warning('error', ID)` + try/catch, mirroring `tests/test_machine.m`) so the seam is exercised on Octave CI.

---

## Sampling Rate

- **After every task commit:** Run the touched suite (`TestDashboardSerializer.m` / new resolver suite)
- **After every plan wave:** Run `tests/run_all_tests.m`
- **Before `/gsd-verify-work`:** Full suite green on MATLAB; resolver flat test green on Octave
- **Max feedback latency:** ~30 s (single suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _filled by planner_ | | | DASH-01/02 | | | unit | | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Resolver-seam class suite (extend `TestDashboardSerializer.m` or new `TestFleetDashboardResolver.m`) — RED tests for: (a) legacy load no-resolver→TagRegistry.get, no warning; (b) multi-page fleet load + resolver→page-2 widgets via resolver; (c) fleet load no-resolver→`FastSenseWidget:tagResolverMissing` warning, Tag=[]; (d) `.m` export machineVar→`machine.get('k')` not bare `TagRegistry.get` (DASH-01/02)
- [ ] Octave flat companion `tests/test_*.m` for the resolver/warning logic (DASH-02 Octave parity)
- [ ] Synthetic in-test fixture (single-page legacy JSON + multi-page fleet JSON) for determinism

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| (none expected) | — | resolver/warning/export all automatable | — |

*All four success criteria have automated verification (resolver-used assertion, legacy-load equality, warning-fires assertion, `.m`-export-string assertion).*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
