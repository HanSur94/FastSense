---
phase: 01-infrastructure-hardening
plan: "04"
subsystem: testing
tags: [matlab, timer, DashboardEngine, test-fix]

# Dependency graph
requires:
  - phase: 01-infrastructure-hardening
    provides: DashboardEngine with ErrorFcn timer restart via onLiveTimerError
provides:
  - testTimerContinuesAfterError using indirect ErrorFcn triggering via a throwing TimerFcn
affects: [01-infrastructure-hardening, INFRA-01]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Indirect ErrorFcn test: replace timer's TimerFcn with a throwing function, pause, assert isrunning"

key-files:
  created: []
  modified:
    - tests/suite/TestDashboardEngine.m

key-decisions:
  - "Test triggers ErrorFcn indirectly via a throwing TimerFcn rather than calling private onLiveTimerError directly"

patterns-established:
  - "Timer error testing: set TimerFcn to @(~,~) error(...), pause(0.5), assert isrunning to validate ErrorFcn restart"

requirements-completed: [INFRA-01]

# Metrics
duration: 1min
completed: 2026-04-01
---

# Phase 01 Plan 04: Gap Closure — testTimerContinuesAfterError Fix Summary

**testTimerContinuesAfterError rewritten to trigger ErrorFcn indirectly via a throwing TimerFcn, giving INFRA-01 runnable automated coverage without calling any private method**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-04-01T20:12:22Z
- **Completed:** 2026-04-01T20:13:05Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Removed direct call to private method `d.onLiveTimerError()` that caused MATLAB to throw an access error
- Replaced with indirect approach: set `LiveTimer.TimerFcn` to a throwing function, wait 0.5s for the timer to fire, then assert `isrunning(d.LiveTimer)`
- INFRA-01 (timer continues after error) now has a test that can reach its assertion and pass in any MATLAB version that enforces `Access=private`

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite testTimerContinuesAfterError to use indirect ErrorFcn triggering** - `fdb5287` (fix)

**Plan metadata:** (docs commit - see below)

## Files Created/Modified
- `tests/suite/TestDashboardEngine.m` - Replaced broken direct private-method call with indirect timer error approach

## Decisions Made
- Used indirect ErrorFcn triggering (replace TimerFcn with a thrower, wait 0.5s) rather than any form of direct private method invocation — consistent with the plan's design intent and MATLAB's access rules

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None - the edit was straightforward; all acceptance criteria passed on first attempt.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- INFRA-01 now has automated coverage via a correctly structured test
- Phase 01 infrastructure-hardening is fully verified with all tests runnable

---
*Phase: 01-infrastructure-hardening*
*Completed: 2026-04-01*
