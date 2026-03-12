classdef TestDashboardLayout < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            layout = DashboardLayout();
            testCase.verifyEqual(layout.Columns, 12);
            testCase.verifyTrue(isempty(layout.Widgets));
        end

        function testComputePosition(testCase)
            layout = DashboardLayout();
            layout.ContentArea = [0 0 1 1];

            pos = layout.computePosition([1 1 6 1]);

            testCase.verifyLength(pos, 4);
            testCase.verifyGreaterThan(pos(1), 0);
            testCase.verifyGreaterThan(pos(2), 0);
            testCase.verifyGreaterThan(pos(3), 0);
            testCase.verifyGreaterThan(pos(4), 0);
        end

        function testFullWidthWidget(testCase)
            layout = DashboardLayout();
            layout.ContentArea = [0 0 1 1];

            pos12 = layout.computePosition([1 1 12 1]);
            pos6  = layout.computePosition([1 1 6 1]);

            testCase.verifyGreaterThan(pos12(3), pos6(3));
        end

        function testAdjacentWidgetsNoOverlap(testCase)
            layout = DashboardLayout();
            layout.ContentArea = [0 0 1 1];

            pos1 = layout.computePosition([1 1 6 1]);
            pos2 = layout.computePosition([7 1 6 1]);

            rightEdge1 = pos1(1) + pos1(3);
            leftEdge2 = pos2(1);
            testCase.verifyLessThanOrEqual(rightEdge1, leftEdge2 + 0.001);
        end

        function testRowStacking(testCase)
            layout = DashboardLayout();
            layout.ContentArea = [0 0 1 1];
            layout.TotalRows = 3;

            pos_r1 = layout.computePosition([1 1 12 1]);
            pos_r2 = layout.computePosition([1 2 12 1]);

            testCase.verifyGreaterThan(pos_r1(2), pos_r2(2));
        end

        function testMaxRowCalculation(testCase)
            layout = DashboardLayout();
            addpath(fullfile(fileparts(mfilename('fullpath'))));
            widgets = {MockDashboardWidget(), MockDashboardWidget()};
            widgets{1}.Position = [1 1 6 2];
            widgets{2}.Position = [1 3 6 3];

            maxRow = layout.calculateMaxRow(widgets);
            testCase.verifyEqual(maxRow, 5);
        end

        function testOverlapDetection(testCase)
            layout = DashboardLayout();

            testCase.verifyTrue(layout.overlaps([1 1 6 2], [3 1 6 2]));
            testCase.verifyFalse(layout.overlaps([1 1 6 2], [7 1 6 2]));
            testCase.verifyFalse(layout.overlaps([1 1 6 1], [1 2 6 1]));
        end

        function testResolveOverlap(testCase)
            layout = DashboardLayout();

            existing = {[1 1 6 2]};
            newPos = [3 1 6 2];

            resolved = layout.resolveOverlap(newPos, existing);
            testCase.verifyEqual(resolved(2), 3);
        end
    end
end
