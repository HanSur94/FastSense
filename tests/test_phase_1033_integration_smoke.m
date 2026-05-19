function test_phase_1033_integration_smoke()
%TEST_PHASE_1033_INTEGRATION_SMOKE End-to-end Phase 1033 smoke (cross-runtime where possible).
%
%   Closes Phase 1033 + milestone v3.1 by proving the FULL surface works
%   end-to-end across all three plans:
%     - Plan 01: DashboardEngine.attachPlantLog / detachPlantLog public API
%                with idempotent re-attach + serialization-state properties
%     - Plan 02: DashboardSerializer.saveJSON / .m-script round-trip with
%                plantLog top-level key + load-time degrade-to-warning
%     - Plan 03: FastSenseCompanion toolbar fan-out (engine-level fan-out
%                exercised; toolbar button covered by the toolbar smoke
%                files) + the openInteractive varargout extension
%
%   Coverage map:
%     PLOG-INT-01..05 -> testPathPickup +
%                       testEngineAttachDetachRoundTrip +
%                       testSaveLoadJsonRoundTrip +
%                       testSaveLoadScriptRoundTrip +
%                       testBackCompatNoPlantLogJson +
%                       testCompanionMultiDashboardFanOut +
%                       testDetachLeavesNoOrphans +
%                       testReAttachAfterLoadIsIdempotent
%
%   Runtime gates:
%     - Sub-tests 1-5 + 7-8 are cross-runtime (no graphics required)
%     - Sub-test 6 (Companion fan-out) is MATLAB-only with clean Octave SKIP
%
%   install() contract: deliberately omits any manual addpath of
%   libs/PlantLog or libs/Dashboard so install.m's libs-block is the
%   regression gate.

    addPathsViaInstallOnly_();

    % Octave gate: every roundtrip test below exercises
    % engine.attachPlantLog → PlantLogReader.readFile → `readtable`.
    % `readtable` is MATLAB-only (Octave needs the `io` package).
    % Skip cleanly when unavailable; the per-test Octave gate for
    % testCompanionMultiDashboardFanOut already covers the uifigure
    % case, but file-import-driven tests need this top-level gate too.
    if exist('OCTAVE_VERSION', 'builtin') && isempty(which('readtable'))
        fprintf('SKIPPED — readtable unavailable on this Octave (install `io` package to enable).\n');
        return;
    end

    nPassed = 0;
    nFailed = 0;
    testN = 0;

    [nPassed, nFailed, testN] = runOne_('testPathPickup',                    @testPathPickup,                    nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testEngineAttachDetachRoundTrip',   @testEngineAttachDetachRoundTrip,   nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testSaveLoadJsonRoundTrip',         @testSaveLoadJsonRoundTrip,         nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testSaveLoadScriptRoundTrip',       @testSaveLoadScriptRoundTrip,       nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testBackCompatNoPlantLogJson',      @testBackCompatNoPlantLogJson,      nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testCompanionMultiDashboardFanOut', @testCompanionMultiDashboardFanOut, nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testDetachLeavesNoOrphans',         @testDetachLeavesNoOrphans,         nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testReAttachAfterLoadIsIdempotent', @testReAttachAfterLoadIsIdempotent, nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testVarargoutBackCompatPreserved',  @testVarargoutBackCompatPreserved,  nPassed, nFailed, testN);

    if nFailed > 0
        error('test_phase_1033_integration_smoke:failures', ...
            '%d of %d test(s) failed.', nFailed, testN);
    end
    fprintf('    All %d phase_1033_integration_smoke tests passed.\n', nPassed);
end

% =====================================================================
% PATH SETUP -- install() contract gate
% =====================================================================

function addPathsViaInstallOnly_()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    install();
end

% =====================================================================
% TEST RUNNER
% =====================================================================

function [nPassed, nFailed, testN] = runOne_(name, fn, nPassed, nFailed, testN)
    testN = testN + 1;
    fprintf('  Test %d: %s\n', testN, name);
    try
        fn();
        nPassed = nPassed + 1;
    catch ME
        nFailed = nFailed + 1;
        fprintf('    FAILED: %s -- %s\n', name, ME.message);
    end
end

% =====================================================================
% NAMED CLEANUP HELPERS
% =====================================================================

function tryDeleteObj_(o)
    try
        if ~isempty(o) && isvalid(o)
            delete(o);
        end
    catch
    end
end

function tryDeletePath_(p)
    try
        if exist(p, 'file') == 2
            delete(p);
        end
    catch
    end
end

function tryCloseCompanion_(c)
    try
        if ~isempty(c) && isvalid(c)
            c.close();
        end
    catch
    end
end

% =====================================================================
% FIXTURE -- 5-row CSV
% =====================================================================

function fp = makeFixtureCsv_()
    fp = [tempname '.csv'];
    fid = fopen(fp, 'w');
    fprintf(fid, 'Time,Message,Unit,Shift\n');
    fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:32:01', 'pump on',    'ZK-12', 'A');
    fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:35:10', 'pump off',   'ZK-12', 'A');
    fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:40:00', 'valve open', 'ZK-13', 'A');
    fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:45:32', 'cooler on',  'ZK-13', 'A');
    fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:50:11', 'cooler off', 'ZK-13', 'A');
    fclose(fid);
end

% =====================================================================
% SUB-TESTS
% =====================================================================

function testPathPickup()
    % Every Phase 1033 surface (and the upstream Phase 1029-1032
    % dependencies) must resolve via install() alone.
    assertTrue_(~isempty(which('FastSenseCompanion')), 'FastSenseCompanion must resolve');
    assertTrue_(~isempty(which('DashboardEngine')),    'DashboardEngine must resolve');
    assertTrue_(~isempty(which('DashboardSerializer')),'DashboardSerializer must resolve');
    assertTrue_(~isempty(which('PlantLogReader')),     'PlantLogReader must resolve');
    assertTrue_(~isempty(which('PlantLogStore')),      'PlantLogStore must resolve');
    assertTrue_(~isempty(which('PlantLogLiveTail')),   'PlantLogLiveTail must resolve');
end

function testEngineAttachDetachRoundTrip()
    % Plan 01 sanity: attach -> store populated -> detach -> store cleared.
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e = DashboardEngine('SmokeRoundTrip');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    store = e.attachPlantLog(fp, 'StartTail', false);
    assertTrue_(isa(store, 'PlantLogStore'), 'attach must return PlantLogStore');
    assertTrue_(store.getCount() == 5, ...
        'store must contain 5 entries; got %d', store.getCount());
    assertTrue_(~isempty(e.PlantLogStoreInternal_), ...
        'after attach, PlantLogStoreInternal_ must be non-empty');
    e.detachPlantLog();
    assertTrue_(isempty(e.PlantLogStoreInternal_), ...
        'after detach, PlantLogStoreInternal_ must be empty');
    assertTrue_(isempty(e.PlantLogSourcePath_), ...
        'after detach, PlantLogSourcePath_ must be empty');
    clear cleanupE cleanupP;
end

function testSaveLoadJsonRoundTrip()
    % Plan 02 JSON round-trip end-to-end: build engine, attach, save JSON,
    % load JSON, verify plant-log state restored (with the file still on disk
    % so the load-time attachPlantLog dispatch succeeds).
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e1 = DashboardEngine('SmokeJsonRT');
    cleanupE1 = onCleanup(@() tryDeleteObj_(e1));
    e1.attachPlantLog(fp, 'Interval', 7, 'StartTail', false);
    outJson = [tempname '.json'];
    cleanupOut = onCleanup(@() tryDeletePath_(outJson));
    e1.save(outJson);
    % Verify file exists + contains plantLog key
    assertTrue_(exist(outJson, 'file') == 2, 'JSON file must exist after save');
    src = readFileAsString_(outJson);
    assertTrue_(~isempty(strfind(src, '"plantLog"')), ...
        'JSON must contain plantLog top-level key after attach'); %#ok<STREMP>
    % Load -- reattaches via DashboardEngine.load JSON branch.
    e2 = DashboardEngine.load(outJson);
    cleanupE2 = onCleanup(@() tryDeleteObj_(e2));
    assertTrue_(~isempty(e2.PlantLogStoreInternal_), ...
        'after load, e2.PlantLogStoreInternal_ must be non-empty (re-attached from saved sourcePath)');
    assertTrue_(e2.PlantLogStoreInternal_.getCount() == 5, ...
        'reloaded store must contain 5 entries; got %d', e2.PlantLogStoreInternal_.getCount());
    assertTrue_(e2.PlantLogInterval_ == 7, ...
        'reloaded Interval must round-trip; got %g', e2.PlantLogInterval_);
    clear cleanupE2 cleanupOut cleanupE1 cleanupP;
end

function testSaveLoadScriptRoundTrip()
    % Plan 02 .m-script round-trip: save to .m, feval-load via
    % DashboardEngine.load, verify equivalent dashboard state.
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e1 = DashboardEngine('SmokeScriptRT');
    cleanupE1 = onCleanup(@() tryDeleteObj_(e1));
    e1.attachPlantLog(fp, 'StartTail', false);
    % Build a unique .m file name to avoid path collisions
    stem = sprintf('smoke_script_rt_%d', randi(1e9));
    outDir = tempdir;
    outM = fullfile(outDir, [stem '.m']);
    cleanupOut = onCleanup(@() tryDeletePath_(outM));
    e1.save(outM);
    assertTrue_(exist(outM, 'file') == 2, '.m file must exist after save');
    src = readFileAsString_(outM);
    assertTrue_(~isempty(strfind(src, 'attachPlantLog')), ...
        '.m-script must contain attachPlantLog block'); %#ok<STREMP>
    % Load via the .m branch -- DashboardEngine.load feval's the function.
    e2 = DashboardEngine.load(outM);
    cleanupE2 = onCleanup(@() tryDeleteObj_(e2));
    assertTrue_(~isempty(e2.PlantLogStoreInternal_), ...
        '.m-script load must re-attach plant log');
    assertTrue_(e2.PlantLogStoreInternal_.getCount() == 5, ...
        '.m-script load store must contain 5 entries; got %d', ...
        e2.PlantLogStoreInternal_.getCount());
    clear cleanupE2 cleanupOut cleanupE1 cleanupP;
end

function testBackCompatNoPlantLogJson()
    % Plan 02 omit-when-empty: dashboard with no plant log saves to JSON
    % WITHOUT the plantLog key. Load it back: no warnings, no store.
    e1 = DashboardEngine('SmokeBackCompat');
    cleanupE1 = onCleanup(@() tryDeleteObj_(e1));
    outJson = [tempname '.json'];
    cleanupOut = onCleanup(@() tryDeletePath_(outJson));
    e1.save(outJson);
    src = readFileAsString_(outJson);
    assertTrue_(isempty(strfind(src, 'plantLog')), ...
        'JSON of empty engine must NOT contain plantLog substring'); %#ok<STREMP>
    % Reset warning state -- no warnings should fire on load
    lastwarn('');
    e2 = DashboardEngine.load(outJson);
    cleanupE2 = onCleanup(@() tryDeleteObj_(e2));
    [warnMsg, warnId] = lastwarn();
    assertTrue_(isempty(warnId), ...
        'back-compat load must not fire any warning; got id=%s msg=%s', warnId, warnMsg);
    assertTrue_(isempty(e2.PlantLogStoreInternal_), ...
        'back-compat load must leave PlantLogStoreInternal_ empty');
    clear cleanupE2 cleanupOut cleanupE1;
end

function testCompanionMultiDashboardFanOut()
    % Plan 03 fan-out: construct Companion with 3 engines, call
    % attachPlantLog directly on each (simulating the openPlantLogDialog_
    % fan-out body), verify every engine has its store populated.
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP testCompanionMultiDashboardFanOut (Octave: uifigure-only).\n');
        return;
    end
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    d1 = DashboardEngine('FanA');
    d2 = DashboardEngine('FanB');
    d3 = DashboardEngine('FanC');
    cleanupD1 = onCleanup(@() tryDeleteObj_(d1));
    cleanupD2 = onCleanup(@() tryDeleteObj_(d2));
    cleanupD3 = onCleanup(@() tryDeleteObj_(d3));
    c = FastSenseCompanion('Dashboards', {d1, d2, d3});
    cleanupC = onCleanup(@() tryCloseCompanion_(c));
    m = struct('TimestampColumn', 'Time', 'MessageColumn', 'Message', 'TimestampFormat', '');
    % Replicate the fan-out loop body from openPlantLogDialog_
    for k = 1:numel(c.Dashboards)
        eng = c.Dashboards{k};
        eng.attachPlantLog(fp, 'Mapping', m, 'StartTail', false);
    end
    assertTrue_(~isempty(d1.PlantLogStoreInternal_), 'd1 store after fan-out');
    assertTrue_(~isempty(d2.PlantLogStoreInternal_), 'd2 store after fan-out');
    assertTrue_(~isempty(d3.PlantLogStoreInternal_), 'd3 store after fan-out');
    clear cleanupC cleanupD3 cleanupD2 cleanupD1 cleanupP;
end

function testDetachLeavesNoOrphans()
    % Plan 01 zero-orphan contract: attach -> detach -> timerfindall back
    % to baseline (no leaked PlantLogLiveTail timers).
    baselineTimers = numel(timerfindall());
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e = DashboardEngine('SmokeOrphans');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    e.attachPlantLog(fp, 'StartTail', true);  % StartTail=true creates timer
    assertTrue_(numel(timerfindall()) >= baselineTimers + 1, ...
        'attach with StartTail=true must add a timer');
    e.detachPlantLog();
    after = numel(timerfindall());
    assertTrue_(after <= baselineTimers, sprintf( ...
        'after detach, timerfindall must not exceed baseline; baseline=%d got=%d', ...
        baselineTimers, after));
    clear cleanupE cleanupP;
end

function testReAttachAfterLoadIsIdempotent()
    % Plan 01 idempotent re-attach: load engine from JSON (which triggers
    % attachPlantLog internally), then explicitly call attachPlantLog with
    % a different file. Verify the second store handle differs from the
    % first AND there is exactly one live tail (no orphans).
    baselineTimers = numel(timerfindall());
    fp1 = makeFixtureCsv_();
    cleanupP1 = onCleanup(@() tryDeletePath_(fp1));
    e1 = DashboardEngine('SmokeIdemp');
    cleanupE1 = onCleanup(@() tryDeleteObj_(e1));
    e1.attachPlantLog(fp1, 'StartTail', true);
    outJson = [tempname '.json'];
    cleanupOut = onCleanup(@() tryDeletePath_(outJson));
    e1.save(outJson);
    delete(e1);  % drop the original engine
    e2 = DashboardEngine.load(outJson);
    cleanupE2 = onCleanup(@() tryDeleteObj_(e2));
    firstStore = e2.PlantLogStoreInternal_;
    assertTrue_(~isempty(firstStore), 'load must re-attach the store');
    % Now re-attach a NEW file -- the engine should detach the prior store
    % first (idempotent re-attach contract).
    fp2 = makeFixtureCsv_();
    cleanupP2 = onCleanup(@() tryDeletePath_(fp2));
    secondStore = e2.attachPlantLog(fp2, 'StartTail', true);
    assertTrue_(secondStore ~= firstStore, ...
        'after re-attach, store handle must change');
    % Timer count should still be baseline + 1 (the new tail; the old one
    % was detached by attachPlantLog's idempotent re-attach).
    after = numel(timerfindall());
    assertTrue_(after <= baselineTimers + 1, sprintf( ...
        'after re-attach, timerfindall must not exceed baseline+1; baseline=%d got=%d', ...
        baselineTimers, after));
    clear cleanupP2 cleanupE2 cleanupOut cleanupP1;
end

function testVarargoutBackCompatPreserved()
    % Plan 03 Task 1 varargout: verify single-output AND two-output forms
    % both work end-to-end. This is the regression gate for the back-compat
    % contract that ALL existing Phase 1030 + Phase 1031 single-output
    % callers continue to function unchanged.
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    m = struct('TimestampColumn', 'Time', ...
               'MessageColumn',   'Message', ...
               'TimestampFormat', '');
    % Single-output (existing back-compat path)
    entries1 = PlantLogReader.openInteractive(fp, 'Headless', true, 'Mapping', m);
    assertTrue_(numel(entries1) == 5, ...
        'single-output must return 5 entries; got %d', numel(entries1));
    % Two-output (new Plan 03 path)
    [entries2, mapping2] = PlantLogReader.openInteractive(fp, 'Headless', true, 'Mapping', m);
    assertTrue_(numel(entries2) == 5, ...
        'two-output entries must equal single-output count; got %d', numel(entries2));
    assertTrue_(isstruct(mapping2), 'two-output mapping must be a struct');
    assertTrue_(strcmp(mapping2.TimestampColumn, 'Time'), ...
        'two-output mapping must echo the input TimestampColumn');
    clear cleanupP;
end

% =====================================================================
% UTILITY
% =====================================================================

function s = readFileAsString_(filepath)
    fid = fopen(filepath, 'r');
    s = fread(fid, '*char')';
    fclose(fid);
end

function assertTrue_(cond, varargin)
    if ~cond
        if isempty(varargin)
            error('test_phase_1033_integration_smoke:assertFailed', ...
                'Assertion failed.');
        else
            error('test_phase_1033_integration_smoke:assertFailed', ...
                varargin{:});
        end
    end
end
