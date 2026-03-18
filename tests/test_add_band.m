function test_add_band()
%TEST_ADD_BAND Tests for FastSense.addBand method.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastsense_private_path();

    % testAddBand
    fp = FastSense();
    fp.addBand(-1, 1, 'FaceColor', [1 0.9 0.9], 'FaceAlpha', 0.3, 'Label', 'Safe');
    assert(numel(fp.Bands) == 1, 'testAddBand: count');
    assert(fp.Bands(1).YLow == -1, 'testAddBand: YLow');
    assert(fp.Bands(1).YHigh == 1, 'testAddBand: YHigh');
    assert(strcmp(fp.Bands(1).Label, 'Safe'), 'testAddBand: Label');

    % testAddMultipleBands
    fp = FastSense();
    fp.addBand(-2, -1);
    fp.addBand(1, 2);
    assert(numel(fp.Bands) == 2, 'testAddMultipleBands');

    % testBandRendered
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.addBand(0.2, 0.8, 'FaceColor', [0 1 0], 'FaceAlpha', 0.2);
    fp.render();
    assert(~isempty(fp.Bands(1).hPatch), 'testBandRendered: hPatch created');
    assert(ishandle(fp.Bands(1).hPatch), 'testBandRendered: hPatch valid');
    ud = get(fp.Bands(1).hPatch, 'UserData');
    assert(strcmp(ud.FastSense.Type, 'band'), 'testBandRendered: UserData type');
    close(fp.hFigure);

    % testBandRejectsAfterRender
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    threw = false;
    try
        fp.addBand(0, 1);
    catch
        threw = true;
    end
    assert(threw, 'testBandRejectsAfterRender');
    close(fp.hFigure);

    % testBandDefaults
    fp = FastSense();
    fp.addBand(0, 1);
    assert(fp.Bands(1).FaceAlpha > 0, 'testBandDefaults: FaceAlpha');
    assert(numel(fp.Bands(1).FaceColor) == 3, 'testBandDefaults: FaceColor');

    fprintf('    All 5 addBand tests passed.\n');
end
