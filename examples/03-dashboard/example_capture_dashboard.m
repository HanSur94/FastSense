%% Dashboard Screenshot Example (matlab-mcp workflow)
% Demonstrates programmatic screenshot of a DashboardEngine for use with
% matlab-mcp / agentic UI testing. The captureDashboard helper writes the
% rendered dashboard (or a specific widget's panel) to a PNG that an AI
% agent can then Read via the file system tool for visual inspection.
%
% Typical agent workflow (each step is a single tool call):
%   1. Build a DashboardEngine in MATLAB / Octave.
%   2. Call d.render() to lay out the figure.
%   3. Call captureDashboard(d, path) — returns absolute PNG path.
%   4. Read the PNG via the agent's file Read tool.
%   5. Inspect the rendered layout visually; optionally capture a single
%      widget via captureDashboard(d, path, 'Widget', 'Title').
%
% See also: captureDashboard, example_dashboard_info, example_dashboard_engine.

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Build a representative dashboard
% Inline XData/YData on FastSenseWidget avoids TagRegistry/SensorTag setup,
% keeping the example self-contained under headless Octave.
t = linspace(0, 60, 600);
tempC = 70 + 5 * sin(2 * pi * t / 20) + 0.3 * randn(1, numel(t));

d = DashboardEngine('Capture Demo', 'Theme', 'light');

d.addWidget('fastsense', 'Title', 'Temperature', ...
    'Position', [1 1 16 6], ...
    'XData', t, 'YData', tempC);

d.addWidget('number', 'Title', 'Current Temperature', ...
    'Position', [17 1 8 3], ...
    'Units', [char(176) 'C'], ...
    'StaticValue', tempC(end));

d.addWidget('number', 'Title', 'Peak', ...
    'Position', [17 4 8 3], ...
    'Units', [char(176) 'C'], ...
    'StaticValue', max(tempC));

d.addWidget('text', 'Title', 'Notes', ...
    'Position', [1 7 24 3], ...
    'Content', 'captureDashboard() writes this view to PNG for AI-driven UI verification.');

%% 2. Render and let the paint cycle complete
d.render();
set(d.hFigure, 'Visible', 'off');   % Comment out to see the window live
pause(0.5);
drawnow;

%% 3. Capture the full dashboard
outDir = fullfile(tempdir, 'mcp_screenshots');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

fullPng = captureDashboard(d, fullfile(outDir, 'dashboard_full.png'));
fprintf('FULL DASHBOARD: %s\n', fullPng);   % Agent Reads this path

%% 4. Capture a single widget by Title
widgetPng = captureDashboard(d, fullfile(outDir, 'dashboard_widget.png'), ...
    'Widget', 'Current Temperature');
fprintf('WIDGET ONLY:    %s\n', widgetPng);   % Agent Reads this path

%% 5. (Optional) Detached-widget capture flow
% Uncomment this block in an interactive session to demonstrate that a
% widget popped out via DashboardEngine.detachWidget is captured from its
% standalone figure window rather than the main dashboard.
%
%   d.detachWidget(d.Widgets{1});
%   pause(0.5); drawnow;
%   detachedPng = captureDashboard(d, ...
%       fullfile(outDir, 'dashboard_detached.png'), ...
%       'Widget', 'Temperature');
%   fprintf('DETACHED:       %s\n', detachedPng);

%% 6. AGENT WORKFLOW
% The matlab-mcp integration makes the full sequence trivial:
%   (1) Run this script (or equivalent) in MATLAB via matlab-mcp.
%   (2) Agent receives stdout containing the two PNG paths above.
%   (3) Agent calls its Read tool on each path — the image renders as a
%       multimodal attachment (Claude Code treats PNGs as images).
%   (4) Agent verifies layout, spacing, colour, and widget contents.
%   (5) Agent can iterate: adjust dashboard, re-capture, re-read.
%
% For a single-widget focus, prefer the 'Widget' option — on MATLAB it
% crops to the widget's uipanel; on Octave it falls back to the whole
% figure (documented limitation of Octave's print()).
