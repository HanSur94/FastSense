function test_dashboard_config_dialog()
%TEST_DASHBOARD_CONFIG_DIALOG Octave parallel suite for DashboardConfigDialog.
%
%   Covers:
%     - Dialog opens with one control per public engine property.
%     - Apply writes edited values back to the engine.
%     - Apply updates the figure Name when Name changes.
%     - Close destroys the dialog figure.

    add_dashboard_path();

    nPassed = 0;
    nFailed = 0;

    % testDialogControlCount
    try
        d = DashboardEngine('DialogCtrlCount');
        dlg = DashboardConfigDialog(d);
        % There are 5 public properties on DashboardEngine today.
        assert(numel(dlg.PropSpecs) >= 5, ...
            sprintf('expected >=5 public props, got %d', numel(dlg.PropSpecs)));
        assert(numel(dlg.hEditCtrls) == numel(dlg.PropSpecs), ...
            'ctrl count must match spec count');
        dlg.close();
        assert(isempty(dlg.hFigure), 'hFigure should be cleared after close');
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testDialogControlCount: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testApplyUpdatesEngine
    try
        d = DashboardEngine('ApplyTest', 'LiveInterval', 5);
        dlg = DashboardConfigDialog(d);

        % Find handles for specific props
        setCtrlByName(dlg, 'Name', 'Renamed Dashboard');
        setCtrlByName(dlg, 'LiveInterval', '2.5');
        setCtrlByName(dlg, 'InfoFile', 'notes.md');

        dlg.apply();

        assert(strcmp(d.Name, 'Renamed Dashboard'), ...
            sprintf('Name not applied: %s', d.Name));
        assert(abs(d.LiveInterval - 2.5) < 1e-9, ...
            sprintf('LiveInterval not applied: %g', d.LiveInterval));
        assert(strcmp(d.InfoFile, 'notes.md'), ...
            sprintf('InfoFile not applied: %s', d.InfoFile));

        dlg.close();
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testApplyUpdatesEngine: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testApplyPopupChangesTheme
    try
        d = DashboardEngine('PopupTest');
        dlg = DashboardConfigDialog(d);
        setPopupByName(dlg, 'Theme', 'dark');
        dlg.apply();
        assert(strcmp(d.Theme, 'dark'), ...
            sprintf('Theme popup not applied: %s', d.Theme));
        dlg.close();
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testApplyPopupChangesTheme: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testConfigButtonOpensDialog
    try
        d = DashboardEngine('BtnOpens');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        before = findobj(0, 'Type', 'figure');
        d.Toolbar.onConfig();
        after = findobj(0, 'Type', 'figure');
        newFigs = setdiff(after, before);
        assert(~isempty(newFigs), 'onConfig() should open a new figure');
        for i = 1:numel(newFigs)
            try close(newFigs(i)); catch, end
        end
        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testConfigButtonOpensDialog: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testInvalidNumericWarns
    try
        d = DashboardEngine('InvalidNum');
        dlg = DashboardConfigDialog(d);
        setCtrlByName(dlg, 'LiveInterval', 'not-a-number');
        % apply() should not throw — it surfaces a warndlg instead.
        % Here we just check no exception escapes.
        try
            dlg.apply();
        catch
            % If it does throw, fail.
            error('apply() should not throw on invalid numeric input');
        end
        % Close any warndlg figures
        warnFigs = findobj(0, 'Type', 'figure', 'Name', 'Dashboard Config');
        for i = 1:numel(warnFigs)
            try close(warnFigs(i)); catch, end
        end
        dlg.close();
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testInvalidNumericWarns: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testAllControlsHaveTooltips
    try
        d = DashboardEngine('TipCheck');
        dlg = DashboardConfigDialog(d);
        for i = 1:numel(dlg.hEditCtrls)
            h = dlg.hEditCtrls{i};
            tip = get(h, 'TooltipString');
            assert(~isempty(tip), sprintf('control %d (%s) missing tooltip', ...
                i, dlg.PropSpecs{i}.name));
        end
        dlg.close();
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testAllControlsHaveTooltips: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testInfoFileHasBrowseButton
    try
        d = DashboardEngine('BrowseCheck');
        dlg = DashboardConfigDialog(d);
        browseBtns = findobj(dlg.hFigure, 'Style', 'pushbutton', ...
            'String', 'Browse…');
        assert(~isempty(browseBtns), 'expected Browse button for InfoFile');
        dlg.close();
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testInfoFileHasBrowseButton: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testShowTimePanelToggle
    try
        d = DashboardEngine('VisTest');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        assert(strcmp(get(d.hTimePanel, 'Visible'), 'on'), ...
            'time panel should start visible');

        d.ShowTimePanel = false;
        d.applyVisibilityAndRelayout();

        assert(strcmp(get(d.hTimePanel, 'Visible'), 'off'), ...
            'time panel should be hidden');

        % Content area y-offset should be 0 (no time panel reserve at bottom)
        ca = d.Layout.ContentArea;
        assert(abs(ca(2) - 0) < 1e-9, ...
            sprintf('content area y-offset should be 0, got %g', ca(2)));

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testShowTimePanelToggle: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0
        error('test_dashboard_config_dialog:fail', ...
            '%d of %d tests failed', nFailed, nPassed + nFailed);
    end
end

function setCtrlByName(dlg, name, valueStr)
    for i = 1:numel(dlg.PropSpecs)
        if strcmp(dlg.PropSpecs{i}.name, name)
            set(dlg.hEditCtrls{i}, 'String', valueStr);
            return;
        end
    end
    error('property %s not found in dialog', name);
end

function setPopupByName(dlg, name, choice)
    for i = 1:numel(dlg.PropSpecs)
        if strcmp(dlg.PropSpecs{i}.name, name)
            spec = dlg.PropSpecs{i};
            idx = find(strcmp(spec.choices, choice), 1);
            assert(~isempty(idx), sprintf('choice %s not in %s', choice, name));
            set(dlg.hEditCtrls{i}, 'Value', idx);
            return;
        end
    end
    error('popup %s not found in dialog', name);
end

function add_dashboard_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fullfile(thisDir, '..');
    addpath(repoRoot);
    install();
end
