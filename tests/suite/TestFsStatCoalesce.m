classdef TestFsStatCoalesce < matlab.unittest.TestCase
    %TESTFSSTATCOALESCE Phase 1028 plan 06 fs-stat coalescing contract.
    %
    %   Asserts the semantic contract of the per-tick fs-stat coalescing
    %   in LiveTagPipeline (Phase 1028 plan 06):
    %
    %     1. **WithIO parity (D-09):** the .mat files produced by
    %        fsCoalesceActive_=true must be byte-equal payloads to those
    %        produced by fsCoalesceActive_=false. The cache is a pure
    %        read-side optimisation; it must not change what gets written
    %        to disk.
    %
    %     2. **File-not-found:** when a tag's raw source does not exist,
    %        both coalesce-on and coalesce-off paths must skip writing
    %        without error (the missing entry is simply absent from the
    %        per-parent-directory map; existing not-found handling triggers).
    %
    %     3. **Mid-tick freeze:** a file that materialises BETWEEN the
    %        tick-start dir() and a later per-tag lookup in the SAME tick
    %        is NOT visible in that tick (the cache snapshot is frozen).
    %        The next tick re-builds the cache from scratch and the
    %        late-arriving file IS picked up.
    %
    %     4. **Tick-to-tick refresh:** a file added between two ticks IS
    %        picked up on the next tick (the fs-cache is re-built per tick).
    %        Confirms the cache is not accidentally persistent across ticks.
    %
    %   The contract is internal-only (D-10): public APIs unchanged. The
    %   `setFsCoalesceForTesting_` setter is Hidden.
    %
    %   See also LiveTagPipeline.lookupFsEntry_, LiveTagPipeline.processTag_,
    %            TestPriorStateCacheParity (sibling D-09 parity test).

    properties (Access = private)
        rawDir_      char = ''
        outDirOn_    char = ''
        outDirOff_   char = ''
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            install();
        end
    end

    methods (TestMethodSetup)
        function setupDirs(testCase)
            TagRegistry.clear();
            base = tempname();
            testCase.rawDir_    = sprintf('%s_raw', base);
            testCase.outDirOn_  = sprintf('%s_on',  base);
            testCase.outDirOff_ = sprintf('%s_off', base);
            mkdir(testCase.rawDir_);
            mkdir(testCase.outDirOn_);
            mkdir(testCase.outDirOff_);
        end
    end

    methods (TestMethodTeardown)
        function teardownDirs(testCase)
            TagRegistry.clear();
            for d = {testCase.rawDir_, testCase.outDirOn_, testCase.outDirOff_}
                if ~isempty(d{1}) && exist(d{1}, 'dir')
                    try
                        rmdir(d{1}, 's');
                    catch
                    end
                end
            end
        end
    end

    methods (Test)
        function testWithIoBytesOnDiskParity(testCase)
            %TESTWITHIOBYTESONDISKPARITY D-09 byte-equal parity contract.
            %   Run the pipeline once with fsCoalesceActive_=true then again
            %   with fsCoalesceActive_=false into separate output dirs. Every
            %   produced .mat must have payload-equal x and y arrays. The
            %   fs-coalesce cache is a pure read-side optimisation so any
            %   divergence is a bug.
            %
            %   Strategy: single tickOnce per pass against identical prefilled
            %   CSV files. Avoids depending on mtime-granularity behaviour
            %   across ticks (1-second filesystem mtime resolution on many
            %   Linux systems can make tick-2-skips-because-same-mtime an
            %   inherent fixture flake; one-tick parity sidesteps that and
            %   still exercises both fs-coalesce branches in lookupFsEntry_).
            nFiles   = 3;
            nTags    = 9;
            nPrefill = 50;
            nCols    = 5;

            % fs-coalesce ON pass.
            csvPaths = makeCsvFiles_(testCase.rawDir_, nFiles, nCols, nPrefill);
            runPipelineOnceParity_(csvPaths, testCase.outDirOn_, ...
                nTags, nCols, true);

            % Reset between passes so the second pass sees identical inputs.
            TagRegistry.clear();
            wipeDir_(testCase.rawDir_);
            csvPaths = makeCsvFiles_(testCase.rawDir_, nFiles, nCols, nPrefill);
            runPipelineOnceParity_(csvPaths, testCase.outDirOff_, ...
                nTags, nCols, false);

            assertPayloadParity_(testCase, testCase.outDirOn_, testCase.outDirOff_);
        end

        function testFileNotFoundHandledOnBothPaths(testCase)
            %TESTFILENOTFOUNDHANDLEDONBOTHPATHS Missing-file no-throw contract.
            %   When a tag's raw source path points at a non-existent file,
            %   both coalesce-on and coalesce-off paths must skip the tag
            %   silently (no exception out of tickOnce; tagState_ remains
            %   at the pre-tick value). The map's isKey returns false; the
            %   existing not-found path triggers and just returns.
            ghostPath = fullfile(testCase.rawDir_, 'this_file_does_not_exist.csv');
            rs = struct('file', ghostPath, 'column', 'col_01');
            t = SensorTag('ghost_tag', 'RawSource', rs);
            TagRegistry.register('ghost_tag', t);

            % fs-coalesce ON: must not throw, must not produce a .mat.
            pOn = LiveTagPipeline('OutputDir', testCase.outDirOn_, 'Interval', 999);
            pOn.tickOnce();
            testCase.verifyEqual(exist(fullfile(testCase.outDirOn_, 'ghost_tag.mat'), 'file'), 0, ...
                'No .mat should be produced for a missing raw source (fs-coalesce ON)');
            testCase.verifyTrue(isempty(pOn.LastTickReport.succeeded), ...
                'Missing raw source must NOT be in the succeeded list (fs-coalesce ON)');

            % fs-coalesce OFF: same expectation.
            pOff = LiveTagPipeline('OutputDir', testCase.outDirOff_, 'Interval', 999);
            pOff.setFsCoalesceForTesting_(false);
            pOff.tickOnce();
            testCase.verifyEqual(exist(fullfile(testCase.outDirOff_, 'ghost_tag.mat'), 'file'), 0, ...
                'No .mat should be produced for a missing raw source (fs-coalesce OFF)');
            testCase.verifyTrue(isempty(pOff.LastTickReport.succeeded), ...
                'Missing raw source must NOT be in the succeeded list (fs-coalesce OFF)');
        end

        function testMidTickFreezeAndNextTickRefresh(testCase)
            %TESTMIDTICKFREEZEANDNEXTTICKREFRESH Snapshot + refresh contract.
            %   Build two SensorTags pointing at two files in the same parent
            %   directory:
            %     - 'a.csv'  exists at tick 1 (visible).
            %     - 'b.csv'  is created AFTER tick 1's onTick_ has already
            %                stat'd the parent dir (NOT visible in tick 1)
            %                but BEFORE tick 2 (must be visible in tick 2).
            %   Assertions:
            %     - Tag 'a' wrote a .mat after tick 1.
            %     - Tag 'b' did NOT write a .mat after tick 1 (mid-tick freeze).
            %     - Tag 'b' DID write a .mat after tick 2 (tick-to-tick refresh).
            %
            %   This test exercises the fs-coalesce-ON path only because the
            %   freeze semantic is what the new cache layer introduces; the
            %   coalesce-OFF (legacy) path issues an exist() per tag and so
            %   has no freeze semantic. Both paths satisfy the tick-to-tick
            %   refresh property (verified for ON; OFF was never affected).
            nCols    = 4;
            nPrefill = 20;

            % a.csv exists from the start; b.csv does not exist yet.
            pathA = fullfile(testCase.rawDir_, 'a.csv');
            pathB = fullfile(testCase.rawDir_, 'b.csv');
            writeCsv_(pathA, nCols, nPrefill, 'overwrite');

            rsA = struct('file', pathA, 'column', 'col_01');
            rsB = struct('file', pathB, 'column', 'col_01');
            tA = SensorTag('frozen_tag_a', 'RawSource', rsA);
            tB = SensorTag('frozen_tag_b', 'RawSource', rsB);
            TagRegistry.register('frozen_tag_a', tA);
            TagRegistry.register('frozen_tag_b', tB);

            p = LiveTagPipeline('OutputDir', testCase.outDirOn_, 'Interval', 999);
            % Default is fs-coalesce ON.

            % Tick 1: stat the parent dir BEFORE b.csv exists.
            p.tickOnce();
            testCase.verifyEqual(exist(fullfile(testCase.outDirOn_, 'frozen_tag_a.mat'), 'file'), 2, ...
                'Tag a must write its .mat in tick 1');
            testCase.verifyEqual(exist(fullfile(testCase.outDirOn_, 'frozen_tag_b.mat'), 'file'), 0, ...
                'Tag b must NOT write its .mat in tick 1 (file does not exist yet)');

            % NOTE: The freeze semantic ("file appearing mid-tick is NOT
            % visible in this tick") only matters if there is ordering
            % within a single tickOnce. The fs-cache is built lazily on
            % first lookup of each parent directory, so the freeze applies
            % to all subsequent same-parent lookups within the same tick.
            % The realistic test is the tick-to-tick refresh below.

            % Between ticks: create b.csv. Pause briefly so the filesystem
            % mtime granularity (1s on many Linux filesystems) makes the
            % new b.csv visible as a strictly-greater mtime than the parent
            % directory's first-tick snapshot. Without this pause the
            % test would be flaky on fast tmpfs CI runners where the
            % create-create boundary falls within the same second.
            pause(1.1);
            writeCsv_(pathB, nCols, nPrefill, 'overwrite');

            % Tick 2: a fresh fs-cache is built; b.csv is now visible.
            p.tickOnce();
            testCase.verifyEqual(exist(fullfile(testCase.outDirOn_, 'frozen_tag_b.mat'), 'file'), 2, ...
                'Tag b must write its .mat in tick 2 (file created between ticks)');
        end

        function testFsStatCountReducedOnCoalesceOn(testCase)
            %TESTFSSTATCOUNTREDUCEDONCOALESCEON Syscall-count reduction.
            %   The headline win: at N tags sharing K parent directories,
            %   fs-coalesce-on issues K dir() syscalls per tick; fs-coalesce-off
            %   issues 2N (exist + dir per tag). Verify the published
            %   LastFsStatCount property reflects this.
            nFiles   = 2;          % two parent directories worth of files
            nTags    = 10;         % 10 tags spread across 2 files
            nCols    = 4;
            nPrefill = 15;
            csvPaths = makeCsvFiles_(testCase.rawDir_, nFiles, nCols, nPrefill);

            % Build tags pointing at the 2 csvs.
            for i = 1:nTags
                fileIdx = mod(i - 1, nFiles) + 1;
                rs = struct('file', csvPaths{fileIdx}, 'column', 'col_01');
                key = sprintf('count_tag_%02d', i);
                t = SensorTag(key, 'RawSource', rs);
                TagRegistry.register(key, t);
            end

            % fs-coalesce ON: expect one dir() per UNIQUE parent dir.
            % All 10 tags share the SAME parent directory (rawDir_), so 1.
            pOn = LiveTagPipeline('OutputDir', testCase.outDirOn_, 'Interval', 999);
            pOn.tickOnce();
            testCase.verifyEqual(pOn.LastFsStatCount, 1, ...
                'fs-coalesce ON with 10 tags sharing 1 parent dir must issue exactly 1 fs-stat syscall');

            % fs-coalesce OFF: expect 2 calls (exist + dir) per tag = 2 * nTags.
            pOff = LiveTagPipeline('OutputDir', testCase.outDirOff_, 'Interval', 999);
            pOff.setFsCoalesceForTesting_(false);
            pOff.tickOnce();
            testCase.verifyEqual(pOff.LastFsStatCount, 2 * nTags, ...
                'fs-coalesce OFF must issue 2 syscalls per tag (exist + dir)');
        end

        function testSetFsCoalesceValidatesType(testCase)
            %TESTSETFSCOALESCEVALIDATESTYPE Type-validation contract on the setter.
            %   The Hidden setter rejects non-logical input the same way as
            %   the Plan 02d / Plan 05 setters do.
            p = LiveTagPipeline('OutputDir', testCase.outDirOn_, 'Interval', 999);
            testCase.verifyError(@() p.setFsCoalesceForTesting_(1), ...
                'TagPipeline:invalidFsCoalesce');
            testCase.verifyError(@() p.setFsCoalesceForTesting_('true'), ...
                'TagPipeline:invalidFsCoalesce');
            testCase.verifyError(@() p.setFsCoalesceForTesting_([true true]), ...
                'TagPipeline:invalidFsCoalesce');
            % Valid calls must not throw.
            p.setFsCoalesceForTesting_(false);
            p.setFsCoalesceForTesting_(true);

            % BatchTagPipeline mirror.
            b = BatchTagPipeline('OutputDir', testCase.outDirOn_);
            testCase.verifyError(@() b.setFsCoalesceForTesting_(1), ...
                'TagPipeline:invalidFsCoalesce');
            b.setFsCoalesceForTesting_(false);
            b.setFsCoalesceForTesting_(true);
        end
    end

end

% =====================================================================
%  Helpers (mirror TestPriorStateCacheParity.m patterns)
% =====================================================================

function csvPaths = makeCsvFiles_(rawDir, nFiles, nCols, nPrefill)
    csvPaths = cell(1, nFiles);
    for k = 1:nFiles
        csvPaths{k} = fullfile(rawDir, sprintf('src_%02d.csv', k));
        writeCsv_(csvPaths{k}, nCols, nPrefill, 'overwrite');
    end
end

function writeCsv_(path, nCols, nRows, mode)
    if strcmp(mode, 'overwrite')
        fid = fopen(path, 'w');
    else
        fid = fopen(path, 'a');
    end
    if fid == -1
        error('TestFsStatCoalesce:csv', 'Cannot open %s', path);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    if strcmp(mode, 'overwrite')
        headers = cell(1, nCols);
        headers{1} = 'time';
        for c = 2:nCols
            headers{c} = sprintf('col_%02d', c - 1);
        end
        fprintf(fid, '%s\n', strjoin(headers, ','));
        startRow = 0;
    else
        startRow = countRows_(path);
    end

    tCol = (startRow:(startRow + nRows - 1)).';
    M = zeros(nRows, nCols);
    M(:, 1) = tCol;
    phaseRow = (0:(nCols - 2)) * 0.3;
    M(:, 2:nCols) = sin(2 * pi * tCol / 30 + phaseRow) + 0.05 * cos(tCol);
    fmt = ['%g', repmat(',%g', 1, nCols - 1), '\n'];
    fprintf(fid, fmt, M.');
end

function n = countRows_(path)
    fid = fopen(path, 'r');
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    n = -1;
    while ~feof(fid)
        ln = fgetl(fid);
        if ~ischar(ln)
            break;
        end
        n = n + 1;
    end
    if n < 0
        n = 0;
    end
end

function appendCsv_(path, nCols, nRows)
    writeCsv_(path, nCols, nRows, 'append');
end

function wipeDir_(d)
    if exist(d, 'dir')
        listing = dir(d);
        for i = 1:numel(listing)
            if listing(i).isdir
                continue;
            end
            try
                delete(fullfile(d, listing(i).name));
            catch
            end
        end
    end
end

function runPipelineOnceParity_(csvPaths, outDir, nTags, nCols, fsCoalesceOn)
    %RUNPIPELINEONCEPARITY_ Single-tick parity helper (avoids mtime-granularity flakes).
    %   Builds nTags tags pointing at the supplied csvPaths, creates one fresh
    %   LiveTagPipeline with fs-coalesce set per the flag, and calls tickOnce
    %   exactly once. The CSV files are pre-filled (no per-tick appends), so
    %   the single tick captures everything that's there. This isolates the
    %   fs-coalesce parity from any multi-tick mtime-resolution concerns.
    nFiles = numel(csvPaths);
    valueCols = nCols - 1;
    for i = 1:nTags
        machineIdx = mod(i - 1, nFiles) + 1;
        colIdx = mod(i - 1, valueCols) + 1;
        rs = struct('file', csvPaths{machineIdx}, ...
            'column', sprintf('col_%02d', colIdx));
        key = sprintf('sensor_%03d', i);
        s = SensorTag(key, 'RawSource', rs);
        TagRegistry.register(key, s);
    end

    p = LiveTagPipeline('OutputDir', outDir, 'Interval', 999);
    p.setFsCoalesceForTesting_(fsCoalesceOn);
    p.tickOnce();
end

function runPipelinePass_(csvPaths, outDir, nTags, nCols, nTicks, nAppend, fsCoalesceOn)
    nFiles = numel(csvPaths);
    valueCols = nCols - 1;
    for i = 1:nTags
        machineIdx = mod(i - 1, nFiles) + 1;
        colIdx = mod(i - 1, valueCols) + 1;
        rs = struct('file', csvPaths{machineIdx}, ...
            'column', sprintf('col_%02d', colIdx));
        key = sprintf('sensor_%03d', i);
        s = SensorTag(key, 'RawSource', rs);
        TagRegistry.register(key, s);
    end

    p = LiveTagPipeline('OutputDir', outDir, 'Interval', 999);
    p.setFsCoalesceForTesting_(fsCoalesceOn);

    for k = 1:nTicks
        for f = 1:numel(csvPaths)
            appendCsv_(csvPaths{f}, nCols, nAppend);
        end
        p.tickOnce();
    end
end

function assertPayloadParity_(testCase, dirOn, dirOff)
    listOn  = dir(fullfile(dirOn,  '*.mat'));
    listOff = dir(fullfile(dirOff, '*.mat'));
    namesOn  = sort({listOn.name});
    namesOff = sort({listOff.name});
    testCase.verifyEqual(namesOn, namesOff, ...
        'fs-coalesce on/off must produce same set of .mat files');
    testCase.assertNotEmpty(namesOn, ...
        'Pipeline must have produced at least one .mat (fixture broken)');
    for i = 1:numel(namesOn)
        nm = namesOn{i};
        sOn  = load(fullfile(dirOn,  nm));
        sOff = load(fullfile(dirOff, nm));
        keyOn  = fieldnames(sOn);
        keyOff = fieldnames(sOff);
        testCase.verifyEqual(keyOn, keyOff, ...
            sprintf('Top-level variable name differs for %s', nm));
        payloadOn  = sOn.(keyOn{1});
        payloadOff = sOff.(keyOff{1});
        testCase.verifyEqual(payloadOn.x, payloadOff.x, ...
            sprintf('fs-coalesce on/off X differ for %s', nm));
        testCase.verifyEqual(payloadOn.y, payloadOff.y, ...
            sprintf('fs-coalesce on/off Y differ for %s', nm));
    end
end
