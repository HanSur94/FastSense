function test_dashboard_layout_plant_log_toggle()
%TEST_DASHBOARD_LAYOUT_PLANT_LOG_TOGGLE MATLAB-only function-style smoke for the L toggle button.
%   Phase 1032 Plan 02 Task 1: addPlantLogToggle + reflowChrome_ three-button anchor +
%   clearPanelControls protected-tag extension.
%
%   Cross-runtime SKIP on Octave because chrome wire-up uses Position queries
%   on uipanels parented to figures that work very differently on Octave; the
%   class-based suite is MATLAB-only anyway.
%
%   Coverage:
%     1. addPlantLogToggle creates exactly one uicontrol with Tag='PlantLogToggleButton'
%     2. uicontrol has String='L', FontWeight='bold', Style='pushbutton', size [24 24]
%     3. Initial position from right edge: x = barW - 24 - 4 - 24 - 4 - 24 - 4
%     4. When no store attached: Enable='off', TooltipString='No plant log attached'
%     5. When store attached + ShowPlantLog=false: Enable='on', tooltip 'Show plant log lines'
%     6. ON state: bg=theme.MarkerPlantLog ([0 0 0]), fg=[1 1 1]; OFF state: theme defaults
%     7. Clicking the toggle flips widget.ShowPlantLog via setShowPlantLog
%     8. After reflowChrome_, all 3 buttons re-anchored at correct offsets
%     9. clearPanelControls preserves PlantLogToggleButton while sweeping rogue uicontrols
%    10. When Enable='off', the toggle does nothing (uicontrol honors Enable natively)
%    11. addPlantLogToggle called twice does not create a duplicate (idempotent)
%    12. Toggle callback wraps work in try/catch so an internal exception is contained

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_dashboard_layout_plant_log_toggle (Octave: uifigure-heavy).\n');
        return;
    end

    add_paths_via_install_only();
    nPassed = 0;

    nPassed = nPassed + test_creates_single_button();
    nPassed = nPassed + test_button_props_match_spec();
    nPassed = nPassed + test_initial_position_leftmost_of_three();
    nPassed = nPassed + test_disabled_when_no_store();
    nPassed = nPassed + test_enabled_when_store_attached();
    nPassed = nPassed + test_pressed_state_colors();
    nPassed = nPassed + test_callback_flips_show_plant_log();
    nPassed = nPassed + test_reflow_chrome_three_buttons();
    nPassed = nPassed + test_clear_panel_controls_protects_toggle();
    nPassed = nPassed + test_disabled_button_does_not_flip_state();
    nPassed = nPassed + test_idempotent_double_call();
    nPassed = nPassed + test_callback_traps_exceptions();

    assert(nPassed == 12, 'expected 12 sub-tests, got %d', nPassed);
    fprintf('    All 12 dashboard_layout_plant_log_toggle assertions passed.\n');
end

% =====================================================================
% PATH SETUP -- install() contract gate (do NOT add manual addpath here)
% =====================================================================

function add_paths_via_install_only()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    install();
    assert(~isempty(which('DashboardLayout')), 'DashboardLayout must resolve after install()');
    assert(~isempty(which('FastSenseWidget')), 'FastSenseWidget must resolve after install()');
    assert(~isempty(which('PlantLogStore')), 'PlantLogStore must resolve after install()');
end

% =====================================================================
% Fixture builders
% =====================================================================

function [eng, widget, fig, btn] = build_widget_with_chrome_(attachStore)
%BUILD_WIDGET_WITH_CHROME_ Construct an offscreen FastSenseWidget rendered
%   through DashboardLayout's chrome path, then return the engine, widget,
%   parent figure, and the L button uicontrol handle.
    fig = figure('Visible', 'off', 'Units', 'pixels', 'Position', [10 10 700 500]);
    eng = DashboardEngine('layoutToggleTest');
    if attachStore
        store = PlantLogStore('x');
        store.addEntries(PlantLogEntry( ...
            'Timestamp', 100, 'Message', 'msg', 'Metadata', struct()));
        eng.setPlantLogStoreForTest_(store);
    end
    widget = FastSenseWidget('Title', 'wt', 'XData', 0:10, 'YData', sin(0:10));
    widget.Position = [1 1 6 2];
    eng.addWidget(widget);
    eng.render(fig);
    % Resolve the L button after render.
    bar = findobj(widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
    btn = findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1);
end

function try_delete_h(h)
    try
        if ~isempty(h) && ishandle(h), delete(h); end
    catch, end
end

function try_delete_obj(o)
    try
        if ~isempty(o) && isvalid(o), delete(o); end
    catch, end
end

% =====================================================================
% Sub-tests
% =====================================================================

function n = test_creates_single_button()
    [eng, widget, fig, btn] = build_widget_with_chrome_(false); %#ok<ASGLU>
    cleanupF = onCleanup(@() try_delete_h(fig));
    cleanupE = onCleanup(@() try_delete_obj(eng));
    assert(numel(btn) == 1 && ishandle(btn(1)), ...
        'expected exactly one PlantLogToggleButton uicontrol after render; got %d', numel(btn));
    clear cleanupE cleanupF;
    n = 1;
end

function n = test_button_props_match_spec()
    [eng, widget, fig, btn] = build_widget_with_chrome_(false); %#ok<ASGLU>
    cleanupF = onCleanup(@() try_delete_h(fig));
    cleanupE = onCleanup(@() try_delete_obj(eng));
    assert(strcmp(get(btn, 'Style'), 'pushbutton'), 'Style must be pushbutton');
    assert(strcmp(get(btn, 'String'), 'L'), 'String must be L');
    assert(strcmp(get(btn, 'FontWeight'), 'bold'), 'FontWeight must be bold');
    p = get(btn, 'Position');
    assert(p(3) == 24 && p(4) == 24, ...
        'Position size must be [24 24]; got [%g %g]', p(3), p(4));
    clear cleanupE cleanupF;
    n = 1;
end

function n = test_initial_position_leftmost_of_three()
    [eng, widget, fig, btn] = build_widget_with_chrome_(false);
    cleanupF = onCleanup(@() try_delete_h(fig));
    cleanupE = onCleanup(@() try_delete_obj(eng));
    bar = findobj(widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
    barPos = get(bar(1), 'Position');
    expectedX = barPos(3) - 24 - 4 - 24 - 4 - 24 - 4;
    btnPos = get(btn, 'Position');
    assert(abs(btnPos(1) - expectedX) < 1e-6, ...
        'L button must be at leftmost-of-three offset; expected x=%g, got x=%g', expectedX, btnPos(1));
    clear cleanupE cleanupF;
    n = 1;
end

function n = test_disabled_when_no_store()
    [eng, widget, fig, btn] = build_widget_with_chrome_(false); %#ok<ASGLU>
    cleanupF = onCleanup(@() try_delete_h(fig));
    cleanupE = onCleanup(@() try_delete_obj(eng));
    assert(strcmp(get(btn, 'Enable'), 'off'), ...
        'Enable must be off when no store attached');
    tip = get(btn, 'TooltipString');
    assert(strcmp(tip, 'No plant log attached'), ...
        'TooltipString must say "No plant log attached"; got "%s"', tip);
    clear cleanupE cleanupF;
    n = 1;
end

function n = test_enabled_when_store_attached()
    [eng, widget, fig, btn] = build_widget_with_chrome_(true); %#ok<ASGLU>
    cleanupF = onCleanup(@() try_delete_h(fig));
    cleanupE = onCleanup(@() try_delete_obj(eng));
    assert(strcmp(get(btn, 'Enable'), 'on'), ...
        'Enable must be on when store attached');
    tip = get(btn, 'TooltipString');
    % ShowPlantLog defaults to false, so the OFF-state tooltip applies.
    assert(strcmp(tip, 'Show plant log lines'), ...
        'TooltipString must say "Show plant log lines" when off; got "%s"', tip);
    clear cleanupE cleanupF;
    n = 1;
end

function n = test_pressed_state_colors()
    [eng, widget, fig, btn] = build_widget_with_chrome_(true);
    cleanupF = onCleanup(@() try_delete_h(fig));
    cleanupE = onCleanup(@() try_delete_obj(eng));
    % OFF state: theme defaults.
    theme = DashboardTheme('light');
    bgOff = get(btn, 'BackgroundColor');
    fgOff = get(btn, 'ForegroundColor');
    assert(isequal(bgOff, theme.ToolbarBackground), ...
        'OFF bg must equal ToolbarBackground; got %s', mat2str(bgOff));
    assert(isequal(fgOff, theme.ToolbarFontColor), ...
        'OFF fg must equal ToolbarFontColor; got %s', mat2str(fgOff));
    % Flip ShowPlantLog and rebuild the button via addPlantLogToggle directly.
    widget.ShowPlantLog = true;
    eng.Layout.addPlantLogToggle(widget, eng);
    bar = findobj(widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
    btn2 = findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1);
    bgOn = get(btn2, 'BackgroundColor');
    fgOn = get(btn2, 'ForegroundColor');
    assert(isequal(bgOn, theme.MarkerPlantLog), ...
        'ON bg must equal MarkerPlantLog; got %s', mat2str(bgOn));
    assert(isequal(fgOn, [1 1 1]), ...
        'ON fg must be [1 1 1]; got %s', mat2str(fgOn));
    clear cleanupE cleanupF;
    n = 1;
end

function n = test_callback_flips_show_plant_log()
    [eng, widget, fig, btn] = build_widget_with_chrome_(true);
    cleanupF = onCleanup(@() try_delete_h(fig));
    cleanupE = onCleanup(@() try_delete_obj(eng));
    assert(~widget.ShowPlantLog, 'precondition: ShowPlantLog must start false');
    cb = get(btn, 'Callback');
    assert(~isempty(cb), 'Callback must be wired');
    cb(btn, []);
    assert(widget.ShowPlantLog, ...
        'after click, ShowPlantLog must be true; got %s', mat2str(widget.ShowPlantLog));
    clear cleanupE cleanupF;
    n = 1;
end

function n = test_reflow_chrome_three_buttons()
    [eng, widget, fig, btn] = build_widget_with_chrome_(true); %#ok<ASGLU>
    cleanupF = onCleanup(@() try_delete_h(fig));
    cleanupE = onCleanup(@() try_delete_obj(eng));
    % Resize the figure to widen the cell, then drive reflowChrome_ manually.
    set(fig, 'Position', [10 10 900 500]);
    drawnow;
    DashboardLayout.reflowChrome_(widget.hCellPanel, 28, 2);
    bar = findobj(widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
    barPos = get(bar(1), 'Position');
    barW = barPos(3);
    det  = findobj(bar(1), 'Tag', 'DetachButton',          '-depth', 1);
    info = findobj(bar(1), 'Tag', 'InfoIconButton',        '-depth', 1);
    pl   = findobj(bar(1), 'Tag', 'PlantLogToggleButton',  '-depth', 1);
    assert(~isempty(det)  && ~isempty(info) && ~isempty(pl), ...
        'after reflow, all three buttons must exist');
    pDet  = get(det(1),  'Position');
    pInfo = get(info(1), 'Position');
    pPL   = get(pl(1),   'Position');
    assert(abs(pDet(1)  - (barW - 24 - 4))           < 1e-6, ...
        'Detach x must be barW - 24 - 4; got %g (expected %g)', pDet(1), barW - 24 - 4);
    assert(abs(pInfo(1) - (barW - 24 - 24 - 4 - 4))  < 1e-6, ...
        'Info x must be barW - 24 - 24 - 4 - 4; got %g', pInfo(1));
    assert(abs(pPL(1)   - (barW - 24 - 4 - 24 - 4 - 24 - 4)) < 1e-6, ...
        'PlantLog x must be barW - 84; got %g (expected %g)', pPL(1), barW - 84);
    clear cleanupE cleanupF;
    n = 1;
end

function n = test_clear_panel_controls_protects_toggle()
    % Build a bare uipanel, populate with the three button-bar tags + a rogue
    % uicontrol. Then invoke DashboardWidget.clearPanelControls (static
    % protected — invoked through the engine widget). Verify rogues die.
    fig = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(fig));
    p = uipanel('Parent', fig);
    uicontrol('Parent', p, 'Tag', 'InfoIconButton',       'Style', 'pushbutton');
    uicontrol('Parent', p, 'Tag', 'DetachButton',         'Style', 'pushbutton');
    uicontrol('Parent', p, 'Tag', 'PlantLogToggleButton', 'Style', 'pushbutton');
    uicontrol('Parent', p, 'Tag', 'RogueControl',         'Style', 'pushbutton');
    % Drive the clearPanelControls path through a real widget delete cycle
    % isn't trivial; we use a TestableDashboardWidget subclass via a local
    % anonymous probe — the static is protected, so we leverage the
    % PanelClearProbe helper class shipped alongside the engine. Reflection
    % fallback: invoke via the same path that GroupWidget.refresh uses.
    %
    % Cleaner approach: use a NumberWidget on which we manually re-render via
    % refresh — its render path calls clearPanelControls on its hPanel.
    nw = NumberWidget('Title', 'probe', 'Value', 0);
    nw.hPanel = p;
    nw.ParentTheme = DashboardTheme('light');
    nw.render(p);
    nw.refresh();
    % After refresh, the rogue (still present, since render only touches its
    % own children — NumberWidget creates text controls). The simpler way:
    % invoke the static directly via a subclass that exposes it.
    Probe_DW_PanelClear.clear(p);
    rogue = findobj(p, 'Tag', 'RogueControl', '-depth', 1);
    assert(isempty(rogue) || all(~ishandle(rogue)), ...
        'rogue uicontrol must be swept');
    pl   = findobj(p, 'Tag', 'PlantLogToggleButton', '-depth', 1);
    assert(~isempty(pl) && ishandle(pl(1)), ...
        'PlantLogToggleButton must survive clearPanelControls');
    info = findobj(p, 'Tag', 'InfoIconButton', '-depth', 1);
    det  = findobj(p, 'Tag', 'DetachButton',   '-depth', 1);
    assert(~isempty(info) && ~isempty(det), ...
        'pre-existing chrome tags must survive clearPanelControls');
    clear cleanupF;
    n = 1;
end

function n = test_disabled_button_does_not_flip_state()
    [eng, widget, fig, btn] = build_widget_with_chrome_(false);
    cleanupF = onCleanup(@() try_delete_h(fig));
    cleanupE = onCleanup(@() try_delete_obj(eng));
    assert(strcmp(get(btn, 'Enable'), 'off'), ...
        'precondition: Enable must be off');
    % Programmatic invocation bypasses the Enable gate; this test relies on
    % the callback guard inside onPlantLogTogglePressed_ to detect the
    % disabled state. Since uicontrol natively skips Callback on Enable='off'
    % user clicks, we ALSO need a software-level guard; the implementation
    % treats Enable='off' as a no-op when forced.
    priorState = widget.ShowPlantLog;
    cb = get(btn, 'Callback');
    % Force-call the callback; the wrapper should detect the disabled bar
    % AND the absent store (no engine.PlantLogStoreInternal_), and not
    % toggle state on failure (because setShowPlantLog throws on no-store
    % path — but the implementation also accepts Enable='on' transitions).
    % We assert that the prior state is preserved even on force-call.
    try
        cb(btn, []);
    catch
        % Callback wraps in try/catch — should not propagate.
    end
    assert(widget.ShowPlantLog == priorState, ...
        'Disabled toggle force-call must not change ShowPlantLog');
    clear cleanupE cleanupF;
    n = 1;
end

function n = test_idempotent_double_call()
    [eng, widget, fig, btn] = build_widget_with_chrome_(false); %#ok<ASGLU>
    cleanupF = onCleanup(@() try_delete_h(fig));
    cleanupE = onCleanup(@() try_delete_obj(eng));
    bar = findobj(widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
    countBefore = numel(findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1));
    eng.Layout.addPlantLogToggle(widget, eng);
    eng.Layout.addPlantLogToggle(widget, eng);
    countAfter  = numel(findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1));
    assert(countBefore == 1, 'precondition: exactly one toggle at start');
    assert(countAfter  == 1, ...
        'after two extra calls, still exactly one toggle; got %d', countAfter);
    clear cleanupE cleanupF;
    n = 1;
end

function n = test_callback_traps_exceptions()
    [eng, widget, fig, btn] = build_widget_with_chrome_(true); %#ok<ASGLU>
    cleanupF = onCleanup(@() try_delete_h(fig));
    cleanupE = onCleanup(@() try_delete_obj(eng));
    % Tear down the engine BEFORE clicking to force the callback into the
    % exception path (the widget loses its engine context). The wrapper
    % must NOT propagate.
    %
    % Easier path: pass a NaN tf into setShowPlantLog by clobbering the
    % stored engine handle. Implementation routes ME through warning,
    % so we just verify no exception escapes.
    cb = get(btn, 'Callback');
    warning('off', 'DashboardLayout:plantLogToggleParentMissing');
    cleanupW = onCleanup(@() warning('on', 'DashboardLayout:plantLogToggleParentMissing'));
    threw = false;
    try
        % Pass a synthetic widget handle that does not implement
        % setShowPlantLog to force the inner setShowPlantLog branch to
        % throw. We pass the engine handle in src so the wrapper has
        % SOMETHING to chew on.
        cb([], []);
    catch
        threw = true;
    end
    assert(~threw, 'callback must NOT propagate exceptions');
    clear cleanupW cleanupE cleanupF;
    n = 1;
end
