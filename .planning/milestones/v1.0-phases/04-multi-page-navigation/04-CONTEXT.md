# Phase 4: Multi-Page Navigation - Context

**Gathered:** 2026-04-01
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous)

<domain>
## Phase Boundary

Add DashboardPage container concept to DashboardEngine, a PageBar UI for navigation between pages, active page persistence through save/load, and backward compatibility for single-page dashboards.

</domain>

<decisions>
## Implementation Decisions

### Page Model
- DashboardEngine gains a Pages cell array of DashboardPage objects
- DashboardPage is a thin wrapper holding: name, widgets list, and active state
- Single-page dashboards have exactly one implicit page (no visible page bar)
- addWidget() routes to the active page's widget list

### Page Navigation UI
- PageBar rendered as a row of pushbuttons above the dashboard grid area
- Styled consistently with existing DashboardToolbar
- Only visible when Pages count > 1
- Active page button visually distinguished (like tab active state)

### Serialization
- DashboardSerializer extended for multi-page JSON structure
- Active page name persisted in JSON
- Single-page JSON loads without a page bar (backward compatible)

### Claude's Discretion
- Exact PageBar layout and styling
- DashboardPage class design (separate file vs. nested struct)
- How page switching interacts with live timer (refresh only active page widgets)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DashboardEngine.m` — Widgets cell array, addWidget(), render(), load()
- `DashboardLayout.m` — 24-column grid, allocatePanels(), realizeWidget()
- `DashboardSerializer.m` — JSON save/load, .m export
- `DashboardToolbar.m` — pushbutton styling pattern for PageBar
- `DashboardTheme.m` — TabActiveBg/TabInactiveBg colors reusable for page buttons

### Established Patterns
- Phase 2: ReflowCallback injection via addWidget/load
- Phase 3: realizeWidget() central injection for all widgets
- GroupWidget tabbed mode: tab switching pattern reusable for page switching

### Integration Points
- `DashboardEngine.addWidget()` — routes to active page
- `DashboardEngine.render()` — renders only active page widgets
- `DashboardEngine.onLiveTick()` — refreshes only active page widgets
- `DashboardSerializer.saveJSON()`/`loadJSON()` — multi-page structure

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond ROADMAP success criteria.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
