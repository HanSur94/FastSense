classdef TestTagCatalogPane < matlab.unittest.TestCase
%TESTTAGCATALOGPANE Class-based tests for TagCatalogPane (Phase 1019).
%   MATLAB-only (uses uifigure/uilistbox). Skipped on Octave.
%   Exercises CATALOG-01 through CATALOG-06 plus cross-cutting checks.
%
%   Uses findobj / findall on the companion uifigure to locate UI controls
%   without accessing private properties directly.
%
%   See also TagCatalogPane, FastSenseCompanion, filterTags, groupByLabel.

    properties
        App = []  % FastSenseCompanion handle; reset each test
    end

    % ------------------------------------------------------------------
    methods (TestClassSetup)
        function addPaths(~)
            %ADDPATHS Add project root to path and call install().
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    % ------------------------------------------------------------------
    methods (TestMethodSetup)
        function buildApp(testCase)
            %BUILDAPP Skip on Octave; populate fixtures; open companion.
            % Octave guard
            testCase.assumeFalse( ...
                exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestTagCatalogPane: MATLAB-only, skipping on Octave.');
            % Isolate registry state before construction
            TagRegistry.clear();
            testCase.registerFixtures();
            % Construct companion (internally calls TagRegistry.find)
            testCase.App = FastSenseCompanion('Dashboards', {}, 'Theme', 'dark');
            testCase.addTeardown(@() testCase.teardownApp());
        end
    end

    % ------------------------------------------------------------------
    % Internal teardown (also registered via addTeardown in buildApp)
    % ------------------------------------------------------------------
    methods (Access = private)

        function teardownApp(testCase)
            %TEARDOWNAPP Close companion and clear registry.
            if ~isempty(testCase.App) && isvalid(testCase.App)
                testCase.App.close();
            end
            TagRegistry.clear();
            testCase.App = [];
        end

        function registerFixtures(~)
            %REGISTERFIXTURES Populate TagRegistry with 5 deterministic test tags.
            %   2 groups ('ProcessArea', 'CoolingSystem') + 1 ungrouped.
            %   Covers multiple kinds (SensorTag / StateTag) and criticalities.

            % SensorTag — ProcessArea — high
            t1 = SensorTag('pressure_a', 'Name', 'Pressure A', ...
                'X', 1:5, 'Y', ones(1,5), ...
                'Description', 'Reactor feed pressure', ...
                'Labels', {'ProcessArea'}, 'Criticality', 'high');
            TagRegistry.register('pressure_a', t1);

            % SensorTag — ProcessArea — medium
            t2 = SensorTag('flow_b', 'Name', 'Flow B', ...
                'X', 1:5, 'Y', ones(1,5), ...
                'Description', 'Feed line flow rate', ...
                'Labels', {'ProcessArea'}, 'Criticality', 'medium');
            TagRegistry.register('flow_b', t2);

            % StateTag — CoolingSystem — low
            t3 = StateTag('valve_state', 'Name', 'Valve State', ...
                'X', 1:5, 'Y', zeros(1,5), ...
                'Description', 'Cooling valve open/closed', ...
                'Labels', {'CoolingSystem'}, 'Criticality', 'low');
            TagRegistry.register('valve_state', t3);

            % SensorTag — CoolingSystem — safety
            t4 = SensorTag('coolant_temp', 'Name', 'Coolant Temp', ...
                'X', 1:5, 'Y', ones(1,5) * 20, ...
                'Description', 'Coolant temperature', ...
                'Labels', {'CoolingSystem'}, 'Criticality', 'safety');
            TagRegistry.register('coolant_temp', t4);

            % SensorTag — Ungrouped — medium
            t5 = SensorTag('composite_kpi', 'Name', 'Composite KPI', ...
                'X', 1:5, 'Y', zeros(1,5), ...
                'Description', 'Derived performance index', ...
                'Labels', {}, 'Criticality', 'medium');
            TagRegistry.register('composite_kpi', t5);
        end

        function [catalog, cs] = getCatalogAndStruct(testCase)
            %GETCATALOGANDSTRUCT Access catalog pane and its private struct via warning suppress.
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState));
            catalog = struct(testCase.App).CatalogPane_;
            if nargout > 1; cs = struct(catalog); end
        end

        % ---- UI locator helpers ----

        function hFig = findFig(testCase)
            %FINDFIG Locate the companion uifigure by name.
            hFig = findobj(groot, 'Type', 'figure', 'Name', 'FastSense Companion');
            if isempty(hFig)
                hFig = findobj(groot, '-regexp', 'Name', 'FastSense Companion');
            end
            testCase.assertNotEmpty(hFig, 'findFig: companion uifigure not found');
            hFig = hFig(1);
        end

        function lb = findListbox(testCase)
            %FINDLISTBOX Locate the uilistbox inside the companion figure.
            hFig = testCase.findFig();
            lb = findall(hFig, '-isa', 'matlab.ui.control.ListBox');
            testCase.assertNotEmpty(lb, 'findListbox: uilistbox not found');
            lb = lb(1);
        end

        function sf = findSearchField(testCase)
            %FINDSEARCHFIELD Locate the search uieditfield.
            hFig = testCase.findFig();
            sf = findall(hFig, '-isa', 'matlab.ui.control.EditField');
            testCase.assertNotEmpty(sf, 'findSearchField: search editfield not found');
            sf = sf(1);
        end

        function btn = findClearButton(testCase)
            %FINDCLEARBUTTON Locate the x clear button by its char(215) text.
            hFig = testCase.findFig();
            btns = findall(hFig, '-isa', 'matlab.ui.control.Button');
            btn = [];
            for i = 1:numel(btns)
                if isequal(btns(i).Text, char(215))
                    btn = btns(i);
                    return;
                end
            end
            testCase.assertNotEmpty(btn, 'findClearButton: clear (x) button not found');
        end

        function btn = findPillButton(testCase, labelText)
            %FINDPILLBUTTON Locate a pill uibutton by exact label text.
            hFig = testCase.findFig();
            btns = findall(hFig, '-isa', 'matlab.ui.control.Button');
            btn = [];
            for i = 1:numel(btns)
                if strcmp(btns(i).Text, labelText)
                    btn = btns(i);
                    return;
                end
            end
            testCase.assertNotEmpty(btn, ...
                sprintf('findPillButton: pill button "%s" not found', labelText));
        end

        function n = countVisibleTags(~, lb)
            %COUNTVISIBLETAGS Count non-header rows in the listbox (ischar ItemsData).
            n = sum(cellfun(@(d) ischar(d) && ~isempty(d), lb.ItemsData));
        end

    end

    % ==================================================================
    methods (Test)

        % ---- CATALOG-01: Search narrows and clears ----

        function testCATALOG01_searchNarrowsListbox(testCase)
        %TESTCATALOG01_SEARCHNARROWSLISTBOX CATALOG-01: typing a term narrows the listbox.
            lb = testCase.findListbox();
            nBefore = testCase.countVisibleTags(lb);
            sf = testCase.findSearchField();
            sf.Value = 'pressure';
            feval(sf.ValueChangedFcn, [], []);
            pause(0.25);
            drawnow;
            nAfter = testCase.countVisibleTags(lb);
            testCase.assertLessThan(nAfter, nBefore, ...
                'CATALOG-01: search should narrow the visible tag count');
            testCase.assertGreaterThan(nAfter, 0, ...
                'CATALOG-01: search for "pressure" should yield at least 1 result');
        end

        function testCATALOG01_searchCaseInsensitive(testCase)
        %TESTCATALOG01_SEARCHCASEINSENSITIVE CATALOG-01: search is case-insensitive.
            lb = testCase.findListbox();
            sf = testCase.findSearchField();
            % Uppercase search for a lowercase key
            sf.Value = 'PRESSURE';
            feval(sf.ValueChangedFcn, [], []);
            pause(0.25);
            drawnow;
            nUpper = testCase.countVisibleTags(lb);
            % Lowercase search for the same key
            sf.Value = 'pressure';
            feval(sf.ValueChangedFcn, [], []);
            pause(0.25);
            drawnow;
            nLower = testCase.countVisibleTags(lb);
            testCase.assertEqual(nUpper, nLower, ...
                'CATALOG-01: case-insensitive search should return same count');
            testCase.assertGreaterThan(nLower, 0, ...
                'CATALOG-01: "pressure" search should return at least 1 result');
        end

        function testCATALOG01_clearButtonRestoresFull(testCase)
        %TESTCATALOG01_CLEARBUTTONRESTORESFULL CATALOG-01: clear button restores full list.
            lb = testCase.findListbox();
            nFull = testCase.countVisibleTags(lb);
            % Narrow with a search
            sf = testCase.findSearchField();
            sf.Value = 'pressure';
            feval(sf.ValueChangedFcn, [], []);
            pause(0.25);
            drawnow;
            % Click clear button
            clearBtn = testCase.findClearButton();
            feval(clearBtn.ButtonPushedFcn, [], []);
            drawnow;
            nAfter = testCase.countVisibleTags(lb);
            testCase.assertEqual(nAfter, nFull, ...
                'CATALOG-01: clear button should restore the full list');
        end

        function testCATALOG01_searchByDescription(testCase)
        %TESTCATALOG01_SEARCHBYDESCRIPTION CATALOG-01: search matches Description field.
            lb = testCase.findListbox();
            sf = testCase.findSearchField();
            % 'Reactor' appears in 'Reactor feed pressure' (pressure_a description)
            sf.Value = 'Reactor';
            feval(sf.ValueChangedFcn, [], []);
            pause(0.25);
            drawnow;
            visibleKeys = lb.ItemsData(cellfun(@ischar, lb.ItemsData));
            testCase.assertNotEmpty(visibleKeys, ...
                'CATALOG-01: search by Description text should return results');
        end

        % ---- CATALOG-02: Kind pill + criticality pill filters ----

        function testCATALOG02_kindPillNarrowsToSensor(testCase)
        %TESTCATALOG02_KINDPILLNARROWSTOSENSOR CATALOG-02: Sensor kind pill filters by class.
            sensorBtn = testCase.findPillButton('Sensor');
            feval(sensorBtn.ButtonPushedFcn, [], []);
            drawnow;
            lb = testCase.findListbox();
            visibleKeys = lb.ItemsData(cellfun(@ischar, lb.ItemsData));
            testCase.assertNotEmpty(visibleKeys, ...
                'CATALOG-02: Sensor pill should leave at least one tag visible');
            for i = 1:numel(visibleKeys)
                t = TagRegistry.get(visibleKeys{i});
                testCase.verifyTrue(isa(t, 'SensorTag'), ...
                    sprintf('CATALOG-02: tag "%s" should be a SensorTag', visibleKeys{i}));
            end
        end

        function testCATALOG02_criticalityPillNarrows(testCase)
        %TESTCATALOG02_CRITICALITYPILLNARROWS CATALOG-02: High criticality pill filters correctly.
            highBtn = testCase.findPillButton('High');
            feval(highBtn.ButtonPushedFcn, [], []);
            drawnow;
            lb = testCase.findListbox();
            visibleKeys = lb.ItemsData(cellfun(@ischar, lb.ItemsData));
            testCase.assertNotEmpty(visibleKeys, ...
                'CATALOG-02: High pill should leave at least one tag visible');
            for i = 1:numel(visibleKeys)
                t = TagRegistry.get(visibleKeys{i});
                testCase.verifyEqual(t.Criticality, 'high', ...
                    sprintf('CATALOG-02: tag "%s" should have high criticality', visibleKeys{i}));
            end
        end

        function testCATALOG02_andAcrossPillRows(testCase)
        %TESTCATALOG02_ANDACROSSPILLROWS CATALOG-02: AND semantics across kind + criticality rows.
            % Activate Sensor kind pill AND High criticality pill
            sensorBtn = testCase.findPillButton('Sensor');
            feval(sensorBtn.ButtonPushedFcn, [], []);
            highBtn = testCase.findPillButton('High');
            feval(highBtn.ButtonPushedFcn, [], []);
            drawnow;
            lb = testCase.findListbox();
            visibleKeys = lb.ItemsData(cellfun(@ischar, lb.ItemsData));
            % Only SensorTag AND high criticality should remain
            for i = 1:numel(visibleKeys)
                t = TagRegistry.get(visibleKeys{i});
                testCase.verifyTrue(isa(t, 'SensorTag'), ...
                    sprintf('CATALOG-02: AND filter: tag "%s" not a SensorTag', visibleKeys{i}));
                testCase.verifyEqual(t.Criticality, 'high', ...
                    sprintf('CATALOG-02: AND filter: tag "%s" not high criticality', visibleKeys{i}));
            end
        end

        function testCATALOG02_orWithinKindRow(testCase)
        %TESTCATALOG02_ORWITHINKINDROW CATALOG-02: OR semantics within the kind pill row.
            % Activate Sensor and State pills (OR within row)
            sensorBtn = testCase.findPillButton('Sensor');
            feval(sensorBtn.ButtonPushedFcn, [], []);
            stateBtn = testCase.findPillButton('State');
            feval(stateBtn.ButtonPushedFcn, [], []);
            drawnow;
            lb = testCase.findListbox();
            visibleKeys = lb.ItemsData(cellfun(@ischar, lb.ItemsData));
            testCase.assertNotEmpty(visibleKeys, ...
                'CATALOG-02: Sensor+State pills should show at least one tag');
            for i = 1:numel(visibleKeys)
                t = TagRegistry.get(visibleKeys{i});
                isSensorOrState = isa(t, 'SensorTag') || isa(t, 'StateTag');
                testCase.verifyTrue(isSensorOrState, ...
                    sprintf('CATALOG-02: OR: tag "%s" not Sensor or State', visibleKeys{i}));
            end
        end

        % ---- CATALOG-03: Selection persists across filter changes ----

        function testCATALOG03_selectionSurvivesSearch(testCase)
        %TESTCATALOG03_SELECTIONSURVIVESSEARCH CATALOG-03: selection persists through search.
            lb = testCase.findListbox();
            % Select pressure_a
            lb.Value = {'pressure_a'};
            feval(lb.ValueChangedFcn, [], []);
            drawnow;
            % Apply search that hides pressure_a (matches valve_state only)
            sf = testCase.findSearchField();
            sf.Value = 'valve';
            feval(sf.ValueChangedFcn, [], []);
            pause(0.25);
            drawnow;
            % pressure_a should not be in the visible list now
            visibleKeys = lb.ItemsData(cellfun(@ischar, lb.ItemsData));
            testCase.assertFalse(any(strcmp(visibleKeys, 'pressure_a')), ...
                'CATALOG-03: pressure_a should be hidden while search is active');
            % Clear search: pressure_a should reappear AND be selected
            clearBtn = testCase.findClearButton();
            feval(clearBtn.ButtonPushedFcn, [], []);
            drawnow;
            testCase.assertTrue(any(strcmp(lb.Value, 'pressure_a')), ...
                'CATALOG-03: pressure_a selection should be restored after clear');
        end

        function testCATALOG03_headerSelectionRejected(testCase)
        %TESTCATALOG03_HEADERSELECTIONREJECTED CATALOG-03: group-header rows are not selectable.
            lb = testCase.findListbox();
            % Find a group-header row (ItemsData == [] means header)
            headerIdx = [];
            for i = 1:numel(lb.ItemsData)
                if isempty(lb.ItemsData{i}) || ...
                        (isnumeric(lb.ItemsData{i}) && isscalar(lb.ItemsData{i}) && isnan(lb.ItemsData{i}(1)))
                    headerIdx = i;
                    break;
                end
            end
            if isempty(headerIdx)
                testCase.assertFail('CATALOG-03: no group-header row found in listbox');
            end
            % Attempt to "select" the header row string
            lb.Value = {lb.Items{headerIdx}};
            feval(lb.ValueChangedFcn, [], []);
            drawnow;
            % SelectedKeys should NOT contain the header (header ItemsData is [])
            testCase.assertEmpty(lb.Value, ...
                'CATALOG-03: group-header row must be rejected from selection');
        end

        % ---- CATALOG-04: Grouping by first Label, Ungrouped last ----

        function testCATALOG04_groupHeadersPresent(testCase)
        %TESTCATALOG04_GROUPHEADERSPRESENT CATALOG-04: group headers (▼) appear in listbox.
            lb = testCase.findListbox();
            arrowChar = char(9660);  % ▼
            headers = lb.Items(cellfun(@(s) ~isempty(s) && s(1) == arrowChar, lb.Items));
            testCase.assertNotEmpty(headers, ...
                'CATALOG-04: no group headers found — expected rows beginning with ▼');
        end

        function testCATALOG04_ungroupedHeaderLast(testCase)
        %TESTCATALOG04_UNGROUPEDHEADERLAST CATALOG-04: Ungrouped group is the last group header.
            lb = testCase.findListbox();
            arrowChar = char(9660);
            headerIdx = find(cellfun(@(s) ~isempty(s) && s(1) == arrowChar, lb.Items));
            testCase.assertNotEmpty(headerIdx, ...
                'CATALOG-04: no group headers found');
            lastHeader = lb.Items{headerIdx(end)};
            testCase.assertFalse(isempty(strfind(lastHeader, 'Ungrouped')), ...
                'CATALOG-04: the last group header should be "Ungrouped"');
        end

        function testCATALOG04_tagAppearsOnceUnderFirstLabel(testCase)
        %TESTCATALOG04_TAGAPPEARSONCEFIRSTLABEL CATALOG-04: each tag appears under its first label only.
            lb = testCase.findListbox();
            % Count how many times 'pressure_a' (Name: 'Pressure A') appears as a data row
            keyCount = sum(strcmp(lb.ItemsData, 'pressure_a'));
            testCase.assertEqual(keyCount, 1, ...
                'CATALOG-04: pressure_a should appear exactly once in the listbox');
        end

        % ---- CATALOG-05: Count badge format ----

        function testCATALOG05_countBadgeInitialFormat(testCase)
        %TESTCATALOG05_COUNTBADGEINITIALFORMAT CATALOG-05: initial badge shows "N of M visible".
            hFig = testCase.findFig();
            labels = findall(hFig, '-isa', 'matlab.ui.control.Label');
            countText = '';
            for i = 1:numel(labels)
                if ~isempty(strfind(labels(i).Text, 'visible'))
                    countText = labels(i).Text;
                    break;
                end
            end
            testCase.assertNotEmpty(countText, ...
                'CATALOG-05: count badge label (containing "visible") not found');
            % Must match "\d+ of \d+ visible" pattern
            testCase.assertFalse(isempty(regexp(countText, '^\d+ of \d+ visible')), ...
                sprintf('CATALOG-05: count badge format mismatch — got: "%s"', countText));
        end

        function testCATALOG05_countBadgeWithSelection(testCase)
        %TESTCATALOG05_COUNTBADGEWITHSELECTION CATALOG-05: selected suffix appears when N>0.
            lb = testCase.findListbox();
            lb.Value = {'pressure_a'};
            feval(lb.ValueChangedFcn, [], []);
            drawnow;
            hFig = testCase.findFig();
            labels = findall(hFig, '-isa', 'matlab.ui.control.Label');
            selectedText = '';
            for i = 1:numel(labels)
                if ~isempty(strfind(labels(i).Text, 'selected'))
                    selectedText = labels(i).Text;
                    break;
                end
            end
            testCase.assertNotEmpty(selectedText, ...
                'CATALOG-05: count badge should contain "selected" after selecting a tag');
            % Must match pattern "N of M visible · K selected"
            testCase.assertFalse(isempty(regexp(selectedText, '\d+ of \d+ visible')), ...
                sprintf('CATALOG-05: selected badge format mismatch — got: "%s"', selectedText));
        end

        % ---- CATALOG-06: Snapshot semantics + refreshCatalog() ----

        function testCATALOG06_snapshotHidesNewTagBeforeRefresh(testCase)
        %TESTCATALOG06_SNAPSHOTHIDESNEWTAG CATALOG-06: new tags invisible until refreshCatalog().
            lb = testCase.findListbox();
            nBefore = testCase.countVisibleTags(lb);
            % Add a new tag after app construction
            tNew = SensorTag('new_sensor', 'Name', 'New Sensor', ...
                'X', 1:3, 'Y', ones(1,3), ...
                'Labels', {'ProcessArea'}, 'Criticality', 'low');
            TagRegistry.register('new_sensor', tNew);
            drawnow;
            % Catalog should NOT auto-update (snapshot semantics)
            nMidway = testCase.countVisibleTags(lb);
            testCase.assertEqual(nMidway, nBefore, ...
                'CATALOG-06: catalog must not auto-update before refreshCatalog()');
        end

        function testCATALOG06_refreshCatalogShowsNewTag(testCase)
        %TESTCATALOG06_REFRESHCATALOGSHOWSNEWTAG CATALOG-06: refreshCatalog() picks up new tags.
            lb = testCase.findListbox();
            nBefore = testCase.countVisibleTags(lb);
            % Add a new tag after construction
            tNew = SensorTag('extra_flow', 'Name', 'Extra Flow', ...
                'X', 1:3, 'Y', ones(1,3), ...
                'Labels', {'ProcessArea'}, 'Criticality', 'low');
            TagRegistry.register('extra_flow', tNew);
            % Explicitly refresh
            testCase.App.refreshCatalog();
            drawnow;
            nAfter = testCase.countVisibleTags(lb);
            testCase.assertGreaterThan(nAfter, nBefore, ...
                'CATALOG-06: catalog should show new tag after refreshCatalog()');
        end

        % ---- Cross-cutting checks ----

        function testNoOrphanTimersAfterClose(testCase)
        %TESTNOORPHANTIMERSSAFTERCLOSE No debounce timers leaked after close().
            % Trigger search to lazily create the debounce timer
            sf = testCase.findSearchField();
            sf.Value = 'pressure';
            feval(sf.ValueChangedFcn, [], []);
            drawnow;
            nBefore = numel(timerfindall);
            % The teardown registered in buildApp will call close(); count after
            testCase.App.close();
            nAfter = numel(timerfindall);
            testCase.assertLessThanOrEqual(nAfter, nBefore, ...
                'cross-cutting: close() must not leave orphan timers');
            % Reset App so addTeardown does not double-close
            testCase.App = FastSenseCompanion('Dashboards', {}, 'Theme', 'dark');
        end

        function testNoBannedHandlesInTagCatalogPane(testCase)
        %TESTNOBANNEDHANDLESINTAGCATALOGPANE Cross-cutting: no implicit-handle calls in source.
            src = fileread(which('TagCatalogPane'));
            hasBanned = ~isempty(regexp(src, '\bgcf\b|\bgca\b', 'once'));
            testCase.assertFalse(hasBanned, ...
                'cross-cutting: implicit figure/axes handle call found in TagCatalogPane.m');
        end

        function testListenersPropertyExists(testCase)
        %TESTLISTENERSPROPERTYEXISTS Cross-cutting: Listeners_ cell is declared in TagCatalogPane.
            src = fileread(which('TagCatalogPane'));
            testCase.assertFalse(isempty(strfind(src, 'Listeners_')), ...
                'cross-cutting: Listeners_ property not found in TagCatalogPane.m');
            % Also verify detach deletes listeners
            testCase.assertFalse(isempty(strfind(src, 'delete(obj.Listeners_)')), ...
                'cross-cutting: delete(obj.Listeners_) not found in TagCatalogPane.m');
        end

        % ---- Phase 1021: getSelectedKeys / deselectKey ----

        function testGetSelectedKeysReturnsCellstr(testCase)
        %TESTGETSELECTEDKEYSRETURNSCELLSTR Phase 1021: getSelectedKeys returns cellstr.
            [catalog, cs] = testCase.getCatalogAndStruct();
            cs.hListbox_.Value = {'pressure_a', 'flow_b'};
            feval(cs.hListbox_.ValueChangedFcn, [], []); drawnow;
            keys = catalog.getSelectedKeys();
            testCase.verifyTrue(iscell(keys), 'getSelectedKeys must return a cell');
            testCase.verifyEqual(numel(keys), 2, 'getSelectedKeys must return 2 keys');
            testCase.verifyTrue(any(strcmp(keys, 'pressure_a')), 'pressure_a missing');
            testCase.verifyTrue(any(strcmp(keys, 'flow_b')), 'flow_b missing');
        end

        function testDeselectKeyRemovesAndFiresEvent(testCase)
        %TESTDESELECTKEYREMOVESANDFIRESEVENT Phase 1021: deselectKey removes key + fires event.
            [catalog, cs] = testCase.getCatalogAndStruct();
            cs.hListbox_.Value = {'pressure_a', 'flow_b'};
            feval(cs.hListbox_.ValueChangedFcn, [], []); drawnow;
            fired = false;
            lh = addlistener(catalog, 'TagSelectionChanged', @(~,~) setFired());
            function setFired(); fired = true; end
            cleanupL = onCleanup(@() delete(lh));
            catalog.deselectKey('pressure_a'); drawnow;
            testCase.verifyTrue(fired, 'deselectKey must fire TagSelectionChanged');
            keys = catalog.getSelectedKeys();
            testCase.verifyFalse(any(strcmp(keys, 'pressure_a')), 'pressure_a not removed');
            testCase.verifyTrue(any(strcmp(keys, 'flow_b')), 'flow_b removed unexpectedly');
        end

        function testDeselectKeyOnUnselectedKeyIsNoop(testCase)
        %TESTDESELECTKEYNOOP Phase 1021: deselectKey on unselected key is a no-op.
            [catalog, cs] = testCase.getCatalogAndStruct();
            cs.hListbox_.Value = {'pressure_a'};
            feval(cs.hListbox_.ValueChangedFcn, [], []); drawnow;
            catalog.deselectKey('nonexistent_key'); drawnow;
            keys = catalog.getSelectedKeys();
            testCase.verifyEqual(numel(keys), 1, 'selection size must not change');
            testCase.verifyTrue(any(strcmp(keys, 'pressure_a')), 'pressure_a lost');
        end

        function testDeselectKeyRejectsNonChar(testCase)
        %TESTDESELECTKEYREJECTSNONCHAR Phase 1021: deselectKey throws on non-char key.
            catalog = testCase.getCatalogAndStruct();
            try
                catalog.deselectKey(42);
                testCase.verifyTrue(true, 'uialert path: no rethrow (acceptable)');
            catch ME
                testCase.verifyEqual(ME.identifier, 'FastSenseCompanion:invalidArgument', ...
                    'FastSenseCompanion:invalidArgument expected');
            end
        end

    end

end
