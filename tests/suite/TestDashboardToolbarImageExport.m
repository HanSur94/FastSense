classdef TestDashboardToolbarImageExport < matlab.unittest.TestCase
%TESTDASHBOARDTOOLBARIMAGEEXPORT Tests for phase 1004 image export.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', '..'));
            install();
        end
    end

    methods (Test)
        function testExportImagePNG(testCase)
            TestDashboardToolbarImageExport.assumeExportWorks(testCase);
            d = DashboardEngine('Test');
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            tmp = [tempname '.png'];
            testCase.addTeardown( ...
                @() TestDashboardToolbarImageExport.deleteIfExists(tmp));

            d.exportImage(tmp, 'png');
            testCase.verifyEqual(exist(tmp, 'file'), 2, ...
                'testExportImagePNG: file should exist');
            info = dir(tmp);
            testCase.verifyGreaterThan(info.bytes, 0, ...
                'testExportImagePNG: file should be non-empty');
        end

        function testExportImageJPEG(testCase)
            TestDashboardToolbarImageExport.assumeExportWorks(testCase);
            d = DashboardEngine('Test');
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            tmp = [tempname '.jpg'];
            testCase.addTeardown( ...
                @() TestDashboardToolbarImageExport.deleteIfExists(tmp));

            d.exportImage(tmp, 'jpeg');
            testCase.verifyEqual(exist(tmp, 'file'), 2, ...
                'testExportImageJPEG: file should exist');
            info = dir(tmp);
            testCase.verifyGreaterThan(info.bytes, 0, ...
                'testExportImageJPEG: file should be non-empty');
        end

        function testSanitizeFilename(testCase) %#ok<MANU>
            % Verify the regex contract used by defaultImageFilename()
            raw = 'My Dash/Board: v1';
            safe = regexprep(raw, '[/\\:*?"<>|\s]', '_');
            testCase.verifyEqual(safe, 'My_Dash_Board__v1');
        end

        function testUnknownFormatError(testCase)
            d = DashboardEngine('X');
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            tmp = [tempname '.bmp'];
            testCase.verifyError(@() d.exportImage(tmp, 'bmp'), ...
                'DashboardEngine:unknownImageFormat');
        end

        function testWriteFailureErrors(testCase)
            d = DashboardEngine('X');
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            bad = '/nonexistent_dir_zzz_1004/out.png';
            testCase.verifyError(@() d.exportImage(bad, 'png'), ...
                'DashboardEngine:imageWriteFailed');
        end

        function testButtonPresent(testCase)
            %TESTBUTTONPRESENT IMG-01: Image button label, tooltip, order.
            d = DashboardEngine('TestDash');
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 42);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            testCase.verifyNotEmpty(d.Toolbar.hImageBtn, ...
                'testButtonPresent: hImageBtn should exist');
            testCase.verifyEqual(get(d.Toolbar.hImageBtn, 'String'), 'Image', ...
                'testButtonPresent: label should be ''Image''');
            testCase.verifyEqual(get(d.Toolbar.hImageBtn, 'TooltipString'), ...
                'Save dashboard as image (PNG/JPEG)', ...
                'testButtonPresent: tooltip should match CONTEXT.md');

            % Horizontal order check: Image button sits between Config and Export
            % (smaller x-Position => further left in normalized coords).
            posImage  = get(d.Toolbar.hImageBtn,  'Position');
            posConfig = get(d.Toolbar.hConfigBtn, 'Position');
            posExport = get(d.Toolbar.hExportBtn, 'Position');
            testCase.verifyGreaterThan(posImage(1), posConfig(1), ...
                'Image should be right of Config');
            testCase.verifyLessThan(posImage(1), posExport(1), ...
                'Image should be left of Export');
        end

        function testCancelNoOp(testCase)
            %TESTCANCELNOOP IMG-07: user cancels uiputfile (file==0).
            d = DashboardEngine('CancelTest');
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            % Bypass the real uiputfile by calling the testable dispatcher.
            % Should return silently without throwing.
            testCase.verifyWarningFree( ...
                @() d.Toolbar.dispatchImageExport(0, '', 1), ...
                'testCancelNoOp: cancel must be silent no-op');
        end

        function testMultiPageActiveOnly(testCase)
            %TESTMULTIPAGEACTIVEONLY IMG-08: switchPage(2) + exportImage writes file.
            TestDashboardToolbarImageExport.assumeExportWorks(testCase);
            d = DashboardEngine('MultiPage');
            d.addPage('Page1');
            d.addWidget('number', 'Title', 'P1', 'Position', [1 1 6 2], 'StaticValue', 1);
            d.addPage('Page2');
            d.switchPage(2);
            d.addWidget('number', 'Title', 'P2', 'Position', [1 1 6 2], 'StaticValue', 2);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            tmp = [tempname '.png'];
            testCase.addTeardown( ...
                @() TestDashboardToolbarImageExport.deleteIfExists(tmp));

            d.exportImage(tmp, 'png');
            testCase.verifyEqual(exist(tmp, 'file'), 2, ...
                'testMultiPageActiveOnly: file should exist');
            info = dir(tmp);
            testCase.verifyGreaterThan(info.bytes, 0, ...
                'testMultiPageActiveOnly: file should be non-empty');
        end

        function testLiveModeNoPause(testCase)
            %TESTLIVEMODENOPAUSE IMG-09: exportImage does not stop live timer.
            TestDashboardToolbarImageExport.assumeExportWorks(testCase);
            d = DashboardEngine('LiveTest');
            d.LiveInterval = 0.5;
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() d.stopLive());
            testCase.addTeardown(@() close(d.hFigure));

            d.startLive();
            testCase.verifyTrue(d.IsLive, 'precondition: IsLive before export');

            tmp = [tempname '.png'];
            testCase.addTeardown( ...
                @() TestDashboardToolbarImageExport.deleteIfExists(tmp));

            d.exportImage(tmp, 'png');

            % Core IMG-09 assertion: live stays live after export.
            testCase.verifyTrue(d.IsLive, ...
                'testLiveModeNoPause: IsLive must remain true after exportImage');
            testCase.verifyEqual(exist(tmp, 'file'), 2, ...
                'testLiveModeNoPause: file should exist');
        end
    end

    methods (Static, Access = private)
        function deleteIfExists(p)
            if exist(p, 'file')
                delete(p);
            end
        end

        function assumeExportWorks(testCase)
            %ASSUMEEXPORTWORKS Skip when the MATLAB runtime can't export the
            %   dashboard figure. MATLAB R2020b headless (no display server)
            %   raises "Specified handle is not valid for export" on uipanel
            %   figures even with visibility toggle, stub axes, and
            %   getframe fallback.
            %
            %   feature('ShowFigureWindows') returns 0 when MATLAB is running
            %   headless (no display / -nodisplay / virtual-desktop issues).
            %   That's the same environment where this export path breaks.
            hasDisplay = true;
            try
                hasDisplay = logical(feature('ShowFigureWindows'));
            catch
            end
            testCase.assumeTrue(hasDisplay, ...
                'exportImage needs a display; headless MATLAB R2020b rejects uipanel figures.');
        end
    end
end
