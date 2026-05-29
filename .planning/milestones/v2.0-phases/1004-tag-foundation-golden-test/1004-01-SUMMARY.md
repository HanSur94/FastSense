---
phase: 1004-tag-foundation-golden-test
plan: 01
subsystem: sensor-threshold
tags: [matlab, octave, handle-class, abstract-by-convention, tag, tdd]

requires:
  - phase: 1003-composite-thresholds
    provides: "CompositeThreshold serialization pattern, Threshold.m constructor template, ThresholdRegistry singleton pattern, Octave-safe throw-from-base precedent (DataSource.m)"
provides:
  - "Tag abstract base class with 8 universal properties (Key, Name, Units, Description, Labels, Metadata, Criticality, SourceRef)"
  - "6 abstract-by-convention methods: getXY, valueAt, getTimeRange, getKind, toStruct, static fromStruct (Pitfall 1 gate: exactly 6)"
  - "resolveRefs default no-op hook for Phase 1008 CompositeTag override"
  - "MockTag test scaffold (concrete Tag subclass) — unblocks Plan 02 TagRegistry tests"
  - "Validated Criticality enum (low|medium|high|safety) via set.Criticality (META-04)"
  - "Pattern documentation: throw-from-base rather than `methods (Abstract)` for Octave parity"
affects: [1004-02-tag-registry, 1005-sensor-state-tags, 1008-composite-tag, 1011-legacy-removal]

tech-stack:
  added: []
  patterns:
    - "Octave-safe abstract-by-convention: throw-from-base + error('ClassName:notImplemented')"
    - "Direct base-instance testing for abstract stubs (no super-call sugar required)"
    - "MockTag subclass test scaffold (mirrors MockDashboardWidget/MockDataSource convention)"

key-files:
  created:
    - "libs/SensorThreshold/Tag.m (175 SLOC including docstring)"
    - "tests/suite/MockTag.m (91 SLOC)"
    - "tests/suite/TestTag.m (172 SLOC, 19 test cases)"
    - "tests/test_tag.m (129 SLOC, 18 Octave assertions)"
  modified: []

key-decisions:
  - "Tag is NOT declared Abstract (no `methods (Abstract)` block) — throw-from-base pattern from DataSource.m is carried forward for Octave parity"
  - "Abstract stubs tested by calling methods on a direct Tag('k') instance; super-call form (getXY@Tag(t)) is not portable outside subclass method bodies"
  - "Name defaults to Key inside the constructor rather than via a Dependent property — simpler and matches Threshold.m style"
  - "Criticality validation enforces ischar(v) before strcmp membership check — defends against non-char inputs"
  - "MockTag.toStruct wraps Labels as {obj.Labels} to survive struct() cellstr collapse; fromStruct unwraps when iscell(L{1})"

patterns-established:
  - "Error ID namespace: Tag:invalidKey, Tag:unknownOption, Tag:invalidCriticality, Tag:notImplemented"
  - "Constructor: required positional Key (validated non-empty char), then name-value varargin; unknown option raises Tag:unknownOption"
  - "resolveRefs(registry) is a default no-op so leaf Tag subclasses need no override; only CompositeTag (Phase 1008) will override"
  - "Each abstract stub has `%#ok<STOUT,MANU>` (or INUSD for unused input) so MISS_HIT is happy about the unused return declarations"

requirements-completed: [TAG-01, TAG-02, META-01, META-03, META-04]

duration: 4min
completed: 2026-04-16
---

# Phase 1004 Plan 01: Tag Abstract Base Class Summary

**Octave-safe Tag abstract base class with exactly 6 throw-from-base stubs, 8 universal properties, Criticality enum validation, and MockTag test scaffold enabling downstream TagRegistry work.**

## Performance

- **Duration:** 4 min (297 seconds)
- **Started:** 2026-04-16T13:12:07Z
- **Completed:** 2026-04-16T13:17:04Z
- **Tasks:** 2 (TDD: RED → GREEN)
- **Files created:** 4 (1 production class, 3 test files)
- **Files modified:** 0 legacy files (strangler-fig MIGRATE-02 constraint upheld)

## Accomplishments

- Established the root of the v2.0 Tag domain hierarchy with the 8 universal properties called out in Phase 1004 CONTEXT
- Locked the Pitfall 1 budget: exactly 6 `error('Tag:notImplemented', ...)` stubs (5 instance + 1 static) enforced by a runtime test that greps the source
- Shipped a MockTag concrete subclass so Plan 02 TagRegistry tests can be written without waiting on Phase 1005 concrete Tag subclasses
- Validated the Criticality enum setter against low|medium|high|safety; rejects non-char and out-of-set values at both construction time and via direct assignment
- Captured the Octave-safe "throw-from-base" pattern at the class level (no `methods (Abstract)` block) — direct descendant of the DataSource.m precedent

## Task Commits

1. **Task 1: Write RED tests (MockTag, TestTag, test_tag)** — `7a0eb0c` (test)
2. **Task 2: Implement Tag.m (GREEN)** — `ff8639e` (feat)

_Note: Task 2 commit bundles Tag.m with an in-task test adjustment that switched the abstract-stub tests from the `getXY@Tag(t)` super-call form (MATLAB-only, only valid inside subclass bodies) to direct `Tag('k').getXY()` invocation. This is portable across MATLAB and Octave and is documented under Decisions._

## Files Created

- `libs/SensorThreshold/Tag.m` — Abstract base class; 8 inline-defaulted properties; name-value constructor; set.Criticality enum guard; 6 throw-from-base stubs (getXY, valueAt, getTimeRange, getKind, toStruct, static fromStruct); resolveRefs default no-op hook
- `tests/suite/MockTag.m` — Minimal concrete Tag subclass; returns empty/NaN data for all abstracts; kind='mock'; roundtrip-capable toStruct/fromStruct
- `tests/suite/TestTag.m` — 19 MATLAB unittest cases (constructor defaults, name-value parsing, unknown option, Labels/Metadata behavior, Criticality valid+invalid, 5 instance abstracts, static fromStruct, resolveRefs no-op, 6-stub Pitfall 1 gate)
- `tests/test_tag.m` — 18 Octave flat-style assertions mirroring the major TestTag cases

## Requirements Coverage Matrix

| Requirement | Test (TestTag.m)                               | Test (test_tag.m)                           |
| ----------- | ---------------------------------------------- | ------------------------------------------- |
| TAG-01      | testAbstract{GetXY,ValueAt,GetTimeRange,GetKind,ToStruct,FromStruct}Throws, testAbstractMethodCount | testAbstractGetXYThrows, testAbstractValueAtThrows, testAbstractGetTimeRangeThrows, testAbstractGetKindThrows, testAbstractToStructThrows, testAbstractFromStructThrows, testAbstractMethodCount |
| TAG-02      | testConstructorRequiresKey, testConstructorDefaults, testConstructorNameValuePairs, testConstructorUnknownOptionErrors | testConstructorDefaults + NV + invalidKey + unknownOption |
| META-01     | testLabelsDefault, testLabelsAssign            | testConstructorDefaults (Labels default), testLabelsAssign |
| META-03     | testMetadataOpenStruct, testMetadataEmptyByDefault | testMetadataOpenStruct, testConstructorDefaults (Metadata default) |
| META-04     | testCriticalityDefault, testCriticalityAllValidValues, testCriticalityInvalidInConstructor, testCriticalityInvalidViaSetter | testConstructorDefaults (medium), testCriticalityAllValidValues, testCriticalityInvalidInConstructor |

## Pitfall 1 Gate Result

- `grep -c "Tag:notImplemented" libs/SensorThreshold/Tag.m` → **6** (exact target, enforced by `testAbstractMethodCount` in both test files)
- `grep -c "methods (Abstract)" libs/SensorThreshold/Tag.m` → **0** (no Abstract block)
- `grep -c "error('Tag:notImplemented'" libs/SensorThreshold/Tag.m` → **6** (literal-form budget)

## Decisions Made

- **Throw-from-base over `methods (Abstract)`:** Octave's handling of the `Abstract` attribute diverges from MATLAB (see DataSource.m history); throw-from-base yields identical behavior on both runtimes.
- **Test abstracts on direct `Tag('k')` instance:** MATLAB's `getXY@Tag(t)` super-call syntax is only valid inside a subclass method body. Since Tag is not declared Abstract we can instantiate it directly and simply call the method — portable and simpler.
- **Criticality setter validates `ischar(v)` before set membership:** prevents cryptic strcmp errors when callers pass a cell or numeric by mistake.
- **`Name` defaults to `Key` inside the constructor** rather than via a Dependent property: keeps the property list flat, matches Threshold.m, and avoids the overhead of a getter on every read.
- **MockTag.toStruct wraps Labels as `{obj.Labels}`:** `struct('labels', {})` would collapse an empty cell; explicit wrapping guarantees fromStruct can reliably recover the cellstr shape.

## Deviations from Plan

None — plan executed exactly as written, with one in-task adjustment documented under Decisions (super-call → direct-instance test form for MATLAB/Octave parity). This adjustment kept all stated acceptance criteria satisfied and was applied inside Task 2 as part of the GREEN pass.

## Issues Encountered

- **Docstring hits inflated Pitfall 1 grep count on first pass.** The initial Tag.m docstring mentioned `'Tag:notImplemented'`, `Tag:invalidKey`, `Tag:unknownOption`, and `Tag:invalidCriticality` literally. Since `testAbstractMethodCount` uses a substring grep, the docstring hits pushed the count to 7 and broke several acceptance greps. Fixed by paraphrasing in the docstring while keeping the 6 `error('Tag:notImplemented', ...)` calls intact in method bodies. This change is included in the Task 2 commit.
- **Octave rejects `getXY@Tag(t)` outside class method bodies.** Surfaced when the Octave smoke run of `test_tag.m` reported `superclass calls can only occur in methods or constructors`. Resolved by switching to direct `Tag('k').getXY()` in both TestTag.m and test_tag.m (Tag is intentionally not `Abstract`-declared, so direct instantiation is supported on both runtimes).

## Verification Notes

- **Octave 10.x (local):** `octave --eval "install(); test_tag();"` → `All 18 test_tag tests passed.`
- **Octave regression spot-check:** `test_sensor()` → `All 8 sensor tests passed.`; `test_event_integration()` → `All 4 event_integration tests passed.` Legacy SensorThreshold + EventDetection suites unaffected.
- **MATLAB:** not available in this sandbox. TestTag.m is a MATLAB unittest class (inherits `matlab.unittest.TestCase`); its green run will be confirmed by `gsd-verifier` or CI (MATLAB primary target per CLAUDE.md).
- **No legacy file modifications:** `git diff --name-only HEAD libs/SensorThreshold/` lists only `Tag.m`. Sensor.m, Threshold.m, StateChannel.m, CompositeThreshold.m, SensorRegistry.m, ThresholdRegistry.m, ExternalSensorRegistry.m, and ThresholdRule.m are untouched (MIGRATE-02 strangler-fig constraint upheld).

## Known Stubs

None. The 6 `error('Tag:notImplemented', ...)` stubs are the intended abstract-by-convention contract for subclasses, not UI placeholders. They are the deliverable.

## Next Phase Readiness

- **Plan 02 (TagRegistry):** MockTag is ready to be imported into `TestTagRegistry.m` for register/get/find/loadFromStructs coverage.
- **Plan 03 (Golden integration test):** Does not touch Tag; independent.
- **Phase 1005 (SensorTag, StateTag):** Inherits the exact contract locked here (6 abstracts, Criticality enum, Labels/Metadata patterns). No Tag.m edits should be required.
- **Phase 1008 (CompositeTag):** Will be the first subclass to override `resolveRefs(registry)` for cross-reference wiring.

---

## Self-Check: PASSED

Verified on disk:
- FOUND: libs/SensorThreshold/Tag.m
- FOUND: tests/suite/MockTag.m
- FOUND: tests/suite/TestTag.m
- FOUND: tests/test_tag.m

Verified commits exist in `git log`:
- FOUND: 7a0eb0c (Task 1 — test files)
- FOUND: ff8639e (Task 2 — Tag.m + test adjustments)

Gate greps on `libs/SensorThreshold/Tag.m`:
- `Tag:notImplemented` count = 6 (exact)
- `methods (Abstract)` count = 0
- 8 inline-defaulted properties present
- `set.Criticality`, `Tag:invalidCriticality`, `Tag:invalidKey`, `Tag:unknownOption`, `function resolveRefs`, `function obj = fromStruct`, `methods (Static)` — each count = 1

Octave runtime checks:
- `test_tag()` → All 18 assertions pass
- `test_sensor()` → All 8 assertions pass (no regression)
- `test_event_integration()` → All 4 assertions pass (no regression)

---
*Phase: 1004-tag-foundation-golden-test*
*Completed: 2026-04-16*
