# Event Viewer

The Companion's Event Viewer renders detected threshold-violation events from `EventStore` in two views — Gantt timeline and tabular list — filtered by tag selection, severity, and time range. Opened from the Companion toolbar's **Events** button as a single-instance pop-out `uifigure`.

It is the same surface the bottom-of-companion **Events log** strip can detach into. The pop-out icon on the events log header opens the detached view in its own figure window.

## Left pane — tag catalog + view switch

A `TagCatalogPane` lets you multi-select tags via search, kind / criticality filter pills, and a listbox. Selecting tags filters both the Gantt and the Table.

A `uiswitch` at the top of the left pane flips between **Gantt** and **Table** views without losing the selection or filter state.

## Right pane — view-dependent content

| View  | Content                                                                                              |
| ----- | ---------------------------------------------------------------------------------------------------- |
| Gantt | timeline axes with one row per selected tag; severity-colored bars per event with a crosshair        |
| Table | sortable list with start / end / duration / severity / tag, and a **Plot Selected (N)** drill-down   |

A filter bar across the top of the right pane carries presets, From / To datetimes, severity tri-toggle, **Open only**, **Refresh**, **Auto** (live), and an interval picker. A `TimeRangeSelector` slider below the content lets you drag a window across the full event history.

## Severity

- Sev 1 (info) — typically green
- Sev 2 (warning) — typically orange
- Sev 3 (critical) — typically red

The severity tri-toggle in the filter bar is multi-toggle: any combination of the three may be active. Default is all three on.

## Click behaviour

| Surface           | Single-click                                | Double-click                                                              |
| ----------------- | ------------------------------------------- | ------------------------------------------------------------------------- |
| Gantt bar         | debounced **Event Info** popup with Notes   | new `DashboardEngine` with one `FastSenseWidget`, X zoomed to event window |
| Table row         | row selection (enables Plot Selected)       | same drill-down dashboard as the Gantt double-click                       |
| Table multi-row   | enables **Plot Selected (N)**               | (N/A)                                                                     |

**Plot Selected (N)** opens a single dashboard with N stacked `FastSenseWidget`s, one per selected event — useful for comparing related violations side by side.

## Live log vs Events log

The Companion's bottom strip hosts two compact log panes:

- **Events log** — rolling list of recent detected events (this surface's compact form)
- **Live log** — per-tag sample-delta counts as new data arrives (a different surface)

See [Live Log](Live-Log) for the live updates pane.

## See also

- [Live Log](Live-Log)
- [Tag Status Table](Tag-Status-Table)
- [Companion Overview](Companion-Overview)
