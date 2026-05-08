classdef TestEventsLogPane < matlab.unittest.TestCase
%TESTEVENTSLOGPANE Class-based tests for EventsLogPane (Phase 1027.1).
%   Covers attach/detach lifecycle, LogBuffer_ preservation across re-attach,
%   buffer cap, theme propagation, and DetachRequested event firing.
%
%   MATLAB-only — Octave skipped (uifigure unavailable).
%
%   See also EventsLogPane, TestLiveLogPane, TestFastSenseCompanion, run_all_tests.

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
                'TestEventsLogPane: skipped on Octave (uifigure not available)');
        end
    end

    methods (Test)

        function testConstructorRequiresTheme(testCase)
            %TESTCONSTRUCTORREQUIRESTHEME Missing/non-struct theme -> EventsLogPane:invalidTheme.
            testCase.verifyError(@() EventsLogPane(), 'EventsLogPane:invalidTheme');
            testCase.verifyError(@() EventsLogPane(42), 'EventsLogPane:invalidTheme');
        end

        function testConstructDoesNotBuildUI(testCase)
            %TESTCONSTRUCTDOESNOTBUILDUI Construction must NOT attach (deferred to attach()).
            p = EventsLogPane(CompanionTheme.get('dark'));
            testCase.addTeardown(@() delete(p));
            testCase.verifyFalse(p.IsAttached, ...
                'EventsLogPane should be detached after construction');
        end

        function testAttachToUifigure(testCase)
            %TESTATTACHTOUIFIGURE attach(uifigure, theme) sets IsAttached and parents UI.
            [p, hFig] = testCase.makePane_('dark');
            testCase.verifyTrue(p.IsAttached, 'attach should set IsAttached=true');
            testCase.verifyGreaterThanOrEqual(numel(hFig.Children), 1, ...
                'uifigure should contain the attached log root');
        end

        function testAttachToUipanel(testCase)
            %TESTATTACHTOUIPANEL attach(uipanel, theme) is a valid parent.
            theme = CompanionTheme.get('dark');
            hFig = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(hFig));
            panel = uipanel(hFig);
            p = EventsLogPane(theme);
            testCase.addTeardown(@() delete(p));
            p.attach(panel, theme);
            testCase.verifyTrue(p.IsAttached);
            testCase.verifyGreaterThanOrEqual(numel(panel.Children), 1);
        end

        function testDetachClearsHandles(testCase)
            %TESTDETACHCLEARSHANDLES detach() releases UI; addLogEntry still buffers.
            [p, ~] = testCase.makePane_('dark');
            p.detach();
            testCase.verifyFalse(p.IsAttached);
            % addLogEntry while detached must not error
            p.addLogEntry('info', 'after detach');
            testCase.verifyEqual(p.bufferSize(), 1);
        end

        function testDetachPreservesBuffers(testCase)
            %TESTDETACHPRESERVESBUFFERS Re-attach restores full history (attached + detached).
            theme = CompanionTheme.get('dark');
            hFig1 = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(hFig1));
            p = EventsLogPane(theme);
            testCase.addTeardown(@() delete(p));
            p.attach(hFig1, theme);
            p.addLogEntry('info', 'a');
            p.addLogEntry('info', 'b');
            p.addLogEntry('info', 'c');
            p.detach();
            p.addLogEntry('info', 'd');
            p.addLogEntry('info', 'e');
            hFig2 = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(hFig2));
            p.attach(hFig2, theme);
            testCase.verifyEqual(p.bufferSize(), 5, ...
                'attach should preserve all 5 entries (3 attached + 2 detached)');
        end

        function testAddLogEntryWhileDetached(testCase)
            %TESTADDLOGENTRYWHILEDETACHED Buffer fills before any attach call.
            theme = CompanionTheme.get('dark');
            p = EventsLogPane(theme);
            testCase.addTeardown(@() delete(p));
            p.addLogEntry('info', 'before attach');
            testCase.verifyEqual(p.bufferSize(), 1);
            hFig = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(hFig));
            p.attach(hFig, theme);
            testCase.verifyEqual(p.bufferSize(), 1, ...
                'buffer should survive attach');
        end

        function testFiveHundredRowCap(testCase)
            %TESTFIVEHUNDREDROWCAP LogBuffer_ caps at 500 rows.
            [p, ~] = testCase.makePane_('dark');
            for i = 1:600
                p.addLogEntry('info', sprintf('line %d', i));
            end
            testCase.verifyEqual(p.bufferSize(), 500, ...
                'log buffer should cap at 500');
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
            p = EventsLogPane(CompanionTheme.get('dark'));
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

        function testLogBufferOrdering(testCase)
            %TESTLOGBUFFERORDERING Newest entry first; level uppercased.
            [p, ~] = testCase.makePane_('dark');
            p.addLogEntry('info', 'first');
            p.addLogEntry('warn', 'second');
            testCase.verifyEqual(p.bufferSize(), 2);
            row1 = p.peekLogRow(1);  % newest first
            testCase.verifyEqual(row1{3}, 'second', ...
                'newest entry should be at index 1');
            testCase.verifyEqual(row1{2}, 'WARN', ...
                'level should be uppercased');
        end

        function testSetLastUpdatedNoOpWhenDetached(testCase)
            %TESTSETLASTUPDATEDNOOPWHENDETACHED setLastUpdated tolerates detached pane.
            p = EventsLogPane(CompanionTheme.get('dark'));
            testCase.addTeardown(@() delete(p));
            % Should not throw on detached pane
            p.setLastUpdated(datetime('now'));
            p.setLastUpdated('12:34:56');
            testCase.verifyFalse(p.IsAttached);
        end

    end

    methods (Access = private)
        function [p, hFig] = makePane_(testCase, themeName)
        %MAKEPANE_ Helper: build a hidden uifigure and an attached EventsLogPane.
            if nargin < 2; themeName = 'dark'; end
            theme = CompanionTheme.get(themeName);
            hFig = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(hFig));
            p = EventsLogPane(theme);
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
