%% FastSense Toolbar Demo
% Demonstrates the interactive toolbar: data cursor, crosshair,
% grid toggle, legend toggle, autoscale Y, and PNG export.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

n = 1e6;
x = linspace(0, 100, n);
y1 = sin(x * 2*pi/10) + 0.3*randn(1,n);
y2 = cos(x * 2*pi/15) + 0.3*randn(1,n);

fprintf('Toolbar example: %d points, 2 lines...\n', n);
tic;

fp = FastSense('Theme', 'light');
fp.addLine(x, y1, 'DisplayName', 'Sine');
fp.addLine(x, y2, 'DisplayName', 'Cosine');
fp.addThreshold(1.2, 'Direction', 'upper', 'ShowViolations', true);
fp.render();

tb = FastSenseToolbar(fp);

fprintf('Rendered with toolbar in %.3f seconds.\n', toc);
fprintf('Try: Data Cursor (click), Crosshair (hover), Grid, Legend, Autoscale Y, Export PNG\n');

%% Dashboard with toolbar
fig = FastSenseGrid(1, 2, 'Theme', 'dark');
fp1 = fig.tile(1);
fp1.addLine(x, y1, 'DisplayName', 'Pressure');
fp1.addThreshold(1.0, 'Direction', 'upper', 'ShowViolations', true);
fp2 = fig.tile(2);
fp2.addLine(x, y2, 'DisplayName', 'Temperature');
fig.renderAll();
fig.setTileTitle(1, 'Pressure');
fig.setTileTitle(2, 'Temperature');

tb2 = FastSenseToolbar(fig);
fprintf('Dashboard with toolbar ready.\n');

%% Datetime X-Axis
x = datenum(2024,1,1) + (0:99999)/86400;  % ~1 day at 1-second resolution
y = sin((1:100000) * 2*pi/3600) + 0.2*randn(1,100000);

fp3 = FastSense('Theme', 'light');
fp3.addLine(x, y, 'DisplayName', 'Tag', 'XType', 'datenum');
fp3.render();
title(fp3.hAxes, 'Datetime Axis — zoom to see format change');

tb3 = FastSenseToolbar(fp3);
fprintf('Datetime axis with toolbar ready. Zoom to see tick format adapt.\n');

%% Metadata — attach context to lines and query it
% Metadata uses forward-fill (last-observation-carried-forward) lookup.
n4 = 500000;
x4 = linspace(0, 100, n4);
y4 = sin(x4 * 2*pi/20) + 0.2*randn(1, n4);

fp4 = FastSense('Theme', 'light');
meta = struct('datenum', [0 25 50 75], ...
    'operator', {{'Alice', 'Bob', 'Alice', 'Charlie'}}, ...
    'shift',    {{'Day', 'Day', 'Night', 'Night'}});
fp4.addLine(x4, y4, 'DisplayName', 'Tag', 'Metadata', meta);
fp4.render();
title(fp4.hAxes, 'Metadata — lookupMetadata / setLineMetadata');
tb4 = FastSenseToolbar(fp4);

% Query metadata at different X positions
info1 = fp4.lookupMetadata(1, 30);
fprintf('lookupMetadata(1, 30): operator=%s, shift=%s\n', info1.operator, info1.shift);
info2 = fp4.lookupMetadata(1, 80);
fprintf('lookupMetadata(1, 80): operator=%s, shift=%s\n', info2.operator, info2.shift);

% setLineMetadata — replace metadata after construction
newMeta = struct('datenum', [0 50], ...
    'operator', {{'Dave', 'Eve'}}, ...
    'shift',    {{'Day', 'Night'}});
fp4.setLineMetadata(1, newMeta);
info3 = fp4.lookupMetadata(1, 30);
fprintf('After setLineMetadata: operator=%s, shift=%s\n', info3.operator, info3.shift);

%% openLoupe — pop out an enlarged copy of the current plot
fp4.openLoupe();
fprintf('openLoupe() called — enlarged copy opened in a new figure.\n');
