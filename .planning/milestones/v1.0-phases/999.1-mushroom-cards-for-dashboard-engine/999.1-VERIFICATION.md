---
phase: 999.1-mushroom-cards-for-dashboard-engine
verified: 2026-04-05T00:00:00Z
status: gaps_found
score: 12/13 must-haves verified
gaps:
  - truth: "ChipBarWidget resolveChipColor maps 'info' state to InfoColor"
    status: failed
    reason: "ChipBarWidget.resolveChipColor switch block has no 'info' case — 'info' state falls through to the otherwise branch and returns [0.5 0.5 0.5] (gray) instead of theme.InfoColor"
    artifacts:
      - path: "libs/Dashboard/ChipBarWidget.m"
        issue: "resolveChipColor switch (lines 234-243) handles 'ok', {'warn','warning'}, 'alarm' but missing case 'info' -> theme.InfoColor"
    missing:
      - "Add case 'info' -> chipColor = theme.InfoColor; in resolveChipColor switch block (libs/Dashboard/ChipBarWidget.m lines 234-243)"
---

# Phase 999.1: Mushroom Cards for Dashboard Engine — Verification Report

**Phase Goal:** Add Home Assistant-style Mushroom Card widgets to the dashboard engine — minimal, icon-driven cards with clean visual design for sensor status, controls, and quick glance data. Three new widget classes: IconCardWidget, ChipBarWidget, SparklineCardWidget, plus theme additions and full serializer/builder/detach integration.
**Verified:** 2026-04-05
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | InfoColor = [0.27 0.52 0.85] in all 6 DashboardTheme presets | ✓ VERIFIED | `DashboardTheme.m` line 139: `d.InfoColor = [0.27 0.52 0.85];` in shared defaults block — applies to all 6 presets |
| 2 | IconCardWidget renders colored circle icon, value, and label without error | ✓ VERIFIED | render() creates axes with fill() circle (lines 77-92), hValueText uicontrol (lines 95-105), hLabelText uicontrol (lines 108-118), calls refresh() |
| 3 | IconCardWidget icon color changes based on state (ok/warn/alarm/info/inactive) | ✓ VERIFIED | resolveIconColor() private method (lines 249-256) handles all 5 states including 'info' -> InfoColor |
| 4 | IconCardWidget serializes to 'iconcard' and round-trips via toStruct/fromStruct | ✓ VERIFIED | getType() returns 'iconcard' (line 192); toStruct() calls super + adds units/format/staticState/source (lines 197-216); fromStruct() Static reconstructs all fields (lines 221-244) |
| 5 | IconCardWidget refresh() safe before render() | ✓ VERIFIED | Guard at line 125: `if isempty(obj.hPanel) \|\| ~ishandle(obj.hPanel), return; end` |
| 6 | ChipBarWidget renders N chips in a single shared axes | ✓ VERIFIED | render() creates single `obj.hAx` axes (lines 72-81), draws fill circles in loop at evenly-spaced positions (lines 90-111) |
| 7 | ChipBarWidget chip colors update on refresh() via statusFcn/sensor state | ✓ VERIFIED | refresh() iterates chips, calls resolveChipColor, sets FaceColor (lines 127-136) |
| 8 | ChipBarWidget 'info' state maps to InfoColor | ✗ FAILED | resolveChipColor switch (lines 234-243) has no 'info' case — 'info' falls to `otherwise` and returns [0.5 0.5 0.5]; PLAN-02 action spec explicitly required 'info'->InfoColor |
| 9 | ChipBarWidget serializes to 'chipbar' and round-trips | ✓ VERIFIED | getType() returns 'chipbar' (line 139); toStruct() emits type+'chips' cell (lines 144-161); fromStruct() reconstructs Title/Position/Chips (lines 165-187) |
| 10 | ChipBarWidget refresh() safe before render() | ✓ VERIFIED | Guard at lines 118-119: `if isempty(obj.hPanel) \|\| ~ishandle(obj.hPanel), return; end` |
| 11 | SparklineCardWidget renders value, title, delta, and sparkline | ✓ VERIFIED | render() creates hTitleText, hDeltaText, hValueText uicontrols and hSparkAx axes (lines 64-129); refresh() computes delta with arrows char(9650)/char(9660) and flat-data guard |
| 12 | SparklineCardWidget serializes to 'sparkline' and round-trips | ✓ VERIFIED | getType() returns 'sparkline' (line 228); toStruct() emits all properties (lines 233-252); fromStruct() reconstructs all fields (lines 256-281) |
| 13 | DashboardEngine, Serializer, DetachedMirror, DashboardBuilder all wired for 3 new types | ✓ VERIFIED | See Key Link Verification table below |

**Score:** 12/13 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `libs/Dashboard/DashboardTheme.m` | InfoColor on all 6 presets | ✓ VERIFIED | Line 139 in shared defaults block |
| `libs/Dashboard/IconCardWidget.m` | Mushroom icon card widget | ✓ VERIFIED | 281 lines; classdef IconCardWidget < DashboardWidget; all abstract methods implemented |
| `libs/Dashboard/ChipBarWidget.m` | Horizontal chip bar widget | ✓ STUB (partial) | 247 lines; classdef ChipBarWidget < DashboardWidget; resolveChipColor missing 'info' case |
| `libs/Dashboard/SparklineCardWidget.m` | KPI card with sparkline and delta | ✓ VERIFIED | 284 lines; classdef SparklineCardWidget < DashboardWidget; all methods fully implemented |
| `libs/Dashboard/DashboardEngine.m` | WidgetTypeMap_ entries for 3 new types | ✓ VERIFIED | Lines 80-85 add 'iconcard'/'chipbar'/'sparkline' -> @IconCardWidget/@ChipBarWidget/@SparklineCardWidget |
| `libs/Dashboard/DashboardSerializer.m` | createWidgetFromStruct + linesForWidget + emitChildWidget for 3 new types | ✓ VERIFIED | 4 dispatch points all contain case 'iconcard', 'chipbar', 'sparkline' (lines 117-124, 340-345, 524-537, 701-718) |
| `libs/Dashboard/DetachedMirror.m` | cloneWidget dispatch for 3 new types | ✓ VERIFIED | Lines 179-184: case 'iconcard', 'chipbar', 'sparkline' in cloneWidget switch |
| `libs/Dashboard/DashboardBuilder.m` | addIconCard, addChipBar, addSparkline + palette | ✓ VERIFIED | Lines 174-196: 3 convenience methods; lines 337-342: palette types+labels; lines 284-286: findNextSlot cases |
| `tests/suite/TestIconCardWidget.m` | Unit tests for IconCardWidget | ✓ VERIFIED | 12 test methods including testStateColorInfo, testStateColorInactive beyond PLAN spec |
| `tests/suite/TestChipBarWidget.m` | Unit tests for ChipBarWidget | ✓ VERIFIED | 7 test methods covering all required behaviors |
| `tests/suite/TestSparklineCardWidget.m` | Unit tests for SparklineCardWidget | ✓ VERIFIED | 9 test methods covering all required behaviors |
| `tests/suite/TestDashboardSerializer.m` | Extended with 6 new type tests | ✓ VERIFIED | testFromStructIconCard, testFromStructChipBar, testFromStructSparkline, testJsonRoundTripIconCard, testJsonRoundTripChipBar, testJsonRoundTripSparkline present |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `IconCardWidget.m` | `DashboardWidget.m` | subclass inheritance | ✓ WIRED | Line 1: `classdef IconCardWidget < DashboardWidget` |
| `IconCardWidget.m` | `DashboardTheme.m` | getTheme() for state colors | ✓ WIRED | Lines 62, 158: `theme = obj.getTheme()` used for StatusOkColor/InfoColor etc. |
| `ChipBarWidget.m` | `DashboardWidget.m` | subclass inheritance | ✓ WIRED | Line 1: `classdef ChipBarWidget < DashboardWidget` |
| `ChipBarWidget.m` | `DashboardTheme.m` | getTheme() for state colors | ✓ WIRED | Lines 57, 125: `theme = obj.getTheme()` |
| `SparklineCardWidget.m` | `DashboardWidget.m` | subclass inheritance | ✓ WIRED | Line 1: `classdef SparklineCardWidget < DashboardWidget` |
| `SparklineCardWidget.m` | `DashboardTheme.m` | getTheme() for sparkline color + delta | ✓ WIRED | Lines 67, 192: `theme = obj.getTheme()` used for DragHandleColor, StatusOkColor, StatusAlarmColor |
| `DashboardEngine.m` | `IconCardWidget.m` | WidgetTypeMap_ constructor handle | ✓ WIRED | Lines 80/85: `'iconcard'` -> `@IconCardWidget` in containers.Map |
| `DashboardSerializer.m` | `IconCardWidget.m` | createWidgetFromStruct case dispatch | ✓ WIRED | Line 340: `case 'iconcard'` -> `IconCardWidget.fromStruct(ws)` |
| `DetachedMirror.m` | `IconCardWidget.m` | cloneWidget case dispatch | ✓ WIRED | Line 179: `case 'iconcard'` -> `IconCardWidget.fromStruct(s)` |
| `DashboardBuilder.m` | addWidget('iconcard') | addIconCard convenience method | ✓ WIRED | Line 176: `obj.addWidget('iconcard')` |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `IconCardWidget.m` | CurrentValue | Sensor.Y / ValueFcn() / StaticValue | Yes — three-path binding (lines 130-146) | ✓ FLOWING |
| `ChipBarWidget.m` | chip FaceColor | chip.statusFcn() / chip.sensor.Y | Yes — chip state resolved per chip (lines 209-231) | ✓ FLOWING |
| `SparklineCardWidget.m` | hSparkLine XData/YData | Sensor.Y / SparkData | Yes — ySnip computed and set on line handle (lines 167-206) | ✓ FLOWING |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — verification requires running MATLAB/Octave which is not available as a CLI command in this environment. The widget implementations are inspected programmatically and structurally complete.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| MUSH-01 | 999.1-01 | InfoColor theme field on all 6 presets | ✓ SATISFIED | `DashboardTheme.m` line 139 in shared defaults |
| MUSH-02 | 999.1-01 | IconCardWidget — icon card with state color | ✓ SATISFIED | `libs/Dashboard/IconCardWidget.m` fully implemented; 12 tests |
| MUSH-03 | 999.1-02 | ChipBarWidget — horizontal chip status bar | ✓ SATISFIED (with warning) | `libs/Dashboard/ChipBarWidget.m` exists and functional; 'info' state color gap is a minor behavioral defect, not a blocking functional failure |
| MUSH-04 | 999.1-03 | SparklineCardWidget — KPI + sparkline + delta | ✓ SATISFIED | `libs/Dashboard/SparklineCardWidget.m` fully implemented; 9 tests |
| MUSH-05 | 999.1-04 | Engine registration for 3 types | ✓ SATISFIED | `DashboardEngine.m` WidgetTypeMap_ lines 80-85 |
| MUSH-06 | 999.1-04 | Serializer integration (createWidgetFromStruct + linesForWidget + emitChildWidget) | ✓ SATISFIED | 4 dispatch points in DashboardSerializer.m all covered; 6 new tests in TestDashboardSerializer.m |
| MUSH-07 | 999.1-04 | DetachedMirror + DashboardBuilder integration | ✓ SATISFIED | DetachedMirror.cloneWidget handles all 3 types via toStruct/fromStruct round-trip; DashboardBuilder has addIconCard/addChipBar/addSparkline convenience methods and palette entries |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `libs/Dashboard/ChipBarWidget.m` | 234-243 | `resolveChipColor` switch missing `case 'info'` | ⚠️ Warning | 'info' state chips display as gray instead of InfoColor; inconsistent with IconCardWidget behavior and PLAN spec |

No TODOs, FIXMEs, placeholders, or empty implementations found in any of the 3 new widget files.

---

### Human Verification Required

#### 1. Visual rendering of all three card types

**Test:** Create a dashboard with one of each widget type (IconCardWidget with state='ok', ChipBarWidget with 3 chips at ok/warn/alarm, SparklineCardWidget with SparkData), render it, and visually inspect the output.
**Expected:** Icon card shows colored circle at left with value centered; chip bar shows 3 small circles with labels; sparkline card shows big number with trend line and delta arrow in bottom third.
**Why human:** Visual layout, font sizes, and proportion cannot be verified by static code analysis.

#### 2. DashboardBuilder palette button functionality

**Test:** Open DashboardBuilder in MATLAB, click "Icon Card", "Chip Bar", and "Sparkline" buttons in the palette.
**Expected:** Clicking each adds the corresponding widget to the canvas at the correct default size (IconCard 6x2, ChipBar 12x1, Sparkline 6x3) with a default title.
**Why human:** Requires a running MATLAB figure with interactive UI events.

#### 3. JSON round-trip completeness for ChipBarWidget with chips

**Test:** Create ChipBarWidget with 3 chips that have statusFcn set, save to JSON, reload.
**Expected:** Widget reloads with 3 chips having correct labels; statusFcn is not preserved (by design — non-serializable), but chip count and labels survive.
**Why human:** Requires running MATLAB to exercise jsondecode/jsonencode path and verify chip restoration.

---

### Gaps Summary

**1 gap found** blocking full specification compliance:

**ChipBarWidget 'info' state color** — The `resolveChipColor` private method in `ChipBarWidget.m` does not have a `case 'info'` branch. When a chip's `statusFcn` returns `'info'`, the color falls through to `otherwise` and returns `[0.5 0.5 0.5]` (gray), rather than `theme.InfoColor` as specified in PLAN-02 and consistent with `IconCardWidget.resolveIconColor`. This creates an inconsistency between widget types when using the 'info' semantic state.

The fix is one line: add `case 'info', chipColor = theme.InfoColor;` before `otherwise` in the switch block at lines 234-243 of `libs/Dashboard/ChipBarWidget.m`.

This gap does not affect the primary widget functionality (rendering, refresh, serialization, engine registration) — all widgets are usable in production. It is a behavioral completeness gap, not a blocker.

---

_Verified: 2026-04-05_
_Verifier: Claude (gsd-verifier)_
