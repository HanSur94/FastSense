function test_disk_storage()
%TEST_DISK_STORAGE Integration tests for FastSense disk-backed storage.
%   Tests that FastSense correctly stores large datasets on disk via
%   FastSenseDataStore and that render, zoom/pan, updateData, and cleanup
%   all work transparently with disk-backed lines.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastsense_private_path();

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIPPED: requires MATLAB PostSet listeners.\n');
        return;
    end

    % --- StorageMode and MemoryLimit properties ---

    % testDefaultStorageMode: default is 'auto'
    fp = FastSense();
    fp.addLine(1:10, rand(1,10));
    assert(strcmp(fp.StorageMode, 'auto'), 'testDefaultStorageMode');

    % testStorageModeConstructor: can set via constructor
    fp = FastSense('StorageMode', 'disk');
    assert(strcmp(fp.StorageMode, 'disk'), 'testStorageModeConstructor');

    % testMemoryLimitDefault: default is 500e6
    fp = FastSense();
    fp.addLine(1:10, rand(1,10));
    assert(fp.MemoryLimit == 500e6, 'testMemoryLimitDefault');

    % testMemoryLimitConstructor: can override via constructor
    fp = FastSense('MemoryLimit', 100e6);
    assert(fp.MemoryLimit == 100e6, 'testMemoryLimitConstructor');

    % --- Auto storage mode triggers disk for large data ---

    % testAutoModeDiskTrigger: data exceeding MemoryLimit goes to disk
    fp = FastSense('MemoryLimit', 1000);  % very low threshold: 1000 bytes
    n = 1000;  % 1000 points * 8 bytes * 2 = 16000 bytes > 1000
    x = linspace(0, 10, n);
    y = sin(x);
    fp.addLine(x, y);
    assert(~isempty(fp.Lines(1).DataStore), ...
        'testAutoModeDiskTrigger: should have DataStore');
    assert(isempty(fp.Lines(1).X), ...
        'testAutoModeDiskTrigger: X should be empty (on disk)');
    assert(isempty(fp.Lines(1).Y), ...
        'testAutoModeDiskTrigger: Y should be empty (on disk)');
    assert(fp.Lines(1).NumPoints == n, ...
        'testAutoModeDiskTrigger: NumPoints must be correct');

    % testAutoModeMemoryForSmall: small data stays in memory
    fp = FastSense('MemoryLimit', 1e9);  % 1 GB threshold
    fp.addLine(1:100, rand(1, 100));
    assert(isempty(fp.Lines(1).DataStore), ...
        'testAutoModeMemoryForSmall: should NOT have DataStore');
    assert(~isempty(fp.Lines(1).X), ...
        'testAutoModeMemoryForSmall: X should be in memory');

    % testForceDiskMode: StorageMode='disk' forces all data to disk
    fp = FastSense('StorageMode', 'disk');
    fp.addLine(1:50, rand(1, 50));
    assert(~isempty(fp.Lines(1).DataStore), ...
        'testForceDiskMode: small data should still go to disk');
    assert(fp.Lines(1).NumPoints == 50, ...
        'testForceDiskMode: NumPoints');

    % testForceMemoryMode: StorageMode='memory' keeps all data in RAM
    fp = FastSense('StorageMode', 'memory', 'MemoryLimit', 100);
    fp.addLine(1:10000, rand(1, 10000));
    assert(isempty(fp.Lines(1).DataStore), ...
        'testForceMemoryMode: should NOT use disk even if above limit');

    % --- Render with disk-backed data ---

    % testRenderDiskLine: disk-backed line renders without error
    fp = FastSense('StorageMode', 'disk');
    n = 20000;
    x = linspace(0, 100, n);
    y = sin(x);
    fp.addLine(x, y, 'DisplayName', 'DiskSine');
    fp.render();
    assert(fp.IsRendered, 'testRenderDiskLine: should be rendered');
    assert(isgraphics(fp.Lines(1).hLine, 'line'), ...
        'testRenderDiskLine: should have a line handle');
    % The plotted data should be downsampled (not all n points)
    plotX = get(fp.Lines(1).hLine, 'XData');
    assert(numel(plotX) < n, ...
        'testRenderDiskLine: plotted points should be downsampled');
    assert(numel(plotX) > 10, ...
        'testRenderDiskLine: should have some plotted points');
    close(fp.hFigure);

    % testRenderMixedLines: mix of memory and disk lines renders
    fp = FastSense('MemoryLimit', 1000);
    fp.addLine(1:10, rand(1, 10), 'DisplayName', 'Small');      % memory
    fp.addLine(linspace(0,100,5000), rand(1,5000), 'DisplayName', 'Large'); % disk
    fp.render();
    assert(fp.IsRendered, 'testRenderMixedLines: should render');
    assert(isgraphics(fp.Lines(1).hLine, 'line'), 'testRenderMixedLines: L1');
    assert(isgraphics(fp.Lines(2).hLine, 'line'), 'testRenderMixedLines: L2');
    close(fp.hFigure);

    % --- Zoom/pan with disk-backed data ---

    % testZoomDiskLine: zooming re-downsamples from disk correctly
    fp = FastSense('StorageMode', 'disk');
    n = 50000;
    x = linspace(0, 100, n);
    y = sin(x);
    fp.addLine(x, y);
    fp.render();

    % Zoom to a narrow range
    set(fp.hAxes, 'XLim', [40 60]);
    drawnow;
    pause(0.3);

    plotX = get(fp.Lines(1).hLine, 'XData');
    % All plotted points should be within the visible range (with padding)
    assert(all(plotX >= 39), 'testZoomDiskLine: plotted X too low');
    assert(all(plotX <= 61), 'testZoomDiskLine: plotted X too high');
    assert(numel(plotX) > 10, 'testZoomDiskLine: should have points');
    close(fp.hFigure);

    % testZoomDiskLineDataFidelity: zoomed data preserves signal shape
    fp = FastSense('StorageMode', 'disk');
    n = 100000;
    x = linspace(0, 100, n);
    y = x * 2;  % simple linear — easy to verify
    fp.addLine(x, y);
    fp.render();

    set(fp.hAxes, 'XLim', [10 20]);
    drawnow;
    pause(0.3);

    plotX = get(fp.Lines(1).hLine, 'XData');
    plotY = get(fp.Lines(1).hLine, 'YData');
    % Y should be approximately 2*X for all plotted points
    maxErr = max(abs(plotY - plotX * 2));
    assert(maxErr < 0.1, ...
        sprintf('testZoomDiskLineDataFidelity: Y != 2*X, maxErr=%.4f', maxErr));
    close(fp.hFigure);

    % --- updateData with disk-backed storage ---

    % testUpdateDataDisk: updateData replaces disk-backed data
    fp = FastSense('StorageMode', 'disk');
    x = linspace(0, 10, 10000);
    y = sin(x);
    fp.addLine(x, y);
    fp.render();

    newX = linspace(0, 20, 15000);
    newY = cos(newX);
    fp.updateData(1, newX, newY);
    assert(fp.Lines(1).NumPoints == 15000, ...
        'testUpdateDataDisk: NumPoints after update');
    assert(~isempty(fp.Lines(1).DataStore), ...
        'testUpdateDataDisk: should still have DataStore');

    % Pyramid should have been cleared
    assert(isempty(fp.Lines(1).Pyramid), ...
        'testUpdateDataDisk: pyramid should be cleared');
    close(fp.hFigure);

    % --- Threshold violations with disk-backed data ---

    % testThresholdsDiskLine: violations render correctly on disk lines
    fp = FastSense('StorageMode', 'disk');
    n = 10000;
    x = linspace(0, 100, n);
    y = sin(x);  % values between -1 and 1
    fp.addLine(x, y);
    fp.addThreshold(0.5, 'Direction', 'upper', 'ShowViolations', true);
    fp.render();
    assert(isgraphics(fp.Thresholds(1).hLine, 'line'), ...
        'testThresholdsDiskLine: threshold line created');
    close(fp.hFigure);

    % --- Cleanup on delete ---

    % testDeleteCleansDiskFiles: deleting FastSense cleans up DataStore files
    fp = FastSense('StorageMode', 'disk');
    fp.addLine(1:5000, rand(1, 5000));
    ds = fp.Lines(1).DataStore;
    % Get the file path before deletion
    if ~isempty(ds.DbPath) && exist(ds.DbPath, 'file')
        fpath = ds.DbPath;
    else
        fpath = ds.BinPath;
    end
    assert(exist(fpath, 'file') > 0, ...
        'testDeleteCleansDiskFiles: temp file should exist');
    delete(fp);
    assert(~exist(fpath, 'file'), ...
        'testDeleteCleansDiskFiles: temp file should be cleaned up');

    % --- lineNumPoints helper ---

    % testLineNumPoints: works for both memory and disk lines
    fp = FastSense('MemoryLimit', 1000);
    fp.addLine(1:50, rand(1, 50));             % memory
    fp.addLine(1:5000, rand(1, 5000));         % disk
    assert(fp.lineNumPoints(1) == 50, 'testLineNumPoints: memory line');
    assert(fp.lineNumPoints(2) == 5000, 'testLineNumPoints: disk line');

    % --- lineXRange helper ---

    % testLineXRange: returns correct endpoints for both storage types
    fp = FastSense('MemoryLimit', 1000);
    fp.addLine(5:100, rand(1, 96));            % memory
    fp.addLine(linspace(10,200,5000), rand(1,5000));  % disk
    [mn1, mx1] = fp.lineXRange(1);
    assert(mn1 == 5, 'testLineXRange: memory XMin');
    assert(mx1 == 100, 'testLineXRange: memory XMax');
    [mn2, mx2] = fp.lineXRange(2);
    assert(mn2 == 10, 'testLineXRange: disk XMin');
    assert(mx2 == 200, 'testLineXRange: disk XMax');

    fprintf('    All 17 disk storage tests passed.\n');
end
