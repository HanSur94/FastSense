# Last Updated Indicator — Design Spec

## Summary

Add a text label to the DashboardToolbar showing the absolute timestamp of the last successful live data refresh (e.g., `"Last update: 14:32:05"`).

## Motivation

Dashboards with live data need a visible indicator so users can tell at a glance whether data is fresh or stale. Currently there is no feedback that the live timer is working beyond watching widget values change.

## Design

### UI Element

- **Type:** `uilabel` in the toolbar bar
- **Position:** Right of existing toolbar buttons, left-aligned
- **Format:** `"Last update: HH:MM:SS"` (absolute time via `datestr(t, 'HH:MM:SS')`)
- **Initial state:** `"Last update: —"` before any live tick fires
- **Styling:** Theme secondary text color, smaller font than toolbar buttons, non-interactive

### Data Flow

1. `DashboardEngine.onLiveTick()` refreshes all widgets
2. After the refresh loop, records `obj.LastUpdateTime = now`
3. Calls `obj.Toolbar.setLastUpdateTime(obj.LastUpdateTime)`
4. `DashboardToolbar.setLastUpdateTime(t)` formats and displays the timestamp

### File Changes

| File | Change |
|------|--------|
| `DashboardToolbar.m` | Add `LastUpdateLabel` property, create label in layout, add `setLastUpdateTime(t)` method |
| `DashboardEngine.m` | Add `LastUpdateTime` property, update in `onLiveTick()`, call toolbar method |

### Behavior in Edit Mode

When the user enters edit mode, `stopLive()` halts the timer. The label retains the last known timestamp — no special handling needed. On resuming live mode, the label updates again on the next tick.
