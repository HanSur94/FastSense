classdef InspectorPane < handle
%INSPECTORPANE Placeholder pane for FastSenseCompanion.
%   Full implementation in Phase 1021.
%
%   See also FastSenseCompanion, CompanionTheme.

    properties (Access = private)
        hPanel_    = []  % uipanel handle (set by attach)
        Listeners_ = {}  % addlistener return values; deleted on detach
    end

    methods (Access = public)
        function attach(obj, parentPanel, hFig, catalogPane, orchestrator, theme)
        %ATTACH Place the placeholder label inside parentPanel.
        %   parentPanel  — a uipanel handle (provided by FastSenseCompanion)
        %   hFig         — uifigure handle (for uialert) [Phase 1021]
        %   catalogPane  — TagCatalogPane instance (for deselectKey) [Phase 1021]
        %   orchestrator — FastSenseCompanion instance (for notify) [Phase 1021]
        %   theme        — resolved CompanionTheme struct [Phase 1021]
        %
        %   All error() calls must use 'FastSenseCompanion:*' namespace.
        %   Phase 1021 (Plan 03) will fully implement this method.
            obj.hPanel_ = parentPanel;
            % Clear any existing children
            delete(obj.hPanel_.Children);
            uilabel(obj.hPanel_, ...
                'Text',                'Inspector — selection-driven, Phase 1021', ...
                'FontSize',            11, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment',   'middle', ...
                'Units',               'normalized', ...
                'Position',            [0 0 1 1]);
            % FontColor set by caller after attach via theme
        end

        function setState(obj, state, payload) %#ok<INUSD>
        %SETSTATE Route to the correct render method. Called by InspectorStateChanged listener.
        %   state   — char in {'welcome','tag','multitag','dashboard'}
        %   payload — struct (shape depends on state; see inspectorResolveState)
        %   Full implementation in Phase 1021 Plan 03.
        end

        function detach(obj)
        %DETACH Release listeners. Does not delete the panel (owned by FastSenseCompanion).
            delete(obj.Listeners_);
            obj.Listeners_ = {};
        end
    end
end
