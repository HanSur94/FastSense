# FastSense v4.0 Cluster Setup

This guide is for system administrators bringing up a shared file share for
FastSense Companions running in multi-user (cluster) mode. The cluster lets
up to 50 engineers work against the same data without leaving MATLAB and
without external services.

The shared filesystem **is** the coordination plane. There is no FastSense
server process, no Redis, no database server. Everything is files on a
shared SMB or NFS share, plus optional UDP multicast hints for fast ack
propagation.

## What FastSense Guarantees

| Guarantee | Detail |
|-----------|--------|
| No data corruption | Per-tag write locks (FileLock) + atomic temp+rename writes prevent any reader from seeing a partial file. |
| No lost acks | Every ack is written to the shared `events.sqlite` with `BEGIN IMMEDIATE` + retry. |
| Single-source events | A `MonitorTag` threshold violation produces exactly ONE event regardless of how many Companions are running. |
| Eventual consistency | When User A acks an alarm, **expect propagation to other Companions within ~5 seconds**. If two operators ack simultaneously, BOTH acks are recorded in the audit trail; the first to commit becomes the canonical ack-user. |

## What FastSense Does NOT Guarantee

- **Strong consistency.** Reads from a Companion's local view may be up to ~5s
  stale. Do not write business logic that requires sub-second cross-Companion
  consensus.
- **WAN replication.** This is a LAN-only design. Mounting the share over a
  VPN or WAN link is not supported.
- **Tolerance of misconfigured oplocks.** SMB oplocks MUST be disabled on the
  EventStore directory (see below). With oplocks enabled the SQLite file CAN
  and WILL be corrupted under multi-writer load.
- **Tolerance of unaware NFSv3 deployments.** macOS NFSv3 clients have
  documented buggy POSIX advisory locking. If you must use NFSv3, restrict
  EventStore writers to Linux clients and set `FASTSENSE_ALLOW_NFSV3=1`
  (see "NFSv3 Warning" below).

## Recommended Topology

| Component | Recommended | Acceptable | Avoid |
|-----------|-------------|-----------|-------|
| File share protocol | **SMB** (CIFS) on all clients | NFSv4 with `noac` on Linux-only | NFSv3 (see warning below); WebDAV; SSHFS |
| OS mix | Windows + macOS + Linux all on SMB | Windows + Linux on SMB; macOS clients read-only on NFSv4 | NFSv3 with mixed macOS clients |
| Network | Switched gigabit LAN, single broadcast domain | Multiple VLANs with multicast routing enabled | WAN; cellular; Wi-Fi when latency-sensitive |
| Time sync | NTP enforced on all clients (drift < 1 s) | Drift < 10 s | Unmanaged clocks; manual `date` adjustments |

**SMB-over-NFS on mixed-OS LANs.** macOS's NFS client implementation is
documented as having buggy POSIX advisory locking behaviour (per the SQLite
team's own deployment guidance). When you have macOS clients in the mix,
serve the FastSense share over SMB — not NFS. If NFSv4 is your only option,
restrict the FastSense EventStore writers to Linux clients only; macOS
clients can mount read-only via NFS or full read/write via SMB on the same
file server.

## Setup Step 1 — Provision the Share

Create a single shared directory on the file server, accessible to every
Companion user with read/write permissions:

```
\\fileserver\fastsense\v4-cluster\
```

or POSIX:

```
/mnt/fastsense/v4-cluster/
```

FastSense will auto-create three subdirectories on first cluster-mode
startup: `tags/`, `locks/`, `events/`.

## Setup Step 2 — Disable SMB Oplocks on the Share

**This is mandatory.** SMB opportunistic locks (oplocks) cache file contents
on the client; under multi-writer load the oplock-break flush window can
yield torn reads of the SQLite EventStore file. Per the SQLite team's
[How to Corrupt an SQLite Database](https://sqlite.org/howtocorrupt.html),
SMB oplocks are a documented corruption mode for SQLite over network FS.

### Windows Server

Run the bundled PowerShell snippet on the file server as Administrator:

```powershell
.\smb-disable-oplocks.ps1
```

Or directly:

```powershell
Set-SmbServerConfiguration -EnableLeasing $false -Force
```

See [`smb-disable-oplocks.ps1`](./smb-disable-oplocks.ps1) for the runnable
script with verification readback.

### Samba (Linux file server)

Add to your `smb.conf` per-share section:

```ini
[fastsense-v4-cluster]
    path = /srv/fastsense/v4-cluster
    oplocks = no
    level2 oplocks = no
    kernel oplocks = no
    # (... your existing per-share settings ...)
```

See [`smb-disable-oplocks.conf`](./smb-disable-oplocks.conf) for the canonical
snippet. Restart Samba (`systemctl restart smbd nmbd`) after editing.

### Verification

On first cluster-mode startup, FastSense runs an oplock smoke probe
(`ClusterConfig.checkSharedConfig`) — a deterministic 1024-byte canary
write-and-immediate-read. On mismatch you'll see a one-time warning:

```
Warning: Concurrency:smbOplockDetected
SMB oplock canary smoke test FAILED on '\\fileserver\fastsense\v4-cluster'.
...
Operational fix: disable oplocks on the EventStore directory.
```

The probe is best-effort — false negatives are possible. The configuration
step above is the authoritative fix; the probe is the safety net.

## Setup Step 3 — Open the Multicast Firewall Rule

FastSense uses MATLAB `udpport` multicast on the IPv4 site-local admin scope
`239.192.40.x` (per RFC 2365) to accelerate ack propagation. Disk state is
canonical — dropped multicast packets only delay, never lose, an ack.

Open UDP traffic on the cluster's chosen port (default 40000) for the
`239.192.40.0/24` group across your LAN. Per-OS firewall configuration is
documented in [`multicast-firewall.md`](./multicast-firewall.md).

Notes:
- macOS and Windows Defender may prompt the first time MATLAB binds the
  socket. Approve "private network" only — do NOT expose to public networks.
- If your managed switches block multicast (some default configurations do),
  FastSense falls back to UDP broadcast `255.255.255.255` on the same port
  with a one-time warning. Confirm with your network admin.

## Setup Step 4 — NFSv3 Warning and Escape Hatch

NFSv3 lock management is documented to have ghost-lock and lock-loss failure
modes (rpc.statd / rpc.lockd disappearance, mixed-host inconsistency). On
startup, FastSense detects NFSv3 mounts and emits a one-time warning:

```
Warning: Concurrency:nfsv3Detected
SharedRoot '/mnt/fastsense' appears to be on an NFSv3 mount.
NFSv3 advisory locking is unreliable (rpc.statd may fail to recover locks
after network blips). Mitigation: use NFSv4 with 'noac' on Linux clients
OR migrate to SMB. To suppress this warning, set FASTSENSE_ALLOW_NFSV3=1.
```

If you have read this warning and accepted the risk (e.g. you have a
well-managed NFSv4 deployment that mount-detected as NFSv3 by mistake, or
you have isolated EventStore writers to a single client), suppress the
warning with the environment variable:

```bash
export FASTSENSE_ALLOW_NFSV3=1
```

on POSIX, or

```powershell
$env:FASTSENSE_ALLOW_NFSV3 = '1'
```

on Windows.

**Do not set this variable to silence the warning without addressing the
underlying issue.** FastSense does not refuse to start on NFSv3 — it only
warns — but the failure modes documented in PITFALLS.md are real, not
theoretical.

## Setup Step 5 — Launch Companions in Cluster Mode

Each user launches their Companion with the `SharedRoot` NV-pair:

```matlab
app = FastSenseCompanion( ...
    'Dashboards', {myDashboard}, ...
    'Registry',   TagRegistry, ...
    'SharedRoot', '\\fileserver\fastsense\v4-cluster\');
```

Or set the environment variable once and omit the NV-pair:

```bash
export FASTSENSE_SHARED_ROOT=/mnt/fastsense/v4-cluster
```

With the env var set, every Companion the user launches enters cluster
mode automatically.

## Operator Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| One-time `Concurrency:smbOplockDetected` warning at startup | SMB oplocks enabled on the share | Run `smb-disable-oplocks.ps1` (Windows) or update `smb.conf` (Samba); restart the file-sharing service. |
| One-time `Concurrency:nfsv3Detected` warning at startup | SharedRoot is on an NFSv3 mount | Migrate to NFSv4 with `noac` OR move to SMB. If you have mitigated locally, set `FASTSENSE_ALLOW_NFSV3=1`. |
| Ack propagation > 30s between Companions | Multicast firewall blocking 239.192.40.x | Open the firewall rule per [`multicast-firewall.md`](./multicast-firewall.md), or accept broadcast fallback. |
| One-time `Concurrency:identityResolutionFailed` error on startup | OS username/hostname could not be resolved | Verify `whoami` and `hostname` shell commands work in your MATLAB launcher's environment. On Octave `--disable-java` builds, install the `instrument-control` package. |
| Companion shows "Tag P-101 is being updated by alice@plant-a (5s ago)" notices | Normal cluster contention — two Companions wrote the same tag near-simultaneously | No action needed. The skipped tick is deferred to the next interval. |
| All Companions hang for ~90s after one Companion is killed | Stale-lock recovery in progress | Normal behaviour. After `staleTimeout + 5s` (default 95s), the next Companion takes over. To reduce wait time, lower `StaleTimeout` in the FileLock constructor (not recommended below 60s). |

## See Also

- `.planning/research/SUMMARY.md` — design rationale for v4.0
- `.planning/research/PITFALLS.md` — detailed failure modes (Pitfalls 2, 11, 14 surface here)
- `libs/Concurrency/ClusterConfig.m` — startup probe + NFSv3 detection
- `libs/Concurrency/FileLock.m` — per-tag advisory lock primitive

---
*FastSense v4.0 Multi-User LAN Concurrency — Operator Setup*
