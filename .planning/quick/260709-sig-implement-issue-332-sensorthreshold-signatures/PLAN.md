---
type: quick
quick_id: 260709-sig
slug: implement-issue-332-sensorthreshold-signatures
issue: 332
status: complete
---

# Quick Task: SensorThreshold functionSignatures.json (#332)

## Goal
Editor tab-completion for the Tag family, parity with FastSense/Dashboard.

## Scope (additive only)
- New `libs/SensorThreshold/functionSignatures.json` — constructors (Sensor/
  State/Monitor/Composite Tag), factories (level/band), fromCsv, nameAt,
  TagRegistry, and the Tag analysis methods (percentile/integral/correlate/
  lagCorrelation/findPeaks/removeOutliers/spectrum/compareWindows/getStats).

## Test
- New `tests/test_function_signatures.m`: all 3 signatures JSON parse + schema;
  SensorThreshold has the expected new entries.

## Verification
- test_function_signatures passes; jsondecode valid. MISS_HIT clean (test).
