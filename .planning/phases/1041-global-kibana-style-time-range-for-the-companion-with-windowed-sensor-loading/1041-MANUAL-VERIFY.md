# Manual Verification: Phase 1041 — Global Time Range for FastSenseCompanion

**Purpose:** Verify behaviors that cannot be asserted headlessly — picker visual rendering,
one-click preset interaction, relative-slide on live ticks, empty-state widget display,
persistence across sessions, and theme restyle.

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

### Step 1 — Default range button label and color

**Action:** Inspect the companion toolbar after it opens.

**Expected:**
- The range button (positioned to the left of the gear) reads **"Last 7 days"**.
- The button background matches the inactive (WidgetBorderColor) toolbar style — same
  as the Tile, Wiki, and Events buttons. No Accent highlight (no filter is set yet).

---

### Step 2 — Picker opens; three tabs visible; Quick tab active

**Action:** Click the "Last 7 days" toolbar button.

**Expected:**
- A 400 × 280 px popup titled **"Time Range"** opens near the companion window.
- Three tabs are visible in the top strip: **Quick**, **Relative**, **Absolute**.
- **Quick** tab is active (Accent background on the Quick tab button).
- The Quick panel shows six preset buttons:
  "Last 24 hours", "Last 7 days", "Last 30 days", "Last 90 days", "Last 1 year", "All data".
- The **"Last 7 days"** preset button is highlighted (Accent background) because it
  matches the current spec.
- The Apply button row is **hidden** in Quick mode (Cancel is visible).
- Clicking anywhere outside the popup does NOT close it (non-modal).

---

### Step 3 — One-click quick apply + label update + re-query

**Action:** With the picker open (from Step 2), click **"Last 30 days"**.

**Expected:**
- Popup **closes immediately** (no separate Apply needed).
- Toolbar button text changes to **"Last 30 days"**.
- Toolbar button background changes to the **Accent color** (visual signal that a filter
  is active — non-default range).
- Any open dashboard or ad-hoc plot **re-queries** its data to the last 30 days. For a
  disk-backed sensor this is visible as fewer points loading; for an in-RAM tag the line
  updates to the 30-day slice.

---

### Step 4 — Relative builder tab: live preview + Apply

**Action:** Click the "Last 30 days" toolbar button to reopen the picker. Click the
**Relative** tab.

**Expected:**
- The Relative panel becomes visible: a spinner (N), a unit dropdown, "Last … until now" labels.
- Default values reflect the current spec (N = 30, unit = days).
- Change the spinner to **14** and the dropdown to **weeks**.
- A preview label below the controls updates live: it shows a date range
  approximately `YYYY-MM-DD to YYYY-MM-DD` spanning 98 days from today.
- Click **Apply**.

**After Apply:**
- Popup closes.
- Toolbar button reads **"Last 14 weeks"**.
- Open views re-query to the 98-day window.

---

### Step 5 — Absolute tab: validation + Apply

**Action:** Reopen the picker; click the **Absolute** tab.

**Expected:**
- Two date pickers (Start, End) with default values (today − 7 days, today).

**Sub-step A — Validation:**
- Set the Start date picker to today's date.
- Set the End date picker to yesterday's date (Start > End).
- The **Apply button is disabled** and the preview label shows
  **"Invalid: start must be before end"** in red (StatusAlarmColor).

**Sub-step B — Valid absolute range:**
- Fix the End date to tomorrow's date.
- Preview label shows **"1 days"** (or "2 days" depending on clock).
- Apply is enabled; click **Apply**.
- Popup closes; toolbar button reads a date string e.g. **"2026-06-02 to 2026-06-04"**.
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
- The toolbar button still shows the active range (Accent color).

---

### Step 7 — Relative-window slide on live tick (requires a live-to-today sensor)

**Action:** Ensure the active range is **"Last 7 days"** (click the button, pick the preset
if needed). Open a live-to-today sensor (e.g., `s2` which spans from 2025 to today).
Click **Live** to start live mode.

Let at least 3 live ticks elapse (default: 1 second per tick).

**Expected for relative range:**
- The right edge of the data window slides with wall-clock "now" — new tail samples
  appear on every tick WITHOUT a popup re-open or full figure rerender flicker.
- The toolbar button label remains **"Last 7 days"** (it does not add a timestamp or change).

**Expected for absolute range (regression):**
- Change the range to an Absolute window (e.g., yesterday to today). Live ticks
  continue but the window is **fixed** — the left edge does NOT slide.

---

### Step 8 — Theme restyle of the range button and popup

**Action:** With the picker popup closed, open the companion Settings dialog (gear button).
Switch the theme (e.g., from dark to light). Close the settings dialog.

**Expected:**
- The range button restyles to the new theme (FontColor + BackgroundColor match the new
  theme's ToolbarFontColor / WidgetBorderColor or Accent as appropriate).

**Bonus (if popup is open):**
- Reopen the picker popup; switch the theme while it is visible. The popup's background
  and control colors update to the new theme.

---

### Step 9 — Persistence across reopen

**Action:**
1. Set a non-default range (e.g., "Last 30 days").
2. Close the companion: `c.close()`.
3. Reopen: `c2 = FastSenseCompanion('Registry', TagRegistry);`.

**Expected:**
- The toolbar button on the new companion reads **"Last 30 days"** (Accent color).
- `c2.currentTimeWindow()` returns a `[t0, t1]` span of ~30 days.
- The restored range is loaded from `companionPrefs` automatically.

---

## Sign-off

| Step | Description | Result | Notes |
|------|-------------|--------|-------|
| 1 | Default label "Last 7 days" + WidgetBorderColor background | ⬜ | |
| 2 | Picker 400x280, 3 tabs, Quick active, presets listed, Cancel visible | ⬜ | |
| 3 | One-click "Last 30 days" closes popup + Accent + re-query | ⬜ | |
| 4 | Relative tab: live preview updates; Apply closes + updates label | ⬜ | |
| 5A | Absolute: start > end → Apply disabled + red error text | ⬜ | |
| 5B | Absolute: valid range → Apply + date-string label | ⬜ | |
| 6 | Empty-state "No data in selected range" for out-of-window sensor | ⬜ | |
| 7 | Relative window slides on live tick; Absolute stays fixed | ⬜ | |
| 8 | Theme switch restyles button (and popup if open) | ⬜ | |
| 9 | Persistence: reopen companion restores last-used range | ⬜ | |

**Tester:** ______________________

**Date:** ______________________

**Overall result:** Pass / Fail / Partial

**Issues found:**

---

*This checklist covers the two manual-only validation targets from `1041-VALIDATION.md`:*
*1. CompanionTimeBar picker visuals + popup interaction (presets / relative / absolute)*
*2. Relative-window slide on live tick*
