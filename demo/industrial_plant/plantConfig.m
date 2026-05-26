function cfg = plantConfig()
%PLANTCONFIG Static taxonomy for the industrial plant demo.
%   cfg = plantConfig() returns a scalar struct with the full tag taxonomy
%   for the demo: sensor keys + units/ranges, state keys + label sets,
%   monitor rule definitions (parent/conditionFn/debounce/criticality),
%   and the rollup CompositeTag key.
%
%   This is the single source of truth for every downstream demo helper
%   (registerPlantTags, makeDataGenerator, run_demo). Plan 02 of the same
%   phase consumes these keys to wire widgets on the dashboard.
%
%   Fields:
%     SensorKeys   - cellstr, 8 continuous sensor keys
%     StateKeys    - cellstr, 2 discrete state keys
%     Subsystems   - cellstr, 3 sub-systems (FeedLine/Reactor/Cooling)
%     Units        - struct: key -> units char
%     Ranges       - struct: key -> [min max] double
%     Baselines    - struct: key -> struct('mean', .., 'amp', .., 'period', ..,
%                                           'noise', .., 'phase', ..) for the
%                           synthetic generator's sine+noise model
%     Labels       - struct: stateKey -> 1xN cellstr of state labels
%     StateSchedule - struct: stateKey -> 1xN struct('t', double, 'idx', double)
%                            deterministic state transitions used by the
%                            generator
%     MonitorDefs  - struct array: key/parentKey/conditionFn/alarmOffFn/
%                                   MinDuration/Criticality/Subsystem
%     CompositeKey - char, top-level rollup key ('plant.health')
%
%   See also: registerPlantTags, makeDataGenerator, run_demo.

    cfg = struct();

    cfg.Subsystems   = {'FeedLine', 'Reactor', 'Cooling'};
    cfg.CompositeKey = 'plant.health';

    cfg.SensorKeys = { ...
        'feedline.pressure', ...
        'feedline.flow', ...
        'reactor.pressure', ...
        'reactor.temperature', ...
        'reactor.rpm', ...
        'cooling.in_temp', ...
        'cooling.out_temp', ...
        'cooling.flow'};

    cfg.StateKeys = {'feedline.valve_state', 'reactor.mode'};

    % ---- Units ----
    cfg.Units = struct();
    cfg.Units.('feedline_pressure')   = 'bar';
    cfg.Units.('feedline_flow')       = 'L/min';
    cfg.Units.('reactor_pressure')    = 'bar';
    cfg.Units.('reactor_temperature') = 'degC';
    cfg.Units.('reactor_rpm')         = 'rpm';
    cfg.Units.('cooling_in_temp')     = 'degC';
    cfg.Units.('cooling_out_temp')    = 'degC';
    cfg.Units.('cooling_flow')        = 'L/min';

    % ---- Operational ranges ([min max]) ----
    cfg.Ranges = struct();
    cfg.Ranges.('feedline_pressure')   = [0, 10];
    cfg.Ranges.('feedline_flow')       = [0, 200];
    cfg.Ranges.('reactor_pressure')    = [0, 20];
    cfg.Ranges.('reactor_temperature') = [20, 200];
    cfg.Ranges.('reactor_rpm')         = [0, 3000];
    cfg.Ranges.('cooling_in_temp')     = [5, 40];
    cfg.Ranges.('cooling_out_temp')    = [10, 60];
    cfg.Ranges.('cooling_flow')        = [0, 150];

    % ---- Synthetic signal baselines (sine + Gaussian noise) ----
    %   y(t) = mean + amp * sin(2*pi*t/period + phase) + noise*randn
    cfg.Baselines = struct();
    cfg.Baselines.('feedline_pressure')   = mkBaseline_(5.0,   0.4,  30, 0.08, 0.0);
    cfg.Baselines.('feedline_flow')       = mkBaseline_(120,   8.0,  45, 1.50, 0.5);
    cfg.Baselines.('reactor_pressure')    = mkBaseline_(12.0,  0.6,  40, 0.12, 1.0);
    cfg.Baselines.('reactor_temperature') = mkBaseline_(160,   4.0, 120, 0.40, 0.0);
    cfg.Baselines.('reactor_rpm')         = mkBaseline_(1800, 180,   25, 15.0, 0.7);
    cfg.Baselines.('cooling_in_temp')     = mkBaseline_(18,    1.5,  60, 0.15, 0.3);
    cfg.Baselines.('cooling_out_temp')    = mkBaseline_(35,    2.0,  60, 0.20, 0.3);
    cfg.Baselines.('cooling_flow')        = mkBaseline_(80,    5.0,  50, 0.80, 0.9);

    % ---- Discrete state labels ----
    cfg.Labels = struct();
    cfg.Labels.('feedline_valve_state') = {'closed', 'opening', 'open', 'closing'};
    cfg.Labels.('reactor_mode')         = {'idle', 'heating', 'running', 'cooldown', 'fault'};

    % ---- Deterministic state transition schedule (for demo readability) ----
    %   Indexed from 1 (MATLAB-style); converted to 0-based file rows by
    %   makeDataGenerator as needed.
    cfg.StateSchedule = struct();
    cfg.StateSchedule.('feedline_valve_state') = [ ...
        struct('t',   0, 'idx', 1), ...   % closed
        struct('t',   3, 'idx', 2), ...   % opening
        struct('t',   6, 'idx', 3), ...   % open
        struct('t',  50, 'idx', 4), ...   % closing
        struct('t',  53, 'idx', 3)];      % open again
    cfg.StateSchedule.('reactor_mode') = [ ...
        struct('t',   0, 'idx', 1), ...   % idle
        struct('t',   5, 'idx', 2), ...   % heating
        struct('t',  12, 'idx', 3), ...   % running
        struct('t',  60, 'idx', 4), ...   % cooldown
        struct('t',  80, 'idx', 1)];      % idle

    % ---- MonitorTag definitions (parent/conditionFn/hysteresis/debounce) ----
    %   MonitorTag uses 'AlarmOffConditionFn' for hysteresis -- we pass a
    %   ConditionFn (alarm-ON trigger) AND an AlarmOffConditionFn (lower
    %   release threshold) as a pair of function handles.
    cfg.MonitorDefs = mkMonitorDefs_();

    % Demo time-base: the data generator timestamps samples with MATLAB
    % datenum (days since 0000-01-00). MonitorTag.MinDuration is measured
    % in parent-X native units, so seconds → days.
    cfg.TimeBase              = 'datenum';
    cfg.SecondsPerTimeUnit    = 86400;  % days → seconds; inverse factor below
    cfg.MonitorMinDurationFor = @(seconds) seconds / 86400;

    % ---- Display thresholds for FastSense plots -----------------------
    %   Parallel table to MonitorDefs that expresses the trip value in a
    %   form diagram widgets can draw as a horizontal line. Each entry is
    %   a struct with Value / Direction / Label / MonitorKey so tooltips
    %   can credit the MonitorTag that owns the rule.
    cfg.DisplayThresholds = mkDisplayThresholds_();

end

function b = mkBaseline_(meanV, amp, period, noise, phase)
    %MKBASELINE_ Build a baseline struct for the sine+noise signal model.
    b = struct('mean', meanV, 'amp', amp, 'period', period, ...
               'noise', noise, 'phase', phase);
end

function defs = mkMonitorDefs_()
    %MKMONITORDEFS_ Build the MonitorDef struct array.
    %   Each entry carries an AlarmOn trigger (ConditionFn) plus a release
    %   threshold expressed as AlarmOffFn to give hysteresis behaviour.
    % Criticality mapping note: Tag base class accepts the fixed set
    % {low, medium, high, safety}. Plan text uses 'warning'/'critical'
    % semantics; we map warning -> medium and critical -> high so the
    % Tag validator accepts them (Rule 1 auto-fix; surfaces in SUMMARY).
    % AlarmOffConditionFn semantics (per MonitorTag.applyHysteresis_):
    %   "State ON flips to OFF when AlarmOffConditionFn is TRUE."
    % So the release predicate is the INVERSE-direction of the trip predicate:
    %   trip  = y > 18   ->  release = y < 16
    %   trip  = y < 20   ->  release = y > 30
    defs = [ ...
        mkDef_('feedline.pressure.high', 'feedline.pressure', ...
               @(x,y) y > 8, @(x,y) y < 7, 2, 'medium', 'FeedLine'), ...
        mkDef_('reactor.pressure.critical', 'reactor.pressure', ...
               @(x,y) y > 18, @(x,y) y < 16, 1, 'high', 'Reactor'), ...
        mkDef_('reactor.temperature.high', 'reactor.temperature', ...
               @(x,y) y > 180, @(x,y) y < 170, 3, 'medium', 'Reactor'), ...
        mkDef_('cooling.flow.low', 'cooling.flow', ...
               @(x,y) y < 20, @(x,y) y > 30, 2, 'medium', 'Cooling')];
end

function d = mkDef_(key, parentKey, condFn, offFn, minDurSeconds, crit, sub)
    %MKDEF_ Build one MonitorDef entry.
    %   Debounce is authored in SECONDS (`MinDurationSeconds`) so the
    %   config stays human-readable. The demo's parent SensorTags time-
    %   stamp samples with MATLAB datenum (days), so registerPlantTags
    %   converts via cfg.MonitorMinDurationDays(mDef.MinDurationSeconds)
    %   before handing the value to MonitorTag.MinDuration. Any other
    %   consumer that wants to read this directly must be aware of the
    %   unit — the field name carries that contract.
    d = struct( ...
        'Key',                key, ...
        'ParentKey',          parentKey, ...
        'ConditionFn',        condFn, ...
        'AlarmOffFn',         offFn, ...
        'MinDurationSeconds', minDurSeconds, ...
        'Criticality',        crit, ...
        'Subsystem',          sub);
end

function t = mkDisplayThresholds_()
    %MKDISPLAYTHRESHOLDS_ Sensor-key -> cell of threshold specs for diagrams.
    %   Mirrors the trip values in mkMonitorDefs_ but as static numeric
    %   values with explicit Direction / Label so FastSenseWidget can draw
    %   them as horizontal lines.
    t = struct();
    t.feedline_pressure = { ...
        struct('Value', 8, 'Direction', 'upper', ...
               'Label', 'MonitorTag feedline.pressure.high (y > 8 bar)', ...
               'MonitorKey', 'feedline.pressure.high')};
    t.reactor_pressure = { ...
        struct('Value', 18, 'Direction', 'upper', ...
               'Label', 'MonitorTag reactor.pressure.critical (y > 18 bar)', ...
               'MonitorKey', 'reactor.pressure.critical')};
    t.reactor_temperature = { ...
        struct('Value', 180, 'Direction', 'upper', ...
               'Label', 'MonitorTag reactor.temperature.high (y > 180 degC)', ...
               'MonitorKey', 'reactor.temperature.high')};
    t.cooling_flow = { ...
        struct('Value', 20, 'Direction', 'lower', ...
               'Label', 'MonitorTag cooling.flow.low (y < 20 L/min)', ...
               'MonitorKey', 'cooling.flow.low')};
end
