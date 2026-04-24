classdef TestFastSenseEventClick < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(~)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root); install();
        end
    end
    methods (Test)
        function testPerMarkerButtonDownFcnIsSet(tc)
            tc.assumeFail('Plan 1012-03 refactors renderEventLayer_ to one line() per event');
        end
        function testUserDataHoldsEventId(tc)
            tc.assumeFail('Plan 1012-03 wires UserData.eventId on each marker');
        end
        function testOpenEventMarkerIsHollow(tc)
            tc.assumeFail('Plan 1012-03 branches MarkerFaceColor on ev.IsOpen');
        end
        function testClosedEventMarkerIsFilled(tc)
            tc.assumeFail('Plan 1012-03 preserves filled styling for ev.IsOpen==false');
        end
        function testClickOpensDetailsPanel(tc)
            if ~usejava('jvm'), tc.assumeFail('JVM-gated'); end
            tc.assumeFail('Plan 1012-03 implements openEventDetails_ uipanel');
        end
        function testEscDismissesDetailsPanel(tc)
            if ~usejava('jvm'), tc.assumeFail('JVM-gated'); end
            tc.assumeFail('Plan 1012-03 wires WindowKeyPressFcn for ESC');
        end
        function testXButtonDismissesDetailsPanel(tc)
            if ~usejava('jvm'), tc.assumeFail('JVM-gated'); end
            tc.assumeFail('Plan 1012-03 adds X-button uicontrol to the uipanel');
        end
        function testClickOutsideDismissesDetailsPanel(tc)
            if ~usejava('jvm'), tc.assumeFail('JVM-gated'); end
            tc.assumeFail('Plan 1012-03 wires WindowButtonDownFcn hit-test');
        end
    end
end
