---
phase: 1045-cross-machine-comparison-view
reviewed: 2026-06-17T00:00:00Z
depth: deep
files_reviewed: 7
files_reviewed_list:
  - libs/FastSenseCompanion/CompareBuilderDialog.m
  - libs/FastSenseCompanion/FastSenseCompanion.m
  - libs/FastSenseCompanion/private/buildCompareResolution_.m
  - libs/FastSenseCompanion/private/compareSeriesColor_.m
  - libs/FastSenseCompanion/private/openAdHocPlot.m
  - libs/Fleet/CanonicalMapper.m
  - libs/Fleet/Fleet.m
findings:
  critical: 0
  warning: 3
  info: 5
  total: 8
status: issues_found
---

# Phase 1045: Code Review Report

**Reviewed:** 2026-06-17
**Depth:** deep (cross-file: dialog ↔ companion ↔ Fleet/Machine/CanonicalMapper ↔ openAdHocPlot)
**Files Reviewed:** 7
**Status:** issues_found

## Summary

The 1045 delta is well-structured and the six locked critical invariants all hold:
machine tags never touch `TagRegistry` (grep clean); no UI primitives added to
`libs/Fleet/`; no `contains(` in `CanonicalMapper.m`; the LOW+AUTO confidence gate
in `buildCompareResolution_` (line 64) and the default-checked rule in
`resolveAllRows_` (line 349) correctly exclude LOW matches; `onOpenComparison_`
resolves through `machine.get()` only — never a `CanonicalMapper` method — after the
`ResolvedTags_` cache populates (resolve-once #5 holds); and Promote is in-memory
(`mapper().override`, no `Fleet.save`). All callbacks are try/catch-wrapped with
non-blocking `uialert`, and errors are namespaced.

No blockers found. The material findings are three WARNINGs: a stale-handle /
re-entrancy gap in the async Promote `CloseFcn` path (the most important one), a
unit-string mislabel in the Open-time mismatch alert, and a missing legacy/`[]`-fleet
guard in the dialog constructor. The rest are Info-level encapsulation and robustness
nits. Index-alignment of `ResolvedTags_`/`seriesColors`/`seriesLabels` is correct
(all three grow together in the same loop), and the in-place action-widget delete/
rebuild in `refreshRowWidgets_` is leak-safe (old handle deleted before reassignment,
struct written back).

## Warnings

### WR-01: `onPromoteConfirmed_` trusts a captured row index `i` across an async boundary with no bounds/identity guard

**File:** `libs/FastSenseCompanion/CompareBuilderDialog.m:270-294` (and the closure created at `:535`)
**Issue:**
`onPromote_` opens a `uiconfirm` whose `CloseFcn` captures the row index `i`
(`@(~, event) obj.onPromoteConfirmed_(i, event)`). `onPromoteConfirmed_` then does
`rs = obj.RowStates_{i}` (line 283) with **no bounds check** — unlike its siblings
`onConfirm_` (line 258) and `onRowAction_` (line 507), which both guard
`i < 1 || i > numel(obj.RowStates_)`. If `RowStates_` shrank between opening the
confirm and the callback firing (e.g. a re-resolve via `onSensorSelected_`/
`onClearSensor_` rebuilt the rows to a shorter set), `RowStates_{i}` throws an
out-of-range error. It is caught by the surrounding try/catch and surfaced as a
"Promote Failed" alert, so it will not crash the event loop — but worse, if the array
is the *same length but now describes different machines*, `onPromoteConfirmed_` would
silently promote the override against the **wrong** `machineId`/`localKey`
(`rs.machineId`, `rs.localKey` come from the post-rebuild row). In practice `uiconfirm`
is modal to `obj.hFig_`, so the user cannot drive a rebuild while the dialog is up,
which keeps this latent — but the method is also a public test seam invoked directly
with synthetic events, where no such modality protects it.
**Why it matters:** A mis-indexed promote writes an incorrect canonical mapping into
the in-memory map — a silent data-correctness defect on the very path the phase is
built to protect. The asymmetry with the other two dispatch methods (which *do* guard)
shows the guard was simply omitted here.
**Fix:** Add the same guard at the top of `onPromoteConfirmed_`, and ideally re-verify
identity rather than just bounds:
```matlab
function onPromoteConfirmed_(obj, i, event)
    try
        if ~strcmp(event.SelectedOption, 'Promote'); return; end
        if i < 1 || i > numel(obj.RowStates_); return; end
        rs = obj.RowStates_{i};
        % defensive: only promote a row still in an unpromoted override state
        if ~strcmp(rs.state, 'override') || (isfield(rs,'promoted') && rs.promoted)
            return;
        end
        obj.App_.fleet().mapper().override(obj.CurrentLogicalId_, rs.machineId, rs.localKey);
        ...
```

### WR-02: Open-time unit-mismatch alert prints the **canonical** unit, not the diverging tag unit

**File:** `libs/FastSenseCompanion/CompareBuilderDialog.m:715-716`
**Issue:**
`warnUnitMismatches_` formats each line as
`'  %s %s: %s (unit: %s)'` with the last `%s` = `rs.localUnits`. But `rs.localUnits`
is the **canonical reference unit** (copied from the resolved CanonicalMapper entry in
`buildCompareResolution_:62`, and never re-pointed to the override tag's unit in
`onRowDropdownChanged_`). The mismatch was detected precisely because the override
tag's `Units` *differs* from `rs.localUnits` (`detectRowUnitMismatch_:803`). So the
alert tells the operator the unit they were comparing *against*, while claiming it is
the unit that "may differ from the shared sensor." The UI-SPEC copy (line 622,
"tags with units that may differ … localKey (unit: X)") intends X = the divergent
tag's unit.
**Why it matters:** The whole point of the consolidated mismatch alert is to let the
operator eyeball the y-axis scale risk before analysis. Showing the canonical unit
instead of the actual tag unit gives them the wrong number to reason about — an
actively misleading message, not just a cosmetic one.
**Fix:** Look up and print the override tag's own unit. `detectRowUnitMismatch_`
already fetches `tag.Units`; cache it on the row (e.g. `rs.tagUnits`) when it sets
`rs.unitMismatch = true`, and print that:
```matlab
lines{end+1} = sprintf('  %s %s: %s (unit: %s)', ...
    char(8226), nm, rs.localKey, rs.tagUnits);
```
(or re-resolve the tag unit inside `warnUnitMismatches_`). Keep `rs.localUnits`
available too if you want "expected X, got Y" phrasing.

### WR-03: `CompareBuilderDialog` constructor crashes if `app.fleet()` returns `[]` (no legacy-mode guard)

**File:** `libs/FastSenseCompanion/CompareBuilderDialog.m:64-120`
**Issue:**
The constructor validates `isa(app,'FastSenseCompanion')` but not that the companion is
in fleet mode. Line 120 immediately dereferences
`keys(app.fleet().mapper().Entries_)`. `FastSenseCompanion.fleet()` returns `[]` in
legacy single-machine mode (its own docstring says so), and `[].mapper()` throws an
opaque MATLAB error ("No appropriate method/property `mapper` for class double") rather
than the project's namespaced `CompareBuilderDialog:*` contract. The toolbar Compare
button only exists in fleet mode, so the production path is safe — but the constructor
is public and directly constructed by the class-suite and any external caller, and the
phase's own error-namespacing contract (UI-SPEC line 734,
`CompareBuilderDialog:invalidApp` thrown in constructor) is violated for this input.
**Why it matters:** Defense-in-depth + contract conformance. A direct
`CompareBuilderDialog(legacyApp)` should fail loudly with a namespaced, actionable
error, not a raw double-dispatch error from deep in `uidropdown` setup (after the
uifigure has already been created and leaked).
**Fix:** Guard right after the `isa` check, before creating the figure:
```matlab
if isempty(app.fleet())
    error('CompareBuilderDialog:notFleetMode', ...
        'CompareBuilderDialog requires a fleet-mode FastSenseCompanion (no Fleet present).');
end
```

## Info

### IN-01: Dialog reaches into `CanonicalMapper.Entries_` directly instead of a public `keys()` accessor

**File:** `libs/FastSenseCompanion/CompareBuilderDialog.m:120`
**Issue:** `obj.hSensorDD_.Items = keys(app.fleet().mapper().Entries_)` pokes the
publicly-readable-but-`SetAccess=private` internal `containers.Map`. The UI-SPEC
(lines 198, 458) specifies populating from `CanonicalMapper.keys()`, but no such public
method exists on `CanonicalMapper` (confirmed: methods are suggest/override/confirm/
reviewPending/resolve/isResolvable/unmapped/toStruct/save/fromStruct/load). This
couples the dialog to the mapper's internal storage shape; if `Entries_` is ever
renamed or restructured, the dialog breaks silently.
**Fix:** Add a one-line public `function ids = logicalIds(obj); ids = keys(obj.Entries_); end`
to `CanonicalMapper` and call `app.fleet().mapper().logicalIds()` here. Matches the
`Fleet.mapper()`/`machineIds()` seam philosophy this phase otherwise follows.

### IN-02: `keys()` of a `containers.Map` returns a row cell — `uidropdown.Items` ordering is map-key order, not insertion/fleet order

**File:** `libs/FastSenseCompanion/CompareBuilderDialog.m:120`
**Issue:** `keys(containers.Map)` returns keys in sorted (lexicographic) order, not
insertion order. This is harmless for correctness (any logical id is selectable) but
means the quick-fill list order is not stable against how the mapper was built and may
surprise users who expect catalog/insertion order. Purely a UX nit; no functional
impact.
**Fix:** None required. If insertion order is desired later, track it in the mapper.

### IN-03: `onPromoteConfirmed_` sets `rs.status = 'OVERRIDDEN'` but never `rs.state`

**File:** `libs/FastSenseCompanion/CompareBuilderDialog.m:283-288`
**Issue:** The promoted row keeps `rs.state == 'override'` and relies on the
`rs.promoted` flag for both `badgeSpec_` (checks `promoted` first → "✓ promoted",
line 831) and `buildActionWidget_` (checks `promoted` → empty slot, line 477). This is
correct given the current ordering of those checks, but it leaves `rs.status` and
`rs.state` describing different things (`status='OVERRIDDEN'`, `state='override'`),
relying on every future reader to check `promoted` before `state`. Mildly fragile.
**Fix:** Optional — either introduce an explicit `'promoted'` state or add a comment at
both check sites noting that `promoted` is the discriminator that must be tested before
`state`/`unitMismatch`.

### IN-04: `onRowDropdownChanged_` → `'none'` path leaves a stale `rs.color`/`rs.localUnits`/`rs.confidence`

**File:** `libs/FastSenseCompanion/CompareBuilderDialog.m:570-574`
**Issue:** When the user selects `'— none —'`, the code resets `state`, `checked`,
`localKey`, `unitMismatch` but leaves `localUnits`, `localName`, `confidence`, `status`,
and `color` from the prior resolution on the struct. None are read while in `none`
state (badge/action switch on `state`), so this is currently inert, but it is a latent
trap: if a future code path reads `rs.localUnits` for a `none` row it gets stale data.
**Fix:** Clear the companion fields when transitioning to `none`, mirroring
`emptyRow_()` defaults:
```matlab
rs.localUnits = ''; rs.localName = ''; rs.confidence = ''; rs.status = '';
```

### IN-05: `warnSkippedMachines_` and `includedIndices_`/`includedCount_` duplicate the inclusion predicate

**File:** `libs/FastSenseCompanion/CompareBuilderDialog.m:634-643, 697-706, 729-752`
**Issue:** The "checked AND not none" predicate is open-coded in `includedCount_`
(line 639) and `includedIndices_` (line 702); the inverse skip predicate is open-coded
in `warnSkippedMachines_` (line 735). They are consistent today, but a future change to
one (e.g. adding a new excluded state) risks the count/open-set and the skip-alert
drifting out of sync — a classic inclusion/exclusion mismatch source.
**Fix:** Factor a single `tf = obj.isIncluded_(rs)` helper and define skipped as
`~isIncluded_ && ~strcmp(state,'auto'-already-counted)`; have all three call it.

---

## Resolution (fixes applied 2026-06-17)

All 3 WARNINGs + 3 of the 5 INFOs fixed in `CompareBuilderDialog.m` / `CanonicalMapper.m`:

- **WR-01** — `onPromoteConfirmed_` now bounds-checks `i` AND re-verifies the row is still an unpromoted `override` before calling `override` (rejects a stale/out-of-range async index).
- **WR-02** — `warnUnitMismatches_` now prints the diverging **tag** unit via a shared `tagUnits_` helper (also refactored `detectRowUnitMismatch_` onto it).
- **WR-03** — constructor now throws `CompareBuilderDialog:notFleetMode` when `app.fleet()` is `[]`.
- **IN-01** — added `CanonicalMapper.logicalIds()`; the dialog populates the quick-fill via it instead of poking `Entries_`.
- **IN-04** — the `'— none —'` transition clears the stale `localUnits`/`localName`/`confidence`/`status`.
- **IN-05** — factored a single `isIncluded_(rs)` predicate shared by `includedCount_`/`includedIndices_`.
- IN-02 (map key order) and IN-03 (status/state divergence) left as-is per the report (no fix required; IN-03 covered by an inline comment at the discriminator).

**Re-verification:** `check_matlab_code` clean on both files; a 10-check review-fix smoke is green (legacy-guard throws; `logicalIds` populates; out-of-range + re-promote guards no-op; valid promote → `OVERRIDDEN`; none-clear; unit-mismatch override → `⚠ unit mismatch` + diverging unit `K`). Full `TestFastSenseCompanion.m` re-run = **90/91**, the single failure being the pre-existing `testADHOC05_noOrphanTimersAfterPlotAndClose` orphan-debounce-timer flake — a **legacy-mode ad-hoc path** test that `delete()`s its spawned figure (bypassing the engine's `stopLive`); it exercises none of the changed code and is timing-sensitive (green in the phase-verification run). All 7 CMP tests remain green.

---

_Reviewed: 2026-06-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
