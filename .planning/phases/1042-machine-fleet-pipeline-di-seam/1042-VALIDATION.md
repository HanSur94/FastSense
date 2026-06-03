---
phase: 1042
slug: machine-fleet-pipeline-di-seam
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-03
---

# Phase 1042 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Validation Architecture derived in `1042-RESEARCH.md` §"Validation Architecture". Per-task map is filled by the planner.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB `matlab.unittest` class suites (`tests/suite/Test*.m`, MATLAB-only) + Octave function tests (`tests/test_*.m`, Octave-only) |
| **Config file** | none — custom runner `tests/run_all_tests.m` |
| **Quick run command** | single file via MCP `run_matlab_test_file` (e.g. `tests/suite/TestMachine.m`) |
| **Full suite command** | `tests/run_all_tests.m` |
| **Estimated runtime** | ~2–5 min full suite |

**Octave-CI note (from RESEARCH.md):** class suites (`TestMachine.m`, `TestFleet.m`) run on MATLAB only. Flat companion tests `tests/test_machine.m` + `tests/test_fleet.m` MUST be added so Fleet data-model code is exercised on Octave CI.

---

## Sampling Rate

- **After every task commit:** Run the touched class suite (`TestMachine.m` / `TestFleet.m` / pipeline DI test)
- **After every plan wave:** Run `tests/run_all_tests.m`
- **Before `/gsd-verify-work`:** Full suite green on MATLAB; Fleet flat tests green on Octave
- **Max feedback latency:** ~30 s (single suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _filled by planner_ | | | FLEET-01..06 | | | unit | | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/suite/TestMachine.m` — Machine catalog isolation, duck-type API, lazy load, ingest DI (FLEET-01/02/03/05)
- [ ] `tests/suite/TestFleet.m` — addMachine, filterByName/Group, save/load round-trip, embedded canonical map (FLEET-01/04/06)
- [ ] `tests/test_machine.m` + `tests/test_fleet.m` — Octave-CI flat companions (Octave parity for FLEET-04 round-trip + invariants)
- [ ] Pipeline DI test — `tagSource_` default unchanged + machine-scoped override (FLEET-03)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 5-machine startup memory/time budget (< 2 s, < 50 MB) | FLEET-05 | Resource measurement is environment-sensitive | Build 5-machine test fleet; `tic`/`toc` + memory probe around load; assert under budget |

*Automated grep gates (TagRegistry.register==0, no `ui*` in libs/Fleet, TagRegistry.list()==0 after 2-machine load) belong in the suites above, not here.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
