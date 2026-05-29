# Phase 2: Collapsible Sections - Context

**Gathered:** 2026-04-01
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous)

<domain>
## Phase Boundary

Wire grid reflow into GroupWidget collapse/expand so collapsing reclaims screen space. Verify tabbed GroupWidget active tab persists through save/load. Verify tab label contrast in light and dark themes.

</domain>

<decisions>
## Implementation Decisions

### Reflow Mechanism
- GroupWidget needs a callback to trigger DashboardLayout.reflow() on collapse/expand
- Use a function handle callback (EngineRef pattern) rather than a direct object reference to avoid circular references between GroupWidget and DashboardEngine
- DashboardEngine.addWidget() should inject the reflow callback into GroupWidget instances

### Tab Persistence
- ActiveTab field already serializes in toStruct()/fromStruct() — verify round-trip works correctly
- Write integration test confirming active tab survives JSON save/load cycle

### Theme Contrast
- TabActiveBg and TabInactiveBg already defined for all 5 themes in DashboardTheme.m
- Verify contrast ratio between active/inactive tab backgrounds and text color is legible
- Fix any theme where contrast is insufficient

### Claude's Discretion
All detailed implementation choices (exact callback signature, reflow algorithm, test structure) are at Claude's discretion. The collapse/expand methods and reflow() already exist — this is wiring, not new feature development.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `GroupWidget.m` — collapse()/expand() methods exist with TODO comments at lines 241 and 260
- `DashboardLayout.m` — reflow() method exists
- `DashboardTheme.m` — TabActiveBg/TabInactiveBg defined for all 5 themes
- `GroupWidget.toStruct()` — serializes collapsed state and activeTab
- `GroupWidget.fromStruct()` — restores collapsed state and activeTab

### Established Patterns
- Phase 1 established EngineRef callback pattern (used for timer ErrorFcn)
- normalizeToCell.m shared helper pattern for jsondecode normalization
- TDD pattern: write failing tests first, then implement

### Integration Points
- `DashboardEngine.addWidget()` — inject reflow callback into GroupWidget
- `GroupWidget.collapse()`/`expand()` — call reflow callback
- `DashboardLayout.reflow()` — recalculates grid positions

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond ROADMAP success criteria. Standard reflow wiring.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
