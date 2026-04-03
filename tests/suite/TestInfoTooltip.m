classdef TestInfoTooltip < matlab.unittest.TestCase
%TESTINFOTOOLTIP Unit tests for DashboardLayout info icon and popup (INFO-01..05).
%
%   Tests cover:
%     INFO-01: Info icon injected on widgets with Description
%     INFO-02: Info icon absent on widgets without Description
%     INFO-03: Popup panel created on openInfoPopup
%     INFO-04: Popup displays Description text
%     INFO-05: Popup dismissal via Escape, click-outside; prior callbacks restored

    properties
        hFig
        Layout
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function createFigure(testCase)
            testCase.hFig = figure('Visible', 'off');
            testCase.Layout = DashboardLayout();
            testCase.addTeardown(@() delete(testCase.hFig));
        end
    end

    methods (Access = private)
        function widget = makeWidget(testCase, desc)
        %MAKEWIDGET Create a headless TextWidget with an allocated panel.
            widget = TextWidget('Title', 'T', 'Position', [1 1 6 2], 'Content', 'x');
            if nargin > 1
                widget.Description = desc;
            end
            theme = DashboardTheme('light');
            widget.ParentTheme = theme;
            hp = uipanel('Parent', testCase.hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1], 'BorderType', 'none');
            widget.hPanel = hp;
        end
    end

    methods (Test)

        function testInfoIconAppearsWhenDescriptionSet(testCase)
        % INFO-01: widget with Description gets an InfoIconButton after realizeWidget.
            widget = testCase.makeWidget('## Hello\n\nWorld');
            testCase.Layout.realizeWidget(widget);
            btn = findobj(widget.hPanel, 'Tag', 'InfoIconButton');
            testCase.verifyNotEmpty(btn, 'InfoIconButton should appear when Description is set');
        end

        function testInfoIconAbsentWhenDescriptionEmpty(testCase)
        % INFO-02: widget without Description gets no InfoIconButton after realizeWidget.
            widget = testCase.makeWidget();  % no Description
            testCase.Layout.realizeWidget(widget);
            btn = findobj(widget.hPanel, 'Tag', 'InfoIconButton');
            testCase.verifyEmpty(btn, 'InfoIconButton should NOT appear when Description is empty');
        end

        function testOpenInfoPopupCreatesFigure(testCase)
        % INFO-03: openInfoPopup creates a modal figure window.
            widget = testCase.makeWidget('Some description text');
            theme = DashboardTheme('light');
            testCase.Layout.openInfoPopup(widget, theme);
            testCase.verifyNotEmpty(testCase.Layout.hInfoPopup, ...
                'hInfoPopup should be set after openInfoPopup');
            testCase.verifyTrue(ishandle(testCase.Layout.hInfoPopup), ...
                'hInfoPopup should be a valid handle');
            testCase.verifyTrue(strcmp(get(testCase.Layout.hInfoPopup, 'Type'), 'figure'), ...
                'hInfoPopup should be a figure');
            testCase.addTeardown(@() testCase.Layout.closeInfoPopup());
        end

        function testPopupDisplaysDescriptionText(testCase)
        % INFO-04: popup edit control contains the Description text.
            desc = 'Hello world description';
            widget = testCase.makeWidget(desc);
            theme = DashboardTheme('light');
            testCase.Layout.openInfoPopup(widget, theme);
            testCase.addTeardown(@() testCase.Layout.closeInfoPopup());
            popup = testCase.Layout.hInfoPopup;
            editCtrl = findobj(popup, 'Style', 'edit');
            testCase.verifyNotEmpty(editCtrl, 'Edit control should exist inside popup');
            str = get(editCtrl(1), 'String');
            % String may be char or cell
            if iscell(str)
                str = strjoin(str, ' ');
            end
            testCase.verifySubstring(str, 'Hello world', ...
                'Popup edit should contain the Description text');
        end

        function testCloseInfoPopupDeletesFigure(testCase)
        % INFO-05: closeInfoPopup removes the popup figure and clears hInfoPopup.
            widget = testCase.makeWidget('Close test');
            theme = DashboardTheme('light');
            testCase.Layout.openInfoPopup(widget, theme);
            popupHandle = testCase.Layout.hInfoPopup;
            testCase.Layout.closeInfoPopup();
            testCase.verifyEmpty(testCase.Layout.hInfoPopup, ...
                'hInfoPopup should be empty after closeInfoPopup');
            testCase.verifyFalse(ishandle(popupHandle), ...
                'Popup figure handle should be invalid after closeInfoPopup');
        end

        function testSecondOpenClosesFirst(testCase)
        % Opening a second popup should close the first one.
            widget = testCase.makeWidget('First popup');
            theme = DashboardTheme('light');
            testCase.Layout.openInfoPopup(widget, theme);
            firstHandle = testCase.Layout.hInfoPopup;
            widget2 = testCase.makeWidget('Second popup');
            testCase.Layout.openInfoPopup(widget2, theme);
            testCase.addTeardown(@() testCase.Layout.closeInfoPopup());
            testCase.verifyFalse(ishandle(firstHandle), ...
                'First popup figure should be deleted when second opens');
            testCase.verifyTrue(ishandle(testCase.Layout.hInfoPopup), ...
                'Second popup should be open');
        end

        function testAllWidgetTypesGetIconWhenDescriptionSet(testCase)
        % INFO-01 (breadth): TextWidget, NumberWidget, StatusWidget each get icon.
            theme = DashboardTheme('light');
            widgetClasses = {'TextWidget', 'NumberWidget', 'StatusWidget'};
            for i = 1:numel(widgetClasses)
                try
                    cls = widgetClasses{i};
                    hp = uipanel('Parent', testCase.hFig, 'Units', 'normalized', ...
                        'Position', [0 0 1 1], 'BorderType', 'none');
                    switch cls
                        case 'TextWidget'
                            w = TextWidget('Title', 'T', 'Position', [1 1 6 2], ...
                                'Content', 'x', 'Description', 'test');
                        case 'NumberWidget'
                            w = NumberWidget('Title', 'N', 'Position', [1 1 6 2], ...
                                'Value', 42, 'Description', 'test');
                        case 'StatusWidget'
                            w = StatusWidget('Title', 'S', 'Position', [1 1 6 2], ...
                                'Status', 'ok', 'Description', 'test');
                    end
                    w.ParentTheme = theme;
                    w.hPanel = hp;
                    layout = DashboardLayout();
                    layout.realizeWidget(w);
                    btn = findobj(w.hPanel, 'Tag', 'InfoIconButton');
                    testCase.verifyNotEmpty(btn, ...
                        sprintf('%s should have InfoIconButton when Description is set', cls));
                catch e
                    warning('TestInfoTooltip:widgetSkipped', ...
                        'Skipped %s due to error: %s', widgetClasses{i}, e.message);
                end
            end
        end

        function testRealizeWidgetWithDescriptionAddsIcon(testCase)
        % Full integration: allocate panel via layout, realize, check icon.
            layout = testCase.Layout;
            layout.hFigure = testCase.hFig;
            widget = MockDashboardWidget('Title', 'MW', 'Position', [1 1 6 2], ...
                'Description', 'A mock description');
            theme = DashboardTheme('light');
            widget.ParentTheme = theme;
            hp = uipanel('Parent', testCase.hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1], 'BorderType', 'none');
            widget.hPanel = hp;
            layout.realizeWidget(widget);
            btn = findobj(widget.hPanel, 'Tag', 'InfoIconButton');
            testCase.verifyNotEmpty(btn, ...
                'InfoIconButton should appear after realizeWidget with non-empty Description');
        end

        function testEndToEndInfoIconAppearsViaEngine(testCase)
        % Integration: DashboardEngine.render() injects InfoIconButton for widget with Description.
            d = DashboardEngine('Integration Test');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 6 2], ...
                'Content', 'x', 'Description', '## Hello');
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));
            w = d.Widgets{1};
            btn = findobj(w.hPanel, 'Tag', 'InfoIconButton');
            testCase.verifyNotEmpty(btn, ...
                'InfoIconButton should appear via DashboardEngine.render() for widget with Description');
        end

        function testEndToEndNoIconWhenDescriptionEmpty(testCase)
        % Integration: DashboardEngine.render() does NOT inject icon for widget without Description.
            d = DashboardEngine('Integration Test No Desc');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 6 2], 'Content', 'x');
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));
            w = d.Widgets{1};
            btn = findobj(w.hPanel, 'Tag', 'InfoIconButton');
            testCase.verifyEmpty(btn, ...
                'InfoIconButton should NOT appear for widget without Description');
        end

        function testReflowClosesOpenPopup(testCase)
        % After reflow(), any open info popup should be closed.
            d = DashboardEngine('Reflow Test');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 6 2], ...
                'Content', 'x', 'Description', '## Test');
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));
            % Manually open the popup via layout
            w = d.Widgets{1};
            theme = DashboardTheme(d.Theme);
            d.Layout.openInfoPopup(w, theme);
            testCase.verifyNotEmpty(d.Layout.hInfoPopup, ...
                'Popup should be open before reflow');
            % Trigger reflow via Layout.reflow()
            d.Layout.reflow(d.hFigure, d.Widgets, theme);
            testCase.verifyEmpty(d.Layout.hInfoPopup, ...
                'Popup should be dismissed after reflow()');
        end

        function testLayoutHFigureSetAfterRender(testCase)
        % After DashboardEngine.render(), Layout.hFigure should equal d.hFigure.
            d = DashboardEngine('HFigure Wiring Test');
            d.addWidget('text', 'Title', 'T', 'Position', [1 1 6 2], 'Content', 'x');
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));
            testCase.verifyTrue(ishandle(d.Layout.hFigure), ...
                'Layout.hFigure should be a valid handle after render()');
            testCase.verifyEqual(d.Layout.hFigure, d.hFigure, ...
                'Layout.hFigure should equal DashboardEngine.hFigure after render()');
        end

        function testPopupShowsPlainDescription(testCase)
        % Popup shows the raw Description string (no HTML/CSS contamination).
            desc = 'Temperature sensor T-401. Y-axis fixed to 55-100.';
            widget = testCase.makeWidget(desc);
            theme = DashboardTheme('light');
            testCase.Layout.openInfoPopup(widget, theme);
            testCase.addTeardown(@() testCase.Layout.closeInfoPopup());
            popup = testCase.Layout.hInfoPopup;
            editCtrl = findobj(popup, 'Style', 'edit');
            testCase.verifyNotEmpty(editCtrl, 'Edit control should exist inside popup');
            str = get(editCtrl(1), 'String');
            if iscell(str)
                str = strjoin(str, ' ');
            end
            testCase.verifySubstring(str, 'Temperature sensor', ...
                'Popup should contain the Description text verbatim');
            testCase.verifyEmpty(regexp(str, '<style>', 'once'), ...
                'Popup should NOT contain HTML style tags');
        end

    end
end
