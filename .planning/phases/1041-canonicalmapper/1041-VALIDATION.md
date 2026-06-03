---
phase: 1041
slug: canonicalmapper
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-02
---

# Phase 1041 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Test map derived from `1041-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `matlab.unittest.TestCase` (MATLAB R2020b+ and GNU Octave 7+ via `run_all_tests.m`) |
| **Config file** | none — follows existing `tests/suite/Test*.m` pattern |
| **Quick run command** | `runtests('tests/suite/TestCanonicalMapper')` |
| **Full suite command** | `run_all_tests` |
| **Estimated runtime** | ~5 seconds (in-memory unit tests; round-trip uses JSON string, no disk I/O) |

---

## Sampling Rate

- **After every task commit:** Run `runtests('tests/suite/TestCanonicalMapper')`
- **After every plan wave:** Run `runtests('tests/suite/TestCanonicalMapper')` + the two grep gates
- **Before `/gsd:verify-work`:** Full `run_all_tests` must be green
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

> Task IDs are assigned by the planner (Step 8). Rows below map each phase requirement to the
> concrete test method that proves it. The `gsd-nyquist-auditor` reconciles Task IDs after plans exist.
> Every test file is created in Wave 0 of the phase (the implementation + test file do not exist yet).

| Requirement | Behavior | Test Type | Test Method | File Exists | Status |
|-------------|----------|-----------|-------------|-------------|--------|
| CANON-01 | Normalization: lowercase + punctuation collapse | unit | `testNormalizeLowercase` | ❌ W0 | ⬜ pending |
| CANON-01 | Normalization: collapse repeated separators + trim | unit | `testNormalizeCollapsesRepeats` | ❌ W0 | ⬜ pending |
| CANON-01 | Edit-distance symmetry `d(a,b)==d(b,a)` | unit | `testEditDistanceSymmetry` | ❌ W0 | ⬜ pending |
| CANON-01 | Edit-distance known pairs (`abc/abc=0`, `abc/axc=1`, `abc/''=3`) | unit | `testEditDistanceKnownPairs` | ❌ W0 | ⬜ pending |
| CANON-01 | `suggest` 3 machines / 2 matching pairs → 2 logicalIds | unit | `testSuggestTwoMatchingPairs` | ❌ W0 | ⬜ pending |
| CANON-01 | `suggest` no similar keys → 0 logicalIds, all in unmapped | unit | `testSuggestNoMatches` | ❌ W0 | ⬜ pending |
| CANON-02 | sim ≥ 0.90 → HIGH | unit | `testConfidenceHighThreshold` | ❌ W0 | ⬜ pending |
| CANON-02 | sim ∈ [0.60, 0.90) → MEDIUM | unit | `testConfidenceMediumThreshold` | ❌ W0 | ⬜ pending |
| CANON-02 | sim < 0.60 → LOW | unit | `testConfidenceLowThreshold` | ❌ W0 | ⬜ pending |
| CANON-02 | boundary: sim exactly 0.90 → HIGH | unit | `testConfidenceBoundaryHigh` | ❌ W0 | ⬜ pending |
| CANON-02 | boundary: sim exactly 0.60 → MEDIUM | unit | `testConfidenceBoundaryMedium` | ❌ W0 | ⬜ pending |
| CANON-02 | unit mismatch downgrades HIGH→MEDIUM + flag | unit | `testUnitMismatchDowngradesHigh` | ❌ W0 | ⬜ pending |
| CANON-02 | unit mismatch downgrades MEDIUM→LOW + flag | unit | `testUnitMismatchDowngradesMedium` | ❌ W0 | ⬜ pending |
| CANON-02 | empty units → no mismatch flagged | unit | `testUnitMismatchEmptyUnitsIgnored` | ❌ W0 | ⬜ pending |
| CANON-02 | unit match case-insensitive (`degC` vs `DegC`) | unit | `testUnitMatchCaseInsensitive` | ❌ W0 | ⬜ pending |
| CANON-03 | override creates OVERRIDDEN entry w/ precedence over AUTO | unit | `testOverrideCreatesEntry` | ❌ W0 | ⬜ pending |
| CANON-03 | override survives re-run of `suggest` | unit | `testOverrideSurvivesResuggest` | ❌ W0 | ⬜ pending |
| CANON-03 | `toStruct`/`fromStruct` round-trip preserves all entries | unit | `testRoundTripPreservesEntries` | ❌ W0 | ⬜ pending |
| CANON-03 | round-trip preserves OVERRIDDEN status | unit | `testRoundTripPreservesOverriddenStatus` | ❌ W0 | ⬜ pending |
| CANON-03 | `save`/`load` round-trip → identical mapper state | unit | `testSaveLoadRoundTrip` | ❌ W0 | ⬜ pending |
| CANON-04 | `reviewPending` returns LOW-confidence AUTO entries | unit | `testReviewPendingReturnsLow` | ❌ W0 | ⬜ pending |
| CANON-04 | `reviewPending` returns unitMismatch entries any confidence | unit | `testReviewPendingReturnsUnitMismatch` | ❌ W0 | ⬜ pending |
| CANON-04 | `reviewPending` excludes HIGH/MEDIUM confirmed entries | unit | `testReviewPendingExcludesGoodEntries` | ❌ W0 | ⬜ pending |
| CANON-04 | `unmapped('M01')` returns keys with no mapping | unit | `testUnmappedReturnsUnresolved` | ❌ W0 | ⬜ pending |
| CANON-04 | `unmapped` empty when all keys mapped | unit | `testUnmappedEmptyWhenAllMapped` | ❌ W0 | ⬜ pending |
| CANON-04 | `isResolvable` false for LOW+AUTO | unit | `testIsResolvableFalseForLow` | ❌ W0 | ⬜ pending |
| CANON-04 | `isResolvable` true for HIGH+AUTO | unit | `testIsResolvableTrueForHigh` | ❌ W0 | ⬜ pending |
| CANON-05 | `CanonicalMapEditor` constructs + opens figure (MATLAB-only) | smoke | `testEditorConstructs` | ❌ W0 | ⬜ pending |
| SUCCESS-5 | `grep -rn "contains(" libs/Fleet/CanonicalMapper.m` → 0 | grep gate | `testOctaveSafeGrepGate` | ❌ W0 | ⬜ pending |
| SUCCESS-5 | `grep -rn "editDistance(" libs/Fleet/CanonicalMapper.m` → 0 | grep gate | `testNoToolboxCallGrepGate` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Highest-Risk Correctness Areas (over-sampled)

The roadmap mandate is "no wrong comparison can happen silently." These four areas get extra cases:

1. **Confidence threshold boundaries** — test exactly 0.90 (→HIGH), 0.8999 (→MEDIUM), 0.60 (→MEDIUM), 0.5999 (→LOW). An off-by-rounding boundary misclassifies entries.
2. **Unit-mismatch flagging** — a silently-unflagged mismatch is the most dangerous outcome. Test `degC` vs `K` (numerically close, physically different) → `unitMismatch=true`; test empty-units edge case separately.
3. **Override persistence round-trip** — a lost override reverts a user-confirmed safe mapping to a possibly-wrong AUTO entry. Serialize→deserialize (JSON string, no disk) and assert override survives with OVERRIDDEN status.
4. **`reviewPending` exclusion contract** — gatekeeps Phase 1045's comparison safety. Assert every "should be pending" variant (LOW, unitMismatch, LOW+mismatch) appears, and every "should NOT" variant (HIGH no-mismatch, CONFIRMED, OVERRIDDEN) does not.

---

## Wave 0 Requirements

- [ ] `tests/suite/TestCanonicalMapper.m` — new suite covering all CANON-01..05 + SUCCESS-5 gates
- [ ] `libs/Fleet/CanonicalMapper.m` — the data-model implementation (does not exist yet)
- [ ] `libs/Fleet/CanonicalMapEditor.m` — CANON-05 standalone editor (does not exist yet)
- [ ] `addpath(fullfile(root, 'libs', 'Fleet'))` in `install.m` — path registration for the new lib

*No framework install needed — `matlab.unittest.TestCase` is already used across 40+ suite files.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Editable table renders + promote button works visually | CANON-05 | Visual layout/interaction in a `uifigure` is not asserted by headless unit tests beyond construction smoke | Open `CanonicalMapEditor(mapper)`; confirm columns (logical name / per-machine local key / status / confidence) render, an entry is editable, and a LOW entry can be promoted/confirmed; confirm change reflects in `mapper` state |

*All other phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
