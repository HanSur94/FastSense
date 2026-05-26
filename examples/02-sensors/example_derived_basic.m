%% DerivedTag — Basic two-input derivation (differential pressure)
% Demonstrates:
%   - DerivedTag(key, parents, computeFn) constructor
%   - Function-handle compute that returns [X, Y]
%   - Auto-invalidation: parent.updateData(...) makes the next getXY()
%     transparently recompute — no manual cache management needed
%   - valueAt(t) ZOH lookup at any timestamp
%   - Integration with FastSense via addTag()
%
% Use case: compute pump differential pressure (outlet - inlet) as a
% first-class Tag that downstream consumers (thresholds, dashboards,
% MonitorTags) can treat exactly like a raw sensor.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Build two parent SensorTags on a shared time grid
t = linspace(0, 60, 6000);
inletY  = 1.5 + 0.10 * sin(2*pi*t/12) + 0.02 * randn(1, numel(t));   % bar
outletY = 4.0 + 0.40 * sin(2*pi*t/12) + 0.05 * randn(1, numel(t));   % bar

inlet  = SensorTag('pump_inlet',  'Name', 'Pump Inlet Pressure', ...
    'Units', 'bar', 'X', t, 'Y', inletY);
outlet = SensorTag('pump_outlet', 'Name', 'Pump Outlet Pressure', ...
    'Units', 'bar', 'X', t, 'Y', outletY);

%% 2. Build a DerivedTag that computes outlet - inlet
% The compute function receives the parents cell array and returns the
% derived [X, Y] pair. Here the two parents share a grid, so we just
% return the parent's X and the element-wise subtraction.
dp = DerivedTag('differential_pressure', {outlet, inlet}, ...
    @(p) deal(p{1}.X, p{1}.Y - p{2}.Y), ...
    'Name', 'Pump Differential Pressure', 'Units', 'bar');

%% 3. Lazy-evaluate: getXY() triggers the compute on first call, caches it
[xDp, yDp] = dp.getXY();
fprintf('Differential pressure: %d samples, mean = %.3f bar, max = %.3f bar\n', ...
    numel(yDp), mean(yDp), max(yDp));
fprintf('Recomputes so far: %d (computed lazily on first getXY)\n', ...
    dp.recomputeCount_);

%% 4. valueAt — sample the derived signal at any timestamp
fprintf('valueAt(30s) = %.3f bar\n', dp.valueAt(30));
fprintf('valueAt([10 20 30 40]) = '); disp(dp.valueAt([10 20 30 40]));

%% 5. Auto-invalidation — update a parent and the next getXY() recomputes
% The DerivedTag registered itself as a listener on each parent, so any
% updateData() on a parent automatically invalidates the cache.
outlet.updateData(t, outletY + 0.5);   % outlet rises by 0.5 bar
[~, yDp2] = dp.getXY();
fprintf('After outlet.updateData: mean diff = %.3f bar (was %.3f)\n', ...
    mean(yDp2), mean(yDp));
fprintf('Recomputes so far: %d (parent-driven invalidation)\n', ...
    dp.recomputeCount_);

%% 6. Plot with FastSense
% DerivedTag is a first-class Tag, so addTag() routes it through the
% same continuous-line path as a SensorTag.
fp = FastSense();
fp.addTag(dp);
fp.render();
title(dp.Name);
xlabel('Time [s]');
ylabel(dp.Units);
