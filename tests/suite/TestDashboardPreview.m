classdef TestDashboardPreview < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testBaseWidgetAsciiRender(testCase)
            w = TextWidget('Title', 'Hello');
            lines = w.asciiRender(20, 3);
            testCase.verifyEqual(numel(lines), 3);
            testCase.verifyEqual(numel(lines{1}), 20);
            testCase.verifyTrue(contains(lines{1}, 'Hello'));
        end

        function testAsciiRenderHeightZero(testCase)
            w = TextWidget('Title', 'Hello');
            lines = w.asciiRender(20, 0);
            testCase.verifyEmpty(lines);
        end
    end
end
