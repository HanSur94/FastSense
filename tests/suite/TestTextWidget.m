classdef TestTextWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = TextWidget('Title', 'Section A', 'Content', 'Overview of sensors');
            testCase.verifyEqual(w.Title, 'Section A');
            testCase.verifyEqual(w.Content, 'Overview of sensors');
        end

        function testDefaultPosition(testCase)
            w = TextWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 3 1]);
        end

        function testGetType(testCase)
            w = TextWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'text');
        end

        function testToStructFromStruct(testCase)
            w = TextWidget('Title', 'Header', 'Content', 'Body text', ...
                'Position', [1 1 6 1], 'FontSize', 16);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'text');
            testCase.verifyEqual(s.content, 'Body text');
            testCase.verifyEqual(s.fontSize, 16);

            w2 = TextWidget.fromStruct(s);
            testCase.verifyEqual(w2.Title, 'Header');
            testCase.verifyEqual(w2.Content, 'Body text');
            testCase.verifyEqual(w2.FontSize, 16);
        end

        function testRender(testCase)
            w = TextWidget('Title', 'Header', 'Content', 'Some text');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            children = allchild(hp);
            testCase.verifyGreaterThanOrEqual(numel(children), 1);
        end

        function testRenderTitleOnly(testCase)
            w = TextWidget('Title', 'Just a Title');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            children = allchild(hp);
            testCase.verifyGreaterThanOrEqual(numel(children), 1);
        end

        function testRefreshIsNoOp(testCase)
            w = TextWidget('Title', 'Static');
            % Should not error
            w.refresh();
        end
    end
end
