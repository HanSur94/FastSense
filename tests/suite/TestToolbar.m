classdef TestToolbar < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testConstructorWithFastSense(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            tb = FastSenseToolbar(fp);
            testCase.verifyNotEmpty(tb.hToolbar, 'testConstructorWithFastSense: hToolbar');
            testCase.verifyTrue(ishandle(tb.hToolbar), 'testConstructorWithFastSense: ishandle');
        end

        function testConstructorWithFastSenseGrid(testCase)
            fig = FastSenseGrid(1, 2);
            fp1 = fig.tile(1); fp1.addLine(1:100, rand(1,100));
            fp2 = fig.tile(2); fp2.addLine(1:100, rand(1,100));
            fig.renderAll();
            testCase.addTeardown(@close, fig.hFigure);
            tb = FastSenseToolbar(fig);
            testCase.verifyNotEmpty(tb.hToolbar, 'testConstructorWithFPFigure: hToolbar');
        end

        function testToolbarHasAllButtons(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            tb = FastSenseToolbar(fp);
            children = get(tb.hToolbar, 'Children');
            % Buttons created in createToolbar(): cursor, crosshair, grid,
            % legend, autoscale, exportPNG, exportData, refresh, live,
            % metadata, violations, theme = 12.
            testCase.verifyEqual(numel(children), 12, ...
                sprintf('testToolbarHasAllButtons: got %d', numel(children)));
        end

        function testIconsAre16x16x3(testCase)
            icons = FastSenseToolbar.makeIcon('grid');
            testCase.verifyEqual(size(icons), [16 16 3], 'testIconsAre16x16x3');
        end

        function testAllIconNames(testCase)
            names = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', 'export', 'violations'};
            for i = 1:numel(names)
                icon = FastSenseToolbar.makeIcon(names{i});
                testCase.verifyEqual(size(icon), [16 16 3], ...
                    sprintf('testAllIconNames: %s', names{i}));
            end
        end

        function testToggleGrid(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            tb = FastSenseToolbar(fp);
            gridBefore = get(fp.hAxes, 'XGrid');
            tb.toggleGrid();
            gridAfter = get(fp.hAxes, 'XGrid');
            testCase.verifyTrue(~strcmp(gridBefore, gridAfter), 'testToggleGrid: should toggle');
        end

        function testToggleLegend(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100), 'DisplayName', 'TestLine');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            tb = FastSenseToolbar(fp);
            tb.toggleLegend();
            hLeg = findobj(fp.hFigure, 'Type', 'axes', 'Tag', 'legend');
            if isempty(hLeg)
                hLeg = legend(fp.hAxes);
            end
            vis1 = get(hLeg, 'Visible');
            tb.toggleLegend();
            vis2 = get(hLeg, 'Visible');
            testCase.verifyTrue(~strcmp(vis1, vis2), 'testToggleLegend: should toggle');
        end

        function testAutoscaleY(testCase)
            fp = FastSense();
            y = [zeros(1,50), 10*ones(1,50)];
            fp.addLine(1:100, y);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            tb = FastSenseToolbar(fp);
            % Zoom into first half (all zeros)
            set(fp.hAxes, 'XLim', [1 50]);
            drawnow;
            tb.autoscaleY();
            ylims = get(fp.hAxes, 'YLim');
            % Y range should be tight around 0, not spanning 0-10
            testCase.verifyTrue(ylims(2) < 5, ...
                sprintf('testAutoscaleY: YLim(2) should be < 5, got %.1f', ylims(2)));
        end

        function testExportPNG(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            tb = FastSenseToolbar(fp);
            tmpFile = [tempname, '.png'];
            testCase.addTeardown(@() TestToolbar.deleteIfExists(tmpFile));
            tb.exportPNG(tmpFile);
            testCase.verifyEqual(exist(tmpFile, 'file'), 2, 'testExportPNG: file should exist');
        end

        function testCrosshairMode(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            tb = FastSenseToolbar(fp);
            testCase.verifyEqual(tb.Mode, 'none', 'testCrosshairMode: initial mode');
            tb.setCrosshair(true);
            testCase.verifyEqual(tb.Mode, 'crosshair', 'testCrosshairMode: on');
            tb.setCrosshair(false);
            testCase.verifyEqual(tb.Mode, 'none', 'testCrosshairMode: off');
        end

        function testCrosshairMutualExclusion(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            tb = FastSenseToolbar(fp);
            tb.setCursor(true);
            testCase.verifyEqual(tb.Mode, 'cursor', 'testMutualExcl: cursor on');
            tb.setCrosshair(true);
            testCase.verifyEqual(tb.Mode, 'crosshair', 'testMutualExcl: crosshair replaces cursor');
            % char() handles R2020b (already char) + newer releases (OnOffSwitchState enum)
            testCase.verifyEqual(char(get(tb.hCursorBtn, 'State')), 'off', 'testMutualExcl: cursor btn off');
        end

        function testCursorMode(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            tb = FastSenseToolbar(fp);
            tb.setCursor(true);
            testCase.verifyEqual(tb.Mode, 'cursor', 'testCursorMode: on');
            tb.setCursor(false);
            testCase.verifyEqual(tb.Mode, 'none', 'testCursorMode: off');
        end

        function testSnapToNearest(testCase)
            fp = FastSense();
            fp.addLine([1 2 3 4 5], [10 20 30 40 50]);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            tb = FastSenseToolbar(fp);
            [sx, sy, ~] = tb.snapToNearest(fp, 2.8, 25);
            testCase.verifyEqual(sx, 3, sprintf('testSnapToNearest: x should be 3, got %g', sx));
            testCase.verifyEqual(sy, 30, sprintf('testSnapToNearest: y should be 30, got %g', sy));
        end

        function testViolationsToggle(testCase)
            fp = FastSense();
            fp.addLine(1:100, [ones(1,50)*2, ones(1,50)*8]);
            fp.addThreshold(5, 'Direction', 'upper', 'ShowViolations', true);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            tb = FastSenseToolbar(fp);
            % Violations should be visible initially
            testCase.verifyTrue(fp.ViolationsVisible, 'testViolationsToggle: default true');
            hM = fp.Thresholds(1).hMarkers;
            % char() handles R2020b (already char) + newer releases (OnOffSwitchState enum)
            testCase.verifyEqual(char(get(hM, 'Visible')), 'on', 'testViolationsToggle: markers visible');
            % Toggle off via toolbar callback
            tb.setViolationsVisible(false);
            testCase.verifyTrue(~fp.ViolationsVisible, 'testViolationsToggle: now false');
            testCase.verifyEqual(char(get(hM, 'Visible')), 'off', 'testViolationsToggle: markers hidden');
            % Toggle back on
            tb.setViolationsVisible(true);
            testCase.verifyEqual(char(get(hM, 'Visible')), 'on', 'testViolationsToggle: markers back');
        end
    end

    methods (Static, Access = private)
        function deleteIfExists(filePath)
            if exist(filePath, 'file') == 2
                delete(filePath);
            end
        end
    end
end
