# Dashboard Info vs Wiki

FastSense has **two parallel help systems**. They don't overlap, they don't share buttons, and they're meant for different audiences. If you're a dashboard author wiring help into your own work, this page tells you which one to reach for.

## System 1 — `DashboardEngine.InfoFile` (per-dashboard contextual help)

Set at dashboard construction:

```matlab
d = DashboardEngine('InfoFile', 'notes.md', 'Theme', 'dark');
```

A small **Info** button appears on the dashboard toolbar. Clicking it opens a modal `uifigure` that renders `notes.md` via `MarkdownRenderer`. The modal is **scoped to that dashboard** — it knows nothing about other pages, other surfaces, or cross-doc links.

Use System 1 when you want to ship operational notes alongside a specific dashboard:

- "Press F5 to reset"
- "The red band is the safety limit"
- "This dashboard's data updates every 30 seconds"
- "Contact the line lead before changing thresholds"

`DashboardWidget.Description` is the per-widget tooltip-only complement to System 1 — set it for a single info-icon hover string per widget when a full markdown page is overkill.

## System 2 — Wiki Browser (project-wide manual)

A new **Wiki** button appears on every Companion window's toolbar. It opens a **non-modal** browser pane that renders any markdown in the project's `wiki/` directory with sidebar TOC, back / forward navigation, and full-text search.

Use System 2 when you want the user to read about something **across** the whole project:

- "What is FastSenseCompanion and how do its three panes work?"
- "What does the Tag Status Table window do?"
- "How do I read the Event Viewer's Gantt chart?"
- "What's the difference between the Events log and the Live log?"

The Wiki Browser is a single shared window per Companion session — clicking any Wiki button focuses the existing window if open and navigates to the requested page, otherwise creates the window.

## Coexistence

The two systems never collide on the same button. They can both exist on the same workflow because they live on different windows:

| Surface                  | System 1 (Info)              | System 2 (Wiki)                                                 |
| ------------------------ | ---------------------------- | --------------------------------------------------------------- |
| Dashboard figure toolbar | yes (when `InfoFile` set)    | no (out of scope for Phase 1034)                                |
| Companion main toolbar   | no                           | yes                                                             |
| Companion sub-windows    | no                           | yes (Phase 1034 wires Tag Status Table, Event Viewer, Live Log) |
| Per-widget hover         | `Description` tooltip only   | no                                                              |

## Authoring guidance

- **Hand-written wiki pages** for System 2 go directly into `wiki/`. No new templating, no auto-injection placeholders. Pick filenames that **do not** appear in `scripts/generate_wiki.py`'s `PAGE_MAP` — otherwise the wiki generator could overwrite your hand-written content on its next run.
- **Per-dashboard markdown** for System 1 lives wherever your dashboard build script keeps its assets. Pass an absolute path or a path relative to the dashboard's `FilePath`.

## See also

- [Companion Overview](Companion-Overview)
- [Home](Home)
