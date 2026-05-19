function test_event_pick_mode()
%TEST_EVENT_PICK_MODE Tests for the FastSense two-click event-pick flow (260513-v69 + 260513-voo).
%
%   Headless-safe: every figure created is 'Visible','off' and torn down via
%   per-handle delete() inside onCleanup. We never call close all force --
%   the user's industrial plant demo may be running in the same MATLAB
%   session.
%
%   Coverage (T1-T7 from 260513-v69 locked decision section 7; T3 retargeted
%   and T8-T12 added by 260513-voo for shaded-region overlay + modal-
%   persisted decoration + cancel/cleanup lifetime):
%     1) startEventPick_ flips IsEventPicking_, draws EventPickHint, saves
%        the prior axes ButtonDownFcn into PrevAxesBDFcn_.
%     2) After first-click bookkeeping (T1 + line + hint update), exactly
%        ONE EventPickLine is present and hint says 'END'.
%     3) completeEventPick_ second-click handoff: store gains 1 event with
%        Category=manual_annotation/Severity=2; decoration (line+patch+hint)
%        SURVIVES past completeEventPick_ until the modal closes;
%        IsEventPicking_=false; hEventDetails_ non-empty (popup opened).
%        (260513-voo rewire: was "graphics removed", now "graphics survive
%        modal".)
%     4) onPickKey_ with Key='escape' cancels: no event appended, temp
%        graphics removed (incl. patch), axes ButtonDownFcn restored to
%        prior loupe value.
%     5) completeEventPick_(10, 5) auto-swaps -> StartTime=5, EndTime=10.
%     6) startEventPick_ called twice in a row toggle-cancels (no throw,
%        no event appended, IsEventPicking_=false, patch removed).
%     7) cancelEventPick_ on a non-picking instance is idempotent (no throw,
%        no axes child mutation).
%     8) [260513-voo] createPickPatch_(x) on click 1 creates a zero-width
%        EventPickRegion patch with HitTest='off'; cancelEventPick_ clears
%        the handle.
%     9) [260513-voo] onPickMotion_FromX_(cx) updates patch XData to
%        [t1, cx, cx, t1] and YData to current axes YLim.
%    10) [260513-voo] Click-2 path (createPickPatch_ + finalizePickPatch_ +
%        completeEventPick_) persists 1 event, opens the modal, AND leaves
%        the patch (XData = sorted interval) + line + hint visible behind
%        the modal.
%    11) [260513-voo] Closing hEventDetails_ fires the
%        ObjectBeingDestroyed listener -> onEventDetailsClosed_ removes all
%        decoration and restores axes BDF + figure WBM to pre-pick values.
%    12) [260513-voo] cancelEventPick_ mid-pick (post-click-1, pre-click-2)
%        removes the patch, clears PrevFigWBMFcn_, and restores the figure
%        WindowButtonMotionFcn (so HoverCrosshair stays alive on the chain).

    add_test_path_();

    nPassed = 0;
    nFailed = 0;

    % --- Test 1: startEventPick_ enters pick mode --------------------
    try
        [engine, fs, cleaner] = build_engine_with_widget_(); %#ok<ASGLU>
        prevBD = get(fs.hAxes, 'ButtonDownFcn');
        fs.startEventPick_(engine);
        assert(fs.IsEventPicking_, 'Test 1: IsEventPicking_ should be true');
        hint = findall(fs.hAxes, 'Tag', 'EventPickHint');
        assert(numel(hint) == 1, 'Test 1: expected exactly 1 EventPickHint');
        assert(~isempty(fs.PrevAxesBDFcn_), ...
            'Test 1: PrevAxesBDFcn_ should be saved');
        assert(isequal(func2str_safe_(fs.PrevAxesBDFcn_), func2str_safe_(prevBD)), ...
            'Test 1: PrevAxesBDFcn_ should equal the prior loupe handler');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test1_startEntersPickMode: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 2: first-click bookkeeping draws ONE line + updates hint ---
    try
        [engine, fs, cleaner] = build_engine_with_widget_(); %#ok<ASGLU>
        fs.startEventPick_(engine);
        % Drive the first-click bookkeeping at the state-machine level
        % (portable across MATLAB / Octave CurrentPoint semantics).
        fs.EventPickT1_ = 25;
        fs.drawPickLine_(25);
        fs.updatePickHint_('Click END of event (Right-click or ESC to cancel)...');
        lines = findall(fs.hAxes, 'Tag', 'EventPickLine');
        assert(numel(lines) == 1, 'Test 2: expected exactly 1 EventPickLine');
        hint = findall(fs.hAxes, 'Tag', 'EventPickHint');
        assert(numel(hint) == 1, 'Test 2: expected exactly 1 EventPickHint');
        s = get(hint(1), 'String');
        if iscell(s), s = s{1}; end
        assert(~isempty(strfind(s, 'END')), ...
            'Test 2: hint String should contain END');
        fs.cancelEventPick_();
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test2_firstClickBookkeeping: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 3: completeEventPick_ persists + opens details popup --
    % (260513-voo: decoration now survives past completeEventPick_ until the
    %  modal closes; this test is retargeted accordingly.)
    try
        [engine, fs, cleaner] = build_engine_with_widget_(); %#ok<ASGLU>
        fs.startEventPick_(engine);
        nBefore = numel(engine.EventStore.getEvents());
        % Drive the click-1 sub-state via the state seam so the second-click
        % path runs the production createPickPatch_/finalizePickPatch_ flow.
        fs.EventPickT1_ = 10;
        fs.drawPickLine_(10);
        fs.createPickPatch_(10);
        fs.finalizePickPatch_(10, 50);
        fs.completeEventPick_(10, 50);
        evs = engine.EventStore.getEvents();
        assert(numel(evs) == nBefore + 1, 'Test 3: store should gain 1 event');
        ev = evs(end);
        assert(ev.StartTime == 10 && ev.EndTime == 50, ...
            'Test 3: time range mismatch');
        assert(strcmp(ev.Category, 'manual_annotation'), ...
            'Test 3: Category should be manual_annotation');
        assert(ev.Severity == 2, 'Test 3: Severity should be 2');
        assert(strcmp(ev.Notes, ''), 'Test 3: Notes should be empty by default');
        % 260513-voo: decoration must SURVIVE behind the modal.
        assert(numel(findall(fs.hAxes, 'Tag', 'EventPickLine')) >= 1, ...
            'Test 3: EventPickLine should survive past completeEventPick_');
        assert(numel(findall(fs.hAxes, 'Tag', 'EventPickRegion')) == 1, ...
            'Test 3: EventPickRegion patch should survive past completeEventPick_');
        assert(numel(findall(fs.hAxes, 'Tag', 'EventPickHint')) == 1, ...
            'Test 3: EventPickHint should survive past completeEventPick_');
        assert(~fs.IsEventPicking_, 'Test 3: IsEventPicking_ should be false');
        assert(~isempty(fs.hEventDetails_) && ishandle(fs.hEventDetails_), ...
            'Test 3: hEventDetails_ should be non-empty handle');
        % Sanity belt: closing the modal triggers full cleanup (proper T11).
        safe_delete_(fs.hEventDetails_);
        drawnow;
        assert(isempty(findall(fs.hAxes, 'Tag', 'EventPickRegion')), ...
            'Test 3: patch removed after modal close (sanity)');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test3_completeOpensDetails: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 4: ESC cancels mid-pick --------------------------------
    try
        [engine, fs, cleaner] = build_engine_with_widget_(); %#ok<ASGLU>
        nBefore = numel(engine.EventStore.getEvents());
        prevBD = get(fs.hAxes, 'ButtonDownFcn');
        fs.startEventPick_(engine);
        fs.onPickKey_([], struct('Key', 'escape'));
        assert(numel(engine.EventStore.getEvents()) == nBefore, ...
            'Test 4: store should be unchanged after ESC cancel');
        assert(numel(findall(fs.hAxes, 'Tag', 'EventPickHint')) == 0, ...
            'Test 4: hint should be removed');
        assert(numel(findall(fs.hAxes, 'Tag', 'EventPickLine')) == 0, ...
            'Test 4: line should be removed');
        assert(numel(findall(fs.hAxes, 'Tag', 'EventPickRegion')) == 0, ...
            'Test 4: patch should be removed (260513-voo)');
        assert(~fs.IsEventPicking_, 'Test 4: IsEventPicking_ should be false');
        assert(isequal(func2str_safe_(get(fs.hAxes, 'ButtonDownFcn')), ...
                       func2str_safe_(prevBD)), ...
            'Test 4: axes ButtonDownFcn should be restored');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test4_escCancels: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 5: auto-swap when END < START --------------------------
    try
        [engine, fs, cleaner] = build_engine_with_widget_(); %#ok<ASGLU>
        fs.startEventPick_(engine);
        fs.completeEventPick_(10, 5);   % END before START
        evs = engine.EventStore.getEvents();
        assert(numel(evs) >= 1, 'Test 5: event must be appended');
        ev = evs(end);
        assert(ev.StartTime == 5, 'Test 5: StartTime should be min(10,5)=5');
        assert(ev.EndTime == 10, 'Test 5: EndTime should be max(10,5)=10');
        safe_delete_(fs.hEventDetails_);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test5_autoSwap: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 6: toggle-cancel via re-entering pick ------------------
    try
        [engine, fs, cleaner] = build_engine_with_widget_(); %#ok<ASGLU>
        nBefore = numel(engine.EventStore.getEvents());
        fs.startEventPick_(engine);
        fs.startEventPick_(engine);    % second call toggle-cancels
        assert(~fs.IsEventPicking_, ...
            'Test 6: second call should leave IsEventPicking_ false');
        assert(numel(engine.EventStore.getEvents()) == nBefore, ...
            'Test 6: no event should be appended');
        assert(numel(findall(fs.hAxes, 'Tag', 'EventPickHint')) == 0, ...
            'Test 6: hint should be removed after toggle-cancel');
        assert(numel(findall(fs.hAxes, 'Tag', 'EventPickRegion')) == 0, ...
            'Test 6: patch should be removed after toggle-cancel (260513-voo)');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test6_toggleCancel: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 7: cancelEventPick_ idempotent guard -------------------
    try
        [engine, fs, cleaner] = build_engine_with_widget_(); %#ok<ASGLU>
        nBefore = numel(get(fs.hAxes, 'Children'));
        threw = false;
        try
            fs.cancelEventPick_();
        catch
            threw = true;
        end
        assert(~threw, ...
            'Test 7: cancelEventPick_ on non-picking should not throw');
        assert(~fs.IsEventPicking_, ...
            'Test 7: IsEventPicking_ stays false');
        nAfter = numel(get(fs.hAxes, 'Children'));
        assert(nAfter == nBefore, ...
            'Test 7: axes children count should be unchanged');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test7_cancelIdempotent: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 8: patch created on click 1 with 0 width (260513-voo) --
    try
        [engine, fs, cleaner] = build_engine_with_widget_(); %#ok<ASGLU>
        fs.startEventPick_(engine);
        % Drive first click via state seam (same pattern as Test 2).
        fs.EventPickT1_ = 25;
        fs.drawPickLine_(25);
        fs.createPickPatch_(25);
        assert(~isempty(fs.EventPickPatch_), 'Test 8: patch handle stored');
        assert(ishandle(fs.EventPickPatch_), 'Test 8: patch is a live handle');
        xd = get(fs.EventPickPatch_, 'XData');
        assert(numel(xd) == 4 && all(xd == 25), ...
            'Test 8: XData all equal to t1=25 at creation');
        tg = get(fs.EventPickPatch_, 'Tag');
        assert(strcmp(tg, 'EventPickRegion'), 'Test 8: Tag should be EventPickRegion');
        ht = get(fs.EventPickPatch_, 'HitTest');
        assert(strcmp(ht, 'off'), 'Test 8: HitTest must be off');
        fs.cancelEventPick_();
        assert(isempty(fs.EventPickPatch_), 'Test 8: cancel clears the patch handle');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test8_patchCreatedClick1: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 9: motion updates patch width via test seam (260513-voo)
    try
        [engine, fs, cleaner] = build_engine_with_widget_(); %#ok<ASGLU>
        fs.startEventPick_(engine);
        fs.EventPickT1_ = 10;
        fs.drawPickLine_(10);
        fs.createPickPatch_(10);
        fs.onPickMotion_FromX_(42);
        xd = get(fs.EventPickPatch_, 'XData');
        assert(isequal(xd(:)', [10 42 42 10]), ...
            'Test 9: XData after motion must be [10 42 42 10]');
        yLim = get(fs.hAxes, 'YLim');
        yd = get(fs.EventPickPatch_, 'YData');
        assert(isequal(yd(:)', [yLim(1) yLim(1) yLim(2) yLim(2)]), ...
            'Test 9: YData must match current YLim');
        fs.cancelEventPick_();
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test9_motionUpdatesPatch: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 10: patch finalized on click 2 AND survives modal (voo)
    try
        [engine, fs, cleaner] = build_engine_with_widget_(); %#ok<ASGLU>
        nBefore = numel(engine.EventStore.getEvents());
        fs.startEventPick_(engine);
        % Drive click 1 state-seam, then call completeEventPick_(15, 35)
        % via the same finalize -> persist flow the production click-2
        % branch in onPickClick_ runs.
        fs.EventPickT1_ = 15;
        fs.drawPickLine_(15);
        fs.createPickPatch_(15);
        fs.finalizePickPatch_(15, 35);
        fs.completeEventPick_(15, 35);
        evs = engine.EventStore.getEvents();
        assert(numel(evs) == nBefore + 1, 'Test 10: store should gain 1 event');
        assert(~isempty(fs.hEventDetails_) && ishandle(fs.hEventDetails_), ...
            'Test 10: modal should be open');
        assert(~isempty(fs.EventPickPatch_) && ishandle(fs.EventPickPatch_), ...
            'Test 10: patch must survive completeEventPick_');
        xd = get(fs.EventPickPatch_, 'XData');
        assert(isequal(xd(:)', [15 35 35 15]), ...
            'Test 10: patch XData must be the sorted interval');
        lines = findall(fs.hAxes, 'Tag', 'EventPickLine');
        assert(~isempty(lines), 'Test 10: EventPickLine survives');
        hints = findall(fs.hAxes, 'Tag', 'EventPickHint');
        assert(~isempty(hints), 'Test 10: EventPickHint survives');
        safe_delete_(fs.hEventDetails_);   % belt-and-suspenders teardown
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test10_patchFinalizedSurvivesModal: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 11: modal close triggers full cleanup via listener (voo)
    try
        [engine, fs, cleaner] = build_engine_with_widget_(); %#ok<ASGLU>
        prevBD  = get(fs.hAxes, 'ButtonDownFcn');
        hFig    = ancestor(fs.hAxes, 'figure');
        prevWBM = get(hFig, 'WindowButtonMotionFcn');
        fs.startEventPick_(engine);
        % Drive the click-2 production path through the state seam so the
        % patch + line + hint are all on screen before the modal opens.
        fs.EventPickT1_ = 20;
        fs.drawPickLine_(20);
        fs.createPickPatch_(20);
        fs.finalizePickPatch_(20, 40);
        fs.completeEventPick_(20, 40);
        assert(~isempty(fs.hEventDetails_) && ishandle(fs.hEventDetails_), ...
            'Test 11: precondition -- modal opened');
        delete(fs.hEventDetails_);
        drawnow;
        assert(isempty(findall(fs.hAxes, 'Tag', 'EventPickLine')), ...
            'Test 11: EventPickLine removed after modal close');
        assert(isempty(findall(fs.hAxes, 'Tag', 'EventPickRegion')), ...
            'Test 11: EventPickRegion patch removed after modal close');
        assert(isempty(findall(fs.hAxes, 'Tag', 'EventPickHint')), ...
            'Test 11: EventPickHint removed after modal close');
        assert(~fs.IsEventPicking_, 'Test 11: IsEventPicking_ false');
        assert(isequal(func2str_safe_(get(fs.hAxes, 'ButtonDownFcn')), ...
                       func2str_safe_(prevBD)), ...
            'Test 11: axes ButtonDownFcn restored');
        assert(isequal(func2str_safe_(get(hFig, 'WindowButtonMotionFcn')), ...
                       func2str_safe_(prevWBM)), ...
            'Test 11: figure WindowButtonMotionFcn restored');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test11_modalCloseCleansUp: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- Test 12: cancel during pick removes patch + restores WBM (voo)
    try
        [engine, fs, cleaner] = build_engine_with_widget_(); %#ok<ASGLU>
        hFig    = ancestor(fs.hAxes, 'figure');
        prevWBM = get(hFig, 'WindowButtonMotionFcn');
        fs.startEventPick_(engine);
        fs.EventPickT1_ = 30;
        fs.drawPickLine_(30);
        fs.createPickPatch_(30);
        assert(~isempty(fs.EventPickPatch_) && ishandle(fs.EventPickPatch_), ...
            'Test 12: precondition -- patch exists');
        fs.cancelEventPick_();
        assert(isempty(findall(fs.hAxes, 'Tag', 'EventPickRegion')), ...
            'Test 12: cancel removes patch');
        assert(isequal(func2str_safe_(get(hFig, 'WindowButtonMotionFcn')), ...
                       func2str_safe_(prevWBM)), ...
            'Test 12: cancel restores figure WindowButtonMotionFcn');
        assert(isempty(fs.PrevFigWBMFcn_), 'Test 12: PrevFigWBMFcn_ cleared');
        assert(~fs.IsEventPicking_, 'Test 12: IsEventPicking_ false after cancel');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL test12_cancelMidPickRestoresWBM: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    fprintf('    %d passed, %d failed (event-pick mode tests, 260513-v69 + 260513-voo)\n', ...
        nPassed, nFailed);
    if nFailed > 0
        error('test_event_pick_mode: %d/%d failed', ...
            nFailed, nPassed + nFailed);
    end
end

% ============================================================
% Local helpers
% ============================================================

function add_test_path_()
%ADD_TEST_PATH_ Bootstrap addpath + install for the test.
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    addpath(here);
    install();
end

function [engine, fs, cleaner] = build_engine_with_widget_()
%BUILD_ENGINE_WITH_WIDGET_ Build a hidden-figure engine + 1 FastSenseWidget
%   bound to a synthetic SensorTag. Returns the engine, the inner FastSense,
%   and an onCleanup handle that tears down the figure (and any popup) safely.
    t = (0:1:100)';
    y = sin(t / 10);
    tag = SensorTag('demo.signal', 'Name', 'demo', 'X', t, 'Y', y);
    w   = FastSenseWidget('Tag', tag, 'Title', 'demo.signal', ...
                          'ShowEventMarkers', true);
    storePath = [tempname() '.mat'];
    store = EventStore(storePath);
    engine = DashboardEngine('PickModeTest', 'Widgets', {w});
    engine.EventStore = store;
    engine.render();
    try
        set(engine.hFigure, 'Visible', 'off');   % keep the user's screen clean
    catch
    end
    fs = w.FastSenseObj;
    cleaner = onCleanup(@() teardown_(engine, fs));
end

function teardown_(engine, fs)
%TEARDOWN_ Per-handle delete; never close all force.
    try
        if ~isempty(fs) && ~isempty(fs.hEventDetails_) && ...
                ishandle(fs.hEventDetails_)
            delete(fs.hEventDetails_);
        end
    catch
    end
    try
        if ~isempty(engine) && ~isempty(engine.hFigure) && ...
                ishandle(engine.hFigure)
            delete(engine.hFigure);
        end
    catch
    end
end

function safe_delete_(h)
%SAFE_DELETE_ Per-handle delete, best-effort.
    try
        if ~isempty(h) && ishandle(h)
            delete(h);
        end
    catch
    end
end

function s = func2str_safe_(h)
%FUNC2STR_SAFE_ Stringify a function_handle / empty / cell so isequal works.
    if isempty(h)
        s = '';
        return;
    end
    if isa(h, 'function_handle')
        try
            s = func2str(h);
        catch
            s = '';
        end
        return;
    end
    if iscell(h) && ~isempty(h) && isa(h{1}, 'function_handle')
        try
            s = func2str(h{1});
        catch
            s = '';
        end
        return;
    end
    s = '';
end
