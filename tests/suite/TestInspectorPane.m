classdef TestInspectorPane < matlab.unittest.TestCase
%TESTINSPECTORPANE Class-based tests for InspectorPane (Phase 1021).
%   MATLAB-only (uses uifigure). Skipped on Octave.
%   Exercises INSPECT-01 through INSPECT-06 plus cross-cutting checks
%   (sparkline-via-axes contract, namespaced errors, event payloads).
%
%   Uses findall on the companion uifigure plus struct(app) hack to read
%   private state when public API does not expose it.
%
%   See also InspectorPane, FastSenseCompanion, inspectorResolveState,
%            InspectorStateEventData, AdHocPlotEventData, TestDashboardListPane.

    properties
        App      = []   % FastSenseCompanion handle; reset each test
        Engines  = {}   % cell of DashboardEngine handles created in setup
        TagKeys  = {}   % cellstr of tag keys registered in setup
        AdHocReceived = struct('Fired', false)  % for Plot event capture
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
                'TestInspectorPane: MATLAB-only, skipping on Octave.');
            TagRegistry.clear();
            testCase.registerFixtures();
            testCase.Engines = { ...
                DashboardEngine('Reactor View'), ...
                DashboardEngine('Cooling Loop') };
            testCase.App = FastSenseCompanion( ...
                'Dashboards', testCase.Engines, 'Theme', 'dark', ...
                'Name', 'Companion Test');
            testCase.AdHocReceived = struct('Fired', false);
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
            testCase.App     = [];
            testCase.Engines = {};
            testCase.TagKeys = {};
        end

        function registerFixtures(testCase)
            %REGISTERFIXTURES Populate TagRegistry with 2 deterministic test tags.
            t1 = SensorTag('alpha_press', 'Name', 'Alpha Pressure', ...
                'X', 1:5, 'Y', [10 11 12 11 10], ...
                'Description', 'Alpha pressure sensor', ...
                'Labels', {'Reactor'}, 'Criticality', 'high');
            TagRegistry.register('alpha_press', t1);
            t2 = SensorTag('beta_flow', 'Name', 'Beta Flow', ...
                'X', 1:5, 'Y', [1 2 3 4 5], ...
                'Description', 'Beta flow rate', ...
                'Labels', {'Reactor'}, 'Criticality', 'medium');
            TagRegistry.register('beta_flow', t2);
            testCase.TagKeys = {'alpha_press', 'beta_flow'};
        end

        function hFig = findFig(testCase)
            %FINDFIG Locate the companion uifigure by name.
            hFig = findobj(groot, 'Type', 'figure', 'Name', 'Companion Test');
            if isempty(hFig)
                hFig = findobj(groot, '-regexp', 'Name', 'Companion');
            end
            testCase.assertNotEmpty(hFig, 'companion uifigure not found');
            hFig = hFig(1);
        end

        function pane = inspectorPane(testCase)
            %INSPECTORPANE Access the InspectorPane_ via struct hack.
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState));
            s = struct(testCase.App);
            pane = s.InspectorPane_;
            testCase.assertNotEmpty(pane, 'InspectorPane_ not found on app');
        end

        function btns = findButtonsByText(testCase, txt)
            %FINDBUTTONSBYTEXT Find all uibuttons whose Text matches txt.
            hFig = testCase.findFig();
            allBtns = findall(hFig, '-isa', 'matlab.ui.control.Button');
            btns = matlab.ui.control.Button.empty;
            for i = 1:numel(allBtns)
                if strcmp(allBtns(i).Text, txt)
                    btns(end+1) = allBtns(i); %#ok<AGROW>
                end
            end
        end

        function selectTagsViaCatalog(testCase, keys)
            %SELECTTAGSVIACATALOG Drive selection through the catalog pane listbox.
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState));
            s = struct(testCase.App);
            catalog = s.CatalogPane_;
            cs = struct(catalog);
            lb = cs.hListbox_;
            lb.Value = keys;
            feval(lb.ValueChangedFcn, [], []);
            drawnow;
        end

        function rs = currentInspectorState(testCase)
            %CURRENTINSPECTORSTATE Read State_ from InspectorPane via struct hack.
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState));
            ps = struct(testCase.inspectorPane());
            rs = ps.State_;
        end

        function captureAdHoc_(testCase, ed)
            %CAPTUREADHOC_ Callback for OpenAdHocPlotRequested event capture.
            testCase.AdHocReceived = struct( ...
                'TagKeys', {ed.TagKeys}, 'Mode', ed.Mode, 'Fired', true);
        end

    end

    % ==================================================================
    methods (Test)

        % ---- INSPECT-01: Welcome state on construction ----

        function testINSPECT01_welcomeStateOnConstruction(testCase)
        %TESTINSPECT01_WELCOMESTATECONSTRUCTION INSPECT-01: initial state must be welcome.
            testCase.verifyEqual(testCase.currentInspectorState(), 'welcome', ...
                'INSPECT-01: initial state must be welcome');
            hFig = testCase.findFig();
            lbls = findall(hFig, '-isa', 'matlab.ui.control.Label');
            hintTexts = arrayfun(@(L) L.Text, lbls, 'UniformOutput', false);
            testCase.verifyTrue(any(strcmp(hintTexts, 'Select a tag for details')), ...
                'INSPECT-01: hint 1 missing');
            testCase.verifyTrue(any(strcmp(hintTexts, 'Click a dashboard row for summary')), ...
                'INSPECT-01: hint 2 missing');
            testCase.verifyTrue(any(strcmp(hintTexts, 'Select 2+ tags to compose a plot')), ...
                'INSPECT-01: hint 3 missing');
        end

        % ---- INSPECT-02: Tag state renders metadata and axes ----

        function testINSPECT02_tagStateRendersMetadataAndAxes(testCase)
        %TESTINSPECT02_TAGSTATERENDERSMETA INSPECT-02: single tag -> tag state + classical axes.
            testCase.selectTagsViaCatalog({'alpha_press'});
            drawnow;
            testCase.verifyEqual(testCase.currentInspectorState(), 'tag', ...
                'INSPECT-02: 1 tag selected must produce tag state');
            hFig = testCase.findFig();
            ax = findall(hFig, '-isa', 'matlab.graphics.axis.Axes');
            testCase.verifyNotEmpty(ax, 'INSPECT-02: tag state must contain a classical axes');
            uiAx = findall(hFig, '-isa', 'matlab.ui.control.UIAxes');
            testCase.verifyEmpty(uiAx, ...
                'INSPECT-02: tag state must NOT use ui-axes (REQ-locked: classical axes only)');
            openBtns = testCase.findButtonsByText('Open Detail');
            testCase.verifyNumElements(openBtns, 1, ...
                'INSPECT-02: tag state must show exactly 1 Open Detail button');
        end

        function testINSPECT02_metadataRowsCarryTagFields(testCase)
        %TESTINSPECT02_METADATAROWSCARRYTAGFIELDS INSPECT-02: tag fields appear as value labels.
            testCase.selectTagsViaCatalog({'alpha_press'});
            drawnow;
            hFig = testCase.findFig();
            lbls = findall(hFig, '-isa', 'matlab.ui.control.Label');
            texts = arrayfun(@(L) L.Text, lbls, 'UniformOutput', false);
            testCase.verifyTrue(any(strcmp(texts, 'alpha_press')), ...
                'INSPECT-02: Key value label must be present');
            testCase.verifyTrue(any(strcmp(texts, 'Alpha Pressure')), ...
                'INSPECT-02: Name value label must be present');
            testCase.verifyTrue(any(strcmp(texts, 'high')), ...
                'INSPECT-02: Criticality value label must be present');
        end

        function testINSPECT02_openDetailButtonDoesNotCrash(testCase)
        %TESTINSPECT02_OPENDETAILBUTTONDOESNOTCRASH INSPECT-02: Open Detail click must not crash.
            testCase.selectTagsViaCatalog({'alpha_press'});
            drawnow;
            openBtn = testCase.findButtonsByText('Open Detail');
            testCase.assertNotEmpty(openBtn, 'INSPECT-02: Open Detail button not found');
            feval(openBtn(1).ButtonPushedFcn, [], []);
            drawnow;
            testCase.verifyTrue(testCase.App.IsOpen, ...
                'INSPECT-02: Open Detail click must not close the companion');
            % Cleanup any spawned classical figures so subsequent tests are not polluted.
            cf = findobj(groot, 'Type', 'figure');
            keep = arrayfun(@(f) strcmp(f.Name, 'Companion Test'), cf);
            delete(cf(~keep));
        end

        % ---- INSPECT-03: Dashboard state renders title and Play/Pause buttons ----

        function testINSPECT03_dashboardStateRendersTitleAndButtons(testCase)
        %TESTINSPECT03_DASHBOARDSTATERENDERSTITLE INSPECT-03: dashboard click -> dashboard state.
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState));
            s = struct(testCase.App);
            list = s.ListPane_;
            ls = struct(list);
            testCase.assertNotEmpty(ls.hRowButtons_, ...
                'INSPECT-03: no row buttons found in ListPane_');
            feval(ls.hRowButtons_{1}.ButtonPushedFcn, [], []);
            drawnow;
            testCase.verifyEqual(testCase.currentInspectorState(), 'dashboard', ...
                'INSPECT-03: dashboard click must produce dashboard state');
            hFig = testCase.findFig();
            lbls = findall(hFig, '-isa', 'matlab.ui.control.Label');
            texts = arrayfun(@(L) L.Text, lbls, 'UniformOutput', false);
            testCase.verifyTrue(any(strcmp(texts, 'Reactor View')), ...
                'INSPECT-03: dashboard title must be present');
            playBtns  = testCase.findButtonsByText([char(9654) ' Play']);
            pauseGlyph = [char(9646) char(9646) ' Pause'];
            pauseBtns = testCase.findButtonsByText(pauseGlyph);
            testCase.verifyNumElements(playBtns, 1, 'INSPECT-03: Play button missing');
            testCase.verifyNumElements(pauseBtns, 1, 'INSPECT-03: Pause button missing');
        end

        function testINSPECT03_playButtonStartsLive(testCase)
        %TESTINSPECT03_PLAYBUTTONSTARTSLIVE INSPECT-03: Play click calls dashboard.startLive().
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState));
            s = struct(testCase.App);
            list = s.ListPane_;
            ls = struct(list);
            feval(ls.hRowButtons_{1}.ButtonPushedFcn, [], []);
            drawnow;
            d = testCase.Engines{1};
            testCase.assertFalse(d.IsLive, 'precondition: dashboard must start idle');
            playBtns = testCase.findButtonsByText([char(9654) ' Play']);
            testCase.assertNotEmpty(playBtns, 'INSPECT-03: Play button not found');
            feval(playBtns(1).ButtonPushedFcn, [], []);
            drawnow;
            testCase.verifyTrue(d.IsLive, ...
                'INSPECT-03: Play click must call dashboard.startLive()');
            d.stopLive();   % cleanup so other tests start fresh
        end

        % ---- INSPECT-04: Multitag state renders chips and Plot button ----

        function testINSPECT04_multitagStateRendersChips(testCase)
        %TESTINSPECT04_MULTITAGSTATERENDERS INSPECT-04: 2 tags -> multitag state + chips + Plot.
            testCase.selectTagsViaCatalog(testCase.TagKeys);
            drawnow;
            testCase.verifyEqual(testCase.currentInspectorState(), 'multitag', ...
                'INSPECT-04: 2 tags selected must produce multitag state');
            plotBtns = testCase.findButtonsByText('Plot');
            testCase.verifyNumElements(plotBtns, 1, ...
                'INSPECT-04: multitag state must show exactly 1 Plot button');
            xBtns = testCase.findButtonsByText(char(215));
            % Find chip x buttons by tooltip prefix 'Remove '
            chipXs = matlab.ui.control.Button.empty;
            for i = 1:numel(xBtns)
                if ~isempty(strfind(xBtns(i).Tooltip, 'Remove '))
                    chipXs(end+1) = xBtns(i); %#ok<AGROW>
                end
            end
            testCase.verifyGreaterThanOrEqual(numel(chipXs), 2, ...
                'INSPECT-04: multitag state must show >=2 chip x buttons');
        end

        function testINSPECT04_chipDeselectRemovesChip(testCase)
        %TESTINSPECT04_CHIPDESELECTREMOVESCHIP INSPECT-04: x click removes chip + transitions.
            testCase.selectTagsViaCatalog(testCase.TagKeys);
            drawnow;
            xBtns = testCase.findButtonsByText(char(215));
            chipXs = matlab.ui.control.Button.empty;
            for i = 1:numel(xBtns)
                if ~isempty(strfind(xBtns(i).Tooltip, 'Remove '))
                    chipXs(end+1) = xBtns(i); %#ok<AGROW>
                end
            end
            testCase.assertNumElements(chipXs, 2, ...
                'INSPECT-04: must have exactly 2 chip x buttons before deselect');
            feval(chipXs(1).ButtonPushedFcn, [], []);
            drawnow;
            testCase.verifyEqual(testCase.currentInspectorState(), 'tag', ...
                'INSPECT-04: deselecting one of two chips must transition to tag state');
        end

        function testINSPECT04_plotButtonFiresEventWithPayload(testCase)
        %TESTINSPECT04_PLOTBUTTONFIRESEVENT INSPECT-04: Plot fires OpenAdHocPlotRequested.
            testCase.selectTagsViaCatalog(testCase.TagKeys);
            drawnow;
            lh = addlistener(testCase.App, 'OpenAdHocPlotRequested', ...
                @(~, ed) testCase.captureAdHoc_(ed));
            cleanup = onCleanup(@() delete(lh));
            plotBtns = testCase.findButtonsByText('Plot');
            testCase.assertNotEmpty(plotBtns, 'INSPECT-04: Plot button not found');
            feval(plotBtns(1).ButtonPushedFcn, [], []);
            drawnow;
            testCase.verifyTrue(testCase.AdHocReceived.Fired, ...
                'INSPECT-04: Plot click must fire OpenAdHocPlotRequested');
            testCase.verifyEqual(numel(testCase.AdHocReceived.TagKeys), 2, ...
                'INSPECT-04: payload must carry 2 tag keys');
            testCase.verifyEqual(testCase.AdHocReceived.Mode, 'Overlay', ...
                'INSPECT-04: default composer mode must be Overlay');
        end

        % ---- INSPECT-05: Routing flips on tag select after dashboard ----

        function testINSPECT05_routingFlipsOnTagSelectAfterDashboard(testCase)
        %TESTINSPECT05_ROUTINGFLIPSTAG INSPECT-05: tag select after dashboard flips to tag state.
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState));
            s = struct(testCase.App);
            list = s.ListPane_;
            ls = struct(list);
            feval(ls.hRowButtons_{1}.ButtonPushedFcn, [], []);
            drawnow;
            testCase.assertEqual(testCase.currentInspectorState(), 'dashboard', ...
                'INSPECT-05 precondition: dashboard click must produce dashboard state');
            testCase.selectTagsViaCatalog({'alpha_press'});
            drawnow;
            testCase.verifyEqual(testCase.currentInspectorState(), 'tag', ...
                'INSPECT-05: selecting 1 tag after dashboard click must flip back to tag state');
        end

        % ---- INSPECT-06: Sparkline failure falls back to label ----

        function testINSPECT06_sparklineFailureFallsBackToLabel(testCase)
        %TESTINSPECT06_SPARKLINEFAILURE INSPECT-06: broken getXY -> 'Sparkline unavailable'.
            mock = MockTagThrowingGetXY('mock_throws', 'Name', 'Mock Throws', ...
                'X', 1:5, 'Y', 1:5, 'Description', 'Test mock', ...
                'Labels', {'Test'}, 'Criticality', 'low');
            TagRegistry.register('mock_throws', mock);
            testCase.App.refreshCatalog();
            drawnow;
            testCase.selectTagsViaCatalog({'mock_throws'});
            drawnow;
            hFig = testCase.findFig();
            lbls = findall(hFig, '-isa', 'matlab.ui.control.Label');
            texts = arrayfun(@(L) L.Text, lbls, 'UniformOutput', false);
            testCase.verifyTrue(any(strcmp(texts, 'Sparkline unavailable')), ...
                'INSPECT-06: sparkline failure must show fallback label');
            testCase.verifyTrue(testCase.App.IsOpen, ...
                'INSPECT-06: companion must stay open on sparkline failure');
        end

        % ---- Cross-cutting: sparkline-via-classical-axes contract enforced statically ----

        function testCrossCutting_noUiaxesInInspectorFile(testCase)
        %TESTCROSSCUTTING_NOUIAXES Cross-cutting: classical axes used (no ui-axes) in source.
            src = fileread(which('InspectorPane'));
            testCase.verifyEmpty(regexp(src, '\buiaxes\b', 'once'), ...
                'cross-cutting: forbidden axes type found in InspectorPane.m (REQ: classical axes)');
        end

        function testCrossCutting_axesParentUipanelInInspectorFile(testCase)
        %TESTCROSSCUTTING_AXESPARENTUIPANEL Cross-cutting: axes('Parent', ...) used in source.
            src = fileread(which('InspectorPane'));
            testCase.verifyNotEmpty(regexp(src, "axes\\('Parent'", 'once'), ...
                'cross-cutting: InspectorPane.m must use axes(''Parent'', ...) for sparkline');
        end

        function testCrossCutting_listenersClearedOnPaneDetach(testCase)
        %TESTCROSSCUTTING_LISTENERSCLEAREDONPANEDETACH Listeners_ empty after detach().
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState));
            pane = testCase.inspectorPane();
            pane.detach();
            ps = struct(pane);
            testCase.verifyEmpty(ps.Listeners_, ...
                'cross-cutting: Listeners_ must be empty after detach');
        end

    end

end
