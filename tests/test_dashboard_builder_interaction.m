function test_dashboard_builder_interaction()
%TEST_DASHBOARD_BUILDER_INTERACTION Tests for drag, resize, and mouse-driven
%   interactions in DashboardBuilder edit mode.
%
%   Uses builder.MockCurrentPoint to simulate mouse position (works in both
%   MATLAB and Octave), then triggers ButtonDownFcn on overlay handles and
%   invokes the figure's WindowButtonMotionFcn / WindowButtonUpFcn callbacks.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    setup();

    close all force;
    drawnow;

    passed = 0;
    failed = 0;
    failures = {};

    tests = {
        @testDragStartSelectsWidget
        @testDragMovesWidgetPosition
        @testDragClampsToLeftEdge
        @testDragClampsToRightEdge
        @testDragClampsRowToMinOne
        @testDragResolvesOverlap
        @testDragSnapsToGrid
        @testResizeStartSelectsWidget
        @testResizeChangesWidthHeight
        @testResizeClampsMinimum
        @testResizeClampsMaxWidth
        @testMouseMoveDragUpdatesPanelPosition
        @testMouseMoveResizeUpdatesSize
        @testMouseMoveWithNoDragIsNoop
        @testMouseUpWithNoDragIsNoop
        @testOverlayDeleteButtonRemovesWidget
        @testDragLabelClickStartsDrag
        @testDragStateResetAfterMouseUp
        @testPaletteButtonsAddWidgets
        @testApplyButtonCallback
        @testDeleteButtonCallback
        @testDragWidgetZeroMovement
        @testResizeWidgetZeroMovement
    };

    for i = 1:numel(tests)
        name = func2str(tests{i});
        try
            tests{i}();
            passed = passed + 1;
        catch e
            failed = failed + 1;
            failures{end+1} = sprintf('%s: %s', name, e.message);
        end
        close all force;
    end

    fprintf('    %d/%d dashboard builder interaction tests passed.\n', ...
        passed, passed + failed);
    if ~isempty(failures)
        fprintf('    Failures:\n');
        for i = 1:numel(failures)
            fprintf('      - %s\n', failures{i});
        end
        error('test_dashboard_builder_interaction: %d test(s) failed', failed);
    end
end

%% ---- Helper: create a 2-widget dashboard in edit mode ----

function [engine, builder, hFig] = makeTestDashboard()
    engine = DashboardEngine('Interaction Test');
    engine.addWidget('kpi', 'Title', 'Widget A', ...
        'Position', [1 1 3 1], 'StaticValue', 10);
    engine.addWidget('kpi', 'Title', 'Widget B', ...
        'Position', [7 1 3 1], 'StaticValue', 20);
    engine.render();
    hFig = engine.hFigure;
    set(hFig, 'Visible', 'off');
    builder = DashboardBuilder(engine);
    builder.enterEditMode();
end

%% ---- Helper: compute grid step sizes ----

function [stepW, stepH] = gridStepSize(engine)
    layout = engine.Layout;
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

%% ---- Helper: simulate drag or resize start ----

function startDrag(builder, hFig, widgetIdx)
    ov = builder.Overlays{widgetIdx};
    cb = get(ov.hDragBar, 'ButtonDownFcn');
    cb(ov.hDragBar, []);
end

function startResize(builder, hFig, widgetIdx)
    ov = builder.Overlays{widgetIdx};
    cb = get(ov.hResize, 'ButtonDownFcn');
    cb(ov.hResize, []);
end

function triggerMotion(hFig)
    motionCb = get(hFig, 'WindowButtonMotionFcn');
    motionCb(hFig, []);
end

function triggerMouseUp(hFig)
    upCb = get(hFig, 'WindowButtonUpFcn');
    upCb(hFig, []);
end

%% ---- Drag Tests ----

function testDragStartSelectsWidget()
    [engine, builder, hFig] = makeTestDashboard();
    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    builder.MockCurrentPoint = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];

    startDrag(builder, hFig, 1);

    assert(builder.SelectedIdx == 1, 'testDragStartSelectsWidget: SelectedIdx');
    assert(strcmp(builder.DragMode, 'drag'), 'testDragStartSelectsWidget: DragMode');
    assert(builder.DragIdx == 1, 'testDragStartSelectsWidget: DragIdx');
end

function testDragMovesWidgetPosition()
    [engine, builder, hFig] = makeTestDashboard();
    origPos = engine.Widgets{1}.Position;
    [stepW, ~] = gridStepSize(engine);

    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
    builder.MockCurrentPoint = startPt;
    startDrag(builder, hFig, 1);

    % Move 2 columns right
    builder.MockCurrentPoint = [startPt(1) + 2*stepW, startPt(2)];
    triggerMotion(hFig);
    triggerMouseUp(hFig);

    newPos = engine.Widgets{1}.Position;
    assert(newPos(1) == origPos(1)+2, ...
        sprintf('testDragMovesWidgetPosition: col %d != %d', newPos(1), origPos(1)+2));
    assert(newPos(3) == origPos(3), 'testDragMovesWidgetPosition: width changed');
    assert(newPos(4) == origPos(4), 'testDragMovesWidgetPosition: height changed');
end

function testDragClampsToLeftEdge()
    [engine, builder, hFig] = makeTestDashboard();
    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
    builder.MockCurrentPoint = startPt;
    startDrag(builder, hFig, 1);

    builder.MockCurrentPoint = [startPt(1)-0.9, startPt(2)];
    triggerMouseUp(hFig);

    newPos = engine.Widgets{1}.Position;
    assert(newPos(1) >= 1, ...
        sprintf('testDragClampsToLeftEdge: col=%d < 1', newPos(1)));
end

function testDragClampsToRightEdge()
    [engine, builder, hFig] = makeTestDashboard();
    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
    builder.MockCurrentPoint = startPt;
    startDrag(builder, hFig, 1);

    builder.MockCurrentPoint = [startPt(1)+0.9, startPt(2)];
    triggerMouseUp(hFig);

    newPos = engine.Widgets{1}.Position;
    assert(newPos(1)+newPos(3)-1 <= 12, ...
        sprintf('testDragClampsToRightEdge: right=%d > 12', newPos(1)+newPos(3)-1));
end

function testDragClampsRowToMinOne()
    [engine, builder, hFig] = makeTestDashboard();
    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
    builder.MockCurrentPoint = startPt;
    startDrag(builder, hFig, 1);

    builder.MockCurrentPoint = [startPt(1), startPt(2)+0.9];
    triggerMouseUp(hFig);

    newPos = engine.Widgets{1}.Position;
    assert(newPos(2) >= 1, ...
        sprintf('testDragClampsRowToMinOne: row=%d < 1', newPos(2)));
end

function testDragResolvesOverlap()
    [engine, builder, hFig] = makeTestDashboard();
    origBPos = engine.Widgets{2}.Position; % [7 1 3 1]
    [stepW, ~] = gridStepSize(engine);

    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
    builder.MockCurrentPoint = startPt;
    startDrag(builder, hFig, 1);

    % Move widget A to overlap with widget B (col 7)
    deltaCols = origBPos(1) - engine.Widgets{1}.Position(1);
    builder.MockCurrentPoint = [startPt(1) + deltaCols*stepW, startPt(2)];
    triggerMouseUp(hFig);

    newAPos = engine.Widgets{1}.Position;
    % If columns overlap, rows must not overlap
    if newAPos(1) <= origBPos(1)+origBPos(3)-1 && ...
       newAPos(1)+newAPos(3)-1 >= origBPos(1)
        assert(newAPos(2) > origBPos(2)+origBPos(4)-1, ...
            'testDragResolvesOverlap: overlap not resolved');
    end
end

function testDragSnapsToGrid()
    [engine, builder, hFig] = makeTestDashboard();
    [stepW, ~] = gridStepSize(engine);

    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
    builder.MockCurrentPoint = startPt;
    startDrag(builder, hFig, 1);

    % Move by 1.7 columns (should snap to 2)
    builder.MockCurrentPoint = [startPt(1) + 1.7*stepW, startPt(2)];
    triggerMouseUp(hFig);

    newPos = engine.Widgets{1}.Position;
    assert(mod(newPos(1), 1) == 0, ...
        sprintf('testDragSnapsToGrid: col=%g not integer', newPos(1)));
    assert(mod(newPos(2), 1) == 0, ...
        sprintf('testDragSnapsToGrid: row=%g not integer', newPos(2)));
end

%% ---- Resize Tests ----

function testResizeStartSelectsWidget()
    [engine, builder, hFig] = makeTestDashboard();
    panelPos = get(engine.Widgets{2}.hPanel, 'Position');
    builder.MockCurrentPoint = [panelPos(1)+panelPos(3)-0.005, panelPos(2)+0.005];

    startResize(builder, hFig, 2);

    assert(builder.SelectedIdx == 2, 'testResizeStartSelectsWidget: SelectedIdx');
    assert(strcmp(builder.DragMode, 'resize'), 'testResizeStartSelectsWidget: DragMode');
    assert(builder.DragIdx == 2, 'testResizeStartSelectsWidget: DragIdx');
end

function testResizeChangesWidthHeight()
    [engine, builder, hFig] = makeTestDashboard();
    origPos = engine.Widgets{2}.Position;
    [stepW, stepH] = gridStepSize(engine);

    panelPos = get(engine.Widgets{2}.hPanel, 'Position');
    startPt = [panelPos(1)+panelPos(3)-0.005, panelPos(2)+0.005];
    builder.MockCurrentPoint = startPt;
    startResize(builder, hFig, 2);

    % +2 columns wider, +1 row taller (drag right and down)
    builder.MockCurrentPoint = [startPt(1)+2*stepW, startPt(2)-1*stepH];
    triggerMouseUp(hFig);

    newPos = engine.Widgets{2}.Position;
    assert(newPos(3) == origPos(3)+2, ...
        sprintf('testResizeChangesWidthHeight: w=%d != %d', newPos(3), origPos(3)+2));
    assert(newPos(4) == origPos(4)+1, ...
        sprintf('testResizeChangesWidthHeight: h=%d != %d', newPos(4), origPos(4)+1));
    assert(newPos(1) == origPos(1), 'testResizeChangesWidthHeight: col changed');
    assert(newPos(2) == origPos(2), 'testResizeChangesWidthHeight: row changed');
end

function testResizeClampsMinimum()
    [engine, builder, hFig] = makeTestDashboard();
    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    startPt = [panelPos(1)+panelPos(3)-0.005, panelPos(2)+0.005];
    builder.MockCurrentPoint = startPt;
    startResize(builder, hFig, 1);

    builder.MockCurrentPoint = [startPt(1)-0.9, startPt(2)+0.9];
    triggerMouseUp(hFig);

    newPos = engine.Widgets{1}.Position;
    assert(newPos(3) >= 1, ...
        sprintf('testResizeClampsMinimum: w=%d < 1', newPos(3)));
    assert(newPos(4) >= 1, ...
        sprintf('testResizeClampsMinimum: h=%d < 1', newPos(4)));
end

function testResizeClampsMaxWidth()
    [engine, builder, hFig] = makeTestDashboard();
    panelPos = get(engine.Widgets{2}.hPanel, 'Position');
    startPt = [panelPos(1)+panelPos(3)-0.005, panelPos(2)+0.005];
    builder.MockCurrentPoint = startPt;
    startResize(builder, hFig, 2);

    builder.MockCurrentPoint = [startPt(1)+0.9, startPt(2)];
    triggerMouseUp(hFig);

    newPos = engine.Widgets{2}.Position;
    assert(newPos(1)+newPos(3)-1 <= 12, ...
        sprintf('testResizeClampsMaxWidth: right=%d > 12', newPos(1)+newPos(3)-1));
end

%% ---- Mouse Move Visual Feedback Tests ----

function testMouseMoveDragUpdatesPanelPosition()
    [engine, builder, hFig] = makeTestDashboard();
    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
    builder.MockCurrentPoint = startPt;
    startDrag(builder, hFig, 1);

    origPanelPos = get(engine.Widgets{1}.hPanel, 'Position');

    dx = 0.1;
    builder.MockCurrentPoint = [startPt(1)+dx, startPt(2)];
    triggerMotion(hFig);

    newPanelPos = get(engine.Widgets{1}.hPanel, 'Position');
    assert(abs(newPanelPos(1) - (origPanelPos(1)+dx)) < 1e-6, ...
        'testMouseMoveDragUpdatesPanelPosition: X not tracking');
    assert(abs(newPanelPos(3) - origPanelPos(3)) < 1e-6, ...
        'testMouseMoveDragUpdatesPanelPosition: width changed');
end

function testMouseMoveResizeUpdatesSize()
    [engine, builder, hFig] = makeTestDashboard();
    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    startPt = [panelPos(1)+panelPos(3)-0.005, panelPos(2)+0.005];
    builder.MockCurrentPoint = startPt;
    startResize(builder, hFig, 1);

    origPanelPos = get(engine.Widgets{1}.hPanel, 'Position');

    dx = 0.05;
    builder.MockCurrentPoint = [startPt(1)+dx, startPt(2)];
    triggerMotion(hFig);

    newPanelPos = get(engine.Widgets{1}.hPanel, 'Position');
    assert(newPanelPos(3) > origPanelPos(3), ...
        'testMouseMoveResizeUpdatesSize: width did not increase');
    assert(abs(newPanelPos(1) - origPanelPos(1)) < 1e-6, ...
        'testMouseMoveResizeUpdatesSize: X shifted');
end

function testMouseMoveWithNoDragIsNoop()
    [engine, builder, hFig] = makeTestDashboard();
    origPos = engine.Widgets{1}.Position;

    builder.MockCurrentPoint = [0.5, 0.5];
    triggerMotion(hFig);

    assert(isequal(engine.Widgets{1}.Position, origPos), ...
        'testMouseMoveWithNoDragIsNoop: position changed');
end

function testMouseUpWithNoDragIsNoop()
    [engine, builder, hFig] = makeTestDashboard();
    origPos = engine.Widgets{1}.Position;

    builder.MockCurrentPoint = [0.5, 0.5];
    triggerMouseUp(hFig);

    assert(isequal(engine.Widgets{1}.Position, origPos), ...
        'testMouseUpWithNoDragIsNoop: position changed');
end

%% ---- Overlay Control Tests ----

function testOverlayDeleteButtonRemovesWidget()
    [engine, builder, ~] = makeTestDashboard();
    assert(numel(engine.Widgets) == 2, 'testOverlayDeleteButton: initial count');

    ov = builder.Overlays{1};
    cb = get(ov.hDeleteBtn, 'Callback');
    cb(ov.hDeleteBtn, []);

    assert(numel(engine.Widgets) == 1, 'testOverlayDeleteButton: count after delete');
    assert(strcmp(engine.Widgets{1}.Title, 'Widget B'), ...
        'testOverlayDeleteButton: wrong widget remaining');
end

function testDragLabelClickStartsDrag()
    [engine, builder, hFig] = makeTestDashboard();
    panelPos = get(engine.Widgets{2}.hPanel, 'Position');
    builder.MockCurrentPoint = [panelPos(1)+0.02, panelPos(2)+panelPos(4)-0.01];

    ov = builder.Overlays{2};
    cb = get(ov.hDragLabel, 'ButtonDownFcn');
    cb(ov.hDragLabel, []);

    assert(strcmp(builder.DragMode, 'drag'), 'testDragLabelClickStartsDrag: DragMode');
    assert(builder.DragIdx == 2, 'testDragLabelClickStartsDrag: DragIdx');
    assert(builder.SelectedIdx == 2, 'testDragLabelClickStartsDrag: SelectedIdx');
end

%% ---- State cleanup tests ----

function testDragStateResetAfterMouseUp()
    [engine, builder, hFig] = makeTestDashboard();
    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
    builder.MockCurrentPoint = startPt;
    startDrag(builder, hFig, 1);

    assert(strcmp(builder.DragMode, 'drag'), 'testDragStateReset: before');

    triggerMouseUp(hFig);

    assert(strcmp(builder.DragMode, ''), 'testDragStateReset: DragMode not cleared');
    assert(builder.DragIdx == 0, 'testDragStateReset: DragIdx not cleared');
end

%% ---- Palette & Properties Tests ----

function testPaletteButtonsAddWidgets()
    [engine, builder, ~] = makeTestDashboard();
    btns = findobj(builder.hPalette, 'Style', 'pushbutton');
    assert(numel(btns) >= 8, ...
        sprintf('testPaletteButtonsAddWidgets: only %d buttons', numel(btns)));

    initialCount = numel(engine.Widgets);
    % Use the KPI button (2nd from last) to avoid FastPlot requiring a line
    cb = get(btns(end-1), 'Callback');
    cb(btns(end-1), []);

    assert(numel(engine.Widgets) == initialCount+1, ...
        'testPaletteButtonsAddWidgets: widget not added');
end

function testApplyButtonCallback()
    [engine, builder, ~] = makeTestDashboard();
    builder.selectWidget(1);
    set(builder.hPropTitle, 'String', 'Changed');
    set(builder.hPropCol, 'String', '1');
    set(builder.hPropRow, 'String', '1');
    set(builder.hPropWidth, 'String', '3');
    set(builder.hPropHeight, 'String', '1');

    cb = get(builder.hPropApply, 'Callback');
    cb(builder.hPropApply, []);

    assert(strcmp(engine.Widgets{1}.Title, 'Changed'), ...
        'testApplyButtonCallback: title not changed');
end

function testDeleteButtonCallback()
    [engine, builder, ~] = makeTestDashboard();
    builder.selectWidget(1);
    initialCount = numel(engine.Widgets);

    cb = get(builder.hPropDelete, 'Callback');
    cb(builder.hPropDelete, []);

    assert(numel(engine.Widgets) == initialCount-1, ...
        'testDeleteButtonCallback: widget not deleted');
end

%% ---- Edge Cases ----

function testDragWidgetZeroMovement()
    [engine, builder, hFig] = makeTestDashboard();
    origPos = engine.Widgets{1}.Position;

    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    startPt = [panelPos(1)+0.01, panelPos(2)+panelPos(4)-0.01];
    builder.MockCurrentPoint = startPt;
    startDrag(builder, hFig, 1);

    triggerMouseUp(hFig);

    assert(isequal(engine.Widgets{1}.Position, origPos), ...
        'testDragWidgetZeroMovement: position changed');
end

function testResizeWidgetZeroMovement()
    [engine, builder, hFig] = makeTestDashboard();
    origPos = engine.Widgets{1}.Position;

    panelPos = get(engine.Widgets{1}.hPanel, 'Position');
    startPt = [panelPos(1)+panelPos(3)-0.005, panelPos(2)+0.005];
    builder.MockCurrentPoint = startPt;
    startResize(builder, hFig, 1);

    triggerMouseUp(hFig);

    assert(isequal(engine.Widgets{1}.Position, origPos), ...
        'testResizeWidgetZeroMovement: position changed');
end
