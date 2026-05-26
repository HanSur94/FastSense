classdef TestTagStatusTableWindow < matlab.unittest.TestCase
%TESTTAGSTATUSTABLEWINDOW Class-based UI lifecycle tests for TagStatusTableWindow.
%   Covers quick-task 260519-bs4 BS4-01..03:
%     - opening the window from a real FastSenseCompanion
%     - singleton semantics (twice -> same handle)
%     - in-place markTagsDirty after scanLiveTagUpdates_
%     - lifecycle: window-close -> companion drops reference
%     - lifecycle: companion close() / setProject() tears the window down
%     - toolbar Tag button presence (Tag = 'CompanionTagStatusBtn')
%
%   See also TagStatusTableWindow, FastSenseCompanion, run_all_tests.

    methods (TestClassSetup)
        function gateModernMatlab(testCase)
            if exist('OCTAVE_VERSION', 'builtin'); return; end
            testCase.assumeTrue(~verLessThan('matlab', '9.10'), ...
                'TagStatusTableWindow suite requires MATLAB R2021a+ uifigure features');
        end

        function gateHeadlessLinux(testCase)
            %GATEHEADLESSLINUX Skip on Linux CI runners -- uifigure
            %   construction + interaction is unreliable without a real
            %   X server. macOS / Windows CI cover this suite.
            if exist('OCTAVE_VERSION', 'builtin'); return; end
            isHeadlessLinux = ~ispc && ~ismac && ~usejava('desktop');
            testCase.assumeFalse(isHeadlessLinux, ...
                'TestTagStatusTableWindow uifigure paths fail on headless Linux -- covered on macOS/Windows CI');
        end

        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function skipOnOctave(testCase)
            % FastSenseCompanion is MATLAB-only. Skip entire suite on Octave.
            testCase.assumeFalse( ...
                exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestTagStatusTableWindow: skipped on Octave (uifigure not available)');
        end

        function resetRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)

        function testOpenFromCompanion(testCase)
            %TESTOPENFROMCOMPANION openTagStatusTable returns a valid window with 2 rows.
            registerTwoSensors_();
            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            testCase.addTeardown(@() TagRegistry.clear());

            w = app.openTagStatusTable();

            testCase.verifyClass(w, 'TagStatusTableWindow', ...
                'testOpenFromCompanion: openTagStatusTable must return a TagStatusTableWindow');
            testCase.verifyTrue(isvalid(w), ...
                'testOpenFromCompanion: returned window must be valid');
            testCase.verifyTrue(w.IsOpen, ...
                'testOpenFromCompanion: window IsOpen must be true');
            testCase.verifyEqual(w.bufferSize(), 2, ...
                'testOpenFromCompanion: 2 SensorTags registered -> buffer size 2');
        end

        function testTwiceReturnsSameWindow(testCase)
            %TESTTWICERETURNSSAMEWINDOW Two openTagStatusTable calls return the SAME handle.
            registerTwoSensors_();
            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            testCase.addTeardown(@() TagRegistry.clear());

            w1 = app.openTagStatusTable();
            w2 = app.openTagStatusTable();

            testCase.verifyTrue(w1 == w2, ...
                'testTwiceReturnsSameWindow: second call must return the same singleton handle');

            % Verify there is only ONE Tag-Status figure registered with root.
            figs = findall(groot, 'Type', 'figure', '-and', 'Name', ...
                'Tag Status -- FastSense Companion');
            testCase.verifyEqual(numel(figs), 1, ...
                'testTwiceReturnsSameWindow: only one Tag Status figure should exist');
        end

        function testMarkTagsDirty_updatesRow(testCase)
            %TESTMARKTAGSDIRTY_UPDATESROW scanLiveTagUpdates_ pushes new sample counts.
            tA = SensorTag('tag_a', 'Name', 'TagA');
            tA.updateData([1 2 3], [10 20 30]);
            tB = SensorTag('tag_b', 'Name', 'TagB');
            tB.updateData([1 2], [100 200]);
            TagRegistry.register('tag_a', tA);
            TagRegistry.register('tag_b', tB);

            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            testCase.addTeardown(@() TagRegistry.clear());

            w = app.openTagStatusTable();
            % Seed the LiveSampleCount_ via an initial scan so we see the
            % delta on the next call (first scan only baselines the counts).
            app.scanLiveTagUpdatesForTest_();
            % Grow tag_a's sample count.
            tA.updateData([1 2 3 4 5], [10 20 30 40 55]);

            app.scanLiveTagUpdatesForTest_();

            % Find tag_a row in the buffer; samples column (now index 11
            % after Events column was inserted at 10 in 260519-bs4-06) should
            % read '5' and latest (index 6) should reflect 55. The Events
            % column at index 10 must be '0' since no EventStore is bound.
            rowA = findRowByKey_(w, 'tag_a');
            testCase.verifyNotEmpty(rowA, ...
                'testMarkTagsDirty_updatesRow: tag_a row must exist in buffer');
            testCase.verifyEqual(rowA{11}, '5', ...
                'testMarkTagsDirty_updatesRow: Samples must reflect new count after tick');
            testCase.verifyEqual(rowA{10}, '0', ...
                'testMarkTagsDirty_updatesRow: Events count is 0 with no EventStore');
            testCase.verifyTrue(any(strcmp(rowA{6}, {'55.00', '55', '55.000'})), ...
                sprintf(['testMarkTagsDirty_updatesRow: Latest must reflect new ' ...
                    'value 55, got ''%s'''], rowA{6}));
        end

        function testClose_deregisters(testCase)
            %TESTCLOSE_DEREGISTERS Window close clears companion ref; further ticks do not throw.
            registerTwoSensors_();
            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            testCase.addTeardown(@() TagRegistry.clear());

            w = app.openTagStatusTable();
            testCase.verifyTrue(isvalid(w), 'precondition: window valid');
            w.close();

            testCase.verifyEmpty(app.tagStatusTableWindowForTest_(), ...
                'testClose_deregisters: companion TagStatusTableWindow_ must be empty after close');
            % A subsequent live tick must not throw.
            app.scanLiveTagUpdatesForTest_();
        end

        function testCompanionCloseTearsDown(testCase)
            %TESTCOMPANIONCLOSETEARSDOWN Closing the companion closes any open Tag Status window.
            registerTwoSensors_();
            app = FastSenseCompanion();
            % Open window, then close the companion.
            w = app.openTagStatusTable(); %#ok<NASGU>
            app.close();
            testCase.addTeardown(@() TagRegistry.clear());

            figs = findall(groot, 'Type', 'figure', '-and', 'Name', ...
                'Tag Status -- FastSense Companion');
            testCase.verifyEmpty(figs, ...
                'testCompanionCloseTearsDown: no Tag Status figure should remain after companion close');
        end

        function testSetProject_tearsDown(testCase)
            %TESTSETPROJECT_TEARSDOWN setProject closes any open Tag Status window.
            registerTwoSensors_();
            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            testCase.addTeardown(@() TagRegistry.clear());

            w = app.openTagStatusTable();
            testCase.verifyTrue(isvalid(w), 'precondition: window valid');

            app.setProject({}, TagRegistry);

            testCase.verifyEmpty(app.tagStatusTableWindowForTest_(), ...
                'testSetProject_tearsDown: companion ref must be cleared after setProject');
            figs = findall(groot, 'Type', 'figure', '-and', 'Name', ...
                'Tag Status -- FastSense Companion');
            testCase.verifyEmpty(figs, ...
                'testSetProject_tearsDown: no Tag Status figure should remain after setProject');
        end

        function testButtonExistsOnToolbar(testCase)
            %TESTBUTTONEXISTSONTOOLBAR Toolbar must carry a uibutton tagged 'CompanionTagStatusBtn'.
            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));

            hFig = app.getFigForTest_();
            btn = findall(hFig, 'Tag', 'CompanionTagStatusBtn');
            testCase.verifyNotEmpty(btn, ...
                'testButtonExistsOnToolbar: toolbar must contain a CompanionTagStatusBtn');
            testCase.verifyEqual(numel(btn), 1, ...
                'testButtonExistsOnToolbar: exactly one CompanionTagStatusBtn must exist');
        end

        function testActivityFlipsWithoutLiveMode(testCase)
            %TESTACTIVITYFLIPSWITHOUTLIVEMODE buildRow_ flips Live->Inactive as nowSeconds advances.
            %   This is the integration-level proxy for "window's own timer keeps
            %   Activity accurate when companion is NOT in Live mode": we drive
            %   the pure-logic seam (buildRow_'s nowSeconds parameter) the same
            %   way the timer's onRefreshTick_ does internally.
            TagRegistry.clear();
            testCase.addTeardown(@() TagRegistry.clear());

            tag = SensorTag('ax', 'Name', 'Anchor X');
            xLast = 1.7e9;                         % posix-time-ish anchor
            tag.updateData([xLast - 1, xLast], [1 2]);

            % t = xLast + 10s -> within threshold -> Live.
            rowLive = TagStatusTableWindow.buildRow_(tag, xLast + 10);
            testCase.verifyEqual(rowLive{9}, 'Live', ...
                'testActivityFlipsWithoutLiveMode: must be Live at +10s');

            % t = xLast + 301s -> beyond threshold (300s) -> Inactive.
            rowInactive = TagStatusTableWindow.buildRow_(tag, xLast + 301);
            testCase.verifyEqual(rowInactive{9}, 'Inactive', ...
                'testActivityFlipsWithoutLiveMode: must be Inactive at +301s');
        end

        function testLastRefreshedLabelOnOpen(testCase)
            %TESTLASTREFRESHEDLABELONOPEN On open, header label begins with "Last refreshed:".
            registerTwoSensors_();
            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            testCase.addTeardown(@() TagRegistry.clear());

            w = app.openTagStatusTable();
            lbl = w.lastRefreshedLabelForTest();

            testCase.verifyTrue(startsWith(lbl, 'Last refreshed:'), ...
                sprintf(['testLastRefreshedLabelOnOpen: label must begin with ' ...
                    '''Last refreshed:'', got ''%s'''], lbl));
            % On openWith we seed the label to wall-clock time so it
            % should NOT be the "--:--:--" placeholder.
            testCase.verifyFalse(contains(lbl, '--:--:--'), ...
                'testLastRefreshedLabelOnOpen: label must be seeded to a concrete time on open');
        end

        function testLastRefreshedLabelUpdatesAfterTick(testCase)
            %TESTLASTREFRESHEDLABELUPDATESAFTERTICK After a simulated refresh tick,
            %   the label must show a new HH:MM:SS. Because the timer fires
            %   on a 1s cadence, we drive a synchronous tick via the test
            %   helper and verify the label updated (or at least still
            %   begins with the correct prefix and matches the HH:MM:SS
            %   pattern).
            registerTwoSensors_();
            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            testCase.addTeardown(@() TagRegistry.clear());

            w = app.openTagStatusTable();
            w.tickForTest();
            lbl = w.lastRefreshedLabelForTest();

            testCase.verifyTrue(startsWith(lbl, 'Last refreshed:'), ...
                sprintf(['testLastRefreshedLabelUpdatesAfterTick: label must ' ...
                    'begin with ''Last refreshed:'', got ''%s'''], lbl));
            % Must match the regex "HH:MM:SS" (two digits each), proving
            % a real timestamp got written by the tick.
            tok = regexp(lbl, '\d{2}:\d{2}:\d{2}', 'match', 'once');
            testCase.verifyNotEmpty(tok, ...
                sprintf(['testLastRefreshedLabelUpdatesAfterTick: label must ' ...
                    'contain an HH:MM:SS timestamp after a tick, got ''%s'''], lbl));
        end

        function testSetPollingActive_falseStopsTimer(testCase)
            %TESTSETPOLLINGACTIVE_FALSESTOPSTIMER setPollingActive(false) stops RefreshTimer_.
            %   The timer must move from Running='on' to Running='off' but
            %   must NOT be deleted (close() still cleans it up). 260519-bs4-05.
            registerTwoSensors_();
            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            testCase.addTeardown(@() TagRegistry.clear());

            w = app.openTagStatusTable();
            tBefore = w.refreshTimerForTest();
            testCase.verifyNotEmpty(tBefore, ...
                'testSetPollingActive_falseStopsTimer: timer must exist after open');
            testCase.verifyEqual(get(tBefore, 'Running'), 'on', ...
                'testSetPollingActive_falseStopsTimer: timer must be running pre-pause');

            w.setPollingActive(false);

            tAfter = w.refreshTimerForTest();
            testCase.verifyNotEmpty(tAfter, ...
                'testSetPollingActive_falseStopsTimer: timer must still exist (not deleted) after pause');
            testCase.verifyEqual(get(tAfter, 'Running'), 'off', ...
                'testSetPollingActive_falseStopsTimer: timer state must be off after pause');
        end

        function testSetPollingActive_trueRestartsTimer(testCase)
            %TESTSETPOLLINGACTIVE_TRUERESTARTSTIMER setPollingActive(true) re-starts the timer.
            registerTwoSensors_();
            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            testCase.addTeardown(@() TagRegistry.clear());

            w = app.openTagStatusTable();
            w.setPollingActive(false);
            t = w.refreshTimerForTest();
            testCase.verifyEqual(get(t, 'Running'), 'off', ...
                'precondition: timer must be off after pause');

            w.setPollingActive(true);

            tAfter = w.refreshTimerForTest();
            testCase.verifyNotEmpty(tAfter, ...
                'testSetPollingActive_trueRestartsTimer: timer must exist after resume');
            testCase.verifyEqual(get(tAfter, 'Running'), 'on', ...
                'testSetPollingActive_trueRestartsTimer: timer state must be on after resume');
        end

        function testMarkTagsDirty_noOpWhilePaused(testCase)
            %TESTMARKTAGSDIRTY_NOOPWHILEPAUSED markTagsDirty must not mutate Data while paused.
            registerTwoSensors_();
            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            testCase.addTeardown(@() TagRegistry.clear());

            w = app.openTagStatusTable();
            % Snapshot the table.Data BEFORE pausing.
            hFig = w.getFigForTest();
            hTbl = findall(hFig, 'Type', 'uitable');
            testCase.verifyNotEmpty(hTbl, ...
                'precondition: uitable handle must be discoverable');
            dataBefore = hTbl.Data;

            w.setPollingActive(false);

            % While paused, mutate one of the underlying tags and call
            % markTagsDirty -- it MUST be inert.
            tA = TagRegistry.get('press_a');
            tA.updateData([1 2 3 4 5 6], [10 11 12 13 14 99]);
            w.markTagsDirty({'press_a'});

            dataAfter = hTbl.Data;
            testCase.verifyEqual(dataAfter, dataBefore, ...
                'testMarkTagsDirty_noOpWhilePaused: table.Data must be unchanged while paused');
        end

        function testPauseBtnLabelFlips(testCase)
            %TESTPAUSEBTNLABELFLIPS Button text toggles via setPollingActive.
            registerTwoSensors_();
            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            testCase.addTeardown(@() TagRegistry.clear());

            w = app.openTagStatusTable();
            testCase.verifyEqual(w.pauseBtnLabelForTest(), 'Pause polling', ...
                'testPauseBtnLabelFlips: initial label must be ''Pause polling''');

            w.setPollingActive(false);
            testCase.verifyEqual(w.pauseBtnLabelForTest(), 'Resume polling', ...
                'testPauseBtnLabelFlips: label must read ''Resume polling'' when paused');

            w.setPollingActive(true);
            testCase.verifyEqual(w.pauseBtnLabelForTest(), 'Pause polling', ...
                'testPauseBtnLabelFlips: label must revert to ''Pause polling'' after resume');
        end

        function testEventsCountColumnPopulatedFromRegistry(testCase)
            %TESTEVENTSCOUNTCOLUMNPOPULATEDFROMREGISTRY Tag with events emits real Events count in table.Data.
            %   Build a fixture where ONE tag has 3 bound events and the
            %   other has none; open a window; verify the table column 10
            %   carries the right per-row count. 260519-bs4-06 patch.
            TagRegistry.clear();
            EventBinding.clear();
            testCase.addTeardown(@() TagRegistry.clear());
            testCase.addTeardown(@() EventBinding.clear());

            % First tag: no EventStore -> Events count must be 0.
            tA = SensorTag('no_events', 'Name', 'No Events');
            tA.updateData([1 2 3], [1 2 3]);
            TagRegistry.register('no_events', tA);

            % Second tag: bind an EventStore with 3 events.
            store = EventStore('');
            tB = SensorTag('has_events', 'Name', 'Has Events');
            tB.updateData([1 2 3], [10 20 30]);
            tB.EventStore = store;
            for i = 1:3
                ev = Event(i, i + 0.5, 'has_events', 'thr', NaN, 'upper');
                store.append(ev);
                ev.TagKeys = {'has_events'};
                EventBinding.attach(ev.Id, 'has_events');
            end
            TagRegistry.register('has_events', tB);

            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            w = app.openTagStatusTable();
            testCase.verifyEqual(w.bufferSize(), 2, ...
                'precondition: buffer must hold both rows');

            rowNoEvents  = findRowByKey_(w, 'no_events');
            rowHasEvents = findRowByKey_(w, 'has_events');

            testCase.verifyNotEmpty(rowNoEvents,  'no_events row missing');
            testCase.verifyNotEmpty(rowHasEvents, 'has_events row missing');
            testCase.verifyEqual(rowNoEvents{10},  '0', ...
                'tag with no EventStore must show Events=0');
            testCase.verifyEqual(rowHasEvents{10}, '3', ...
                'tag with 3 bound events must show Events=3');
        end

        function testRefreshTimerStoppedAndDeletedOnClose(testCase)
            %TESTREFRESHTIMERSTOPPEDANDDELETEDONCLOSE Window close must stop AND delete its timer.
            registerTwoSensors_();
            app = FastSenseCompanion();
            testCase.addTeardown(@() safeClose_(app));
            testCase.addTeardown(@() TagRegistry.clear());
            testCase.addTeardown(@() cleanupLeakedTimers_());

            w = app.openTagStatusTable();

            % Snapshot the window's timer set immediately after open.
            timersBefore = findStatusTableTimers_();
            testCase.verifyNotEmpty(timersBefore, ...
                ['testRefreshTimerStoppedAndDeletedOnClose: a TagStatusTable-* ' ...
                'timer must exist after openWith']);

            w.close();

            % After close, no TagStatusTable-* timers should remain.
            timersAfter = findStatusTableTimers_();
            testCase.verifyEmpty(timersAfter, ...
                ['testRefreshTimerStoppedAndDeletedOnClose: all TagStatusTable-* ' ...
                'timers must be stopped+deleted after close']);
        end

    end
end

% ===================== local helpers =====================

function registerTwoSensors_()
    TagRegistry.clear();
    s1 = SensorTag('press_a', 'Name', 'Pressure A', 'Units', 'bar');
    s1.updateData([1 2 3], [10 11 12]);
    s2 = SensorTag('temp_b', 'Name', 'Temp B', 'Units', 'C');
    s2.updateData([1 2 3], [20 21 22]);
    TagRegistry.register('press_a', s1);
    TagRegistry.register('temp_b', s2);
end

function safeClose_(app)
    try
        if isvalid(app)
            app.close();
        end
    catch
    end
end

function row = findRowByKey_(w, key)
    row = {};
    for i = 1:w.bufferSize()
        r = w.peekRow(i);
        if strcmp(r{1}, key)
            row = r;
            return;
        end
    end
end

function cleanupLeakedTimers_()
    % Defensive sweep: stop+delete any TagStatusTable-* timers that survived
    % a test failure mid-execution. Required because timers persist across
    % MATLAB scope (root-owned), so a panic'd test could otherwise leave
    % the next test's findStatusTableTimers_ polluted.
    try
        leaked = findStatusTableTimers_();
        for k = 1:numel(leaked)
            try
                stop(leaked(k));
            catch
            end
            try
                delete(leaked(k));
            catch
            end
        end
    catch
    end
end

function out = findStatusTableTimers_()
    % timerfindall does not accept '-regexp', so we get all timers and
    % filter by Name prefix. Returns an empty array if nothing matches.
    out = [];
    try
        all = timerfindall;
        if isempty(all); return; end
        keep = false(1, numel(all));
        for k = 1:numel(all)
            try
                nm = get(all(k), 'Name');
                if ischar(nm) && strncmp(nm, 'TagStatusTable-', 15)
                    keep(k) = true;
                end
            catch
            end
        end
        out = all(keep);
    catch
        out = [];
    end
end
