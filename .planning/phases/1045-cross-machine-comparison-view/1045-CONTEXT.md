# Phase 1045: Cross-Machine Comparison View - Context

**Gathered:** 2026-06-10
**Status:** Ready for planning

<domain>
## Phase Boundary

A **machine-first cross-machine comparison**: a modeless compare-builder dialog (Approach A, locked) where the user selects machines, sets each machine's data (shared-sensor quick-fill via the canonical map, or a per-machine local tag), and opens an overlay figure via the existing `openAdHocPlot` Overlay path. Confidence-gated auto-resolution (LOW/unreviewed matches need explicit per-machine confirmation), graceful skip for machines lacking the sensor, per-machine stable colors with machine-qualified legends, and resolve-once-at-open caching so live ticks never call `CanonicalMapper.resolve` (CMP-05 invariant).

In scope: `CompareBuilderDialog` (new modeless second uifigure, `CompanionSettingsDialog` pattern), fleet-mode toolbar Compare button, additive `'SeriesColors'`/`'SeriesLabels'` NV args on `openAdHocPlot`, per-machine color assignment, confidence gate + unit-mismatch warnings + per-row promote-to-map, skip surfacing, open-time resolution caching, tests.

Out of scope: changes to the 3 Companion panes or `setProject` (locked: none); dashboard clone/remap (Phase 1046); fleet-wide health badges; persisting promotions to disk (user's `Fleet.save` remains the save path).

</domain>

<decisions>
## Implementation Decisions

User accepted all recommendations across three grey areas (smart discuss, autonomous mode). Grounded in CMP-UX-MATLAB-RESEARCH (Pattern 5 = lowest friction), CMP-UX-PRIORART, and the locked v5.0 Approach A.

### Compare-Builder Dialog Composition (CMP-01, CMP-06)
- **Entry point:** a **toolbar "Compare" button shown in fleet mode only** — legacy (no-Fleet) toolbar stays byte-identical (mirrors the 1044 selector rule).
- **Machine list:** **one row-grid per fleet machine** — checkbox (include) + machine name + per-machine resolution `uidropdown` + status badge (auto/confirm-needed/none/override). DashboardListPane per-row grid idiom; rows carry the CMP-06 states. Not uilistbox+detail-panel.
- **Data selection model:** **top "shared sensor" quick-fill `uidropdown`** (canonical logical ids from `CanonicalMapper`) that auto-resolves per checked machine, **plus per-row override dropdowns** (that machine's local tags). R2021a `Searchable` wrapped in try/catch (R2020b guard idiom).
- **Lifecycle:** **singleton modeless second uifigure** per companion (`CompareBuilderDlg_` handle property; re-invoke focuses existing; closes with companion `close()`; `CompanionSettingsDialog` precedent at FastSenseCompanion.m:1049-1060).

### Per-Machine Color & openAdHocPlot Injection API (CMP-02) — resolves the STATE-flagged decision
- **Stable color scheme:** **fleet-insertion-index → `CompanionTheme.LineColors` palette (modulo)** — deterministic per machine (NOT selection order), matches machine-selector ordering, Octave-safe. Not Id-hash.
- **Injection API (the flagged 'colors arg vs struct-array' decision):** **additive optional NV args on `openAdHocPlot`: `'SeriesColors'` (cell of RGB triples) + `'SeriesLabels'` (cellstr), parallel to the existing 1xN tag cell.** Legacy calls remain byte-unchanged; absent args = current `ColorOrder` auto-assignment.
- **Legend label:** `[machineName]: [sensorDisplayName]` (pinned by SC2).
- **Palette exhaustion:** simple modulo cycle (no linestyle variation in v1).

### Resolution Flow, Confidence Gate & Promotion (CMP-03, CMP-04, CMP-05, CMP-06)
- **LOW-confidence / unreviewed matches:** **per-row inline gate** — the row is excluded-by-default with a "needs confirm" badge and the candidate preselected; a per-row Confirm action includes it. No batch modal.
- **Unit mismatch on manual substitution:** **inline row warning badge + one consolidated non-blocking `uialert` at Open time** listing all mismatches. Open is never blocked by unit mismatch (warned, not refused).
- **Promotion:** **per-row "Promote" action** appears on manually-overridden rows; calls the existing `CanonicalMapper` promote/override path (same as `CanonicalMapEditor`); in-memory only — persisting remains the user's `Fleet.save`. Never auto-promote.
- **Missing sensor (CMP-03):** row shows **`— none —`**, machine excluded from Open; at Open a **consolidated non-blocking alert + an events-log entry** lists skipped machines; the comparison opens with the remaining machines.
- **Caching (CMP-05, pinned invariant):** all tags resolved **once at Open** into a cached cell; the overlay figure's live path calls `updateData` only; `CanonicalMapper.resolve` absent from steady-state tick profile.

### Claude's Discretion
Planner may refine: exact dialog grid dims/labels (UI-SPEC will pin them), badge glyphs/copy, error ids (`FastSenseCompanion:*` / `CompareBuilderDialog:*`), dropdown population helpers, and test file naming — as long as the 5 ROADMAP success criteria, the locked Approach A constraints (no pane/setProject changes), and the milestone critical invariants hold (incl. LOW-confidence exclusion rule #4 and resolve-absent-from-tick-profile #5).

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CompanionSettingsDialog` (FastSenseCompanion.m:1049-1060 invocation) — the singleton modeless second-uifigure pattern to copy for `CompareBuilderDialog`.
- `private/openAdHocPlot.m` — Overlay path already accepts a 1xN Tag cell (`:18`); gains optional `'SeriesColors'`/`'SeriesLabels'`; `findEventStoreFor_` already degrades gracefully for unregistered (machine-scoped) tags (1044 WR-03 fix, `FastSenseCompanion:machineScopedTagNoOverlay`).
- `Fleet.resolveLogical(logicalId)` → Nx2 {Machine, Tag} pairs (1042) — the quick-fill resolution engine. `Fleet.machineIds()` (1044) for insertion-index color mapping.
- `CanonicalMapper` confidence levels + promote/override path (1041; `CanonicalMapEditor` precedent), `toStruct/fromStruct`.
- `MachineSelectorPane`/`DashboardListPane` row-grid + badge idioms; `trackOpenedFigure_` (FastSenseCompanion.m:~2099) so the overlay joins Tile/Close-all.
- 1044 conditional-toolbar precedent for the fleet-only Compare button ([1 11] grid gains a column or reuses spacer region in fleet mode only).

### Established Patterns
- Second uifigure dialogs: singleton handle property + `isvalid` focus-or-create + companion `close()` teardown; every timer `stop;delete`; `Listeners_` hygiene; callbacks try/catch + non-blocking uialert; errors namespaced.
- Octave-safety only matters for pure logic (resolution/color-index helpers) — the dialog itself is MATLAB-only (uifigure), mirroring the 1044 class-suite/flat-test split.
- R2020b guards: `Placeholder`/`Searchable` in try/catch; no uitable checkbox columns (R2022a+) — per-row uicheckbox in row-grids instead (research caveat #3).

### Integration Points
- Toolbar: fleet-mode Compare button → `openCompareBuilder_()` → `CompareBuilderDlg_` singleton.
- Open action: build resolved {tag, color, label} triples → `openAdHocPlot(tags, 'Overlay', ..., 'SeriesColors', c, 'SeriesLabels', l)` → tracked overlay figure.
- Critical invariants #4/#5 (STATE.md) verified at phase gate: LOW-confidence never auto-included; `CanonicalMapper.resolve` not in steady-state tick profile.

</code_context>

<specifics>
## Specific Ideas

- Builder reads as: [shared-sensor quick-fill dropdown] above [machine rows], "Open Comparison" primary CTA at bottom — signal-first flow within a machine-first dialog (prior-art Pattern D, adapted).
- Per-row states: ✓ auto (HIGH confidence) / ⚠ confirm (LOW/unreviewed) / — none — / ✎ override (+Promote).
- Colors come from the machine, not the selection: re-opening with a different machine subset keeps each machine's color.

</specifics>

<deferred>
## Deferred Ideas

- Persisting promotions automatically (auto `Fleet.save` after promote) — explicit user save remains v1.
- Linestyle variation on palette exhaustion.
- Comparison presets / saved comparisons; time-period layer comparison (TrendMiner-style) — future milestone.
- Per-machine dashboard clone/remap — Phase 1046.

</deferred>
