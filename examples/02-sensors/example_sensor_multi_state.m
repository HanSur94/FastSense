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
s = SensorTag('flow', 'Name', 'Gas Flow Rate', 'ID', 301);
t = linspace(0, 120, 60000);
s.updateData(t, 50 + 15*sin(2*pi*t/20) + 3*randn(1, numel(t)));

% Add deliberate excursions
s.Y(8000:8200) = s.Y(8000:8200) + 30;   % spike during running
s.Y(25000:25300) = s.Y(25000:25300) - 25; % dip during evacuated
s.Y(45000:45100) = s.Y(45000:45100) + 20; % spike in zone B

% --- Numeric state channel: machine state ---
scMachine = StateTag('machine', 'X', [0  30  60  90], 'Y', [0   1   2   1];  % 0=idle, 1=running, 2=evacuated);

% --- String-valued state channel: zone ---
scZone = StateTag('zone', 'X', [0, 40, 80], 'Y', {'A', 'B', 'A'};  % zone changes mid-run);


% --- Upper thresholds per machine state ---
% Idle: lenient upper limit

% Running: tighter upper limit

% Evacuated: strictest upper limit

% --- Lower threshold only when evacuated ---

% --- Combined condition: running AND zone B → extra-strict upper ---

% --- Resolve all thresholds and violations ---

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
fp.addTag(s, 'ShowThresholds', true);
fp.render();
title('Gas Flow — Multi-State Dynamic Thresholds');
xlabel('Time [s]');
ylabel('Flow [sccm]');
