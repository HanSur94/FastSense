%% FastSenseDock — Many Tabs (Scroll Arrows) Example
% 20 tabs in a single dock window to exercise the scrollable tab bar.
% Each tab gets a simple 1x1 figure with a sine wave variant.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

wState = warning('off', 'all');
restoreWarn = onCleanup(@() warning(wState));

fprintf('Docked Tabs: 20 tabs — testing scrollable tab bar...\n');
tic;

dock = FastSenseDock('Theme', 'dark', 'Name', 'Many Tabs Demo', ...
    'Position', [50 50 1400 800]);

% Common time base
t0 = datetime(2026, 3, 8, 8, 0, 0);
t1 = datetime(2026, 3, 8, 9, 0, 0);
sec = @(t) seconds(t - t0);

tabNames = { ...
    'Temperature',   'Pressure',    'Vibration',    'Flow Rate', ...
    'Humidity',      'Voltage',     'Current',      'RPM', ...
    'Torque',        'Load',        'Frequency',    'Phase', ...
    'Displacement',  'Acceleration','Strain',       'Force', ...
    'Power',         'Energy',      'Noise',        'CO2 Level'};

n = 200000;  % points per tab (kept small for fast rendering)
t = linspace(t0, t1, n);
s = sec(t);

for k = 1:20
    fig = FastSenseGrid(1, 1, 'ParentFigure', dock.hFigure, 'Theme', 'dark');
    fp = fig.tile(1);

    % Vary the signal per tab
    freq = 300 + k * 50;
    amp  = 5 + k * 0.5;
    offset = 10 * k;
    y = offset + amp * sin(s * 2 * pi / freq) + 0.5 * randn(1, n);
    fp.addLine(t, y, 'DisplayName', tabNames{k});
    fp.addThreshold(offset + amp * 0.8, 'Direction', 'upper', ...
        'ShowViolations', true, 'Label', 'High');

    dock.addTab(fig, tabNames{k});
end

dock.renderAll();

% Label each tab's tile
for k = 1:20
    dock.Tabs(k).Figure.setTileTitle(1, sprintf('%s (200K pts)', tabNames{k}));
    dock.Tabs(k).Figure.setTileYLabel(1, tabNames{k});
end

elapsed = toc;
fprintf('20-tab dock rendered in %.2f seconds.\n', elapsed);
fprintf('Use < > arrows to scroll through tabs.\n');
