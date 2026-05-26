function test_time_range_selector()
%TEST_TIME_RANGE_SELECTOR Unit tests for TimeRangeSelector invariants.
%
%   Covers seven invariants from plan 1016-02's public contract (with
%   Case 5 split into 5a/5b per 260512-live-mode-companion-adhoc-tail-
%   -spike's preserve-vs-rescale dichotomy):
%     1. Construction defaults (DataRange=[0 1], Selection=[0 1], no callback).
%     2. Swapped setSelection bounds are reordered to tStart < tEnd.
%     3. setSelection clamps out-of-range bounds to DataRange.
%     4. setSelection enforces MinWidthFrac * span as a minimum width.
%     5a. setDataRange superset extension preserves selection verbatim.
%     5b. setDataRange contraction-outside-selection rescales proportionally.
%     6. OnRangeChanged fires exactly once per setSelection call with the
%        final (post-clamp, post-reorder) [tStart, tEnd].

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    % Reset the capture-state persistent used by the callback below.
    captureState('reset');

    % Invisible figure + panel host for the selector.
    f = figure('Visible', 'off');
    cleanup = onCleanup(@() closeIfValid(f));

    % --- Case 1: Construction defaults ---------------------------------------
    p1 = uipanel('Parent', f, 'Units', 'normalized', ...
                 'Position', [0 0 1 0.06]);
    s = TimeRangeSelector(p1);
    assert(isequal(s.DataRange, [0 1]), ...
        sprintf('Case 1: DataRange default = [%g %g] expected [0 1]', ...
                s.DataRange(1), s.DataRange(2)));
    assert(isequal(s.Selection, [0 1]), ...
        sprintf('Case 1: Selection default = [%g %g] expected [0 1]', ...
                s.Selection(1), s.Selection(2)));
    assert(isempty(s.OnRangeChanged), 'Case 1: OnRangeChanged default non-empty');
    delete(s);

    % --- Case 2: Swapped bounds reorder --------------------------------------
    p2 = uipanel('Parent', f, 'Units', 'normalized', ...
                 'Position', [0 0 1 0.06]);
    s = TimeRangeSelector(p2);
    s.setDataRange(0, 100);
    s.setSelection(80, 20);
    [a, b] = s.getSelection();
    assert(a == 20, sprintf('Case 2 reorder: a=%g expected 20', a));
    assert(b == 80, sprintf('Case 2 reorder: b=%g expected 80', b));
    delete(s);

    % --- Case 3: Clamp to DataRange ------------------------------------------
    p3 = uipanel('Parent', f, 'Units', 'normalized', ...
                 'Position', [0 0 1 0.06]);
    s = TimeRangeSelector(p3);
    s.setDataRange(10, 20);
    s.setSelection(5, 25);
    [a, b] = s.getSelection();
    assert(abs(a - 10) < 1e-12, sprintf('Case 3 clamp: a=%g expected 10', a));
    assert(abs(b - 20) < 1e-12, sprintf('Case 3 clamp: b=%g expected 20', b));
    delete(s);

    % --- Case 4: Minimum-width enforcement -----------------------------------
    % MinWidthFrac defaults to 0.005 of DataRange span. For DR=[0,100] -> 0.5.
    p4 = uipanel('Parent', f, 'Units', 'normalized', ...
                 'Position', [0 0 1 0.06]);
    s = TimeRangeSelector(p4);
    s.setDataRange(0, 100);
    s.setSelection(50, 50.0001);
    [a, b] = s.getSelection();
    assert((b - a) >= 0.5 - 1e-9, ...
        sprintf('Case 4 min width: width=%g expected >= 0.5', b - a));
    delete(s);

    % --- Case 5: setDataRange selection-preserve vs rescale ------------------
    % Production behavior (260512-live-mode-companion-adhoc-tail-spike):
    %   - When the new DataRange is a STRICT SUPERSET of the current selection,
    %     the selection is preserved verbatim — Sel=[20,80] stays put after
    %     DR is extended from [0,100] to [0,200]. This is the "live mode
    %     pan-freeze" path (every live tick extends DR by ~1 s; we don't
    %     want that to shift the user's selected window).
    %   - When the new DataRange contracts or no longer contains the
    %     selection, the selection IS rescaled proportionally.
    % We exercise BOTH branches here.
    p5 = uipanel('Parent', f, 'Units', 'normalized', ...
                 'Position', [0 0 1 0.06]);
    s = TimeRangeSelector(p5);
    s.setDataRange(0, 100);
    s.setSelection(20, 80);
    % Branch 1: superset extension — selection preserved verbatim.
    s.setDataRange(0, 200);
    [a, b] = s.getSelection();
    assert(abs(a - 20) < 1e-6, sprintf('Case 5 preserve: a=%g expected 20 (superset path)', a));
    assert(abs(b - 80) < 1e-6, sprintf('Case 5 preserve: b=%g expected 80 (superset path)', b));
    delete(s);

    % Branch 2: range contraction outside current selection — rescale fires.
    p5b = uipanel('Parent', f, 'Units', 'normalized', ...
                  'Position', [0 0 1 0.06]);
    s = TimeRangeSelector(p5b);
    s.setDataRange(0, 100);
    s.setSelection(20, 80);
    s.setDataRange(50, 200);   % contracts left edge above Sel(1)=20 -> rescale
    [a, b] = s.getSelection();
    % Rescaled selection: frac0=0.2 (was 20% offset), frac1=0.8 (80% offset);
    % newSpan = 150 -> a = 50 + 0.2*150 = 80, b = 50 + 0.8*150 = 170.
    assert(abs(a - 80) < 1e-6, sprintf('Case 5 rescale: a=%g expected 80 (contraction path)', a));
    assert(abs(b - 170) < 1e-6, sprintf('Case 5 rescale: b=%g expected 170 (contraction path)', b));
    delete(s);

    % --- Case 6: OnRangeChanged fires once per call with final bounds --------
    % State is captured in a persistent store inside captureState() and drained
    % via @captureHandler. This pattern works identically in MATLAB and Octave
    % (no nested-function closure semantics involved).
    p6 = uipanel('Parent', f, 'Units', 'normalized', ...
                 'Position', [0 0 1 0.06]);
    s = TimeRangeSelector(p6);
    s.setDataRange(0, 100);
    captureState('reset');
    s.OnRangeChanged = @captureHandler;

    s.setSelection(10, 30);
    st = captureState('get');
    assert(st.nFires == 1, ...
        sprintf('Case 6: nFires=%d after setSelection expected 1', st.nFires));
    assert(abs(st.tStart - 10) < 1e-9, ...
        sprintf('Case 6: captured tStart=%g expected 10', st.tStart));
    assert(abs(st.tEnd - 30) < 1e-9, ...
        sprintf('Case 6: captured tEnd=%g expected 30', st.tEnd));

    s.setSelection(80, 20);   % swapped -> reorder + fire
    st = captureState('get');
    assert(st.nFires == 2, ...
        sprintf('Case 6: nFires=%d after reorder-setSelection expected 2', st.nFires));
    assert(abs(st.tStart - 20) < 1e-9, ...
        sprintf('Case 6: reordered tStart=%g expected 20', st.tStart));
    assert(abs(st.tEnd - 80) < 1e-9, ...
        sprintf('Case 6: reordered tEnd=%g expected 80', st.tEnd));

    delete(s);

    fprintf('    All 7 tests passed.\n');
end

function captureHandler(tStart, tEnd)
%CAPTUREHANDLER OnRangeChanged callback used by Case 6; records each fire.
    captureState('record', tStart, tEnd);
end

function out = captureState(op, varargin)
%CAPTURESTATE Persistent-variable capture shim for OnRangeChanged.
%   captureState('reset')               -> clear state
%   captureState('record', tStart, tEnd) -> append a fire
%   captureState('get')                 -> return struct(nFires, tStart, tEnd)
    persistent state
    if isempty(state)
        state = struct('tStart', [], 'tEnd', [], 'nFires', 0);
    end
    out = [];
    switch op
        case 'reset'
            state = struct('tStart', [], 'tEnd', [], 'nFires', 0);
        case 'record'
            state.tStart = varargin{1};
            state.tEnd   = varargin{2};
            state.nFires = state.nFires + 1;
        case 'get'
            out = state;
        otherwise
            error('captureState:unknownOp', 'Unknown op: %s', op);
    end
end

function closeIfValid(h)
%CLOSEIFVALID onCleanup-safe close.
    try
        if ~isempty(h) && ishandle(h)
            close(h);
        end
    catch
    end
end
