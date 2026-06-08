function matches = filterMachines(machinesCell, searchTerm)
%FILTERMACHINES Pure Octave-safe substring filter over Machine Name + Id.
%   matches = filterMachines(machinesCell, searchTerm)
%
%   Inputs:
%     machinesCell - 1xN cell of Machine handles (full fleet, insertion order)
%     searchTerm   - char; empty string means no filter (returns all)
%
%   Output:
%     matches - cell of Machine handles in insertion order whose Name OR Id
%               contains searchTerm (case-insensitive substring); {} on no match
%
%   Octave-safe: uses strfind(lower(...)), never the MATLAB-only 'contains'.
%   Mirrors libs/FastSenseCompanion/private/filterTags.m (search pass only).
%
%   See also MachineSelectorPane, Fleet, filterTags.

    if isempty(machinesCell)
        matches = {};
        return;
    end

    if isempty(searchTerm)
        matches = machinesCell;
        return;
    end

    needle = lower(searchTerm);
    keep = false(1, numel(machinesCell));
    for i = 1:numel(machinesCell)
        m = machinesCell{i};
        if ~isempty(strfind(lower(m.Name), needle)) || ...
           ~isempty(strfind(lower(m.Id),   needle))
            keep(i) = true;
        end
    end
    matches = machinesCell(keep);
end
