classdef AdHocPlotEventData < event.EventData
%ADHOCPLOTEVENTDATA Payload for FastSenseCompanion.OpenAdHocPlotRequested event.
%
%   Usage (inside InspectorPane.onPlot_):
%     ed = AdHocPlotEventData(tagKeys, mode);
%     notify(obj.Orchestrator_, 'OpenAdHocPlotRequested', ed);
%
%   Phase 1022 will subscribe and spawn the actual figure. In Phase 1021,
%   the event is fired but no listener acts on it.
%
%   Properties (read-only after construction):
%     TagKeys  - cellstr of selected tag keys
%     Mode     - char in {'Overlay','LinkedGrid'}
%
%   See also InspectorPane, FastSenseCompanion, event.EventData.

    properties (SetAccess = immutable)
        TagKeys = {}
        Mode    = ''
    end

    methods
        function obj = AdHocPlotEventData(tagKeys, mode)
        %ADHOCPLOTEVENTDATA Construct payload with (tagKeys cellstr, mode char).
            if nargin < 2
                error('FastSenseCompanion:invalidEventData', ...
                    'AdHocPlotEventData requires (tagKeys, mode).');
            end
            if ~iscell(tagKeys)
                error('FastSenseCompanion:invalidEventData', ...
                    'AdHocPlotEventData: tagKeys must be a cell array of char.');
            end
            for i = 1:numel(tagKeys)
                if ~ischar(tagKeys{i})
                    error('FastSenseCompanion:invalidEventData', ...
                        'AdHocPlotEventData: tagKeys{%d} must be char.', i);
                end
            end
            validModes = {'Overlay', 'LinkedGrid'};
            if ~ischar(mode) || ~any(strcmp(mode, validModes))
                error('FastSenseCompanion:invalidEventData', ...
                    'AdHocPlotEventData: mode must be one of: %s. Got: ''%s''.', ...
                    strjoin(validModes, ', '), mode);
            end
            obj.TagKeys = tagKeys;
            obj.Mode    = mode;
        end
    end
end
