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
            d = DashboardEngine('Test');
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'Value', 1);
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
            d = DashboardEngine('Test');
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'Value', 1);
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
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'Value', 1);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            tmp = [tempname '.bmp'];
            testCase.verifyError(@() d.exportImage(tmp, 'bmp'), ...
                'DashboardEngine:unknownImageFormat');
        end

        function testWriteFailureErrors(testCase)
            d = DashboardEngine('X');
            d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'Value', 1);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            bad = '/nonexistent_dir_zzz_1004/out.png';
            testCase.verifyError(@() d.exportImage(bad, 'png'), ...
                'DashboardEngine:imageWriteFailed');
        end
    end

    methods (Static, Access = private)
        function deleteIfExists(p)
            if exist(p, 'file')
                delete(p);
            end
        end
    end
end
