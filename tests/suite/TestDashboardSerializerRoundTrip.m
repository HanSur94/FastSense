classdef TestDashboardSerializerRoundTrip < matlab.unittest.TestCase
    properties
        TempDir
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

    methods (Access = private)
        function widgets = createAllWidgets(~)
            %CREATEALLWIDGETS Build one widget of each type with minimal config.
            widgets = cell(1, 9);
            widgets{1} = FastSenseWidget('Title', 'FSW', 'Position', [1 1 12 3], ...
                'XData', 1:5, 'YData', [1 2 3 4 5]);
            widgets{2} = NumberWidget('Title', 'NW', 'Position', [1 4 6 1], ...
                'StaticValue', 42, 'Units', 'V');
            widgets{3} = StatusWidget('Title', 'SW', 'Position', [7 4 4 1], ...
                'StaticStatus', 'ok');
            widgets{4} = GaugeWidget('Title', 'GW', 'Position', [1 5 6 4], ...
                'StaticValue', 55, 'Range', [0 100], 'Units', 'psi');
            widgets{5} = TextWidget('Title', 'TW', 'Position', [7 5 6 1], ...
                'Content', 'Hello');
            widgets{6} = TableWidget('Title', 'TBW', 'Position', [13 1 12 3], ...
                'Data', {{'A',1; 'B',2}}, 'ColumnNames', {'Name','Val'});
            widgets{7} = RawAxesWidget('Title', 'RAW', 'Position', [13 4 12 4]);
            widgets{8} = EventTimelineWidget('Title', 'ETW', 'Position', [1 9 24 2], ...
                'Events', struct('startTime', {0, 10}, 'endTime', {5, 20}, ...
                'label', {'A', 'B'}));
            widgets{9} = DividerWidget('Title', 'DIV', 'Position', [1 8 24 1], 'Thickness', 2);
        end
    end

    methods (Test)
        function testAllWidgetTypesRoundTrip(testCase)
            %TESTALLWIDGETTYPESROUNDTRIP Serialize all 8 types to JSON,
            %   load back, convert to widgets, and verify type/title/position.
            widgets = testCase.createAllWidgets();

            % Build config and save to JSON
            config = DashboardSerializer.widgetsToConfig( ...
                'RoundTrip Test', 'dark', 5, widgets);
            filepath = fullfile(testCase.TempDir, 'roundtrip.json');
            DashboardSerializer.saveJSON(config, filepath);

            % Load back and reconstruct widgets
            loaded = DashboardSerializer.loadJSON(filepath);
            rebuilt = DashboardSerializer.configToWidgets(loaded);

            testCase.verifyEqual(numel(rebuilt), 9, ...
                'All 9 widget types should survive the round-trip');

            expectedTypes  = {'fastsense','number','status','gauge', ...
                              'text','table','rawaxes','timeline','divider'};
            expectedTitles = {'FSW','NW','SW','GW','TW','TBW','RAW','ETW','DIV'};
            expectedPos    = {[1 1 12 3],[1 4 6 1],[7 4 4 1],[1 5 6 4], ...
                              [7 5 6 1],[13 1 12 3],[13 4 12 4],[1 9 24 2],[1 8 24 1]};

            for i = 1:9
                testCase.verifyEqual(rebuilt{i}.Type, expectedTypes{i}, ...
                    sprintf('Widget %d type mismatch', i));
                testCase.verifyEqual(rebuilt{i}.Title, expectedTitles{i}, ...
                    sprintf('Widget %d title mismatch', i));
                testCase.verifyEqual(rebuilt{i}.Position, expectedPos{i}, ...
                    sprintf('Widget %d position mismatch', i));
            end
        end

        function testExportScriptContainsAllTypes(testCase)
            %TESTEXPORTSCRIPTCONTAINSALLTYPES Export to .m, verify addWidget
            %   calls for every widget type.
            widgets = testCase.createAllWidgets();

            config = DashboardSerializer.widgetsToConfig( ...
                'Script Export Test', 'light', 3, widgets);
            filepath = fullfile(testCase.TempDir, 'export_all.m');
            DashboardSerializer.exportScript(config, filepath);

            testCase.verifyTrue(exist(filepath, 'file') == 2, ...
                'Exported .m file should exist');

            content = fileread(filepath);
            testCase.verifyTrue(contains(content, 'DashboardEngine'), ...
                'Script should reference DashboardEngine');

            expectedTypes = {'fastsense','number','status','gauge', ...
                             'text','table','rawaxes','timeline','divider'};
            for i = 1:numel(expectedTypes)
                testCase.verifyTrue( ...
                    contains(content, sprintf('''%s''', expectedTypes{i})), ...
                    sprintf('Script should contain addWidget call for type ''%s''', ...
                        expectedTypes{i}));
            end

            expectedTitles = {'FSW','NW','SW','GW','TW','TBW','RAW','ETW'};
            for i = 1:numel(expectedTitles)
                testCase.verifyTrue(contains(content, expectedTitles{i}), ...
                    sprintf('Script should contain title ''%s''', expectedTitles{i}));
            end
        end

        function testRoundTripPreservesWidgetSpecificProperties(testCase)
            %TESTROUNDTRIPPRESERVESWIDGETSPECIFICPROPERTIES Verify that
            %   widget-specific properties survive serialize/deserialize.
            widgets = testCase.createAllWidgets();

            config = DashboardSerializer.widgetsToConfig( ...
                'Props Test', 'dark', 5, widgets);
            filepath = fullfile(testCase.TempDir, 'props.json');
            DashboardSerializer.saveJSON(config, filepath);

            loaded = DashboardSerializer.loadJSON(filepath);
            rebuilt = DashboardSerializer.configToWidgets(loaded);

            % FastSenseWidget: XData and YData via source.data
            fsw = rebuilt{1};
            testCase.verifyEqual(fsw.XData, 1:5, ...
                'FastSenseWidget XData should be preserved');
            testCase.verifyEqual(fsw.YData, [1 2 3 4 5], ...
                'FastSenseWidget YData should be preserved');

            % NumberWidget: Units, StaticValue, Format
            nw = rebuilt{2};
            testCase.verifyEqual(nw.Units, 'V', ...
                'NumberWidget Units should be preserved');
            testCase.verifyEqual(nw.StaticValue, 42, ...
                'NumberWidget StaticValue should be preserved');
            testCase.verifyEqual(nw.Format, '%.1f', ...
                'NumberWidget Format should be preserved');

            % StatusWidget: StaticStatus via source.static
            sw = rebuilt{3};
            testCase.verifyEqual(sw.StaticStatus, 'ok', ...
                'StatusWidget StaticStatus should be preserved');

            % GaugeWidget: Range, Units, Style
            gw = rebuilt{4};
            testCase.verifyEqual(gw.Range, [0 100], ...
                'GaugeWidget Range should be preserved');
            testCase.verifyEqual(gw.Units, 'psi', ...
                'GaugeWidget Units should be preserved');
            testCase.verifyEqual(gw.Style, 'arc', ...
                'GaugeWidget Style should be preserved');
            testCase.verifyEqual(gw.StaticValue, 55, ...
                'GaugeWidget StaticValue should be preserved');

            % TextWidget: Content, Alignment
            tw = rebuilt{5};
            testCase.verifyEqual(tw.Content, 'Hello', ...
                'TextWidget Content should be preserved');
            testCase.verifyEqual(tw.Alignment, 'left', ...
                'TextWidget Alignment should be preserved');

            % TableWidget: ColumnNames, Mode
            tbw = rebuilt{6};
            testCase.verifyEqual(tbw.ColumnNames, {'Name','Val'}, ...
                'TableWidget ColumnNames should be preserved');
            testCase.verifyEqual(tbw.Mode, 'data', ...
                'TableWidget Mode should be preserved');

            % RawAxesWidget: no PlotFcn (callbacks are not serializable)
            raw = rebuilt{7};
            testCase.verifyTrue(isa(raw, 'RawAxesWidget'), ...
                'RawAxesWidget class should be preserved');
            testCase.verifyEmpty(raw.PlotFcn, ...
                'RawAxesWidget PlotFcn should be empty after round-trip');

            % EventTimelineWidget: Events struct with startTime/endTime/label
            etw = rebuilt{8};
            testCase.verifyTrue(~isempty(etw.Events), ...
                'EventTimelineWidget Events should not be empty');
            testCase.verifyEqual(etw.Events(1).startTime, 0, ...
                'EventTimelineWidget first event startTime should be 0');
            testCase.verifyEqual(etw.Events(2).endTime, 20, ...
                'EventTimelineWidget second event endTime should be 20');
            testCase.verifyEqual(etw.Events(1).label, 'A', ...
                'EventTimelineWidget first event label should be A');
            testCase.verifyEqual(etw.Events(2).label, 'B', ...
                'EventTimelineWidget second event label should be B');
        end

        function testChartCallbackRoundTrip(testCase)
            %TESTCHARTCALLBACKROUNDTRIP P0-3: a callback chart widget's DataFcn
            %   must survive toStruct/fromStruct (was silently dropped before).
            w = BarChartWidget('Title', 'Bars');
            w.DataFcn = @() [1 2 3];
            s = w.toStruct();
            w2 = BarChartWidget.fromStruct(s);
            testCase.verifyNotEmpty(w2.DataFcn, 'DataFcn must be restored from s.source');
            testCase.verifyEqual(func2str(w2.DataFcn), func2str(w.DataFcn));
        end

        function testScatterSensorRoundTrip(testCase)
            %TESTSCATTERSENSORROUNDTRIP P0-3: Scatter SensorX/SensorY must be
            %   restored from TagRegistry on load (was silently dropped before).
            TagRegistry.clear();
            testCase.addTeardown(@() TagRegistry.clear());
            tx = SensorTag('sx', 'X', 1:5, 'Y', 1:5);
            ty = SensorTag('sy', 'X', 1:5, 'Y', 2:6);
            TagRegistry.register('sx', tx);
            TagRegistry.register('sy', ty);
            w = ScatterWidget('Title', 'Sc');
            w.SensorX = tx;
            w.SensorY = ty;
            s = w.toStruct();
            w2 = ScatterWidget.fromStruct(s);
            testCase.verifyNotEmpty(w2.SensorX, 'SensorX must be restored');
            testCase.verifyNotEmpty(w2.SensorY, 'SensorY must be restored');
            testCase.verifyEqual(w2.SensorX.Key, 'sx');
        end

        function testChartOldStructNoSourceLoadsQuietly(testCase)
            %TESTCHARTOLDSTRUCTNOSOURCELOADSQUIETLY P0-3 backward-compat: an old
            %   chart struct WITHOUT s.source must load with no binding and NO warning.
            s = struct('type', 'barchart', 'title', 'B', ...
                'position', struct('col', 1, 'row', 1, 'width', 8, 'height', 4));
            lastwarn('');
            w2 = BarChartWidget.fromStruct(s);
            [~, wid] = lastwarn();
            testCase.verifyEmpty(wid, 'Old struct without source must not emit a warning');
            testCase.verifyEmpty(w2.DataFcn);
        end

        function testSaveEmitsNumberBinding(testCase)
            %TESTSAVEEMITSNUMBERBINDING P0-3: DashboardSerializer.save (.m export)
            %   must emit the ValueFcn binding (it was dropped before the fix).
            d = DashboardEngine('rt');
            d.addWidget('number', 'Title', 'Speed', 'Position', [1 1 4 2], ...
                'ValueFcn', @() 42);
            filepath = fullfile(testCase.TempDir, 'rtbind.m');
            d.save(filepath);
            txt = fileread(filepath);
            testCase.verifyTrue(contains(txt, 'ValueFcn'), ...
                'save() must emit the number ValueFcn binding');
        end
    end
end
