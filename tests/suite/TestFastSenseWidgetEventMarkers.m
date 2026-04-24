classdef TestFastSenseWidgetEventMarkers < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(~)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root); install();
        end
    end
    methods (Test)
        function testShowEventMarkersDefaultFalse(tc)
            tc.assumeFail('Plan 1012-03 adds ShowEventMarkers property to FastSenseWidget');
        end
        function testEventStorePropertyDefaultEmpty(tc)
            tc.assumeFail('Plan 1012-03 adds EventStore property to FastSenseWidget');
        end
        function testPropertiesForwardToInnerFastSense(tc)
            tc.assumeFail('Plan 1012-03 wires forwarding in render() and rebuildForTag_()');
        end
        function testToStructOmitsWhenDefault(tc)
            tc.assumeFail('Plan 1012-03 gates s.showEventMarkers emission on default false');
        end
        function testFromStructRehydrates(tc)
            tc.assumeFail('Plan 1012-03 reads s.showEventMarkers in fromStruct');
        end
        function testRefreshDiffsLastEventIds(tc)
            tc.assumeFail('Plan 1012-03 adds LastEventIds_ cache + diff in refresh()');
        end
        function testRefreshTriggersRerenderOnAdded(tc)
            tc.assumeFail('Plan 1012-03 calls FastSense.refreshEventLayer() on ids change');
        end
        function testRefreshTriggersRerenderOnOpenToClosed(tc)
            tc.assumeFail('Plan 1012-03 detects open->closed transition via LastEventOpen_');
        end
    end
end
