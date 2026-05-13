# Requirements: FastSense v4.0 Multi-User LAN Concurrency

**Defined:** 2026-05-13
**Core Value:** A MATLAB engineer can ingest a million-sample sensor stream, monitor thresholds, build sub-second-responsive dashboards, and navigate it all from a single Companion app — without leaving MATLAB and without external toolboxes. v4.0 preserves this while allowing up to 50 such engineers to work against the same data on a shared LAN file system.

## v1 Requirements

Requirements for v4.0 release. Each maps to roadmap phases. Numbering continues from prior milestones (v3.0 ended at phase 1023.1; pending unscoped 1025-1028 are carry-forward, NOT v4.0).

### Concurrency Primitives (CONC)

Foundation layer — cross-host file locking, stale-lock recovery, atomic writes. Without these, none of the rest works.

- [ ] **CONC-01**: User can run 2+ Companion sessions writing the same per-tag `.mat` file via the shared share without producing a corrupted MAT (verified by parallel-write integration test on real SMB share).
- [x] **CONC-02**: When a Companion holding a per-tag write lock crashes (kill -9 or hard-power-off), another Companion takes over the lock within `staleTimeout + 5s` (default `staleTimeout = 90s`) without manual cleanup. Stale-lock recovery uses **server-side filesystem mtime**, not wall-clock TTL.
- [ ] **CONC-03**: Every shared-file write (`.mat`, NDJSON log, snapshot, SQLite) uses atomic temp-file + rename so concurrent readers never observe partially-written data. CI lint forbids raw `save()` to shared paths.

### Identity & Audit (IDENT)

Who did what — sourced from OS, no login screen, FDA Part 11 §11.10(e) audit trail compliance.

- [x] **IDENT-01**: Every shared write (event ack, NDJSON entry, snapshot, lockfile) is stamped with `user@host (pid, epoch)`. `userIdentity.m` resolves via `getenv('USERNAME'|'USER')` + `system('hostname')` + optional Java InetAddress fallback (Octave-guarded by `usejava('jvm')`). In cluster mode, identity failure throws — no silent `'unknown'` writes.
- [ ] **IDENT-02**: Every event acknowledgement records (user, host, timestamp, action, target event-id). Audit trail is queryable and viewable in the Companion app's event log column.

### Shared Event Store (EVTLOG)

Replace the single MAT-file EventStore with a concurrent-safe append-only NDJSON log + leader-elected snapshot consolidator. Reader merges log onto canonical snapshot.

- [ ] **EVTLOG-01**: Events and acks are persisted as append-only NDJSON lines on the shared share. Appends are serialised through the per-tag `FileLock` (NOT `O_APPEND` atomicity, which is unreliable on SMB/NFS). On any `EventStore` save path on shared share, `journal_mode=DELETE` + `busy_timeout=10000` + `BEGIN IMMEDIATE` + application-level retry replaces WAL.
- [ ] **EVTLOG-02**: 50-process append stress test produces exactly the expected number of valid JSON lines; `EventLogReader` skips and counts any corrupt lines defensively.
- [ ] **EVTLOG-03**: A reader observing a file being mid-rewritten (temp+rename in progress) either gets the previous version or the new version — never a parse error. Reader retries on transient parse failure with 50ms backoff; surfaces a persistent failure after 3 retries.

### Acknowledgement & Event Lifecycle (ACK)

User-facing event acknowledgement workflow + single-source event emission across the cluster.

- [ ] **ACK-01**: When User A acknowledges an alarm, the ack becomes visible to the other 49 Companions within ~5 seconds (eventual-consistency target; UDP multicast hint accelerates propagation but disk state is canonical).
- [ ] **ACK-02**: An event displays a distinct visual state for "acked but condition still active" vs "acked and cleared" vs "unacked active" (per ISA-18.2 / EEMUA 191 alarm-state model — condition state and ack state are orthogonal).
- [ ] **ACK-03**: User can attach an optional free-text comment when acknowledging an event. Comment is persisted with the ack record.
- [ ] **ACK-04**: A `MonitorTag` threshold violation produces exactly ONE event in the shared EventStore regardless of how many Companions are running. Single-source guarantee derives from "lock holder for tag data is sole emitter for tag events" — `LiveTagPipeline.processTag_` and `LiveEventPipeline.processMonitorTag_` share the same per-tag `FileLock` domain.

### Resilience & Operator Communication (OPS)

System-level survivability and the documented contract operators need to trust the system.

- [ ] **OPS-01**: A temporary loss of the shared file share (network blip, server reboot) does not crash any Companion. Companions enter a degraded "read-only / waiting for share" state, retry transparently, and resume on share return. Existing single-user `.m` scripts run unchanged with no shared share.
- [ ] **OPS-02**: An operator-facing document (`examples/cluster-setup/README` or equivalent) specifies: (a) the eventual-consistency contract ("you may see ack propagation lag up to ~5s"), (b) the SMB-over-NFS recommendation on mixed-OS LANs, (c) the SMB-oplocks-must-be-disabled-on-EventStore-directory operational requirement with Windows-Server and Samba syntax, (d) the multicast firewall rule for `udpport` notification hints, (e) the NFSv3-detection startup warning.

## v2 Requirements (deferred to v4.1+)

P2 differentiators identified by FEATURES.md research, deferred from v4.0 to keep scope tight.

### Presence & Awareness (PRES)

- **PRES-01**: Companion app shows a "who's online" list of currently-running Companions (user@host) using `udpport` multicast heartbeats.
- **PRES-02**: Event-log row displays "acked by user@host (Δt ago)" once acked.
- **PRES-03**: Non-blocking toast when `TagWriteCoordinator` skips a tick because another Companion holds the lock ("Tag X being updated by user@host, 5s ago").

### Alarm Management (ALARM)

- **ALARM-01**: User can "shelve" an alarm to temporarily suppress it without acknowledging (ISA-18.2 §5.4.4 requirement; deferred only because of scope).
- **ALARM-02**: Optional ack revocation grace window (configurable per tag).
- **ALARM-03**: Threaded comments on events (multiple comments per event).
- **ALARM-04**: Shift-handover snapshot (export current alarm state for the next operator).

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Cloud / SaaS / WAN replication | LAN-only deployment per PROJECT.md constraint; eliminates partition / latency failure modes |
| Browser-primary UI | WebBridge is a read-only viewer; Companion remains primary UI per PROJECT.md |
| Authentication, RBAC, login screens | Trusted-network LAN deployment; OS username + hostname is sufficient identity; no security benefit on trusted LAN |
| In-app chat / messaging (AF-1) | Siphons operator decisions out of the audit trail; no major SCADA platform (Ignition, AVEVA, WinCC) offers it — strong negative-space signal |
| Live cursors / presence-aware editing (AF-2) | Meaningless for multi-tag dashboards; engineering effort with no operational value |
| Native mobile push notifications (AF-3) | BYO external gateway via existing `NotificationService` hook; no native mobile stack |
| Native email alerting (AF-4) | Same as AF-3 — use BYO gateway, do not build native SMTP into the platform |
| Per-user alarm filtering (AF-12) | ISA-18.2 §10 anti-pattern; operators must all see the same alarm reality. Filtering belongs on dashboards (UI-only), never on the event store |
| Pessimistic locking on dashboards (AF-8) | Dashboards are CODE (every Companion runs the same `.m` script); no runtime dashboard sharing exists |
| SQLite WAL on shared share | Structurally impossible — `wal-index` requires shared memory not available across hosts. Confirmed by SQLite team docs |
| Python / Node / Redis / Postgres in v4.0 runtime stack | PROJECT.md constraint: pure MATLAB. Bundled mksqlite + MEX C are permitted; new external services are not |
| Multi-WAN / federated sites | Out of scope per PROJECT.md; single office, single LAN |

## Traceability

Each requirement maps to exactly one phase. Phase numbering continues from v3.0 (last phase 1023.1); pending 1025-1028 are carry-forward NOT v4.0, so v4.0 starts at phase **1029**.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CONC-02 (stale recovery) | Phase 1029 (Foundation) | Pending |
| CONC-03 (atomic writes) | Phase 1029 (Foundation) | Pending |
| IDENT-01 (identity) | Phase 1029 (Foundation) | Pending |
| CONC-01 (per-tag locks) | Phase 1030 (TagWriteCoordinator) | Pending |
| EVTLOG-01 (NDJSON + rollback-mode SQLite) | Phase 1031 (EventLog) | Pending |
| EVTLOG-02 (50-proc stress) | Phase 1031 (EventLog) | Pending |
| EVTLOG-03 (read-path resilience) | Phase 1031 (EventLog) | Pending |
| ACK-04 (single-source emission) | Phase 1032 (Single-Source Events) | Pending |
| ACK-01 (ack propagation) | Phase 1032 (Single-Source Events) | Pending |
| ACK-02 (acked-but-active state) | Phase 1032 (Single-Source Events) | Pending |
| ACK-03 (ack comment) | Phase 1032 (Single-Source Events) | Pending |
| IDENT-02 (audit trail on acks) | Phase 1032 (Single-Source Events) | Pending |
| OPS-01 (network-failure tolerance) | Phase 1033 (Companion Integration) | Pending |
| OPS-02 (operator docs) | Phase 1033 (Companion Integration) | Pending |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14 (confirmed by roadmapper 2026-05-13)
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-13*
*Last updated: 2026-05-13 — Roadmapper confirmed Traceability mapping; all 14 P1 REQ-IDs map to phases 1029-1033 with no redistribution needed.*
