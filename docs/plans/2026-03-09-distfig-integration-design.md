# DistFig Integration Design

## Summary

Add a static method `FastPlot.distFig()` that wraps the MATLAB File Exchange
`distFig` function (ID 37176, by Anders Simonsen) for distributing figure
windows across the screen.

## API

```matlab
FastPlot.distFig()                             % auto-arrange all figures
FastPlot.distFig('Rows', 2, 'Cols', 3)         % 2×3 grid
FastPlot.distFig('Screen', 'East', 'Rows', 2)  % right monitor, 2 rows
```

All arguments are passed through to `distFig` unchanged.

## Implementation

- One static method on `FastPlot` (~5 lines)
- Pure passthrough: `distFig(varargin{:})`
- Error check: throw clear error if `distFig` is not on the MATLAB path
- No new properties, no constructor changes, no render pipeline changes

## Dependency

- User must install `distFig` from MATLAB File Exchange separately
- Link: https://www.mathworks.com/matlabcentral/fileexchange/37176-distribute-figures
