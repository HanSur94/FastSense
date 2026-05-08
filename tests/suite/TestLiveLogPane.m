classdef TestLiveLogPane < matlab.unittest.TestCase
%TESTLIVELOGPANE Class-based tests for LiveLogPane (Phase 1027.1).
%   Covers attach/detach lifecycle, LiveLogBuffer_ preservation across
%   re-attach, buffer cap, clearLiveLog, theme propagation, and
%   DetachRequested event firing.
%
%   MATLAB-only — Octave skipped (uifigure unavailable).
%
%   See also LiveLogPane, TestEventsLogPane, TestFastSenseCompanion, run_all_tests.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<INUSD>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function skipOnOctave(testCase)
            testCase.assumeFalse( ...
                exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestLiveLogPane: skipped on Octave (uifigure not available)');
        end
    end

    methods (Test)

        function testConstructorRequiresTheme(testCase)
            %TESTCONSTRUCTORREQUIRESTHEME Missing/non-struct theme -> LiveLogPane:invalidTheme.
            testCase.verifyError(@() LiveLogPane(), 'LiveLogPane:invalidTheme');
            testCase.verifyError(@() LiveLogPane(42), 'LiveLogPane:invalidTheme');
        end

        function testConstructDoesNotBuildUI(testCase)
            %TESTCONSTRUCTDOESNOTBUILDUI Construction must NOT attach (deferred to attach()).
            p = LiveLogPane(CompanionTheme.get('dark'));
            testCase.addTeardown(@() delete(p));
            testCase.verifyFalse(p.IsAttached, ...
                'LiveLogPane should be detached after construction');
        end

        function testAttachToUifigure(testCase)
            %TESTATTACHTOUIFIGURE attach(uifigure, theme) sets IsAttached and parents UI.
            [p, hFig] = testCase.makePane_('dark');
            testCase.verifyTrue(p.IsAttached, 'attach should set IsAttached=true');
            testCase.verifyGreaterThanOrEqual(numel(hFig.Children), 1, ...
                'uifigure should contain the attached live log root');
        end

        function testAttachToUipanel(testCase)
            %TESTATTACHTOUIPANEL attach(uipanel, theme) is a valid parent.
            theme = CompanionTheme.get('dark');
            hFig = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(hFig));
            panel = uipanel(hFig);
            p = LiveLogPane(theme);
            testCase.addTeardown(@() delete(p));
            p.attach(panel, theme);
            testCase.verifyTrue(p.IsAttached);
            testCase.verifyGreaterThanOrEqual(numel(panel.Children), 1);
        end

        function testDetachClearsHandles(testCase)
            %TESTDETACHCLEARSHANDLES detach() releases UI; addLiveLogEntry still buffers.
            [p, ~] = testCase.makePane_('dark');
            p.detach();
            testCase.verifyFalse(p.IsAttached);
            % addLiveLogEntry while detached must not error
            p.addLiveLogEntry('tag.x', 1, 1.0);
            testCase.verifyEqual(p.bufferSize(), 1);
        end

        function testDetachPreservesLiveBuffer(testCase)
            %TESTDETACHPRESERVESLIVEBUFFER Re-attach restores full history (attached + detached).
            theme = CompanionTheme.get('dark');
            hFig1 = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(hFig1));
            p = LiveLogPane(theme);
            testCase.addTeardown(@() delete(p));
            p.attach(hFig1, theme);
            p.addLiveLogEntry('tag.a', 1, 1.0);
            p.addLiveLogEntry('tag.b', 1, 2.0);
            p.addLiveLogEntry('tag.c', 1, 3.0);
            p.detach();
            p.addLiveLogEntry('tag.d', 1, 4.0);
            p.addLiveLogEntry('tag.e', 1, 5.0);
            hFig2 = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(hFig2));
            p.attach(hFig2, theme);
            testCase.verifyEqual(p.bufferSize(), 5, ...
                'attach should preserve all 5 live entries (3 attached + 2 detached)');
        end

        function testAddLiveLogEntryWhileDetached(testCase)
            %TESTADDLIVELOGENTRYWHILEDETACHED Buffer fills before any attach call.
            theme = CompanionTheme.get('dark');
            p = LiveLogPane(theme);
            testCase.addTeardown(@() delete(p));
            p.addLiveLogEntry('tag.x', 1, 1.0);
            testCase.verifyEqual(p.bufferSize(), 1);
            hFig = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(hFig));
            p.attach(hFig, theme);
            testCase.verifyEqual(p.bufferSize(), 1, ...
                'buffer should survive attach');
        end

        function testFiveHundredRowCap(testCase)
            %TESTFIVEHUNDREDROWCAP LiveLogBuffer_ caps at 500 rows.
            [p, ~] = testCase.makePane_('dark');
            for i = 1:600
                p.addLiveLogEntry('tag.x', 1, double(i));
            end
            testCase.verifyEqual(p.bufferSize(), 500, ...
                'live buffer should cap at 500');
        end

        function testClearLiveLog(testCase)
            %TESTCLEARLIVELOG clearLiveLog() empties live buffer.
            [p, ~] = testCase.makePane_('dark');
            p.addLiveLogEntry('a', 1, 1.0);
            p.addLiveLogEntry('a', 1, 2.0);
            p.addLiveLogEntry('a', 1, 3.0);
            testCase.verifyEqual(p.bufferSize(), 3);
            p.clearLiveLog();
            testCase.verifyEqual(p.bufferSize(), 0);
        end

        function testApplyThemeDarkToLight(testCase)
            %TESTAPPLYTHEMEDARKTOLIGHT applyTheme(light) updates root background.
            [p, ~] = testCase.makePane_('dark');
            light = CompanionTheme.get('light');
            p.applyTheme(light);
            bg = p.rootBackgroundColor();
            testCase.verifyEqual(bg, light.WidgetBackground, 'AbsTol', 1e-6);
        end

        function testApplyThemeLightToDark(testCase)
            %TESTAPPLYTHEMELIGHTTODARK applyTheme(dark) updates root background.
            [p, ~] = testCase.makePane_('light');
            dark = CompanionTheme.get('dark');
            p.applyTheme(dark);
            bg = p.rootBackgroundColor();
            testCase.verifyEqual(bg, dark.WidgetBackground, 'AbsTol', 1e-6);
        end

        function testApplyThemeNoOpWhenDetached(testCase)
            %TESTAPPLYTHEMENOOPWHENDETACHED applyTheme is silent when not attached.
            p = LiveLogPane(CompanionTheme.get('dark'));
            testCase.addTeardown(@() delete(p));
            % Should not throw
            p.applyTheme(CompanionTheme.get('light'));
            testCase.verifyFalse(p.IsAttached);
        end

        function testDetachRequestedEventFires(testCase)
            %TESTDETACHREQUESTEDEVENTFIRES requestDetach() fires DetachRequested once per call.
            [p, ~] = testCase.makePane_('dark');
            bag = containers.Map('KeyType','char','ValueType','double');
            bag('hits') = 0;
            lh = addlistener(p, 'DetachRequested', @(~,~) bumpBag(bag));
            testCase.addTeardown(@() delete(lh));
            p.requestDetach();
            p.requestDetach();
            testCase.verifyEqual(bag('hits'), 2, ...
                'DetachRequested should fire once per requestDetach() call');
        end

    end

    methods (Access = private)
        function [p, hFig] = makePane_(testCase, themeName)
        %MAKEPANE_ Helper: build a hidden uifigure and an attached LiveLogPane.
            if nargin < 2; themeName = 'dark'; end
            theme = CompanionTheme.get(themeName);
            hFig = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(hFig));
            p = LiveLogPane(theme);
            testCase.addTeardown(@() delete(p));
            p.attach(hFig, theme);
        end
    end
end

% ---------------------------------------------------------------------------
function bumpBag(b)
%BUMPBAG Top-level helper: increment 'hits' counter in the given containers.Map.
%   Used by testDetachRequestedEventFires because closures over local vars in
%   classdef Test methods cannot mutate the captured variable; a handle-typed
%   bag (containers.Map) sidesteps that restriction.
    b('hits') = b('hits') + 1;
end
