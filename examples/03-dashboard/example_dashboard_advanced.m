%% Advanced Dashboard — All Phase 01-08 Features
% Demonstrates all new dashboard features added in phases 01-08:
%
%   Feature 1: Multi-page navigation     — addPage / switchPage
%   Feature 2: Widget info tooltips      — Description property on widgets
%   Feature 3: Detachable widgets        — ^ button on widget headers (auto)
%   Feature 4: DividerWidget             — visual section separators
%   Feature 5: CollapsibleWidget         — addCollapsible convenience method
%   Feature 6: Y-axis limits             — YLimits on FastSenseWidget
%   Feature 7: GroupWidget tabbed mode   — multi-view tabbed container
%   Feature 8: JSON save/load roundtrip  — multi-page persists to JSON
%   Feature 9: InfoFile                  — Markdown doc linked to toolbar
%
% Usage:
%   example_dashboard_advanced
%
% After render:
%   - Click the page buttons (Overview / Analysis) to switch pages
%   - Hover over a widget title to see its Description tooltip (info icon)
%   - Click "^" in any widget header to detach it as a standalone window
%   - Click the collapsed "Sensor Details" header to expand/collapse it
%   - Click "Info" in the toolbar to open the linked Markdown documentation
%   - See console output for JSON save/load roundtrip confirmation

close all force;
clear functions;  % flush MATLAB function cache

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% ========== Generate realistic process data ==========
rng(42);  % reproducible
N = 10000;
t = linspace(0, 86400, N);  % 24 hours in seconds

% --- Machine mode state channel (idle=0, running=1, maintenance=2) ---
modeChangeTimes = [0, 3600, 7200, 28800, 36000, 72000, 79200, 82800];
modeValues      = [0, 1,    1,    2,     1,     0,     1,     1];

scMode = StateTag('machine', 'X', modeChangeTimes, 'Y', modeValues);

% --- Temperature sensor T-401 ---
tempBase = zeros(1, N);
for k = 1:N
    mode = scMode.valueAt(t(k));
    switch mode
        case 0, tempBase(k) = 68;
        case 1, tempBase(k) = 74;
        case 2, tempBase(k) = 65;
    end
end
tempNoise = 3*sin(2*pi*t/3600) + randn(1,N)*1.2;
temp = tempBase + tempNoise;
% Inject a brief overshoot around hour 10
overIdx = t >= 36000 & t <= 38000;
temp(overIdx) = temp(overIdx) + 12;

sTemp = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'F'], 'X', t, 'Y', temp);

% --- Pressure sensor P-201 ---
pressBase = zeros(1, N);
for k = 1:N
    mode = scMode.valueAt(t(k));
    switch mode
        case 0, pressBase(k) = 30;
        case 1, pressBase(k) = 55;
        case 2, pressBase(k) = 20;
    end
end
pressNoise = 8*sin(2*pi*t/7200) + randn(1,N)*2;
pressure = pressBase + pressNoise;

sPress = SensorTag('P-201', 'Name', 'Pressure', 'Units', 'psi', 'X', t, 'Y', pressure);

% --- Flow sensor F-301 ---
flowBase = zeros(1, N);
for k = 1:N
    mode = scMode.valueAt(t(k));
    switch mode
        case 0, flowBase(k) = 0;
        case 1, flowBase(k) = 120;
        case 2, flowBase(k) = 0;
    end
end
flowNoise = 5*sin(2*pi*t/1800) + randn(1,N)*3;
flow = max(0, flowBase + flowNoise);

sFlow = SensorTag('F-301', 'Name', 'Flow Rate', 'Units', 'L/min', 'X', t, 'Y', flow);

%% ========== Build mock alarm log ==========
% Violation tracking moved to MonitorTag in the v2.0 Tag model; this demo
% does not wire a MonitorTag so we synthesize a small alarm log by
% picking the top-2 samples per sensor and labelling them by a simple
% warn/alarm threshold. Consumed unchanged by the TableWidget below.
alarmLog = {};
sensorSpecs = { ...
    sTemp,  78, 85, 'T-401'; ...
    sPress, 60, 70, 'P-201'; ...
    sFlow,  130, 150, 'F-301' ...
};
for si = 1:size(sensorSpecs, 1)
    s        = sensorSpecs{si, 1};
    warnVal  = sensorSpecs{si, 2};
    alarmVal = sensorSpecs{si, 3};
    sKey     = sensorSpecs{si, 4};
    [~, yAll] = s.getXY();
    xAll      = s.X;
    [~, peakIdx] = maxk(yAll, 2);
    peakIdx = sort(peakIdx);
    for j = 1:numel(peakIdx)
        yVal = yAll(peakIdx(j));
        if yVal >= alarmVal
            label = 'Hi Alarm';
        elseif yVal >= warnVal
            label = 'Hi Warn';
        else
            label = 'Peak';
        end
        tSec  = xAll(peakIdx(j));
        hours = floor(tSec / 3600);
        mins  = floor(mod(tSec, 3600) / 60);
        timeStr = sprintf('%02d:%02d', hours, mins);
        alarmLog(end+1, :) = {timeStr, sKey, sprintf('%.1f', yVal), label}; %#ok<AGROW>
    end
end
if ~isempty(alarmLog)
    [~, sortIdx] = sort(alarmLog(:, 1));
    alarmLog = alarmLog(sortIdx, :);
    if size(alarmLog, 1) > 8
        alarmLog = alarmLog(end-7:end, :);
    end
end

%% ========== Feature 9: InfoFile — Markdown doc linked to toolbar ==========
% Point InfoFile at the existing example_dashboard_info.md for demonstration.
% An "Info" button appears in the toolbar; clicking it renders the Markdown
% and opens it in MATLAB's built-in browser.
infoPath = fullfile(fileparts(mfilename('fullpath')), 'example_dashboard_info.md');

%% ========== Create DashboardEngine with InfoFile (Feature 9) ==========
d = DashboardEngine('Advanced Dashboard Demo', 'Theme', 'light', 'InfoFile', infoPath);

%% ========== Feature 1: Multi-page navigation — Page 1 "Overview" ==========
d.addPage('Overview');   % Page 1 — ActivePage is now 1
d.addPage('Analysis');   % Page 2 — ActivePage stays at 1
% Widgets added below go to page 1 (the active page)

%% Feature 6 + Feature 2: FastSenseWidget with YLimits and Description tooltip
% YLimits pins the Y-axis so the view is stable across refreshes.
% Description adds a small info icon; hovering reveals the tooltip text.
d.addWidget('fastsense', ...
    'Tag', sTemp, ...
    'YLimits', [55 100], ...
    'Description', 'Temperature sensor T-401.  Y-axis fixed to 55–100 °F so threshold lines are always visible regardless of zoom level.', ...
    'Position', [1 1 24 4]);

%% Feature 4: DividerWidget — horizontal rule separating sections
d.addWidget('divider', 'Position', [1 5 24 1]);

%% KPI row: number, gauge, status — each with Description tooltip (Feature 2)
d.addWidget('number', 'Title', 'Temperature', ...
    'Tag', sTemp, ...
    'Format', '%.1f', ...
    'Description', 'Latest temperature reading from T-401 with trend arrow.', ...
    'Position', [1 6 8 3]);

d.addWidget('gauge', 'Title', 'Pressure', ...
    'Tag', sPress, ...
    'Range', [0 80], ...
    'Description', 'Live pressure gauge.  Red arc indicates Hi Alarm zone (>65 psi).', ...
    'Position', [9 6 8 3]);

d.addWidget('status', 'Title', 'Flow Status', ...
    'Tag', sFlow, ...
    'Description', 'Traffic-light indicator: green = nominal, yellow = Lo Warn, red = Hi Alarm.', ...
    'Position', [17 6 8 3]);

%% Feature 5: CollapsibleWidget convenience method
% addCollapsible wraps children in a GroupWidget with Mode='collapsible'.
% The header is clickable — click it to toggle visibility.
childTable = TableWidget('Title', 'Alarm Log', ...
    'ColumnNames', {'Time', 'Tag', 'Value', 'Threshold'}, ...
    'Data', alarmLog);
childText = TextWidget('Title', 'Notes', ...
    'Content', sprintf(['24-hour sensor data (N=%d pts).\n' ...
        'Temperature overshoots Hi Alarm between 10:00 and 10:33.\n' ...
        'Pressure Lo Warn active during idle periods.'], N));
d.addCollapsible('Sensor Details', {childTable, childText}, ...
    'Position', [1 9 24 4]);

%% ========== Feature 1: Switch to Page 2 "Analysis" ==========
d.switchPage(2);
% All subsequent addWidget calls route to page 2.

%% Feature 7: GroupWidget tabbed mode — multiple views sharing one space
g = d.addWidget('group', 'Label', 'Sensor Distributions', 'Mode', 'tabbed', ...
    'Position', [1 1 24 6]);
g.addChild(HistogramWidget('Tag', sTemp, 'Title', 'Temperature Distribution', ...
    'ShowNormalFit', true, 'NumBins', 40), 'Temperature');
g.addChild(HistogramWidget('Tag', sPress, 'Title', 'Pressure Distribution', ...
    'ShowNormalFit', true, 'NumBins', 40), 'Pressure');
g.addChild(HistogramWidget('Tag', sFlow, 'Title', 'Flow Distribution', ...
    'NumBins', 40), 'Flow');

%% Second FastSenseWidget on page 2 with YLimits and tooltip (Features 6 + 2)
d.addWidget('fastsense', ...
    'Tag', sPress, ...
    'YLimits', [0 80], ...
    'Description', 'Pressure sensor P-201.  Y-axis fixed to 0–80 psi to show threshold lines clearly.', ...
    'Position', [1 7 24 4]);

%% Feature 4: Custom-styled divider — thicker red line as visual alert marker
d.addWidget('divider', ...
    'Thickness', 2, ...
    'Color', [0.8 0.2 0.2], ...
    'Position', [1 11 24 1]);

d.addWidget('scatter', 'Title', 'Temp vs Pressure (color = Flow)', ...
    'SensorX', sTemp, ...
    'SensorY', sPress, ...
    'SensorColor', sFlow, ...
    'MarkerSize', 3, ...
    'Colormap', 'parula', ...
    'Description', 'Cross-sensor scatter.  Color encodes flow rate: blue = low, yellow = high.', ...
    'Position', [1 12 24 5]);

%% Switch back to page 1 for initial view
d.switchPage(1);

%% ========== Render ==========
% Feature 3: Detachable widgets
% After render, each widget header shows a "^" button.  Click it to detach
% the widget as a live-mirrored standalone figure window.  The detached
% window refreshes on the same LiveInterval as the dashboard.
d.render();

fprintf('\n=== Advanced Dashboard rendered ===\n');
fprintf('Page 1 "Overview" is shown by default.\n');
fprintf('Click "Analysis" in the page bar to switch to page 2.\n');
fprintf('Click the "^" button on any widget header to detach it (Feature 3).\n');
fprintf('Click the "Sensor Details" header to collapse/expand it (Feature 5).\n');
fprintf('Click the "Info" toolbar button to view the Markdown documentation (Feature 9).\n');

%% ========== Feature 8: JSON save / load roundtrip with multi-page ==========
jsonPath = fullfile(tempdir, 'advanced_dashboard_demo.json');
d.save(jsonPath);
fprintf('\nSaved to: %s\n', jsonPath);

% Register sensors so fromStruct can resolve them during load
TagRegistry.register('T-401', sTemp);
TagRegistry.register('P-201', sPress);
TagRegistry.register('F-301', sFlow);

% Load back — multi-page layout, InfoFile, and widget properties all preserved
d2 = DashboardEngine.load(jsonPath);
fprintf('Reloaded: %d widget(s), %d page(s), InfoFile="%s"\n', ...
    numel(d2.Widgets), numel(d2.Pages), d2.InfoFile);
assert(numel(d2.Pages) == 2, 'Expected 2 pages after reload');

% Clean up
TagRegistry.unregister('T-401');
TagRegistry.unregister('P-201');
TagRegistry.unregister('F-301');
delete(jsonPath);
fprintf('Temp file cleaned up.\n');

%% ========== Summary ==========
fprintf('\n--- Features demonstrated in this script ---\n');
fprintf('  1. Multi-page navigation     addPage(Overview/Analysis) + switchPage()\n');
fprintf('  2. Widget info tooltips       Description= on 5+ widgets\n');
fprintf('  3. Detachable widgets         ^ button in widget headers (auto-enabled)\n');
fprintf('  4. DividerWidget              Two instances: default + custom red styled\n');
fprintf('  5. CollapsibleWidget          addCollapsible wrapping Table + Text\n');
fprintf('  6. Y-axis limits              YLimits=[55 100] and [0 80] on two sensors\n');
fprintf('  7. GroupWidget tabbed mode    Histogram tabs for Temp/Pressure/Flow\n');
fprintf('  8. JSON save/load roundtrip   Multi-page + InfoFile persist correctly\n');
fprintf('  9. InfoFile                   Markdown doc linked to toolbar Info button\n');
