function test_dashboard_engine_attach_plant_log()
%TEST_DASHBOARD_ENGINE_ATTACH_PLANT_LOG Cross-runtime smoke for Phase 1033 Plan 01.
%
%   Verifies the new public DashboardEngine.attachPlantLog /
%   detachPlantLog API:
%     - attach returns a PlantLogStore handle, populates the engine's
%       four serialization-state properties + the existing
%       PlantLogStoreInternal_ + (when StartTail=true) PlantLogLiveTailInternal_.
%     - Invalid opts raise DashboardEngine:invalidPlantLogOption.
%     - Invalid file path is propagated from PlantLogReader.
%     - detach is idempotent on a never-attached engine.
%     - detach clears every plant-log property + leaves zero orphan timers.
%     - Re-attach with a different file detaches the prior store first
%       (idempotent re-attach contract).
%
%   install() contract: deliberately omits any manual addpath of
%   libs/PlantLog or libs/Dashboard so install.m's libs-block is the
%   regression gate (Phase 1029 Plan 03 + Phase 1031 Plan 03 idiom).
%
%   Runtime: cross-runtime (MATLAB R2020b+ + Octave 7+). No graphics
%   required -- attachPlantLog wires the slider/hover only when a
%   TimeRangeSelector_ is rendered, so these tests deliberately skip
%   the render() path and rely on the test seam's headless-safe
%   behavior. The class-based suite (tests/suite/TestDashboardEngineAttachPlantLog.m)
%   covers the rendered + listener-wiring paths.
%
%   Coverage:
%     PLOG-INT-01 (attach API)  -> testAttachReturnsStore, testAttachDefaultOpts,
%                                  testAttachExplicitOpts
%     PLOG-INT-01 (idempotent)  -> testReAttachIdempotent
%     PLOG-INT-01 (errors)      -> testInvalidOptKey, testInvalidInterval,
%                                  testFilePathNotFound, testInvalidStartTail,
%                                  testOddVarargin
%     PLOG-INT-02 (detach API)  -> testDetachOnNeverAttachedNoOp,
%                                  testDetachAfterAttach,
%                                  testDetachClearsTimer,
%                                  testDetachIdempotent

    addPathsViaInstallOnly_();

    % Octave gate: PlantLogReader.readFile uses `readtable`, which is
    % part of MATLAB but only available in Octave with the `io` package.
    % Skip cleanly when readtable is unavailable — same pattern Phase 1030
    % used in tests/test_plant_log_reader.m for the same reason.
    if exist('OCTAVE_VERSION', 'builtin') && isempty(which('readtable'))
        fprintf('SKIPPED — readtable unavailable on this Octave (install `io` package to enable).\n');
        return;
    end

    nPassed = 0;
    nFailed = 0;
    testN = 0;

    [nPassed, nFailed, testN] = runOne_('testAttachReturnsStore',     @testAttachReturnsStore,     nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testAttachDefaultOpts',      @testAttachDefaultOpts,      nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testAttachExplicitOpts',     @testAttachExplicitOpts,     nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testInvalidOptKey',          @testInvalidOptKey,          nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testInvalidInterval',        @testInvalidInterval,        nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testInvalidStartTail',       @testInvalidStartTail,       nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testOddVarargin',            @testOddVarargin,            nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testFilePathNotFound',       @testFilePathNotFound,       nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testFilePathInvalidInput',   @testFilePathInvalidInput,   nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testDetachOnNeverAttachedNoOp', @testDetachOnNeverAttachedNoOp, nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testDetachAfterAttach',      @testDetachAfterAttach,      nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testDetachClearsTimer',      @testDetachClearsTimer,      nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testDetachIdempotent',       @testDetachIdempotent,       nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testReAttachIdempotent',     @testReAttachIdempotent,     nPassed, nFailed, testN);
    [nPassed, nFailed, testN] = runOne_('testCustomMappingPath',      @testCustomMappingPath,      nPassed, nFailed, testN);

    if nFailed > 0
        error('test_dashboard_engine_attach_plant_log:failures', ...
            '%d of %d test(s) failed.', nFailed, testN);
    end
    fprintf('    All %d dashboard_engine_attach_plant_log tests passed.\n', nPassed);
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
% TEST RUNNER -- prints + counts; never lets one failure stop the rest
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
% NAMED CLEANUP HELPERS -- no try inside anonymous funcs
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

% =====================================================================
% FIXTURE -- a 5-row CSV at tempname with Time, Message, Unit, Shift
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

function testAttachReturnsStore()
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e = DashboardEngine('TestAttachReturns');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    store = e.attachPlantLog(fp, 'StartTail', false);
    assertTrue_(isa(store, 'PlantLogStore'), ...
        'attachPlantLog must return a PlantLogStore handle');
    assertTrue_(~isempty(e.PlantLogStoreInternal_), ...
        'after attach, engine.PlantLogStoreInternal_ must be non-empty');
    assertTrue_(e.PlantLogStoreInternal_ == store, ...
        'returned store handle must be === engine.PlantLogStoreInternal_');
    assertTrue_(store.getCount() == 5, ...
        'attach must populate the store with the 5 fixture rows; got %d', store.getCount());
    clear cleanupE cleanupP;
end

function testAttachDefaultOpts()
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e = DashboardEngine('TestAttachDefault');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    e.attachPlantLog(fp);  % no opts -> all defaults
    assertTrue_(isequal(e.PlantLogSourcePath_, fp), ...
        'PlantLogSourcePath_ must equal the file path passed to attachPlantLog');
    assertTrue_(isstruct(e.PlantLogMapping_) && ...
        isfield(e.PlantLogMapping_, 'timestampCol') && ...
        isfield(e.PlantLogMapping_, 'messageCol') && ...
        isfield(e.PlantLogMapping_, 'format'), ...
        'PlantLogMapping_ must be a struct with timestampCol/messageCol/format');
    assertTrue_(e.PlantLogInterval_ == 5, ...
        'PlantLogInterval_ default must be 5 (CONTEXT D-02)');
    assertTrue_(islogical(e.PlantLogStartTail_) && e.PlantLogStartTail_, ...
        'PlantLogStartTail_ default must be true (CONTEXT D-02)');
    assertTrue_(~isempty(e.PlantLogLiveTailInternal_), ...
        'StartTail=true (default) must produce a non-empty PlantLogLiveTailInternal_');
    % Clean teardown -- destructor also runs detachPlantLog
    e.detachPlantLog();
    clear cleanupE cleanupP;
end

function testAttachExplicitOpts()
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e = DashboardEngine('TestAttachExplicit');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    m = struct('timestampCol', 'Time', 'messageCol', 'Message', ...
               'metadataCols', {{'Unit', 'Shift'}}, 'format', '');
    store = e.attachPlantLog(fp, ...
        'Mapping', m, 'Interval', 7, 'StartTail', false);
    assertTrue_(isa(store, 'PlantLogStore'), 'expected PlantLogStore handle');
    assertTrue_(e.PlantLogInterval_ == 7, 'Interval=7 must round-trip; got %g', e.PlantLogInterval_);
    assertTrue_(islogical(e.PlantLogStartTail_) && ~e.PlantLogStartTail_, ...
        'StartTail=false must round-trip');
    assertTrue_(isempty(e.PlantLogLiveTailInternal_), ...
        'StartTail=false must leave PlantLogLiveTailInternal_ empty');
    assertTrue_(store.getCount() == 5, ...
        'attach must populate with 5 entries from the fixture; got %d', store.getCount());
    clear cleanupE cleanupP;
end

function testInvalidOptKey()
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e = DashboardEngine('TestBadKey');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    ok = false;
    try
        e.attachPlantLog(fp, 'BadKey', 1);
    catch ME
        ok = strcmp(ME.identifier, 'DashboardEngine:invalidPlantLogOption');
    end
    assertTrue_(ok, ...
        'unknown opt key must raise DashboardEngine:invalidPlantLogOption');
    assertTrue_(isempty(e.PlantLogStoreInternal_), ...
        'after invalid-opt error, engine.PlantLogStoreInternal_ must remain empty');
    clear cleanupE cleanupP;
end

function testInvalidInterval()
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e = DashboardEngine('TestBadInterval');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    badValues = {-1, 0, NaN, Inf, [1 2], 'oops'};
    for k = 1:numel(badValues)
        ok = false;
        try
            e.attachPlantLog(fp, 'Interval', badValues{k});
        catch ME
            ok = strcmp(ME.identifier, 'DashboardEngine:invalidPlantLogOption');
        end
        assertTrue_(ok, ...
            'Interval=%s must raise DashboardEngine:invalidPlantLogOption', ...
            describeValue_(badValues{k}));
    end
    clear cleanupE cleanupP;
end

function testInvalidStartTail()
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e = DashboardEngine('TestBadStartTail');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    badValues = {'yes', [true true], {true}};
    for k = 1:numel(badValues)
        ok = false;
        try
            e.attachPlantLog(fp, 'StartTail', badValues{k});
        catch ME
            ok = strcmp(ME.identifier, 'DashboardEngine:invalidPlantLogOption');
        end
        assertTrue_(ok, ...
            'StartTail=%s must raise DashboardEngine:invalidPlantLogOption', ...
            describeValue_(badValues{k}));
    end
    clear cleanupE cleanupP;
end

function testOddVarargin()
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e = DashboardEngine('TestOddVar');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    ok = false;
    try
        e.attachPlantLog(fp, 'Interval');  % odd-length varargin
    catch ME
        ok = strcmp(ME.identifier, 'DashboardEngine:invalidPlantLogOption');
    end
    assertTrue_(ok, ...
        'odd-length varargin must raise DashboardEngine:invalidPlantLogOption');
    clear cleanupE cleanupP;
end

function testFilePathNotFound()
    e = DashboardEngine('TestNotFound');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    nonexistent = fullfile(tempdir, ['__no_such_file_', tempnameStem_(), '.csv']);
    if exist(nonexistent, 'file') == 2
        delete(nonexistent);
    end
    ok = false;
    try
        e.attachPlantLog(nonexistent);
    catch ME
        % Reader propagates PlantLogReader:fileNotFound
        ok = ~isempty(strfind(ME.identifier, 'fileNotFound'));
    end
    assertTrue_(ok, ...
        'nonexistent file path must raise PlantLogReader:fileNotFound');
    assertTrue_(isempty(e.PlantLogStoreInternal_), ...
        'after failed attach, engine.PlantLogStoreInternal_ must remain empty');
    clear cleanupE;
end

function testFilePathInvalidInput()
    e = DashboardEngine('TestBadPath');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    badValues = {[], '', 42};
    for k = 1:numel(badValues)
        ok = false;
        try
            e.attachPlantLog(badValues{k});
        catch ME
            ok = strcmp(ME.identifier, 'PlantLogReader:invalidInput');
        end
        assertTrue_(ok, ...
            'filePath=%s must raise PlantLogReader:invalidInput', ...
            describeValue_(badValues{k}));
    end
    clear cleanupE;
end

function testDetachOnNeverAttachedNoOp()
    e = DashboardEngine('TestDetachNoOp');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    % Must not error, must not warn audibly. We can't trivially assert
    % no-warning cross-runtime, but we can assert no-throw + state empty.
    e.detachPlantLog();
    assertTrue_(isempty(e.PlantLogStoreInternal_),    'no-attach: store stays empty');
    assertTrue_(isempty(e.PlantLogLiveTailInternal_), 'no-attach: tail stays empty');
    assertTrue_(isempty(e.PlantLogTickListener_),     'no-attach: listener stays empty');
    assertTrue_(isempty(e.PlantLogSliderHover_),      'no-attach: slider hover stays empty');
    assertTrue_(isempty(e.WidgetHovers_),             'no-attach: widget hovers stay empty');
    assertTrue_(isequal(e.PlantLogSourcePath_, ''),   'no-attach: source path stays ''''');
    assertTrue_(isempty(e.PlantLogMapping_),          'no-attach: mapping stays empty');
    assertTrue_(isempty(e.PlantLogInterval_),         'no-attach: interval stays empty');
    assertTrue_(isempty(e.PlantLogStartTail_),        'no-attach: startTail stays empty');
    clear cleanupE;
end

function testDetachAfterAttach()
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e = DashboardEngine('TestDetachAfter');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    e.attachPlantLog(fp, 'StartTail', false);
    assertTrue_(~isempty(e.PlantLogStoreInternal_), ...
        'precondition: store attached');
    e.detachPlantLog();
    assertTrue_(isempty(e.PlantLogStoreInternal_),    'detach: store empty');
    assertTrue_(isempty(e.PlantLogLiveTailInternal_), 'detach: tail empty');
    assertTrue_(isempty(e.PlantLogTickListener_),     'detach: listener empty');
    assertTrue_(isempty(e.WidgetHovers_),             'detach: widget hovers empty');
    assertTrue_(isequal(e.PlantLogSourcePath_, ''),   'detach: source path empty');
    assertTrue_(isempty(e.PlantLogMapping_),          'detach: mapping empty');
    assertTrue_(isempty(e.PlantLogInterval_),         'detach: interval empty');
    assertTrue_(isempty(e.PlantLogStartTail_),        'detach: startTail empty');
    clear cleanupE cleanupP;
end

function testDetachClearsTimer()
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    baseline = countTimers_();
    e = DashboardEngine('TestDetachTimer');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    e.attachPlantLog(fp);  % default StartTail=true -> timer
    afterAttach = countTimers_();
    assertTrue_(afterAttach >= baseline + 1, ...
        'attach with StartTail=true must add at least 1 timer; baseline=%d after=%d', ...
        baseline, afterAttach);
    e.detachPlantLog();
    afterDetach = countTimers_();
    assertTrue_(afterDetach <= baseline, ...
        'detach must drop timer count back to baseline; baseline=%d after=%d', ...
        baseline, afterDetach);
    clear cleanupE cleanupP;
end

function testDetachIdempotent()
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e = DashboardEngine('TestDetachIdem');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    e.attachPlantLog(fp, 'StartTail', false);
    e.detachPlantLog();
    e.detachPlantLog();  % second call must be a no-op
    assertTrue_(isempty(e.PlantLogStoreInternal_), ...
        'after double detach, store remains empty');
    clear cleanupE cleanupP;
end

function testReAttachIdempotent()
    fp1 = makeFixtureCsv_();
    fp2 = makeFixtureCsv_();
    cleanupP1 = onCleanup(@() tryDeletePath_(fp1));
    cleanupP2 = onCleanup(@() tryDeletePath_(fp2));
    baseline = countTimers_();
    e = DashboardEngine('TestReAttach');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    store1 = e.attachPlantLog(fp1);  % default StartTail=true
    afterFirst = countTimers_();
    store2 = e.attachPlantLog(fp2);  % re-attach with different file
    afterSecond = countTimers_();
    assertTrue_(store1 ~= store2, ...
        're-attach must return a NEW store handle (different from the first)');
    assertTrue_(e.PlantLogStoreInternal_ == store2, ...
        'engine.PlantLogStoreInternal_ must point at the SECOND store');
    assertTrue_(isequal(e.PlantLogSourcePath_, fp2), ...
        'engine.PlantLogSourcePath_ must update to second file path');
    % Timer count after re-attach must be exactly baseline+1 (NOT +2 --
    % the first tail must have been torn down).
    assertTrue_(afterFirst  >= baseline + 1, ...
        'first attach must create a timer; baseline=%d after=%d', baseline, afterFirst);
    assertTrue_(afterSecond <= baseline + 1, ...
        're-attach must leave exactly +1 timer (no orphans); baseline=%d after=%d', ...
        baseline, afterSecond);
    clear cleanupE cleanupP1 cleanupP2;
end

function testCustomMappingPath()
    % Exercises the JSON-schema-shape Mapping translation path explicitly.
    fp = makeFixtureCsv_();
    cleanupP = onCleanup(@() tryDeletePath_(fp));
    e = DashboardEngine('TestCustomMap');
    cleanupE = onCleanup(@() tryDeleteObj_(e));
    m = struct('timestampCol', 'Time', 'messageCol', 'Message', ...
               'metadataCols', {{'Unit', 'Shift'}}, 'format', '');
    store = e.attachPlantLog(fp, 'Mapping', m, 'StartTail', false);
    assertTrue_(store.getCount() == 5, ...
        'custom-mapping attach must produce 5 entries; got %d', store.getCount());
    % The stored mapping is round-trippable: timestampCol/messageCol/format are
    % populated from the reader-shape conversion.
    out = e.PlantLogMapping_;
    assertTrue_(isstruct(out) && isfield(out, 'timestampCol') && ...
        isfield(out, 'messageCol') && isfield(out, 'format'), ...
        'engine.PlantLogMapping_ must be a struct with timestampCol/messageCol/format');
    assertTrue_(isequal(out.timestampCol, 'Time'), ...
        'timestampCol round-trips: expected Time, got %s', tostr_(out.timestampCol));
    assertTrue_(isequal(out.messageCol, 'Message'), ...
        'messageCol round-trips: expected Message, got %s', tostr_(out.messageCol));
    clear cleanupE cleanupP;
end

% =====================================================================
% ASSERT + UTILITY HELPERS
% =====================================================================

function assertTrue_(cond, varargin)
    if ~cond
        if isempty(varargin)
            error('test_dashboard_engine_attach_plant_log:assertFailed', ...
                'Assertion failed.');
        else
            error('test_dashboard_engine_attach_plant_log:assertFailed', ...
                varargin{:});
        end
    end
end

function n = countTimers_()
    try
        ts = timerfindall();
        n = numel(ts);
    catch
        n = 0;
    end
end

function s = tempnameStem_()
    % Cross-runtime tempname-style stem (numeric only) so the nonexistent
    % file path never collides between concurrent test runs. Uses two
    % randi(1e9) draws -- avoids the 'now' advisory.
    s = sprintf('%d_%d', randi(1e9), randi(1e9));
end

function s = describeValue_(v)
    % Compact one-line description for assert messages (cross-runtime safe).
    try
        if ischar(v)
            s = ['"' v '"'];
        elseif isnumeric(v)
            if isempty(v)
                s = '[]';
            elseif isscalar(v)
                s = num2str(v);
            else
                s = ['<' num2str(numel(v)) '-element numeric>'];
            end
        elseif islogical(v)
            if isscalar(v)
                s = mat2str(v);
            else
                s = ['<' num2str(numel(v)) '-element logical>'];
            end
        elseif iscell(v)
            s = ['<cell ' num2str(numel(v)) '>'];
        else
            s = ['<' class(v) '>'];
        end
    catch
        s = '<?>';
    end
end

function s = tostr_(v)
    % Compact representation of any value (for assert messages).
    if ischar(v)
        s = v;
    else
        try
            s = mat2str(v);
        catch
            s = class(v);
        end
    end
end
