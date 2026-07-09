---
type: quick
quick_id: 260709-csv
slug: implement-issue-345-sensortag-fromcsv
issue: 345
status: complete
---

# Summary: SensorTag.fromCsv() (#345)

## What was built
- `libs/SensorThreshold/SensorTag.m`: static `fromCsv(path, ...)` — one-shot
  delimited-file import returning a SensorTag (or array for multiple value
  columns). Resolves TimeCol/ValueCol by header name OR 1-based index; multiple
  ValueCol -> SensorTag array keyed by header; 'Key' overrides the single-value
  key; other NV pairs (Name/Units/Criticality/...) forward to the constructor.
  Reads through the library's toolbox-free, Octave-safe readRawDelimited_ (MEX +
  pure-MATLAB fallback) — NOT readtable — auto-detects the delimiter, and sorts
  rows by ascending time. Added private helpers resolveCsvCol_ / csvColName_.
- `tests/suite/TestSensorTag.m`: +6 tests (auto cols, by-header-name, multi-col
  array, key-override + Units passthrough, sort-by-time, bad-column errors) plus
  a writeTempCsv_ helper.

## Verification
- TestSensorTag: 26 passed / 0 failed (was 20; +6).
- check_matlab_code + MISS_HIT mh_style/mh_lint: clean.

## Constraints
Strictly additive · toolbox-free / Octave-safe (readRawDelimited_, not
readtable) · pure MATLAB/Octave · no serialization/contract change.
