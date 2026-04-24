classdef TestFastSenseEventClick < matlab.unittest.TestCase
    %TESTFASTSENSEEVENTCLICK Phase 1012 Plan 03 — FastSense per-marker click wiring + details panel.

    methods (TestClassSetup)
        function addPaths(~)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root); install();
        end
    end

    methods (Test)
        function testPerMarkerButtonDownFcnIsSet(tc)
            [fp, ~, fig] = TestFastSenseEventClick.makeFixture(false);
            markers = TestFastSenseEventClick.findRoundMarkers(fig);
            tc.verifyGreaterThanOrEqual(numel(markers), 1);
            bd = get(markers{1}, 'ButtonDownFcn');
            tc.verifyClass(bd, 'function_handle');
            delete(fig);
        end

        function testUserDataHoldsEventId(tc)
            [~, ev, fig] = TestFastSenseEventClick.makeFixture(false);
            markers = TestFastSenseEventClick.findRoundMarkers(fig);
            tc.verifyGreaterThanOrEqual(numel(markers), 1);
            ud = get(markers{1}, 'UserData');
            tc.verifyTrue(isstruct(ud));
            tc.verifyTrue(isfield(ud, 'eventId'));
            tc.verifyEqual(ud.eventId, ev.Id);
            delete(fig);
        end

        function testOpenEventMarkerIsHollow(tc)
            [~, ~, fig] = TestFastSenseEventClick.makeFixture(true);   % IsOpen=true
            markers = TestFastSenseEventClick.findRoundMarkers(fig);
            tc.verifyGreaterThanOrEqual(numel(markers), 1);
            faceColor = get(markers{1}, 'MarkerFaceColor');
            tc.verifyEqual(faceColor, 'none');
            delete(fig);
        end

        function testClosedEventMarkerIsFilled(tc)
            [~, ~, fig] = TestFastSenseEventClick.makeFixture(false);  % IsOpen=false
            markers = TestFastSenseEventClick.findRoundMarkers(fig);
            tc.verifyGreaterThanOrEqual(numel(markers), 1);
            faceColor = get(markers{1}, 'MarkerFaceColor');
            tc.verifyNotEqual(faceColor, 'none');   % RGB triplet expected
            delete(fig);
        end

        function testClickOpensDetailsPanel(tc)
            if ~usejava('jvm'), tc.assumeFail('JVM required for figure-level callback simulation'); end
            [fp, ~, fig] = TestFastSenseEventClick.makeFixture(false);
            markers = TestFastSenseEventClick.findRoundMarkers(fig);
            tc.verifyGreaterThanOrEqual(numel(markers), 1);
            fp.onEventMarkerClick_(markers{1}, []);  % direct dispatch
            tc.verifyFalse(isempty(fp.hEventDetails_));
            tc.verifyTrue(ishandle(fp.hEventDetails_));
            delete(fp.hFigure);
        end

        function testEscDismissesDetailsPanel(tc)
            if ~usejava('jvm'), tc.assumeFail('JVM required'); end
            [fp, ~, fig] = TestFastSenseEventClick.makeFixture(false);
            markers = TestFastSenseEventClick.findRoundMarkers(fig);
            tc.verifyGreaterThanOrEqual(numel(markers), 1);
            fp.onEventMarkerClick_(markers{1}, []);
            fp.onKeyPressForDetailsDismiss_(struct('Key', 'escape'));
            tc.verifyTrue(isempty(fp.hEventDetails_));
            delete(fp.hFigure);
        end

        function testXButtonDismissesDetailsPanel(tc)
            if ~usejava('jvm'), tc.assumeFail('JVM required'); end
            [fp, ~, fig] = TestFastSenseEventClick.makeFixture(false);
            markers = TestFastSenseEventClick.findRoundMarkers(fig);
            tc.verifyGreaterThanOrEqual(numel(markers), 1);
            fp.onEventMarkerClick_(markers{1}, []);
            fp.closeEventDetails_();       % simulate X-button Callback
            tc.verifyTrue(isempty(fp.hEventDetails_));
            delete(fp.hFigure);
        end

        function testFormatEventFieldsShowsOpenForOpenEvent(tc)
            ev = Event(5, NaN, 's1', 'hi', 5, 'upper'); ev.IsOpen = true;
            fp = FastSense();   % no render needed for formatEventFields_
            txt = fp.formatEventFields_(ev);
            tc.verifyTrue(contains(txt, 'EndTime:        Open'));
            tc.verifyTrue(contains(txt, 'Duration:       Open'));
        end
    end

    methods (Static)
        function handles = findRoundMarkers(fig)
            %FINDROUNDMARKERS Find all round (Marker='o', LineStyle='none') line handles.
            %   Uses findall to avoid private-property access (Octave compat).
            allLines = findall(fig, 'Type', 'line');
            handles = {};
            for ci = 1:numel(allLines)
                try
                    mk = get(allLines(ci), 'Marker');
                    ls = get(allLines(ci), 'LineStyle');
                    if strcmp(mk, 'o') && strcmp(ls, 'none')
                        handles{end+1} = allLines(ci); %#ok<AGROW>
                    end
                catch
                end
            end
        end

        function [fp, ev, fig] = makeFixture(isOpen)
            fig = figure('Visible', 'off');
            ax = axes('Parent', fig);
            parent = SensorTag('p');
            parent.updateData([0 1 2 3 4 5], [0 0 0 10 10 0]);
            es = EventStore('');
            if isOpen
                ev = Event(3, NaN, 'p', 'hi', 5, 'upper'); ev.IsOpen = true;
            else
                ev = Event(3, 4, 'p', 'hi', 5, 'upper');
            end
            ev.Severity = 2;
            es.append(ev);
            ev.TagKeys = {'p'};
            EventBinding.attach(ev.Id, 'p');
            fp = FastSense('Parent', ax);
            fp.addTag(parent);
            fp.ShowEventMarkers = true;
            fp.EventStore = es;
            fp.render();
        end
    end
end
