# Cross-Machine Comparison: UX Prior Art Research

**Scope:** Interaction patterns for selecting multiple assets and building a comparison view — specifically for "compare the same logical sensor across N machines" in a desktop app that maintains a single active machine context.
**Researched:** 2026-06-02
**Overall confidence:** MEDIUM-HIGH (patterns verified from official docs where reachable; some secondary characteristics from community + blog sources)

---

## Context Summary

FastSense Companion keeps ONE active machine at a time (selecting a machine replaces the full 3-pane view via `setProject`). Cross-machine comparison opens its own dedicated figure window (overlay plot, reusing `openAdHocPlot`). The open design question is purely the SELECTION FLOW: how does the user go from "I want to compare Temperature across machines M01, M03, M07" to seeing the overlay figure, without disrupting their current single-active-machine browsing session?

---

## Tool-by-Tool Survey

### 1. AVEVA PI Vision — "Switch Asset" / Asset Context Dropdown

**What it is:** Every display in PI Vision is built against an AF element template. A dropdown arrow appears on displays; clicking it opens a list of sibling elements (machines with the same template structure). Selecting one replaces all symbol bindings on the display atomically — the whole display re-renders for the new asset.

**Selection mechanism:** Single dropdown per display. One asset at a time. No multi-select of assets. To overlay N assets, engineers must create multi-pen trend symbols manually (each pen bound to a specific machine path).

**Multi-asset overlay path:** PI Vision supports adding multiple AF attribute references to a single Trend symbol — but this requires design-time configuration by a display author. End users can switch context but cannot ad-hoc build overlays without edit access to the display.

**The "asset list" panel:** When the admin enables it, users see a flyout panel listing sibling assets with text search/wildcard filter. Selecting an asset from this panel performs the global context switch.

**Signal-first vs asset-first:** PI Vision is asset-first. You navigate to a display designed for an asset type, then switch which asset fills it. The signal is implicit in the display template.

**Fit to FastSense (single-active-context model):** HIGH — the PI Vision pattern is almost identical to the current `setProject` model. The asset list panel analogy is the proposed machine selector in the left/top of Companion. However, PI Vision does NOT offer a self-service "compare N assets on one chart" without display-authoring access.

**Sources:**
- [PI Vision Switch Assets documentation](https://docs.aveva.com/bundle/pi-vision/page/1009837.html)
- [Set asset list options](https://docs.aveva.com/bundle/pi-vision/page/1009703.html)
- [AVEVA Community — PI Vision changing context](https://community.aveva.com/pi-square-community/f/forum/98834/pi-vision---changing-context)
- [Treeview switch asset option — AVEVA Community](https://community.aveva.com/pi-square-community/learning-forums/f/forum/94536/introduction-and-treeview-switch-asset-option)

---

### 2. Seeq Workbench — Asset Swap ("Swap in this asset" button)

**What it is:** In Seeq's workbench, after you build an analysis on Asset A (add signals from A to the Details pane, create calculations), a swap icon appears to the right of each asset name in the Data/Search pane. Clicking it attempts to remap ALL current signals and calculations to the new asset — if paths match 1:1, it happens automatically; if ambiguous, a modal shows best-match options.

**Selection mechanism:** Single-asset swap. The swap button replaces the entire analysis context with the new asset. This is a one-at-a-time swap, not a multi-select overlay builder.

**Multi-asset overlay via Compare View:** Seeq's Compare View is a separate mode. It requires conditions (time capsules/events) and signals already present in the Details pane. To compare signal X across assets A, B, C, the user must have added signal X from A, then swapped to B and added X from B again (or done it programmatically via `spy.swap`). The Details pane accumulates signals from multiple swaps.

**The Compare View UX:** Once multiple signals are in the Details pane and a condition groups them (R54+: toolbar Group button auto-groups signals sharing the same parent asset), Compare View overlays or small-multiples them aligned by capsule/condition time window.

**Asset selection in Organizer Topics:** A different pattern — plus icon → modal dialog with checkboxes → dropdown in the topic page to switch between selected assets. Assets must be "adjacent" in the tree. Text filter up to 1000 assets.

**Signal-first vs asset-first:** Asset-first at the swap level, but the Details pane accumulation is effectively signal-first (you pick signals from multiple assets and let the view decide layout).

**Fit to FastSense:** MEDIUM. The swap-per-asset-then-accumulate pattern works for expert users but is cumbersome for "pick 5 machines, compare temperature" in a desktop app. The Organizer Topics dropdown-per-asset-selector pattern is closer to what FastSense needs.

**Sources:**
- [Seeq Compare View — R65](https://support.seeq.com/kb/R65/cloud/compare-view)
- [spy.swap documentation](https://python-docs.seeq.com/user_guide/spy.swap.html)
- [Asset selection in Organizer Topics](https://support.seeq.com/kb/latest/cloud/asset-selection-in-organizer-topics)
- [Searching and Navigating an Asset Tree — R65](https://support.seeq.com/kb/R65/cloud/searching-and-navigating-an-asset-tree)
- [Asset Groups — R58](https://support.seeq.com/kb/R58/cloud/asset-groups)

---

### 3. Grafana — Multi-Value Template Variable (Checkbox Dropdown)

**What it is:** Dashboard variables can be configured as "multi-value". The variable appears as a dropdown in the dashboard top bar. When expanded, it shows a checkbox list of all values (machine names, hosts, etc.). Users check any subset; the dashboard panel(s) re-render with N series (one per selected value), auto-colored by Grafana's standard palette.

**Selection mechanism:** Checkbox dropdown in the dashboard header. "Include All" option selects all values in one click. Selected values shown as comma-joined text in the closed dropdown button. No explicit "confirm" step — panels update reactively on each checkbox toggle.

**Adding/removing after the fact:** Just toggle checkboxes in the dropdown. Immediate update.

**Signal-first vs asset-first:** Signal is fixed by the panel's query template (e.g., `cpu_usage{host="$machine"}`). The user picks which machines fill `$machine`. This is SIGNAL-FIRST selection — the signal is already implied by which panel/dashboard you're on; you pick the machine subset.

**Known pain point (HIGH confidence from community):** Color assignment is not stable across selections. If you deselect machine 2 and reselect later, it may get a different color. This makes "Machine 3 = orange" unstable in presentations. Workaround: pin color overrides in panel settings. This is a documented community complaint (GitHub issue #23677: "Multi Value - default select all values").

**Fit to FastSense:** HIGH for the signal-first model. FastSense's comparison is already signal-first: user picks a logical sensor (the signal), then selects machines (the assets). Grafana's multi-value dropdown directly maps to "pick which machines to include in the overlay". 

**Sources:**
- [Grafana variables documentation](https://grafana.com/docs/grafana/latest/variables/variable-selection-options/)
- [Grafana variables blog 2024](https://grafana.com/blog/2024/10/30/grafana-variables-what-they-are-and-how-they-create-dynamic-dashboards/)
- [Multi-value variable GitHub issue](https://github.com/grafana/grafana/issues/23677)

---

### 4. Grafana Explore — Split View + Query Duplication

**What it is:** Explore mode has a "Split" button that duplicates the current query into a side-by-side pane. Each pane is independent — different data sources, different query, synchronized time. Users can click "+ Add query" within a single pane to stack multiple series on one chart.

**Selection mechanism:** Progressive query building. User writes/selects first query (first machine), clicks "Add query" to add a second. Each query row has its own filter selectors. No explicit machine list — queries are built individually.

**Fit to FastSense:** LOW. This is for free-form query builders, not a machine catalog with pre-defined tag keys. Requires technical users. Not suitable for a MATLAB companion app's UX level.

**Sources:**
- [Grafana Explore documentation](https://grafana.com/docs/grafana/latest/explore/)
- [Query management in Explore](https://grafana.com/docs/grafana/latest/explore/query-management/)

---

### 5. TrendMiner — Layer-Based Comparison (Time-Period Layers)

**What it is:** TrendMiner's comparison model is TIME-period focused, not asset-focused. A "layer" is a time range overlay for the SAME asset's signals. Layers appear in a left-panel list; the "+" button opens a date picker popup, user specifies start/end, clicks "Add layer." The result overlays the same signals at different time periods on one chart.

**Selection mechanism:** Sequential layer addition via date-picker popup. No basket/tray; layers added one at a time. Layer list in the left panel allows renaming, color assignment, toggling visibility, removing.

**Multi-asset comparison:** TrendMiner's primary comparison is time-period, not cross-asset. Cross-asset comparison is supported through the asset tree browser (search tags and attributes from different assets), but the primary UX is layer-based time comparison on a single asset.

**Signal-first vs asset-first:** Signal-first for time layers. Asset-agnostic — the layer just re-plots the same signals at a different time window.

**Fit to FastSense:** LOW for the layer pattern (time-based, not machine-based). However, the side-panel layer list with sequential add + individual management is a good reference for how to manage N active comparison series without a complex modal.

**Sources:**
- [TrendMiner Layer Creation guide](https://userguide.trendminer.com/2025.R1.0/en/layer-creation.html)
- [TrendMiner Asset Tree guide](https://userguide.trendminer.com/2024.R2.0/en/the-asset-tree.html)

---

### 6. Datadog — "Compare To" / Profile Comparison

**What it is:** Datadog's profiler has a two-profile comparison flow. From any profile view, a "⇄ Compare" button establishes the current profile as Profile B. The user then selects Profile A via filters (time range + tags). A split-pane diff view appears.

**Selection mechanism:** Single dedicated button sets the "anchor" (current context), then a secondary picker selects the comparison target. This is the "overlay-on-current" pattern — one item is already implied (the active context), the user only picks the second.

**Multi-asset:** This is strictly 2-way comparison in the profiler. Datadog's main dashboard multi-series selection uses tag-based grouping in query editors (GROUP BY host, etc.) which is automatic from data, not explicit user selection.

**Fit to FastSense:** MEDIUM for the "compare-with-current" flow (current machine is active; user picks additional machines to compare against it). Clean for 2-machine comparison; awkward for N-machine.

**Sources:**
- [Datadog Compare Profiles documentation](https://docs.datadoghq.com/profiler/compare_profiles/)

---

### 7. Tableau — Set Actions (Comparison Sets)

**What it is:** Users interact with scatter plot or other visualization elements. Clicking on dimension members (e.g., machine IDs in a scatter) adds them to a named "set." The set can be designated as "Focus" (primary context) or "Comparison" (secondary). These sets persist across dashboard views and drive filters/color on other charts.

**Selection mechanism:** Direct visual interaction (clicking marks in a chart) builds the set. No explicit list to check boxes in — the selection is the visualization interaction itself. A separate bar chart shows Focus vs Comparison membership.

**Persistence:** Sets persist across Tableau dashboards. Saving a workbook saves the set.

**Fit to FastSense:** LOW for desktop MATLAB context. Tableau's pattern requires a visualization canvas to click in. FastSense Companion is a 3-pane list-based UI, not a canvas. However, the concept of a named/saved comparison set is relevant (e.g., save a `{logicalSensor, [machines]}` preset).

**Sources:**
- [Tableau Set Actions — 8 ways to bring powerful comparisons](https://www.tableau.com/blog/8-ways-bring-powerful-new-comparisons-viz-audiences-set-actions-97207)
- [Persistent Comparison Sets across Tableau Dashboards](https://playfairdata.com/how-to-create-persistent-comparison-sets-across-tableau-dashboards/)

---

### 8. Google Analytics 4 — Comparison Sidebar (Comparison Labels)

**What it is:** "Add comparison" button in top-left of any standard report opens a right-side panel. User picks a dimension and value(s) to define a segment; clicks Apply. Active comparisons appear as labeled badges at the top of the report; all charts update to show N lines. Max 4 simultaneous comparisons. X button on each badge removes it.

**Selection mechanism:** Button opens sidebar → dimension selector → value picker → Apply. One comparison at a time added sequentially, but all remain visible as badges.

**Managing after the fact:** Badge row is a visible "comparison tray." X on any badge removes it; Edit icon reopens the sidebar for that comparison.

**Signal-first vs asset-first:** Dimension-first (signal-equivalent): you pick WHAT to compare (device type, country) and then the VALUES of that dimension (mobile vs desktop). This maps well to: pick WHICH SENSOR (dimension), then pick WHICH MACHINES (values).

**Fit to FastSense:** HIGH. The badge-row comparison tray is directly applicable. For FastSense: "selected for comparison" machines appear as dismissible badges/chips below the machine list. The logical sensor is already chosen (the context of initiating comparison).

**Sources:**
- [Google Analytics 4 Comparisons — Analytics Mania](https://www.analyticsmania.com/post/google-analytics-4-comparisons-how-to-use-them/)

---

### 9. Ignition SCADA — Pen List / Tag Browser (Drag-to-Trend)

**What it is:** Industrial SCADA trend tools (Ignition Vision, Wonderware InTouch, OSIsoft ProcessBook) traditionally use a "pen list" model: a separate tag browser tree; users drag-and-drop tags from the browser onto the trend chart; each dropped tag becomes a "pen" (line) on the chart. A pen configuration panel lists all active pens and lets users set color, axis, visibility.

**Selection mechanism:** Drag-and-drop from tag tree to chart. No explicit "add to comparison" step — the act of dragging IS the selection. Pens persist until explicitly removed. ProcessBook (end-of-life 2024) and InTouch follow this model.

**Multi-asset:** Cross-asset overlay requires the user to navigate to Machine A in the tag tree, drag its temperature tag, then navigate to Machine B, drag its temperature tag. The operator must know which tags to find. There is no canonical/logical name abstraction — the user is responsible for knowing `M01_temp_ch1` vs `M02_temp_sensor_1`.

**Fit to FastSense:** LOW as a direct pattern (no drag-and-drop canvas in MATLAB uifigure context, and FastSense already abstracts this via the canonical map). However, the pen-list concept (a visible list of what's currently in the chart, with remove buttons) maps to the comparison result management UI.

**Sources:**
- [AVEVA ArchestrA Trend Client User Guide (PDF)](https://cdn.logic-control.com/docs/aveva/hmi-scada/application-server/aaTrendClient.pdf)
- [dataPARC vs PI Historian comparison](https://www.dataparc.com/blog/best-pi-processbook-alternatives/)

---

## Synthesis: Core Interaction Patterns Catalog

### Pattern A — Checkbox Dropdown (Grafana Multi-Value Variable)

**Description:** A dropdown in the header/toolbar shows all available machines. Opening it reveals a checkbox list. User checks any subset. A close button or click-outside confirms. Charts update reactively. Optional "Select All" checkbox.

**Tools:** Grafana (template variables), Power BI (multi-select slicer), many BI tools.

**Pros:**
- Compact — one control for both search and selection
- Reactive — user sees chart update as they check/uncheck (immediate feedback)
- "All" checkbox solves "compare everything" instantly
- Familiar pattern across analytics tools
- Well-suited to signal-first flow: signal already set by which plot you're building; machines are the variable

**Cons:**
- Color instability on re-selection (documented Grafana issue) — must be designed around by assigning colors by machine index, not selection order
- With 20+ machines, the checkbox list becomes long; needs search-within-dropdown
- No explicit "confirm" step means accidental deselections trigger re-renders (can be costly if pulls database)
- Doesn't show the active machine prominently vs the comparison machines

**Fit to single-active-context FastSense:**
GOOD. Signal is already fixed (logical sensor chosen before opening compare). Machine selector shows a checkable list of fleet machines. Active machine (current `setProject` machine) pre-checked but unchecking it just removes it from the comparison (doesn't change the Companion's active context).

**MATLAB implementation note:** `uilistbox` with `Multiselect = 'on'` + a search text field above it gives this pattern without custom controls.

---

### Pattern B — Comparison Badge/Tray (GA4 Style)

**Description:** A persistent "comparison tray" row shows currently-selected comparison items as dismissible badges/chips. An "Add +" button or inline search opens a picker to add more. Each badge has an X to remove. Tray is always visible when a comparison is active.

**Tools:** Google Analytics 4 (Comparisons feature), some BI tools (applied filters row).

**Pros:**
- Always-visible inventory of what's in the comparison (no hidden state)
- One-click removal per item (X on badge) — no need to re-open dropdown
- Tray acts as confirmation: "I can see I have M01, M03, M07 selected"
- Naturally separates "active machine" from "comparison set" — active machine is elsewhere; tray is the overlay set
- Scales well to 3–7 items; degrades gracefully beyond that (wrap or overflow indicator)
- Modeless — user can keep browsing without dismissing a dialog

**Cons:**
- Requires UI real estate for the tray row (vertical space in the Companion pane)
- Adding items requires either a separate picker modal or inline search — adds a step vs checkbox dropdown
- Badge labels must be short enough to fit (machine IDs are fine; long names need truncation)

**Fit to single-active-context FastSense:**
EXCELLENT. The tray row lives below or adjacent to the machine list. It is the comparison queue, separate from the active machine context. User selects a logical sensor first (from the tag catalog), right-clicks or uses an action button → "Add to comparison" → machine is added to the tray as a badge. When tray has 2+ items, an "Open comparison overlay" button becomes active.

**MATLAB implementation note:** Row of `uibutton` chips inside a scrollable `uipanel` + delete callback on each. Fits within existing companion layout.

---

### Pattern C — "Add to Comparison" Context Menu (Right-Click / Action Button on List Item)

**Description:** Right-clicking a machine in the machine list shows a context menu including "Add to comparison" (and possibly "Compare with active machine"). The item is added to a hidden or visible set. When 2+ items are in the set, a "View comparison" or "Open overlay" action becomes available.

**Tools:** Used in many desktop analytics apps; analogy in OSIsoft ProcessBook (right-click tag → add to trend); common in file managers and DAM tools.

**Pros:**
- Low UI footprint — no extra panel needed when comparison set is empty
- Discoverable via right-click, which desktop engineers expect
- Does not require pre-selecting a sensor (can trigger sensor selection as part of the flow)
- Natural "overlay-on-current" sub-variant: "Compare [selected machine] with [active machine]" — 2-machine fast path

**Cons:**
- Right-click is invisible — users may not discover it without documentation
- Requires a secondary step to view/manage the set if a tray isn't shown
- Managing a set of 5+ items via context menu is tedious
- Does not visually communicate "you have 3 machines queued for comparison"

**Fit to single-active-context FastSense:**
GOOD as a secondary/supplementary pattern. Combine with Pattern B: right-click → "Add to comparison tray" adds a badge to the tray. The tray is the primary UI; the context menu is the entry point. This avoids a modal.

---

### Pattern D — Dedicated "Compare" Modal/Dialog (Signal-First Flow)

**Description:** A button or menu item opens a modal dialog: Step 1 = pick a logical sensor (from canonical map). Step 2 = pick machines (multi-select checkbox list, search). Step 3 = open overlay. Modal closes after confirmation.

**Tools:** PI Vision multi-pen trend configuration (design-time modal), Seeq Asset Groups setup (plus-icon → modal), TrendMiner layer creation (date picker popup → add).

**Pros:**
- Explicit, guided flow — user knows exactly what they're doing
- Can handle both steps (signal selection AND machine selection) in one place
- Easy to validate: "you must pick at least 2 machines"
- Clean state — when dialog is dismissed, comparison is either open or not

**Cons:**
- MODAL = blocks the companion while the dialog is open (user cannot browse machines to remember names)
- Forces completion or cancellation — no "I'll decide later"
- Friction: two steps before anything is visible
- Loses "serendipitous discovery" — user must already know what logical sensor they want

**Fit to single-active-context FastSense:**
MEDIUM. Best suited when the user has a clear intent upfront ("I want to compare X across Y machines"). Worst case: user opens the dialog, doesn't remember machine names, must cancel, browse the list, then re-open. Consider a MODELESS variant (see Pattern E).

---

### Pattern E — Inline "Compare" Action on Logical Sensor (Signal-First, Modeless)

**Description:** In the tag catalog pane (the left pane of Companion), each logical sensor in the canonical map has an inline "Compare across machines" button (or right-click menu item). Clicking it immediately opens the overlay figure with the active machine's signal plotted and a "machine selector" panel attached to the figure (not a modal). User adds/removes machines from that panel after the fact.

**Tools:** FastSense existing analogy: `openAdHocPlot` triggered from tag catalog. Conceptual analogy: Grafana panel → "Explore" button opens a focused exploration view with the metric pre-filled.

**Pros:**
- Modeless — figure opens immediately, user can see one machine's data while selecting others
- Signal-first: sensor is already determined by what the user clicked
- User can open multiple comparison figures for different sensors simultaneously
- Natural extension of the existing "open ad-hoc plot" from tag selection

**Cons:**
- Machine selector must be embedded in or near the overlay figure (a panel or side drawer)
- If the figure is a plain MATLAB figure (not uifigure), embedding interactive controls is limited
- User may not realize they need to add machines — the figure opens with only 1 series, which looks like a regular ad-hoc plot

**Fit to single-active-context FastSense:**
EXCELLENT for the FastSense architecture. `openAdHocPlot` already opens a new figure from the tag catalog. The comparison variant adds: (a) an initial machine pre-selection modal or (b) a companion panel listing machines with checkboxes alongside the figure. The active machine's signal is shown immediately; comparison machines added incrementally.

---

### Pattern F — Pin-to-Compare / Star for Comparison (Deferred Accumulation)

**Description:** User "pins" or "stars" machines in the machine list to mark them for comparison (no immediate action). When ready, clicks "Compare pinned machines" for a chosen sensor. Pins persist across sessions (or at least within the session).

**Tools:** Many file managers and developer tools use star/pin for deferred multi-selection. Some APM tools use "watchlist" or "pinned hosts."

**Pros:**
- Completely non-disruptive to browsing — user can browse machines one by one, pinning interesting ones
- Persists across browsing sessions
- Zero disruption to single-active-context model

**Cons:**
- Two-step: pin THEN trigger comparison — requires remembering to trigger
- No visual feedback that a comparison "is ready" unless explicitly designed
- Pins can become stale — user forgets what they pinned and why
- Requires sensor selection step separately

**Fit to single-active-context FastSense:**
MEDIUM. Good as a "build a fleet subset for repeated use" persistent feature (maps to PROJECT.md's "pin/star machines" v5.x differentiator). Less ideal as the PRIMARY comparison initiation flow since it separates asset selection from signal selection too much.

---

## Key Design Questions Answered by Prior Art

### Signal-First vs Asset-First: Which Ordering?

**Evidence from prior art:** Tools converge on TWO valid orderings depending on user mental model:

- **Seeq, AVEVA PI Vision:** Asset-first — user navigates to an asset, then picks which signals from that asset to analyze. Comparison is an afterthought (swap the asset).
- **Grafana, Google Analytics:** Signal-first — the signal is fixed by the panel/report; the user picks which assets (machines/hosts) fill the variable.
- **TrendMiner:** Signal-first — user adds signals they care about, then adds time-window layers.

For FastSense: the canonical map is SIGNAL-first by design (logical sensor name → per-machine local key). The user picks a logical sensor from the canonical map, then selects machines. **Signal-first is the natural fit.**

### Keeping Single Primary Context While Pulling In Others

**Evidence from prior art:**
- PI Vision: atomically REPLACES the context. No "keep current + add others" model.
- Seeq Organizer: one dropdown per content block, each switches independently. Primary context is the current page.
- Grafana: all selected values are equal-weight — no "primary" machine. The chart shows all selected machines as peers.
- GA4: all comparisons are equal — no "primary." But one segment can be "All Users" which acts as the baseline.
- Datadog profiler: explicit "baseline vs comparison" — one item is the anchor.

For FastSense: the "active machine" in the Companion is the PRIMARY context (browsing, dashboard viewing). The comparison set is SEPARATE and does not replace the active machine. The overlay figure shows all comparison machines as peers (like Grafana), but the Companion pane always shows only the active machine. This is a clean separation.

**Design implication:** The machine selector for comparison should NOT change `setProject`. The active machine can optionally be pre-included in the comparison set, but the user can remove it without changing the Companion's active context.

### Handling Missing Signals

**Evidence:**
- Seeq: `spy.swap` reports failure per asset in a Result column. Yellow popup shows "2 of 3 signals swapped."
- PI Vision: missing attribute → blank/broken cell in element-relative displays (silent skip).
- FEATURES.md prior art: skip and warn (not crash).

**For FastSense:** When a machine lacks the logical sensor, skip it from the overlay and show a warning text label in the figure legend: "M05: sensor not found." Do not block the comparison from opening.

### Managing Result at Scale: Overlay vs Small-Multiples vs Stacked

**Evidence from prior art:**
- Grafana multi-value: overlay (all series on one Y-axis by default). With 10+ series, becomes unreadable.
- Seeq Compare View: small-multiples option (stacked panels per asset) as well as overlay.
- TrendMiner: overlay for time layers; can stack panes manually.
- FEATURES.md prior art: overlay is the primary mode (reusing `openAdHocPlot` Overlay).

**For FastSense:** Overlay is appropriate for up to ~7 machines. Beyond that, color distinguishability becomes the bottleneck (research consensus: 7–9 distinguishable colors max; see dashboard design sources). A defensive cap of 8–10 machines with a warning beyond that is prudent.

---

## Known UX Pitfalls

### Pitfall 1 — Color Instability (CRITICAL)
**What:** If colors are assigned by selection ORDER rather than by machine IDENTITY, removing and re-adding a machine gives it a new color. Analysts rely on "Machine 3 = orange" across multiple sessions.
**Evidence:** Documented Grafana community complaint (GitHub issue #23677). Common in all tools that assign colors sequentially.
**Prevention:** Assign color by machine INDEX in the fleet (e.g., `M01` always gets color slot 1, `M02` color slot 2). Color assignment is deterministic from machine metadata, not from selection order. This requires the `Fleet` to carry a stable per-machine color index.

### Pitfall 2 — Modal Blocking Active Context Browsing (HIGH)
**What:** Opening a modal comparison dialog forces the user to have all machine names and sensor names ready in memory. If they need to browse the machine list to check names, they must cancel and re-open.
**Evidence:** Modal pattern (PI Vision pen configuration, Seeq asset group setup) draws repeated complaints in engineering tool UX research.
**Prevention:** Use Pattern B (badge tray) or Pattern E (modeless signal-first with post-open machine selector). Allow machine selection to happen from the same pane that shows the machine list.

### Pitfall 3 — Losing the Comparison Set (HIGH)
**What:** Closing the overlay figure discards the comparison set. User must rebuild from scratch next time.
**Evidence:** Tableau explicitly designed persistent sets to solve this (Set Actions). Grafana variables are saved with the dashboard config — but ad-hoc Explore queries are ephemeral.
**Prevention:** Either (a) save the last comparison set in companion prefs (simple, low-cost), or (b) implement named comparison presets (FEATURES.md v5.x differentiator). At minimum, the comparison set should persist while the Companion window is open.

### Pitfall 4 — Scale Cliff at 8+ Machines (MEDIUM)
**What:** Overlay charts with 8+ distinct colored series become unreadable — colors repeat, lines cross, legend becomes a wall of text.
**Evidence:** Dashboard design research consensus: 7–9 items is the color discrimination ceiling. Metabase "Top 5 Dashboard Fails" identifies this explicitly.
**Prevention:** (a) Soft cap at 8 with a warning dialog. (b) Beyond 8, offer small-multiples mode (stacked subplots) as an alternative. (c) For very large fleets, offer fleet envelope (min/max band + median) — but this is a v5.x differentiator.

### Pitfall 5 — Signal-Asset Impedance Mismatch (MEDIUM)
**What:** If the user selects machines BEFORE selecting a sensor, the comparison dialog must accommodate "I don't know which sensor I want yet." This leads to an awkward two-step modal where neither step is satisfying.
**Evidence:** Seeq's asset-first swap requires the user to already have signals in their worksheet. PI Vision requires display-time configuration.
**Prevention:** Always start signal-first: the comparison flow is initiated FROM the tag catalog (click a logical sensor → trigger compare). Machine selection is the second step. The signal is never ambiguous.

### Pitfall 6 — Invisible Multi-Select State (MEDIUM)
**What:** When machines are selected for comparison via checkboxes or context menus without a visible tray, users lose track of what is selected. "Did I select M03 or not?"
**Evidence:** This is a standard multi-select UX anti-pattern documented across BI tools. GA4's badge tray was explicitly designed to address this.
**Prevention:** Always show a visible summary of the comparison set (badge tray, list, or persistent chip row). Never rely on checkbox state that is hidden when the dropdown is closed.

---

## Ranked Shortlist (Best Fit to FastSense)

Ranking by: (1) fit to single-active-context model, (2) signal-first flow, (3) low disruption to browsing, (4) MATLAB uifigure implementability.

### Rank 1 — Pattern E + B: Inline Sensor Action → Badge Tray (RECOMMENDED)

**How it works for FastSense:**
1. User is browsing their active machine's tag catalog (existing behavior).
2. They see a logical sensor in the tag catalog that has cross-machine mapping (e.g., "Temperature" in the canonical map).
3. An inline "Compare" button (or right-click context menu → "Compare across machines") on that logical sensor triggers the flow.
4. A modeless machine selection panel opens — either a floating `uifigure` dialog or a dedicated section of the inspector pane — showing a searchable checkbox list of fleet machines.
5. As machines are checked, they appear as dismissible chip/badge items in the selection panel. No "confirm" required — the user checks, the chip appears.
6. An "Open overlay" button (active when 2+ machines checked) opens the `openAdHocPlot` Overlay figure.
7. The badge row remains visible in the panel. Unchecking a machine removes its badge and (if the figure is open) updates it live.

**Why Rank 1:**
- Signal is fixed before machine selection (zero ambiguity)
- Modeless — user can see machine names while selecting
- Badge tray gives visible confirmation of what's queued
- Active machine context (`setProject`) is untouched
- Maps directly to existing `openAdHocPlot` Overlay path
- MATLAB implementation: `uilistbox` with Multiselect, above a chip row of `uibutton`s, in the inspector pane or a floating `uipanel`.

### Rank 2 — Pattern B + A: Badge Tray with Checkbox Dropdown from Machine List

**How it works for FastSense:**
1. The Companion's machine selector pane (new for v5.0) has a "Compare" toggle/mode.
2. When active, selecting machines from the list adds them as badges to a visible tray at the bottom of the pane.
3. The active machine is shown in a separate header (not in the tray). User can optionally add it to the tray too.
4. After selecting a sensor (from the tag catalog) and checking the desired machines in the tray, "Open overlay" is available.

**Why Rank 2:**
- Machine-list-integrated: no separate dialog
- Visible tray state
- Minor con: requires entering "compare mode" which is an extra click vs Pattern E's direct "Compare" button on the sensor

### Rank 3 — Pattern C + B: Context Menu → Badge Tray (Two-Pane Approach)

**How it works:** Right-click on any machine in the machine list → "Add to comparison set." The added machine appears as a badge in a persistent comparison tray in the bottom section of the machine-list pane. When the user is ready, they pick a logical sensor from the tag catalog (or via a dropdown in the tray) and click "Open comparison overlay."

**Why Rank 3:**
- Zero extra UI until the user right-clicks — minimal footprint when not comparing
- Good for asset-first users who know which machines they want before picking a sensor
- Con: sensor selection step is after machine selection — slightly less natural for canonical map use

### Rank 4 — Pattern D: Signal-First Modal (Two-Step Guided Dialog)

**How it works:** "Compare sensor across machines" button (in toolbar or inspector) opens a modal: Step 1 = pick logical sensor from canonical map dropdown. Step 2 = pick machines via checkbox list with search. Confirm opens overlay.

**Why Rank 4:** 
- Explicit and discoverable
- Con: modal blocks browsing; forces user to have all info ready upfront
- Con: closes the dialog before showing any result — no iterative refinement

### Rank 5 — Pattern F: Pin-to-Compare (Persistent Deferred Set)

**Why Rank 5:** Good for saving reusable machine subsets, but not the primary comparison initiation path. Better as a complement to Rank 1–2 (save a pinned subset for fast reuse). Implement as v5.x after primary comparison is proven.

### (Not recommended as primary) Pattern A: Standalone Checkbox Dropdown

**Why not primary:** Grafana's checkbox dropdown is designed for DASHBOARD-LEVEL context where the signal is implicit in the dashboard structure. FastSense Companion needs to explicitly connect signal selection to machine selection. A freestanding dropdown for machines without signal selection does not complete the flow. Use as the machine-picker component WITHIN Pattern E/B, not as a standalone pattern.

---

## Recommended Architecture for FastSense v5.0

Based on the ranked shortlist, the recommended UI architecture for comparison initiation:

1. **Entry point:** Inline "Compare" button on logical sensor items in the tag catalog pane (right side of each list row when canonical map has multi-machine entries). Also reachable via right-click → context menu → "Compare across machines."

2. **Machine selection:** A modeless floating panel (small `uifigure` or a dropdown-like popover) showing:
   - Search text box
   - `uilistbox` with `Multiselect = 'on'` listing all fleet machines
   - Active machine pre-selected
   - Chip/badge row below the list showing selected machines (each dismissible)
   - "Open Overlay" button (enabled when 2+ machines selected)
   - "Cancel" link

3. **Result management:** The overlay figure opens immediately. The machine selection panel stays open as a "comparison manager" — user can add/remove machines and the overlay figure updates. Closing the figure auto-closes the panel.

4. **Color assignment:** Colors assigned by machine index in `Fleet.getMachines()` order, not by selection order. Machine IDs/names as legend labels.

5. **Missing signal handling:** Machines lacking the logical sensor are shown with a strikethrough or "(no data)" annotation in the selection list, and skipped with a warning note in the figure title or legend.

---

## Sources Index

- [PI Vision Switch Assets](https://docs.aveva.com/bundle/pi-vision/page/1009837.html) — MEDIUM confidence (docs page redirected)
- [PI Vision Set Asset List Options](https://docs.aveva.com/bundle/pi-vision/page/1009703.html) — MEDIUM confidence (docs page redirected)
- [AVEVA Community — PI Vision changing context](https://community.aveva.com/pi-square-community/f/forum/98834/pi-vision---changing-context) — HIGH confidence
- [AVEVA Community — Treeview switch asset](https://community.aveva.com/pi-square-community/learning-forums/f/forum/94536/introduction-and-treeview-switch-asset-option) — HIGH confidence
- [Seeq Compare View — R65](https://support.seeq.com/kb/R65/cloud/compare-view) — HIGH confidence (official docs)
- [Seeq Asset Selection in Organizer Topics](https://support.seeq.com/kb/latest/cloud/asset-selection-in-organizer-topics) — HIGH confidence (official docs, fetched)
- [Seeq Asset Tree Search — R65](https://support.seeq.com/kb/R65/cloud/searching-and-navigating-an-asset-tree) — HIGH confidence (official docs, fetched)
- [spy.swap documentation](https://python-docs.seeq.com/user_guide/spy.swap.html) — HIGH confidence (official docs)
- [Seeq Asset Groups — R58](https://support.seeq.com/kb/R58/cloud/asset-groups) — HIGH confidence
- [Grafana variables documentation](https://grafana.com/docs/grafana/latest/variables/variable-selection-options/) — HIGH confidence
- [Grafana multi-value variable GitHub issue #23677](https://github.com/grafana/grafana/issues/23677) — HIGH confidence (color instability pitfall)
- [Grafana variables blog 2024](https://grafana.com/blog/2024/10/30/grafana-variables-what-they-are-and-how-they-create-dynamic-dashboards/) — HIGH confidence
- [TrendMiner Layer Creation guide](https://userguide.trendminer.com/2025.R1.0/en/layer-creation.html) — HIGH confidence (official docs, fetched)
- [Datadog Compare Profiles](https://docs.datadoghq.com/profiler/compare_profiles/) — HIGH confidence (official docs, fetched)
- [Tableau Set Actions blog](https://www.tableau.com/blog/8-ways-bring-powerful-new-comparisons-viz-audiences-set-actions-97207) — HIGH confidence
- [Tableau Persistent Comparison Sets — Playfair Data](https://playfairdata.com/how-to-create-persistent-comparison-sets-across-tableau-dashboards/) — MEDIUM confidence (fetched)
- [Google Analytics 4 Comparisons — Analytics Mania](https://www.analyticsmania.com/post/google-analytics-4-comparisons-how-to-use-them/) — HIGH confidence (fetched)
- [Grafana Explore documentation](https://grafana.com/docs/grafana/latest/explore/) — HIGH confidence
- [dataPARC ProcessBook Alternatives](https://www.dataparc.com/blog/best-pi-processbook-alternatives/) — MEDIUM confidence
- [Dashboard color pitfalls — Metabase blog](https://www.metabase.com/blog/top-5-dashboard-fails) — MEDIUM confidence
- [Dashboard UX patterns — Pencil & Paper](https://www.pencilandpaper.io/articles/ux-pattern-analysis-data-dashboards) — MEDIUM confidence

---

*Researched for: FastSense v5.0 Cross-Machine Comparison feature — UX selection interaction design*
*Date: 2026-06-02*
