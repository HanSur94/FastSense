function run_tests_with_coverage(pattern)
%RUN_TESTS_WITH_COVERAGE Run tests with code coverage and generate Cobertura XML.
%   run_tests_with_coverage(PATTERN) restricts the run to test files whose
%   short name matches the regular expression PATTERN. Empty/missing PATTERN
%   runs the full suite. Used by CI for path-filtered PR runs.
    import matlab.unittest.TestSuite
    import matlab.unittest.TestRunner
    import matlab.unittest.plugins.CodeCoveragePlugin
    import matlab.unittest.plugins.codecoverage.CoberturaFormat

    if nargin < 1 || isempty(pattern)
        pattern = '';
    end

    test_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'tests');
    repo_root = fullfile(test_dir, '..');
    addpath(repo_root);
    install();

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
            return;
        end
        fprintf('Running %d test methods after filtering.\n', numel(suite));
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
end
