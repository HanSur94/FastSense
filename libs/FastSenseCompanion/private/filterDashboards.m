function filteredIdx = filterDashboards(engines, searchTerm)
%FILTERDASHBOARDS Pure search filter for DashboardListPane.
%   filteredIdx = filterDashboards(engines, searchTerm)
%
%   Inputs:
%     engines     - 1xN cell of DashboardEngine handles
%     searchTerm  - char; empty string ('') means no filter (returns all indices)
%
%   Output:
%     filteredIdx - 1xM double row vector of 1-based indices into engines.
%                   Empty engines or zero matches: returns zeros(1,0).
%                   Empty searchTerm: returns 1:numel(engines).
%
%   Match rule: case-insensitive substring on engine.Name.
%   No UI dependencies - Octave-compatible.
%   See also DashboardListPane, filterTags.

    % Empty input guard
    if isempty(engines)
        filteredIdx = zeros(1, 0);
        return;
    end

    % Empty searchTerm = pass-through
    if isempty(searchTerm)
        filteredIdx = 1:numel(engines);
        return;
    end

    % Substring match loop (use strfind, NOT contains, for Octave compat)
    needle = lower(searchTerm);
    keep = false(1, numel(engines));
    for i = 1:numel(engines)
        nm = engines{i}.Name;
        if ~isempty(nm) && ~isempty(strfind(lower(nm), needle))
            keep(i) = true;
        end
    end
    allIdx = 1:numel(engines);
    filteredIdx = allIdx(keep);
    if isempty(filteredIdx)
        filteredIdx = zeros(1, 0);
    end

end
