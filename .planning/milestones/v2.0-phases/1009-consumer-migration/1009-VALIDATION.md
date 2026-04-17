---
phase: 1009
slug: consumer-migration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 1009 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `matlab.unittest` + Octave flat-assert |
| **Full suite** | `octave --no-gui --eval "install(); cd tests; run_all_tests();"` |
| **Bench** | `octave --no-gui --eval "install(); bench_consumer_migration_tick();"` |
| **Regression** | `test_golden_integration` MUST stay green at every commit (Pitfall 11) |

## Sampling Rate
- **After every commit:** Full suite + golden integration
- **Per-plan commit:** Revertability check via `git revert HEAD --no-edit && run_all_tests && git reset --hard HEAD@{1}`
- **Phase gate:** Full suite + golden + Pitfall 9 bench all green

## Per-Plan Test Map

| Plan | Consumer | New test file(s) | Extends existing |
|------|----------|------------------|------------------|
| 01 | FastSenseWidget | test_fastsense_widget_tag.m + TestFastSenseWidgetTag.m | TestFastSenseWidget.m (regression) |
| 01 | SensorDetailPlot | test_sensor_detail_plot_tag.m | test_SensorDetailPlot.m (regression) |
| 02 | MultiStatusWidget | test_multistatus_widget_tag.m | TestMultiStatusWidget.m |
| 02 | IconCardWidget | test_icon_card_widget_tag.m | TestIconCardWidget.m |
| 02 | EventTimelineWidget | test_event_timeline_widget_tag.m | TestEventTimelineWidget.m |
| 02 | DashboardWidget base | extend TestDashboardWidget.m (Tag property toStruct/fromStruct) | |
| 03 | EventDetector | test_event_detector_tag.m | TestEventDetector.m |
| 03 | LiveEventPipeline | test_live_event_pipeline_tag.m | test_live_pipeline.m (regression) |
| 04 | Pitfall 9 bench | benchmarks/bench_consumer_migration_tick.m (12-widget mix) | |

## Pitfall Gate → Verification Command

| Gate | Verification |
|------|--------------|
| Pitfall 5 (legacy not deleted) | `test -f libs/SensorThreshold/Sensor.m` and for all legacy files; `git log --name-only` shows no delete actions |
| Pitfall 9 (≤10% regression) | `bench_consumer_migration_tick()` prints `overhead_pct <= 10` |
| Pitfall 11 (golden untouched) | `git diff <phase-start>..HEAD -- tests/suite/TestGoldenIntegration.m tests/test_golden_integration.m` → 0 lines |
| Per-commit revertability | Each plan = 1 consumer cluster + tests; other consumers not touched |

## Validation Sign-Off
- [ ] Every commit green on full suite + golden
- [ ] No legacy-class delete
- [ ] Bench <=10%
- [ ] `nyquist_compliant: true` in frontmatter after green

**Approval:** pending
