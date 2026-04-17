# Phase 1004: Tag Foundation + Golden Test - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — base class + registry + regression guard)

<domain>
## Phase Boundary

Establish a parallel `Tag` hierarchy and an untouchable end-to-end regression guard so the v2.0 rewrite has a stable safety net before any consumer touches Tag code.

**In scope:**
- `Tag` abstract base class with ≤6 abstract-by-convention methods (`getXY`, `valueAt`, `getTimeRange`, `getKind`, `toStruct`, static `fromStruct`)
- Universal Tag properties: `Key`, `Name`, `Units`, `Description`, `Labels`, `Metadata`, `Criticality`, `SourceRef`
- `TagRegistry` singleton (static-methods + persistent Map, mirroring `ThresholdRegistry`)
  - CRUD: `register/get/unregister/clear`, hard-error on duplicate key
  - Query: `find/findByLabel/findByKind`
  - Introspection: `list/printTable/viewer`
  - Two-phase deserialization: `loadFromStructs(structs)` (Pass 1 instantiate empty, Pass 2 resolve refs) — loud error on missing references
- Golden integration test: representative Sensor + Threshold + CompositeThreshold + EventDetector flow. Stays green every phase. Marked "do not rewrite without architectural review".
- `META-01..04` implemented on the Tag base (Labels, findByLabel, Metadata, Criticality)
- MIGRATE discipline: parallel hierarchy only — NO edits to `Sensor.m`, `Threshold.m`, `StateChannel.m`, `CompositeThreshold.m`, `SensorRegistry.m`, `ThresholdRegistry.m`, `ExternalSensorRegistry.m`, `ThresholdRule.m`

**Out of scope (later phases):**
- `SensorTag`, `StateTag` concrete subclasses → Phase 1005
- `MonitorTag` derived signals → Phase 1006/1007
- `CompositeTag` aggregation → Phase 1008
- Consumer migrations (FastSense, widgets, EventDetection) → Phase 1009
- Event↔Tag binding → Phase 1010
- Legacy-class deletion → Phase 1011

**Verification gates (from PITFALLS.md):**
- Pitfall 1 — ≤6 abstract methods on `Tag` base; no `error('NotApplicable')` stubs in any subclass
- Pitfall 5 — ≤20 files touched total; no legacy-class edits
- Pitfall 7 — Registry collision = hard error (matches ThresholdRegistry)
- Pitfall 8 — Two-pass `loadFromStructs`; composite-of-composite (3-deep) round-trip test green
- Pitfall 11 — Golden integration test exists, checked in, header comment forbidding rewrite

</domain>

<decisions>
## Implementation Decisions

### File Organization
- Tag classes live alongside legacy in `libs/SensorThreshold/` during strangler-fig window. Makes Phase 1011 deletion + consolidation a pure delete, no move.
- New files: `libs/SensorThreshold/Tag.m`, `libs/SensorThreshold/TagRegistry.m`
- Golden integration test: `tests/suite/TestGoldenIntegration.m` + `tests/test_golden_integration.m` (both entry points, matching existing dual-style convention)

### Patterns Carried Forward (from Phase 1001-1003)
- Handle class inheritance (`classdef Tag < handle`)
- Name-value constructor pattern (`Tag('key', 'Name', n, 'Labels', {...}, 'Criticality', 'safety', ...)`)
- Persistent container-Map singleton for `TagRegistry` (identical shape to `ThresholdRegistry`)
- Error identifier pattern `TagRegistry:problemName`, `Tag:problemName`
- TDD — write `TestTag.m` + `TestTagRegistry.m` + `test_tag.m` + `test_tag_registry.m` suites first, then implement

### Abstract Method Enforcement
- MATLAB "throw-from-base" pattern: base class methods raise `error('Tag:notImplemented', 'Subclasses must implement %s', 'methodName')`
- Subclasses override by providing concrete implementation
- NO `abstract` keyword (avoids Octave quirks per DataSource precedent)

### Tag Properties
- `Key` (char, required) — validated non-empty
- `Name` (char, optional, defaults to Key)
- `Units` (char, optional, defaults to '')
- `Description` (char, optional, defaults to '')
- `Labels` (cellstr, optional, defaults to `{}`)
- `Metadata` (struct, optional, defaults to `struct()`)
- `Criticality` (enum char: `'low'|'medium'|'high'|'safety'`, defaults to `'medium'`)
- `SourceRef` (char, optional, defaults to '')

### TagRegistry API
- `TagRegistry.register(key, tag)` — hard error on collision (`TagRegistry:duplicateKey`)
- `TagRegistry.get(key)` — throws `TagRegistry:unknownKey` if missing
- `TagRegistry.unregister(key)` — idempotent, warns if missing? No — silent no-op on missing (matches ThresholdRegistry pattern)
- `TagRegistry.clear()` — wipe catalog
- `TagRegistry.find(predicateFn)` — cell array of matching tags
- `TagRegistry.findByLabel(label)` — label-driven lookup (port of `findByTag`)
- `TagRegistry.findByKind(kindStr)` — e.g., `'sensor'`, `'state'`, `'monitor'`, `'composite'`
- `TagRegistry.list()` — print sorted keys+names to cmd window
- `TagRegistry.printTable()` — detailed table (Key, Name, Kind, Labels, Criticality, Units)
- `TagRegistry.viewer()` — uitable GUI (Octave-safe)
- `TagRegistry.loadFromStructs(structs)` — two-phase: Pass 1 instantiate with empty children, Pass 2 wire cross-refs via `resolveRefs(registry)` hook on each tag; throws `TagRegistry:unresolvedRef` on Pass 2 failure

### Golden Integration Test
- File: `tests/suite/TestGoldenIntegration.m` + `tests/test_golden_integration.m` wrapper
- Fixture: one `Sensor` (synthetic sinusoid), one `Threshold` (upper bound), one `CompositeThreshold` (2 children), one `EventDetector` run → assert violation count, event times, composite status
- Header comment: `% GOLDEN INTEGRATION TEST — regression guard for v2.0 Tag migration.` + `% DO NOT REWRITE without architectural review.  Modifying this test before Phase 1011 invalidates the safety net.`
- Written against legacy API only — rewritten to Tag API in Phase 1011 cleanup
- No `addpath` to Tag code in this test (legacy-only)
- Registered in both `tests/run_all_tests.m` and suite runner

### Claude's Discretion
- Exact test assertion counts and tolerances — pick representative values, keep test <200 lines
- Private helper organization within `libs/SensorThreshold/private/` if needed
- Format of `printTable`/`viewer` — follow ThresholdRegistry.printTable layout with a Kind column added
- Exact wording of header comments — idiomatic MATLAB docstrings matching existing classes

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `libs/SensorThreshold/ThresholdRegistry.m` — exact template for `TagRegistry` (static methods + persistent container Map)
- `libs/SensorThreshold/Threshold.m` — template for Tag base class (handle class, name-value constructor, validate inputs)
- `libs/SensorThreshold/Sensor.m` — shows `<handle` inheritance, property defaults on declaration, `parseOpts` helper
- `libs/EventDetection/DataSource.m` — proven abstract-via-throw-from-base pattern (no `abstract` keyword)
- `libs/Dashboard/DashboardWidget.m` — another throw-from-base abstract class (Octave-safe)

### Established Patterns
- Error IDs: `ClassName:problemName` camelCase
- Public API: camelCase
- Public props: PascalCase, inline defaults
- Private props: trailing underscore
- Tests: `Test<Class>.m` in `tests/suite/` + `test_<snake_case>.m` flat file

### Integration Points
- None in this phase — `Tag` and `TagRegistry` are brand-new, used by zero consumers in Phase 1004
- Consumers wire in at Phase 1005+ (FastSense.addTag dispatch, SensorTag replacement, etc.)
- `install()` path additions — none (same library, already on path)

</code_context>

<specifics>
## Specific Ideas

- Golden test must exercise an Event path, not just status — EventDetector is the most-used live-pipeline consumer
- Deferred-loading trap from Phase 1003 (`CompositeThreshold.fromStruct` order-sensitivity) is solved once here via two-phase loader — all future Tag subclasses inherit the pattern
- `resolveRefs(registry)` should be a no-op default on `Tag` base — subclasses with child references override it (CompositeTag in Phase 1008 will)

</specifics>

<deferred>
## Deferred Ideas

- None — discuss skipped; requirements fully specified in REQUIREMENTS.md

</deferred>
