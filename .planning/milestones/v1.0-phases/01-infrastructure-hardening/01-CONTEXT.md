# Phase 1: Infrastructure Hardening - Context

**Gathered:** 2026-04-01
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

The dashboard engine is safe to extend — timer errors cannot silently kill refresh, GroupWidget children survive .m export, and jsondecode normalization is applied wherever nested arrays are decoded. All existing dashboard scripts and serialized dashboards continue to work without modification.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DashboardEngine.m` — LiveTimer setup in `startLive()`, tick callback in `onLiveTick()`
- `DashboardSerializer.m` — `.m` export in `save()` method, JSON in `saveJSON()`/`loadJSON()`
- `GroupWidget.m` — `toStruct()`/`fromStruct()` for children serialization
- `DashboardWidget.m` — base class with `toStruct()`/`fromStruct()` pattern

### Established Patterns
- Timer-driven refresh via `DashboardEngine.LiveTimer` with `TimerFcn` callback
- JSON round-trip via `jsondecode`/`jsonencode` with struct normalization
- Widget serialization via `toStruct()`/`fromStruct()` virtual methods

### Integration Points
- `DashboardEngine.startLive()` — where ErrorFcn needs to be set
- `DashboardSerializer.save()` — where GroupWidget children .m export is broken
- `GroupWidget.fromStruct()` — where jsondecode normalization is applied (pattern to extend)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Refer to ROADMAP phase description and success criteria.

</specifics>

<deferred>
## Deferred Ideas

None — infrastructure phase.

</deferred>
