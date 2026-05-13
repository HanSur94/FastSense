classdef TestClearPanelHelper < DashboardWidget
%TESTCLEARPANELHELPER_ Minimal DashboardWidget subclass used by
%   tests/test_create_event_dialog.m to drive the
%   `clearPanelControls` protected-static through a real subclass.
%   Concrete render/refresh/getType stubs satisfy the
%   abstract-by-convention base contract.
%
%   See also test_create_event_dialog.

    methods
        function render(~, ~)
            % no-op
        end

        function refresh(~)
            % no-op
        end

        function t = getType(~)
            t = 'testClearPanelHelper';
        end
    end

    methods (Static)
        function run(hp)
            %RUN Expose the protected clearPanelControls static for tests.
            TestClearPanelHelper.clearPanelControls(hp);
        end
    end
end
