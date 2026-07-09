---
type: quick
quick_id: 260709-csv
slug: implement-issue-345-sensortag-fromcsv
issue: 345
status: complete
---

# Quick Task: SensorTag.fromCsv() — Octave-safe CSV/TSV import (#345)

## Goal
One-shot delimited-file -> SensorTag, import sibling of exportCsv (#288),
Octave-safe (reuses readRawDelimited_, NOT readtable).

## Scope (additive only)
- `libs/SensorThreshold/SensorTag.m` (Static): fromCsv(path, ...). TimeCol/
  ValueCol by name or index, multi ValueCol -> array, Key override, passthrough
  NV -> ctor. Auto delimiter, sort by time. + private resolveCsvCol_/csvColName_.

## Test
- `tests/suite/TestSensorTag.m`: auto cols, by-name, multi-col array, key+units
  passthrough, sort-by-time, bad-column errors. (+ writeTempCsv_ helper)

## Verification
- TestSensorTag 26/26. check_matlab_code + MISS_HIT clean.
