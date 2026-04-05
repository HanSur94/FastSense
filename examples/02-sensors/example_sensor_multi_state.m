%% Multi-State Sensor — Advanced Threshold Features
% Demonstrates:
%   - Two state channels (machine state + zone)
%   - String-valued state channel
%   - Combined conditions across multiple states
%   - Both upper and lower thresholds
%   - getThresholdsAt() for querying active thresholds at a time point

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

% --- Create sensor with synthetic flow data ---
s = Sensor('flow', 'Name', 'Gas Flow Rate', 'ID', 301);
t = linspace(0, 120, 60000);
s.X = t;
s.Y = 50 + 15*sin(2*pi*t/20) + 3*randn(1, numel(t));

% Add deliberate excursions
s.Y(8000:8200) = s.Y(8000:8200) + 30;   % spike during running
s.Y(25000:25300) = s.Y(25000:25300) - 25; % dip during evacuated
s.Y(45000:45100) = s.Y(45000:45100) + 20; % spike in zone B

% --- Numeric state channel: machine state ---
scMachine = StateChannel('machine');
scMachine.X = [0  30  60  90];
scMachine.Y = [0   1   2   1];  % 0=idle, 1=running, 2=evacuated

% --- String-valued state channel: zone ---
scZone = StateChannel('zone');
scZone.X = [0, 40, 80];
scZone.Y = {'A', 'B', 'A'};  % zone changes mid-run

s.addStateChannel(scMachine);
s.addStateChannel(scZone);

% --- Upper thresholds per machine state ---
% Idle: lenient upper limit
tHhIdle = Threshold('hh_idle', 'Name', 'HH (idle)', ...
    'Direction', 'upper', 'Color', [0.9 0.4 0.1], 'LineStyle', '--');
tHhIdle.addCondition(struct('machine', 0), 80);
s.addThreshold(tHhIdle);

% Running: tighter upper limit
tHhRunning = Threshold('hh_running', 'Name', 'HH (running)', ...
    'Direction', 'upper', 'Color', [0.9 0.1 0.1], 'LineStyle', '--');
tHhRunning.addCondition(struct('machine', 1), 68);
s.addThreshold(tHhRunning);

% Evacuated: strictest upper limit
tHhEvacuated = Threshold('hh_evacuated', 'Name', 'HH (evacuated)', ...
    'Direction', 'upper', 'Color', [1 0 0], 'LineStyle', '-');
tHhEvacuated.addCondition(struct('machine', 2), 55);
s.addThreshold(tHhEvacuated);

% --- Lower threshold only when evacuated ---
tLlEvacuated = Threshold('ll_evacuated', 'Name', 'LL (evacuated)', ...
    'Direction', 'lower', 'Color', [0.1 0.1 0.9], 'LineStyle', '-');
tLlEvacuated.addCondition(struct('machine', 2), 30);
s.addThreshold(tLlEvacuated);

% --- Combined condition: running AND zone B → extra-strict upper ---
tHhRunningZoneB = Threshold('hh_running_zoneb', 'Name', 'HH (running+zoneB)', ...
    'Direction', 'upper', 'Color', [0.8 0 0.8], 'LineStyle', ':');
tHhRunningZoneB.addCondition(struct('machine', 1, 'zone', 'B'), 60);
s.addThreshold(tHhRunningZoneB);

% --- Resolve all thresholds and violations ---
s.resolve();

% --- StateChannel.valueAt — query the state at a specific time ---
fprintf('\nStateChannel.valueAt() examples:\n');
fprintf('  machine state at t=10: %d (idle)\n', scMachine.valueAt(10));
fprintf('  machine state at t=35: %d (running)\n', scMachine.valueAt(35));
fprintf('  zone at t=50: %s\n', scZone.valueAt(50));

% --- Query active thresholds at specific time points ---
fprintf('\n=== Active thresholds at specific times ===\n');
queryTimes = [10, 35, 50, 65, 95];
for i = 1:numel(queryTimes)
    tq = queryTimes(i);
    active = s.getThresholdsAt(tq);
    fprintf('  t = %3.0f s:', tq);
    if isempty(active)
        fprintf('  (none)\n');
    else
        for j = 1:numel(active)
            fprintf('  [%s] %.0f (%s)', active(j).Label, active(j).Value, active(j).Direction);
        end
        fprintf('\n');
    end
end

% --- Plot with FastSense ---
fp = FastSense();
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title('Gas Flow — Multi-State Dynamic Thresholds');
xlabel('Time [s]');
ylabel('Flow [sccm]');
