# Phase 1001: First-Class Threshold Entities - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-05
**Phase:** 1001-first-class-threshold-entities
**Areas discussed:** Entity model, Registry & sharing, Sensor integration, Resolve & eval

---

## Entity Model

### Entity class design

| Option | Description | Selected |
|--------|-------------|----------|
| New Threshold class | ThresholdRule stays as-is. New Threshold wraps rules with Key, Name, metadata | |
| Upgrade ThresholdRule | Add Key, Name, metadata directly to ThresholdRule | |
| Threshold wraps rules (TrendMiner) | Threshold = named limit concept with state-dependent values. Share across sensors | ✓ |

**User's choice:** Threshold wraps rules (TrendMiner)
**Notes:** User explicitly wants TrendMiner-style model

### Metadata

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal (just those) | Key, Name, Direction, Color, LineStyle + conditions | |
| Add Units + Description | Also carry Units and Description for documentation/tooltips | |
| Add Units + Desc + Tags | Units, Description, plus Tags cell array for filtering/grouping | ✓ |

**User's choice:** Add Units + Desc + Tags

### Handle vs value class

| Option | Description | Selected |
|--------|-------------|----------|
| Handle class | Changes propagate to all sensors. Matches Sensor pattern | ✓ |
| Value class with copy | Each sensor gets own copy. Simpler but defeats sharing | |

**User's choice:** Handle class (Recommended)

### ThresholdRule fate

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as internal condition | ThresholdRule becomes internal struct/class inside Threshold | |
| Replace with struct | Drop ThresholdRule class, use struct array | |
| You decide | Claude picks best internal representation | ✓ |

**User's choice:** You decide

---

## Registry & Sharing

### Registry pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Mirror SensorRegistry | Same API, persistent singleton, static methods | ✓ |
| Unified registry | Single registry for sensors and thresholds | |
| Instance-based registry | Regular object, not singleton | |

**User's choice:** Mirror SensorRegistry (Recommended)

### Predefined catalog

| Option | Description | Selected |
|--------|-------------|----------|
| Empty + runtime only | No predefined catalog, users populate at runtime | ✓ |
| Predefined catalog | Ship with common thresholds matching predefined sensors | |
| Both | Predefined + runtime | |

**User's choice:** Empty + runtime only

### Tag querying

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — findByTag | Add findByTag, findByDirection query methods | ✓ |
| Just list + get | Simple registry, tags for documentation only | |
| You decide | Claude decides | |

**User's choice:** All query methods (findByTag, findByDirection, etc.)

---

## Sensor Integration

### Sensor API

| Option | Description | Selected |
|--------|-------------|----------|
| addThreshold (dual input) | Accepts objects and keys. New method alongside addThresholdRule | |
| Replace addThresholdRule | Remove old API entirely. Breaking change | ✓ |
| addThreshold + deprecate old | New method, old stays with deprecation warning | |

**User's choice:** Complete revamp — remove addThresholdRule, only addThreshold exists
**Notes:** User said "we wanna completely revamp the thresholds system, so we have to break some things"

### Dual input on addThreshold

| Option | Description | Selected |
|--------|-------------|----------|
| Both object + key | s.addThreshold(obj) or s.addThreshold('key') | ✓ |
| Object only | Must pass Threshold object | |
| Key only | Must register first | |

**User's choice:** Both object + key (Recommended)

### Duplicate handling

| Option | Description | Selected |
|--------|-------------|----------|
| Reject duplicates by Key | Skip/warn if same Key already attached | ✓ |
| Allow duplicates | No checking | |
| You decide | Claude decides | |

**User's choice:** Reject duplicates by Key

### Remove method

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — removeThreshold(key) | Detach from sensor, Threshold stays in registry | ✓ |
| No — just reassign | Clear Thresholds manually | |
| You decide | Claude decides | |

**User's choice:** Yes — removeThreshold(key)

---

## Resolve & Eval

### Resolve architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Resolve stays on Sensor | Sensor.resolve() evaluates its Thresholds. Results on Sensor | |
| Resolve on Threshold per-sensor | Threshold.resolve(sensor). Results keyed by sensor | |
| You decide | Claude picks best integration | ✓ |

**User's choice:** You decide

### Condition system

| Option | Description | Selected |
|--------|-------------|----------|
| Keep StateChannel system | Same struct-based condition matching | ✓ |
| Simpler — just values | Drop conditions, single fixed value per Threshold | |
| You decide | Claude decides | |

**User's choice:** Keep StateChannel system

---

## Claude's Discretion

- Internal condition representation within Threshold class
- Resolve architecture (results on Sensor vs Threshold)
- Migration strategy for all downstream consumers

## Deferred Ideas

None — discussion stayed within phase scope
