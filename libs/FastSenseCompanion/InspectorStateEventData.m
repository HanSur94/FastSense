classdef InspectorStateEventData < event.EventData
%INSPECTORSTATEEVENTDATA Payload for FastSenseCompanion.InspectorStateChanged event.
%
%   Usage (inside FastSenseCompanion.resolveInspectorState_):
%     ed = InspectorStateEventData(state, payload);
%     notify(obj, 'InspectorStateChanged', ed);
%
%   The InspectorPane listener receives ed as the second arg:
%     addlistener(orch, 'InspectorStateChanged', @(s, e) inspector.setState(e.State, e.Payload));
%
%   Properties (read-only after construction):
%     State    - char in {'welcome','tag','multitag','dashboard'}
%     Payload  - struct (shape depends on State; see inspectorResolveState header)
%
%   See also InspectorPane, FastSenseCompanion, inspectorResolveState, event.EventData.

    properties (SetAccess = immutable)
        State   = ''
        Payload = struct()
    end

    methods
        function obj = InspectorStateEventData(state, payload)
        %INSPECTORSTATEEVENTDATA Construct payload with (state, payload struct).
            if nargin < 2
                error('FastSenseCompanion:invalidEventData', ...
                    'InspectorStateEventData requires (state, payload).');
            end
            if ~ischar(state)
                error('FastSenseCompanion:invalidEventData', ...
                    'InspectorStateEventData: state must be char.');
            end
            validStates = {'welcome', 'tag', 'multitag', 'dashboard'};
            if ~any(strcmp(state, validStates))
                error('FastSenseCompanion:invalidEventData', ...
                    'InspectorStateEventData: state must be one of: %s. Got: ''%s''.', ...
                    strjoin(validStates, ', '), state);
            end
            if ~isstruct(payload)
                error('FastSenseCompanion:invalidEventData', ...
                    'InspectorStateEventData: payload must be a struct.');
            end
            obj.State   = state;
            obj.Payload = payload;
        end
    end
end
