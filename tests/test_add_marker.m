function test_add_marker()
%TEST_ADD_MARKER Tests for FastSense.addMarker method.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); setup();
    add_fastsense_private_path();

    % testAddMarker
    fp = FastSense();
    fp.addMarker([10 20 30], [1 2 3], 'Marker', 'v', 'Color', [1 0 0], 'Label', 'Faults');
    assert(numel(fp.Markers) == 1, 'testAddMarker: count');
    assert(isequal(fp.Markers(1).X, [10 20 30]), 'testAddMarker: X');
    assert(strcmp(fp.Markers(1).Label, 'Faults'), 'testAddMarker: Label');

    % testMarkerRendered
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.addMarker([10 50], [0.5 0.8], 'Marker', 'd', 'MarkerSize', 10);
    fp.render();
    assert(~isempty(fp.Markers(1).hLine), 'testMarkerRendered: hLine');
    assert(ishandle(fp.Markers(1).hLine), 'testMarkerRendered: valid handle');
    ud = get(fp.Markers(1).hLine, 'UserData');
    assert(strcmp(ud.FastSense.Type, 'marker'), 'testMarkerRendered: UserData type');
    close(fp.hFigure);

    % testMarkerDefaults
    fp = FastSense();
    fp.addMarker([5], [1]);
    assert(~isempty(fp.Markers(1).Marker), 'testMarkerDefaults: Marker shape');
    assert(fp.Markers(1).MarkerSize > 0, 'testMarkerDefaults: MarkerSize');

    % testMarkerRejectsAfterRender
    fp = FastSense();
    fp.addLine(1:10, rand(1,10));
    fp.render();
    threw = false;
    try
        fp.addMarker([1], [1]);
    catch
        threw = true;
    end
    assert(threw, 'testMarkerRejectsAfterRender');
    close(fp.hFigure);

    fprintf('    All 4 addMarker tests passed.\n');
end
