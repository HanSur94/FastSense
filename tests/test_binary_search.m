function test_binary_search()
%TEST_BINARY_SEARCH Tests for binary_search private function.

    % We need access to the private function via the FastSense directory
    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); setup();
    add_fastsense_private_path();

    x = [1 3 5 7 9];

    % testLeftBasic: first index where x >= 4 -> x(3)=5
    idx = binary_search(x, 4, 'left');
    assert(idx == 3, 'testLeftBasic: expected 3, got %d', idx);

    % testRightBasic: last index where x <= 6 -> x(3)=5
    idx = binary_search(x, 6, 'right');
    assert(idx == 3, 'testRightBasic: expected 3, got %d', idx);

    % testLeftExactMatch: first index where x >= 5 -> x(3)=5
    idx = binary_search(x, 5, 'left');
    assert(idx == 3, 'testLeftExactMatch: expected 3, got %d', idx);

    % testRightExactMatch: last index where x <= 5 -> x(3)=5
    idx = binary_search(x, 5, 'right');
    assert(idx == 3, 'testRightExactMatch: expected 3, got %d', idx);

    % testLeftBelowAll: first index where x >= 0 -> x(1)=1
    idx = binary_search(x, 0, 'left');
    assert(idx == 1, 'testLeftBelowAll: expected 1, got %d', idx);

    % testRightAboveAll: last index where x <= 100 -> x(5)=9
    idx = binary_search(x, 100, 'right');
    assert(idx == 5, 'testRightAboveAll: expected 5, got %d', idx);

    % testLeftAboveAll: clamp to last
    idx = binary_search(x, 100, 'left');
    assert(idx == 5, 'testLeftAboveAll: expected 5, got %d', idx);

    % testRightBelowAll: clamp to first
    idx = binary_search(x, 0, 'right');
    assert(idx == 1, 'testRightBelowAll: expected 1, got %d', idx);

    % testUnevenSpacing
    x2 = [0.1 0.5 1.0 10.0 100.0 100.1];
    idx = binary_search(x2, 9.0, 'left');
    assert(idx == 4, 'testUnevenSpacing: expected 4, got %d', idx);

    % testLargeArray
    x3 = 1:1e6;
    idx = binary_search(x3, 500000.5, 'left');
    assert(idx == 500001, 'testLargeArray: expected 500001, got %d', idx);

    % testSingleElement
    x4 = [5];
    assert(binary_search(x4, 3, 'left') == 1, 'testSingleElement left');
    assert(binary_search(x4, 7, 'right') == 1, 'testSingleElement right');

    fprintf('    All 11 binary_search tests passed.\n');
end
