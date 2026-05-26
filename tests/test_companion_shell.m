function test_companion_shell()
%TEST_COMPANION_SHELL Smoke tests for FastSenseCompanion shell (Phase 1018).
%   Tests that run on both MATLAB and Octave.
%   On Octave only the guard path is exercised (FastSenseCompanion:notSupported).
%   Class-based tests in tests/suite/TestFastSenseCompanion.m cover MATLAB
%   uifigure paths in more depth.
%
%   See also FastSenseCompanion, TestFastSenseCompanion.

    add_companion_path();
    nPassed = 0;

    % --- Test 1: Octave guard throws FastSenseCompanion:notSupported ---
    if exist('OCTAVE_VERSION', 'builtin') ~= 0
        try
            FastSenseCompanion();
            error('TEST_COMPANION_SHELL:noThrow', 'Constructor did not throw on Octave');
        catch e
            assert(strcmp(e.identifier, 'FastSenseCompanion:notSupported'), ...
                sprintf('Wrong error ID on Octave: %s', e.identifier));
            assert(~isempty(strfind(e.message, 'R2020b')), ...
                'Octave error message does not mention R2020b');
        end
        nPassed = nPassed + 1;
        fprintf('    All %d tests passed.\n', nPassed);
        return;   % On Octave, only the guard test is applicable
    end

    % --- Tests 2+: MATLAB-only (uifigure paths) ---
    % The Octave path exited above; the following run on MATLAB only.

    % Test 2: Unknown option throws FastSenseCompanion:unknownOption
    try
        FastSenseCompanion('BadKey', 'val');
        error('TEST_COMPANION_SHELL:noThrow', 'Should have thrown on unknown key');
    catch e
        assert(strcmp(e.identifier, 'FastSenseCompanion:unknownOption'), ...
            sprintf('Wrong ID for unknown key: %s', e.identifier));
    end
    nPassed = nPassed + 1;

    % Test 3: Non-DashboardEngine in Dashboards throws FastSenseCompanion:invalidDashboard
    try
        FastSenseCompanion('Dashboards', {struct('x', 1)});
        error('TEST_COMPANION_SHELL:noThrow', 'Should have thrown for invalid dashboard');
    catch e
        assert(strcmp(e.identifier, 'FastSenseCompanion:invalidDashboard'), ...
            sprintf('Wrong ID for invalid dashboard: %s', e.identifier));
        assert(~isempty(strfind(e.message, '1')), ...
            'Error message missing offending index');
    end
    nPassed = nPassed + 1;

    % Test 4: Constructor with empty Dashboards opens successfully
    app = FastSenseCompanion('Dashboards', {}, 'Theme', 'dark');
    assert(isvalid(app), 'app should be valid after construction');
    assert(app.IsOpen, 'IsOpen should be true after construction');
    app.close();
    nPassed = nPassed + 1;

    % Test 5: close() is idempotent (second call must not throw)
    app2 = FastSenseCompanion('Dashboards', {}, 'Theme', 'light');
    app2.close();
    app2.close();   % second call must be a no-op
    nPassed = nPassed + 1;

    fprintf('    All %d tests passed.\n', nPassed);
end

function add_companion_path()
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
end
