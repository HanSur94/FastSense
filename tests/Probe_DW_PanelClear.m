classdef Probe_DW_PanelClear < DashboardWidget
%PROBE_DW_PANELCLEAR Test-only DashboardWidget subclass exposing the protected
%   static clearPanelControls. Used by tests under tests/ to verify the
%   protected-tag list without bypassing the class's Access spec.
%
%   Subclassing DashboardWidget grants access to its protected members; the
%   class lives under tests/ so it is only loaded inside test runs.

    methods (Static)
        function clear(hPanel)
        %CLEAR Public probe wrapping the protected clearPanelControls static.
            Probe_DW_PanelClear.clearPanelControls(hPanel);
        end
    end

    methods
        function render(~, ~)
        end

        function refresh(~)
        end

        function t = getType(~)
            t = 'probe';
        end
    end
end
