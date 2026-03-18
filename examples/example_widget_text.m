%% Dashboard Engine — TextWidget Configurations
% Demonstrates every configuration of the TextWidget.
%
%   Supported properties:
%     Content   — body text string
%     FontSize  — numeric, 0 = auto/adaptive (default)
%     Alignment — 'left' (default), 'center', or 'right'
%     Title     — widget title (displayed as label on the left)
%     Position  — [col row width height] on 24-column grid
%
% Usage:
%   example_widget_text

close all force;
clear functions;  % flush MATLAB function cache

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% ========== Build Dashboard ==========
d = DashboardEngine('Text Widget Demo');

% --- Row 1-2: Left aligned (default) with explicit font size ---
d.addWidget('text', 'Title', 'Header', ...
    'Position', [1 1 24 2], ...
    'Content', 'Line 4 — Shift A', ...
    'FontSize', 16);

% --- Row 3-4: Center aligned ---
d.addWidget('text', 'Title', 'Status', ...
    'Position', [1 3 24 2], ...
    'Content', 'System Online', ...
    'Alignment', 'center');

% --- Row 5-6: Right aligned ---
d.addWidget('text', 'Title', 'Timestamp', ...
    'Position', [1 5 24 2], ...
    'Content', datestr(now), ... %#ok<TNOW1,DATST>
    'Alignment', 'right');

% --- Row 7-8: Auto font size (default, adapts to panel height) ---
d.addWidget('text', 'Title', 'Info', ...
    'Position', [1 7 24 2], ...
    'Content', 'Font size adapts to panel height');

% --- Row 9-10: Large font ---
d.addWidget('text', 'Title', 'Alert', ...
    'Position', [1 9 24 2], ...
    'Content', 'MAINTENANCE SCHEDULED', ...
    'FontSize', 20);

% --- Row 11-12: No title (content only) ---
d.addWidget('text', ...
    'Position', [1 11 24 2], ...
    'Content', 'Full-width content without a title label', ...
    'FontSize', 12);

%% Render
d.render();
