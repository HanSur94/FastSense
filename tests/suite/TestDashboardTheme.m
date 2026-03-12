classdef TestDashboardTheme < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testDefaultReturnsStruct(testCase)
            theme = DashboardTheme();
            testCase.verifyTrue(isstruct(theme), ...
                'DashboardTheme should return a struct');
        end

        function testContainsFastPlotFields(testCase)
            theme = DashboardTheme();
            testCase.verifyTrue(isfield(theme, 'Background'), ...
                'Should contain FastPlotTheme fields');
            testCase.verifyTrue(isfield(theme, 'FontSize'), ...
                'Should contain FastPlotTheme FontSize field');
        end

        function testContainsDashboardFields(testCase)
            theme = DashboardTheme();
            testCase.verifyTrue(isfield(theme, 'DashboardBackground'), ...
                'Should contain DashboardBackground');
            testCase.verifyTrue(isfield(theme, 'WidgetBackground'), ...
                'Should contain WidgetBackground');
            testCase.verifyTrue(isfield(theme, 'WidgetBorderColor'), ...
                'Should contain WidgetBorderColor');
            testCase.verifyTrue(isfield(theme, 'ToolbarBackground'), ...
                'Should contain ToolbarBackground');
            testCase.verifyTrue(isfield(theme, 'StatusOkColor'), ...
                'Should contain StatusOkColor');
            testCase.verifyTrue(isfield(theme, 'StatusWarnColor'), ...
                'Should contain StatusWarnColor');
            testCase.verifyTrue(isfield(theme, 'StatusAlarmColor'), ...
                'Should contain StatusAlarmColor');
            testCase.verifyTrue(isfield(theme, 'WidgetBorderWidth'), ...
                'Should contain WidgetBorderWidth');
            testCase.verifyTrue(isfield(theme, 'DragHandleColor'), ...
                'Should contain DragHandleColor');
            testCase.verifyTrue(isfield(theme, 'DropZoneColor'), ...
                'Should contain DropZoneColor');
            testCase.verifyTrue(isfield(theme, 'ToolbarFontColor'), ...
                'Should contain ToolbarFontColor');
            testCase.verifyTrue(isfield(theme, 'HeaderFontSize'), ...
                'Should contain HeaderFontSize');
            testCase.verifyTrue(isfield(theme, 'WidgetTitleFontSize'), ...
                'Should contain WidgetTitleFontSize');
            testCase.verifyTrue(isfield(theme, 'GaugeArcWidth'), ...
                'Should contain GaugeArcWidth');
            testCase.verifyTrue(isfield(theme, 'KpiFontSize'), ...
                'Should contain KpiFontSize');
        end

        function testPresetInheritance(testCase)
            theme = DashboardTheme('dark');
            baseDark = FastPlotTheme('dark');
            testCase.verifyEqual(theme.Background, baseDark.Background, ...
                'Should inherit FastPlotTheme dark preset Background');
            testCase.verifyEqual(theme.FontSize, baseDark.FontSize, ...
                'Should inherit FastPlotTheme dark preset FontSize');
        end

        function testNameValueOverrides(testCase)
            theme = DashboardTheme('default', 'DashboardBackground', [1 0 0]);
            testCase.verifyEqual(theme.DashboardBackground, [1 0 0], ...
                'Should apply name-value override');
        end

        function testAllPresetsHaveDashboardFields(testCase)
            presets = {'default', 'dark', 'light', 'industrial', 'scientific', 'ocean'};
            for i = 1:numel(presets)
                theme = DashboardTheme(presets{i});
                testCase.verifyTrue(isfield(theme, 'DashboardBackground'), ...
                    sprintf('%s preset should have DashboardBackground', presets{i}));
                testCase.verifyTrue(isfield(theme, 'StatusAlarmColor'), ...
                    sprintf('%s preset should have StatusAlarmColor', presets{i}));
            end
        end
    end
end
