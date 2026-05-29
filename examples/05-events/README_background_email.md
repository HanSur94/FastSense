# Background email monitoring

This example shows how to run a FastSense `LiveEventPipeline` unattended under
`launchd` (macOS), `systemd` (Linux), or `cron` (fallback), with email
notifications sent on threshold violations.

Source files:
- `examples/05-events/example_background_email_monitor_setup.m` — the production-callable
  setup function (top-level function file). Returns a configured `LiveEventPipeline`.
  Supervisor jobs invoke this directly via `@example_background_email_monitor_setup`.
- `examples/05-events/example_background_email_monitor.m` — thin wrapper demo for a
  bounded run (`MaxRuntimeSec=8`); not needed in production.

Headless entry: `libs/EventDetection/runBackgroundMonitoring.m`.

## How it fits together

```
OS supervisor  --invokes-->  matlab -batch "..."  --calls-->  runBackgroundMonitoring(@example_background_email_monitor_setup, ...)
                                                                      |
                                                                      v
                                                      calls example_background_email_monitor_setup() to build a LiveEventPipeline
                                                      calls pipeline.start()
                                                      loops:  pause(PollSec); print heartbeat
                                                      exits on MaxRuntimeSec / interrupt
                                                      onCleanup -> pipeline.stop()
```

The supervisor's job is restart-on-crash + log rotation. The runner's job is
pipeline lifecycle + heartbeat. Each layer does one thing.

## Quick start (dry run, no SMTP)

```bash
cd /absolute/path/to/FastPlot
matlab -batch "run('examples/05-events/example_background_email_monitor.m')"
```

With no `FASTSENSE_SMTP_SERVER` set, the demo runs in DryRun mode: it prints
`[NOTIFY DRY-RUN] ...` lines instead of calling `sendmail`. The demo bounds
itself to `MaxRuntimeSec=8` so it exits deterministically.

## Enabling real email

1. **Pick a SMTP gateway.** Examples:
   - Your company's relay (`smtp.example.com:25`, no auth on trusted LAN).
   - A managed service (Mailgun, SendGrid, Postmark — all support SMTP submission).
   - A localhost relay (`localhost:25`) backed by `postfix` / `msmtp`.

2. **Set environment variables** in the shell that launches MATLAB:

   ```bash
   export FASTSENSE_SMTP_SERVER=smtp.example.com
   export FASTSENSE_FROM_ADDR=fastsense@example.com
   export FASTSENSE_RECIPIENT=ops-team@example.com
   ```

   The setup function reads these via `getenv(...)` and flips
   `NotificationService.DryRun` to `false` when `FASTSENSE_SMTP_SERVER` is set.

3. **(Optional) Configure auth** — if your relay requires auth, drive MATLAB's
   built-in `sendmail` via the `Internet` preference group:

   ```matlab
   setpref('Internet', 'SMTP_Server',   getenv('FASTSENSE_SMTP_SERVER'));
   setpref('Internet', 'SMTP_Username', getenv('FASTSENSE_SMTP_USER'));
   setpref('Internet', 'SMTP_Password', getenv('FASTSENSE_SMTP_PASSWORD'));
   setpref('Internet', 'E_mail',        getenv('FASTSENSE_FROM_ADDR'));
   props = java.lang.System.getProperties();
   props.setProperty('mail.smtp.auth',             'true');
   props.setProperty('mail.smtp.starttls.enable',  'true');
   props.setProperty('mail.smtp.socketFactory.port', '465');
   props.setProperty('mail.smtp.socketFactory.class', 'javax.net.ssl.SSLSocketFactory');
   ```

   Put that block inside your setup function (before constructing
   `NotificationService`).

> **Security:** **Never** commit SMTP passwords. Use env vars + a deploy-time
> secret store (1Password CLI, AWS Secrets Manager, `pass`, `keychain`). The
> sample env vars above are intended to be set by the supervisor, not the .m file.

## launchd (macOS)

Create `~/Library/LaunchAgents/com.example.fastsense.monitor.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key><string>com.example.fastsense.monitor</string>

    <key>ProgramArguments</key>
    <array>
      <string>/Applications/MATLAB_R2020b.app/bin/matlab</string>
      <string>-nodisplay</string>
      <string>-nosplash</string>
      <string>-batch</string>
      <string>cd('/absolute/path/to/FastPlot'); install; runBackgroundMonitoring(@example_background_email_monitor_setup, 'PollSec', 30, 'MaxRuntimeSec', 0)</string>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
      <key>FASTSENSE_SMTP_SERVER</key><string>smtp.example.com</string>
      <key>FASTSENSE_FROM_ADDR</key>  <string>fastsense@example.com</string>
      <key>FASTSENSE_RECIPIENT</key>  <string>ops-team@example.com</string>
    </dict>

    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>/usr/local/var/log/fastsense-monitor.out</string>
    <key>StandardErrorPath</key><string>/usr/local/var/log/fastsense-monitor.err</string>
  </dict>
</plist>
```

Load with:

```bash
launchctl load   ~/Library/LaunchAgents/com.example.fastsense.monitor.plist
launchctl unload ~/Library/LaunchAgents/com.example.fastsense.monitor.plist  # to stop
tail -F /usr/local/var/log/fastsense-monitor.out                              # to watch
```

`KeepAlive=true` plus `MaxRuntimeSec=0` means launchd restarts the job if it
ever exits. For finite jobs (nightly digest, etc.), set `MaxRuntimeSec` to a
positive number and use `RunAtLoad` + a `StartCalendarInterval`.

## systemd (Linux)

Create `/etc/systemd/system/fastsense-monitor.service`:

```ini
[Unit]
Description=FastSense background email monitor
After=network-online.target

[Service]
Type=simple
User=fastsense
WorkingDirectory=/opt/fastsense
Environment=FASTSENSE_SMTP_SERVER=smtp.example.com
Environment=FASTSENSE_FROM_ADDR=fastsense@example.com
Environment=FASTSENSE_RECIPIENT=ops-team@example.com
ExecStart=/usr/local/MATLAB/R2020b/bin/matlab -nodisplay -nosplash -batch "install; runBackgroundMonitoring(@example_background_email_monitor_setup, 'PollSec', 30, 'MaxRuntimeSec', 0)"
Restart=on-failure
RestartSec=10
StandardOutput=append:/var/log/fastsense/monitor.out
StandardError=append:/var/log/fastsense/monitor.err

[Install]
WantedBy=multi-user.target
```

Manage with:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now fastsense-monitor.service
sudo journalctl -u fastsense-monitor -f
```

`Restart=on-failure` covers crashes; `MaxRuntimeSec=0` keeps the job running.
Use `Type=oneshot` + a `[Timer]` unit instead if you want it to wake up on a
schedule and exit each time.

## cron (fallback)

`cron` is the least-good option (no auto-restart, no log rotation), but it
works when launchd / systemd are unavailable. Create
`/etc/cron.d/fastsense-monitor`:

```cron
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
FASTSENSE_SMTP_SERVER=smtp.example.com
FASTSENSE_FROM_ADDR=fastsense@example.com
FASTSENSE_RECIPIENT=ops-team@example.com
*/15 * * * * fastsense cd /opt/fastsense && /usr/local/MATLAB/R2020b/bin/matlab -nodisplay -nosplash -batch "install; runBackgroundMonitoring(@example_background_email_monitor_setup, 'PollSec', 60, 'MaxRuntimeSec', 840)" >> /var/log/fastsense/monitor.out 2>&1
```

The job wakes every 15 minutes and runs for 14 minutes (`MaxRuntimeSec=840`),
leaving a 60s margin before the next launch. If MATLAB hangs past 15 minutes,
cron will not start a second instance — but use `flock(1)` for explicit
single-instance enforcement on busy hosts:

```cron
*/15 * * * * fastsense /usr/bin/flock -n /tmp/fastsense-monitor.lock /opt/fastsense/run-monitor.sh
```

## Heartbeat format

Every `PollSec` seconds the runner writes one line to stdout:

```
[BG] HH:MM:SS  events=N  emails=M  uptime=Ts
```

Single-line + space-separated so `grep`/`awk` work in the journal:

```bash
journalctl -u fastsense-monitor | grep '^\[BG\]' | awk '{print $1, $2, $4, $5, $6}'
```

## Toggling dry run vs. real email

| env vars set?                         | NotificationService.DryRun | Real email? |
|---------------------------------------|----------------------------|-------------|
| `FASTSENSE_SMTP_SERVER` **unset**     | `true`                     | no          |
| `FASTSENSE_SMTP_SERVER` set           | `false`                    | yes         |

To force-test the real-email path on a developer workstation without touching
production: set `FASTSENSE_SMTP_SERVER=localhost` and run a local relay
(`postfix`, `msmtp`, MailHog, smtp4dev — all work).

## Multi-Companion considerations

The single-source guarantee from Phase 1032 (per-tag `FileLock`) ensures that
a violation produces exactly ONE event in the shared `EventStore`, regardless
of how many Companions are running. **However**, each running Companion that
has wired up a `NotificationService` will call `notify()` for events it
observes — so multiple Companions = multiple emails per event.

For operators who want exactly one email per violation, run the background
monitor on a single dedicated host. The monitor pulls from the same shared
event store as the Companions; the Companions can keep their own
NotificationService disabled (or DryRun).

## Troubleshooting

- **No emails arrive but no errors logged** — check `[NOTIFY DRY-RUN]` lines.
  `DryRun=true` is the default when `FASTSENSE_SMTP_SERVER` is unset.
- **"Cannot connect to SMTP server"** — confirm relay reachable from the host
  and port 25/465/587 open in the firewall.
- **Empty snapshot PNGs in emails** — verify the `MonitorTag` parent is being
  updated (Plan 01's `sensorDataForEvent_` requires `monitor.Parent.getXY()`
  to return non-empty data).
- **Job stops without a `[BG] exit:` line** — the supervisor killed MATLAB
  mid-tick. Increase `MaxRuntimeSec` or relax supervisor timeouts.
- **`Unrecognized function or variable 'example_background_email_monitor_setup'`** —
  `install.m` was not run before the `runBackgroundMonitoring` call. Always
  prepend `install;` to the `matlab -batch` command so `examples/05-events/`
  is on the path before the function handle is resolved.
