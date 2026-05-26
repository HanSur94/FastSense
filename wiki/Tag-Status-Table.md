# Tag Status Table

A live table of every tag in the project's `TagRegistry`, with status, last-updated wall-clock time, activity flag, event count, and label filter chips. Opened from the main Companion toolbar's **Tags** button as a detached classical-figure window.

The table refreshes regardless of whether the Companion is in Live mode — see [Refresh paths](#refresh-paths) below.

## Columns

| Column       | Source                                                       |
| ------------ | ------------------------------------------------------------ |
| Key          | `tag.Key`                                                    |
| Name         | `tag.Name`                                                   |
| Type         | one of Sensor / Monitor / Composite / State / Derived        |
| Criticality  | `tag.Criticality` (Low / Medium / High / Safety)             |
| Units        | `tag.Units`                                                  |
| Latest       | last Y value, formatted by magnitude or state label          |
| Status       | smart per-type (Monitor → OK/ALARM, State → state label, others → —) |
| Last updated | wall-clock time of `X(end)` formatted via `formatLastUpdated_` |
| Activity     | **Live** if `X(end)` is within 5 min of now, else **Inactive** |
| Events       | integer count from `EventStore.getEventsForTag(key)`         |
| Samples      | `numel(X)`                                                   |
| Labels       | `tag.Labels` joined by comma                                 |

## Filters

The header strip carries three chip groups and a free-text search field:

- **Type chips** — Sensor / Monitor / Composite / State / Derived
- **Criticality chips** — Low / Medium / High / Safety
- **Activity chips** — Live / Inactive
- **Search box** — case-insensitive substring across Key, Name, Units, Labels

Chip behaviour: multi-toggle, **AND** across chip groups, **OR** within a group. With every chip on (the default) every tag is visible; toggling a chip off subtracts that category.

## Refresh paths

Two parallel refresh paths keep the table in sync:

1. **Push-on-write** — the Companion's `scanLiveTagUpdates_` calls `markTagsDirty(keys)` whenever pipeline sample counts grow. Zero cost when the window is closed.
2. **Window-owned timer** — a 1 s `fixedSpacing` timer ticks every second so **Activity** and **Last updated** stay correct even when the Companion is **not** in Live mode (e.g. you only want to monitor activity without running the full live pipeline).

The window-owned timer is unique to this surface and was added in quick task 260519-bs4 as a deviation from the original "push-on-write only" design.

## Pause polling

The **Pause polling** button in the top-right freezes both refresh paths without closing the window. While paused:

- `markTagsDirty` becomes a no-op (push-on-write writes are dropped)
- The window-owned timer keeps ticking but skips the re-query body
- The "Last refreshed" header reads `HH:MM:SS (paused)`

Click again to **Resume polling**. Useful when you want a stable snapshot of the table to read or screenshot.

## See also

- [Companion Overview](Companion-Overview)
- [Live Log](Live-Log)
- [Event Viewer](Event-Viewer)
