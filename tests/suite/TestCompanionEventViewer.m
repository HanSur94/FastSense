classdef TestCompanionEventViewer < matlab.unittest.TestCase
%TESTCOMPANIONEVENTVIEWER Class-based tests for CompanionEventViewer.
%   See docs/superpowers/specs/2026-05-08-companion-event-viewer-design.md.

    methods (TestClassSetup)
        function gateModernMatlab(testCase)
            testCase.assumeTrue(~verLessThan('matlab', '9.10'), ...
                'Companion suite requires MATLAB R2021a+');
        end
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function skipOnOctave(testCase)
            testCase.assumeFalse( ...
                exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestCompanionEventViewer: skipped on Octave (companion is MATLAB-only).');
        end
    end

    methods (Test)
        function testConstructorRequiresEventStore(testCase)
            testCase.verifyError( ...
                @() CompanionEventViewer([], TagRegistry, makeFakeCompanion_()), ...
                'CompanionEventViewer:invalidStore');
        end

        function testConstructorRequiresRegistry(testCase)
            es = makeStore_(testCase);
            testCase.verifyError( ...
                @() CompanionEventViewer(es, [], makeFakeCompanion_()), ...
                'CompanionEventViewer:invalidRegistry');
        end

        function testConstructorRequiresCompanion(testCase)
            es = makeStore_(testCase);
            testCase.verifyError( ...
                @() CompanionEventViewer(es, TagRegistry, []), ...
                'CompanionEventViewer:invalidCompanion');
        end

        function testConstructorOpensFigure(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            testCase.verifyTrue(isgraphics(v.hFigure));
        end

        function testCloseIsIdempotent(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            v.close();
            testCase.verifyWarningFree(@() v.close(), ...
                'close() must be idempotent.');
        end

        function testCloseDeletesFigure(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            f = v.hFigure;
            v.close();
            testCase.verifyFalse(isgraphics(f), 'figure must be destroyed.');
        end

        function testBringToFrontIdempotent(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            testCase.verifyWarningFree(@() v.bringToFront());
            testCase.verifyTrue(isgraphics(v.hFigure));
        end

        function testLeftPaneWidthDefaults260(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            testCase.verifyEqual(v.LeftPaneWidth, 260);
        end

        % --- Task 7: applyFilters tests ---

        function testFilterEmptyTagKeysMeansAll(testCase)
            evs = makeEvents_();
            out = CompanionEventViewer.applyFilters(evs, {}, [true true true], false, [-Inf Inf]);
            testCase.verifyEqual(numel(out), numel(evs));
        end

        function testFilterByTagKeys(testCase)
            evs = makeEvents_();
            out = CompanionEventViewer.applyFilters(evs, {'tA'}, [true true true], false, [-Inf Inf]);
            testCase.verifyTrue(all(arrayfun(@(e) any(strcmp(e.TagKeys, 'tA')), out)));
        end

        function testFilterBySeverity(testCase)
            evs = makeEvents_();   % evs has severities 1, 2, 3
            out = CompanionEventViewer.applyFilters(evs, {}, [false true false], false, [-Inf Inf]);
            testCase.verifyTrue(all(arrayfun(@(e) e.Severity == 2, out)));
        end

        function testFilterOpenOnly(testCase)
            evs = makeEvents_();   % evs(end) has IsOpen=true
            out = CompanionEventViewer.applyFilters(evs, {}, [true true true], true, [-Inf Inf]);
            testCase.verifyTrue(all(arrayfun(@(e) e.IsOpen, out)));
            testCase.verifyTrue(numel(out) >= 1);
        end

        function testFilterByTimeRange(testCase)
            evs = makeEvents_();   % evs(1)=[0,1], evs(2)=[10,11], evs(3)=[20,21], evs(4) open at [30,NaN]
            out = CompanionEventViewer.applyFilters(evs, {}, [true true true], false, [9 12]);
            testCase.verifyEqual(numel(out), 1, 'only the [10,11] event overlaps [9,12].');
            testCase.verifyEqual(out(1).StartTime, 10);
        end

        function testFilterTimeRangeIncludesOpenEvents(testCase)
            evs = makeEvents_();
            out = CompanionEventViewer.applyFilters(evs, {}, [true true true], false, [29 99]);
            testCase.verifyTrue(any(arrayfun(@(e) e.IsOpen, out)), ...
                'Open event with EndTime=NaN must overlap any range that starts after its StartTime.');
        end

        % --- Task 8: preset + setTimeRange tests ---

        function testApplyPresetSnapshotWhenNotLive(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            comp.stopLiveMode();    % ensure not live
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.applyPreset_internalForTest('1h');
            testCase.verifyEqual(v.TimePresetMode, 'snapshot');
            testCase.verifyEqual(v.TimeRange(2) - v.TimeRange(1), 1/24, 'AbsTol', 1e-6);
        end

        function testApplyPresetRollWhenLive(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            if ~comp.IsLive; comp.startLiveMode(); end
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.applyPreset_internalForTest('24h');
            testCase.verifyEqual(v.TimePresetMode, 'roll');
            testCase.verifyEqual(v.TimeRange(2) - v.TimeRange(1), 1, 'AbsTol', 1e-6);
        end

        function testSetTimeRangeSwitchesModeToCustom(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.setTimeRange(100, 200);
            testCase.verifyEqual(v.TimePresetMode, 'custom');
            testCase.verifyEqual(v.TimeRange, [100 200]);
        end

        function testSetTimeRangeRejectsInverted(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            testCase.verifyError(@() v.setTimeRange(5, 5), 'CompanionEventViewer:invalidTimeRange');
            testCase.verifyError(@() v.setTimeRange(10, 5), 'CompanionEventViewer:invalidTimeRange');
        end

        % --- Task 9: refresh() tests ---

        function testRefreshDrawsBarsForStoreEvents(testCase)
            es = makeStore_(testCase);
            e1 = Event(0,  1,  'sA', 'lbl', 1, 'upper'); e1.TagKeys = {'tA'}; e1.Severity = 1;
            e2 = Event(10, 11, 'sB', 'lbl', 1, 'upper'); e2.TagKeys = {'tB'}; e2.Severity = 2;
            es.append([e1 e2]);

            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.setTimeRange(-1, 100);   % wide window
            v.refresh();

            canvas = v.getCanvasForTest_();
            testCase.verifyEqual(numel(canvas.BarHandles), 2);
        end

        function testRefreshPicksUpAppendedEvents(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.setTimeRange(-1, 100);
            v.refresh();
            canvas = v.getCanvasForTest_();
            testCase.verifyEqual(numel(canvas.BarHandles), 0);

            e1 = Event(0, 1, 'sA', 'lbl', 1, 'upper'); e1.TagKeys = {'tA'};
            es.append(e1);
            v.refresh();
            testCase.verifyEqual(numel(canvas.BarHandles), 1);
        end

        % --- Task 10: live-mode coupling + auto-refresh timer tests ---

        function testViewerStartsTimerWhenCompanionGoesLive(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            comp.stopLiveMode();
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            testCase.verifyFalse(v.isAutoTimerRunning_(), 'Initially: not running.');

            comp.startLiveMode();
            testCase.verifyTrue(v.isAutoTimerRunning_(), 'Live ON must start timer.');

            comp.stopLiveMode();
            testCase.verifyFalse(v.isAutoTimerRunning_(), 'Live OFF must stop timer.');
        end

        function testViewerSnapshotPresetWhenCompanionLiveOff(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            if ~comp.IsLive; comp.startLiveMode(); end
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.applyPreset_internalForTest('1h');
            testCase.verifyEqual(v.TimePresetMode, 'roll');

            comp.stopLiveMode();
            testCase.verifyEqual(v.TimePresetMode, 'snapshot', ...
                'Companion live OFF must demote roll → snapshot.');
        end

        function testCloseRemovesLiveListenerAndTimer(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            if ~comp.IsLive; comp.startLiveMode(); end
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.verifyTrue(v.isAutoTimerRunning_());
            v.close();

            % After close, toggling companion must not error or re-create state.
            comp.stopLiveMode();
            comp.startLiveMode();
            t = v.getAutoTimerForTest_();
            testCase.verifyFalse(~isempty(t) && isvalid(t) && strcmp(t.Running, 'on'), ...
                'Closed viewer must not re-arm its timer.');
        end

        % --- Task 11: filter bar UI + TimeRangeSelector slider tests ---

        function testPresetButtonsExist(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            btns = findall(v.hFigure, 'Tag', 'PresetBtn');
            testCase.verifyEqual(numel(btns), 4);
            presetTexts = arrayfun(@(b) b.Text, btns, 'UniformOutput', false);
            testCase.verifyEqual(sort(presetTexts), {'1h'; '24h'; '7d'; 'All'});
        end

        function testTagSearchFieldIsRemoved(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            hits = findall(v.hFigure, 'Tag', 'TagSearch');
            testCase.verifyEmpty(hits, ...
                'TagSearch field removed — TagCatalogPane supersedes it.');
        end

        function testFromToDateTimePickersExist(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            fromCtl = findall(v.hFigure, 'Tag', 'FromEdit');
            toCtl   = findall(v.hFigure, 'Tag', 'ToEdit');
            testCase.verifyNotEmpty(fromCtl);
            testCase.verifyNotEmpty(toCtl);
        end

        function testSliderInstantiated(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            testCase.verifyClass(v.getSliderForTest_(), 'TimeRangeSelector');
        end

        function testSliderRangeChangedSetsCustomMode(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            comp.stopLiveMode();    % ensure not live so preset yields 'snapshot'
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.applyPreset_internalForTest('1h');
            testCase.verifyEqual(v.TimePresetMode, 'snapshot');

            % Simulate slider drag via the public callback path.
            v.onSliderRangeChanged_internalForTest(now - 0.5, now);
            testCase.verifyEqual(v.TimePresetMode, 'custom');
        end

        % --- Task 4: root uigridlayout layout tests ---

        function testRootLayoutIs1x2WithLeftAndRightColumns(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            grids = findall(v.hFigure, 'Type', 'uigridlayout');
            testCase.verifyGreaterThanOrEqual(numel(grids), 1, ...
                'Expected at least one uigridlayout (root).');
            % Find the one whose Parent is the figure itself.
            isRoot = arrayfun(@(g) isequal(g.Parent, v.hFigure), grids);
            root = grids(isRoot);
            testCase.verifyEqual(numel(root), 1, 'Exactly one root uigridlayout.');
            testCase.verifyEqual(numel(root.ColumnWidth), 2, ...
                'Root grid must be 1x2.');
            testCase.verifyEqual(root.ColumnWidth{1}, 260, ...
                'Left column must default to LeftPaneWidth (260).');
        end

        % --- Task 5: catalog pane wiring tests ---

        function testCatalogPaneIsAttached(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            pane = v.getCatalogPaneForTest_();
            testCase.verifyClass(pane, 'TagCatalogPane');
        end

        function testCatalogSelectionPushesIntoSelectedTagKeys(testCase)
            % Register one tag so the catalog has something to select.
            TagRegistry.clear();
            testCase.addTeardown(@() TagRegistry.clear());
            TagRegistry.register('sX', SensorTag('sX', 'Name', 'X', 'Units', 'u', ...
                'X', 0:3, 'Y', [1 2 3 4]));

            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());

            % Drive a real selection by calling the test injection helper
            % (bypasses the listbox UI but exercises the same SelectedTagKeys
            % update + refresh path the catalog event handler runs).
            v.injectCatalogSelectionForTest_({'sX'});
            testCase.verifyEqual(v.SelectedTagKeys, {'sX'});
        end

        % --- Task 7: LeftPaneWidth setter tests ---

        function testLeftPaneWidthSetterPropagatesToGrid(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.LeftPaneWidth = 320;
            grids = findall(v.hFigure, 'Type', 'uigridlayout');
            isRoot = arrayfun(@(g) isequal(g.Parent, v.hFigure), grids);
            root = grids(isRoot);
            testCase.verifyEqual(root.ColumnWidth{1}, 320);
        end

        function testLeftPaneWidthRejectsBadValues(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            testCase.verifyError(@() setLeftPaneWidth_(v, -1),  'CompanionEventViewer:invalidLeftPaneWidth');
            testCase.verifyError(@() setLeftPaneWidth_(v, NaN), 'CompanionEventViewer:invalidLeftPaneWidth');
            testCase.verifyError(@() setLeftPaneWidth_(v, 'x'), 'CompanionEventViewer:invalidLeftPaneWidth');
            testCase.verifyError(@() setLeftPaneWidth_(v, 50),  'CompanionEventViewer:invalidLeftPaneWidth');
        end

        % --- Task 12: single-click details popup + double-click drill-down tests ---

        function testSingleClickInvokesDetailsHandler(testCase)
            es = makeStore_(testCase);
            e = Event(0, 1, 'sA', 'lbl', 1, 'upper'); e.TagKeys = {'tA'}; e.Severity = 1;
            es.append(e);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.setTimeRange(-1, 100);
            v.refresh();

            captured = LiveModeCapture();
            v.setSingleClickHandlerForTest_(@(ev) captured.push(true));
            v.fireBarClickForTest_(1, 'normal');
            testCase.verifyTrue(any(captured.Vals));
        end

        function testDoubleClickOpensSensorDetailPlot(testCase)
            TagRegistry.clear();
            testCase.addTeardown(@() TagRegistry.clear());
            parent = SensorTag('sA', 'Name', 'A', 'Units', 'u', ...
                'X', 0:5, 'Y', [1 2 3 2 1 2]);
            TagRegistry.register('sA', parent);

            es = makeStore_(testCase);
            e = Event(0, 1, 'sA', 'lbl', 1, 'upper'); e.TagKeys = {'sA'}; e.Severity = 1;
            es.append(e);

            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.setTimeRange(-1, 100); v.refresh();

            captured = LiveModeCapture();
            v.setDoubleClickHandlerForTest_(@(ev) captured.push(true));
            v.fireBarClickForTest_(1, 'open');
            testCase.verifyTrue(any(captured.Vals));
        end

        function testSingleClickOpensInfoModal(testCase)
            es = makeStore_(testCase);
            e = Event(0, 1, 'sA', 'lbl', 1, 'upper'); e.TagKeys = {'tA'}; e.Severity = 1;
            es.append(e);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.setTimeRange(-1, 100);
            v.refresh();

            % Drive the real single-click path (no stub).
            v.fireBarClickForTest_(1, 'normal');

            % The single-click path is debounced via a 300 ms timer (so a
            % follow-up double-click can cancel it). Wait for the modal to
            % appear up to 3 s, calling drawnow inside the loop so the
            % timer's TimerFcn (which creates the uifigure) actually runs.
            t0 = tic;
            infoFig = [];
            while toc(t0) < 3.0
                drawnow;
                allFigs = findall(groot, 'Type', 'figure');
                names   = arrayfun(@(f) get(f, 'Name'), allFigs, 'UniformOutput', false);
                isInfo  = cellfun(@(n) startsWith(n, 'Event Info'), names);
                infoFig = allFigs(isInfo);
                if ~isempty(infoFig); break; end
                pause(0.05);
            end
            testCase.verifyNotEmpty(infoFig, 'Single-click must open an Event Info modal.');
            testCase.addTeardown(@() arrayfun(@(f) close(f, 'force'), infoFig));

            % The Notes textarea should be present and of the right class.
            notes = findall(infoFig(1), 'Tag', 'EventInfoNotes');
            testCase.verifyNotEmpty(notes);
            testCase.verifyClass(notes, 'matlab.ui.control.TextArea');
        end

        function testDoubleClickOpensDashboardEngine(testCase)
            % Register the tag so resolution succeeds.
            TagRegistry.clear();
            testCase.addTeardown(@() TagRegistry.clear());
            parent = SensorTag('sA', 'Name', 'A', 'Units', 'u', ...
                'X', 0:5, 'Y', [1 2 3 2 1 2]);
            TagRegistry.register('sA', parent);

            es = makeStore_(testCase);
            e = Event(0, 1, 'sA', 'lbl', 1, 'upper'); e.TagKeys = {'sA'}; e.Severity = 1;
            es.append(e);

            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.setTimeRange(-1, 100);
            v.refresh();

            allFigsBefore = findall(groot, 'Type', 'figure');
            v.fireBarClickForTest_(1, 'open');   % 'open' selection = double click
            allFigsAfter = findall(groot, 'Type', 'figure');

            % At least one new figure should appear (the dashboard's hFigure).
            testCase.verifyGreaterThan(numel(allFigsAfter), numel(allFigsBefore), ...
                'Double-click must spawn a new figure (the DashboardEngine).');
            % Clean up any new figures.
            newFigs = setdiff(allFigsAfter, allFigsBefore);
            testCase.addTeardown(@() arrayfun(@(f) close(f, 'force'), newFigs));
        end

        % --- ViewMode toggle tests ---

        function testViewModeDefaultsToGantt(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            testCase.verifyEqual(v.ViewMode, 'gantt');
        end

        function testViewModeSetterTogglesPanels(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            ax = v.getAxesPanelForTest_();
            tp = v.getTablePanelForTest_();
            testCase.verifyTrue(strcmp(char(ax.Visible), 'on'),  'AxesPanel initially on.');
            testCase.verifyTrue(strcmp(char(tp.Visible), 'off'), 'TablePanel initially off.');
            v.ViewMode = 'table';
            testCase.verifyTrue(strcmp(char(ax.Visible), 'off'), 'AxesPanel off in table mode.');
            testCase.verifyTrue(strcmp(char(tp.Visible), 'on'),  'TablePanel on in table mode.');
            v.ViewMode = 'gantt';
            testCase.verifyTrue(strcmp(char(ax.Visible), 'on'),  'AxesPanel on after gantt restore.');
            testCase.verifyTrue(strcmp(char(tp.Visible), 'off'), 'TablePanel off after gantt restore.');
        end

        function testViewModeRejectsInvalidValue(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            testCase.verifyError(@() setViewMode_(v, 'pie'), ...
                'CompanionEventViewer:invalidViewMode');
        end

        function testTableHasExpectedColumns(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            t = v.getTableForTest_();
            testCase.verifyClass(t, 'matlab.ui.control.Table');
            testCase.verifyEqual(t.ColumnName, ...
                {'Start'; 'End'; 'Sensor'; 'Threshold'; 'Severity'; 'Duration'; 'Open'; 'Notes'});
        end

        function testTableRowsMatchFilteredEvents(testCase)
            es = makeStore_(testCase);
            e1 = Event(0,  1,  'sA', 'lbl', 1, 'upper'); e1.TagKeys = {'tA'}; e1.Severity = 1;
            e2 = Event(10, 11, 'sB', 'lbl', 1, 'upper'); e2.TagKeys = {'tB'}; e2.Severity = 2;
            es.append([e1 e2]);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.setTimeRange(-1, 100);
            v.refresh();
            t = v.getTableForTest_();
            testCase.verifyEqual(size(t.Data, 1), 2, ...
                'Table should have one row per filtered event.');
            testCase.verifyEqual(size(t.Data, 2), 8, ...
                'Table should have 8 columns.');
        end

        function testTablePopulatesWithManyEvents(testCase)
            es = makeStore_(testCase);
            evs = Event.empty;
            for k = 1:12
                e = Event(k, k + 0.5, sprintf('s%d', mod(k, 3)+1), 'lbl', 1, 'upper');
                e.TagKeys = {sprintf('t%d', mod(k, 3)+1)};
                e.Severity = mod(k, 3) + 1;
                evs(end+1) = e; %#ok<AGROW>
            end
            es.append(evs);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            % Viewer defaults to 'All' on construction; refresh fills the table.
            v.refresh();
            t = v.getTableForTest_();
            testCase.verifyEqual(size(t.Data, 1), 12);
            % And the canvas should have 12 bars too.
            canvas = v.getCanvasForTest_();
            testCase.verifyEqual(numel(canvas.BarHandles), 12);
        end

        function testDefaultsToAllPreset(testCase)
            es = makeStore_(testCase);
            % Append events so 'all' has something to span.
            e1 = Event(0,  1,  'sA', 'lbl', 1, 'upper'); e1.TagKeys = {'tA'}; e1.Severity = 1;
            e2 = Event(10, 11, 'sB', 'lbl', 1, 'upper'); e2.TagKeys = {'tB'}; e2.Severity = 2;
            es.append([e1 e2]);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            % After construction, TimeRange must span >= the [0, 11] event extent.
            testCase.verifyLessThanOrEqual(v.TimeRange(1), 0);
            testCase.verifyGreaterThanOrEqual(v.TimeRange(2), 11);
        end

        % --- Slider readout label tests ---

        function testSliderReadoutsUpdateAfterPreset(testCase)
            es = makeStore_(testCase);
            % Append events so 'all' has a real span.
            e1 = Event(0,  1,  'sA', 'lbl', 1, 'upper'); e1.TagKeys = {'tA'}; e1.Severity = 1;
            e2 = Event(10, 11, 'sB', 'lbl', 1, 'upper'); e2.TagKeys = {'tB'}; e2.Severity = 2;
            es.append([e1 e2]);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            % Constructor applies 'all' preset, which calls updateSliderReadouts_.
            startLbl = findall(v.hFigure, 'Tag', 'SliderReadoutStart');
            endLbl   = findall(v.hFigure, 'Tag', 'SliderReadoutEnd');
            spanLbl  = findall(v.hFigure, 'Tag', 'SliderReadoutSpan');
            testCase.verifyNotEmpty(startLbl);
            testCase.verifyNotEmpty(endLbl);
            testCase.verifyNotEmpty(spanLbl);
            % Labels must be populated, not the placeholder dash.
            testCase.verifyNotEqual(startLbl.Text, char(8212));
            testCase.verifyNotEqual(endLbl.Text,   char(8212));
            testCase.verifyNotEqual(spanLbl.Text,  char(8212));
        end

        function testSliderReadoutsUpdateAfterSetTimeRange(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.setTimeRange(100, 200);
            startLbl = findall(v.hFigure, 'Tag', 'SliderReadoutStart');
            endLbl   = findall(v.hFigure, 'Tag', 'SliderReadoutEnd');
            spanLbl  = findall(v.hFigure, 'Tag', 'SliderReadoutSpan');
            % Span = 100 days -> "100.0 days"
            testCase.verifyEqual(spanLbl.Text, '100.0 days');
            % start/end should be parseable as datestrs that match the inputs
            testCase.verifyEqual(startLbl.Text, datestr(100, 'yyyy-mm-dd HH:MM:SS'));
            testCase.verifyEqual(endLbl.Text,   datestr(200, 'yyyy-mm-dd HH:MM:SS'));
        end

        % --- Part 1: width test ---

        function testDefaultFigureWidthIs1400(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            pos = v.hFigure.Position;
            testCase.verifyEqual(pos(3), 1400, 'AbsTol', 1);
        end

        % --- Part 2: switch lives in left column test ---

        function testViewSwitchLivesInLeftColumn(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            sw = findall(v.hFigure, 'Tag', 'ViewModeSwitch');
            testCase.verifyNotEmpty(sw);
            % Pragmatic check: get pixel position of switch and assert it's in the
            % left third of the figure.
            switchPx = getpixelposition(sw, true);
            figPx = v.hFigure.Position;
            testCase.verifyLessThan(switchPx(1) + switchPx(3)/2, figPx(3) / 3, ...
                'View switch must live in the left third of the figure (left column).');
        end

        % --- Part 3: Gantt crosshair API test ---

        function testGanttCrosshairAPIPresent(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            canvas = v.getCanvasForTest_();
            testCase.verifyTrue(ismethod(canvas, 'installCrosshair'));
            testCase.verifyTrue(ismethod(canvas, 'uninstallCrosshair'));
            % The crosshair line shouldn't exist yet (only created on first mouse move).
            testCase.verifyEmpty(canvas.hCrosshairLine);
        end

        % --- Multi-event drill-down (Plot Selected) tests ---

        function testTableMultiSelectEnablesPlotButton(testCase)
            es = makeStore_(testCase);
            for k = 1:5
                e = Event(k, k+0.5, sprintf('s%d', k), 'lbl', 1, 'upper');
                e.TagKeys = {sprintf('s%d', k)}; e.Severity = 1;
                es.append(e);
            end
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.refresh();
            btn = findall(v.hFigure, 'Tag', 'PlotSelectedEventsBtn');
            testCase.verifyNotEmpty(btn);
            testCase.verifyEqual(char(btn.Enable), 'off');
            v.injectTableSelectionForTest_([1 3 5]);
            drawnow;
            testCase.verifyEqual(char(btn.Enable), 'on');
            testCase.verifyEqual(btn.Text, 'Plot Selected (3)');
        end

        function testPlotSelectedOpensMultiWidgetDashboard(testCase)
            % Register tags so resolution succeeds for all selected events.
            TagRegistry.clear();
            testCase.addTeardown(@() TagRegistry.clear());
            for k = 1:3
                key = sprintf('s%d', k);
                TagRegistry.register(key, SensorTag(key, 'Name', key, 'Units', 'u', ...
                    'X', 0:9, 'Y', sin((1:10) + k)));
            end

            es = makeStore_(testCase);
            for k = 1:3
                e = Event(k, k+0.5, sprintf('s%d', k), 'lbl', 1, 'upper');
                e.TagKeys = {sprintf('s%d', k)}; e.Severity = 1;
                es.append(e);
            end

            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            v.refresh();
            v.injectTableSelectionForTest_([1 2 3]);

            allFigsBefore = findall(groot, 'Type', 'figure');
            v.onPlotSelectedClickedForTest_();
            drawnow;
            allFigsAfter = findall(groot, 'Type', 'figure');
            newFigs = setdiff(allFigsAfter, allFigsBefore);
            testCase.verifyGreaterThanOrEqual(numel(newFigs), 1, ...
                'Multi-event dashboard must spawn a new figure.');
            testCase.addTeardown(@() arrayfun(@(f) close(f, 'force'), newFigs));
        end
    end
end

% --- File-local helpers (after the classdef end) ----------------------
function es = makeStore_(testCase)
    storePath = [tempname() '.mat'];
    es = EventStore(storePath);
    testCase.addTeardown(@() delete(storePath));
end

function comp = makeFakeCompanion_()
    % Minimal stub for typecheck — real companion needed for listener wiring tests later.
    comp = struct('IsLive', false, 'LivePeriod', 1.0);
end

function comp = makeRealCompanion_(testCase)
    comp = FastSenseCompanion();
    testCase.addTeardown(@() comp.close());
end

function evs = makeEvents_()
    e1 = Event(0,  1,  'sA', 'lbl', 1, 'upper'); e1.TagKeys = {'tA'}; e1.Severity = 1;
    e2 = Event(10, 11, 'sB', 'lbl', 1, 'upper'); e2.TagKeys = {'tB'}; e2.Severity = 2;
    e3 = Event(20, 21, 'sC', 'lbl', 1, 'upper'); e3.TagKeys = {'tA'}; e3.Severity = 3;
    e4 = Event(30, NaN, 'sD', 'lbl', 1, 'upper'); e4.TagKeys = {'tD'}; e4.IsOpen = true; e4.Severity = 2;
    evs = [e1 e2 e3 e4];
end

function setLeftPaneWidth_(v, val)
    v.LeftPaneWidth = val;
end

function setViewMode_(v, val)
    v.ViewMode = val;
end
