classdef TestDashboardWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testIsAbstract(testCase)
            % Conceptually abstract: every subclass MUST override render(),
            % refresh(), and getType(). The class itself can be constructed
            % (Octave 11+ rejects `methods (Abstract)` outside @-folders, so
            % we declare concrete error-throwing stubs instead). Calling any
            % of the conceptually-abstract methods on a raw DashboardWidget
            % must raise DashboardWidget:notImplemented.
            w = DashboardWidget();
            testCase.verifyClass(w, 'DashboardWidget');
            testCase.verifyError(@() w.render([]), ...
                'DashboardWidget:notImplemented', ...
                'render() must throw notImplemented on raw DashboardWidget');
            testCase.verifyError(@() w.refresh(), ...
                'DashboardWidget:notImplemented', ...
                'refresh() must throw notImplemented on raw DashboardWidget');
            testCase.verifyError(@() w.getType(), ...
                'DashboardWidget:notImplemented', ...
                'getType() must throw notImplemented on raw DashboardWidget');
        end

        function testToStructFromStructRoundTrip(testCase)
            w = MockDashboardWidget();
            w.Title = 'Test Widget';
            w.Position = [1 2 8 3];

            s = w.toStruct();
            testCase.verifyEqual(s.title, 'Test Widget');
            testCase.verifyEqual(s.position, struct('col', 1, 'row', 2, 'width', 8, 'height', 3));

            w2 = MockDashboardWidget.fromStruct(s);
            testCase.verifyEqual(w2.Title, 'Test Widget');
            testCase.verifyEqual(w2.Position, [1 2 8 3]);
        end

        function testDefaultPosition(testCase)
            w = MockDashboardWidget();
            testCase.verifyEqual(w.Position, [1 1 6 2], ...
                'Default position should be [1 1 6 2]');
        end

        function testTypeProperty(testCase)
            w = MockDashboardWidget();
            testCase.verifyEqual(w.Type, 'mock', ...
                'Type should return widget type string');
        end

        function testDescriptionProperty(testCase)
            w = MockDashboardWidget('Description', 'Measures outlet temp');
            testCase.verifyEqual(w.Description, 'Measures outlet temp');
        end

        function testSensorProperty(testCase)
            s = SensorTag('T-401', 'Name', 'Temperature');
            w = MockDashboardWidget('Sensor', s);
            testCase.verifyEqual(w.Sensor.Key, 'T-401');
        end

        function testTitleDefaultsToSensorName(testCase)
            s = SensorTag('T-401', 'Name', 'Temperature');
            w = MockDashboardWidget('Sensor', s);
            testCase.verifyEqual(w.Title, 'Temperature');
        end

        function testTitleOverrideBeatsSensorName(testCase)
            s = SensorTag('T-401', 'Name', 'Temperature');
            w = MockDashboardWidget('Title', 'Custom', 'Sensor', s);
            testCase.verifyEqual(w.Title, 'Custom');
        end

        function testToStructIncludesDescription(testCase)
            w = MockDashboardWidget('Title', 'Test', 'Description', 'Info text');
            s = w.toStruct();
            testCase.verifyEqual(s.description, 'Info text');
        end

        function testClearPanelControlsPreservesInjectedTags(testCase)
            % clearPanelControls (shared helper used by every widget's
            % relayout_) must keep InfoIconButton and DetachButton while
            % wiping widget-owned uicontrols. Regression guard for the
            % bug where SizeChangedFcn-triggered relayout wiped the
            % icons DashboardLayout had just injected.
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);

            % Widget content (should be wiped)
            uicontrol('Parent', hp, 'Style', 'text', ...
                'Tag', 'widget-owned-label');
            uicontrol('Parent', hp, 'Style', 'edit', ...
                'Tag', 'widget-owned-edit');

            % Injected by DashboardLayout (must survive)
            uicontrol('Parent', hp, 'Style', 'pushbutton', ...
                'Tag', 'InfoIconButton');
            uicontrol('Parent', hp, 'Style', 'pushbutton', ...
                'Tag', 'DetachButton');

            MockDashboardWidget.invokeClearPanelControls(hp);

            testCase.verifyEmpty( ...
                findobj(hp, 'Tag', 'widget-owned-label'), ...
                'widget-owned controls should be deleted');
            testCase.verifyEmpty( ...
                findobj(hp, 'Tag', 'widget-owned-edit'), ...
                'widget-owned controls should be deleted');
            testCase.verifyNotEmpty( ...
                findobj(hp, 'Tag', 'InfoIconButton'), ...
                'InfoIconButton must survive a relayout');
            testCase.verifyNotEmpty( ...
                findobj(hp, 'Tag', 'DetachButton'), ...
                'DetachButton must survive a relayout');
        end

        function testClearPanelControlsHandlesInvalidHandle(testCase)
            % Helper must no-op on empty/invalid handles (relayout_ is
            % called unconditionally on SizeChangedFcn, sometimes after
            % the panel is already gone).
            MockDashboardWidget.invokeClearPanelControls([]);
            fakeHandle = matlab.graphics.GraphicsPlaceholder;
            MockDashboardWidget.invokeClearPanelControls(fakeHandle);
            testCase.verifyTrue(true, 'no-op path completed without error');
        end
    end
end
