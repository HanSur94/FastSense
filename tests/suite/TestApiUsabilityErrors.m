classdef TestApiUsabilityErrors < matlab.unittest.TestCase
    %TESTAPIUSABILITYERRORS Regression tests for the API-usability error batch.
    %   Pins the namespaced error IDs and convenience behaviors introduced by
    %   the 2026-06 api-usability work (docs/.api-usability/audit-2026-06-29.md)
    %   so they cannot silently regress to raw MATLAB errors:
    %     FastSense:positionalData, MonitorTag:invalidConditionArity,
    %     DerivedTag:invalidCompute (arity), DashboardEngine:unknownTheme,
    %     FastSense:invalidThreshold, SensorTag:sizeMismatch,
    %     DashboardWidget 'Tag' string-key resolution, TagRegistry.keys(),
    %     addFill positional baseline.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function clearRegistry(testCase)
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function cleanup(testCase)
            TagRegistry.clear();
            close all force;
        end
    end

    methods (Test)
        % ---- FastSense constructor: positional-data guard ----
        function testPositionalCtorThrowsNamespaced(testCase)
            t = 1:10; y = sin(t);
            testCase.verifyError(@() FastSense(t, y), 'FastSense:positionalData');
        end

        function testNameValueCtorStillWorks(testCase)
            fp = FastSense('Verbose', false, 'YScale', 'log');
            testCase.verifyEqual(fp.YScale, 'log');
        end

        % ---- MonitorTag: ConditionFn arity ----
        function testMonitorConditionZeroArityThrows(testCase)
            st = SensorTag('s1', 'X', 1:10, 'Y', 1:10);
            testCase.verifyError(@() MonitorTag('m1', st, @() true), ...
                'MonitorTag:invalidConditionArity');
        end

        function testMonitorConditionOneArityThrows(testCase)
            st = SensorTag('s1', 'X', 1:10, 'Y', 1:10);
            testCase.verifyError(@() MonitorTag('m1', st, @(x) x > 5), ...
                'MonitorTag:invalidConditionArity');
        end

        function testMonitorConditionVararginAccepted(testCase)
            st = SensorTag('s1', 'X', 1:10, 'Y', 1:10);
            m = MonitorTag('m1', st, @(varargin) varargin{2} > 5);
            [~, my] = m.getXY();
            testCase.verifyEqual(numel(my), 10);
        end

        % ---- DerivedTag: ComputeFn arity ----
        function testDerivedComputeWrongArityThrows(testCase)
            a = SensorTag('a', 'X', 1:10, 'Y', 1:10);
            b = SensorTag('b', 'X', 1:10, 'Y', 1:10);
            testCase.verifyError(@() DerivedTag('d', {a, b}, @(x, Y) Y{1} + Y{2}), ...
                'DerivedTag:invalidCompute');
        end

        function testDerivedComputeSingleParentsArgAccepted(testCase)
            a = SensorTag('a', 'X', 1:10, 'Y', 1:10);
            d = DerivedTag('d', {a}, @(p) deal(p{1}.X, 2 * p{1}.Y));
            [~, dy] = d.getXY();
            testCase.verifyEqual(dy, 2 * (1:10));
        end

        % ---- DashboardEngine: Theme preset validation ----
        function testUnknownThemeThrows(testCase)
            testCase.verifyError(@() DashboardEngine('x', 'Theme', 'bogus'), ...
                'DashboardEngine:unknownTheme');
        end

        function testKnownAndLegacyThemesAccepted(testCase)
            d1 = DashboardEngine('x', 'Theme', 'dark');
            d2 = DashboardEngine('y', 'Theme', 'scientific');   % legacy alias
            testCase.verifyEqual(d1.Theme, 'dark');
            testCase.verifyEqual(d2.Theme, 'scientific');
        end

        % ---- addThreshold: value type ----
        function testNonNumericThresholdThrows(testCase)
            fp = FastSense();
            testCase.verifyError(@() fp.addThreshold('high'), ...
                'FastSense:invalidThreshold');
        end

        % ---- SensorTag: inline X/Y length check ----
        function testSensorTagSizeMismatchThrows(testCase)
            testCase.verifyError(@() SensorTag('bad', 'X', 1:100, 'Y', 1:50), ...
                'SensorTag:sizeMismatch');
        end

        function testSensorTagMatchedInlineDataAccepted(testCase)
            st = SensorTag('ok', 'X', 1:50, 'Y', 1:50);
            [x, ~] = st.getXY();
            testCase.verifyEqual(numel(x), 50);
        end

        % ---- DashboardWidget: 'Tag' accepts a registry key string ----
        function testWidgetTagStringKeyResolves(testCase)
            st = SensorTag('press_a', 'Name', 'Pressure A', 'X', 1:10, 'Y', 1:10);
            TagRegistry.register('press_a', st);
            d = DashboardEngine('x');
            w = d.addWidget('fastsense', 'Position', [1 1 6 3], 'Tag', 'press_a');
            testCase.verifyClass(w.Tag, 'SensorTag');
            testCase.verifyEqual(w.Title, 'Pressure A');   % title cascade from resolved Tag
        end

        function testWidgetTagMissingKeyThrowsUnknownKey(testCase)
            d = DashboardEngine('x');
            testCase.verifyError(@() d.addWidget('fastsense', ...
                'Position', [1 1 6 3], 'Tag', 'ghost_key'), ...
                'TagRegistry:unknownKey');
        end

        function testWidgetTagObjectStillPassesThrough(testCase)
            st = SensorTag('obj_tag', 'X', 1:10, 'Y', 1:10);
            d = DashboardEngine('x');
            w = d.addWidget('fastsense', 'Position', [1 1 6 3], 'Tag', st);
            testCase.verifySameHandle(w.Tag, st);
        end

        % ---- TagRegistry.keys ----
        function testKeysEmptyRegistry(testCase)
            k = TagRegistry.keys();
            testCase.verifyClass(k, 'cell');
            testCase.verifyEmpty(k);
        end

        function testKeysSorted(testCase)
            TagRegistry.register('zeta',  SensorTag('zeta',  'X', 1:3, 'Y', 1:3));
            TagRegistry.register('alpha', SensorTag('alpha', 'X', 1:3, 'Y', 1:3));
            TagRegistry.register('mike',  SensorTag('mike',  'X', 1:3, 'Y', 1:3));
            testCase.verifyEqual(TagRegistry.keys(), {'alpha', 'mike', 'zeta'});
        end

        % ---- addFill: positional baseline shorthand ----
        function testAddFillPositionalBaseline(testCase)
            t = linspace(0, 10, 100); y = sin(t);
            fp = FastSense();
            fp.addLine(t, y);
            fp.addFill(t, y, 0);   % shorthand for ..., 'Baseline', 0
            testCase.verifyEqual(numel(fp.Shadings), 1);
        end

        function testAddFillNameValueBaselineUnchanged(testCase)
            t = linspace(0, 10, 100); y = sin(t);
            fp = FastSense();
            fp.addLine(t, y);
            fp.addFill(t, y, 'Baseline', -1, 'FaceAlpha', 0.2);
            testCase.verifyEqual(numel(fp.Shadings), 1);
        end
    end
end
