%% Demo: per-graph current-view boxes across MULTIPLE TABS (Phase 1039)
% The lower-slider current-view boxes scope to the ACTIVE page. Each box marks
% one out-of-sync graph's window in that graph's preview-line colour. Switching
% tabs clears the previous page's boxes and surfaces the new page's — driven by
% the same DashboardEngine.switchPage path the tab buttons use.
%
% This demo builds a 2-page dashboard:
%   Page 1 "Process"   — Temperature, Pressure
%   Page 2 "Utilities" — Flow, Level
% and pre-zooms one plot on EACH page so a coloured box is waiting on both tabs.
%
% Try this in the figure:
%   1. Page 1 is active: a coloured box marks the zoomed Temperature window.
%   2. Click the "Utilities" tab — Page 1's box clears; a coloured box marks the
%      zoomed Flow window on Page 2.
%   3. Zoom/pan the other plot on a tab — a second box appears (one per graph).
%   4. Click back to "Process" — Page 1's box returns. Re-sync a plot to clear
%      its box.

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% 1. Synthetic 10-minute data
rng(11);
N = 4000;
t = linspace(0, 600, N);
yTemp  = 70 + 5*sin(2*pi*t/120) + randn(1, N)*0.6;
yPress = 50 + 18*sin(2*pi*t/90) + randn(1, N)*1.2;
yFlow  = 12 + 3*cos(2*pi*t/75)  + randn(1, N)*0.4;
yLevel = 40 + 8*sin(2*pi*t/150) + randn(1, N)*0.7;

%% 2. Two-page dashboard
d = DashboardEngine('Current-View Box — Multi-Tab Demo (Phase 1039)');
d.Theme = 'dark';
d.addPage('Process');
d.addWidget('fastsense', 'Position', [1 1 24 6],  'Title', 'Temperature', 'XData', t, 'YData', yTemp);
d.addWidget('fastsense', 'Position', [1 7 24 6],  'Title', 'Pressure',    'XData', t, 'YData', yPress);
d.addPage('Utilities');
d.switchPage(2);
d.addWidget('fastsense', 'Position', [1 1 24 6],  'Title', 'Flow',  'XData', t, 'YData', yFlow);
d.addWidget('fastsense', 'Position', [1 7 24 6],  'Title', 'Level', 'XData', t, 'YData', yLevel);
d.switchPage(1);
d.render();

%% 3. Pre-zoom one plot on EACH page so a box is waiting on both tabs
% Page-2 widgets only realize when their tab is first shown, so briefly visit
% page 2 to zoom Flow, then return to page 1. (Real interactive zoom does the
% same; switching tabs re-attaches each page's current-view listener.)
wTemp = d.Pages{1}.Widgets{1};   % Temperature on page 1
wFlow = d.Pages{2}.Widgets{1};   % Flow on page 2
try
    xlim(wTemp.FastSenseObj.hAxes, [120 240]);   % zoom Temperature on page 1
    wTemp.UseGlobalTime = false;
catch
end
d.switchPage(2);                                 % realize page 2 widgets
for s = 1:3; drawnow; pause(0.05); end
try
    xlim(wFlow.FastSenseObj.hAxes, [380 500]);   % zoom Flow on page 2
    wFlow.UseGlobalTime = false;
catch
end
for s = 1:3; drawnow; pause(0.05); end
d.switchPage(1);                                 % back to page 1 (Temperature box)
for s = 1:3; drawnow; pause(0.05); end

fprintf('\nMulti-tab current-view demo rendered (2 pages).\n');
fprintf('  Page 1 "Process"   : Temperature pre-zoomed 120..240 s -> coloured box on the slider\n');
fprintf('  Page 2 "Utilities" : Flow pre-zoomed 380..500 s (surfaces when you open the tab)\n');
fprintf('\nInteract:\n');
fprintf('  - Click the "Utilities" tab -> P1 box clears, Flow''s box shows\n');
fprintf('  - Click back to "Process"   -> Temperature''s box returns\n');
fprintf('  - Boxes always reflect the ACTIVE tab; one box per out-of-sync graph\n');
