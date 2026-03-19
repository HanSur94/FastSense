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

        function testFastSenseAsciiWithData(testCase)
            w = FastSenseWidget('Title', 'Temp', 'XData', 1:20, ...
                'YData', sin(linspace(0, 2*pi, 20)));
            lines = w.asciiRender(30, 4);
            testCase.verifyEqual(numel(lines), 4);
            testCase.verifyTrue(contains(lines{1}, 'Temp'));
        end

        function testFastSenseAsciiNoData(testCase)
            w = FastSenseWidget('Title', 'Temp');
            lines = w.asciiRender(30, 4);
            testCase.verifyTrue(contains(lines{1}, 'Temp'));
            testCase.verifyTrue(contains(lines{2}, 'fastsense'));
        end

        function testNumberAsciiWithValue(testCase)
            w = NumberWidget('Title', 'Max', 'StaticValue', 72.5, 'Units', 'degC');
            lines = w.asciiRender(25, 2);
            testCase.verifyTrue(contains(lines{1}, 'Max'));
            testCase.verifyTrue(contains(lines{1}, '72.5'));
        end

        function testNumberAsciiNoData(testCase)
            w = NumberWidget('Title', 'Max');
            lines = w.asciiRender(25, 2);
            testCase.verifyTrue(contains(lines{1}, 'Max'));
            testCase.verifyTrue(contains(lines{2}, 'number'));
        end

        function testStatusAsciiWithData(testCase)
            w = StatusWidget('Title', 'Pump', 'StaticStatus', 'ok');
            lines = w.asciiRender(25, 2);
            testCase.verifyTrue(contains(lines{1}, 'Pump'));
            testCase.verifyTrue(contains(lines{1}, 'OK'));
        end

        function testStatusAsciiNoData(testCase)
            w = StatusWidget('Title', 'Pump');
            lines = w.asciiRender(25, 2);
            testCase.verifyTrue(contains(lines{1}, 'Pump'));
        end

        function testTextAsciiWithContent(testCase)
            w = TextWidget('Title', 'Header', 'Content', 'Some info text');
            lines = w.asciiRender(30, 2);
            testCase.verifyTrue(contains(lines{1}, 'Header'));
            testCase.verifyTrue(contains(lines{2}, 'Some info'));
        end

        function testTextAsciiTitleOnly(testCase)
            w = TextWidget('Title', 'Section A');
            lines = w.asciiRender(20, 2);
            testCase.verifyTrue(contains(lines{1}, 'Section A'));
        end

        function testGaugeAsciiWithValue(testCase)
            w = GaugeWidget('Title', 'Pressure', 'StaticValue', 65, ...
                'Range', [0 100], 'Units', 'bar');
            lines = w.asciiRender(30, 3);
            testCase.verifyTrue(contains(lines{1}, 'Pressure'));
            testCase.verifyTrue(contains(lines{2}, '65'));
        end

        function testGaugeAsciiNoData(testCase)
            w = GaugeWidget('Title', 'Pressure');
            lines = w.asciiRender(30, 3);
            testCase.verifyTrue(contains(lines{1}, 'Pressure'));
            testCase.verifyTrue(contains(lines{2}, 'gauge'));
        end
    end
end
