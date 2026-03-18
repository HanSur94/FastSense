function results = run_all_tests()
%RUN_ALL_TESTS Execute all FastSense unit tests.
%   On MATLAB: runs the class-based test suite in tests/suite/ using
%   matlab.unittest.  On Octave: runs function-based test_*.m files.
%
%   results = run_all_tests() returns a struct with total/passed/failed
%   counts (Octave) or a matlab.unittest.TestResult array (MATLAB).
%
%   Example:
%     results = run_all_tests();

    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();

    if exist('OCTAVE_VERSION', 'builtin')
        results = run_octave_tests(test_dir);
    else
        results = run_matlab_suite(test_dir);
    end
end

function results = run_matlab_suite(test_dir)
%RUN_MATLAB_SUITE Run class-based test suite using matlab.unittest.
    import matlab.unittest.TestSuite
    import matlab.unittest.TestRunner
    import matlab.unittest.plugins.DiagnosticsValidationPlugin

    suite_dir = fullfile(test_dir, 'suite');
    addpath(suite_dir);

    fprintf('=== FastSense Test Suite (MATLAB) ===\n\n');

    suite = TestSuite.fromFolder(suite_dir);

    if isempty(suite)
        fprintf('No tests found in %s\n', suite_dir);
        results = [];
        return;
    end

    fprintf('Discovered %d test methods across %d test files.\n\n', ...
        numel(suite), numel(unique({suite.Name})));

    runner = TestRunner.withTextOutput;
    results = runner.run(suite);

    % Summary
    nPassed = sum([results.Passed]);
    nFailed = sum([results.Failed]);
    nIncomplete = sum([results.Incomplete]);
    nTotal = numel(results);

    fprintf('\n=== Results: %d/%d passed', nPassed, nTotal);
    if nFailed > 0
        fprintf(', %d failed', nFailed);
    end
    if nIncomplete > 0
        fprintf(', %d incomplete (skipped)', nIncomplete);
    end
    fprintf(' ===\n');

    if nFailed > 0
        fprintf('\nFailed tests:\n');
        for i = 1:nTotal
            if results(i).Failed
                fprintf('  - %s\n', results(i).Name);
            end
        end
    end
end

function results = run_octave_tests(test_dir)
%RUN_OCTAVE_TESTS Run function-based tests for Octave compatibility.
%   Each test runs in a separate Octave subprocess to survive the known
%   Octave 8.x crash during handle-class cleanup (break_closure_cycles).
    files = dir(fullfile(test_dir, 'test_*.m'));
    repo_root = fileparts(test_dir);

    total = 0;
    passed = 0;
    failed = 0;
    failures = {};
    marker = '__OCTAVE_TEST_PASSED__';
    newline_char = sprintf('\n');

    fprintf('=== FastSense Test Suite (Octave – subprocess isolation) ===\n\n');
    fprintf('Discovered %d test files.\n\n', numel(files));

    for i = 1:numel(files)
        [~, name, ~] = fileparts(files(i).name);
        fprintf('Running %s...\n', name);

        % Run each test in an isolated subprocess so that an Octave
        % crash (e.g. break_closure_cycles) cannot kill the suite.
        eval_str = sprintf( ...
            'addpath(''%s''); install(); cd(''%s''); add_fastsense_private_path(); %s(); fprintf(''%s\\n'');', ...
            repo_root, test_dir, name, marker);
        cmd = sprintf( ...
            'octave --no-gui --no-init-file --quiet --eval "%s" 2>&1', ...
            eval_str);
        [status, output] = system(cmd);

        % Parse output: look for success marker, strip noise
        lines = strsplit(output, newline_char);
        clean = {};
        test_ok = false;
        for j = 1:numel(lines)
            ln = lines{j};
            if strcmp(strtrim(ln), marker)
                test_ok = true;
                continue;
            end
            if isempty(strtrim(ln)); continue; end
            if strncmp(ln, 'octave:', 7); continue; end
            clean{end+1} = ln;
        end

        for j = 1:numel(clean)
            fprintf('    %s\n', clean{j});
        end

        if test_ok
            fprintf('  PASSED\n');
            passed = passed + 1;
        else
            fprintf('  FAILED (exit code %d)\n', status);
            failed = failed + 1;
            failures{end+1} = sprintf('%s: %s', name, ...
                strjoin(clean, ' | '));
        end
        total = total + 1;

        % Write results incrementally so they survive crashes
        resultsFile = getenv('FASTSENSE_RESULTS_FILE');
        if ~isempty(resultsFile)
            fid = fopen(resultsFile, 'w');
            fprintf(fid, '%d %d\n', passed, failed);
            fclose(fid);
        end
    end

    fprintf('\n=== Results: %d/%d passed, %d failed ===\n', ...
        passed, total, failed);
    if ~isempty(failures)
        fprintf('\nFailures:\n');
        for i = 1:numel(failures)
            fprintf('  - %s\n', failures{i});
        end
    end

    results = struct('total', total, 'passed', passed, 'failed', failed);
end
