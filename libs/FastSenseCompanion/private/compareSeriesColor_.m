function c = compareSeriesColor_(theme, fleet, machineId)
%COMPARESERIESCOLOR_ Stable per-machine series color by fleet insertion index.
%   c = compareSeriesColor_(theme, fleet, machineId)
%
%   Maps a machine's fleet insertion index to theme.LineColors modulo the
%   palette length, so each machine gets a deterministic color independent of
%   which subset is selected for a comparison (CMP-02). A machine not found in
%   the fleet (defensive) falls back to insertion index 1.
%
%   Inputs:
%     theme     - CompanionTheme struct (uses theme.LineColors: cell of 1x3 RGB)
%     fleet     - Fleet handle (provides machineIds() insertion order)
%     machineId - char machine Id
%
%   Output:
%     c - 1x3 RGB row vector from theme.LineColors{mod(idx-1, n) + 1}
%
%   Octave-safe: plain find/strcmp/mod arithmetic; no contains, no isa.
%
%   See also buildCompareResolution_, CompanionTheme, Fleet.machineIds.

    ids = fleet.machineIds();
    idx = find(strcmp(ids, machineId), 1);
    if isempty(idx)
        idx = 1;
    end
    lc = theme.LineColors;
    c = lc{mod(idx - 1, numel(lc)) + 1};
end
