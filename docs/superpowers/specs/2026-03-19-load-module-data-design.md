# loadModuleData — Module Struct to Sensor Registry Bridge

**Date:** 2026-03-19
**Status:** Draft

## Problem

An external system stores sensor data in .mat files as structs ("modules"). Each struct contains:
- Many sensor fields (field name = sensor key, value = 1xN double vector)
- A shared datenum field (name varies per module)
- A `.doc` sub-struct with metadata, including `doc.date` which names the datenum field

We need a fast function to match struct fields against sensors already registered in an `ExternalSensorRegistry` and assign X/Y data to each matched sensor.

## Key Constraint

**Struct field names must match registry keys exactly.** The function matches by string identity — a sensor registered under key `'pressure'` will only match a struct field named `pressure`. No aliasing or renaming is supported.

## Function Signature

```matlab
sensors = loadModuleData(registry, moduleStruct)
```

**Input:**
- `registry` — `ExternalSensorRegistry` with sensors pre-registered
- `moduleStruct` — Scalar struct from external system (not a struct array)

**Output:**
- `sensors` — `1xN` cell array of Sensor objects that were matched and filled with X/Y data. Order follows `fieldnames(moduleStruct)`. Empty `1x0` cell if no matches.

## Algorithm

1. Read `moduleStruct.doc.date` to get the datenum field name
2. Extract datenum vector: `X = moduleStruct.(datenumField)`
3. `fields = fieldnames(moduleStruct)` — all struct fields
4. `registeredKeys = registry.keys()` — returns `1xN` cell of char
5. `ismember(fields, registeredKeys)` to find struct fields present in the registry
6. Exclude `doc` and the datenum field from the match set
7. Loop over matches: `sensor = registry.get(field); sensor.X = X; sensor.Y = moduleStruct.(field)`
8. Return `1xN` cell array of filled sensors

## Performance Design

- **Single pass:** One `fieldnames()` call, one `ismember()` — fast for typical module sizes (tens to hundreds of fields)
- **No memory duplication:** Sensor is a handle class — assigning the same `X` array to multiple sensors stores a reference, not a copy. Only one datenum vector exists in memory.
- **No validation/normalization:** Raw speed. The caller is responsible for data integrity.
- **No disk I/O:** Function receives already-loaded struct, does not call `load()`

## Location

`libs/SensorThreshold/loadModuleData.m` — standalone function alongside ExternalSensorRegistry.

## Edge Cases

- If `doc` or `doc.date` is missing: error with clear message
- If `doc.date` names a field not present in the struct: error with clear message
- If no fields match registered sensors (or registry is empty): return empty `1x0` cell
- Fields named `doc` and the datenum field are always excluded from matching
- Repeated calls overwrite `sensor.X` and `sensor.Y` in-place (handle semantics)
