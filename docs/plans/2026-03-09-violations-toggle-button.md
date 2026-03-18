# Violations Toggle Button Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a toolbar toggle button that globally shows/hides all violation markers without changing per-threshold `ShowViolations` settings.

**Architecture:** A `ViolationsVisible` property on `FastSense` controls marker visibility. The toolbar gets a new `uitoggletool` with a `'violations'` icon. Toggling it calls `setViolationsVisible()` on each FastSense instance, which sets `Visible` on all `hMarkers` handles and gates marker computation in `render()` and `updateViolations()`.

**Tech Stack:** MATLAB (uitoggletool, graphics handle Visible property)

---

### Task 1: Add `ViolationsVisible` property and `setViolationsVisible` method to FastSense

**Files:**
- Modify: `libs/FastSense/FastSense.m:64-81` (public properties)
- Modify: `libs/FastSense/FastSense.m:828` (render gate)
- Modify: `libs/FastSense/FastSense.m:1995` (updateViolations gate)

**Step 1: Add the `ViolationsVisible` property**

In `libs/FastSense/FastSense.m`, in the public properties block (after line 80, `YScale`), add:

```matlab
        ViolationsVisible = true      % global toggle for violation markers
```

**Step 2: Add the `setViolationsVisible` public method**

In `libs/FastSense/FastSense.m`, add a new public method (in the public methods section, near other setter-style methods). Place it after the existing public methods like `addThreshold`, etc.:

```matlab
        function setViolationsVisible(obj, on)
            %SETVIOLATIONSVISIBLE Show or hide all violation markers.
            %   fp.setViolationsVisible(true)  — show markers
            %   fp.setViolationsVisible(false) — hide markers
            obj.ViolationsVisible = on;
            if on
                vis = 'on';
            else
                vis = 'off';
            end
            for t = 1:numel(obj.Thresholds)
                if ~isempty(obj.Thresholds(t).hMarkers) && ishandle(obj.Thresholds(t).hMarkers)
                    set(obj.Thresholds(t).hMarkers, 'Visible', vis);
                end
            end
        end
```

**Step 3: Gate violation marker creation in `render()`**

In `libs/FastSense/FastSense.m:828`, change:

```matlab
                if T.ShowViolations
```

to:

```matlab
                if T.ShowViolations && obj.ViolationsVisible
```

**Step 4: Gate violation marker update in `updateViolations()`**

In `libs/FastSense/FastSense.m:1984`, add an early return after the existing `ishandle` check. Before the existing dirty-flag block, insert:

```matlab
            if ~obj.ViolationsVisible
                return;
            end
```

So lines 1984+ become:

```matlab
            if ~obj.ViolationsVisible
                return;
            end
            if ~isempty(obj.Thresholds) && ishandle(obj.hAxes)
```

**Step 5: Run existing tests to verify no regression**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "run('tests/test_toolbar.m')"`
Expected: All 13 toolbar tests pass.

**Step 6: Commit**

```bash
git add libs/FastSense/FastSense.m
git commit -m "feat: add ViolationsVisible property and setViolationsVisible method to FastSense"
```

---

### Task 2: Add violations toggle button to FastSenseToolbar

**Files:**
- Modify: `libs/FastSense/FastSenseToolbar.m:48` (add handle property)
- Modify: `libs/FastSense/FastSenseToolbar.m:367-371` (createToolbar — insert before theme btn)
- Modify: `libs/FastSense/FastSenseToolbar.m:240-246` (rebind — sync state)

**Step 1: Add the `hViolationsBtn` handle property**

In `libs/FastSense/FastSenseToolbar.m`, in the private properties block, after line 48 (`hThemeBtn`), add:

```matlab
        hViolationsBtn = []    % uitoggletool handle for violations toggle
```

**Step 2: Create the toggle button in `createToolbar()`**

In `libs/FastSense/FastSenseToolbar.m`, insert after the metadata button block (after line 366) and before the theme button (line 368):

```matlab
            obj.hViolationsBtn = uitoggletool(obj.hToolbar, ...
                'CData', FastSenseToolbar.makeIcon('violations'), ...
                'TooltipString', 'Toggle Violations', ...
                'State', 'on', ...
                'OnCallback',  @(s,e) obj.onViolationsOn(), ...
                'OffCallback', @(s,e) obj.onViolationsOff());
```

**Step 3: Add the On/Off callback methods**

In `libs/FastSense/FastSenseToolbar.m`, in the private methods section (after the `onMetadataOff` method around line 392), add:

```matlab
        function onViolationsOn(obj)
            for i = 1:numel(obj.FastSenses)
                obj.FastSenses{i}.setViolationsVisible(true);
            end
        end

        function onViolationsOff(obj)
            for i = 1:numel(obj.FastSenses)
                obj.FastSenses{i}.setViolationsVisible(false);
            end
        end
```

**Step 4: Sync state in `rebind()`**

In `libs/FastSense/FastSenseToolbar.m`, after line 246 (`setappdata(obj.hFigure, 'FastSenseMetadataEnabled', obj.MetadataEnabled);`), add:

```matlab
            % Sync violations toggle to first FastSense's state
            if ~isempty(obj.FastSenses)
                if obj.FastSenses{1}.ViolationsVisible
                    set(obj.hViolationsBtn, 'State', 'on');
                else
                    set(obj.hViolationsBtn, 'State', 'off');
                end
            end
```

**Step 5: Commit**

```bash
git add libs/FastSense/FastSenseToolbar.m
git commit -m "feat: add violations toggle button to toolbar"
```

---

### Task 3: Add violations icon to `makeIcon()`

**Files:**
- Modify: `libs/FastSense/FastSenseToolbar.m:1027` (add case before `end` of switch)
- Modify: `libs/FastSense/FastSenseToolbar.m:1033-1034` (add to initIcons list)
- Modify: `libs/FastSense/FastSenseToolbar.m:880-881` (update docstring)

**Step 1: Add the `'violations'` icon case**

In `libs/FastSense/FastSenseToolbar.m`, before the `end` of the switch block (line 1027), add a new case. The icon is a small exclamation mark in a triangle (warning style), drawn in orange/red:

```matlab
                case 'violations'
                    % Exclamation triangle (warning marker)
                    warnColor = [0.9 0.4 0.1];  % orange
                    % Triangle outline: rows 3-13, centered at col 8
                    for r = 3:13
                        halfW = round((r - 3) * 5 / 10);
                        cL = 8 - halfW;
                        cR = 8 + halfW;
                        if cL >= 1 && cR <= 16
                            icon(r, cL, :) = reshape(warnColor, 1, 1, 3);
                            icon(r, cR, :) = reshape(warnColor, 1, 1, 3);
                        end
                    end
                    % Bottom edge
                    icon(13, 3:13, :) = repmat(reshape(warnColor, 1, 1, 3), 1, 11, 1);
                    % Exclamation mark stem
                    icon(6:9, 8, :) = repmat(reshape(warnColor, 1, 1, 3), 4, 1, 1);
                    % Exclamation mark dot
                    icon(11, 8, :) = reshape(warnColor, 1, 1, 3);
```

**Step 2: Add `'violations'` to initIcons list**

In `libs/FastSense/FastSenseToolbar.m:1033-1034`, change:

```matlab
            names = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', ...
                     'export', 'refresh', 'live', 'metadata', 'theme'};
```

to:

```matlab
            names = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', ...
                     'export', 'refresh', 'live', 'metadata', 'violations', 'theme'};
```

**Step 3: Update makeIcon docstring**

In `libs/FastSense/FastSenseToolbar.m:880-881`, change:

```matlab
            %   Available names: 'cursor', 'crosshair', 'grid', 'legend',
            %   'autoscale', 'export', 'refresh', 'live', 'metadata', 'theme'.
```

to:

```matlab
            %   Available names: 'cursor', 'crosshair', 'grid', 'legend',
            %   'autoscale', 'export', 'refresh', 'live', 'metadata',
            %   'violations', 'theme'.
```

**Step 4: Commit**

```bash
git add libs/FastSense/FastSenseToolbar.m
git commit -m "feat: add violations icon to makeIcon()"
```

---

### Task 4: Update toolbar button count and add toggle test

**Files:**
- Modify: `tests/test_toolbar.m:34` (update button count 10 → 11)
- Modify: `tests/test_toolbar.m:43` (add 'violations' to icon names)
- Modify: `tests/test_toolbar.m:149` (add new test before final fprintf, update count)

**Step 1: Update button count assertion**

In `tests/test_toolbar.m:34`, change:

```matlab
    assert(numel(children) == 10, ...
```

to:

```matlab
    assert(numel(children) == 11, ...
```

**Step 2: Add 'violations' to icon name test**

In `tests/test_toolbar.m:43`, change:

```matlab
    names = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', 'export'};
```

to:

```matlab
    names = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', 'export', 'violations'};
```

**Step 3: Add violations toggle test**

In `tests/test_toolbar.m`, before the final `fprintf` (line 149), add:

```matlab
    % testViolationsToggle
    fp = FastSense();
    fp.addLine(1:100, rand(1,100) * 10);
    fp.addThreshold(5, 'Direction', 'upper', 'ShowViolations', true);
    fp.render();
    tb = FastSenseToolbar(fp);
    % Violations should be visible initially
    assert(fp.ViolationsVisible, 'testViolationsToggle: default true');
    hM = fp.Thresholds(1).hMarkers;
    assert(strcmp(get(hM, 'Visible'), 'on'), 'testViolationsToggle: markers visible');
    % Toggle off via toolbar callback
    fp.setViolationsVisible(false);
    assert(~fp.ViolationsVisible, 'testViolationsToggle: now false');
    assert(strcmp(get(hM, 'Visible'), 'off'), 'testViolationsToggle: markers hidden');
    % Toggle back on
    fp.setViolationsVisible(true);
    assert(strcmp(get(hM, 'Visible'), 'on'), 'testViolationsToggle: markers back');
    close(fp.hFigure);
```

**Step 4: Update final fprintf count**

In `tests/test_toolbar.m`, change:

```matlab
    fprintf('    All 13 toolbar tests passed.\n');
```

to:

```matlab
    fprintf('    All 14 toolbar tests passed.\n');
```

**Step 5: Run all tests**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "run('tests/test_toolbar.m')"`
Expected: All 14 toolbar tests pass.

**Step 6: Commit**

```bash
git add tests/test_toolbar.m
git commit -m "test: add violations toggle test and update button count"
```

---

### Task 5: Update toolbar docstring

**Files:**
- Modify: `libs/FastSense/FastSenseToolbar.m:1-22` (classdef docstring)

**Step 1: Add Violations to the button list in the docstring**

In `libs/FastSense/FastSenseToolbar.m`, after line 20 (`%     Metadata     — show/hide metadata in data cursor tooltips`), add:

```matlab
    %     Violations   — toggle violation marker visibility
```

**Step 2: Commit**

```bash
git add libs/FastSense/FastSenseToolbar.m
git commit -m "docs: add violations button to toolbar docstring"
```
