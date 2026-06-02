classdef TestDashboardEngineWidgetTypes < matlab.unittest.TestCase
%TESTDASHBOARDENGINEWIDGETTYPES Engine widget-type dispatch through the registry.
%   Figure-free: exercises the static widgetTypes()/registerWidgetType API and
%   addWidget dispatch (no render), so it is fast and headless-safe.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodTeardown)
        function resetRegistry(~)
            DashboardWidgetRegistry.reset();
        end
    end

    methods (Test)
        function testWidgetTypesIncludesDriftedTypes(testCase)
            % The stale static list was missing these three (the drift bug).
            t = DashboardEngine.widgetTypes();
            names = t(:, 1);
            testCase.verifyTrue(ismember('iconcard', names));
            testCase.verifyTrue(ismember('chipbar', names));
            testCase.verifyTrue(ismember('sparkline', names));
            % Now derived from the registry => 19 entries.
            testCase.verifyEqual(size(t, 1), 19);
        end

        function testAddWidgetDispatchesViaRegistry(testCase)
            d = DashboardEngine('T');
            w = d.addWidget('number', 'Title', 'N', 'Position', [1 1 4 2]);
            testCase.verifyClass(w, 'NumberWidget');
        end

        function testKpiStillDeprecatedAndReturnsNumber(testCase)
            d = DashboardEngine('T');
            lastwarn('');
            w = d.addWidget('kpi', 'Title', 'K', 'Position', [1 1 4 2]);
            [~, id] = lastwarn();
            testCase.verifyEqual(id, 'DashboardEngine:deprecated');
            testCase.verifyClass(w, 'NumberWidget');
        end

        function testRegisterWidgetTypeThenAdd(testCase)
            % The documented extension surface: register once, works everywhere.
            DashboardEngine.registerWidgetType('mytype', @NumberWidget);
            tt = DashboardEngine.widgetTypes();
            testCase.verifyTrue(ismember('mytype', tt(:, 1)));
            d = DashboardEngine('T');
            w = d.addWidget('mytype', 'Title', 'X', 'Position', [1 1 4 2]);
            testCase.verifyClass(w, 'NumberWidget');
        end

        function testUnknownTypeStillErrors(testCase)
            d = DashboardEngine('T');
            testCase.verifyError(@() d.addWidget('definitelynotatype', 'Title', 'x'), ...
                'DashboardEngine:unknownType');
        end
    end
end
