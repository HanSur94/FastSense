# Manual Verification: Phase 1041 — Global Time Range for FastSenseCompanion

**Purpose:** Verify behaviors that cannot be asserted headlessly — inline control
rendering, one-click preset interaction, Custom-strip date entry, relative-slide on
live ticks, empty-state widget display, persistence across sessions, and theme restyle.

> **Design note (2026-06-03):** The original separate-window picker was replaced by an
> **inline toolbar control** per user request: a preset **dropdown** in toolbar column 9
> (applies on select) plus a trailing **"Custom…"** item that reveals an **in-window
> overlay strip** under the toolbar (Relative / Absolute tabs, Apply / Cancel). No
> separate figure / modal window is ever opened.

**Prerequisites:**
- Run `install()` once in the MATLAB Command Window to add paths and compile MEX.
- A live MATLAB session (R2020b+ or R2021a+ recommended for full uifigure support).
- An optional disk-backed sensor (e.g., `demo/industrial_plant/buildDashboard.m` demo,
  or any sensor whose data span > 7 days) for the windowing + empty-state steps.
  Steps 3, 6, and 7 benefit from disk-backed data; in-RAM tags work for all other steps.

---

## Manual Verification

Open the companion in MATLAB. The simplest setup with a minimal in-RAM registry:

```matlab
install();
TagRegistry.clear();
% Register two simple tags (or use the industrial-plant demo).
t1 = SensorTag('s1', 'Name', 'Pressure', 'X', datenum(2020,1,1):datenum(2020,12,31), ...
               'Y', randn(1, 365), 'Labels', {'plant'}, 'Criticality', 'low');
t2 = SensorTag('s2', 'Name', 'Temperature', ...
               'X', datenum(2025,6,1):datenum(2026,6,2), ...
               'Y', 20 + randn(1, 367), 'Labels', {'plant'}, 'Criticality', 'low');
TagRegistry.register('s1', t1);
TagRegistry.register('s2', t2);
c = FastSenseCompanion('Registry', TagRegistry);
```

### Step 1 — Default range control label and color

**Action:** Inspect the companion toolbar after it opens.

**Expected:**
- The range **dropdown** (positioned to the left of the gear, toolbar column 9) reads
  **"Last 7 days"**.
- The dropdown background matches the inactive (WidgetBorderColor) toolbar style — same
  as the Tile, Wiki, and Events buttons. No Accent highlight (no filter is set yet).

---

### Step 2 — Dropdown lists presets + "Custom…" (no separate window)

**Action:** Open the range dropdown.

**Expected:**
- The dropdown lists six presets, in order:
  "Last 24 hours", "Last 7 days", "Last 30 days", "Last 90 days", "Last 1 year", "All data".
- A final **"Custom…"** item appears after the presets.
- The current spec ("Last 7 days") is the selected value.
- **No popup / separate figure** opens just by viewing the list.

---

### Step 3 — One-click preset apply + label update + re-query

**Action:** Select **"Last 30 days"** from the dropdown.

**Expected:**
- The preset applies **immediately** (no separate Apply step).
- Dropdown value changes to **"Last 30 days"**.
- Dropdown background changes to the **Accent color** (visual signal that a filter is
  active — non-default range).
- Any open dashboard or ad-hoc plot **re-queries** its data to the last 30 days. For a
  disk-backed sensor this is visible as fewer points loading; for an in-RAM tag the line
  updates to the 30-day slice.

---

### Step 4 — Custom… → Relative builder (live preview + Apply)

**Action:** Select **"Custom…"** from the dropdown, then click the **Relative** tab in the
strip that appears under the toolbar.

**Expected:**
- An **in-window strip** appears directly under the toolbar (NOT a separate window). The
  companion figure count does not change.
- The Relative panel shows a spinner (N), a unit dropdown, and "Last … until now" labels.
- Change the spinner to **14** and the unit dropdown to **weeks**.
- A preview label below the controls updates live: it shows a date range
  approximately `YYYY-MM-DD to YYYY-MM-DD` spanning 98 days from today.
- Click **Apply**.

**After Apply:**
- The strip closes.
- The toolbar dropdown reads **"Last 14 weeks"** (shown as a transient leading item).
- Open views re-query to the 98-day window.

---

### Step 5 — Custom… → Absolute date entry: validation + Apply

**Action:** Select **"Custom…"** again. The strip opens on the **Absolute** tab by default
(direct date entry).

**Expected:**
- Two date pickers (Start, End) are visible, seeded from the current range (or
  today − 7 days … today).

**Sub-step A — Validation:**
- Set the Start date picker to today's date.
- Set the End date picker to yesterday's date (Start > End).
- The **Apply button is disabled** and the preview label shows
  **"Invalid: start must be before end"** in red (StatusAlarmColor).

**Sub-step B — Valid absolute range:**
- Fix the End date to tomorrow's date.
- Preview label shows **"1 days"** (or "2 days" depending on clock).
- Apply is enabled; click **Apply**.
- The strip closes; the dropdown reads a date string e.g. **"2026-06-02 to 2026-06-04"**.
- Open views re-query to that fixed window.

---

### Step 6 — Empty-state widget: data outside the active window

**Action:** This step requires a tag whose data does NOT overlap the active window.
Ensure `s1` (2020 data) is selected while the range is set to the last 30 days (i.e.
a modern date range that excludes 2020).

Open an ad-hoc plot for `s1` from the companion Inspector ("Plot" button).

**Expected:**
- The spawned plot window shows a **centered bold label**: **"No data in selected range"**
  (14pt bold, muted foreground color, inside the widget panel). No axes, no crash.
- The toolbar dropdown still shows the active range (Accent color).

---

### Step 7 — Relative-window slide on live tick (requires a live-to-today sensor)

**Action:** Ensure the active range is **"Last 7 days"** (select the preset in the dropdown
if needed). Open a live-to-today sensor (e.g., `s2` which spans from 2025 to today).
Click **Live** to start live mode.

Let at least 3 live ticks elapse (default: 1 second per tick).

**Expected for relative range:**
- The right edge of the data window slides with wall-clock "now" — new tail samples
  appear on every tick WITHOUT a strip re-open or full figure rerender flicker.
- The toolbar dropdown value remains **"Last 7 days"** (it does not add a timestamp or change).

**Expected for absolute range (regression):**
- Change the range to an Absolute window (via Custom… → Absolute). Live ticks
  continue but the window is **fixed** — the left edge does NOT slide.

---

### Step 8 — Theme restyle of the range control (and open strip)

**Action:** With the Custom strip closed, open the companion Settings dialog (gear button).
Switch the theme (e.g., from dark to light). Close the settings dialog.

**Expected:**
- The range dropdown restyles to the new theme (FontColor + BackgroundColor match the new
  theme's foreground / WidgetBorderColor or Accent as appropriate).

**Bonus (if the strip is open):**
- Open Custom… so the strip is visible; switch the theme while it is open. The strip's
  background and control colors update to the new theme; the active tab keeps its Accent.

---

### Step 9 — Persistence across reopen

**Action:**
1. Set a non-default range (e.g., "Last 30 days").
2. Close the companion: `c.close()`.
3. Reopen: `c2 = FastSenseCompanion('Registry', TagRegistry);`.

**Expected:**
- The toolbar dropdown on the new companion reads **"Last 30 days"** (Accent color).
- `c2.currentTimeWindow()` returns a `[t0, t1]` span of ~30 days.
- The restored range is loaded from `companionPrefs` automatically.

---

## Sign-off

| Step | Description | Result | Notes |
|------|-------------|--------|-------|
| 1 | Default dropdown value "Last 7 days" + WidgetBorderColor background | ⬜ | |
| 2 | Dropdown lists 6 presets + "Custom…"; no separate window | ⬜ | |
| 3 | Selecting "Last 30 days" applies instantly + Accent + re-query | ⬜ | |
| 4 | Custom… → Relative: live preview; Apply closes strip + updates value | ⬜ | |
| 5A | Custom… → Absolute: start > end → Apply disabled + red error text | ⬜ | |
| 5B | Custom… → Absolute: valid range → Apply + date-string value | ⬜ | |
| 6 | Empty-state "No data in selected range" for out-of-window sensor | ⬜ | |
| 7 | Relative window slides on live tick; Absolute stays fixed | ⬜ | |
| 8 | Theme switch restyles dropdown (and open strip) | ⬜ | |
| 9 | Persistence: reopen companion restores last-used range | ⬜ | |

**Tester:** ______________________

**Date:** ______________________

**Overall result:** Pass / Fail / Partial

**Issues found:**

---

*This checklist covers the two manual-only validation targets from `1041-VALIDATION.md`:*
*1. CompanionTimeBar inline control visuals + interaction (dropdown presets / Custom relative / Custom absolute)*
*2. Relative-window slide on live tick*
