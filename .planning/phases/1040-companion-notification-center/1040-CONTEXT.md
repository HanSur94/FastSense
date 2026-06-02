# Phase 1040: Companion Notification Center - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Mode:** Brainstormed in-session (interactive design dialogue; approved by user)

<domain>
## Phase Boundary

Add an acknowledgeable in-app notification "inbox" to `FastSenseCompanion`: a new
collapsible right-hand pane (`NotificationCenterPane`) that live-lists *unacknowledged*
threshold-violation events from the shared `EventStore`, and lets an operator acknowledge
them — which writes shared, ISA-18.2-audited ack state via the existing
`EventStore.acknowledgeEvent`. A toolbar bell button with an unacked-count badge toggles
the pane.

This is predominantly a NEW UI SURFACE over EXISTING data + acknowledge infrastructure.
It is distinct from (and complements) the two event surfaces the Companion already has:
the append-only `EventsLogPane` (bottom log strip) and the on-demand `EventViewer`
(Gantt + table).

Out of this phase: any change to the email `NotificationService` path (see Deferred).
</domain>

<decisions>
## Implementation Decisions

### Core gap (what makes this distinct)
- An *acknowledgeable inbox*: "what's new that needs attention," cleared as operators handle items.
- Today's `EventsLogPane` is append-only (no per-item dismiss); the `EventViewer` is on-demand. Neither is an ack-driven inbox. This pane fills that gap.

### Feed source — EventStore is the single source of truth
- Pane reads current events and filters to UNACKED (`isempty(Event.AckedAt)`).
- Live refresh piggybacks on the Companion's EXISTING `LiveTimer_` / `onLiveTick_` loop (period = `LivePeriod`). NO new timer.
- When a `LiveEventPipeline` is supplied (Companion already accepts `LiveEventPipelines`), its tick also nudges a refresh for lower latency.
- Diff incoming events by `Event.Id` so the list does not flicker and the badge only animates on genuinely new items.

### Dismiss == Acknowledge (shared, audited)
- Per-item Acknowledge → `EventStore.acknowledgeEvent(eventId, opts)`.
- Item leaves the inbox on the next diff (it is now acked). Badge decrements.
- Ack is shared + audited (`{user, host, epoch, comment}`); ~5s cluster propagation (ACK-01) to other Companions.
- Ack on an already-acked event (race) is a NO-OP, not an error.

### Placement / UI integration (Approach 1 — chosen)
- New self-contained handle class `NotificationCenterPane` in `libs/FastSenseCompanion/`, a SIBLING to `EventsLogPane`: `attach(parent, theme)` / `detach()`, fires `DetachRequested`, detachable to its own window, state survives attach/detach.
- Companion gains a toolbar BELL button (beside the existing "Events" / Live buttons) with an unacked-count badge; toggling it shows/hides a 4th rightmost grid column. Existing Tag/Dashboard/Inspector columns reflow.
- Bell DISABLED when no EventStore (mirror the existing `hEventsBtn_` enable/disable rule).

### Error handling (follow Companion conventions)
- Every callback wrapped try/catch → non-blocking `uialert` (existing Companion pattern) so EventStore read/ack failures never crash the window.
- EventStore read failure: keep last-good list + show an inline "stale" marker.

### Claude's Discretion
- Exact pixel layout of the pane, badge rendering, severity color mapping (within `CompanionTheme`).
- Detached-window title/arrangement.
- Internal diffing / data-structure details.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets (verified in-session)
- `libs/FastSenseCompanion/EventsLogPane.m` — the detachable-pane PATTERN to mirror (attach/detach, `DetachRequested`, ring buffer, header search + level-filter dropdown, "Updated:" label, pop-out icon).
- `libs/EventDetection/EventStore.m` — `acknowledgeEvent(eventId, opts)` (`opts.comment`), `numEvents()`, ack-records API; events persisted to a shared `.mat` (single-user) / SQLite (cluster).
- `libs/EventDetection/Event.m` — `AckedAt` (empty = unacked), `AckedBy`, `AckComment`, `Severity` (1 info / 2 warn / 3 alarm), `IsOpen` (still-open violation), `Id`, `Notes`, `computeDisplayState()`.
- `libs/FastSenseCompanion/FastSenseCompanion.m` — `LiveTimer_` / `onLiveTick_` / `IsLive` / `LivePeriod` (reuse for refresh), `EventStore_` / `getEventStore()` (resolved store), `LiveEventPipelines_` (optional observation), `hEventsBtn_` + `openEventViewer_()` (row-click target; enable/disable-on-EventStore pattern), toolbar grid + 3-column root grid (extend to 4).
- `tests/CaptureNotificationService.m` — model for a capture/stub test double; build an analogous stub EventStore.

### Established Patterns
- Detachable pane fires `DetachRequested`; Companion listens and re-parents to a uifigure.
- Non-blocking `uialert` for all callback errors (never crash the companion window).
- Severity/level filter dropdown (EventsLogPane) — reuse for the severity filter.

### Integration Points
- `FastSenseCompanion` constructor/build: instantiate `NotificationCenterPane`, add bell button + badge, add the toggleable 4th grid column.
- `onLiveTick_`: after existing work, refresh the notification pane (diff unacked events, update badge).
- **EventStore read API — OPEN, confirm during planning.** `EventViewer` reads events from the `.mat` file directly; `FastSense` queries EventStore for overlays. If no in-memory "current events" accessor exists, add a thin `EventStore.unackedEvents()` (or `events()`) helper rather than re-reading the file inside the pane.

</code_context>

<specifics>
## Specific Ideas (approved UX defaults)

- Badge counts ALL unacked events, colored by the highest severity present.
- Default filter shows ALL severities (info + warn + alarm), with a severity dropdown to narrow.
- Acknowledge is ONE-CLICK; an "Ack with comment…" affordance prompts for `opts.comment`.
- Include an "Acknowledge all visible" bulk action.
- Row-click opens the existing Event Viewer via `Companion.openEventViewer_()` (future: focused on the clicked event).
- Show a "LIVE" tag on still-open events (`Event.IsOpen == true`).
- Newest-first ordering.
- Empty state text: "No unacknowledged events."

</specifics>

<deferred>
## Deferred Ideas (out of scope for v1 — YAGNI)

- Linking the email `NotificationService` into the app. The email path stays as-is; the in-app pane reads the EventStore directly (both derive from the same events, so they stay consistent). Reusing NotificationService *rules / severity* for in-app filtering could be a follow-up.
- Sounds / desktop / OS notifications.
- Snooze / temporary mute.
- Event grouping or storm-collapsing (many rapid violations).
- Per-user local "seen" state separate from shared ack (we chose dismiss == shared acknowledge).

</deferred>
