---
phase: 1042-machine-fleet-pipeline-di-seam
plan: "02"
subsystem: pipeline
tags: [BatchTagPipeline, LiveTagPipeline, TagRegistry, DI, FLEET-03]

# Dependency graph
requires:
  - phase: 1042-machine-fleet-pipeline-di-seam
    provides: "Phase plan and PATTERNS.md with exact seam locations and verbatim code patterns"
provides:
  - "tagSource_ DI seam (private fn-handle property, default @TagRegistry.find) on both BatchTagPipeline and LiveTagPipeline"
  - "'TagSource' NV-pair accepted by both pipeline constructors (before the otherwise hard-error guard)"
  - "eligibleTags_ in both pipelines delegates to obj.tagSource_ instead of static TagRegistry.find"
affects: [1042-03-machine-ingestbatch-startlive, Fleet, Machine]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DI seam via private fn-handle property (tagSource_ = @TagRegistry.find) with NV-pair override — mirrors existing writeFn_ idiom"
    - "opts struct default + case before otherwise guard pattern for additive NV extension"

key-files:
  created: []
  modified:
    - libs/SensorThreshold/BatchTagPipeline.m
    - libs/SensorThreshold/LiveTagPipeline.m

key-decisions:
  - "tagSource_ default is @TagRegistry.find captured at class-load time — preserves single-machine byte-identical behavior (FLEET-03)"
  - "Assignment obj.tagSource_ = opts.TagSource placed after the switch loop in both constructors, independent of cluster-mode branch in LiveTagPipeline"
  - "eligibleTags_ predicate body kept byte-identical between BatchTagPipeline and LiveTagPipeline as per lockstep discipline"
  - "No other methods (run(), start(), onTick_, cluster path) touched — strictly additive seam only"

patterns-established:
  - "DI seam pattern: private fn-handle property + NV-pair + post-switch assignment — use for future injectable dependencies in pipeline classes"

requirements-completed: [FLEET-03]

# Metrics
duration: 15min
completed: 2026-06-07
---

# Phase 1042 Plan 02: Pipeline TagSource DI Seam Summary

**`tagSource_` fn-handle DI seam added to BatchTagPipeline and LiveTagPipeline so Machine can scope ingestion to its own isolated catalog via `@(pred) machine.find(pred)` while the default `@TagRegistry.find` preserves byte-identical single-machine behavior**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-06-07T00:00:00Z
- **Completed:** 2026-06-07T00:00:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `tagSource_ = @TagRegistry.find` private property to BatchTagPipeline (FLEET-03/D-12 seam)
- Added `tagSource_ = @TagRegistry.find` private property to LiveTagPipeline (mirrors BatchTagPipeline)
- Both pipelines accept new `'TagSource'` NV-pair in constructor switch (before the `otherwise` hard-error guard)
- Both `eligibleTags_` methods now call `obj.tagSource_(pred)` instead of static `TagRegistry.find`; predicate bodies are byte-identical
- LiveTagPipeline cluster/SharedRoot path fully untouched (`IsClusterMode_` count unchanged at 9)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add tagSource_ DI seam to BatchTagPipeline.m** - `4e488b3d` (feat)
2. **Task 2: Add identical tagSource_ DI seam to LiveTagPipeline.m** - `e12d980e` (feat)

## Files Created/Modified

- `libs/SensorThreshold/BatchTagPipeline.m` - Added `tagSource_` private property, `'TagSource'` NV-pair, `obj.tagSource_` call in `eligibleTags_`
- `libs/SensorThreshold/LiveTagPipeline.m` - Identical three changes; cluster path preserved

## Decisions Made

- `tagSource_` assignment placed after the switch/validation block in both constructors so it is unconditional (not gated by any cluster-mode branch)
- Comment in LiveTagPipeline `eligibleTags_` explicitly reminds maintainers to update both sites in lockstep when adding a new eligible tag kind (D-16 / Pitfall 10 discipline preserved)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. All three additive changes applied cleanly to both files.

## MATLAB Test Execution

MATLAB test execution (TestBatchTagPipeline, TestLiveTagPipeline suites) is deferred to the orchestrator as stated in the critical runtime constraint. No `mcp__matlab__*` calls were made during this execution.

**Grep-verified acceptance criteria (all passing at time of commit):**

BatchTagPipeline:
- `grep -c "tagSource_ = @TagRegistry.find"` = 1
- `case 'TagSource'` at line 102, `otherwise` at line 104 (102 < 104)
- `grep -c "tags = obj.tagSource_("` = 1
- Non-comment `TagRegistry.find` occurrences = 2 (both are `@TagRegistry.find` handles, not calls)
- `eligibleTags_` signature: `function tags = eligibleTags_(obj)`

LiveTagPipeline:
- `grep -c "tagSource_ = @TagRegistry.find"` = 1
- `case 'TagSource'` at line 204, `otherwise` at line 206 (204 < 206)
- `grep -c "tags = obj.tagSource_("` = 1
- Non-comment `TagRegistry.find` occurrences = 2 (both `@TagRegistry.find` handles)
- `eligibleTags_` signature: `function tags = eligibleTags_(obj)`
- `IsClusterMode_` count = 9 (unchanged)
- Predicate bodies byte-identical between both files

## Known Stubs

None.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The `'TagSource'` DI seam accepts a caller-supplied fn-handle but operates in a trusted local script context per T-1042-02 disposition (accept).

## Next Phase Readiness

- Plan 03 (Machine.ingestBatch / Machine.startLive) can now wire `'TagSource', @(pred) obj.find(pred)` into both pipelines without any further pipeline changes
- Both pipeline defaults remain `@TagRegistry.find` — all existing single-machine batch and live ingestion scripts continue to work without modification

## Self-Check

- [x] `4e488b3d` commit exists: `feat(1042-02): add tagSource_ DI seam to BatchTagPipeline`
- [x] `e12d980e` commit exists: `feat(1042-02): add tagSource_ DI seam to LiveTagPipeline`
- [x] `libs/SensorThreshold/BatchTagPipeline.m` modified with all three changes
- [x] `libs/SensorThreshold/LiveTagPipeline.m` modified with all three changes
- [x] `STATE.md` and `ROADMAP.md` NOT modified (per sequential_execution constraint)

## Self-Check: PASSED

---
*Phase: 1042-machine-fleet-pipeline-di-seam*
*Completed: 2026-06-07*
