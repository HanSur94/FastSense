# FastSense Companion — Overview

The FastSense Companion is a three-pane `uifigure` control panel that browses the project's `TagRegistry`, opens dashboards and ad-hoc plots in their own MATLAB figures, and provides live status monitoring across the entire project. It is purely a navigator — every dashboard it opens runs in a standalone classical figure with its own live timer, theme, and toolbar.

Two parallel help systems live inside FastSense: **System 1** is the per-dashboard `Info` button driven by `DashboardEngine.InfoFile`, and **System 2** is this Wiki Browser. See [Dashboard Info vs Wiki](Dashboard-Info-vs-Wiki) for the full distinction.

## Three-pane layout

| Pane   | What it shows                                                           |
| ------ | ----------------------------------------------------------------------- |
| Left   | Searchable tag catalog with multi-select and filter pills               |
| Middle | Dashboard list (open / live-toggle)                                     |
| Right  | Adaptive inspector (welcome / single tag / multi-tag / dashboard state) |

The right pane is *adaptive*: when one tag is selected it shows metadata, thresholds, and a "Plot this tag" action; when multiple tags are selected it switches to a plot composer (Linked grid vs Overlay, time range, live cadence); when a dashboard tile is clicked instead it shows that dashboard's summary plus open / live-toggle buttons. Most-recent click wins.

## Top toolbar (left to right)

- **Events** — opens the [Event Viewer](Event-Viewer)
- **Live: ON/OFF** — toggles the companion-driven inspector refresh and the live log
- **Tags** — opens the [Tag Status Table](Tag-Status-Table)
- **Tile / Close all** — manages the windows the Companion has opened (dashboards, ad-hoc plots, detached panes)
- **Wiki** — opens this Wiki Browser (you are reading it now)
- **Gear** — opens Companion settings (theme, live period)

## Log strip (bottom)

The bottom of the window hosts two compact log panes:

- **Events log** — rolling list of recent threshold violations from `EventStore`
- **Live log** — per-tag `Δ samples` and latest value as new data lands

Each pane has a pop-out icon in its header that detaches the pane into its own figure window. See [Event Viewer](Event-Viewer) for the events pane and [Live Log](Live-Log) for the live updates pane.

## Opening a dashboard

Select a dashboard in the middle pane and click **Open**. The Companion pops it into a separate MATLAB figure via `DashboardEngine.render()`. The dashboard owns its own live timer, theme, and `Info` button — the Companion is purely a control panel and does not manage dashboard refresh cadence on the dashboard's behalf.

Ad-hoc plots (single tag → Detail; multi-tag → Linked grid or Overlay) open as classical figures and are tracked by the Companion's **Tile** and **Close all** toolbar buttons.

## Live mode

The **Live: ON/OFF** toggle controls a Companion-owned `timer` that drives the inspector refresh and the live log. It does **not** start or stop any `DashboardEngine`'s own live timer — those are per-dashboard. When Live is OFF the inspector and live log are idle; the Tag Status Table still polls under its own timer so activity flags stay correct.

## See also

- [Tag Status Table](Tag-Status-Table)
- [Event Viewer](Event-Viewer)
- [Live Log](Live-Log)
- [Dashboard Info vs Wiki](Dashboard-Info-vs-Wiki)
- [Home](Home)
