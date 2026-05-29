classdef TestDashboardLayoutPlantLogToggle < matlab.unittest.TestCase
%TESTDASHBOARDLAYOUTPLANTLOGTOGGLE Class-based suite for the L toggle button.
%   Mirrors tests/test_dashboard_layout_plant_log_toggle.m sub-test coverage
%   (12 tests). Phase 1032 Plan 02 Task 1.

    properties
        Fig = []
        Eng = []
        Widget = []
        Btn = []
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            thisFile = mfilename('fullpath');
            suiteDir = fileparts(thisFile);
            testsDir = fileparts(suiteDir);
            repoRoot = fileparts(testsDir);
            addpath(repoRoot);
            addpath(testsDir);
            install();
        end
    end

    methods (TestMethodTeardown)
        function teardown(testCase)
            try
                if ~isempty(testCase.Eng) && isvalid(testCase.Eng), delete(testCase.Eng); end
            catch, end
            testCase.Eng = [];
            try
                if ~isempty(testCase.Fig) && ishandle(testCase.Fig), delete(testCase.Fig); end
            catch, end
            testCase.Fig = [];
            testCase.Widget = [];
            testCase.Btn = [];
        end
    end

    methods (Access = private)
        function buildWidgetWithChrome(testCase, attachStore)
            testCase.Eng = DashboardEngine('layoutToggleTest');
            if attachStore
                store = PlantLogStore('x');
                store.addEntries(PlantLogEntry( ...
                    'Timestamp', 100, 'Message', 'msg', 'Metadata', struct()));
                testCase.Eng.setPlantLogStoreForTest_(store);
            end
            testCase.Widget = FastSenseWidget('Title', 'wt', ...
                'Description', 'info text so the InfoIconButton renders alongside the L button', ...
                'XData', 0:10, 'YData', sin(0:10));
            testCase.Widget.Position = [1 1 6 2];
            testCase.Eng.addWidget(testCase.Widget);
            testCase.Eng.render();
            testCase.Fig = testCase.Eng.hFigure;
            try set(testCase.Fig, 'Visible', 'off'); catch, end
            bar = findobj(testCase.Widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
            testCase.Btn = findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1);
        end
    end

    methods (Test)
        function testCreatesSingleButton(testCase)
            testCase.buildWidgetWithChrome(false);
            testCase.verifyEqual(numel(testCase.Btn), 1, ...
                'expected exactly one PlantLogToggleButton');
        end

        function testButtonPropsMatchSpec(testCase)
            testCase.buildWidgetWithChrome(false);
            testCase.verifyEqual(get(testCase.Btn, 'Style'), 'pushbutton');
            testCase.verifyEqual(get(testCase.Btn, 'String'), 'L');
            testCase.verifyEqual(get(testCase.Btn, 'FontWeight'), 'bold');
            p = get(testCase.Btn, 'Position');
            testCase.verifyEqual(p(3), 24);
            testCase.verifyEqual(p(4), 24);
        end

        function testInitialPositionLeftmostOfThree(testCase)
            % After the v3.1↔v4.0 merge the right cluster has 4 buttons
            % (Detach + Create + Info + PlantLog) when CreateEventCallback
            % is wired — which is always true via DashboardEngine.render.
            % Each button is 24 px wide with a 4 px gap, so PlantLog (leftmost)
            % sits at: x = barW - 4*24 - 4*4 = barW - 112.
            testCase.buildWidgetWithChrome(false);
            bar = findobj(testCase.Widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
            barPos = get(bar(1), 'Position');
            expectedX = barPos(3) - 4*24 - 4*4;
            btnPos = get(testCase.Btn, 'Position');
            testCase.verifyLessThan(abs(btnPos(1) - expectedX), 1e-6);
        end

        function testDisabledWhenNoStore(testCase)
            testCase.buildWidgetWithChrome(false);
            testCase.verifyEqual(get(testCase.Btn, 'Enable'), 'off');
            testCase.verifyEqual(get(testCase.Btn, 'TooltipString'), 'No plant log attached');
        end

        function testEnabledWhenStoreAttached(testCase)
            testCase.buildWidgetWithChrome(true);
            testCase.verifyEqual(get(testCase.Btn, 'Enable'), 'on');
            testCase.verifyEqual(get(testCase.Btn, 'TooltipString'), 'Show plant log lines');
        end

        function testPressedStateColors(testCase)
            testCase.buildWidgetWithChrome(true);
            theme = DashboardTheme('light');
            testCase.verifyEqual(get(testCase.Btn, 'BackgroundColor'), theme.ToolbarBackground);
            testCase.verifyEqual(get(testCase.Btn, 'ForegroundColor'), theme.ToolbarFontColor);
            testCase.Widget.ShowPlantLog = true;
            testCase.Eng.Layout.addPlantLogToggle(testCase.Widget, testCase.Eng);
            bar = findobj(testCase.Widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
            btn2 = findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1);
            testCase.verifyEqual(get(btn2, 'BackgroundColor'), theme.MarkerPlantLog);
            testCase.verifyEqual(get(btn2, 'ForegroundColor'), [1 1 1]);
        end

        function testCallbackFlipsShowPlantLog(testCase)
            testCase.buildWidgetWithChrome(true);
            testCase.verifyFalse(testCase.Widget.ShowPlantLog);
            cb = get(testCase.Btn, 'Callback');
            testCase.verifyNotEmpty(cb);
            cb(testCase.Btn, []);
            testCase.verifyTrue(testCase.Widget.ShowPlantLog);
        end

        function testReflowChromeThreeButtons(testCase)
            % Post-merge: the right cluster is 4 buttons (Detach + Create +
            % Info + PlantLog) because DashboardEngine.render unconditionally
            % wires the Create callback (v4.0 260513-snt). Positions from
            % the right edge: Detach (barW-28), Create (barW-56), Info
            % (barW-84), PlantLog (barW-112).
            testCase.buildWidgetWithChrome(true);
            set(testCase.Fig, 'Position', [10 10 900 500]);
            drawnow;
            DashboardLayout.reflowChrome_(testCase.Widget.hCellPanel, 28, 2);
            bar = findobj(testCase.Widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
            barPos = get(bar(1), 'Position');
            barW = barPos(3);
            det    = findobj(bar(1), 'Tag', 'DetachButton',          '-depth', 1);
            create = findobj(bar(1), 'Tag', 'CreateEventButton',     '-depth', 1);
            info   = findobj(bar(1), 'Tag', 'InfoIconButton',        '-depth', 1);
            pl     = findobj(bar(1), 'Tag', 'PlantLogToggleButton',  '-depth', 1);
            testCase.verifyNotEmpty(det);
            testCase.verifyNotEmpty(create);
            testCase.verifyNotEmpty(info);
            testCase.verifyNotEmpty(pl);
            pDet = get(det(1),    'Position');
            pCre = get(create(1), 'Position');
            pInf = get(info(1),   'Position');
            pPL  = get(pl(1),     'Position');
            testCase.verifyLessThan(abs(pDet(1) - (barW -  28)), 1e-6);
            testCase.verifyLessThan(abs(pCre(1) - (barW -  56)), 1e-6);
            testCase.verifyLessThan(abs(pInf(1) - (barW -  84)), 1e-6);
            testCase.verifyLessThan(abs(pPL(1)  - (barW - 112)), 1e-6);
        end

        function testClearPanelControlsProtectsToggle(testCase)
            testCase.Fig = figure('Visible', 'off');
            p = uipanel('Parent', testCase.Fig);
            uicontrol('Parent', p, 'Tag', 'InfoIconButton',       'Style', 'pushbutton');
            uicontrol('Parent', p, 'Tag', 'DetachButton',         'Style', 'pushbutton');
            uicontrol('Parent', p, 'Tag', 'PlantLogToggleButton', 'Style', 'pushbutton');
            uicontrol('Parent', p, 'Tag', 'RogueControl',         'Style', 'pushbutton');
            ProbeDwPanelClear.clear(p);
            rogue = findobj(p, 'Tag', 'RogueControl', '-depth', 1);
            testCase.verifyTrue(isempty(rogue) || all(~ishandle(rogue)));
            pl   = findobj(p, 'Tag', 'PlantLogToggleButton', '-depth', 1);
            testCase.verifyTrue(~isempty(pl) && ishandle(pl(1)));
            info = findobj(p, 'Tag', 'InfoIconButton', '-depth', 1);
            det  = findobj(p, 'Tag', 'DetachButton',   '-depth', 1);
            testCase.verifyNotEmpty(info);
            testCase.verifyNotEmpty(det);
        end

        function testDisabledButtonDoesNotFlipState(testCase)
            testCase.buildWidgetWithChrome(false);
            testCase.verifyEqual(get(testCase.Btn, 'Enable'), 'off');
            priorState = testCase.Widget.ShowPlantLog;
            cb = get(testCase.Btn, 'Callback');
            warning('off', 'DashboardLayout:plantLogToggleParentMissing');
            try cb(testCase.Btn, []); catch, end
            warning('on', 'DashboardLayout:plantLogToggleParentMissing');
            testCase.verifyEqual(testCase.Widget.ShowPlantLog, priorState);
        end

        function testIdempotentDoubleCall(testCase)
            testCase.buildWidgetWithChrome(false);
            bar = findobj(testCase.Widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
            testCase.verifyEqual(numel(findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1)), 1);
            testCase.Eng.Layout.addPlantLogToggle(testCase.Widget, testCase.Eng);
            testCase.Eng.Layout.addPlantLogToggle(testCase.Widget, testCase.Eng);
            testCase.verifyEqual(numel(findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1)), 1);
        end

        function testCallbackTrapsExceptions(testCase)
            testCase.buildWidgetWithChrome(true);
            cb = get(testCase.Btn, 'Callback');
            warning('off', 'DashboardLayout:plantLogToggleParentMissing');
            threw = false;
            try
                cb([], []);
            catch
                threw = true;
            end
            warning('on', 'DashboardLayout:plantLogToggleParentMissing');
            testCase.verifyFalse(threw);
        end

        function testInfoIconSurvivesToggleOnOff(testCase)
            % 260526-info-icon-vanishes-after-plantlog-toggle:
            % After toggling L on then off via the button callback, the
            % InfoIconButton (and Detach + L itself) must still be present
            % on the WidgetButtonBar AND each button must sit at its
            % canonical post-reflow x position. The original bug placed L
            % at xPL=barW-84 (3-button-cluster math) which is exactly the
            % post-reflow x position of InfoIconButton in the 4-button
            % cluster — so L visually covered Info even though Info was
            % still in the handle tree. The fix calls reflowChrome_ at the
            % end of addPlantLogToggle so the 4-button-cluster positions
            % are re-applied after every rebuild.
            testCase.buildWidgetWithChrome(true);
            bar = findobj(testCase.Widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
            % Sanity: all four right-cluster buttons exist before any toggling.
            testCase.verifyNotEmpty(findobj(bar, 'Tag', 'InfoIconButton',       '-depth', 1));
            testCase.verifyNotEmpty(findobj(bar, 'Tag', 'DetachButton',         '-depth', 1));
            testCase.verifyNotEmpty(findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1));
            cb = get(testCase.Btn, 'Callback');
            % Toggle ON (enable plant-log overlay).
            cb(testCase.Btn, []);
            drawnow;
            testCase.verifyTrue(testCase.Widget.ShowPlantLog);
            % Re-resolve the L button after addPlantLogToggle rebuilt it.
            btn2 = findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1);
            cb2 = get(btn2, 'Callback');
            % Toggle OFF (disable plant-log overlay).
            cb2(btn2, []);
            drawnow;
            testCase.verifyFalse(testCase.Widget.ShowPlantLog);
            % All four right-cluster buttons MUST still be on the bar.
            info = findobj(bar, 'Tag', 'InfoIconButton',       '-depth', 1);
            det  = findobj(bar, 'Tag', 'DetachButton',         '-depth', 1);
            pl   = findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1);
            testCase.verifyNotEmpty(info, 'InfoIconButton must survive L on/off cycle');
            testCase.verifyNotEmpty(det,  'DetachButton must survive L on/off cycle');
            testCase.verifyNotEmpty(pl,   'PlantLogToggleButton must survive L on/off cycle');
            % AND the canonical 4-button-cluster positions must be respected:
            %   Detach @ barW-28, Info @ barW-84, PlantLog @ barW-112.
            % If L sits at barW-84 (the original bug), it overlaps Info.
            % Use the bar's CURRENT width (it can be reread by reflowChrome_
            % via the SizeChangedFcn pathway, and may drift by sub-pixel
            % rounding when the cell panel resizes — use a 1px tolerance).
            barW = subsref(get(bar, 'Position'), substruct('()', {3}));
            pInfo = get(info(1), 'Position');
            pDet  = get(det(1),  'Position');
            pPL   = get(pl(1),   'Position');
            tol = 1.0;  % 1 px slack for sub-pixel rounding of bar width.
            testCase.verifyLessThan(abs(pDet(1)  - (barW -  28)), tol, ...
                'Detach must sit at barW - 28');
            testCase.verifyLessThan(abs(pInfo(1) - (barW -  84)), tol, ...
                'Info must sit at barW - 84');
            testCase.verifyLessThan(abs(pPL(1)   - (barW - 112)), tol, ...
                'PlantLog must sit at barW - 112 (NOT barW - 84 — that would overlap Info)');
            % And the strongest separation invariant: PlantLog and Info
            % must NOT share an x position (the original bug had them
            % both at barW - 84, fully overlapping).
            testCase.verifyGreaterThan(abs(pPL(1) - pInfo(1)), 24 - 2*tol, ...
                'PlantLog and Info must NOT share an x position');
        end
    end
end
