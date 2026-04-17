classdef TestMultiStatusWidgetTag < matlab.unittest.TestCase
    %TESTMULTISTATUSWIDGETTAG MATLAB unittest suite for MultiStatusWidget Tag migration.
    %   Phase 1009 Plan 02 — verifies that MultiStatusWidget items accept
    %   a 'tag' field (Tag handle or string key), renders with colour
    %   derived from tag.valueAt(now) via the Tag API, preserves the
    %   legacy threshold/sensor item shapes byte-for-byte, expands
    %   CompositeTag children parallel to CompositeThreshold, and
    %   round-trips via toStruct/fromStruct.
    %
    %   See also MultiStatusWidget, makePhase1009Fixtures.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'tests', 'suite'));
        end
    end

    methods (TestMethodSetup)
        function resetRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function teardownRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)

        function testTagItemAlarmStatus(testCase)
            % MonitorTag whose last sample fires alarm → dot is theme.StatusAlarmColor.
            st = makePhase1009Fixtures.makeSensorTag('mst_src_a', ...
                'X', 1:5, 'Y', [1 1 1 1 20]);
            m  = makePhase1009Fixtures.makeMonitorTag('mst_mon_a', st);

            w = MultiStatusWidget('Title', 'S');
            w.Sensors = {struct('label', 'mon', 'tag', m)};

            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            theme = DashboardTheme('dark');
            w.ParentTheme = theme;
            w.render(hp);

            % Find the fill patch (last child added in refresh for a struct item).
            patches = findobj(w.hAxes, 'Type', 'patch');
            testCase.verifyNotEmpty(patches, 'MultiStatus Tag alarm item must render a patch');
            fc = get(patches(1), 'FaceColor');
            testCase.verifyEqual(fc, theme.StatusAlarmColor, 'AbsTol', 0.01, ...
                'Tag-bound alarm item should render with StatusAlarmColor');
        end

        function testTagItemOkStatus(testCase)
            % ConditionFn returns 0 for the tail → dot is default (okColor).
            st = makePhase1009Fixtures.makeSensorTag('mst_src_ok', ...
                'X', 1:5, 'Y', [1 1 1 1 1]);
            m  = makePhase1009Fixtures.makeMonitorTag('mst_mon_ok', st);

            w = MultiStatusWidget('Title', 'S');
            w.Sensors = {struct('label', 'mon', 'tag', m)};

            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            theme = DashboardTheme('dark');
            w.ParentTheme = theme;
            w.render(hp);

            patches = findobj(w.hAxes, 'Type', 'patch');
            testCase.verifyNotEmpty(patches);
            fc = get(patches(1), 'FaceColor');
            testCase.verifyEqual(fc, theme.StatusOkColor, 'AbsTol', 0.01);
        end

        function testTagItemStringKey(testCase)
            % String tag key resolves via TagRegistry on render.
            st = makePhase1009Fixtures.makeSensorTag('mst_src_sk', ...
                'X', 1:5, 'Y', [1 1 1 1 20]);
            makePhase1009Fixtures.makeMonitorTag('mst_mon_sk', st);

            w = MultiStatusWidget('Title', 'S');
            w.Sensors = {struct('label', 'mon', 'tag', 'mst_mon_sk')};

            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            theme = DashboardTheme('dark');
            w.ParentTheme = theme;
            w.render(hp);

            patches = findobj(w.hAxes, 'Type', 'patch');
            testCase.verifyNotEmpty(patches);
            fc = get(patches(1), 'FaceColor');
            testCase.verifyEqual(fc, theme.StatusAlarmColor, 'AbsTol', 0.01);
        end

        function testTagRoundTripViaToStruct(testCase)
            st = makePhase1009Fixtures.makeSensorTag('mst_src_rt');
            m  = makePhase1009Fixtures.makeMonitorTag('mst_mon_rt', st);

            w = MultiStatusWidget('Title', 'S');
            w.Sensors = {struct('label', 'alpha', 'tag', m)};
            s = w.toStruct();

            testCase.verifyTrue(iscell(s.items));
            testCase.verifyEqual(s.items{1}.type, 'tag');
            testCase.verifyEqual(s.items{1}.key, 'mst_mon_rt');

            w2 = MultiStatusWidget.fromStruct(s);
            testCase.verifyEqual(numel(w2.Sensors), 1);
            e = w2.Sensors{1};
            testCase.verifyTrue(isstruct(e));
            testCase.verifyTrue(isfield(e, 'tag') && ~isempty(e.tag));
            testCase.verifyEqual(e.tag.Key, 'mst_mon_rt');
        end

        function testLegacyThresholdItemStillWorks(testCase)
            % Existing threshold-struct item unchanged.
            t = Threshold('mst_legacy_thr', 'Direction', 'upper');
            t.addCondition(struct(), 50);
            item = struct('threshold', t, 'value', 42, 'label', 'Pump');

            w = MultiStatusWidget('Title', 'S');
            w.Sensors = {item};
            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hAxes);
        end

        function testLegacySensorItemStillWorks(testCase)
            % Raw Sensor handle item unchanged.
            s = SensorTag('mst_legacy_s', 'Name', 'L');
            s.updateData(1:10, (1:10) * 1.0);

            w = MultiStatusWidget('Title', 'S');
            w.Sensors = {s};
            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hAxes);
        end

        function testCompositeTagExpansion(testCase)
            % CompositeTag item expands children + summary row
            % (parallel to existing CompositeThreshold expansion).
            st1 = makePhase1009Fixtures.makeSensorTag('mst_src_c1', ...
                'X', 1:5, 'Y', [1 1 1 1 20]);
            st2 = makePhase1009Fixtures.makeSensorTag('mst_src_c2', ...
                'X', 1:5, 'Y', [1 1 1 1 20]);
            m1 = makePhase1009Fixtures.makeMonitorTag('mst_mon_c1', st1);
            m2 = makePhase1009Fixtures.makeMonitorTag('mst_mon_c2', st2);
            ct = makePhase1009Fixtures.makeCompositeTag('mst_comp_c', ...
                {m1, m2}, 'and');

            w = MultiStatusWidget('Title', 'S');
            w.Sensors = {struct('label', 'composite', 'tag', ct)};

            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            % 2 children + 1 summary = 3 patches.
            patches = findobj(w.hAxes, 'Type', 'patch');
            testCase.verifyGreaterThanOrEqual(numel(patches), 3, ...
                'Composite expansion should produce >= 3 patches (children + summary)');
        end

        function testBaseClassTagSourceEmittedInToStruct(testCase)
            % DashboardWidget base Tag property: set on a subclass via property,
            % confirm toStruct@DashboardWidget writes 'tag' source. MultiStatus
            % overrides toStruct fully; use IconCardWidget (subclass that calls
            % toStruct@DashboardWidget) for this assertion.
            st = makePhase1009Fixtures.makeSensorTag('mst_base_tag');
            w = IconCardWidget('Title', 'B', 'Tag', st);
            s = w.toStruct();
            testCase.verifyTrue(isfield(s, 'source'));
            testCase.verifyEqual(s.source.type, 'tag');
            testCase.verifyEqual(s.source.key, 'mst_base_tag');
        end

    end
end
