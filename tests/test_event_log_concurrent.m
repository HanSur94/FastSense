function test_event_log_concurrent()
%TEST_EVENT_LOG_CONCURRENT Concurrent append stress for EventLog.
%
%   Verifies that EventLog.append correctly lock-serialises writes through
%   TagWriteCoordinator, writes a magic-byte header on first append, encodes
%   events as NDJSON lines readable by ndjsonDecode, and handles lock
%   contention by returning ok=false (skip-and-defer).
%
%   Two tiers:
%     1. CI smoke (always runs): in-process correctness + 2-proc Linux spawn
%     2. FASTSENSE_STRESS_50 (gated): 50-proc append race -> 50,000 lines
%
%   The 2-proc spawn (Test 3) is skipped on macOS and Windows because
%   matlab -batch startup inside a running session exceeds the 90 s budget
%   per Phase 1030-02 SUMMARY Deviation #2.
%
%   The 50-proc stress (Test 5) is operator-gated via FASTSENSE_STRESS_50=1.
%   Run it on the target SMB share to validate SC1 empirically before
%   wiring MonitorTag.emitEvent_ (Phase 1032). If SkippedLineCount > 0 after
%   the stress, this is the Phase 1031 SC6 contingency trigger — re-architect
%   to per-writer-file + merge is documented in the plan objective.
%
%   Tests:
%     1. In-process round-trip: 3 appends -> 1 header + 3 JSON lines
%     2. Lock contention: external holder -> ok=false / nestedLockAcquireForbidden
%     3. 2-proc CI smoke (Linux only): 2x25 appends -> 50 valid lines (macOS skip)
%     4. Invalid input rejection: append([]) and append(42) throw EventLog:invalidEvent
%     5. 50-proc stress (FASTSENSE_STRESS_50=1 gate): 50x1000 -> 50,000 valid lines

    add_concurrency_path_();

    % Octave gate: ClusterIdentity.resolve() (called transitively via FileLock
    % during EventLog.append) uses `datetime('now','TimeZone','UTC')`, which
    % Octave 11.1.0 ships only as a package-level function from the `datatypes`
    % Octave Forge package. CI doesn't install that package; tests that hit the
    % datetime call abort. Skip the whole test on Octave — MATLAB R2020b+ has
    % datetime as a core builtin and exercises every code path here.
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIPPED: Octave detected (test requires MATLAB datetime; install datatypes package and remove this skip to enable).\n');
        return;
    end

    nPassed = 0;

    % ---- Test 1: in-process append round-trip ----------------------------
    sharedRoot = tempname();
    mkdir(sharedRoot);
    cleanupRoot = onCleanup(@() cleanupDir_(sharedRoot)); %#ok<NASGU>

    el = EventLog(sharedRoot, 'key_a');
    for k = 1:3
        ok = el.append(struct('id', sprintf('evt_%d', k), 'val', k));
        assert(ok, sprintf('t1: append #%d returned ok=false', k));
    end
    assert(el.LastAppendSkipped == 0, 't1: no skips in single-process path');

    % Read back and decode — ndjsonDecode skips the '#' header line silently.
    text = fileread(el.path());
    [events, st] = ndjsonDecode(text);
    assert(numel(events) == 3, sprintf('t1: expected 3 events, got %d', numel(events)));
    assert(st.SkippedLineCount == 0, ...
        sprintf('t1: expected 0 skipped lines, got %d', st.SkippedLineCount));
    assert(strcmp(events(1).id, 'evt_1'), 't1: order preserved (first event id mismatch)');

    % Magic header must be present in the raw file text.
    assert(~isempty(strfind(text, EventLog.MAGIC)), ...  %#ok<STREMP>
        't1: magic header line not found in raw file');

    nPassed = nPassed + 1;

    % ---- Test 2: in-process contention: external lock holder -------------
    coord = TagWriteCoordinator(sharedRoot);
    [externalLock, gotExternal] = coord.acquireTag('key_b', struct('Timeout', 0));
    assert(gotExternal, 't2: external lock on key_b must be acquired');
    cleanupExternal = onCleanup(@() externalLock.release()); %#ok<NASGU>

    el2 = EventLog(sharedRoot, 'key_b', struct('LockTimeout', 0));
    ok2 = true;
    try
        ok2 = el2.append(struct('id', 'shouldFail'));
    catch ME
        % Same process already holds the lock on key_b.  FileLock throws
        % Concurrency:nestedLockAcquireForbidden rather than returning ok=false
        % (Phase 1030-01 SUMMARY decision: testTwoCoordinatorsContendOnSameTagKey).
        % Treat this as observable contention — both paths are correct outcomes.
        assert(strcmp(ME.identifier, 'Concurrency:nestedLockAcquireForbidden'), ...
            sprintf('t2: unexpected error id: %s', ME.identifier));
        ok2 = false;
    end
    assert(~ok2, 't2: contention must surface as ok=false or nestedLockAcquireForbidden');

    nPassed = nPassed + 1;

    % ---- Test 3: 2-proc CI smoke (Linux only) ----------------------------
    if isunix() && ~ismac()
        sharedRoot2 = tempname();
        mkdir(sharedRoot2);
        cleanupRoot2 = onCleanup(@() cleanupDir_(sharedRoot2)); %#ok<NASGU>

        nProcs   = 2;
        nPerProc = 25;
        tagKey   = 'smoke_a';
        spawnAppenders_(sharedRoot2, tagKey, nProcs, nPerProc, 60);

        logPath = fullfile(sharedRoot2, 'events', [tagKey, '.events.ndjson']);
        assert(isfile(logPath), 't3: log file not found after spawned procs');
        text3 = fileread(logPath);
        [events3, st3] = ndjsonDecode(text3);
        expected3 = nProcs * nPerProc;
        assert(numel(events3) == expected3, ...
            sprintf('t3: expected %d events, got %d (skipped=%d)', ...
                expected3, numel(events3), st3.SkippedLineCount));
        assert(st3.SkippedLineCount == 0, ...
            sprintf(['t3: 0 corrupt lines required; got %d. ', ...
                'TEAR ALERT — Phase 1031 SC6 contingency triggered. ', ...
                'Re-architect to per-writer-file + merge (see plan objective).'], ...
                st3.SkippedLineCount));
        nPassed = nPassed + 1;
    else
        fprintf(['    SKIPPED t3 2-proc spawn ', ...
            '(matlab -batch startup budget on macOS/Windows; ', ...
            'per Phase 1030-02 SUMMARY Deviation #2).\n']);
    end

    % ---- Test 4: invalid input rejection ---------------------------------
    threw1 = false;
    try
        el.append([]);
    catch ME1
        threw1 = strcmp(ME1.identifier, 'EventLog:invalidEvent');
    end
    assert(threw1, 't4a: append([]) must throw EventLog:invalidEvent');

    threw2 = false;
    try
        el.append(42);
    catch ME2
        threw2 = strcmp(ME2.identifier, 'EventLog:invalidEvent');
    end
    assert(threw2, 't4b: append(42) must throw EventLog:invalidEvent');

    nPassed = nPassed + 1;

    % ---- Test 5: 50-proc tier (FASTSENSE_STRESS_50 gated) ----------------
    if ~strcmp(getenv('FASTSENSE_STRESS_50'), '1')
        fprintf(['    SKIPPED 50-proc tier ', ...
            '(set FASTSENSE_STRESS_50=1 to enable). ', ...
            'PASSED %d in-process + smoke tests.\n'], nPassed);
        return;
    end
    if ~isunix() || ismac()
        fprintf(['    SKIPPED 50-proc tier ', ...
            '(Linux-only per matlab -batch budget; ', ...
            'per Phase 1030-02 SUMMARY Deviation #2).\n']);
        return;
    end

    sharedRoot3 = tempname();
    mkdir(sharedRoot3);
    cleanupRoot3 = onCleanup(@() cleanupDir_(sharedRoot3)); %#ok<NASGU>

    nProcs   = 50;
    nPerProc = 1000;
    tagKey3  = 'stress_50';
    spawnAppenders_(sharedRoot3, tagKey3, nProcs, nPerProc, 600);

    logPath3 = fullfile(sharedRoot3, 'events', [tagKey3, '.events.ndjson']);
    assert(isfile(logPath3), 'STRESS_50: log file not found after 50 spawned procs');
    text5 = fileread(logPath3);
    [events5, st5] = ndjsonDecode(text5);
    expected5 = nProcs * nPerProc;
    assert(numel(events5) == expected5, ...
        sprintf('STRESS_50: expected %d events, got %d', expected5, numel(events5)));
    assert(st5.SkippedLineCount == 0, ...
        sprintf(['STRESS_50: 0 corrupt lines required (SC1), got %d. ', ...
            'Phase 1031 SC6 contingency triggered — see plan objective.'], ...
            st5.SkippedLineCount));

    nPassed = nPassed + 1;
    fprintf('    All %d event_log_concurrent tests passed (incl. 50-proc stress).\n', nPassed);
end

function add_concurrency_path_()
%ADD_CONCURRENCY_PATH_ Add repo root and run install() to put libs on path.
    thisDir  = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    install();
end

function spawnAppenders_(sharedRoot, tagKey, nProcs, nPerProc, timeoutSec)
%SPAWNAPPENDERS_ Spawn nProcs matlab children each appending nPerProc events.
%
%   Each child runs install(), constructs an EventLog for sharedRoot/tagKey,
%   then appends nPerProc events.  On contention (ok=false), the child retries
%   with random jitter (5-25 ms) until the event is written.  This mirrors the
%   retry pattern Phase 1032's MonitorTag.emitEvent_ will use.
%
%   Polls until all matlab children exit or timeoutSec elapses.
%
%   Input:
%     sharedRoot — char; shared root path (tempdir per test)
%     tagKey     — char; tag identifier
%     nProcs     — double; number of child processes to spawn
%     nPerProc   — double; events per child
%     timeoutSec — double; maximum seconds to wait for all children
    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    % Build the child batch command.  Retry on ok==false to ensure exactly
    % nPerProc events are written per child despite lock contention.
    cmdTpl = sprintf(['cd(''%s''); install(); ', ...
                     'el = EventLog(''%s'', ''%s''); ', ...
                     'pid = feature(''getpid''); ', ...
                     'k = 1; ', ...
                     'while k <= %d, ', ...
                     '  ok = el.append(struct(''proc'', pid, ''i'', k)); ', ...
                     '  if ok, k = k + 1; ', ...
                     '  else, pause(0.005 + 0.02 * rand()); end; ', ...
                     'end; exit;'], ...
                     repoRoot, sharedRoot, tagKey, nPerProc);

    % Spawn all children in background.
    for p = 1:nProcs
        system(sprintf('matlab -batch "%s" >/dev/null 2>&1 &', cmdTpl));
    end

    % Poll until no matlab -batch children remain or timeout elapses.
    tStart = tic();
    while toc(tStart) < timeoutSec
        pause(2);
        [~, out] = system('pgrep -fc "matlab -batch"');
        running = str2double(strtrim(out));
        if isnan(running)
            running = 0;
        end
        if running == 0
            break;
        end
    end
end

function cleanupDir_(dirPath)
%CLEANUPDIR_ Remove directory tree (best-effort; non-fatal on error).
    if isfolder(dirPath)
        try
            rmdir(dirPath, 's');
        catch
        end
    end
end
