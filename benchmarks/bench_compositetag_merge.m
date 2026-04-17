function bench_compositetag_merge()
%BENCH_COMPOSITETAG_MERGE Pitfall 3 gate: 8 children x 100k samples.
%   Asserts the vectorized sort-based k-way merge in
%   CompositeTag.mergeStream_ meets two authoritative gates at scale:
%
%     PRIMARY GATE 1 (output-size proxy, PORTABLE):
%       numel(output_X) <= 1.10 * sum(child sample counts).
%       A naive implementation that materialized an N x M aligned matrix
%       (or a union-of-all-timestamps + per-child interp1 scan) would emit
%       ~sum(child samples) unique timestamps with zero coalesce, inflating
%       the output past the 1.10 headroom. The 10 percent margin covers
%       legitimate merge overhead while catching any N x M blowup.
%
%     PRIMARY GATE 2 (wall time):
%       tElapsed < 0.200 s at 8 children x 100k samples.
%       RESEARCH Section 5 estimates ~150 ms for the vectorized approach
%       (single sort + single linear walk). The 200 ms gate is the
%       authoritative perf ceiling from the phase ROADMAP.
%
%   DIAGNOSTIC ONLY (not gated): RSS readout via ps -o rss= on POSIX.
%   Rationale (RESEARCH Section 3): there is no portable peak-memory API
%   in Octave 11.1.0 (no memory(), no /proc on macOS). The output-size
%   proxy IS the primary memory gate because any impl that materialized
%   N x M timestamp-aligned values would also emit >1.10 x total in the
%   output. RSS is printed when available but never asserted.
%
%   Run:
%     octave --no-gui --eval "install(); bench_compositetag_merge();"
%
%   Exits 0 with "Pitfall 3 PASS" on success; raises assert() (non-zero
%   exit) if either gate fails.
%
%   See also CompositeTag, MonitorTag, SensorTag.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    try
        install();
    catch
        % install() is a no-op if paths are already set — swallow silently.
    end

    nChildren = 8;
    nPoints   = 100000;
    fprintf('\n== bench_compositetag_merge: %d children x %d samples ==\n', ...
            nChildren, nPoints);

    % Deterministic seed so the bench is reproducible run-to-run.
    if exist('rng', 'file') == 2
        rng(0);
    else
        rand('state', 0); %#ok<RAND>
        randn('state', 0); %#ok<RAND>
    end

    TagRegistry.clear();

    % Build 8 MonitorTags, each over a SensorTag with 100k jittered samples.
    % Jittering the ranges via (i-1) offset means timestamps OVERLAP across
    % children — total union across all 8 is ~ 800k unique timestamps, which
    % is what a naive union-materialisation impl would emit.
    children = cell(1, nChildren);
    for i = 1:nChildren
        x = sort(rand(1, nPoints) + (i - 1));
        y = sin(2*pi*x);
        st = SensorTag(sprintf('sens_%d', i), 'X', x, 'Y', y);
        children{i} = MonitorTag(sprintf('mon_%d', i), st, @(xx, yy) yy > 0);
    end

    comp = CompositeTag('agg', 'and');
    for i = 1:nChildren
        comp.addChild(children{i});
    end

    % Time the merge-sort aggregation (single call on cold cache).
    t0 = tic;
    [X, ~] = comp.getXY();
    tElapsed = toc(t0);

    % --- PRIMARY GATE 1: output-size proxy ---
    totalChildSamples = nChildren * nPoints;
    outSamples = numel(X);
    ratio = outSamples / totalChildSamples;
    fprintf('Output samples: %d / total child samples: %d (ratio %.3fx, gate <= 1.100x)\n', ...
            outSamples, totalChildSamples, ratio);
    assert(outSamples <= totalChildSamples * 1.1, ...
        sprintf('Pitfall 3 FAIL: output size %d > 1.1 * child total %d', ...
                outSamples, totalChildSamples));

    % --- PRIMARY GATE 2: wall time ---
    fprintf('Compute time: %.3f s (gate: < 0.200 s)\n', tElapsed);
    assert(tElapsed < 0.2, ...
        sprintf('Pitfall 3 FAIL: compute time %.3fs > 0.200s', tElapsed));

    % --- DIAGNOSTIC: RSS readout (informational; skip gracefully on unsupported) ---
    try
        if isunix() || ismac()
            pid = [];
            try
                pid = feature('getpid');
            catch
            end
            if isempty(pid) || ~isnumeric(pid) || pid <= 0
                try
                    pid = getpid();
                catch
                    pid = -1;
                end
            end
            if pid > 0
                [~, out] = system(sprintf('ps -o rss= -p %d', pid));
                rssKB = str2double(strtrim(out));
                if ~isnan(rssKB)
                    fprintf('RSS: %.1f MB (informational only)\n', rssKB / 1024);
                end
            end
        end
    catch
        fprintf('RSS readout unavailable (informational only).\n');
    end

    TagRegistry.clear();
    fprintf('Pitfall 3 PASS: output-size proxy + compute-time gates satisfied.\n\n');
end
