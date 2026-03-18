%% Dynamic Thresholds at Scale — 10 Sensors x 100M Timestamps
% Demonstrates condition-based (dynamic) threshold resolution on 10
% sensors, each with 100 million data points. Thresholds change based
% on two state channels: a numeric machine-mode channel and a
% string-valued recipe-phase channel. Each sensor has 6 threshold
% rules that activate only under specific state combinations.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

%% Configuration
nSensors   = 10;
nPoints    = 100e6;                       % 100M timestamps per sensor
tSpan      = [0 10000];                   % time range [s]

% Shared time vector (all sensors share the same timestamps)
fprintf('Generating shared time vector (%dM points)...\n', nPoints/1e6);
tic;
x = linspace(tSpan(1), tSpan(2), nPoints);
fprintf('  Done in %.1f s\n', toc);

%% State Channels — shared across all sensors
% Machine mode: cycles through idle(0) -> ramp(1) -> process(2) -> cool(3)
% with transitions every ~2500 s
scMachine = StateChannel('machine');
scMachine.X = [0, 2500, 5000, 7500];
scMachine.Y = [0, 1, 2, 3];  % 0=idle, 1=ramp, 2=process, 3=cool-down

% Recipe phase: string-valued, changes mid-run
scRecipe = StateChannel('recipe');
scRecipe.X = [0, 3000, 6000, 8500];
scRecipe.Y = {'setup', 'deposition', 'etch', 'purge'};

%% Sensor definitions — 10 industrial process sensors
sensorDefs = {
%   key              name                        base  amp   noise  unit
    'temperature'    'Chamber Temperature'       400   80    15     'degC'
    'pressure'       'Chamber Pressure'          50    20    5      'mbar'
    'flow_n2'        'N2 Flow Rate'              200   60    10     'sccm'
    'flow_o2'        'O2 Flow Rate'              100   40    8      'sccm'
    'rf_power'       'RF Power'                  500   150   25     'W'
    'dc_bias'        'DC Bias Voltage'          -300   100   20     'V'
    'rotation'       'Substrate Rotation'         30    5     2      'rpm'
    'thickness'      'Film Thickness'            100   50    5      'nm/min'
    'reflectance'    'Optical Reflectance'        0.5   0.2   0.05  'a.u.'
    'humidity'       'Exhaust Humidity'            5    3     1      'ppm'
};

%% Threshold definitions per sensor
%  Each sensor gets 6 dynamic rules:
%    - Upper alarm (HH) during process
%    - Lower alarm (LL) during process
%    - Upper warning (H) during ramp
%    - Lower warning (L) during cool-down
%    - Strict upper during process+deposition (combined condition)
%    - Strict lower during process+etch (combined condition)
thresholdScale = [
%   HH_proc  LL_proc  H_ramp  L_cool  HH_dep  LL_etch
    0.70     0.30     0.55    0.40    0.60    0.35     % temperature
    0.75     0.25     0.60    0.35    0.65    0.30     % pressure
    0.70     0.30     0.55    0.40    0.60    0.35     % flow_n2
    0.70     0.30     0.55    0.40    0.60    0.35     % flow_o2
    0.70     0.30     0.55    0.40    0.60    0.35     % rf_power
    0.70     0.30     0.55    0.40    0.60    0.35     % dc_bias
    0.75     0.25     0.60    0.35    0.65    0.30     % rotation
    0.70     0.30     0.55    0.40    0.60    0.35     % thickness
    0.70     0.30     0.55    0.40    0.60    0.35     % reflectance
    0.75     0.25     0.60    0.35    0.65    0.30     % humidity
];

%% Create and resolve sensors
sensors = cell(1, nSensors);
totalResolveTime = 0;
totalViolations  = 0;

for si = 1:nSensors
    key  = sensorDefs{si, 1};
    name = sensorDefs{si, 2};
    base = sensorDefs{si, 3};
    amp  = sensorDefs{si, 4};
    nse  = sensorDefs{si, 5};
    unit = sensorDefs{si, 6};

    fprintf('\n[%2d/%d] Sensor: %s\n', si, nSensors, name);

    % --- Generate sensor data ---
    fprintf('  Generating %dM points...', nPoints/1e6);
    tic;
    freq = 0.5 + 0.3 * si;  % unique frequency per sensor
    y = base + amp * sin(2*pi*x / (tSpan(2)/freq)) + nse * randn(1, nPoints);
    fprintf(' %.1f s\n', toc);

    % --- Build sensor ---
    s = Sensor(key, 'Name', name, 'ID', si);
    s.X = x;
    s.Y = y;
    s.addStateChannel(scMachine);
    s.addStateChannel(scRecipe);

    % --- Compute threshold values from data range ---
    yMin = base - amp;
    yMax = base + amp;
    yRange = yMax - yMin;
    sc = thresholdScale(si, :);

    % Rule 1: Upper alarm during process (machine==2)
    s.addThresholdRule(struct('machine', 2), yMin + sc(1)*yRange, ...
        'Direction', 'upper', 'Label', sprintf('HH process (%s)', unit), ...
        'Color', [0.9 0.1 0.1], 'LineStyle', '-');

    % Rule 2: Lower alarm during process (machine==2)
    s.addThresholdRule(struct('machine', 2), yMin + sc(2)*yRange, ...
        'Direction', 'lower', 'Label', sprintf('LL process (%s)', unit), ...
        'Color', [0.1 0.1 0.9], 'LineStyle', '-');

    % Rule 3: Upper warning during ramp (machine==1)
    s.addThresholdRule(struct('machine', 1), yMin + sc(3)*yRange, ...
        'Direction', 'upper', 'Label', sprintf('H ramp (%s)', unit), ...
        'Color', [0.9 0.6 0.1], 'LineStyle', '--');

    % Rule 4: Lower warning during cool-down (machine==3)
    s.addThresholdRule(struct('machine', 3), yMin + sc(4)*yRange, ...
        'Direction', 'lower', 'Label', sprintf('L cool (%s)', unit), ...
        'Color', [0.1 0.6 0.9], 'LineStyle', '--');

    % Rule 5: Strict upper during process+deposition (combined condition)
    s.addThresholdRule(struct('machine', 2, 'recipe', 'deposition'), ...
        yMin + sc(5)*yRange, ...
        'Direction', 'upper', 'Label', sprintf('HH dep (%s)', unit), ...
        'Color', [0.8 0.0 0.6], 'LineStyle', ':');

    % Rule 6: Strict lower during process+etch (combined condition)
    s.addThresholdRule(struct('machine', 2, 'recipe', 'etch'), ...
        yMin + sc(6)*yRange, ...
        'Direction', 'lower', 'Label', sprintf('LL etch (%s)', unit), ...
        'Color', [0.0 0.6 0.8], 'LineStyle', ':');

    % --- Resolve ---
    fprintf('  Resolving 6 dynamic thresholds over %dM points...', nPoints/1e6);
    tic;
    s.resolve();
    elapsed = toc;
    totalResolveTime = totalResolveTime + elapsed;
    fprintf(' %.3f s\n', elapsed);

    % Count violations
    nViol = 0;
    for v = 1:numel(s.ResolvedViolations)
        nViol = nViol + numel(s.ResolvedViolations(v).X);
    end
    totalViolations = totalViolations + nViol;
    fprintf('  Thresholds: %d | Violations: %d\n', ...
        numel(s.ResolvedThresholds), nViol);

    sensors{si} = s;

    % Free Y to reduce memory pressure before next sensor
    clear y;
end

%% Summary
fprintf('\n========================================\n');
fprintf('  Sensors:          %d\n', nSensors);
fprintf('  Points/sensor:    %dM\n', nPoints/1e6);
fprintf('  Total points:     %dM\n', nSensors * nPoints/1e6);
fprintf('  Rules/sensor:     6 (dynamic, condition-based)\n');
fprintf('  State channels:   2 (machine + recipe)\n');
fprintf('  Total violations: %d\n', totalViolations);
fprintf('  Total resolve:    %.2f s  (%.3f s/sensor avg)\n', ...
    totalResolveTime, totalResolveTime / nSensors);
fprintf('  Throughput:       %.0f Mpts/s\n', ...
    nSensors * nPoints / 1e6 / totalResolveTime);
fprintf('========================================\n');

%% Plot first sensor as demo
fprintf('\nPlotting first sensor with FastSense...\n');
fp = FastSense();
fp.addSensor(sensors{1}, 'ShowThresholds', true);
fp.render();
title(fp.hAxes, sprintf('%s — 100M pts, 6 Dynamic Thresholds', ...
    sensors{1}.Name));
xlabel(fp.hAxes, 'Time [s]');
ylabel(fp.hAxes, sprintf('%s [%s]', sensors{1}.Name, sensorDefs{1,6}));
