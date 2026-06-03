---
phase: 1041-canonicalmapper
reviewed: 2026-06-03T00:00:00Z
depth: deep
files_reviewed: 4
files_reviewed_list:
  - libs/Fleet/CanonicalMapper.m
  - libs/Fleet/CanonicalMapEditor.m
  - tests/suite/TestCanonicalMapper.m
  - install.m
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 1041: Code Review Report

**Reviewed:** 2026-06-03  
**Depth:** deep  
**Files Reviewed:** 4  
**Status:** issues_found

## Summary

`CanonicalMapper.m` is well-structured and Octave-safe. The core algorithm (seed-then-assign clustering, Wagner-Fischer edit distance, confidence assignment) is correct for the normal case. The JSON round-trip strategy (per-entry `jsonencode` + `normalizeToCell_` to handle jsondecode struct-array collapse) is sound.

Two defects require attention before this ships to Phase 1045: a logic divergence between `reviewPending()` and `isResolvable()` that makes confirmed unit-mismatch entries appear as still-pending (BLOCKER for the "no wrong comparison silently" guarantee), and a duplicate-entry scenario when the same machine has two similarly-punctuated keys that cluster together.

The editor is MATLAB-only by design and structurally sound; findings there are quality gaps rather than data-loss risks.

---

## Critical Issues

### CR-01: `reviewPending()` does not exclude CONFIRMED/OVERRIDDEN unit-mismatch entries — contract violated

**File:** `libs/Fleet/CanonicalMapper.m:279-280`

**Issue:** The test contract (TestCanonicalMapper.m line 39-40) states:
> *"reviewPending(): entries with status AUTO|PENDING AND (confidence==LOW OR unitMismatch). CONFIRMED/OVERRIDDEN entries are never pending."*

The implementation is:
```matlab
needsReview = (strcmp(e.status, 'AUTO') && strcmp(e.confidence, 'LOW')) ...
    || e.unitMismatch;
```

The `|| e.unitMismatch` branch is **not gated on status**. A unit-mismatch entry that has been CONFIRMED (via `CanonicalMapEditor → Promote Anyway`) keeps `unitMismatch = true` in the struct (the flag is set at suggest-time and never cleared). After confirm, `isResolvable()` correctly returns `true` (CONFIRMED overrides the unit-mismatch block), but `reviewPending()` still returns that entry, creating an inconsistency: the comparison gate thinks the entry is safe to use while the review queue says it still needs human attention.

This breaks the "no wrong comparison can happen silently" safety invariant: Phase 1045 code that gates on `reviewPending()` being empty before proceeding would spin indefinitely on any confirmed unit-mismatch entry.

**Fix:**
```matlab
needsReview = strcmp(e.status, 'AUTO') && ...
    (strcmp(e.confidence, 'LOW') || e.unitMismatch);
```
This matches the documented contract: only AUTO (and future PENDING) entries that are LOW or have a unit mismatch need review. CONFIRMED and OVERRIDDEN entries are exempt regardless of `unitMismatch`.

**Test gap to add:** A test that confirms a unit-mismatch entry and then verifies it is absent from `reviewPending()`.

---

## Warnings

### WR-01: Same-machine duplicate entries under one logicalId when a machine has multiple similarly-punctuated sensor keys

**File:** `libs/Fleet/CanonicalMapper.m:175-183`

**Issue:** The cluster-building loop (lines 175-183) does not deduplicate by `machineId`. If a single machine provides two input keys that both normalize to the same centroid (e.g. `Temp.Motor` and `Temp-Motor` both normalize to `temp_motor`), and those keys cross-link to another machine's key at >= MEDIUM similarity, both entries land in the same cluster and both are appended to `entries`, yielding two entry structs with the same `(logicalId, machineId)` pair in the same bucket. The one-entry-per-(logicalId, machineId) schema assumed by `confirm()`, `isResolvable()`, and `unmapped()` is violated, and any downstream consumer iterating the bucket sees a spurious duplicate.

Reproduction sketch:
```matlab
infos = {
    struct('machineId','M01','localKey','Temp.Motor','name','','units','degC'),
    struct('machineId','M01','localKey','Temp-Motor','name','','units','degC'),
    struct('machineId','M02','localKey','temp_motor','name','','units','degC')
};
m = CanonicalMapper(); m.suggest(infos);
% m.Entries_('temp_motor') has 3 entries: M02 once, M01 twice
```

**Fix:** Before appending to `entries` in the cluster loop, check whether `machineId` already has an entry with higher or equal similarity and skip the duplicate (keep the better one):
```matlab
% Before entries{end+1} = ...:
alreadyMapped = false;
for chk = 1:numel(entries)
    if strcmp(entries{chk}.machineId, t.machineId)
        alreadyMapped = true;
        break;
    end
end
if alreadyMapped
    continue;
end
```

---

### WR-02: File-handle leak in `save()` when `fwrite` throws

**File:** `libs/Fleet/CanonicalMapper.m:364-370`

**Issue:** `fwrite(fid, json)` is called without error handling between `fopen` and `fclose`. If `fwrite` fails (e.g. disk full mid-write), MATLAB does not throw — it returns a byte-count of 0. However if the underlying operation raises an exception in an unusual environment, `fclose` at line 369 would be skipped, leaking the file descriptor.

More concretely: `fwrite` does not throw in normal MATLAB, but `movefile` (line 370) can throw (e.g. cross-device move, permission error). In that case, the temp file is left on disk alongside the original — the atomicity guarantee partially holds (original untouched) but the `.tmp` orphan is never cleaned up.

**Fix:** Wrap in a `try/catch` with cleanup:
```matlab
fid = fopen(tmp, 'w');
if fid == -1
    error('CanonicalMapper:fileError', 'Cannot open file for writing: %s', tmp);
end
try
    fwrite(fid, json);
    fclose(fid);
    movefile(tmp, filepath, 'f');
catch moveErr
    fclose(fid);
    if exist(tmp, 'file') == 2
        delete(tmp);
    end
    rethrow(moveErr);
end
```

---

### WR-03: Two distinct seed clusters that normalize to the same `logicalId` silently collide

**File:** `libs/Fleet/CanonicalMapper.m:195-197`

**Issue:** At line 196, `newMap(lid) = entries` overwrites any existing value for `lid`. If two independent seed clusters happen to produce the same normalized logicalId string (e.g. cluster A centroid `flow-rate` and cluster B centroid `flow_rate` both normalize to `flow_rate`), the second cluster's entries silently replace the first cluster's entries. No error, no warning — cluster A's data is lost.

This scenario is more likely than the same-machine duplicate (WR-01) because it can arise from legitimately different sensors whose raw keys accidentally normalize to the same token.

**Fix:** Detect and merge (or raise an error) when a logicalId collision occurs:
```matlab
if isKey(newMap, lid)
    % Collision: two clusters normalized to the same logicalId.
    % Keep existing entries and append, or warn and pick one.
    existingEntries = newMap(lid);
    newMap(lid) = [existingEntries, entries]; %#ok<AGROW>
    warning('CanonicalMapper:logicalIdCollision', ...
        'Two clusters normalized to the same logicalId "%s" — entries merged.', lid);
else
    newMap(lid) = entries;
end
```
A merge-and-warn approach is safest; a complete duplicate-detection pass over `logicalId{:}` before building `newMap` would be cleaner.

---

### WR-04: `onPromote_` silent skip of LOW-confidence warning when entry also has `unitMismatch`

**File:** `libs/Fleet/CanonicalMapEditor.m:333-353`

**Issue:** The warning dialog logic uses `if e.unitMismatch ... elseif strcmp(e.confidence, 'LOW')`. An entry with BOTH `unitMismatch=true` AND `confidence='LOW'` (a LOW-confidence entry whose units differ — possible after MEDIUM downgrade on an attach member) only shows the unit-mismatch dialog, silently skipping the low-confidence warning. The user is informed about the unit problem but not that the similarity score was poor, which is independently relevant information for the confirmation decision.

**Fix:** Replace `elseif` with two independent checks, or compose a combined warning message:
```matlab
msgs = {};
if e.unitMismatch
    msgs{end+1} = sprintf('UNIT MISMATCH: "%s" on machine "%s" uses different units than "%s".', ...
        e.localKey, e.machineId, e.logicalId);
end
if strcmp(e.confidence, 'LOW')
    msgs{end+1} = sprintf('LOW CONFIDENCE: similarity is only %.0f%%.', e.similarity * 100);
end
if ~isempty(msgs)
    sel = uiconfirm(obj.hFig_, strjoin(msgs, sprintf('\n\n')), 'Review Warning', ...
        'Options', {'Promote Anyway', 'Cancel'}, 'DefaultOption', 'Cancel', ...
        'CancelOption', 'Cancel', 'Icon', 'warning');
    if ~strcmp(sel, 'Promote Anyway')
        return;
    end
end
```

---

## Info

### IN-01: `Listeners_` infrastructure is fully dead — allocated but never populated

**File:** `libs/Fleet/CanonicalMapEditor.m:44, 426-427`

**Issue:** `Listeners_ = {}` is declared as a property and cleaned up in `onCloseRequest_` (lines 426-427), but no code path in the class ever calls `addlistener` or appends to `Listeners_`. The cleanup loop is a no-op in all reachable states. The `delete` destructor also does not run the cleanup. If listeners are added in a future patch without updating the destructor, they will leak when `delete(obj)` is called directly (as the test cleanup does).

**Fix:** Either remove the unused infrastructure now, or move the `Listeners_` cleanup into the `delete` destructor so both code paths (close button and `delete`) are covered:
```matlab
function delete(obj)
    for k = 1:numel(obj.Listeners_)
        if isvalid(obj.Listeners_{k})
            delete(obj.Listeners_{k});
        end
    end
    if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
        delete(obj.hFig_);
    end
    obj.IsOpen = false;
end
```

---

### IN-02: Text filter in `filterEntries_` does not search `machineId`

**File:** `libs/Fleet/CanonicalMapEditor.m:240`

**Issue:** The filter haystack is `lower([e.logicalId ' ' e.localKey])`. A user typing a machine ID (e.g. `M03`) in the filter field gets no results, even though Machine is a visible column. This is a usability gap — the filter silently fails for a natural search term.

**Fix:**
```matlab
hay = lower([e.logicalId ' ' e.localKey ' ' e.machineId]);
```

---

### IN-03: `'PENDING'` status is documented and checked in `isResolvable` but is never assigned

**File:** `libs/Fleet/CanonicalMapper.m:37, 300`

**Issue:** The class header, the test-contract doc comment (TestCanonicalMapper.m:39-42), and the `isResolvable` docstring all reference `'PENDING'` as a valid status. `isResolvable` guards against `status~=PENDING` (implicitly, by checking only for CONFIRMED/OVERRIDDEN). But `makeEntry_`, `override()`, and `confirm()` never assign `'PENDING'`. The status is unreachable dead state from the code as written. If Phase 1044 introduces a PENDING assignment path without this review having surfaced the gap, the `reviewPending()` predicate (which currently only checks `status=='AUTO'`) will silently not flag PENDING entries.

**Fix (documentation):** Add a `% TODO(Phase 1044): PENDING status assigned by FleetConfig.importUnreviewed()` comment near the `makeEntry_` function and a `strcmp(e.status, 'PENDING')` branch in `reviewPending()` pre-emptively, or update the header to reflect the current status set `{'AUTO','CONFIRMED','OVERRIDDEN'}`.

---

_Reviewed: 2026-06-03_  
_Reviewer: Claude (gsd-code-reviewer)_  
_Depth: deep_
