---
type: quick
quick_id: 260709-cbk
slug: implement-issue-363-add-tagregistry-tost
issue: 363
status: complete
---

# Summary: TagRegistry.toStructs() (#363)

## What was built
- `libs/SensorThreshold/TagRegistry.m`: new static method
  `structs = TagRegistry.toStructs()` — iterates the private `catalog()` map,
  sorts keys for deterministic output, calls each tag's existing `toStruct()`,
  returns a `1xN` cell (empty catalog → `1x0`). Pure assembly, no new per-tag
  serialization. Documented in the class header method list.
- `tests/suite/TestTagRegistry.m`: 3 new tests
  (`testToStructsEmptyReturnsEmptyCell`, `testToStructsSortedByKey`,
  `testToStructsRoundTripsThroughLoadFromStructs`).

## Verification
- `TestTagRegistry`: 29 passed / 0 failed (was 26; +3).
- `check_matlab_code`: clean on added code (2 warnings are pre-existing
  containers.Map-assignment idiom at lines 95/138, not touched).
- MISS_HIT `mh_style` + `mh_lint`: clean on both files.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no Tag/Widget
contract change · output feeds existing `loadFromStructs` (clean round-trip).
