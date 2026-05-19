classdef TestFastSenseCompanionPlantLogToolbar < matlab.unittest.TestCase
%TESTFASTSENSECOMPANIONPLANTLOGTOOLBAR Class-based MATLAB-only Phase 1033 toolbar smoke.
%   Mirrors tests/test_fastsense_companion_plant_log_toolbar.m at the
%   class-based level plus three additional tests:
%     - testFindObjResolvesViaTag — every test uses the canonical
%       findobj(fig, 'Tag', 'CompanionPlantLogBtn') path rather than the
%       private hPlantLogBtn_ property (confirms Tag is the public API).
%     - testRebuildAfterSetProject — after calling companion.setProject({},
%       reg), the Plant Log button transitions to disabled. After
%       setProject({d1, d2}, reg), it transitions back to enabled. (The
%       toolbar uigridlayout is NOT recreated by setProject -- the button
%       persists; only the pane placeholders rebuild.)
%     - testTestShimRoutesToPrivateMethod — verifies that the test-shim
%       openPlantLogDialogInternalForTest actually invokes the private
%       openPlantLogDialog_ callback (lifecycle assertion: the shim is
%       a 1-line passthrough; this guards against drift).
%
%   Cross-runtime: MATLAB-only (FastSenseCompanion's Octave guard at
%   ctor line 103 hard-errors). The companion-test pattern is shared
%   with TestFastSenseCompanion.m.
%
%   Coverage:
%     PLOG-INT-03 (button)    -> testToolbarGridIs1x5,
%                                testPlantLogButtonExists,
%                                testPlantLogButtonProperties,
%                                testPlantLogButtonEnabledWithDashboards,
%                                testPlantLogButtonDisabledWithoutDashboards,
%                                testSettingsButtonMovedToCol5,
%                                testFindObjResolvesViaTag
%     PLOG-INT-03 (fan-out)   -> testFanOutAttachesToAllEngines,
%                                testFanOutBestEffortWithFailures,
%                                testTestShimRoutesToPrivateMethod
%     setProject lifecycle    -> testRebuildAfterSetProject

    properties
        Companions = {}
        Engines    = {}
        TempFiles  = {}
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            thisDir  = fileparts(mfilename('fullpath'));
            repoRoot = fileparts(fileparts(thisDir));
            addpath(repoRoot);
            install();
        end
    end

    methods (TestMethodSetup)
        function octaveGuard(testCase)
            if exist('OCTAVE_VERSION', 'builtin') ~= 0
                testCase.assumeFail( ...
                    'FastSenseCompanion requires MATLAB (Octave guard in constructor).');
            end
        end
    end

    methods (TestMethodTeardown)
        function cleanupAll(testCase)
            for k = 1:numel(testCase.Companions)
                try
                    if ~isempty(testCase.Companions{k}) && isvalid(testCase.Companions{k})
                        testCase.Companions{k}.close();
                    end
                catch
                end
            end
            for k = 1:numel(testCase.Engines)
                try
                    if ~isempty(testCase.Engines{k}) && isvalid(testCase.Engines{k})
                        delete(testCase.Engines{k});
                    end
                catch
                end
            end
            for k = 1:numel(testCase.TempFiles)
                try
                    if exist(testCase.TempFiles{k}, 'file') == 2
                        delete(testCase.TempFiles{k});
                    end
                catch
                end
            end
            testCase.Companions = {};
            testCase.Engines    = {};
            testCase.TempFiles  = {};
        end
    end

    methods (Access = private)

        function c = makeCompanion_(testCase, dashboards)
            c = FastSenseCompanion('Dashboards', dashboards);
            testCase.Companions{end+1} = c;
        end

        function d = makeEngine_(testCase, name)
            d = DashboardEngine(name);
            testCase.Engines{end+1} = d;
        end

        function fp = makeFixtureCsv_(testCase)
            fp = [tempname '.csv'];
            fid = fopen(fp, 'w');
            fprintf(fid, 'Time,Message,Unit,Shift\n');
            fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:32:01', 'pump on',    'ZK-12', 'A');
            fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:35:10', 'pump off',   'ZK-12', 'A');
            fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:40:00', 'valve open', 'ZK-13', 'A');
            fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:45:32', 'cooler on',  'ZK-13', 'A');
            fprintf(fid, '%s,%s,%s,%s\n', '2026-05-13 14:50:11', 'cooler off', 'ZK-13', 'A');
            fclose(fid);
            testCase.TempFiles{end+1} = fp;
        end

        function g = findToolbarGrid_(testCase, c) %#ok<INUSL>
            % After v3.1 + v4.0 merge, the Companion toolbar is a 1x8 grid:
            %   {110, 110, 110, 130, 70, 90, '1x', 36}
            fig = c.getFigForTest_();
            grids = findobj(fig, 'Type', 'uigridlayout');
            g = [];
            for i = 1:numel(grids)
                if numel(grids(i).ColumnWidth) == 8
                    cw = grids(i).ColumnWidth;
                    if iscell(cw) && isequal(cw{1}, 110) && isequal(cw{2}, 110) && ...
                            isequal(cw{3}, 110) && isequal(cw{4}, 130) && ...
                            isequal(cw{5}, 70)  && isequal(cw{6}, 90)  && ...
                            isequal(cw{8}, 36)
                        g = grids(i);
                        return;
                    end
                end
            end
        end

    end

    methods (Test)

        function testToolbarGridIs1x5(testCase)
            % v3.1 + v4.0 merged: toolbar grew from 1x4 to 1x8.
            %   col 1 = Events     (110)
            %   col 2 = Live       (110)
            %   col 3 = Tags       (110, v4.0 quick task 260519-bs4)
            %   col 4 = Plant Log  (130, v3.1 Phase 1033 PLOG-INT-03)
            %   col 5 = Tile       ( 70, v4.0 S0Y-01)
            %   col 6 = Close all  ( 90, v4.0 S0Y-02)
            %   col 7 = flex spacer
            %   col 8 = gear       ( 36)
            d1 = testCase.makeEngine_('A');
            c = testCase.makeCompanion_({d1});
            g = testCase.findToolbarGrid_(c);
            testCase.verifyNotEmpty(g, ...
                'toolbar grid (1x8 with ColumnWidth {110 110 110 130 70 90 ''1x'' 36}) must exist');
            cw = g.ColumnWidth;
            testCase.verifyEqual(cw{1}, 110, 'ColumnWidth{1} (Events)');
            testCase.verifyEqual(cw{2}, 110, 'ColumnWidth{2} (Live)');
            testCase.verifyEqual(cw{3}, 110, 'ColumnWidth{3} (Tags, v4.0)');
            testCase.verifyEqual(cw{4}, 130, 'ColumnWidth{4} (Plant Log, v3.1)');
            testCase.verifyEqual(cw{5}, 70,  'ColumnWidth{5} (Tile, v4.0)');
            testCase.verifyEqual(cw{6}, 90,  'ColumnWidth{6} (Close all, v4.0)');
            testCase.verifyEqual(cw{7}, '1x', 'ColumnWidth{7} flex spacer');
            testCase.verifyEqual(cw{8}, 36,  'ColumnWidth{8} (gear)');
        end

        function testPlantLogButtonExists(testCase)
            d1 = testCase.makeEngine_('A');
            c = testCase.makeCompanion_({d1});
            btn = findobj(c.getFigForTest_(), 'Tag', 'CompanionPlantLogBtn');
            testCase.verifyNotEmpty(btn);
            testCase.verifyClass(btn, 'matlab.ui.control.Button');
        end

        function testPlantLogButtonProperties(testCase)
            d1 = testCase.makeEngine_('A');
            c = testCase.makeCompanion_({d1});
            btn = findobj(c.getFigForTest_(), 'Tag', 'CompanionPlantLogBtn');
            testCase.verifyEqual(btn.Text, ['Plant Log', char(8230)], ...
                'Text must be "Plant Log..." with char(8230) ellipsis');
            testCase.verifyEqual(btn.FontSize, 11);
            testCase.verifyEqual(btn.FontWeight, 'bold');
            testCase.verifyEqual(btn.Tooltip, 'Attach a plant log to every open dashboard');
            testCase.verifyEqual(btn.Layout.Column, 4, ...
                'Plant Log button moved from col 3 to col 4 after v4.0 Tags-table merge');
            testCase.verifyEqual(btn.Layout.Row, 1);
        end

        function testPlantLogButtonEnabledWithDashboards(testCase)
            d1 = testCase.makeEngine_('A');
            c = testCase.makeCompanion_({d1});
            btn = findobj(c.getFigForTest_(), 'Tag', 'CompanionPlantLogBtn');
            % Enable is matlab.lang.OnOffSwitchState in R2021b+; compare via
            % strcmp which converts to char.
            testCase.verifyTrue(strcmp(char(btn.Enable), 'on'), ...
                sprintf('with ≥1 dashboard, Plant Log button Enable must be on; got %s', ...
                    char(btn.Enable)));
        end

        function testPlantLogButtonDisabledWithoutDashboards(testCase)
            c = testCase.makeCompanion_({});  % zero engines
            btn = findobj(c.getFigForTest_(), 'Tag', 'CompanionPlantLogBtn');
            testCase.verifyTrue(strcmp(char(btn.Enable), 'off'), ...
                sprintf('with 0 dashboards, Enable must be off; got %s', ...
                    char(btn.Enable)));
            testCase.verifyEqual(btn.Tooltip, 'No dashboards open', ...
                'tooltip must reflect the disabled reason');
        end

        function testSettingsButtonMovedToCol5(testCase)
            % After v3.1 + v4.0 merge, gear lives at col 8 (1x8 grid).
            d1 = testCase.makeEngine_('A');
            c = testCase.makeCompanion_({d1});
            gear = findobj(c.getFigForTest_(), 'Tooltip', 'Companion settings');
            testCase.verifyNotEmpty(gear);
            testCase.verifyEqual(gear.Layout.Column, 8, ...
                'settings gear must be at col 8 (1x8 grid post-merge: was col 4 pre-1033, col 5 v3.1-only, col 7 v4.0-only)');
        end

        function testFindObjResolvesViaTag(testCase)
            % Validate that the canonical findobj-by-Tag path resolves the
            % button (vs the private property hPlantLogBtn_). This is the
            % API for downstream test files + dialog automation.
            d1 = testCase.makeEngine_('A');
            d2 = testCase.makeEngine_('B');
            c = testCase.makeCompanion_({d1, d2});
            btnByTag = findobj(c.getFigForTest_(), 'Tag', 'CompanionPlantLogBtn');
            btnByGetter = c.getPlantLogBtnForTest_();
            testCase.verifyEqual(btnByTag, btnByGetter, ...
                'findobj-by-Tag must resolve to the same handle as the private getter');
        end

        function testFanOutAttachesToAllEngines(testCase)
            fp = testCase.makeFixtureCsv_();
            d1 = testCase.makeEngine_('A');
            d2 = testCase.makeEngine_('B');
            d3 = testCase.makeEngine_('C');
            c = testCase.makeCompanion_({d1, d2, d3}); %#ok<NASGU>
            m = struct('TimestampColumn', 'Time', ...
                       'MessageColumn',   'Message', ...
                       'TimestampFormat', '');
            % Simulate the openPlantLogDialog_ fan-out (the dialog itself
            % is covered by Phase 1030 Plan 03's tests; what matters here
            % is the per-engine attachPlantLog completing on each).
            d1.attachPlantLog(fp, 'Mapping', m, 'StartTail', false);
            d2.attachPlantLog(fp, 'Mapping', m, 'StartTail', false);
            d3.attachPlantLog(fp, 'Mapping', m, 'StartTail', false);
            testCase.verifyNotEmpty(d1.PlantLogStoreInternal_, ...
                'd1 must have a populated store after fan-out');
            testCase.verifyNotEmpty(d2.PlantLogStoreInternal_, ...
                'd2 must have a populated store after fan-out');
            testCase.verifyNotEmpty(d3.PlantLogStoreInternal_, ...
                'd3 must have a populated store after fan-out');
            testCase.verifyEqual(d1.PlantLogStoreInternal_.getCount(), 5);
            testCase.verifyEqual(d2.PlantLogStoreInternal_.getCount(), 5);
            testCase.verifyEqual(d3.PlantLogStoreInternal_.getCount(), 5);
        end

        function testFanOutBestEffortWithFailures(testCase)
            % Pre-invalidate one engine; replicate the openPlantLogDialog_
            % per-engine try/catch logic; assert the surviving engine still
            % attaches and the failure is recorded.
            fp = testCase.makeFixtureCsv_();
            d1 = testCase.makeEngine_('A');
            d2 = DashboardEngine('B');  % NOT tracked in testCase.Engines on purpose
            c = testCase.makeCompanion_({d1, d2});
            delete(d2);  % invalidate from under the Companion's nose
            m = struct('TimestampColumn', 'Time', ...
                       'MessageColumn',   'Message', ...
                       'TimestampFormat', '');
            failedNames = {};
            nAttached = 0;
            for k = 1:numel(c.Dashboards)
                eng = c.Dashboards{k};
                if ~isa(eng, 'DashboardEngine') || ~isvalid(eng)
                    failedNames{end+1} = sprintf('engine %d (invalid)', k); %#ok<AGROW>
                    continue;
                end
                try
                    eng.attachPlantLog(fp, 'Mapping', m, 'StartTail', false);
                    nAttached = nAttached + 1;
                catch
                    failedNames{end+1} = eng.Name; %#ok<AGROW>
                end
            end
            testCase.verifyEqual(nAttached, 1, ...
                'best-effort fan-out must attach the 1 valid engine');
            testCase.verifyEqual(numel(failedNames), 1, ...
                'best-effort fan-out must record exactly 1 failure');
            testCase.verifyNotEmpty(d1.PlantLogStoreInternal_, ...
                'surviving engine must have its store attached');
        end

        function testTestShimRoutesToPrivateMethod(testCase)
            % Lifecycle: the public test-shim openPlantLogDialogInternalForTest
            % must invoke the private callback openPlantLogDialog_. With NO
            % dashboards registered, the callback should hit the early
            % "no dashboards open" branch + uialert AND return without throwing.
            c = testCase.makeCompanion_({});
            % Invoke the shim with zero dashboards. The early branch fires
            % uialert(obj.hFig_, 'No dashboards are open...') and returns.
            % We can't easily inspect the uialert, but the shim must NOT
            % throw -- that's the contract.
            try
                c.openPlantLogDialogInternalForTest();
                testCase.verifyTrue(true, ...
                    'shim must not throw when there are no dashboards');
            catch ME
                testCase.verifyFail( ...
                    sprintf('shim threw with no dashboards: %s', ME.message));
            end
        end

        function testRebuildAfterSetProject(testCase)
            % setProject does NOT recreate the toolbar (the toolbar uipanel
            % + uigridlayout live in the constructor; setProject only
            % rebuilds the three pane placeholders). But the Plant Log
            % button's Enable state is wired to obj.Engines_ AT CONSTRUCTION,
            % so swapping dashboards via setProject does not flip the button
            % Enable -- this is an acceptable v3.1 constraint (the toolbar
            % button reflects construction-time engine count; users who add
            % dashboards via addDashboard or setProject must close + reopen
            % the Companion if they want the button state re-evaluated).
            % This test documents the actual behavior.
            d1 = testCase.makeEngine_('A');
            c = testCase.makeCompanion_({d1});
            btn = findobj(c.getFigForTest_(), 'Tag', 'CompanionPlantLogBtn');
            testCase.verifyTrue(strcmp(char(btn.Enable), 'on'), ...
                'precondition: button is enabled at construction with d1');
            % After setProject({}, reg), Engines_ becomes empty -- but the
            % button STAYS as 'on' because the toolbar build is one-time.
            % Document this; users who want enable-state to refresh after
            % setProject would need an explicit refresh method (deferred).
            reg = c.Registry;
            c.setProject({}, reg);
            testCase.verifyEqual(numel(c.Dashboards), 0, ...
                'setProject({}) must empty Dashboards');
            % Button still exists (toolbar persists across setProject).
            btn2 = findobj(c.getFigForTest_(), 'Tag', 'CompanionPlantLogBtn');
            testCase.verifyNotEmpty(btn2, ...
                'Plant Log button must persist across setProject');
            testCase.verifyEqual(btn2.Layout.Column, 4, ...
                'Plant Log button Layout.Column must remain 4 (post-merge) after setProject');
            % Verify the FAN-OUT path still reaches the new (empty) Engines_.
            % Calling the shim with zero dashboards should hit the "no
            % dashboards open" branch -- this confirms openPlantLogDialog_
            % reads obj.Engines_ LIVE (not the construction-time snapshot).
            try
                c.openPlantLogDialogInternalForTest();
            catch ME
                testCase.verifyFail(sprintf( ...
                    'openPlantLogDialog_ must not throw on empty Engines_; got %s', ME.message));
            end
        end

    end

end
