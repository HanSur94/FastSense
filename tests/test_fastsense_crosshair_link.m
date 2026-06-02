function test_fastsense_crosshair_link()
%TEST_FASTSENSE_CROSSHAIR_LINK Tests for FastSenseWidget crosshair-link feature (260602-mri).
%
%   Covers:
%     PURE (no graphics, run on MATLAB + Octave):
%       - Default CrosshairLinked == false
%       - setCrosshairLink(true/false) round-trips; 'bad' throws namespaced error
%       - toStruct omits crosshairLinked when false; emits true when set
%       - fromStruct restores true when present; legacy struct -> false
%     RENDER-GUARDED (MATLAB desktop only, skipped on Octave + headless):
%       - onMoveExternal shows crosshair; immediately following onLeave is
%         SUPPRESSED (suppress-leave crux); onLeaveExternal hides (clears)
%       - setBroadcastFcn fires BroadcastFcn_ exactly once from onMove;
%         onMoveExternal does NOT re-invoke it (InBroadcast_ gate)
%     ENGINE + PURE enumeration:
%       - collectLinkedCrosshairs_ returns only linked+rendered widgets
%       - flipping CrosshairLinked changes the count
%       - GroupWidget-nested FastSenseWidget IS included (flatten works)
%     RENDER-GUARDED integration:
%       - 2-widget dashboard: rewireCrosshairLinks_ + onMove on A mirrors B;
%         onLeave on A hides B

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();

    nPassed = 0; nFailed = 0;
    cleanupAll = onCleanup(@() close('all', 'force')); %#ok<NASGU>

    % =========================================================
    %  PURE TESTS (MATLAB + Octave)
    % =========================================================

    % --- test_default_crosshair_linked_is_false ---
    try
        tag = makeTag_();
        w = FastSenseWidget('Tag', tag);
        assert(w.CrosshairLinked == false, ...
            sprintf('default CrosshairLinked must be false, got %d', w.CrosshairLinked));
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_default_crosshair_linked_is_false: %s\n', err.message);
    end

    % --- test_set_crosshair_link_true_and_false ---
    try
        tag = makeTag_();
        w = FastSenseWidget('Tag', tag);
        w.setCrosshairLink(true);
        assert(w.CrosshairLinked == true, 'setCrosshairLink(true) must set CrosshairLinked=true');
        w.setCrosshairLink(false);
        assert(w.CrosshairLinked == false, 'setCrosshairLink(false) must set CrosshairLinked=false');
        % also accept numeric 0/1
        w.setCrosshairLink(1);
        assert(w.CrosshairLinked == true, 'setCrosshairLink(1) must set CrosshairLinked=true');
        w.setCrosshairLink(0);
        assert(w.CrosshairLinked == false, 'setCrosshairLink(0) must set CrosshairLinked=false');
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_set_crosshair_link_true_and_false: %s\n', err.message);
    end

    % --- test_set_crosshair_link_bad_throws ---
    try
        tag = makeTag_();
        w = FastSenseWidget('Tag', tag);
        errId = '';
        try
            w.setCrosshairLink('bad');
        catch e
            errId = e.identifier;
        end
        assert(strcmp(errId, 'FastSenseWidget:invalidCrosshairLink'), ...
            sprintf('expected FastSenseWidget:invalidCrosshairLink, got ''%s''', errId));
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_set_crosshair_link_bad_throws: %s\n', err.message);
    end

    % --- test_to_struct_omits_when_false ---
    try
        tag = makeTag_();
        w = FastSenseWidget('Tag', tag);  % default false
        s = w.toStruct();
        assert(~isfield(s, 'crosshairLinked'), ...
            'toStruct must NOT emit crosshairLinked when false (legacy JSON byte-identical)');
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_to_struct_omits_when_false: %s\n', err.message);
    end

    % --- test_to_struct_emits_true_when_set ---
    try
        tag = makeTag_();
        w = FastSenseWidget('Tag', tag);
        w.setCrosshairLink(true);
        s = w.toStruct();
        assert(isfield(s, 'crosshairLinked'), ...
            'toStruct must emit crosshairLinked when true');
        assert(s.crosshairLinked == true, ...
            sprintf('crosshairLinked in struct must be true, got %d', s.crosshairLinked));
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_to_struct_emits_true_when_set: %s\n', err.message);
    end

    % --- test_from_struct_restores_true ---
    try
        tag = makeTag_();
        w1 = FastSenseWidget('Tag', tag);
        w1.setCrosshairLink(true);
        s = w1.toStruct();
        w2 = FastSenseWidget.fromStruct(s);
        assert(w2.CrosshairLinked == true, ...
            sprintf('fromStruct must restore CrosshairLinked=true, got %d', w2.CrosshairLinked));
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_from_struct_restores_true: %s\n', err.message);
    end

    % --- test_legacy_struct_without_field_defaults_false ---
    try
        s = struct('type', 'fastsense', 'title', 't', ...
                   'position', struct('col', 1, 'row', 1, 'width', 6, 'height', 2));
        w = FastSenseWidget.fromStruct(s);
        assert(w.CrosshairLinked == false, ...
            sprintf('legacy struct without crosshairLinked must default to false, got %d', ...
            w.CrosshairLinked));
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_legacy_struct_without_field_defaults_false: %s\n', err.message);
    end

    % =========================================================
    %  PURE ENGINE ENUMERATION TEST (MATLAB + Octave, no figures)
    % =========================================================

    % --- test_collect_linked_crosshairs_pure_enumeration ---
    % Build a tiny DashboardEngine and a fake widget list to verify
    % collectLinkedCrosshairs_ enumeration without real figures.
    try
        eng = DashboardEngine('TestLink');
        % Build 3 widgets: 2 linked, 1 unlinked. None rendered (headless).
        tag = makeTag_();
        wA = FastSenseWidget('Tag', tag); wA.setCrosshairLink(true);
        wB = FastSenseWidget('Tag', tag); wB.setCrosshairLink(true);
        wC = FastSenseWidget('Tag', tag); % unlinked

        % With no FastSenseObj rendered, collectLinkedCrosshairs_ should
        % return empty (guard: FastSenseObj must be rendered).
        eng.Widgets = {wA, wB, wC};
        linked = eng.collectLinkedCrosshairs_(eng.Widgets);
        assert(isempty(linked), ...
            sprintf('unrendered widgets must yield empty linked set; got %d', numel(linked)));

        % Flip wA unlinked -> size still 0 (not rendered)
        wA.setCrosshairLink(false);
        linked2 = eng.collectLinkedCrosshairs_(eng.Widgets);
        assert(isempty(linked2), ...
            'still empty with all unrendered widgets');
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_collect_linked_crosshairs_pure_enumeration: %s\n', err.message);
    end

    % =========================================================
    %  RENDER-GUARDED TESTS (MATLAB desktop only)
    % =========================================================

    % Skip render-guarded cases on Octave (HoverCrosshair is MATLAB-only)
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    Render-guarded crosshair-link tests: SKIPPED (Octave - HoverCrosshair uses isvalid).\n');
        fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
        if nFailed > 0
            error('test_fastsense_crosshair_link:failures', '%d test(s) failed.', nFailed);
        end
        fprintf('    All %d tests passed.\n', nPassed);
        return;
    end

    if ~canRenderFigures_()
        fprintf('    Render-guarded crosshair-link tests: SKIPPED (no java desktop).\n');
        fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
        if nFailed > 0
            error('test_fastsense_crosshair_link:failures', '%d test(s) failed.', nFailed);
        end
        fprintf('    All %d tests passed.\n', nPassed);
        return;
    end

    % --- test_suppress_leave_crux ---
    % Core mechanism proof: onMoveExternal shows; next onLeave is suppressed;
    % onLeaveExternal hides cleanly.
    try
        [fp, hFig] = makeFp_(1);
        cleanup = onCleanup(@() safeClose_(hFig)); %#ok<NASGU>
        hc = HoverCrosshair(fp);
        t = linspace(0, 10, 500);
        xMid = t(250);

        % Drive crosshair externally (simulates being mirrored by another widget).
        hc.onMoveExternal(xMid);
        assert(strcmp(get(hc.hLineV, 'Visible'), 'on'), ...
            'onMoveExternal must show the crosshair line');

        % An immediately following onLeave (same dispatch, cursor not over us)
        % MUST be suppressed because SuppressLeaveUntil_ was just set.
        hc.onLeave();
        assert(strcmp(get(hc.hLineV, 'Visible'), 'on'), ...
            'onLeave immediately after onMoveExternal must be SUPPRESSED (crux)');

        % onLeaveExternal clears suppress + hides.
        hc.onLeaveExternal();
        assert(strcmp(get(hc.hLineV, 'Visible'), 'off'), ...
            'onLeaveExternal must hide the crosshair');

        delete(hc);
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_suppress_leave_crux: %s\n', err.message);
    end

    % --- test_broadcast_fires_once_no_reentry ---
    % BroadcastFcn_ fires exactly once from onMove; onMoveExternal does NOT
    % re-invoke it (InBroadcast_ gate).
    try
        [fp, hFig] = makeFp_(1);
        cleanup = onCleanup(@() safeClose_(hFig)); %#ok<NASGU>
        hc = HoverCrosshair(fp);
        t = linspace(0, 10, 500);
        xMid = t(250);

        % Install a broadcast counter via setBroadcastFcn.
        counterMap = containers.Map({'count'}, {0});
        moveFn  = @(x) incrementCounter_(counterMap);
        leaveFn = @() [];
        hc.setBroadcastFcn(moveFn, leaveFn);

        % onMove must fire BroadcastFcn_ exactly once.
        hc.onMove(xMid);
        assert(counterMap('count') == 1, ...
            sprintf('onMove must fire BroadcastFcn_ once; fired %d times', counterMap('count')));

        % onMoveExternal must NOT re-invoke BroadcastFcn_ (InBroadcast_ gate).
        hc.onMoveExternal(xMid);
        assert(counterMap('count') == 1, ...
            sprintf('onMoveExternal must not re-invoke BroadcastFcn_; count is %d', counterMap('count')));

        delete(hc);
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_broadcast_fires_once_no_reentry: %s\n', err.message);
    end

    % --- test_two_widget_mirror_integration ---
    % End-to-end: 2-widget dashboard, both linked, rewire, then simulate
    % hover on A -> B mirrors; then A leaves -> B hides.
    try
        eng = DashboardEngine('TestLink2');
        [fig, panA] = makeOffscreenFigure_();
        cleanFig = onCleanup(@() safeClose_(fig)); %#ok<NASGU>

        tag = makeTag_();
        wA = FastSenseWidget('Tag', tag); wA.setCrosshairLink(true);
        wB = FastSenseWidget('Tag', tag); wB.setCrosshairLink(true);

        % Render wA and wB into sub-panels of our test figure.
        panB = uipanel('Parent', fig, 'Units', 'normalized', 'Position', [0.5 0 0.5 1]);
        panAp = uipanel('Parent', fig, 'Units', 'normalized', 'Position', [0 0 0.5 1]);
        wA.render(panAp);
        wB.render(panB);

        % Wire engine widget list + rewire crosshair links.
        eng.Widgets = {wA, wB};
        eng.rewireCrosshairLinks_();

        % Simulate hover on A: onMove fires BroadcastFcn_ which calls
        % broadcastCrosshairX_ -> B.onMoveExternal.
        t = linspace(0, 10, 500);
        xMid = t(250);
        hcA = wA.FastSenseObj.HoverCrosshair_;
        hcB = wB.FastSenseObj.HoverCrosshair_;
        if ~isempty(hcA) && isvalid(hcA) && ~isempty(hcB) && isvalid(hcB)
            hcA.onMove(xMid);
            drawnow;
            assert(strcmp(get(hcB.hLineV, 'Visible'), 'on'), ...
                'B crosshair must be visible after A onMove (mirror works)');

            % A leaves -> broadcast leave -> B hides.
            hcA.onLeave();
            drawnow;
            assert(strcmp(get(hcB.hLineV, 'Visible'), 'off'), ...
                'B crosshair must hide after A onLeave (leave-broadcast works)');
        else
            fprintf('    test_two_widget_mirror_integration: skipped (crosshairs not created in headless mode)\n');
        end
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_two_widget_mirror_integration: %s\n', err.message);
    end

    % =========================================================
    %  Summary
    % =========================================================
    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0
        error('test_fastsense_crosshair_link:failures', '%d test(s) failed.', nFailed);
    end
    fprintf('    All %d tests passed.\n', nPassed);
end

% ============================ HELPERS ============================

function tag = makeTag_()
%MAKETAG_ Plain SensorTag with sinusoidal data on [0, 10].
    t = linspace(0, 10, 500)';
    y = sin(t);
    tag = SensorTag('tst_xlink', 'Name', 'TstLink', 'X', t, 'Y', y);
end

function [fig, panel] = makeOffscreenFigure_()
%MAKEOFFSCREENFIGURE_ Visible='off' figure + single uipanel for rendering.
    fig = figure('Visible', 'off', 'Units', 'pixels', 'Position', [100 100 800 400]);
    panel = uipanel('Parent', fig, 'Units', 'normalized', 'Position', [0 0 1 1]);
end

function [fp, hFig] = makeFp_(nLines)
%MAKEFP_ Build a rendered FastSense in an offscreen figure.
    hFig = figure('Visible', 'off');
    ax = axes('Parent', hFig);
    fp = FastSense('Parent', ax);
    t = linspace(0, 10, 500);
    if nLines >= 1
        fp.addLine(t, sin(t), 'DisplayName', 'sine');
    end
    if nLines >= 2
        fp.addLine(t, cos(t), 'DisplayName', 'cosine');
    end
    fp.render();
end

function tf = canRenderFigures_()
%CANRENDERFIGURES_ True when MATLAB can create an invisible figure + uipanel.
    tf = false;
    try
        h = figure('Visible', 'off');
        if ishandle(h)
            tf = true;
            close(h, 'force');
        end
    catch
        tf = false;
    end
end

function safeClose_(fig)
    try
        if ~isempty(fig) && ishandle(fig)
            close(fig, 'force');
        end
    catch
    end
end

function incrementCounter_(m)
%INCREMENTCOUNTER_ Increment the 'count' key in a containers.Map.
    m('count') = m('count') + 1;
end
