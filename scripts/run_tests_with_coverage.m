function run_tests_with_coverage(pattern, batchPattern)
%RUN_TESTS_WITH_COVERAGE Run tests with code coverage and generate Cobertura XML.
%   run_tests_with_coverage(PATTERN) restricts the run to test files whose
%   short name matches the regular expression PATTERN. Empty/missing PATTERN
%   runs the full suite. Used by CI for path-filtered PR runs.
%
%   run_tests_with_coverage(PATTERN, BATCHPATTERN) additionally filters by
%   BATCHPATTERN (also a regex). A test is run only when its short name
%   matches BOTH patterns. CI uses this to split the suite across multiple
%   matrix jobs so each MATLAB process sees a bounded test load — a
%   workaround for cumulative R2021b headless-Linux state corruption that
%   surfaces as segfaults late in long runs. Empty/missing BATCHPATTERN
%   means "no batch filter applied" (compatible with the legacy 1-arg
%   signature).
%
%   Coverage XML is emitted to coverage.xml (the workflow uploads it to
%   Codecov with a batch-tagged flag so partial coverage across batches
%   merges cleanly on the Codecov side).
    import matlab.unittest.TestSuite
    import matlab.unittest.TestRunner
    import matlab.unittest.plugins.CodeCoveragePlugin
    import matlab.unittest.plugins.codecoverage.CoberturaFormat

    if nargin < 1 || isempty(pattern)
        pattern = '';
    end
    if nargin < 2 || isempty(batchPattern)
        batchPattern = '';
    end

    test_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'tests');
    repo_root = fullfile(test_dir, '..');
    addpath(repo_root);
    install();

    % Sentinel file the CI workflow checks after this script runs. We
    % delete it up front and only write it on success below — see the
    % "force-quit" comment near the end of this file. CI uses this
    % instead of MATLAB's exit code because R2021b reproducibly
    % segfaults during shutdown after our script returns, even when
    % every test passes.
    sentinelFile = fullfile(repo_root, '.matlab-tests-passed');
    if exist(sentinelFile, 'file')
        delete(sentinelFile);
    end

    suite_dir = fullfile(test_dir, 'suite');
    addpath(suite_dir);

    suite = TestSuite.fromFolder(suite_dir);
    if ~isempty(pattern)
        fprintf('Filtering tests by pattern: %s\n', pattern);
        names = {suite.Name};
        keep = ~cellfun(@isempty, regexp(names, pattern, 'once'));
        suite = suite(keep);
        if isempty(suite)
            fprintf('No tests matched pattern; nothing to run.\n');
            % Still write the sentinel so the CI step succeeds — an empty
            % match after narrowing is a valid no-op, not a failure.
            writeSentinel_(repo_root);
            return;
        end
        fprintf('Running %d test methods after filtering.\n', numel(suite));
    end
    if ~isempty(batchPattern)
        fprintf('Applying batch filter: %s\n', batchPattern);
        names = {suite.Name};
        keep = ~cellfun(@isempty, regexp(names, batchPattern, 'once'));
        suite = suite(keep);
        if isempty(suite)
            fprintf('No tests matched batch pattern; nothing to run.\n');
            writeSentinel_(repo_root);
            return;
        end
        fprintf('Running %d test methods in this batch.\n', numel(suite));
    end
    runner = TestRunner.withTextOutput;

    % Add code coverage for all library source files
    sourceFiles = {};
    libDirs = {'FastSense', 'SensorThreshold', 'EventDetection', 'Dashboard', 'WebBridge'};
    for i = 1:numel(libDirs)
        libPath = fullfile(repo_root, 'libs', libDirs{i});
        files = dir(fullfile(libPath, '*.m'));
        for j = 1:numel(files)
            sourceFiles{end+1} = fullfile(libPath, files(j).name);
        end
    end

    coverageFile = fullfile(repo_root, 'coverage.xml');
    runner.addPlugin(CodeCoveragePlugin.forFile(sourceFiles, ...
        'Producing', CoberturaFormat(coverageFile)));

    results = runner.run(suite);

    nFailed = sum([results.Failed]);
    if nFailed > 0
        error('Tests failed: %d', nFailed);
    end

    % All tests passed (or were filtered by assumption). Write the
    % sentinel file so CI knows the run was clean even if MATLAB
    % subsequently segfaults during shutdown.
    %
    % Background: on R2021b headless Linux MATLAB reproducibly crashes
    % during exit cleanup after our script returns — stack lands in
    % libmwbridge.so / Mfh_file::dispatch (the same MATLAB-internals
    % dispatcher bug that drove the gateHeadlessLinux skips in
    % tests/suite/). matlab-actions/run-command sees the non-zero exit
    % code and fails the step, even though the test run itself was
    % clean. The CI workflow checks this sentinel file after the
    % matlab-actions step (with continue-on-error) and decides
    % pass/fail based on its presence.
    writeSentinel_(repo_root);
end

function writeSentinel_(repo_root)
%WRITESENTINEL_ Write the .matlab-tests-passed sentinel file.
%   Factored out so both the all-passed exit and the empty-match exits
%   (after filtering produces no tests) write the same sentinel — both
%   are valid "no failures" outcomes from CI's perspective.
    sentinelFile = fullfile(repo_root, '.matlab-tests-passed');
    fid = fopen(sentinelFile, 'w');
    if fid ~= -1
        fprintf(fid, 'pass\n');
        fclose(fid);
    end
end
