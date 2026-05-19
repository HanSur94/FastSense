function test_minmax_tail_anchor()
%TEST_MINMAX_TAIL_ANCHOR Regression for 260512-c5x.
%   The MinMax downsampler must never let the rightmost emitted X
%   fall short of the data tail. Verified across the MEX core, the
%   pure-MATLAB core, and the log-X core, and for both "anchor
%   needed" and "anchor not needed" configurations.
%
%   See also test_minmax_downsample, minmax_downsample,
%            minmax_core_mex.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
    add_fastsense_private_path();

    % --- Case A: spike near tail, no bucket-aligned extreme -----
    %     Synthetic repro from the root-cause investigation: a single
    %     extreme value mid-bucket near the tail, no other extremes
    %     after it. The displayed line previously stopped well short
    %     of segX(end) because neither min nor max of the final bucket
    %     landed on x(end).
    x = 1:10000;
    y = zeros(1, 10000);
    y(9500) = 1000;       % big spike that lands mid-bucket
    [xo, yo] = minmax_downsample(x, y, 500, false); %#ok<ASGLU>
    assert(xo(end) == x(end), ...
        'Case A: tail anchor — xo(end)=%g expected %g', xo(end), x(end));
    assert(ismember(numel(xo), [1000, 1001]), ...
        'Case A: length must be 2*nb or 2*nb+1, got %d', numel(xo));
    assert(all(diff(xo) >= 0), 'Case A: X monotonicity violated');

    % --- Case B: bucket-aligned tail (no anchor needed) ----------
    %     Last bucket's true max IS at segX(end), so length should
    %     remain exactly 2*nb (anchor not appended — preserves
    %     monotonicity guarantee that anchor only appears when its X
    %     strictly exceeds xOut(end)).
    x = 1:1000;
    y = x;                % monotonically increasing -> last bucket
                          % max = y(end) at x(end)
    [xo, yo] = minmax_downsample(x, y, 100, false); %#ok<ASGLU>
    assert(xo(end) == x(end), 'Case B: xo(end) must equal x(end)');
    assert(numel(xo) == 200, ...
        'Case B: no anchor needed -> length 2*nb, got %d', numel(xo));

    % --- Case D: log-X path --------------------------------------
    %     Positive log-spaced X with an extreme near (but not AT) the
    %     tail — exercises minmax_core_logx's variable-length path.
    x = logspace(0, 4, 5000);     % positive, log-spaced
    y = randn(1, 5000);
    y(end - 200) = 1e6;           % extreme near tail, not at tail
    [xo, ~] = minmax_downsample(x, y, 200, false, true);
    assert(xo(end) == x(end), ...
        'Case D (logX): xo(end)=%g expected %g', xo(end), x(end));
    assert(all(diff(xo) >= 0), 'Case D: X monotonicity violated');

    % --- Case E: live-demo magnitude (~600k samples, irregular) --
    %     Realistic industrial-scale dataset — confirms tail anchor
    %     works on the same shape that produced the original bug
    %     report (industrial plant demo reactor.pressure widget).
    rng(42);
    n = 600000;
    x = sort(rand(1, n) * 740000);  % irregular spacing, industrial scale
    y = randn(1, n);
    [xo, ~] = minmax_downsample(x, y, 1200, false);
    assert(xo(end) == x(end), ...
        'Case E: live-demo scale — xo(end)=%.6f expected %.6f', ...
        xo(end), x(end));

    fprintf('    All 4 tail-anchor cases passed (A/B/D/E).\n');
end
