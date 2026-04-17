# Deferred Items - Phase 1011

## EventConfig.m legacy references
- **File:** libs/EventDetection/EventConfig.m
- **Issue:** `addSensor()` method calls `sensor.resolve()` (Sensor class deleted in Plan 01); `runDetection()` calls `detectEventsFromSensor()` (deleted in Plan 01); `escalateEvents` reads `s.ResolvedThresholds` (Sensor property, no longer exists)
- **Impact:** EventConfig is effectively dead code -- cannot be used without Sensor class
- **Recommendation:** Delete or rewrite EventConfig in a future plan (Phase 1011 Plan 04/05 or follow-up)

## EventViewer.m threshold display
- **File:** libs/EventDetection/EventViewer.m  
- **Issue:** `buildSensor` was rewritten to `buildSensorData` (Plan 03) but threshold display in event detail views is lost since `addSensor` with threshold overlay is replaced by plain `addLine`
- **Impact:** EventViewer works but no longer shows threshold overlay on event detail plots
- **Recommendation:** Wire threshold display via addThreshold once Tag-based threshold metadata is available
