---
type: quick
quick_id: 260709-rmc
slug: implement-issue-364-datastore-removecolumn
issue: 364
status: complete
---

# Quick Task: FastSenseDataStore.removeColumn(name) (#364)

## Goal
The DELETE of the add/list/read column surface; enables the "replace a column"
idiom removeColumn(name) + addColumn(name,newData).

## Scope (additive only)
- `libs/FastSense/FastSenseDataStore.m`: removeColumn(name) mirroring addColumn's
  guards + BEGIN/COMMIT/ROLLBACK; DELETE FROM columns WHERE col_name=?; drop from
  ColumnNames; unknown -> FastSenseDataStore:unknownColumn.

## Test
- `tests/suite/TestDatastoreColumnsAndCache.m` (mksqlite-gated): drops-it,
  unknown-throws, remove-then-add-replaces.

## Verification
- TestDatastoreColumnsAndCache 33/33. check_matlab_code + MISS_HIT clean.
