# Live Log

A rolling per-tag log of new samples landing in the Companion's live pipeline. Sits at the bottom of the Companion's main window and detaches into its own figure via the pop-out icon in the header strip.

It is a **passive renderer** — the row data is pushed in by the Companion every tick. The pane owns no per-tag cursor state; that responsibility lives upstream in `FastSenseCompanion`.

## Columns

| Column    | Meaning                                                                  |
| --------- | ------------------------------------------------------------------------ |
| Time      | wall-clock receipt time, formatted `HH:MM:SS`                            |
| Tag       | `tag.Key` (matches the same key shown in the Tag Status Table)           |
| Δ samples | new sample count since the previous tick                                 |
| Latest    | most recent Y value, formatted by magnitude or state label               |

Buffer is capped at 500 rows, newest first. When the cap is reached the oldest row is dropped.

## Tracking source

The Live Log does **not** track per-tag sample cursors itself — `FastSenseCompanion.scanLiveTagUpdates_` owns the `LiveSampleCount_` map and calls `addLiveLogEntry(tagKey, delta, latestY)` whenever a positive delta is detected. This boundary is fixed by Phase 1027 CONTEXT and is the same separation the [Event Viewer](Event-Viewer)'s events log uses — pipeline state lives in the Companion, panes only render rows.

## Filter

A free-text search field above the table filters rows by Tag (case-insensitive substring). The buffer keeps every row in memory regardless of filter, so clearing the filter immediately restores the full view.

The **Clear** button next to the filter wipes the buffer entirely.

## When does it update?

Only while the Companion is in **Live mode** (top toolbar's "Live: ON"). When Live is OFF the live pipeline is idle and no new rows arrive. Existing rows stay visible.

The [Tag Status Table](Tag-Status-Table) is the exception — it polls under its own window-owned timer and stays current even when Live is OFF.

## Detached vs inline

When detached, the pane re-parents itself into a standalone `uifigure` and keeps its full buffer history. Closing the detached figure re-attaches the pane inline. The buffer is preserved across the round-trip.

## See also

- [Event Viewer](Event-Viewer)
- [Tag Status Table](Tag-Status-Table)
- [Companion Overview](Companion-Overview)
