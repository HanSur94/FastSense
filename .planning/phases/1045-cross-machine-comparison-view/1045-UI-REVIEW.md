# Phase 1045 — UI Review

**Audited:** 2026-06-17
**Baseline:** `.planning/phases/1045-cross-machine-comparison-view/1045-UI-SPEC.md` (locked contract)
**Screenshots:** not captured — pure MATLAB `uifigure` surface, no web/dev server. Live human-verify checkpoint already APPROVED by user (builder + overlay + theme repaint correct on screen). This is a static contract-conformance audit.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | All locked strings exact; one pre-documented neutral empty-state addition, judged acceptable |
| 2. Visuals | 4/4 | ASCII-fallback glyphs, 1×6 row grid, [5 1] outer grid, empty-label action placeholder all per spec |
| 3. Color | 4/4 | Swatch = series color; CTA Accent/WidgetBorder gate; per-state badge colors; theme re-assert all correct |
| 4. Typography | 4/4 | Sizes 10/11 px and weights match the Typography table exactly |
| 5. Spacing | 4/4 | 36 px rows, RowSpacing 4, Padding [16 16 16 16]/[4 0 4 0], column widths all match |
| 6. Registry Safety | N/A | MATLAB uifigure — no component registry. PASS (not applicable) |

**Overall: 20/20 scored pillars (Registry N/A) — full contract conformance**

---

## Top 3 Priority Fixes

No BLOCKERs and no required fixes. The implementation conforms to the locked contract. The only deviation is the pre-documented neutral empty-state string, which is an acceptable UX improvement (see Pillar 1). Optional considerations only:

1. **(Optional, WARNING) Undeclared empty-state string** — `CompareBuilderDialog.m:373` renders `'Select a shared sensor to compare'` when machines exist but no sensor is picked. The UI-SPEC only locks `'No machines in fleet'`. Impact: positive — fills an otherwise-blank panel with guidance. Fix: ratify the string into the UI-SPEC Copywriting table so it is contract-tracked, or leave as-is (acceptable).
2. **(Optional) CTA FontColor in disabled (0-included) state** — `:629` uses `ToolbarFontColor` on `WidgetBorderColor` bg; spec line 249 matches. No action needed; flagged only because contrast on the dimmed CTA is the weakest text/bg pair in the dialog — verify legibility if a future theme darkens `WidgetBorderColor`.
3. **(Optional) Searchable/Placeholder R2020b guards** — `:121-129` correctly wrap both in try/catch per spec, but on pre-R2021a `Value=''` never executes, so `Items{1}` is the implicit selection. The `onClearSensor_` path (`:323`) already accounts for this. No fix; noted for completeness.

---

## Detailed Findings

### Pillar 1: Copywriting (4/4) — PASS

Exact-string verification against the Copywriting Contract:

- Dialog Name `'Compare Machines'` — `:89` PASS
- `'Shared sensor:'` — `:112` PASS
- Placeholder `'Select a sensor...'` — `:126` PASS (try/catch guarded)
- `'Clear'` + tooltip `'Clear shared sensor selection'` — `:134,:138` PASS
- `'Open Comparison'` + tooltip `'Open comparison overlay figure'` — `:167,:173` PASS
- `'Close'` — `:178` PASS
- Count badge `'%d of %d machines included'` / `'0 of %d machines included — select at least 2'` — `:613,:615` PASS (em-dash `—` present in 0-state)
- `'No machines in fleet'` — `:366` PASS
- Per-row `'Confirm'` + tooltip `'Include this machine (confidence: LOW)'` — `:470,:474` PASS
- Per-row `'Promote'` + tooltip `'Promote this override into the canonical map'` — `:483,:486` PASS
- Badge text: `✓ auto`/`⚠ confirm`/`✎ override`/`⚠ unit mismatch`/`✓ promoted`/`— none —` — `badgeSpec_` `:823-844` PASS (all glyphs via ASCII-fallback fields)
- Unit-mismatch alert copy + title `'Unit Mismatch Warning'`, icon `warning` — `:720-725` PASS
- Machines-skipped alert copy + title `'Machines Skipped'`, icon `info` — `:744-749` PASS
- Promote confirm: title `'Promote Override to Canonical Map'`, message arg order `localKey / logicalId / machineId`, Options `{'Promote','Cancel'}`, DefaultOption/CancelOption 2 — `:529-535` PASS
- Legend `[machineName]: [sensorDisplayName]` — `:683` PASS
- Error titles `'Promote Failed'` (`:292`), `'Comparison Failed'` (`:693`), `'Compare Builder'` (`:248` etc.) — PASS

**Noted deviation (acceptable):** `:373` `'Select a shared sensor to compare'` — an extra neutral empty-state not in the locked contract. Distinct from the locked `'No machines in fleet'` (which renders only at `machineCount()==0`, `:366`). This is the documented known deviation; it improves the empty-panel UX and does not collide with or alter any locked string. Judged acceptable; recommend ratifying into the spec.

### Pillar 2: Visuals (4/4) — PASS

- ASCII-fallback glyphs via `usejava('desktop')` — `:75-85` PASS (CHECK/WARN/PENCIL/DASH, with `'+'/'!'/'*'/'-'` fallbacks)
- Row layout 1×6 grid `{8,24,'1x','1x',80,60}` — `:401` PASS
- Outer `[5 1]` grid `{32,8,'1x',8,40}` — `:97` PASS
- Action slot uses empty `uilabel` placeholder when no button (`emptyActionSlot_`) — `:494-499`, dispatched for `auto`/`none`/`promoted` — PASS
- Swatch = empty-text `uilabel` with `BackgroundColor` — `:408-413` PASS
- Toolbar: fleet `[1 12]` grid, Compare at col 9, spacer→10, active-machine→11, gear→12; legacy stays `[1 10]` byte-identical — `FastSenseCompanion.m` diff PASS

### Pillar 3: Color (4/4) — PASS

- Swatch = per-machine series color `rs.color` (sourced from `buildCompareResolution_` 3-arg theme form, NOT a theme token) — `:412`; re-asserted in `applyTheme_` `:241-243` PASS
- Open CTA bg `Accent` when includedCount≥1 else `WidgetBorderColor`; FontColor `DashboardBackground` (Accent) / `ToolbarFontColor` (dimmed) — `:624-630` PASS (matches spec lines 247-249). Initial construction starts dimmed (`:170-172`), corrected on first `updateCountAndOpen_` via `rebuildRows_` — PASS
- Badge FontColors per state: auto→`ToolbarFontColor`, confirm_needed→`StatusWarnColor`, override→`ToolbarFontColor`, unit-mismatch→`StatusWarnColor`, promoted→`Accent`, none→`ToolbarFontColor` — `badgeSpec_` `:822-844` PASS
- Theme repaint re-asserts swatch colors (`:241-243`) + badge colors (`:244` via `applyBadge_`) + figure Color (`:235`) + Open button (`:246`) after the walker (`:236`) — PASS

### Pillar 4: Typography (4/4) — PASS

- 11 px: `'Shared sensor:'` label, sensor dropdown, Clear, count badge, Open CTA, Close, machine name, row dropdown, action buttons — verified at `:114,:119,:135,:159,:168,:179,:426,:435,:472,:483` PASS
- 10 px: status badge — `:452` PASS
- Weights: `'bold'` on Open CTA (`:169`), machine name (`:427`); `'normal'` (default) elsewhere — PASS. (Dialog title row is the quick-fill strip — there is no separate bold "Compare Machines" header label inside the body; the title lives on the uifigure `Name`. Spec Typography row 1 names the figure title, satisfied by `:89`.)

### Pillar 5: Spacing (4/4) — PASS

- Outer grid Padding `[16 16 16 16]`, RowSpacing 0, RowHeight `{32,8,'1x',8,40}` — `:97-100` PASS
- Row grid: RowHeight 36 (`repmat({36},...)`), RowSpacing 4, Padding `[0 0 0 0]` — `:380-383` PASS
- Per-row nested grid Padding `[4 0 4 0]`, ColumnSpacing 4, ColumnWidth `{8,24,'1x','1x',80,60}` — `:401-404` PASS
- Quick-fill strip ColumnSpacing 8, ColumnWidth `{'fit','1x',80}` — `:107-109` PASS
- CTA strip ColumnSpacing 8, ColumnWidth `{'1x',120,80}` — `:151-153` PASS
- uifigure 600×480, Resize on, AutoResizeChildren off — `:90-92` PASS
- Toolbar Compare column 80 px fixed — diff PASS

### Pillar 6: Registry Safety (N/A) — PASS

No component registry. MATLAB uifigure built-ins only (`uifigure`, `uigridlayout`, `uipanel`, `uicheckbox`, `uidropdown`, `uibutton`, `uilabel`). No shadcn, no npm, no third-party blocks. `components.json` absent. Nothing to vet.

---

## Files Audited

- `/Users/hannessuhr/PARA/10_Projects/FastPlot/.claude/worktrees/friendly-leakey-0bc166/libs/FastSenseCompanion/CompareBuilderDialog.m` (full, 868 lines)
- `/Users/hannessuhr/PARA/10_Projects/FastPlot/.claude/worktrees/friendly-leakey-0bc166/libs/FastSenseCompanion/FastSenseCompanion.m` (toolbar diff `44cd5f10..HEAD`)
- `/Users/hannessuhr/PARA/10_Projects/FastPlot/.claude/worktrees/friendly-leakey-0bc166/.planning/phases/1045-cross-machine-comparison-view/1045-UI-SPEC.md` (contract baseline)
