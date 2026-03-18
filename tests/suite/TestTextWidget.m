classdef TestTextWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = TextWidget();
            testCase.verifyEqual(w.Content, '', ...
                'Default Content should be empty string');
            testCase.verifyEqual(w.FontSize, 0, ...
                'Default FontSize should be 0 (theme default)');
            testCase.verifyEqual(w.Alignment, 'left', ...
                'Default Alignment should be left');
        end

        function testDefaultPosition(testCase)
            w = TextWidget();
            testCase.verifyEqual(w.Position, [1 1 6 1], ...
                'TextWidget default position should be [1 1 6 1]');
        end

        function testRenderTitleOnly(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            panel = uipanel('Parent', fig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            w = TextWidget('Title', 'Section A');
            w.render(panel);

            testCase.verifyNotEmpty(w.Title);
            testCase.verifyEmpty(w.Content);
        end

        function testRenderContentOnly(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            panel = uipanel('Parent', fig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            w = TextWidget('Content', 'Some body text');
            w.render(panel);

            testCase.verifyEmpty(w.Title);
            testCase.verifyEqual(w.Content, 'Some body text');
        end

        function testRenderTitleAndContent(testCase)
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            panel = uipanel('Parent', fig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            w = TextWidget('Title', 'Header', 'Content', 'Details here');
            w.render(panel);

            testCase.verifyEqual(w.Title, 'Header');
            testCase.verifyEqual(w.Content, 'Details here');
        end

        function testRefreshIsNoop(testCase)
            w = TextWidget('Title', 'Static');
            % refresh should complete without error
            testCase.verifyWarningFree(@() w.refresh(), ...
                'refresh on a static TextWidget should be a no-op');
        end

        function testCustomFontSize(testCase)
            w = TextWidget('FontSize', 18);
            testCase.verifyEqual(w.FontSize, 18, ...
                'Custom FontSize should be respected');
        end

        function testCustomAlignment(testCase)
            w = TextWidget('Alignment', 'center');
            testCase.verifyEqual(w.Alignment, 'center', ...
                'Custom Alignment should be respected');
        end

        function testToStruct(testCase)
            w = TextWidget('Title', 'Info', 'Content', 'Hello world', ...
                'FontSize', 12, 'Alignment', 'right');
            w.Position = [2 3 4 1];

            s = w.toStruct();

            testCase.verifyEqual(s.type, 'text');
            testCase.verifyEqual(s.title, 'Info');
            testCase.verifyEqual(s.content, 'Hello world');
            testCase.verifyEqual(s.fontSize, 12);
            testCase.verifyEqual(s.alignment, 'right');
            testCase.verifyEqual(s.position, struct('col', 2, 'row', 3, ...
                'width', 4, 'height', 1));
        end

        function testFromStruct(testCase)
            w = TextWidget('Title', 'Round Trip', 'Content', 'Body', ...
                'FontSize', 14, 'Alignment', 'center');
            w.Position = [3 2 5 1];

            s = w.toStruct();
            w2 = TextWidget.fromStruct(s);

            testCase.verifyEqual(w2.Title, w.Title);
            testCase.verifyEqual(w2.Content, w.Content);
            testCase.verifyEqual(w2.FontSize, w.FontSize);
            testCase.verifyEqual(w2.Alignment, w.Alignment);
            testCase.verifyEqual(w2.Position, w.Position);
        end

        function testGetType(testCase)
            w = TextWidget();
            testCase.verifyEqual(w.getType(), 'text', ...
                'getType should return text');
        end
    end
end
