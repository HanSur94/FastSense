classdef TestEventStore < matlab.unittest.TestCase
    %TESTEVENTSTORE EventStore / EventViewer surface tests.
    %
    %   All legacy-pipeline tests (EventConfig.addTag + cfg.runDetection +
    %   Threshold class) were deleted in Phase 1014 Plan 05: the
    %   Sensor/Threshold/StateChannel pipeline was removed in Phase 1011
    %   and EventConfig.addSensor now throws 'EventConfig:legacyRemoved'.
    %
    %   Live-path EventStore coverage (append + save + load round-trip
    %   against the real v2.0 API) lives in tests/suite/TestEventStoreRw.m.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testFromFileNotFound(testCase)
            threw = false;
            try
                EventViewer.fromFile('/tmp/nonexistent_event_store.mat');
            catch e
                threw = true;
                testCase.verifyTrue(contains(e.identifier, 'fileNotFound'), 'fromFile: correct error id');
            end
            testCase.verifyTrue(threw, 'fromFile: throws on missing file');
        end
    end
end
