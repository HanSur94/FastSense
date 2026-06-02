---
phase: 1041
slug: global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
status: draft
shadcn_initialized: false
preset: none
created: 2026-06-02
---

# Phase 1041 — UI Design Contract

> Visual and interaction contract for the CompanionTimeBar picker.
> This is a SMALL UI control added to an EXISTING mature uifigure design system.
> Every decision derives from the existing CompanionTheme / DashboardTheme / FastSenseCompanion
> source files. No new design language is introduced.

---

## Scope

Three surfaces only:

1. **Range button** — the toolbar `uibutton` in the `'1x'` spacer column (col 9) showing the current range label.
2. **Picker popup** — a standalone `uifigure` (mirroring `CompanionSettingsDialog`) with three modes: Quick presets, Relative builder, Absolute.
3. **Widget empty state** — the label rendered inside a `FastSenseWidget` (or any companion-opened plot widget) when `getXYRange` returns empty for the active window.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (MATLAB uifigure — no web component library) |
| Preset | not applicable |
| Component library | MATLAB uifigure built-ins: `uibutton`, `uipanel`, `uigridlayout`, `uidropdown`, `uieditfield`, `uispinner`, `uidatepicker`, `uilabel` |
| Icon library | Unicode glyphs (same as existing toolbar: `char(9881)` gear, `char(8599)` arrow-out, `char(8230)` ellipsis) |
| Font | Helvetica (source: `FastSenseTheme.m:101` — `'FontName', 'Helvetica'`) |

**Runtime:** MATLAB R2020b+ only. `uidatepicker` requires R2020a+. Companion UI is not tested under Octave (existing pattern: `skipOnOctave` in `TestMethodSetup`).

---

## Spacing Scale

All values are in pixels as used by MATLAB `uigridlayout` / `uipanel` / `uibutton` properties.
These values are derived directly from the existing companion source (`FastSenseCompanion.m`, `CompanionSettingsDialog.m`, `CompanionTheme.m`).

| Token | Value (px) | Source | Usage |
|-------|-----------|--------|-------|
| xs | 4 | `FastSenseCompanion.m:329` — toolbar `Padding = [4 0 4 0]` | Toolbar inner padding (horizontal sides) |
| sm | 8 | `FastSenseCompanion.m:331` — `ColumnSpacing = 8`; `CompanionSettingsDialog.m:87` — button row `ColumnSpacing = 8` | Grid column spacing, button-row gap |
| md | 12 | `CompanionSettingsDialog.m:63` — `RowSpacing = 12` | Popup row spacing |
| lg | 16 | `CompanionTheme.m:39` — `PanePadding = 16`; `DashboardListPane.m:343` — empty state grid `Padding = [16 16 16 16]` | Pane inner padding, popup `Padding`, empty-state label padding |
| xl | 24 | `CompanionTheme.m:40` — `GridOuterPadding = 24`; `FastSenseCompanion.m:304` — root layout `Padding = [24 24 24 24]` | Root layout outer padding |

**Popup `Padding`:** `[16 16 16 16]` — matches `CompanionSettingsDialog.m:62`.
**Popup `RowSpacing`:** 12 px — matches `CompanionSettingsDialog.m:63`.
**Popup `ColumnSpacing`:** 12 px — matches `CompanionSettingsDialog.m:63`.

Exceptions:
- Toolbar row height is `'1x'` (fill available height); the toolbar panel row is 32 px tall (`FastSenseCompanion.m:303` — `RowHeight = {32, '1x', 360}`).
- Settings gear button is 36 px wide (fixed, `hToolbarGrid.ColumnWidth` col 10). Range button is `'1x'` (flex fill of the spacer column).

---

## Typography

All font sizes in points (MATLAB `FontSize` property — same units as existing toolbar buttons).

| Role | Size (pt) | Weight | Source | Usage |
|------|-----------|--------|--------|-------|
| Toolbar button label | 11 | bold | `FastSenseCompanion.m:338` — `obj.hEventsBtn_.FontSize = 11; FontWeight = 'bold'` | Range button text ("Last 7 days"), all toolbar action buttons |
| Popup label / dropdown | 11 | normal (400) | Default `uibutton`/`uilabel` — matches companion existing popup (`CompanionSettingsDialog.m` does not set FontSize, relies on MATLAB default ~11 pt) | Picker mode labels, field labels |
| Popup section header | 12 | bold | Consistent with `FastSenseCompanion.m:429` — bell button `FontSize = 12; FontWeight = 'bold'`; one step up from 11 to distinguish header from control labels | Active mode label ("Quick", "Relative", "Absolute") inside popup |
| Widget empty state | 14 | bold | `DashboardListPane.m:349` — `lbl.FontSize = 14; FontWeight = 'bold'` — exact copy of existing `renderEmptyState_` pattern | "No data in selected range" centered label inside widget panel |
| Settings gear | 14 | normal | `FastSenseCompanion.m:445` — `FontSize = 14` | Gear icon only — not a new size, listed for completeness |

---

## Color

All RGB values derived from `DashboardTheme.m` and `CompanionTheme.m`. Values shown for the **dark preset** (companion default); light-preset equivalents in parentheses.

| Role | Dark RGB | Light RGB | Source field | Usage |
|------|----------|-----------|-------------|-------|
| Dominant (60%) — surface | `[0.10 0.10 0.18]` | `[0.96 0.96 0.97]` | `DashboardTheme.m:57` `DashboardBackground` | Popup `uifigure.Color`, popup grid `BackgroundColor` |
| Secondary (30%) — controls | `[0.09 0.13 0.24]` | `[1.00 1.00 1.00]` | `DashboardTheme.m:58` `WidgetBackground` | Toolbar panel `BackgroundColor`, popup input control background, empty-state label `BackgroundColor` |
| Tertiary — button chrome | `[0.16 0.23 0.37]` | `[0.85 0.85 0.87]` | `DashboardTheme.m:59` `WidgetBorderColor` | Range button `BackgroundColor`, popup Cancel button `BackgroundColor`, inactive mode tab bg — matches existing non-accent toolbar buttons (e.g. Tile, Wiki, bell: all use `WidgetBorderColor`) |
| Accent (10%) | `[0.31 0.80 0.64]` | `[0.20 0.60 0.86]` | `DashboardTheme.m:63` `DragHandleColor` (aliased as `theme.Accent` in `CompanionTheme.m:57`) | ONLY: the Apply button `BackgroundColor` in the picker popup; the active mode indicator (selected mode tab / section header border); the range button when a non-default range is active (to signal "filter is set") |
| Foreground | `[0.66 0.73 0.78]` | `[0.20 0.20 0.25]` | `DashboardTheme.m:61` `ToolbarFontColor` | All button `FontColor`, popup label `FontColor`, range button label text |
| Placeholder / muted | `[0.66 0.73 0.78]` | `[0.20 0.20 0.25]` | `CompanionTheme.m:49` `PlaceholderTextColor` — same value as `ToolbarFontColor` | Widget empty-state label `FontColor` ("No data in selected range") |

**Accent reserved for:**
- Apply button background in the picker popup.
- Active mode indicator (border or background on the selected Quick / Relative / Absolute tab).
- Range button `BackgroundColor` when a non-default range spec is active (visual signal that filtering is in effect). Default (Last 7 days) uses `WidgetBorderColor` like all other toolbar buttons.

**Destructive color:** `[0.91 0.27 0.38]` (`StatusAlarmColor` — `DashboardTheme.m:103`). Not used in this phase (no destructive action). Listed for completeness; the Cancel button uses `WidgetBorderColor`, not red.

---

## Surfaces

### Surface 1: Range Button (Toolbar)

**Location:** `hToolbarGrid` col 9 — the current `'1x'` flex spacer. Phase 1041 replaces the spacer with a `uibutton` that fills the available width.

**Toolbar grid update:** `hToolbarGrid.ColumnWidth` changes from `{110, 110, 110, 130, 70, 90, 70, 70, '1x', 36}` to the same array (col 9 stays `'1x'`). The spacer column previously had no widget; the range button simply occupies that slot.

**Button specification:**

| Property | Value | Rationale |
|----------|-------|-----------|
| `Type` | `uibutton`, 'push' | Consistent with all other toolbar buttons |
| `Layout.Column` | 9 | The `'1x'` spacer slot |
| `Text` | Current range label (see Label Formatting below) | Dynamic; updated on every `RangeChanged` |
| `FontSize` | 11 | Matches all other toolbar buttons (`hEventsBtn_.FontSize = 11`) |
| `FontWeight` | `'bold'` | Matches all other toolbar buttons |
| `FontColor` | `theme.ForegroundColor` (`theme.ToolbarFontColor`) | Matches Tile, Wiki, bell buttons |
| `BackgroundColor` | `theme.WidgetBorderColor` when default; `theme.Accent` when non-default range active | Accent signals "filter is set" — same convention as Live: ON (Live button uses Accent when active, per existing code) |
| `Tag` | `'CompanionTimeRangeBtn'` | For test findobj |
| `Tooltip` | `'Set the global time range for all companion-opened views'` | Descriptive, consistent with other button tooltips |
| `ButtonPushedFcn` | `@(~,~) obj.openTimePicker_()` | Opens the picker popup |

**Label Formatting:**

| Spec type | Format | Example |
|-----------|--------|---------|
| Relative (preset or custom) | `'Last N unit'` | `'Last 7 days'` / `'Last 24 hours'` / `'Last 1 year'` |
| Absolute | `'YYYY-MM-DD to YYYY-MM-DD'` (using `datestr(t, 'yyyy-mm-dd')`) | `'2024-01-01 to 2024-03-01'` |
| All | `'All data'` | `'All data'` |

The label is produced by `CompanionTimeRange.label()` (see RESEARCH.md Pattern 4). The word `'to'` (not an arrow `→`) is chosen because MATLAB label rendering does not guarantee arrow-glyph availability across platforms.

---

### Surface 2: Picker Popup

**Pattern:** Standalone `uifigure` — identical pattern to `CompanionSettingsDialog.m`. Non-modal. Positioned near the toolbar (use `getpixelposition(obj.hFig_, 'recursive')` to place relative to the companion figure).

**uifigure specification:**

| Property | Value | Source |
|----------|-------|--------|
| `Name` | `'Time Range'` | Short, consistent with `'Companion Settings'` |
| `Position` | `[x y 400 280]` (decision: 40 px wider, 80 px taller than `CompanionSettingsDialog` to accommodate three-mode content) | Sized to fit 3 modes without scrolling |
| `Resize` | `'off'` | Fixed size — matches `CompanionSettingsDialog` |
| `AutoResizeChildren` | `'off'` | Required when `Resize='off'` |
| `Color` | `theme.DashboardBackground` | Matches `CompanionSettingsDialog.m:55` |
| `WindowStyle` | NOT set (non-modal) | Matches `CompanionSettingsDialog.m` |
| `CloseRequestFcn` | `@(~,~) obj.close()` | Matches `CompanionSettingsDialog.m:101` |

**Root grid:** `uigridlayout(hFig, [5 1])`

| Row | Height | Content |
|-----|--------|---------|
| 1 | 32 | Mode tab strip (`uigridlayout [1 3]` — "Quick" / "Relative" / "Absolute" `uibutton` tabs) |
| 2 | `'1x'` | Active mode content panel (swap between Quick / Relative / Absolute) |
| 3 | 1 | Visual separator (thin `uipanel` with `BackgroundColor = theme.WidgetBorderColor`, `BorderType = 'none'`, `Position` height = 1) |
| 4 | 40 | Apply + Cancel button row |

`Padding = [16 16 16 16]`, `RowSpacing = 12`, `ColumnSpacing = 0`.

**Mode tab strip (Row 1):**

Three `uibutton` push buttons in a `uigridlayout([1 3])` with `ColumnWidth = {'1x', '1x', '1x'}`, `Padding = [0 0 0 0]`, `ColumnSpacing = 4`.

| Button | Text | Active state | Inactive state |
|--------|------|-------------|----------------|
| Quick | `'Quick'` | `BackgroundColor = theme.Accent`, `FontColor = theme.ForegroundColor` | `BackgroundColor = theme.WidgetBorderColor`, `FontColor = theme.ForegroundColor` |
| Relative | `'Relative'` | same active pattern | same inactive pattern |
| Absolute | `'Absolute'` | same active pattern | same inactive pattern |

`FontSize = 11`, `FontWeight = 'bold'`. Clicking a tab button shows the corresponding content panel (hide/show via `Visible` property) and repaints the tab backgrounds.

**Default active mode:** Quick, with "Last 7 days" pre-selected. This matches the default `companionPrefs` value.

---

#### Mode: Quick Presets (content panel for Row 2 when Quick tab active)

A `uigridlayout([6 1])` with `RowHeight = {32, 32, 32, 32, 32, 32}`, `ColumnWidth = {'1x'}`, `Padding = [0 0 0 0]`, `RowSpacing = 4`.

Six `uibutton` push buttons, one per preset:

| Row | Text | Spec encoded |
|-----|------|-------------|
| 1 | `'Last 24 hours'` | relative: N=24, unit='hours' |
| 2 | `'Last 7 days'` (default) | relative: N=7, unit='days' |
| 3 | `'Last 30 days'` | relative: N=30, unit='days' |
| 4 | `'Last 90 days'` | relative: N=90, unit='days' |
| 5 | `'Last 1 year'` | relative: N=1, unit='years' |
| 6 | `'All data'` | spec type='all' |

**Active preset highlighting:** The button matching the current `CompanionTimeRange` spec uses `BackgroundColor = theme.Accent`. All others use `BackgroundColor = theme.WidgetBorderColor`.

**Interaction:** Clicking any preset button immediately calls `Apply` (no separate Apply click needed — quick presets are one-click). The popup closes after applying. This is consistent with Kibana's quick-select behavior and reduces clicks for the common case.

`FontSize = 11`, `FontWeight = 'bold'`, `FontColor = theme.ForegroundColor`, `HorizontalAlignment = 'left'`.

---

#### Mode: Relative Builder (content panel for Row 2 when Relative tab active)

A `uigridlayout([2 3])` with `RowHeight = {32, 32}`, `ColumnWidth = {60, '1x', 120}`, `Padding = [0 0 0 0]`, `RowSpacing = 8`, `ColumnSpacing = 8`.

| Row | Col 1 | Col 2 | Col 3 |
|-----|-------|-------|-------|
| 1 (labels) | `uilabel` "Last" | (empty) | `uilabel` "until now" |
| 2 (controls) | `uispinner` N | (spans col 2-3 — see below) | `uidropdown` unit |

Correction: use a `uigridlayout([1 3])` for the control row:

| Control | Type | Properties |
|---------|------|-----------|
| N field | `uispinner` | `Limits = [1 9999]`, `Step = 1`, `Value = 7` (default), `RoundFractionalValues = 'on'` |
| Unit selector | `uidropdown` | `Items = {'hours', 'days', 'weeks', 'months', 'years'}`, `Value = 'days'` (default) |

Below the two rows: a read-only `uilabel` showing the resolved date range preview, e.g. `"2026-05-26 to 2026-06-02"`. Updated on every spinner/dropdown change. `FontSize = 11`, `FontColor = theme.PlaceholderTextColor`. This previews what the window will be without requiring an Apply click.

In this mode, Apply commits the relative spec. The popup closes after Apply.

---

#### Mode: Absolute (content panel for Row 2 when Absolute tab active)

A `uigridlayout([3 2])` with `RowHeight = {32, 32, 32}`, `ColumnWidth = {80, '1x'}`, `Padding = [0 0 0 0]`, `RowSpacing = 8`, `ColumnSpacing = 8`.

| Row | Col 1 (label) | Col 2 (control) |
|-----|--------------|-----------------|
| 1 | `uilabel` "Start" | `uidatepicker` start date |
| 2 | `uilabel` "End" | `uidatepicker` end date |
| 3 | (empty) | `uilabel` preview of N days in window, e.g. `"91 days"`, `FontColor = theme.PlaceholderTextColor` |

`uidatepicker` value type: `datetime`. Conversion to datenum on Apply: `datenum(picker.Value)` (Pitfall 6 from RESEARCH.md). Default values: start = `datetime('today') - caldays(7)`, end = `datetime('today')`.

**Validation:** If start >= end, the Apply button is disabled and the preview label shows `"Invalid: start must be before end"` in `theme.StatusAlarmColor` (`[0.91 0.27 0.38]`).

---

#### Action Row (Row 4, `uigridlayout([1 2])`, `ColumnWidth = {'1x', '1x'}`, `ColumnSpacing = 8`, `Padding = [0 0 0 0]`)

| Button | Text | Properties |
|--------|------|-----------|
| Apply | `'Apply'` | `BackgroundColor = theme.Accent`, `FontColor = theme.ForegroundColor`, `FontSize = 11`, `FontWeight = 'bold'` |
| Cancel | `'Cancel'` | `BackgroundColor = theme.WidgetBorderColor`, `FontColor = theme.ForegroundColor`, `FontSize = 11`, `FontWeight = 'bold'` |

**Apply behavior:**
- Quick mode: n/a — presets apply immediately (no separate Apply needed).
- Relative mode: calls `CompanionTimeRange.setRelative(N, unit)`, closes popup.
- Absolute mode: validates start < end; if valid calls `CompanionTimeRange.setAbsolute(t0, t1)`, closes popup.

**Cancel behavior:** Closes popup without changing `CompanionTimeRange` spec. No confirmation required.

**Apply is hidden in Quick mode** (presets are one-click; the row is still rendered but the Apply button `Visible = 'off'` in Quick mode to reduce visual noise. Cancel remains visible so users can dismiss without selecting anything).

**Theming:** Call `applyThemeToChildren_(hFig_, theme)` after construction — same as `CompanionSettingsDialog.m:99`.

**Singleton pattern:** Companion holds `TimePicker_ = []` (same as `SettingsDlg_`). Opening while a picker is already open brings the existing one to focus (`figure(hFig_)`) instead of opening a second.

---

### Surface 3: Widget Empty State

**Trigger:** `FastSenseWidget` (and any companion-opened plot widget) receives empty `[x, y]` from `getXYRange(t0, t1)` — meaning no samples fall in the selected window.

**Rendering pattern:** Directly mirrors `DashboardListPane.renderEmptyState_()` (lines 325-356 of `DashboardListPane.m`). A centered `uilabel` inside the widget's content panel.

**Implementation:**

```
uigridlayout([1 1]) filling the widget content area
  RowHeight = {'1x'}, ColumnWidth = {'1x'}
  Padding = [16 16 16 16]
  BackgroundColor = theme.WidgetBackground

  uilabel:
    Text = "No data in selected range"
    FontSize = 14
    FontWeight = 'bold'
    FontColor = theme.PlaceholderTextColor   (= ToolbarFontColor)
    BackgroundColor = theme.WidgetBackground
    HorizontalAlignment = 'center'
    VerticalAlignment   = 'center'
```

This is the exact pattern from `DashboardListPane.renderEmptyState_` with the copy text swapped in. No new design decisions.

**Copy text (exact):** `"No data in selected range"`

This copy is intentionally minimal and actionable by implication — the user knows the range is set in the toolbar button and can change it there. No secondary line / "try adjusting the range" sub-copy is added in v1 (YAGNI).

**When to show:** Replace the widget's normal content (FastSense axes) with the empty-state label for the duration that the empty condition holds. On next refresh/re-query where data becomes non-empty, the normal content restores.

---

## Copywriting Contract

| Element | Copy | Notes |
|---------|------|-------|
| Range button default label | `Last 7 days` | Relative preset — matches `companionPrefs` default |
| Range button label — relative custom | `Last N unit` (e.g. `Last 30 days`) | `CompanionTimeRange.label()` output |
| Range button label — absolute | `YYYY-MM-DD to YYYY-MM-DD` | `datestr(t, 'yyyy-mm-dd')` — no arrow glyph |
| Range button label — all | `All data` | |
| Range button tooltip | `Set the global time range for all companion-opened views` | |
| Picker popup title | `Time Range` | uifigure `Name` property |
| Quick mode — all-data preset | `All data` | Mirrors the button label |
| Quick mode — "last 24h" | `Last 24 hours` | Full word "hours", not "h" |
| Quick mode — "last 7d" | `Last 7 days` | Full word "days" |
| Quick mode — "last 30d" | `Last 30 days` | Full word "days" |
| Quick mode — "last 90d" | `Last 90 days` | Full word "days" |
| Quick mode — "last 1y" | `Last 1 year` | Singular "year" |
| Relative builder — label before N | `Last` | `uilabel` |
| Relative builder — label after unit | `until now` | `uilabel` — communicates the relative anchor is wall-clock now |
| Absolute — validation error | `Invalid: start must be before end` | In `StatusAlarmColor`; replaces preview label |
| Apply button | `Apply` | Standard MATLAB dialog convention |
| Cancel button | `Cancel` | Standard MATLAB dialog convention |
| Widget empty state (heading) | `No data in selected range` | 14pt bold, centered |
| Widget empty state body | (none) | No sub-copy in v1 |

---

## Interaction Contracts

### Range Button

- Single click: opens picker popup (or brings existing popup to front if already open).
- No right-click / hover state beyond MATLAB default.
- Label updates synchronously after `RangeChanged` fires.
- `BackgroundColor` switches from `WidgetBorderColor` to `Accent` when the active spec differs from the default (Last 7 days). This signals "a filter is active" without a separate indicator.

### Picker Popup — Mode Switching

- Mode tabs are always visible in the tab strip regardless of which mode is active.
- Switching mode tabs does not apply the range — only shows/hides content panels.
- The previously committed spec is not modified by tab switching alone.

### Picker Popup — Quick Mode One-Click Apply

- Clicking a preset button immediately fires `CompanionTimeRange.setRelative()` (or `setAll()` for "All data"), closes the popup.
- No intermediate Apply needed. The Apply button row is hidden (`Visible = 'off'`) in Quick mode.

### Picker Popup — Relative and Absolute — Two-Step Apply

- User adjusts controls.
- Apply button commits the spec, closes the popup.
- Cancel closes without committing.
- Keyboard Enter key: not specially wired in v1 (MATLAB default uifigure behavior).

### RangeChanged Event

- Fires on: preset click (Quick mode), Apply click (Relative / Absolute mode).
- Does NOT fire on: mode tab switch, control edits before Apply, Cancel.
- Companion listener: `onRangeChanged_()` resolves range, calls `setTimeWindow(t0, t1)` on all managed engines + stashed ad-hoc engines. See RESEARCH.md Pattern — Companion RangeChanged listener.

### Live Ticks and Relative Window

- Relative specs slide silently. On each live tick, `FastSenseWidget` calls `getXYRange(t0, t1)` where `t1 = now()` freshly resolved — no `RangeChanged` fires, no `rerenderWidgets`. The widget's `refresh()`/`update()` cycle handles it transparently.
- Absolute specs are fixed. Live ticks append to the right edge only if the absolute window's `t1` is in the future or present.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| Not applicable (MATLAB uifigure — no web registry) | none | not required |

---

## Deferred (Out of Scope for v1 — Do NOT Implement)

These are explicitly excluded per CONTEXT.md deferred section:

- Auto-refresh interval control (Kibana "Refresh every").
- Sub-day time-of-day precision in the picker UI (uidatepicker is date-only).
- Scrub-beyond-window incremental loading in SensorDetailPlot navigator.
- Per-view pin / unpin from the global range.
- Recently-used ranges list.
- datetime / timezone-aware handling beyond datenum convention.
- Hover / focus states beyond MATLAB default uifigure rendering.
- Keyboard navigation shortcuts beyond MATLAB defaults.

---

## Source Traceability

| Decision | Source |
|----------|--------|
| Font: Helvetica, 11pt bold for toolbar buttons | `FastSenseTheme.m:101`, `FastSenseCompanion.m:338` |
| `WidgetBorderColor` for inactive toolbar buttons | `FastSenseCompanion.m:392-393` (Tile button), `m:419` (Wiki button), `m:432` (bell button) |
| `Accent` for active/special state | `FastSenseCompanion.m:403-404` (Close all, the only Accent-colored button) |
| Toolbar grid col 9 = `'1x'` spacer | `FastSenseCompanion.m:327` `ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, '1x', 36}` |
| Toolbar panel row height = 32px | `FastSenseCompanion.m:303` `RowHeight = {32, '1x', 360}` |
| Popup: standalone uifigure, 360×200, `Resize='off'` | `CompanionSettingsDialog.m:50-55` |
| Popup grid: `Padding=[16 16 16 16]`, `RowSpacing=12`, `ColumnSpacing=12` | `CompanionSettingsDialog.m:62-63` |
| Button row `ColumnSpacing=8` | `CompanionSettingsDialog.m:87` |
| Apply button uses Accent bg | `CompanionTheme.m:57` + existing Close all pattern (`m:403`) |
| Cancel button uses `WidgetBorderColor` bg | Inactive button convention (Tile, Wiki, bell) |
| Empty state: 14pt bold centered `uilabel`, `PlaceholderTextColor`, `WidgetBackground`, `Padding=[16 16 16 16]` | `DashboardListPane.m:346-356` — `renderEmptyState_` exact copy pattern |
| datenum convention for X time base | `demo/industrial_plant/plantConfig.m:113`, `seedHistory.m:53-55`, RESEARCH.md Q1 |
| `datestr(t, 'yyyy-mm-dd')` for absolute label | ISO-8601 date format; MATLAB built-in, Octave-compatible |

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending
