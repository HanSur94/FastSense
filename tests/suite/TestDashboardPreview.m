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

        function testPreviewEmpty(testCase)
            d = DashboardEngine('Empty');
            output = evalc('d.preview()');
            testCase.verifyTrue(contains(output, 'empty'));
            testCase.verifyTrue(contains(output, 'Empty'));
        end

        function testPreviewSingleWidget(testCase)
            d = DashboardEngine('Test');
            d.addWidget('text', 'Title', 'Hello', 'Position', [1 1 12 1]);
            output = evalc('d.preview()');
            testCase.verifyTrue(contains(output, 'Test'));
            testCase.verifyTrue(contains(output, 'Hello'));
        end

        function testPreviewMultiWidget(testCase)
            d = DashboardEngine('Multi');
            d.addWidget('text', 'Title', 'A', 'Position', [1 1 12 1]);
            d.addWidget('text', 'Title', 'B', 'Position', [13 1 12 1]);
            output = evalc('d.preview()');
            testCase.verifyTrue(contains(output, 'A'));
            testCase.verifyTrue(contains(output, 'B'));
        end

        function testPreviewCustomWidth(testCase)
            d = DashboardEngine('Wide');
            d.addWidget('text', 'Title', 'X', 'Position', [1 1 24 1]);
            output80 = evalc('d.preview(''Width'', 80)');
            output120 = evalc('d.preview(''Width'', 120)');
            lines80 = strsplit(output80, newline);
            lines120 = strsplit(output120, newline);
            maxLen80 = max(cellfun(@numel, lines80));
            maxLen120 = max(cellfun(@numel, lines120));
            testCase.verifyGreaterThan(maxLen120, maxLen80);
        end

        function testPreviewMinWidth(testCase)
            d = DashboardEngine('Narrow');
            d.addWidget('text', 'Title', 'X', 'Position', [1 1 24 1]);
            output = evalc('d.preview(''Width'', 20)');
            testCase.verifyTrue(~isempty(output));
        end
    end
end
