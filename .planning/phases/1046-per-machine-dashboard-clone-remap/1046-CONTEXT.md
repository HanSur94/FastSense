---
phase: 1046-per-machine-dashboard-clone-remap
slug: per-machine-dashboard-clone-remap
status: discussed
requirements: [DASH-03, DASH-04]
depends_on: [1041, 1042, 1043, 1044]
created: 2026-06-17
---

# Phase 1046 — Context: Per-Machine Dashboard Clone/Remap

## Goal

A user can clone a dashboard built on one machine onto another machine, with every tag
binding that resolves through the canonical map rebound to the **target** machine's local
tags. Bindings that cannot be remapped (the target machine lacks the sensor) are returned
in a **warnings list** — never silent empty widgets, never a crash. The cloned dashboard
opens with the remaining widgets bound correctly. An end-to-end round-trip (serialize a
machine's dashboard, load it on a different machine with the machine-scoped resolver, all
tags bound to the target catalog) passes.

## Requirements

- **DASH-03**: Clone a dashboard from one machine onto another; tag bindings rebound to the
  target machine's tags via the canonical map.
- **DASH-04**: When a clone target lacks a sensor used by the source dashboard, the
  unresolved bindings are surfaced as a warnings list (not silent empty widgets).

## Existing Foundation (verified during discuss)

- **1043 resolver seam:** `DashboardEngine.load(file, 'TagResolver'|'SensorResolver', fn)`
  threads `fn` through `DashboardSerializer.configToWidgets(config, resolver)` →
  `createWidgetFromStruct(ws, resolver)` → `FastSenseWidget.fromStruct(s, tagResolver)`,
  which (per 1043-02) calls `tagResolver(s.source.key)` on the `'tag'` path. **The 1043-02
  summary deliberately left the resolver call UNWRAPPED — "graceful partial-bind deferred to
  Phase 1046 DASH-04". That graceful behavior is THIS phase's job.**
- **Serialized tag binding:** a Tag-bound `FastSenseWidget` serializes as
  `s.source = struct('type','tag','key', obj.Tag.Key)`. The round-trip identifier is
  `Tag.Key` (a per-machine local key).
- **Serialize a live engine → config:** `DashboardSerializer.widgetsToConfig(name, theme,
  liveInterval, widgets, infoFile)` (single-page) / `widgetsPagesToConfig(...)` (multi-page).
- **CanonicalMapper** has `resolve(logicalId, machineId)` (FORWARD) and `logicalIds()`, but
  **NO reverse `(machineId, localKey) → logicalId` lookup** — must be added.
- **Fleet is a pure data model with ZERO Dashboard coupling** (no `libs/Dashboard` reference
  anywhere in `libs/Fleet/`). Preserving that property drove the placement decision below.
- **No companion clone affordance** exists today (no Clone/Copy/Duplicate in DashboardListPane).

## Decisions (locked this discuss)

1. **Cloner placement → static method on `DashboardSerializer`** (`libs/Dashboard/`).
   *Why:* keeps `Fleet` a pure data model — the dependency direction stays Dashboard→Fleet,
   never the reverse. The serializer already owns config↔widgets + the 1043 resolver seam, so
   the cloner is at home there. (User deferred the choice; the two alternatives — a Fleet
   method or a standalone in `libs/Fleet/` — both create a new `Fleet→Dashboard` coupling and
   were rejected on that ground.)

2. **Reverse canonical lookup → new `CanonicalMapper` method** (`libs/Fleet/`, pure data,
   Octave-safe). Scans `Entries_` for the entry matching `(machineId, localKey)` and returns
   its `logicalId` (or `''`). Mirrors the `resolve`/`logicalIds`/`isResolvable` seam.

3. **Scope → programmatic API + tests only** (no companion UI hook this phase).
   *Why:* DASH-03/04 success criteria are API + round-trip; no UI is mandated; this is the
   final milestone phase and the clean-close priority wins. A companion "Clone to machine"
   action remains a deferred follow-up (consistent with the deferred "Clone dry-run preview").

4. **DASH-04 graceful bind → the clone builds a TARGET-scoped resolver that NEVER throws.**
   For each `source.key`: reverse-lookup to a `logicalId` on the source machine →
   `resolve(logicalId, targetMachineId)` → target local key → `targetMachine.get(key)`. Any
   failed step appends a warning and leaves that widget unbound; the resolver returns `[]` for
   that key so `fromStruct` creates the widget without a Tag. The clone returns the bound
   dashboard plus the accumulated warnings.

5. **Warnings contract → a struct array** returned alongside the cloned dashboard, one entry
   per unresolved binding: fields `sourceKey`, `logicalId` (`''` if no canonical mapping),
   `reason` (e.g. `'no canonical mapping for source key'`, `'target machine has no mapping for
   this sensor'`, `'target tag not in catalog'`). Empty (`1x0`) when everything rebinds.
   *(widgetTitle dropped from the contract: the resolver is called with `source.key` only —
   it never sees the owning widget's title — so a per-widget title cannot be attached cheaply;
   `sourceKey` + `reason` fully satisfies DASH-04's "surface the unresolved bindings".)*

## Resolved during discuss (verified against live code — feeds planning)

- **`FastSenseWidget.fromStruct(s, tagResolver)` CONFIRMED** at `FastSenseWidget.m:1501`:
  `nargin<2` guard (1511); `case 'tag'` → `if ~isempty(tagResolver), obj.Tag =
  tagResolver(s.source.key)` (1523–1527), else legacy `TagRegistry.get` + `tagResolverMissing`
  warning. The seam works for the `'tag'` path — the cloner's target resolver reaches it. (The
  earlier exploratory read hit a stale block; the live source is correct.)
- **Clone mechanism → reuse the whole verified load path via a temp file.**
  `DashboardEngine.load(file, varargin)` (`DashboardEngine.m:4345`) parses
  `TagResolver`/`SensorResolver` (4356), builds `DashboardEngine(config.name)` and threads
  `resolver` through `configToWidgets` (single-page) and the per-page
  `createWidgetFromStruct(w, resolver)` loop (4385–4408, multi-page). So the cloner:
  (1) serialize the source dashboard → config → a temp `.json` (`DashboardSerializer.saveJSON`
  / the engine's own `save(filepath)` at `DashboardEngine.m:920`); (2) build the target-scoped
  resolver; (3) `DashboardEngine.load(temp, 'TagResolver', targetResolver)`; (4) delete the
  temp. This reuses single- AND multi-page reconstruction for free — no duplicated
  orchestration. (Temp-file vs hand-rolled `configToWidgets`+engine-build is a final
  planning call; temp-file is the DRY default.)
- **Reverse lookup → a standalone `CanonicalMapper.logicalIdFor(machineId, localKey)`**
  returning the `logicalId` (or `''`). The target resolver composes it with `resolve` +
  `targetMachine.get`. (`resolve`/`logicalIds`/`isResolvable` are the sibling seam.)
- **Source serialization seam:** `DashboardSerializer.widgetsToConfig(name, theme,
  liveInterval, widgets, infoFile)` (`:362`) / `widgetsPagesToConfig(...)` (`:380`) build the
  config; `DashboardEngine.save(filepath)` (`:920`) already does engine→config→file.

## Scope Boundaries

**In scope:** clone/remap programmatic API (DASH-03), graceful warnings list (DASH-04),
reverse canonical lookup, round-trip test (serialize on machine A → load on machine B), unit +
flat tests.

**Deferred / out of scope (per REQUIREMENTS.md):** clone **dry-run preview**; **batch clone**
(one source → N targets); companion **"Clone to machine" UI** hook; normalized-time overlay;
statistical fleet envelope. Critical invariants still apply: machine tags never enter the
global `TagRegistry`; no UI in `libs/Fleet/`; Octave-safe `libs/Fleet/` code (no `contains`).
