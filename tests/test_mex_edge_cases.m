function test_mex_edge_cases()
%TEST_MEX_EDGE_CASES Edge case tests for MEX functions.
%   Skips if MEX files are not compiled.

    run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));
    add_fastplot_private_path();

    has_bs  = (exist('binary_search_mex', 'file') == 3);
    has_mm  = (exist('minmax_core_mex', 'file') == 3);
    has_lt  = (exist('lttb_core_mex', 'file') == 3);

    if ~has_bs && ~has_mm && ~has_lt
        fprintf('    SKIPPED: No MEX files compiled. Run build_mex() first.\n');
        return;
    end

    n_passed = 0;

    % ---- binary_search edge cases ----
    if has_bs
        % Single element
        assert(binary_search_mex([5], 3, 'left') == 1);
        assert(binary_search_mex([5], 7, 'right') == 1);
        assert(binary_search_mex([5], 5, 'left') == 1);
        assert(binary_search_mex([5], 5, 'right') == 1);

        % Two elements
        assert(binary_search_mex([1 10], 5, 'left') == 2);
        assert(binary_search_mex([1 10], 5, 'right') == 1);

        % Exact boundary values
        x = [1 2 3 4 5];
        assert(binary_search_mex(x, 1, 'left') == 1);
        assert(binary_search_mex(x, 5, 'right') == 5);

        % Duplicates
        x = [1 1 1 3 3 3 5 5 5];
        assert(binary_search_mex(x, 1, 'left') == 1);
        assert(binary_search_mex(x, 3, 'left') == 4);
        assert(binary_search_mex(x, 1, 'right') == 3);
        assert(binary_search_mex(x, 3, 'right') == 6);

        fprintf('    binary_search_mex edge cases: PASSED\n');
        n_passed = n_passed + 1;
    end

    % ---- minmax_core edge cases ----
    if has_mm
        % Minimum size: 2 elements, 1 bucket
        [xo, yo] = minmax_core_mex([1 2], [10 20], 1);
        assert(numel(xo) == 2 && numel(yo) == 2);
        assert(xo(1) == 1 && xo(2) == 2);
        assert(yo(1) == 10 && yo(2) == 20);

        % All same values
        x = 1:100;
        y = ones(1, 100) * 42;
        [~, yo] = minmax_core_mex(x, y, 10);
        assert(all(yo == 42), 'All-same values: expected all 42');

        % Negative values
        x = 1:100;
        y = -50 + (1:100) * 0.1;
        [~, yo] = minmax_core_mex(x, y, 10);
        assert(min(yo) >= -50 && max(yo) <= -40);

        % Large array: 10M points
        n = 1e7;
        x = linspace(0, 100, n);
        y = sin(x);
        [xo, yo] = minmax_core_mex(x, y, 1000);
        assert(numel(xo) == 2000, 'Large: expected 2000 points, got %d', numel(xo));
        assert(max(yo) <= 1.0 + 1e-10 && min(yo) >= -1.0 - 1e-10, ...
            'Large: y values out of sine range');

        % Remainder handling: n not divisible by numBuckets
        x = 1:17;
        y = [5 3 8 1 9 2 7 4 6 10 11 12 13 14 15 16 17];
        [~, yo] = minmax_core_mex(x, y, 3);
        assert(numel(yo) == 6);

        fprintf('    minmax_core_mex edge cases: PASSED\n');
        n_passed = n_passed + 1;
    end

    % ---- lttb_core edge cases ----
    if has_lt
        % Minimum: numOut == 2 (just endpoints)
        [xo, yo] = lttb_core_mex([1 2 3 4 5], [10 20 30 40 50], 2);
        assert(numel(xo) == 2);
        assert(xo(1) == 1 && xo(2) == 5);
        assert(yo(1) == 10 && yo(2) == 50);

        % numOut == 3
        x = 1:10;
        y = [0 0 0 0 10 0 0 0 0 0];
        [xo, yo] = lttb_core_mex(x, y, 3);
        assert(numel(xo) == 3);
        assert(xo(1) == 1 && xo(end) == 10);

        % Monotonic data
        x = 1:1000;
        y = (1:1000) * 0.001;
        [xo, ~] = lttb_core_mex(x, y, 50);
        assert(all(diff(xo) > 0), 'Monotonic X violated');

        % Large array
        n = 1e6;
        x = linspace(0, 100, n);
        y = sin(x);
        [xo, yo] = lttb_core_mex(x, y, 500);
        assert(numel(xo) == 500);
        assert(xo(1) == x(1) && xo(end) == x(end));

        fprintf('    lttb_core_mex edge cases: PASSED\n');
        n_passed = n_passed + 1;
    end

    fprintf('    All %d MEX edge case tests passed.\n', n_passed);
end
