%% Dashboard Info Page Example
% Demonstrates: DashboardEngine with an Info button that opens a rendered
% Markdown file in the browser.
%
% The InfoFile property links a .md file to the dashboard.  When set, an
% "Info" button appears in the toolbar next to the title.  Clicking it
% renders the Markdown as HTML and opens it in MATLAB's built-in browser.
%
% See also: example_dashboard_engine, example_dashboard_all_widgets.

close all force;
clear functions;
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Generate sample sensor data
rng(7);
N = 10000;
t = linspace(0, 86400, N);  % 24 hours in seconds

sTemp = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'C'], 'X', t, 'Y', 70 + 5*sin(2*pi*t/3600) + randn(1,N)*0.8);


sPress = SensorTag('P-201', 'Name', 'Pressure', 'Units', 'bar', 'X', t, 'Y', 50 + 20*sin(2*pi*t/7200) + randn(1,N)*1.5);


%% 2. Generate a process diagram image for the info page
% The Markdown file references this image via ![...](example_dashboard_info_diagram.png)
examplesDir = fileparts(mfilename('fullpath'));
diagramPath = fullfile(examplesDir, 'example_dashboard_info_diagram.png');
if ~exist(diagramPath, 'file')
    hFig = figure('Visible', 'off', 'Position', [100 100 600 250], 'Color', 'w');
    ax = axes(hFig, 'Visible', 'off');
    hold(ax, 'on');
    % Draw simple block diagram: Feed -> Reactor -> Outlet
    rectangle(ax, 'Position', [0.5 0.3 1.2 0.4], 'Curvature', 0.1, ...
        'FaceColor', [0.85 0.92 1], 'EdgeColor', [0.3 0.5 0.8], 'LineWidth', 1.5);
    text(ax, 1.1, 0.5, {'Feed Header'; 'P-201'}, 'HorizontalAlignment', 'center', 'FontSize', 10);

    rectangle(ax, 'Position', [2.5 0.15 1.5 0.7], 'Curvature', 0.1, ...
        'FaceColor', [1 0.92 0.85], 'EdgeColor', [0.8 0.5 0.3], 'LineWidth', 1.5);
    text(ax, 3.25, 0.5, 'Reactor', 'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');

    rectangle(ax, 'Position', [4.8 0.3 1.2 0.4], 'Curvature', 0.1, ...
        'FaceColor', [0.85 1 0.88], 'EdgeColor', [0.3 0.7 0.4], 'LineWidth', 1.5);
    text(ax, 5.4, 0.5, {'Outlet'; 'T-401'}, 'HorizontalAlignment', 'center', 'FontSize', 10);

    % Arrows
    annotation(hFig, 'arrow', [0.30 0.40], [0.5 0.5], 'LineWidth', 1.5);
    annotation(hFig, 'arrow', [0.66 0.76], [0.5 0.5], 'LineWidth', 1.5);

    xlim(ax, [0 6.5]);
    ylim(ax, [0 1]);
    print(hFig, diagramPath, '-dpng', '-r150');
    close(hFig);
    fprintf('Generated process diagram: %s\n', diagramPath);
end

%% 3. Create dashboard with InfoFile
% The InfoFile points to a Markdown file in the same directory as this
% script.  The Info button will appear in the toolbar.
infoPath = fullfile(fileparts(mfilename('fullpath')), 'example_dashboard_info.md');

d = DashboardEngine('Process Monitoring — Line 4', ...
    'Theme', 'light', ...
    'InfoFile', infoPath);

d.addWidget('fastsense', ...
    'Position', [1 1 16 8], ...
    'Tag', sTemp);

d.addWidget('fastsense', ...
    'Position', [17 1 8 8], ...
    'Tag', sPress);

d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 9 6 4], ...
    'Units', [char(176) 'C'], ...
    'Tag', sTemp);

d.addWidget('number', 'Title', 'Pressure', ...
    'Position', [7 9 6 4], ...
    'Units', 'bar', ...
    'Tag', sPress);

d.addWidget('text', 'Title', 'Notes', ...
    'Position', [13 9 12 4], ...
    'Content', 'Click the Info button in the toolbar to view dashboard documentation.');

d.render();
fprintf('Dashboard rendered. Click the "Info" button next to the title.\n');

%% 4. Save and reload — InfoFile is preserved
jsonPath = fullfile(tempdir, 'example_dashboard_info.json');
d.save(jsonPath);
fprintf('Dashboard saved to: %s\n', jsonPath);

% Verify InfoFile survives the JSON round-trip
jsonText = fileread(jsonPath);
assert(contains(jsonText, 'infoFile'), 'infoFile should be in JSON');
fprintf('JSON contains infoFile field: OK\n');

% Register sensors so that fromStruct can resolve them during load
TagRegistry.register('T-401', sTemp);
TagRegistry.register('P-201', sPress);

d2 = DashboardEngine.load(jsonPath);
fprintf('Reloaded InfoFile: %s\n', d2.InfoFile);

% Clean up registry
TagRegistry.unregister('T-401');
TagRegistry.unregister('P-201');
