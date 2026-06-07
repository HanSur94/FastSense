classdef TestFleetDashboardResolver < matlab.unittest.TestCase
%TESTFLEETDASHBOARDRESOLVER RED test scaffold for Phase 1043 resolver seam.
%   Pins all four success criteria of the resolver seam BEFORE production code
%   changes.  These tests MUST fail (RED) against current HEAD because:
%     - FastSenseWidget.fromStruct takes only 1 arg (no tagResolver)
%     - DashboardEngine.load does not parse 'TagResolver' NV pair
%     - The multi-page path at :4384 drops the resolver entirely
%     - DashboardSerializer.linesForWidget has no 'tag' case
%     - warning ID is still 'FastSenseWidget:tagNotFound', not
%       'FastSenseWidget:tagResolverMissing'
%
%   Tests GREEN after Plans 02 + 03.
%
%   Covers D-06 (a/b/c/d) — DASH-01 (SC1/SC4) and DASH-02 (SC2/SC3).
%
%   See also TestDashboardSerializer, test_dashboard_resolver.

    properties
        TempDir
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function clearRegistry(testCase)
            testCase.TempDir = tempname();
            mkdir(testCase.TempDir);
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
            TagRegistry.clear();
        end
    end

    methods (Test)

        % -----------------------------------------------------------------
        % SC2 / DASH-02: legacy single-page JSON loads via TagRegistry,
        % no resolver supplied, no FastSenseWidget:tagResolverMissing warning.
        % D-06(a): legacy single-machine JSON loads with no resolver → tags
        % via TagRegistry.get, bound, no warning.
        % -----------------------------------------------------------------
        function testLegacyLoadNoResolverUsesRegistry(testCase)
            % Register a legacy tag in the global catalog.
            legacyTag = SensorTag('legacy_temp');
            TagRegistry.register('legacy_temp', legacyTag);

            % Build a single-page config with one fastsense tag-type widget.
            ws.type = 'fastsense';
            ws.title = 'Legacy Temp';
            ws.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
            ws.source = struct('type', 'tag', 'key', 'legacy_temp');

            config.name = 'Legacy Dashboard';
            config.theme = 'dark';
            config.liveInterval = 5;
            config.grid = struct('columns', 24);
            config.widgets = {ws};

            filepath = fullfile(testCase.TempDir, 'legacy.json');
            DashboardSerializer.saveJSON(config, filepath);

            % SC2: load with NO resolver → tag must bind via TagRegistry, no warning.
            loadFn = @() DashboardEngine.load(filepath);
            testCase.verifyWarningFree(loadFn, ...
                'SC2/DASH-02: legacy load must emit no FastSenseWidget:tagResolverMissing warning');

            eng = DashboardEngine.load(filepath);
            testCase.verifyFalse(isempty(eng.Widgets), ...
                'SC2/DASH-02: loaded engine must have at least one widget');
            w = eng.Widgets{1};
            testCase.verifyFalse(isempty(w.Tag), ...
                'SC2/DASH-02: widget Tag must be non-empty on legacy registry hit');
            testCase.verifyTrue(isa(w.Tag, 'SensorTag'), ...
                'SC2/DASH-02: widget Tag must be a SensorTag');
        end

        % -----------------------------------------------------------------
        % SC1 / DASH-01: multi-page fleet JSON + injected resolver → page-2
        % tag widgets resolve via the resolver, not TagRegistry.
        % D-06(b): multi-page fleet JSON + injected resolver → page-2 widgets.
        % -----------------------------------------------------------------
        function testMultiPageFleetResolverBindsPage2(testCase)
            % TagRegistry is cleared by TestMethodSetup; machine tags must NOT
            % leak into it (FLEET-02 invariant, verified at end of this test).
            m = Machine('Id', 'M01', 'DataRoot', tempdir());
            m.addTag(SensorTag('temperature'));
            m.addTag(SensorTag('pressure'));

            % Build a 2-page fleet config.
            ws1.type = 'fastsense';
            ws1.title = 'Page1 Widget';
            ws1.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
            ws1.source = struct('type', 'tag', 'key', 'temperature');

            pg1.name = 'Page 1';
            pg1.widgets = {ws1};

            ws2.type = 'fastsense';
            ws2.title = 'Page2 Widget';
            ws2.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
            ws2.source = struct('type', 'tag', 'key', 'pressure');

            pg2.name = 'Page 2';
            pg2.widgets = {ws2};

            config.name = 'Fleet Dashboard';
            config.theme = 'dark';
            config.liveInterval = 5;
            config.grid = struct('columns', 24);
            config.pages = {pg1, pg2};

            filepath = fullfile(testCase.TempDir, 'fleet_multi.json');
            DashboardSerializer.saveJSON(config, filepath);

            % SC1: load with resolver → page-2 widget must bind via resolver.
            resolver = @(k) m.get(k);
            eng = DashboardEngine.load(filepath, 'TagResolver', resolver);

            testCase.verifyFalse(isempty(eng.Pages), ...
                'SC1/DASH-01: loaded engine must have pages');
            testCase.verifyTrue(numel(eng.Pages) >= 2, ...
                'SC1/DASH-01: loaded engine must have at least 2 pages');

            page2 = eng.Pages{2};
            testCase.verifyFalse(isempty(page2.Widgets), ...
                'SC1/DASH-01: page 2 must have widgets');
            tag2 = page2.Widgets{1}.Tag;
            testCase.verifyFalse(isempty(tag2), ...
                'SC1/DASH-01: page-2 widget must bind via injected resolver (Tag non-empty)');
            testCase.verifyTrue(isa(tag2, 'SensorTag'), ...
                'SC1/DASH-01: page-2 Tag must be a SensorTag');
            testCase.verifyEqual(char(tag2.Key), 'pressure', ...
                'SC1/DASH-01: page-2 Tag key must be ''pressure''');

            % Negative: machine tags must NOT have leaked into the global registry.
            leaked = TagRegistry.find(@(t) true);
            testCase.verifyTrue(isempty(leaked), ...
                'SC1/DASH-01: machine tags must NOT leak into TagRegistry (FLEET-02)');
        end

        % -----------------------------------------------------------------
        % SC3 / DASH-02: fleet tag not in TagRegistry, no resolver supplied
        % → warning 'FastSenseWidget:tagResolverMissing', no crash, Tag=[].
        % D-06(c): fleet JSON, no resolver → warning fires, no crash, Tag=[].
        % -----------------------------------------------------------------
        function testNoResolverFleetTagMissWarns(testCase)
            % 'pressure' is NOT in TagRegistry (cleared by setup).
            ws.type = 'fastsense';
            ws.title = 'Pressure';
            ws.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
            ws.source = struct('type', 'tag', 'key', 'pressure');

            config.name = 'Fleet Dashboard';
            config.theme = 'dark';
            config.liveInterval = 5;
            config.grid = struct('columns', 24);
            config.widgets = {ws};

            filepath = fullfile(testCase.TempDir, 'fleet_miss.json');
            DashboardSerializer.saveJSON(config, filepath);

            % SC3: load must emit the warning but NOT error.
            testCase.verifyWarning( ...
                @() DashboardEngine.load(filepath), ...
                'FastSenseWidget:tagResolverMissing', ...
                'SC3/DASH-02: tagResolverMissing warning must fire on no-resolver fleet-tag miss');

            % Load again to inspect Tag state (warning will fire; suppress it
            % during the inspection load so verifyEqual is reached cleanly).
            warning('off', 'FastSenseWidget:tagResolverMissing');
            cleanupWarn = onCleanup( ...
                @() warning('on', 'FastSenseWidget:tagResolverMissing'));
            eng = DashboardEngine.load(filepath);
            testCase.verifyFalse(isempty(eng.Widgets), ...
                'SC3/DASH-02: engine must still have widgets even on resolver miss');
            testCase.verifyTrue(isempty(eng.Widgets{1}.Tag), ...
                'SC3/DASH-02: widget Tag must be empty after no-resolver miss');
        end

        % -----------------------------------------------------------------
        % SC4 / DASH-01: .m export with machineVar emits machine-scoped form.
        % D-06(d): exportScript with machineVar → <machineVar>.get('key'),
        %          not TagRegistry.get('key').
        % -----------------------------------------------------------------
        function testExportScriptMachineVarEmitsMachineScopedTag(testCase)
            ws.type = 'fastsense';
            ws.title = 'Pressure';
            ws.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
            ws.source = struct('type', 'tag', 'key', 'pressure');

            config.name = 'Fleet Dashboard';
            config.theme = 'dark';
            config.liveInterval = 5;
            config.grid = struct('columns', 24);
            config.widgets = {ws};

            filepath = fullfile(testCase.TempDir, 'fleet_export.m');

            % SC4: exportScript with machineVar → machine-scoped tag reference.
            % Expected pattern: machine.get('pressure') in exported file.
            DashboardSerializer.exportScript(config, filepath, 'machine');
            content = fileread(filepath);

            % grep acceptance: machine.get('pressure')
            testCase.verifyFalse(isempty(strfind(content, 'machine.get(''pressure'')')), ...
                'SC4/DASH-01: exported .m must contain machine.get(''pressure'') when machineVar supplied');
            testCase.verifyTrue(isempty(strfind(content, 'TagRegistry.get(''pressure'')')), ...
                'SC4/DASH-01: exported .m must NOT contain TagRegistry.get(''pressure'') when machineVar supplied');
        end

        % -----------------------------------------------------------------
        % SC4 negative companion: exportScript WITHOUT machineVar emits
        % TagRegistry form (legacy backward-compat).
        % -----------------------------------------------------------------
        function testExportScriptNoMachineVarEmitsRegistry(testCase)
            ws.type = 'fastsense';
            ws.title = 'Pressure';
            ws.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
            ws.source = struct('type', 'tag', 'key', 'pressure');

            config.name = 'Legacy Dashboard';
            config.theme = 'dark';
            config.liveInterval = 5;
            config.grid = struct('columns', 24);
            config.widgets = {ws};

            filepath = fullfile(testCase.TempDir, 'legacy_export.m');

            % No machineVar: legacy form → TagRegistry.get('pressure').
            DashboardSerializer.exportScript(config, filepath);
            content = fileread(filepath);

            testCase.verifyFalse(isempty(strfind(content, 'TagRegistry.get(''pressure'')')), ...
                'SC4 negative/DASH-02: exported .m must contain TagRegistry.get(''pressure'') when no machineVar');
        end

    end

end
