classdef TestDashboardProgress < matlab.unittest.TestCase
%TESTDASHBOARDPROGRESS Unit tests for DashboardProgress and its integration with DashboardEngine.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testSilentModeProducesNoOutput(testCase)
            p = DashboardProgress('Demo', 3, 1, 'off');
            w = stubWidget('NumberWidget', 'a');
            tickOut   = evalc('p.tick(w, 1, '''');');
            finishOut = evalc('p.finish();');
            testCase.verifyEmpty(tickOut);
            testCase.verifyEmpty(finishOut);
        end

        function testInteractiveTickEmitsProgressLine(testCase)
            p = DashboardProgress('SensorOverview', 3, 1, 'on');
            w = stubWidget('NumberWidget', 'rpm');
            out = evalc('p.tick(w, 1, '''');');
            testCase.verifyNotEmpty(out);
            testCase.verifyTrue(contains(out, '[Dashboard ''SensorOverview'']'));
            testCase.verifyTrue(contains(out, '1/3'));
            testCase.verifyTrue(contains(out, 'NumberWidget'));
            testCase.verifyTrue(contains(out, 'rpm'));
        end

        function testInteractiveFinishEmitsSummaryWithNewline(testCase)
            p = DashboardProgress('SensorOverview', 2, 1, 'on');
            w = stubWidget('NumberWidget', 'a');
            evalc('p.tick(w, 1, '''');');
            evalc('p.tick(w, 1, '''');');
            out = evalc('p.finish();');
            testCase.verifyTrue(contains(out, 'rendered 2 widgets'));
            testCase.verifyEqual(out(end), sprintf('\n'));
            testCase.verifyFalse(contains(out, 'across'));
        end

        function testInteractiveFinishMultiPageMentionsPages(testCase)
            p = DashboardProgress('X', 5, 3, 'on');
            out = evalc('p.finish();');
            testCase.verifyTrue(contains(out, 'across 3 pages'));
        end

        function testInteractiveTickIncludesPageLabelWhenMultiPage(testCase)
            p = DashboardProgress('X', 4, 2, 'on');
            w = stubWidget('NumberWidget', 'k');
            out = evalc('p.tick(w, 2, ''Engine'');');
            testCase.verifyTrue(contains(out, 'page 2/2'));
            testCase.verifyTrue(contains(out, 'Engine'));
        end

        function testInteractiveTickOmitsPageLabelWhenSinglePage(testCase)
            p = DashboardProgress('X', 2, 1, 'on');
            w = stubWidget('NumberWidget', 'k');
            out = evalc('p.tick(w, 1, '''');');
            testCase.verifyFalse(contains(out, 'page '));
        end

        function testTickClampsAtTotal(testCase)
            p = DashboardProgress('X', 2, 1, 'on');
            w = stubWidget('NumberWidget', 'k');
            evalc('p.tick(w, 1, '''');');
            evalc('p.tick(w, 1, '''');');
            out = evalc('p.tick(w, 1, '''');');
            testCase.verifyTrue(contains(out, '2/2'));
        end

        function testTickMissingTitleFallsBackToIndex(testCase)
            p = DashboardProgress('X', 2, 1, 'on');
            w = stubWidget('NumberWidget', '');
            out = evalc('p.tick(w, 1, '''');');
            testCase.verifyTrue(contains(out, '#1'));
        end

        function testEngineRenderEmitsProgressSummary(testCase)
            d = DashboardEngine('EngineProgress');
            d.ProgressMode = 'on';
            d.addWidget('number', 'Title', 'A', 'Position', [1 1 6 2], 'StaticValue', 1);
            d.addWidget('number', 'Title', 'B', 'Position', [7 1 6 2], 'StaticValue', 2);
            out = evalc('d.render();');
            testCase.addTeardown(@() close(d.hFigure));
            set(d.hFigure, 'Visible', 'off');
            testCase.verifyTrue(contains(out, 'rendered 2 widgets'));
            testCase.verifyTrue(contains(out, '[Dashboard ''EngineProgress'']'));
        end

        function testEngineRenderSilentWhenModeOff(testCase)
            d = DashboardEngine('SilentOff');
            d.ProgressMode = 'off';
            d.addWidget('number', 'Title', 'A', 'Position', [1 1 6 2], 'StaticValue', 1);
            out = evalc('d.render();');
            testCase.addTeardown(@() close(d.hFigure));
            set(d.hFigure, 'Visible', 'off');
            testCase.verifyFalse(contains(out, 'rendered'));
        end

        function testRenderPreservesLazyPageRealization(testCase)
            d = DashboardEngine('LazyCheck');
            d.ProgressMode = 'on';
            d.addPage('P1'); d.switchPage(1);
            d.addWidget('number', 'Title', 'P1W', 'Position', [1 1 12 1], 'StaticValue', 1);
            d.addPage('P2'); d.switchPage(2);
            d.addWidget('number', 'Title', 'P2W', 'Position', [1 1 12 1], 'StaticValue', 2);
            d.switchPage(1);
            evalc('d.render();');
            testCase.addTeardown(@() close(d.hFigure));
            set(d.hFigure, 'Visible', 'off');
            testCase.verifyTrue(d.Pages{1}.Widgets{1}.Realized, ...
                'Active page widget must be realized');
            testCase.verifyFalse(d.Pages{2}.Widgets{1}.Realized, ...
                'Non-active page widget must stay unrealized');
        end

        function testRerenderEmitsSummary(testCase)
            d = DashboardEngine('Rerender');
            d.ProgressMode = 'on';
            d.addWidget('number', 'Title', 'A', 'Position', [1 1 6 2], 'StaticValue', 1);
            evalc('d.render();');
            testCase.addTeardown(@() close(d.hFigure));
            set(d.hFigure, 'Visible', 'off');
            out = evalc('d.rerenderWidgets();');
            testCase.verifyTrue(contains(out, 'rendered 1 widgets'));
        end
    end
end

function w = stubWidget(typeName, title)
    w = struct('Title', title, 'ClassName', typeName);
end
