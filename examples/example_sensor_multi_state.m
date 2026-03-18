%% Multi-State Sensor — Advanced Threshold Features
% Demonstrates:
%   - Two state channels (machine state + zone)
%   - String-valued state channel
%   - Combined conditions across multiple states
%   - Both upper and lower thresholds
%   - getThresholdsAt() for querying active thresholds at a time point

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

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
s.addThresholdRule(struct('machine', 0), 80, ...
    'Direction', 'upper', 'Label', 'HH (idle)', ...
    'Color', [0.9 0.4 0.1], 'LineStyle', '--');

% Running: tighter upper limit
s.addThresholdRule(struct('machine', 1), 68, ...
    'Direction', 'upper', 'Label', 'HH (running)', ...
    'Color', [0.9 0.1 0.1], 'LineStyle', '--');

% Evacuated: strictest upper limit
s.addThresholdRule(struct('machine', 2), 55, ...
    'Direction', 'upper', 'Label', 'HH (evacuated)', ...
    'Color', [1 0 0], 'LineStyle', '-');

% --- Lower threshold only when evacuated ---
s.addThresholdRule(struct('machine', 2), 30, ...
    'Direction', 'lower', 'Label', 'LL (evacuated)', ...
    'Color', [0.1 0.1 0.9], 'LineStyle', '-');

% --- Combined condition: running AND zone B → extra-strict upper ---
s.addThresholdRule(struct('machine', 1, 'zone', 'B'), 60, ...
    'Direction', 'upper', 'Label', 'HH (running+zoneB)', ...
    'Color', [0.8 0 0.8], 'LineStyle', ':');

% --- Resolve all thresholds and violations ---
s.resolve();

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
