# Phase 1044: Companion Machine Dimension - Context

**Gathered:** 2026-06-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a **machine dimension** to the `FastSenseCompanion` three-pane uifigure: a machine selector that makes the chosen machine the active context (its tags fill the tag-catalog pane, its dashboards fill the dashboard-list pane), with an always-visible active-machine indicator and clean live-timer handling on switch. Legacy single-machine construction (`'Registry'`/`'Dashboards'`, no `Fleet`) keeps working unchanged as a single implicit machine.

In scope: the machine-selector UI control + placement, re-pointing the four static `TagRegistry.find` call sites (TagCatalogPane.m:60,205; FastSenseCompanion.m:1616,1618) to the active machine, `setProject(machine.Dashboards, machine)` wiring, machine-switch timer lifecycle (no accumulation), active-machine indicator, and backward-compat for the legacy constructor.

Out of scope (later phases): cross-machine comparison/overlay (Phase 1045), per-machine dashboard clone/remap (Phase 1046), fleet-wide health/status badges (future milestone — do NOT block the selector on this).

</domain>

<decisions>
## Implementation Decisions

User accepted all recommended answers across the three grey areas (smart-discuss, autonomous mode). Recommendations were grounded in the v5.0 research (SUMMARY Q5 / FEATURES Area 1 — "uilistbox + uieditfield 150ms debounce, copy TagCatalogPane verbatim") and the MACH-05 backward-compat requirement.

### Machine Selector — Placement & Form (MACH-01, MACH-02, MACH-03)
- **Placement:** Dedicated **left-rail column** — a new leftmost pane so the Companion reads as a clean hierarchy **Machines ▸ Tags ▸ Dashboards ▸ Inspector**. This resolves the placement decision PROJECT.md explicitly deferred to this phase (left rail vs. top dropdown vs. tabs → **left rail**). The data model is placement-agnostic; this is purely the Companion layout.
- **Control form:** `uilistbox` + a search `uieditfield` with a ~150ms debounce timer — **copy the live `TagCatalogPane` idiom verbatim** (uilistbox with `Items`/`ItemsData`, Octave-safe `strfind` filtering). Scales to fleet size (20+ machines, lazy-populated list). Not a dropdown (weak free-text search at fleet scale), not tabs (does not scale).
- **Active-machine indicator (MACH-03 / SC2 "always shows which machine is active"):** a **persistent active-machine label in the toolbar** (e.g. `▸ Press Line 3 [M03]`) **plus** the list-selection highlight. The toolbar label stays visible even when the machine list is scrolled.
- **Legacy (no-Fleet) appearance:** **Hide the selector entirely** — the legacy 3-pane window looks **identical** to today (the single implicit machine needs no selector). Satisfies MACH-05 "continues to work unchanged". The left-rail column is only added when a `Fleet` is supplied (conditional construction).

### Machine List Behavior (MACH-01)
- **Search:** free-text **substring over Name + Id**, ~150ms debounce, `strfind(lower(...))` — Octave-safe, mirrors `private/filterTags.m` / `filterDashboards.m`. Never `contains`.
- **List order:** **Fleet insertion order** (matches `Fleet` iteration and the stable user-supplied `Id` identity). Not alphabetical, not auto-grouped (v1).
- **Per-row label:** **Name primary + `Group` as dim/secondary** text; `Id` available in tooltip. (`Name` defaults to `Id` when omitted, per Phase 1042 D-10.)
- **Zero-match / empty state:** **placeholder text "No machines match"** (mirrors the existing pane placeholder convention).

### Machine Switch Semantics (MACH-02, MACH-04)
- **Live mode across a switch:** **preserve the live on/off state.** If Live was ON when the user switches machines: **stop the previously-active dashboard's live timer → switch context → restart for the new machine.** This is the core of SC3/MACH-04 — `timerfindall` count must be stable across repeated switches (no accumulation). Stop-before-start, `stop(t); delete(t)` order where a timer is torn down.
- **Tag selection + inspector on switch:** **reset to the welcome state.** `setProject` already clears `SelectedTagKeys_` / `SelectedDashboardIdx_` / `LastInteraction_`; relying on that avoids stale cross-machine tag keys.
- **Dashboard figures opened from the prior machine:** **leave them open.** Detached/opened MATLAB figures belong to the user; do not auto-close on switch.
- **Initial active machine:** **auto-select the first machine** in the fleet on construction (active context is never empty when a Fleet is present).

### Construction API & Backward-Compat (MACH-05) — Claude's Discretion, grounded in research + Phase 1042/1043
- **Fleet passed via a new `'Fleet', fleetObj` name-value pair** on the `FastSenseCompanion` constructor. Legacy `'Registry'`/`'Dashboards'` args (no `Fleet`) continue to work unchanged.
- **Implicit-machine unification:** legacy construction wraps the supplied `Registry`/`Dashboards` in an internal **single implicit `Machine`** so the active-context code path is uniform (one machine vs. many). The legacy implicit machine must NOT register its tags into the global `TagRegistry` beyond what already happens today — and crucially must not change legacy behavior (the implicit machine simply *is* the existing registry/dashboards).
- **Four call-site redirect:** re-point the four static `TagRegistry.find(...)` sites to the **active machine's** read API — `obj.Registry_.find(...)` where `Registry_` is the active `Machine` (or the implicit machine in legacy mode). `Machine.find/get/keys` are duck-type equivalents of the `TagRegistry` static methods (Phase 1042), so this is a drop-in redirect.
- **`setProject(machine.Dashboards, machine)`** is the switch mechanism — it accepts the `Machine` handle as the "registry" (duck-typed). It already detaches/re-attaches panes and re-wires listeners (no listener accumulation), which is exactly the machine-switch need.
- The planner may refine exact property/method names (`ActiveMachine_` vs. reusing `Registry_`), error-id spelling (`FastSenseCompanion:*`), the debounce constant, and left-rail width as long as the four success criteria and the milestone critical invariants hold.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`TagCatalogPane` uilistbox + debounced search** (`libs/FastSenseCompanion/TagCatalogPane.m`) — the exact selector idiom to copy verbatim for the machine list (Items/ItemsData, search field, debounce timer).
- **`private/filterTags.m` / `filterDashboards.m`** — `strfind(lower(...))` Octave-safe substring filtering pattern for the machine search.
- **`setProject(obj, dashboards, registry)`** (`FastSenseCompanion.m:725-799`) — rebuilds all three panes in place, resets selection state, and clears/re-wires listeners (no accumulation). The machine-switch path reuses this with `setProject(machine.Dashboards, machine)`.
- **`startLiveMode` / `stopLiveMode`** (`FastSenseCompanion.m:867-915`) — Companion-owned `LiveTimer_` (`fixedRate`, `BusyMode='drop'`); `onLiveTick_` scans the active registry/machine. Stop-before-start + `stop;delete` teardown idiom already present at `:588-599`.
- **`Machine` duck-type API** (`libs/Fleet/Machine.m`) — `get(localKey)`, `find(pred)`, `findByKind`, `findByLabel`, `keys()`, `.Dashboards`, `.Name`, `.Id`, `.Group`, `.EventStore`. Drop-in for `TagRegistry` static calls.
- **`Fleet` API** (`libs/Fleet/Fleet.m`) — `getMachine(id)`, `machineCount()`, `filterByName(pattern)`, `filterByGroup(group)`; iterate via `machineCount()` + `getMachine`. (A public ordered-id accessor may be a small planner add — `MachineIds_` is currently private.)
- **`CompanionTheme` + `private/applyThemeToChildren_.m`** theme walker already covers `DropDown`, `ListBox`, `EditField`, `Label`, `Panel`, `GridLayout` — a standard `uilistbox`/`uieditfield`/`uilabel` machine selector is themed automatically with no walker changes.

### Established Patterns
- Root layout is `uigridlayout(hFig_, [3 3])` with `RowHeight {32,'1x',360}`, `ColumnWidth {220,'1x',360}` (`FastSenseCompanion.m:301-307`). Toolbar = row 1 cols [1 3]; three panes = row 2 cols 1/2/3; log strip = row 3 cols [1 3]. Adding a left-rail column = prepend a column → `{170,220,'1x',360}` **only when a Fleet is supplied** (legacy stays `{220,'1x',360}`).
- Toolbar buttons live in a single 1×N inner grid inside `hToolbarPanel_` (`:309-449`) — the active-machine label slots in here.
- Every class that calls `addlistener` keeps a `Listeners_` cell + `delete(obj.Listeners_)` on close; every timer is `stop(t); delete(t)` in that order; the Companion is the only `uifigure` (spawned dashboards/plots are classical `figure`).

### Integration Points
- **Four `TagRegistry.find` redirect sites:** `TagCatalogPane.m:60` (attach snapshot), `TagCatalogPane.m:205` (refresh snapshot), `FastSenseCompanion.m:1616` + `:1618` (onLiveTick_ status scan + fallback). Redirect to `obj.Registry_.find(...)` (active machine).
- **Machine switch entry point:** new machine-selector `ValueChangedFcn` → stop live (if on) → `setProject(machine.Dashboards, machine)` → restart live (if was on).
- **Construction:** `FastSenseCompanion(...)` gains `'Fleet'` NV pair; legacy `'Registry'`/`'Dashboards'` wrapped in an implicit `Machine`.

</code_context>

<specifics>
## Specific Ideas

- Selector control is a **copy of the `TagCatalogPane` uilistbox + debounced search**, not a bespoke widget — minimize new surface area and inherit theming for free.
- Active-machine indicator is a **toolbar label** so it survives list scrolling (SC2 "always shows which machine is active").
- The left-rail column is **conditional on a Fleet being supplied** — legacy mode is byte-identically the current 3-pane window.
- Hierarchy reads left→right: **Machines ▸ Tags ▸ Dashboards ▸ Inspector**.

</specifics>

<deferred>
## Deferred Ideas

- **Per-machine health/status badge** (green/amber/red on each machine row) — requires fleet-wide background monitoring; explicitly NOT a blocker for the selector (research SUMMARY). Future milestone.
- **Grouped machine list** (collapsible headers by `Machine.Group`) — v1 ships a flat insertion-order list; grouping is a later nicety.
- **Cross-machine comparison / overlay** — Phase 1045.
- **Per-machine dashboard clone/remap** — Phase 1046.

</deferred>
