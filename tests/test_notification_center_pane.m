function test_notification_center_pane()
%TEST_NOTIFICATION_CENTER_PANE Pure-logic tests for the Companion notification inbox.
%   Headless, Octave-tolerant. Exercises the StubEventStore test double and the
%   NotificationCenterPane static helpers (filter/sort/diff/badge) with no
%   uifigure — every assertion is a millisecond data transform.
%
%   NOTE: the real Event constructor takes six args
%   Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)
%   with direction validated against {'upper','lower'} — the planning docs'
%   4-arg shorthand does not construct, so the full signature is used here.
%
%   See also NotificationCenterPane, StubEventStore, Event, EventStore.

    add_companion_path();
    n = 0;

    % --- Fixtures: e1 (sev3, t=30), e2 (sev2, t=20) unacked; e3 (sev1, t=10) acked ---
    e1 = Event(30, NaN, 'P-101', 'HighPressure', 100, 'upper');
    e1.Id = 'evt_1'; e1.Severity = 3; e1.IsOpen = true;
    e2 = Event(20, NaN, 'T-200', 'Overtemp', 80, 'upper');
    e2.Id = 'evt_2'; e2.Severity = 2;
    e3 = Event(10, 15, 'F-300', 'LowFlow', 5, 'lower');
    e3.Id = 'evt_3'; e3.Severity = 1; e3.AckedAt = now;

    % 1. filterUnacked_ drops the acked event, preserves order.
    unacked = NotificationCenterPane.filterUnacked_([e1 e2 e3]);
    n = n + 1; check(numel(unacked) == 2, 'filterUnacked_ should keep 2 unacked events');
    n = n + 1; check(isequal(NotificationCenterPane.idsOf_(unacked), {'evt_1', 'evt_2'}), ...
        'filterUnacked_ should keep evt_1 and evt_2');

    % 2. sortNewestFirst_ orders by StartTime descending (feed an unsorted array).
    sorted = NotificationCenterPane.sortNewestFirst_([e2 e3 e1]);
    n = n + 1; check(isequal(NotificationCenterPane.idsOf_(sorted), {'evt_1', 'evt_2', 'evt_3'}), ...
        'sortNewestFirst_ should order evt_1 (t=30), evt_2 (t=20), evt_3 (t=10)');
    n = n + 1; check(strcmp(sorted(1).Id, 'evt_1'), 'sortNewestFirst_(1) should be the newest (evt_1)');

    % 3. An AckedAt = NaN event is treated as UNACKED.
    e4 = Event(40, NaN, 'V-400', 'Vibration', 9, 'upper');
    e4.Id = 'evt_4'; e4.Severity = 2; e4.AckedAt = NaN;
    keptNaN = NotificationCenterPane.filterUnacked_([e3 e4]);
    n = n + 1; check(numel(keptNaN) == 1 && strcmp(keptNaN(1).Id, 'evt_4'), ...
        'filterUnacked_ should keep an AckedAt=NaN event and drop the acked one');

    % 4. maxSeverity_.
    n = n + 1; check(NotificationCenterPane.maxSeverity_([e1 e2]) == 3, 'maxSeverity_([3 2]) should be 3');
    n = n + 1; check(NotificationCenterPane.maxSeverity_(Event.empty) == 0, 'maxSeverity_(empty) should be 0');

    % 5. diffIds_ — order-insensitive set comparison.
    n = n + 1; check(~NotificationCenterPane.diffIds_({'a', 'b'}, {'b', 'a'}), ...
        'diffIds_ should be false for a reordered identical set');
    n = n + 1; check(NotificationCenterPane.diffIds_({'a', 'b'}, {'a'}), ...
        'diffIds_ should be true when an id is added');
    n = n + 1; check(~NotificationCenterPane.diffIds_({}, {}), 'diffIds_({},{}) should be false');

    % 6. badgeText_.
    n = n + 1; check(strcmp(NotificationCenterPane.badgeText_(0, 'B'), 'B'), 'badgeText_(0) is the plain glyph');
    n = n + 1; check(strcmp(NotificationCenterPane.badgeText_(5, 'B'), 'B (5)'), 'badgeText_(5) is "B (5)"');

    % 7. badgeColor_ maps severity to theme tokens.
    theme = CompanionTheme.get('dark');
    n = n + 1; check(isequal(NotificationCenterPane.badgeColor_(3, theme), theme.StatusAlarmColor), ...
        'badgeColor_(3) should be StatusAlarmColor');
    n = n + 1; check(isequal(NotificationCenterPane.badgeColor_(2, theme), theme.StatusWarnColor), ...
        'badgeColor_(2) should be StatusWarnColor');
    n = n + 1; check(isequal(NotificationCenterPane.badgeColor_(1, theme), theme.Accent), ...
        'badgeColor_(1) should be Accent');

    % 8. StubEventStore round-trip + ack-race throw.
    s = StubEventStore;
    s.Events_ = [e1 e2 e3];
    s.acknowledgeEvent('evt_2', struct('comment', ''));
    n = n + 1; check(isequal(s.AckedIds_, {'evt_2'}), 'stub should record the acked id');
    n = n + 1; check(~isempty(s.Events_(2).AckedAt), 'stub should mutate the matching Event AckedAt');

    s.ThrowOnAck_ = true;
    threw = false;
    try
        s.acknowledgeEvent('evt_2', struct('comment', ''));
    catch ME
        threw = strcmp(ME.identifier, 'EventStore:unknownEventId');
    end
    n = n + 1; check(threw, 'stub with ThrowOnAck_ should raise EventStore:unknownEventId');

    fprintf('    All %d tests passed.\n', n);
end

function add_companion_path()
%ADD_COMPANION_PATH Add repo root to path and run install() to wire all libs.
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
end

function check(cond, msg)
%CHECK Assert cond is true; error with msg otherwise.
    if ~cond
        error('test_notification_center_pane:failed', '%s', msg);
    end
end
