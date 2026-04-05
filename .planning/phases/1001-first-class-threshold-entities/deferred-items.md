# Deferred Items — Phase 1001

## Out-of-scope addThresholdRule usages (from Plan 02)

The following test files still use the old `addThresholdRule` / `ThresholdRules` API.
They are OUT OF SCOPE for plan 02 (which covers only the 8 sensor-specific test files).
These will be migrated in subsequent plans (03/04) that cover EventDetection and
remaining consumer code.

- tests/test_sensor_todisk.m
- tests/test_detect_events_from_sensor.m
- tests/test_add_sensor.m
- tests/test_SensorDetailPlot.m
- tests/test_event_config.m
- tests/test_incremental_detector.m
- tests/test_event_store.m
- tests/test_event_integration.m
- tests/test_live_pipeline.m
- tests/suite/TestSensorDetailPlot.m
- tests/suite/TestLivePipeline.m
- tests/suite/TestAddSensor.m
- tests/suite/TestGaugeWidget.m
- tests/suite/TestExternalSensorRegistry.m
- tests/suite/TestIncrementalDetector.m
- tests/suite/TestDashboardEngine.m
- tests/suite/TestDetectEventsFromSensor.m
- tests/suite/TestFastSenseWidget.m
- tests/suite/TestEventConfig.m
- tests/suite/TestLoadModuleMetadata.m
- tests/suite/TestSensorTodisk.m
- tests/suite/TestEventStore.m
- tests/suite/TestEventIntegration.m
- tests/suite/TestStatusWidget.m
