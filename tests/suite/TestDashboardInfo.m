classdef TestDashboardInfo < matlab.unittest.TestCase
    properties
        TempDir
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

    methods (Test)
        function testInfoFileDefaultEmpty(testCase)
            d = DashboardEngine('Test');
            testCase.verifyEqual(d.InfoFile, '');
        end

        function testInfoFileAtConstruction(testCase)
            d = DashboardEngine('Test', 'InfoFile', 'info.md');
            testCase.verifyEqual(d.InfoFile, 'info.md');
        end

        function testInfoFileSetAfterConstruction(testCase)
            d = DashboardEngine('Test');
            d.InfoFile = 'docs/readme.md';
            testCase.verifyEqual(d.InfoFile, 'docs/readme.md');
        end

        function testShowInfoMissingFileWarns(testCase)
            d = DashboardEngine('Test');
            d.InfoFile = 'nonexistent_file_xyz.md';
            % showInfo should warn, not error
            testCase.verifyWarning(@() d.showInfo(), ...
                'DashboardEngine:infoFileNotFound');
        end

        function testShowInfoReadsFile(testCase)
            mdPath = fullfile(testCase.TempDir, 'info.md');
            fid = fopen(mdPath, 'w');
            fprintf(fid, '# Test Info\n\nHello world.');
            fclose(fid);

            d = DashboardEngine('Test');
            d.InfoFile = mdPath;
            d.showInfo();
            testCase.addTeardown(@() d.cleanupInfoTempFile());
            testCase.verifyTrue(~isempty(d.InfoTempFile));
            testCase.verifyTrue(exist(d.InfoTempFile, 'file') == 2);
        end

        function testRelativePathResolvesAgainstFilePath(testCase)
            % Create a subdirectory with an md file
            subDir = fullfile(testCase.TempDir, 'sub');
            mkdir(subDir);
            mdPath = fullfile(subDir, 'info.md');
            fid = fopen(mdPath, 'w');
            fprintf(fid, '# Info');
            fclose(fid);

            d = DashboardEngine('Test');
            d.InfoFile = 'info.md';
            % Simulate having been loaded from sub/dashboard.json
            % FilePath is SetAccess=private, so we save+load to set it
            dashPath = fullfile(subDir, 'dash.json');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], 'Content', 'x');
            d.save(dashPath);

            d2 = DashboardEngine.load(dashPath);
            d2.InfoFile = 'info.md';
            % Should resolve info.md relative to sub/
            d2.showInfo();
            testCase.addTeardown(@() d2.cleanupInfoTempFile());
            testCase.verifyTrue(exist(d2.InfoTempFile, 'file') == 2);
        end

        function testRelativePathUnsavedResolvesAgainstPwd(testCase)
            mdPath = fullfile(pwd, 'test_info_unsaved_xyz.md');
            fid = fopen(mdPath, 'w');
            fprintf(fid, '# Unsaved test');
            fclose(fid);
            testCase.addTeardown(@() delete(mdPath));

            d = DashboardEngine('Test');
            d.InfoFile = 'test_info_unsaved_xyz.md';
            % FilePath is empty (unsaved), should resolve against pwd
            d.showInfo();
            testCase.addTeardown(@() d.cleanupInfoTempFile());
            testCase.verifyTrue(exist(d.InfoTempFile, 'file') == 2);
        end

        function testSerializationRoundTrip(testCase)
            d = DashboardEngine('Info Test', 'InfoFile', 'docs/info.md');
            d.addWidget('text', 'Title', 'Note', 'Position', [1 1 4 2], ...
                'Content', 'Hello');

            filepath = fullfile(testCase.TempDir, 'info_dash.json');
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(d2.InfoFile, 'docs/info.md');
        end

        function testSerializationWithoutInfoFile(testCase)
            d = DashboardEngine('No Info');
            d.addWidget('text', 'Title', 'Note', 'Position', [1 1 4 2], ...
                'Content', 'Hello');

            filepath = fullfile(testCase.TempDir, 'no_info_dash.json');
            d.save(filepath);

            content = fileread(filepath);
            testCase.verifyFalse(contains(content, 'infoFile'));
        end

        function testWidgetsToConfigBackwardCompat(testCase)
            w = TextWidget('Title', 'T', 'Position', [1 1 4 2], 'Content', 'x');
            config = DashboardSerializer.widgetsToConfig('Test', 'light', 5, {w});
            testCase.verifyEqual(config.name, 'Test');
            testCase.verifyFalse(isfield(config, 'infoFile'));
        end

        function testExportScriptWithInfoFile(testCase)
            d = DashboardEngine('Export Info', 'InfoFile', 'notes.md');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], ...
                'Content', 'x');

            filepath = fullfile(testCase.TempDir, 'export_info.m');
            d.exportScript(filepath);

            content = fileread(filepath);
            testCase.verifyTrue(contains(content, 'InfoFile'));
            testCase.verifyTrue(contains(content, 'notes.md'));
        end

        function testExportScriptWithoutInfoFile(testCase)
            d = DashboardEngine('Export No Info');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], ...
                'Content', 'x');

            filepath = fullfile(testCase.TempDir, 'export_no_info.m');
            d.exportScript(filepath);

            content = fileread(filepath);
            testCase.verifyFalse(contains(content, 'InfoFile'));
        end

        function testToolbarInfoButtonPresent(testCase)
            d = DashboardEngine('Toolbar Test', 'InfoFile', 'dummy.md');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], ...
                'Content', 'x');
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            testCase.verifyNotEmpty(d.Toolbar.hInfoBtn);
            testCase.verifyTrue(ishandle(d.Toolbar.hInfoBtn));
        end

        function testToolbarInfoButtonAlwaysPresent(testCase)
            % Info button is mandatory — always rendered, even without InfoFile.
            d = DashboardEngine('Toolbar No Info');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], ...
                'Content', 'x');
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            testCase.verifyNotEmpty(d.Toolbar.hInfoBtn);
            testCase.verifyTrue(ishandle(d.Toolbar.hInfoBtn));
        end

        function testShowInfoWithoutInfoFileShowsPlaceholder(testCase)
            % When no InfoFile is set, showInfo renders a built-in placeholder.
            d = DashboardEngine('Placeholder Test');
            d.showInfo();
            testCase.addTeardown(@() d.cleanupInfoTempFile());

            testCase.verifyNotEmpty(d.InfoTempFile);
            testCase.verifyEqual(exist(d.InfoTempFile, 'file'), 2);

            html = fileread(d.InfoTempFile);
            testCase.verifyTrue(contains(html, 'Placeholder Test'));
            testCase.verifyTrue(contains(html, 'InfoFile'));
        end

        function testToolbarButtonsHaveTooltips(testCase)
            % Every visible toolbar button should carry a non-empty tooltip.
            d = DashboardEngine('Tooltip Test');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], ...
                'Content', 'x');
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            handles = {d.Toolbar.hLiveBtn, ...
                d.Toolbar.hSaveBtn,  d.Toolbar.hImageBtn, ...
                d.Toolbar.hExportBtn, d.Toolbar.hSyncBtn, ...
                d.Toolbar.hInfoBtn};
            for i = 1:numel(handles)
                tip = get(handles{i}, 'TooltipString');
                testCase.verifyNotEmpty(tip, ...
                    sprintf('Button %d missing tooltip', i));
            end
        end

        function testLiveButtonBorderReflectsActiveState(testCase)
            % Live button should show a blue border when live mode is ON,
            % and a neutral (toolbar-background) border when OFF.
            d = DashboardEngine('Live Border Test');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 4 2], ...
                'Content', 'x');
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            testCase.addTeardown(@() d.stopLive());

            testCase.verifyNotEmpty(d.Toolbar.hLivePanel);

            themeStruct = d.getCachedTheme();

            % OFF → border matches toolbar background (invisible)
            offColor = get(d.Toolbar.hLivePanel, 'HighlightColor');
            testCase.verifyEqual(offColor, themeStruct.ToolbarBackground, ...
                'AbsTol', 1e-6);

            % Simulate toolbar click toggling live ON
            set(d.Toolbar.hLiveBtn, 'Value', 1);
            d.Toolbar.onLiveToggle(d.Toolbar.hLiveBtn);

            onColor = get(d.Toolbar.hLivePanel, 'HighlightColor');
            testCase.verifyEqual(onColor, themeStruct.InfoColor, ...
                'AbsTol', 1e-6);
        end
    end
end
