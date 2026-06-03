# Phase 1042: Machine + Fleet + Pipeline DI Seam - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-03
**Phase:** 1042-machine-fleet-pipeline-di-seam
**Areas discussed:** none selected by user — 4 gray areas presented, all deferred to Claude's discretion and approved

---

## Gray-Area Selection (present_gray_areas)

| Option | Description | Selected |
|--------|-------------|----------|
| Catalog population | How a Machine acquires its tags + what "metadata-only" load reads (in-script `addTag` vs. DataRoot manifest); drives FLEET-05 lazy-load + ingest workflow | |
| Canonical map storage | Embed the canonical map in the single fleet JSON vs. a referenced sibling file (FLEET-04) | |
| DataRoot paths | Absolute vs. relative-to-config (+ `~`/env expansion) path persistence (FLEET-04) | |
| Machine API + identity | `Fleet.addMachine` call shape, Id user-supplied vs. derived, `Group` field shape (FLEET-01, FLEET-06) | |

**User's choice:** "nothing" (free-text) — no area selected for discussion.
**Notes:** Interpreted as "no Q&A needed, you decide." Honored the user's terse signal: rather than re-prompting per area, Claude proposed concrete defaults for all four gray areas and asked a single write-confirm gate.

---

## Write Confirmation (gate)

| Option | Description | Selected |
|--------|-------------|----------|
| Write it | Lock all four defaults as proposed, write CONTEXT.md + DISCUSSION-LOG.md, commit, update STATE | ✓ |
| Let me adjust one | Revise one or more of the four calls before writing | |

**User's choice:** Write it.
**Notes:** All four proposed defaults approved as-is. CONTEXT.md remains editable and plan-phase is gated, so nothing is irreversible.

---

## Claude's Discretion

All four open gray areas were decided by Claude with user approval:

1. **Catalog population (D-01..D-04)** — programmatic `machine.addTag(t)`; lazy-load reuses existing `SensorTag.RawSource` deferred read; config stores machine definitions + canonical map, not the tag catalog; no filesystem auto-discovery.
2. **Canonical map storage (D-05, D-06)** — embedded in the single fleet JSON via `CanonicalMapper.toStruct`/`fromStruct`; standalone mapper save/load untouched.
3. **DataRoot paths (D-07, D-08)** — stored as-given; relative paths resolved against the config dir on load, absolute used verbatim, `~` expanded; auto-relativize-on-save deferred.
4. **Machine API + identity (D-09..D-11)** — name-value `Fleet.addMachine` factory (plus pre-built-handle form); `Id` user-supplied, required, unique (`Fleet:duplicateMachineId`); `Group` single freeform char; `filterByGroup`/`filterByName` composable.

D-12..D-14 (pipeline `tagSource_` DI seam, `Machine.ingestBatch`/`startLive` wrappers, per-machine `EventStore`) restate locked v5.0 research findings, not fresh discussion choices.

## Deferred Ideas

- Auto-relativize an absolute DataRoot on save.
- Per-machine catalog manifest in `DataRoot` for cross-session catalog rehydration without re-running the user script.
- Filesystem auto-discovery of machines/tags (explicitly out-of-scope).
- `fleetConfigVersion` migration logic beyond a stored version field.

No scope-creep ideas were raised (user chose not to discuss).
