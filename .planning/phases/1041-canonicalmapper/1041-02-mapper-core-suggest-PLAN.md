---
phase: 1041-canonicalmapper
plan: 02
type: tdd
wave: 1
depends_on: ["1041-01"]
files_modified:
  - libs/Fleet/CanonicalMapper.m
autonomous: true
requirements: [CANON-01, CANON-02]
must_haves:
  truths:
    - "User can call mapper.suggest(tagInfos) and receive a logicalId -> {machineId -> localKey} map built from toolbox-free edit-distance similarity"
    - "Every auto-suggested mapping entry carries a confidence level HIGH/MEDIUM/LOW from the locked thresholds (>=0.90 HIGH, >=0.60 MEDIUM, else LOW)"
    - "Every entry whose units are inconsistent is flagged unitMismatch=true and its confidence is capped down one level (HIGH->MEDIUM, MEDIUM->LOW)"
    - "CanonicalMapper.m calls no contains() and no Statistics Toolbox editDistance() — Octave-safe"
  artifacts:
    - path: "libs/Fleet/CanonicalMapper.m"
      provides: "Pure data-model class: normalize_, editDistance_, suggest, confidence assignment, unit-mismatch downgrade"
      contains: "classdef CanonicalMapper < handle"
      min_lines: 150
  key_links:
    - from: "libs/Fleet/CanonicalMapper.m"
      to: "Entries_ containers.Map"
      via: "suggest populates Entries_(logicalId) = {entry,...}"
      pattern: "Entries_\\("
    - from: "CanonicalMapper.suggest"
      to: "editDistance_ / normalize_"
      via: "similarity scoring on normalized keys"
      pattern: "editDistance_\\(|normalize_\\("
---

<objective>
Implement the CanonicalMapper data-model CORE in `libs/Fleet/CanonicalMapper.m`: the toolbox-free normalization pipeline, hand-rolled Wagner-Fischer edit distance, the `suggest(tagInfos)` clustering pipeline, confidence assignment against the locked 0.90/0.60 thresholds, and the unit-mismatch flag + confidence downgrade rule. This satisfies CANON-01, CANON-02, and the SUCCESS-5 Octave-safety grep gates.

Purpose: This is the compute heart of "no wrong comparison can happen silently" — confidence levels and unit-mismatch flagging are derived here. It is a pure data model (no UI), Octave-safe, and independently testable without the not-yet-built Machine class (input is a cell of tag-info structs).
Output: `libs/Fleet/CanonicalMapper.m` (class scaffold + normalize_/editDistance_/assignConfidence_/applyUnitDowngrade_/suggest + the Entries_ store + property constants).

This is a TDD plan: the 16 CANON-01/02 + 2 grep-gate test methods in TestCanonicalMapper.m (written RED in Plan 01) are the GREEN target. Implement against them.
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
<!-- The test contract this plan turns GREEN lives in tests/suite/TestCanonicalMapper.m (Plan 01). -->
<!-- Read that file to see exact assertions. Signatures and constants below are LOCKED by RESEARCH.md. -->

Normalization pipeline (RESEARCH.md § Code Examples — Octave-safe, copy verbatim):
```matlab
function key = normalize_(key)
    key = lower(key);
    key = regexprep(key, '[^a-z0-9]', '_');  % non-alphanumeric -> _
    key = regexprep(key, '_+', '_');          % collapse repeated _
    key = strtrim(key);
    if ~isempty(key) && key(1) == '_';   key = key(2:end);   end
    if ~isempty(key) && key(end) == '_'; key = key(1:end-1); end
end
```

Edit distance (RESEARCH.md § Code Examples — Wagner-Fischer, NO toolbox, name MUST end in `_`):
```matlab
function d = editDistance_(a, b)
    m = numel(a); n = numel(b);
    if m == 0; d = n; return; end
    if n == 0; d = m; return; end
    D = zeros(m+1, n+1);
    D(:,1) = (0:m)'; D(1,:) = 0:n;
    for i = 1:m
        for j = 1:n
            cost = double(a(i) ~= b(j));
            D(i+1,j+1) = min([D(i,j)+cost, D(i+1,j)+1, D(i,j+1)+1]);
        end
    end
    d = D(m+1, n+1);
end
```

Similarity formula (LOCKED):
```matlab
sim = 1 - editDistance_(normA, normB) / max(numel(normA), numel(normB));
```

Confidence thresholds (LOCKED constants — declare as Constant private properties):
```matlab
HIGH_THRESHOLD_   = 0.90   % sim >= 0.90 -> HIGH
MEDIUM_THRESHOLD_ = 0.60   % sim >= 0.60 -> MEDIUM ; sim < 0.60 -> LOW
```

Unit-mismatch downgrade rule (LOCKED — RESEARCH.md Pattern 3 / § Code Examples):
- localUnits or canonicalUnits empty -> unitMismatch=false, no downgrade (no info)
- ~strcmp(lower(localUnits), lower(canonicalUnits)) -> unitMismatch=true AND: HIGH->MEDIUM, MEDIUM->LOW, LOW->LOW
- canonical unit for a logical sensor = units of the first HIGH-confidence match in the cluster (or '')

Entry struct schema (each value in Entries_(logicalId) cell):
```matlab
entry.logicalId entry.machineId entry.localKey entry.localName entry.localUnits
entry.similarity entry.confidence entry.status entry.unitMismatch
```

tagInfos input contract (LOCKED — RESEARCH.md Pattern 1; NOT Machine handles):
```matlab
tagInfos{k} = struct('machineId',char,'localKey',char,'name',char,'units',char)
```

logicalId naming (LOCKED — RESEARCH.md Open Question #1 default, UI-SPEC Open Decisions): normalized cluster-centroid form, NO '/' namespace prefix. Use the normalized form of the longest (or lexicographically smallest on tie) localKey in the cluster. logicalId MUST NOT equal any single machine's raw localKey verbatim unless that key is already normalized (Pitfall 3).

Reference implementations to mirror:
- libs/SensorThreshold/Tag.m:54 — `Units = ''` property type (char, may be empty)
- libs/FastSenseCompanion/private/filterTags.m:32-34 — the `~isempty(strfind(lower(...)))` Octave-safe idiom (NEVER contains())
- libs/SensorThreshold/Tag.m — handle-class header-comment style, error-ID convention `CanonicalMapper:problem`
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: CanonicalMapper class scaffold + normalize_ + editDistance_ (CANON-01 primitives)</name>
  <read_first>
    - tests/suite/TestCanonicalMapper.m (the testNormalizeLowercase, testEditDistanceSymmetry, testEditDistanceKnownPairs bodies — your GREEN target; and the two grep-gate tests so you know exactly what they scan for)
    - libs/SensorThreshold/Tag.m (lines 1-100 — handle-class header-comment style, properties block layout, error-ID convention, the Octave abstract-stub note at line 9)
    - .planning/phases/1041-canonicalmapper/1041-RESEARCH.md (§ Code Examples for normalize_ and editDistance_; § Project Constraints for MISS_HIT limits and header-comment requirements)
  </read_first>
  <behavior>
    - testEditDistanceKnownPairs: editDistance_('abc','abc')=0, ('abc','axc')=1, ('abc','')=3 (asserted via the similarity formula in the test).
    - testEditDistanceSymmetry: similarity for a pair is identical regardless of tagInfo order (distance is commutative).
    - testNormalizeLowercase: keys differing only by case/punctuation normalize to the same string (asserted via suggest clustering, or via a public normalize wrapper if you expose one).
    - The two grep gates (testOctaveSafeGrepGate, testNoToolboxCallGrepGate) must go GREEN the moment the file exists: NO `contains(` anywhere; the edit-distance helper MUST be named `editDistance_` (trailing underscore) so the `editDistance(` gate does not trip.
  </behavior>
  <action>
    Create `libs/Fleet/CanonicalMapper.m` as `classdef CanonicalMapper < handle`.

    1. CLASS HEADER (comprehensive, per CLAUDE.md convention): description ("Toolbox-free canonical sensor mapping with confidence levels and unit-consistency checking"), a Usage example block showing `m = CanonicalMapper(); m.suggest(tagInfos); m.reviewPending();`, a Properties list, a Methods list (suggest, override, confirm, reviewPending, unmapped, isResolvable, toStruct, fromStruct, save, load), and `% See also CanonicalMapEditor, Machine, Fleet`.

    2. PROPERTIES:
       ```matlab
       properties (SetAccess = private)
           Entries_   % containers.Map('KeyType','char','ValueType','any'); value = cell of entry structs
       end
       properties (Constant, Access = private)
           HIGH_THRESHOLD_   = 0.90
           MEDIUM_THRESHOLD_ = 0.60
       end
       ```
       Initialize `Entries_` in the constructor: `obj.Entries_ = containers.Map('KeyType','char','ValueType','any');`.

    3. CONSTRUCTOR `function obj = CanonicalMapper()` — no required args; initialize the map. (Forward note: Plan 03 adds save/load/toStruct/fromStruct; do not stub them as errors here — leave them unimplemented for Plan 03, OR add throwing stubs `error('CanonicalMapper:notImplemented',...)`. PREFER leaving them out entirely so Plan 03 adds them; the CANON-03/04 tests stay RED until Plan 03, which is the intended Nyquist progression.)

    4. PRIVATE HELPER `normalize_(key)` — copy VERBATIM from the interfaces block above (RESEARCH.md § Code Examples). Use `regexprep`/`lower`/`strtrim` only. NO contains/startsWith/endsWith/string.

    5. PRIVATE HELPER `editDistance_(a, b)` — copy VERBATIM from the interfaces block above. Plain double matrix, Wagner-Fischer. The name MUST be `editDistance_` with the trailing underscore (the no-toolbox grep gate scans for `editDistance(` without underscore).

    6. PRIVATE HELPER `sim = similarity_(obj, a, b)`:
       ```matlab
       na = obj.normalize_(a); nb = obj.normalize_(b);
       L = max(numel(na), numel(nb));
       if L == 0; sim = 1; return; end          % two empty keys are identical
       sim = 1 - obj.editDistance_(na, nb) / L;
       ```
       (normalize_ and editDistance_ may be local functions at the bottom of the file or private methods; if private methods, call as obj.normalize_(...). Decide and be consistent. RESEARCH.md shows them as standalone helpers — local functions in the same .m file is acceptable and matches DashboardSerializer's pattern. If you make them local functions, similarity_ calls them directly without obj.)

    7. Run the grep gates and the three CANON-01 distance/normalize tests. They must pass (grep gates) / the distance+normalize tests pass once suggest exists in Task 2 (testNormalizeLowercase and testEditDistanceSymmetry assert via suggest). If your test for editDistance asserts via similarity formula and suggest is not built yet, those specific tests stay RED until Task 2 — that is fine within this plan; the grep gates MUST be GREEN now.

    MISS_HIT: keep functions short (each helper well under the 520-line / complexity-80 limits — these are ~20 LOC each), lines <= 160 chars, nesting <= 5.
  </action>
  <verify>
    <automated>runtests('tests/suite/TestCanonicalMapper') — testOctaveSafeGrepGate and testNoToolboxCallGrepGate GREEN; testEditDistanceKnownPairs GREEN (if it asserts via the helper formula and does not require suggest). Run via mcp__matlab__run_matlab_test_file.</automated>
  </verify>
  <acceptance_criteria>
    - File exists: `ls libs/Fleet/CanonicalMapper.m` exits 0
    - `grep -c "classdef CanonicalMapper < handle" libs/Fleet/CanonicalMapper.m` returns `1`
    - Octave-safety gate (HARD): `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` returns `0` (zero lines)
    - No-toolbox gate (HARD): `grep -rn "editDistance(" libs/Fleet/CanonicalMapper.m` returns `0` (the private helper is `editDistance_(` with underscore, which must NOT match — confirm with `grep -c "editDistance_(" libs/Fleet/CanonicalMapper.m` returns >= 1)
    - No other Octave-unsafe primitives: `grep -rnE "startsWith\(|endsWith\(|\bstring\(" libs/Fleet/CanonicalMapper.m` returns `0`
    - normalize_ and editDistance_ are present: `grep -c "function .*normalize_" libs/Fleet/CanonicalMapper.m` >= 1 and `grep -c "function .*editDistance_" libs/Fleet/CanonicalMapper.m` >= 1
    - Entries_ initialized as containers.Map: `grep -c "containers.Map" libs/Fleet/CanonicalMapper.m` >= 1
    - `mcp__matlab__check_matlab_code` on libs/Fleet/CanonicalMapper.m reports no error-level diagnostics
    - `runtests('tests/suite/TestCanonicalMapper')`: testOctaveSafeGrepGate and testNoToolboxCallGrepGate PASS
  </acceptance_criteria>
  <done>CanonicalMapper.m exists as a handle class with the Entries_ map, threshold constants, and the normalize_/editDistance_/similarity_ helpers; both grep gates are GREEN; the file is Octave-safe and toolbox-free.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: suggest(tagInfos) clustering + confidence assignment + unit-mismatch downgrade (CANON-01, CANON-02)</name>
  <read_first>
    - libs/Fleet/CanonicalMapper.m (current state from Task 1 — you are adding methods to it)
    - tests/suite/TestCanonicalMapper.m (the GREEN targets: testSuggestTwoMatchingPairs, testSuggestNoMatches, testConfidenceHighThreshold/Medium/Low, testConfidenceBoundaryHigh, testConfidenceBoundaryMedium, testUnitMismatchDowngradesHigh/Medium, testUnitMismatchEmptyUnitsIgnored, testUnitMatchCaseInsensitive — read each to match exact expected values)
    - .planning/phases/1041-canonicalmapper/1041-RESEARCH.md (Pattern 2 entry schema, Pattern 3 confidence/units rules + status state machine, § Code Examples assignConfidence_ and applyUnitDowngrade_)
  </read_first>
  <behavior>
    - testSuggestTwoMatchingPairs: 4 tagInfos forming 2 cross-machine clusters -> 2 distinct logicalIds in Entries_.
    - testSuggestNoMatches: mutually dissimilar keys -> 0 logicalIds; every key in unmapped(machineId).
    - testConfidenceHighThreshold/Medium/Low + boundaries: confidence assigned EXACTLY per >=0.90 / >=0.60 / else (inclusive boundaries: sim==0.90 -> HIGH, sim==0.60 -> MEDIUM).
    - testUnitMismatchDowngradesHigh: HIGH + mismatched units -> MEDIUM + unitMismatch=true.
    - testUnitMismatchDowngradesMedium: MEDIUM + mismatch -> LOW + unitMismatch=true.
    - testUnitMismatchEmptyUnitsIgnored: empty unit on either side -> unitMismatch=false, no downgrade.
    - testUnitMatchCaseInsensitive: 'degC' vs 'DegC' -> unitMismatch=false.
  </behavior>
  <action>
    Add the public `suggest` method and the private confidence/unit helpers to `libs/Fleet/CanonicalMapper.m`.

    1. INPUT VALIDATION at the top of `suggest(obj, tagInfos)`:
       - If `~iscell(tagInfos)`: `error('CanonicalMapper:invalidInput', 'suggest expects a cell array of tag-info structs.')`.
       - Each element must be a struct with fields machineId, localKey, name, units (use isfield checks; missing units treated as '' if absent — but RESEARCH.md says units is required, so error if machineId/localKey/name absent; default units to '' if the field is missing).

    2. CLUSTERING ALGORITHM (CANON-01). Flatten tagInfos into a list of (machineId, localKey, name, units). Cross-machine greedy clustering:
       - For each unordered pair of tag-infos from DIFFERENT machines, compute `sim = obj.similarity_(a.localKey, b.localKey)`.
       - A pair is a candidate match when `sim >= obj.MEDIUM_THRESHOLD_` (0.60) — below MEDIUM is LOW and per the state machine still recorded as LOW/AUTO/PENDING, but to avoid clustering every dissimilar key together, only group keys with sim >= MEDIUM into a shared logicalId. (testSuggestNoMatches uses keys with sim < 0.60 -> 0 logicalIds. testConfidenceLowThreshold constructs a pair that DOES cluster but lands LOW — to make both true, cluster on sim >= MEDIUM for grouping BUT also produce a LOW entry when a within-cluster member scores below MEDIUM against the centroid. Simplest correct approach: build clusters by single-link grouping at threshold MEDIUM; the cluster's logicalId is the normalized centroid; then for EACH member compute its similarity to the centroid key and assign confidence from THAT sim — a member can be LOW relative to the centroid. Document this clearly. For testConfidenceLowThreshold, construct the cluster so one member's sim-to-centroid is < 0.60 -> LOW. Match the exact fixture keys the test uses.)
       - logicalId = `obj.normalize_(centroidKey)` where centroidKey is the LONGEST localKey in the cluster (tie -> lexicographically smallest normalized). NEVER assign logicalId = a machine's raw localKey verbatim (Pitfall 3).
       - Skip any (logicalId, machineId) pair already present with status ~= 'AUTO' (precedence — relevant once Plan 03 adds override; harmless now). Use `isKey(obj.Entries_, logId)` guards.

    3. ENTRY CONSTRUCTION: for each cluster member create an entry struct with ALL nine fields (Pattern 2). similarity = member's sim to centroid. status = 'AUTO'. confidence = `obj.assignConfidence_(sim)`. unitMismatch = false (set by step 5).

    4. PRIVATE HELPER `assignConfidence_(obj, sim)` — copy from RESEARCH.md § Code Examples:
       ```matlab
       if sim >= obj.HIGH_THRESHOLD_;      conf = 'HIGH';
       elseif sim >= obj.MEDIUM_THRESHOLD_; conf = 'MEDIUM';
       else;                                conf = 'LOW';
       end
       ```
       Boundaries inclusive (>=) per the locked thresholds.

    5. UNIT CONSISTENCY (CANON-02). After all entries for a logicalId exist, derive the canonical unit = the localUnits of the FIRST entry with confidence=='HIGH' (else ''). Then for each entry apply `applyUnitDowngrade_(entry, canonicalUnits)` — copy from RESEARCH.md § Code Examples:
       ```matlab
       entry.unitMismatch = false;
       if isempty(entry.localUnits) || isempty(canonicalUnits); return; end
       if ~strcmp(lower(entry.localUnits), lower(canonicalUnits))   % case-insensitive
           entry.unitMismatch = true;
           switch entry.confidence
               case 'HIGH';   entry.confidence = 'MEDIUM';
               case 'MEDIUM'; entry.confidence = 'LOW';
               % LOW stays LOW
           end
       end
       ```
       Store the resulting entries back into `obj.Entries_(logicalId)`.

    6. UNMAPPED BOOKKEEPING: record every input (machineId, localKey) so `unmapped(machineId)` (built in Plan 03) can return keys that never landed in any cluster. Store the raw input list in a private property (e.g. `LastTagInfos_` SetAccess=private) so Plan 03's unmapped() can cross-reference. Add that property now: `LastTagInfos_ = {}`. Set `obj.LastTagInfos_ = tagInfos;` inside suggest. (This is the minimal seam so Plan 03 can implement unmapped without re-running suggest.)

    7. Run the full suite. The 5 CANON-01 + 5 confidence + 4 unit tests (14 total) plus the 2 grep gates should be GREEN (16 GREEN). CANON-03/04 tests (override/persistence/queries) and CANON-05 (editor) remain RED — they are built in Plans 03/04.

    MISS_HIT: `suggest` may approach the complexity limit — keep cyclomatic complexity <= 80 and function length <= 520; extract the clustering inner loop into a private helper if needed. Nesting <= 5.
  </action>
  <verify>
    <automated>runtests('tests/suite/TestCanonicalMapper') — the 14 CANON-01/02 methods + 2 grep gates GREEN (16 passing); CANON-03/04/05 still RED. Run via mcp__matlab__run_matlab_test_file.</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "function suggest" libs/Fleet/CanonicalMapper.m` returns `1`
    - `grep -c "function .*assignConfidence_" libs/Fleet/CanonicalMapper.m` >= 1 and `grep -c "function .*applyUnitDowngrade_" libs/Fleet/CanonicalMapper.m` >= 1
    - Thresholds present as named constants (no magic numbers in suggest): `grep -c "HIGH_THRESHOLD_\|MEDIUM_THRESHOLD_" libs/Fleet/CanonicalMapper.m` >= 2
    - Case-insensitive unit compare present: `grep -c "strcmp(lower(" libs/Fleet/CanonicalMapper.m` >= 1
    - LastTagInfos_ seam present for Plan 03 unmapped(): `grep -c "LastTagInfos_" libs/Fleet/CanonicalMapper.m` >= 2
    - Octave-safety still holds: `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` returns `0`; `grep -rn "editDistance(" libs/Fleet/CanonicalMapper.m` returns `0`
    - `mcp__matlab__check_matlab_code` on libs/Fleet/CanonicalMapper.m reports no error-level diagnostics
    - `runtests('tests/suite/TestCanonicalMapper')` PASSES all 16 of: testNormalizeLowercase, testEditDistanceSymmetry, testEditDistanceKnownPairs, testSuggestTwoMatchingPairs, testSuggestNoMatches, testConfidenceHighThreshold, testConfidenceMediumThreshold, testConfidenceLowThreshold, testConfidenceBoundaryHigh, testConfidenceBoundaryMedium, testUnitMismatchDowngradesHigh, testUnitMismatchDowngradesMedium, testUnitMismatchEmptyUnitsIgnored, testUnitMatchCaseInsensitive, testOctaveSafeGrepGate, testNoToolboxCallGrepGate
  </acceptance_criteria>
  <done>suggest(tagInfos) clusters cross-machine keys via toolbox-free edit-distance similarity, assigns HIGH/MEDIUM/LOW confidence at the locked 0.90/0.60 inclusive boundaries, flags unit mismatches and caps confidence per the downgrade rule, records the input tag-infos for Plan 03's unmapped(), and all 14 CANON-01/02 tests + 2 grep gates are GREEN.</done>
</task>

</tasks>

<verification>
- `runtests('tests/suite/TestCanonicalMapper')`: 16 GREEN (14 CANON-01/02 + 2 grep gates); CANON-03/04/05 RED (built in Plans 03/04).
- `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` returns 0 (Octave-safe gate — phase exit criterion #5).
- `grep -rn "editDistance(" libs/Fleet/CanonicalMapper.m` returns 0 (no Statistics Toolbox — phase exit criterion #5).
- mcp__matlab__check_matlab_code: no errors. (Run mh_lint/mh_metric if the MISS_HIT tooling is available; complexity <= 80, length <= 520.)
</verification>

<success_criteria>
- mapper.suggest(tagInfos) returns a logicalId -> {machineId -> localKey} map with every entry carrying HIGH/MEDIUM/LOW confidence (CANON-01, CANON-02 success criterion #1).
- Unit-inconsistent entries are flagged unitMismatch=true and confidence-capped (CANON-02 success criterion #2 — the unit-consistency half of "no wrong comparison can happen silently").
- The two grep gates pass (SUCCESS-5).
- CanonicalMapper.m is a pure data model: no uifigure/uitable/uicontrol code present.
</success_criteria>

<output>
After completion, create `.planning/phases/1041-canonicalmapper/1041-02-SUMMARY.md`
</output>
