function [state, payload] = inspectorResolveState(lastInteraction, selectedTagKeys, selectedDashboardIdx, dashboards, tagRegistry)
%INSPECTORRESOLVESTATE Pure routing helper for InspectorPane state machine.
%   [state, payload] = inspectorResolveState(lastInteraction, selectedTagKeys, ...
%                                            selectedDashboardIdx, dashboards, tagRegistry)
%
%   Routing precedence:
%     numel(selectedTagKeys) == 1 -> 'tag'
%     numel(selectedTagKeys) >= 2 -> 'multitag'
%     lastInteraction == 'dashboard' AND selectedDashboardIdx > 0 -> 'dashboard'
%     otherwise                                                   -> 'welcome'
%
%   No UI dependencies - Octave-compatible.
%   See also InspectorPane, FastSenseCompanion, InspectorStateEventData.

    % Defensive empty handling
    if isempty(selectedTagKeys)
        selectedTagKeys = {};
    end
    if ~iscell(selectedTagKeys)
        selectedTagKeys = {selectedTagKeys};
    end
    if isempty(dashboards)
        dashboards = {};
    end
    nTags       = numel(selectedTagKeys);
    nDashboards = numel(dashboards);

    % Tag-count-wins routing (BEFORE checking lastInteraction)
    if nTags == 1
        state   = 'tag';
        tagH    = tagRegistry.get(selectedTagKeys{1});
        payload = struct('tag', tagH, 'tagKeys', {selectedTagKeys});
        return;
    end
    if nTags >= 2
        state    = 'multitag';
        tagsCell = cell(1, nTags);
        for ii = 1:nTags
            tagsCell{ii} = tagRegistry.get(selectedTagKeys{ii});
        end
        payload = struct('tags', {tagsCell}, 'tagKeys', {selectedTagKeys});
        return;
    end

    % Dashboard routing (only when no tags selected)
    if strcmp(lastInteraction, 'dashboard') && ...
            isnumeric(selectedDashboardIdx) && isscalar(selectedDashboardIdx) && ...
            selectedDashboardIdx > 0 && selectedDashboardIdx <= nDashboards
        state   = 'dashboard';
        payload = struct('dashboard', dashboards{selectedDashboardIdx});
        return;
    end

    % Welcome fallback
    state   = 'welcome';
    payload = struct('nTags', nTags, 'nDashboards', nDashboards);

end
