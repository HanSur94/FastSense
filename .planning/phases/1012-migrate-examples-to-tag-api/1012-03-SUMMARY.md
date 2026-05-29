---
phase: 1012-migrate-examples-to-tag-api
plan: 03
status: complete
commits: 2
files_changed: 6
duration: 12min
---

# Plan 1012-03 Summary — Migrate 02-sensors + add tags/ showcase

## Outcome

Two atomic commits, per CONTEXT.md line 55 lock (NON-NEGOTIABLE dual-commit discipline).

### Commit 1 — `8830acc` `refactor(examples): migrate 02-sensors existing files to Tag API (fix toDisk example)`

Migrated one remaining legacy hazard in `examples/02-sensors/` (the rest were already Tag-clean from Phase 1011 bulk substitution).

**Fixed: `examples/02-sensors/example_sensor_todisk.m`**
- Removed `.ResolvedThresholds` / `.ResolvedViolations` references (deleted in Phase 1011) — replaced with a `MonitorTag` + `sc = StateTag` demo showing that `MonitorTag.getXY()` works transparently on a disk-backed `SensorTag` parent.
- Fixed 4 self-referential constructor bugs where the text-replace had left `s.X` / `s2.X` / `s3.X` / `si.X` on the RHS of the constructor assigning those same variables — extracted the data into local `tX/tY` / `t2X/t2Y` / `t3X/t3Y` / `sxi/syi` arrays.
- Added a `thresholdForState` local helper for the new `MonitorTag.ConditionFn` closure.

### Commit 2 — `a5caeb4` `refactor(examples): add 02-sensors/tags/ Tag-primitive showcase (5 scripts)`

Created 5 showcase scripts in a new `examples/02-sensors/tags/` subfolder, one per Tag primitive. Each script demonstrates the primitive end-to-end and **registers every tag it constructs via `TagRegistry.register`** (CONTEXT.md line 51 lock).

| Script | Primitive | `TagRegistry.register` count | Notable |
|--------|-----------|------------------------------|---------|
| `example_tag_sensor.m` | `SensorTag` | 2 (min 1) | Construct, register, `updateData` append, render via `fp.addTag` |
| `example_tag_state.m`  | `StateTag`  | 2 (min 1) | Numeric + cellstr forms; ZOH `valueAt` on scalar + vector t; render as bands |
| `example_tag_monitor.m`| `MonitorTag`| 5 (min 3) | Simple / hysteresis / debounce variants on a shared parent; parent-driven invalidation demo |
| `example_tag_composite.m` | `CompositeTag` | 9 (min 6) | AND vs MAJORITY side-by-side on `FastSenseGrid(1,2)`; 4 AggregateMode quoted (`'and'`, `'or'`, `'majority'`, etc.) |
| `example_tag_registry.m` | `TagRegistry` | 5 (min 3) | CRUD demo; **HARD-ERROR on duplicate Key** via `try/catch` + `TagRegistry:duplicateKey` assert |

## Acceptance gates (all green)

- Commit 1 `git log -1 --name-only --format= | grep -c '02-sensors/tags/'` returns **0** ✓
- Commit 2 `git log -1 --name-only --format= | grep -c '02-sensors/tags/'` returns **5** ✓
- Per-script `TagRegistry.register` grep counts all exceed the plan minimums (2/2/5/9/5 vs 1/1/3/6/3 required)
- Composite script `grep -cE "'(and|or|majority|count|worst|severity)'" example_tag_composite.m` returns **4** (min 2)
- Registry script duplicate-Key assertion present (8 hits for `duplicateKey|duplicate`)
- All 5 scripts start with the 4-level preamble (`fileparts(fileparts(fileparts(fileparts(...))))`) because they live one level deeper than the sibling examples
- Grep regression on `02-sensors/` for legacy patterns returns **0** hits

## Self-Check: PASSED

- [x] Exactly 2 atomic commits (Commit 1 = existing files only, Commit 2 = tags/ only)
- [x] No overlap — `git log -1 --name-only` for each commit verifies isolation
- [x] All 5 showcase scripts follow the narrative style of `examples/02-sensors/example_sensor_registry.m`
- [x] Every tag constructed is registered via `TagRegistry.register` (CONTEXT.md decision line 51)
- [x] HARD-ERROR duplicate-Key demo present in `example_tag_registry.m` (CONTEXT.md `<specifics>` requirement)
- [x] `example_tag_composite.m` demonstrates ≥2 AggregateModes side-by-side (CONTEXT.md `<specifics>` requirement)

## Deferred

- `TagRegistry.loadFromStructs` two-phase JSON round-trip — mentioned in the registry docstring but not demonstrated in `example_tag_registry.m` to keep the script focused. Candidate for a follow-on showcase or a dedicated JSON-persistence demo.
- Numeric vs. cellstr `StateTag.Y` cross-section — `example_tag_state.m` shows both forms in isolation; a future example could combine them in one pipeline.
