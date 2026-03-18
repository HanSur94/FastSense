classdef TestDiskStorage < matlab.unittest.TestCase
%TestDiskStorage Integration tests for FastSense disk-backed storage.
%   Tests that FastSense correctly stores large datasets on disk via
%   FastSenseDataStore and that render, zoom/pan, updateData, and cleanup
%   all work transparently with disk-backed lines.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testDefaultStorageMode(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10));
            testCase.verifyEqual(fp.StorageMode, 'auto', 'testDefaultStorageMode');
        end

        function testStorageModeConstructor(testCase)
            fp = FastSense('StorageMode', 'disk');
            testCase.verifyEqual(fp.StorageMode, 'disk', 'testStorageModeConstructor');
        end

        function testMemoryLimitDefault(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10));
            testCase.verifyEqual(fp.MemoryLimit, 500e6, 'testMemoryLimitDefault');
        end

        function testMemoryLimitConstructor(testCase)
            fp = FastSense('MemoryLimit', 100e6);
            testCase.verifyEqual(fp.MemoryLimit, 100e6, 'testMemoryLimitConstructor');
        end

        function testAutoModeDiskTrigger(testCase)
            % data exceeding MemoryLimit goes to disk
            fp = FastSense('MemoryLimit', 1000);  % very low threshold: 1000 bytes
            n = 1000;  % 1000 points * 8 bytes * 2 = 16000 bytes > 1000
            x = linspace(0, 10, n);
            y = sin(x);
            fp.addLine(x, y);
            testCase.verifyNotEmpty(fp.Lines(1).DataStore, ...
                'testAutoModeDiskTrigger: should have DataStore');
            testCase.verifyEmpty(fp.Lines(1).X, ...
                'testAutoModeDiskTrigger: X should be empty (on disk)');
            testCase.verifyEmpty(fp.Lines(1).Y, ...
                'testAutoModeDiskTrigger: Y should be empty (on disk)');
            testCase.verifyEqual(fp.Lines(1).NumPoints, n, ...
                'testAutoModeDiskTrigger: NumPoints must be correct');
        end

        function testAutoModeMemoryForSmall(testCase)
            % small data stays in memory
            fp = FastSense('MemoryLimit', 1e9);  % 1 GB threshold
            fp.addLine(1:100, rand(1, 100));
            testCase.verifyEmpty(fp.Lines(1).DataStore, ...
                'testAutoModeMemoryForSmall: should NOT have DataStore');
            testCase.verifyNotEmpty(fp.Lines(1).X, ...
                'testAutoModeMemoryForSmall: X should be in memory');
        end

        function testForceDiskMode(testCase)
            % StorageMode='disk' forces all data to disk
            fp = FastSense('StorageMode', 'disk');
            fp.addLine(1:50, rand(1, 50));
            testCase.verifyNotEmpty(fp.Lines(1).DataStore, ...
                'testForceDiskMode: small data should still go to disk');
            testCase.verifyEqual(fp.Lines(1).NumPoints, 50, ...
                'testForceDiskMode: NumPoints');
        end

        function testForceMemoryMode(testCase)
            % StorageMode='memory' keeps all data in RAM
            fp = FastSense('StorageMode', 'memory', 'MemoryLimit', 100);
            fp.addLine(1:10000, rand(1, 10000));
            testCase.verifyEmpty(fp.Lines(1).DataStore, ...
                'testForceMemoryMode: should NOT use disk even if above limit');
        end

        function testRenderDiskLine(testCase)
            % disk-backed line renders without error
            fp = FastSense('StorageMode', 'disk');
            n = 20000;
            x = linspace(0, 100, n);
            y = sin(x);
            fp.addLine(x, y, 'DisplayName', 'DiskSine');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(fp.IsRendered, 'testRenderDiskLine: should be rendered');
            testCase.verifyTrue(isgraphics(fp.Lines(1).hLine, 'line'), ...
                'testRenderDiskLine: should have a line handle');
            % The plotted data should be downsampled (not all n points)
            plotX = get(fp.Lines(1).hLine, 'XData');
            testCase.verifyTrue(numel(plotX) < n, ...
                'testRenderDiskLine: plotted points should be downsampled');
            testCase.verifyTrue(numel(plotX) > 10, ...
                'testRenderDiskLine: should have some plotted points');
        end

        function testRenderMixedLines(testCase)
            % mix of memory and disk lines renders
            fp = FastSense('MemoryLimit', 1000);
            fp.addLine(1:10, rand(1, 10), 'DisplayName', 'Small');      % memory
            fp.addLine(linspace(0,100,5000), rand(1,5000), 'DisplayName', 'Large'); % disk
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(fp.IsRendered, 'testRenderMixedLines: should render');
            testCase.verifyTrue(isgraphics(fp.Lines(1).hLine, 'line'), 'testRenderMixedLines: L1');
            testCase.verifyTrue(isgraphics(fp.Lines(2).hLine, 'line'), 'testRenderMixedLines: L2');
        end

        function testZoomDiskLine(testCase)
            % zooming re-downsamples from disk correctly
            fp = FastSense('StorageMode', 'disk');
            n = 50000;
            x = linspace(0, 100, n);
            y = sin(x);
            fp.addLine(x, y);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);

            % Zoom to a narrow range
            set(fp.hAxes, 'XLim', [40 60]);
            drawnow;
            pause(0.3);

            plotX = get(fp.Lines(1).hLine, 'XData');
            % All plotted points should be within the visible range (with padding)
            testCase.verifyTrue(all(plotX >= 39), 'testZoomDiskLine: plotted X too low');
            testCase.verifyTrue(all(plotX <= 61), 'testZoomDiskLine: plotted X too high');
            testCase.verifyTrue(numel(plotX) > 10, 'testZoomDiskLine: should have points');
        end

        function testZoomDiskLineDataFidelity(testCase)
            % zoomed data preserves signal shape
            fp = FastSense('StorageMode', 'disk');
            n = 100000;
            x = linspace(0, 100, n);
            y = x * 2;  % simple linear — easy to verify
            fp.addLine(x, y);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);

            set(fp.hAxes, 'XLim', [10 20]);
            drawnow;
            pause(0.3);

            plotX = get(fp.Lines(1).hLine, 'XData');
            plotY = get(fp.Lines(1).hLine, 'YData');
            % Y should be approximately 2*X for all plotted points
            maxErr = max(abs(plotY - plotX * 2));
            testCase.verifyLessThan(maxErr, 0.1, ...
                sprintf('testZoomDiskLineDataFidelity: Y != 2*X, maxErr=%.4f', maxErr));
        end

        function testUpdateDataDisk(testCase)
            % updateData replaces disk-backed data
            fp = FastSense('StorageMode', 'disk');
            x = linspace(0, 10, 10000);
            y = sin(x);
            fp.addLine(x, y);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);

            newX = linspace(0, 20, 15000);
            newY = cos(newX);
            fp.updateData(1, newX, newY);
            testCase.verifyEqual(fp.Lines(1).NumPoints, 15000, ...
                'testUpdateDataDisk: NumPoints after update');
            testCase.verifyNotEmpty(fp.Lines(1).DataStore, ...
                'testUpdateDataDisk: should still have DataStore');

            % Pyramid should have been cleared
            testCase.verifyEmpty(fp.Lines(1).Pyramid, ...
                'testUpdateDataDisk: pyramid should be cleared');
        end

        function testThresholdsDiskLine(testCase)
            % violations render correctly on disk lines
            fp = FastSense('StorageMode', 'disk');
            n = 10000;
            x = linspace(0, 100, n);
            y = sin(x);  % values between -1 and 1
            fp.addLine(x, y);
            fp.addThreshold(0.5, 'Direction', 'upper', 'ShowViolations', true);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(isgraphics(fp.Thresholds(1).hLine, 'line'), ...
                'testThresholdsDiskLine: threshold line created');
        end

        function testDeleteCleansDiskFiles(testCase)
            % deleting FastSense cleans up DataStore files
            fp = FastSense('StorageMode', 'disk');
            fp.addLine(1:5000, rand(1, 5000));
            ds = fp.Lines(1).DataStore;
            % Get the file path before deletion
            if ~isempty(ds.DbPath) && exist(ds.DbPath, 'file')
                fpath = ds.DbPath;
            else
                fpath = ds.BinPath;
            end
            testCase.verifyTrue(exist(fpath, 'file') > 0, ...
                'testDeleteCleansDiskFiles: temp file should exist');
            delete(fp);
            testCase.verifyTrue(~exist(fpath, 'file'), ...
                'testDeleteCleansDiskFiles: temp file should be cleaned up');
        end

        function testLineNumPoints(testCase)
            % works for both memory and disk lines
            fp = FastSense('MemoryLimit', 1000);
            fp.addLine(1:50, rand(1, 50));             % memory
            fp.addLine(1:5000, rand(1, 5000));         % disk
            testCase.verifyEqual(fp.lineNumPoints(1), 50, 'testLineNumPoints: memory line');
            testCase.verifyEqual(fp.lineNumPoints(2), 5000, 'testLineNumPoints: disk line');
        end

        function testLineXRange(testCase)
            % returns correct endpoints for both storage types
            fp = FastSense('MemoryLimit', 1000);
            fp.addLine(5:100, rand(1, 96));            % memory
            fp.addLine(linspace(10,200,5000), rand(1,5000));  % disk
            [mn1, mx1] = fp.lineXRange(1);
            testCase.verifyEqual(mn1, 5, 'testLineXRange: memory XMin');
            testCase.verifyEqual(mx1, 100, 'testLineXRange: memory XMax');
            [mn2, mx2] = fp.lineXRange(2);
            testCase.verifyEqual(mn2, 10, 'testLineXRange: disk XMin');
            testCase.verifyEqual(mx2, 200, 'testLineXRange: disk XMax');
        end
    end
end
