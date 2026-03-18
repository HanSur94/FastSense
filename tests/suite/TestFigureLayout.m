classdef TestFigureLayout < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            fig = FastSenseGrid(2, 3);
            testCase.addTeardown(@close, fig.hFigure);
            testCase.verifyEqual(fig.Grid, [2 3], 'testConstruction: Grid');
            testCase.verifyNotEmpty(fig.hFigure, 'testConstruction: hFigure');
            testCase.verifyTrue(ishandle(fig.hFigure), 'testConstruction: hFigure valid');
        end

        function testTileReturnsFastSense(testCase)
            fig = FastSenseGrid(2, 1);
            testCase.addTeardown(@close, fig.hFigure);
            fp = fig.tile(1);
            testCase.verifyTrue(isa(fp, 'FastSense'), 'testTileReturnsFastSense');
        end

        function testTileLazy(testCase)
            fig = FastSenseGrid(2, 1);
            testCase.addTeardown(@close, fig.hFigure);
            fp1a = fig.tile(1);
            fp1b = fig.tile(1);
            % In Octave, handle == isn't always defined; check axes handle identity
            fp1a.addLine(1:10, rand(1,10));
            testCase.verifyEqual(numel(fp1b.Lines), 1, 'testTileLazy: same object on repeat call');
        end

        function testTileCreatesAxes(testCase)
            fig = FastSenseGrid(2, 1);
            testCase.addTeardown(@close, fig.hFigure);
            fp = fig.tile(1);
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.verifyNotEmpty(fp.hAxes, 'testTileCreatesAxes: axes exist');
            testCase.verifyTrue(ishandle(fp.hAxes), 'testTileCreatesAxes: axes valid');
        end

        function testMultipleTiles(testCase)
            fig = FastSenseGrid(2, 2);
            testCase.addTeardown(@close, fig.hFigure);
            for i = 1:4
                fp = fig.tile(i);
                fp.addLine(1:50, rand(1,50));
            end
            fig.renderAll();
            for i = 1:4
                fp = fig.tile(i);
                testCase.verifyTrue(fp.IsRendered, sprintf('testMultipleTiles: tile %d rendered', i));
            end
        end

        function testRenderAllSkipsRendered(testCase)
            fig = FastSenseGrid(2, 1);
            testCase.addTeardown(@close, fig.hFigure);
            fp1 = fig.tile(1);
            fp1.addLine(1:10, rand(1,10));
            fp1.render();
            fp2 = fig.tile(2);
            fp2.addLine(1:10, rand(1,10));
            fig.renderAll();  % should not error on already-rendered tile 1
            testCase.verifyTrue(fp2.IsRendered, 'testRenderAllSkipsRendered: tile 2');
        end

        function testOutOfBoundsTileErrors(testCase)
            fig = FastSenseGrid(2, 2);
            testCase.addTeardown(@close, fig.hFigure);
            threw = false;
            try
                fig.tile(5);  % only 4 tiles in 2x2
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'testOutOfBoundsTileErrors');
        end

        function testTileSpanning(testCase)
            fig = FastSenseGrid(2, 2);
            testCase.addTeardown(@close, fig.hFigure);
            fig.setTileSpan(1, [1 2]);  % tile 1 spans both columns
            fp1 = fig.tile(1);
            fp1.addLine(1:50, rand(1,50));
            fp1.render();
            pos = get(fp1.hAxes, 'Position');
            % Spanning tile should be wider than half the figure
            testCase.verifyTrue(pos(3) > 0.4, 'testTileSpanning: wide enough');
        end

        function testFigureThemePassedToTiles(testCase)
            fig = FastSenseGrid(2, 1, 'Theme', 'dark');
            testCase.addTeardown(@close, fig.hFigure);
            fp = fig.tile(1);
            testCase.verifyTrue(all(fp.Theme.Background < [0.2 0.2 0.2]), 'testFigureThemePassedToTiles');
        end

        function testTileThemeOverride(testCase)
            fig = FastSenseGrid(2, 1, 'Theme', 'dark');
            testCase.addTeardown(@close, fig.hFigure);
            fig.setTileTheme(1, struct('AxesColor', [0.3 0 0]));
            fp = fig.tile(1);
            testCase.verifyEqual(fp.Theme.AxesColor, [0.3 0 0], 'testTileThemeOverride: AxesColor');
            testCase.verifyTrue(all(fp.Theme.Background < [0.2 0.2 0.2]), 'testTileThemeOverride: inherits bg');
        end

        function testFigureProperties(testCase)
            fig = FastSenseGrid(1, 1, 'Name', 'MyDash', 'Position', [50 50 800 600]);
            testCase.addTeardown(@close, fig.hFigure);
            name = get(fig.hFigure, 'Name');
            testCase.verifyEqual(name, 'MyDash', 'testFigureProperties: Name');
        end

        function testTileLabels(testCase)
            fig = FastSenseGrid(2, 1);
            testCase.addTeardown(@close, fig.hFigure);
            fp = fig.tile(1);
            fp.addLine(1:50, rand(1,50));
            fp.render();
            fig.setTileTitle(1, 'My Title');
            fig.setTileYLabel(1, 'Y Axis');
            fig.setTileXLabel(1, 'X Axis');
            % No error = pass
        end

        function testAxesReturnsRawAxes(testCase)
            fig = FastSenseGrid(2, 2);
            testCase.addTeardown(@close, fig.hFigure);
            ax = fig.axes(1);
            testCase.verifyTrue(ishandle(ax), 'testAxesReturnsRawAxes: valid handle');
            testCase.verifyEqual(get(ax, 'Type'), 'axes', 'testAxesReturnsRawAxes: is axes');
        end

        function testAxesLazy(testCase)
            fig = FastSenseGrid(2, 1);
            testCase.addTeardown(@close, fig.hFigure);
            ax1 = fig.axes(1);
            ax2 = fig.axes(1);
            testCase.verifyEqual(ax1, ax2, 'testAxesLazy: same handle on repeat call');
        end

        function testTileThenAxesErrors(testCase)
            fig = FastSenseGrid(2, 1);
            testCase.addTeardown(@close, fig.hFigure);
            fig.tile(1);
            threw = false;
            try
                fig.axes(1);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'testTileThenAxesErrors');
        end

        function testAxesThenTileErrors(testCase)
            fig = FastSenseGrid(2, 1);
            testCase.addTeardown(@close, fig.hFigure);
            fig.axes(1);
            threw = false;
            try
                fig.tile(1);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'testAxesThenTileErrors');
        end

        function testMixedRenderAll(testCase)
            fig = FastSenseGrid(2, 2);
            testCase.addTeardown(@close, fig.hFigure);
            fig.tile(1).addLine(1:50, rand(1,50));
            ax2 = fig.axes(2); bar(ax2, [1 2 3], [10 20 15]);
            fig.tile(3).addLine(1:50, rand(1,50));
            ax4 = fig.axes(4); plot(ax4, 1:10, rand(1,10));
            fig.renderAll();
            testCase.verifyTrue(fig.tile(1).IsRendered, 'testMixedRenderAll: tile 1 rendered');
            testCase.verifyTrue(fig.tile(3).IsRendered, 'testMixedRenderAll: tile 3 rendered');
            % Raw axes tiles should still have valid handles
            testCase.verifyTrue(ishandle(ax2), 'testMixedRenderAll: ax2 valid');
            testCase.verifyTrue(ishandle(ax4), 'testMixedRenderAll: ax4 valid');
        end

        function testAxesThemeApplied(testCase)
            fig = FastSenseGrid(1, 1, 'Theme', 'dark');
            testCase.addTeardown(@close, fig.hFigure);
            ax = fig.axes(1);
            bgColor = get(ax, 'Color');
            testCase.verifyTrue(all(bgColor < [0.3 0.3 0.3]), 'testAxesThemeApplied: dark background');
        end

        function testLabelsOnRawAxes(testCase)
            fig = FastSenseGrid(2, 1);
            testCase.addTeardown(@close, fig.hFigure);
            ax = fig.axes(1);
            bar(ax, [1 2 3], [10 20 15]);
            fig.setTileTitle(1, 'Bar Chart');
            fig.setTileXLabel(1, 'Category');
            fig.setTileYLabel(1, 'Value');
            % No error = pass; verify title text
            titleObj = get(ax, 'Title');
            testCase.verifyEqual(get(titleObj, 'String'), 'Bar Chart', 'testLabelsOnRawAxes: title');
        end

        function testAxesOutOfBounds(testCase)
            fig = FastSenseGrid(2, 2);
            testCase.addTeardown(@close, fig.hFigure);
            threw = false;
            try
                fig.axes(5);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'testAxesOutOfBounds');
        end

        function testAxesTileSpanning(testCase)
            fig = FastSenseGrid(2, 2);
            testCase.addTeardown(@close, fig.hFigure);
            fig.setTileSpan(1, [1 2]);
            ax = fig.axes(1);
            pos = get(ax, 'Position');
            testCase.verifyTrue(pos(3) > 0.4, 'testAxesTileSpanning: wide enough');
        end
    end
end
