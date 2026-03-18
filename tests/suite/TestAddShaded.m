classdef TestAddShaded < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testAddShaded(testCase)
            x = 1:100;
            y1 = ones(1,100) * 2;
            y2 = ones(1,100) * -2;
            fp = FastSense();
            fp.addShaded(x, y1, y2, 'FaceColor', [0 0 1], 'FaceAlpha', 0.2);
            testCase.verifyEqual(numel(fp.Shadings), 1, 'testAddShaded: count');
            testCase.verifyEqual(fp.Shadings(1).X, x, 'testAddShaded: X');
            testCase.verifyEqual(fp.Shadings(1).Y1, y1, 'testAddShaded: Y1');
            testCase.verifyEqual(fp.Shadings(1).Y2, y2, 'testAddShaded: Y2');
        end

        function testShadedRendered(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.addShaded(1:100, ones(1,100), zeros(1,100), 'FaceColor', [1 0 0]);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyNotEmpty(fp.Shadings(1).hPatch, 'testShadedRendered: hPatch');
            testCase.verifyTrue(ishandle(fp.Shadings(1).hPatch), 'testShadedRendered: valid');
            ud = get(fp.Shadings(1).hPatch, 'UserData');
            testCase.verifyEqual(ud.FastSense.Type, 'shaded', 'testShadedRendered: type');
        end

        function testShadedValidation(testCase)
            fp = FastSense();
            threw = false;
            try
                fp.addShaded(1:10, 1:10, 1:5);  % mismatched lengths
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'testShadedValidation: length mismatch');
        end

        function testShadedMonotonicX(testCase)
            fp = FastSense();
            threw = false;
            try
                fp.addShaded([3 1 2], [1 1 1], [0 0 0]);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'testShadedMonotonicX');
        end

        function testShadedRejectsAfterRender(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            threw = false;
            try
                fp.addShaded(1:10, ones(1,10), zeros(1,10));
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'testShadedRejectsAfterRender');
        end

        function testShadedColumnVectors(testCase)
            fp = FastSense();
            fp.addShaded((1:10)', (1:10)', zeros(10,1));
            testCase.verifyTrue(isrow(fp.Shadings(1).X), 'testShadedColumnVectors: X row');
            testCase.verifyTrue(isrow(fp.Shadings(1).Y1), 'testShadedColumnVectors: Y1 row');
            testCase.verifyTrue(isrow(fp.Shadings(1).Y2), 'testShadedColumnVectors: Y2 row');
        end

        function testAddFill(testCase)
            fp = FastSense();
            x = 1:50;
            y = rand(1,50);
            fp.addFill(x, y, 'FaceColor', [0 0.5 1], 'FaceAlpha', 0.2);
            testCase.verifyEqual(numel(fp.Shadings), 1, 'testAddFill: creates shading');
            testCase.verifyTrue(all(fp.Shadings(1).Y2 == 0), 'testAddFill: baseline is 0');
        end

        function testAddFillCustomBaseline(testCase)
            fp = FastSense();
            fp.addFill(1:10, rand(1,10), 'Baseline', -1);
            testCase.verifyTrue(all(fp.Shadings(1).Y2 == -1), 'testAddFillCustomBaseline');
        end

        function testAddFillRendered(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.addFill(1:100, rand(1,100), 'FaceColor', [0 1 0]);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(ishandle(fp.Shadings(1).hPatch), 'testAddFillRendered: valid patch');
            ud = get(fp.Shadings(1).hPatch, 'UserData');
            testCase.verifyEqual(ud.FastSense.Type, 'shaded', 'testAddFillRendered: type is shaded');
        end
    end
end
