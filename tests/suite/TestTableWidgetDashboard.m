classdef TestTableWidgetDashboard < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = TableWidget('Title', 'Sensor Table');
            testCase.verifyEqual(w.Title, 'Sensor Table');
            testCase.verifyEmpty(w.DataFcn);
            testCase.verifyEmpty(w.Data);
            testCase.verifyEmpty(w.ColumnNames);
            testCase.verifyEqual(w.Mode, 'data');
            testCase.verifyEqual(w.N, 10);
        end

        function testDefaultPosition(testCase)
            w = TableWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 8 2], ...
                'TableWidget default position should be [1 1 8 2]');
        end

        function testRender(testCase)
            w = TableWidget('Title', 'Render Test', ...
                'Data', {'X',1; 'Y',2}, 'ColumnNames', {'Name','Val'});
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyNotEmpty(w.hTable, ...
                'uitable handle should be created after render');
        end

        function testRefreshStaticData(testCase)
            staticData = {'Alpha', 10; 'Beta', 20; 'Gamma', 30};
            w = TableWidget('Title', 'Static', 'Data', staticData, ...
                'ColumnNames', {'Label','Value'});
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            tableData = get(w.hTable, 'Data');
            testCase.verifyEqual(tableData, staticData, ...
                'Data property should populate uitable after render/refresh');
        end

        function testRefreshWithDataFcn(testCase)
            callCount = 0;
            myFcn = @() evalAndCount();
            function d = evalAndCount()
                callCount = callCount + 1;
                d = {'Row1', callCount};
            end
            w = TableWidget('Title', 'Callback', 'DataFcn', myFcn);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);  % first call via render -> refresh
            firstData = get(w.hTable, 'Data');
            testCase.verifyEqual(firstData{1,1}, 'Row1');
            w.refresh();   % second call
            secondData = get(w.hTable, 'Data');
            testCase.verifyGreaterThan(secondData{1,2}, firstData{1,2}, ...
                'DataFcn should be called again on refresh');
        end

        function testToStruct(testCase)
            w = TableWidget('Title', 'Stats', ...
                'Data', {'A',1}, 'ColumnNames', {'Key','Val'}, ...
                'Position', [2 3 10 4]);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'table');
            testCase.verifyEqual(s.title, 'Stats');
            testCase.verifyEqual(s.columnNames, {'Key','Val'});
            testCase.verifyEqual(s.position, ...
                struct('col', 2, 'row', 3, 'width', 10, 'height', 4));
            testCase.verifyEqual(s.source.type, 'static');
        end

        function testFromStruct(testCase)
            w = TableWidget('Title', 'Round Trip', ...
                'Data', {'X',99}, 'ColumnNames', {'Name','Value'}, ...
                'Position', [3 2 12 5]);
            s = w.toStruct();
            w2 = TableWidget.fromStruct(s);
            testCase.verifyEqual(w2.Title, 'Round Trip');
            testCase.verifyEqual(w2.Position, [3 2 12 5]);
            testCase.verifyEqual(w2.ColumnNames, {'Name','Value'});
        end

        function testGetType(testCase)
            w = TableWidget();
            testCase.verifyEqual(w.getType(), 'table');
        end
    end
end
