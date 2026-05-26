classdef TestPriorStateCacheParity < matlab.unittest.TestCase
    %TESTPRIORSTATECACHEPARITY Phase 1028 plan 02d parity contract.
    %   Asserts that the in-memory prior-state cache (cacheActive_=true,
    %   default) writes byte-equal .mat files to the cache-off path
    %   (cacheActive_=false, which routes through writeTagMat_('append',...)
    %   with a real on-disk load). This is the D-09 parity contract for
    %   the cache: any divergence in saved bytes is a bug.
    %
    %   Strategy:
    %     1. Build a small synthetic CSV-fed tag graph (3 source files, 12
    %        SensorTags, 3 StateTags — small enough for fast tests, large
    %        enough to exercise both numeric and cellstr Y).
    %     2. Run the pipeline 3 ticks twice — once with cacheActive_=true,
    %        once with cacheActive_=false — into two separate output dirs.
    %        Tick 1 cold-seeds the cache; ticks 2-3 exercise the warm path.
    %        A pause(1.1) sits between each tick because R2021b Linux
    %        `dir().datenum` has 1-second resolution and the pipeline's
    %        modTime<=lastModTime guard would otherwise silently skip
    %        ticks that land in the same wallclock second (see commit
    %        5cd6b23 for the same fix in TestFsStatCoalesce).
    %     3. For every tag, load both .mat files and assert isequal on x and
    %        y arrays. (Binary-equality of the .mat container itself is not
    %        enforced because save() may legitimately reorder unimportant
    %        metadata; payload-equality on the load result is the contract
    %        SensorTag.load actually depends on.)
    %
    %   See also: writeTagMatCached_, LiveTagPipeline.processTag_,
    %             writeTagMat_ (the cache-off reference path).

    properties (Access = private)
        rawDir_      char = ''
        outDirOn_    char = ''
        outDirOff_   char = ''
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            install();
        end
    end

    methods (TestMethodSetup)
        function setupDirs(testCase)
            TagRegistry.clear();
            base = tempname();
            testCase.rawDir_   = sprintf('%s_raw', base);
            testCase.outDirOn_ = sprintf('%s_on',  base);
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
        function testCacheOnOffByteEqualSensors(testCase)
            % Numeric SensorTag fan-out, 3 ticks (was 10), append mode.
            %
            % Tick count reduction + per-tick pause(1.1) below address an
            % R2021b Linux mtime-granularity flake (same root cause as
            % commit 5cd6b23's TestFsStatCoalesce fix). On Linux R2021b CI,
            % `dir().datenum` has 1-second resolution. The pipeline's
            % mtime guard (LiveTagPipeline.processTag_ line 580) skips
            % a tick when `modTime <= state.lastModTime`. Cache-on ticks
            % run faster than cache-off ticks (the entire point of Plan 02d
            % — cache-on skips load+save), so cache-on completes its loop
            % within a single wallclock second more often than cache-off,
            % producing fewer processed ticks. The asymmetric skip counts
            % yielded different on-disk row counts even though the cache
            % mechanism itself is byte-equal to the disk path.
            %
            % Three ticks is enough to exercise the warm-cache path
            % (tick 1 = cold seed; ticks 2-3 = warm); the parity contract
            % does not require many ticks, only that the warm path runs
            % at least once.
            nFiles  = 3;
            nTags   = 12;
            nTicks  = 3;
            nPrefill = 50;
            nAppend  = 20;
            nCols    = 6;

            csvPaths = makeCsvFiles_(testCase.rawDir_, nFiles, nCols, nPrefill);

            % Run cache-ON pass.
            runPipelinePass_(csvPaths, testCase.outDirOn_, ...
                nTags, nCols, nTicks, nAppend, true);

            % Reset CSV files + registry between passes so the second pass
            % sees identical inputs to the first.
            TagRegistry.clear();
            csvPaths = makeCsvFiles_(testCase.rawDir_, nFiles, nCols, nPrefill);
            runPipelinePass_(csvPaths, testCase.outDirOff_, ...
                nTags, nCols, nTicks, nAppend, false);

            % Assert byte-equal payloads for every tag.
            assertCacheParity_(testCase, testCase.outDirOn_, testCase.outDirOff_);
        end

        function testCacheOnOffByteEqualStateTags(testCase)
            % StateTag exercises the cellstr-Y branch of writeTagMatCached_.
            % Run a smaller fixture but include states. Same 3-tick + pause
            % R2021b-mtime-granularity fix as testCacheOnOffByteEqualSensors.
            nFiles  = 2;
            nTicks  = 3;
            nPrefill = 30;
            nAppend  = 10;
            nCols    = 5;

            csvPaths = makeCsvFiles_(testCase.rawDir_, nFiles, nCols, nPrefill);

            runStatePipelinePass_(csvPaths, testCase.outDirOn_, ...
                nCols, nTicks, nAppend, true);

            TagRegistry.clear();
            csvPaths = makeCsvFiles_(testCase.rawDir_, nFiles, nCols, nPrefill);
            runStatePipelinePass_(csvPaths, testCase.outDirOff_, ...
                nCols, nTicks, nAppend, false);

            assertCacheParity_(testCase, testCase.outDirOn_, testCase.outDirOff_);
        end

        function testCacheActiveDefaultIsTrue(testCase)
            % Production default must be cache-ON. Construct a fresh
            % pipeline and verify cacheActive_ is true via behavior:
            % run one tick on a fresh outdir and confirm the .mat exists.
            csvPaths = makeCsvFiles_(testCase.rawDir_, 1, 4, 20);
            rs = struct('file', csvPaths{1}, 'column', 'col_01');
            t = SensorTag('default_check', 'RawSource', rs);
            TagRegistry.register('default_check', t);

            p = LiveTagPipeline('OutputDir', testCase.outDirOn_, 'Interval', 999);
            % No setCacheActiveForTesting_ call; default must hold.
            p.tickOnce();

            outFile = fullfile(testCase.outDirOn_, 'default_check.mat');
            testCase.verifyEqual(exist(outFile, 'file'), 2, ...
                'Production default cache-on path must still write the .mat');
        end

        function testSetCacheActiveValidatesType(testCase)
            % The setter must reject non-logical input.
            p = LiveTagPipeline('OutputDir', testCase.outDirOn_, 'Interval', 999);
            testCase.verifyError(@() p.setCacheActiveForTesting_(1), ...
                'TagPipeline:invalidCacheActive');
            testCase.verifyError(@() p.setCacheActiveForTesting_('true'), ...
                'TagPipeline:invalidCacheActive');
            testCase.verifyError(@() p.setCacheActiveForTesting_([true true]), ...
                'TagPipeline:invalidCacheActive');
            % Valid call must not throw.
            p.setCacheActiveForTesting_(false);
            p.setCacheActiveForTesting_(true);
        end
    end

end

% =====================================================================
%  Helpers
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
        error('TestPriorStateCacheParity:csv', 'Cannot open %s', path);
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
    % Quick row counter for header + data lines; we want existing data row count.
    fid = fopen(path, 'r');
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    n = -1;  % subtract header
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

function runPipelinePass_(csvPaths, outDir, nTags, nCols, nTicks, nAppend, cacheOn)
    % Build SensorTags.
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
    p.setCacheActiveForTesting_(cacheOn);

    for k = 1:nTicks
        if k > 1
            % R2021b Linux dir().datenum has 1-second resolution. Without
            % this pause, fast appends in the same wallclock second produce
            % an unchanged mtime and the pipeline's modTime<=lastModTime
            % guard (LiveTagPipeline.processTag_ line 580) silently skips
            % the tick. The cache-on path runs faster than cache-off (the
            % whole point of Plan 02d), so cache-on completes more ticks
            % within a single second than cache-off, yielding asymmetric
            % skip counts and different on-disk row counts. Pausing >1s
            % between appends guarantees the mtime advances strictly.
            % See commit 5cd6b23 for the equivalent TestFsStatCoalesce fix.
            pause(1.1);
        end
        for f = 1:numel(csvPaths)
            appendCsv_(csvPaths{f}, nCols, nAppend);
        end
        p.tickOnce();
    end
end

function runStatePipelinePass_(csvPaths, outDir, nCols, nTicks, nAppend, cacheOn)
    % Build a mix of SensorTag + StateTag so the cellstr-Y path is exercised.
    nFiles = numel(csvPaths);
    valueCols = nCols - 1;
    nSensor = 4;
    nState  = 3;
    for i = 1:nSensor
        machineIdx = mod(i - 1, nFiles) + 1;
        colIdx = mod(i - 1, valueCols) + 1;
        rs = struct('file', csvPaths{machineIdx}, ...
            'column', sprintf('col_%02d', colIdx));
        key = sprintf('sensor_%03d', i);
        s = SensorTag(key, 'RawSource', rs);
        TagRegistry.register(key, s);
    end
    for i = 1:nState
        machineIdx = mod(i - 1, nFiles) + 1;
        colIdx = mod(i + nSensor - 1, valueCols) + 1;
        rs = struct('file', csvPaths{machineIdx}, ...
            'column', sprintf('col_%02d', colIdx));
        key = sprintf('state_%03d', i);
        st = StateTag(key, 'RawSource', rs);
        TagRegistry.register(key, st);
    end

    p = LiveTagPipeline('OutputDir', outDir, 'Interval', 999);
    p.setCacheActiveForTesting_(cacheOn);

    for k = 1:nTicks
        if k > 1
            % See runPipelinePass_ for the R2021b mtime-granularity rationale.
            pause(1.1);
        end
        for f = 1:numel(csvPaths)
            appendCsv_(csvPaths{f}, nCols, nAppend);
        end
        p.tickOnce();
    end
end

function assertCacheParity_(testCase, dirOn, dirOff)
    % Compare every .mat file in dirOn against the same-name file in dirOff.
    listOn = dir(fullfile(dirOn, '*.mat'));
    listOff = dir(fullfile(dirOff, '*.mat'));

    namesOn  = sort({listOn.name});
    namesOff = sort({listOff.name});
    testCase.verifyEqual(namesOn, namesOff, ...
        'Cache-on and cache-off output dirs must contain the same set of .mat files');
    testCase.assertNotEmpty(namesOn, ...
        'Pipeline must have produced at least one .mat (test fixture broken)');

    for i = 1:numel(namesOn)
        nm = namesOn{i};
        pathOn  = fullfile(dirOn,  nm);
        pathOff = fullfile(dirOff, nm);

        sOn  = load(pathOn);
        sOff = load(pathOff);

        % Each .mat has a single top-level struct named after the tag key.
        keyOn  = fieldnames(sOn);
        keyOff = fieldnames(sOff);
        testCase.verifyEqual(keyOn, keyOff, ...
            sprintf('Top-level variable name differs between cache-on/off for %s', nm));

        payloadOn  = sOn.(keyOn{1});
        payloadOff = sOff.(keyOff{1});

        testCase.verifyTrue(isstruct(payloadOn) && isstruct(payloadOff), ...
            sprintf('Payload must be a struct for %s', nm));
        testCase.verifyEqual(sort(fieldnames(payloadOn)), sort(fieldnames(payloadOff)), ...
            sprintf('Payload fields differ between cache-on/off for %s', nm));

        % Strict equality on x (numeric).
        testCase.verifyEqual(payloadOn.x, payloadOff.x, ...
            sprintf('Cache-on/off X arrays differ for %s', nm));
        % Strict equality on y (numeric or cellstr).
        testCase.verifyEqual(payloadOn.y, payloadOff.y, ...
            sprintf('Cache-on/off Y arrays differ for %s', nm));

        % Defensive size check (catches the case where both happen to be
        % equal-but-empty due to a fixture bug).
        testCase.verifyGreaterThan(numel(payloadOn.x), 0, ...
            sprintf('X array unexpectedly empty for %s', nm));
    end
end
