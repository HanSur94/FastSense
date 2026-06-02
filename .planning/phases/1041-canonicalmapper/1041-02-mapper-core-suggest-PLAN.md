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
    - testEditDistanceKnownPairs: editDistance_('abc','abc')=0, ('abc','axc')=1, ('abc','')=3 (asserted via the similarity formula in the test — which builds tagInfos and calls suggest(), so this test cannot pass until Task 2 implements suggest()).
    - testEditDistanceSymmetry: similarity for a pair is identical regardless of tagInfo order (distance is commutative) — also asserted via suggest(), GREEN only after Task 2.
    - testNormalizeLowercase: keys differing only by case/punctuation normalize to the same string (asserted via suggest clustering) — GREEN only after Task 2.
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

    7. Run the grep gates. They MUST pass the moment the file exists (no contains(, helper named editDistance_). The three CANON-01 distance/normalize tests (testEditDistanceKnownPairs, testEditDistanceSymmetry, testNormalizeLowercase) all assert via suggest(), so they remain RED until Task 2 builds suggest() — that is the intended progression within this plan. Do NOT expect them GREEN after Task 1.

    MISS_HIT: keep functions short (each helper well under the 520-line / complexity-80 limits — these are ~20 LOC each), lines <= 160 chars, nesting <= 5.
  </action>
  <verify>
    <automated>runtests('tests/suite/TestCanonicalMapper') — after Task 1, ONLY testOctaveSafeGrepGate and testNoToolboxCallGrepGate are GREEN. testEditDistanceKnownPairs, testEditDistanceSymmetry, testNormalizeLowercase, and ALL other data-model tests remain RED until Task 2 completes suggest() (every CANON-01/02 test asserts via suggest(), which does not exist after Task 1). Run via mcp__matlab__run_matlab_test_file.</automated>
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
    - `runtests('tests/suite/TestCanonicalMapper')`: testOctaveSafeGrepGate and testNoToolboxCallGrepGate PASS; the CANON-01 data-model tests remain RED (they call suggest(), built in Task 2) — this is the correct intermediate state, not a failure of this task
  </acceptance_criteria>
  <done>CanonicalMapper.m exists as a handle class with the Entries_ map, threshold constants, and the normalize_/editDistance_/similarity_ helpers; both grep gates are GREEN; the file is Octave-safe and toolbox-free. The CANON-01 data-model tests stay RED until Task 2 adds suggest().</done>
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
    - testSuggestNoMatches: mutually dissimilar keys (no cross-machine pair reaches 0.60) -> 0 logicalIds; every key in unmapped(machineId).
    - testConfidenceHighThreshold/Medium/Low + boundaries: confidence assigned EXACTLY per >=0.90 / >=0.60 / else (inclusive boundaries: sim==0.90 -> HIGH, sim==0.60 -> MEDIUM).
    - testConfidenceLowThreshold: a 3-member cluster yields one within-cluster LOW entry, because per-member confidence is scored against the CENTROID and the distant third member scores < 0.60 against it (see the LOCKED fixture + confirmed sim math in the action step). This is NOT a 2-member non-clustering pair — a 2-member pair below 0.60 forms no cluster and produces no entry.
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

    2. CLUSTERING ALGORITHM (CANON-01) — SEED-then-assign. Flatten tagInfos into a list of (machineId, localKey, name, units). The algorithm has TWO distinct steps, and the GROUPING threshold is separate from the per-member CONFIDENCE — this separation is what lets a within-cluster member land LOW (the testConfidenceLowThreshold requirement):

       STEP A — form SEED clusters (the grouping threshold gates THIS step only):
         - Examine every unordered pair of tag-infos from DIFFERENT machines; compute `sim = obj.similarity_(a.localKey, b.localKey)`.
         - A SEED cluster is created only when at least one cross-machine pair has `sim >= obj.MEDIUM_THRESHOLD_` (0.60). Merge transitively (single-link) at >=0.60 to grow seeds. If NO cross-machine pair reaches 0.60, NO seed cluster forms — every tag-info is a singleton (this is what makes testSuggestNoMatches yield 0 logicalIds, all keys unmapped).
         - For each seed cluster, the centroidKey = the LONGEST localKey in the cluster (tie -> lexicographically smallest normalized). logicalId = `obj.normalize_(centroidKey)`. NEVER assign logicalId = a machine's raw localKey verbatim (Pitfall 3).

       STEP B — assign remaining members to the NEAREST seed centroid (NO floor here):
         - For every tag-info NOT already in a seed cluster, find the seed centroid with the highest `simToCentroid = obj.similarity_(member.localKey, centroidKey)` AND a different machine than centroid members; assign the member to THAT cluster. There is NO 0.60 floor in this step — a member is admitted to its nearest existing cluster regardless of simToCentroid (this is precisely how a distant member becomes a within-cluster LOW entry).
         - A tag-info remains a singleton (-> unmapped) ONLY when NO seed cluster exists for it to attach to (i.e. Step A produced none reachable from a different machine). Do not create a one-machine "cluster".

       PER-MEMBER CONFIDENCE (scored against the centroid, NOT against the grouping threshold):
         - For EACH cluster member (seed members and Step-B members alike), compute `simToCentroid = obj.similarity_(member.localKey, centroidKey)` and `entry.confidence = obj.assignConfidence_(simToCentroid)`; store `entry.similarity = simToCentroid`. A Step-B member with simToCentroid < 0.60 therefore gets confidence == 'LOW' while still being a cluster member — this is the mechanism the test depends on.
         - Skip any (logicalId, machineId) pair already present with status ~= 'AUTO' (precedence — relevant once Plan 03 adds override; harmless now). Use `isKey(obj.Entries_, logId)` guards.

       LOCKED FIXTURE for testConfidenceLowThreshold (use these EXACT keys; Plan 01 Task 2 builds the IDENTICAL fixture; sim math hand-confirmed below — all keys are already normalized, length 10, so the similarity formula is `1 - editDistance_/10`):
       ```matlab
       tagInfos = {
           struct('machineId','M01','localKey','abcdefghij','name','Centroid','units','u'), ...   % seed member
           struct('machineId','M02','localKey','abcdefghij','name','Identical','units','u'), ...   % seed member (identical to M01)
           struct('machineId','M03','localKey','abzzzzzzzz','name','Distant','units','u') ...       % Step-B member, distant from centroid
       };
       ```
       CONFIRMED sim math (Wagner-Fischer, by hand — reproduce these exact numbers in a code comment in suggest() and in testConfidenceLowThreshold):
         - M01 `abcdefghij` vs M02 `abcdefghij`: identical -> editDistance_ = 0 -> sim = 1 - 0/10 = 1.00 (>= 0.60) -> SEED cluster forms; centroidKey = `abcdefghij` (longest; M01/M02 tie, lexicographically smallest = `abcdefghij`); logicalId = `abcdefghij`. M01 & M02 simToCentroid = 1.00 -> confidence HIGH.
         - M03 `abzzzzzzzz` vs centroid `abcdefghij`: positions 1-2 (`ab`) match, positions 3-10 (`cdefghij` vs `zzzzzzzz`) are 8 substitutions; equal length so all-substitution is optimal -> editDistance_ = 8 -> simToCentroid = 1 - 8/10 = 0.20. M03 is NOT a seed pair with anyone (its best cross-machine sim is 0.20 < 0.60), so Step A leaves it unseeded; Step B attaches M03 to its nearest existing centroid `abcdefghij` (the only seed) with NO floor -> M03 becomes a cluster member with simToCentroid = 0.20 -> `assignConfidence_(0.20)` == 'LOW'.
       RESULT: one cluster (logicalId `abcdefghij`) with three entries — M01 HIGH, M02 HIGH, M03 **LOW**. testConfidenceLowThreshold asserts the M03 entry has confidence == 'LOW'. (If you discover the executor's editDistance_ produces a different value for any of these three pairs — it will not, these are exact — keep the fixture and update the comment; do NOT silently weaken the assertion.)

    3. ENTRY CONSTRUCTION: for each cluster member create an entry struct with ALL nine fields (Pattern 2). similarity = member's simToCentroid. status = 'AUTO'. confidence = `obj.assignConfidence_(simToCentroid)`. unitMismatch = false (set by step 5).

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
       Store the resulting entries back into `obj.Entries_(logicalId)`. (Note: in the LOCKED LOW fixture all three units are `'u'`, so no downgrade fires — M03 is LOW purely from its 0.20 similarity, isolating the confidence-from-centroid behavior the test targets.)

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
    - testConfidenceLowThreshold specifically passes via the LOCKED 3-member fixture (M01/M02 `abcdefghij` seed centroid + M03 `abzzzzzzzz` Step-B member at simToCentroid 0.20 -> LOW), NOT via a 2-member non-clustering pair
  </acceptance_criteria>
  <done>suggest(tagInfos) clusters cross-machine keys via toolbox-free edit-distance similarity (seed clusters at the 0.60 grouping threshold, remaining members assigned to the nearest seed centroid with no floor, per-member confidence scored against the centroid so a distant member lands LOW), assigns HIGH/MEDIUM/LOW confidence at the locked 0.90/0.60 inclusive boundaries, flags unit mismatches and caps confidence per the downgrade rule, records the input tag-infos for Plan 03's unmapped(), and all 14 CANON-01/02 tests + 2 grep gates are GREEN.</done>
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
</content>
