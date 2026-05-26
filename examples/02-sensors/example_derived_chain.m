function example_derived_chain()
%EXAMPLE_DERIVED_CHAIN DerivedTag in a downstream chain - first-class Tag.
%   Demonstrates that a DerivedTag can be a parent for a MonitorTag and
%   that updates to root SensorTags cascade automatically through the
%   full chain:
%
%       SensorTag(flow_in)  --+
%                             +--> DerivedTag(flow_imbalance)
%       SensorTag(flow_out) --+              |
%                                            v
%                             MonitorTag(imbalance_alarm) --+
%                                                           +--> CompositeTag('or')
%       SensorTag(temp) ----> MonitorTag(temp_alarm)       --+
%
%   When `flow_in.updateData(...)` is called, ALL downstream tags
%   invalidate their caches via the listener wiring set up in each
%   constructor - no manual recompute needed.
%
%   Use case: a process monitor where one composite alarm aggregates a
%   "physics-derived" anomaly (flow imbalance) with a raw threshold
%   (temperature), and the user only ever queries the top-level composite.

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    run(fullfile(projectRoot, 'install.m'));

    TagRegistry.clear();   % clean slate so example is reproducible

    % --- 1. SensorTag leaves --------------------------------------------
    t = linspace(0, 100, 5000);
    flowInY  = 50 + 2*sin(2*pi*t/30) + 0.5*randn(1, numel(t));   % L/min
    flowOutY = 50 + 2*sin(2*pi*t/30) + 0.5*randn(1, numel(t));   % L/min
    flowOutY(2000:2400) = flowOutY(2000:2400) - 8;               % leak event
    tempY    = 70 + 3*sin(2*pi*t/45) + 0.5*randn(1, numel(t));   % degC
    tempY(3500:4000) = tempY(3500:4000) + 12;                    % hot spike

    flowIn  = SensorTag('flow_in',  'Name', 'Inflow',  'Units', 'L/min', ...
        'X', t, 'Y', flowInY);
    flowOut = SensorTag('flow_out', 'Name', 'Outflow', 'Units', 'L/min', ...
        'X', t, 'Y', flowOutY);
    temp    = SensorTag('temp',     'Name', 'Temp',    'Units', 'C', ...
        'X', t, 'Y', tempY);

    % --- 2. DerivedTag: flow imbalance = |flow_in - flow_out| ----------
    flowImbalance = DerivedTag('flow_imbalance', {flowIn, flowOut}, ...
        @(p) deal(p{1}.X, abs(p{1}.Y - p{2}.Y)), ...
        'Name', 'Flow Imbalance', 'Units', 'L/min');

    % --- 3. MonitorTag over the DerivedTag (DerivedTag IS a valid parent)
    imbalanceAlarm = MonitorTag('imbalance_alarm', flowImbalance, ...
        @(x, y) y > 5, ...
        'Name', 'Flow Imbalance Alarm');

    % --- 4. MonitorTag over the raw temperature SensorTag ---------------
    tempAlarm = MonitorTag('temp_alarm', temp, ...
        @(x, y) y > 80, ...
        'Name', 'Temperature Alarm');

    % --- 5. CompositeTag aggregating both alarms with OR ---------------
    composite = CompositeTag('process_alarm', 'or', ...
        'Name', 'Process Alarm (any)');
    composite.addChild(imbalanceAlarm);
    composite.addChild(tempAlarm);

    % --- 6. Pull the composite once - recomputeCounts cascade upward ---
    [~, yComp] = composite.getXY();
    fprintf('Composite alarm series: %d samples, fraction in alarm = %.1f%%\n', ...
        numel(yComp), 100 * mean(yComp == 1));
    fprintf('  flow_imbalance recomputes: %d\n', flowImbalance.recomputeCount_);
    fprintf('  imbalance_alarm recomputes: %d\n', imbalanceAlarm.recomputeCount_);
    fprintf('  temp_alarm recomputes: %d\n', tempAlarm.recomputeCount_);

    % --- 7. Trigger a cascade: update a ROOT SensorTag ------------------
    % This invalidates flowImbalance -> imbalanceAlarm -> composite in one
    % chain via the listener wiring set up in each constructor. Here we
    % "fix the leak" by writing a balanced flow_out series so |in - out|
    % stays under the alarm threshold.
    fixedFlowOut = flowInY + 0.3 * randn(1, numel(t));   % balanced + tiny jitter
    flowOut.updateData(t, fixedFlowOut);
    [~, yComp2] = composite.getXY();
    fprintf('After fixing the leak: alarm fraction drops to %.1f%%\n', ...
        100 * mean(yComp2 == 1));
    fprintf('  flow_imbalance recomputes: %d (parent-driven)\n', ...
        flowImbalance.recomputeCount_);
    fprintf('  imbalance_alarm recomputes: %d (parent-driven)\n', ...
        imbalanceAlarm.recomputeCount_);

    % --- 8. Plot the composite signal ----------------------------------
    fp = FastSense();
    fp.addTag(composite);
    fp.render();
    title(composite.Name);
    xlabel('Time [s]');
    ylabel('Alarm (0/1)');

    TagRegistry.clear();
end
