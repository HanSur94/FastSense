function bin = minDurationFilter_(x, bin, minDur)
    %MINDURATIONFILTER_ Zero contiguous 1-runs shorter than minDur (X units).
    %   bin = minDurationFilter_(x, bin, minDur) drops runs of resolved 1s whose
    %   span x(runEnd) - x(runStart) is strictly less than minDur — the same
    %   min-duration debounce MonitorTag applies in its Stage-3 pass, factored
    %   out so boolean-producing tags share one implementation (Issue #325).
    %
    %   Semantics:
    %     - Durations are in native X units.
    %     - Strict less-than (a run whose span == minDur is kept), matching the
    %       legacy detector / MonitorTag convention.
    %     - NaN ("unknown") entries are treated as run boundaries and are never
    %       modified — only resolved 0/1 runs are debounced.
    %     - No-op when minDur <= 0 or bin is empty.
    %
    %   Inputs:
    %     x      - numeric time vector (same length as bin)
    %     bin    - numeric 0/1 (may contain NaN) series
    %     minDur - scalar minimum run duration in X units
    %
    %   Output:
    %     bin - the input with sub-threshold 1-runs set to 0 (shape preserved).
    if minDur <= 0 || isempty(bin)
        return;
    end
    b = bin(:).';
    xv = x(:).';
    n = numel(b);
    i = 1;
    while i <= n
        if b(i) == 1                 % NaN and 0 are not run members
            j = i;
            while j < n && b(j + 1) == 1
                j = j + 1;
            end
            if xv(j) - xv(i) < minDur
                b(i:j) = 0;
            end
            i = j + 1;
        else
            i = i + 1;
        end
    end
    bin = reshape(b, size(bin));
end
