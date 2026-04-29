classdef TestDashboardListPane < matlab.unittest.TestCase
%TESTDASHBOARDLISTPANE Class-based tests for DashboardListPane (Phase 1020).
%   MATLAB-only (uses uifigure). Skipped on Octave.
%   Exercises BROWSER-01 through BROWSER-05 plus cross-cutting checks
%   (debounce timer cleanup, Listeners_ retention).
%
%   See also DashboardListPane, FastSenseCompanion, filterDashboards,
%            DashboardEventData, TestTagCatalogPane.

    properties
        App     = []   % FastSenseCompanion handle; reset each test
        Engines = {}   % cell of DashboardEngine handles created in setup
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
            testCase.assumeFalse( ...
                exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestDashboardListPane: MATLAB-only, skipping on Octave.');
            TagRegistry.clear();
            % Three deterministic dashboards with distinct names
            testCase.Engines = { ...
                DashboardEngine('Reactor View'), ...
                DashboardEngine('Cooling Loop'), ...
                DashboardEngine('Diagnostics') };
            testCase.App = FastSenseCompanion( ...
                'Dashboards', testCase.Engines, 'Theme', 'dark');
            testCase.addTeardown(@() testCase.teardownApp());
        end
    end

    % ------------------------------------------------------------------
    methods (Access = private)

        function teardownApp(testCase)
            %TEARDOWNAPP Close companion and clear registry.
            if ~isempty(testCase.App) && isvalid(testCase.App)
                testCase.App.close();
            end
            TagRegistry.clear();
            testCase.App    = [];
            testCase.Engines = {};
        end

        function hFig = findFig(testCase)
            %FINDFIG Locate the companion uifigure by name.
            hFig = findobj(groot, 'Type', 'figure', 'Name', 'FastSense Companion');
            if isempty(hFig)
                hFig = findobj(groot, '-regexp', 'Name', 'FastSense Companion');
            end
            testCase.assertNotEmpty(hFig, 'companion uifigure not found');
            hFig = hFig(1);
        end

        function sf = findDashboardSearch(testCase)
            %FINDDASHBOARDSEARCH Locate the dashboard search field by placeholder text.
            hFig = testCase.findFig();
            fields = findall(hFig, '-isa', 'matlab.ui.control.EditField');
            sf = [];
            for i = 1:numel(fields)
                if strcmp(fields(i).Placeholder, ['Search dashboards', char(8230)])
                    sf = fields(i);
                    return;
                end
            end
            testCase.assertNotEmpty(sf, 'dashboard search field not found');
        end

        function btns = findOpenButtons(testCase)
            %FINDOPENBUTTONS Find all 'Open' buttons in the companion figure.
            hFig = testCase.findFig();
            all = findall(hFig, '-isa', 'matlab.ui.control.Button');
            btns = matlab.ui.control.Button.empty;
            for i = 1:numel(all)
                if strcmp(all(i).Text, 'Open')
                    btns(end+1) = all(i); %#ok<AGROW>
                end
            end
        end

        function btns = findRowButtons(testCase)
            %FINDROWBUTTONS Row-area buttons whose Text is a dashboard Name.
            hFig = testCase.findFig();
            all = findall(hFig, '-isa', 'matlab.ui.control.Button');
            names = cellfun(@(e) e.Name, testCase.Engines, 'UniformOutput', false);
            btns = matlab.ui.control.Button.empty;
            for i = 1:numel(all)
                if any(strcmp(all(i).Text, names))
                    btns(end+1) = all(i); %#ok<AGROW>
                end
            end
        end

        function clearBtn = findDashboardClearButton(testCase)
            %FINDDASHBOARDCLEARBUTTON Find the x clear button for the dashboard search.
            %   Disambiguates from catalog pane clear button by tooltip.
            hFig = testCase.findFig();
            btns = findall(hFig, '-isa', 'matlab.ui.control.Button');
            clearBtn = [];
            for i = 1:numel(btns)
                if strcmp(btns(i).Text, char(215)) && strcmp(btns(i).Tooltip, 'Clear search')
                    % Try to confirm we are in the dashboard pane by checking for
                    % a sibling Open button within common ancestor panels
                    p = btns(i).Parent;
                    for depth = 1:6
                        if isempty(p) || ~isvalid(p)
                            break;
                        end
                        siblings = findall(p, '-isa', 'matlab.ui.control.Button');
                        hasOpen = false;
                        for s = 1:numel(siblings)
                            if strcmp(siblings(s).Text, 'Open')
                                hasOpen = true;
                                break;
                            end
                        end
                        if hasOpen
                            clearBtn = btns(i);
                            return;
                        end
                        p = p.Parent;
                    end
                end
            end
            if isempty(clearBtn)
                % Fall back: take any '×' button with Tooltip 'Clear search'
                for i = 1:numel(btns)
                    if strcmp(btns(i).Text, char(215)) && strcmp(btns(i).Tooltip, 'Clear search')
                        clearBtn = btns(i);
                        break;
                    end
                end
            end
            testCase.assertNotEmpty(clearBtn, 'dashboard clear (x) button not found');
        end

    end

    % ==================================================================
    methods (Test)

        % ---- BROWSER-01: rows render for each dashboard ----

        function testBROWSER01_rowsRenderForEachDashboard(testCase)
        %TESTBROWSER01_ROWSRENDERFOREACHDASHBOARD BROWSER-01: one row + Open per dashboard.
            rowBtns  = testCase.findRowButtons();
            openBtns = testCase.findOpenButtons();
            testCase.assertNumElements(rowBtns, 3, ...
                'BROWSER-01: expected 3 row-area buttons');
            testCase.assertNumElements(openBtns, 3, ...
                'BROWSER-01: expected 3 Open buttons');
        end

        function testBROWSER01_widgetCountLabelPresent(testCase)
        %TESTBROWSER01_WIDGETCOUNTLABELPRESENT BROWSER-01: per-row widget count (N) label wired.
            % Engines are fresh DashboardEngine with no widgets: count = 0
            hFig = testCase.findFig();
            labels = findall(hFig, '-isa', 'matlab.ui.control.Label');
            zeroCountFound = false;
            for i = 1:numel(labels)
                if strcmp(labels(i).Text, '(0)')
                    zeroCountFound = true;
                    break;
                end
            end
            testCase.assertTrue(zeroCountFound, ...
                'BROWSER-01: expected at least one (0) widget-count label for fresh engines');
        end

        function testBROWSER01_statusDotPresent(testCase)
        %TESTBROWSER01_STATUSDOTPRESENT BROWSER-01: status dot glyph exists for each row.
            hFig = testCase.findFig();
            labels = findall(hFig, '-isa', 'matlab.ui.control.Label');
            dotCount = 0;
            for i = 1:numel(labels)
                if strcmp(labels(i).Text, char(9679))
                    dotCount = dotCount + 1;
                end
            end
            testCase.assertGreaterThanOrEqual(dotCount, 3, ...
                'BROWSER-01: expected at least 3 status dot labels (one per engine)');
        end

        % ---- BROWSER-02: Open calls engine.render(); errors surface as uialert ----

        function testBROWSER02_openClickDoesNotCrashCompanion(testCase)
        %TESTBROWSER02_OPENCLICKDOESNOTCRASHCOMPANION BROWSER-02: Open click cannot crash companion.
        %   Full error-surfacing via uialert is validated manually;
        %   CI verifies that the click does not throw and companion stays alive.
            openBtns = testCase.findOpenButtons();
            testCase.assertNotEmpty(openBtns, 'BROWSER-02: need at least one Open button');
            openBtn = openBtns(1);
            feval(openBtn.ButtonPushedFcn, [], []);
            drawnow;
            testCase.verifyTrue(testCase.App.IsOpen, ...
                'BROWSER-02: Open click must not close the companion');
        end

        % ---- BROWSER-03: row click fires DashboardSelected ----

        function testBROWSER03_rowClickChangesHighlight(testCase)
        %TESTBROWSER03_ROWCLICKCHANGESHIGHLIGHT BROWSER-03: clicked row background changes.
            rowBtns   = testCase.findRowButtons();
            testCase.assertGreaterThanOrEqual(numel(rowBtns), 1, ...
                'BROWSER-03: need at least one row button');
            clickedBtn = rowBtns(1);
            origColor  = clickedBtn.BackgroundColor;
            feval(clickedBtn.ButtonPushedFcn, [], []);
            drawnow;
            % findRowButtons again in case applyFilter_ rebuilt the grid
            newRowBtns = testCase.findRowButtons();
            testCase.assertNotEmpty(newRowBtns, ...
                'BROWSER-03: row buttons must still exist after click');
            target = newRowBtns(1);
            testCase.verifyFalse(isequal(target.BackgroundColor, origColor), ...
                'BROWSER-03: clicked row should change background to selected color');
        end

        function testBROWSER03_eventPayloadCarriesEngineAndIndex(testCase)
        %TESTBROWSER03_EVENTPAYLOADCARRIESENGINEANDINDEX BROWSER-03: DashboardSelected carries payload.
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState));
            s = struct(testCase.App);
            pane = s.ListPane_;
            received = struct('Engine', [], 'Index', 0, 'Fired', false);

            function assignReceived(ed)
                received.Engine = ed.Engine;
                received.Index  = ed.Index;
                received.Fired  = true;
            end

            lh = addlistener(pane, 'DashboardSelected', @(~, ed) assignReceived(ed));
            rowBtns = testCase.findRowButtons();
            testCase.assertGreaterThanOrEqual(numel(rowBtns), 2, ...
                'BROWSER-03: need at least 2 row buttons for index test');
            feval(rowBtns(2).ButtonPushedFcn, [], []);
            drawnow;
            delete(lh);
            testCase.verifyTrue(received.Fired, ...
                'BROWSER-03: DashboardSelected event must fire on row click');
            testCase.verifyEqual(received.Index, 2, ...
                'BROWSER-03: payload Index must match clicked row (2)');
            testCase.verifySameHandle(received.Engine, testCase.Engines{2}, ...
                'BROWSER-03: payload Engine must match the clicked engine');
        end

        % ---- BROWSER-04: search narrows rows ----

        function testBROWSER04_searchNarrowsRows(testCase)
        %TESTBROWSER04_SEARCHNARROWSROWS BROWSER-04: search string filters row list.
            sf = testCase.findDashboardSearch();
            sf.Value = 'reactor';
            feval(sf.ValueChangedFcn, [], []);
            pause(0.25); drawnow;
            % Only 'Reactor View' matches; we need to include it in Engines for findRowButtons
            testCase.Engines = { ...
                DashboardEngine('Reactor View'), ...
                DashboardEngine('Cooling Loop'), ...
                DashboardEngine('Diagnostics') };
            % Check via Open buttons — one per visible row
            openBtns = testCase.findOpenButtons();
            testCase.verifyEqual(numel(openBtns), 1, ...
                'BROWSER-04: search "reactor" should leave only Reactor View (1 Open button)');
        end

        function testBROWSER04_searchIsCaseInsensitive(testCase)
        %TESTBROWSER04_SEARCHISCASEINSENSITIVE BROWSER-04: search is case-insensitive.
            sf = testCase.findDashboardSearch();
            sf.Value = 'REACTOR';
            feval(sf.ValueChangedFcn, [], []);
            pause(0.25); drawnow;
            openBtns = testCase.findOpenButtons();
            testCase.verifyEqual(numel(openBtns), 1, ...
                'BROWSER-04: case-insensitive search "REACTOR" should show 1 result');
        end

        function testBROWSER04_clearButtonRestoresFullList(testCase)
        %TESTBROWSER04_CLEARBUTTONRESTORESFULLLIST BROWSER-04: clear button shows all rows.
            sf = testCase.findDashboardSearch();
            sf.Value = 'reactor';
            feval(sf.ValueChangedFcn, [], []);
            pause(0.25); drawnow;
            % Verify narrowed
            openBtnsNarrow = testCase.findOpenButtons();
            testCase.verifyEqual(numel(openBtnsNarrow), 1, ...
                'BROWSER-04: setup: narrow should yield 1 button');
            % Click clear
            clearBtn = testCase.findDashboardClearButton();
            feval(clearBtn.ButtonPushedFcn, [], []);
            drawnow;
            openBtnsRestored = testCase.findOpenButtons();
            testCase.verifyEqual(numel(openBtnsRestored), 3, ...
                'BROWSER-04: clear must restore all 3 Open buttons');
        end

        % ---- BROWSER-05: addDashboard / removeDashboard ----

        function testBROWSER05_addDashboardAppendsRow(testCase)
        %TESTBROWSER05_ADDDASHBOARDAPPENDSROW BROWSER-05: addDashboard appends a new row.
            newD = DashboardEngine('Maintenance');
            testCase.App.addDashboard(newD);
            drawnow;
            openBtns = testCase.findOpenButtons();
            testCase.verifyEqual(numel(openBtns), 4, ...
                'BROWSER-05: addDashboard must append a row (4 Open buttons after add)');
        end

        function testBROWSER05_addDashboardRejectsNonDashboardEngine(testCase)
        %TESTBROWSER05_ADDDASHBOARDREJECTSNONDASHBOARDENGINE BROWSER-05: type validation.
            testCase.verifyError(@() testCase.App.addDashboard(struct('Name', 'x')), ...
                'FastSenseCompanion:invalidDashboard');
        end

        function testBROWSER05_addDashboardRejectsDuplicateHandle(testCase)
        %TESTBROWSER05_ADDDASHBOARDREJECTSDUPLICATEHANDLE BROWSER-05: duplicate rejection.
            testCase.verifyError(@() testCase.App.addDashboard(testCase.Engines{1}), ...
                'FastSenseCompanion:duplicateDashboard');
        end

        function testBROWSER05_removeDashboardDropsRow(testCase)
        %TESTBROWSER05_REMOVEDASHBOARDDROPSROW BROWSER-05: removeDashboard removes a row.
            testCase.App.removeDashboard('Cooling Loop');
            drawnow;
            openBtns = testCase.findOpenButtons();
            testCase.verifyEqual(numel(openBtns), 2, ...
                'BROWSER-05: removeDashboard must drop a row (2 Open buttons after remove)');
        end

        function testBROWSER05_removeDashboardThrowsOnUnknown(testCase)
        %TESTBROWSER05_REMOVEDASHBOARDTHROWSONUNKNOWN BROWSER-05: missing key throws.
            testCase.verifyError(@() testCase.App.removeDashboard('NoSuchDashboard'), ...
                'FastSenseCompanion:dashboardNotFound');
        end

        function testBROWSER05_removeSelectedDashboardResetsInspector(testCase)
        %TESTBROWSER05_REMOVESELECTEDRESETSINSPOECTOR BROWSER-05: inspector resets on selected remove.
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState));
            rowBtns = testCase.findRowButtons();
            testCase.assertGreaterThanOrEqual(numel(rowBtns), 2, ...
                'BROWSER-05: need at least 2 row buttons');
            feval(rowBtns(2).ButtonPushedFcn, [], []);
            drawnow;
            testCase.App.removeDashboard(testCase.Engines{2}.Name);
            drawnow;
            s = struct(testCase.App);
            testCase.verifyEqual(s.SelectedDashboardIdx_, 0, ...
                'BROWSER-05: SelectedDashboardIdx_ must reset to 0 after removing selected dashboard');
            testCase.verifyEqual(s.LastInteraction_, '', ...
                'BROWSER-05: LastInteraction_ must reset to empty after removing selected dashboard');
        end

        % ---- Cross-cutting safety ----

        function testCrossCutting_noOrphanTimersAfterClose(testCase)
        %TESTCROSSCUTTING_NOORPHANTIMERSSAFTERCLOSE No debounce timers leaked after close().
            sf = testCase.findDashboardSearch();
            sf.Value = 'reactor';
            feval(sf.ValueChangedFcn, [], []);
            drawnow;
            nBefore = numel(timerfindall);
            testCase.App.close();
            nAfter = numel(timerfindall);
            testCase.assertLessThanOrEqual(nAfter, nBefore, ...
                'cross-cutting: close() must not leave orphan timers');
            % Reset so addTeardown does not double-close
            testCase.App = FastSenseCompanion('Dashboards', testCase.Engines, 'Theme', 'dark');
        end

        function testCrossCutting_listenersClearedOnPaneDetach(testCase)
        %TESTCROSSCUTTING_LISTENERSCLEAREDONPANEDETACH Listeners_ cell is empty after detach().
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState));
            sApp = struct(testCase.App);
            pane = sApp.ListPane_;
            pane.detach();
            sPaneAfter = struct(pane);
            testCase.verifyEmpty(sPaneAfter.Listeners_, ...
                'cross-cutting: Listeners_ must be empty after detach()');
        end

        function testCrossCutting_noBannedHandlesInDashboardListPane(testCase)
        %TESTCROSSCUTTING_NOBANNEDHANDLESINDASHBOARDLISTPANE No implicit-handle calls in source.
            src = fileread(which('DashboardListPane'));
            testCase.verifyEmpty(regexp(src, '\bgcf\b|\bgca\b', 'once'), ...
                'cross-cutting: implicit handle call found in DashboardListPane.m');
        end

    end

end
