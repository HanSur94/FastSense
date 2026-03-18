function test_disk_advanced()
%TEST_DISK_ADVANCED Advanced integration tests for FastSense disk storage.
%   Covers: storage mode transitions, multiple disk lines, pyramid building,
%   updateData edge cases, re-render after update, and stress scenarios.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastsense_private_path();

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIPPED: requires MATLAB PostSet listeners.\n');
        return;
    end

    fprintf('  --- Advanced disk storage tests ---\n');

    % 1. Multiple disk lines in same figure
    fp = FastSense('StorageMode', 'disk');
    for i = 1:5
        x = linspace(0, 100, 10000);
        y = sin(x + i);
        fp.addLine(x, y, 'DisplayName', sprintf('Line%d', i));
    end
    assert(numel(fp.Lines) == 5, 'multiDisk: 5 lines added');
    for i = 1:5
        assert(~isempty(fp.Lines(i).DataStore), ...
            sprintf('multiDisk: line %d on disk', i));
    end
    fp.render();
    assert(fp.IsRendered, 'multiDisk: rendered');
    for i = 1:5
        assert(isgraphics(fp.Lines(i).hLine, 'line'), ...
            sprintf('multiDisk: line %d has handle', i));
    end
    close(fp.hFigure);
    fprintf('    multiple disk lines: PASS\n');

    % 2. updateData: memory -> disk transition
    fp = FastSense('MemoryLimit', 10000);
    fp.addLine(1:50, rand(1, 50));  % memory (800 bytes < 10000)
    fp.render();
    assert(isempty(fp.Lines(1).DataStore), 'memToDisk: starts in memory');
    % Update with larger data that exceeds limit
    fp.updateData(1, linspace(0, 100, 5000), rand(1, 5000));  % 80000 bytes > 10000
    assert(~isempty(fp.Lines(1).DataStore), 'memToDisk: now on disk');
    assert(fp.Lines(1).NumPoints == 5000, 'memToDisk: NumPoints');
    close(fp.hFigure);
    fprintf('    memory -> disk transition: PASS\n');

    % 3. updateData: disk -> memory transition
    fp = FastSense('MemoryLimit', 10000);
    fp.addLine(linspace(0, 100, 5000), rand(1, 5000));  % disk
    fp.render();
    assert(~isempty(fp.Lines(1).DataStore), 'diskToMem: starts on disk');
    % Get old DataStore file path
    ds = fp.Lines(1).DataStore;
    if ~isempty(ds.DbPath) && exist(ds.DbPath, 'file')
        oldPath = ds.DbPath;
    else
        oldPath = ds.BinPath;
    end
    % Update with smaller data
    fp.updateData(1, 1:10, rand(1, 10));  % 160 bytes < 10000
    assert(isempty(fp.Lines(1).DataStore), 'diskToMem: now in memory');
    assert(fp.Lines(1).NumPoints == 10, 'diskToMem: NumPoints');
    % Old file should be cleaned up
    assert(~exist(oldPath, 'file'), 'diskToMem: old file cleaned');
    close(fp.hFigure);
    fprintf('    disk -> memory transition: PASS\n');

    % 4. updateData preserves old DataStore cleanup
    fp = FastSense('StorageMode', 'disk');
    fp.addLine(1:5000, rand(1, 5000));
    fp.render();
    ds1 = fp.Lines(1).DataStore;
    if ~isempty(ds1.DbPath); path1 = ds1.DbPath; else; path1 = ds1.BinPath; end
    fp.updateData(1, 1:8000, rand(1, 8000));
    ds2 = fp.Lines(1).DataStore;
    if ~isempty(ds2.DbPath); path2 = ds2.DbPath; else; path2 = ds2.BinPath; end
    assert(~strcmp(path1, path2), 'updateCleanup: different files');
    assert(~exist(path1, 'file'), 'updateCleanup: old file removed');
    assert(exist(path2, 'file') > 0, 'updateCleanup: new file exists');
    close(fp.hFigure);
    fprintf('    updateData cleans old DataStore: PASS\n');

    % 5. Render, update, re-render cycle
    fp = FastSense('StorageMode', 'disk');
    x = linspace(0, 100, 20000);
    fp.addLine(x, sin(x));
    fp.render();
    plotY1 = get(fp.Lines(1).hLine, 'YData');
    % Update with different data
    fp.updateData(1, x, cos(x));
    drawnow; pause(0.3);
    plotY2 = get(fp.Lines(1).hLine, 'YData');
    % Data should have changed (sin != cos)
    assert(~isequal(plotY1, plotY2), 'reRender: data changed after update');
    close(fp.hFigure);
    fprintf('    render-update-rerender cycle: PASS\n');

    % 6. Zoom to very narrow range on disk line
    fp = FastSense('StorageMode', 'disk');
    n = 100000;
    x = linspace(0, 1000, n);
    y = sin(x);
    fp.addLine(x, y);
    fp.render();
    set(fp.hAxes, 'XLim', [500, 500.1]);  % very narrow zoom
    drawnow; pause(0.3);
    plotX = get(fp.Lines(1).hLine, 'XData');
    assert(~isempty(plotX), 'narrowZoom: should have data');
    assert(all(plotX >= 499 & plotX <= 501), 'narrowZoom: data in range');
    close(fp.hFigure);
    fprintf('    very narrow zoom on disk: PASS\n');

    % 7. Zoom out to full range after narrow zoom
    fp = FastSense('StorageMode', 'disk');
    n = 50000;
    x = linspace(0, 100, n);
    y = sin(x);
    fp.addLine(x, y);
    fp.render();
    % Zoom in
    set(fp.hAxes, 'XLim', [40 60]);
    drawnow; pause(0.3);
    nZoomed = numel(get(fp.Lines(1).hLine, 'XData'));
    % Zoom back out
    set(fp.hAxes, 'XLim', [0 100]);
    drawnow; pause(0.3);
    nFull = numel(get(fp.Lines(1).hLine, 'XData'));
    % Full view should have more (or equal) points
    assert(nFull >= nZoomed, 'zoomOut: full view >= zoomed view');
    close(fp.hFigure);
    fprintf('    zoom in then out: PASS\n');

    % 8. Mixed memory+disk lines render with correct data
    fp = FastSense('MemoryLimit', 1000);
    x1 = 1:50; y1 = x1 * 2;       % memory
    x2 = linspace(0, 100, 5000); y2 = x2 * 3;  % disk
    fp.addLine(x1, y1, 'DisplayName', 'Mem');
    fp.addLine(x2, y2, 'DisplayName', 'Disk');
    fp.render();
    % Check memory line data
    pY1 = get(fp.Lines(1).hLine, 'YData');
    pX1 = get(fp.Lines(1).hLine, 'XData');
    assert(max(abs(pY1 - pX1 * 2)) < 0.01, 'mixedData: memory Y=2X');
    % Check disk line data (downsampled, so check relationship)
    pY2 = get(fp.Lines(2).hLine, 'YData');
    pX2 = get(fp.Lines(2).hLine, 'XData');
    assert(max(abs(pY2 - pX2 * 3)) < 0.1, 'mixedData: disk Y=3X');
    close(fp.hFigure);
    fprintf('    mixed mem+disk data fidelity: PASS\n');

    % 9. Delete with multiple disk lines cleans all files
    fp = FastSense('StorageMode', 'disk');
    paths = {};
    for i = 1:3
        fp.addLine(1:5000, rand(1, 5000));
        ds = fp.Lines(i).DataStore;
        if ~isempty(ds.DbPath); paths{i} = ds.DbPath; else; paths{i} = ds.BinPath; end
    end
    delete(fp);
    for i = 1:3
        assert(~exist(paths{i}, 'file'), ...
            sprintf('multiCleanup: file %d not deleted', i));
    end
    fprintf('    delete cleans all disk files: PASS\n');

    % 10. Disk line with NaN values renders without error
    fp = FastSense('StorageMode', 'disk');
    n = 10000;
    x = linspace(0, 100, n);
    y = sin(x);
    y(1000:1100) = NaN;  % NaN gap
    fp.addLine(x, y);
    fp.render();
    assert(fp.IsRendered, 'nanDisk: rendered');
    close(fp.hFigure);
    fprintf('    disk line with NaN gap: PASS\n');

    % 11. Threshold violations with disk line + NaN
    fp = FastSense('StorageMode', 'disk');
    x = linspace(0, 100, 10000);
    y = sin(x); y(500:600) = NaN;
    fp.addLine(x, y);
    fp.addThreshold(0.5, 'Direction', 'upper', 'ShowViolations', true);
    fp.render();
    assert(isgraphics(fp.Thresholds(1).hLine, 'line'), 'nanThreshold: line');
    close(fp.hFigure);
    fprintf('    threshold on disk+NaN line: PASS\n');

    % 12. Threshold with lower direction on disk line
    fp = FastSense('StorageMode', 'disk');
    x = linspace(0, 100, 10000);
    y = sin(x);
    fp.addLine(x, y);
    fp.addThreshold(-0.5, 'Direction', 'lower', 'ShowViolations', true);
    fp.render();
    assert(isgraphics(fp.Thresholds(1).hLine, 'line'), 'lowerThreshDisk: line');
    close(fp.hFigure);
    fprintf('    lower threshold on disk line: PASS\n');

    % 13. Multiple thresholds on disk line
    fp = FastSense('StorageMode', 'disk');
    x = linspace(0, 100, 20000);
    y = sin(x);
    fp.addLine(x, y);
    fp.addThreshold(0.5, 'Direction', 'upper', 'ShowViolations', true);
    fp.addThreshold(-0.5, 'Direction', 'lower', 'ShowViolations', true);
    fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true);
    fp.render();
    assert(numel(fp.Thresholds) == 3, 'multiThreshDisk: 3 thresholds');
    close(fp.hFigure);
    fprintf('    multiple thresholds on disk: PASS\n');

    % 14. MemoryLimit boundary: exactly at threshold
    fp = FastSense('MemoryLimit', 1600);  % 100 points * 8 * 2 = 1600
    fp.addLine(1:100, rand(1, 100));
    % 1600 bytes == 1600 limit → not strictly greater, stays in memory
    assert(isempty(fp.Lines(1).DataStore), 'boundary: at limit stays memory');
    % One more point pushes over
    fp.addLine(1:101, rand(1, 101));  % 1616 > 1600
    assert(~isempty(fp.Lines(2).DataStore), 'boundary: over limit goes disk');
    fprintf('    MemoryLimit exact boundary: PASS\n');

    % 15. Rapid sequential updateData calls
    fp = FastSense('StorageMode', 'disk');
    fp.addLine(1:5000, rand(1, 5000));
    fp.render();
    for i = 1:10
        fp.updateData(1, linspace(0, 100, 5000+i*100), rand(1, 5000+i*100));
    end
    assert(fp.Lines(1).NumPoints == 5000 + 10*100, 'rapidUpdate: final count');
    assert(~isempty(fp.Lines(1).DataStore), 'rapidUpdate: still on disk');
    close(fp.hFigure);
    fprintf('    rapid sequential updates: PASS\n');

    fprintf('\n    All 15 advanced disk storage tests passed.\n');
end
