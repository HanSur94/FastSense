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
            for li = 1:numel(lines)
                testCase.verifyEqual(numel(lines{li}), 20);
            end
        end

        function testAsciiRenderHeightZero(testCase)
            w = TextWidget('Title', 'Hello');
            lines = w.asciiRender(20, 0);
            testCase.verifyEmpty(lines);
        end

        function testAsciiRenderNegativeHeight(testCase)
            w = TextWidget('Title', 'Hello');
            lines = w.asciiRender(20, -1);
            testCase.verifyEmpty(lines);
        end

        function testAsciiRenderTruncation(testCase)
            w = TextWidget('Title', 'Very Long Title That Exceeds Width');
            lines = w.asciiRender(10, 1);
            testCase.verifyEqual(numel(lines{1}), 10);
        end
    end
end
