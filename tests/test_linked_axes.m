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

    % testDeletedMemberDoesNotBlockPropagation (260610-fta)
    % delete() of a linked member used to leave a deleted handle in the
    % link registry; the next zoom raised "Invalid or deleted object" at
    % the corpse and never reached members registered after it.
    fig = figure('Visible', 'off');
    ax1 = subplot(3,1,1, 'Parent', fig);
    ax2 = subplot(3,1,2, 'Parent', fig);
    ax3 = subplot(3,1,3, 'Parent', fig);

    fp1 = FastSense('Parent', ax1, 'LinkGroup', 'delgroup');
    fp1.addLine(1:1000, rand(1,1000));
    fp1.render();

    fp2 = FastSense('Parent', ax2, 'LinkGroup', 'delgroup');
    fp2.addLine(1:1000, rand(1,1000));
    fp2.render();

    fp3 = FastSense('Parent', ax3, 'LinkGroup', 'delgroup');
    fp3.addLine(1:1000, rand(1,1000));
    fp3.render();

    delete(fp2);  % corpse sits between fp1 and fp3 in registry order

    set(fp1.hAxes, 'XLim', [300 600]);
    drawnow;
    pause(0.3);

    xlim3 = get(fp3.hAxes, 'XLim');
    assert(abs(xlim3(1) - 300) < 2 && abs(xlim3(2) - 600) < 2, ...
        'testDeletedMemberDoesNotBlockPropagation: fp3 XLim should match [300 600], got [%.1f %.1f]', ...
        xlim3(1), xlim3(2));

    close(fig);

    fprintf('    All 3 linked axes tests passed.\n');
end
