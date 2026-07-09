---
type: quick
quick_id: 260709-spc
slug: implement-issue-338-tag-spectrum
issue: 338
status: complete
---

# Quick Task: Tag.spectrum()/dominantFrequency() — frequency-domain sibling (#338)

## Goal
Add the domain-critical frequency-analysis primitive: single-sided amplitude
spectrum + dominant frequency, toolbox-free (core fft).

## Scope (additive only)
- **File:** `libs/SensorThreshold/Tag.m` (base methods, inherited by all kinds).
- **New API:** `[f,amp] = spectrum('SampleRate',Fs,'Detrend',mode)`;
  `fPeak = dominantFrequency(...)` (argmax non-DC). Fs inferred from median dt.
  numeric-only. Assumes near-uniform sampling (points at resampleUniform #308).

## Test
- `tests/suite/TestTag.m`: 10Hz sine peak, amplitude+length, SampleRate override,
  Detrend DC removal, too-few-points, non-numeric, bad-options.

## Verification
- TestTag 91/91. check_matlab_code + MISS_HIT clean.
