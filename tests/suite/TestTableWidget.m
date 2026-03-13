classdef TestTableWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = TableWidget('Title', 'Data', 'Data', {{'A',1;'B',2}});
            testCase.verifyEqual(w.Title, 'Data');
        end

        function testDefaultPosition(testCase)
            w = TableWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 4 2]);
        end

        function testGetType(testCase)
            w = TableWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'table');
        end

        function testToStructFromStruct(testCase)
            w = TableWidget('Title', 'Readings', ...
                'ColumnNames', {'Sensor','Value'}, ...
                'Position', [1 1 6 3]);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'table');
            testCase.verifyEqual(s.title, 'Readings');

            w2 = TableWidget.fromStruct(s);
            testCase.verifyEqual(w2.Title, 'Readings');
            testCase.verifyEqual(w2.Position, [1 1 6 3]);
        end

        function testRender(testCase)
            w = TableWidget('Title', 'Test Table', ...
                'Data', {'A',1;'B',2}, 'ColumnNames', {'Name','Val'});
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyNotEmpty(w.hTable);
        end
    end
end
