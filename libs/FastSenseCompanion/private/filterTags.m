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
    % Determine each tag's group (first label or 'Ungrouped')
    % Accumulate into a map from group name -> cell of tags
    groupNames = {};
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
            groupNames{end+1} = grp; %#ok<AGROW>
        end
    end

    if isempty(groupNames)
        byGroup = struct('GroupName', {}, 'Tags', {});
        return;
    end

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
