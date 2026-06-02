# Phase 1039 — Deferred / Out-of-Scope Items

Items discovered during execution that are NOT caused by the current plan's changes
and were intentionally left unfixed (per the GSD scope-boundary rule).

## 1039-04

### Octave-only environmental flake: `test_notification_service / test_snapshot_generation`

- **Discovered during:** Plan 04 regression sweep (existing-tests must-stay-green check).
- **Symptom:** Under the Octave CLI in this session, `test_snapshot_generation` fails its
  `snapshots_created` assertion (expects >= 2 rendered PNGs in `SnapshotDir`).
- **Root cause:** PNG snapshot rendering depends on Octave's graphics toolkit (FLTK in this
  headless session, which prints "the fltk graphics toolkit is discouraged"). PNG export is
  environmentally fragile under headless Octave; the same test passes under MATLAB.
- **Evidence it is NOT a regression / NOT caused by Plan 04:**
  - Plan 04 added only test files (`git diff --name-only HEAD~1 HEAD` = 3 new `tests/*.m`);
    `NotificationService.m` and `generateEventSnapshot.m` were untouched this plan.
  - `test_notification_service` runs **7/7 PASS under MATLAB R2025b** (verified this plan),
    matching the Plan 03 SUMMARY record ("test_notification_service 7/7 PASS under Octave"
    as of commit 5266234b — i.e. it has passed under Octave historically; the failure is
    session-/toolkit-dependent, not code-dependent).
- **Action:** Not fixed (out of scope — pre-existing environmental rendering dependency).
  Snapshot rendering is exercised and green under MATLAB.
