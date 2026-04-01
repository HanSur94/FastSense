# FastSense Advanced Dashboard

## What This Is

An upgrade to FastSense's existing dashboard engine adding nested layout organization (tabs, collapsible groups, multi-page navigation), per-widget info tooltips for contextual documentation, and detachable live-mirrored widgets that pop out as independent figure windows. Built for MATLAB engineers who use dashboards for sensor data analysis.

## Core Value

Users can organize complex dashboards into navigable sections and pop out any widget for detailed analysis without losing the dashboard context.

## Requirements

### Validated

- ✓ Widget-based dashboard composition with 20+ widget types — existing
- ✓ 24-column grid layout system — existing
- ✓ Dashboard serialization (JSON/.m export) — existing
- ✓ Theming (light/dark, custom colors) — existing
- ✓ Live data refresh via DashboardEngine timer — existing
- ✓ GroupWidget for basic widget grouping — existing
- ✓ DashboardToolbar with global controls — existing
- ✓ WebBridge for browser-based visualization — existing

### Active

- [ ] Tabbed layout sections — group widgets into switchable tabs within a dashboard
- [ ] Collapsible sections — expand/collapse widget groups to manage screen real estate
- [ ] Multi-page dashboards — navigate between distinct dashboard pages
- [ ] Widget info tooltips — small info icon in widget header, click/hover shows user-written description text
- [ ] Detachable widgets — button on widget to clone into a separate MATLAB figure window
- [ ] Live-mirrored detached widgets — detached figures stay synced with dashboard data updates
- [ ] Nested layout serialization — tabs/collapse/pages persist through save/load cycle

### Out of Scope

- Drag-and-drop visual rearrangement — complexity vs. value for MATLAB-script-driven workflows
- Cross-filtering between widgets — not requested, would require a data binding framework
- Interactive controls (dropdowns, sliders) driving widget data — not requested for this milestone
- New widget types — current 20+ types are sufficient
- Browser/WebBridge updates for new features — focus on native MATLAB dashboard first

## Context

- FastSense is a MATLAB library for high-performance time series visualization with sensor/threshold modeling
- Dashboard engine (`libs/Dashboard/`) already has DashboardEngine, DashboardWidget base class, DashboardLayout (24-col grid), DashboardSerializer, DashboardTheme, DashboardBuilder
- GroupWidget already provides basic widget grouping — tabs/collapsible sections extend this concept
- All widgets inherit from DashboardWidget which defines the render/update lifecycle
- DashboardSerializer handles JSON round-tripping — new layout types must integrate with this
- Live refresh is timer-driven via DashboardEngine — detached widgets need to hook into this

## Constraints

- **Tech stack**: Pure MATLAB (no external dependencies) — consistent with existing codebase
- **Backward compatibility**: Existing dashboard scripts and serialized dashboards must continue to work
- **Widget contract**: New features must work through the existing DashboardWidget base class interface
- **Performance**: Detached live-mirrored widgets must not degrade dashboard refresh rate

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Extend GroupWidget for tabs/collapsible | GroupWidget already handles widget containment | — Pending |
| Info tooltip via widget header icon | Minimal UI footprint, consistent placement | — Pending |
| Live mirror via DashboardEngine timer | Reuse existing refresh infrastructure | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-01 after initialization*
