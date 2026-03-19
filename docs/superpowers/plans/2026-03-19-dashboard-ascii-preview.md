# Dashboard ASCII Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an ASCII preview function that prints a console representation of the dashboard layout with widget content, usable before `render()`.

**Architecture:** Each widget subclass implements `asciiRender(width, height)` returning cell array of text lines. `DashboardEngine.preview()` maps grid positions to character coordinates, composites widget ASCII into a 2D buffer with box-drawing borders, and prints to console.

**Tech Stack:** MATLAB (pure, no dependencies), Unicode box-drawing characters, sparkline blocks.

**Spec:** `docs/superpowers/specs/2026-03-19-dashboard-ascii-preview-design.md`

---

### Task 1: Default `asciiRender` in DashboardWidget base class

**Files:**
- Modify: `libs/Dashboard/DashboardWidget.m:71-80`
- Test: `tests/suite/TestDashboardPreview.m` (create)

- [ ] **Step 1: Create test file with first test**

Create `tests/suite/TestDashboardPreview.m`:

```matlab
classdef TestDashboardPreview < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testBaseWidgetAsciiRender(testCase)
            % NumberWidget inherits default if not overridden yet
            w = TextWidget('Title', 'Hello');
            lines = w.asciiRender(20, 3);
            testCase.verifyEqual(numel(lines), 3);
            testCase.verifyEqual(numel(lines{1}), 20);
            testCase.verifyTrue(contains(lines{1}, 'Hello'));
        end

        function testAsciiRenderHeightZero(testCase)
            w = TextWidget('Title', 'Hello');
            lines = w.asciiRender(20, 0);
            testCase.verifyEmpty(lines);
        end
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); result = runtests('tests/suite/TestDashboardPreview'); disp(result)"`
Expected: FAIL — `No method 'asciiRender'`

- [ ] **Step 3: Implement default asciiRender in DashboardWidget**

In `libs/Dashboard/DashboardWidget.m`, add this method in the existing `methods` block (after `getTimeRange` at line 79, before the `end` at line 80):

```matlab
        function lines = asciiRender(obj, width, height)
        %ASCIIRENDER Return ASCII representation of this widget.
        %   lines = asciiRender(obj, width, height) returns a cell array
        %   of strings, each exactly WIDTH characters. HEIGHT is the
        %   available number of lines. Default implementation shows
        %   [type] Title; subclasses override for richer content.
            if height <= 0
                lines = {};
                return;
            end
            label = sprintf('[%s]', obj.getType());
            if ~isempty(obj.Title)
                label = sprintf('%s %s', label, obj.Title);
            end
            if numel(label) > width
                label = label(1:width);
            end
            label = [label, repmat(' ', 1, width - numel(label))];
            lines = cell(1, height);
            lines{1} = label;
            blank = repmat(' ', 1, width);
            for i = 2:height
                lines{i} = blank;
            end
        end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); result = runtests('tests/suite/TestDashboardPreview'); disp(result)"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardWidget.m tests/suite/TestDashboardPreview.m
git commit -m "feat(dashboard): add default asciiRender to DashboardWidget base class"
```

---

### Task 2: `DashboardEngine.preview()` compositor

**Files:**
- Modify: `libs/Dashboard/DashboardEngine.m`
- Modify: `tests/suite/TestDashboardPreview.m`

- [ ] **Step 1: Add tests for preview**

Append these tests to `TestDashboardPreview.m`:

```matlab
        function testPreviewEmpty(testCase)
            d = DashboardEngine('Empty');
            output = evalc('d.preview()');
            testCase.verifyTrue(contains(output, 'empty'));
            testCase.verifyTrue(contains(output, 'Empty'));
        end

        function testPreviewSingleWidget(testCase)
            d = DashboardEngine('Test');
            d.addWidget('text', 'Title', 'Hello', 'Position', [1 1 12 1]);
            output = evalc('d.preview()');
            testCase.verifyTrue(contains(output, 'Test'));
            testCase.verifyTrue(contains(output, 'Hello'));
        end

        function testPreviewMultiWidget(testCase)
            d = DashboardEngine('Multi');
            d.addWidget('text', 'Title', 'A', 'Position', [1 1 12 1]);
            d.addWidget('text', 'Title', 'B', 'Position', [13 1 12 1]);
            output = evalc('d.preview()');
            testCase.verifyTrue(contains(output, 'A'));
            testCase.verifyTrue(contains(output, 'B'));
        end

        function testPreviewCustomWidth(testCase)
            d = DashboardEngine('Wide');
            d.addWidget('text', 'Title', 'X', 'Position', [1 1 24 1]);
            output80 = evalc('d.preview(''Width'', 80)');
            output120 = evalc('d.preview(''Width'', 120)');
            lines80 = strsplit(output80, newline);
            lines120 = strsplit(output120, newline);
            % Wider preview should produce longer lines
            maxLen80 = max(cellfun(@numel, lines80));
            maxLen120 = max(cellfun(@numel, lines120));
            testCase.verifyGreaterThan(maxLen120, maxLen80);
        end

        function testPreviewMinWidth(testCase)
            d = DashboardEngine('Narrow');
            d.addWidget('text', 'Title', 'X', 'Position', [1 1 24 1]);
            % Width below 48 should be clamped with warning
            output = evalc('d.preview(''Width'', 20)');
            testCase.verifyTrue(~isempty(output));
        end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); result = runtests('tests/suite/TestDashboardPreview'); disp(result)"`
Expected: FAIL — `No method 'preview'` for the new tests

- [ ] **Step 3: Implement `preview()` in DashboardEngine**

Add this method to the `methods (Access = public)` block in `DashboardEngine.m`, after `exportScript` (line 181):

```matlab
        function preview(obj, varargin)
        %PREVIEW Print ASCII representation of the dashboard to console.
        %   d.preview()              % default 120 chars wide
        %   d.preview('Width', 120)  % custom width
            width = 120;
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'Width')
                    width = varargin{k+1};
                end
            end

            % Enforce minimum width
            if width < 48
                warning('DashboardEngine:previewWidth', ...
                    'Width %d too small, clamping to 48.', width);
                width = 48;
            end

            nWidgets = numel(obj.Widgets);

            % Empty dashboard
            if nWidgets == 0
                fprintf('  %s (empty -- no widgets)\n', obj.Name);
                return;
            end

            % Grid dimensions
            cols = obj.Layout.Columns;
            maxRow = 1;
            for i = 1:nWidgets
                p = obj.Widgets{i}.Position;
                bottomRow = p(2) + p(4) - 1;
                if bottomRow > maxRow
                    maxRow = bottomRow;
                end
            end

            % Character sizing
            colW = floor(width / cols);        % chars per grid column
            linesPerRow = 4;                    % lines per grid row
            bufW = cols * colW;
            bufH = maxRow * linesPerRow;

            % Create character buffer (space-filled)
            buf = repmat(' ', bufH, bufW);

            % Render each widget
            for i = 1:nWidgets
                w = obj.Widgets{i};
                p = w.Position;  % [col, row, wCols, hRows]

                % Character coordinates (1-based)
                x1 = (p(1) - 1) * colW + 1;
                y1 = (p(2) - 1) * linesPerRow + 1;
                cw = p(3) * colW;
                ch = p(4) * linesPerRow;

                % Clamp to buffer bounds
                x2 = min(x1 + cw - 1, bufW);
                y2 = min(y1 + ch - 1, bufH);
                cw = x2 - x1 + 1;
                ch = y2 - y1 + 1;

                if cw < 3 || ch < 3
                    continue;  % too small to draw
                end

                % Draw box border
                topBorder = [char(9484), repmat(char(9472), 1, cw - 2), char(9488)];
                bottomBorder = [char(9492), repmat(char(9472), 1, cw - 2), char(9496)];
                buf(y1, x1:x2) = topBorder;
                buf(y2, x1:x2) = bottomBorder;
                for row = y1+1:y2-1
                    buf(row, x1) = char(9474);      % │
                    buf(row, x2) = char(9474);      % │
                end

                % Get widget ASCII content
                innerW = cw - 4;  % 2 border chars + 2 padding spaces
                innerH = ch - 2;  % top and bottom border
                if innerW > 0 && innerH > 0
                    lines = w.asciiRender(innerW, innerH);

                    % Pad/truncate to innerH lines
                    blank = repmat(' ', 1, innerW);
                    if numel(lines) < innerH
                        for li = numel(lines)+1:innerH
                            lines{li} = blank;
                        end
                    elseif numel(lines) > innerH
                        lines = lines(1:innerH);
                    end

                    % Ensure each line is exactly innerW chars
                    for li = 1:numel(lines)
                        ln = lines{li};
                        if numel(ln) < innerW
                            ln = [ln, repmat(' ', 1, innerW - numel(ln))];
                        elseif numel(ln) > innerW
                            ln = ln(1:innerW);
                        end
                        buf(y1 + li, x1+2:x1+1+innerW) = ln;
                    end
                end
            end

            % Print header
            fprintf('\n  %s (%d widgets, %dx%d grid)\n', ...
                obj.Name, nWidgets, cols, maxRow);

            % Print buffer
            for row = 1:bufH
                fprintf('%s\n', buf(row, :));
            end
            fprintf('\n');
        end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); result = runtests('tests/suite/TestDashboardPreview'); disp(result)"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardEngine.m tests/suite/TestDashboardPreview.m
git commit -m "feat(dashboard): add preview() compositor to DashboardEngine"
```

---

### Task 3: `asciiRender` for FastSenseWidget (sparkline)

**Files:**
- Modify: `libs/Dashboard/FastSenseWidget.m`
- Modify: `tests/suite/TestDashboardPreview.m`

- [ ] **Step 1: Add tests**

Append to `TestDashboardPreview.m`:

```matlab
        function testFastSenseAsciiWithData(testCase)
            w = FastSenseWidget('Title', 'Temp', 'XData', 1:20, ...
                'YData', sin(linspace(0, 2*pi, 20)));
            lines = w.asciiRender(30, 4);
            testCase.verifyEqual(numel(lines), 4);
            testCase.verifyTrue(contains(lines{1}, 'Temp'));
        end

        function testFastSenseAsciiNoData(testCase)
            w = FastSenseWidget('Title', 'Temp');
            lines = w.asciiRender(30, 4);
            testCase.verifyTrue(contains(lines{1}, 'Temp'));
            testCase.verifyTrue(contains(lines{2}, 'fastsense'));
        end
```

- [ ] **Step 2: Run tests — expect FAIL for testFastSenseAsciiNoData (default puts placeholder on line 1, not line 2)**

- [ ] **Step 3: Implement asciiRender in FastSenseWidget**

Add this method to `FastSenseWidget.m` in the `methods` block (after `getType`):

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            % Title line
            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            % Data: sparkline or placeholder
            yData = [];
            if ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)
                yData = obj.Sensor.Y;
            elseif ~isempty(obj.YData)
                yData = obj.YData;
            end

            if ~isempty(yData) && height >= 2
                bars = char(9601):char(9608);  % ▁▂▃▄▅▆▇█
                nBars = numel(bars);
                yMin = min(yData); yMax = max(yData);
                if yMax == yMin, yMax = yMin + 1; end
                % Resample to fit width
                nPts = min(numel(yData), width);
                idx = round(linspace(1, numel(yData), nPts));
                sampled = yData(idx);
                spark = blanks(nPts);
                for si = 1:nPts
                    level = round((sampled(si) - yMin) / (yMax - yMin) * (nBars - 1)) + 1;
                    level = max(1, min(nBars, level));
                    spark(si) = bars(level);
                end
                if numel(spark) < width
                    spark = [spark, repmat(' ', 1, width - numel(spark))];
                end
                lines{2} = spark(1:width);
            elseif height >= 2
                ph = '[~~ fastsense ~~]';
                if numel(ph) > width, ph = ph(1:width); end
                lines{2} = [ph, repmat(' ', 1, width - numel(ph))];
            end
        end
```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/FastSenseWidget.m tests/suite/TestDashboardPreview.m
git commit -m "feat(dashboard): add sparkline asciiRender to FastSenseWidget"
```

---

### Task 4: `asciiRender` for NumberWidget

**Files:**
- Modify: `libs/Dashboard/NumberWidget.m`
- Modify: `tests/suite/TestDashboardPreview.m`

- [ ] **Step 1: Add tests**

```matlab
        function testNumberAsciiWithValue(testCase)
            w = NumberWidget('Title', 'Max', 'StaticValue', 72.5, 'Units', 'degC');
            lines = w.asciiRender(25, 2);
            testCase.verifyTrue(contains(lines{1}, 'Max'));
            testCase.verifyTrue(contains(lines{1}, '72.5'));
        end

        function testNumberAsciiNoData(testCase)
            w = NumberWidget('Title', 'Max');
            lines = w.asciiRender(25, 2);
            testCase.verifyTrue(contains(lines{1}, 'Max'));
            testCase.verifyTrue(contains(lines{2}, 'number'));
        end
```

- [ ] **Step 2: Run tests — verify new tests fail or use default**

- [ ] **Step 3: Implement asciiRender in NumberWidget**

Add to `NumberWidget.m` after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            % Try to get current value
            val = obj.StaticValue;
            units = obj.Units;
            if isempty(val) && ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)
                val = obj.Sensor.Y(end);
                if isempty(units) && ~isempty(obj.Sensor.Units)
                    units = obj.Sensor.Units;
                end
            end

            if ~isempty(val)
                valStr = sprintf(obj.Format, val);
                if ~isempty(units)
                    valStr = sprintf('%s %s', valStr, units);
                end
                label = sprintf('%s  %s', obj.Title, valStr);
            else
                label = obj.Title;
            end
            if numel(label) > width, label = label(1:width); end
            lines{1} = [label, repmat(' ', 1, width - numel(label))];

            if isempty(val) && height >= 2
                ph = '[-- number --]';
                if numel(ph) > width, ph = ph(1:width); end
                lines{2} = [ph, repmat(' ', 1, width - numel(ph))];
            end
        end
```

- [ ] **Step 4: Run tests**

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/NumberWidget.m tests/suite/TestDashboardPreview.m
git commit -m "feat(dashboard): add asciiRender to NumberWidget"
```

---

### Task 5: `asciiRender` for StatusWidget

**Files:**
- Modify: `libs/Dashboard/StatusWidget.m`
- Modify: `tests/suite/TestDashboardPreview.m`

- [ ] **Step 1: Add tests**

```matlab
        function testStatusAsciiWithData(testCase)
            w = StatusWidget('Title', 'Pump', 'StaticStatus', 'ok');
            lines = w.asciiRender(25, 2);
            testCase.verifyTrue(contains(lines{1}, 'Pump'));
            testCase.verifyTrue(contains(lines{1}, 'OK'));
        end

        function testStatusAsciiNoData(testCase)
            w = StatusWidget('Title', 'Pump');
            lines = w.asciiRender(25, 2);
            testCase.verifyTrue(contains(lines{1}, 'Pump'));
        end
```

- [ ] **Step 2: Run tests**

- [ ] **Step 3: Implement asciiRender in StatusWidget**

Add to `StatusWidget.m` after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            dot = char(9679);  % ●
            status = obj.StaticStatus;
            if isempty(status) && ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)
                status = 'ok';  % simplified — full derivation needs theme
                if ~isempty(obj.Sensor.ThresholdRules)
                    val = obj.Sensor.Y(end);
                    for k = 1:numel(obj.Sensor.ThresholdRules)
                        rule = obj.Sensor.ThresholdRules{k};
                        if (rule.IsUpper && val > rule.Value) || ...
                                (~rule.IsUpper && val < rule.Value)
                            status = 'violation';
                            break;
                        end
                    end
                end
            end

            if ~isempty(status)
                displayStatus = upper(status);
                if strcmp(status, 'violation'), displayStatus = 'ALARM'; end
                label = sprintf('%s %s: %s', dot, obj.Title, displayStatus);
            else
                label = sprintf('%s %s', dot, obj.Title);
            end
            if numel(label) > width, label = label(1:width); end
            lines{1} = [label, repmat(' ', 1, width - numel(label))];

            if isempty(status) && height >= 2
                ph = '[-- status --]';
                if numel(ph) > width, ph = ph(1:width); end
                lines{2} = [ph, repmat(' ', 1, width - numel(ph))];
            end
        end
```

- [ ] **Step 4: Run tests**

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/StatusWidget.m tests/suite/TestDashboardPreview.m
git commit -m "feat(dashboard): add asciiRender to StatusWidget"
```

---

### Task 6: `asciiRender` for TextWidget

**Files:**
- Modify: `libs/Dashboard/TextWidget.m`
- Modify: `tests/suite/TestDashboardPreview.m`

- [ ] **Step 1: Add tests**

```matlab
        function testTextAsciiWithContent(testCase)
            w = TextWidget('Title', 'Header', 'Content', 'Some info text');
            lines = w.asciiRender(30, 2);
            testCase.verifyTrue(contains(lines{1}, 'Header'));
            testCase.verifyTrue(contains(lines{2}, 'Some info'));
        end

        function testTextAsciiTitleOnly(testCase)
            w = TextWidget('Title', 'Section A');
            lines = w.asciiRender(20, 2);
            testCase.verifyTrue(contains(lines{1}, 'Section A'));
        end
```

- [ ] **Step 2: Run tests**

- [ ] **Step 3: Implement asciiRender in TextWidget**

Add to `TextWidget.m` after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            if ~isempty(ttl)
                lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];
            end

            if ~isempty(obj.Content) && height >= 2
                ct = obj.Content;
                if numel(ct) > width, ct = ct(1:width); end
                lines{2} = [ct, repmat(' ', 1, width - numel(ct))];
            end
        end
```

- [ ] **Step 4: Run tests**

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/TextWidget.m tests/suite/TestDashboardPreview.m
git commit -m "feat(dashboard): add asciiRender to TextWidget"
```

---

### Task 7: `asciiRender` for GaugeWidget

**Files:**
- Modify: `libs/Dashboard/GaugeWidget.m`
- Modify: `tests/suite/TestDashboardPreview.m`

- [ ] **Step 1: Add tests**

```matlab
        function testGaugeAsciiWithValue(testCase)
            w = GaugeWidget('Title', 'Pressure', 'StaticValue', 65, ...
                'Range', [0 100], 'Units', 'bar');
            lines = w.asciiRender(30, 3);
            testCase.verifyTrue(contains(lines{1}, 'Pressure'));
            testCase.verifyTrue(contains(lines{2}, '65'));
        end

        function testGaugeAsciiNoData(testCase)
            w = GaugeWidget('Title', 'Pressure');
            lines = w.asciiRender(30, 3);
            testCase.verifyTrue(contains(lines{1}, 'Pressure'));
            testCase.verifyTrue(contains(lines{2}, 'gauge'));
        end
```

- [ ] **Step 2: Run tests**

- [ ] **Step 3: Implement asciiRender in GaugeWidget**

Add to `GaugeWidget.m` after `getType` (line 80):

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            % Try to get value
            val = obj.StaticValue;
            if isempty(val) && ~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)
                val = obj.Sensor.Y(end);
            end

            if ~isempty(val) && height >= 2
                rng = obj.Range;
                frac = max(0, min(1, (val - rng(1)) / (rng(2) - rng(1))));
                barW = max(1, width - 10);
                filled = round(frac * barW);
                barStr = [char(9608)*ones(1,filled), char(9617)*ones(1,barW-filled)];
                valStr = sprintf(' %.0f%%', frac * 100);
                gauge = [barStr, valStr];
                if numel(gauge) > width, gauge = gauge(1:width); end
                if numel(gauge) < width
                    gauge = [gauge, repmat(' ', 1, width - numel(gauge))];
                end
                lines{2} = gauge;

                % Value + units on line 3
                if height >= 3
                    if ~isempty(obj.Units)
                        info = sprintf('%.1f %s  [%.0f - %.0f]', val, obj.Units, rng(1), rng(2));
                    else
                        info = sprintf('%.1f  [%.0f - %.0f]', val, rng(1), rng(2));
                    end
                    if numel(info) > width, info = info(1:width); end
                    lines{3} = [info, repmat(' ', 1, width - numel(info))];
                end
            elseif height >= 2
                ph = '[-- gauge --]';
                if numel(ph) > width, ph = ph(1:width); end
                lines{2} = [ph, repmat(' ', 1, width - numel(ph))];
            end
        end
```

- [ ] **Step 4: Run tests**

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/GaugeWidget.m tests/suite/TestDashboardPreview.m
git commit -m "feat(dashboard): add asciiRender to GaugeWidget"
```

---

### Task 8: `asciiRender` for remaining widget types

**Files:**
- Modify: `libs/Dashboard/TableWidget.m`
- Modify: `libs/Dashboard/GroupWidget.m`
- Modify: `libs/Dashboard/EventTimelineWidget.m`
- Modify: `libs/Dashboard/RawAxesWidget.m`
- Modify: `libs/Dashboard/HeatmapWidget.m`
- Modify: `libs/Dashboard/BarChartWidget.m`
- Modify: `libs/Dashboard/HistogramWidget.m`
- Modify: `libs/Dashboard/ScatterWidget.m`
- Modify: `libs/Dashboard/ImageWidget.m`
- Modify: `libs/Dashboard/MultiStatusWidget.m`
- Modify: `tests/suite/TestDashboardPreview.m`

- [ ] **Step 1: Add comprehensive test for all widget types**

Append to `TestDashboardPreview.m`:

```matlab
        function testAllWidgetTypesAsciiRender(testCase)
            % Verify every widget type produces valid output without error
            types = {
                'text',     {'Title', 'T'}
                'table',    {'Title', 'T'}
                'group',    {'Title', 'T'}
                'timeline', {'Title', 'T'}
                'rawaxes',  {'Title', 'T'}
                'heatmap',  {'Title', 'T'}
                'barchart', {'Title', 'T'}
                'histogram',{'Title', 'T'}
                'scatter',  {'Title', 'T'}
                'image',    {'Title', 'T'}
                'multistatus', {'Title', 'T'}
            };
            for k = 1:size(types, 1)
                d = DashboardEngine('Test');
                d.addWidget(types{k,1}, types{k,2}{:}, 'Position', [1 1 12 2]);
                output = evalc('d.preview(''Width'', 72)');
                testCase.verifyTrue(~isempty(output), ...
                    sprintf('Widget type %s produced empty preview', types{k,1}));
            end
        end
```

- [ ] **Step 2: Run tests — should pass with default asciiRender**

- [ ] **Step 3: Implement asciiRender for each remaining widget**

**TableWidget.m** — add after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                nCols = numel(obj.ColumnNames);
                nRows = obj.N;
                if ~isempty(obj.Data)
                    if iscell(obj.Data)
                        nRows = size(obj.Data, 1);
                    end
                end
                if nCols > 0
                    info = sprintf('%d cols x %d rows', nCols, nRows);
                else
                    info = '[-- table --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end
```

**GroupWidget.m** — add after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if isempty(ttl), ttl = obj.Label; end
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                if strcmp(obj.Mode, 'tabbed') && ~isempty(obj.Tabs)
                    info = sprintf('[group: %d tabs]', numel(obj.Tabs));
                elseif ~isempty(obj.Children)
                    info = sprintf('[group: %d children]', numel(obj.Children));
                else
                    info = '[-- group --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end
```

**EventTimelineWidget.m** — add after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                nEvents = 0;
                if ~isempty(obj.Events)
                    nEvents = numel(obj.Events);
                elseif ~isempty(obj.EventStoreObj)
                    try nEvents = numel(obj.EventStoreObj.Events); catch, end
                end
                if nEvents > 0
                    info = sprintf('%d events', nEvents);
                else
                    info = '[-- timeline --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end
```

**RawAxesWidget.m** — add after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                info = '[custom axes]';
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end
```

**HeatmapWidget.m** — add after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                nX = numel(obj.XLabels);
                nY = numel(obj.YLabels);
                if nX > 0 && nY > 0
                    info = sprintf('%dx%d heatmap', nY, nX);
                else
                    info = '[-- heatmap --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end
```

**BarChartWidget.m** — add after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                info = sprintf('[%s barchart]', obj.Orientation);
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end
```

**HistogramWidget.m** — add after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                hasData = (~isempty(obj.Sensor) && ~isempty(obj.Sensor.Y)) || ...
                          ~isempty(obj.DataFcn);
                if hasData && ~isempty(obj.Sensor)
                    info = sprintf('%d data points', numel(obj.Sensor.Y));
                else
                    info = '[-- histogram --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end
```

**ScatterWidget.m** — add after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                if ~isempty(obj.SensorX) && ~isempty(obj.SensorY) && ...
                        ~isempty(obj.SensorX.Y) && ~isempty(obj.SensorY.Y)
                    n = min(numel(obj.SensorX.Y), numel(obj.SensorY.Y));
                    info = sprintf('%d points', n);
                else
                    info = '[-- scatter --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end
```

**ImageWidget.m** — add after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if isempty(ttl), ttl = obj.Caption; end
            if numel(ttl) > width, ttl = ttl(1:width); end
            if ~isempty(ttl)
                lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];
            end

            if height >= 2
                if ~isempty(obj.File)
                    [~, fname, ext] = fileparts(obj.File);
                    info = sprintf('[img: %s%s]', fname, ext);
                else
                    info = '[-- image --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end
```

**MultiStatusWidget.m** — add after `getType`:

```matlab
        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                n = numel(obj.Sensors);
                if n > 0
                    nOk = 0;
                    for k = 1:n
                        s = obj.Sensors{k};
                        if isempty(s) || isempty(s.Y) || isempty(s.ThresholdRules)
                            nOk = nOk + 1;
                            continue;
                        end
                        val = s.Y(end);
                        violated = false;
                        for r = 1:numel(s.ThresholdRules)
                            rule = s.ThresholdRules{r};
                            if (rule.IsUpper && val > rule.Value) || ...
                                    (~rule.IsUpper && val < rule.Value)
                                violated = true;
                                break;
                            end
                        end
                        if ~violated
                            nOk = nOk + 1;
                        end
                    end
                    info = sprintf('%d sensors: %d OK, %d alert', n, nOk, n - nOk);
                else
                    info = '[-- multistatus --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end
```

- [ ] **Step 4: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); result = runtests('tests/suite/TestDashboardPreview'); disp(result)"`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/TableWidget.m libs/Dashboard/GroupWidget.m \
    libs/Dashboard/EventTimelineWidget.m libs/Dashboard/RawAxesWidget.m \
    libs/Dashboard/HeatmapWidget.m libs/Dashboard/BarChartWidget.m \
    libs/Dashboard/HistogramWidget.m libs/Dashboard/ScatterWidget.m \
    libs/Dashboard/ImageWidget.m libs/Dashboard/MultiStatusWidget.m \
    tests/suite/TestDashboardPreview.m
git commit -m "feat(dashboard): add asciiRender to all remaining widget types"
```

---

### Task 9: Integration test — full dashboard preview

**Files:**
- Modify: `tests/suite/TestDashboardPreview.m`

- [ ] **Step 1: Add integration test**

Append to `TestDashboardPreview.m`:

```matlab
        function testFullDashboardPreview(testCase)
            d = DashboardEngine('Process Monitor');
            d.addWidget('fastsense', 'Title', 'Temperature', ...
                'Position', [1 1 12 3], 'XData', 1:50, 'YData', sin(1:50));
            d.addWidget('number', 'Title', 'Max Temp', ...
                'Position', [13 1 6 1], 'StaticValue', 72.5, 'Units', 'degC');
            d.addWidget('status', 'Title', 'Pump 1', ...
                'Position', [19 1 6 1], 'StaticStatus', 'ok');
            d.addWidget('gauge', 'Title', 'Pressure', ...
                'Position', [13 2 12 2], 'StaticValue', 65, ...
                'Range', [0 100], 'Units', 'bar');
            d.addWidget('text', 'Title', 'Notes', 'Content', 'All systems go', ...
                'Position', [1 4 24 1]);

            output = evalc('d.preview()');
            testCase.verifyTrue(contains(output, 'Process Monitor'));
            testCase.verifyTrue(contains(output, 'Temperature'));
            testCase.verifyTrue(contains(output, '72.5'));
            testCase.verifyTrue(contains(output, 'Pump 1'));
            testCase.verifyTrue(contains(output, 'Pressure'));
            testCase.verifyTrue(contains(output, 'Notes'));
            testCase.verifyTrue(contains(output, '5 widgets'));
        end

        function testPreviewDoesNotRequireRender(testCase)
            % Verify preview works without calling render()
            d = DashboardEngine('Pre-Render');
            d.addWidget('fastsense', 'Title', 'T1', 'Position', [1 1 12 2]);
            d.addWidget('number', 'Title', 'V1', 'Position', [13 1 6 1]);
            testCase.verifyEmpty(d.hFigure);
            output = evalc('d.preview()');
            testCase.verifyTrue(contains(output, 'Pre-Render'));
            testCase.verifyEmpty(d.hFigure);  % No figure created
        end
```

- [ ] **Step 2: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); result = runtests('tests/suite/TestDashboardPreview'); disp(result)"`
Expected: ALL PASS

- [ ] **Step 3: Commit**

```bash
git add tests/suite/TestDashboardPreview.m
git commit -m "test(dashboard): add integration tests for preview feature"
```
