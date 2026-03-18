# API Reference: Themes

FastPlot includes a configurable theme system with 6 built-in presets, 3 color palettes, and full customization.

---

## FastPlotTheme

Function that returns a theme struct. Not a class — returns a plain struct.

### Usage

```matlab
t = FastPlotTheme();                  % Returns 'default' preset
t = FastPlotTheme('dark');            % Named preset
t = FastPlotTheme('dark', 'FontSize', 14, 'LineWidth', 2.0);  % Preset with overrides
t = FastPlotTheme(struct('Background', [0 0 0]));  % Custom struct (merged with defaults)
```

### Applying Themes

```matlab
% At construction
fp = FastPlot('Theme', 'dark');
fig = FastPlotFigure(2, 2, 'Theme', 'industrial');
dock = FastPlotDock('Theme', 'scientific');

% After construction
fp.Theme = FastPlotTheme('dark');
fp.reapplyTheme();
```

---

## Built-in Presets

### default
White background, standard MATLAB-like colors. Good for general use.
- Background: white [1 1 1]
- Axes: white
- Grid: light gray, dotted
- Font: Helvetica, 10pt
- Palette: 7-color vibrant set

### dark
Dark gray background with bright, high-contrast lines. Good for monitoring dashboards.
- Background: dark gray [0.15 0.15 0.15]
- Axes: slightly lighter [0.18 0.18 0.18]
- Foreground: light gray [0.9 0.9 0.9]
- Grid: gray, low alpha
- Palette: bright neon-inspired colors

### light
Soft white background with muted, comfortable colors. Good for long analysis sessions.
- Background: off-white [0.98 0.98 0.98]
- Axes: white
- Grid: light, subtle
- Palette: muted, softer tones

### industrial
High contrast with engineering-style presentation. Good for plant monitoring.
- Background: very dark [0.1 0.1 0.1]
- Bold grid lines
- Larger fonts
- Palette: high-visibility colors

### scientific
Publication-ready. Serif font, no grid, colorblind-safe palette.
- Background: white
- Font: Times New Roman (or serif)
- No grid (GridStyle = 'none')
- Palette: Wong (2011) colorblind-safe 7-color set
- Thinner lines

### ocean
Deep blue-green color scheme. Good for marine, environmental, or dark-themed dashboards.
- Background: deep navy [0.05 0.12 0.18]
- Axes: dark teal [0.07 0.16 0.24]
- Foreground: cool gray-blue
- Palette: cool-toned colors

---

## Theme Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| Background | 1x3 RGB | [1 1 1] | Figure background color |
| AxesColor | 1x3 RGB | [1 1 1] | Axes background color |
| ForegroundColor | 1x3 RGB | [0.15 0.15 0.15] | Text, tick labels, axis lines |
| GridColor | 1x3 RGB | [0.8 0.8 0.8] | Grid line color |
| GridAlpha | double | 0.5 | Grid transparency (0-1) |
| GridStyle | char | ':' | Grid line style: '-', '--', ':', '-.', 'none' |
| FontName | char | 'Helvetica' | Font family for labels and titles |
| FontSize | double | 10 | Base font size for axis labels |
| TitleFontSize | double | 12 | Title font size |
| LineWidth | double | 0.5 | Default data line width |
| LineColorOrder | Nx3 or char | (7-color set) | Color cycle matrix or palette name |
| ThresholdColor | 1x3 RGB | [0.8 0 0] | Default threshold line color |
| ThresholdStyle | char | '--' | Default threshold line style |
| ViolationMarker | char | 'o' | Default violation marker shape |
| ViolationSize | double | 4 | Default violation marker size (points) |
| BandAlpha | double | 0.1 | Default band fill transparency |

---

## Color Palettes

LineColorOrder can be an Nx3 RGB matrix or one of these named palettes:

### vibrant (default)
Bright, distinct colors optimized for dark and light backgrounds.

### muted
Softer, desaturated colors for a professional look. Less eye strain.

### colorblind
Wong (2011) colorblind-safe palette. 7 colors distinguishable by people with the most common forms of color vision deficiency. Used by the 'scientific' preset.

**Usage:**
```matlab
t = FastPlotTheme('dark', 'LineColorOrder', 'colorblind');
t = FastPlotTheme('default', 'LineColorOrder', 'muted');
```

**Custom palette:**
```matlab
myColors = [
    0.2 0.4 0.8;   % Blue
    0.8 0.2 0.2;   % Red
    0.2 0.7 0.3;   % Green
    0.9 0.6 0.1;   % Orange
];
t = FastPlotTheme('dark', 'LineColorOrder', myColors);
```

---

## Theme Inheritance

Themes cascade with this priority (highest first):

```
Element override  >  Tile theme  >  Figure theme  >  'default' preset
```

1. **Element override** — Color/LineWidth etc. passed directly to addLine(), addThreshold()
2. **Tile theme** — setTileTheme() overrides for specific tiles
3. **Figure theme** — Theme from FastPlotFigure or FastPlot constructor
4. **default preset** — Fills in any unspecified fields

Each level only needs to specify the fields it wants to change. Unspecified fields cascade from the next level.

### Example — Cascading themes

```matlab
% Figure uses dark theme
fig = FastPlotFigure(2, 2, 'Theme', 'dark');

% Tile 2 overrides just the background
fig.setTileTheme(2, struct('Background', [0.1 0.1 0.2]));

% Individual line overrides color
fp = fig.tile(1);
fp.addLine(x, y, 'Color', [1 0.5 0]);  % Orange, overrides theme palette
```

---

## FastPlotDefaults

Global default configuration. All FastPlot instances inherit these unless overridden.

```matlab
% View current defaults (edit the function to change)
FastPlotDefaults()
```

### Default Fields

| Field | Default | Description |
|-------|---------|-------------|
| Theme | 'default' | Default theme preset |
| ThemeDir | 'themes' | Custom theme folder |
| Verbose | false | Diagnostics |
| MinPointsForDownsample | 5000 | Raw plotting threshold |
| DownsampleFactor | 2 | Points per pixel |
| PyramidReduction | 100 | Pyramid compression factor |
| DefaultDownsampleMethod | 'minmax' | Downsampling algorithm |
| XScale | 'linear' | Default X scale |
| YScale | 'linear' | Default Y scale |
| LiveInterval | 2.0 | Polling interval (seconds) |
| DashboardPadding | [0.06 0.04 0.01 0.02] | Dashboard edge padding |
| DashboardGapH | 0.03 | Horizontal tile gap |
| DashboardGapV | 0.06 | Vertical tile gap |
| TabBarHeight | 0.03 | Dock tab bar height |

To reset cached defaults:
```matlab
FastPlot.resetDefaults();
```

---

## Custom Theme Examples

### Dark theme with large fonts
```matlab
t = FastPlotTheme('dark', 'FontSize', 14, 'TitleFontSize', 18, 'LineWidth', 2.0);
fp = FastPlot('Theme', t);
```

### Publication-ready with custom colors
```matlab
t = FastPlotTheme('scientific', ...
    'LineColorOrder', [0 0 0; 0.5 0.5 0.5; 0 0 0.8], ...
    'LineWidth', 1.0, ...
    'FontSize', 12);
fp = FastPlot('Theme', t);
```

### Minimal industrial theme
```matlab
t = FastPlotTheme('industrial', 'GridAlpha', 0.1, 'BandAlpha', 0.08);
fig = FastPlotFigure(2, 2, 'Theme', t);
```

---

## See Also

- [[API Reference: FastPlot]] — Using themes with plots
- [[API Reference: Dashboard]] — Dashboard-level theming
