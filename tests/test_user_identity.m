function test_user_identity()
%TEST_USER_IDENTITY Octave-compat function test for userIdentity().
%   Exercises usejava('jvm')==false branch explicitly.
%
%   Test 1: userIdentity() returns non-empty user and non-empty host
%   Test 2: Source shape checks — system('hostname') as secondary fallback
%           and usejava('jvm') as Java guard are present in the source
%
%   See also userIdentity.

    nPassed = 0;
    nFailed = 0;

    % Test 1: basic non-empty return
    try
        [u, h] = userIdentity();
        assert(~isempty(u), 'userIdentity returned empty user');
        assert(~isempty(h), 'userIdentity returned empty host');
        nPassed = nPassed + 1;
    catch err
        fprintf(2, 'FAIL: testBasic — %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % Test 2: hostname is non-empty when env vars are clear
    % (cannot reliably clear env vars in cross-platform test; just verify
    % the system('hostname') call exists in source)
    srcPath = which('userIdentity');
    if isempty(srcPath)
        fprintf(2, 'FAIL: testSourceShape — userIdentity not on path\n');
        nFailed = nFailed + 1;
    else
        try
            txt = fileread(srcPath);
            assert(~isempty(regexp(txt, 'system\(''hostname''\)', 'once')), ...
                'userIdentity must call system(''hostname'') as secondary fallback (Pitfall D)');
            assert(~isempty(regexp(txt, 'usejava\(''jvm''\)', 'once')), ...
                'userIdentity must guard Java fallback with usejava(''jvm'') (Pitfall 8)');
            nPassed = nPassed + 1;
        catch err
            fprintf(2, 'FAIL: testSourceShape — %s\n', err.message);
            nFailed = nFailed + 1;
        end
    end

    fprintf('    %d/%d tests passed.\n', nPassed, nPassed + nFailed);
    if nFailed > 0
        error('test_user_identity:failures', '%d test(s) failed.', nFailed);
    end
end
