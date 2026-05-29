# Phase 5: Detachable Widgets - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous)

<domain>
## Phase Boundary

Add detach button to every widget header, create DetachedMirror class for standalone figure windows, wire live sync via DashboardEngine timer, implement independent zoom for detached FastSenseWidget, and ensure clean lifecycle (close removes from registry, no stale handle errors).

</domain>

<decisions>
## Implementation Decisions

### Detach Button
- Placed in widget header chrome (like info icon from Phase 3)
- Injected centrally via DashboardLayout.realizeWidget() — no per-widget changes
- Small button with detach/popout icon or text

### DetachedMirror Architecture
- DetachedMirror is a separate handle class (NOT a DashboardWidget subclass)
- Registered in DashboardEngine.DetachedMirrors cell array
- Iterated separately in onLiveTick() — not part of widget grid layout
- Each DetachedMirror owns its own figure window and a cloned widget instance

### Widget Cloning
- Clone via toStruct()/fromStruct() round-trip (same mechanism as serialization)
- FastSenseWidget override: rebind to same Sensor object, set UseGlobalTime = false
- Cloned widget rendered into DetachedMirror's figure panel

### Live Sync
- DashboardEngine.onLiveTick() extended to iterate DetachedMirrors after active page widgets
- Each mirror calls widget.onLiveTick() on its cloned widget
- Stale handle cleanup: check ishandle(mirror.hFigure) before tick, remove if closed

### Lifecycle
- Detached widgets are read-only mirrors (DETACH-07)
- Closing figure window triggers CloseRequestFcn → removes from registry
- Detached state is NOT persisted (SERIAL-04, Phase 6)

### Claude's Discretion
- DetachedMirror internal layout (figure title, panel arrangement)
- Button icon/text style
- Performance optimization for multiple simultaneous detached windows

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DashboardWidget.m` — toStruct()/fromStruct() for widget cloning
- `DashboardLayout.realizeWidget()` — injection point for detach button (Phase 3 pattern)
- `DashboardEngine.onLiveTick()` — timer tick loop to extend
- `FastSenseWidget.m` — UseGlobalTime property for independent zoom
- Phase 3 info icon injection pattern — reuse for detach button

### Established Patterns
- Phase 3: central injection via realizeWidget() for header chrome
- Phase 1: ErrorFcn on timer prevents silent death (protects detach tick errors)
- Phase 2: ReflowCallback injection pattern

### Integration Points
- `DashboardLayout.realizeWidget()` — add detach button alongside info icon
- `DashboardEngine.onLiveTick()` — extend to iterate DetachedMirrors
- `DashboardEngine` — new DetachedMirrors property and detachWidget()/removeDetached() methods

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond ROADMAP success criteria.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
