# FastSense Light Mode — 1:1 Design Spec (Pencil → MATLAB)

**Status:** draft · **Date:** 2026-07-09 · **Surfaces:** FastSense plot, Dashboard, Companion
**Pencil file:** `~/.pencil/documents/15bbe5fe-d0f5-470b-a8c7-1f54cba91b93/pencil-halo.pen`

---

## 0. What "1:1" means here, and how to use this doc

- **Direction of truth:** *Pencil drives MATLAB.* The Pencil frames are the visual target;
  MATLAB is built (or corrected) to match them.
- **The catch that makes it honest:** the Pencil frames are drawn using **only primitives MATLAB
  can render cheaply** (§1). Nothing in a frame requires a gradient, shadow, blur, or true rounded
  panel corner. So "make MATLAB look like the mock" is achievable, not aspirational.
- **The token contract (§2) is the bridge.** Every color and size in the Pencil frames is a *named
  variable* whose value equals a specific MATLAB theme field. Translating a frame = look up the
  token → set the matching `FastSenseTheme` / `DashboardTheme` / `CompanionTheme` field → place the
  primitive. No eyeballing of hex codes.
- **Redlines (§5)** list every place today's MATLAB still diverges from the target, with the fix.

**Frame index**

| Surface | Pencil frame name | Node id | Reference px |
|---|---|---|---|
| Single plot | `FastSense Light — Plot` | `UO6JB` | 920 × 580 |
| Dashboard | `FastSense Light — Dashboard` | `CK5l7` | 1440 × 980 |
| Companion | `FastSense Light — Companion` | `bmDPJ` | 1200 × 760 |
| (reference) As-is UI | `FastSense — Current UI (as-is)` | `ZAUY9` | 1600 × 1010 |
| (reference) Redesign study | `FastSense — Redesigned UI` | `EwZma` | 1600 × 1400 |

---

## 1. Cheap-render budget (the hard constraint)

Every element in every frame maps to one of these MATLAB primitives. If a mock ever needs anything
in the **Forbidden** column, that's a bug in the mock — not a feature to implement.

| Allowed primitive | MATLAB realization |
|---|---|
| Flat fill rectangle | `uipanel.BackgroundColor` / `axes.Color` / `annotation('rectangle')` |
| 1 px hairline border | `uipanel` line border · `axes.Box='on'` + `XColor/YColor` · `rectangle EdgeColor` |
| Straight polyline / data line | `line()` / `plot()` with `Color`, `LineWidth` |
| Dashed line | `line(...,'LineStyle','--')` |
| Solid arc (gauge) | `line()` over many sampled angles (no true arc primitive needed) |
| Single-hue fill band | `patch` / `area` with `FaceAlpha` (this is the *only* transparency MATLAB does cheaply) |
| Text | `uicontrol('style','text')` · `uilabel` · `text()` |
| Small monochrome glyph | Unicode char in a text control, or a thin `line`/`patch` icon |

| Forbidden (must not appear) | Why |
|---|---|
| Linear/radial gradients | No cheap axes/uipanel gradient; would need an image |
| Drop shadows / inner shadows | Not a MATLAB panel property |
| Background blur | Not available |
| Rounded panel corners | **`uipanel` corners are always square.** See caveat below. |
| Multi-layer translucent overlays | Compositing cost + no real support |

> **cornerRadius caveat.** The Pencil frames use a small `cornerRadius` (≈4 px) on chips, tool
> buttons, and the legend purely so the *mock* reads cleanly at a glance. **MATLAB renders these
> square.** When translating, treat every `cornerRadius` as `0`. This is an accepted, documented
> divergence, not a target.

---

## 2. Token contract (single source of truth)

Pencil variable ⟷ hex ⟷ MATLAB RGB triplet (0–1) ⟷ theme field. The MATLAB triplets are copied
verbatim from `FastSenseTheme.m` / `DashboardTheme.m`, so they are exact, not reconverted from hex.

### Canvas / surfaces / borders

| Pencil var | Hex | MATLAB RGB | Theme field(s) | Used for |
|---|---|---|---|---|
| `fs-canvas` | `#F5F6F8` | `[0.961 0.965 0.973]` | `DashboardBackground`, `FastSenseTheme.Background` | figure / dashboard canvas |
| `fs-surface` | `#FFFFFF` | `[1 1 1]` | `WidgetBackground`, `AxesColor` | widget panels, axes fill |
| `fs-surface-alt` | `#F9FAFB` | `[0.976 0.980 0.984]` | `ToolbarBackground` | toolbar strips, tool buttons |
| `fs-border` | `#E5E8EC` | `[0.898 0.910 0.925]` | `WidgetBorderColor`, `GroupBorderColor` | 1 px card / panel borders |
| `fs-tab-inactive` | `#D9DEE6` | `[0.850 0.870 0.900]` | `TabInactiveBg` | inactive page tab bg |
| `fs-grid` | `#E9EDF2` | `[0.914 0.929 0.949]` | `GridColor`, `GridLineColor` | axes gridlines |

### Accent

| Pencil var | Hex | MATLAB RGB | Theme field(s) | Used for |
|---|---|---|---|---|
| `fs-accent` | `#2563EB` | `[0.145 0.388 0.922]` | `DragHandleColor`, `CompanionTheme.Accent` | primary CTA, active handle, links, active pill |
| `fs-accent-soft` | `#EAF1FE` | `[0.918 0.945 0.996]` | `DropZoneColor`, `TabActiveBg` | active tab bg, drop zone, soft accent fill |
| `fs-accent-2` | `#3B82F6` | *(none — derive)* | — | hover/secondary accent (use sparingly) |

### Status (semantic)

| Pencil var | Hex | MATLAB RGB | Theme field(s) | Used for |
|---|---|---|---|---|
| `fs-ok` | `#16A34A` | `[0.086 0.639 0.290]` | `StatusOkColor` | OK dots, positive KPI trend |
| `fs-warn` | `#F59E0B` | `[0.961 0.620 0.043]` | `StatusWarnColor` | warning state |
| `fs-alarm` | `#EF4444` | `[0.937 0.267 0.267]` | `StatusAlarmColor`, `FastSenseTheme.ThresholdColor` | alarm dots, threshold line |
| `fs-ok-soft` / `fs-warn-soft` / `fs-alarm-soft` | `#E7F6EC` / `#FEF3E2` / `#FDEBEC` | *(none — derive)* | — | status-pill backgrounds (only if pills land) |

### Ink / text

| Pencil var | Hex | MATLAB RGB | Theme field(s) | Used for |
|---|---|---|---|---|
| `fs-ink` | `#1E293B` | `[0.118 0.161 0.231]` | `GroupHeaderFg` | primary text on white |
| `fs-ink-2` | `#64748B` | `[0.392 0.455 0.545]` | `ToolbarFontColor`, `PlaceholderTextColor`, `AxisColor` | secondary text, tick labels |
| `fs-plot-ink` | `#354155` | `[0.208 0.255 0.333]` | `FastSenseTheme.ForegroundColor` | plot axis labels / ticks |

### Plot line palette — `muted` (LOCKED)

`FastSenseTheme.LineColorOrder = 'muted'`. These are the exact `getPalette('muted')` rows.
Reconciled in Pencil 2026-07-09 (previously the mock used brighter lines — that was the divergence).

| Pencil var | Hex | MATLAB RGB | Series |
|---|---|---|---|
| `fs-line-1` | `#547AA3` | `[0.33 0.47 0.64]` | steel blue |
| `fs-line-2` | `#AD665C` | `[0.68 0.40 0.36]` | dusty rose |
| `fs-line-3` | `#8C8C5C` | `[0.55 0.55 0.36]` | olive |
| `fs-line-4` | `#9470A6` | `[0.58 0.44 0.65]` | mauve |
| `fs-line-5` | `#739E80` | `[0.45 0.62 0.50]` | sage |
| `fs-line-6` | `#A68C66` | `[0.65 0.55 0.40]` | tan |
| `fs-line-7` | `#668C99` | `[0.40 0.55 0.60]` | slate |
| `fs-line-8` | `#9E6B85` | `[0.62 0.42 0.52]` | plum |

### Heatmap ramp (optional)

`fs-heat-1..6` (`#EAF1FB → #123E73`) is a Pencil-only blue ramp for `HeatmapWidget` mocks. MATLAB
`HeatmapWidget` currently uses its own colormap; reconcile only if a heatmap is in scope (§5-g).

---

## 3. Typography

| Role | Pencil (mock) | MATLAB | Size |
|---|---|---|---|
| Font family | `fs-font` = **Inter** | `theme.FontName` = **Helvetica** | — |
| Dashboard header | — | `HeaderFontSize` | **14 pt** |
| Widget title | title header | `WidgetTitleFontSize` | **11 pt** |
| KPI value | big number | `KpiFontSize` | **28 pt** |
| Plot axis labels | 10 px | `FastSenseTheme.FontSize` | **10 pt** |
| Plot title | 12 px | `FastSenseTheme.TitleFontSize` | **12 pt** |

> **Font divergence.** Inter is not guaranteed present in MATLAB. Translator rule: **map Inter →
> `Helvetica`** (the theme default) or `'SansSerif'`. Do not add an Inter dependency. Inter in the
> mock is a visual stand-in for "clean grotesque sans"; Helvetica satisfies that at render time.

---

## 4. Surface specs

### 4.1 FastSense single plot — frame `UO6JB` (920 × 580)

```
┌───────────────────────────────────────────────┐  ← figure, fill fs-canvas
│ Toolbar  (h=40, fill fs-surface-alt, 1px btm)  │
│  title fs-ink 13·600 / subtitle fs-ink-2 10    │  ⟵ FastSenseToolbar
│  right: 6 tool buttons (26², fs-surface+border) │
├───────────────────────────────────────────────┤
│ pad 14                                          │
│  ┌───────── AxesCard  fill fs-surface, 1px ───┐ │  ⟵ axes: Color=white, Box=on
│  │ y-tick    · 5 H gridlines / 6 V gridlines  │ │     XColor/YColor = fs-ink-2
│  │ labels ·  · lines fs-line-1, fs-line-2     │ │     GridColor=fs-grid, GridAlpha=0.7
│  │ (fs-ink-2)· - - alarm threshold fs-alarm - │ │     threshold: line '--' fs-alarm
│  │           ·           [legend chip]        │ │     legend(): box fs-border on fs-surface
│  │ ───────── x-tick labels (fs-ink-2) ─────── │ │
│  └────────────────────────────────────────────┘ │
└───────────────────────────────────────────────┘
```

| Mock element | MATLAB target |
|---|---|
| Toolbar strip | `FastSenseToolbar` — bg `ToolbarBackground`, bottom hairline `WidgetBorderColor` |
| Title / subtitle | `text`/label, `fs-ink` bold + `fs-ink-2` |
| 6 tool buttons | toolbar buttons; glyph `fs-ink-2` on `fs-surface`, 1 px `fs-border` |
| Axes card | `axes` `Color=[1 1 1]`, `Box='on'`, `XColor=YColor=fs-ink-2`, `LineWidth≈0.75` |
| Gridlines | `grid on`, `GridColor=fs-grid`, `GridAlpha=0.7`, `GridLineStyle='-'` |
| Data lines | `plot` cycling `LineColorOrder` (muted), `LineWidth=1.0–1.8` |
| Alarm threshold | `line` `Color=ThresholdColor`, `LineStyle='--'` + right-aligned label |
| Legend chip | `legend` `Color=fs-surface`, `EdgeColor=fs-border`, `TextColor=fs-ink` |

Interior margins (at 920×580): y-label gutter **44 px**, x-label gutter **26 px**, top **10**, right **12**.
In MATLAB these are the axes `Position` insets — express as normalized (`≈[0.055 0.06 0.93 0.88]`).

### 4.2 Dashboard — frame `CK5l7` (1440 × 980)

**Mechanism (already in code):**
- `DashboardToolbar.Height = 0.04` (normalized) top strip, below optional `BannerHeight`.
- Optional page-tab bar (`PageBarHeight`) — active tab `TabActiveBg` / inactive `fs-tab-inactive`.
- Body = **24-column** grid (`DashboardLayout.Columns = 24`).
- Gutters & pad are theme-driven (wired in `DashboardEngine` before `allocatePanels`):
  `WidgetGapH = 0.006`, `WidgetGapV = 0.010`, `DashboardPad = [0.008 0.010 0.008 0.010]` (L B R T, normalized).
- Every widget = white `uipanel`, 1 px `WidgetBorderColor` → reads as a separated card.

| Mock widget (this frame) | MATLAB widget | Notes |
|---|---|---|
| KPI row (4 tiles: value + unit + trend) | `NumberWidget` | trend arrow `fs-ok`/`fs-alarm`; value `fs-ink`, unit/label `fs-ink-2` |
| Line chart "Reactor Temperature" | `FastSenseWidget` | muted lines, dashed alarm threshold (as §4.1) |
| Radial gauge "Overall Health 78" | `GaugeWidget` | arc `fs-ok`, track `fs-grid`, `GaugeArcWidth=8` |
| "Active Platforms" status list | `MultiStatusWidget` | dots `fs-ok`/`fs-warn`/`fs-alarm`; **monitor-kind only maps 0/1→alarm** |
| Bar chart "Data Logs / hr" | `BarChartWidget` | bars `fs-accent`; one alarm bar `fs-alarm` |
| Table "Sensor Events" | `TableWidget` | header `fs-ink`, rows `fs-ink-2`, status cells semantic |
| Widget title headers | `DashboardWidget.drawPanelTitle_` | bold `fs-ink`, `WidgetTitleFontSize` 11 |

### 4.3 Companion — frame `bmDPJ` (1200 × 760)

**Mechanism (already in code, `FastSenseCompanion.m`):**
`uifigure` → `uigridlayout` with `ColumnWidth = {220, '1x', 360}`, `RowHeight = {32, '1x', 360}`,
`ColumnSpacing = 16`, outer `Padding = 24` (`GridOuterPadding`).

| Grid cell | Pane / element | MATLAB |
|---|---|---|
| Row 1 (h=32), full width | Top toolbar (brand, mode, time controls) | toolbar grid `ColumnWidth {110,110,110,130,70,90,70,70,'1x',36}`, spacing 8 |
| Col 1 (w=220) | Tag catalog: search + filter pills + list | `TagCatalogPane` |
| Col 2 (`1x`) | Dashboard list (rows + "Open") | `DashboardListPane`; active row `fs-accent-soft`, "Open" `fs-accent` |
| Col 3 (w=360) | Inspector: title, sparkline, stats, CTAs | `InspectorPane` |
| Row 3 (h=360) | Event/log strip | `CompanionEventViewer` region |

| Mock element | MATLAB target | Token |
|---|---|---|
| Search field | `uieditfield`, `SearchFieldHeight = 28` | border `fs-border`, text `fs-ink` |
| Filter pill (active / idle) | pills, `FilterPillHeight = 24` | active bg `fs-accent`, idle `fs-surface-alt`/`fs-border` |
| Inspector sparkline | `FastSense`/axes mini-line | `fs-line-1` (muted), `CompanionTheme.LineColors{1}` |
| "In Plot" CTA | primary button | bg `fs-accent`, text `#FFFFFF` |
| "Add to Dashboard" | secondary button | `fs-surface` + `fs-border`, text `fs-ink` |
| Placeholder text | empty-pane labels | `PlaceholderTextColor` = `fs-ink-2` |

---

## 5. Redlines — gap between today's MATLAB and this target

What still has to change for the live app to match the frames. Ordered by visibility.

| # | Gap | Target | Status / effort |
|---|---|---|---|
| a | Plot line palette (mock was brighter) | muted `fs-line-*` | **DONE** — Pencil reconciled to muted; no MATLAB change |
| b | Font family | Inter (mock) vs Helvetica (app) | **Accept** — map Inter→Helvetica; no dependency |
| c | Rounded corners on chips/cards/buttons | square (MATLAB) | **Accept** — treat `cornerRadius=0` |
| d | Dashboard toolbar chrome (brand + Live pill + grouped buttons) | match mock toolbar | **DONE** (260709-gp9) — custom-drawn axes+patch layer over hidden `uicontrol` shim in `DashboardToolbar`; green Live pill; classic-figure controls can't be styled, so this was the only cheap path |
| e | Per-plot `X V A L +` strip (shared widget chrome) | fold into an overflow menu | **DONE** (260709-ikg) — `X`/`V`/`A`/`L`/`+` hidden (alive) behind a single `…` `OverflowMenuButton` in `DashboardLayout`; click posts a `uicontextmenu` routing to the same actions; Info + Detach stay visible |
| f | Status pills (OK/WARN/ALARM) | pill w/ soft bg (`fs-*-soft`) | **Open** — only fits in tall status cells; add `fs-*-soft` fields |
| g | Heatmap colormap | `fs-heat-1..6` ramp | **Open, optional** — only if a heatmap widget is in scope |

Items **a–c** are settled (accepted or done). **d** and **e** — the two that most changed the overall
look — are now implemented via the hide-not-delete compatibility-shim pattern (native controls stay
valid+hidden, a cheap custom layer is drawn over them). **f–g** remain optional polish.

---

## 6. Translation checklist (per widget / surface)

1. Confirm the widget's theme fields resolve to the §2 tokens (they do for `light`; verify after any theme edit).
2. Place primitives from the §1 budget only — no gradient/shadow/blur/rounded-panel.
3. Map every mock `cornerRadius` → 0; every `Inter` → `Helvetica`.
4. Colors: pull the MATLAB RGB triplet from §2, never hand-convert the hex.
5. Fonts/sizes: use the §3 point sizes (theme fields), not the mock's px.
6. Verify live: render in MATLAB (`example_dashboard_all_widgets` for the dashboard; a `FastSense`
   plot for §4.1; `FastSenseCompanion` for §4.3), screenshot, compare region-by-region to the frame.
7. Log any *new* divergence back into §5 rather than silently deviating.

---

## 7. Change log

- **2026-07-09** — Initial 1:1 spec. Reconciled Pencil line palette to MATLAB `muted`; added
  `fs-plot-ink`, `fs-tab-inactive`; added standalone `FastSense Light — Plot` frame (`UO6JB`).
