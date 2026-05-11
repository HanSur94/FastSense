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
