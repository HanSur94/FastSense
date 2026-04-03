# Phase 9: Threshold Mini-Labels in FastSense Plots - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Add optional small inline text labels within FastSense plot axes that display the name of each threshold line, so users can identify thresholds at a glance without relying on legends or tooltips. Labels are opt-in via a new `ShowThresholdLabels` property on both FastSense and FastSenseWidget.

</domain>

<decisions>
## Implementation Decisions

### Label Appearance
- Font size: 8pt fixed — small enough to not obscure data, large enough to read
- Text color: matches the threshold line's color — instant visual association
- Background: semi-transparent patch matching axes background color — prevents blending into plot data
- Font weight: normal (not bold) — keeps labels unobtrusive

### Label Placement
- Horizontal position: right edge of the visible axes
- Vertical position: directly on the threshold line, vertically centered
- No overlap handling — let MATLAB stack naturally (overlapping thresholds are rare)
- Labels reposition on zoom/pan — stay at current right edge of visible axes

### Opt-In API & Integration
- New property `ShowThresholdLabels` on FastSense (default false) — opt-in, backward compatible
- FastSenseWidget also exposes `ShowThresholdLabels`, serialized in toStruct/fromStruct
- Label text comes from the threshold's existing `Label` property; falls back to "Threshold N" if empty
- Labels update (reposition) on each refresh tick to stay aligned with axes limits after zoom/pan/live update

### Claude's Discretion
- Implementation details of the MATLAB text object creation and positioning
- How to store hText handles on the Thresholds struct
- Exact semi-transparent background implementation (MATLAB text BackgroundColor + EdgeColor)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `FastSense.Thresholds` struct array with fields: Value, X, Y, Direction, ShowViolations, Color, LineStyle, Label, hLine, hMarkers
- `FastSense.Theme` has ThresholdColor, ThresholdStyle, FontSize, FontName — can derive label styling
- `parseOpts()` shared helper for name-value pair parsing
- `FastSenseWidget.toStruct/fromStruct` pattern for serialization

### Established Patterns
- Threshold rendering happens in the render() method around line 1180 — creates hLine handles stored on Thresholds struct
- Scalar thresholds extend across full X range; time-varying use X/Y vectors
- Line handles stored as `Thresholds(t).hLine` for later update
- Threshold X-extent updated in the update loop (~line 2917) to match current xlim
- UserData on threshold lines stores metadata: Type='threshold', Name=Label, ThresholdValue
- `resolveThresholdStyle()` fills default color/style from theme

### Integration Points
- Label creation: alongside hLine creation in render() (~line 1180-1201)
- Label repositioning: in the update/refresh path where Thresholds hLine XData is updated (~line 2917)
- FastSenseWidget.render() calls fp.addSensor() which calls addThreshold() — labels flow through naturally
- FastSenseWidget.toStruct/fromStruct for serialization of ShowThresholdLabels

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following the established threshold rendering pattern.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
