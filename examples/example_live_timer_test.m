%% example_live_timer_test.m — Test dashboard live mode with MATLAB timer
%
% Run this from the MATLAB IDE to verify timer-based live polling works.
% The script creates a dashboard, starts live mode, writes data updates,
% and verifies the timer detects each change automatically.
%
% Usage:
%   >> cd /path/to/FastPlot
%   >> run examples/example_live_timer_test.m

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

fprintf('\n=== Dashboard Live Timer Test ===\n\n');

% --- Create initial data file ---
tmpFile = fullfile(tempdir, 'fastplot_timer_test.mat');
nPoints = 1000;
s.time = linspace(0, 100, nPoints);
s.pressure = sin(s.time * 2*pi/10);
s.temperature = 50 + 5*cos(s.time * 2*pi/20);
save(tmpFile, '-struct', 's');
fprintf('1. Created initial data: %d points\n', nPoints);

% --- Create dashboard ---
fig = FastPlotFigure(2, 1, 'Theme', 'dark', 'Name', 'Live Timer Test');
fp1 = fig.tile(1);
fp1.addLine(s.time, s.pressure, 'DisplayName', 'Pressure', 'Color', [0.3 0.7 1]);
fp2 = fig.tile(2);
fp2.addLine(s.time, s.temperature, 'DisplayName', 'Temperature', 'Color', [1 0.5 0.3]);
fig.renderAll();
fig.tileTitle(1, 'Pressure');
fig.tileTitle(2, 'Temperature');
tb = FastPlotToolbar(fig);
drawnow;
fprintf('2. Dashboard rendered\n');

% --- Start live mode with 1s timer ---
fig.startLive(tmpFile, @(f,d) updateTiles(f,d), 'Interval', 1.0, 'ViewMode', 'preserve');
assert(fig.LiveIsActive, 'FAIL: LiveIsActive should be true');
fprintf('3. startLive() active, timer running (1s interval)\n');

% --- Update 1 ---
pause(2);
nNew = 2000;
s.time = linspace(0, 200, nNew);
s.pressure = sin(s.time * 2*pi/10) + 1.0;
s.temperature = 60 + 5*cos(s.time * 2*pi/20);
save(tmpFile, '-struct', 's');
fprintf('4. Wrote update 1: %d points (pressure +1, temp +10)\n', nNew);

ok = waitForUpdate(fp1, nNew, 15);
assert(ok, 'FAIL: Update 1 not detected');
fprintf('   Detected! Pressure: %d pts, mean=%.2f. PASSED\n', numel(fp1.Lines(1).Y), mean(fp1.Lines(1).Y));

% --- Update 2 ---
pause(2);
nNew2 = 3000;
s.time = linspace(0, 300, nNew2);
s.pressure = sin(s.time * 2*pi/10) + 2.0;
s.temperature = 70 + 5*cos(s.time * 2*pi/20);
save(tmpFile, '-struct', 's');
fprintf('5. Wrote update 2: %d points (pressure +2, temp +20)\n', nNew2);

ok = waitForUpdate(fp1, nNew2, 15);
assert(ok, 'FAIL: Update 2 not detected');
fprintf('   Detected! Pressure: %d pts, mean=%.2f. PASSED\n', numel(fp1.Lines(1).Y), mean(fp1.Lines(1).Y));

% --- Update 3 ---
pause(2);
nNew3 = 5000;
s.time = linspace(0, 500, nNew3);
s.pressure = sin(s.time * 2*pi/10) + 3.0;
s.temperature = 80 + 5*cos(s.time * 2*pi/20);
save(tmpFile, '-struct', 's');
fprintf('6. Wrote update 3: %d points (pressure +3, temp +30)\n', nNew3);

ok = waitForUpdate(fp1, nNew3, 15);
assert(ok, 'FAIL: Update 3 not detected');
fprintf('   Detected! Pressure: %d pts, mean=%.2f. PASSED\n', numel(fp1.Lines(1).Y), mean(fp1.Lines(1).Y));

% --- Stop and verify ---
fig.stopLive();
assert(~fig.LiveIsActive, 'FAIL: LiveIsActive should be false after stop');
fprintf('7. stopLive() OK\n');

delete(tmpFile);
fprintf('\n=== All tests PASSED ===\n');
fprintf('Figure stays open — zoom and pan to explore.\n');


%% --- Local functions ---

function updateTiles(f, d)
    f.tile(1).updateData(1, d.time, d.pressure);
    f.tile(2).updateData(1, d.time, d.temperature);
end

function ok = waitForUpdate(fp, expectedN, timeout)
    waited = 0;
    while waited < timeout
        pause(0.5);
        drawnow;
        waited = waited + 0.5;
        if numel(fp.Lines(1).Y) == expectedN
            ok = true;
            return;
        end
    end
    ok = false;
end
