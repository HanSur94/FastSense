function test_dashboard_widget_button_bar()
%TEST_DASHBOARD_WIDGET_BUTTON_BAR Regression: bar is right-anchored small strip.
%
%   Asserts the per-widget button bar (Tag='WidgetButtonBar') is rendered
%   as a small right-anchored strip (<= 64px wide) and not as a full-width
%   header band that would obscure each widget's own title rendering.
%
%   Covers (m52):
%     1. bar Position(3) (width) <= 64
%     2. bar Position(1) (x-anchor) > inset (NOT at left edge) when panel
%        is wider than the bar (normal widget size)
%     3. bar right edge sits ~inset px from the panel right edge
%     4. info + detach buttons fit inside the bar
%     5. SizeChangedFcn keeps the right-anchor invariant after a resize

    add_dashboard_path();

    nPassed = 0;
    nFailed = 0;

    % --- Test 1: bar is small + right-anchored after first render ----------
    try
        d = DashboardEngine('WidgetButtonBarTest');
        d.addWidget('text', 'Title', 'Hello', 'Content', 'World', ...
            'Position', [1 1 6 4]);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        bar = findobj(d.hFigure, 'Tag', 'WidgetButtonBar');
        assert(~isempty(bar), 'WidgetButtonBar uipanel not found');
        bar = bar(1);

        [barPos, panelPos] = getPixelPositions_(bar);
        inset = 2;

        assert(barPos(3) <= 64, ...
            sprintf('bar width %g exceeds 64px (full-width regression)', ...
            barPos(3)));

        if panelPos(3) > 64 + 2 * inset
            assert(barPos(1) > inset, ...
                sprintf('bar not right-anchored: x=%g (expected > %g)', ...
                barPos(1), inset));
        end

        rightGap = panelPos(3) - (barPos(1) + barPos(3));
        assert(abs(rightGap - inset) <= 1, ...
            sprintf('bar right-edge gap %g not ~%g px', rightGap, inset));

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testBarRightAnchored: %s\n', err.message);
        nFailed = nFailed + 1;
        try close(d.hFigure); catch, end %#ok<NOSEM>
    end

    % --- Test 2: info + detach buttons fit inside the bar -----------------
    try
        d = DashboardEngine('WidgetButtonBarFitTest');
        d.addWidget('text', 'Title', 'Hello', 'Content', 'World', ...
            'Position', [1 1 6 4]);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        bar = findobj(d.hFigure, 'Tag', 'WidgetButtonBar');
        assert(~isempty(bar), 'WidgetButtonBar uipanel not found');
        bar = bar(1);
        barPos = getPixelPositions_(bar);

        det  = findobj(bar, 'Tag', 'DetachButton',   '-depth', 1);
        info = findobj(bar, 'Tag', 'InfoIconButton', '-depth', 1);

        if ~isempty(det)
            dp = get(det(1), 'Position');
            assert(dp(1) >= 0, ...
                sprintf('DetachButton x=%g is negative', dp(1)));
            assert(dp(1) + dp(3) <= barPos(3) + 0.5, ...
                sprintf('DetachButton overflows bar (x+w=%g, barW=%g)', ...
                dp(1) + dp(3), barPos(3)));
        end
        if ~isempty(info)
            ip = get(info(1), 'Position');
            assert(ip(1) >= 0, ...
                sprintf('InfoIconButton x=%g is negative', ip(1)));
            assert(ip(1) + ip(3) <= barPos(3) + 0.5, ...
                sprintf('InfoIconButton overflows bar (x+w=%g, barW=%g)', ...
                ip(1) + ip(3), barPos(3)));
        end

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testButtonsFitBar: %s\n', err.message);
        nFailed = nFailed + 1;
        try close(d.hFigure); catch, end %#ok<NOSEM>
    end

    % --- Test 3: reflowButtonBar_ preserves right-anchor invariant --------
    try
        d = DashboardEngine('WidgetButtonBarReflowTest');
        d.addWidget('text', 'Title', 'Hello', 'Content', 'World', ...
            'Position', [1 1 6 4]);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        bar = findobj(d.hFigure, 'Tag', 'WidgetButtonBar');
        assert(~isempty(bar), 'WidgetButtonBar uipanel not found');
        bar = bar(1);
        widgetPanel = get(bar, 'Parent');

        % Resize the panel to a new pixel width and call the static
        % reflow helper that production wires to SizeChangedFcn. Calling
        % it directly keeps the test deterministic across desktop / -batch
        % MATLAB, which differ in whether SizeChangedFcn is wired.
        oldUnits = get(widgetPanel, 'Units');
        set(widgetPanel, 'Units', 'pixels');
        pp = get(widgetPanel, 'Position');
        set(widgetPanel, 'Position', [pp(1) pp(2) pp(3) - 30 pp(4)]);
        DashboardLayout.reflowButtonBar_(widgetPanel, 28, 2);
        set(widgetPanel, 'Units', oldUnits);

        [barPos, panelPos] = getPixelPositions_(bar);
        inset = 2;

        assert(barPos(3) <= 64, ...
            sprintf('after reflow, bar width %g exceeds 64px', barPos(3)));
        if panelPos(3) > 64 + 2 * inset
            assert(barPos(1) > inset, ...
                sprintf('after reflow, bar not right-anchored (x=%g)', ...
                barPos(1)));
        end
        rightGap = panelPos(3) - (barPos(1) + barPos(3));
        assert(abs(rightGap - inset) <= 1, ...
            sprintf('after reflow, right-edge gap %g not ~%g px', ...
            rightGap, inset));

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testReflowKeepsRightAnchor: %s\n', err.message);
        nFailed = nFailed + 1;
        try close(d.hFigure); catch, end %#ok<NOSEM>
    end

    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0
        error('test_dashboard_widget_button_bar:fail', ...
            '%d of %d tests failed', nFailed, nPassed + nFailed);
    end
end

function [pos, parentPos] = getPixelPositions_(h)
%GETPIXELPOSITIONS_ Return [pos, parentPos] in pixels for handle h.
    oldUnits = get(h, 'Units');
    set(h, 'Units', 'pixels');
    pos = get(h, 'Position');
    set(h, 'Units', oldUnits);

    parent = get(h, 'Parent');
    oldPU = get(parent, 'Units');
    set(parent, 'Units', 'pixels');
    parentPos = get(parent, 'Position');
    set(parent, 'Units', oldPU);
end

function add_dashboard_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fullfile(thisDir, '..');
    addpath(repoRoot);
    install();
end
