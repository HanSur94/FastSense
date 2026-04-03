# FastSense Advanced Dashboard

## What This Is

A MATLAB sensor data dashboard engine with nested layout organization (tabs, collapsible groups, multi-page navigation), per-widget info tooltips with Markdown rendering, and detachable live-mirrored widgets that pop out as independent figure windows. Built for MATLAB engineers analyzing sensor data with threshold-based monitoring.

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
- ✓ Timer error recovery (ErrorFcn + auto-restart) — v1.0
- ✓ GroupWidget .m export preserves children — v1.0
- ✓ Shared normalizeToCell helper for jsondecode normalization — v1.0
- ✓ Collapsible sections with grid reflow — v1.0
- ✓ Tab persistence through save/load — v1.0
- ✓ Widget info tooltips with Markdown rendering — v1.0
- ✓ Multi-page dashboards with PageBar navigation — v1.0
- ✓ Active page persistence through save/load — v1.0
- ✓ Detachable live-mirrored widgets — v1.0
- ✓ Independent time axis zoom on detached FastSenseWidget — v1.0
- ✓ Multi-page JSON and .m round-trip serialization — v1.0
- ✓ Collapsed state persistence — v1.0
- ✓ Legacy JSON backward compatibility — v1.0
- ✓ DividerWidget for visual dashboard section separation — v1.0 Phase 8
- ✓ addCollapsible convenience method on DashboardEngine — v1.0 Phase 8
- ✓ Configurable Y-axis limits (YLimits) on FastSenseWidget — v1.0 Phase 8
- ✓ Threshold mini-labels (ShowThresholdLabels) on FastSense and FastSenseWidget — v1.0 Phase 9

### Active

(None — next milestone not yet defined)

### Out of Scope

- Drag-and-drop visual rearrangement — complexity vs. value for MATLAB-script-driven workflows
- Cross-filtering between widgets — would require a data binding framework
- Interactive controls (dropdowns, sliders) — DashboardEngine is visualization, not control panel
- Browser/WebBridge parity for new features — future milestone
- GroupWidget children individual detach buttons — v1 limitation, top-level only
- Time panel in multi-page mode — works on active page only (known limitation)

## Context

- FastSense is a MATLAB library for high-performance time series visualization with sensor/threshold modeling
- Dashboard engine (`libs/Dashboard/`) has DashboardEngine, DashboardWidget (20+ types), DashboardLayout (24-col grid), DashboardSerializer, DashboardTheme, DashboardBuilder, DashboardPage, DetachedMirror, MarkdownRenderer
- v1.0 shipped: 9 phases, 24 plans, 44 requirements, 2948 lines added across 24 files
- New classes added: DashboardPage.m, DetachedMirror.m, DividerWidget.m
- Key patterns established: central injection via realizeWidget(), ReflowCallback for layout updates, DetachCallback for widget pop-out, normalizeToCell for jsondecode safety
- 24,473 LOC MATLAB across libs/ (as of v1.0 completion)
- Known tech debt: 5 items (INFO-03 Markdown downgrade, missing serialization tests, single-page save edge case)

## Constraints

- **Tech stack**: Pure MATLAB (no external dependencies) — consistent with existing codebase
- **Backward compatibility**: Existing dashboard scripts and serialized dashboards continue to work
- **Widget contract**: Features work through the existing DashboardWidget base class interface
- **Performance**: Detached live-mirrored widgets share the engine timer, no extra timers

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Extend GroupWidget for tabs/collapsible | GroupWidget already handles widget containment | ✓ Good |
| Info tooltip via widget header icon | Minimal UI footprint, consistent placement | ✓ Good |
| Live mirror via DashboardEngine timer | Reuse existing refresh infrastructure | ✓ Good |
| Central injection via realizeWidget() | Single choke-point for all 20+ widget types | ✓ Good |
| DetachedMirror as separate class (not DashboardWidget) | Avoids grid layout interference | ✓ Good |
| Clone via toStruct/fromStruct round-trip | Works for all widget types without per-type dispatch | ✓ Good |
| containers.Map for CloseRequestFcn reference | Solves closure-over-cell-array mutation limitation | ✓ Good |
| Plain text popup (HTML stripped) over javacomponent | Cross-platform safe (Octave compatible) | ✓ Good |
| DividerWidget via uipanel not axes | Simpler, no zoom/pan interaction, cheaper render | ✓ Good |
| addCollapsible on DashboardEngine (not DashboardBuilder) | DashboardEngine owns programmatic API | ✓ Good |
| YLimits=[] for auto, [min max] for fixed | Consistent with MATLAB ylim() convention | ✓ Good |
| ShowThresholdLabels opt-in (default false) | Backward compatible; labels only when explicitly requested | ✓ Good |
| Threshold label at right edge, repositions on zoom/pan | Always visible in view, doesn't move with data | ✓ Good |

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
*Last updated: 2026-04-03 after v1.0 milestone complete (9 phases, 24 plans shipped)*
