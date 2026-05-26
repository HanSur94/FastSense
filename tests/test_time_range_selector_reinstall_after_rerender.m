function test_time_range_selector_reinstall_after_rerender()
%TEST_TIME_RANGE_SELECTOR_REINSTALL_AFTER_RERENDER Regression for 260512-egv + 260512-eu2.
%   After DashboardEngine.rerenderWidgets() (top-toolbar Reset), the
%   figure's WindowButton{Down,Motion,Up}Fcn must remain wired such
%   that a synthesized WBD -> WBM -> WBU sequence on the slider
%   bracket moves TimeRangeSelector.Selection.
%
%   Pre-fix (without the reinstallCallbacks() hook), the chained
%   HoverCrosshair restorations during widget panel teardown left a
%   dangling closure on WindowButtonMotionFcn whose ~isvalid guard
%   silently no-op'd every motion event, so the slider's
%   onButtonMotion_ was never reached after a Reset and Selection
%   never updated.
%
%   This test was extended for 260512-eu2 to ALSO assert that
%   per-widget HoverCrosshair survives rerenderWidgets. 260512-egv
%   placed the TRS reinstall at the END of rerenderWidgets, AFTER
%   the Layout.realizeWidget loop that constructs new HoverCrosshairs,
%   which wiped out the new HC chain on the figure WBM and left
%   HoverCrosshair feature inert after Reset (acknowledged trade-off
%   in 260512-egv). 260512-eu2 moves the reinstall to BEFORE the
%   realizeWidget loop so new HCs install on TOP of trs.onButtonMotion_,
%   restoring HoverCrosshair while keeping slider drag working (motion
%   events forward through the HC chain via PrevWBMFcn_ down to trs).
%
%   Post-eu2 assertions added (gated on usejava('desktop')):
%     - func2str(get(fig, 'WBM')) contains 'onFigureMove_' — proves
%       WBM is a HoverCrosshair, NOT trs.onButtonMotion_ directly.
%     - At least one realized FastSenseWidget has a valid HoverCrosshair
%       handle on its inner FastSenseObj after rerender.
%
%   HoverCrosshair construction is gated on usejava('desktop') in
%   FastSense.m so it's skipped in `matlab -batch` / CI runs. The
%   slider-drag (egv) regression coverage runs in all environments;
%   the HC (eu2) assertions only fire when desktop is available
%   (live MATLAB GUI session).
%
%   Test strategy (PATH I from the plan): construct a minimal
%   DashboardEngine with one FastSenseWidget, render it, exercise
%   the synth drag both pre- and post-rerenderWidgets, and assert
%   Selection moves in both cases.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    if exist('OCTAVE_VERSION', 'builtin')
        % Octave rejects writes to FastSenseWidget's SetAccess=private
        % properties (FastSenseObj) even when the write originates inside
        % a FastSenseWidget instance method (Octave's access check appears
        % confused by the FastSenseWidget < DashboardWidget subclassing).
        % The test calls engine.render() -> realizeBatch -> realizeWidget
        % -> FastSenseWidget.render line 134 (obj.FastSenseObj = fp;) and
        % trips at construction time before reaching the actual TRS
        % reinstall regression coverage. MATLAB CI continues to exercise
        % the full path.
        %
        % Same root cause as test_event_pick_mode's Octave skip; introduced
        % by quick tasks 260513-v69 / 260513-voo.
        fprintf('  SKIPPED on Octave (FastSenseWidget SetAccess=private self-write rejected by Octave OOP).\n');
        return;
    end

    % Construct a minimal engine with one FastSenseWidget over synthetic
    % data. The engine creates its own figure inside render().
    n = 200;
    xData = (1:n).';
    yData = sin((1:n)' / 10);
    fsw = FastSenseWidget('Title', 'reinstall-test', ...
                          'XData', xData, 'YData', yData);
    engine = DashboardEngine('reinstall-test', 'Widgets', {fsw});
    cleanupEngine = onCleanup(@() safeDeleteEngine_(engine));
    engine.render();

    % Hide the figure so the test runs headless (the desktop session may
    % still be visible to the user but the figure won't steal focus).
    if ~isempty(engine.hFigure) && ishandle(engine.hFigure)
        set(engine.hFigure, 'Visible', 'off');
    end

    fig = engine.hFigure;
    trs = engine.TimeRangeSelector_;
    assert(~isempty(trs) && isa(trs, 'TimeRangeSelector'), ...
        'Engine must own a TimeRangeSelector_ after render().');
    assert(~isempty(fig) && ishandle(fig), ...
        'Engine must own a valid figure after render().');

    % --- Case A: Pre-rerender ------------------------------------------------
    % Sanity: WindowButton handlers must be installed on the figure (any
    % chain that leads to the TRS via the HoverCrosshair stack also counts).
    assert(~isempty(get(fig, 'WindowButtonDownFcn')), ...
        'Case A: WindowButtonDownFcn must be non-empty on a freshly rendered engine');
    assert(~isempty(get(fig, 'WindowButtonMotionFcn')), ...
        'Case A: WindowButtonMotionFcn must be non-empty on a freshly rendered engine');
    assert(~isempty(get(fig, 'WindowButtonUpFcn')), ...
        'Case A: WindowButtonUpFcn must be non-empty on a freshly rendered engine');

    synthDragShouldMoveSelection_(fig, trs, 'Case A (pre-rerender)');

    % --- Case B: Simulate top-toolbar Reset button --------------------------
    engine.rerenderWidgets();

    % WindowButton* handlers must still be present after rerender. Without
    % the reinstallCallbacks() hook the WBM would be a leftover dangling
    % HoverCrosshair closure that silently no-ops; with the fix it's the
    % selector's own handler again.
    wbdFcn = get(fig, 'WindowButtonDownFcn');
    wbmFcn = get(fig, 'WindowButtonMotionFcn');
    wbuFcn = get(fig, 'WindowButtonUpFcn');
    assert(~isempty(wbdFcn), 'Case B: WindowButtonDownFcn must not be empty post-rerender');
    assert(~isempty(wbmFcn), 'Case B: WindowButtonMotionFcn must not be empty post-rerender');
    assert(~isempty(wbuFcn), 'Case B: WindowButtonUpFcn must not be empty post-rerender');

    % (eu2) WBM must be a HoverCrosshair's onFigureMove_, NOT
    % trs.onButtonMotion_ directly. This is the key signal that the
    % new HCs are chained ON TOP of the freshly-reinstalled trs
    % handler (eu2 install order), rather than being wiped out by an
    % end-of-method reinstall (egv install order).
    %
    % HC construction is gated on usejava('desktop') in FastSense.m
    % (line ~1594); in batch mode (matlab -batch / CI) usejava('desktop')
    % returns false so no HCs are ever installed and WBM remains the
    % bare trs handler. The eu2-specific assertions only apply when
    % desktop is available (live MATLAB / interactive sessions).
    hcAvailable = usejava('desktop');
    wbmStr = '';
    if isa(wbmFcn, 'function_handle')
        try
            wbmStr = func2str(wbmFcn);
        catch
            wbmStr = '';
        end
    end
    if hcAvailable
        assertHoverCrosshair_(wbmStr, 'Case B (post-rerender)');
    else
        fprintf(['    [eu2] Skipped HC chain assertion (Case B) — '...
                 'usejava(''desktop'')=0; HC creation is desktop-gated.\n']);
    end

    % Function handles can't be compared portably for identity, so we
    % verify BEHAVIOR: a synth drag must move Selection.
    synthDragShouldMoveSelection_(fig, trs, 'Case B (post-rerender)');

    % (eu2) At least one realized FastSenseWidget must have a live
    % HoverCrosshair attached on its inner FastSenseObj.
    if hcAvailable
        assertSomeWidgetHasHoverCrosshair_(engine, 'Case B (post-rerender)');
    else
        fprintf(['    [eu2] Skipped widget-HC assertion (Case B) — '...
                 'usejava(''desktop'')=0; HC creation is desktop-gated.\n']);
    end

    % --- Case C: Idempotent under repeated Resets ---------------------------
    % rerenderWidgets() can be called many times during a session; the
    % reinstall hook must keep BOTH the slider wired AND the HoverCrosshair
    % chain rebuilt across all of them. (egv: slider; eu2: HC.)
    engine.rerenderWidgets();
    synthDragShouldMoveSelection_(fig, trs, 'Case C (second rerender)');
    if hcAvailable
        wbmFcn2 = get(fig, 'WindowButtonMotionFcn');
        wbmStr2 = '';
        if isa(wbmFcn2, 'function_handle')
            try
                wbmStr2 = func2str(wbmFcn2);
            catch
                wbmStr2 = '';
            end
        end
        assertHoverCrosshair_(wbmStr2, 'Case C (second rerender)');
        assertSomeWidgetHasHoverCrosshair_(engine, 'Case C (second rerender)');
    else
        fprintf(['    [eu2] Skipped HC chain + widget-HC assertions '...
                 '(Case C) — usejava(''desktop'')=0.\n']);
    end

    fprintf('    All cases passed: TRS callbacks remain wired across rerenderWidgets.\n');
end

function synthDragShouldMoveSelection_(f, trs, label)
%SYNTHDRAGSHOULDMOVESELECTION_  Fire WBD->WBM->WBU and assert Selection moved.
    % Narrow Selection so there's room to pan in either direction.
    span = trs.DataRange(2) - trs.DataRange(1);
    trs.setSelection(trs.DataRange(1) + 0.3 * span, ...
                     trs.DataRange(1) + 0.6 * span);
    before = trs.Selection;

    % Find the slider axes pixel center for CurrentPoint. Use the same
    % getpixelposition(...,true) recursive walk that pointerInAxes_ uses.
    axPx = getpixelposition(trs.hAxes, true);  % [x y w h]
    centerX = axPx(1) + axPx(3) / 2;
    centerY = axPx(2) + axPx(4) / 2;

    prevUnits = get(f, 'Units');
    cleanupUnits = onCleanup(@() set(f, 'Units', prevUnits));
    set(f, 'Units', 'pixels');

    % Park pointer in selection center; fire WindowButtonDownFcn.
    set(f, 'CurrentPoint', [centerX, centerY]);
    fn = get(f, 'WindowButtonDownFcn');
    if isa(fn, 'function_handle'), fn(f, []); end
    assert(strcmp(trs.DragState, 'panning'), ...
        [label ': DragState must be ''panning'' after WBD, got ' trs.DragState]);

    % Move pointer +200 pixels in X; fire WindowButtonMotionFcn. The
    % selector's onButtonMotion_ must be reached and must update
    % Selection — this is the actual regression test.
    set(f, 'CurrentPoint', [centerX + 200, centerY]);
    fn = get(f, 'WindowButtonMotionFcn');
    if isa(fn, 'function_handle'), fn(f, []); end

    % Fire WindowButtonUpFcn to release the drag.
    fn = get(f, 'WindowButtonUpFcn');
    if isa(fn, 'function_handle'), fn(f, []); end

    after = trs.Selection;
    assert(~isequal(before, after), ...
        sprintf('%s: synth drag did NOT move Selection (before=[%.6g %.6g] after=[%.6g %.6g]) — TRS WindowButton handlers are not reachable', ...
                label, before(1), before(2), after(1), after(2)));
    assert(strcmp(trs.DragState, 'idle'), ...
        [label ': DragState must be ''idle'' after WBU, got ' trs.DragState]);
end

function safeDeleteEngine_(engine)
    try
        if ~isempty(engine) && isvalid(engine)
            f = engine.hFigure;
            delete(engine);
            if ~isempty(f) && ishandle(f)
                delete(f);
            end
        end
    catch
        % Best-effort cleanup; never throw from onCleanup.
    end
end

function assertHoverCrosshair_(wbmStr, label)
%ASSERTHOVERCROSSHAIR_ Assert the WBM func2str signature looks like a HC handler.
%   Post-eu2 the figure's WindowButtonMotionFcn must be a HoverCrosshair's
%   anonymous wrapper around onFigureMove_, NOT trs.onButtonMotion_ directly.
%   The exact func2str output depends on MATLAB version and the closure
%   contents, so we accept anything containing 'onFigureMove_' as the
%   positive signal, and explicitly reject 'onButtonMotion_' (the TRS
%   signature that would indicate eu2's earlier-reinstall move didn't
%   stick or was overwritten).
    hasHC = ~isempty(strfind(wbmStr, 'onFigureMove_'));  %#ok<STREMP>
    isTrsDirect = ~isempty(strfind(wbmStr, 'onButtonMotion_'));  %#ok<STREMP>
    msgHC = ['%s: WindowButtonMotionFcn must be a HoverCrosshair ' ...
             '(contain ''onFigureMove_''), got func2str=''%s''. ' ...
             'The eu2 fix requires new HCs to install on top of ' ...
             'the reinstalled trs handler.'];
    assert(hasHC, sprintf(msgHC, label, wbmStr));
    msgTrs = ['%s: WindowButtonMotionFcn appears to be ' ...
              'trs.onButtonMotion_ DIRECTLY (func2str=''%s'') — ' ...
              'this is the pre-eu2 state where the end-of-method ' ...
              'reinstall wiped out new HCs. The eu2 fix moves the ' ...
              'reinstall earlier so HCs install on top.'];
    assert(~isTrsDirect, sprintf(msgTrs, label, wbmStr));
end

function assertSomeWidgetHasHoverCrosshair_(engine, label)
%ASSERTSOMEWIDGETHASHOVERCROSSHAIR_ Walk engine widgets and find a live HC.
%   FastSenseWidget stores its FastSense instance on the public read-only
%   property `FastSenseObj`, and FastSense stores its HoverCrosshair on
%   `HoverCrosshair_`. Walk activePageWidgets() and accept the first one
%   that exposes a valid HoverCrosshair handle.
    ws = engine.activePageWidgets();
    assert(~isempty(ws), [label ': activePageWidgets returned empty']);
    found = false;
    for k = 1:numel(ws)
        w = ws{k};
        hc = probeHoverCrosshair_(w);
        if ~isempty(hc) && isvalid(hc)
            found = true;
            break;
        end
    end
    msgFound = [label ': No active-page FastSenseWidget has a ' ...
                'live HoverCrosshair after rerender. The eu2 fix ' ...
                'should rebuild HoverCrosshair on each widget ' ...
                'during Layout.realizeWidget; if this fails, the ' ...
                'reinstall is still wiping them out.'];
    assert(found, msgFound);
end

function hc = probeHoverCrosshair_(w)
%PROBEHOVERCROSSHAIR_ Return widget's HoverCrosshair handle or [] if none.
%   FastSenseWidget exposes FastSenseObj (public SetAccess=private); the
%   FastSense instance stores HoverCrosshair_ as a private property that
%   FastSense's own constructor populates in render() when
%   HoverCrosshair=true and the figure is interactive.
    hc = [];
    try
        if isprop(w, 'FastSenseObj') && ~isempty(w.FastSenseObj)
            fp = w.FastSenseObj;
            if isprop(fp, 'HoverCrosshair_') && ~isempty(fp.HoverCrosshair_)
                hc = fp.HoverCrosshair_;
            end
        end
    catch
        % Best-effort probe; return [] on any error.
    end
end
