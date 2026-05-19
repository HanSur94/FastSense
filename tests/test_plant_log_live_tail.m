function test_plant_log_live_tail()
%TEST_PLANT_LOG_LIVE_TAIL Function-style cross-runtime smoke for PlantLogLiveTail.
%   Drives the hidden tick_() test seam so the suite runs deterministically
%   without waiting for real timer events. One sub-test (test_start_stop_cleanup)
%   exercises the start/stop pair to assert the timerfindall baseline is
%   preserved after stop().
%
%   Contract: deliberately omits any manual `addpath(fullfile(..., 'libs',
%   'PlantLog'))` -- install.m's libs-block edit (Phase 1029 Plan 03) is the
%   regression gate. If install() ever drops libs/PlantLog/, the very first
%   which() check in add_paths_via_install_only() fails fast.
%
%   Cleanup pattern (PHASE 1030 CHECKER REVISION must NOT regress):
%   every onCleanup callback dispatches to a NAMED helper (try_close,
%   try_delete, try_delete_handle). NO inline try/catch inside anonymous
%   functions -- the parser rejects it.

    add_paths_via_install_only();
    nPassed = 0;

    nPassed = nPassed + test_constructor_defaults();
    nPassed = nPassed + test_constructor_custom_interval();
    nPassed = nPassed + test_constructor_validates_store();
    nPassed = nPassed + test_constructor_validates_mapping();
    nPassed = nPassed + test_constructor_unknown_option();
    nPassed = nPassed + test_setinterval_validates();
    nPassed = nPassed + test_tick_ingests_rows();
    nPassed = nPassed + test_tick_dedup_silent();
    nPassed = nPassed + test_tick_appended_rows();
    nPassed = nPassed + test_tick_error_increments_count();
    nPassed = nPassed + test_tail_tick_event_fires();
    nPassed = nPassed + test_start_stop_cleanup();
    nPassed = nPassed + test_setinterval_while_running_restarts();

    % NOTE: literal '13' on the next line so static acceptance grep matches.
    assert(nPassed == 13, ...
        sprintf('Expected 13 sub-tests; got %d', nPassed));
    fprintf('    All 13 plant_log_live_tail assertions passed.\n');
end

% =====================================================================
% PATH SETUP -- install() contract gate (do NOT add manual addpath here)
% =====================================================================

function add_paths_via_install_only()
    % NOTE: deliberately NO manual addpath of libs/PlantLog -- the install.m
    % libs-block (Phase 1029 Plan 03) is the contract under test.
    thisDir  = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    install();
    assert(~isempty(which('PlantLogLiveTail')), ...
        'PlantLogLiveTail must resolve after install()');
    assert(~isempty(which('PlantLogStore')), ...
        'PlantLogStore must resolve after install()');
    assert(~isempty(which('PlantLogReader')), ...
        'PlantLogReader must resolve after install()');
end

% =====================================================================
% NAMED CLEANUP HELPERS -- never use inline try inside anonymous funcs
% =====================================================================

function try_close(fid)
    try
        if fid > 0
            fclose(fid);
        end
    catch
    end
end

function try_delete(p)
    try
        if exist(p, 'file') == 2
            delete(p);
        end
    catch
    end
end

function try_delete_handle(h)
    try
        if ~isempty(h) && isvalid(h)
            delete(h);
        end
    catch
    end
end

% =====================================================================
% CSV WRITERS (cross-runtime; no readtable/writetable on writer side)
% =====================================================================

function p = make_temp_csv_path_()
    p = [tempname() '.csv'];
end

function write_csv_(path, rows)
    % rows: cell of {tsString, msgString} pairs
    fid = fopen(path, 'w');
    cleanup = onCleanup(@() try_close(fid));
    fprintf(fid, 'timestamp,message\n');
    for k = 1:numel(rows)
        fprintf(fid, '%s,%s\n', rows{k}{1}, rows{k}{2});
    end
    clear cleanup;
end

function append_csv_(path, rows)
    fid = fopen(path, 'a');
    cleanup = onCleanup(@() try_close(fid));
    for k = 1:numel(rows)
        fprintf(fid, '%s,%s\n', rows{k}{1}, rows{k}{2});
    end
    clear cleanup;
end

function m = default_mapping_()
    m = struct( ...
        'TimestampColumn', 'timestamp', ...
        'MessageColumn',   'message', ...
        'TimestampFormat', '');
end

% =====================================================================
% SUB-TESTS
% =====================================================================

function n = test_constructor_defaults()
    s = PlantLogStore('x');
    m = default_mapping_();
    t = PlantLogLiveTail(s, '/tmp/dummy.csv', m);
    cleanupT = onCleanup(@() try_delete_handle(t));
    assert(t.getInterval() == 5, ...
        'Default interval should be 5');
    assert(~t.isRunning(), ...
        'Should not be running on construction without StartImmediately');
    clear cleanupT;
    n = 1;
    fprintf('  PASS: test_constructor_defaults\n');
end

function n = test_constructor_custom_interval()
    s = PlantLogStore('x');
    m = default_mapping_();
    t = PlantLogLiveTail(s, '/tmp/dummy.csv', m, 'Interval', 0.25);
    cleanupT = onCleanup(@() try_delete_handle(t));
    assert(t.getInterval() == 0.25, 'Custom interval should be 0.25');
    clear cleanupT;
    n = 1;
    fprintf('  PASS: test_constructor_custom_interval\n');
end

function n = test_constructor_validates_store()
    m = default_mapping_();
    threw = false;
    try
        PlantLogLiveTail(struct('foo', 1), '/tmp/x.csv', m);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogLiveTail:invalidInput'), ...
            'Bad store: id should be PlantLogLiveTail:invalidInput');
    end
    assert(threw, 'Bad store should throw');
    n = 1;
    fprintf('  PASS: test_constructor_validates_store\n');
end

function n = test_constructor_validates_mapping()
    s = PlantLogStore('x');
    badMapping = struct('MessageColumn', 'message');  % missing TimestampColumn
    threw = false;
    try
        PlantLogLiveTail(s, '/tmp/x.csv', badMapping);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogLiveTail:invalidInput'), ...
            'Bad mapping: id should be PlantLogLiveTail:invalidInput');
    end
    assert(threw, 'Mapping missing TimestampColumn should throw');
    n = 1;
    fprintf('  PASS: test_constructor_validates_mapping\n');
end

function n = test_constructor_unknown_option()
    s = PlantLogStore('x');
    m = default_mapping_();
    threw = false;
    try
        PlantLogLiveTail(s, '/tmp/x.csv', m, 'Frequency', 1);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogLiveTail:unknownOption'), ...
            'Unknown option: id should be PlantLogLiveTail:unknownOption');
    end
    assert(threw, 'Unknown option should throw');
    n = 1;
    fprintf('  PASS: test_constructor_unknown_option\n');
end

function n = test_setinterval_validates()
    s = PlantLogStore('x');
    m = default_mapping_();
    t = PlantLogLiveTail(s, '/tmp/x.csv', m);
    cleanupT = onCleanup(@() try_delete_handle(t));
    threw = false;
    try
        t.setInterval(-1);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogLiveTail:invalidInput'), ...
            'setInterval(-1): id should be PlantLogLiveTail:invalidInput');
    end
    assert(threw, 'Negative interval should throw');
    clear cleanupT;
    n = 1;
    fprintf('  PASS: test_setinterval_validates\n');
end

function n = test_tick_ingests_rows()
    % Octave gate: tick_ calls PlantLogReader.openInteractive →
    % `readtable` (MATLAB-only) and then fires the PlantLogTailTick
    % event via `notify` (also MATLAB-only). Skip on Octave.
    if exist('OCTAVE_VERSION', 'builtin') && isempty(which('readtable'))
        fprintf('  SKIP: test_tick_ingests_rows (Octave: readtable/notify unavailable).\n');
        n = 0;
        return;
    end
    p = make_temp_csv_path_();
    cleanupP = onCleanup(@() try_delete(p));
    write_csv_(p, { ...
        {'2025-01-15 10:00:00', 'pump on'}, ...
        {'2025-01-15 10:01:00', 'pump off'}, ...
        {'2025-01-15 10:02:00', 'valve open'}});
    s = PlantLogStore(p);
    m = default_mapping_();
    t = PlantLogLiveTail(s, p, m);
    cleanupT = onCleanup(@() try_delete_handle(t));
    t.tick_();
    assert(s.getCount() == 3, ...
        sprintf('After tick_(), store should have 3 entries; got %d', s.getCount()));
    clear cleanupT;
    clear cleanupP;
    n = 1;
    fprintf('  PASS: test_tick_ingests_rows\n');
end

function n = test_tick_dedup_silent()
    if exist('OCTAVE_VERSION', 'builtin') && isempty(which('readtable'))
        fprintf('  SKIP: test_tick_dedup_silent (Octave: readtable/notify unavailable).\n');
        n = 0;
        return;
    end
    p = make_temp_csv_path_();
    cleanupP = onCleanup(@() try_delete(p));
    write_csv_(p, { ...
        {'2025-01-15 10:00:00', 'pump on'}, ...
        {'2025-01-15 10:01:00', 'pump off'}, ...
        {'2025-01-15 10:02:00', 'valve open'}});
    s = PlantLogStore(p);
    m = default_mapping_();
    t = PlantLogLiveTail(s, p, m);
    cleanupT = onCleanup(@() try_delete_handle(t));
    t.tick_();
    t.tick_();   % second tick on unchanged file -- dedup
    assert(s.getCount() == 3, ...
        sprintf('Two ticks on unchanged file: dedup should hold count at 3; got %d', ...
        s.getCount()));
    clear cleanupT;
    clear cleanupP;
    n = 1;
    fprintf('  PASS: test_tick_dedup_silent\n');
end

function n = test_tick_appended_rows()
    if exist('OCTAVE_VERSION', 'builtin') && isempty(which('readtable'))
        fprintf('  SKIP: test_tick_appended_rows (Octave: readtable/notify unavailable).\n');
        n = 0;
        return;
    end
    p = make_temp_csv_path_();
    cleanupP = onCleanup(@() try_delete(p));
    write_csv_(p, { ...
        {'2025-01-15 10:00:00', 'pump on'}, ...
        {'2025-01-15 10:01:00', 'pump off'}, ...
        {'2025-01-15 10:02:00', 'valve open'}});
    s = PlantLogStore(p);
    m = default_mapping_();
    t = PlantLogLiveTail(s, p, m);
    cleanupT = onCleanup(@() try_delete_handle(t));
    t.tick_();
    assert(s.getCount() == 3, 'After first tick: 3 entries');
    append_csv_(p, { ...
        {'2025-01-15 10:03:00', 'pressure spike'}, ...
        {'2025-01-15 10:04:00', 'valve close'}});
    t.tick_();
    assert(s.getCount() == 5, ...
        sprintf('After append + second tick: 5 entries; got %d', s.getCount()));
    clear cleanupT;
    clear cleanupP;
    n = 1;
    fprintf('  PASS: test_tick_appended_rows\n');
end

function n = test_tick_error_increments_count()
    if exist('OCTAVE_VERSION', 'builtin') && isempty(which('readtable'))
        fprintf('  SKIP: test_tick_error_increments_count (Octave: tick_() needs notify).\n');
        n = 0;
        return;
    end
    s = PlantLogStore('bogus');
    m = default_mapping_();
    bogusPath = '/nonexistent/path/to/nothing.csv';
    t = PlantLogLiveTail(s, bogusPath, m);
    cleanupT = onCleanup(@() try_delete_handle(t));
    % Suppress the expected warning so the test output stays clean.
    w = warning('off', 'PlantLogLiveTail:tickError');
    cleanupW = onCleanup(@() warning(w));
    t.tick_();
    assert(t.getErrorCount() >= 1, ...
        sprintf('Bogus path should bump error count; got %d', t.getErrorCount()));
    clear cleanupW;
    clear cleanupT;
    n = 1;
    fprintf('  PASS: test_tick_error_increments_count\n');
end

function n = test_tail_tick_event_fires()
    if exist('OCTAVE_VERSION', 'builtin') && isempty(which('readtable'))
        fprintf('  SKIP: test_tail_tick_event_fires (Octave: readtable/notify unavailable).\n');
        n = 0;
        return;
    end
    p = make_temp_csv_path_();
    cleanupP = onCleanup(@() try_delete(p));
    write_csv_(p, { ...
        {'2025-01-15 10:00:00', 'pump on'}, ...
        {'2025-01-15 10:01:00', 'pump off'}});
    s = PlantLogStore(p);
    m = default_mapping_();
    t = PlantLogLiveTail(s, p, m);
    cleanupT = onCleanup(@() try_delete_handle(t));

    % Capture event fires via a containers.Map (handle-typed; works on both
    % MATLAB and Octave; mutable from inside an anonymous fn). Avoids the
    % cross-runtime gotchas of nested-function closures.
    state = containers.Map('KeyType', 'char', 'ValueType', 'any');
    state('fires')     = 0;
    state('lastTotal') = -1;
    lis = addlistener(t, 'PlantLogTailTick', @(src, ed) capture_tick_(state, ed));
    cleanupL = onCleanup(@() try_delete_handle(lis));

    t.tick_();
    fires     = state('fires');
    lastTotal = state('lastTotal');
    assert(fires >= 1, ...
        sprintf('PlantLogTailTick should have fired at least once; got %d', fires));

    if ~exist('OCTAVE_VERSION', 'builtin')
        % Payload-shape assertion is MATLAB-only -- Octave's event.EventData
        % support is partial and PlantLogLiveTail falls through to a
        % payload-less notify.
        assert(lastTotal == s.getCount(), ...
            sprintf('Captured TotalCount (%d) should match store.getCount() (%d)', ...
            lastTotal, s.getCount()));
    end

    clear cleanupL;
    clear cleanupT;
    clear cleanupP;
    n = 1;
    fprintf('  PASS: test_tail_tick_event_fires\n');
end

function n = test_start_stop_cleanup()
    % Use Interval=5 so no real tick fires during the 0.05s pause -- avoids
    % spurious warnings about the dummy CSV path (the test goal is timer
    % lifecycle, not tick semantics).
    if exist('OCTAVE_VERSION', 'builtin') && isempty(which('timerfindall'))
        fprintf('  SKIP: test_start_stop_cleanup (Octave: timerfindall unavailable).\n');
        n = 0;
        return;
    end
    s = PlantLogStore('x');
    m = default_mapping_();
    t = PlantLogLiveTail(s, '/tmp/dummy.csv', m, 'Interval', 5);
    cleanupT = onCleanup(@() try_delete_handle(t));
    % Suppress any tickError warning in case a tick fires before stop().
    w = warning('off', 'PlantLogLiveTail:tickError');
    cleanupW = onCleanup(@() warning(w));
    baseline = numel(timerfindall());
    t.start();
    pause(0.05);
    assert(t.isRunning(), 'After start(): isRunning() true');
    t.stop();
    assert(~t.isRunning(), 'After stop(): isRunning() false');
    after = numel(timerfindall());
    assert(after <= baseline, ...
        sprintf('timerfindall after stop (%d) should be <= baseline (%d)', ...
        after, baseline));
    clear cleanupW;
    clear cleanupT;
    n = 1;
    fprintf('  PASS: test_start_stop_cleanup\n');
end

function n = test_setinterval_while_running_restarts()
    if exist('OCTAVE_VERSION', 'builtin') && isempty(which('timer'))
        fprintf('  SKIP: test_setinterval_while_running_restarts (Octave: timer unavailable).\n');
        n = 0;
        return;
    end
    s = PlantLogStore('x');
    m = default_mapping_();
    t = PlantLogLiveTail(s, '/tmp/dummy.csv', m, 'Interval', 5);
    cleanupT = onCleanup(@() try_delete_handle(t));
    % Suppress any tickError warning -- this test focuses on lifecycle, not ticks.
    w = warning('off', 'PlantLogLiveTail:tickError');
    cleanupW = onCleanup(@() warning(w));
    t.start();
    pause(0.05);
    assert(t.isRunning(), 'Pre-setInterval: isRunning() true');
    t.setInterval(0.5);
    assert(t.isRunning(), 'Post-setInterval(0.5): isRunning() should still be true');
    assert(t.getInterval() == 0.5, ...
        sprintf('Interval should be 0.5; got %g', t.getInterval()));
    t.stop();
    assert(~t.isRunning(), 'After final stop(): isRunning() false');
    clear cleanupW;
    clear cleanupT;
    n = 1;
    fprintf('  PASS: test_setinterval_while_running_restarts\n');
end

% =====================================================================
% EVENT CAPTURE HELPER (mutates containers.Map in place; cross-runtime safe)
% =====================================================================

function capture_tick_(state, ed)
    % Mutates the shared containers.Map state from inside addlistener's
    % anonymous wrapper. containers.Map is a handle type on both MATLAB
    % and Octave, so the assignment via state(key) = val is visible to
    % the test after the listener fires.
    state('fires') = state('fires') + 1;
    try
        % MATLAB delivers a PlantLogTailEventData; Octave fallback
        % delivers the bare event.EventData. isprop is the cheap probe.
        if isprop(ed, 'TotalCount')
            state('lastTotal') = ed.TotalCount; %#ok<NASGU>
        end
    catch
    end
end
