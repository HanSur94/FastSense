classdef TestDashboardDetach < matlab.unittest.TestCase
%TESTDASHBOARDDETACH Unit tests for DetachedMirror and DashboardEngine detach wiring.
%
%   Covers DETACH-01 through DETACH-07:
%     DETACH-01: Every widget shows a detach button in header chrome
%     DETACH-02: Clicking detach opens widget as standalone figure window
%     DETACH-03: Detached widget receives live updates from engine timer
%     DETACH-04: Closing detached figure removes it from mirror registry
%     DETACH-05: Detached FastSenseWidget gets independent time axis zoom
%     DETACH-06: Multiple detaches do not create extra MATLAB timers
%     DETACH-07: Detached widgets are read-only mirrors (different object handles)
%
%   Test status by group:
%     PASS immediately (DetachedMirror.cloneWidget self-contained):
%       testFastSenseIndependentZoom  (DETACH-05)
%       testNoExtraTimers             (DETACH-06)
%       testMirrorIsReadOnly          (DETACH-07)
%
%     FAIL until Plan 02 (DashboardLayout.addDetachButton wiring):
%       testDetachButtonInjected      (DETACH-01)
%
%     FAIL until Plan 03 (DashboardEngine.detachWidget + onLiveTick):
%       testDetachOpensWindow         (DETACH-02)
%       testMirrorTickedOnLive        (DETACH-03)
%       testCloseRemovesFromRegistry  (DETACH-04)

    methods (TestClassSetup)
        function addPaths(testCase)
        %ADDPATHS Add project paths so all Dashboard classes are reachable.
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodTeardown)
        function closeFigures(testCase) %#ok<MANU>
        %CLOSEFIGURES Close any figures opened during a test to avoid leaks.
            close all force;
        end
    end

    % -----------------------------------------------------------------------
    % Helper: build a minimal FastSenseWidget with a stub sensor-like struct
    % -----------------------------------------------------------------------
    methods (Access = private)

        function [widget, fakeSensor] = makeFastSenseWidget(testCase) %#ok<MANU>
        %MAKEFASTSENSEWIDGET Return a FastSenseWidget with a lightweight Sensor-like object.
        %
        %   Uses a real Sensor from SensorRegistry if possible; otherwise creates
        %   and registers a minimal Sensor so cloneWidget is exercised without
        %   requiring a live DataStore.

            sensorKey = '__detach_test__';
            try
                fakeSensor = TagRegistry.get(sensorKey);
            catch
                fakeSensor = SensorTag(sensorKey, 'Name', 'Test Sensor');
                fakeSensor.updateData(1:10, rand(1, 10));
                try
                    TagRegistry.register(sensorKey, fakeSensor);
                catch
                end
            end

            widget = FastSenseWidget('Title', 'TestFSW', ...
                'Position', [1 1 12 3], ...
                'Sensor', fakeSensor);
        end

    end

    % -----------------------------------------------------------------------
    % DETACH-01: Every widget shows a detach button (needs Plan 02)
    % -----------------------------------------------------------------------
    methods (Test)

        function testDetachButtonInjected(testCase)
        % DETACH-01: After realizeWidget(), every widget has a 'DetachButton' uicontrol.
        %   FAILS until Plan 02 adds DashboardLayout.addDetachButton() and wires DetachCallback.

            d = DashboardEngine('DetachBtnTest');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 6 2], 'Content', 'hello');
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            w = d.Widgets{1};
            btn = findobj(w.hPanel, 'Tag', 'DetachButton');
            testCase.verifyNotEmpty(btn, ...
                'DetachButton uicontrol should be injected into every widget panel after render()');
        end

        % -----------------------------------------------------------------------
        % DETACH-02: Clicking detach opens a standalone figure (needs Plan 03)
        % -----------------------------------------------------------------------

        function testDetachOpensWindow(testCase)
        % DETACH-02: detachWidget() creates a DetachedMirror and opens a figure window.
        %   FAILS until Plan 03 adds DashboardEngine.detachWidget() and DetachedMirrors property.

            d = DashboardEngine('DetachOpenTest');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 6 2], 'Content', 'hello');
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close('all', 'force'));

            w = d.Widgets{1};
            d.detachWidget(w);

            testCase.verifyEqual(numel(d.DetachedMirrors), 1, ...
                'DetachedMirrors should have exactly 1 entry after detachWidget()');
            mirror = d.DetachedMirrors{1};
            testCase.verifyTrue(ishandle(mirror.hFigure), ...
                'mirror.hFigure should be a valid figure handle after detachWidget()');
        end

        % -----------------------------------------------------------------------
        % DETACH-03: Mirror is ticked during onLiveTick (needs Plan 03)
        % -----------------------------------------------------------------------

        function testMirrorTickedOnLive(testCase)
        % DETACH-03: After detachWidget(), onLiveTick() ticks the mirror's widget.
        %   FAILS until Plan 03 extends DashboardEngine.onLiveTick() to iterate DetachedMirrors.

            d = DashboardEngine('TickTest');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 6 2], 'Content', 'hello');
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close('all', 'force'));

            w = d.Widgets{1};
            d.detachWidget(w);

            % Mark the mirror widget dirty so onLiveTick has something to do
            mirror = d.DetachedMirrors{1};
            mirror.Widget.Dirty = true;

            % Simulate a live tick
            d.onLiveTick();

            % After tick the widget's refresh() should have been called; Dirty is
            % cleared only if the subclass refresh() clears it, but the key assertion
            % is that no error was thrown and the mirror was not marked stale.
            testCase.verifyFalse(mirror.isStale(), ...
                'Mirror should not be stale after successful onLiveTick()');
        end

        % -----------------------------------------------------------------------
        % DETACH-04: Closing the detached figure removes mirror from registry (needs Plan 03)
        % -----------------------------------------------------------------------

        function testCloseRemovesFromRegistry(testCase)
        % DETACH-04: Closing the detached figure cleans up DetachedMirrors.
        %   FAILS until Plan 03 adds removeDetached() and wires CloseRequestFcn.

            d = DashboardEngine('CloseRegistryTest');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 6 2], 'Content', 'hello');
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            w = d.Widgets{1};
            d.detachWidget(w);
            testCase.verifyEqual(numel(d.DetachedMirrors), 1, ...
                'Precondition: 1 mirror in registry before close');

            mirror = d.DetachedMirrors{1};
            close(mirror.hFigure);   % triggers CloseRequestFcn → removeDetached()

            testCase.verifyEmpty(d.DetachedMirrors, ...
                'DetachedMirrors should be empty after closing the detached figure');
        end

        % -----------------------------------------------------------------------
        % DETACH-05: Cloned FastSenseWidget has UseGlobalTime = false (PASSES)
        % -----------------------------------------------------------------------

        function testFastSenseIndependentZoom(testCase)
        % DETACH-05: DetachedMirror.cloneWidget() sets UseGlobalTime = false on FastSenseWidget.
        %   PASSES — tests DetachedMirror.cloneWidget() which is already implemented.

            [origWidget, ~] = testCase.makeFastSenseWidget();

            % Exercise DetachedMirror constructor (creates figure — close in teardown)
            themeStruct = DashboardTheme('light');
            noop = @() [];
            mirror = DetachedMirror(origWidget, themeStruct, noop);
            set(mirror.hFigure, 'Visible', 'off');

            cloned = mirror.Widget;
            testCase.verifyTrue(isa(cloned, 'FastSenseWidget'), ...
                'Cloned widget should be a FastSenseWidget');
            testCase.verifyFalse(cloned.UseGlobalTime, ...
                'Cloned FastSenseWidget must have UseGlobalTime = false for independent zoom');
        end

        % -----------------------------------------------------------------------
        % DETACH-06: Detaching does not create extra timers (PASSES)
        % -----------------------------------------------------------------------

        function testNoExtraTimers(testCase)
        % DETACH-06: DetachedMirror constructor does not create any MATLAB timers.
        %   PASSES — DetachedMirror intentionally reuses the engine's existing timer.

            timersBefore = numel(timerfind);

            widget = TextWidget('Title', 'T', 'Position', [1 1 6 2], 'Content', 'x');
            themeStruct = DashboardTheme('light');
            noop = @() [];
            mirror = DetachedMirror(widget, themeStruct, noop);
            set(mirror.hFigure, 'Visible', 'off');

            timersAfter = numel(timerfind);

            testCase.verifyEqual(timersAfter, timersBefore, ...
                'DetachedMirror must not create any extra MATLAB timers');
        end

        % -----------------------------------------------------------------------
        % DETACH-07: Cloned widget is a different object handle (PASSES)
        % -----------------------------------------------------------------------

        function testMirrorIsReadOnly(testCase)
        % DETACH-07: mirror.Widget is a new object, not the same handle as original.
        %   PASSES — toStruct/fromStruct always creates a new object instance.

            widget = TextWidget('Title', 'T', 'Position', [1 1 6 2], 'Content', 'x');
            themeStruct = DashboardTheme('light');
            noop = @() [];
            mirror = DetachedMirror(widget, themeStruct, noop);
            set(mirror.hFigure, 'Visible', 'off');

            testCase.verifyNotEqual(mirror.Widget, widget, ...
                'mirror.Widget must be a different object handle than the original widget');
            testCase.verifyFalse(mirror.Widget == widget, ...
                'mirror.Widget handle must differ from original widget handle (not same reference)');
        end

    end

end
