# Phase 6: Serialization & Persistence - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure/verification phase — discuss skipped)

<domain>
## Phase Boundary

Verify and harden round-trip correctness for all new structures across JSON and .m formats. Multi-page layouts, collapsed state, and detached widget exclusion must all survive save/load cycles. Pre-milestone JSON dashboards must load without errors.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure verification phase. Write comprehensive round-trip tests for:
1. Multi-page JSON save/load (pages, widgets, active page)
2. Multi-page .m export/import (pages, widgets)
3. Collapsed/expanded state persistence
4. Detached widget state NOT persisted
5. Legacy (pre-milestone) JSON backward compatibility

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DashboardSerializer.m` — saveJSON/loadJSON, save (`.m` export), widgetsPagesToConfig
- `DashboardEngine.m` — save/load methods, Pages model, DetachedMirrors
- `GroupWidget.m` — Collapsed state in toStruct/fromStruct
- `TestDashboardMultiPage.m` — existing multi-page tests (9 methods)
- `TestDashboardSerializerRoundTrip.m` — existing round-trip tests
- `TestDashboardMSerializer.m` — existing .m export tests

### Integration Points
- Phase 4 added multi-page JSON serialization
- Phase 2 added collapsed state (already serialized)
- Phase 5 added DetachedMirrors (must NOT be serialized)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — verification/hardening phase.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
