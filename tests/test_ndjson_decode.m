function test_ndjson_decode()
%TEST_NDJSON_DECODE Unit tests for libs/Concurrency/ndjsonDecode.
%
%   Octave 7+ and MATLAB R2020b+ compatible. Function-style test — no class
%   inheritance, no verifyEqual. Follows the pattern established by
%   tests/test_no_raw_save_to_shared.m and tests/test_event_store.m.
%
%   Tests:
%     1. Empty input returns [] and SkippedLineCount == 0
%     2. Encode/decode round-trip on flat struct preserves field values
%     3. Corrupt line skipped and counted; adjacent valid lines returned
%     4. Comment/header line (#FASTSENSE_EVENTLOG_V1) silently skipped
%     5. Blank lines and trailing newlines silently skipped
%     6. Three-record round-trip with heterogeneous field sets
%     7. Number-only JSON line counted as skipped (must be struct)

    add_concurrency_path_();

    nPassed = 0;

    % -- Test 1: empty input ----------------------------------------------
    [ev, st] = ndjsonDecode('');
    assert(isempty(ev), 'Test 1: empty input: events must be []');
    assert(st.SkippedLineCount == 0, 'Test 1: empty input: SkippedLineCount must be 0');
    nPassed = nPassed + 1;

    % -- Test 2: encode/decode round-trip on a flat struct ----------------
    s = struct('a', 1, 'b', 'two');
    line = ndjsonEncode(s);
    [ev, st] = ndjsonDecode(line);
    assert(numel(ev) == 1, 'Test 2: round-trip: must return 1 event');
    assert(ev(1).a == 1, 'Test 2: round-trip: field a must equal 1');
    assert(strcmp(ev(1).b, 'two'), 'Test 2: round-trip: field b must equal ''two''');
    assert(st.SkippedLineCount == 0, 'Test 2: round-trip: SkippedLineCount must be 0');
    nPassed = nPassed + 1;

    % -- Test 3: corrupt line skipped and counted -------------------------
    good1 = ndjsonEncode(struct('a', 1));
    good2 = ndjsonEncode(struct('a', 2));
    bad   = sprintf('{not_json}\n');
    [ev, st] = ndjsonDecode([good1, bad, good2]);
    assert(numel(ev) == 2, 'Test 3: corrupt: must return 2 valid events');
    assert(st.SkippedLineCount == 1, 'Test 3: corrupt: SkippedLineCount must be 1');
    nPassed = nPassed + 1;

    % -- Test 4: comment/header line silently skipped (not counted) -------
    header = sprintf('#FASTSENSE_EVENTLOG_V1\n');
    [ev, st] = ndjsonDecode([header, ndjsonEncode(struct('a', 1))]);
    assert(numel(ev) == 1, 'Test 4: header: must return 1 event after header line');
    assert(st.SkippedLineCount == 0, 'Test 4: header: header line must NOT be counted as corrupt');
    nPassed = nPassed + 1;

    % -- Test 5: blank lines and trailing newline silently skipped --------
    inner = strtrim(ndjsonEncode(struct('a', 1)));
    [ev, st] = ndjsonDecode(sprintf('\n\n%s\n', inner));
    assert(numel(ev) == 1, 'Test 5: blanks: must return 1 event');
    assert(st.SkippedLineCount == 0, 'Test 5: blanks: blank lines must not be counted as skipped');
    nPassed = nPassed + 1;

    % -- Test 6: 3-record round-trip with heterogeneous field sets --------
    ra = struct('id', 'a', 'val', 1);
    rb = struct('id', 'b', 'note', 'hi');
    rc = struct('id', 'c', 'val', 2);
    [ev, st] = ndjsonDecode([ndjsonEncode(ra), ndjsonEncode(rb), ndjsonEncode(rc)]);
    assert(numel(ev) == 3, 'Test 6: rt3: must return 3 events');
    assert(strcmp(ev(1).id, 'a') && strcmp(ev(2).id, 'b') && strcmp(ev(3).id, 'c'), ...
        'Test 6: rt3: record order must be preserved');
    assert(st.SkippedLineCount == 0, 'Test 6: rt3: SkippedLineCount must be 0');
    nPassed = nPassed + 1;

    % -- Test 7: number-only JSON line counted as skipped -----------------
    [ev, st] = ndjsonDecode([sprintf('42\n'), ndjsonEncode(struct('a', 1))]);
    assert(numel(ev) == 1, 'Test 7: number: bare number must not be accepted as struct event');
    assert(st.SkippedLineCount == 1, 'Test 7: number: bare number must be counted as skipped');
    nPassed = nPassed + 1;

    fprintf('    All %d ndjson_decode tests passed.\n', nPassed);
end

function add_concurrency_path_()
%ADD_CONCURRENCY_PATH_ Add repo root and run install() to put libs/Concurrency/ on path.
    thisDir  = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    install();
end
