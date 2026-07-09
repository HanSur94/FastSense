---
type: quick
quick_id: 260709-spc
slug: implement-issue-338-tag-spectrum
issue: 338
status: complete
---

# Summary: Tag.spectrum() / dominantFrequency() (#338)

## What was built
- `libs/SensorThreshold/Tag.m`: base-class `[f, amp] = spectrum(...)` — single-
  sided amplitude spectrum via core fft (non-DC/non-Nyquist bins doubled so a
  pure tone reads ~A). Fs inferred from median getXY spacing or given via
  'SampleRate'; optional 'Detrend' (true/'linear' | 'mean' | false). numeric-Y
  only (Tag:notNumeric); >=2 samples (Tag:spectrumTooFewPoints). Plus
  `fPeak = dominantFrequency(...)` — argmax bin ignoring DC. Toolbox-free (NOT
  Signal Processing Toolbox). Inherited by every tag kind.
- `tests/suite/TestTag.m`: +7 tests (10Hz sine peak, amplitude+bin-count,
  SampleRate override, mean-Detrend DC removal, too-few-points, non-numeric,
  bad-options).

## Verification
- TestTag: 91 passed / 0 failed (was 84; +7).
- check_matlab_code + MISS_HIT mh_style/mh_lint: clean.

## Constraints
Strictly additive · toolbox-free (core fft) · pure MATLAB/Octave · read-only ·
no serialization/contract change. Assumes near-uniform sampling (documented;
points at resampleUniform #308 for irregular streams).
