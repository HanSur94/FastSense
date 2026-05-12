function test_preview_xcenters_advance()
%TEST_PREVIEW_XCENTERS_ADVANCE Regression for 260512-cxc.
%   FastSenseWidget.getPreviewSeries must thread the downsampler's
%   tail anchor through to xCenters(end). Pre-fix, the trailing
%   xCenter was the midpoint of the last bucket's interior min/max
%   X positions, which froze under live data growth.
%
%   Three cases:
%     A) Anchor present + spike near tail -> xCenters(end) == x(end).
%     B) Growing data: two widgets with different-length X arrays;
%        the longer one's xCenters(end) strictly exceeds the shorter.
%     C) No-anchor path (monotonic ramp): xCenters(end) == x(end) via
%        the pre-existing xPairs midpoint, untouched.
%
%   See also test_minmax_tail_anchor, test_dashboard_preview_envelope.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    % --- Case A: Anchor present, xCenters(end) reaches tail -----
    %     Synthetic repro from the root-cause investigation: a single
    %     extreme value mid-bucket near the tail, no other extremes
    %     after it. Pre-fix the bucket's interior min/max midpoint
    %     was hundreds of x-units behind segX(end).
    n = 10000;
    x = 1:n;
    y = zeros(1, n);
    y(9500) = 1000;       % mid-bucket spike near tail
    w = FastSenseWidget('Title', 'wA', 'XData', x, 'YData', y);
    s = w.getPreviewSeries(500);
    assert(~isempty(s), 'Case A: getPreviewSeries returned []');
    assert(abs(s.xCenters(end) - x(end)) < 1e-9, ...
        sprintf('Case A: xCenters(end)=%.6f expected %.6f', ...
                s.xCenters(end), x(end)));
    assert(numel(s.xCenters) == 500, ...
        sprintf('Case A: numel(xCenters)=%d expected 500', ...
                numel(s.xCenters)));

    % --- Case B: Growing data — xCenters(end) advances ----------
    %     Build two widgets where the second has more samples that
    %     extend X beyond the first's tail. The second widget's
    %     xCenters(end) must strictly exceed the first's. Same spike
    %     shape in both so each ends with a non-trivial last bucket.
    n1 = 10000;  n2 = 10500;
    x1 = 1:n1;   y1 = zeros(1, n1);  y1(9500) = 1000;
    x2 = 1:n2;   y2 = zeros(1, n2);  y2(9500) = 1000;
    w1 = FastSenseWidget('Title', 'wB1', 'XData', x1, 'YData', y1);
    w2 = FastSenseWidget('Title', 'wB2', 'XData', x2, 'YData', y2);
    s1 = w1.getPreviewSeries(500);
    s2 = w2.getPreviewSeries(500);
    assert(~isempty(s1) && ~isempty(s2), 'Case B: getPreviewSeries empty');
    assert(s2.xCenters(end) > s1.xCenters(end), ...
        sprintf('Case B: xCenters(end) did not advance (%.6f -> %.6f)', ...
                s1.xCenters(end), s2.xCenters(end)));
    assert(abs(s2.xCenters(end) - x2(end)) < 1e-9, ...
        sprintf('Case B: xCenters(end)=%.6f expected %.6f', ...
                s2.xCenters(end), x2(end)));

    % --- Case C: No-anchor path unchanged ------------------------
    %     Monotonic ramp: last bucket's true max IS at x(end), so the
    %     downsampler emits exactly 2*nb (no anchor appended — the
    %     260512-c5x cores only append when xOut(end) < segX(end)).
    %     For x=1:1000 with nb=50, last bucket samples = [981..1000];
    %     xPairs(:,end) = [981; 1000] (min-then-max in some order);
    %     midpoint = 990.5. The pre-existing midpoint formula does NOT
    %     equal x(end) here — but that is the pre-fix behavior we are
    %     preserving in the no-anchor case, and crucially the 260512-cxc
    %     override is correctly inert (anchorX is empty so xCenters(end)
    %     is left as the midpoint). This proves we did not regress the
    %     no-anchor path.
    x = 1:1000;
    y = x;
    w = FastSenseWidget('Title', 'wC', 'XData', x, 'YData', y);
    s = w.getPreviewSeries(50);
    assert(~isempty(s), 'Case C: getPreviewSeries returned []');
    expectedMidpoint = (981 + 1000) / 2;  % pre-existing midpoint, no-anchor path
    assert(abs(s.xCenters(end) - expectedMidpoint) < 1e-9, ...
        sprintf('Case C (no-anchor): xCenters(end)=%.6f expected midpoint %.6f', ...
                s.xCenters(end), expectedMidpoint));
    assert(numel(s.xCenters) == 50, ...
        sprintf('Case C: numel(xCenters)=%d expected 50', ...
                numel(s.xCenters)));

    try, close(findall(0, 'Type', 'figure')); catch, end
    fprintf('    All 3 preview xCenters-advance cases passed (A/B/C).\n');
end
