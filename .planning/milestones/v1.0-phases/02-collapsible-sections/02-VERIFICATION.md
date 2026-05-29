---
phase: 02-collapsible-sections
verified: 2026-04-01T00:00:00Z
status: human_needed
score: 4/4 must-haves verified
human_verification:
  - test: "Visually confirm the scientific theme tab contrast — collapse a tabbed GroupWidget under the 'scientific' preset and check whether the active tab reads as visually selected"
    expected: "The active tab should appear distinct from inactive tabs and clearly indicate the selected state to a human viewer"
    why_human: "The scientific preset has TabActiveBg (mean 0.8733) darker than TabInactiveBg (mean 0.9333) — active tab is semantically inverted relative to convention. The programmatic contrast threshold (0.06 >= 0.05) passes, but human legibility cannot be confirmed without visual inspection."
  - test: "Trigger a collapse on a rendered dashboard and observe that widgets below the collapsed GroupWidget shift upward immediately"
    expected: "The grid reflows visibly in the MATLAB figure window — no blank space remains below the collapsed section"
    why_human: "testCollapseGroupWidgetReflowsGrid verifies rerenderWidgets() is called and hPanel handles survive, but does not assert pixel positions of widgets below the collapsed group"
---

# Phase 2: Collapsible Sections Verification Report

**Phase Goal:** Users can collapse GroupWidget sections to reclaim screen space, with the grid reflowing immediately and the expanded/collapsed state surviving save/load
**Verified:** 2026-04-01
**Status:** human_needed
**Re-verification:** No — initial verification

## Scope Note: Phase Goal vs ROADMAP Success Criteria

The phase goal text includes "the expanded/collapsed state surviving save/load." The ROADMAP success criteria for Phase 2 do NOT include this — collapsed/expanded state persistence is SERIAL-03, assigned to Phase 6. The ROADMAP success criteria (the authoritative contract) are used below. The serialization infrastructure IS in place (GroupWidget.toStruct() serializes `collapsed`, fromStruct() restores it), but no Phase 2 test verifies it end-to-end. This gap is by design and will be covered in Phase 6.

---

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Collapsing a GroupWidget causes widgets below to shift upward | ✓ VERIFIED | ReflowCallback wired in collapse(); DashboardEngine.reflowAfterCollapse() calls rerenderWidgets(); testCollapseGroupWidgetReflowsGrid confirms hPanel is recreated and Collapsed=true |
| 2 | Expanding a collapsed GroupWidget pushes widgets below downward | ✓ VERIFIED | ReflowCallback wired in expand() (same mechanism); testExpandCallsReflowCallback confirms callback fires |
| 3 | Tabbed GroupWidget active tab preserved after JSON round-trip | ✓ VERIFIED | GroupWidget.toStruct() writes `activeTab` field; fromStruct() restores it; testActiveTabPersistsThroughJSONRoundTrip passes |
| 4 | Tab labels are legible in both light and dark themes | ✓ VERIFIED (automated) | testTabContrastAllThemes passes for all 6 presets with luminance-delta >= 0.05 and FG-vs-active delta >= 0.15; one semantic concern flagged for human review |

**Score:** 4/4 truths verified (automated). 2 items require human visual confirmation.

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `libs/Dashboard/GroupWidget.m` | ReflowCallback property; invocation in collapse() and expand() | ✓ VERIFIED | Line 11: `ReflowCallback = []`; lines 242-244: invocation in collapse(); lines 261-263: invocation in expand() |
| `libs/Dashboard/DashboardEngine.m` | reflowAfterCollapse() private method; injection in addWidget() and load() | ✓ VERIFIED | Lines 121-123: injection in addWidget(); lines 877-883: injection loop in load() JSON path; lines 802-808: reflowAfterCollapse() private method |
| `tests/suite/TestGroupWidget.m` | testCollapseCallsReflowCallback and 3 other ReflowCallback tests + LAYOUT-07/08 tests | ✓ VERIFIED | Lines 284-372: all 6 test methods present and substantive |
| `tests/suite/TestDashboardEngine.m` | testCollapseGroupWidgetReflowsGrid + 2 injection tests | ✓ VERIFIED | Lines 167-191: all 3 test methods present and substantive |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `GroupWidget.m collapse()` | `ReflowCallback` | `if ~isempty(obj.ReflowCallback); obj.ReflowCallback(); end` | ✓ WIRED | Lines 242-244 confirmed |
| `GroupWidget.m expand()` | `ReflowCallback` | `if ~isempty(obj.ReflowCallback); obj.ReflowCallback(); end` | ✓ WIRED | Lines 261-263 confirmed |
| `DashboardEngine.m addWidget()` | `GroupWidget.ReflowCallback` | `@() obj.reflowAfterCollapse()` injected for Mode=='collapsible' | ✓ WIRED | Lines 120-123 confirmed |
| `DashboardEngine.m load()` | `GroupWidget.ReflowCallback` | Second loop after widgets-loading loop injects callback | ✓ WIRED | Lines 877-883 confirmed (JSON path only; .m path runs through addWidget() which already injects) |
| `GroupWidget.toStruct()` | `GroupWidget.fromStruct()` | `activeTab` field written at line 217; read at line 485 | ✓ WIRED | Both confirmed present |
| `DashboardTheme presets` | `GroupWidget tab rendering` | `TabActiveBg`/`TabInactiveBg` present in all 6 presets | ✓ WIRED | All presets verified in DashboardTheme.m |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `GroupWidget.m` collapse/expand | `ReflowCallback` | Injected by `DashboardEngine.addWidget()` or `load()` | Yes — function handle to `reflowAfterCollapse()` | ✓ FLOWING |
| `GroupWidget.m` toStruct/fromStruct | `ActiveTab` | Written by `switchTab()`, serialized via `s.activeTab` | Yes — string field from user action | ✓ FLOWING |
| `DashboardTheme.m` | `TabActiveBg`, `TabInactiveBg` | Hardcoded preset values | Yes — defined per preset | ✓ FLOWING |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — production code requires a running MATLAB instance. Tests confirm behavior at unit and integration level; no standalone CLI entry point exists.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| LAYOUT-01 | 02-01-PLAN.md | Collapsible sections reflow the grid on collapse | ✓ SATISFIED | ReflowCallback wired in collapse(); reflowAfterCollapse() calls rerenderWidgets(); testCollapseGroupWidgetReflowsGrid passes |
| LAYOUT-02 | 02-01-PLAN.md | Expanding a collapsed section reflows the grid | ✓ SATISFIED | ReflowCallback wired in expand(); testExpandCallsReflowCallback passes |
| LAYOUT-07 | 02-02-PLAN.md | Existing tabbed GroupWidget persists active tab through JSON save/load | ✓ SATISFIED | testActiveTabPersistsThroughJSONRoundTrip confirms round-trip works |
| LAYOUT-08 | 02-02-PLAN.md | Tab visual contrast legible in both light and dark themes | ✓ SATISFIED (automated) | testTabContrastAllThemes passes all 6 presets; human review recommended for scientific preset |

**Orphaned requirements check:** REQUIREMENTS.md maps LAYOUT-01, LAYOUT-02, LAYOUT-07, LAYOUT-08 to Phase 2. All four are claimed in phase plans. No orphaned requirements.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `libs/Dashboard/DashboardTheme.m` | 93-94 | scientific preset: `TabActiveBg` (mean 0.8733) is darker than `TabInactiveBg` (mean 0.9333) — active tab visually less prominent than inactive | ⚠️ Warning | Passes programmatic threshold (delta 0.06 >= 0.05) but semantics are inverted — users may not perceive the active tab as "selected" |

No stub, placeholder, hardcoded-empty, or TODO anti-patterns found in production files.

---

### Human Verification Required

#### 1. Scientific Theme Tab Contrast Semantics

**Test:** Open a tabbed GroupWidget dashboard using the `scientific` theme. Switch to a non-default tab and observe which tab appears visually selected.
**Expected:** The active tab should appear clearly distinguished from inactive tabs — brighter, highlighted, or otherwise visually "selected."
**Why human:** The `scientific` preset has TabActiveBg (mean 0.8733) darker than TabInactiveBg (mean 0.9333), meaning the inactive tab is lighter than the active tab. This is semantically inverted from convention. The programmatic luminance-delta check (0.06) passes the 0.05 threshold, so no automated failure is raised, but a human must confirm the visual result is actually legible and not confusing.

#### 2. Grid Reflow Visual Verification

**Test:** Create a dashboard with a collapsible GroupWidget followed by a widget below it. Render the dashboard, then click the collapse button on the GroupWidget.
**Expected:** The widget below the collapsed group immediately shifts upward to fill the reclaimed space. No blank gap remains. Expanding the group pushes it back down.
**Why human:** `testCollapseGroupWidgetReflowsGrid` verifies that `rerenderWidgets()` is triggered and that `hPanel` is valid and `Collapsed=true`, but it does not assert pixel-level positions of widgets below the collapsed group. Only visual inspection in a rendered MATLAB figure can confirm the actual reflow behavior matches user expectations.

---

### Gaps Summary

No gaps blocking goal achievement were found. All four ROADMAP success criteria have implementation evidence and passing tests. Two items are flagged for human visual confirmation (grid reflow appearance, scientific theme contrast semantics) but these do not represent blocking defects — the programmatic checks all pass.

**Note on collapsed-state save/load:** The phase goal text mentions "expanded/collapsed state surviving save/load" but the ROADMAP success criteria for Phase 2 do not include this. The serialization infrastructure exists (`s.collapsed` in toStruct, `obj.Collapsed = s.collapsed` in fromStruct), but no Phase 2 test verifies the full round-trip. This is intentional — SERIAL-03 is assigned to Phase 6. No gap to close in Phase 2.

---

_Verified: 2026-04-01_
_Verifier: Claude (gsd-verifier)_
