function runOpenAdHocPlotTests()
%RUNOPENADHOCPLOTTESTS Test runner for openAdHocPlot helper (sibling-folder pattern).
%   Lives inside libs/FastSenseCompanion/private/ so MATLAB's private-folder
%   visibility makes openAdHocPlot reachable. Called by
%   tests/test_companion_open_ad_hoc_plot.m.
%
%   MATLAB-only — openAdHocPlot calls FastSense which uses MEX kernels and
%   produces a real classical figure() window. Tests close every spawned
%   figure in cleanup so the suite leaves no orphan windows.
%
%   Coverage:
%     T1 — invalid mode 'Foo' throws FastSenseCompanion:invalidPlotMode
%     T2 — too-few-tags (1 tag) throws FastSenseCompanion:invalidPlotMode
%     T3 — Overlay happy: 2 tags spawn 1 classical figure; skipped is empty
%     T4 — LinkedGrid happy: 4 tags spawn 1 classical figure
%     T5 — Partial-skip: 1 throwing + 2 good => figure spawns; skipped has 1 entry
%     T6 — All-fail: every tag throws => FastSenseCompanion:plotSpawnFailed
%     T7 — Empty-data tag => skipped marked 'no data'; figure from valid tags
%
%   See also openAdHocPlot, MockPlottableTag, runFilterDashboardsTests.

    nPassed = 0;
    spawned = matlab.ui.Figure.empty;
    cleanupAll = onCleanup(@() closeFigs_(spawned)); %#ok<NASGU>

    mk = @(key, name, behavior) makeMock_(key, name, behavior);

    % T1 — invalid mode
    try
        openAdHocPlot({mk('a', 'A', 'Default'), mk('b', 'B', 'Default')}, ...
                      'Foo', 'dark');
        error('T1: invalid mode must throw');
    catch ME
        assert(strcmp(ME.identifier, 'FastSenseCompanion:invalidPlotMode'), ...
            sprintf('T1: expected FastSenseCompanion:invalidPlotMode, got %s', ...
                    ME.identifier));
        nPassed = nPassed + 1;
    end

    % T2 — too-few-tags
    try
        openAdHocPlot({mk('a', 'A', 'Default')}, 'Overlay', 'dark');
        error('T2: <2 tags must throw');
    catch ME
        assert(strcmp(ME.identifier, 'FastSenseCompanion:invalidPlotMode'), ...
            sprintf('T2: expected FastSenseCompanion:invalidPlotMode, got %s', ...
                    ME.identifier));
        nPassed = nPassed + 1;
    end

    % T3 — Overlay happy path
    tags = {mk('a3', 'A3', 'Default'), mk('b3', 'B3', 'Default')};
    [hFig, skipped] = openAdHocPlot(tags, 'Overlay', 'dark');
    spawned(end+1) = hFig;
    assert(ishandle(hFig) && strcmp(get(hFig, 'Type'), 'figure'), ...
        'T3: Overlay must return a classical figure handle');
    assert(isempty(skipped), 'T3: Overlay happy path must have empty skipped list');
    assert(strcmp(get(hFig, 'Visible'), 'on'), ...
        'T3: spawned figure must be Visible=on');
    nPassed = nPassed + 1;

    % T4 — LinkedGrid happy path (4 tags -> 2x2 grid)
    tags = {mk('g1', 'G1', 'Default'), mk('g2', 'G2', 'Default'), ...
            mk('g3', 'G3', 'Default'), mk('g4', 'G4', 'Default')};
    [hFig, skipped] = openAdHocPlot(tags, 'LinkedGrid', 'dark');
    spawned(end+1) = hFig;
    assert(ishandle(hFig) && strcmp(get(hFig, 'Type'), 'figure'), ...
        'T4: LinkedGrid must return a classical figure handle');
    assert(isempty(skipped), 'T4: LinkedGrid happy path must have empty skipped');
    nPassed = nPassed + 1;

    % T5 — Partial-skip (1 throwing + 2 good)
    tags = {mk('p1', 'Bad', 'Throw'), ...
            mk('p2', 'Good 1', 'Default'), ...
            mk('p3', 'Good 2', 'Default')};
    [hFig, skipped] = openAdHocPlot(tags, 'Overlay', 'dark');
    spawned(end+1) = hFig;
    assert(ishandle(hFig), 'T5: figure must spawn even with one bad tag');
    assert(numel(skipped) == 1, ...
        sprintf('T5: expected 1 skipped, got %d', numel(skipped)));
    assert(~isempty(strfind(skipped{1}, 'Bad')), ...
        'T5: skipped entry must include the bad tag Name');
    nPassed = nPassed + 1;

    % T6 — All-fail
    tags = {mk('f1', 'F1', 'Throw'), mk('f2', 'F2', 'Throw')};
    try
        openAdHocPlot(tags, 'Overlay', 'dark');
        error('T6: all-fail must throw');
    catch ME
        assert(strcmp(ME.identifier, 'FastSenseCompanion:plotSpawnFailed'), ...
            sprintf('T6: expected FastSenseCompanion:plotSpawnFailed, got %s', ...
                    ME.identifier));
        nPassed = nPassed + 1;
    end

    % T7 — Empty-data tag is skipped, others spawn
    tags = {mk('e1', 'Empty', 'ReturnEmpty'), ...
            mk('e2', 'Has Data 1', 'Default'), ...
            mk('e3', 'Has Data 2', 'Default')};
    [hFig, skipped] = openAdHocPlot(tags, 'Overlay', 'dark');
    spawned(end+1) = hFig;
    assert(ishandle(hFig), 'T7: figure must spawn from remaining valid tags');
    assert(numel(skipped) == 1, ...
        sprintf('T7: expected 1 skipped, got %d', numel(skipped)));
    assert(~isempty(strfind(skipped{1}, 'no data')), ...
        'T7: empty-data tag must be marked ''no data'' in skipped list');
    nPassed = nPassed + 1;

    fprintf('    All %d tests passed.\n', nPassed);
end

function m = makeMock_(key, name, behavior)
%MAKEMOCK_ Build a MockPlottableTag with X=1:50, Y=sin-ish, then set Behavior.
    m = MockPlottableTag(key, 'Name', name, ...
        'X', 1:50, 'Y', sin((1:50) / 5));
    m.Behavior = behavior;
end

function closeFigs_(figs)
%CLOSEFIGS_ Best-effort close of every spawned figure.
    for i = 1:numel(figs)
        if ishandle(figs(i))
            try
                delete(figs(i));
            catch
                % swallow — cleanup is best-effort
            end
        end
    end
end
