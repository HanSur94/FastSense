function test_dashboard_zero_padding()
%TEST_DASHBOARD_ZERO_PADDING Regression tests for zero-default layout padding (D-03) and D-09 backward-compat.
%
%   Covers five invariants:
%     1. Flush edges (D-03): default layout yields pos(1)=0 and pos(1)+pos(3)=1 for full-row widget.
%     2. Zero inter-widget gap (D-03): adjacent half-row widgets touch exactly.
%     3. User override still honored (D-09): direct assignment of Padding survives.
%     4. D-09 construction NV-pair preservation: constructor NV-pairs override the new zero defaults.
%     5. D-09 DashboardSerializer round-trip: serializer does NOT persist layout padding, so
%        reconstructed dashboards get the zero defaults (current contract — a future serializer
%        extension that persists padding must update this assertion).

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    % --- Case 1: Flush edges (D-03) ------------------------------------------
    layout = DashboardLayout();
    layout.ContentArea = [0 0 1 1];
    layout.TotalRows = 1;
    pos = layout.computePosition([1 1 24 1]);
    assert(abs(pos(1) - 0) < 1e-12, ...
        sprintf('Case 1 flush-left: pos(1)=%g expected 0', pos(1)));
    assert(abs((pos(1) + pos(3)) - 1) < 1e-12, ...
        sprintf('Case 1 flush-right: pos(1)+pos(3)=%g expected 1', pos(1) + pos(3)));

    % --- Case 2: Zero inter-widget gap (D-03) --------------------------------
    layout2 = DashboardLayout();
    layout2.ContentArea = [0 0 1 1];
    pos1 = layout2.computePosition([1 1 12 1]);
    pos2 = layout2.computePosition([13 1 12 1]);
    assert(abs((pos1(1) + pos1(3)) - pos2(1)) < 1e-12, ...
        sprintf('Case 2 zero-gap: pos1 right=%g pos2 left=%g', ...
            pos1(1) + pos1(3), pos2(1)));

    % --- Case 3: User override still honored (D-09 direct assignment) --------
    layout3 = DashboardLayout();
    layout3.ContentArea = [0 0 1 1];
    layout3.Padding = [0.05 0.05 0.05 0.05];
    pos3 = layout3.computePosition([1 1 6 1]);
    assert(pos3(1) >= 0.05 - 1e-12, ...
        sprintf('Case 3 user override: pos(1)=%g expected >= 0.05', pos3(1)));

    % --- Case 4: D-09 construction NV-pair preservation ----------------------
    layout4 = DashboardLayout('Padding', [0.03 0.04 0.05 0.06], ...
                              'GapH', 0.01, 'GapV', 0.02);
    assert(isequal(layout4.Padding, [0.03 0.04 0.05 0.06]), ...
        'Case 4: Padding NV-pair not preserved');
    assert(abs(layout4.GapH - 0.01) < 1e-12, ...
        sprintf('Case 4: GapH=%g expected 0.01', layout4.GapH));
    assert(abs(layout4.GapV - 0.02) < 1e-12, ...
        sprintf('Case 4: GapV=%g expected 0.02', layout4.GapV));

    % --- Case 5: D-09 DashboardSerializer round-trip -------------------------
    % D-09: DashboardSerializer does not persist layout padding; reconstructed
    % dashboards get the zero defaults. This test locks that contract so a
    % future serializer extension that DOES persist padding must update this
    % assertion.
    tempDir = tempname();
    mkdir(tempDir);
    cleanup = onCleanup(@() rmdirSafe(tempDir));
    tempFile = fullfile(tempDir, 'rt_test_dashboard.m');

    d = DashboardEngine('rt-test');
    % Layout has SetAccess=private on DashboardEngine, but Layout itself is a
    % handle whose public properties remain settable through the handle alias.
    dLayout = d.Layout;
    dLayout.Padding = [0.03 0.04 0.05 0.06];
    dLayout.GapH    = 0.01;
    dLayout.GapV    = 0.02;
    d.addWidget('text', 'Title', 'rt', 'Content', 'x', 'Position', [1 1 6 1]);

    % Pre-save assertions: verify explicit assignments stuck.
    assert(isequal(d.Layout.Padding, [0.03 0.04 0.05 0.06]), ...
        'Case 5 pre-save: Padding assignment lost');
    assert(abs(d.Layout.GapH - 0.01) < 1e-12, ...
        'Case 5 pre-save: GapH assignment lost');
    assert(abs(d.Layout.GapV - 0.02) < 1e-12, ...
        'Case 5 pre-save: GapV assignment lost');

    % Build config (engine's export path uses widgetsToConfig) and serialize.
    cfg = DashboardSerializer.widgetsToConfig(d.Name, d.Theme, d.LiveInterval, ...
        d.Widgets, d.InfoFile);
    DashboardSerializer.save(cfg, tempFile);

    % Round-trip: load reconstructs engine from generated function.
    d2 = DashboardSerializer.load(tempFile);
    assert(isa(d2, 'DashboardEngine'), 'Case 5: loaded object is not a DashboardEngine');
    % Serializer currently does NOT persist layout padding -> expect zero defaults.
    assert(isequal(d2.Layout.Padding, [0 0 0 0]), ...
        sprintf(['Case 5 round-trip: reconstructed Padding=[%g %g %g %g] ' ...
                 'expected zero defaults (serializer does not persist layout)'], ...
            d2.Layout.Padding(1), d2.Layout.Padding(2), ...
            d2.Layout.Padding(3), d2.Layout.Padding(4)));
    assert(d2.Layout.GapH == 0, ...
        sprintf('Case 5 round-trip: reconstructed GapH=%g expected 0', d2.Layout.GapH));
    assert(d2.Layout.GapV == 0, ...
        sprintf('Case 5 round-trip: reconstructed GapV=%g expected 0', d2.Layout.GapV));

    fprintf('    All 5 tests passed.\n');
end

function rmdirSafe(d)
%RMDIRSAFE Best-effort recursive directory removal for test cleanup.
    try
        if exist(d, 'dir')
            rmdir(d, 's');
        end
    catch
        % Ignore cleanup failures
    end
end
