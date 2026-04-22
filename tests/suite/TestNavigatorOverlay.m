classdef TestNavigatorOverlay < matlab.unittest.TestCase
    properties (Access = private)
        hFig
        hAxes
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function createFixture(testCase)
            testCase.hFig = figure('Visible', 'off');
            testCase.hAxes = axes('Parent', testCase.hFig);
            % Draw a dummy line so axes has data range
            plot(testCase.hAxes, [0 100], [0 10]);
            xlim(testCase.hAxes, [0 100]);
            ylim(testCase.hAxes, [0 10]);
        end
    end

    methods (TestMethodTeardown)
        function destroyFixture(testCase)
            if ishandle(testCase.hFig)
                delete(testCase.hFig);
            end
        end
    end

    methods (Test)
        %% Construction
        function testConstructorCreatesOverlay(testCase)
            ov = NavigatorOverlay(testCase.hAxes);
            testCase.verifyClass(ov, ?NavigatorOverlay);
            testCase.verifyTrue(ishandle(ov.hRegion));
            testCase.verifyTrue(ishandle(ov.hDimLeft));
            testCase.verifyTrue(ishandle(ov.hDimRight));
            testCase.verifyTrue(ishandle(ov.hEdgeLeft));
            testCase.verifyTrue(ishandle(ov.hEdgeRight));
            delete(ov);
        end

        %% setRange
        function testSetRangeUpdatesPatches(testCase)
            ov = NavigatorOverlay(testCase.hAxes);
            ov.setRange(20, 60);

            % Region patch X vertices should span [20, 60]
            regionX = get(ov.hRegion, 'XData');
            testCase.verifyEqual(min(regionX), 20, 'AbsTol', 1e-10);
            testCase.verifyEqual(max(regionX), 60, 'AbsTol', 1e-10);

            % DimLeft should cover [0, 20]
            dimLX = get(ov.hDimLeft, 'XData');
            testCase.verifyEqual(min(dimLX), 0, 'AbsTol', 1e-10);
            testCase.verifyEqual(max(dimLX), 20, 'AbsTol', 1e-10);

            % DimRight should cover [60, 100]
            dimRX = get(ov.hDimRight, 'XData');
            testCase.verifyEqual(min(dimRX), 60, 'AbsTol', 1e-10);
            testCase.verifyEqual(max(dimRX), 100, 'AbsTol', 1e-10);

            % Edge lines at boundaries
            edgeLX = get(ov.hEdgeLeft, 'XData');
            testCase.verifyEqual(edgeLX(1), 20, 'AbsTol', 1e-10);
            edgeRX = get(ov.hEdgeRight, 'XData');
            testCase.verifyEqual(edgeRX(1), 60, 'AbsTol', 1e-10);

            delete(ov);
        end

        %% Boundary clamping
        function testSetRangeClampsToAxesLimits(testCase)
            ov = NavigatorOverlay(testCase.hAxes);
            ov.setRange(-10, 120);

            regionX = get(ov.hRegion, 'XData');
            testCase.verifyEqual(min(regionX), 0, 'AbsTol', 1e-10);
            testCase.verifyEqual(max(regionX), 100, 'AbsTol', 1e-10);
            delete(ov);
        end

        %% Minimum width
        function testSetRangeEnforcesMinimumWidth(testCase)
            ov = NavigatorOverlay(testCase.hAxes);
            % 0.5% of range [0,100] = 0.5
            ov.setRange(50, 50.1);

            regionX = get(ov.hRegion, 'XData');
            actualWidth = max(regionX) - min(regionX);
            testCase.verifyGreaterThanOrEqual(actualWidth, 0.5);
            delete(ov);
        end

        %% OnRangeChanged callback
        function testCallbackFiresOnSetRange(testCase)
            ov = NavigatorOverlay(testCase.hAxes);
            callbackFired = false;
            capturedRange = [0 0];
            ov.OnRangeChanged = @(xMin, xMax) deal_callback(xMin, xMax);
            ov.setRange(30, 70);

            testCase.verifyTrue(callbackFired);
            testCase.verifyEqual(capturedRange, [30 70], 'AbsTol', 1e-10);
            delete(ov);

            function deal_callback(xMin, xMax)
                callbackFired = true;
                capturedRange = [xMin xMax];
            end
        end

        %% Cleanup
        function testDeleteRemovesGraphics(testCase)
            ov = NavigatorOverlay(testCase.hAxes);
            hReg = ov.hRegion;
            delete(ov);
            testCase.verifyFalse(ishandle(hReg));
        end

        function testDeleteRestoresFigureCallbacks(testCase)
            hFig = testCase.hFig;
            oldDown = get(hFig, 'WindowButtonDownFcn');
            ov = NavigatorOverlay(testCase.hAxes);
            delete(ov);
            restoredDown = get(hFig, 'WindowButtonDownFcn');
            testCase.verifyEqual(restoredDown, oldDown);
        end

        %% Panning preserves region width at boundary
        function testPanPreservesWidthAtLeftBoundary(testCase)
            ov = NavigatorOverlay(testCase.hAxes);
            ov.setRange(5, 25);  % width = 20
            ov.setRange(-10, 10);  % pan past left edge
            regionX = get(ov.hRegion, 'XData');
            testCase.verifyGreaterThanOrEqual(min(regionX), 0);
            % Width should be clamped but not shrunk
            actualWidth = max(regionX) - min(regionX);
            testCase.verifyGreaterThanOrEqual(actualWidth, 0.5);  % at least min width
            delete(ov);
        end

        function testPanPreservesWidthAtRightBoundary(testCase)
            ov = NavigatorOverlay(testCase.hAxes);
            ov.setRange(80, 95);  % width = 15
            ov.setRange(90, 110);  % pan past right edge
            regionX = get(ov.hRegion, 'XData');
            testCase.verifyLessThanOrEqual(max(regionX), 100);
            delete(ov);
        end

        %% Hold state is preserved
        function testHoldStatePreserved(testCase)
            hold(testCase.hAxes, 'off');
            ov = NavigatorOverlay(testCase.hAxes);
            testCase.verifyFalse(ishold(testCase.hAxes));
            delete(ov);
        end
    end
end
