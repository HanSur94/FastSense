# Phase 1013 Brainstorm Notes

Captured during the initial feature conversation before `/gsd:discuss-phase` / `/gsd:plan-phase`. These are **user-stated requirements and decisions**, not a finalized design.

## History note

Originally drafted as "Phase 1012" in the `distracted-kalam-809418` worktree before a number collision was discovered: PR #59 had already merged a different Phase 1012 ("Tag ingestion pipeline — raw files → per-tag .mat") into `main`. The duplicate add was discarded; this phase is renumbered to **1013** — the next clean integer after the merged 1012.

## User intent (original German)

- FastSense Widget ist das go-to Plotting-Diagramm.
- Event-Pipe detektiert Events, die im EventStore gespeichert werden.
- Events sollen im FastSense Widget als runde Marker sichtbar sein.
- FastSense Widget kann Event-Symbole ein-/ausschalten → braucht Verbindung zum EventStore.
- Events müssen Tags zugewiesen werden (bei Event-Generierung).
- User klickt auf Event-Symbol → sieht alle Infos zum Event.
- Event-Symbol am Start-Datenpunkt eines Events.
- Muss auch funktionieren, wenn das Event gerade erst detektiert wurde und noch nicht abgeschlossen ist.

## Scope delta vs. Phase 1010

Phase 1010 already shipped:

- `Event.TagKeys` + `EventBinding` registry
- `EventStore.eventsForTag()`
- `FastSense.renderEventLayer_` with round markers (closed events only)
- `FastSense.ShowEventMarkers` toggle
- Theme color by `Event.Severity`

**This phase adds on top:**

1. **Open/in-progress event visibility** — LiveEventPipeline writes events to EventStore immediately on detection-start (not only on close). Event gains a status field (e.g. `IsOpen` / `Status = 'Open' | 'Closed'`); `EndTime` is updated on close. `renderEventLayer_` renders open events too (potentially styled differently — hollow vs filled — TBD).
2. **Click-to-details** — clicking a round marker opens an info surface (panel / popup / sub-figure) showing all Event fields: StartTime, EndTime/Duration, PeakValue, Min/Max/Mean/RMS/Std, Severity, Category, TagKeys, Threshold info, open-indicator.
3. **FastSenseWidget-level wiring** — expose `ShowEventMarkers` + `EventStore` binding on the dashboard widget (not only on the bare `FastSense` core class), so dashboard users get markers + toggle + click-details without dropping to `FastSense` directly.

## Architecture decisions (locked in during brainstorm)

- **D1. Single Source of Truth = EventStore.** Pipeline persists both open and closed events to EventStore; widget reads only from EventStore.
  - Rejected alternatives: (B) widget merges EventStore + MonitorTag; (C) push-callback infra.
  - Rationale: symmetric with existing EventStore-centric consumers (EventViewer, EventTimelineWidget), snapshot/reload keeps working.

## Open questions for `/gsd:discuss-phase`

- **Q1. Marker Y-position.** Candidate A: `Y = signal value at StartTime`. Candidate B: `Y = ThresholdValue`. Candidate C: fixed edge (e.g. 95% of yLim). Brainstorm lean: **A (signal)**. Not yet confirmed by user.
- **Q2. Tag assignment at generation.** User said "Events müssen Tag zugewiesen werden … also bei Event-Generierung auch ein Tag zuweisen." `Event.TagKeys` exists; verify whether `EventDetector` / `LiveEventPipeline` populate it reliably for every new event, or if this phase must harden that path.
- **Q3. Click-details surface.** Floating tooltip vs. side panel vs. modal vs. jump-to-`EventViewer`. Need UX decision.
- **Q4. Open vs. closed marker styling.** Same symbol? Hollow vs filled? Different color ring?
- **Q5. Live refresh cadence.** How often does the widget re-query EventStore during live mode? Piggyback on existing `DashboardEngine.onLiveTick`?
- **Q6. Severity / Category filtering on toggle.** Is toggle global on/off only, or filter by Severity / Category?

## Integration note: Phase 1012 (Tag Pipeline) just landed

PR #59 added `BatchTagPipeline`, `LiveTagPipeline`, `readRawDelimited_`, `selectTimeAndValue_`, `writeTagMat_`. This phase should verify that:
- The new pipeline classes emit Events via the same `EventStore` path as `LiveEventPipeline` (or document the divergence).
- `LiveTagPipeline` is the right integration point for "write open event to EventStore on detection-start" rather than the legacy `LiveEventPipeline`, if the former is now the canonical live path.

## Files expected to touch (rough sketch, not binding)

- `libs/EventDetection/Event.m` — add `IsOpen` / `Status`.
- `libs/EventDetection/LiveEventPipeline.m` and/or `libs/SensorThreshold/LiveTagPipeline.m` and/or `libs/SensorThreshold/MonitorTag.m` — emit open events on rising edge, update on falling edge. Decision on which file(s) depends on Q above.
- `libs/EventDetection/EventStore.m` — schema handling for in-place event update.
- `libs/FastSense/FastSense.m` (`renderEventLayer_`) — open-event rendering + click callback wiring.
- `libs/Dashboard/FastSenseWidget.m` — `ShowEventMarkers`, `EventStore` property, click-details surface.
- Tests + examples.

## Out of scope (do NOT touch)

- Phase 1010 deliverables: `Event.TagKeys`, `EventBinding`, `EventStore.eventsForTag`, existing `renderEventLayer_` closed-event path, Severity→Color theme mapping. These stay byte-for-byte unless a contract change is explicitly required.
- Phase 1012 deliverables: `BatchTagPipeline` / `LiveTagPipeline` raw-file-to-.mat ingestion contracts. Read from them, don't rewrite them.
