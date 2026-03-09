function results = run_all_tests()
%RUN_ALL_TESTS Execute all FastPlot unit tests.
%   Finds all test_*.m files in the tests directory and runs them.

    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
    add_fastplot_private_path();
    files = dir(fullfile(test_dir, 'test_*.m'));

    total = 0;
    passed = 0;
    failed = 0;
    failures = {};

    for i = 1:numel(files)
        [~, name, ~] = fileparts(files(i).name);
        fprintf('Running %s...\n', name);
        try
            feval(name);
            fprintf('  PASSED\n');
            passed = passed + 1;
        catch e
            fprintf('  FAILED: %s\n', e.message);
            failed = failed + 1;
            failures{end+1} = sprintf('%s: %s', name, e.message);
        end
        total = total + 1;
    end

    fprintf('\n=== Results: %d/%d passed, %d failed ===\n', passed, total, failed);
    if ~isempty(failures)
        fprintf('\nFailures:\n');
        for i = 1:numel(failures)
            fprintf('  - %s\n', failures{i});
        end
    end

    results = struct('total', total, 'passed', passed, 'failed', failed);
end
