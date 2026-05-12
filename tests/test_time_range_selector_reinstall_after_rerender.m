function test_time_range_selector_reinstall_after_rerender()
%TEST_TIME_RANGE_SELECTOR_REINSTALL_AFTER_RERENDER Regression for 260512-egv.
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
%   Test strategy (PATH I from the plan): construct a minimal
%   DashboardEngine with one FastSenseWidget, render it, exercise
%   the synth drag both pre- and post-rerenderWidgets, and assert
%   Selection moves in both cases.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

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

    % Function handles can't be compared portably for identity, so we
    % verify BEHAVIOR: a synth drag must move Selection.
    synthDragShouldMoveSelection_(fig, trs, 'Case B (post-rerender)');

    % --- Case C: Idempotent under repeated Resets ---------------------------
    % rerenderWidgets() can be called many times during a session; the
    % reinstall hook must keep the selector wired across all of them.
    engine.rerenderWidgets();
    synthDragShouldMoveSelection_(fig, trs, 'Case C (second rerender)');

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
