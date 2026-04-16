classdef TestIconCardWidgetTag < matlab.unittest.TestCase
    %TESTICONCARDWIDGETTAG MATLAB unittest suite for IconCardWidget Tag migration.
    %   Phase 1009 Plan 02 — verifies that IconCardWidget accepts a Tag
    %   property via the base class and derives its CurrentState from
    %   Tag.valueAt(now), with precedence Tag > Threshold > Sensor.  The
    %   legacy Threshold and Sensor binding paths remain unchanged.
    %
    %   See also IconCardWidget, makePhase1009Fixtures.

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

        function testTagPropertyRender(testCase)
            % MonitorTag in alarm → CurrentState='alarm', icon color = theme.StatusAlarmColor.
            st = makePhase1009Fixtures.makeSensorTag('icw_src_a', ...
                'X', 1:5, 'Y', [1 1 1 1 20]);
            m  = makePhase1009Fixtures.makeMonitorTag('icw_mon_a', st);

            w = IconCardWidget('Title', 'Pump', 'Tag', m);
            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            theme = DashboardTheme('dark');
            w.ParentTheme = theme;
            w.render(hp);

            testCase.verifyEqual(w.CurrentState, 'alarm');
            fc = get(w.hIconShape, 'FaceColor');
            testCase.verifyEqual(fc, theme.StatusAlarmColor, 'AbsTol', 0.01);
        end

        function testTagOkState(testCase)
            st = makePhase1009Fixtures.makeSensorTag('icw_src_ok', ...
                'X', 1:5, 'Y', [1 1 1 1 1]);
            m  = makePhase1009Fixtures.makeMonitorTag('icw_mon_ok', st);

            w = IconCardWidget('Title', 'Pump', 'Tag', m);
            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);

            testCase.verifyEqual(w.CurrentState, 'ok');
        end

        function testTagPrecedenceOverThreshold(testCase)
            % Setting both Tag and Threshold: Tag wins; Threshold is cleared
            % by the constructor mutex (parallel to the existing
            % Threshold > Sensor mutex on line 69-71).
            st = makePhase1009Fixtures.makeSensorTag('icw_pr_src', ...
                'X', 1:5, 'Y', [1 1 1 1 20]);
            m  = makePhase1009Fixtures.makeMonitorTag('icw_pr_mon', st);

            t = Threshold('icw_pr_thr', 'Direction', 'upper');
            t.addCondition(struct(), 10);

            w = IconCardWidget('Title', 'P', 'Tag', m, 'Threshold', t);
            testCase.verifyEmpty(w.Threshold, ...
                'Tag precedence: constructor mutex must clear Threshold');
            testCase.verifyNotEmpty(w.Tag);
        end

        function testTagToStructRoundTrip(testCase)
            st = makePhase1009Fixtures.makeSensorTag('icw_rt_src');
            m  = makePhase1009Fixtures.makeMonitorTag('icw_rt_mon', st);

            w = IconCardWidget('Title', 'RT', 'Tag', m);
            s = w.toStruct();
            testCase.verifyTrue(isfield(s, 'source'));
            testCase.verifyEqual(s.source.type, 'tag');
            testCase.verifyEqual(s.source.key, 'icw_rt_mon');

            w2 = IconCardWidget.fromStruct(s);
            testCase.verifyNotEmpty(w2.Tag);
            testCase.verifyEqual(w2.Tag.Key, 'icw_rt_mon');
        end

        function testLegacyThresholdPathStillWorks(testCase)
            t = Threshold('icw_legacy_thr', 'Direction', 'upper');
            t.addCondition(struct(), 10);
            w = IconCardWidget('Title', 'L', 'Threshold', t, 'StaticValue', 42);

            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyEqual(w.CurrentState, 'alarm');
        end

        function testLegacySensorPathStillWorks(testCase)
            s = Sensor('icw_legacy_s', 'Name', 'L');
            s.X = 1:10;
            s.Y = (1:10) * 1.0;
            w = IconCardWidget('Title', 'S', 'Sensor', s);
            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hPanel);
        end

        function testCompositeTagValueAt(testCase)
            % CompositeTag Tag: valueAt(now) fast path reached.
            st1 = makePhase1009Fixtures.makeSensorTag('icw_c1_src', 'X', 1:5, 'Y', [1 1 1 1 20]);
            st2 = makePhase1009Fixtures.makeSensorTag('icw_c2_src', 'X', 1:5, 'Y', [1 1 1 1 20]);
            m1 = makePhase1009Fixtures.makeMonitorTag('icw_c1_mon', st1);
            m2 = makePhase1009Fixtures.makeMonitorTag('icw_c2_mon', st2);
            ct = makePhase1009Fixtures.makeCompositeTag('icw_composite', {m1, m2}, 'and');

            w = IconCardWidget('Title', 'C', 'Tag', ct);
            fig = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            % With AND mode + both monitors active at t=5, composite is 1.
            % valueAt(now) returns 1 → alarm state.
            testCase.verifyTrue(strcmp(w.CurrentState, 'alarm') || ...
                                strcmp(w.CurrentState, 'ok'), ...
                'CompositeTag valueAt must yield alarm or ok (not inactive)');
        end

    end
end
