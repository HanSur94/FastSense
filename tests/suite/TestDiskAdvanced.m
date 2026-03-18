classdef TestDiskAdvanced < matlab.unittest.TestCase
%TestDiskAdvanced Advanced integration tests for FastSense disk storage.
%   Covers: storage mode transitions, multiple disk lines, pyramid building,
%   updateData edge cases, re-render after update, and stress scenarios.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testMultipleDiskLines(testCase)
            fp = FastSense('StorageMode', 'disk');
            for i = 1:5
                x = linspace(0, 100, 10000);
                y = sin(x + i);
                fp.addLine(x, y, 'DisplayName', sprintf('Line%d', i));
            end
            testCase.verifyEqual(numel(fp.Lines), 5, 'multiDisk: 5 lines added');
            for i = 1:5
                testCase.verifyNotEmpty(fp.Lines(i).DataStore, ...
                    sprintf('multiDisk: line %d on disk', i));
            end
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(fp.IsRendered, 'multiDisk: rendered');
            for i = 1:5
                testCase.verifyTrue(isgraphics(fp.Lines(i).hLine, 'line'), ...
                    sprintf('multiDisk: line %d has handle', i));
            end
        end

        function testMemoryToDiskTransition(testCase)
            fp = FastSense('MemoryLimit', 10000);
            fp.addLine(1:50, rand(1, 50));  % memory (800 bytes < 10000)
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyEmpty(fp.Lines(1).DataStore, 'memToDisk: starts in memory');
            % Update with larger data that exceeds limit
            fp.updateData(1, linspace(0, 100, 5000), rand(1, 5000));  % 80000 bytes > 10000
            testCase.verifyNotEmpty(fp.Lines(1).DataStore, 'memToDisk: now on disk');
            testCase.verifyEqual(fp.Lines(1).NumPoints, 5000, 'memToDisk: NumPoints');
        end

        function testDiskToMemoryTransition(testCase)
            fp = FastSense('MemoryLimit', 10000);
            fp.addLine(linspace(0, 100, 5000), rand(1, 5000));  % disk
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyNotEmpty(fp.Lines(1).DataStore, 'diskToMem: starts on disk');
            % Get old DataStore file path
            ds = fp.Lines(1).DataStore;
            if ~isempty(ds.DbPath) && exist(ds.DbPath, 'file')
                oldPath = ds.DbPath;
            else
                oldPath = ds.BinPath;
            end
            % Update with smaller data
            fp.updateData(1, 1:10, rand(1, 10));  % 160 bytes < 10000
            testCase.verifyEmpty(fp.Lines(1).DataStore, 'diskToMem: now in memory');
            testCase.verifyEqual(fp.Lines(1).NumPoints, 10, 'diskToMem: NumPoints');
            % Old file should be cleaned up
            testCase.verifyTrue(~exist(oldPath, 'file'), 'diskToMem: old file cleaned');
        end

        function testUpdateDataPreservesCleanup(testCase)
            fp = FastSense('StorageMode', 'disk');
            fp.addLine(1:5000, rand(1, 5000));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            ds1 = fp.Lines(1).DataStore;
            if ~isempty(ds1.DbPath); path1 = ds1.DbPath; else; path1 = ds1.BinPath; end
            fp.updateData(1, 1:8000, rand(1, 8000));
            ds2 = fp.Lines(1).DataStore;
            if ~isempty(ds2.DbPath); path2 = ds2.DbPath; else; path2 = ds2.BinPath; end
            testCase.verifyTrue(~strcmp(path1, path2), 'updateCleanup: different files');
            testCase.verifyTrue(~exist(path1, 'file'), 'updateCleanup: old file removed');
            testCase.verifyTrue(exist(path2, 'file') > 0, 'updateCleanup: new file exists');
        end

        function testRenderUpdateReRenderCycle(testCase)
            fp = FastSense('StorageMode', 'disk');
            x = linspace(0, 100, 20000);
            fp.addLine(x, sin(x));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            plotY1 = get(fp.Lines(1).hLine, 'YData');
            % Update with different data
            fp.updateData(1, x, cos(x));
            drawnow; pause(0.3);
            plotY2 = get(fp.Lines(1).hLine, 'YData');
            % Data should have changed (sin != cos)
            testCase.verifyTrue(~isequal(plotY1, plotY2), 'reRender: data changed after update');
        end

        function testVeryNarrowZoomOnDisk(testCase)
            fp = FastSense('StorageMode', 'disk');
            n = 100000;
            x = linspace(0, 1000, n);
            y = sin(x);
            fp.addLine(x, y);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            set(fp.hAxes, 'XLim', [500, 500.1]);  % very narrow zoom
            drawnow; pause(0.3);
            plotX = get(fp.Lines(1).hLine, 'XData');
            testCase.verifyNotEmpty(plotX, 'narrowZoom: should have data');
            testCase.verifyTrue(all(plotX >= 499 & plotX <= 501), 'narrowZoom: data in range');
        end

        function testZoomInThenOut(testCase)
            fp = FastSense('StorageMode', 'disk');
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            fp.addLine(x, y);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            % Zoom in
            set(fp.hAxes, 'XLim', [40 60]);
            drawnow; pause(0.3);
            nZoomed = numel(get(fp.Lines(1).hLine, 'XData'));
            % Zoom back out
            set(fp.hAxes, 'XLim', [0 100]);
            drawnow; pause(0.3);
            nFull = numel(get(fp.Lines(1).hLine, 'XData'));
            % Full view should have more (or equal) points
            testCase.verifyTrue(nFull >= nZoomed, 'zoomOut: full view >= zoomed view');
        end

        function testMixedMemDiskDataFidelity(testCase)
            fp = FastSense('MemoryLimit', 1000);
            x1 = 1:50; y1 = x1 * 2;       % memory
            x2 = linspace(0, 100, 5000); y2 = x2 * 3;  % disk
            fp.addLine(x1, y1, 'DisplayName', 'Mem');
            fp.addLine(x2, y2, 'DisplayName', 'Disk');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            % Check memory line data
            pY1 = get(fp.Lines(1).hLine, 'YData');
            pX1 = get(fp.Lines(1).hLine, 'XData');
            testCase.verifyLessThan(max(abs(pY1 - pX1 * 2)), 0.01, 'mixedData: memory Y=2X');
            % Check disk line data (downsampled, so check relationship)
            pY2 = get(fp.Lines(2).hLine, 'YData');
            pX2 = get(fp.Lines(2).hLine, 'XData');
            testCase.verifyLessThan(max(abs(pY2 - pX2 * 3)), 0.1, 'mixedData: disk Y=3X');
        end

        function testDeleteCleansAllDiskFiles(testCase)
            fp = FastSense('StorageMode', 'disk');
            paths = {};
            for i = 1:3
                fp.addLine(1:5000, rand(1, 5000));
                ds = fp.Lines(i).DataStore;
                if ~isempty(ds.DbPath); paths{i} = ds.DbPath; else; paths{i} = ds.BinPath; end
            end
            delete(fp);
            for i = 1:3
                testCase.verifyTrue(~exist(paths{i}, 'file'), ...
                    sprintf('multiCleanup: file %d not deleted', i));
            end
        end

        function testDiskLineWithNaN(testCase)
            fp = FastSense('StorageMode', 'disk');
            n = 10000;
            x = linspace(0, 100, n);
            y = sin(x);
            y(1000:1100) = NaN;  % NaN gap
            fp.addLine(x, y);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(fp.IsRendered, 'nanDisk: rendered');
        end

        function testThresholdDiskLineWithNaN(testCase)
            fp = FastSense('StorageMode', 'disk');
            x = linspace(0, 100, 10000);
            y = sin(x); y(500:600) = NaN;
            fp.addLine(x, y);
            fp.addThreshold(0.5, 'Direction', 'upper', 'ShowViolations', true);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(isgraphics(fp.Thresholds(1).hLine, 'line'), 'nanThreshold: line');
        end

        function testLowerThresholdOnDiskLine(testCase)
            fp = FastSense('StorageMode', 'disk');
            x = linspace(0, 100, 10000);
            y = sin(x);
            fp.addLine(x, y);
            fp.addThreshold(-0.5, 'Direction', 'lower', 'ShowViolations', true);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(isgraphics(fp.Thresholds(1).hLine, 'line'), 'lowerThreshDisk: line');
        end

        function testMultipleThresholdsOnDiskLine(testCase)
            fp = FastSense('StorageMode', 'disk');
            x = linspace(0, 100, 20000);
            y = sin(x);
            fp.addLine(x, y);
            fp.addThreshold(0.5, 'Direction', 'upper', 'ShowViolations', true);
            fp.addThreshold(-0.5, 'Direction', 'lower', 'ShowViolations', true);
            fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyEqual(numel(fp.Thresholds), 3, 'multiThreshDisk: 3 thresholds');
        end

        function testMemoryLimitExactBoundary(testCase)
            fp = FastSense('MemoryLimit', 1600);  % 100 points * 8 * 2 = 1600
            fp.addLine(1:100, rand(1, 100));
            % 1600 bytes == 1600 limit -> not strictly greater, stays in memory
            testCase.verifyEmpty(fp.Lines(1).DataStore, 'boundary: at limit stays memory');
            % One more point pushes over
            fp.addLine(1:101, rand(1, 101));  % 1616 > 1600
            testCase.verifyNotEmpty(fp.Lines(2).DataStore, 'boundary: over limit goes disk');
        end

        function testRapidSequentialUpdates(testCase)
            fp = FastSense('StorageMode', 'disk');
            fp.addLine(1:5000, rand(1, 5000));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            for i = 1:10
                fp.updateData(1, linspace(0, 100, 5000+i*100), rand(1, 5000+i*100));
            end
            testCase.verifyEqual(fp.Lines(1).NumPoints, 5000 + 10*100, 'rapidUpdate: final count');
            testCase.verifyNotEmpty(fp.Lines(1).DataStore, 'rapidUpdate: still on disk');
        end
    end
end
