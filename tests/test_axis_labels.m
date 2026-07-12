function test_axis_labels()
%TEST_AXIS_LABELS Tests for FastSense XLabel/YLabel options + auto-derive (#356).

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();
    add_fastsense_private_path();

    % testExplicitLabels
    fp = FastSense('XLabel', 'Time (s)', 'YLabel', 'Pressure (bar)');
    assert(strcmp(fp.XLabel, 'Time (s)'), 'testExplicitLabels: XLabel stored');
    assert(strcmp(fp.YLabel, 'Pressure (bar)'), 'testExplicitLabels: YLabel stored');
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(strcmp(get(get(fp.hAxes, 'XLabel'), 'String'), 'Time (s)'), 'testExplicitLabels: X drawn');
    assert(strcmp(get(get(fp.hAxes, 'YLabel'), 'String'), 'Pressure (bar)'), 'testExplicitLabels: Y drawn');
    close(fp.hFigure);

    % testDefaultUnlabeled — both '' => nothing drawn (unchanged behaviour)
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(isempty(get(get(fp.hAxes, 'XLabel'), 'String')), 'testDefaultUnlabeled: X empty');
    assert(isempty(get(get(fp.hAxes, 'YLabel'), 'String')), 'testDefaultUnlabeled: Y empty');
    close(fp.hFigure);

    % testAutoDeriveFromUnits
    fp = FastSense();
    fp.addTag(SensorTag('press_a', 'Units', 'bar'));
    assert(strcmp(fp.YLabel, 'bar'), 'testAutoDeriveFromUnits: YLabel = Units');

    % testAutoDeriveFallsBackToName
    fp = FastSense();
    fp.addTag(SensorTag('p', 'Name', 'Pump Pressure'));   % no Units
    assert(strcmp(fp.YLabel, 'Pump Pressure'), 'testAutoDeriveFallsBackToName');

    % testExplicitYLabelWinsOverDerivation
    fp = FastSense('YLabel', 'Custom');
    fp.addTag(SensorTag('press_a', 'Units', 'bar'));
    assert(strcmp(fp.YLabel, 'Custom'), 'testExplicitWins');

    % testMultiTagClearsDerivedLabel
    fp = FastSense();
    fp.addTag(SensorTag('a', 'Units', 'bar'));
    assert(strcmp(fp.YLabel, 'bar'), 'testMultiTag: derived after first');
    fp.addTag(SensorTag('b', 'Units', 'degC'));
    assert(isempty(fp.YLabel), 'testMultiTag: cleared once a second tag is added');

    fprintf('    All 6 axis-label tests passed.\n');
end
