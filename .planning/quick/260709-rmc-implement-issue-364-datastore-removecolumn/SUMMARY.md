---
type: quick
quick_id: 260709-rmc
slug: implement-issue-364-datastore-removecolumn
issue: 364
status: complete
---

# Summary: FastSenseDataStore.removeColumn(name) (#364)

## What was built
- `libs/FastSense/FastSenseDataStore.m`: `removeColumn(name)` — the DELETE of the
  add/list/read column CRUD. Mirrors addColumn's guards (SQLite backend +
  IsValid) and BEGIN/COMMIT/ROLLBACK transaction wrapper: DELETE FROM columns
  WHERE col_name=?, then drop name from ColumnNames. Unknown column ->
  FastSenseDataStore:unknownColumn. Enables the supported "replace a column"
  idiom (removeColumn then addColumn). Sibling of EventStore.removeEvents (#354)
  and PlantLogStore.removeEntries (#365).
- `tests/suite/TestDatastoreColumnsAndCache.m`: +3 mksqlite-gated tests
  (drops-it + data gone, unknown-throws, remove-then-add-replaces).

## Verification
- TestDatastoreColumnsAndCache: 33 passed / 0 failed (was 30; +3), mksqlite
  available on this runner.
- check_matlab_code clean on new method; MISS_HIT mh_style + mh_lint clean.

## Constraints
Strictly additive · toolbox-free · SQLite backend (required, guarded) · no
serialization/format change · existing stores unaffected.
