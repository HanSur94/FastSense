---
phase: 1044-companion-machine-dimension
reviewed: 2026-06-10T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - libs/Fleet/Fleet.m
  - libs/FastSenseCompanion/MachineSelectorPane.m
  - libs/FastSenseCompanion/MachineSelectionEventData.m
  - libs/FastSenseCompanion/private/filterMachines.m
  - libs/FastSenseCompanion/runFilterMachinesTests.m
  - libs/FastSenseCompanion/FastSenseCompanion.m
  - libs/FastSenseCompanion/TagCatalogPane.m
  - tests/suite/TestFastSenseCompanion.m
  - tests/test_fleet.m
  - tests/test_machine_selector_pane.m
findings:
  critical: 0
  warning: 6
  info: 7
  total: 13
status: findings
---

# Phase 1044: Code Review Report

**Reviewed:** 2026-06-10
**Depth:** standard
**Files Reviewed:** 10
**Status:** findings

## Summary

Reviewed the Phase 1044 diff (a0ceff0a..working tree): `Fleet.machineIds()`, the new
`MachineSelectorPane` + `MachineSelectionEventData` + `filterMachines` trio, the
`'Fleet'` NV pair and conditional `[3 4]`/`[3 3]` construction in `FastSenseCompanion`,
the four redirected registry-read conditionals, `onMachineSelected_`, and the new tests.

The hard invariants mostly hold: legacy construction is structurally unchanged
(verified branch-by-branch — every fleet-conditional has a byte-equivalent legacy
else-path), `setProject`'s clear-all/re-wire correctly re-registers the
`MachineSelectionChanged` listener so the rail survives switches, the live timer is
reused (stop-without-delete + reuse in `startLiveMode`) so the `timerfindall`
invariant is genuine, `Machine.Dashboards` defaults to `{}` so the `iscell` wrap is
safe, and error IDs are correctly namespaced. `Fleet.machineIds()` returns a value
copy of the cell, so internals cannot be mutated by callers.

However, six warning-level defects were found: the new pane's 150 ms debounce is
nonfunctional (wrong timer property for `singleShot` mode), the listbox highlight can
silently desync from the active machine and become un-clickable, machine isolation is
incomplete (4 static `TagRegistry.find` + 2 `TagRegistry.get` reads remain inside
`libs/FastSenseCompanion`, violating the research's own "grep returns 0" audit
criterion), `setProject` — now a per-click hot path — wipes the EventViewer
destruction listeners without re-registering them (Events button can stick disabled),
the `TagCatalogPane` redirect introduces a crash path for registry values the old
static call tolerated, and the constructor's fleet branch skips the dashboard
validation that every other intake path enforces.

## Warnings

### WR-01: 150 ms search debounce is nonfunctional — `Period` is ignored by `singleShot` timers

**File:** `libs/FastSenseCompanion/MachineSelectorPane.m:230-241`
**Issue:** The lazily-created debounce timer sets `ExecutionMode = 'singleShot'` and
`Period = 0.150`, but never sets `StartDelay`. For `singleShot` timers MATLAB executes
`TimerFcn` once, `StartDelay` seconds after `start()`; `Period` only applies to the
`fixed*` modes. `StartDelay` defaults to 0, so the "debounced" filter fires
essentially immediately on every `ValueChanged`, and the stop/restart "reset
countdown" logic at lines 238-241 resets nothing. The phase deliverable explicitly
specifies a 150 ms debounce (MACH-01 / CONTEXT.md locked constant). The same latent
defect exists in `TagCatalogPane.m:360-362` and `DashboardListPane.m:365-367` — the
phase replicated the broken template into a third file rather than fixing it.
**Fix:**
```matlab
obj.DebounceTimer_ = timer();
obj.DebounceTimer_.ExecutionMode = 'singleShot';
obj.DebounceTimer_.StartDelay    = 0.150;   % singleShot delay lives here, not Period
obj.DebounceTimer_.BusyMode      = 'drop';
obj.DebounceTimer_.TimerFcn      = @(~,~) obj.applyFilter_();
```
(Consider a follow-up quick task fixing the two pre-existing panes the same way.)

### WR-02: Listbox highlight silently desyncs from the active machine after filtering — and the desynced row cannot be clicked back

**File:** `libs/FastSenseCompanion/MachineSelectorPane.m:195-223` (`applyFilter_`)
**Issue:** `applyFilter_` rebuilds `Items`/`ItemsData` but never restores the active
machine's selection. The pane keeps no active-id state at all. When a search term
filters the active machine out of the list, MATLAB silently resets the single-select
`Value` to the first visible item — without firing `ValueChangedFcn`. Result: the
list highlights machine X while the toolbar indicator (MACH-03) names machine Y.
Worse, clicking the highlighted row X produces no `ValueChanged` event (no value
change), so the user cannot activate the machine the UI shows as selected; clearing
the search leaves the highlight on the wrong machine permanently. This directly
undermines MACH-03 ("the companion always indicates which machine is the active
context") — the two indicators contradict each other.
**Fix:** Track the active id (set it in `onMachineSelected_` and `selectById`), and at
the end of `applyFilter_` re-assert it when present:
```matlab
if ~isempty(obj.ActiveId_) && any(strcmp(itemsData, obj.ActiveId_))
    obj.hListbox_.Value = obj.ActiveId_;
end
```

### WR-03: Machine isolation incomplete — 6 global-registry reads remain inside the companion library

**File:** `libs/FastSenseCompanion/InspectorPane.m:639`, `libs/FastSenseCompanion/private/inspectorResolveState.m:43`, `libs/FastSenseCompanion/private/openAdHocPlot.m:165`, `libs/FastSenseCompanion/private/companionDiscoverEventStore.m:39`, `libs/FastSenseCompanion/CompanionEventViewer.m:1417,1542`
**Issue:** The four planned sites (TagCatalogPane attach/refresh, the live status
scan) were redirected, but 1044-RESEARCH.md's own audit criterion — "`grep -n
"TagRegistry.find" libs/FastSenseCompanion/` should return 0 after implementation"
(line 278) — is not met: four `TagRegistry.find` calls plus two `TagRegistry.get`
calls still read the global singleton. Concrete fleet-mode consequences:
1. A fleet machine's own `MonitorTag`s never appear in the inspector's monitor-rule
   pane (`InspectorPane.m:639`) or as ad-hoc plot threshold overlays
   (`openAdHocPlot.m:165`) — the machine's tags live in `Machine.Tags_`, not the
   global registry, so these scans return nothing for them.
2. Cross-contamination in the reverse direction: if the global `TagRegistry`
   persistent singleton holds tags from an earlier legacy session in the same MATLAB
   instance (a likely migration scenario, with matching key names like
   `cooling.temp`), those foreign monitors/thresholds are drawn over the active
   fleet machine's data — silently wrong overlays in an analysis tool.
**Fix:** Either redirect these sites through the active context (thread `Registry_` /
the companion handle into `InspectorPane`, `openAdHocPlot`, `inspectorResolveState`,
`CompanionEventViewer` and branch as done in `TagCatalogPane`), or document the
remaining sites as explicit deferred scope in the phase artifacts and guard them to
return empty in fleet mode (never read the global singleton when `Fleet_` is set).

### WR-04: Machine switch wipes the EventViewer destruction listeners — Events button can stick disabled for the session

**File:** `libs/FastSenseCompanion/FastSenseCompanion.m:895-929` (clear-all + re-wire), `:2128-2137` (registration), `:2279-2290` (re-enable)
**Issue:** `openEventViewer_` stores two `ObjectBeingDestroyed` listeners in
`Listeners_` (lines 2128-2131) whose callback `clearEventViewerHandle_` re-enables the
Events toolbar button disabled at line 2135. `setProject` deletes ALL of `Listeners_`
(895-901) and its re-wire block (902-929) re-registers the pane listeners and — per
this phase — the machine-selector listener, but NOT the EventViewer listeners.
Sequence: open Event Viewer → click a machine (Phase 1044 makes `setProject` fire on
every click) → close the viewer → `clearEventViewerHandle_` never runs → the Events
button remains `Enable='off'` with tooltip "Event viewer is open" for the rest of the
session. This was latent pre-phase (setProject was a rare explicit API call); Phase
1044 turns it into the primary interaction path, so the phase materially worsens the
exposure.
**Fix:** In `setProject`'s re-wire block, re-register the viewer listeners when a
viewer is open:
```matlab
if ~isempty(obj.EventViewer_) && isvalid(obj.EventViewer_) && ...
        ~isempty(obj.EventViewer_.hFigure) && isgraphics(obj.EventViewer_.hFigure)
    obj.Listeners_{end+1} = addlistener(obj.EventViewer_.hFigure, ...
        'ObjectBeingDestroyed', @(~,~) obj.clearEventViewerHandle_());
    obj.Listeners_{end+1} = addlistener(obj.EventViewer_, ...
        'ObjectBeingDestroyed', @(~,~) obj.clearEventViewerHandle_());
end
```
(Or keep these two listeners in a separate property that the clear-all does not touch.)

### WR-05: TagCatalogPane redirect introduces a crash path for registry values the old static call tolerated

**File:** `libs/FastSenseCompanion/TagCatalogPane.m:62-66` (attach), `:212-217` (refresh)
**Issue:** Before this phase, `attach`/`refresh` called static `TagRegistry.find(...)`
and ignored `Registry_` entirely, so any registry value — including `[]` — worked.
The new else-branch calls `obj.Registry_.find(@(t) true)` on whatever was stored. The
public `setProject(dashboards, registry)` (FastSenseCompanion.m:846-866) validates
`dashboards` but performs zero validation on `registry`; a caller passing `[]` (or
any non-find-capable value) — previously harmless — now gets a raw
"Dot indexing is not supported…" crash from deep inside `attach` instead of a
namespaced error. The constructor path is safe only because Step 5 defaults
`userRegistry = TagRegistry` (line 259).
**Fix:** Make the static branch the safe default and/or validate at the boundary:
```matlab
if isempty(obj.Registry_) || isa(obj.Registry_, 'TagRegistry')
    obj.AllTags_ = TagRegistry.find(@(t) true);
else
    obj.AllTags_ = obj.Registry_.find(@(t) true);
end
```
and in `setProject`, reject registries that are neither empty, `TagRegistry`, nor
`Machine` with `error('FastSenseCompanion:invalidRegistry', ...)`.

### WR-06: Constructor fleet branch skips DashboardEngine validation that every other intake path enforces

**File:** `libs/FastSenseCompanion/FastSenseCompanion.m:278-289`
**Issue:** Step 4 (lines 246-255) validates each element of user-supplied
`Dashboards` is a `DashboardEngine` and throws `FastSenseCompanion:invalidDashboard`;
`setProject` (857-862) enforces the same on every machine switch. The fleet
auto-select branch assigns `firstMachine.Dashboards` to `Engines_`/`Dashboards`
verbatim with only an `iscell` wrap. `Machine.Dashboards` is a public, unvalidated
property (`libs/Fleet/Machine.m:68`), so `m.Dashboards = {42}` constructs a companion
that fails later deep inside pane render or the live tick with an un-namespaced
error, while switching TO that same machine fails fast and cleanly via `setProject`.
Inconsistent failure modes for the same bad input.
**Fix:** Run the Step-4 validation loop over `firstDash` before assignment (reuse the
exact error ID/message so the constructor contract is uniform).

## Info

### IN-01: Search does not match Group, but rows display Group

**File:** `libs/FastSenseCompanion/private/filterMachines.m:32-33`, `MachineSelectorPane.m:205-208`
**Issue:** Rows render as `'Name (Group)'`, but `filterMachines` matches Name + Id
only. Typing the visible group text (e.g. `pumps`) returns "No machines match" even
though every row displays it. `Fleet.filterByGroup` exists and is unused here.
**Fix:** Add `|| ~isempty(strfind(lower(m.Group), needle))` to the predicate (Group
is always char, default `''` — Octave-safe).

### IN-02: Empty fleet shows "No machines match" with no search term

**File:** `libs/FastSenseCompanion/MachineSelectorPane.m:214-219`
**Issue:** With a fleet of zero machines and an empty search box, the badge reads
"No machines match", implying a filter excluded them. Misleading.
**Fix:** Branch on `isempty(obj.SearchTerm_)` to show `'0 machines'` when unfiltered.

### IN-03: `MachineSelectorPane.Listeners_` is dead state

**File:** `libs/FastSenseCompanion/MachineSelectorPane.m:37`, `:146-152`
**Issue:** `Listeners_` is declared and iterated in `detach`, but no code path ever
appends to it — the pane only fires events, never listens. Dead state copied from the
TagCatalogPane template.
**Fix:** Remove the property and the detach loop, or keep with a comment if symmetry
with future listeners is intended.

### IN-04: `selectById` throws raw errors for filtered-out or unknown ids

**File:** `libs/FastSenseCompanion/MachineSelectorPane.m:155-164`
**Issue:** Unlike every other public/callback surface in the pane, `selectById` has
no try/catch. If `id` is not in the current `ItemsData` (e.g., a search filter is
active), `obj.hListbox_.Value = id` throws a raw MATLAB error; the event is also
fired for ids that don't exist in the fleet, surfacing later as a
`Fleet:unknownMachineId` uialert from the orchestrator.
**Fix:** Guard with `any(strcmp(obj.hListbox_.ItemsData, id))` before assigning
`Value`, and validate the id against the fleet before notifying.

### IN-05: Conflicting `'Fleet'` + `'Dashboards'`/`'Registry'` arguments are silently overridden

**File:** `libs/FastSenseCompanion/FastSenseCompanion.m:278-289`
**Issue:** When both `'Fleet'` and explicit `'Dashboards'`/`'Registry'` are supplied,
the first machine's context silently replaces the explicit arguments (or, for an
empty fleet, the explicit arguments silently win). No error, warning, or doc note.
**Fix:** Either `error('FastSenseCompanion:conflictingOptions', ...)` on the
combination, or document precedence in the class header.

### IN-06: Pane catch blocks call `uialert` on a possibly-invalid figure

**File:** `libs/FastSenseCompanion/MachineSelectorPane.m:221`, `:243`, `:254`
**Issue:** `applyFilter_` (reachable from the debounce `TimerFcn`),
`onSearchChanged_`, and `onClearSearch_` call `uialert(obj.hFig_, ...)` in their
catch blocks without the `~isempty && isvalid` guard that `onMachineSelected_`
(lines 270-274) uses. A timer callback already dispatched when teardown begins would
rethrow from inside the catch. Window is small (detach stops the timer) but the
inconsistency within the same file invites the race.
**Fix:** Apply the same guarded-uialert pattern used in `onMachineSelected_`.

### IN-07: Machine-owned EventStores are ignored — events surface is not machine-scoped

**File:** `libs/FastSenseCompanion/FastSenseCompanion.m:317`, `:1948-1976`
**Issue:** `EventStore_` is discovered once at construction via
`companionDiscoverEventStore` (which scans the global registry) and
`onMachineSelected_` never re-resolves it, despite `Machine.EventStore` existing
(`libs/Fleet/Machine.m:72`). In fleet mode the bell/Events viewer shows one fixed
store regardless of the active machine. Not covered by MACH-01..05, so likely future
scope — but worth an explicit deferral note in the phase artifacts so it reads as a
decision, not an omission.
**Fix:** Either switch `EventStore_` to `newMachine.EventStore` in
`onMachineSelected_` (with bell-state refresh), or record the deferral.

---

## Verified Clean

- **Legacy construction (MACH-05):** every fleet conditional (`[3 4]` grid, toolbar
  `[1 11]`, gear column, panel columns, log span, style-panel list) has an else-path
  identical to the pre-phase code; `testLegacyConstruction_Unchanged` covers grid,
  panels, label, and toolbar column count.
- **Listener lifecycle:** constructor wires `MachineSelectionChanged` after
  `selectById` (no construction round-trip); `setProject` clear-all + re-wire
  (925-929) prevents both duplication and a dead rail; deleting the executing
  listener mid-callback is safe in MATLAB.
- **Timer hygiene (MACH-04):** `stopLiveMode` stops without deleting,
  `startLiveMode` reuses `LiveTimer_`; `detach` stops before deleting the debounce
  timer; `close()` detaches the pane before figure deletion.
- **Fleet.m / filterMachines:** Octave-safe (`strfind(lower(...))`), `machineIds()`
  returns a value copy in insertion order, error IDs namespaced `Fleet:*` /
  `FastSenseCompanion:*` per convention.
- **Duck-typing:** `Machine.find/get` exist (Machine.m:157,171); `Registry_.get` at
  FastSenseCompanion.m:2378 and `openWith(obj.Registry_, ...)` at :1220 are satisfied
  by the Machine API.

---

_Reviewed: 2026-06-10_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
