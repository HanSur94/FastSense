---
phase: 1031-event-log
plan: 02
subsystem: Concurrency
tags: [event-log, ndjson, file-locking, tag-write-coordinator, EVTLOG-01, EVTLOG-02]

requires:
  - phase: 1030-01
    provides: TagWriteCoordinator.acquireTag() — per-tag FileLock facade used for lock-serialised append
  - phase: 1031-01
    provides: ndjsonEncode/ndjsonDecode — NDJSON codec used for event encoding and test verification

provides:
  - EventLog(sharedRoot, tagKey) — append-only NDJSON writer with lock-serialised cross-process safety
  - EventLog.append(eventStruct) — acquires TagWriteCoordinator lock, writes magic header on first append, encodes via ndjsonEncode
  - EventLog.path() — returns absolute path to <sharedRoot>/events/<tagKey>.events.ndjson
  - EventLog.LastAppendSkipped — contention counter for observability
  - test_event_log_concurrent — function-style CI smoke + FASTSENSE_STRESS_50 stress harness

affects:
  - Phase 1031-03 (EventLogReader — reads files written by EventLog)
  - Phase 1032 (MonitorTag.emitEvent_ wires through EventLog.append)
  - Phase 1033 (EventLogConsolidator reads event logs for snapshot generation)

tech-stack:
  added: []
  patterns:
    - Lock-serialised NDJSON append via TagWriteCoordinator (Pitfall 5 prevention point)
    - Magic-byte + version header (#FASTSENSE_EVENTLOG_V1) for format detection, transparent to ndjsonDecode
    - onCleanup-based RAII for both lock release and fopen/fclose (exception-safe)
    - LastAppendSkipped counter pattern (mirrors LiveTagPipeline.SkippedTickCount from Phase 1030-02)
    - FASTSENSE_STRESS_50 operator-gated stress tier (mirrors TestFileLockStress50 pattern from Phase 1029-05)
    - Child-process retry loop on ok=false with random jitter (5-25 ms) for stress test child harness

key-files:
  created:
    - libs/Concurrency/EventLog.m
    - tests/test_event_log_concurrent.m
  modified: []

key-decisions:
  - "EventLog.append uses fopen+fwrite+fclose under FileLock — NOT AtomicWriter.write (which obliterates prior content via temp+rename). AtomicWriter is for snapshot rolls (Phase 1033 EventLogConsolidator)."
  - "Magic header (#FASTSENSE_EVENTLOG_V1) starts with '#' so ndjsonDecode skips it silently — no special reader coupling required"
  - "LastAppendSkipped is SetAccess=private (not Access=private) so Phase 1032 and Phase 1033 Companion UI can observe contention rate"
  - "2-proc CI smoke skipped on macOS per Phase 1030-02 Deviation #2 (matlab -batch startup cost exceeds 90s budget)"
  - "Phase 1031 SC6 contingency acknowledged in code: single-file NDJSON append; SC6 budget covers pivot to per-writer-file + merge if SMB atomicity fails"

patterns-established:
  - "EventLog append pattern: acquireTag -> onCleanup(release) -> mkdir-if-absent -> needHeader check -> fopen('a') -> onCleanup(fclose) -> header-if-new -> fwrite(ndjsonEncode(s))"
  - "Stress test tiers: always-runs in-process (Tests 1+2+4) + Linux-only CI smoke (Test 3) + FASTSENSE_STRESS_50 operator gate (Test 5)"

requirements-completed: [EVTLOG-01, EVTLOG-02]

duration: 4min
completed: 2026-05-14
---

# Phase 1031 Plan 02: EventLog Summary

**Lock-serialised append-only NDJSON event log with magic-byte header and concurrent stress harness wired through TagWriteCoordinator (Pitfall 5 prevention)**

## Performance

- **Duration:** 4 min
- **Started:** 2026-05-14T12:20:31Z
- **Completed:** 2026-05-14T12:25:13Z
- **Tasks:** 2
- **Files modified:** 2 created

## Accomplishments

- `EventLog` handle class: constructor validates inputs and derives `<sharedRoot>/events/<tagKey>.events.ndjson` via `SharedPaths.eventsDir`
- `append(eventStruct)` acquires `TagWriteCoordinator.acquireTag(tagKey)` lock before opening file — Pitfall 5 prevention (O_APPEND is not atomic on SMB/NFS)
- First append writes magic-byte header `#FASTSENSE_EVENTLOG_V1\n` — transparent to `ndjsonDecode` which silently skips `#`-prefixed lines
- Subsequent appends write only the NDJSON line (no duplicate header)
- RAII pattern: `onCleanup` for both lock release and `fclose` — exception-safe
- `LastAppendSkipped` counter: incremented on `ok=false` contention return, skipping `lock.release()` per Phase 1030-01 contract
- 5 error IDs: `EventLog:invalidSharedRoot`, `EventLog:invalidTagKey`, `EventLog:invalidEvent`, `EventLog:openFailed` + propagated `Concurrency:nestedLockAcquireForbidden`
- Test harness with in-process (Tests 1/2/4), Linux-only 2-proc smoke (Test 3), and FASTSENSE_STRESS_50-gated 50-proc stress (Test 5)

## Files Created/Modified

- `libs/Concurrency/EventLog.m` — 190 lines; handle class; lock-serialised NDJSON append writer
- `tests/test_event_log_concurrent.m` — 241 lines; function-style Octave-compatible stress test

## Decisions Made

- Used `fopen+fwrite+fclose` under the FileLock instead of `AtomicWriter.write` — atomic temp+rename would obliterate prior log content; AtomicWriter is reserved for Phase 1033 snapshot consolidation
- Magic header starts with `#` matching the comment-skip contract in `ndjsonDecode` (Plan 01 Test 4) — no reader coupling required
- `LockTimeout_` defaults to 5 seconds — balanced between stall avoidance in live pipelines and reasonable retry window for contended SMB shares
- `needHeader` check occurs BEFORE `fopen` (not after) — the FileLock provides the race-free first-writer guarantee; `O_CREAT` kernel semantics are not relied upon
- Phase 1031 SC6 contingency documented in classdef header and plan — single-file NDJSON approach; pivot budget in Phase 1033 if SMB atomicity fails

## Deviations from Plan

None — plan executed as written. The plan's code template was implemented verbatim with consistent in-line documentation.

## Known Stubs

None. All plan goals achieved with no placeholder data or deferred functionality.

## Self-Check: PASSED

Files verified:
- FOUND: libs/Concurrency/EventLog.m (190 lines)
- FOUND: tests/test_event_log_concurrent.m (241 lines)

Commits verified:
- FOUND: a407132 feat(1031-02): add EventLog lock-serialised NDJSON append writer
- FOUND: 5d28fbe test(1031-02): add concurrent EventLog append stress test

Acceptance criteria:
- `grep -nE "classdef\s+EventLog"` — PASS (line 1)
- `grep -n "TagWriteCoordinator"` — PASS (7 hits)
- `grep -nE "acquireTag\("` — PASS (4 hits)
- `grep -n "ndjsonEncode"` — PASS (3 hits)
- `grep -n "FASTSENSE_EVENTLOG_V1"` — PASS (3 hits)
- `grep -n "SharedPaths\.eventsDir"` — PASS (2 hits)
- `grep -n "onCleanup"` — PASS (4 hits)
- `grep -nE "EventLog:invalidSharedRoot|...|EventLog:openFailed"` — PASS (12 hits, 4 unique IDs)
- `grep -n "LastAppendSkipped"` — PASS (4 hits)
- `grep -n "FASTSENSE_STRESS_50"` — PASS (6 hits in test file)
- `grep -n "matlab -batch"` — PASS (6 hits in test file)
- `grep -n "ndjsonDecode"` — PASS (5 hits in test file)
- `grep -nE "isunix\(\) && ~ismac\(\)"` — PASS (1 hit in test file)
- `grep -nE "SkippedLineCount == 0"` — PASS (3 hits in test file)
- `grep -nE "EventLog\.MAGIC"` — PASS (1 hit in test file)
- min_lines >= 90 for EventLog.m — PASS (190 lines)
