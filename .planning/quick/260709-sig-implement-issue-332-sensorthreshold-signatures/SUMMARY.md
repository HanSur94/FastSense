---
type: quick
quick_id: 260709-sig
slug: implement-issue-332-sensorthreshold-signatures
issue: 332
status: complete
---

# Summary: SensorThreshold functionSignatures.json (#332)

## What was built
- `libs/SensorThreshold/functionSignatures.json`: editor tab-completion metadata
  for the Tag family (parity with the FastSense/Dashboard signatures). 21 entries
  covering the SensorTag/StateTag/MonitorTag/CompositeTag constructors, the
  MonitorTag.level/band factories, SensorTag.fromCsv, StateTag.nameAt/transitions,
  TagRegistry.get/register/toStructs, and the Tag analysis methods (getStats,
  percentile, integral, correlate, lagCorrelation, findPeaks, removeOutliers,
  spectrum, compareWindows) — with kind/type/choices for each argument.
- `tests/test_function_signatures.m`: validates all three functionSignatures.json
  files parse as JSON with a schema version and that the SensorThreshold file
  exposes the expected Tag-family + factory entries.

## Verification
- test_function_signatures: passes (jsondecode valid across all 3 files, 21
  SensorThreshold entries, expected keys present).
- MISS_HIT mh_style + mh_lint clean on the test.

## Constraints
Strictly additive · toolbox-free · pure data/tooling artifact (no runtime code) ·
malformed JSON would simply not load — validated to parse.
