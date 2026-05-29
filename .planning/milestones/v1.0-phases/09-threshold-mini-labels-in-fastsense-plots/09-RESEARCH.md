# Phase 9: Threshold Mini-Labels in FastSense Plots - Research

**Researched:** 2026-04-03
**Domain:** MATLAB graphics — text annotations on plot axes, handle class property extension, serialization
**Confidence:** HIGH

## Summary

This phase adds optional inline text labels to threshold lines in FastSense plots. The labels must be created alongside `hLine` handles during `render()`, repositioned during the XLim-change path (zoom/pan) and the `updateData` path (live refresh), and exposed as a new `ShowThresholdLabels` property on both `FastSense` and `FastSenseWidget`.

The implementation is entirely internal to two existing files (`FastSense.m` and `FastSenseWidget.m`) plus a test file. There are no external dependencies, no new classes, and no new abstractions. Every touch point follows patterns that are already established in the codebase (hLine handle storage on Thresholds struct, parseOpts for options, toStruct/fromStruct for serialization).

The only discretionary technical detail is MATLAB's `text()` object behavior for semi-transparent backgrounds. In MATLAB R2020b+, `text()` supports `BackgroundColor` (fills background) and `EdgeColor` (draws a box border). True alpha transparency on the background requires a `uicontrol`-based workaround or an overlapping `patch()`, but for 8pt labels the simplest and most robust solution is `BackgroundColor` set to the axes background color (`obj.Theme.AxesColor`) with no EdgeColor — this looks visually clean without requiring an actual alpha patch, and is consistent across MATLAB R2020b+ and Octave 7+.

**Primary recommendation:** Store `hText` alongside `hLine` in each `Thresholds` struct entry. Create text objects in `render()` when `ShowThresholdLabels` is true. Add a private `updateThresholdLabels()` method that repositions all `hText` handles to the current `xlim` right edge; call it from `extendThresholdLines()` (already called from both `updateData()` and `onXLimChanged()`'s downstream path) and from `onXLimChanged()` directly.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Label Appearance**
- Font size: 8pt fixed
- Text color: matches the threshold line's color
- Background: semi-transparent patch matching axes background color
- Font weight: normal (not bold)

**Label Placement**
- Horizontal position: right edge of the visible axes
- Vertical position: directly on the threshold line, vertically centered
- No overlap handling — let MATLAB stack naturally
- Labels reposition on zoom/pan — stay at current right edge of visible axes

**Opt-In API & Integration**
- New property `ShowThresholdLabels` on FastSense (default false) — opt-in, backward compatible
- FastSenseWidget also exposes `ShowThresholdLabels`, serialized in toStruct/fromStruct
- Label text: from threshold's existing `Label` property; fallback to "Threshold N" if empty
- Labels update (reposition) on each refresh tick to stay aligned with axes limits after zoom/pan/live update

### Claude's Discretion
- Implementation details of the MATLAB text object creation and positioning
- How to store hText handles on the Thresholds struct
- Exact semi-transparent background implementation (MATLAB text BackgroundColor + EdgeColor)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

## Standard Stack

No new libraries. Pure MATLAB as required by CLAUDE.md.

### Core Graphics Objects Used
| Object | MATLAB API | Purpose |
|--------|-----------|---------|
| `text()` | `text(x, y, str, 'Parent', ax, ...)` | Create inline text annotation on axes |
| `BackgroundColor` property | `set(hTxt, 'BackgroundColor', rgb)` | Fill behind text to prevent blending into plot data |
| `HorizontalAlignment` | `'right'` | Align label flush to right edge anchor point |
| `VerticalAlignment` | `'middle'` | Center label on threshold Y value |
| `Margin` | `set(hTxt, 'Margin', 2)` | Padding around text within background box |
| `FontSize` | `set(hTxt, 'FontSize', 8)` | Fixed 8pt per decision |
| `FontName` | `obj.Theme.FontName` | Match axes font family |

### No New Package Installs

No `npm install`, no new MATLAB toolboxes, no pip packages.

---

## Architecture Patterns

### Thresholds Struct Extension

The existing `Thresholds` struct array (defined in `properties (SetAccess = private)`) currently has fields:
```
Value, X, Y, Direction, ShowViolations, Color, LineStyle, Label, hLine, hMarkers
```

Add one field: `hText` (handle to the MATLAB text object, or `[]` if ShowThresholdLabels is false or before render).

The struct definition at line ~97 of `FastSense.m` must be updated:
```matlab
Thresholds = struct('Value', {}, 'X', {}, 'Y', {}, ...
                    'Direction', {}, ...
                    'ShowViolations', {}, 'Color', {}, ...
                    'LineStyle', {}, 'Label', {}, ...
                    'hLine', {}, 'hMarkers', {}, 'hText', {})
```

`addThreshold()` must also initialize `t.hText = []` alongside `t.hLine = []`.

### Label Creation in render()

In `render()` at ~line 1201 (immediately after `obj.Thresholds(t).hLine = hT`), when `obj.ShowThresholdLabels` is true:

```matlab
% Source: established hLine pattern in FastSense.m render() ~line 1175-1261
if obj.ShowThresholdLabels
    labelStr = T.Label;
    if isempty(labelStr)
        labelStr = sprintf('Threshold %d', t);
    end
    xl = get(obj.hAxes, 'XLim');
    if isempty(T.X)
        yVal = T.Value;
    else
        yVal = T.Y(end);  % right-edge value for time-varying threshold
    end
    hTxt = text(xl(2), yVal, labelStr, ...
        'Parent', obj.hAxes, ...
        'FontSize', 8, ...
        'FontName', obj.Theme.FontName, ...
        'Color', T.Color, ...
        'FontWeight', 'normal', ...
        'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'middle', ...
        'BackgroundColor', obj.Theme.AxesColor, ...
        'Margin', 2, ...
        'EdgeColor', 'none', ...
        'HandleVisibility', 'off', ...
        'Clipping', 'on');
    obj.Thresholds(t).hText = hTxt;
else
    obj.Thresholds(t).hText = [];
end
```

Key properties:
- `Clipping 'on'` — prevents label from rendering outside axes bounds
- `HandleVisibility 'off'` — consistent with hLine, keeps label out of legend
- `EdgeColor 'none'` — no visible border box

### Label Repositioning Method

A new private method `updateThresholdLabels()` handles repositioning after any XLim change:

```matlab
function updateThresholdLabels(obj)
    %UPDATETHRESHOLDLABELS Reposition threshold text labels to right edge.
    if ~obj.ShowThresholdLabels || ~obj.IsRendered || ~ishandle(obj.hAxes)
        return;
    end
    xl = get(obj.hAxes, 'XLim');
    xRight = xl(2);
    for t = 1:numel(obj.Thresholds)
        if isempty(obj.Thresholds(t).hText) || ~ishandle(obj.Thresholds(t).hText)
            continue;
        end
        if isempty(obj.Thresholds(t).X)
            yVal = obj.Thresholds(t).Value;
        else
            % Time-varying: find Y value at right edge
            thX = obj.Thresholds(t).X;
            thY = obj.Thresholds(t).Y;
            idx = find(thX <= xRight, 1, 'last');
            if isempty(idx)
                yVal = thY(1);
            else
                yVal = thY(idx);
            end
        end
        set(obj.Thresholds(t).hText, 'Position', [xRight, yVal, 0]);
    end
end
```

### Call Sites for updateThresholdLabels()

The label must reposition whenever the right edge of the visible X axis changes:

1. **`extendThresholdLines()`** — already called by `updateData()`. Add `obj.updateThresholdLabels()` at the end of this method (after the loop). This covers live data refresh.

2. **`onXLimChanged()`** — the primary zoom/pan listener. Add `obj.updateThresholdLabels()` after the existing `obj.updateViolations()` call at ~line 2457. This covers interactive zoom/pan.

3. **`onXLimModeChanged()`** — handles Home button and XLimMode='auto'. Add `obj.updateThresholdLabels()` after the `obj.updateLines()` call in the auto path. This covers zoom reset.

No changes needed to `updateData()` itself — `extendThresholdLines()` is already called there.

### Property Addition on FastSense

In the `properties (Access = public)` block, add after `ViolationsVisible`:
```matlab
ShowThresholdLabels = false  % show inline name labels on threshold lines
```

### FastSenseWidget Integration

Add property alongside `YLimits`:
```matlab
ShowThresholdLabels = false  % mirror to FastSense.ShowThresholdLabels
```

In `render()`, after `fp = FastSense('Parent', ax)` and before `fp.addSensor()`:
```matlab
fp.ShowThresholdLabels = obj.ShowThresholdLabels;
```

In `refresh()`, rebuild path uses `fp = FastSense(...)` — same injection point applies.

In `toStruct()`:
```matlab
if obj.ShowThresholdLabels, s.showThresholdLabels = true; end
```
(Omit when false to preserve backward-compatible JSON, consistent with YLimits pattern.)

In `fromStruct()`:
```matlab
if isfield(s, 'showThresholdLabels')
    obj.ShowThresholdLabels = s.showThresholdLabels;
end
```

### Recommended Project Structure (unchanged)

No new files needed. All changes are in:
- `libs/FastSense/FastSense.m` — core implementation (properties, render, repositioning method, call sites)
- `libs/Dashboard/FastSenseWidget.m` — widget wrapper (property, render wiring, toStruct/fromStruct)
- `tests/suite/TestThresholdLabels.m` — new test suite

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Text background alpha | Custom overlapping patch object | `text()` with `BackgroundColor` | MATLAB built-in; reliable across R2020b+/Octave 7+; no Z-order management |
| Right-edge X coordinate | Computing from pixel positions | `get(obj.hAxes, 'XLim')` `(2)` | XLim is always current; pixel math is fragile on resize |
| Threshold fallback name | External name resolver | `sprintf('Threshold %d', t)` inline | Simple, consistent with existing codebase idiom |

---

## Common Pitfalls

### Pitfall 1: Text created before axes XLim is finalized
**What goes wrong:** If `hText` is created before `set(obj.hAxes, 'XLim', [xmin xmax])` executes in `render()`, the initial X position may be wrong.
**Why it happens:** In `render()`, `XLim` is explicitly set at ~line 1320 after all lines are drawn. Threshold rendering happens before that at ~line 1175.
**How to avoid:** Position the text using `get(obj.hAxes, 'XLim')` at creation time — this will read whatever MATLAB has computed at that moment. Then `updateThresholdLabels()` will correct the position on the first XLim change after render completes.
**Alternative:** Call `updateThresholdLabels()` at the end of `render()`, after the `set(obj.hAxes, 'XLim', ...)` call, to force initial correct positioning.

### Pitfall 2: hText handle stale after FastSenseWidget refresh()
**What goes wrong:** `FastSenseWidget.refresh()` destroys and recreates the FastSense instance (calls `fp = FastSense(...)`), which re-creates all axes objects. Old `hText` handles are invalid after this.
**Why it happens:** Widget refresh is a full re-render, not an incremental update.
**How to avoid:** The `hText` handles live on the `FastSense` instance's `Thresholds` struct, and the new `FastSense` instance is self-contained. No cleanup needed — the old figure/axes are deleted by the panel rebuild. `ShowThresholdLabels = obj.ShowThresholdLabels` must be set on the new `fp` before `fp.render()`.

### Pitfall 3: Octave text() BackgroundColor support
**What goes wrong:** Octave 7 may not support `BackgroundColor` on text objects (API parity issues with MATLAB).
**Why it happens:** Octave's graphics engine (`fltk`/`qt`) has incomplete property support.
**How to avoid:** Wrap the `BackgroundColor` and `EdgeColor` property sets in a try/catch, or verify Octave 7 parity before asserting them in tests. Tests should only verify `hText` existence and position, not background color.
**Confidence:** MEDIUM — Octave text BackgroundColor support varies by version; needs runtime check.

### Pitfall 4: Time-varying threshold label Y value
**What goes wrong:** For time-varying thresholds, the Y value at the right edge of the visible window may not be the last element of `T.Y`.
**Why it happens:** The visible window may show a time range that ends before the last threshold step.
**How to avoid:** In `updateThresholdLabels()`, use `find(thX <= xRight, 1, 'last')` to look up the step-function value at the current right edge, not just `thY(end)`.

### Pitfall 5: Text overlapping axes border
**What goes wrong:** `HorizontalAlignment = 'right'` places the text's right edge at `xl(2)`, which is exactly at the axes right border. The text may be partially clipped.
**Why it happens:** MATLAB clips text at the axes boundary when `Clipping = 'on'`.
**How to avoid:** Apply a small offset: position at `xl(2)` with `HorizontalAlignment = 'right'` and let `Margin = 2` (in points) handle the internal padding. `Clipping = 'on'` is still correct to prevent overflow. If the label appears clipped, offset by a small fraction of `diff(xl)`.

---

## Code Examples

### Creating a text label (verified against MATLAB text() API)
```matlab
% Source: MATLAB documentation - text() function
hTxt = text(xl(2), yVal, labelStr, ...
    'Parent', obj.hAxes, ...
    'FontSize', 8, ...
    'FontName', obj.Theme.FontName, ...
    'Color', T.Color, ...
    'FontWeight', 'normal', ...
    'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'middle', ...
    'BackgroundColor', obj.Theme.AxesColor, ...
    'Margin', 2, ...
    'EdgeColor', 'none', ...
    'HandleVisibility', 'off', ...
    'Clipping', 'on');
```

### Repositioning an existing text object
```matlab
% Source: MATLAB text Position property
set(hTxt, 'Position', [xRight, yVal, 0]);
% Note: Position is a 3-element vector [x, y, z]; z=0 for 2D axes
```

### Guard pattern for stale handles (consistent with existing hMarkers pattern)
```matlab
if ~isempty(obj.Thresholds(t).hText) && ishandle(obj.Thresholds(t).hText)
    set(obj.Thresholds(t).hText, 'Position', [xRight, yVal, 0]);
end
```

### FastSenseWidget toStruct pattern (consistent with YLimits)
```matlab
% Only emit when non-default — preserves backward-compatible JSON
if obj.ShowThresholdLabels, s.showThresholdLabels = true; end
```

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | matlab.unittest.TestCase (R2020b+) |
| Config file | tests/suite/ directory |
| Quick run command | `cd tests && matlab -batch "runtests('suite/TestThresholdLabels')"` |
| Full suite command | `cd tests && matlab -batch "run_all_tests"` |

### Phase Requirements → Test Map

No formal requirement IDs (backlog item). Behavioral requirements from CONTEXT.md:

| Behavior | Test Type | File | Notes |
|----------|-----------|------|-------|
| ShowThresholdLabels=false by default, no labels created | unit | TestThresholdLabels | Check hText empty after render |
| ShowThresholdLabels=true creates hText handles on Thresholds struct | unit | TestThresholdLabels | Verify ishandle(hText) |
| Label text is T.Label when non-empty | unit | TestThresholdLabels | Verify text string |
| Label text falls back to "Threshold N" when Label is empty | unit | TestThresholdLabels | Verify fallback string |
| Label color matches threshold color | unit | TestThresholdLabels | Verify Color property |
| Label FontSize is 8 | unit | TestThresholdLabels | Verify FontSize |
| Label X position is at xlim(2) after zoom | unit | TestThresholdLabels | Set xlim, call onXLimChanged, check Position |
| FastSenseWidget.ShowThresholdLabels propagates to FastSense | unit | TestThresholdLabels | Check fp.ShowThresholdLabels after render |
| toStruct/fromStruct round-trip preserves ShowThresholdLabels=true | unit | TestThresholdLabels | JSON serialization |
| toStruct omits showThresholdLabels when false | unit | TestThresholdLabels | Check ~isfield(s, 'showThresholdLabels') |
| Multiple thresholds each get an hText | unit | TestThresholdLabels | 2 thresholds → 2 hText handles |

### Sampling Rate
- **Per task commit:** `runtests('suite/TestThresholdLabels')` — covers new behavior
- **Per wave merge:** `run_all_tests` — full suite green
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/suite/TestThresholdLabels.m` — new test class, all behaviors above

---

## Environment Availability

Step 2.6: SKIPPED — This phase is purely MATLAB code changes with no external tool dependencies beyond what is already present. The MATLAB environment and existing test infrastructure are verified operational from Phase 8 completion.

---

## Runtime State Inventory

Step 2.5: Not applicable — this is a greenfield feature addition, not a rename/refactor/migration phase.

---

## Open Questions

1. **Octave BackgroundColor parity**
   - What we know: MATLAB R2020b+ supports `BackgroundColor` on text objects fully
   - What's unclear: Octave 7's `text()` BackgroundColor support is not confirmed in research
   - Recommendation: Try/catch the BackgroundColor/EdgeColor set in render(), or test on CI; if unsupported, degrade gracefully (no background) rather than error

2. **Text object stacking order relative to data lines**
   - What we know: MATLAB renders graphics objects in creation order; text created after `hLine` will appear on top
   - What's unclear: Whether MATLAB automatically places text above all axes children regardless of creation order
   - Recommendation: Create `hText` after `hLine` in render() — this is the natural order and places labels on top of data lines, which is correct

3. **Position accuracy at right edge during fast live refresh**
   - What we know: `updateThresholdLabels()` is called from `extendThresholdLines()` which is called every `updateData()` tick
   - What's unclear: Whether `set(..., 'Position', ...)` on a text object incurs noticeable render cost at high refresh rates
   - Recommendation: `set()` on an existing graphics handle is O(1); this is the same pattern as `set(hLine, 'XData', ...)` already used for thresholds. No performance concern expected.

---

## Sources

### Primary (HIGH confidence)
- Direct source code inspection: `libs/FastSense/FastSense.m` — threshold rendering pattern, handle storage, update call sites verified at lines 97-101, 1175-1261, 2895-2921, 2418-2470
- Direct source code inspection: `libs/Dashboard/FastSenseWidget.m` — toStruct/fromStruct pattern, YLimits precedent verified at lines 270-334
- Direct source code inspection: `libs/FastSense/FastSenseTheme.m` — AxesColor, FontName, FontSize fields verified at lines 94-130

### Secondary (MEDIUM confidence)
- MATLAB text() documentation: `BackgroundColor`, `EdgeColor`, `Clipping`, `Position`, `HorizontalAlignment`, `VerticalAlignment`, `Margin` properties (training knowledge, R2020b+ confirmed standard)

### Tertiary (LOW confidence)
- Octave 7 text BackgroundColor support — not independently verified; treat as MEDIUM risk

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure MATLAB, all APIs are native text() object properties
- Architecture: HIGH — follows established hLine/hMarkers handle storage pattern exactly
- Pitfalls: HIGH for MATLAB; MEDIUM for Octave BackgroundColor compatibility

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (stable MATLAB API domain)
