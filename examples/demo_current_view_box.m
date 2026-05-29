%% Demo: Lower-slider per-graph "current view" boxes (Phase 1039)
% The existing lower preview slider (TimeRangeSelector) keeps its draggable
% SELECTION window exactly as before. Phase 1039 adds, inside the slider, ONE
% smaller "current view" box PER visible graph that is NOT synchronized with
% the selection (i.e. you zoomed/panned that plot directly). Each box is drawn
% in the SAME colour as that graph's slider preview line, so you can tell at a
% glance which plot is looking where.
%
% This demo renders a 3-widget dashboard and pre-zooms TWO plots to different
% interior windows, so two differently-coloured current-view boxes are already
% visible in the lower slider on load.
%
% Try this in the figure:
%   1. Lower slider: the wide translucent rectangle is the SELECTION. The two
%      smaller coloured boxes are the CURRENT VIEWS of the zoomed plots — each
%      box matches its plot's preview-line colour.
%   2. Zoom/pan the THIRD plot (scroll / toolbar) — a third box appears in that
%      plot's colour at its window. One box per out-of-sync graph.
%   3. Drag the slider SELECTION to match a plot, or press "Sync all" — as each
%      plot comes back in sync, its box disappears.

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

%% 3. Pre-zoom TWO plots so two coloured current-view boxes show on load
% (Real interactive zoom does exactly this — here we drive it programmatically
%  so the boxes are visible immediately. Each box matches its plot's preview
%  line colour.)
wTemp  = d.Widgets{1};
wPress = d.Widgets{2};
try
    xlim(wTemp.FastSenseObj.hAxes,  [120 240]);   % zoom Temperature -> 120..240 s
    wTemp.UseGlobalTime = false;
    xlim(wPress.FastSenseObj.hAxes, [400 520]);   % zoom Pressure    -> 400..520 s
    wPress.UseGlobalTime = false;
catch
end
% Let FastSense's zoom re-resolve settle so the axes hold the zoomed window
% before we read it (FastSense rebuilds line graphics on an XLim change).
for s = 1:4; drawnow; pause(0.05); end
% Refresh the indicator now (normally fired by each widget's XLim listener).
try d.updateCurrentViewIndicatorForTest_(); catch, end

fprintf('\nCurrent-view box demo rendered.\n');
fprintf('  Full extent       : %.0f .. %.0f s (slider DataRange)\n', t(1), t(end));
fprintf('  Temperature zoomed: 120 .. 240 s  -> box in Temperature''s colour\n');
fprintf('  Pressure zoomed   : 400 .. 520 s  -> box in Pressure''s colour\n');
fprintf('\nInteract:\n');
fprintf('  - Zoom/pan the Flow plot      -> a third box appears in Flow''s colour\n');
fprintf('  - Re-sync a plot (Sync all / match selection) -> that plot''s box disappears\n');
fprintf('  - One box per out-of-sync graph; the wide rectangle is the SELECTION\n');
