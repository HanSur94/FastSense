function [filteredTags, byGroup] = filterTags(tagsCell, searchTerm, activeKinds, activeCrits)
%FILTERTAGS Pure filter helper for TagCatalogPane.
%   [filteredTags, byGroup] = filterTags(tagsCell, searchTerm, activeKinds, activeCrits)
%
%   Inputs:
%     tagsCell    - 1xN cell of Tag handles (snapshot from TagRegistry)
%     searchTerm  - char; empty string means no search filter
%     activeKinds - cellstr subset of {'sensor','state','monitor','composite'}; empty = all
%     activeCrits - cellstr subset of {'low','medium','high','safety'}; empty = all
%
%   Outputs:
%     filteredTags - cell of Tag handles passing all filters; same ordering as tagsCell
%     byGroup      - struct array, fields: GroupName (char), Tags (cell of Tag handles)
%                    ordered alphabetically by GroupName; 'Ungrouped' placed last
%
%   Grouping rules:
%     - All tag kinds: use Labels{1} as the group name when non-empty.
%     - If Labels is empty: group is 'Ungrouped'.
%   Labels is the Tag classification field (set at construction); callers are
%   responsible for populating it with a subsystem name.  Labels must NOT carry
%   state-value vocabularies — that misuse causes 'closed'/'idle' groups.
%
%   After all groups are collected, case-insensitive duplicates are merged so
%   that 'FeedLine' and 'Feedline' (casing variants of the same subsystem) land
%   in a single group.  The canonical name is the first-seen spelling.
%
%   'Ungrouped' is always sorted last.
%
%   No UI dependencies - Octave-compatible.
%   See also groupByLabel, TagCatalogPane.

    % Handle empty input
    if isempty(tagsCell)
        filteredTags = {};
        byGroup = struct('GroupName', {}, 'Tags', {});
        return;
    end

    % --- Search pass (case-insensitive substring match across Key, Name, Description) ---
    if ~isempty(searchTerm)
        needle = lower(searchTerm);
        keep = false(1, numel(tagsCell));
        for i = 1:numel(tagsCell)
            t = tagsCell{i};
            if ~isempty(strfind(lower(t.Key), needle)) || ...
               ~isempty(strfind(lower(t.Name), needle)) || ...
               ~isempty(strfind(lower(t.Description), needle))
                keep(i) = true;
            end
        end
        tagsCell = tagsCell(keep);
    end

    % --- Kind pass (OR within kind row; if activeKinds is empty, skip) ---
    if ~isempty(activeKinds)
        keep = false(1, numel(tagsCell));
        for i = 1:numel(tagsCell)
            t = tagsCell{i};
            if (any(strcmp(activeKinds, 'sensor'))    && isa(t, 'SensorTag'))    || ...
               (any(strcmp(activeKinds, 'state'))     && isa(t, 'StateTag'))     || ...
               (any(strcmp(activeKinds, 'monitor'))   && isa(t, 'MonitorTag'))   || ...
               (any(strcmp(activeKinds, 'composite')) && isa(t, 'CompositeTag'))
                keep(i) = true;
            end
        end
        tagsCell = tagsCell(keep);
    end

    % --- Criticality pass (OR within crit row; if activeCrits is empty, skip) ---
    if ~isempty(activeCrits)
        keep = false(1, numel(tagsCell));
        for i = 1:numel(tagsCell)
            if any(strcmp(activeCrits, tagsCell{i}.Criticality))
                keep(i) = true;
            end
        end
        tagsCell = tagsCell(keep);
    end

    filteredTags = tagsCell;

    % --- Build byGroup struct array ---
    % Determine each tag's group (first label or 'Ungrouped').
    % Accumulate into a map from raw group name -> cell of tags.
    rawGroupNames = {};
    groupMap = containers.Map();

    for i = 1:numel(filteredTags)
        t = filteredTags{i};
        if isempty(t.Labels)
            grp = 'Ungrouped';
        else
            grp = t.Labels{1};
        end

        if isKey(groupMap, grp)
            groupMap(grp) = [groupMap(grp), {t}];
        else
            groupMap(grp) = {t};
            rawGroupNames{end+1} = grp; %#ok<AGROW>
        end
    end

    if isempty(rawGroupNames)
        byGroup = struct('GroupName', {}, 'Tags', {});
        return;
    end

    % Merge case-insensitive duplicate group names (e.g. 'FeedLine'/'Feedline').
    % Canonical name = first-seen spelling for that case-folded key.
    [groupNames, groupMap] = mergeCaseGroups_(rawGroupNames, groupMap);

    % Sort group names alphabetically, then move 'Ungrouped' to end
    hasUngrouped = any(strcmp(groupNames, 'Ungrouped'));
    namedGroups = groupNames(~strcmp(groupNames, 'Ungrouped'));
    namedGroups = sort(namedGroups);
    if hasUngrouped
        orderedNames = [namedGroups, {'Ungrouped'}];
    else
        orderedNames = namedGroups;
    end

    % Build struct array
    nGroups = numel(orderedNames);
    byGroup = struct('GroupName', cell(1, nGroups), 'Tags', cell(1, nGroups));
    for i = 1:nGroups
        byGroup(i).GroupName = orderedNames{i};
        byGroup(i).Tags      = groupMap(orderedNames{i});
    end
end

% -------------------------------------------------------------------------

function [names, mergedMap] = mergeCaseGroups_(rawNames, rawMap)
%MERGECASEGROUPS_ Merge case-insensitive duplicate group names.
%   When two groups differ only in case (e.g. 'FeedLine' and 'Feedline'),
%   merge their tag lists under a single canonical name.  The canonical name
%   is the first-seen spelling for that case-folded key (i.e. insertion-order
%   stable; determined by the order tags were processed in the caller loop).
%
%   Returns the deduplicated name list and an updated containers.Map.
    if isempty(rawNames)
        names     = {};
        mergedMap = containers.Map();
        return;
    end

    % Build a lowercase -> canonical-name mapping (first-seen wins).
    lowerToCanon = containers.Map();
    for i = 1:numel(rawNames)
        n    = rawNames{i};
        nLow = lower(n);
        if ~isKey(lowerToCanon, nLow)
            lowerToCanon(nLow) = n;
        end
    end

    % Build merged map: accumulate tags from rawMap under canonical names.
    mergedMap = containers.Map();
    names     = {};
    for i = 1:numel(rawNames)
        n      = rawNames{i};
        nLow   = lower(n);
        canon  = lowerToCanon(nLow);
        tags   = rawMap(n);
        if isKey(mergedMap, canon)
            mergedMap(canon) = [mergedMap(canon), tags];
        else
            mergedMap(canon) = tags;
            names{end+1} = canon; %#ok<AGROW>
        end
    end
end
