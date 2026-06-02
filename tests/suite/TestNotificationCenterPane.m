classdef TestNotificationCenterPane < matlab.unittest.TestCase
%TESTNOTIFICATIONCENTERPANE Class-based tests for the Companion notification inbox (Phase 1040).
%   Covers attach/detach lifecycle, detach/reattach state preservation, the
%   unacked refresh + diff-by-Id, ack -> removal, ack-race no-op, the stale
%   read-error guard, severity filtering, the empty state, applyTheme, and the
%   DetachRequested event — all headless via uifigure('Visible','off').
%
%   MATLAB-only — Octave skipped (uifigure unavailable). Event fixtures use the
%   real 6-arg Event constructor (the planning docs' 4-arg form does not
%   construct — direction is required).
%
%   See also NotificationCenterPane, StubEventStore, TestEventsLogPane, run_all_tests.

    methods (TestClassSetup)
        function addPaths(~)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function skipOnOctave(testCase)
            testCase.assumeFalse( ...
                exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestNotificationCenterPane: skipped on Octave (uifigure not available)');
        end
    end

    methods (Test)

        function testConstructDetached(testCase)
            %TESTCONSTRUCTDETACHED Construction must NOT attach.
            p = NotificationCenterPane(CompanionTheme.get('dark'));
            testCase.addTeardown(@() delete(p));
            testCase.verifyFalse(p.IsAttached, 'pane should be detached after construction');
        end

        function testAttachBuildsTable(testCase)
            %TESTATTACHBUILDSTABLE attach builds the inbox uitable + sets IsAttached.
            [p, hFig] = testCase.makePane_('dark');
            testCase.verifyTrue(p.IsAttached, 'attach should set IsAttached=true');
            testCase.verifyNotEmpty(findall(hFig, 'Type', 'uitable'), ...
                'attach should build a uitable');
        end

        function testDetachReattachPreservesState(testCase)
            %TESTDETACHREATTACHPRESERVESSTATE Last-good list + render survive detach/reattach.
            theme = CompanionTheme.get('dark');
            f1 = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(f1));
            p = NotificationCenterPane(theme);
            testCase.addTeardown(@() delete(p));
            p.attach(f1, theme);
            stub = testCase.makeStub_();
            p.refresh(stub);
            testCase.verifyEqual(p.lastGoodCount_(), 2, 'refresh should keep 2 unacked');
            p.detach();
            testCase.verifyFalse(p.IsAttached);
            testCase.verifyEqual(p.lastGoodCount_(), 2, 'last-good list must survive detach');
            f2 = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(f2));
            p.attach(f2, theme);
            testCase.verifyEqual(p.numVisibleRows_(), 2, 'reattach should repaint the 2 rows');
        end

        function testRefreshFiltersUnacked(testCase)
            %TESTREFRESHFILTERSUNACKED refresh keeps only unacked, newest-first.
            [p, ~] = testCase.makePane_('dark');
            stub = testCase.makeStub_();   % evt_3 is acked
            p.refresh(stub);
            testCase.verifyEqual(p.lastGoodCount_(), 2);
            ids = p.lastIdsSnapshot_();
            testCase.verifyEqual(ids{1}, 'evt_1', 'newest (Start=30) should sort first');
        end

        function testDiffNoFlicker(testCase)
            %TESTDIFFNOFLICKER Identical successive refresh leaves LastIds_ unchanged.
            [p, ~] = testCase.makePane_('dark');
            stub = testCase.makeStub_();
            p.refresh(stub);
            ids1 = p.lastIdsSnapshot_();
            p.refresh(stub);   % identical event set
            ids2 = p.lastIdsSnapshot_();
            testCase.verifyEqual(ids2, ids1, 'no-diff refresh should not change the id set');
        end

        function testAckRemovesOnNextRefresh(testCase)
            %TESTACKREMOVESONNEXTREFRESH Acking an event drops it from the inbox next refresh.
            [p, ~] = testCase.makePane_('dark');
            stub = testCase.makeStub_();
            p.setCompanion(stub);   % stub doubles as the Companion's store resolver
            p.refresh(stub);
            testCase.verifyEqual(p.lastGoodCount_(), 2);
            p.ackForTest_('evt_2');
            p.refresh(stub);
            testCase.verifyEqual(p.lastGoodCount_(), 1, 'acked event should leave the inbox');
            ids = p.lastIdsSnapshot_();
            testCase.verifyFalse(any(strcmp(ids, 'evt_2')), 'evt_2 should be gone');
        end

        function testAckRaceIsNoOp(testCase)
            %TESTACKRACEISNOOP An already-acked event (unknownEventId) is a silent no-op.
            [p, ~] = testCase.makePane_('dark');
            stub = testCase.makeStub_();
            stub.ThrowOnAck_ = true;
            p.setCompanion(stub);
            p.refresh(stub);
            testCase.verifyEqual(p.lastGoodCount_(), 2);
            % Must NOT throw — onAckBtn_ swallows EventStore:unknownEventId.
            p.ackForTest_('evt_2');
            testCase.verifyEqual(p.lastGoodCount_(), 2, 'inbox unchanged after race no-op');
        end

        function testStaleOnReadError(testCase)
            %TESTSTALEONREADERROR getEvents failure keeps last-good + shows a (stale) marker.
            [p, ~] = testCase.makePane_('dark');
            stub = testCase.makeStub_();
            p.refresh(stub);
            testCase.verifyEqual(p.lastGoodCount_(), 2);
            stub.ThrowOnGet_ = true;
            p.refresh(stub);
            testCase.verifyEqual(p.lastGoodCount_(), 2, 'last-good list preserved on read error');
            testCase.verifyTrue(contains(p.lastUpdatedText_(), '(stale)'), ...
                'Updated label should show the (stale) marker');
        end

        function testSeverityFilter(testCase)
            %TESTSEVERITYFILTER Severity dropdown narrows the visible rows client-side.
            [p, ~] = testCase.makePane_('dark');
            stub = testCase.makeStub_();   % unacked: evt_1 (sev3), evt_2 (sev2)
            p.refresh(stub);
            testCase.verifyEqual(p.numVisibleRows_(), 2);
            p.setSeverityFilterForTest_('Alarm');
            testCase.verifyEqual(p.numVisibleRows_(), 1, 'only the sev-3 event should remain');
        end

        function testEmptyState(testCase)
            %TESTEMPTYSTATE Clearing all events renders the locked empty-state row.
            [p, ~] = testCase.makePane_('dark');
            stub = testCase.makeStub_();
            p.refresh(stub);
            testCase.verifyEqual(p.numVisibleRows_(), 2);
            stub.Events_ = Event.empty;
            p.refresh(stub);
            testCase.verifyEqual(p.numVisibleRows_(), 0);
            d = p.tableDataForTest_();
            testCase.verifyEqual(d, {'', '', 'No unacknowledged events', '', '', '', '', ''}, ...
                'empty state copy must match the locked string');
        end

        function testApplyThemeReassertsOverrides(testCase)
            %TESTAPPLYTHEMEREASSERTSOVERRIDES applyTheme(light) runs cleanly while attached.
            [p, ~] = testCase.makePane_('dark');
            p.applyTheme(CompanionTheme.get('light'));
            testCase.verifyTrue(p.IsAttached, 'pane should stay attached after applyTheme');
        end

        function testDetachRequestedFires(testCase)
            %TESTDETACHREQUESTEDFIRES requestDetach() fires DetachRequested.
            [p, ~] = testCase.makePane_('dark');
            bag = containers.Map('KeyType', 'char', 'ValueType', 'double');
            bag('hits') = 0;
            lh = addlistener(p, 'DetachRequested', @(~,~) bumpBag(bag));
            testCase.addTeardown(@() delete(lh));
            p.requestDetach();
            testCase.verifyEqual(bag('hits'), 1, 'DetachRequested should fire once per requestDetach');
        end

    end

    methods (Access = private)
        function [p, hFig] = makePane_(testCase, themeName)
        %MAKEPANE_ Build a hidden uifigure + attached NotificationCenterPane.
            if nargin < 2; themeName = 'dark'; end
            theme = CompanionTheme.get(themeName);
            hFig = uifigure('Visible', 'off');
            testCase.addTeardown(@() delete(hFig));
            p = NotificationCenterPane(theme);
            testCase.addTeardown(@() delete(p));
            p.attach(hFig, theme);
        end

        function evs = makeEvents_(~)
        %MAKEEVENTS_ Fixed Event array: evt_1 (sev3, t=30, open), evt_2 (sev2, t=20), evt_3 (sev1, acked).
            e1 = Event(30, NaN, 'P-101', 'HighPressure', 100, 'upper');
            e1.Id = 'evt_1'; e1.Severity = 3; e1.IsOpen = true;
            e2 = Event(20, NaN, 'T-200', 'Overtemp', 80, 'upper');
            e2.Id = 'evt_2'; e2.Severity = 2;
            e3 = Event(10, 15, 'F-300', 'LowFlow', 5, 'lower');
            % Non-empty numeric datenum marks evt_3 acked; literal keeps the fixture deterministic.
            e3.Id = 'evt_3'; e3.Severity = 1; e3.AckedAt = 737000;
            evs = [e1 e2 e3];
        end

        function s = makeStub_(testCase)
        %MAKESTUB_ A StubEventStore preloaded with makeEvents_ (2 unacked + 1 acked).
            s = StubEventStore;
            s.Events_ = testCase.makeEvents_();
        end
    end
end

% ---------------------------------------------------------------------------
function bumpBag(b)
%BUMPBAG Increment 'hits' in the given containers.Map (closures can't mutate locals).
    b('hits') = b('hits') + 1;
end
