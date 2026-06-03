classdef TestCompanionTimeBar < matlab.unittest.TestCase
%TESTCOMPANIONTIMEBAR MATLAB-only UI smoke suite for CompanionTimeBar.
%
%   Tests the inline toolbar dropdown + Custom editor strip (the redesign that
%   replaced the separate-window popup):
%     - Range dropdown exists in toolbar col 9 with Tag 'CompanionTimeRangeBtn'
%     - Items are the six presets plus a trailing 'Custom…' item
%     - Default Value is 'Last 7 days'
%     - Selecting a preset fires RangeChanged + updates the dropdown Value
%     - 'All data' preset sets the all-spec (empty t0/t1)
%     - Selecting 'Custom…' (or openPicker()) reveals an IN-WINDOW overlay strip
%       (Tag 'CompanionTimeRangeStrip') — NO separate figure is ever created
%     - The Custom strip exposes date pickers (Absolute) + a relative builder
%     - Apply on the Absolute tab commits an absolute range; Apply on Relative
%       commits a relative range; Cancel leaves the range unchanged
%     - Non-default range uses Accent BackgroundColor; default uses WidgetBorderColor
%     - setTheme() restyles the dropdown without error
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
            %   The 1320x800 figure matches the companion's default geometry so the
            %   strip's pixel positioning lands on-figure. The app handle is passed
            %   as [] (as in production the strip derives its host figure from the
            %   dropdown's ancestor, so no real FastSenseCompanion is required).
            testCase.HostFig_     = uifigure('Visible', 'off', 'Position', [100 100 1320 800]);
            testCase.ToolbarGrid_ = uigridlayout(testCase.HostFig_, [1 10]);
            testCase.ToolbarGrid_.ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, '1x', 36};
            testCase.ToolbarGrid_.RowHeight   = {'1x'};
            testCase.Range_  = CompanionTimeRange();
            testCase.Theme_  = CompanionTheme.get('dark');
            testCase.Bar_ = CompanionTimeBar( ...
                testCase.ToolbarGrid_, 9, testCase.Range_, testCase.Theme_, []);
            testCase.addTeardown(@() testCase.tearDownFixtures_());
        end
    end

    methods (Test)

        function testRangeControlExists(testCase)
            %TESTRANGECONTROLEXISTS Range dropdown with Tag 'CompanionTimeRangeBtn' sits in col 9.
            dd = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            testCase.verifyEqual(numel(dd), 1, ...
                'testRangeControlExists: expected exactly one CompanionTimeRangeBtn');
            testCase.verifyClass(dd, 'matlab.ui.control.DropDown', ...
                'testRangeControlExists: the range control must be a uidropdown');
            testCase.verifyEqual(dd.Layout.Column, 9, ...
                'testRangeControlExists: control must sit in column 9');
        end

        function testDropdownItemsAndDefault(testCase)
            %TESTDROPDOWNITEMSANDDEFAULT Items = 6 presets + 'Custom…'; default Value 'Last 7 days'.
            dd = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            expectedPresets = {'Last 24 hours', 'Last 7 days', 'Last 30 days', ...
                               'Last 90 days', 'Last 1 year', 'All data'};
            for i = 1:numel(expectedPresets)
                testCase.verifyTrue(any(strcmp(dd.Items, expectedPresets{i})), ...
                    sprintf('testDropdownItemsAndDefault: missing preset ''%s''', expectedPresets{i}));
            end
            testCase.verifyTrue(any(strcmp(dd.Items, testCase.customLabel_())), ...
                'testDropdownItemsAndDefault: dropdown must include a ''Custom…'' item');
            testCase.verifyEqual(dd.Value, 'Last 7 days', ...
                'testDropdownItemsAndDefault: default Value must be ''Last 7 days''');
        end

        function testCustomItemOpensInlineStripNoWindow(testCase)
            %TESTCUSTOMITEMOPENSINLINESTRIPNOWINDOW Selecting 'Custom…' reveals an in-window strip; no figure spawns.
            nBefore = numel(findall(groot, 'Type', 'figure'));
            testCase.selectDropdown_(testCase.customLabel_());
            drawnow;
            nAfter = numel(findall(groot, 'Type', 'figure'));

            % No separate window — figure count unchanged and no 'Time Range' figure.
            testCase.verifyEqual(nAfter, nBefore, ...
                'testCustomItemOpensInlineStripNoWindow: selecting Custom… must NOT create a new figure');
            testCase.verifyEmpty(findall(groot, 'Type', 'figure', 'Name', 'Time Range'), ...
                'testCustomItemOpensInlineStripNoWindow: no separate ''Time Range'' window may exist');

            % Strip exists as an in-window overlay panel parented to the host figure.
            strip = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeStrip');
            testCase.verifyEqual(numel(strip), 1, ...
                'testCustomItemOpensInlineStripNoWindow: exactly one in-window Custom strip expected');
        end

        function testCustomStripHasDatePickers(testCase)
            %TESTCUSTOMSTRIPHASDATEPICKERS Custom strip exposes date pickers + relative builder + actions.
            testCase.Bar_.openPicker();
            drawnow;
            testCase.verifyEqual(numel(findall(testCase.HostFig_, 'Type', 'uidatepicker')), 2, ...
                'testCustomStripHasDatePickers: Absolute mode must provide two date pickers');
            testCase.verifyEqual(numel(findall(testCase.HostFig_, 'Type', 'uispinner')), 1, ...
                'testCustomStripHasDatePickers: Relative mode must provide one spinner');
            testCase.verifyNotEmpty(testCase.findStripButton_('Apply'), ...
                'testCustomStripHasDatePickers: an Apply button must exist');
            testCase.verifyNotEmpty(testCase.findStripButton_('Cancel'), ...
                'testCustomStripHasDatePickers: a Cancel button must exist');
            testCase.verifyNotEmpty(testCase.findStripButton_('Relative'), ...
                'testCustomStripHasDatePickers: a Relative tab must exist');
            testCase.verifyNotEmpty(testCase.findStripButton_('Absolute'), ...
                'testCustomStripHasDatePickers: an Absolute tab must exist');
        end

        function testCustomStripSingleton(testCase)
            %TESTCUSTOMSTRIPSINGLETON openPicker() twice leaves exactly one strip.
            testCase.Bar_.openPicker();
            drawnow;
            testCase.Bar_.openPicker();
            drawnow;
            testCase.verifyEqual(numel(findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeStrip')), 1, ...
                'testCustomStripSingleton: second openPicker() must NOT spawn a second strip');
        end

        function testPresetFiresEventAndUpdatesValue(testCase)
            %TESTPRESETFIRESEVENTSANDUPDATESVALUE 'Last 30 days' preset fires RangeChanged and updates the dropdown.
            % Handle-type counter: an anonymous listener cannot assign into the
            % test workspace, so mutate a shared containers.Map in place.
            fireCounter = containers.Map('KeyType', 'char', 'ValueType', 'double');
            fireCounter('n') = 0;
            lh = addlistener(testCase.Range_, 'RangeChanged', ...
                @(~,~) bumpFireCounter_(fireCounter));
            cleanupL = onCleanup(@() delete(lh)); %#ok<NASGU>

            testCase.selectDropdown_('Last 30 days');
            drawnow;

            testCase.verifyGreaterThanOrEqual(fireCounter('n'), 1, ...
                'testPresetFiresEventAndUpdatesValue: RangeChanged must have fired');

            [t0, t1] = testCase.Range_.resolve();
            testCase.verifyEqual(t1 - t0, 30, 'AbsTol', 1e-4, ...
                'testPresetFiresEventAndUpdatesValue: resolved span must be ~30 days');

            dd = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            testCase.verifyEqual(dd.Value, 'Last 30 days', ...
                'testPresetFiresEventAndUpdatesValue: dropdown Value must be ''Last 30 days''');
        end

        function testAllDataPresetSetsAll(testCase)
            %TESTALLDATAPRESETSSETSALL 'All data' preset sets the all-spec (empty t0/t1).
            testCase.selectDropdown_('All data');
            drawnow;
            [t0, t1] = testCase.Range_.resolve();
            testCase.verifyTrue(isempty(t0) && isempty(t1), ...
                'testAllDataPresetSetsAll: resolve() must return empty t0 and t1 for all-data');
            dd = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            testCase.verifyEqual(dd.Value, 'All data', ...
                'testAllDataPresetSetsAll: dropdown Value must be ''All data''');
        end

        function testAbsoluteCommitSetsRange(testCase)
            %TESTABSOLUTECOMMITSETSRANGE Apply on the Absolute tab commits an absolute range + closes the strip.
            testCase.Bar_.openPicker();   % opens on the Absolute tab by default
            drawnow;
            applyBtn = testCase.findStripButton_('Apply');
            testCase.assertNotEmpty(applyBtn, ...
                'testAbsoluteCommitSetsRange: Apply button must exist');
            testCase.invokeButton_(applyBtn);
            drawnow;

            s = testCase.Range_.toStruct();
            testCase.verifyEqual(s.type, 'absolute', ...
                'testAbsoluteCommitSetsRange: committing Absolute must set an absolute spec');
            testCase.verifyEmpty(findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeStrip'), ...
                'testAbsoluteCommitSetsRange: the strip must close after Apply');

            dd = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            testCase.verifyEqual(dd.Value, testCase.Range_.label(), ...
                'testAbsoluteCommitSetsRange: dropdown Value must show the committed date-range label');
            testCase.verifyEqual(dd.BackgroundColor, testCase.Theme_.Accent, 'AbsTol', 1e-3, ...
                'testAbsoluteCommitSetsRange: a non-default range must use the Accent background');
        end

        function testRelativeCommitSetsRange(testCase)
            %TESTRELATIVECOMMITSETSRANGE Apply on the Relative tab commits a relative range.
            testCase.Bar_.openPicker();
            drawnow;
            sp = findall(testCase.HostFig_, 'Type', 'uispinner');
            testCase.assertNotEmpty(sp, 'testRelativeCommitSetsRange: spinner must exist');
            sp(1).Value = 14;
            testCase.invokeButton_(testCase.findStripButton_('Relative'));   % switch to Relative tab
            drawnow;
            testCase.invokeButton_(testCase.findStripButton_('Apply'));
            drawnow;

            s = testCase.Range_.toStruct();
            testCase.verifyEqual(s.type, 'relative', ...
                'testRelativeCommitSetsRange: committing Relative must set a relative spec');
            testCase.verifyEqual(s.N, 14, ...
                'testRelativeCommitSetsRange: spinner value (14) must be committed as N');
            dd = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            testCase.verifyEqual(dd.Value, 'Last 14 days', ...
                'testRelativeCommitSetsRange: dropdown Value must read ''Last 14 days''');
        end

        function testCancelLeavesRangeUnchanged(testCase)
            %TESTCANCELLEAVESRANGEUNCHANGED Cancel closes the strip without changing the range.
            before = testCase.Range_.toStruct();
            testCase.Bar_.openPicker();
            drawnow;
            testCase.invokeButton_(testCase.findStripButton_('Cancel'));
            drawnow;
            after = testCase.Range_.toStruct();
            testCase.verifyEqual(after.type, before.type, ...
                'testCancelLeavesRangeUnchanged: Cancel must not change the spec type');
            testCase.verifyEqual(after.N, before.N, ...
                'testCancelLeavesRangeUnchanged: Cancel must not change N');
            testCase.verifyEmpty(findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeStrip'), ...
                'testCancelLeavesRangeUnchanged: the strip must close on Cancel');
        end

        function testNonDefaultUsesAccent(testCase)
            %TESTNONDEFAULTUSESACCENT Non-default range uses Accent; default uses WidgetBorderColor.
            dd = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            testCase.Range_.setRelative(30, 'days');
            testCase.Bar_.refreshButton();
            testCase.verifyEqual(dd.BackgroundColor, testCase.Theme_.Accent, 'AbsTol', 1e-3, ...
                'testNonDefaultUsesAccent: non-default range must use Accent BackgroundColor');
            testCase.Range_.setRelative(7, 'days');
            testCase.Bar_.refreshButton();
            testCase.verifyEqual(dd.BackgroundColor, testCase.Theme_.WidgetBorderColor, 'AbsTol', 1e-3, ...
                'testNonDefaultUsesAccent: default range must use WidgetBorderColor');
        end

        function testThemeSwitchRestylesControl(testCase)
            %TESTTHEMESWITCHRESTYLESCONTROL setTheme() changes the dropdown FontColor without warning.
            dd = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            darkFontColor  = testCase.Theme_.ForegroundColor;
            lightTheme     = CompanionTheme.get('light');
            lightFontColor = lightTheme.ForegroundColor;
            testCase.assumeNotEqual(darkFontColor, lightFontColor, ...
                'testThemeSwitchRestylesControl: dark/light foreground colors must differ');
            testCase.verifyWarningFree( ...
                @() testCase.Bar_.setTheme(lightTheme), ...
                'testThemeSwitchRestylesControl: setTheme() must not warn');
            testCase.verifyEqual(dd.FontColor, lightFontColor, 'AbsTol', 1e-3, ...
                'testThemeSwitchRestylesControl: FontColor must match light theme foreground');
        end

    end

    methods (Access = private)

        function s = customLabel_(~)
            %CUSTOMLABEL_ The dropdown item label that opens the Custom editor strip.
            s = ['Custom', char(8230)];   % 'Custom…'
        end

        function selectDropdown_(testCase, val)
            %SELECTDROPDOWN_ Drive the dropdown ValueChangedFcn as a user selection would.
            dd = findall(testCase.HostFig_, 'Tag', 'CompanionTimeRangeBtn');
            dd.Value = val;
            cb = dd.ValueChangedFcn;
            cb(dd, []);
        end

        function btn = findStripButton_(testCase, txt)
            %FINDSTRIPBUTTON_ Find a uibutton in the Custom strip by its Text.
            btn = [];
            all = findall(testCase.HostFig_, 'Type', 'uibutton');
            for i = 1:numel(all)
                if strcmp(all(i).Text, txt)
                    btn = all(i);
                    return;
                end
            end
        end

        function invokeButton_(~, btn)
            %INVOKEBUTTON_ Fire a uibutton's ButtonPushedFcn callback.
            f = btn.ButtonPushedFcn;
            f(btn, struct());
        end

        function tearDownFixtures_(testCase)
            %TEARDOWNFIXTURES_ Close strip, delete bar, delete host figure.
            try
                if ~isempty(testCase.Bar_) && isvalid(testCase.Bar_)
                    testCase.Bar_.close();
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
            % Belt-and-suspenders: assert the redesign never spawns a separate window.
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
