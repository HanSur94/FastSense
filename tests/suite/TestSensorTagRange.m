classdef TestSensorTagRange < matlab.unittest.TestCase
%TESTSENSORTAGRANGE Class-suite coverage for windowed Tag reads (Phase 1041).
%
%   The windowed-read logic — Tag.getXYRange, SensorTag.getXYRange, and the
%   FastSenseDataStore time-extent / range helpers — is exercised in depth by
%   the function-based test `test_sensor_tag_range`. This repo's MATLAB CI
%   coverage shards run class-based tests/suite/Test*.m only (via
%   TestSuite.fromFolder), so a function-based test alone passes locally but
%   leaves the code 0%-covered in Codecov. This thin suite runs that function
%   inside a class test method so its line coverage is attributed under a
%   class suite. All assertions live in the function test (assert(); any
%   failure throws and fails this test).
%
%   See also test_sensor_tag_range, Tag, SensorTag, FastSenseDataStore.

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
            %   the function-based test_sensor_tag_range already runs on Octave.
            testCase.assumeFalse( ...
                exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestSensorTagRange: covered on Octave by function-based test_sensor_tag_range.');
        end
    end

    methods (Test)
        function runsWindowedReadChecks(testCase)
            %RUNSWINDOWEDREADCHECKS Execute the function-based windowed-read suite.
            %   Any failed assert inside the function throws and fails this test.
            test_sensor_tag_range();
            testCase.verifyTrue(true, 'test_sensor_tag_range completed without error');
        end
    end

end
