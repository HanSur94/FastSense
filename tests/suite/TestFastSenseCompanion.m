classdef TestFastSenseCompanion < matlab.unittest.TestCase
%TESTFASTSENSECOMPANION Class-based tests for FastSenseCompanion shell (Phase 1018).
%   Covers COMPSHELL-01 through COMPSHELL-06.
%   All uifigure windows are created with default visibility; addTeardown
%   ensures cleanup even on failure.
%
%   See also FastSenseCompanion, run_all_tests.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function skipOnOctave(testCase)
            % FastSenseCompanion is MATLAB-only. Skip entire suite on Octave.
            testCase.assumeFalse( ...
                exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestFastSenseCompanion: skipped on Octave (uifigure not available)');
        end
    end

    methods (Test)

        % ---- COMPSHELL-01: Constructor argument handling ----

        function testConstructorNoArgs(testCase)
            %TESTCONSTRUCTORNOARGS Default construction succeeds; IsOpen is true.
            app = FastSenseCompanion();
            testCase.addTeardown(@() app.close());
            testCase.verifyTrue(isvalid(app), ...
                'testConstructorNoArgs: app must be valid after construction');
            testCase.verifyTrue(app.IsOpen, ...
                'testConstructorNoArgs: IsOpen must be true after construction');
        end

        function testConstructorWithDashboards(testCase)
            %TESTCONSTRUCTORWITHDASHBOARDS Two valid DashboardEngine entries are stored.
            d1 = DashboardEngine('Test1');
            d2 = DashboardEngine('Test2');
            app = FastSenseCompanion('Dashboards', {d1, d2}, 'Theme', 'dark');
            testCase.addTeardown(@() app.close());
            testCase.verifyEqual(numel(app.Dashboards), 2, ...
                'testConstructorWithDashboards: expected 2 dashboards stored');
        end

        function testConstructorThemeLightPreset(testCase)
            %TESTCONSTRUCTORTHMELIGHTPRESET Theme property reflects the supplied preset.
            app = FastSenseCompanion('Theme', 'light');
            testCase.addTeardown(@() app.close());
            testCase.verifyEqual(app.Theme, 'light', ...
                'testConstructorThemeLightPreset: Theme property must reflect light preset');
        end

        function testUnknownOptionThrows(testCase)
            %TESTUNKNOWNOPTIONTHROWS Unknown key -> FastSenseCompanion:unknownOption
            % COMPSHELL-01
            testCase.verifyError( ...
                @() FastSenseCompanion('NotAKey', 'value'), ...
                'FastSenseCompanion:unknownOption', ...
                'testUnknownOptionThrows: wrong error ID for unknown key');
        end

        function testInvalidDashboardThrows(testCase)
            %TESTINVALIDDASHBOARDTHROWS Non-DashboardEngine -> FastSenseCompanion:invalidDashboard
            % COMPSHELL-01
            testCase.verifyError( ...
                @() FastSenseCompanion('Dashboards', {struct('x', 1)}), ...
                'FastSenseCompanion:invalidDashboard', ...
                'testInvalidDashboardThrows: wrong error ID for invalid dashboard');
        end

        function testInvalidDashboardIndexInMessage(testCase)
            %TESTINVALIDDASHBOARDINDEXINMESSAGE Offending index appears in error message.
            % COMPSHELL-01
            try
                FastSenseCompanion('Dashboards', {DashboardEngine('ok'), 42});
                testCase.verifyFail('testInvalidDashboardIndexInMessage: should have thrown');
            catch e
                testCase.verifyEqual(e.identifier, 'FastSenseCompanion:invalidDashboard', ...
                    'testInvalidDashboardIndexInMessage: wrong error ID');
                testCase.verifyTrue( ...
                    ~isempty(strfind(e.message, '2')), ...
                    'testInvalidDashboardIndexInMessage: message must contain offending index 2');
            end
        end

        % ---- COMPSHELL-02: uifigure opens immediately ----

        function testUifigureCreatedImmediately(testCase)
            %TESTUIFIGURECREATEDIMMEDIATELY No separate render() call required; IsOpen true.
            % COMPSHELL-02
            app = FastSenseCompanion();
            testCase.addTeardown(@() app.close());
            testCase.verifyTrue(app.IsOpen, ...
                'testUifigureCreatedImmediately: IsOpen must be true right after construction');
        end

        function testThreePanelsExist(testCase)
            %TESTTHREEPANELSEXIST Three pane panels exist and are valid after construction.
            % COMPSHELL-02: three panes created immediately
            app = FastSenseCompanion();
            testCase.addTeardown(@() app.close());
            % Access private fields via struct() — standard MATLAB unittest practice
            s = struct(app);
            testCase.verifyTrue(isvalid(s.hLeftPanel_), ...
                'testThreePanelsExist: hLeftPanel_ must be valid');
            testCase.verifyTrue(isvalid(s.hMidPanel_), ...
                'testThreePanelsExist: hMidPanel_ must be valid');
            testCase.verifyTrue(isvalid(s.hRightPanel_), ...
                'testThreePanelsExist: hRightPanel_ must be valid');
        end

        % ---- COMPSHELL-03: close() lifecycle ----

        function testCloseCleanup(testCase)
            %TESTCLOSECLEANUP close() sets IsOpen false; timer count unchanged.
            % COMPSHELL-03
            timersBefore = numel(timerfindall);
            app = FastSenseCompanion();
            app.close();
            testCase.verifyFalse(app.IsOpen, ...
                'testCloseCleanup: IsOpen must be false after close()');
            testCase.verifyEqual(numel(timerfindall), timersBefore, ...
                'testCloseCleanup: timerfindall count must be unchanged after close()');
        end

        function testCloseIdempotent(testCase)
            %TESTCLOSEIDEMPOTENT Second close() call must not throw.
            % COMPSHELL-03
            app = FastSenseCompanion();
            app.close();
            % Second call must be a no-op, not an error
            app.close();
            testCase.verifyFalse(app.IsOpen, ...
                'testCloseIdempotent: IsOpen should remain false after double close');
        end

        function testCloseDoesNotAffectDashboards(testCase)
            %TESTCLOSEDOESNOTAFFECTDASHBOARDS Closing companion does NOT close dashboard figures.
            % COMPSHELL-03: companion close() must not affect DashboardEngine figures
            d = DashboardEngine('CloseTest');
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            app = FastSenseCompanion('Dashboards', {d});
            app.close();
            % Dashboard figure must still be open and valid
            testCase.verifyTrue(isvalid(d.hFigure), ...
                'testCloseDoesNotAffectDashboards: dashboard figure must survive companion close');
        end

        % ---- COMPSHELL-04: Octave guard code is present ----

        function testOctaveGuardCodePresent(testCase)
            %TESTOCTAVEGUARDCODEPRESENT Octave guard code exists in FastSenseCompanion source.
            % COMPSHELL-04: we cannot execute the guard on MATLAB, so verify textually
            src = fileread(which('FastSenseCompanion'));
            testCase.verifyTrue( ...
                ~isempty(strfind(src, 'OCTAVE_VERSION')), ...
                'testOctaveGuardCodePresent: OCTAVE_VERSION check missing from source');
            testCase.verifyTrue( ...
                ~isempty(strfind(src, 'FastSenseCompanion:notSupported')), ...
                'testOctaveGuardCodePresent: notSupported error ID missing from source');
        end

        % ---- COMPSHELL-05: setProject replaces state without uifigure recreation ----

        function testSetProjectReplacesState(testCase)
            %TESTSETPROJECTREPLACESSTATE setProject replaces internal state; uifigure survives.
            % COMPSHELL-05
            d1 = DashboardEngine('Original');
            d2 = DashboardEngine('Replacement');
            app = FastSenseCompanion('Dashboards', {d1});
            testCase.addTeardown(@() app.close());
            s = struct(app);
            figBefore = s.hFig_;
            app.setProject({d2}, TagRegistry);
            testCase.verifyEqual(numel(app.Dashboards), 1, ...
                'testSetProjectReplacesState: should have 1 dashboard after setProject');
            testCase.verifyEqual(app.Dashboards{1}.Name, 'Replacement', ...
                'testSetProjectReplacesState: Dashboards should contain the new engine');
            % uifigure must NOT have been recreated — same handle
            s2 = struct(app);
            testCase.verifyEqual(s.hFig_, s2.hFig_, ...
                'testSetProjectReplacesState: uifigure handle must be the same object after setProject');
        end

        function testSetProjectInvalidDashboardThrows(testCase)
            %TESTSETPROJECTINVALIDDASHBOARDTHROWS setProject validates dashboards same as constructor.
            % COMPSHELL-05
            app = FastSenseCompanion();
            testCase.addTeardown(@() app.close());
            testCase.verifyError( ...
                @() app.setProject({99}, TagRegistry), ...
                'FastSenseCompanion:invalidDashboard', ...
                'testSetProjectInvalidDashboardThrows: wrong error ID for invalid dashboard in setProject');
        end

        % ---- COMPSHELL-06: no gcf/gca in source files ----

        function testNoGcfGcaInSource(testCase)
            %TESTNOGCFGCAINSOURCE No gcf or gca present in any FastSenseCompanion source file.
            % COMPSHELL-06: companion must reference obj.hFig_ exclusively, never gcf/gca
            companionDir = fileparts(which('FastSenseCompanion'));
            files = dir(fullfile(companionDir, '*.m'));
            for i = 1:numel(files)
                src = fileread(fullfile(companionDir, files(i).name));
                testCase.verifyTrue( ...
                    isempty(regexp(src, '\bgcf\b|\bgca\b', 'once')), ...
                    sprintf('testNoGcfGcaInSource: gcf or gca found in %s', files(i).name));
            end
        end

        % ---- Phase 1020 BROWSER-05: addDashboard / removeDashboard ----

        function testAddDashboardAppendsToBrowser(testCase)
        %TESTADDDASHBOARDAPPENDSTOBROWSER BROWSER-05: addDashboard adds engine to public list.
            d1 = DashboardEngine('Fixture1');
            d2 = DashboardEngine('Fixture2');
            app = FastSenseCompanion('Dashboards', {d1, d2}, 'Theme', 'dark');
            testCase.addTeardown(@() app.close());
            nBefore = numel(app.Dashboards);
            d = DashboardEngine('NewBoard');
            app.addDashboard(d);
            testCase.verifyEqual(numel(app.Dashboards), nBefore + 1, ...
                'addDashboard: Dashboards count must be nBefore + 1');
            % Stronger: verify the new engine handle appears in the list
            found = false;
            for i = 1:numel(app.Dashboards)
                if app.Dashboards{i} == d
                    found = true;
                    break;
                end
            end
            testCase.verifyTrue(found, ...
                'BROWSER-05: appended DashboardEngine must be present in app.Dashboards');
        end

        function testAddDashboardRejectsNonDashboardEngine(testCase)
        %TESTADDDASHBOARDREJECTSNONDASHBOARDENGINE BROWSER-05: addDashboard validates type.
            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() app.close());
            testCase.verifyError(@() app.addDashboard(struct('Name', 'x')), ...
                'FastSenseCompanion:invalidDashboard');
        end

        function testAddDashboardRejectsDuplicateHandle(testCase)
        %TESTADDDASHBOARDREJECTSDUPLICATEHANDLE BROWSER-05: addDashboard rejects same handle twice.
            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() app.close());
            d = DashboardEngine('OnceOnly');
            app.addDashboard(d);
            testCase.verifyError(@() app.addDashboard(d), ...
                'FastSenseCompanion:duplicateDashboard');
        end

        function testRemoveDashboardDropsByName(testCase)
        %TESTREMOVEDASHBOARDDROPSBYNAME BROWSER-05: removeDashboard drops engine by Name match.
            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() app.close());
            d = DashboardEngine('ToRemove');
            app.addDashboard(d);
            nBefore = numel(app.Dashboards);
            app.removeDashboard('ToRemove');
            nAfter = numel(app.Dashboards);
            testCase.verifyEqual(nAfter, nBefore - 1, ...
                'BROWSER-05: removeDashboard must reduce Dashboards count by 1');
        end

        function testRemoveDashboardThrowsOnUnknown(testCase)
        %TESTREMOVEDASHBOARDTHROWSONUNKNOWN BROWSER-05: removeDashboard throws on missing key.
            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() app.close());
            testCase.verifyError(@() app.removeDashboard('NoSuchKey'), ...
                'FastSenseCompanion:dashboardNotFound');
        end

        function testRemoveDashboardThrowsOnNonChar(testCase)
        %TESTREMOVEDASHBOARDTHROWSONNONCHAR BROWSER-05: removeDashboard rejects non-char input.
            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() app.close());
            testCase.verifyError(@() app.removeDashboard(42), ...
                'FastSenseCompanion:dashboardNotFound');
        end

        % ---- Phase 1021: InspectorStateChanged event firing tests ----

        function testInspectorStateChangedFiresOnDashboardClick(testCase)
        %TESTINSPECTORSTATECHANGEDFIRESONDASBOARDCLICK Phase 1021: event fires on dashboard click.
            d = DashboardEngine('TestDash1021');
            app = FastSenseCompanion('Dashboards', {d}, 'Theme', 'dark');
            testCase.addTeardown(@() app.close());
            drawnow;
            received = struct('Fired', false, 'State', '');
            cb = @(~, ed) assignField(ed);
            function assignField(ed)
                received.State = ed.State;
                received.Fired = true;
            end
            lh = addlistener(app, 'InspectorStateChanged', cb);
            cleanupL = onCleanup(@() delete(lh));
            % Drive a dashboard row click via struct hack
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanupW = onCleanup(@() warning(warnState));
            s = struct(app);
            ls = struct(s.ListPane_);
            testCase.assertNotEmpty(ls.hRowButtons_, ...
                'Phase 1021: no row buttons found in ListPane_');
            feval(ls.hRowButtons_{1}.ButtonPushedFcn, [], []);
            drawnow;
            testCase.verifyTrue(received.Fired, ...
                'Phase 1021: InspectorStateChanged must fire on dashboard click');
            testCase.verifyEqual(received.State, 'dashboard', ...
                'Phase 1021: dashboard click must produce state=dashboard');
        end

        function testInspectorStateChangedFiresWelcomeOnNothing(testCase)
        %TESTINSPECTORSTATECHANGEDFIRESWEOLCOMEONNOTHING Phase 1021: welcome state on remove.
            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() app.close());
            received = struct('Fired', false, 'State', '');
            cb = @(~, ed) assignField(ed);
            function assignField(ed)
                received.State = ed.State;
                received.Fired = true;
            end
            lh = addlistener(app, 'InspectorStateChanged', cb);
            cleanupL = onCleanup(@() delete(lh));
            % Add a dashboard and select it via row click
            d = DashboardEngine('Tmp1021');
            app.addDashboard(d);
            drawnow;
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanupW = onCleanup(@() warning(warnState));
            s = struct(app);
            ls = struct(s.ListPane_);
            % Click the row to select the dashboard
            feval(ls.hRowButtons_{end}.ButtonPushedFcn, [], []);
            drawnow;
            % Reset flag so we capture the post-remove fire
            received.Fired = false;
            received.State = '';
            app.removeDashboard('Tmp1021');
            drawnow;
            testCase.verifyTrue(received.Fired, ...
                'Phase 1021: removeDashboard of selected must fire InspectorStateChanged');
            testCase.verifyEqual(received.State, 'welcome', ...
                'Phase 1021: removing the selected dashboard must produce state=welcome');
        end

        function testOpenAdHocPlotRequestedEventFires(testCase)
        %TESTOPENADHOCPLOTREQUESTEDEVENTFIRES Phase 1021: Plot click fires OpenAdHocPlotRequested.
            TagRegistry.clear();
            t1 = SensorTag('ta1021', 'Name', 'Tag A', 'X', 1:3, 'Y', 1:3, ...
                'Labels', {'L'}, 'Criticality', 'low');
            TagRegistry.register('ta1021', t1);
            t2 = SensorTag('tb1021', 'Name', 'Tag B', 'X', 1:3, 'Y', 1:3, ...
                'Labels', {'L'}, 'Criticality', 'low');
            TagRegistry.register('tb1021', t2);
            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() app.close());
            testCase.addTeardown(@() TagRegistry.clear());
            drawnow;
            received = struct('TagKeys', {{}}, 'Mode', '', 'Fired', false);
            cb = @(~, ed) assignField(ed);
            function assignField(ed)
                received.TagKeys = ed.TagKeys;
                received.Mode    = ed.Mode;
                received.Fired   = true;
            end
            lh = addlistener(app, 'OpenAdHocPlotRequested', cb);
            cleanupL = onCleanup(@() delete(lh));
            % Drive 2-tag selection via catalog listbox struct hack
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanupW = onCleanup(@() warning(warnState));
            s = struct(app);
            cs = struct(s.CatalogPane_);
            cs.hListbox_.Value = {'ta1021', 'tb1021'};
            feval(cs.hListbox_.ValueChangedFcn, [], []);
            drawnow;
            % Find Plot button and click
            hFig = findobj(groot, 'Type', 'figure', 'Name', 'FastSense Companion');
            if isempty(hFig)
                hFig = findobj(groot, '-regexp', 'Name', 'FastSense Companion');
            end
            testCase.assertNotEmpty(hFig, 'Phase 1021: companion figure not found');
            allBtns = findall(hFig(1), '-isa', 'matlab.ui.control.Button');
            plotBtn = [];
            for i = 1:numel(allBtns)
                if strcmp(allBtns(i).Text, 'Plot')
                    plotBtn = allBtns(i);
                    break;
                end
            end
            testCase.assertNotEmpty(plotBtn, 'Phase 1021: Plot button not found in multitag state');
            feval(plotBtn.ButtonPushedFcn, [], []);
            drawnow;
            testCase.verifyTrue(received.Fired, ...
                'Phase 1021: Plot click must fire OpenAdHocPlotRequested');
            testCase.verifyEqual(numel(received.TagKeys), 2, ...
                'Phase 1021: payload must carry 2 tag keys');
            testCase.verifyEqual(received.Mode, 'Overlay', ...
                'Phase 1021: default mode must be Overlay');
        end

        % ---- Phase 1022: ADHOC end-to-end Plot button tests ----

        function testADHOC02_overlayPlotSpawnsClassicalFigure(testCase)
        %TESTADHOC02_OVERLAYPLOTSPAWNSCLASSICALFIGURE ADHOC-02: Overlay mode spawns classical figure.
            testCase.assumeFalse(exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestFastSenseCompanion ADHOC tests are MATLAB-only.');
            TagRegistry.clear();
            TagRegistry.register('mk1', MockPlottableTag('mk1', 'Name', 'M1', ...
                'X', 1:50, 'Y', sin((1:50)/3)));
            TagRegistry.register('mk2', MockPlottableTag('mk2', 'Name', 'M2', ...
                'X', 1:50, 'Y', cos((1:50)/3)));
            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() isvalid(app) && app.IsOpen && app.close());
            app.refreshCatalog();
            drawnow;
            preFigs = findobj(groot, 'Type', 'figure');
            testCase.driveSelectAndPlot_(app, {'mk1', 'mk2'}, 'Overlay');
            drawnow;
            postFigs = findobj(groot, 'Type', 'figure');
            newFigs  = setdiff(postFigs, preFigs);
            adhocFig = testCase.findCompanionAdHocFigure_(newFigs);
            testCase.assertNotEmpty(adhocFig, ...
                'ADHOC-02: Overlay Plot click must spawn a FastSense Companion figure');
            testCase.verifyEqual(get(adhocFig, 'Type'), 'figure', ...
                'ADHOC-02: spawned must be classical figure (Type=figure)');
            testCase.addTeardown(@() testCase.cleanupAdHoc_(adhocFig));
        end

        function testADHOC03_linkedGridPlotSpawnsClassicalFigure(testCase)
        %TESTADHOC03_LINKEDGRIDPLOTSPAWNSCLASSICALFIGURE ADHOC-03: LinkedGrid mode spawns tiled figure.
            testCase.assumeFalse(exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestFastSenseCompanion ADHOC tests are MATLAB-only.');
            TagRegistry.clear();
            for i = 1:4
                k = sprintf('lg%d', i);
                TagRegistry.register(k, MockPlottableTag(k, ...
                    'Name', sprintf('LG%d', i), 'X', 1:30, 'Y', (1:30) + i));
            end
            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() isvalid(app) && app.IsOpen && app.close());
            app.refreshCatalog();
            drawnow;
            preFigs = findobj(groot, 'Type', 'figure');
            testCase.driveSelectAndPlot_(app, {'lg1', 'lg2', 'lg3', 'lg4'}, 'LinkedGrid');
            drawnow;
            postFigs = findobj(groot, 'Type', 'figure');
            newFigs  = setdiff(postFigs, preFigs);
            adhocFig = testCase.findCompanionAdHocFigure_(newFigs);
            testCase.assertNotEmpty(adhocFig, ...
                'ADHOC-03: LinkedGrid Plot click must spawn a FastSense Companion figure');
            testCase.verifyEqual(get(adhocFig, 'Type'), 'figure', ...
                'ADHOC-03: spawned must be classical figure');
            testCase.addTeardown(@() testCase.cleanupAdHoc_(adhocFig));
        end

        function testADHOC04_companionCloseDoesNotCloseSpawnedFigure(testCase)
        %TESTADHOC04_COMPANIONCLOSEDOESNOTCLOSESPAWNEDFIGURE ADHOC-04: spawned figure outlives companion.
            testCase.assumeFalse(exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestFastSenseCompanion ADHOC tests are MATLAB-only.');
            TagRegistry.clear();
            TagRegistry.register('a4', MockPlottableTag('a4', 'Name', 'A4', ...
                'X', 1:20, 'Y', 1:20));
            TagRegistry.register('b4', MockPlottableTag('b4', 'Name', 'B4', ...
                'X', 1:20, 'Y', 20:-1:1));
            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() isvalid(app) && app.IsOpen && app.close());
            app.refreshCatalog();
            drawnow;
            preFigs = findobj(groot, 'Type', 'figure');
            testCase.driveSelectAndPlot_(app, {'a4', 'b4'}, 'Overlay');
            drawnow;
            postFigs = findobj(groot, 'Type', 'figure');
            newFigs  = setdiff(postFigs, preFigs);
            adhocFig = testCase.findCompanionAdHocFigure_(newFigs);
            testCase.assertNotEmpty(adhocFig, 'ADHOC-04 precondition: spawned figure must exist');
            app.close();
            drawnow;
            testCase.verifyTrue(ishandle(adhocFig), ...
                'ADHOC-04: spawned figure handle must remain valid after companion.close()');
            testCase.verifyTrue(strcmp(get(adhocFig, 'Visible'), 'on'), ...
                'ADHOC-04: spawned figure must remain Visible=on after companion.close()');
            testCase.addTeardown(@() testCase.cleanupAdHoc_(adhocFig));
        end

        function testADHOC04_closingSpawnedFigureDoesNotCloseCompanion(testCase)
        %TESTADHOC04_CLOSINGSPAWNEDFIGUREDOESNOTCLOSECOMPANION ADHOC-04 reverse: closing spawned does not affect companion.
            testCase.assumeFalse(exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestFastSenseCompanion ADHOC tests are MATLAB-only.');
            TagRegistry.clear();
            TagRegistry.register('r1', MockPlottableTag('r1', 'Name', 'R1', ...
                'X', 1:20, 'Y', 1:20));
            TagRegistry.register('r2', MockPlottableTag('r2', 'Name', 'R2', ...
                'X', 1:20, 'Y', 20:-1:1));
            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() isvalid(app) && app.IsOpen && app.close());
            app.refreshCatalog();
            drawnow;
            preFigs = findobj(groot, 'Type', 'figure');
            testCase.driveSelectAndPlot_(app, {'r1', 'r2'}, 'Overlay');
            drawnow;
            postFigs = findobj(groot, 'Type', 'figure');
            newFigs  = setdiff(postFigs, preFigs);
            adhocFig = testCase.findCompanionAdHocFigure_(newFigs);
            testCase.assertNotEmpty(adhocFig, 'precondition: spawned figure must exist');
            delete(adhocFig);
            drawnow;
            testCase.verifyTrue(app.IsOpen, ...
                'ADHOC-04 reverse: companion.IsOpen must remain true after spawned figure closed');
        end

        function testADHOC05_noOrphanTimersAfterPlotAndClose(testCase)
        %TESTADHOC05_NOORPHANTIMERSAFTERPLOTANDCLOSE ADHOC-05: timerfindall delta is empty after spawn+close cycle.
            testCase.assumeFalse(exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestFastSenseCompanion ADHOC tests are MATLAB-only.');
            TagRegistry.clear();
            TagRegistry.register('t1', MockPlottableTag('t1', 'Name', 'T1', ...
                'X', 1:20, 'Y', 1:20));
            TagRegistry.register('t2', MockPlottableTag('t2', 'Name', 'T2', ...
                'X', 1:20, 'Y', 20:-1:1));
            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() isvalid(app) && app.IsOpen && app.close());
            app.refreshCatalog();
            drawnow;
            preTimers = timerfindall();
            preFigs   = findobj(groot, 'Type', 'figure');
            testCase.driveSelectAndPlot_(app, {'t1', 't2'}, 'Overlay');
            drawnow;
            postFigs  = findobj(groot, 'Type', 'figure');
            newFigs   = setdiff(postFigs, preFigs);
            for i = 1:numel(newFigs)
                if ishandle(newFigs(i))
                    delete(newFigs(i));
                end
            end
            app.close();
            drawnow;
            postTimers = timerfindall();
            newTimers  = setdiff(postTimers, preTimers);
            testCase.verifyEmpty(newTimers, ...
                'ADHOC-05: spawn+close cycle must leave no orphan companion-owned timers');
        end

        % ---- QUICK-LIVEUPDATES-01: scanLiveTagUpdates_ guard regression ----

        function testScanLiveTagUpdatesPopulatesTableAfterGrowth(testCase)
        %TESTSCANLIVETAGUPDATESPOPULATESTABLEAFTERGROWTH Live updates table receives a row after a SensorTag grows between two scan ticks.
        %   Regression test for the isempty(containers.Map) guard bug.
        %   Before the fix: scanLiveTagUpdates_ returned on every tick because
        %   isempty(containers.Map) is true for an empty map (chicken-and-egg).
            TagRegistry.clear();
            testCase.addTeardown(@() TagRegistry.clear());

            % Register a SensorTag with an initial 3-sample series.
            tag = SensorTag('liveupd1', 'Name', 'LiveUpd1', ...
                'X', [1 2 3], 'Y', [10 20 30], ...
                'Labels', {'L'}, 'Criticality', 'low');
            TagRegistry.register('liveupd1', tag);

            app = FastSenseCompanion('Theme', 'dark');
            testCase.addTeardown(@() app.close());
            drawnow;

            % Reach the private scan method via the live timer's TimerFcn,
            % which is a closure that DOES have private access to the method.
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanupW = onCleanup(@() warning(warnState)); %#ok<NASGU>
            s = struct(app);
            testCase.assertNotEmpty(s.LiveTimer_, ...
                'Live timer must exist after construction (Live mode defaults ON)');
            testCase.assertTrue(isa(s.LiveSampleCount_, 'containers.Map'), ...
                'LiveSampleCount_ must be a containers.Map after constructor');
            tickFcn = s.LiveTimer_.TimerFcn;

            % Tick 1: baseline — function should record n=3 for the key but NOT log a row.
            feval(tickFcn, s.LiveTimer_, []);
            drawnow;

            % Grow the tag by 2 samples.
            tag.updateData([1 2 3 4 5], [10 20 30 40 50]);

            % Tick 2: should see the delta and append a row.
            feval(tickFcn, s.LiveTimer_, []);
            drawnow;

            % Assertion: at least one row in the live-updates table.
            s2 = struct(app);
            testCase.verifyGreaterThanOrEqual(size(s2.hLiveLogTable_.Data, 1), 1, ...
                'Live updates table must contain at least one row after a SensorTag grows between two ticks');
            testCase.verifyTrue(s2.LiveSampleCount_.isKey('liveupd1'), ...
                'LiveSampleCount_ must contain the tag key after the first tick');
            testCase.verifyEqual(s2.LiveSampleCount_('liveupd1'), 5, ...
                'LiveSampleCount_(''liveupd1'') must equal 5 after the second tick');
        end

    end

    methods (Access = private)

        function driveSelectAndPlot_(testCase, app, keys, mode) %#ok<INUSL>
        %DRIVESELECTANDPLOT_ Helper: drive catalog selection then click Plot in mode.
        %   app: the FastSenseCompanion instance (passed in by each test method).
            warnState = warning('off', 'MATLAB:structOnObject');
            cleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>
            s = struct(app);
            cs = struct(s.CatalogPane_);
            cs.hListbox_.Value = keys;
            feval(cs.hListbox_.ValueChangedFcn, [], []);
            drawnow;
            ps = struct(s.InspectorPane_);
            if strcmp(mode, 'Overlay')
                feval(ps.hModeOverlay_.ButtonPushedFcn, [], []);
            else
                feval(ps.hModeLinked_.ButtonPushedFcn, [], []);
            end
            drawnow;
            feval(ps.hPlotBtn_.ButtonPushedFcn, [], []);
            drawnow;
        end

        function adhocFig = findCompanionAdHocFigure_(~, candidateFigs)
        %FINDCOMPANIONADHOCFIGURE_ Pick the figure whose Name starts with 'FastSense Companion'.
            adhocFig = matlab.ui.Figure.empty;
            for i = 1:numel(candidateFigs)
                try
                    nm = candidateFigs(i).Name;
                    if ~isempty(strfind(nm, 'FastSense Companion'))
                        adhocFig = candidateFigs(i);
                        return;
                    end
                catch
                    continue;
                end
            end
        end

        function cleanupAdHoc_(testCase, adhocFig) %#ok<INUSL>
        %CLEANUPADHOC_ Close one spawned ad-hoc figure + clear registry.
            if ~isempty(adhocFig) && ishandle(adhocFig)
                try
                    delete(adhocFig);
                catch
                    % swallow — best-effort
                end
            end
            TagRegistry.clear();
        end

    end
end
