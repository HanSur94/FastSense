classdef TestMultiStatusWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = MultiStatusWidget();
            testCase.verifyEqual(w.getType(), 'multistatus');
            testCase.verifyEqual(w.ShowLabels, true);
            testCase.verifyEqual(w.IconStyle, 'dot');
        end

        function testToStruct(testCase)
            w = MultiStatusWidget('Title', 'Status Grid');
            w.Columns = 4;
            w.IconStyle = 'square';
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'multistatus');
            testCase.verifyEqual(s.columns, 4);
            testCase.verifyEqual(s.iconStyle, 'square');
        end

        function testThresholdOnLimitNotViolated(testCase)
        %TESTTHRESHOLDONLIMITNOTVIOLATED Regression for the inclusive (>=) bug in
        %   deriveColorFromThreshold: a value sitting EXACTLY on a threshold limit
        %   should NOT be a violation (strict > / < convention matching all other
        %   dashboard widgets). The private method now delegates to isThresholdViolated.
            upper = MockThreshold(true, 10);
            lower = MockThreshold(false, 5);
            % On the limit — must NOT be a violation.
            testCase.verifyFalse(isThresholdViolated(upper, 10), ...
                'val == upper limit must NOT be a violation (was inclusive >= before fix)');
            testCase.verifyFalse(isThresholdViolated(lower, 5), ...
                'val == lower limit must NOT be a violation (was inclusive <= before fix)');
            % Strictly beyond the limit — must be a violation.
            testCase.verifyTrue(isThresholdViolated(upper, 11));
            testCase.verifyTrue(isThresholdViolated(lower, 4));
        end
    end
end
