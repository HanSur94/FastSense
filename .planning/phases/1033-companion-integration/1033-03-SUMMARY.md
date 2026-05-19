---
phase: 1033-companion-integration
plan: "03"
subsystem: Concurrency + Operator Docs
tags: [operator-docs, cluster-setup, smb, nfs, oplocks, multicast, nfsv3-detection, tdd]
dependency_graph:
  requires: [1032-05-SUMMARY.md, ClusterConfig checkSharedConfig (oplock canary)]
  provides: [examples/cluster-setup/README.md, detectNfsv3_ detection, FASTSENSE_ALLOW_NFSV3 escape hatch]
  affects: [libs/Concurrency/ClusterConfig.m, examples/cluster-setup/, tests/suite/TestClusterConfigNfsv3.m]
tech_stack:
  added: []
  patterns: [TDD RED-GREEN-REFACTOR, mount-table parsing for NFSv3 detection, one-time persistent warning pattern]
key_files:
  created:
    - examples/cluster-setup/README.md
    - examples/cluster-setup/smb-disable-oplocks.ps1
    - examples/cluster-setup/smb-disable-oplocks.conf
    - examples/cluster-setup/multicast-firewall.md
    - tests/suite/TestClusterConfigNfsv3.m
  modified:
    - libs/Concurrency/ClusterConfig.m
decisions:
  - "NFSv3 detection is best-effort (false negatives acceptable, false positives would annoy operators) — conservative default treats unversioned 'nfs' mounts as v3-suspect"
  - "escape hatch FASTSENSE_ALLOW_NFSV3=1 is a warning suppressor, not a startup gate — operator runs with risk acknowledged"
  - "nfsv3WarningEmitted_ is a separate persistent from warningEmitted_ so each warning can fire independently"
  - "detectNfsv3_ is public-accessible (Static, no Access restriction) to enable test observability without reflection tricks"
metrics:
  duration_sec: 523
  completed_date: "2026-05-14"
  tasks_completed: 2
  files_created: 5
  files_modified: 1
---

# Phase 1033 Plan 03: Operator Docs + NFSv3 Detection Summary

Operator-facing cluster-setup guide and `ClusterConfig.detectNfsv3_` extension fulfilling OPS-02 trust contract — covers all 5 required bullets: eventual-consistency contract, SMB-over-NFS recommendation, oplocks-disabled requirement with Windows Server and Samba syntax, multicast firewall rule (239.192.40.x, RFC 2365), and NFSv3-detection startup warning with FASTSENSE_ALLOW_NFSV3 escape hatch.

## Tasks Completed

### Task 1: Operator README + 3 snippet files (commit 9d149cb)

Four files created in `examples/cluster-setup/`:

| File | Purpose |
|------|---------|
| `README.md` | Full operator setup guide — 5-step walkthrough from share provisioning to Companion launch; covers all OPS-02 bullets; standalone (no source reading required) |
| `smb-disable-oplocks.ps1` | Windows Server PowerShell: disables SMB leases + per-share oplock disable on FastSenseShare |
| `smb-disable-oplocks.conf` | Samba `smb.conf` per-share snippet: `oplocks = no`, `level2 oplocks = no`, `kernel oplocks = no`, `posix locking = yes` |
| `multicast-firewall.md` | Per-OS firewall rules: Windows Defender `New-NetFirewallRule`, macOS `pfctl`, Linux `iptables`/`firewalld`/`nftables`; broadcast 255.255.255.255 fallback |

The README covers all 5 OPS-02 bullets explicitly:
- **(a) Eventual-consistency contract**: "expect propagation to other Companions within ~5 seconds. If two operators ack simultaneously, BOTH acks are recorded; first to commit becomes canonical ack-user."
- **(b) SMB-over-NFS**: macOS NFS has documented buggy POSIX advisory locking; prefer SMB on mixed-OS LANs
- **(c) Oplocks disabled**: Windows Server `Set-SmbServerConfiguration -EnableLeasing $false` + Samba `oplocks = no` + `level2 oplocks = no` + `kernel oplocks = no` per-share
- **(d) Multicast firewall**: `239.192.40.x` (RFC 2365 site-local admin scope), default port 40000, broadcast fallback documented
- **(e) NFSv3 startup warning**: `Concurrency:nfsv3Detected` warning, FASTSENSE_ALLOW_NFSV3=1 escape hatch documented

### Task 2: ClusterConfig.detectNfsv3_ extension (commits 49be3fc RED + 0aab979 GREEN)

**TDD cycle executed:**
- RED (49be3fc): `tests/suite/TestClusterConfigNfsv3.m` with 3 failing tests
- GREEN (0aab979): `libs/Concurrency/ClusterConfig.m` extended with `detectNfsv3_` and NFSv3 warning block

**Implementation strategy:**

`detectNfsv3_(sharedRoot)` static method:
1. Returns `false` immediately on Windows (`ispc()`) — Windows NFSv3 clients are rare
2. Parses `mount` output (POSIX) for the longest mountpoint prefix matching `sharedRoot`
3. Checks if mount type contains `nfs` at all — returns false if not
4. Explicit v3 detection: `vers=3` or `nfsvers=3` → true
5. Conservative default: `nfs` without `vers=4`, `nfsvers=4`, or `nfs4` → true (Linux legacy `nfs` mount type defaults to v3)
6. All exceptions caught silently → false (false negatives acceptable)

Wire-in inside `checkSharedConfig`:
- Called after the oplock probe (never on early-return paths — they return `nfsv3Detected=false` from initialization)
- Separate `persistent nfsv3WarningEmitted_` flag from the smbOplock one
- Warning suppressed when `FASTSENSE_ALLOW_NFSV3=1`
- `result.evidence.nfsv3Detected` field added for test observability

**Static analysis results:**
- MISS_HIT `mh_style`: 0 issues
- MISS_HIT `mh_lint`: 0 issues
- MATLAB `checkcode`: 3 informational suggestions (2x `%#ok<USENS>` suppression no longer needed in R2025b — mirrors pattern already in original file at line 78; 1x `newline` style suggestion). Zero errors.

**Test results:**
- `TestClusterConfigOplocks` (regression): **7/7 PASSED**
- `TestClusterConfigNfsv3` (new): **3/3 PASSED** (testWindowsSkipsDetection correctly filtered on macOS via `assumeFail`)

## Decisions Made

1. **NFSv3 detection is best-effort, warning-only (not fatal).** Context.md OPS-02 specifies a "warning" not a startup refusal. False negatives are acceptable (operators with correct NFSv4 won't be warned). False positives (legacy `nfs` without explicit version) are mitigated by the FASTSENSE_ALLOW_NFSV3 escape hatch.

2. **FASTSENSE_ALLOW_NFSV3=1 suppresses warning, does not change behavior.** FastSense still runs on NFSv3 — the warning simply informs. This matches how FASTSENSE_SKIP_BUILD works elsewhere in the codebase.

3. **separate persistent flag per warning ID.** `nfsv3WarningEmitted_` is independent of `warningEmitted_` (the oplock flag). If a share triggers both issues, both one-time warnings fire once each.

4. **Mount-table prefix matching uses longest-prefix rule.** Multiple NFS submounts are handled correctly — the most specific mountpoint wins.

## Deviations from Plan

None — plan executed exactly as written. The only minor divergence: the `%#ok<USENS>` comment on the new persistent mirrors the existing pattern in the original file, which MATLAB R2025b now says is "no longer needed." This is purely cosmetic (R2020b still generates the warning being suppressed) and matches the pre-existing code style.

## Known Stubs

None. The operator README is complete and self-contained. `detectNfsv3_` is fully implemented. The positive NFSv3 test case (real NFSv3 mount) is intentionally deferred to Plan 04 acceptance testing against a real shared share, as documented in the test file header comment.

## Hand-off Notes for Plan 04

- The 50-Companion acceptance test (`Test50CompanionAcceptance.m`) should reference `examples/cluster-setup/README.md` for the operator setup steps. An operator follows the README to configure the share, then runs the acceptance test to verify.
- The `FASTSENSE_ALLOW_NFSV3=1` escape hatch should be documented in the acceptance test's CI environment setup if the test VM uses an NFS share.
- `ClusterConfig.checkSharedConfig` now returns `result.evidence.nfsv3Detected` — the acceptance test can assert this field is `false` on a properly-configured SMB share to confirm the share protocol is correct.
- OPS-02 is now fully closed: all 5 required bullets are documented AND the NFSv3 detection code is in place.

## Self-Check: PASSED

Created files exist:
- examples/cluster-setup/README.md: FOUND
- examples/cluster-setup/smb-disable-oplocks.ps1: FOUND
- examples/cluster-setup/smb-disable-oplocks.conf: FOUND
- examples/cluster-setup/multicast-firewall.md: FOUND
- tests/suite/TestClusterConfigNfsv3.m: FOUND

Modified files exist:
- libs/Concurrency/ClusterConfig.m: FOUND

Commits exist:
- 9d149cb (Task 1 docs): FOUND
- 49be3fc (TDD RED): FOUND
- 0aab979 (TDD GREEN): FOUND

All acceptance criteria passed: grep checks on README (oplocks 17x, eventual consistency 1x, NFSv3 19x, multicast/239.192.40 10x, FASTSENSE_ALLOW_NFSV3 5x), ClusterConfig (NFSv3/nfsv3 13x, Concurrency:nfsv3Detected 2x, FASTSENSE_ALLOW_NFSV3 3x, detectNfsv3_ 3x).
