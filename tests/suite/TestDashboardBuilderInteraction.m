classdef TestDashboardBuilderInteraction < matlab.unittest.TestCase
%TESTDASHBOARDBUILDERINTERACTION Tests for drag, resize, and mouse-driven
%   interactions in DashboardBuilder edit mode.
%
%   Uses builder.MockCurrentPoint to simulate mouse position, then triggers
%   ButtonDownFcn on overlay handles and invokes the figure's
%   WindowButtonMotionFcn / WindowButtonUpFcn callbacks.

    properties
        Engine
        Builder
        hFig
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (TestMethodSetup)
        function createDashboard(testCase)
            testCase.Engine = DashboardEngine('Interaction Test');
            testCase.Engine.addWidget('kpi', 'Title', 'Widget A', ...
                'Position', [1 1 3 1], 'StaticValue', 10);
            testCase.Engine.addWidget('kpi', 'Title', 'Widget B', ...
                'Position', [7 1 3 1], 'StaticValue', 20);
            testCase.Engine.render();
            testCase.hFig = testCase.Engine.hFigure;
            set(testCase.hFig, 'Visible', 'off');

            testCase.Builder = DashboardBuilder(testCase.Engine);
            testCase.Builder.enterEditMode();

            testCase.addTeardown(@() testCase.cleanupDashboard());
        end
    end

    methods
        function cleanupDashboard(testCase)
            if ~isempty(testCase.hFig) && ishandle(testCase.hFig)
                close(testCase.hFig);
            end
        end

        function [stepW, stepH] = gridStepSize(testCase)
            layout = testCase.Engine.Layout;
            ca = layout.ContentArea;
            totalW = ca(3) - layout.Padding(1) - layout.Padding(3);
            totalH = ca(4) - layout.Padding(2) - layout.Padding(4);
            cols = layout.Columns;
            rows = max(layout.TotalRows, 1);
            cellW = (totalW - (cols - 1) * layout.GapH) / cols;
            cellH = (totalH - (rows - 1) * layout.GapV) / rows;
            stepW = cellW + layout.GapH;
            stepH = cellH + layout.GapV;
        end

        function startDrag(testCase, widgetIdx)
            ov = testCase.Builder.Overlays{widgetIdx};
            cb = get(ov.hDragBar, 'ButtonDownFcn');
            cb(ov.hDragBar, []);
        end

        function startResize(testCase, widgetIdx)
            ov = testCase.Builder.Overlays{widgetIdx};
            cb = get(ov.hResize, 'ButtonDownFcn');
            cb(ov.hResize, []);
        end

        function triggerMotion(testCase)
            motionCb = get(testCase.hFig, 'WindowButtonMotionFcn');
            motionCb(testCase.hFig, []);
        end

        function triggerMouseUp(testCase)
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);
        end
    end

    methods (Test)
        %% --- Drag Tests ---

        function testDragStartSelectsWidget(testCase)
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            testCase.Builder.MockCurrentPoint = ...
                [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
            testCase.startDrag(1);

            testCase.verifyEqual(testCase.Builder.SelectedIdx, 1);
            testCase.verifyEqual(testCase.Builder.DragMode, 'drag');
            testCase.verifyEqual(testCase.Builder.DragIdx, 1);
        end

        function testDragMovesWidgetPosition(testCase)
            origPos = testCase.Engine.Widgets{1}.Position;
            [stepW, ~] = testCase.gridStepSize();

            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startDrag(1);

            testCase.Builder.MockCurrentPoint = [startPt(1)+2*stepW, startPt(2)];
            testCase.triggerMotion();
            testCase.triggerMouseUp();

            newPos = testCase.Engine.Widgets{1}.Position;
            testCase.verifyEqual(newPos(1), origPos(1)+2);
            testCase.verifyEqual(newPos(3), origPos(3));
            testCase.verifyEqual(newPos(4), origPos(4));
        end

        function testDragClampsToLeftEdge(testCase)
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startDrag(1);

            testCase.Builder.MockCurrentPoint = [startPt(1)-0.9, startPt(2)];
            testCase.triggerMouseUp();

            testCase.verifyGreaterThanOrEqual(testCase.Engine.Widgets{1}.Position(1), 1);
        end

        function testDragClampsToRightEdge(testCase)
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startDrag(1);

            testCase.Builder.MockCurrentPoint = [startPt(1)+0.9, startPt(2)];
            testCase.triggerMouseUp();

            newPos = testCase.Engine.Widgets{1}.Position;
            testCase.verifyLessThanOrEqual(newPos(1)+newPos(3)-1, 12);
        end

        function testDragClampsRowToMinOne(testCase)
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startDrag(1);

            testCase.Builder.MockCurrentPoint = [startPt(1), startPt(2)+0.9];
            testCase.triggerMouseUp();

            testCase.verifyGreaterThanOrEqual(testCase.Engine.Widgets{1}.Position(2), 1);
        end

        function testDragResolvesOverlap(testCase)
            origBPos = testCase.Engine.Widgets{2}.Position;
            [stepW, ~] = testCase.gridStepSize();

            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startDrag(1);

            deltaCols = origBPos(1) - testCase.Engine.Widgets{1}.Position(1);
            testCase.Builder.MockCurrentPoint = ...
                [startPt(1)+deltaCols*stepW, startPt(2)];
            testCase.triggerMouseUp();

            newAPos = testCase.Engine.Widgets{1}.Position;
            if newAPos(1) <= origBPos(1)+origBPos(3)-1 && ...
               newAPos(1)+newAPos(3)-1 >= origBPos(1)
                testCase.verifyGreaterThan(newAPos(2), origBPos(2)+origBPos(4)-1);
            end
        end

        function testDragSnapsToGrid(testCase)
            [stepW, ~] = testCase.gridStepSize();

            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startDrag(1);

            testCase.Builder.MockCurrentPoint = [startPt(1)+1.7*stepW, startPt(2)];
            testCase.triggerMouseUp();

            newPos = testCase.Engine.Widgets{1}.Position;
            testCase.verifyEqual(mod(newPos(1), 1), 0);
            testCase.verifyEqual(mod(newPos(2), 1), 0);
        end

        %% --- Resize Tests ---

        function testResizeStartSelectsWidget(testCase)
            panelPos = get(testCase.Engine.Widgets{2}.hPanel, 'Position');
            testCase.Builder.MockCurrentPoint = ...
                [panelPos(1)+panelPos(3)-0.005, panelPos(2)+0.005];
            testCase.startResize(2);

            testCase.verifyEqual(testCase.Builder.SelectedIdx, 2);
            testCase.verifyEqual(testCase.Builder.DragMode, 'resize');
            testCase.verifyEqual(testCase.Builder.DragIdx, 2);
        end

        function testResizeChangesWidthHeight(testCase)
            origPos = testCase.Engine.Widgets{2}.Position;
            [stepW, stepH] = testCase.gridStepSize();

            panelPos = get(testCase.Engine.Widgets{2}.hPanel, 'Position');
            startPt = [panelPos(1)+panelPos(3)-0.005, panelPos(2)+0.005];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startResize(2);

            testCase.Builder.MockCurrentPoint = ...
                [startPt(1)+2*stepW, startPt(2)-1*stepH];
            testCase.triggerMouseUp();

            newPos = testCase.Engine.Widgets{2}.Position;
            testCase.verifyEqual(newPos(3), origPos(3)+2);
            testCase.verifyEqual(newPos(4), origPos(4)+1);
            testCase.verifyEqual(newPos(1), origPos(1));
            testCase.verifyEqual(newPos(2), origPos(2));
        end

        function testResizeClampsMinimum(testCase)
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1)+panelPos(3)-0.005, panelPos(2)+0.005];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startResize(1);

            testCase.Builder.MockCurrentPoint = [startPt(1)-0.9, startPt(2)+0.9];
            testCase.triggerMouseUp();

            newPos = testCase.Engine.Widgets{1}.Position;
            testCase.verifyGreaterThanOrEqual(newPos(3), 1);
            testCase.verifyGreaterThanOrEqual(newPos(4), 1);
        end

        function testResizeClampsMaxWidth(testCase)
            panelPos = get(testCase.Engine.Widgets{2}.hPanel, 'Position');
            startPt = [panelPos(1)+panelPos(3)-0.005, panelPos(2)+0.005];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startResize(2);

            testCase.Builder.MockCurrentPoint = [startPt(1)+0.9, startPt(2)];
            testCase.triggerMouseUp();

            newPos = testCase.Engine.Widgets{2}.Position;
            testCase.verifyLessThanOrEqual(newPos(1)+newPos(3)-1, 12);
        end

        %% --- Mouse Move Visual Feedback Tests ---

        function testMouseMoveDragUpdatesPanelPosition(testCase)
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startDrag(1);

            origPanelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');

            dx = 0.1;
            testCase.Builder.MockCurrentPoint = [startPt(1)+dx, startPt(2)];
            testCase.triggerMotion();

            newPanelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            testCase.verifyEqual(newPanelPos(1), origPanelPos(1)+dx, 'AbsTol', 1e-6);
            testCase.verifyEqual(newPanelPos(3), origPanelPos(3), 'AbsTol', 1e-6);
        end

        function testMouseMoveResizeUpdatesSize(testCase)
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1)+panelPos(3)-0.005, panelPos(2)+0.005];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startResize(1);

            origPanelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');

            dx = 0.05;
            testCase.Builder.MockCurrentPoint = [startPt(1)+dx, startPt(2)];
            testCase.triggerMotion();

            newPanelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            testCase.verifyGreaterThan(newPanelPos(3), origPanelPos(3));
            testCase.verifyEqual(newPanelPos(1), origPanelPos(1), 'AbsTol', 1e-6);
        end

        function testMouseMoveWithNoDragIsNoop(testCase)
            origPos = testCase.Engine.Widgets{1}.Position;

            testCase.Builder.MockCurrentPoint = [0.5, 0.5];
            testCase.triggerMotion();

            testCase.verifyEqual(testCase.Engine.Widgets{1}.Position, origPos);
        end

        function testMouseUpWithNoDragIsNoop(testCase)
            origPos = testCase.Engine.Widgets{1}.Position;

            testCase.Builder.MockCurrentPoint = [0.5, 0.5];
            testCase.triggerMouseUp();

            testCase.verifyEqual(testCase.Engine.Widgets{1}.Position, origPos);
        end

        %% --- Overlay Control Tests ---

        function testOverlayDeleteButtonRemovesWidget(testCase)
            testCase.verifyEqual(numel(testCase.Engine.Widgets), 2);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hDeleteBtn, 'Callback');
            cb(ov.hDeleteBtn, []);

            testCase.verifyEqual(numel(testCase.Engine.Widgets), 1);
            testCase.verifyEqual(testCase.Engine.Widgets{1}.Title, 'Widget B');
        end

        function testDragLabelClickStartsDrag(testCase)
            panelPos = get(testCase.Engine.Widgets{2}.hPanel, 'Position');
            testCase.Builder.MockCurrentPoint = ...
                [panelPos(1)+0.02, panelPos(2)+panelPos(4)-0.01];

            ov = testCase.Builder.Overlays{2};
            cb = get(ov.hDragLabel, 'ButtonDownFcn');
            cb(ov.hDragLabel, []);

            testCase.verifyEqual(testCase.Builder.DragMode, 'drag');
            testCase.verifyEqual(testCase.Builder.DragIdx, 2);
            testCase.verifyEqual(testCase.Builder.SelectedIdx, 2);
        end

        %% --- State cleanup ---

        function testDragStateResetAfterMouseUp(testCase)
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startDrag(1);

            testCase.verifyEqual(testCase.Builder.DragMode, 'drag');

            testCase.triggerMouseUp();

            testCase.verifyEqual(testCase.Builder.DragMode, '');
            testCase.verifyEqual(testCase.Builder.DragIdx, 0);
        end

        %% --- Palette & Properties ---

        function testPaletteButtonsAddWidgets(testCase)
            btns = findobj(testCase.Builder.hPalette, 'Style', 'pushbutton');
            testCase.verifyGreaterThanOrEqual(numel(btns), 8);

            initialCount = numel(testCase.Engine.Widgets);
            cb = get(btns(end-1), 'Callback');
            cb(btns(end-1), []);

            testCase.verifyEqual(numel(testCase.Engine.Widgets), initialCount+1);
        end

        function testApplyButtonCallback(testCase)
            testCase.Builder.selectWidget(1);
            set(testCase.Builder.hPropTitle, 'String', 'Changed');
            set(testCase.Builder.hPropCol, 'String', '1');
            set(testCase.Builder.hPropRow, 'String', '1');
            set(testCase.Builder.hPropWidth, 'String', '3');
            set(testCase.Builder.hPropHeight, 'String', '1');

            cb = get(testCase.Builder.hPropApply, 'Callback');
            cb(testCase.Builder.hPropApply, []);

            testCase.verifyEqual(testCase.Engine.Widgets{1}.Title, 'Changed');
        end

        function testDeleteButtonCallback(testCase)
            testCase.Builder.selectWidget(1);
            initialCount = numel(testCase.Engine.Widgets);

            cb = get(testCase.Builder.hPropDelete, 'Callback');
            cb(testCase.Builder.hPropDelete, []);

            testCase.verifyEqual(numel(testCase.Engine.Widgets), initialCount-1);
        end

        %% --- Edge cases ---

        function testDragWidgetZeroMovement(testCase)
            origPos = testCase.Engine.Widgets{1}.Position;

            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startDrag(1);
            testCase.triggerMouseUp();

            testCase.verifyEqual(testCase.Engine.Widgets{1}.Position, origPos);
        end

        function testResizeWidgetZeroMovement(testCase)
            origPos = testCase.Engine.Widgets{1}.Position;

            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1)+panelPos(3)-0.005, panelPos(2)+0.005];
            testCase.Builder.MockCurrentPoint = startPt;
            testCase.startResize(1);
            testCase.triggerMouseUp();

            testCase.verifyEqual(testCase.Engine.Widgets{1}.Position, origPos);
        end
    end
end
