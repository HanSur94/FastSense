function [items, itemsData] = groupByLabel(filteredTags)
%GROUPBYLABEL Build uilistbox Items/ItemsData arrays from filtered tags.
%   [items, itemsData] = groupByLabel(filteredTags)
%
%   Input:
%     filteredTags - cell of Tag handles (already filtered by filterTags)
%
%   Outputs:
%     items     - cellstr flat list for uilistbox.Items
%                 group headers: char(9660) + ' {GroupName} ' + char(183) + ' {N}'
%                 child rows:    '  {tag.Name}'  (2-space indent)
%                 empty result:  {'  No tags match'}
%     itemsData - cell parallel to items
%                 [] (scalar double) for group-header rows
%                 tag.Key (char) for child rows
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
%   No UI dependencies. Octave-compatible.
%   See also filterTags, TagCatalogPane.

    % Handle empty input
    if isempty(filteredTags)
        items     = {'  No tags match'};
        itemsData = {[]};
        return;
    end

    % Determine each tag's group (first label or 'Ungrouped').
    % Accumulate into ordered map; key is the raw group string.
    rawGroupNames = {};
    groupMap      = containers.Map();

    for i = 1:numel(filteredTags)
        t   = filteredTags{i};
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

    % Merge case-insensitive duplicate group names (e.g. 'FeedLine'/'Feedline').
    % Canonical name = first-seen spelling for that case-folded key.
    [groupNames, groupMap] = mergeCaseGroups_(rawGroupNames, groupMap);

    % Sort alphabetically; Ungrouped always last
    hasUngrouped = any(strcmp(groupNames, 'Ungrouped'));
    namedGroups  = groupNames(~strcmp(groupNames, 'Ungrouped'));
    namedGroups  = sort(namedGroups);
    if hasUngrouped
        orderedNames = [namedGroups, {'Ungrouped'}];
    else
        orderedNames = namedGroups;
    end

    % Build flat items/itemsData arrays
    items     = {};
    itemsData = {};
    downArrow = char(9660);   % Unicode U+25BC = ▼
    midDot    = char(183);    % Unicode U+00B7 = ·

    for g = 1:numel(orderedNames)
        grpName   = orderedNames{g};
        grpTags   = groupMap(grpName);
        nGroup    = numel(grpTags);

        % Group header row
        header        = [downArrow, ' ', grpName, ' ', midDot, ' ', num2str(nGroup)];
        items{end+1}     = header;     %#ok<AGROW>
        itemsData{end+1} = [];         %#ok<AGROW>

        % Child tag rows (preserving input order within group)
        for k = 1:nGroup
            items{end+1}     = ['  ', grpTags{k}.Name]; %#ok<AGROW>
            itemsData{end+1} = grpTags{k}.Key;          %#ok<AGROW>
        end
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
