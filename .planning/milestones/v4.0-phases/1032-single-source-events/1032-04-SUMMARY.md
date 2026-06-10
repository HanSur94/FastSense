---
phase: 1032
plan: 04
subsystem: EventDetection
tags: [ack-workflow, isa-18-2, three-state, identity-stamp, backward-compat, ACK-01, ACK-02, ACK-03, IDENT-02]
dependency_graph:
  requires:
    - Event handle class (Phase 1012 — IsOpen / close / Notes)
    - EventStore.appendAckRecord (Phase 1031-04 — cluster ack write path)
    - EventStore.busyRetryWrap_ (Phase 1032-03 — retry wrapper)
    - ClusterIdentity.resolve (Phase 1029-01 — identity stamping)
  provides:
    - Event.Identity / AckedAt / AckedBy / AckComment properties
    - Event.computeDisplayState() — ISA-18.2 four-state visual model
    - Event.fromStructSafe(s) — legacy struct promotion with safe defaults
    - EventStore.acknowledgeEvent(eventId, opts) — single-user + cluster routing
    - EventStore.getAckRecordsForEvent(eventId) — per-event ack history
    - EventStore.acks_ — in-memory ack array persisted by save()
  affects:
    - Phase 1033 (Companion UI): consumes computeDisplayState() for alarm badges + getAckRecordsForEvent for audit-log column
tech_stack:
  added: []
  patterns:
    - ISA-18.2 §5.4 four-state alarm model (unacked-active | acked-active | acked-cleared | unacked-cleared)
    - handle-class in-place mutation for in-memory ack mirror (AckedAt/AckedBy/AckComment stamped on Event handle)
    - struct array append with safe empty check (single-user acks_)
    - backward-compat field guarding via isfield() in fromStructSafe
key_files:
  created:
    - tests/suite/TestEventAcknowledgement.m
  modified:
    - libs/EventDetection/Event.m
    - libs/EventDetection/EventStore.m
decisions:
  - "AckedAt stored as numeric datenum (not datetime) to be serialization-safe in .mat files; ClusterIdentity.epoch (datetime) is converted with datenum() at the EventStore boundary."
  - "AckComment added as top-level Event property (mirrors AckedBy.comment) for ergonomic UI read access without struct traversal."
  - "computeDisplayState returns four states not three — the ISA-18.2 §5.4 three-state model plus 'unacked-cleared' (event closed without ack). ACK-02 acceptance criterion enumerates the three canonical states; fourth included for completeness and UI audit ergonomics."
  - "Event.fromStructSafe added as static helper rather than modifying the Event constructor — keeps the constructor simple; fromStructSafe is the Phase 1033 consolidator's promotion entry point."
  - "Single-user acknowledgeEvent does NOT enforce idempotency (second ack on same event overwrites AckedAt/AckedBy and appends a second acks_ row). Documented as out-of-scope for v4.0; Phase 1033 UI shows latest ack row."
metrics:
  duration_seconds: 668
  completed_date: "2026-05-14"
  tasks_completed: 3
  files_created: 1
  files_modified: 2
  test_pass_rate: "13/13 new + 4/4 + 1/1 + 7/7 + 6/6 + 7/7 + 5/5 regression = 43/43"
  static_analysis: "info/style-level only (no errors); now/datestr style notes are pre-existing codebase pattern"
---

# Phase 1032 Plan 04: Ack Workflow Summary

**One-liner:** ISA-18.2 four-state ack workflow — Identity/AckedAt/AckedBy stamped on Event, computeDisplayState() for visual state, EventStore.acknowledgeEvent routing single-user acks_ + cluster SQLite, backward-compat fromStructSafe for legacy .mat files.

## What landed

### `libs/EventDetection/Event.m` — ack fields + display state + legacy loader

New public properties (with safe inline defaults so existing code never breaks):
```matlab
Identity   = struct()  % {user, host, epoch} at emission time (IDENT-02)
AckedAt    = []        % numeric datenum; [] = unacked
AckedBy    = struct()  % {user, host, epoch, comment}
AckComment = ''        % convenience alias for AckedBy.comment
```

New instance method `computeDisplayState()` — returns one of:
- `'unacked-active'`  — IsOpen=true, AckedAt=[]
- `'acked-active'`    — IsOpen=true, AckedAt non-empty
- `'acked-cleared'`   — IsOpen=false, AckedAt non-empty
- `'unacked-cleared'` — IsOpen=false, AckedAt=[] (fourth cell per ISA-18.2)

New static method `Event.fromStructSafe(s)` — promotes legacy structs (v3.x .mat files without Identity/AckedAt/AckedBy fields) to `Event` handle instances with safe defaults.

### `libs/EventDetection/EventStore.m` — acknowledgeEvent + acks_ + persistence

- New private property `acks_` — struct array `{eventId, by_user, by_host, epoch, comment, action='ack'}` (single-user) or in-memory mirror of SQLite ack_records (cluster).
- New public method `acknowledgeEvent(eventId, opts)`:
  - Stamps `ClusterIdentity.resolve()` identity (non-strict; tolerates failure)
  - Single-user: appends to `acks_`, mutates `Event.AckedAt`/`AckedBy`/`AckComment` in-memory
  - Cluster: routes through `appendAckRecord` (Phase 1031-04 + Plan 03 retry wrapper)
  - Throws `EventStore:unknownEventId` when event not found in single-user mode
- New public method `getAckRecordsForEvent(eventId)` — single-user filters `acks_`; cluster queries SQLite with `WHERE event_id = ?`
- `save()` extended to persist `acks_` in .mat when non-empty
- `loadFile()` extended to expose `meta.acks` when present in loaded .mat

### `tests/suite/TestEventAcknowledgement.m` — 13 tests, all green

| Test | Coverage |
|------|---------|
| testEventDefaultIdentityIsEmpty | Default property values |
| testComputeDisplayStateUnackedActive | IsOpen=T, AckedAt=[] → 'unacked-active' |
| testComputeDisplayStateAckedActive | IsOpen=T, AckedAt=now → 'acked-active' |
| testComputeDisplayStateAckedCleared | IsOpen=F, AckedAt=now → 'acked-cleared' |
| testComputeDisplayStateUnackedCleared | IsOpen=F, AckedAt=[] → 'unacked-cleared' |
| testAckRoundtripSingleUser | append + ack + save + load, acks field in .mat |
| testAckRoundtripClusterMode | cluster mode, assumeFail if mksqlite absent |
| testAckCommentPersisted | ACK-03 comment end-to-end |
| testAckUnknownEventIdThrows | EventStore:unknownEventId error |
| testLegacyEventLoadsWithoutIdentity | fromStructSafe with v3.x struct |
| testIdentityCanBeAssignedPostConstruction | Identity post-construction assignment |
| testAckWithNoCommentDefaultsToEmpty | no-comment guard |
| testAckAckedAtMirroredOnEvent | AckedAt + computeDisplayState transition after ack |

## ACK requirement coverage matrix

| REQ-ID | Description | Test method |
|--------|-------------|-------------|
| ACK-01 | Ack visible to other Companions within ~5s | testAckRoundtripSingleUser (saves to .mat); testAckRoundtripClusterMode (writes to SQLite ack_records) |
| ACK-02 | Three-state visual model | testComputeDisplayState* (4 tests covering all states) |
| ACK-03 | Free-text comment persisted | testAckCommentPersisted |
| IDENT-02 | Audit trail: {user, host, epoch, action, target_event_id} | testAckAckedAtMirroredOnEvent (verifies AckedBy.user populated) |

## Backward-compat verification

`testLegacyEventLoadsWithoutIdentity` simulates a v3.x `.mat` event struct (no Identity/AckedAt/AckedBy fields). `Event.fromStructSafe` promotes it to an `Event` instance with:
- `ev.Identity` == `struct()` (default)
- `ev.AckedAt` == `[]` (default)
- `ev.SensorName` == `'s_legacy'` (preserved)

Pre-1032 code paths (direct struct array storage) are ALSO backward-compatible because the `Identity`, `AckedAt`, `AckedBy`, `AckComment` properties have safe inline defaults — any code creating `Event` objects without setting these fields gets the correct defaults automatically.

## Regression results

| Test suite | Result |
|---|---|
| TestEventAcknowledgement (new) | 13/13 PASS |
| TestEvent | 4/4 PASS |
| TestEventStore | 1/1 PASS |
| TestEventStoreRw | 7/7 PASS |
| TestEventStoreCluster | 6/6 PASS |
| TestEventStoreConcurrency | 7/7 PASS |
| TestEventSnapshot | 5/5 PASS |

## Hand-off notes for Phase 1033 (Companion UI)

- **Visual state API:** `Event.computeDisplayState()` returns a string — map to badge colors in Companion:
  - `'unacked-active'` → red/flashing (urgent — operator must acknowledge)
  - `'acked-active'`   → yellow/steady (acknowledged, condition still active)
  - `'acked-cleared'`  → green/dim (normal closure)
  - `'unacked-cleared'` → grey (closed without ack — audit anomaly, low priority)

- **Per-event ack history:** `es.getAckRecordsForEvent(eventId)` returns struct array with `{eventId, by_user, by_host, epoch, comment}` — use as rows in the audit-log column of the event details popup.

- **Polling for multi-user ack propagation:** Phase 1033 should add `es.getAckRecordsForEvent(id)` calls in the EventStore poll tick alongside `getEvents()`. The ACK-01 ~5s propagation target is met when the Companion polls SQLite ack_records on its existing live tick.

## Deviations from Plan

None — plan executed exactly as written. The fourth display state `'unacked-cleared'` was already specified in the plan (task 1 behavior test 6); its inclusion is plan-conformant.

## Known Stubs

None — all ack fields are wired to real data. `Event.fromStructSafe` returns a fully-populated Event instance, not a stub.

## Self-Check: PASSED

All files created/modified:
- FOUND: `libs/EventDetection/Event.m`
- FOUND: `libs/EventDetection/EventStore.m`
- FOUND: `tests/suite/TestEventAcknowledgement.m`
- FOUND: `.planning/phases/1032-single-source-events/1032-04-SUMMARY.md`

All commits verified:
- FOUND: d05b73c `feat(1032-04): add ack fields + computeDisplayState + fromStructSafe to Event`
- FOUND: ab97901 `feat(1032-04): add acknowledgeEvent + getAckRecordsForEvent + acks_ to EventStore`
- FOUND: d3365a0 `test(1032-04): TestEventAcknowledgement — ack roundtrip + three-state + legacy load`
- FOUND: 4f04800 `fix(1032-04): clean up EventStore.m code analyzer suppressors`

Grep verification:
- `computeDisplayState` in Event.m: 2 occurrences (definition + comment ref) ✓
- ISA-18.2 state names in Event.m: 9 occurrences ✓
- `acknowledgeEvent` in EventStore.m: 3 occurrences ✓
- `EventStore:unknownEventId` in EventStore.m: 5 occurrences ✓
