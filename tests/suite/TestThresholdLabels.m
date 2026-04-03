classdef TestThresholdLabels < matlab.unittest.TestCase
%TESTTHRESHOLDLABELS Test suite for threshold label behavior in FastSense and FastSenseWidget.
%
%   Tests cover default off state, label creation, text content, fallback naming,
%   color matching, font size, alignment, multiple thresholds, widget property default,
%   toStruct omission/emission, and fromStruct round-trip.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultOff(testCase)
            fp = FastSense();
            testCase.verifyFalse(fp.ShowThresholdLabels, 'testDefaultOff');
        end

        function testNoLabelsWhenOff(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            ax = axes('Parent', fig);
            fp = FastSense('Parent', ax);
            fp.addLine(1:100, randn(1, 100));
            fp.addThreshold(0.5, 'Label', 'T1');
            fp.ShowThresholdLabels = false;
            fp.render();
            testCase.verifyTrue(isempty(fp.Thresholds(1).hText), 'testNoLabelsWhenOff');
        end

        function testLabelCreated(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            ax = axes('Parent', fig);
            fp = FastSense('Parent', ax);
            fp.addLine(1:100, randn(1, 100));
            fp.addThreshold(0.5, 'Label', 'T1');
            fp.ShowThresholdLabels = true;
            fp.render();
            testCase.verifyTrue(ishandle(fp.Thresholds(1).hText), 'testLabelCreated');
        end

        function testLabelText(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            ax = axes('Parent', fig);
            fp = FastSense('Parent', ax);
            fp.addLine(1:100, randn(1, 100));
            fp.addThreshold(0.5, 'Label', 'MaxTemp');
            fp.ShowThresholdLabels = true;
            fp.render();
            testCase.verifyEqual(get(fp.Thresholds(1).hText, 'String'), 'MaxTemp', 'testLabelText');
        end

        function testLabelFallback(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            ax = axes('Parent', fig);
            fp = FastSense('Parent', ax);
            fp.addLine(1:100, randn(1, 100));
            fp.addThreshold(0.5);  % no Label
            fp.ShowThresholdLabels = true;
            fp.render();
            testCase.verifyEqual(get(fp.Thresholds(1).hText, 'String'), 'Threshold 1', 'testLabelFallback');
        end

        function testLabelColor(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            ax = axes('Parent', fig);
            fp = FastSense('Parent', ax);
            fp.addLine(1:100, randn(1, 100));
            fp.addThreshold(0.5, 'Color', [1 0 0], 'Label', 'Red');
            fp.ShowThresholdLabels = true;
            fp.render();
            testCase.verifyEqual(get(fp.Thresholds(1).hText, 'Color'), [1 0 0], 'testLabelColor');
        end

        function testLabelFontSize(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            ax = axes('Parent', fig);
            fp = FastSense('Parent', ax);
            fp.addLine(1:100, randn(1, 100));
            fp.addThreshold(0.5, 'Label', 'T1');
            fp.ShowThresholdLabels = true;
            fp.render();
            testCase.verifyEqual(get(fp.Thresholds(1).hText, 'FontSize'), 8, 'testLabelFontSize');
        end

        function testLabelAlignment(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            ax = axes('Parent', fig);
            fp = FastSense('Parent', ax);
            fp.addLine(1:100, randn(1, 100));
            fp.addThreshold(0.5, 'Label', 'T1');
            fp.ShowThresholdLabels = true;
            fp.render();
            testCase.verifyEqual(get(fp.Thresholds(1).hText, 'HorizontalAlignment'), 'right', 'testLabelAlignment: horiz');
            testCase.verifyEqual(get(fp.Thresholds(1).hText, 'VerticalAlignment'), 'middle', 'testLabelAlignment: vert');
        end

        function testMultipleThresholds(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            ax = axes('Parent', fig);
            fp = FastSense('Parent', ax);
            fp.addLine(1:100, randn(1, 100));
            fp.addThreshold(0.5, 'Label', 'Upper');
            fp.addThreshold(-0.5, 'Label', 'Lower');
            fp.ShowThresholdLabels = true;
            fp.render();
            testCase.verifyTrue(ishandle(fp.Thresholds(1).hText), 'testMultiple: first');
            testCase.verifyTrue(ishandle(fp.Thresholds(2).hText), 'testMultiple: second');
            testCase.verifyEqual(get(fp.Thresholds(1).hText, 'String'), 'Upper', 'testMultiple: first text');
            testCase.verifyEqual(get(fp.Thresholds(2).hText, 'String'), 'Lower', 'testMultiple: second text');
        end

        function testWidgetPropertyDefault(testCase)
            w = FastSenseWidget();
            testCase.verifyFalse(w.ShowThresholdLabels, 'testWidgetPropertyDefault');
        end

        function testWidgetToStructOmitsWhenFalse(testCase)
            w = FastSenseWidget();
            w.Title = 'Test';
            w.Position = [1 1 12 4];
            w.XData = 1:10;
            w.YData = randn(1, 10);
            s = w.toStruct();
            testCase.verifyFalse(isfield(s, 'showThresholdLabels'), 'testWidgetToStructOmitsWhenFalse');
        end

        function testWidgetToStructEmitsWhenTrue(testCase)
            w = FastSenseWidget();
            w.Title = 'Test';
            w.Position = [1 1 12 4];
            w.XData = 1:10;
            w.YData = randn(1, 10);
            w.ShowThresholdLabels = true;
            s = w.toStruct();
            testCase.verifyTrue(isfield(s, 'showThresholdLabels'), 'testWidgetToStructEmitsWhenTrue: field exists');
            testCase.verifyTrue(s.showThresholdLabels, 'testWidgetToStructEmitsWhenTrue: value');
        end

        function testWidgetFromStructRoundTrip(testCase)
            w = FastSenseWidget();
            w.Title = 'Test';
            w.Position = [1 1 12 4];
            w.XData = 1:10;
            w.YData = randn(1, 10);
            w.ShowThresholdLabels = true;
            s = w.toStruct();
            w2 = FastSenseWidget.fromStruct(s);
            testCase.verifyTrue(w2.ShowThresholdLabels, 'testWidgetFromStructRoundTrip');
        end
    end
end
