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
%   No UI dependencies. Octave-compatible.
%   See also filterTags, TagCatalogPane.

    % Handle empty input
    if isempty(filteredTags)
        items     = {'  No tags match'};
        itemsData = {[]};
        return;
    end

    % Determine each tag's group (first label or 'Ungrouped')
    % Accumulate into ordered map
    groupNames = {};
    groupMap   = containers.Map();

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
