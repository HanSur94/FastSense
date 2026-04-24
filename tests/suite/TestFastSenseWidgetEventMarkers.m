classdef TestFastSenseWidgetEventMarkers < matlab.unittest.TestCase
    %TESTFASTSENSEWIDGETEVENTMARKERS Phase 1012 Plan 03 — widget-level event marker wiring.

    methods (TestClassSetup)
        function addPaths(~)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root); install();
        end
    end

    methods (Test)
        function testShowEventMarkersDefaultFalse(tc)
            w = FastSenseWidget();
            tc.verifyFalse(w.ShowEventMarkers);
        end

        function testEventStorePropertyDefaultEmpty(tc)
            w = FastSenseWidget();
            tc.verifyEmpty(w.EventStore);
        end

        function testPropertiesForwardToInnerFastSense(tc)
            if ~usejava('jvm'), tc.assumeFail('JVM required for render'); end
            [w, ~, es] = TestFastSenseWidgetEventMarkers.renderFixture();  % opt-in: ShowEventMarkers=true
            tc.verifyEqual(w.FastSenseObj.ShowEventMarkers, w.ShowEventMarkers);
            tc.verifyEqual(w.FastSenseObj.EventStore, es);
            delete(gcf);
        end

        function testGuardPreservesInnerDefaultWhenWidgetDefault(tc)
            %TESTGUARDPRESERVESINNERDEFAULTWHENWIDGETDEFAULT BLOCKER 1 Option A test.
            %   When widget.ShowEventMarkers=false AND widget.EventStore=[]
            %   (defaults), render() must NOT forward to the inner FastSense.
            %   Inner FastSense.ShowEventMarkers default is TRUE (Phase 1010);
            %   it must still be TRUE after widget.render() with widget
            %   defaults. Proves we did not silently hide markers for
            %   consumers who never touched the widget's ShowEventMarkers
            %   but may have configured the inner FastSense directly.
            if ~usejava('jvm'), tc.assumeFail('JVM required for render'); end
            w = FastSenseWidget();
            parent = SensorTag('p');
            parent.updateData([0 1 2], [0 1 0]);
            w.Tag = parent;
            % Explicitly DO NOT opt in at widget level.
            tc.verifyFalse(w.ShowEventMarkers);
            tc.verifyEmpty(w.EventStore);
            f = figure('Visible', 'off');
            pnl = uipanel('Parent', f);
            w.render(pnl);
            % Guard must have SKIPPED forwarding. Inner FastSense keeps
            % its Phase-1010 default-true. EventStore stays untouched.
            tc.verifyTrue(w.FastSenseObj.ShowEventMarkers);
            tc.verifyEmpty(w.FastSenseObj.EventStore);
            delete(f);
        end

        function testToStructOmitsWhenDefault(tc)
            w = FastSenseWidget('Title', 'x');
            s = w.toStruct();
            tc.verifyFalse(isfield(s, 'showEventMarkers'));
        end

        function testToStructIncludesWhenTrue(tc)
            w = FastSenseWidget('Title', 'x');
            w.ShowEventMarkers = true;
            s = w.toStruct();
            tc.verifyTrue(isfield(s, 'showEventMarkers'));
            tc.verifyTrue(s.showEventMarkers);
        end

        function testToStructNeverEmitsEventStore(tc)
            w = FastSenseWidget('Title', 'x');
            w.EventStore = EventStore('');
            s = w.toStruct();
            tc.verifyFalse(isfield(s, 'eventStore'));
            tc.verifyFalse(isfield(s, 'EventStore'));
        end

        function testFromStructRehydrates(tc)
            s = struct( ...
                'title', 't', 'position', struct('col', 1, 'row', 1, 'width', 6, 'height', 2), ...
                'showEventMarkers', true);
            w = FastSenseWidget.fromStruct(s);
            tc.verifyTrue(w.ShowEventMarkers);
        end

        function testRefreshTriggersRerenderOnAdded(tc)
            if ~usejava('jvm'), tc.assumeFail('JVM required for render'); end
            [w, ~, es] = TestFastSenseWidgetEventMarkers.renderFixture();
            tc.verifyEmpty(w.LastEventIds_);
            ev = Event(2, 3, 'p', 'hi', 5, 'upper');
            es.append(ev); EventBinding.attach(ev.Id, 'p');
            w.refresh();
            tc.verifyNotEmpty(w.LastEventIds_);
            tc.verifyEqual(w.LastEventIds_{1}, ev.Id);
            delete(gcf);
        end

        function testRefreshTriggersRerenderOnOpenToClosed(tc)
            if ~usejava('jvm'), tc.assumeFail('JVM required for render'); end
            [w, ~, es] = TestFastSenseWidgetEventMarkers.renderFixture();
            ev = Event(2, NaN, 'p', 'hi', 5, 'upper'); ev.IsOpen = true;
            es.append(ev); EventBinding.attach(ev.Id, 'p');
            w.refresh();
            tc.verifyTrue(w.LastEventOpen_(1));
            es.closeEvent(ev.Id, 3, []);
            w.refresh();
            tc.verifyFalse(w.LastEventOpen_(1));
            delete(gcf);
        end

        function testRefreshNoopWhenShowEventMarkersFalse(tc)
            if ~usejava('jvm'), tc.assumeFail('JVM required for render'); end
            [w, ~, es] = TestFastSenseWidgetEventMarkers.renderFixture();
            w.ShowEventMarkers = false;
            ev = Event(2, 3, 'p', 'hi', 5, 'upper');
            es.append(ev); EventBinding.attach(ev.Id, 'p');
            w.refresh();
            % No marker diff should have run — LastEventIds_ remains empty.
            tc.verifyEmpty(w.LastEventIds_);
            delete(gcf);
        end

        function testRefreshNoopWhenEventStoreEmpty(tc)
            if ~usejava('jvm'), tc.assumeFail('JVM required for render'); end
            w = FastSenseWidget();
            w.Tag = SensorTag('p');
            w.Tag.updateData([0 1 2], [0 1 0]);
            w.ShowEventMarkers = true;
            % EventStore intentionally empty
            f = figure('Visible', 'off');
            pnl = uipanel('Parent', f);
            w.render(pnl);
            w.refresh();
            tc.verifyEmpty(w.LastEventIds_);
            delete(f);
        end
    end

    methods (Static)
        function [w, parent, es] = renderFixture()
            w = FastSenseWidget();
            parent = SensorTag('p');
            parent.updateData([0 1 2 3 4 5], [0 0 0 10 10 0]);
            w.Tag = parent;
            es = EventStore('');
            w.EventStore = es;
            w.ShowEventMarkers = true;
            f = figure('Visible', 'off');
            pnl = uipanel('Parent', f);
            w.render(pnl);
        end
    end
end
