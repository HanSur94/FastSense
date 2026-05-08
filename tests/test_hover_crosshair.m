function test_hover_crosshair()
%TEST_HOVER_CROSSHAIR Tests for FastSense HoverCrosshair (Task 1 + Task 2).
%
%   Covers:
%     - HoverCrosshair construction on a rendered FastSense
%     - Programmatic onMove / onLeave updates graphics visibility + content
%     - Out-of-range x produces em-dash for that line
%     - Chained motion handler preserves pre-existing callback
%     - delete() restores prior WindowButtonMotionFcn and removes graphics
%     - FastSense 'HoverCrosshair' property: default on, opt-out works
%     - delete(fp) cascades cleanup and restores callback

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();

    % HoverCrosshair uses MATLAB's handle-class isvalid() throughout, which
    % Octave does not implement (errors: 'isvalid undefined' /
    % 'function not yet implemented in Octave'). Hover is mouse-driven and
    % targets MATLAB anyway — skip cleanly under Octave.
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIPPED (Octave: HoverCrosshair is MATLAB-only — uses isvalid).\n');
        return;
    end

    if ~canCreateFigure_()
        fprintf('    SKIPPED (headless: cannot create figure)\n');
        return;
    end

    nPassed = 0;
    cases = { ...
        @test_construct_no_throw, ...
        @test_simulate_motion_creates_graphics, ...
        @test_out_of_range_shows_dash, ...
        @test_leave_hides, ...
        @test_delete_cleanup, ...
        @test_chain_preserved ...
    };
    % Append integration tests if the FastSense.HoverCrosshair property
    % wiring landed (Task 2). Older builds without the property gracefully
    % skip these.
    if hasFastSenseHoverProp_()
        cases = [cases, { ...
            @test_disable_property, ...
            @test_default_on, ...
            @test_explicit_off, ...
            @test_delete_cascade ...
        }];
    end

    for k = 1:numel(cases)
        cleaner = onCleanup(@() closeAllSafe_()); %#ok<NASGU>
        try
            cases{k}();
            nPassed = nPassed + 1;
        catch ME
            fprintf('    FAILED: %s\n        %s\n', func2str(cases{k}), ME.message);
            rethrow(ME);
        end
        clear cleaner;
    end

    fprintf('    All %d hover crosshair tests passed.\n', nPassed);
end

% ============================ TEST CASES ============================

function test_construct_no_throw()
    [fp, hFig] = makeFp_(2);
    cleanup = onCleanup(@() safeClose_(hFig)); %#ok<NASGU>
    hc = HoverCrosshair(fp);
    assert(isa(hc, 'HoverCrosshair'), 'expected HoverCrosshair handle');
    assert(isvalid(hc), 'expected valid handle');
    assert(ishandle(hc.hLineV), 'crosshair line should be a graphics handle');
    assert(ishandle(hc.hTipBox), 'tip box should be a graphics handle');
    delete(hc);
end

function test_simulate_motion_creates_graphics()
    [fp, hFig] = makeFp_(2);
    cleanup = onCleanup(@() safeClose_(hFig)); %#ok<NASGU>
    hc = HoverCrosshair(fp);
    % Pick an x in-range for both lines
    xMid = mean(get(fp.hAxes, 'XLim'));
    hc.onMove(xMid);
    assert(strcmp(get(hc.hLineV, 'Visible'), 'on'), 'crosshair line not visible');
    assert(strcmp(get(hc.hTipBox, 'Visible'), 'on'), 'tip box not visible');
    s = get(hc.hTipBox, 'String');
    assert(iscell(s), 'tip String should be a cell array of rows');
    assert(numel(s) >= 3, 'expected header + 2 line rows');
    joined = strjoin(s, '|');
    assert(~isempty(strfind(joined, 'sine')), 'tip should mention "sine"'); %#ok<STREMP>
    assert(~isempty(strfind(joined, 'cosine')), 'tip should mention "cosine"'); %#ok<STREMP>
    delete(hc);
end

function test_out_of_range_shows_dash()
    [fp, hFig] = makeFp_(1);
    cleanup = onCleanup(@() safeClose_(hFig)); %#ok<NASGU>
    hc = HoverCrosshair(fp);
    xData = fp.Lines(1).X;
    xOut = xData(1) - 10;
    hc.onMove(xOut);
    s = get(hc.hTipBox, 'String');
    joined = strjoin(s, '|');
    DASH = char(8212);
    assert(~isempty(strfind(joined, DASH)), ...
        'expected em-dash for out-of-range x'); %#ok<STREMP>
    delete(hc);
end

function test_leave_hides()
    [fp, hFig] = makeFp_(1);
    cleanup = onCleanup(@() safeClose_(hFig)); %#ok<NASGU>
    hc = HoverCrosshair(fp);
    hc.onMove(mean(get(fp.hAxes, 'XLim')));
    hc.onLeave();
    assert(strcmp(get(hc.hLineV, 'Visible'), 'off'), 'line not hidden after onLeave');
    assert(strcmp(get(hc.hTipBox, 'Visible'), 'off'), 'tip not hidden after onLeave');
    delete(hc);
end

function test_delete_cleanup()
    [fp, hFig] = makeFp_(1);
    cleanup = onCleanup(@() safeClose_(hFig)); %#ok<NASGU>
    sentinel = @(s, e) []; % no-op handler
    set(hFig, 'WindowButtonMotionFcn', sentinel);
    saved = get(hFig, 'WindowButtonMotionFcn');
    hc = HoverCrosshair(fp);
    % After construction, the figure handler is now ours, not the sentinel
    cur = get(hFig, 'WindowButtonMotionFcn');
    assert(~isequal(cur, saved), 'expected our handler to replace sentinel');
    hLineV = hc.hLineV;
    hTipBox = hc.hTipBox;
    delete(hc);
    restored = get(hFig, 'WindowButtonMotionFcn');
    assert(isequal(restored, saved), ...
        'WindowButtonMotionFcn not restored after delete');
    assert(~ishandle(hLineV), 'crosshair line not deleted');
    assert(~ishandle(hTipBox), 'tip box not deleted');
end

function test_chain_preserved()
    [fp, hFig] = makeFp_(1);
    cleanup = onCleanup(@() safeClose_(hFig)); %#ok<NASGU>
    flagFile = [tempname() '.flag'];
    cleanupFlag = onCleanup(@() safeDelete_(flagFile)); %#ok<NASGU>
    sentinel = @(s, e) localTouchFlag(flagFile);
    set(hFig, 'WindowButtonMotionFcn', sentinel);
    hc = HoverCrosshair(fp);
    % Invoke the figure's currently-installed handler (our chained one).
    cb = get(hFig, 'WindowButtonMotionFcn');
    assert(isa(cb, 'function_handle'), 'expected function handle');
    try
        cb(hFig, struct());
    catch
        % Even if hit-test path errors (Octave headless), the chained
        % sentinel must have already run before any error.
    end
    assert(exist(flagFile, 'file') == 2, ...
        'sentinel handler was not invoked via the chained callback');
    delete(hc);
end

function test_disable_property()
    [hFig, ax] = newHiddenFig_();
    cleanup = onCleanup(@() safeClose_(hFig)); %#ok<NASGU>
    fp = FastSense('Parent', ax, 'HoverCrosshair', false);
    fp.addLine(1:100, rand(1, 100), 'DisplayName', 'a');
    fp.render();
    assert(fp.HoverCrosshair == false, 'property not honored'); %#ok<NASGU>
    assert(isempty(fp.HoverCrosshair_), ...
        'HoverCrosshair_ should be empty when disabled');
end

function test_default_on()
    [hFig, ax] = newHiddenFig_();
    cleanup = onCleanup(@() safeClose_(hFig)); %#ok<NASGU>
    fp = FastSense('Parent', ax);
    fp.addLine(1:50, rand(1, 50), 'DisplayName', 'a');
    fp.render();
    assert(fp.HoverCrosshair == true, 'default should be true'); %#ok<NASGU>
    assert(~isempty(fp.HoverCrosshair_), ...
        'HoverCrosshair_ should be created when default-on');
    assert(isa(fp.HoverCrosshair_, 'HoverCrosshair'), ...
        'HoverCrosshair_ must be HoverCrosshair instance');
end

function test_explicit_off()
    [hFig, ax] = newHiddenFig_();
    cleanup = onCleanup(@() safeClose_(hFig)); %#ok<NASGU>
    fp = FastSense('Parent', ax, 'HoverCrosshair', false);
    fp.addLine(1:50, rand(1, 50));
    fp.render();
    assert(isempty(fp.HoverCrosshair_), 'expected no instance');
end

function test_delete_cascade()
    [hFig, ax] = newHiddenFig_();
    cleanup = onCleanup(@() safeClose_(hFig)); %#ok<NASGU>
    sentinel = @(s, e) [];
    set(hFig, 'WindowButtonMotionFcn', sentinel);
    saved = get(hFig, 'WindowButtonMotionFcn');
    fp = FastSense('Parent', ax);
    fp.addLine(1:50, rand(1, 50));
    fp.render();
    assert(~isempty(fp.HoverCrosshair_), 'expected instance after render');
    delete(fp);
    if ishandle(hFig)
        restored = get(hFig, 'WindowButtonMotionFcn');
        assert(isequal(restored, saved), ...
            'figure callback not restored after delete(fp)');
    end
end

% ============================ HELPERS ============================

function tf = hasFastSenseHoverProp_()
    tf = false;
    try
        mc = ?FastSense;
        propNames = {mc.PropertyList.Name};
        tf = any(strcmp(propNames, 'HoverCrosshair')) && ...
             any(strcmp(propNames, 'HoverCrosshair_'));
    catch
        tf = false;
    end
end

function tf = canCreateFigure_()
    tf = true;
    try
        h = figure('Visible', 'off');
        delete(h);
    catch
        tf = false;
    end
end

function [fp, hFig] = makeFp_(nLines)
    [hFig, ax] = newHiddenFig_();
    fp = FastSense('Parent', ax);
    t = linspace(0, 10, 500);
    if nLines >= 1
        fp.addLine(t, sin(t), 'DisplayName', 'sine');
    end
    if nLines >= 2
        fp.addLine(t, cos(t), 'DisplayName', 'cosine');
    end
    if nLines >= 3
        fp.addLine(t, 0.5 * sin(2 * t), 'DisplayName', 'half-2x');
    end
    fp.render();
end

function [hFig, ax] = newHiddenFig_()
    hFig = figure('Visible', 'off');
    ax = axes('Parent', hFig);
end

function safeClose_(h)
    try
        if ~isempty(h) && ishandle(h)
            delete(h);
        end
    catch
        % ignore
    end
end

function safeDelete_(p)
    try
        if exist(p, 'file') == 2
            delete(p);
        end
    catch
        % ignore
    end
end

function closeAllSafe_()
    try close all force; catch; end %#ok<TRYNC>
end

function localTouchFlag(p)
    try
        fid = fopen(p, 'w');
        if fid > 0
            fprintf(fid, 'touched');
            fclose(fid);
        end
    catch
        % ignore
    end
end
