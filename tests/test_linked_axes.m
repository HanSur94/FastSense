function test_linked_axes()
%TEST_LINKED_AXES Tests for linked axes zoom propagation.
%   Requires PostSet listeners (MATLAB only, skipped on Octave).

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();
    add_fastsense_private_path();

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIPPED: Octave lacks PostSet listeners for axes properties.\n');
        return;
    end

    % testLinkedZoomPropagates
    fig = figure('Visible', 'off');
    ax1 = subplot(2,1,1, 'Parent', fig);
    ax2 = subplot(2,1,2, 'Parent', fig);

    fp1 = FastSense('Parent', ax1, 'LinkGroup', 'testgroup');
    fp1.addLine(1:1000, rand(1,1000));
    fp1.render();

    fp2 = FastSense('Parent', ax2, 'LinkGroup', 'testgroup');
    fp2.addLine(1:1000, rand(1,1000));
    fp2.render();

    % Zoom fp1
    set(fp1.hAxes, 'XLim', [200 400]);
    drawnow;
    pause(0.3);

    % fp2 should follow
    xlim2 = get(fp2.hAxes, 'XLim');
    assert(abs(xlim2(1) - 200) < 2 && abs(xlim2(2) - 400) < 2, ...
        'testLinkedZoomPropagates: fp2 XLim should match [200 400], got [%.1f %.1f]', xlim2(1), xlim2(2));

    close(fig);

    % testUnlinkedDoesNotPropagate
    fig = figure('Visible', 'off');
    ax1 = subplot(2,1,1, 'Parent', fig);
    ax2 = subplot(2,1,2, 'Parent', fig);

    fp1 = FastSense('Parent', ax1);
    fp1.addLine(1:1000, rand(1,1000));
    fp1.render();

    fp2 = FastSense('Parent', ax2);
    fp2.addLine(1:1000, rand(1,1000));
    fp2.render();

    originalXLim = get(fp2.hAxes, 'XLim');
    set(fp1.hAxes, 'XLim', [200 400]);
    drawnow;
    pause(0.3);

    xlim2 = get(fp2.hAxes, 'XLim');
    assert(isequal(xlim2, originalXLim), ...
        'testUnlinkedDoesNotPropagate: fp2 XLim should not change');

    close(fig);

    fprintf('    All 2 linked axes tests passed.\n');
end
