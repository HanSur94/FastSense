---
phase: 1031-event-log
plan: "03"
subsystem: Concurrency
tags: [ndjson, event-log, mtime-cache, retry, torn-rename, pitfall-12]
requirements: [EVTLOG-02, EVTLOG-03]

dependency_graph:
  requires:
    - 1031-01  # ndjsonDecode (Plan 01 - NDJSON codec)
    - 1029-04  # AtomicWriter.readWithRetry (Phase 1029 foundation)
  provides:
    - EventLogReader class (tail/readAll/readAllWithStats + mtime cache + retry)
  affects:
    - 1032     # EventStore.getEventsForTag merge step will use EventLogReader.tail(N)
    - 1033     # Companion event-log pane will poll tail(100) on a timer

tech_stack:
  added: []
  patterns:
    - containers.Map as mutable closure accumulator (handle class reference semantics)
    - Per-instance mtime cache (dir().datenum) instead of shared static cache
    - AtomicWriter.readWithRetry for torn-rename window absorption (Pitfall 12)
    - ndjsonDecode cumulative SkippedLineCount for corruption trend tracking

key_files:
  created:
    - libs/Concurrency/EventLogReader.m
    - tests/suite/TestEventLogReader.m
  modified: []

decisions:
  - "Static method parseLog_ instead of nested function: MATLAB classdef methods cannot contain nested functions; static method with containers.Map skipMap handle achieves equivalent closure semantics"
  - "containers.Map as mutable accumulator: used to pass SkippedLineCount back from anonymous loader @(p) to outer read_() scope without nested functions"
  - "readAllWithStats bypasses mtime cache: ensures parseStats reflects current file state for diagnostic use; separate from readAll which benefits from cache"
  - "SkippedLineCount is cumulative: accumulates across multiple readAll() calls on a single reader instance so callers can detect corruption trends over time"

metrics:
  duration_minutes: 45
  completed_date: "2026-05-14"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
  tests_passed: 9
  tests_total: 9
---

# Phase 1031 Plan 03: EventLogReader Summary

**One-liner:** NDJSON event log reader with per-instance mtime cache + 3x50ms AtomicWriter retry absorbing torn-rename windows (Pitfall 12).

## What Was Built

`libs/Concurrency/EventLogReader.m` — a handle class that reads `.events.ndjson` files written by `EventLog` (Plan 02). Composes:
- `ndjsonDecode` (Plan 01) for corrupt-line-tolerant parsing
- `AtomicWriter.readWithRetry` (Phase 1029-04) for torn-rename window tolerance
- Per-instance `mtimeCache_` (dir().datenum) to skip redundant re-parses

Public API:
- `readAll()` — read all events, mtime-cached
- `tail(n)` — read last N events (caches full file, trims on return)
- `readAllWithStats()` — fresh read that returns `parseStats.SkippedLineCount`

Observable properties: `SkippedLineCount` (cumulative), `LastReadCacheHit` (logical), `LastReadDurationSec` (double).

## Test Results

`tests/suite/TestEventLogReader.m` — 9/9 tests passed:

| Test | Description | Result |
|------|-------------|--------|
| testReadAllOnEmptyFile | Missing file -> [] with SkippedLineCount==0 | PASS |
| testReadAllReturnsAllEvents | 3-event log -> readAll returns 3, SkippedLineCount==0 | PASS |
| testTailReturnsLastN | tail(2) returns events with i==4 and i==5 | PASS |
| testTailFewerThanNReturnsAll | tail(10) on 2-event log returns 2 | PASS |
| testCorruptLineSkippedAndCounted | Injected malformed line -> SkippedLineCount==1 | PASS |
| testMtimeCacheHit | Second readAll without writes -> LastReadCacheHit==true | PASS |
| testMtimeCacheInvalidates | EventLog.append -> next readAll is cache miss + new event | PASS |
| testTornRenameRecovery | 30-cycle movefile+readAll -> 0 reader errors | PASS |
| testReadAllWithStats | readAllWithStats exposes parseStats.SkippedLineCount | PASS |

Regression tests also passed:
- `TestAtomicWriter`: 10/10
- `test_ndjson_decode`: 7/7 (all ndjsonDecode tests)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced nested functions with static methods + containers.Map**
- **Found during:** Task 1 implementation
- **Issue:** MATLAB classdef methods cannot contain nested functions (a restriction of MATLAB's class system). The plan's code example used `function parseLog_(p)` as a nested function inside `read_()`, which is invalid in MATLAB.
- **Fix:** Moved `parseLog_` to `methods (Static, Access = private)` with a `containers.Map skipMap` parameter. `containers.Map` is a handle class, so mutations inside the static method (and anonymous loaders) are visible to the outer scope. This achieves exactly the closure semantics the plan intended.
- **Pattern reference:** `TestAtomicWriter.testReaderRetryHelper` lines 119-125 uses this identical containers.Map-as-handle-accumulator pattern.
- **Files modified:** `libs/Concurrency/EventLogReader.m`
- **Commit:** a0065fb

**2. [Rule 2 - Lint] Suppressed mlint false-positive on containers.Map subscript assignment**
- **Found during:** Post-implementation static analysis
- **Issue:** `checkcode` reported "Value assigned to variable might be unused" on `skipMap('count') = ...`. This is a known mlint limitation — it does not recognize that containers.Map subscript assignment mutates the handle object in-place (the result is not "assigned to an unused variable"; the map itself is mutated).
- **Fix:** Added `%#ok<NASGU>` suppression comment.
- **Commit:** e66c3ff

### Test Count Note

The plan specified 7 test methods; 9 were written:
- `testTailFewerThanNReturnsAll` added (tail boundary condition — essential edge case)
- `testReadAllWithStats` added (the plan's `readAllWithStats` API needed test coverage)

## Key Decisions

1. **Static method for loader**: MATLAB classdef restriction requires `parseLog_` to be a `Static` method rather than a nested function. `containers.Map` handle semantics provide equivalent mutable-state-in-closure behavior.

2. **containers.Map pattern for SkippedLineCount accumulation**: Used `containers.Map({'count'}, {0})` as a by-reference accumulator threaded through anonymous loader. Avoids the need for nested functions while maintaining identical semantics to the plan's design.

3. **readAllWithStats bypasses mtime cache**: A deliberate design choice so diagnostic callers always get current parseStats. The mtime cache optimization applies only to `readAll()` and `tail()`.

4. **Cumulative SkippedLineCount**: Accumulates across all `readAll()` calls on a single reader instance. Each successful parse adds that parse's skipped count to the running total. Phase 1033 Companion UI can poll this to surface a "corruption rate" status badge.

## Known Stubs

None. All plan goals implemented and wired with live data. No placeholders.

## Self-Check

- [x] `libs/Concurrency/EventLogReader.m` exists
- [x] `tests/suite/TestEventLogReader.m` exists
- [x] `grep -n 'ndjsonDecode' libs/Concurrency/EventLogReader.m` — 4 hits
- [x] `grep -n 'AtomicWriter.readWithRetry' libs/Concurrency/EventLogReader.m` — 4 hits
- [x] `grep -n 'SkippedLineCount' libs/Concurrency/EventLogReader.m` — 10 hits
- [x] `grep -nE 'mtimeCache_' libs/Concurrency/EventLogReader.m` — 4 hits
- [x] 9/9 tests pass (TestEventLogReader)
- [x] 10/10 TestAtomicWriter regression: PASS
- [x] 7/7 test_ndjson_decode regression: PASS
- [x] Commits: a0065fb (Task 1), 446b954 (Task 2), e66c3ff (lint fix)
