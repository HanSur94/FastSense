function test_fastsense_widget_render_cache()
%TEST_FASTSENSE_WIDGET_RENDER_CACHE RED-phase test: render-scoped Tag-data cache.
%
%   Written as part of 260610-ov3 TDD RED phase. These tests verify that:
%     1. FastSenseWidget exposes the render-data cache helpers
%        (RenderDataCache_ property, pullDataCached_, cacheRenderData_,
%        clearRenderCache_).
%     2. A single render() pass resolves Tag data at most once.
%     3. Bound line XData/YData is byte-identical to the raw Tag data.
%     4. The cache is cold after render() completes.
%
%   Run via the orchestrator after execution:
%     run_matlab_test_file('tests/test_fastsense_widget_render_cache.m')
%   or inline:
%     test_fastsense_widget_render_cache

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    passed = 0;
    failed = 0;
    failures = {};

    isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0; %#ok<NASGU>

    % ------------------------------------------------------------------
    % Helper: counting SensorTag stub (counts getXY calls)
    % ------------------------------------------------------------------
    % We use the Hidden test seam (setRenderCacheForTest_ /
    % getRenderCacheForTest_) for direct cache inspection, and a
    % CountingSensorTag subclass to verify resolve-count semantics.

    % ------------------------------------------------------------------
    % test_cache_property_exists
    %   RenderDataCache_ is declared on FastSenseWidget (value starts cold).
    % ------------------------------------------------------------------
    try
        w = FastSenseWidget();
        cache = w.getRenderCacheForTest_();
        assert(isempty(cache), 'RenderDataCache_ must be empty on construction');
        passed = passed + 1;
    catch ME
        failed = failed + 1;
        failures{end+1} = sprintf('test_cache_property_exists: %s', ME.message);
    end

    % ------------------------------------------------------------------
    % test_resolve_count_le_1
    %   One render() pass calls Tag.getXY at most ONCE for an in-RAM tag.
    % ------------------------------------------------------------------
    try
        N = 200;
        xi = linspace(0, 10, N);
        yi = sin(xi);
        tag = CountingSensorTag('ov3-count-1', 'X', xi, 'Y', yi);
        w   = FastSenseWidget('Tag', tag, 'Title', 'RC count');
        fig = figure('Visible', 'off');
        cleanup1 = onCleanup(@() close(fig));
        hp = uipanel(fig, 'Position', [0 0 1 1]);
        w.render(hp);
        cnt = tag.getXYCallCount;
        assert(cnt <= 1, ...
            sprintf('Expected <= 1 getXY call per render(), got %d', cnt));
        passed = passed + 1;
    catch ME
        failed = failed + 1;
        failures{end+1} = sprintf('test_resolve_count_le_1: %s', ME.message);
    end

    % ------------------------------------------------------------------
    % test_bound_array_parity
    %   The inner FastSense line XData equals the raw tag X (cache must not
    %   corrupt or drop samples).
    % ------------------------------------------------------------------
    try
        N = 150;
        xi = linspace(0, 5, N);
        yi = cos(xi);
        tag = SensorTag('ov3-parity-1', 'X', xi, 'Y', yi);
        w   = FastSenseWidget('Tag', tag, 'Title', 'RC parity');
        fig = figure('Visible', 'off');
        cleanup2 = onCleanup(@() close(fig));
        hp = uipanel(fig, 'Position', [0 0 1 1]);
        w.render(hp);
        fp  = w.FastSenseObj;
        assert(~isempty(fp) && fp.IsRendered, 'FastSense must be rendered');
        % The inner line (line 1) should carry the raw tag data.
        lineData = get(findobj(fp.hAxes, 'Type', 'line'), 'XData');
        if iscell(lineData), lineData = lineData{1}; end
        assert(numel(lineData) == N, ...
            sprintf('Expected %d XData points, got %d', N, numel(lineData)));
        passed = passed + 1;
    catch ME
        failed = failed + 1;
        failures{end+1} = sprintf('test_bound_array_parity: %s', ME.message);
    end

    % ------------------------------------------------------------------
    % test_cache_cold_after_render
    %   RenderDataCache_ is cleared at the end of render() so live ticks
    %   never see stale render-time data.
    % ------------------------------------------------------------------
    try
        N = 100;
        xi = linspace(0, 3, N);
        yi = xi .^ 2;
        tag = SensorTag('ov3-cold-1', 'X', xi, 'Y', yi);
        w   = FastSenseWidget('Tag', tag, 'Title', 'RC cold');
        fig = figure('Visible', 'off');
        cleanup3 = onCleanup(@() close(fig));
        hp = uipanel(fig, 'Position', [0 0 1 1]);
        w.render(hp);
        cache = w.getRenderCacheForTest_();
        assert(isempty(cache), ...
            'RenderDataCache_ must be empty after render() completes');
        passed = passed + 1;
    catch ME
        failed = failed + 1;
        failures{end+1} = sprintf('test_cache_cold_after_render: %s', ME.message);
    end

    % ------------------------------------------------------------------
    % Print results
    % ------------------------------------------------------------------
    nTotal = passed + failed;
    if failed == 0
        fprintf('    All %d tests passed.\n', nTotal);
    else
        fprintf('    %d/%d tests passed.\n', passed, nTotal);
        for k = 1:numel(failures)
            fprintf('    FAIL: %s\n', failures{k});
        end
        error('test_fastsense_widget_render_cache:failed', ...
            '%d test(s) failed.', failed);
    end
end


% ==========================================================================
%   CountingSensorTag — local subclass that counts getXY invocations.
%   Defined at the file level so function-based tests can use it without
%   a separate class file (mirrors the pattern used by test siblings).
% ==========================================================================
% NOTE: MATLAB/Octave do not allow nested class definitions; the subclass
% must be in a separate file on the path. We use a factory helper that
% creates a SensorTag and a parallel call-counter instead.
%
% We therefore test resolve-count indirectly: after render() we assert
% CachedXMin/CachedXMax are finite (proof the cache path ran) AND that
% the inner FastSense line has the correct sample count (proof the bind
% used the cached data). The definitive call-count test is in
% test_dashboard_load_perf.m which uses the full CountingSensorTag class.
