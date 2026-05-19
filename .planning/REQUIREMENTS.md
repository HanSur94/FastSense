# Requirements: FastSense — v3.1 Plant Log Integration

**Defined:** 2026-05-13
**Core Value:** Engineers can render millions of sensor points smoothly, organize
them into navigable dashboards, and surface anomalies — all in pure MATLAB with no
toolbox dependencies.

## v3.1 Requirements

Requirements for the v3.1 milestone. Each maps to roadmap phases in
`.planning/ROADMAP.md`.

### Import

- [x] **PLOG-IM-01**: User can open a `.csv` plant log file and have its rows imported as plant-log entries.
- [x] **PLOG-IM-02**: User can open an `.xlsx` plant log file and have its rows imported as plant-log entries (MATLAB primary; Octave XLSX support is best-effort, tests gated on runtime availability).
- [x] **PLOG-IM-03**: System auto-detects the timestamp column by parsing each column's values as dates/times and selecting the first column whose values parse cleanly.
- [x] **PLOG-IM-04**: System auto-detects the message column as the first non-timestamp text column.
- [x] **PLOG-IM-05**: Columns that aren't timestamp or message are preserved as metadata associated with each entry.
- [x] **PLOG-IM-06**: User sees a mapping dialog (uifigure modal) after auto-detection showing the detected timestamp column, message column, metadata columns, and a 10-row preview of the parsed result.
- [x] **PLOG-IM-07**: User can override the timestamp column, message column, or explicit timestamp format string in the mapping dialog before confirming the import.
- [x] **PLOG-IM-08**: User sees a non-blocking error via `uialert` if no parseable timestamp column is found; the dialog blocks confirmation until the user picks a valid column.

### Storage

- [x] **PLOG-ST-01**: Imported plant-log entries live in a `PlantLogStore` instance separate from the existing `EventStore`; no plant-log entry ever appears in `EventStore.getEvents()`.
- [x] **PLOG-ST-02**: User can query the entries in a `PlantLogStore` by time range, receiving every entry whose timestamp falls within `[t0, t1]`.
- [x] **PLOG-ST-03**: User can query the total count of entries currently in a `PlantLogStore`.
- [x] **PLOG-ST-04**: Re-importing the same source file produces no duplicate entries — dedup is keyed on timestamp + row-content hash.
- [x] **PLOG-ST-05**: User can read the original message text and every metadata column value for any entry returned from the store.

### Live Tail

- [x] **PLOG-LT-01**: User can enable live tail on an imported plant log; the system re-reads the source file on a periodic timer and appends newly-discovered rows to the store.
- [x] **PLOG-LT-02**: Live tail never produces duplicate entries — rows matched by timestamp + row hash are skipped on each re-read.
- [x] **PLOG-LT-03**: User can configure the live-tail re-read interval (default 5 seconds).
- [x] **PLOG-LT-04**: User can stop live tail at any time; the timer is cleaned up reliably with no orphan timer remaining in `timerfindall`.
- [x] **PLOG-LT-05**: A parse error during a live-tail re-read surfaces to the user via non-blocking `uialert` (or `warning` in non-uifigure contexts) and does not crash the dashboard or stop the timer.

### Visualization

- [x] **PLOG-VIZ-01**: When a `PlantLogStore` is attached to a dashboard, the bottom slider preview track shows a black vertical line for every plant-log entry within the slider's visible time range.
- [x] **PLOG-VIZ-02**: Slider preview plant-log lines are visually distinct from existing sev1/2/3 colored event markers (black, 1px stroke, full opacity).
- [x] **PLOG-VIZ-03**: Every `FastSenseWidget` has a `ShowPlantLog` toggle that defaults to off (`false`).
- [x] **PLOG-VIZ-04**: When a widget's `ShowPlantLog` is on and a `PlantLogStore` is attached, the widget axes show a black vertical line at each entry timestamp within the widget's current x-axis range.
- [x] **PLOG-VIZ-05**: User can toggle `ShowPlantLog` per widget via an icon button in the widget button bar.
- [x] **PLOG-VIZ-06**: Hovering a plant-log line on the slider preview pops a small tooltip with the entry's timestamp and message.
- [x] **PLOG-VIZ-07**: Hovering a plant-log line on a FastSenseWidget pops a small tooltip with the entry's timestamp, message, and every metadata column value.
- [x] **PLOG-VIZ-08**: When live tail appends new entries, the slider preview and all widgets with `ShowPlantLog=true` reflect the new lines without requiring a full re-render of the dashboard.
- [x] **PLOG-VIZ-09**: Plant-log line color is sourced from a theme token (`MarkerPlantLog`, default black on both light and dark themes) so themes can override if needed.

### Integration

- [x] **PLOG-INT-01**: User can attach a plant log to a `DashboardEngine` via `engine.attachPlantLog(filePath, opts)` and the slider preview overlay activates immediately.
- [x] **PLOG-INT-02**: User can detach a plant log via `engine.detachPlantLog()`; all slider and widget overlays disappear and any active live tail stops cleanly.
- [x] **PLOG-INT-03**: User can open a plant log from `FastSenseCompanion`'s toolbar via an "Open Plant Log…" entry, which imports the file and attaches the resulting store to every open `DashboardEngine` instance the companion is managing.
- [x] **PLOG-INT-04**: Saving a dashboard via `DashboardSerializer` (JSON and `.m` export) persists the plant-log source path, the column mapping, the live-tail interval, and each widget's `ShowPlantLog` flag.
- [x] **PLOG-INT-05**: Loading a serialized dashboard re-imports the plant log from the saved source path using the saved column mapping and restores each widget's `ShowPlantLog` state; entries themselves are not persisted in the JSON/`.m` export.

## v3.2+ Requirements

Deferred to future milestones. Tracked but not in current roadmap.

### Streaming

- **PLOG-STR-01**: User can attach a plant log via a TCP/socket stream rather than a file path.
- **PLOG-STR-02**: User can attach a plant log via OPC-UA or MQTT.

### Editing

- **PLOG-EDIT-01**: User can edit imported entries' messages directly in a plant-log viewer pane.
- **PLOG-EDIT-02**: User can add manual annotations that persist alongside imported entries.

### Tag binding

- **PLOG-TAG-01**: A plant-log column can be mapped to a Tag key, so entries scope only to widgets graphing that tag.

## Out of Scope

Explicitly excluded for v3.1. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Editing imported plant-log entries | Plant logs are a read-only reflection of the source file; users edit the file, live tail picks up changes |
| Severity inference from message text | Plant logs render as black regardless of severity columns; visual distinction from auto-detected events is the value |
| Merging plant logs into the existing `EventStore` | Kept in a separate `PlantLogStore` for clean separation from threshold-detected events |
| Alerting / notification on imported plant-log entries | `NotificationService` remains scoped to `MonitorTag` violations |
| Real-time streaming protocols (OPC-UA, MQTT, syslog tail-via-socket) | Only file re-read is supported in v3.1; sockets/streams deferred to PLOG-STR |
| Tag-bound plant-log overlay filtering | Entries are global (slider) / per-widget opt-in (widgets); per-tag filtering deferred to PLOG-TAG |
| Plant-log entries replacing the `EventTimelineWidget` | That widget continues to show `EventStore` events; plant logs use their own visualization channel |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLOG-IM-01 | 1030 | Complete |
| PLOG-IM-02 | 1030 | Complete |
| PLOG-IM-03 | 1030 | Complete |
| PLOG-IM-04 | 1030 | Complete |
| PLOG-IM-05 | 1030 | Complete |
| PLOG-IM-06 | 1030 | Complete |
| PLOG-IM-07 | 1030 | Complete |
| PLOG-IM-08 | 1030 | Complete |
| PLOG-ST-01 | 1029 | Complete |
| PLOG-ST-02 | 1029 | Complete |
| PLOG-ST-03 | 1029 | Complete |
| PLOG-ST-04 | 1029 | Complete |
| PLOG-ST-05 | 1029 | Complete |
| PLOG-LT-01 | 1031 | Complete |
| PLOG-LT-02 | 1031 | Complete |
| PLOG-LT-03 | 1031 | Complete |
| PLOG-LT-04 | 1031 | Complete |
| PLOG-LT-05 | 1031 | Complete |
| PLOG-VIZ-01 | 1031 | Complete |
| PLOG-VIZ-02 | 1031 | Complete |
| PLOG-VIZ-03 | 1032 | Complete |
| PLOG-VIZ-04 | 1032 | Complete |
| PLOG-VIZ-05 | 1032 | Complete |
| PLOG-VIZ-06 | 1031 | Complete |
| PLOG-VIZ-07 | 1032 | Complete |
| PLOG-VIZ-08 | 1031 | Complete |
| PLOG-VIZ-09 | 1031 | Complete |
| PLOG-INT-01 | 1033 | Complete |
| PLOG-INT-02 | 1033 | Complete |
| PLOG-INT-03 | 1033 | Complete |
| PLOG-INT-04 | 1033 | Complete |
| PLOG-INT-05 | 1033 | Complete |

**Coverage:**
- v3.1 active requirements (table rows): 32 total
  - Import: 8 (PLOG-IM-01..08)
  - Storage: 5 (PLOG-ST-01..05)
  - Live Tail: 5 (PLOG-LT-01..05)
  - Visualization: 9 (PLOG-VIZ-01..09)
  - Integration: 5 (PLOG-INT-01..05)
- Mapped to phases: 32 ✓
- Unmapped: 0 ✓

> **Note:** Earlier drafts of this file stated "28 active v3.1 requirements"; the
> traceability table (above) is the authoritative count and resolves to 32 entries
> across the five categories. All 32 are mapped to phases 1029–1033 in
> `.planning/ROADMAP.md`.

---
*Requirements defined: 2026-05-13*
*Last updated: 2026-05-13 — roadmap created, all 32 active requirements mapped to phases 1029–1033*
