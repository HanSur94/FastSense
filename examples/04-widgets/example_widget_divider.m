%% DividerWidget — Visual Section Separators
% Demonstrates every Thickness level and Color override of the DividerWidget
% inside a DashboardEngine dashboard.
%
% DividerWidget properties:
%   Thickness  — Relative line thickness: 1=thin (default), 2=medium, 3=thick.
%                Maps to a normalized height fraction (1=10%, 2=20%, 3=30%).
%   Color      — [r g b] RGB override for the divider color.
%                Empty (default) uses the theme WidgetBorderColor.
%   Position   — [col row width height] on the 24-column grid (1-based).
%                Default: [1 1 24 1] — full-width, single grid row.
%
% DividerWidget is a static widget with no data binding.
% It renders as a centered horizontal bar inside its grid cell.

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Create simple sensors for the number widgets
rng(42);
N = 500;
t = linspace(0, 3600, N);

sPressA = SensorTag('PA-01', 'Name', 'Pressure A', 'Units', 'bar');
sPressA.updateData(t, 8.4 + 0.3*sin(2*pi*t/600) + randn(1,N)*0.05);

sTempA = SensorTag('TA-01', 'Name', 'Temp A', 'Units', [char(176) 'C']);
sTempA.updateData(t, 42 + 3*sin(2*pi*t/900) + randn(1,N)*0.3);

sPressB = SensorTag('PB-01', 'Name', 'Pressure B', 'Units', 'bar');
sPressB.updateData(t, 5.1 + 0.2*sin(2*pi*t/1200) + randn(1,N)*0.04);

sTempB = SensorTag('TB-01', 'Name', 'Temp B', 'Units', [char(176) 'C']);
sTempB.updateData(t, 61 + 2*sin(2*pi*t/600) + randn(1,N)*0.2);

%% 2. Build Dashboard
d = DashboardEngine('DividerWidget Demo');
d.Theme = 'dark';

% --- Row 1: Section A number widgets ---
d.addWidget('number', 'Position', [1  1 12 2], 'Sensor', sPressA);
d.addWidget('number', 'Position', [13 1 12 2], 'Sensor', sTempA);

% --- Row 3: Default divider (Thickness=1, theme WidgetBorderColor) ---
d.addWidget('divider', 'Position', [1 3 24 1]);

% --- Row 4: Section B number widgets ---
d.addWidget('number', 'Position', [1  4 12 2], 'Sensor', sPressB);
d.addWidget('number', 'Position', [13 4 12 2], 'Sensor', sTempB);

% --- Row 6: Thick divider (Thickness=3) with a custom red color ---
d.addWidget('divider', ...
    'Position',  [1 6 24 1], ...
    'Thickness', 3, ...
% --- Row 7: Medium divider (Thickness=2) with a different custom color ---
d.addWidget('divider', ...
    'Position',  [1 7 24 1], ...
    'Thickness', 2, ...
% --- Row 8: Thin default divider again to show stacking ---
d.addWidget('divider', 'Position', [1 8 24 1]);

% --- Row 9+: Static values below the dividers ---
d.addWidget('number', 'Title', 'Batch ID',   'Position', [1  9 6 2], 'StaticValue', 2048, 'Format', '%d',   'Units', '');
d.addWidget('number', 'Title', 'Yield',      'Position', [7  9 6 2], 'StaticValue', 98.3, 'Format', '%.1f', 'Units', '%');
d.addWidget('number', 'Title', 'Reject Rate','Position', [13 9 6 2], 'StaticValue', 1.7,  'Format', '%.1f', 'Units', '%');
d.addWidget('number', 'Title', 'Cycle Time', 'Position', [19 9 6 2], 'StaticValue', 12.4, 'Format', '%.1f', 'Units', 's');

%% 3. Render
d.render();

fprintf('Dashboard rendered with %d widgets.\n', numel(d.Widgets));
fprintf('  Divider 1 (row 3): Thickness=1, theme color (default)\n');
fprintf('  Divider 2 (row 6): Thickness=3, Color=[0.80 0.20 0.20] (red)\n');
fprintf('  Divider 3 (row 7): Thickness=2, Color=[0.20 0.55 0.90] (blue)\n');
fprintf('  Divider 4 (row 8): Thickness=1, theme color (default)\n');
