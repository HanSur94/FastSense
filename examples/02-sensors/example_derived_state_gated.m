function example_derived_state_gated()
%EXAMPLE_DERIVED_STATE_GATED DerivedTag combining a SensorTag + a StateTag.
%   Demonstrates:
%     - DerivedTag with mixed-kind parents (SensorTag + StateTag)
%     - Computing a gated signal: keep raw samples ONLY while the state
%       channel is in a chosen value, NaN otherwise
%     - StateTag.valueAt(t) ZOH alignment inside the compute function
%     - Cascade invalidation when EITHER parent updates
%
%   Use case: an analyst only cares about chamber temperature while the
%   machine is actively measuring (state == 1). Idle and cooling samples
%   are masked to NaN so plots and stats reflect only the production window.
%
%   Wrapped as a function (rather than a script) so the local helper
%   gateOnState is portable to both MATLAB and Octave.

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    run(fullfile(projectRoot, 'install.m'));

    % --- 1. Parents: a continuous SensorTag + a discrete StateTag ---
    t = linspace(0, 120, 600);
    tempY = 22 + 8 * sin(2*pi*t/40) + 0.4 * randn(1, numel(t));
    chamberTemp = SensorTag('chamber_temp', 'Name', 'Chamber Temperature', ...
        'Units', 'C', 'X', t, 'Y', tempY);

    % Machine state: 0=idle, 1=measuring, 2=cooling.
    % State changes at t = [0 25 75 100]; default ZOH carries forward.
    machineState = StateTag('machine_state', ...
        'X', [0 25 75 100], ...
        'Y', [0  1  2   0]);

    % --- 2. DerivedTag: keep temperature only while state == 1, else NaN ---
    % The compute function uses StateTag.valueAt() to align discrete state
    % samples onto the temperature grid (right-biased ZOH).
    gatedTemp = DerivedTag('temp_during_measuring', ...
        {chamberTemp, machineState}, ...
        @(p) gateOnState(p{1}, p{2}, 1), ...
        'Name', 'Temperature (Measuring State Only)', 'Units', 'C');

    % --- 3. getXY + non-NaN ratio ---
    [~, y] = gatedTemp.getXY();
    nValid = sum(~isnan(y));
    fprintf('Gated samples: %d valid / %d total (%.1f%% measuring time)\n', ...
        nValid, numel(y), 100 * nValid / numel(y));
    fprintf('Mean temperature during measuring: %.2f C\n', ...
        mean(y(~isnan(y))));

    % --- 4. Cascade through both parent kinds ---
    % Update the StateTag — gating boundaries shift; gatedTemp recomputes
    % automatically because it listens on both parents.
    machineState.updateData([0 10 100 110], [0 1 2 0]);   % wider measuring window
    [~, y2] = gatedTemp.getXY();
    nValid2 = sum(~isnan(y2));
    fprintf('After widening measuring window: %d valid samples (was %d)\n', ...
        nValid2, nValid);

    % Update the SensorTag — values change but the gate is unchanged.
    chamberTemp.updateData(t, tempY + 5);
    [~, y3] = gatedTemp.getXY();
    fprintf('After raising temperature by +5C: gated mean = %.2f C\n', ...
        mean(y3(~isnan(y3))));
    fprintf('Recomputes so far: %d (one per parent updateData)\n', ...
        gatedTemp.recomputeCount_);

    % --- 5. Plot ---
    fp = FastSense();
    fp.addTag(gatedTemp);
    fp.render();
    title(gatedTemp.Name);
    xlabel('Time [s]');
    ylabel(gatedTemp.Units);
end

function [X, Y] = gateOnState(sensorTag, stateTag, gateValue)
    %GATEONSTATE Keep sensorTag.Y where stateTag.valueAt(X) == gateValue.
    %   Returns (X, Y) on the sensor's native grid; out-of-gate samples
    %   are set to NaN so the FastSense renderer breaks the line at gaps.
    X = sensorTag.X;
    Y = sensorTag.Y;
    s = stateTag.valueAt(X);
    Y(s ~= gateValue) = NaN;
end
