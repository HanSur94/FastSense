%EXAMPLE_METADATA Demonstrates metadata support in FastPlot.
%
%   Shows how to attach metadata to a line and view it
%   in the data cursor tooltip.

run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'libs', 'FastPlot', 'private'));

% Generate sample time series
x = linspace(0, 100, 10000);
y = sin(x / 5) + 0.3 * randn(size(x));

% Create metadata with forward-fill semantics
meta.datenum  = [0, 25, 50, 75];
meta.operator = {'Alice', 'Bob', 'Charlie', 'Alice'};
meta.mode     = {'auto', 'manual', 'auto', 'manual'};
meta.status   = {'normal', 'calibrating', 'normal', 'maintenance'};

% Create plot with metadata
fp = FastPlot('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Sensor', 'Metadata', meta);
fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true);
fp.render();

% Attach toolbar
tb = FastPlotToolbar(fp);

% Enable metadata display
tb.setMetadata(true);

fprintf('Click on data points with the Data Cursor to see metadata.\n');
fprintf('Metadata changes at x = 0, 25, 50, 75.\n');
