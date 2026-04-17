function test_incremental_detector()
%TEST_INCREMENTAL_DETECTOR  Skipped in Phase 1011.
%   IncrementalEventDetector.process() depended on the deleted
%   Sensor/Threshold/detectEventsFromSensor pipeline.  LiveEventPipeline
%   now uses MonitorTag.appendData() for incremental detection.
%   This test is retained as a placeholder for future rewrite.
    fprintf('    SKIPPED: IncrementalEventDetector.process legacy pipeline removed in Phase 1011.\n');
end
