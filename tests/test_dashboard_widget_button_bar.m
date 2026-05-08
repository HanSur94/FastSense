function test_dashboard_widget_button_bar()
%TEST_DASHBOARD_WIDGET_BUTTON_BAR Regression: bar is full-width with
%   widget content rendered into a sub-panel BELOW it (no overlap).
%
%   Asserts the per-widget button bar (Tag='WidgetButtonBar') is rendered
%   as a full-width opaque header strip and a sibling WidgetContentPanel
%   sub-panel hosts the widget's own content. Replaces the m52
%   right-anchored-strip contract with the mhv full-width-with-content-
%   panel contract per user instruction "must be full widht .. just
%   make sure all widget info and displa si bwlow it".
%
%   Covers (mhv):
%     1. bar Position(1) == inset (left-anchored)
%     2. bar Position(3) ≈ panelWidth - 2*inset (full width)
%     3. WidgetContentPanel exists, bottom-anchored, full-width
%     4. content panel top edge <= bar bottom edge (no overlap)
%     5. info + detach buttons still fit inside the bar (preserved)
%     6. reflowChrome_ keeps full-width invariant after resize
%     7. DividerWidget gets NO chrome (no bar, no content panel)

    add_dashboard_path();

    nPassed = 0;
    nFailed = 0;

    % --- Test 1: bar is full-width left-anchored after first render -------
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
        expectedW = panelPos(3) - 2 * inset;
        assert(abs(barPos(3) - expectedW) <= 1, ...
            sprintf('bar width %g != expected full width %g (full-width regression)', ...
            barPos(3), expectedW));
        assert(abs(barPos(1) - inset) <= 1, ...
            sprintf('bar not left-anchored: x=%g (expected ~%g)', barPos(1), inset));

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testBarFullWidth: %s\n', err.message);
        nFailed = nFailed + 1;
        try close(d.hFigure); catch, end %#ok<NOSEM>
    end

    % --- Test 2: WidgetContentPanel exists, sized below bar, full-width ---
    try
        d = DashboardEngine('WidgetButtonBarContentPanelTest');
        d.addWidget('text', 'Title', 'Hello', 'Content', 'World', ...
            'Position', [1 1 6 4]);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        bar = findobj(d.hFigure, 'Tag', 'WidgetButtonBar');
        assert(~isempty(bar), 'WidgetButtonBar uipanel not found');
        bar = bar(1);
        barPos = getPixelPositions_(bar);

        content = findobj(d.hFigure, 'Tag', 'WidgetContentPanel');
        assert(~isempty(content), 'WidgetContentPanel uipanel not found');
        content = content(1);
        [contentPos, cellPos] = getPixelPositions_(content);

        assert(abs(contentPos(2)) <= 1, ...
            sprintf('content panel not bottom-anchored: y=%g', contentPos(2)));
        assert(abs(contentPos(3) - cellPos(3)) <= 1, ...
            sprintf('content panel width %g != cell width %g', contentPos(3), cellPos(3)));

        % Bar bottom in cell-relative pixels; content top must be at-or-below.
        barBottom = barPos(2);
        contentTop = contentPos(2) + contentPos(4);
        assert(contentTop <= barBottom + 0.5, ...
            sprintf('content panel overlaps bar (contentTop=%g > barBottom=%g)', ...
            contentTop, barBottom));

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testContentPanelBelowBar: %s\n', err.message);
        nFailed = nFailed + 1;
        try close(d.hFigure); catch, end %#ok<NOSEM>
    end

    % --- Test 3: info + detach buttons fit inside the bar ----------------
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

    % --- Test 4: reflowChrome_ keeps full-width + resizes content panel --
    try
        d = DashboardEngine('WidgetButtonBarReflowTest');
        d.addWidget('text', 'Title', 'Hello', 'Content', 'World', ...
            'Position', [1 1 6 4]);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        bar = findobj(d.hFigure, 'Tag', 'WidgetButtonBar');
        assert(~isempty(bar), 'WidgetButtonBar uipanel not found');
        bar = bar(1);
        % After mhv, the bar is parented to the OUTER cell panel (hCellPanel).
        cellPanel = get(bar, 'Parent');

        content = findobj(d.hFigure, 'Tag', 'WidgetContentPanel');
        assert(~isempty(content), 'WidgetContentPanel uipanel not found');
        content = content(1);

        % Resize the cell panel to a new pixel width and call the static
        % reflow helper that production wires to SizeChangedFcn.
        oldUnits = get(cellPanel, 'Units');
        set(cellPanel, 'Units', 'pixels');
        pp = get(cellPanel, 'Position');
        set(cellPanel, 'Position', [pp(1) pp(2) pp(3) - 30 pp(4)]);
        DashboardLayout.reflowChrome_(cellPanel, 28, 2);
        set(cellPanel, 'Units', oldUnits);

        [barPos, panelPos] = getPixelPositions_(bar);
        inset = 2;
        assert(abs(barPos(3) - (panelPos(3) - 2 * inset)) <= 1, ...
            sprintf('after reflow, bar width %g != full width %g', ...
            barPos(3), panelPos(3) - 2 * inset));
        assert(abs(barPos(1) - inset) <= 1, ...
            sprintf('after reflow, bar not left-anchored (x=%g)', barPos(1)));

        [contentPos, cellPos] = getPixelPositions_(content);
        assert(abs(contentPos(3) - cellPos(3)) <= 1, ...
            'content panel did not resize on reflow');
        assert(contentPos(2) + contentPos(4) <= barPos(2) + 0.5, ...
            'content panel overlaps bar after reflow');

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testReflowKeepsFullWidth: %s\n', err.message);
        nFailed = nFailed + 1;
        try close(d.hFigure); catch, end %#ok<NOSEM>
    end

    % --- Test 5: DividerWidget gets NO chrome ----------------------------
    try
        d = DashboardEngine('WidgetButtonBarDividerTest');
        d.addWidget('divider', 'Position', [1 1 6 1]);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        assert(numel(d.Widgets) >= 1, 'no widgets registered');
        w = d.Widgets{1};
        assert(isa(w, 'DividerWidget'), 'expected DividerWidget');

        % No-chrome path: hCellPanel == hPanel (or hCellPanel left empty).
        % Either way, the cell panel that owns this widget must contain
        % NO WidgetButtonBar and NO WidgetContentPanel.
        cellPanel = w.hCellPanel;
        if isempty(cellPanel) || ~ishandle(cellPanel)
            cellPanel = w.hPanel;
        end
        assert(~isempty(cellPanel) && ishandle(cellPanel), ...
            'DividerWidget has no resolvable cell panel');

        bars = findobj(cellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
        assert(isempty(bars), ...
            'DividerWidget unexpectedly got a WidgetButtonBar');
        contents = findobj(cellPanel, 'Tag', 'WidgetContentPanel', '-depth', 1);
        assert(isempty(contents), ...
            'DividerWidget unexpectedly got a WidgetContentPanel');

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testDividerNoChrome: %s\n', err.message);
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
