classdef TestDividerWidget < matlab.unittest.TestCase
%TESTDIVIDERWIDGET Unit tests for DividerWidget.
%
%   Tests cover default construction, custom properties, rendering,
%   refresh no-op, toStruct/fromStruct round-trip, and defaults-omitted
%   behavior in toStruct.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            %TESTDEFAULTCONSTRUCTION DividerWidget defaults.
            w = DividerWidget();
            testCase.verifyEqual(w.getType(), 'divider', ...
                'getType should return ''divider''');
            testCase.verifyEqual(w.Position, [1 1 24 1], ...
                'Default Position should be [1 1 24 1]');
            testCase.verifyEqual(w.Thickness, 1, ...
                'Default Thickness should be 1');
            testCase.verifyEmpty(w.Color, ...
                'Default Color should be empty');
        end

        function testCustomProperties(testCase)
            %TESTCUSTOMPROPERTIES Custom Thickness and Color are stored.
            w = DividerWidget('Thickness', 2, 'Color', [1 0 0]);
            testCase.verifyEqual(w.Thickness, 2, ...
                'Thickness should be 2');
            testCase.verifyEqual(w.Color, [1 0 0], ...
                'Color should be [1 0 0]');
        end

        function testRender(testCase)
            %TESTRENDER render() creates a uipanel child (hLine) inside parentPanel.
            w = DividerWidget();
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyEqual(w.hPanel, hp, ...
                'hPanel should be set to parentPanel');
            testCase.verifyNotEmpty(w.hLine, ...
                'hLine should be created after render');
            testCase.verifyTrue(ishandle(w.hLine), ...
                'hLine should be a valid handle');
            % Verify BorderType is 'none'
            testCase.verifyEqual(get(w.hLine, 'BorderType'), 'none', ...
                'hLine BorderType should be ''none''');
        end

        function testRefreshNoOp(testCase)
            %TESTREFRESHNOOB refresh() completes without error.
            w = DividerWidget();
            w.refresh(); % should not throw
            testCase.verifyTrue(true, 'refresh() should complete without error');
        end

        function testToStructRoundTrip(testCase)
            %TESTTOSTRUCTROUNDTRIP toStruct/fromStruct preserves Thickness and Color.
            w = DividerWidget('Thickness', 3, 'Color', [0 0.5 1], ...
                'Title', 'DIV', 'Position', [1 2 12 1]);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'divider', ...
                'Serialized type should be ''divider''');

            w2 = DividerWidget.fromStruct(s);
            testCase.verifyEqual(w2.getType(), 'divider', ...
                'Reconstructed type should be ''divider''');
            testCase.verifyEqual(w2.Thickness, 3, ...
                'Reconstructed Thickness should be 3');
            testCase.verifyEqual(w2.Color, [0 0.5 1], ...
                'Reconstructed Color should match');
            testCase.verifyEqual(w2.Title, 'DIV', ...
                'Reconstructed Title should match');
            testCase.verifyEqual(w2.Position, [1 2 12 1], ...
                'Reconstructed Position should match');
        end

        function testToStructDefaultsOmitted(testCase)
            %TESTTOSTRUCTDEFAULTSOMITTED toStruct on default DividerWidget
            %   does NOT contain ''thickness'' or ''color'' fields.
            w = DividerWidget();
            s = w.toStruct();
            testCase.verifyFalse(isfield(s, 'thickness'), ...
                'toStruct should not include ''thickness'' at default value');
            testCase.verifyFalse(isfield(s, 'color'), ...
                'toStruct should not include ''color'' when empty');
        end
    end
end
