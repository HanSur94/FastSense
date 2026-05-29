%% Demo: Lower-slider "current view" box (Phase 1039)
% The existing lower preview slider (TimeRangeSelector) keeps its draggable
% SELECTION window exactly as before. Phase 1039 adds a second, smaller,
% amber "current view" box that marks where the plots are ACTUALLY looking
% right now — and it only appears when a plot's x-limits are NOT synchronized
% with the slider selection (i.e. you zoomed/panned one plot directly).
%
% This demo renders a 3-widget dashboard and pre-zooms the top plot to an
% interior window so the amber current-view box is already visible in the
% lower slider on load.
%
% Try this in the figure:
%   1. Lower slider: the wide translucent rectangle is the SELECTION; the
%      smaller amber box is the CURRENT VIEW of the zoomed (top) plot.
%   2. Zoom/pan the MIDDLE or BOTTOM plot (scroll / toolbar) — its window
%      joins the amber box (the box spans the union of out-of-sync plots).
%   3. Drag the slider SELECTION to match a plot, or press the dashboard's
%      "Sync all" — once every plot is back in sync, the amber box disappears.

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% 1. Synthetic 10-minute sensor data (shared time base)
rng(11);
N = 4000;
t = linspace(0, 600, N);                                   % 10 minutes, seconds
yTemp  = 70 + 5*sin(2*pi*t/120) + randn(1, N)*0.6;         % degrees C
yPress = 50 + 18*sin(2*pi*t/90)  + randn(1, N)*1.2;        % bar
yFlow  = 12 + 3*cos(2*pi*t/75)   + randn(1, N)*0.4;        % L/s

sTemp  = SensorTag('T-401', 'Name', 'Temperature', 'Units', [char(176) 'C'], 'X', t, 'Y', yTemp);
sPress = SensorTag('P-201', 'Name', 'Pressure',    'Units', 'bar',           'X', t, 'Y', yPress);
sFlow  = SensorTag('F-101', 'Name', 'Flow',        'Units', 'L/s',           'X', t, 'Y', yFlow);

%% 2. Three-widget dashboard (lower TimeRangeSelector builds automatically)
d = DashboardEngine('Current-View Box Demo — Phase 1039');
d.Theme = 'dark';
d.addWidget('fastsense', 'Position', [1 1  24 6], 'Tag', sTemp);
d.addWidget('fastsense', 'Position', [1 7  24 6], 'Tag', sPress);
d.addWidget('fastsense', 'Position', [1 13 24 6], 'Tag', sFlow);
d.render();

%% 3. Pre-zoom the top plot so the amber current-view box shows on load
% (Real interactive zoom does exactly this — here we drive it programmatically
%  so the box is visible immediately.)
wTop = d.Widgets{1};
try
    xlim(wTop.FastSenseObj.hAxes, [120 240]);   % zoom Temperature to 120..240 s
    wTop.UseGlobalTime = false;                 % detach it from the slider selection
catch
end
drawnow;
% Refresh the indicator now (normally fired by the widget's XLim listener).
try d.updateCurrentViewIndicatorForTest_(); catch, end

fprintf('\nCurrent-view box demo rendered.\n');
fprintf('  Full extent      : %.0f .. %.0f s (slider DataRange)\n', t(1), t(end));
fprintf('  Top plot zoomed  : 120 .. 240 s  -> amber CURRENT-VIEW box in the lower slider\n');
fprintf('\nInteract:\n');
fprintf('  - Zoom/pan another plot      -> amber box grows to span all out-of-sync views\n');
fprintf('  - Drag slider selection / Sync all to re-sync -> amber box disappears\n');
fprintf('  - The wide translucent rectangle is the SELECTION (unchanged behavior)\n');
