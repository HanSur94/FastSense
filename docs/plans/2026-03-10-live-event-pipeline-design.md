# Live Event Detection Pipeline — Design

**Date:** 2026-03-10
**Status:** Approved

## Overview

A live event detection pipeline that reads continuously-updated sensor data, detects threshold violations incrementally, stores events to a shared `.mat` file, and sends email notifications with event snapshot plots. Multiple clients can poll the event store via EventViewer.

## Architecture

```
External Data Pipeline (writes .mat files)
        │
        ▼
┌─────────────────────────────────────────┐
│         LiveEventPipeline (VM)          │
│                                         │
│  DataSourceMap ──► IncrementalDetector   │
│  (sensor key →      (per-sensor state,  │
│   DataSource)        open-event carry)  │
│                          │              │
│                          ▼              │
│                    EventStore           │
│                   (single .mat)         │
│                          │              │
│                          ▼              │
│               NotificationService       │
│              (email + 2 plot PNGs)      │
└─────────────────────────────────────────┘
        │                        │
        ▼                        ▼
  EventViewer (N clients)   Email inboxes
  poll .mat, auto-refresh   with snapshots
```

## Components

### 1. DataSource (abstract)

Abstract class with one method:

```matlab
result = fetchNew(obj)
% Returns struct:
%   .X       — new datenum timestamps (1xN)
%   .Y       — new values (1xN or MxN)
%   .stateX  — new state timestamps (1xK) [optional]
%   .stateY  — new state values (1xK)     [optional]
%   .changed — logical, true if new data since last call
```

### 2. MatFileDataSource

- Reads sensor data from a `.mat` file path
- Tracks last-read file timestamp + last-read data index
- `fetchNew()` checks file modification time, skips if unchanged
- Returns only new points since last read
- Also reads state channel data from the same or separate `.mat` file

### 3. MockDataSource

- Generates realistic industrial signals for testing
- Multi-day history on first call (configurable, e.g., 3 days backlog)
- Subsequent calls: ~5 new points per cycle (3s sample rate, 15s interval)
- Signal: smooth random walk + drift + Gaussian noise
- Violation episodes: ramps through thresholds at configurable probability
- Sparse state changes: transitions a few times per hour
- Optional deterministic `Seed` for reproducible test runs

### 4. DataSourceMap

`containers.Map` mapping sensor keys (from SensorRegistry) to DataSource instances.

```matlab
map = DataSourceMap();
map.add('pressure', MatFileDataSource('\\server\share\pressure.mat'));
map.add('temperature', MockDataSource('BaseValue', 80, 'NoiseStd', 2));
```

### 5. IncrementalEventDetector

Wraps existing `EventDetector` with incremental state per sensor:

- **Per-sensor state:**
  - `lastIndex` — last processed data point index
  - `openEvent` — partial Event if violation ongoing at end of last cycle
  - `fullX` / `fullY` — accumulated data arrays
  - `resolvedSensor` — current resolved Sensor (re-resolved on state change)

- **Each cycle per sensor:**
  1. Fetch new data, skip if unchanged
  2. Append to accumulated arrays, update state channels if new state data
  3. Re-resolve thresholds if state data changed
  4. Run detection on new slice only
  5. Merge with open event if violation continues, or finalize open event
  6. Severity escalation on newly completed events only

### 6. EventStore

- Single `.mat` file for all events from all sensors
- Atomic write: save to temp file, then rename
- File contains: `events` (array), `lastUpdated` (datenum), `pipelineConfig` (sensor list + thresholds)
- Static `load(filePath)` method for clients (checks file mod time, skips if unchanged)
- Backup rotation via existing `MaxBackups` logic

### 7. NotificationService

- Rule-based email dispatch
- Resolution order: sensor+threshold specific > sensor-level > default > no notification

**NotificationRule properties:**
- `SensorKey` — sensor to match (empty = any)
- `ThresholdLabel` — threshold to match (empty = any)
- `Recipients` — cell array of email addresses
- `Subject` — template string with placeholders
- `Message` — template string with placeholders
- `IncludeSnapshot` — logical (default: true)
- `ContextHours` — hours of history for Plot 2 (default: 2)
- `SnapshotSize` — `[width, height]` pixels (default: `[800, 400]`)

**Template placeholders:** `{sensor}`, `{threshold}`, `{direction}`, `{startTime}`, `{endTime}`, `{peak}`, `{duration}`, `{mean}`, `{rms}`, `{std}`

### 8. Event Snapshot Plots

Two plots generated per notification:

**Plot 1 — Event Detail:**
- Zoomed to event time span + 10% padding each side
- Shaded semi-transparent patch over violation X-span
- Threshold line + violation markers
- State bands if applicable

**Plot 2 — Event Context:**
- Event + 2 hours of history before violation start
- Same shaded violation region
- Same threshold line + violation markers
- Shows signal trend leading into the violation

Both generated headless (`'Visible', 'off'`) via FastSense, saved as PNG, attached to email. Old snapshots auto-cleaned after configurable retention (default: 7 days).

### 9. LiveEventPipeline (Orchestrator)

**Properties:**
- `SensorRegistry`, `DataSourceMap`, `IncrementalDetector`
- `EventStore`, `NotificationService`
- `Interval` (default: 15s), `Timer`, `Status` ('stopped'|'running'|'error')

**Methods:**
- `start()` — validate config, start timer
- `stop()` — stop timer, finalize open events, flush store
- `runCycle()` — one detection pass:
  1. For each sensor: fetchNew → append → resolve → detect incrementally
  2. Collect newly completed events
  3. eventStore.append(newEvents)
  4. For each new event: notificationService.notify(event, sensorData)
  5. Log cycle summary

**Error handling:**
- Single sensor failure: log warning, skip, continue others
- Event store write failure: retry next cycle, events held in memory
- Email failure: log error, don't block pipeline

## Existing Classes — No Changes Required

- `Event`, `EventDetector`, `EventConfig`
- `EventViewer` (clients use `fromFile()` + `startAutoRefresh()`)
- `Sensor`, `ThresholdRule`, `StateChannel`, `SensorRegistry`
- `FastSense`

## Configuration

Single shared timer at 15-second interval. Sensor data arrives at ~3s per point. File timestamp check skips unchanged sources. State data is sparse (few transitions per hour), handled by zero-order-hold in StateChannel.

## Client Setup

```matlab
% On any client PC with access to the shared .mat file:
ev = EventViewer.fromFile('\\server\share\events.mat');
ev.startAutoRefresh(15);
```
