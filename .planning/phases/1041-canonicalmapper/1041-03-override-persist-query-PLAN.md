---
phase: 1041-canonicalmapper
plan: 03
type: tdd
wave: 2
depends_on: ["1041-02"]
files_modified:
  - libs/Fleet/CanonicalMapper.m
autonomous: true
requirements: [CANON-03, CANON-04]
must_haves:
  truths:
    - "User can call mapper.override(logicalId, machineId, localKey) and the override persists with precedence over auto-suggestions (status OVERRIDDEN, survives re-run of suggest)"
    - "toStruct/fromStruct and save/load round-trip preserve every entry including OVERRIDDEN status"
    - "mapper.reviewPending() returns every LOW-confidence AUTO entry and every unit-mismatch entry, and excludes HIGH/MEDIUM/CONFIRMED/OVERRIDDEN good entries — the gate that keeps wrong comparisons from happening silently"
    - "mapper.unmapped(machineId) returns the tail of localKeys with no canonical assignment; isResolvable(logicalId, machineId) is false for LOW+AUTO and true for HIGH+AUTO"
  artifacts:
    - path: "libs/Fleet/CanonicalMapper.m"
      provides: "override, confirm, reviewPending, unmapped, isResolvable, toStruct, fromStruct, save, load + normalizeToCell_ helper"
      contains: "function reviewPending"
      min_lines: 280
  key_links:
    - from: "CanonicalMapper.reviewPending"
      to: "comparison exclusion gate (Phase 1045)"
      via: "returns LOW-AUTO + unitMismatch entries"
      pattern: "function pending = reviewPending"
    - from: "CanonicalMapper.save"
      to: "atomic JSON file"
      via: "fwrite to .tmp then movefile (EventStore pattern)"
      pattern: "movefile\\("
    - from: "CanonicalMapper.override"
      to: "Entries_ with status OVERRIDDEN precedence"
      via: "suggest skips non-AUTO entries"
      pattern: "OVERRIDDEN"
---

<objective>
Complete the CanonicalMapper data model in `libs/Fleet/CanonicalMapper.m` by adding the manual-override + confirm methods (CANON-03 precedence), the JSON persistence round-trip (`toStruct`/`fromStruct`/`save`/`load`, DashboardSerializer per-entry-encode + EventStore atomic-write patterns), and the review/query API (`reviewPending`, `unmapped`, `isResolvable` — CANON-04, the safety gate that excludes unreviewed matches from comparison).

Purpose: This is the "reviewable so wrong comparisons can't happen silently" half of the phase goal. `reviewPending`/`isResolvable` are the exact contract Phase 1045's comparison view calls to exclude LOW-confidence and unit-mismatch matches. Override persistence ensures a user-confirmed safe mapping never reverts to a possibly-wrong AUTO entry.
Output: `libs/Fleet/CanonicalMapper.m` extended with override/confirm/reviewPending/unmapped/isResolvable/toStruct/fromStruct/save/load + private normalizeToCell_.

This is a TDD plan: the 12 CANON-03/04 test methods in TestCanonicalMapper.m (RED since Plan 01) are the GREEN target. By plan end, 28 of 30 tests are GREEN (only the MATLAB-only editor smoke test testEditorConstructs remains for Plan 04).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/1041-canonicalmapper/1041-RESEARCH.md
@.planning/phases/1041-canonicalmapper/1041-VALIDATION.md

<interfaces>
<!-- The CANON-03/04 test contract lives in tests/suite/TestCanonicalMapper.m (Plan 01). Read it. -->
<!-- Signatures + patterns below are LOCKED by RESEARCH.md Q3/Q6 + § Code Examples. -->

Status state machine (LOCKED — RESEARCH.md Pattern 3):
```
override(logicalId, mId, localKey) -> status='OVERRIDDEN', confidence='HIGH' (manual = max)
confirm(logicalId, mId)            -> status='CONFIRMED', confidence unchanged
precedence: OVERRIDDEN > CONFIRMED > AUTO
suggest() skips any (logicalId, machineId) already present with status ~= 'AUTO'
```

reviewPending() return (LOCKED — RESEARCH.md Q6 / § Code Examples):
```matlab
% cell of entry structs where:
%   (status=='AUTO' AND confidence=='LOW')  OR  unitMismatch==true
function pending = reviewPending(obj)
    pending = {};
    logIds = obj.Entries_.keys();
    for i = 1:numel(logIds)
        machineEntries = obj.Entries_(logIds{i});
        for j = 1:numel(machineEntries)
            e = machineEntries{j};
            needsReview = (strcmp(e.status,'AUTO') && strcmp(e.confidence,'LOW')) || e.unitMismatch;
            if needsReview; pending{end+1} = e; end %#ok<AGROW>
        end
    end
end
```

isResolvable (LOCKED — RESEARCH.md § Code Examples — the Phase 1045 gate):
```matlab
function ok = isResolvable(obj, logicalId, machineId)
    ok = false;
    if ~isKey(obj.Entries_, logicalId); return; end
    machineEntries = obj.Entries_(logicalId);
    for i = 1:numel(machineEntries)
        e = machineEntries{i};
        if strcmp(e.machineId, machineId)
            isBlocked = (strcmp(e.status,'AUTO') && strcmp(e.confidence,'LOW')) ...
                     || (e.unitMismatch && ~strcmp(e.status,'CONFIRMED') && ~strcmp(e.status,'OVERRIDDEN'));
            ok = ~isBlocked;
            return;
        end
    end
end
```

unmapped(machineId) (LOCKED — RESEARCH.md Q6): cellstr of localKeys that appeared in the last suggest() input for machineId but are NOT present as any entry's localKey in Entries_. Cross-reference obj.LastTagInfos_ (the seam Plan 02 added) against Entries_.

toStruct / fromStruct (LOCKED — RESEARCH.md Pattern 4 — copy structure):
```matlab
function s = toStruct(obj)
    s.version = 1;
    entryList = {};
    logIds = obj.Entries_.keys();
    for i = 1:numel(logIds)
        machineEntries = obj.Entries_(logIds{i});
        for j = 1:numel(machineEntries)
            entryList{end+1} = machineEntries{j}; %#ok<AGROW>
        end
    end
    s.entries = entryList;
end

function obj = fromStruct(s)            % STATIC
    obj = CanonicalMapper();
    if ~isfield(s,'version') || s.version ~= 1
        warning('CanonicalMapper:unknownVersion','Unknown schema version; loading as v1.');
    end
    entries = s.entries;
    if isstruct(entries); entries = normalizeToCell_(entries); end   % jsondecode collapses homogeneous arrays
    for i = 1:numel(entries)
        e = entries{i};
        if ~isKey(obj.Entries_, e.logicalId); obj.Entries_(e.logicalId) = {}; end
        obj.Entries_(e.logicalId){end+1} = e;
    end
end
```

Persistence patterns to mirror:
- libs/Dashboard/DashboardSerializer.m:218-228 — per-entry jsonencode + ['[' strjoin(parts,',') ']'] assembly (NEVER jsonencode a cell-of-structs directly — Pitfall 5)
- libs/EventDetection/EventStore.m:277 — atomic save: write to tmp, then movefile(tmp, dest)
- libs/FastSenseCompanion/companionPrefs.m:61 — movefile(tmpPath, prefsPath, 'f')
- libs/Dashboard/private/normalizeToCell.m — the exact jsondecode->cell normalization to PORT as a private local function normalizeToCell_ in CanonicalMapper.m (do NOT cross-import; no Dashboard dep in Phase 1041)
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: override + confirm + reviewPending + unmapped + isResolvable (CANON-03 precedence, CANON-04 queries)</name>
  <read_first>
    - libs/Fleet/CanonicalMapper.m (current state from Plan 02 — Entries_, suggest, LastTagInfos_ seam; you are adding methods)
    - tests/suite/TestCanonicalMapper.m (GREEN targets: testOverrideCreatesEntry, testOverrideSurvivesResuggest, testReviewPendingReturnsLow, testReviewPendingReturnsUnitMismatch, testReviewPendingExcludesGoodEntries, testUnmappedReturnsUnresolved, testUnmappedEmptyWhenAllMapped, testIsResolvableFalseForLow, testIsResolvableTrueForHigh — read each for exact expected values)
    - .planning/phases/1041-canonicalmapper/1041-RESEARCH.md (Pattern 3 status state machine + Q6 reviewPending/unmapped/isResolvable semantics + § Code Examples)
  </read_first>
  <behavior>
    - testOverrideCreatesEntry: override creates an entry with status='OVERRIDDEN', the given localKey, confidence='HIGH'.
    - testOverrideSurvivesResuggest: after override, re-running suggest does NOT replace the OVERRIDDEN entry.
    - testReviewPendingReturnsLow / ReturnsUnitMismatch: both kinds appear in reviewPending().
    - testReviewPendingExcludesGoodEntries: HIGH-no-mismatch AUTO, CONFIRMED, and OVERRIDDEN entries are NOT in reviewPending().
    - testUnmappedReturnsUnresolved: unmapped('M03') contains the unmatched key (e.g. 'pressure').
    - testUnmappedEmptyWhenAllMapped: unmapped returns {} when all of a machine's keys are clustered.
    - testIsResolvableFalseForLow / TrueForHigh: the Phase 1045 gate logic exactly.
  </behavior>
  <action>
    Add these public methods to `libs/Fleet/CanonicalMapper.m`.

    1. `override(obj, logicalId, machineId, localKey)`:
       - Validate args are non-empty char (else `error('CanonicalMapper:invalidInput', ...)`).
       - Build/replace the entry for (logicalId, machineId): status='OVERRIDDEN', confidence='HIGH', localKey=given, similarity=1.0, unitMismatch=false (manual override is user-asserted correct), localName/localUnits carried from LastTagInfos_ if a matching (machineId, localKey) is found there, else ''.
       - If logicalId not yet a key, create `obj.Entries_(logicalId) = {}`. Replace any existing entry for the same machineId in that cluster (do not duplicate the machine), else append.

    2. `confirm(obj, logicalId, machineId)`:
       - Find the entry for (logicalId, machineId); set status='CONFIRMED' (confidence UNCHANGED — user endorses the existing confidence). Error `CanonicalMapper:unknownLogicalId` if the logicalId is absent; error `CanonicalMapper:unknownMachine` if no entry for that machineId in the cluster.

    3. Enforce PRECEDENCE in suggest (CANON-03). suggest already has the `LastTagInfos_` seam from Plan 02; add (or confirm present) the guard: before inserting any AUTO entry for (logicalId, machineId), check if an entry for that machineId already exists in `obj.Entries_(logicalId)` with `status ~= 'AUTO'` — if so, SKIP (do not overwrite). This makes testOverrideSurvivesResuggest pass. If the guard already exists from Plan 02, verify it covers OVERRIDDEN and CONFIRMED.

    4. `reviewPending(obj)` — copy VERBATIM from the interfaces block (RESEARCH.md § Code Examples). Returns a cell of entry structs where `(status=='AUTO' && confidence=='LOW') || unitMismatch`.

    5. `isResolvable(obj, logicalId, machineId)` — copy VERBATIM from the interfaces block. Returns false for LOW+AUTO and for unconfirmed unit-mismatch; true otherwise.

    6. `unmapped(obj, machineId)` (CANON-04):
       - Build the set of localKeys for machineId that appear anywhere in Entries_ (any logicalId, any status).
       - From `obj.LastTagInfos_`, collect every localKey whose machineId matches the argument.
       - Return (as a cellstr) the localKeys present in the input set but absent from the mapped set. Return `{}` if all are mapped or LastTagInfos_ is empty for that machine. Order: stable (input order) or sorted — pick sorted ascending for determinism and document it.

    7. Run the suite. The 2 override tests + 3 reviewPending tests + 2 unmapped tests + 2 isResolvable tests (9 CANON-03/04 methods) GREEN. The 3 round-trip/persistence tests (testRoundTripPreservesEntries, testRoundTripPreservesOverriddenStatus, testSaveLoadRoundTrip) remain RED until Task 2. testEditorConstructs RED until Plan 04.

    Octave-safety: still no contains/startsWith/endsWith/string. Use strcmp/strfind/isKey/ismember.
  </action>
  <verify>
    <automated>runtests('tests/suite/TestCanonicalMapper') — the 9 CANON-03/04 query+override methods GREEN; the 3 persistence tests still RED (Task 2); editor RED (Plan 04). Run via mcp__matlab__run_matlab_test_file.</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "function override" libs/Fleet/CanonicalMapper.m` >= 1; `grep -c "function confirm" libs/Fleet/CanonicalMapper.m` >= 1
    - `grep -c "function pending = reviewPending\|function .*reviewPending" libs/Fleet/CanonicalMapper.m` >= 1
    - `grep -c "function .*isResolvable" libs/Fleet/CanonicalMapper.m` >= 1; `grep -c "function .*unmapped" libs/Fleet/CanonicalMapper.m` >= 1
    - Precedence enforced: `grep -c "OVERRIDDEN" libs/Fleet/CanonicalMapper.m` >= 2 (set in override + checked in suggest guard)
    - Octave-safety still holds: `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` returns `0`; `grep -rn "editDistance(" libs/Fleet/CanonicalMapper.m` returns `0`
    - `mcp__matlab__check_matlab_code` on libs/Fleet/CanonicalMapper.m reports no error-level diagnostics
    - `runtests('tests/suite/TestCanonicalMapper')` PASSES all 9 of: testOverrideCreatesEntry, testOverrideSurvivesResuggest, testReviewPendingReturnsLow, testReviewPendingReturnsUnitMismatch, testReviewPendingExcludesGoodEntries, testUnmappedReturnsUnresolved, testUnmappedEmptyWhenAllMapped, testIsResolvableFalseForLow, testIsResolvableTrueForHigh (plus the 14 CANON-01/02 + 2 grep gates from Plan 02 remain GREEN — 25 total GREEN)
  </acceptance_criteria>
  <done>override/confirm establish OVERRIDDEN>CONFIRMED>AUTO precedence (override survives re-suggest); reviewPending returns exactly the LOW-AUTO + unit-mismatch entries and excludes good ones; unmapped returns the unresolved tail; isResolvable encodes the Phase 1045 exclusion gate; 25 of 30 tests GREEN.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: toStruct/fromStruct + save/load JSON round-trip + normalizeToCell_ (CANON-03 persistence)</name>
  <read_first>
    - libs/Fleet/CanonicalMapper.m (current state from Task 1)
    - tests/suite/TestCanonicalMapper.m (GREEN targets: testRoundTripPreservesEntries, testRoundTripPreservesOverriddenStatus, testSaveLoadRoundTrip)
    - libs/Dashboard/DashboardSerializer.m (lines 215-244 — per-entry jsonencode + strjoin assembly; the empty-cell ambiguity note at :249)
    - libs/EventDetection/EventStore.m (lines 270-278 — atomic movefile save)
    - libs/Dashboard/private/normalizeToCell.m (the exact body to PORT as a private local function — do not cross-import)
    - .planning/phases/1041-canonicalmapper/1041-RESEARCH.md (Pattern 4 toStruct/fromStruct + Q3 persistence + Pitfall 5 jsonencode-of-cell)
  </read_first>
  <behavior>
    - testRoundTripPreservesEntries: toStruct -> fromStruct preserves entry count and field values.
    - testRoundTripPreservesOverriddenStatus: an OVERRIDDEN entry survives toStruct -> (jsonencode/jsondecode) -> fromStruct with status still 'OVERRIDDEN'.
    - testSaveLoadRoundTrip: save(path) then load(path) yields an identical-state mapper (entry count + spot entry match).
  </behavior>
  <action>
    Add persistence to `libs/Fleet/CanonicalMapper.m`.

    1. `toStruct(obj)` — copy VERBATIM from the interfaces block (RESEARCH.md Pattern 4). Returns `struct` with `version=1` and `entries` = flat cell of all entry structs across all logicalIds.

    2. STATIC `fromStruct(s)` — copy VERBATIM from the interfaces block. Calls the private `normalizeToCell_` when `s.entries` arrives as a struct array (jsondecode collapses homogeneous JSON arrays). Rebuilds Entries_ keyed by logicalId. Warn `CanonicalMapper:unknownVersion` if version missing or != 1. Declare as a `methods (Static)` member.

    3. PRIVATE local function `normalizeToCell_(x)` at the bottom of the .m file — PORT the body of libs/Dashboard/private/normalizeToCell.m verbatim (empty -> {}, struct array -> cell via per-element copy, else passthrough). Do NOT add a dependency on the Dashboard library; this is a self-contained copy (RESEARCH.md "Don't Hand-Roll" row explicitly prescribes this).

    4. `save(obj, filepath)` — follow DashboardSerializer per-entry encode + EventStore atomic write:
       - `s = obj.toStruct();`
       - Build the entries JSON by encoding EACH entry individually and joining (Pitfall 5 — never jsonencode the whole cell): `parts{i} = jsonencode(s.entries{i});` then `entriesJson = ['[' strjoin(parts, ',') ']'];`. Handle the empty case explicitly: if no entries, `entriesJson = '[]'`.
       - Assemble the top-level object: `json = sprintf('{"version":%d,"entries":%s}', s.version, entriesJson);` (or build via jsonencode on a struct without entries, then splice — match DashboardSerializer:226-228 style; either is acceptable as long as entries is a JSON ARRAY).
       - Atomic write: `tmp = [filepath '.tmp']; fid = fopen(tmp,'w'); if fid==-1; error('CanonicalMapper:fileError','Cannot open file: %s', tmp); end; fwrite(fid, json); fclose(fid); movefile(tmp, filepath, 'f');` (EventStore.m:277 / companionPrefs.m:61 pattern).

    5. STATIC `load(filepath)`:
       - `error('CanonicalMapper:fileNotFound', ...)` if `~isfile(filepath)`.
       - Read all bytes (`fid=fopen(filepath,'r'); raw=fread(fid,'*char')'; fclose(fid);`), `s = jsondecode(raw);`, `obj = CanonicalMapper.fromStruct(s);`. Declare in `methods (Static)`.

    6. Run the full suite. All 3 persistence tests GREEN. Total: 28 of 30 GREEN. Only testEditorConstructs remains RED (Plan 04 builds CanonicalMapEditor).

    Octave parity: jsonencode/jsondecode confirmed on Octave 5+ (RESEARCH.md Q3). Do NOT jsonencode a cell of structs directly. Do NOT use `dir('**/...')`. No contains/string.
  </action>
  <verify>
    <automated>runtests('tests/suite/TestCanonicalMapper') — 28 of 30 GREEN (all CANON-01/02/03/04 + 2 grep gates); only testEditorConstructs RED. Run via mcp__matlab__run_matlab_test_file.</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "function s = toStruct\|function .*toStruct" libs/Fleet/CanonicalMapper.m` >= 1
    - fromStruct and load are STATIC: `grep -c "methods (Static)" libs/Fleet/CanonicalMapper.m` >= 1; `grep -c "function obj = fromStruct\|function .*fromStruct" libs/Fleet/CanonicalMapper.m` >= 1; `grep -c "function obj = load\|function .*= load(filepath)\|function .*load(" libs/Fleet/CanonicalMapper.m` >= 1
    - `grep -c "function .*save(" libs/Fleet/CanonicalMapper.m` >= 1
    - Atomic write present: `grep -c "movefile(" libs/Fleet/CanonicalMapper.m` >= 1
    - Per-entry encode (not whole-cell): `grep -c "strjoin(parts" libs/Fleet/CanonicalMapper.m` >= 1 OR `grep -c "jsonencode(s.entries{" libs/Fleet/CanonicalMapper.m` >= 1
    - normalizeToCell_ ported as a local function: `grep -c "function .*normalizeToCell_" libs/Fleet/CanonicalMapper.m` >= 1; and NO cross-import of the Dashboard helper: `grep -c "normalizeToCell(" libs/Fleet/CanonicalMapper.m` equals the count of `normalizeToCell_(` calls (i.e. only the underscore version is referenced)
    - Octave-safety still holds: `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` returns `0`; `grep -rn "editDistance(" libs/Fleet/CanonicalMapper.m` returns `0`
    - `mcp__matlab__check_matlab_code` on libs/Fleet/CanonicalMapper.m reports no error-level diagnostics
    - `runtests('tests/suite/TestCanonicalMapper')` PASSES testRoundTripPreservesEntries, testRoundTripPreservesOverriddenStatus, testSaveLoadRoundTrip; total passing == 28 (all except testEditorConstructs); 0 failures among those 28
  </acceptance_criteria>
  <done>toStruct/fromStruct round-trip preserves all entries and OVERRIDDEN status; save/load uses per-entry jsonencode assembly + atomic movefile and round-trips identical mapper state; normalizeToCell_ is a self-contained port (no Dashboard dep); 28 of 30 tests GREEN.</done>
</task>

</tasks>

<verification>
- `runtests('tests/suite/TestCanonicalMapper')`: 28 of 30 GREEN (all CANON-01/02/03/04 + grep gates); only testEditorConstructs RED (Plan 04).
- `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` returns 0; `grep -rn "editDistance(" libs/Fleet/CanonicalMapper.m` returns 0 (phase exit criterion #5 stays satisfied).
- mcp__matlab__check_matlab_code: no errors.
- Override survives a re-run of suggest (precedence); save/load round-trips identically.
</verification>

<success_criteria>
- mapper.override persists with precedence over auto-suggestions (CANON-03 success criterion #3).
- toStruct/fromStruct and save/load round-trip preserve every entry incl. OVERRIDDEN (CANON-03).
- reviewPending returns LOW + unit-mismatch entries and excludes good ones; isResolvable gates LOW/unconfirmed-mismatch; unmapped returns the tail (CANON-04 success criterion #2/#3 — the exclusion contract Phase 1045 depends on).
- CanonicalMapper.m remains a pure Octave-safe data model (no UI, no toolbox, no contains).
</success_criteria>

<output>
After completion, create `.planning/phases/1041-canonicalmapper/1041-03-SUMMARY.md`
</output>
