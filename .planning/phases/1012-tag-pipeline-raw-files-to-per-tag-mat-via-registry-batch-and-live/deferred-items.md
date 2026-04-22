# Phase 1012 Deferred Items

Out-of-scope issues discovered during execution. Tracked but NOT fixed in this phase.

---

## 1. BatchTagPipeline `@BatchTagPipeline.isIngestable_` is not Octave-callable

**Discovered during:** Plan 05 execution (2026-04-22)
**Scope:** Pre-existing defect in Plan 04's `libs/SensorThreshold/BatchTagPipeline.m` (line 149)
**Severity:** Octave-parity violation (CLAUDE.md mandate)

### Symptom

In Octave 7+, calling `BatchTagPipeline.run()` fails with:

```
meta.class: method 'isIngestable_' has private access and cannot be run in this context
```

### Root cause

`BatchTagPipeline.eligibleTags_` invokes:

```matlab
tags = TagRegistry.find(@BatchTagPipeline.isIngestable_);
```

`TagRegistry.find(predicateFn)` calls `predicateFn(t)` from inside its own
class scope. Octave's private-method access check fires at the call site
(not at handle-capture time), and since `TagRegistry` is a different class
from `BatchTagPipeline`, the private static method `isIngestable_` is
rejected.

This defect is invisible to Plan 04's own test suite
(`tests/suite/TestBatchTagPipeline.m`) because `matlab.unittest` only runs
on MATLAB, which is more permissive about cross-class private-method
handles. The defect surfaces as soon as anyone tries to exercise
`BatchTagPipeline` from an Octave script or flat `test_*.m` test.

### Why not fixed in Plan 05

- **Out of scope per Rule 3:** Plan 05 owns `LiveTagPipeline.m`, not
  `BatchTagPipeline.m`. The LiveTagPipeline version of this bug was
  fixed in-scope (predicate inlined in `eligibleTags_` lambda).
- Touching `BatchTagPipeline.m` requires re-running Plan 04's 18 tests
  on MATLAB to confirm no regression, which is outside Plan 05's
  verification envelope.

### Recommended fix (future work)

Mirror Plan 05's resolution in `BatchTagPipeline.eligibleTags_`:

```matlab
% Before:
tags = TagRegistry.find(@BatchTagPipeline.isIngestable_);

% After (Octave-safe):
tags = TagRegistry.find(@(t) ...
    (isa(t, 'SensorTag') || isa(t, 'StateTag')) && ...
    isstruct(t.RawSource) && ...
    isfield(t.RawSource, 'file') && ...
    ~isempty(t.RawSource.file));
```

Delete the `methods (Static, Access = private)` `isIngestable_` block
(or keep as a documentation marker with an `Access = public, Hidden` if
desired). After the fix, run both `TestBatchTagPipeline.m` (MATLAB) and
a flat `test_batch_tag_pipeline.m` (Octave) to confirm parity.

### Reproduction

```bash
cd /path/to/worktree
octave --no-gui --eval "
addpath('.'); install();
TagRegistry.clear();
t = SensorTag('t', 'RawSource', struct('file', '/tmp/x.csv', 'column', 'v'));
TagRegistry.register('t', t);
outDir = tempname(); mkdir(outDir);
p = BatchTagPipeline('OutputDir', outDir);
p.run();
"
```

Expected: per-tag ingest failure on `/tmp/x.csv` missing (the test
scenario). Actual: immediate throw from the private-access check.

---
