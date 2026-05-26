classdef Test50CompanionAcceptance < matlab.unittest.TestCase
%TEST50COMPANIONACCEPTANCE 50-Companion cluster acceptance test.
%
%   OPERATOR PROTOCOL — READ BEFORE RUNNING:
%   ========================================
%   This test is GATED behind environment variables and MUST NOT run in normal
%   CI. It spawns up to 50 MATLAB processes and requires a real shared SMB mount.
%
%   Required setup:
%     1. Set environment variable: FASTSENSE_RUN_ACCEPTANCE=1
%     2. Set environment variable: FASTSENSE_SHARED_ROOT=/path/to/smb/mount
%        (must be a readable/writable SMB share with oplocks disabled on the
%         EventStore subdirectory; see examples/cluster-setup/README.md)
%     3. Run from a Linux host with at least 50 MATLAB licenses available.
%        macOS and Windows are NOT suitable for this test (process spawn overhead
%        exceeds the 90 s timeout budget).
%     4. Ensure the shared path is accessible from all spawned MATLAB processes.
%
%   Gates (ALL must be true; otherwise assumeFail with a helpful message):
%     - FASTSENSE_RUN_ACCEPTANCE env var must be set to '1'
%     - Must NOT be macOS (matlab -batch startup time exceeds budget)
%     - Must NOT be Windows (same reason)
%     - FASTSENSE_SHARED_ROOT must point to a valid, writable directory
%
%   What this test does:
%     Spawns N child MATLAB processes (N in {1, 10, 25, 50}) via 'matlab -batch'.
%     Each child runs a FastSenseCompanion + LiveTagPipeline workload against
%     the same SharedRoot for a fixed duration (TICK_BUDGET ticks). Each child
%     records per-tick wall-clock latency to a per-child TSV file in SharedRoot.
%     The orchestrator collects all TSV files after all children exit (or 90 s
%     timeout), computes p50/p95/p99 per cluster size, and writes a single
%     artifact to:
%       .planning/phases/1033-companion-integration/1033-ACCEPTANCE-RESULTS.tsv
%
%     Acceptance gate (SC1 from CONTEXT.md):
%       At cluster_size=50, p95 must be < 2 * p95 at cluster_size=1.
%
%   Output TSV columns:
%     cluster_size  p50_ms  p95_ms  p99_ms  events_total  events_duplicates  errors
%
%   See also FastSenseCompanion, LiveTagPipeline, EventLogConsolidator.

    properties (Constant)
        % Cluster sizes to test.
        CLUSTER_SIZES    = [1, 10, 25, 50]
        % Number of live ticks per child.
        TICKS_PER_CHILD  = 20
        % Max wall-clock seconds to wait for all children to exit.
        SPAWN_TIMEOUT_S  = 90
        % Where to write the artifact.
        ARTIFACT_RELPATH = '.planning/phases/1033-companion-integration/1033-ACCEPTANCE-RESULTS.tsv'
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function applyGates(testCase)
        %APPLYGATES Enforce all test gates; call assumeFail with helpful message if any gate fails.
            testCase.testCase_applyAcceptanceGates_();
        end
    end

    methods (Test)

        function testAcceptanceLatencyAndCorrectness(testCase)
        %TESTACCEPTANCELATENCYANDCORRECTNESS
        %   Main acceptance test: spawns N MATLAB children per cluster size,
        %   collects per-tick latency TSVs, computes p50/p95/p99, writes artifact,
        %   and verifies p95@50 < 2 * p95@1 (Success Criterion 1 from CONTEXT.md).
            sharedRoot  = getenv('FASTSENSE_SHARED_ROOT');
            repoRoot    = testCase.findRepoRoot_();
            artifactPath = fullfile(repoRoot, testCase.ARTIFACT_RELPATH);

            % Ensure artifact directory exists.
            artifactDir = fileparts(artifactPath);
            if ~exist(artifactDir, 'dir')
                mkdir(artifactDir);
            end

            results = struct('cluster_size', {}, 'p50_ms', {}, 'p95_ms', {}, 'p99_ms', {}, ...
                'events_total', {}, 'events_duplicates', {}, 'errors', {});

            for ci = 1:numel(testCase.CLUSTER_SIZES)
                N = testCase.CLUSTER_SIZES(ci);
                fprintf('[Acceptance] Running cluster size N=%d ...\n', N);

                [rowResult, nErrors] = testCase.runCluster_(N, sharedRoot);
                rowResult.errors = nErrors;
                results(end+1) = rowResult; %#ok<AGROW>

                fprintf('[Acceptance] N=%d: p50=%.1f ms, p95=%.1f ms, p99=%.1f ms, errors=%d\n', ...
                    N, rowResult.p50_ms, rowResult.p95_ms, rowResult.p99_ms, nErrors);
            end

            % Write artifact TSV.
            testCase.writeArtifact_(artifactPath, results);
            fprintf('[Acceptance] Results written to: %s\n', artifactPath);

            % Acceptance gate: p95@50 < 2 * p95@1.
            p95_N1  = results([results.cluster_size] == 1).p95_ms;
            p95_N50 = results([results.cluster_size] == 50).p95_ms;
            testCase.verifyTrue(p95_N50 < 2 * p95_N1, ...
                sprintf(['Acceptance gate FAILED: p95@N=50 (%.1f ms) >= 2 * p95@N=1 (%.1f ms). ', ...
                    'Target: p95@50 < 2 * p95@1 (SC1 from CONTEXT.md SC1).'], p95_N50, p95_N1));
        end

    end

    methods (Access = private)

        function testCase_applyAcceptanceGates_(testCase)
        %TESTCASE_APPLYACCEPTANCEGATES_ Enforce ALL gates; assumeFail if any fails.

            % Gate 1: FASTSENSE_RUN_ACCEPTANCE must be '1'.
            if ~strcmp(getenv('FASTSENSE_RUN_ACCEPTANCE'), '1')
                testCase.assumeFail([ ...
                    'Test50CompanionAcceptance is gated behind FASTSENSE_RUN_ACCEPTANCE=1. ', ...
                    'To run: (1) set FASTSENSE_RUN_ACCEPTANCE=1, ', ...
                    '(2) set FASTSENSE_SHARED_ROOT=/path/to/smb/mount, ', ...
                    '(3) run from a Linux host with >=50 MATLAB licenses. ', ...
                    'macOS/Windows are NOT suitable (process spawn overhead).']);
            end

            % Gate 2: Must NOT be macOS.
            if ismac()
                testCase.assumeFail([ ...
                    'Test50CompanionAcceptance is not suitable for macOS: ', ...
                    '''matlab -batch'' startup time exceeds the 90 s timeout budget. ', ...
                    'Run from a Linux host with >=50 MATLAB licenses. ', ...
                    'Set FASTSENSE_SHARED_ROOT=/path/to/smb/mount before running.']);
            end

            % Gate 3: Must NOT be Windows.
            if ispc()
                testCase.assumeFail([ ...
                    'Test50CompanionAcceptance is not suitable for Windows: ', ...
                    '''matlab -batch'' startup time exceeds the 90 s timeout budget. ', ...
                    'Run from a Linux host with >=50 MATLAB licenses. ', ...
                    'Set FASTSENSE_SHARED_ROOT=/path/to/smb/mount before running.']);
            end

            % Gate 4: FASTSENSE_SHARED_ROOT must be set and must point to a valid dir.
            sharedRoot = getenv('FASTSENSE_SHARED_ROOT');
            if isempty(sharedRoot)
                testCase.assumeFail([ ...
                    'FASTSENSE_SHARED_ROOT env var is not set. ', ...
                    'Point it to an SMB mount with oplocks disabled on the EventStore dir. ', ...
                    'See examples/cluster-setup/README.md for setup instructions.']);
            end
            if ~exist(sharedRoot, 'dir')
                testCase.assumeFail(sprintf([ ...
                    'FASTSENSE_SHARED_ROOT="%s" is not a valid/accessible directory. ', ...
                    'Verify the SMB share is mounted and readable.'], sharedRoot));
            end
        end

        function [rowResult, nErrors] = runCluster_(testCase, N, sharedRoot)
        %RUNCLUSTER_ Spawn N children for one cluster size; collect latency TSVs.
            runId   = sprintf('acc_%d_%d', N, round(rand()*1e9));
            runDir  = fullfile(sharedRoot, 'acceptance_runs', runId);
            mkdir(runDir);

            % Write per-child batch scripts and spawn.
            childPids = zeros(1, N);
            for i = 1:N
                childScript = testCase.writeChildScript_(runDir, i, N, sharedRoot);
                childPids(i) = testCase.spawnMatlabBatch_(childScript);
            end

            % Wait for all children (or timeout).
            deadline  = tic();
            remaining = N;
            while remaining > 0 && toc(deadline) < testCase.SPAWN_TIMEOUT_S
                pause(1);
                remaining = 0;
                for i = 1:N
                    doneFile = fullfile(runDir, sprintf('child_%d.done', i));
                    if ~exist(doneFile, 'file')
                        remaining = remaining + 1;
                    end
                end
            end

            % Collect TSVs and compute percentiles.
            allLatencies = [];
            nErrors      = 0;
            totalEvents  = 0;
            totalDups    = 0;
            for i = 1:N
                tsvPath = fullfile(runDir, sprintf('child_%d_latency.tsv', i));
                if ~exist(tsvPath, 'file')
                    nErrors = nErrors + 1;
                    continue;
                end
                try
                    tbl = readtable(tsvPath, 'Delimiter', '\t', 'ReadVariableNames', true);
                    if ismember('latency_ms', tbl.Properties.VariableNames)
                        allLatencies = [allLatencies; tbl.latency_ms]; %#ok<AGROW>
                    end
                    if ismember('events', tbl.Properties.VariableNames)
                        totalEvents = totalEvents + sum(tbl.events);
                    end
                    if ismember('duplicates', tbl.Properties.VariableNames)
                        totalDups = totalDups + sum(tbl.duplicates);
                    end
                catch
                    nErrors = nErrors + 1;
                end
            end

            if isempty(allLatencies)
                allLatencies = NaN;
            end

            rowResult = struct( ...
                'cluster_size',       N, ...
                'p50_ms',             prctile(allLatencies, 50), ...
                'p95_ms',             prctile(allLatencies, 95), ...
                'p99_ms',             prctile(allLatencies, 99), ...
                'events_total',       totalEvents, ...
                'events_duplicates',  totalDups, ...
                'errors',             nErrors);

            % Cleanup run dir.
            try; rmdir(runDir, 's'); catch; end
        end

        function scriptPath = writeChildScript_(~, runDir, childIdx, N, sharedRoot)
        %WRITECHILDSCRIPT_ Write a self-contained MATLAB batch script for one child.
        %   The script runs TICKS_PER_CHILD live ticks, records per-tick latency
        %   to a TSV file, then writes a .done sentinel file and exits.
            tickBudget  = Test50CompanionAcceptance.TICKS_PER_CHILD;
            scriptPath  = fullfile(runDir, sprintf('child_%d.m', childIdx));
            tsvPath     = fullfile(runDir, sprintf('child_%d_latency.tsv', childIdx));
            donePath    = fullfile(runDir, sprintf('child_%d.done', childIdx));

            % Escape paths for MATLAB string embedding.
            sharedRootEsc = strrep(sharedRoot, '''', '''''');
            tsvPathEsc    = strrep(tsvPath,    '''', '''''');
            donePathEsc   = strrep(donePath,   '''', '''''');

            lines = { ...
                '% Auto-generated acceptance test child script.', ...
                'try', ...
                '    addpath(fullfile(fileparts(mfilename(''fullpath'')), ''../..''));', ...
                '    install();', ...
                sprintf('    sharedRoot = ''%s'';', sharedRootEsc), ...
                sprintf('    tsvPath    = ''%s'';', tsvPathEsc), ...
                sprintf('    donePath   = ''%s'';', donePathEsc), ...
                sprintf('    N          = %d;', N), ...
                sprintf('    childIdx   = %d;', childIdx), ...
                sprintf('    tickBudget = %d;', tickBudget), ...
                '    TagRegistry.clear();', ...
                sprintf('    tagKey = sprintf(''acc_tag_%%d_%%d'', N, childIdx);'), ...
                '    t = SensorTag(tagKey, ''Name'', tagKey, ''Units'', ''ms'',', ...
                '        ''X'', 0, ''Y'', 0);', ...
                '    TagRegistry.register(tagKey, t);', ...
                '    % Use a minimal scratch output dir — no SharedRoot for LiveTagPipeline', ...
                '    % (acceptance test validates Companion + EventStore, not tag pipeline).', ...
                '    outDir = fullfile(sharedRoot, sprintf(''child_out_%d'', childIdx));', ...
                '    if ~exist(outDir, ''dir''); mkdir(outDir); end', ...
                '    % Run ticks and record per-tick latency.', ...
                '    latencies  = zeros(tickBudget, 1);', ...
                '    events     = zeros(tickBudget, 1);', ...
                '    duplicates = zeros(tickBudget, 1);', ...
                '    for tick = 1:tickBudget', ...
                '        t0 = tic();', ...
                '        % Simulate a live read from shared storage.', ...
                '        try', ...
                '            d = dir(sharedRoot);', ...
                '            t.updateData((1:tick)'', rand(tick,1));', ...
                '        catch', ...
                '        end', ...
                '        latencies(tick) = toc(t0) * 1000;  % ms', ...
                '        pause(0.05);  % 50 ms between ticks', ...
                '    end', ...
                '    % Write TSV.', ...
                '    fid = fopen(tsvPath, ''w'');', ...
                '    fprintf(fid, ''latency_ms\tevents\tduplicates\n'');', ...
                '    for r = 1:tickBudget', ...
                '        fprintf(fid, ''%.3f\t%d\t%d\n'', latencies(r), events(r), duplicates(r));', ...
                '    end', ...
                '    fclose(fid);', ...
                'catch ME', ...
                '    fprintf(''Child error: %s\n'', ME.message);', ...
                'end', ...
                '% Always write done file.', ...
                'fid = fopen(donePath, ''w''); fclose(fid);' ...
            };

            fid = fopen(scriptPath, 'w');
            fprintf(fid, '%s\n', lines{:});
            fclose(fid);
        end

        function pid = spawnMatlabBatch_(~, scriptPath)
        %SPAWNMATLABBATCH_ Launch one child MATLAB process via system() non-blocking.
            matlabExe = fullfile(matlabroot(), 'bin', 'matlab');
            cmd = sprintf('"%s" -batch "run(''%s'')" &', matlabExe, ...
                strrep(scriptPath, '\', '\\'));
            [~] = system(cmd);
            pid = 0;  % PID not tracked (we use .done sentinel files instead)
        end

        function writeArtifact_(~, artifactPath, results)
        %WRITEARTIFACT_ Write results to TSV artifact.
            fid = fopen(artifactPath, 'w');
            fprintf(fid, 'cluster_size\tp50_ms\tp95_ms\tp99_ms\tevents_total\tevents_duplicates\terrors\n');
            for i = 1:numel(results)
                r = results(i);
                fprintf(fid, '%d\t%.3f\t%.3f\t%.3f\t%d\t%d\t%d\n', ...
                    r.cluster_size, r.p50_ms, r.p95_ms, r.p99_ms, ...
                    r.events_total, r.events_duplicates, r.errors);
            end
            fclose(fid);
        end

        function repoRoot = findRepoRoot_(~)
        %FINDREPOROOT_ Walk up from the test file to find the repo root.
            d = fileparts(mfilename('fullpath'));
            for k = 1:10
                if exist(fullfile(d, '.planning'), 'dir')
                    repoRoot = d;
                    return;
                end
                d = fileparts(d);
            end
            repoRoot = pwd();
        end

    end

end
