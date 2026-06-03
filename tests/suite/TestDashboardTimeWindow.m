classdef TestDashboardTimeWindow < matlab.unittest.TestCase
%TESTDASHBOARDTIMEWINDOW Class-suite coverage for time-window view threading (Phase 1041).
%
%   The view-layer windowing — DashboardEngine.setTimeWindow fan-out,
%   FastSenseWidget windowed pulls + the "No data in selected range"
%   empty-state, and SensorDetailPlot TimeWindow — is exercised by the
%   function-based test `test_dashboard_time_window` (which renders into
%   figure('Visible','off'), so it is headless-safe). This repo's MATLAB CI
%   coverage shards run class-based tests/suite/Test*.m only, so a
%   function-based test alone leaves the code 0%-covered in Codecov. This thin
%   suite runs that function inside a class test method to attribute its
%   coverage. All assertions live in the function test.
%
%   See also test_dashboard_time_window, DashboardEngine, FastSenseWidget,
%   SensorDetailPlot.

    methods (TestClassSetup)
        function addPaths(~)
            %ADDPATHS Add project root + install() to set up all library paths.
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function skipOnOctave(testCase)
            %SKIPONOCTAVE Run under MATLAB only — Codecov shards are MATLAB, and
            %   test_dashboard_time_window already runs (figure-tests skipped) on Octave.
            testCase.assumeFalse( ...
                exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestDashboardTimeWindow: covered on Octave by function-based test_dashboard_time_window.');
        end
    end

    methods (Test)
        function runsTimeWindowChecks(testCase)
            %RUNSTIMEWINDOWCHECKS Execute the function-based time-window suite.
            %   Any failed assert inside the function throws and fails this test.
            test_dashboard_time_window();
            testCase.verifyTrue(true, 'test_dashboard_time_window completed without error');
        end
    end

end
