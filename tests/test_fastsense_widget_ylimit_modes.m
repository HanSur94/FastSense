function test_fastsense_widget_ylimit_modes()
%TEST_FASTSENSE_WIDGET_YLIMIT_MODES Tests for FastSenseWidget.YLimitMode (260513-sfp).
%
%   Covers:
%     - Default YLimitMode='auto-visible' (backward compat)
%     - setYLimitMode validation
%     - 'auto-visible' rescales to current X window (existing behaviour)
%     - 'auto-all' rescales to full tag data ignoring XLim
%     - 'locked' freezes YLim across refresh/update
%     - setYLimitMode clears UserZoomedY (explicit click re-engages autoscale)
%     - Explicit YLimits pin (non-empty) wins over YLimitMode
%     - toStruct/fromStruct round-trips YLimitMode
%     - Legacy struct without yLimitMode field defaults to 'auto-visible'
%     - Follow mode (FastSenseObj.LiveViewMode='follow') still short-circuits
%       autoScaleY_ regardless of mode (260513-ovt regression guard)

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();

    nPassed = 0; nFailed = 0;
    cleanupAll = onCleanup(@() close('all', 'force')); %#ok<NASGU>

    % --- test_default_y_limit_mode_is_auto_visible ---
    try
        tag = makeTag_();
        w = FastSenseWidget('Tag', tag);
        assert(strcmp(w.YLimitMode, 'auto-visible'), ...
            sprintf('default YLimitMode must be ''auto-visible'', got ''%s''', w.YLimitMode));
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_default_y_limit_mode_is_auto_visible: %s\n', err.message);
    end

    % --- test_set_y_limit_mode_validates ---
    try
        tag = makeTag_();
        w = FastSenseWidget('Tag', tag);
        errId = '';
        try
            w.setYLimitMode('bogus');
        catch e
            errId = e.identifier;
        end
        assert(strcmp(errId, 'FastSenseWidget:invalidYLimitMode'), ...
            sprintf('expected ''FastSenseWidget:invalidYLimitMode'', got ''%s''', errId));
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_set_y_limit_mode_validates: %s\n', err.message);
    end

    % --- test_set_y_limit_mode_visible_rescales_to_window ---
    % Synthetic tag with a step: y in [0,4] -> y in [0,10]; x in [5,10] -> y in [0,100].
    % setYLimitMode() internally clears the UserZoomedY latch (which the
    % XLim/YLim sets below would otherwise tickle), so we don't need to
    % poke the read-only latch directly.
    try
        if ~canRenderFigures_()
            fprintf('    test_set_y_limit_mode_visible_rescales_to_window: skipped (no java desktop).\n');
        else
            tag = makeStepTag_();
            w = FastSenseWidget('Tag', tag);
            [fig, panel] = makeOffscreenFigure_();
            cleanup = onCleanup(@() safeClose_(fig)); %#ok<NASGU>
            w.render(panel);
            % Pan XLim so only the [0,4] half (y in [0,10]) is visible.
            set(w.FastSenseObj.hAxes, 'XLim', [0 4]);
            w.setYLimitMode('auto-visible');
            yl = get(w.FastSenseObj.hAxes, 'YLim');
            % yMin should be near 0; yMax should be near 10 (NOT 100). Allow padding (~10%).
            assert(yl(2) < 30, ...
                sprintf('auto-visible YLim must cover ~[0,10], got [%g, %g]', yl(1), yl(2)));
            nPassed = nPassed + 1;
        end
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_set_y_limit_mode_visible_rescales_to_window: %s\n', err.message);
    end

    % --- test_set_y_limit_mode_all_rescales_to_full_data ---
    try
        if ~canRenderFigures_()
            fprintf('    test_set_y_limit_mode_all_rescales_to_full_data: skipped (no java desktop).\n');
        else
            tag = makeStepTag_();
            w = FastSenseWidget('Tag', tag);
            [fig, panel] = makeOffscreenFigure_();
            cleanup = onCleanup(@() safeClose_(fig)); %#ok<NASGU>
            w.render(panel);
            % Pan XLim so only the [0,4] half (y in [0,10]) is visible.
            set(w.FastSenseObj.hAxes, 'XLim', [0 4]);
            w.setYLimitMode('auto-all');
            yl = get(w.FastSenseObj.hAxes, 'YLim');
            % yMax must cover the [5,10] half (~100), regardless of XLim.
            assert(yl(2) > 80, ...
                sprintf('auto-all YLim must cover ~[0,100], got [%g, %g]', yl(1), yl(2)));
            nPassed = nPassed + 1;
        end
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_set_y_limit_mode_all_rescales_to_full_data: %s\n', err.message);
    end

    % --- test_set_y_limit_mode_locked_freezes_y ---
    try
        if ~canRenderFigures_()
            fprintf('    test_set_y_limit_mode_locked_freezes_y: skipped (no java desktop).\n');
        else
            tag = makeTag_();
            w = FastSenseWidget('Tag', tag);
            [fig, panel] = makeOffscreenFigure_();
            cleanup = onCleanup(@() safeClose_(fig)); %#ok<NASGU>
            w.render(panel);
            % Lock in current Y range, then capture YLim AFTER setYLimitMode
            % so any rescale baked in by the mode switch is included in the
            % baseline. autoScaleY_ must then be a no-op.
            w.setYLimitMode('locked');
            Y0 = get(w.FastSenseObj.hAxes, 'YLim');
            % Try to trigger autoScaleY_ via a y vector that would have rescaled.
            w.autoScaleY_(100 * (1:10));
            Y1 = get(w.FastSenseObj.hAxes, 'YLim');
            assert(isequal(Y0, Y1), ...
                sprintf('locked mode must freeze YLim; [%g,%g] -> [%g,%g]', Y0(1), Y0(2), Y1(1), Y1(2)));
            nPassed = nPassed + 1;
        end
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_set_y_limit_mode_locked_freezes_y: %s\n', err.message);
    end

    % --- test_set_y_limit_mode_clears_user_zoomed_y ---
    % Exercise the latch the same way a real mouse-zoom would: by mutating
    % YLim while IsSettingYLim is false. The XLim/YLim PostSet listener
    % installed in render() flips UserZoomedY to true.
    try
        if ~canRenderFigures_()
            fprintf('    test_set_y_limit_mode_clears_user_zoomed_y: skipped (no java desktop).\n');
        else
            tag = makeTag_();
            w = FastSenseWidget('Tag', tag);
            [fig, panel] = makeOffscreenFigure_();
            cleanup = onCleanup(@() safeClose_(fig)); %#ok<NASGU>
            w.render(panel);
            % Simulate a user mouse-zoom of Y. The YLim PostSet listener
            % (installed in render()) latches UserZoomedY=true.
            set(w.FastSenseObj.hAxes, 'YLim', [-5 5]);
            drawnow;
            assert(w.UserZoomedY, ...
                'precondition: user YLim set must latch UserZoomedY');
            % Explicit click on V button must clear the latch.
            w.setYLimitMode('auto-visible');
            assert(~w.UserZoomedY, ...
                'setYLimitMode must clear UserZoomedY');
            nPassed = nPassed + 1;
        end
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_set_y_limit_mode_clears_user_zoomed_y: %s\n', err.message);
    end

    % --- test_y_limits_pin_wins_over_y_limit_mode ---
    try
        if ~canRenderFigures_()
            fprintf('    test_y_limits_pin_wins_over_y_limit_mode: skipped (no java desktop).\n');
        else
            tag = makeTag_();
            w = FastSenseWidget('Tag', tag, 'YLimits', [0 1000]);
            [fig, panel] = makeOffscreenFigure_();
            cleanup = onCleanup(@() safeClose_(fig)); %#ok<NASGU>
            w.render(panel);
            w.setYLimitMode('auto-visible');
            yl = get(w.FastSenseObj.hAxes, 'YLim');
            assert(isequal(yl, [0 1000]), ...
                sprintf('YLimits pin must win, got [%g, %g]', yl(1), yl(2)));
            nPassed = nPassed + 1;
        end
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_y_limits_pin_wins_over_y_limit_mode: %s\n', err.message);
    end

    % --- test_to_struct_from_struct_round_trips_y_limit_mode ---
    try
        tag = makeTag_();
        w1 = FastSenseWidget('Tag', tag);
        w1.setYLimitMode('locked');
        s = w1.toStruct();
        assert(isfield(s, 'yLimitMode'), 'toStruct must emit yLimitMode when non-default');
        assert(strcmp(s.yLimitMode, 'locked'), ...
            sprintf('yLimitMode in struct must be ''locked'', got ''%s''', s.yLimitMode));
        w2 = FastSenseWidget.fromStruct(s);
        assert(strcmp(w2.YLimitMode, 'locked'), ...
            sprintf('fromStruct must restore YLimitMode=''locked'', got ''%s''', w2.YLimitMode));
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_to_struct_from_struct_round_trips_y_limit_mode: %s\n', err.message);
    end

    % --- test_legacy_struct_without_y_limit_mode_defaults_to_auto_visible ---
    try
        s = struct('type', 'fastsense', 'title', 't', ...
                   'position', struct('col', 1, 'row', 1, 'width', 6, 'height', 2));
        w = FastSenseWidget.fromStruct(s);
        assert(strcmp(w.YLimitMode, 'auto-visible'), ...
            sprintf('legacy struct must default to ''auto-visible'', got ''%s''', w.YLimitMode));
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_legacy_struct_without_y_limit_mode_defaults_to_auto_visible: %s\n', err.message);
    end

    % --- test_to_struct_omits_default_y_limit_mode ---
    % JSON-size optimization: default value must NOT leak into serialized struct.
    try
        tag = makeTag_();
        w = FastSenseWidget('Tag', tag);  % default 'auto-visible'
        s = w.toStruct();
        assert(~isfield(s, 'yLimitMode'), ...
            'toStruct must NOT emit yLimitMode when default ''auto-visible''');
        nPassed = nPassed + 1;
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_to_struct_omits_default_y_limit_mode: %s\n', err.message);
    end

    % --- test_follow_mode_still_short_circuits_autoscale ---
    % 260513-ovt regression guard. Follow toggle's "freeze view in X+Y" intent
    % must still override Y autoscaling even with YLimitMode='auto-visible'.
    try
        if ~canRenderFigures_()
            fprintf('    test_follow_mode_still_short_circuits_autoscale: skipped (no java desktop).\n');
        else
            tag = makeTag_();
            w = FastSenseWidget('Tag', tag);
            [fig, panel] = makeOffscreenFigure_();
            cleanup = onCleanup(@() safeClose_(fig)); %#ok<NASGU>
            w.render(panel);
            % Re-engage auto-visible mode AFTER render so any UserZoomedY
            % latched by the YLim PostSet listener during initial draw is
            % cleared. (setYLimitMode is the documented way to drop the
            % latch; we can't write the read-only property directly.)
            w.setYLimitMode('auto-visible');
            % Switch the inner FastSense into 'follow' mode (mirrors the
            % Follow toolbar toggle's effect).
            w.FastSenseObj.LiveViewMode = 'follow';
            % Capture the current YLim before invoking autoScaleY_.
            Y0 = get(w.FastSenseObj.hAxes, 'YLim');
            % autoScaleY_ with mode 'auto-visible' MUST short-circuit
            % because Follow is engaged.
            w.autoScaleY_(100 * (1:10));
            Y1 = get(w.FastSenseObj.hAxes, 'YLim');
            assert(isequal(Y0, Y1), ...
                sprintf('Follow must short-circuit autoScaleY_; YLim changed [%g,%g]->[%g,%g]', ...
                    Y0(1), Y0(2), Y1(1), Y1(2)));
            nPassed = nPassed + 1;
        end
    catch err
        nFailed = nFailed + 1;
        fprintf('    FAIL test_follow_mode_still_short_circuits_autoscale: %s\n', err.message);
    end

    % --- Summary ---
    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0
        error('test_fastsense_widget_ylimit_modes:failures', '%d test(s) failed.', nFailed);
    end
end

function tag = makeTag_()
%MAKETAG_ Plain SensorTag with sinusoidal data on [1, 1000].
    x = (1:1000)';
    y = sin(x / 50);
    tag = SensorTag('tst_basic', 'Name', 'Tst', 'X', x, 'Y', y);
end

function tag = makeStepTag_()
%MAKESTEPTAG_ Synthetic step tag for window-vs-all comparison.
%   y in [0, 10] for x in [0, 4], y in [0, 100] for x in [5, 10].
    x = (0:10)';
    y = zeros(size(x));
    y(1:5) = (0:4) * (10 / 4);     % x=[0..4]  -> y=[0..10]
    y(6:11) = (0:5) * (100 / 5);   % x=[5..10] -> y=[0..100]
    tag = SensorTag('tst_step', 'Name', 'Step', 'X', x, 'Y', y);
end

function [fig, panel] = makeOffscreenFigure_()
%MAKEOFFSCREENFIGURE_ Visible='off' figure + single uipanel for rendering.
    fig = figure('Visible', 'off', 'Units', 'pixels', 'Position', [100 100 600 400]);
    panel = uipanel('Parent', fig, 'Units', 'normalized', 'Position', [0 0 1 1]);
end

function tf = canRenderFigures_()
%CANRENDERFIGURES_ True when MATLAB can create an invisible figure + uipanel.
%   We avoid the stricter usejava('desktop') guard so that '-batch' /
%   '-nodisplay' CI runs (where the desktop is absent but figure creation
%   still works) get full coverage of the rendered cases.
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
