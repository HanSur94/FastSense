# Hierarchical Progress Bar Design

## Goal
Replace the current single-bar console progress with a hierarchical log-style display that shows progress at every level: dock tabs, dashboard tiles, and individual lines.

## Architecture
A single `ConsoleProgressBar` class uses `\r` to animate the current deepest level. When a level completes, it "freezes" (prints `\n`) and becomes a permanent log line. Indentation indicates depth. Each class (FastPlotDock, FastPlotFigure, FastPlot) manages its own level of the hierarchy.

## Display Format

### Dock with dashboards (full hierarchy):
```
Tab 1/3: Temperature
  Tile 1/4:  [██████████████████████████████] 8/8
  Tile 2/4:  [██████████████████████████████] 6/6
  Tile 3/4:  [████████████░░░░░░░░░░░░░░░░░░] 3/5   <- animates
```

### Dashboard only (no dock):
```
Tile 1/4:  [██████████████████████████████] 8/8
Tile 2/4:  [██████████████████████████████] 6/6
Tile 3/4:  [████████████░░░░░░░░░░░░░░░░░░] 3/5   <- animates
```

### Standalone FastPlot:
```
Rendering    [████████████░░░░░░░░░░░░░░░░░░] 3/5   <- animates
```

## Behavior
- Only the deepest active level animates with `\r`
- When a level completes, `freeze()` prints `\n` making it permanent
- Next level starts animating on a new line
- `ShowProgress` property on all three classes (default `true`)
- New `renderAll()` on FastPlotDock for eager rendering of all tabs

## ConsoleProgressBar API
- `ConsoleProgressBar(indent)` — constructor, indent = number of spaces
- `start()` — initialize
- `update(current, total, label)` — update and redraw with `\r`
- `freeze()` — print `\n`, making current state a permanent line
- `finish()` — freeze if not already, mark done

## Integration Points
- **FastPlotDock.renderAll()** — prints "Tab N/M: Name" per tab, delegates to FastPlotFigure.renderAll(cpb)
- **FastPlotFigure.renderAll()** — creates indented bar per tile, freezes after each
- **FastPlot.render()** — updates the active bar per line
