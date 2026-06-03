classdef TestDashboardWidgetRegistry < matlab.unittest.TestCase
%TESTDASHBOARDWIDGETREGISTRY Tests for the single-source-of-truth widget registry.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodTeardown)
        function resetRegistry(~)
            % Persistent map must not leak between tests.
            DashboardWidgetRegistry.reset();
        end
    end

    methods (Test)
        function testTypesHas19IncludingDrifted(testCase)
            t = DashboardWidgetRegistry.types();
            testCase.verifyClass(t, 'cell');
            testCase.verifyEqual(numel(t), 19);
            % The three types that were missing from the old widgetTypes() list.
            testCase.verifyTrue(ismember('iconcard', t));
            testCase.verifyTrue(ismember('chipbar', t));
            testCase.verifyTrue(ismember('sparkline', t));
            % Sorted.
            testCase.verifyEqual(t, sort(t));
        end

        function testIsRegistered(testCase)
            testCase.verifyTrue(DashboardWidgetRegistry.isRegistered('number'));
            testCase.verifyTrue(DashboardWidgetRegistry.isRegistered('sparkline'));
            testCase.verifyFalse(DashboardWidgetRegistry.isRegistered('nope'));
            % An alias is NOT a registered canonical type.
            testCase.verifyFalse(DashboardWidgetRegistry.isRegistered('kpi'));
        end

        function testResolveAlias(testCase)
            testCase.verifyEqual(DashboardWidgetRegistry.resolveAlias('kpi'), 'number');
            testCase.verifyEqual(DashboardWidgetRegistry.resolveAlias('number'), 'number');
            testCase.verifyEqual(DashboardWidgetRegistry.resolveAlias('unknownxyz'), 'unknownxyz');
        end

        function testConstructorFor(testCase)
            h = DashboardWidgetRegistry.constructorFor('number');
            testCase.verifyClass(h, 'function_handle');
            testCase.verifyEqual(func2str(h), 'NumberWidget');
            % Alias resolves to the canonical constructor.
            hk = DashboardWidgetRegistry.constructorFor('kpi');
            testCase.verifyEqual(func2str(hk), 'NumberWidget');
        end

        function testConstructorForUnknownErrors(testCase)
            testCase.verifyError(@() DashboardWidgetRegistry.constructorFor('nope'), ...
                'DashboardWidgetRegistry:unknownType');
        end

        function testRegisterCustomType(testCase)
            DashboardWidgetRegistry.register('mytype', @NumberWidget);
            testCase.verifyTrue(DashboardWidgetRegistry.isRegistered('mytype'));
            testCase.verifyEqual(func2str(DashboardWidgetRegistry.constructorFor('mytype')), 'NumberWidget');
            testCase.verifyTrue(ismember('mytype', DashboardWidgetRegistry.types()));
        end

        function testDuplicateRegisterErrors(testCase)
            testCase.verifyError(@() DashboardWidgetRegistry.register('number', @NumberWidget), ...
                'DashboardWidgetRegistry:duplicateType');
        end

        function testRegisterNonHandleErrors(testCase)
            testCase.verifyError(@() DashboardWidgetRegistry.register('bad', 42), ...
                'DashboardWidgetRegistry:invalidType');
        end

        function testRegisterAlias(testCase)
            DashboardWidgetRegistry.registerAlias('kp2', 'number');
            testCase.verifyEqual(DashboardWidgetRegistry.resolveAlias('kp2'), 'number');
        end

        function testRegisterAliasToUnknownErrors(testCase)
            testCase.verifyError(@() DashboardWidgetRegistry.registerAlias('x', 'notRegistered'), ...
                'DashboardWidgetRegistry:unknownType');
        end

        function testFromStruct(testCase)
            base = NumberWidget('Title', 'N', 'Position', [1 1 4 2], 'StaticValue', 5);
            s = base.toStruct();
            w = DashboardWidgetRegistry.fromStruct('number', s);
            testCase.verifyClass(w, 'NumberWidget');
            % Alias path.
            wk = DashboardWidgetRegistry.fromStruct('kpi', s);
            testCase.verifyClass(wk, 'NumberWidget');
        end

        function testFromStructUnknownErrors(testCase)
            s = struct('type', 'nope', 'title', 'X', ...
                'position', struct('col', 1, 'row', 1, 'width', 4, 'height', 2));
            testCase.verifyError(@() DashboardWidgetRegistry.fromStruct('nope', s), ...
                'DashboardWidgetRegistry:unknownType');
        end

        function testReset(testCase)
            DashboardWidgetRegistry.register('mytype', @NumberWidget);
            testCase.verifyTrue(DashboardWidgetRegistry.isRegistered('mytype'));
            DashboardWidgetRegistry.reset();
            testCase.verifyEqual(numel(DashboardWidgetRegistry.types()), 19);
            testCase.verifyFalse(DashboardWidgetRegistry.isRegistered('mytype'));
            % Built-in alias survives the reset.
            testCase.verifyEqual(DashboardWidgetRegistry.resolveAlias('kpi'), 'number');
        end
    end
end
