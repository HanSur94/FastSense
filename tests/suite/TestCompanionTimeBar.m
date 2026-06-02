classdef TestCompanionTimeBar < matlab.unittest.TestCase
%TESTCOMPANIONTIMEBAR MATLAB-only UI smoke suite for CompanionTimeBar.
%
%   Tests the range button + picker popup produced by Plan 1041-04:
%     - Range button exists in toolbar col 9 with Tag 'CompanionTimeRangeBtn'
%     - Default label is 'Last 7 days'
%     - openPicker() creates exactly one 400x280 uifigure named 'Time Range'
%     - Calling openPicker() twice leaves exactly one popup (singleton)
%     - Clicking a preset button fires RangeChanged, updates the label, closes the popup
%     - 'All data' preset sets the all-spec (empty t0/t1) and correct button label
%     - Non-default range uses Accent BackgroundColor; default uses WidgetBorderColor
%     - setTheme() restyles the button without error
%
%   All tests are MATLAB-only (uifigure). The TestMethodSetup skipOnOctave
%   guard skips the entire suite on Octave, matching the companion test pattern.
%
%   See also CompanionTimeBar, CompanionTimeRange, FastSenseCompanion.

    properties
        HostFig_       % host uifigure for the toolbar grid
        ToolbarGrid_   % 1x10 uigridlayout mimicking the companion toolbar
        Range_         % CompanionTimeRange handle
        Theme_         % CompanionTheme struct ('dark')
        Bar_           % CompanionTimeBar instance under test
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            %ADDPATHS Add project root and install() to set up all library paths.
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function skipOnOctave(testCase)
            %SKIPONOCTAVE CompanionTimeBar is MATLAB-only. Skip entire suite on Octave.
            testCase.assumeFalse( ...
                exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestCompanionTimeBar: skipped on Octave (uifigure not available)');
        end

        function buildFixtures(testCase)
            %BUILDFIXTURES Create the hidden host figure, toolbar grid, range, theme, and bar.
            testCase.HostFig_    = uifigure('Visible', 'off');
            testCase.ToolbarGrid_ = uigridlayout(testCase.HostFig_, [1 10]);
            testCase.ToolbarGrid_.ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, '1x', 36};
            testCase.ToolbarGrid_.RowHeight   = {'1x'};
            testCase.Range_  = CompanionTimeRange();
            testCase.Theme_  = CompanionTheme.get('dark');
            % Build a minimal app stand-in that exposes hFig_ so CompanionTimeBar
            % can position the popup and use uialert. We pass the companion figure
            % handle directly. CompanionTimeBar reads app.hFig_ for position/uialert.
            % Use a struct-in-handle trick: provide an anonymous handle object with
            % hFig_ pointing to HostFig_ via a property struct stored as appdata.
            % Simpler: construct a real (hidden) FastSenseCompanion so we get the
            % full wiring. But that is heavyweight. Instead, pass the HostFig_ as
            % the app handle -- CompanionTimeBar only reads app.hFig_ (the uifigure).
            % We create a minimal anonymous handle class stand-in stored on HostFig_
            % via appdata, then pass it. Because we CANNOT easily create an inline
            % handle class here, we construct a real FastSenseCompanion hidden
            % companion as the lightest supported approach (mirrors TestFastSenseCompanion).
            % We pass [] as app when we want the standalone path -- the bar
            % gracefully handles empty app (all try/catch guarded).
            testCase.Bar_ = CompanionTimeBar( ...
                testCase.ToolbarGrid_, 9, testCase.Range_, testCase.Theme_, []);
            testCase.addTeardown(@() testCase.tearDownFixtures_());
        end
    end

    methods (Test)

        function testRangeButtonExists(testCase)
            %TESTRANGEBUTTONEXISTS Range button with Tag 'CompanionTimeRangeBtn' sits in col 9.
            btn = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            testCase.verifyEqual(numel(btn), 1, ...
                'testRangeButtonExists: expected exactly one CompanionTimeRangeBtn');
            testCase.verifyEqual(btn.Layout.Column, 9, ...
                'testRangeButtonExists: CompanionTimeRangeBtn must sit in column 9');
        end

        function testRangeButtonDefaultLabel(testCase)
            %TESTRANGEBUTTONDEFAULTLABEL Button Text equals ''Last 7 days'' by default.
            btn = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            testCase.verifyEqual(btn.Text, 'Last 7 days', ...
                'testRangeButtonDefaultLabel: default Text must be ''Last 7 days''');
        end

        function testOpenPickerCreatesOnePopup(testCase)
            %TESTOPENPICKERCREATEONEPOPUP openPicker() creates exactly one 400x280 popup.
            testCase.Bar_.openPicker();
            testCase.addTeardown(@() testCase.closePopup_());
            drawnow;
            figs = findall(groot, 'Type', 'figure', 'Name', 'Time Range');
            testCase.verifyEqual(numel(figs), 1, ...
                'testOpenPickerCreatesOnePopup: expected exactly one ''Time Range'' figure');
            testCase.verifyEqual(figs(1).Position(3), 400, ...
                'testOpenPickerCreatesOnePopup: popup width must be 400');
            testCase.verifyEqual(figs(1).Position(4), 280, ...
                'testOpenPickerCreatesOnePopup: popup height must be 280');
        end

        function testOpenPickerSingleton(testCase)
            %TESTOPENPICKERSINGLETON Calling openPicker() twice leaves exactly one popup.
            testCase.Bar_.openPicker();
            testCase.addTeardown(@() testCase.closePopup_());
            drawnow;
            testCase.Bar_.openPicker();
            drawnow;
            figs = findall(groot, 'Type', 'figure', 'Name', 'Time Range');
            testCase.verifyEqual(numel(figs), 1, ...
                'testOpenPickerSingleton: second openPicker() must NOT spawn a new popup');
        end

        function testPresetFiresEventAndUpdatesLabel(testCase)
            %TESTPRESETFIRESEVENTSANDUPDATESLABEL ''Last 30 days'' preset fires RangeChanged and updates label.
            % Handle-type counter: an anonymous function cannot assign into the
            % test workspace (the old assignin('caller',...) wrote into the event
            % dispatcher's frame and captured fireCount=0), so use a containers.Map
            % whose handle the listener mutates in place.
            fireCounter = containers.Map('KeyType', 'char', 'ValueType', 'double');
            fireCounter('n') = 0;
            lh = addlistener(testCase.Range_, 'RangeChanged', ...
                @(~,~) bumpFireCounter_(fireCounter));
            cleanupL = onCleanup(@() delete(lh));

            % Open picker and find the 'Last 30 days' preset button.
            testCase.Bar_.openPicker();
            testCase.addTeardown(@() testCase.closePopup_());
            drawnow;
            popupFigs = findall(groot, 'Type', 'figure', 'Name', 'Time Range');
            testCase.assertNotEmpty(popupFigs, ...
                'testPresetFiresEventAndUpdatesLabel: picker popup must exist');
            popupFig = popupFigs(1);
            allBtns = findall(popupFig, 'Type', 'uibutton');
            preset30Btn = [];
            for i = 1:numel(allBtns)
                if strcmp(allBtns(i).Text, 'Last 30 days')
                    preset30Btn = allBtns(i);
                    break;
                end
            end
            testCase.assertNotEmpty(preset30Btn, ...
                'testPresetFiresEventAndUpdatesLabel: ''Last 30 days'' preset button not found');

            % Invoke the preset button callback.
            cb = preset30Btn.ButtonPushedFcn;
            cb(preset30Btn, struct());
            drawnow;

            % Assert RangeChanged fired.
            testCase.verifyGreaterThanOrEqual(fireCounter('n'), 1, ...
                'testPresetFiresEventAndUpdatesLabel: RangeChanged must have fired');

            % Assert the resolved window is ~30 days.
            [t0, t1] = testCase.Range_.resolve();
            testCase.verifyEqual(t1 - t0, 30, 'AbsTol', 1e-4, ...
                'testPresetFiresEventAndUpdatesLabel: resolved span must be ~30 days');

            % Assert the toolbar button label updated.
            btn = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            testCase.verifyEqual(btn.Text, 'Last 30 days', ...
                'testPresetFiresEventAndUpdatesLabel: button Text must be ''Last 30 days''');

            % Assert popup closed (one-click preset).
            figsAfter = findall(groot, 'Type', 'figure', 'Name', 'Time Range');
            testCase.verifyEqual(numel(figsAfter), 0, ...
                'testPresetFiresEventAndUpdatesLabel: popup must close after preset click');
        end

        function testAllDataPresetSetsAll(testCase)
            %TESTALLDATAPRESETSSETSALL ''All data'' preset sets the all-spec (empty t0/t1).
            testCase.Bar_.openPicker();
            testCase.addTeardown(@() testCase.closePopup_());
            drawnow;
            popupFigs = findall(groot, 'Type', 'figure', 'Name', 'Time Range');
            testCase.assertNotEmpty(popupFigs, ...
                'testAllDataPresetSetsAll: picker popup must exist');
            allBtns = findall(popupFigs(1), 'Type', 'uibutton');
            allDataBtn = [];
            for i = 1:numel(allBtns)
                if strcmp(allBtns(i).Text, 'All data')
                    allDataBtn = allBtns(i);
                    break;
                end
            end
            testCase.assertNotEmpty(allDataBtn, ...
                'testAllDataPresetSetsAll: ''All data'' button not found');
            cb = allDataBtn.ButtonPushedFcn;
            cb(allDataBtn, struct());
            drawnow;
            [t0, t1] = testCase.Range_.resolve();
            testCase.verifyTrue(isempty(t0) && isempty(t1), ...
                'testAllDataPresetSetsAll: resolve() must return empty t0 and t1 for all-data');
            btn = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            testCase.verifyEqual(btn.Text, 'All data', ...
                'testAllDataPresetSetsAll: button Text must be ''All data''');
        end

        function testNonDefaultUsesAccent(testCase)
            %TESTNONDEFAULTUSESACCENT Non-default range uses Accent; default uses WidgetBorderColor.
            btn = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            % After 'Last 30 days', button should be Accent color.
            testCase.Range_.setRelative(30, 'days');
            testCase.Bar_.refreshButton();
            testCase.verifyEqual(btn.BackgroundColor, testCase.Theme_.Accent, 'AbsTol', 1e-3, ...
                'testNonDefaultUsesAccent: non-default range must use Accent BackgroundColor');
            % Reset to default 'Last 7 days'; button should be WidgetBorderColor.
            testCase.Range_.setRelative(7, 'days');
            testCase.Bar_.refreshButton();
            testCase.verifyEqual(btn.BackgroundColor, testCase.Theme_.WidgetBorderColor, 'AbsTol', 1e-3, ...
                'testNonDefaultUsesAccent: default range must use WidgetBorderColor');
        end

        function testThemeSwitchRestylesButton(testCase)
            %TESTTHEMESWITCHRESTYLESBUTTON setTheme() changes button colors without error.
            btn = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            darkFontColor = testCase.Theme_.ForegroundColor;
            lightTheme = CompanionTheme.get('light');
            lightFontColor = lightTheme.ForegroundColor;
            % Ensure the two themes produce different foreground colors (sanity).
            testCase.assumeNotEqual(darkFontColor, lightFontColor, ...
                'testThemeSwitchRestylesButton: dark/light foreground colors must differ');
            % Switch to light theme.
            testCase.verifyWarningFree( ...
                @() testCase.Bar_.setTheme(lightTheme), ...
                'testThemeSwitchRestylesButton: setTheme() must not warn');
            testCase.verifyEqual(btn.FontColor, lightFontColor, 'AbsTol', 1e-3, ...
                'testThemeSwitchRestylesButton: FontColor must match light theme foreground');
        end

    end

    methods (Access = private)

        function tearDownFixtures_(testCase)
            %TEARDOWNFIXTURES_ Close popup, delete bar, delete host figure.
            testCase.closePopup_();
            try
                if ~isempty(testCase.Bar_) && isvalid(testCase.Bar_)
                    delete(testCase.Bar_);
                end
            catch
            end
            try
                if ~isempty(testCase.HostFig_) && isvalid(testCase.HostFig_)
                    delete(testCase.HostFig_);
                end
            catch
            end
            % Belt-and-suspenders: assert no orphan 'Time Range' figure remains.
            figs = findall(groot, 'Type', 'figure', 'Name', 'Time Range');
            for i = 1:numel(figs)
                try; delete(figs(i)); catch; end
            end
        end

        function closePopup_(testCase)
            %CLOSEPOPUP_ Close the picker popup if open.
            try
                if ~isempty(testCase.Bar_) && isvalid(testCase.Bar_)
                    testCase.Bar_.close();
                end
            catch
            end
            drawnow;
            figs = findall(groot, 'Type', 'figure', 'Name', 'Time Range');
            for i = 1:numel(figs)
                try; delete(figs(i)); catch; end
            end
        end

    end

end

function bumpFireCounter_(c)
%BUMPFIRECOUNTER_ Increment the handle-type (containers.Map) event counter.
%   Local function so the RangeChanged listener can mutate a shared counter
%   in place (anonymous functions cannot contain assignment statements).
    c('n') = c('n') + 1;
end
