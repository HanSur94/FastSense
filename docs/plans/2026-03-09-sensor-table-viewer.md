# Sensor Table & Viewer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a console table and GUI viewer for all sensors in SensorRegistry.

**Architecture:** Two new static methods on `SensorRegistry`: `printTable()` for formatted console output, `viewer()` for a `uitable`-based GUI figure. Both iterate over the cached catalog and display key sensor properties.

**Tech Stack:** MATLAB, `fprintf` for console, `figure`/`uitable` for GUI.

---

### Task 1: Add `SensorRegistry.printTable()` — console table

**Files:**
- Modify: `libs/SensorThreshold/SensorRegistry.m:71` (add method after `list()`)
- Test: `tests/test_sensor_registry.m`

**Step 1: Write the failing test**

Add to `tests/test_sensor_registry.m`, before the final `fprintf` success line:

```matlab
    % testPrintTable — should not error
    SensorRegistry.printTable();
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "run('tests/test_sensor_registry.m')"`
Expected: FAIL — `Unrecognized method 'printTable'`

**Step 3: Implement `printTable()`**

Add this static method to `SensorRegistry.m` after the `list()` method (before `end` of `methods (Static)` block at line 91):

```matlab
        function printTable()
            %PRINTTABLE Print a detailed table of all registered sensors.
            %   SensorRegistry.printTable() prints a formatted table with
            %   columns: Key, Name, ID, Source, MatFile, #States, #Rules, #Points.

            map = SensorRegistry.catalog();
            keys = sort(map.keys());
            nSensors = numel(keys);

            if nSensors == 0
                fprintf('No sensors registered.\n');
                return;
            end

            % Header
            fprintf('\n');
            fprintf('  %-20s %-25s %6s  %-20s %-20s %7s %6s %8s\n', ...
                'Key', 'Name', 'ID', 'Source', 'MatFile', '#States', '#Rules', '#Points');
            fprintf('  %s\n', repmat('-', 1, 118));

            % Rows
            for i = 1:nSensors
                s = map(keys{i});
                name = s.Name;
                if isempty(name); name = ''; end

                idStr = '';
                if ~isempty(s.ID); idStr = num2str(s.ID); end

                nStates = numel(s.StateChannels);
                nRules  = numel(s.ThresholdRules);
                nPts    = numel(s.X);

                fprintf('  %-20s %-25s %6s  %-20s %-20s %7d %6d %8d\n', ...
                    truncStr(keys{i}, 20), ...
                    truncStr(name, 25), ...
                    idStr, ...
                    truncStr(s.Source, 20), ...
                    truncStr(s.MatFile, 20), ...
                    nStates, nRules, nPts);
            end
            fprintf('\n  %d sensor(s) total.\n\n', nSensors);
        end
```

Also add the `truncStr` helper as a private static method. Add a new `methods (Static, Access = private)` helper section right before the existing `methods (Static, Access = private)` block that contains `catalog()` — or just add it inside that block:

Actually, since `truncStr` is a simple local function, and MATLAB classdef files don't support local functions, add it as a private static method inside the existing private static methods block (alongside `catalog()`):

```matlab
        function s = truncStr(s, maxLen)
            if numel(s) > maxLen
                s = [s(1:maxLen-2), '..'];
            end
        end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "run('tests/test_sensor_registry.m')"`
Expected: PASS — table prints, no errors

**Step 5: Commit**

```bash
git add libs/SensorThreshold/SensorRegistry.m tests/test_sensor_registry.m
git commit -m "feat: add SensorRegistry.printTable() console table"
```

---

### Task 2: Add `SensorRegistry.viewer()` — GUI figure

**Files:**
- Modify: `libs/SensorThreshold/SensorRegistry.m` (add method in `methods (Static)` block)
- Test: `tests/test_sensor_registry.m`

**Step 1: Write the failing test**

Add to `tests/test_sensor_registry.m`:

```matlab
    % testViewer — should open and close without error
    hFig = SensorRegistry.viewer();
    assert(ishandle(hFig), 'testViewer: returns figure handle');
    close(hFig);
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "run('tests/test_sensor_registry.m')"`
Expected: FAIL — `Unrecognized method 'viewer'`

**Step 3: Implement `viewer()`**

Add this static method to `SensorRegistry.m` in the public static methods block:

```matlab
        function hFig = viewer()
            %VIEWER Open a GUI figure showing all registered sensors.
            %   hFig = SensorRegistry.viewer() creates a figure with a
            %   uitable listing every sensor's Key, Name, ID, Source,
            %   MatFile, #States, #Rules, and #Points.

            map = SensorRegistry.catalog();
            keys = sort(map.keys());
            nSensors = numel(keys);

            % Build table data
            colNames = {'Key', 'Name', 'ID', 'Source', 'MatFile', '#States', '#Rules', '#Points'};
            data = cell(nSensors, numel(colNames));
            for i = 1:nSensors
                s = map(keys{i});
                data{i,1} = keys{i};
                data{i,2} = s.Name;
                if isempty(s.ID)
                    data{i,3} = '';
                else
                    data{i,3} = s.ID;
                end
                data{i,4} = s.Source;
                data{i,5} = s.MatFile;
                data{i,6} = numel(s.StateChannels);
                data{i,7} = numel(s.ThresholdRules);
                data{i,8} = numel(s.X);
            end

            % Create figure
            hFig = figure('Name', 'Sensor Registry', ...
                'NumberTitle', 'off', ...
                'Position', [200 200 900 400], ...
                'Color', [0.15 0.15 0.18], ...
                'MenuBar', 'none', ...
                'ToolBar', 'none');

            % Title label
            uicontrol('Parent', hFig, 'Style', 'text', ...
                'String', sprintf('Sensor Registry  (%d sensors)', nSensors), ...
                'Units', 'normalized', 'Position', [0.02 0.92 0.96 0.06], ...
                'BackgroundColor', [0.15 0.15 0.18], ...
                'ForegroundColor', [0.9 0.9 0.9], ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left');

            % Table
            colWidths = {140, 180, 50, 140, 140, 55, 50, 60};
            uitable('Parent', hFig, ...
                'Data', data, ...
                'ColumnName', colNames, ...
                'ColumnWidth', colWidths, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.96 0.88], ...
                'RowName', [], ...
                'BackgroundColor', [0.22 0.22 0.25; 0.18 0.18 0.21], ...
                'ForegroundColor', [0.9 0.9 0.9], ...
                'FontSize', 11);
        end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "run('tests/test_sensor_registry.m')"`
Expected: PASS — figure opens and closes cleanly

**Step 5: Commit**

```bash
git add libs/SensorThreshold/SensorRegistry.m tests/test_sensor_registry.m
git commit -m "feat: add SensorRegistry.viewer() GUI table"
```
