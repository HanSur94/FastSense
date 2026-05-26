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
        try
            tagH    = tagRegistry.get(selectedTagKeys{1});
            state   = 'tag';
            payload = struct('tag', tagH, 'tagKeys', {selectedTagKeys});
            return;
        catch lookupErr %#ok<NASGU>
            % Diagnostic: surface key + available keys to console so the
            % discrepancy between catalog snapshot and registry singleton
            % becomes debuggable. Fall through to welcome with a hint.
            fprintf(2, ['[FastSenseCompanion] inspectorResolveState: failed to ', ...
                'resolve key ''%s''. Falling back to welcome state.\n'], ...
                selectedTagKeys{1});
            try
                avail = TagRegistry.find(@(t) true);
                fprintf(2, '  Registry has %d tags. First few keys:', numel(avail));
                for jj = 1:min(5, numel(avail)); fprintf(2, ' ''%s''', avail{jj}.Key); end
                fprintf(2, '\n');
            catch
            end
        end
    end
    if nTags >= 2
        try
            tagsCell = cell(1, nTags);
            for ii = 1:nTags
                tagsCell{ii} = tagRegistry.get(selectedTagKeys{ii});
            end
            state   = 'multitag';
            payload = struct('tags', {tagsCell}, 'tagKeys', {selectedTagKeys});
            return;
        catch
            fprintf(2, ['[FastSenseCompanion] inspectorResolveState: failed to ', ...
                'resolve %d-tag selection. Falling back to welcome.\n'], nTags);
        end
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
