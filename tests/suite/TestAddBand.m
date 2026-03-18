classdef TestAddBand < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testAddBand(testCase)
            fp = FastSense();
            fp.addBand(-1, 1, 'FaceColor', [1 0.9 0.9], 'FaceAlpha', 0.3, 'Label', 'Safe');
            testCase.verifyEqual(numel(fp.Bands), 1, 'testAddBand: count');
            testCase.verifyEqual(fp.Bands(1).YLow, -1, 'testAddBand: YLow');
            testCase.verifyEqual(fp.Bands(1).YHigh, 1, 'testAddBand: YHigh');
            testCase.verifyEqual(fp.Bands(1).Label, 'Safe', 'testAddBand: Label');
        end

        function testAddMultipleBands(testCase)
            fp = FastSense();
            fp.addBand(-2, -1);
            fp.addBand(1, 2);
            testCase.verifyEqual(numel(fp.Bands), 2, 'testAddMultipleBands');
        end

        function testBandRendered(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.addBand(0.2, 0.8, 'FaceColor', [0 1 0], 'FaceAlpha', 0.2);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyNotEmpty(fp.Bands(1).hPatch, 'testBandRendered: hPatch created');
            testCase.verifyTrue(ishandle(fp.Bands(1).hPatch), 'testBandRendered: hPatch valid');
            ud = get(fp.Bands(1).hPatch, 'UserData');
            testCase.verifyEqual(ud.FastSense.Type, 'band', 'testBandRendered: UserData type');
        end

        function testBandRejectsAfterRender(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            threw = false;
            try
                fp.addBand(0, 1);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'testBandRejectsAfterRender');
        end

        function testBandDefaults(testCase)
            fp = FastSense();
            fp.addBand(0, 1);
            testCase.verifyTrue(fp.Bands(1).FaceAlpha > 0, 'testBandDefaults: FaceAlpha');
            testCase.verifyEqual(numel(fp.Bands(1).FaceColor), 3, 'testBandDefaults: FaceColor');
        end
    end
end
