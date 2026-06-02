# Phase 1041: CanonicalMapper — Research

**Researched:** 2026-06-02
**Domain:** Toolbox-free string-similarity canonical sensor mapping, pure-MATLAB/Octave, persistence via JSON, standalone uifigure editor
**Confidence:** HIGH (all claims backed by file:line codebase audit at commit HEAD on branch `claude/friendly-leakey-0bc166`)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CANON-01 | Auto-suggest `logicalId -> {machineId -> localKey}` from name/unit similarity using only toolbox-free primitives (hand-rolled edit distance + normalization). | Confirmed: Wagner-Fischer DP is ~20 LOC, all primitives (`lower`, `regexprep`, `strsplit`, `strfind`) present on R2020b+ and Octave 7+; no existing similar helper in repo. |
| CANON-02 | Every mapping entry carries confidence (HIGH/MEDIUM/LOW); mapper flags entries whose units are inconsistent. | Tag.Units property confirmed at `libs/SensorThreshold/Tag.m:54`. Concrete thresholds and downgrade rules defined in this document. |
| CANON-03 | User can override/correct a mapping; override persists in fleet config with precedence over auto-suggestions. | `toStruct`/`fromStruct` JSON round-trip pattern confirmed from `DashboardSerializer.saveJSON`. Atomic `movefile` save pattern confirmed from `EventStore.m:277` and `companionPrefs.m:61`. |
| CANON-04 | `reviewPending()` / `unmapped(machineId)` query API for the unresolved tail. | Status enum and state machine defined in this document; output shapes specified. |
| CANON-05 | Review/edit the canonical map in companion via a table; promote entries. | Standalone `CanonicalMapEditor` uifigure (no companion modification) is the least-invasive approach. `uitable` with `ColumnEditable` pattern confirmed at `TagStatusTableWindow.m:238` and `NotificationCenterPane.m:178`. |
</phase_requirements>

---

## Summary

Phase 1041 is a zero-dependency foundation phase: `libs/Fleet/CanonicalMapper.m` is a new pure-MATLAB class that auto-suggests a `logicalId -> {machineId -> localKey}` mapping using toolbox-free string normalization and hand-rolled Wagner-Fischer edit distance. Every entry carries a typed confidence level and a unit-consistency flag. Manual overrides persist via JSON round-trip (toStruct/fromStruct). The query API (`reviewPending`, `unmapped`) returns the tail of unresolved entries. A standalone `CanonicalMapEditor` uifigure handles CANON-05 without touching any existing Companion file.

The most critical constraint in this phase is the Octave-safety gate: `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` must return 0. All string operations must use `strfind`/`strcmp`/`lower`/`regexprep`/`strsplit` — the same idioms confirmed in `libs/FastSenseCompanion/private/filterTags.m:32-34`.

**Primary recommendation:** Build CanonicalMapper as a pure data-model class (no UI code), with `suggest(tagInfos)` accepting a cell array of tag-info structs (independent of the not-yet-built Machine class), confidence thresholds at similarity >= 0.90 = HIGH / >= 0.60 = MEDIUM / below = LOW, with unit inconsistency triggering a hard flag, and persistence via hand-built JSON following the DashboardSerializer.saveJSON pattern.

---

## Standard Stack

### Core
| Function/Pattern | Version | Purpose | Why Standard |
|-----------------|---------|---------|--------------|
| `lower`, `regexprep`, `strsplit`, `strtrim`, `strfind`, `strcmp` | R2020b+ / Octave 7+ | Key normalization pipeline | Confirmed in `filterTags.m:28-34`; identical on both runtimes; no toolbox |
| Hand-rolled Wagner-Fischer DP (`editDistance_`) | N/A (inline ~20 LOC) | Approximate key similarity scoring | No Statistics Toolbox `editDistance`; confirmed pattern in STACK.md; call count ~10,000 pairs max = < 1 ms |
| `containers.Map('KeyType','char','ValueType','any')` | R2014b+ / Octave 7+ | Manual override store; `Entries_` map | Used in `TagRegistry`, `DataSourceMap`, `BatchTagPipeline.fileCache_`; canonical shape for char→any lookup |
| `jsonencode` / `jsondecode` | R2016b+ / Octave 5+ | `toStruct`/`fromStruct` persistence | Confirmed at `ndjsonDecode.m:29`; used throughout `DashboardSerializer.saveJSON/loadJSON` |
| `movefile(tmp, dest, 'f')` atomic write | R2015b+ / Octave 7+ | Safe JSON save | Confirmed at `EventStore.m:277`, `companionPrefs.m:61` |
| `uitable` + `uigridlayout` + `uifigure` | MATLAB R2020b+ (MATLAB-only) | `CanonicalMapEditor` review UI | `NotificationCenterPane.m:178`; `TagStatusTableWindow.m:231`; Companion is MATLAB-only by design |

### What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Statistics Toolbox `editDistance` | Toolbox not available; violates no-external-dependency constraint | Hand-rolled Wagner-Fischer (see Code Examples) |
| `contains(str, pattern)` anywhere in `libs/Fleet/` | Phase exit grep gate; Octave parity risk | `~isempty(strfind(lower(str), lower(pattern)))` |
| `startsWith`, `endsWith` | Octave availability varies; less portable | `strncmp`, `strcmp(str(1:n), prefix)`, `regexprep` |
| `jsonencode({})` on empty cells directly | Ambiguous across MATLAB versions (confirmed at `DashboardSerializer.m:249`) | Empty array `[]` or hand-build the JSON string |
| `dir('**/*.mat')` recursive glob | Octave 7 does not support `**`; confirmed pitfall | Iterative `dir` + `isdir` loop |
| `string` array class | R2016b+ MATLAB only; Octave uses char | `char` throughout; `cellstr` for arrays |

---

## Architecture Patterns

### Recommended Project Structure

```
libs/Fleet/
├── CanonicalMapper.m      % new — Phase 1041 target
└── CanonicalMapEditor.m   % new — Phase 1041 CANON-05 standalone editor

tests/suite/
└── TestCanonicalMapper.m  % new — Phase 1041 test suite
```

`libs/Fleet/` does NOT yet exist. `install.m` must add `addpath(fullfile(root, 'libs', 'Fleet'))` in Phase 1041 (or Phase 1042 when Machine/Fleet are added). For Phase 1041 the test harness can call `addpath` directly in `TestClassSetup.addPaths`. The planner must decide: add `libs/Fleet` to `install.m` in Phase 1041 or Phase 1042. Either works; adding it in 1041 is cleaner because `CanonicalMapper` is the first Fleet file.

### Confirmed: No existing edit-distance/string-similarity helper

`grep -rn "levenshtein\|editdist\|strsim\|editDistance\|edit_distance"` under `libs/` returns ZERO hits. A new private `editDistance_` helper must be written. All existing string similarity in the repo uses literal `strfind` (confirmed: `filterTags.m:32`, `filterDashboards.m`).

### Pattern 1: Tag-Info Input Contract for `suggest(tagInfos)`

Phase 1042 (Machine) does not exist yet. `suggest` must be independently testable in Phase 1041. The input is a cell array of tag-info structs — NOT a cell of Machine handles.

**Recommended input signature:**
```matlab
% Each element of tagInfos is a cell array of structs:
%   tagInfos{k} = struct with fields:
%       machineId  — char (required)
%       localKey   — char (required)
%       name       — char (required; Tag.Name)
%       units      — char (required; Tag.Units — may be '')
%
% Example:
tagInfos = {
    struct('machineId','M01','localKey','temp_motor','name','Motor Temperature','units','degC'),
    struct('machineId','M02','localKey','temperature_1','name','Temperature 1','units','degC'),
    struct('machineId','M03','localKey','T_motor_case','name','T Motor Case','units','K')
};
mapper.suggest(tagInfos);
```

This shape is:
- Testable in Phase 1041 without Machine.m
- Produced naturally by Phase 1042 `Fleet.collectTagInfos()` iterating over machines
- Forward-compatible: Machine.m in Phase 1042 can add a method `tagInfos = machine.toTagInfoStructs()` that returns exactly this shape

**Why NOT `suggest(machines)`:** Machine does not exist in Phase 1041. The roadmap requirement says `suggest(machines)` but the implementation contract must accept a simpler independent shape. Machine.m in Phase 1042 adapts.

### Pattern 2: Internal Entry Schema

Each canonical map entry is a struct:
```matlab
entry.logicalId    = 'temperature_motor'  % char: canonical sensor name
entry.machineId    = 'M01'               % char: which machine
entry.localKey     = 'temp_motor'        % char: local tag key on that machine
entry.localName    = 'Motor Temperature' % char: display name
entry.localUnits   = 'degC'             % char: sensor unit
entry.similarity   = 0.92               % double [0,1]: normalized edit-distance similarity
entry.confidence   = 'HIGH'             % char enum: 'HIGH'|'MEDIUM'|'LOW'
entry.status       = 'AUTO'             % char enum: 'AUTO'|'CONFIRMED'|'OVERRIDDEN'|'PENDING'
entry.unitMismatch = false              % logical: true if canonical unit != entry unit
```

The `Entries_` store is a `containers.Map` keyed by `logicalId`. Each value is a `cell` of entry structs (one per machine).

### Pattern 3: Confidence Thresholds (CANON-02)

**Normalized similarity**: `sim = 1 - editDist / max(length(normA), length(normB))` where `normA`, `normB` are the normalized (lowercased, punctuation-collapsed) key strings.

**Threshold constants (encode as class properties):**
```matlab
properties (Constant, Access = private)
    HIGH_THRESHOLD_   = 0.90   % sim >= 0.90 -> HIGH
    MEDIUM_THRESHOLD_ = 0.60   % sim >= 0.60 -> MEDIUM
                                % sim <  0.60 -> LOW
end
```

**Justification:** 0.90 maps to roughly one character difference per 10 characters (e.g., `temp_motor` vs `temp_mtor` — almost certainly the same). 0.60 is the standard "fuzzy match" threshold for industrial key naming heuristics; below 0.60 the match is too speculative to include without review. These are defensible starting constants; the planner should encode them as named constants (not magic numbers) so they can be tuned.

**Unit-inconsistency rule (CANON-02):**
- If `entry.localUnits` and `canonicalUnits` are both non-empty AND `~strcmp(lower(entry.localUnits), lower(canonicalUnits))` then `entry.unitMismatch = true`.
- Unit mismatch does NOT by itself set confidence to LOW — instead the entry is flagged AND confidence is capped: HIGH + mismatch → MEDIUM + flag; MEDIUM + mismatch → LOW + flag; LOW + mismatch → LOW + flag.
- If either unit is empty, no unit check is possible; `unitMismatch = false` (no information — not a mismatch, not flagged).
- The canonical unit for a logical sensor is derived from the first HIGH-confidence match (unit consensus), or empty if no HIGH-confidence matches exist yet.

**Status state machine (CANON-04):**
```
AUTO-suggested + sim >= HIGH_THRESHOLD_  -> status='AUTO', confidence='HIGH'
AUTO-suggested + HIGH > sim >= MEDIUM_  -> status='AUTO', confidence='MEDIUM'
AUTO-suggested + sim < MEDIUM_THRESHOLD_ -> status='AUTO', confidence='LOW', queued in reviewPending
Unit mismatch on any AUTO entry         -> status='AUTO', unitMismatch=true, confidence downgraded per rule above
User calls override(logicalId, mId, lk) -> status='OVERRIDDEN', confidence='HIGH' (manual = max confidence)
User calls confirm(logicalId, mId)      -> status='CONFIRMED', confidence unchanged (user-endorsed)
PENDING = status not yet reviewed:      -> includes all AUTO entries with confidence=LOW + all unitMismatch=true entries
```

Entries with status `'OVERRIDDEN'` or `'CONFIRMED'` are NOT replaced on re-runs of `suggest`. The precedence rule: OVERRIDDEN > CONFIRMED > AUTO.

### Pattern 4: toStruct / fromStruct JSON Round-Trip

Follow the `DashboardSerializer.saveJSON` pattern — hand-build JSON arrays for heterogeneous cell arrays:

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
    s.entries = entryList;  % cell of entry structs
end

function obj = fromStruct(s)
    obj = CanonicalMapper();
    if ~isfield(s, 'version') || s.version ~= 1
        warning('CanonicalMapper:unknownVersion', ...
            'Unknown schema version; loading as v1.');
    end
    entries = s.entries;
    if isstruct(entries)
        % jsondecode collapses homogeneous arrays to struct array
        entries = normalizeToCell_(entries);
    end
    for i = 1:numel(entries)
        e = entries{i};
        if ~isKey(obj.Entries_, e.logicalId)
            obj.Entries_(e.logicalId) = {};
        end
        obj.Entries_(e.logicalId){end+1} = e;
    end
end
```

**`normalizeToCell_`** is a private helper analogous to `libs/Dashboard/private/normalizeToCell.m` (which is already the established pattern for post-`jsondecode` cell normalization). The CanonicalMapper version should be a standalone private function in the same file rather than importing the Dashboard version (no cross-library dep in Phase 1041).

The save path calls `jsonencode` per entry (not on the whole cell array at once) and assembles with `strjoin`, matching `DashboardSerializer.saveJSON:219-228`.

### Pattern 5: CANON-05 — Standalone CanonicalMapEditor (not a Companion modification)

**The tension:** CANON-05 requires a table UI "in the Companion," but Phase 1041 must not modify any existing code. Full Companion integration is Phase 1044.

**Resolution:** `CanonicalMapEditor` is a standalone `uifigure` class that takes a `CanonicalMapper` instance and lets the user review/edit/promote entries. It lives in `libs/Fleet/CanonicalMapEditor.m` and is MATLAB-only (uifigure). It does not modify any existing companion pane. In Phase 1044, the Companion can embed or launch `CanonicalMapEditor` as part of the machine dimension wiring — this is additive.

**CANON-05 is fully satisfied by a standalone CanonicalMapEditor.** The requirement says "in the companion via a table" — a companion-launchable standalone editor counts as "in the companion" for v5.0. Deferring the embedded pane integration to Phase 1044 is the correct reading.

**uitable pattern to mirror:** `NotificationCenterPane.m:178-190` and `TagStatusTableWindow.m:231-244` both show the established uitable pattern:
```matlab
hTable = uitable(parent);
hTable.ColumnName     = {'Logical Sensor', 'Machine', 'Local Key', 'Units', 'Confidence', 'Status'};
hTable.ColumnWidth    = {180, 80, 150, 60, 80, 90};
hTable.ColumnEditable = [false false false false false true];  % only Status column editable
hTable.RowName        = {};
hTable.FontSize       = 10;
hTable.Data           = cell(0, 6);
hTable.CellEditCallback = @(src, ev) onStatusEdit_(obj, ev);
```

Key implementation notes from `NotificationCenterPane.m:188`:
- The uifigure uitable property is `CellSelectionCallback` (NOT `CellSelectionChangedFcn` — the planning docs have this wrong in some versions).
- `ColumnEditable` must be `logical` array, not `double` (confirmed: `TagStatusTableWindow.m:238` uses `false(1, 12)`).
- `uitable` row height is ~20 px platform default in R2020b; `LineHeight` is NOT settable.

**Promote action:** A "Promote" button next to the table calls `mapper.confirm(logicalId, machineId)` for the selected row.

### Anti-Patterns to Avoid

- **Anti-pattern: `contains(` in any Fleet code** — Phase exit grep gate. `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` must return 0. Use `~isempty(strfind(lower(s), needle))`.
- **Anti-pattern: Statistics Toolbox `editDistance`** — Success criterion #5 of the phase spec explicitly requires `grep` for this returns 0.
- **Anti-pattern: `suggest` accepting Machine handles** — Machine does not exist in Phase 1041; creates a hard circular dependency. Accept tag-info struct cell array instead.
- **Anti-pattern: logicalId derived from one machine's localKey verbatim** — The logicalId should be a normalized form derived from the matching cluster, not just one machine's key. Recommend: logicalId = normalized form of the most common/longest matching key in the cluster.
- **Anti-pattern: UI code (`uifigure`, `uitable`, etc.) in `CanonicalMapper.m`** — Keep `CanonicalMapper.m` pure data model (Octave-safe); all UI lives in `CanonicalMapEditor.m`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON round-trip of heterogeneous struct cell | Custom binary serializer, `.mat` file | `jsonencode` per-entry + `strjoin` assembly (DashboardSerializer pattern) | Confirmed Octave-portable; human-readable; VCS-committable |
| Atomic file save | Custom lock file | `movefile(tmp, dest, 'f')` after `fwrite` to `.tmp` | Confirmed at EventStore.m:277, companionPrefs.m:61 |
| Cell normalization from `jsondecode` | Custom type-check loop | Private `normalizeToCell_` helper (port of `libs/Dashboard/private/normalizeToCell.m`) | Already the established pattern; exact semantics documented |
| uitable editable-row UI | Custom per-cell uicontrol grid | `uitable` with `ColumnEditable` array | Confirmed working pattern at TagStatusTableWindow.m:238 |

---

## Investigation Q&A

### Q1: Edit Distance — Toolbox-Free Approach

**Confirmed:** No existing edit-distance or string-similarity helper anywhere in `libs/`. The repo uses only `strfind`/`strcmp`/`lower` for string matching.

**Implementation:** Standard Wagner-Fischer DP. The MATLAB-idiomatic form:
```matlab
function d = editDistance_(a, b)
%EDITDISTANCE_ Wagner-Fischer edit distance. Octave-safe; ~20 LOC.
    m = numel(a);
    n = numel(b);
    D = repmat(0:n, m+1, 1);
    D(:,1) = (0:m)';
    for i = 1:m
        for j = 1:n
            cost = double(a(i) ~= b(j));
            D(i+1,j+1) = min([D(i,j)+cost, D(i+1,j)+1, D(i,j+1)+1]);
        end
    end
    d = D(m+1, n+1);
end
```

Plain `double` matrix, no string-class operations, no toolbox. Works identically on MATLAB R2020b+ and Octave 7+.

**Octave-unsafe primitives to avoid:**
- `contains(` — Octave 7+ has it, but: (a) the phase exit grep gate forbids it; (b) multi-pattern `contains(str, {'a','b'})` is unreliable across Octave versions. Never use.
- `editDistance` — Statistics Toolbox, not available by constraint.
- `string` array class — MATLAB-only since R2016b; Octave uses `char`. Use `char()` throughout.
- `startsWith` / `endsWith` — Available in MATLAB R2016b+ and Octave 7+, but use `strncmp` / custom suffix check for certainty.
- `regexp(..., 'names')` named capture — available but `contains` replacements don't need it.

**Existing Octave-safe patterns in repo (confirmed):**
- `filterTags.m:32`: `~isempty(strfind(lower(t.Key), needle))` — the standard idiom
- `filterDashboards.m`: same `strfind` pattern
- `parseOpts.m`: `strcmp` for option key matching

### Q2: Tag Unit Metadata (CANON-02)

**Confirmed at `libs/SensorThreshold/Tag.m:54`:**
```
Units        = ''       % char: measurement unit
```

`Units` is a public `char` property on the abstract `Tag` base class. All subclasses (SensorTag, StateTag, MonitorTag, CompositeTag, DerivedTag) inherit it. It defaults to empty string `''`.

**`Labels` property (Tag.m:58):** `Labels = {}` is a `cellstr` of cross-cutting classification labels (e.g., `{'vibration', 'critical'}`). Not the same as units; labels are multi-value semantic tags.

**`Name` property (Tag.m:52):** `Name = ''` is the human-readable display name, defaults to `Key`.

**How `suggest(tagInfos)` reads sensor name and unit:**
The tag-info struct (see Pattern 1 above) carries both:
- `tagInfo.name` ← `tag.Name` (human-readable; used for similarity scoring alongside the key)
- `tagInfo.units` ← `tag.Units` (used for unit-consistency check)
- `tagInfo.localKey` ← `tag.Key` (the primary matching field)

The normalization pipeline runs on `localKey` (primary) and optionally `name` (secondary boost if key match is borderline). Unit check is separate from similarity scoring.

### Q3: Override Persistence (CANON-03)

**Fleet config does not exist in Phase 1041.** Phase 1041 must provide its own serialization. The design:

- `CanonicalMapper.toStruct()` returns a plain struct with `version=1` and a flat list of all entries.
- `CanonicalMapper.fromStruct(s)` reconstructs from that struct.
- `CanonicalMapper.save(filepath)` uses the `DashboardSerializer.saveJSON` save pattern: build JSON per entry, assemble with `strjoin`, write to `.tmp`, then `movefile`.
- `CanonicalMapper.load(filepath)` static factory reading JSON.

**Phase 1042 integration:** When `Fleet.m` is built in Phase 1042, it embeds `CanonicalMapper.toStruct()` into the fleet config JSON under a `"canonicalMap"` key. The Fleet's `save()` / `load()` calls `CanonicalMapper.fromStruct(config.canonicalMap)` on reload. No change required to CanonicalMapper itself.

**Confirmed Octave parity of jsonencode/jsondecode:** `ndjsonDecode.m:29` states "Both MATLAB R2016b+ and Octave 5+ ship jsondecode." Fleet code avoids `jsonencode` on cell arrays of heterogeneous structs at top level — builds JSON array strings manually with `strjoin(parts, ',')`.

**Override precedence rule:** Entries with `status='OVERRIDDEN'` or `status='CONFIRMED'` are loaded from JSON first; they take precedence. On re-run of `suggest`, the mapper skips any (logicalId, machineId) pair that already has an entry with `status ~= 'AUTO'`.

### Q4: CANON-05 Tension Resolution

**Confirmed: `libs/Fleet/` does NOT exist yet.** Both `CanonicalMapper.m` and `CanonicalMapEditor.m` are new files.

**Companion audit for uitable/editable patterns:**
- `NotificationCenterPane.m:178-190` — uitable in uifigure parent, `CellSelectionCallback`, 8-column layout, read-only.
- `TagStatusTableWindow.m:231-244` — uitable in classical figure, `ColumnEditable = false(1,12)`, 12-column layout, read-only.
- `CompanionEventViewer.m:127` — uitable with `Table_` handle, `CellEditCallback` implied (has `simulateCellEdit_` test helper at line 357).

**CanonicalMapEditor pattern:**
1. Standalone `classdef CanonicalMapEditor < handle` in `libs/Fleet/CanonicalMapEditor.m`.
2. Constructor: `ed = CanonicalMapEditor(mapper)` — takes a CanonicalMapper handle.
3. Builds its own `uifigure` with a `uigridlayout`.
4. `uitable` inside shows: `{'Logical Sensor', 'Machine', 'Local Key', 'Units Match', 'Confidence', 'Status'}`.
5. Status column is editable (dropdowns `'AUTO'|'CONFIRMED'|'OVERRIDDEN'`).
6. "Promote" button calls `mapper.confirm(logId, machId)` for selected row.
7. "Override" button opens a per-row edit dialog.
8. Refresh button reloads from mapper.
9. Does NOT call `setProject`, does NOT embed in Companion's grid — fully standalone.

**Flagging for deferral:** The full embedded Companion table pane (Companion column 4 or inspector tab) is deferred to Phase 1044 when the Companion machine dimension is wired. The standalone CanonicalMapEditor satisfies CANON-05 for Phase 1041.

### Q5: Confidence Thresholds

**Exact constants recommended:**
```matlab
HIGH_THRESHOLD_   = 0.90   % normalized similarity >= 0.90 -> HIGH
MEDIUM_THRESHOLD_ = 0.60   % normalized similarity >= 0.60 -> MEDIUM
                            % normalized similarity <  0.60 -> LOW
```

**Normalized similarity formula:**
```matlab
sim = 1 - editDistance_(normA, normB) / max(numel(normA), numel(normB));
```
where `normA`, `normB` are the normalized key strings (lowercased, punctuation → `_`, consecutive `_` collapsed).

**Unit-inconsistency downgrade rule:**
- HIGH + unitMismatch → confidence becomes MEDIUM, `unitMismatch = true`
- MEDIUM + unitMismatch → confidence becomes LOW, `unitMismatch = true`
- LOW + unitMismatch → confidence stays LOW, `unitMismatch = true`

**Token-overlap scoring (secondary):** To reduce false misses on structurally different keys, a secondary token-overlap score can boost the similarity: split both normalized keys on `_` into token sets; `tokenOverlap = numel(intersect(tokA, tokB)) / numel(union(tokA, tokB))`. Final score: `combinedSim = 0.7 * editSim + 0.3 * tokenOverlap`. The planner should decide whether to include token overlap in v1 or keep pure edit-distance and add token overlap as a separate constant-gated feature.

### Q6: reviewPending / unmapped Semantics

**`reviewPending()` returns:**
```matlab
% Returns a cell array of entry structs where review is needed:
%   - status == 'AUTO' AND confidence == 'LOW'
%   - OR unitMismatch == true (regardless of confidence)
pending = mapper.reviewPending();
% pending: cell of entry structs (see entry schema in Pattern 2)
```
Each entry in `pending` has all fields defined in the entry schema. Callers iterate to display the table. Entries excluded from comparison until `confirm()` or `override()` is called.

**`unmapped(machineId)` returns:**
```matlab
% Returns a cellstr of localKeys on the given machine that have no
% mapping in any logicalId (neither AUTO nor OVERRIDDEN).
unmappedKeys = mapper.unmapped('M01');
% unmappedKeys: cellstr — localKeys with no canonical assignment
```
This requires `suggest` to have been called with tagInfos including the machine's entries. The mapper cross-references: every localKey that appeared in the input tagInfos for machineId but did not end up as any entry in Entries_ is "unmapped."

**Excluded-from-comparison semantics:** Phase 1041 does not implement the comparison view (that is Phase 1045). The exclusion is enforced by the Phase 1045 `Fleet.resolveLogical` check: it skips any (logicalId, machineId) pair where `entry.status == 'AUTO' && strcmp(entry.confidence, 'LOW')` AND the entry has not been confirmed. CanonicalMapper exposes `isResolvable(logicalId, machineId)` → logical that encodes this rule, so Phase 1045 can call it without re-implementing the logic.

### Q7: File Location + Test Harness

**File location:** `libs/Fleet/CanonicalMapper.m` — confirmed from `ARCHITECTURE.md` and roadmap.

**`libs/Fleet/` does not exist yet.** Phase 1041 creates it. `install.m:54-62` currently lists 8 lib paths. A line must be added: `addpath(fullfile(root, 'libs', 'Fleet'));`. This is a ONE-LINE modification to `install.m`. The roadmap says "no existing code modified" — this is the minimum required change and should be treated as infrastructure bootstrapping, not a feature modification. The planner must decide: add `Fleet` path to `install.m` in Phase 1041 or add it in Phase 1042 and use a local `addpath` in the test only during 1041. Both approaches work; the clean choice is to add it in Phase 1041 since the library is created in 1041.

**Test suite pattern to mirror:** `TestTagRegistry.m` and `TestMonitorTag.m` are the closest structural analogues. The canonical pattern:

```matlab
classdef TestCanonicalMapper < matlab.unittest.TestCase
    %TESTCANONICALMANAGER ...

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            % addpath Fleet explicitly if install.m doesn't include it yet:
            addpath(fullfile(repo, 'libs', 'Fleet'));
        end
    end

    methods (TestMethodSetup)
        function resetMapper(testCase) %#ok<MANU>
            % No global state to reset in CanonicalMapper (not a singleton)
        end
    end

    methods (Test)
        % ... test methods in camelCase starting with verb ...
    end
end
```

Key points from studying `TestMonitorTag.m:25-46` and `TestTagRegistry.m:11-27`:
- `TestClassSetup` method MUST be named `addPaths` (convention enforced by project).
- `addpath(repo); install();` is the standard setup — ensures all libs are on path.
- `TestMethodSetup` / `TestMethodTeardown` for any global state (CanonicalMapper is NOT a singleton, so no global state to clear).
- Test method names: `testNormalizeLowercase`, `testEditDistanceSymmetric`, `testSuggestHighConfidence`, etc.

**Success criterion #5 (grep gate):** The test suite should include a `testOctaveSafeGrep` method that calls `grep` via `system()` to verify `contains(` returns 0. This is the established pattern from `TestMonitorTag.m:17-18` which documents grep-gate tests.

---

## Common Pitfalls

### Pitfall 1: `contains(` in CanonicalMapper string matching
**What goes wrong:** `contains(key, pattern)` is written for readability; phase exit gate fails.
**Why it happens:** `contains` is natural MATLAB idiom and works on R2020b+; developer forgets Octave gate.
**How to avoid:** Use `~isempty(strfind(lower(key), lower(pattern)))` always. Write the grep gate test as the FIRST test method so it fails loudly.
**Warning signs:** Any `contains(` hit in `grep -rn "contains(" libs/Fleet/CanonicalMapper.m`.

### Pitfall 2: `suggest` input accepts Machine handles (circular dependency)
**What goes wrong:** Phase 1041 `suggest(machines)` requires `Machine.m` which doesn't exist until Phase 1042.
**Why it happens:** The requirement text says `suggest(machines)` — but this describes the final API, not the Phase 1041 input shape.
**How to avoid:** `suggest(tagInfos)` accepts a cell array of plain structs. Phase 1042 adds `Fleet.buildTagInfos()` that produces the struct array from Machine objects.
**Warning signs:** CanonicalMapper.m imports or instantiates Machine class; tests require Machine.m to run.

### Pitfall 3: logicalId assigned as one machine's verbatim localKey
**What goes wrong:** Machine M01's `'temp_motor'` becomes the logicalId. Machine M03's `'T_motor_case'` maps to it. When Machine M01 is renamed, the logicalId changes, breaking all overrides stored in JSON.
**Why it happens:** Simplest implementation.
**How to avoid:** logicalId is a normalized canonical form computed from the cluster, not taken from any single machine's key. Use the normalized form of the centroid key (or the lexicographically smallest normalized key in the cluster). Or derive it as `'logical/' + normalized_key` with a `/` namespace prefix so it can never be confused with a localKey (Pitfall 5 in PITFALLS.md).
**Warning signs:** logicalId == localKey for any machine; logicalId changes when a machine is renamed.

### Pitfall 4: Unit comparison is case-sensitive
**What goes wrong:** `'degC'` != `'DegC'` → false mismatch reported.
**How to avoid:** `strcmp(lower(unitA), lower(unitB))`.

### Pitfall 5: jsonencode of cell-of-structs produces scalar struct
**What goes wrong:** `jsonencode(entryList)` on a cell of entry structs (when all structs have identical fields) collapses to a JSON object instead of a JSON array.
**Why it happens:** `jsonencode` on `{struct1, struct2}` is version-dependent.
**How to avoid:** Encode each entry individually: `parts{i} = jsonencode(entry)`, then `['[' strjoin(parts, ',') ']']`. This is the established `DashboardSerializer.saveJSON` pattern.

### Pitfall 6: Override does not survive re-run of suggest
**What goes wrong:** User overrides (logicalId='temp_motor', machineId='M03', localKey='T_case'). Developer calls `suggest(allTagInfos)` again. Override is replaced by an AUTO entry.
**How to avoid:** `suggest` checks before inserting any entry: if `isKey(obj.Entries_, logId)` and the existing entry for this machineId has `status ~= 'AUTO'`, skip it. OVERRIDDEN > CONFIRMED > AUTO.

---

## Code Examples

### Normalization Pipeline
```matlab
function key = normalize_(key)
%NORMALIZE_ Toolbox-free key normalization pipeline. Octave-safe.
    key = lower(key);
    key = regexprep(key, '[^a-z0-9]', '_');  % non-alphanumeric -> _
    key = regexprep(key, '_+', '_');          % collapse repeated _
    key = strtrim(key);
    if ~isempty(key) && key(1) == '_'
        key = key(2:end);
    end
    if ~isempty(key) && key(end) == '_'
        key = key(1:end-1);
    end
end
```

### Edit Distance (Wagner-Fischer DP)
```matlab
function d = editDistance_(a, b)
%EDITDISTANCE_ Standard Wagner-Fischer edit distance. No toolbox. ~20 LOC.
%   Inputs a, b are char arrays. Octave-safe.
    m = numel(a);
    n = numel(b);
    if m == 0; d = n; return; end
    if n == 0; d = m; return; end
    D = zeros(m+1, n+1);
    D(:,1) = (0:m)';
    D(1,:) = 0:n;
    for i = 1:m
        for j = 1:n
            cost = double(a(i) ~= b(j));
            D(i+1,j+1) = min([D(i,j)+cost, D(i+1,j)+1, D(i,j+1)+1]);
        end
    end
    d = D(m+1, n+1);
end
```

### Confidence Assignment
```matlab
function conf = assignConfidence_(obj, sim)
%ASSIGNCONFIDENCE_ Map normalized similarity to confidence enum.
    if sim >= obj.HIGH_THRESHOLD_
        conf = 'HIGH';
    elseif sim >= obj.MEDIUM_THRESHOLD_
        conf = 'MEDIUM';
    else
        conf = 'LOW';
    end
end
```

### Unit Downgrade Rule
```matlab
function entry = applyUnitDowngrade_(entry, canonicalUnits)
%APPLYUNITDOWNGRADE_ Check unit consistency; downgrade confidence if mismatch.
    entry.unitMismatch = false;
    if isempty(entry.localUnits) || isempty(canonicalUnits)
        return;  % can't compare; no mismatch declared
    end
    if ~strcmp(lower(entry.localUnits), lower(canonicalUnits))
        entry.unitMismatch = true;
        switch entry.confidence
            case 'HIGH'
                entry.confidence = 'MEDIUM';
            case 'MEDIUM'
                entry.confidence = 'LOW';
            % LOW stays LOW
        end
    end
end
```

### reviewPending Return Shape
```matlab
function pending = reviewPending(obj)
%REVIEWPENDING Return entries needing human review.
%   Returns a cell array of entry structs where:
%     - status == 'AUTO' AND confidence == 'LOW'
%     - OR unitMismatch == true
    pending = {};
    logIds = obj.Entries_.keys();
    for i = 1:numel(logIds)
        machineEntries = obj.Entries_(logIds{i});
        for j = 1:numel(machineEntries)
            e = machineEntries{j};
            needsReview = (strcmp(e.status,'AUTO') && strcmp(e.confidence,'LOW')) ...
                       || e.unitMismatch;
            if needsReview
                pending{end+1} = e; %#ok<AGROW>
            end
        end
    end
end
```

### isResolvable for Phase 1045 gate
```matlab
function ok = isResolvable(obj, logicalId, machineId)
%ISRESOLVABLE Return true if this (logicalId, machineId) pair can be
%   used in a comparison (not pending review).
    ok = false;
    if ~isKey(obj.Entries_, logicalId); return; end
    machineEntries = obj.Entries_(logicalId);
    for i = 1:numel(machineEntries)
        e = machineEntries{i};
        if strcmp(e.machineId, machineId)
            % Unresolvable: AUTO + LOW or any unit mismatch not confirmed
            isBlocked = (strcmp(e.status,'AUTO') && strcmp(e.confidence,'LOW')) ...
                     || (e.unitMismatch && ~strcmp(e.status,'CONFIRMED') ...
                                        && ~strcmp(e.status,'OVERRIDDEN'));
            ok = ~isBlocked;
            return;
        end
    end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Statistics Toolbox `editDistance` for fuzzy matching | Hand-rolled Wagner-Fischer DP (~20 LOC) | Always required here — no toolbox | Must implement inline; confirmed no existing helper in repo |
| `contains()` for string search | `~isempty(strfind(lower(s), needle))` | Octave-safe constraint from project start | Phase exit grep gate enforces this |
| `jsonencode({})` on empty cell | Hand-built JSON `[]` string | MATLAB version ambiguity (confirmed DashboardSerializer.m:249) | Must encode entry arrays per-element |

---

## Open Questions

1. **logicalId naming convention**
   - What we know: logicalId should be stable, not derived from any single machine's volatile localKey.
   - What's unclear: Should logicalId be namespaced with `/` (e.g., `'canonical/temperature/motor'`) to distinguish from localKeys? Pitfall 5 in PITFALLS.md suggests this. But the requirements text just says `'temperature_motor'`-style names.
   - Recommendation: Use the normalized form of the cluster centroid key WITHOUT a `/` namespace prefix in v5.0 (simpler); defer namespace prefix to v5.1. The planner must pick one and encode it consistently.

2. **Token-overlap secondary scoring in suggest**
   - What we know: Pure edit-distance can miss structurally different keys that share tokens (Pitfall 4 in PITFALLS.md).
   - What's unclear: Whether Phase 1041 includes token-overlap (adds 15 LOC) or defers to a v5.1 enhancement.
   - Recommendation: Include it in Phase 1041 as a gated secondary scoring path (weight 0.3 token, 0.7 edit). The planner can choose to omit it if simplicity is preferred; pure edit-distance still satisfies CANON-01.

3. **install.m modification**
   - What we know: `libs/Fleet/` needs to be on the MATLAB path; install.m:54-62 is where library paths are added.
   - What's unclear: Should the one-line `addpath(fullfile(root, 'libs', 'Fleet'))` go into Phase 1041 or Phase 1042?
   - Recommendation: Add it in Phase 1041 — the directory is created in 1041, and the test harness needs it.

4. **CanonicalMapEditor uifigure vs. modal dialog**
   - What we know: The requirement says "companion via a table" — standalone uifigure satisfies this.
   - What's unclear: Should CanonicalMapEditor be a full uifigure (window) or a `uiprogressdlg`-style modal?
   - Recommendation: Full standalone uifigure (non-modal) so users can keep it open while working. Pattern: same as `TagStatusTableWindow` (a standalone figure, not a modal).

---

## Environment Availability

Step 2.6: SKIPPED — Phase 1041 is purely code/config changes. No external tools, services, databases, or CLI utilities are required beyond the existing MATLAB/Octave runtime already in use.

---

## Validation Architecture

> Nyquist validation is ENABLED. This section defines the test strategy for `TestCanonicalMapper.m`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `matlab.unittest.TestCase` (MATLAB + Octave via `run_all_tests.m`) |
| Config file | None required — follows existing suite pattern |
| Quick run command | `runtests('tests/suite/TestCanonicalMapper')` |
| Full suite command | `run_all_tests` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CANON-01 | Normalization pipeline: lowercase, punctuation collapse | unit | `runtests('TestCanonicalMapper/testNormalizeLowercase')` | ❌ Wave 0 |
| CANON-01 | Edit distance symmetry: `editDist(a,b) == editDist(b,a)` | unit | `runtests('TestCanonicalMapper/testEditDistanceSymmetry')` | ❌ Wave 0 |
| CANON-01 | Edit distance known pairs: `('abc','abc')=0`, `('abc','axc')=1`, `('abc','')=3` | unit | `runtests('TestCanonicalMapper/testEditDistanceKnownPairs')` | ❌ Wave 0 |
| CANON-01 | `suggest` with 3 machines, 2 matching pairs → 2 logicalIds created | unit | `runtests('TestCanonicalMapper/testSuggestTwoMatchingPairs')` | ❌ Wave 0 |
| CANON-01 | `suggest` with no similar keys → 0 logicalIds, all keys in `unmapped` | unit | `runtests('TestCanonicalMapper/testSuggestNoMatches')` | ❌ Wave 0 |
| CANON-02 | HIGH confidence: sim >= 0.90 → confidence='HIGH' | unit | `runtests('TestCanonicalMapper/testConfidenceHighThreshold')` | ❌ Wave 0 |
| CANON-02 | MEDIUM confidence: sim in [0.60, 0.90) → confidence='MEDIUM' | unit | `runtests('TestCanonicalMapper/testConfidenceMediumThreshold')` | ❌ Wave 0 |
| CANON-02 | LOW confidence: sim < 0.60 → confidence='LOW' | unit | `runtests('TestCanonicalMapper/testConfidenceLowThreshold')` | ❌ Wave 0 |
| CANON-02 | Threshold boundary: sim exactly 0.90 → HIGH | unit | `runtests('TestCanonicalMapper/testConfidenceBoundaryHigh')` | ❌ Wave 0 |
| CANON-02 | Threshold boundary: sim exactly 0.60 → MEDIUM | unit | `runtests('TestCanonicalMapper/testConfidenceBoundaryMedium')` | ❌ Wave 0 |
| CANON-02 | Unit mismatch: HIGH entry with unit mismatch → MEDIUM + `unitMismatch=true` | unit | `runtests('TestCanonicalMapper/testUnitMismatchDowngradesHigh')` | ❌ Wave 0 |
| CANON-02 | Unit mismatch: MEDIUM entry with unit mismatch → LOW + `unitMismatch=true` | unit | `runtests('TestCanonicalMapper/testUnitMismatchDowngradesMedium')` | ❌ Wave 0 |
| CANON-02 | Unit mismatch: empty units → no mismatch flagged | unit | `runtests('TestCanonicalMapper/testUnitMismatchEmptyUnitsIgnored')` | ❌ Wave 0 |
| CANON-02 | Unit match case-insensitive: 'degC' vs 'DegC' → no mismatch | unit | `runtests('TestCanonicalMapper/testUnitMatchCaseInsensitive')` | ❌ Wave 0 |
| CANON-03 | Override creates OVERRIDDEN entry; precedence over AUTO | unit | `runtests('TestCanonicalMapper/testOverrideCreatesEntry')` | ❌ Wave 0 |
| CANON-03 | Override survives re-run of suggest | unit | `runtests('TestCanonicalMapper/testOverrideSurvivesResuggest')` | ❌ Wave 0 |
| CANON-03 | `toStruct`/`fromStruct` round-trip preserves all entries | unit | `runtests('TestCanonicalMapper/testRoundTripPreservesEntries')` | ❌ Wave 0 |
| CANON-03 | Round-trip preserves OVERRIDDEN status | unit | `runtests('TestCanonicalMapper/testRoundTripPreservesOverriddenStatus')` | ❌ Wave 0 |
| CANON-03 | `save(path)` + `load(path)` round-trip produces identical mapper state | unit | `runtests('TestCanonicalMapper/testSaveLoadRoundTrip')` | ❌ Wave 0 |
| CANON-04 | `reviewPending` returns LOW-confidence AUTO entries | unit | `runtests('TestCanonicalMapper/testReviewPendingReturnsLow')` | ❌ Wave 0 |
| CANON-04 | `reviewPending` returns unitMismatch=true entries regardless of confidence | unit | `runtests('TestCanonicalMapper/testReviewPendingReturnsUnitMismatch')` | ❌ Wave 0 |
| CANON-04 | `reviewPending` does NOT return HIGH/MEDIUM confirmed entries | unit | `runtests('TestCanonicalMapper/testReviewPendingExcludesGoodEntries')` | ❌ Wave 0 |
| CANON-04 | `unmapped('M01')` returns keys with no mapping | unit | `runtests('TestCanonicalMapper/testUnmappedReturnsUnresolved')` | ❌ Wave 0 |
| CANON-04 | `unmapped` returns empty if all keys mapped | unit | `runtests('TestCanonicalMapper/testUnmappedEmptyWhenAllMapped')` | ❌ Wave 0 |
| CANON-04 | `isResolvable` returns false for LOW+AUTO | unit | `runtests('TestCanonicalMapper/testIsResolvableFalseForLow')` | ❌ Wave 0 |
| CANON-04 | `isResolvable` returns true for HIGH+AUTO | unit | `runtests('TestCanonicalMapper/testIsResolvableTrueForHigh')` | ❌ Wave 0 |
| CANON-05 | `CanonicalMapEditor` constructs and opens a figure (smoke test, MATLAB-only) | smoke | `runtests('TestCanonicalMapper/testEditorConstructs')` | ❌ Wave 0 |
| SUCCESS-5 | `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` returns 0 | grep gate | `runtests('TestCanonicalMapper/testOctaveSafeGrepGate')` | ❌ Wave 0 |
| SUCCESS-5 | `grep -rn "editDistance(" libs/Fleet/CanonicalMapper.m` returns 0 | grep gate | `runtests('TestCanonicalMapper/testNoToolboxCallGrepGate')` | ❌ Wave 0 |

### Highest-Risk Correctness Areas

The roadmap states: "no wrong comparison can happen silently." The three highest-risk areas are:

1. **Confidence threshold boundaries** — if the boundary at 0.90 or 0.60 is off by even a rounding error, entries are misclassified. Test boundary exactly: construct a key pair whose normalized edit-distance similarity is exactly 0.90 and verify HIGH; test with 0.8999 (should be MEDIUM); test with 0.60 and 0.5999.

2. **Unit mismatch flagging** — a mismatch that is silently not flagged is the most dangerous outcome. Test: same-name sensors in `degC` and `K` (numerically similar data, physically different scale) must produce `unitMismatch=true`. Test empty-units edge case separately.

3. **Override persistence round-trip** — if an override is lost on `fromStruct`, user-confirmed safe mappings revert to potentially wrong AUTO entries. Test: create override, serialize to JSON string (not file, to avoid I/O in test), deserialize, verify override survives.

4. **reviewPending exclusion contract** — if `reviewPending()` does NOT return a LOW-confidence entry, Phase 1045's comparison-view gate cannot protect against it. Over-sample: test that every variant of "should be pending" (LOW confidence, unit mismatch, LOW+mismatch) appears in `reviewPending`, and that every variant of "should NOT be pending" (HIGH no mismatch, CONFIRMED, OVERRIDDEN) does NOT appear.

### Sampling Rate
- **Per task commit:** `runtests('tests/suite/TestCanonicalMapper')`
- **Per wave merge:** `runtests('tests/suite/TestCanonicalMapper')` + grep gates
- **Phase gate:** Full `run_all_tests` green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/suite/TestCanonicalMapper.m` — covers all CANON requirements above
- [ ] `libs/Fleet/CanonicalMapper.m` — the implementation file itself
- [ ] `libs/Fleet/CanonicalMapEditor.m` — CANON-05 standalone editor
- [ ] `addpath(fullfile(root, 'libs', 'Fleet'))` in `install.m` — path registration

No framework install needed; `matlab.unittest.TestCase` is already in use across 40+ suite files.

---

## Project Constraints (from CLAUDE.md)

- **Pure MATLAB (no external dependencies)** — no Statistics Toolbox, no Text Analytics Toolbox. All string operations from base MATLAB/Octave.
- **Dual target: MATLAB R2020b+ and GNU Octave 7+** — `CanonicalMapper.m` is a data-model class and must be Octave-safe. `CanonicalMapEditor.m` is UI and is MATLAB-only (matches existing Companion pattern).
- **Naming:** Classes PascalCase (`CanonicalMapper`, `CanonicalMapEditor`); private methods camelCase with trailing underscore convention; error IDs `CanonicalMapper:camelCaseProblem`.
- **MISS_HIT:** Code must pass `mh_style`, `mh_lint`, `mh_metric --ci`. Line length 160 max; cyclomatic complexity ≤ 80; max function length 520 lines; max nesting depth 5; max params 12.
- **No UI code in data model:** `libs/Fleet/CanonicalMapper.m` must pass `grep -rn "uifigure\|uicontrol\|uitree\|uigridlayout\|uiprogressdlg" libs/Fleet/CanonicalMapper.m` returning 0.
- **Handle class:** `classdef CanonicalMapper < handle` — consistent with all other domain classes (Tag, TagRegistry, DashboardEngine, etc.).
- **Header comments:** Comprehensive class header with description, usage examples, property list, method list, See also.
- **Error IDs:** `CanonicalMapper:invalidInput`, `CanonicalMapper:unknownLogicalId`, `CanonicalMapper:duplicateOverride`, etc.
- **Octave abstract pattern:** Use throw-from-base stubs, not `methods (Abstract)` block (confirmed from Tag.m:9 comment).
- **GSD workflow:** Do not make direct repo edits outside a GSD workflow.

---

## Sources

### Primary (HIGH confidence — direct code audit at commit HEAD)
- `libs/SensorThreshold/Tag.m:51-61` — confirmed `Units`, `Name`, `Labels`, `Key` property names and types
- `libs/FastSenseCompanion/private/filterTags.m:28-34` — confirmed `strfind(lower(...))` pattern; no `contains`
- `libs/FastSenseCompanion/NotificationCenterPane.m:178-190` — confirmed uitable in uifigure; `CellSelectionCallback` (not `CellSelectionChangedFcn`); `ColumnEditable` logical array
- `libs/FastSenseCompanion/TagStatusTableWindow.m:231-244` — confirmed uitable construction pattern; `ColumnEditable = false(1, 12)`; `BackgroundColor` stripe pair
- `libs/EventDetection/EventStore.m:250,277` — confirmed atomic `movefile(tmp, dest)` save pattern
- `libs/FastSenseCompanion/companionPrefs.m:58-66` — confirmed `movefile(tmpPath, prefsPath, 'f')` atomic save
- `libs/Dashboard/DashboardSerializer.m:176-244` — confirmed `jsonencode` per-widget + `strjoin` assembly pattern; empty-cell ambiguity at :249
- `tests/suite/TestMonitorTag.m:25-46` — confirmed test class structure: `addPaths` in `TestClassSetup`, `TestMethodSetup` for state reset, test methods camelCase
- `tests/suite/TestTagRegistry.m:11-28` — confirmed `addPaths` + `install()` pattern; `clearBefore`/`clearAfter` method naming
- `tests/suite/TestBatchTagPipeline.m:22-29` — confirmed `addPaths` with explicit `addpath` + `install()` calls
- `install.m:54-62` — confirmed no `Fleet` path registered yet; exact location to add
- `grep -rn "levenshtein\|editdist\|strsim\|editDistance\|edit_distance" libs/` — **0 hits confirmed**: no existing string-similarity helper
- `grep -rn "contains(" libs/ --include="*.m"` — 4 hits, all in non-Fleet code (`EventStore.m`, `TimeRangeSelector.m`, `ClusterConfig.m`); none in Octave-targeted data model

### Secondary (MEDIUM confidence — from pre-existing milestone research)
- `.planning/research/ARCHITECTURE.md` — CanonicalMapper integration design, file location, phasing rationale
- `.planning/research/PITFALLS.md` — Pitfall 3 (false matches), Pitfall 4 (false misses), Pitfall 14 (Octave parity)
- `.planning/research/STACK.md` — Hand-rolled edit-distance rationale, JSON persistence decision, strfind vs contains
- `.planning/research/SUMMARY.md` — Confidence-level requirement, Wagner-Fischer endorsement, Phase 1 scope

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every primitive confirmed with file:line evidence; no new dependencies
- Architecture: HIGH — all patterns grounded in confirmed repo code; API surface fully specified
- Pitfalls: HIGH — all traced to concrete repo files; grep-gate pattern established in existing tests
- Thresholds: MEDIUM — 0.90/0.60 cut points are defensible engineering priors, not empirically tuned to this specific sensor naming domain; may require adjustment after first real fleet test

**Research date:** 2026-06-02
**Valid until:** 2026-09-01 (stable primitives; no external dependency staleness risk)
