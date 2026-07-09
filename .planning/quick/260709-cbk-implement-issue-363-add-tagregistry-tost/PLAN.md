---
type: quick
quick_id: 260709-cbk
slug: implement-issue-363-add-tagregistry-tost
issue: 363
status: in-progress
---

# Quick Task: TagRegistry.toStructs() — whole-catalog serializer (#363)

## Goal
Add the SAVE half of the TagRegistry save/load contract: a static
`TagRegistry.toStructs()` that returns the whole catalog as the cell array
`loadFromStructs` already consumes, sorted by key for determinism.

## Scope (additive only)
- **File:** `libs/SensorThreshold/TagRegistry.m`
- **New API:** `structs = TagRegistry.toStructs()` — static, public.
  - Iterate the private `catalog()` map, sort keys, call each tag's existing
    `toStruct()`, return a `1xN` cell (empty catalog → `1x0` cell).
- No format change, no existing behavior touched. Output feeds existing
  `loadFromStructs` → clean round-trip.

## Test
- `tests/suite/TestTagRegistry.m`: add
  - `testToStructsEmptyReturnsEmptyCell`
  - `testToStructsSortedByKey`
  - `testToStructsRoundTripsThroughLoadFromStructs` (build catalog →
    toStructs → clear → loadFromStructs → verify keys/props restored)

## Verification
- `run_matlab_test_file TestTagRegistry.m` (all pass).
- `check_matlab_code` clean on both files; MISS_HIT style/lint clean.

## Constraints check
- Toolbox-free ✅ · backward-compatible (strictly additive) ✅ ·
  pure MATLAB/Octave ✅ · no Tag/Widget contract change ✅.
