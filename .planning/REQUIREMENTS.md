# Requirements: FastSense Advanced Dashboard

**Defined:** 2026-04-01
**Core Value:** Users can organize complex dashboards into navigable sections and pop out any widget for detailed analysis without losing the dashboard context.

## v1 Requirements

Requirements for this milestone. Each maps to roadmap phases.

### Layout Organization

- [ ] **LAYOUT-01**: Collapsible sections reflow the grid — collapsing a GroupWidget reclaims screen space by shifting widgets below upward
- [ ] **LAYOUT-02**: Expanding a collapsed section pushes widgets below downward to make room
- [ ] **LAYOUT-03**: Multi-page dashboards — user can define multiple pages within a single dashboard figure
- [ ] **LAYOUT-04**: Page navigation UI — toolbar buttons or tab strip to switch between pages
- [ ] **LAYOUT-05**: Active page persists through save/load cycle
- [ ] **LAYOUT-06**: Only the active page's widgets are rendered; inactive pages are hidden
- [ ] **LAYOUT-07**: Existing tabbed GroupWidget persists active tab through save/load round-trip
- [ ] **LAYOUT-08**: Tab visual contrast is legible in both light and dark themes

### Widget Info Tooltips

- [ ] **INFO-01**: Every widget with a non-empty Description shows an info icon in its header
- [ ] **INFO-02**: Clicking the info icon displays the description text in a popup panel
- [ ] **INFO-03**: Info popup renders Description as Markdown using MarkdownRenderer
- [ ] **INFO-04**: Info popup can be dismissed by clicking outside it or pressing Escape
- [ ] **INFO-05**: Info icon and popup work on all 20+ existing widget types without per-widget changes

### Detachable Widgets

- [ ] **DETACH-01**: Every widget shows a detach button in its header chrome
- [ ] **DETACH-02**: Clicking detach opens the widget as a standalone figure window
- [ ] **DETACH-03**: Detached widget receives live data updates from DashboardEngine timer
- [ ] **DETACH-04**: Closing a detached figure window cleanly removes it from the mirror registry
- [ ] **DETACH-05**: Detached FastSenseWidget gets independent time axis zoom/pan (UseGlobalTime = false)
- [ ] **DETACH-06**: Multiple widgets can be detached simultaneously without degrading dashboard refresh rate
- [ ] **DETACH-07**: Detached widgets are read-only live mirrors (no edits syncing back)

### Infrastructure Hardening

- [x] **INFRA-01**: DashboardEngine.LiveTimer has an ErrorFcn that logs errors and keeps the timer running
- [x] **INFRA-02**: DashboardSerializer .m export correctly serializes GroupWidget children (fix existing bug)
- [x] **INFRA-03**: jsondecode struct-vs-cell normalization applied at all new nesting levels (pages, detached registry)

### Serialization & Persistence

- [ ] **SERIAL-01**: Multi-page structure persists through JSON save/load cycle
- [ ] **SERIAL-02**: Multi-page structure persists through .m export/import cycle
- [ ] **SERIAL-03**: Collapsed/expanded state of sections persists through save/load
- [ ] **SERIAL-04**: Detached widget state is NOT persisted (detached windows are session-only)
- [ ] **SERIAL-05**: Existing single-page dashboards load without errors (backward compatibility)

### Backward Compatibility

- [x] **COMPAT-01**: Existing dashboard scripts run without modification
- [x] **COMPAT-02**: Previously serialized JSON dashboards load correctly
- [x] **COMPAT-03**: Previously serialized .m dashboards load correctly
- [x] **COMPAT-04**: DashboardBuilder API remains unchanged for single-page dashboards

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Enhanced Interactivity

- **INTERACT-01**: Cross-filtering between widgets (click point in one, filter others)
- **INTERACT-02**: Interactive controls (dropdowns, sliders) driving widget data
- **INTERACT-03**: Drag-and-drop widget rearrangement

### WebBridge Parity

- **WEB-01**: Multi-page navigation in browser view
- **WEB-02**: Widget info tooltips in browser view
- **WEB-03**: Detachable widgets in browser view

### Polish

- **POLISH-01**: Tab overflow handling for groups with many tabs
- **POLISH-02**: Animated collapse/expand transitions
- **POLISH-03**: Detached widget window remembers position/size across detach cycles

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Drag-and-drop rearrangement | High cost, low value for script-driven workflows; MATLAB uicontrol drag is unreliable |
| Cross-filtering / data binding | Would require new reactive data model; conflicts with sensor-driven architecture |
| Interactive controls (sliders, dropdowns) | DashboardEngine is visualization, not control panel; point to App Designer |
| Tooltip hover animations | MATLAB uicontrols don't support CSS-style hover; WindowButtonMotionFcn is fragile |
| Deep nesting beyond depth 2 | Exponential rendering complexity; use multi-page instead |
| Bidirectional detached widget edits | Disproportionate state management complexity |
| Browser/WebBridge updates | Separate rendering path; future milestone |
| New widget types | 20+ types sufficient; compose existing widgets in GroupWidget |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| LAYOUT-01 | Phase 2 | Pending |
| LAYOUT-02 | Phase 2 | Pending |
| LAYOUT-03 | Phase 4 | Pending |
| LAYOUT-04 | Phase 4 | Pending |
| LAYOUT-05 | Phase 4 | Pending |
| LAYOUT-06 | Phase 4 | Pending |
| LAYOUT-07 | Phase 2 | Pending |
| LAYOUT-08 | Phase 2 | Pending |
| INFO-01 | Phase 3 | Pending |
| INFO-02 | Phase 3 | Pending |
| INFO-03 | Phase 3 | Pending |
| INFO-04 | Phase 3 | Pending |
| INFO-05 | Phase 3 | Pending |
| DETACH-01 | Phase 5 | Pending |
| DETACH-02 | Phase 5 | Pending |
| DETACH-03 | Phase 5 | Pending |
| DETACH-04 | Phase 5 | Pending |
| DETACH-05 | Phase 5 | Pending |
| DETACH-06 | Phase 5 | Pending |
| DETACH-07 | Phase 5 | Pending |
| INFRA-01 | Phase 1 | Complete |
| INFRA-02 | Phase 1 | Complete |
| INFRA-03 | Phase 1 | Complete |
| SERIAL-01 | Phase 6 | Pending |
| SERIAL-02 | Phase 6 | Pending |
| SERIAL-03 | Phase 6 | Pending |
| SERIAL-04 | Phase 6 | Pending |
| SERIAL-05 | Phase 6 | Pending |
| COMPAT-01 | Phase 1 | Complete |
| COMPAT-02 | Phase 1 | Complete |
| COMPAT-03 | Phase 1 | Complete |
| COMPAT-04 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 32 total
- Mapped to phases: 32
- Unmapped: 0

---
*Requirements defined: 2026-04-01*
*Last updated: 2026-04-01 after roadmap creation*
