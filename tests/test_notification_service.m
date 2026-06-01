function test_notification_service()
    add_event_path();
    test_constructor();
    test_add_rule();
    test_rule_matching_priority();
    test_notify_dry_run();
    test_default_rule();
    test_disabled();
    test_snapshot_generation();
    test_transport_delegation();
    test_cooldown_suppresses_within_window();
    test_cooldown_allows_after_expiry();
    fprintf('test_notification_service: ALL PASSED\n');
end

function add_event_path()
    thisDir  = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    addpath(fullfile(repoRoot, 'libs', 'FastSense'));
    addpath(fullfile(repoRoot, 'tests', 'suite'));
    install();
end

function test_constructor()
    ns = NotificationService();
    assert(ns.Enabled, 'enabled_default');
    assert(isempty(ns.Rules), 'no_rules');
    fprintf('  PASS: test_constructor\n');
end

function test_add_rule()
    ns = NotificationService();
    r = NotificationRule('SensorKey', 'temp', 'Recipients', {{'a@b.com'}});
    ns.addRule(r);
    assert(numel(ns.Rules) == 1, 'one_rule');
    fprintf('  PASS: test_add_rule\n');
end

function test_rule_matching_priority()
    ns = NotificationService();
    % Default rule
    ns.setDefaultRule(NotificationRule('Recipients', {{'default@b.com'}}));
    % Sensor rule
    ns.addRule(NotificationRule('SensorKey', 'temp', 'Recipients', {{'sensor@b.com'}}));
    % Sensor+threshold rule
    ns.addRule(NotificationRule('SensorKey', 'temp', 'ThresholdLabel', 'HH', ...
        'Recipients', {{'exact@b.com'}}));

    ev = Event(now, now+0.01, 'temp', 'HH', 100, 'upper');
    rule = ns.findBestRule(ev);
    assert(strcmp(rule.Recipients{1}, 'exact@b.com'), 'best_is_exact');

    ev2 = Event(now, now+0.01, 'temp', 'H', 80, 'upper');
    rule2 = ns.findBestRule(ev2);
    assert(strcmp(rule2.Recipients{1}, 'sensor@b.com'), 'best_is_sensor');

    ev3 = Event(now, now+0.01, 'pressure', 'X', 50, 'upper');
    rule3 = ns.findBestRule(ev3);
    assert(strcmp(rule3.Recipients{1}, 'default@b.com'), 'best_is_default');
    fprintf('  PASS: test_rule_matching_priority\n');
end

function test_notify_dry_run()
    ns = NotificationService('DryRun', true);
    ns.setDefaultRule(NotificationRule('Recipients', {{'test@b.com'}}, 'IncludeSnapshot', false));
    ev = Event(now, now+0.01, 'temp', 'HH', 100, 'upper');
    ev = ev.setStats(105, 10, 90, 105, 98, 99, 3);
    sd = struct('X', linspace(now-1, now, 100), 'Y', 80*ones(1, 100), ...
        'thresholdValue', 100, 'thresholdDirection', 'upper');
    % Should not throw (dry run skips actual email)
    ns.notify(ev, sd);
    assert(ns.NotificationCount == 1, 'count_incremented');
    fprintf('  PASS: test_notify_dry_run\n');
end

function test_default_rule()
    ns = NotificationService('DryRun', true);
    ev = Event(now, now+0.01, 'x', 'Y', 1, 'upper');
    rule = ns.findBestRule(ev);
    assert(isempty(rule), 'no_default_no_match');
    fprintf('  PASS: test_default_rule\n');
end

function test_disabled()
    ns = NotificationService('Enabled', false, 'DryRun', true);
    ns.setDefaultRule(NotificationRule('Recipients', {{'x@y.com'}}, 'IncludeSnapshot', false));
    ev = Event(now, now+0.01, 'x', 'Y', 1, 'upper');
    ev = ev.setStats(2, 1, 1, 2, 1.5, 1.6, 0.5);
    sd = struct('X', [now], 'Y', [2], 'thresholdValue', 1, 'thresholdDirection', 'upper');
    ns.notify(ev, sd);
    assert(ns.NotificationCount == 0, 'disabled_no_notify');
    fprintf('  PASS: test_disabled\n');
end

function test_snapshot_generation()
    ns = NotificationService('DryRun', true, 'SnapshotDir', tempname);
    ns.setDefaultRule(NotificationRule('Recipients', {{'x@y.com'}}, 'IncludeSnapshot', true));
    ev = Event(now-1/24, now-0.5/24, 'temp', 'HH', 100, 'upper');
    ev = ev.setStats(115, 50, 90, 115, 105, 106, 5);
    rng(42);
    t = linspace(now-3/24, now, 500);
    y = 80 + 2*randn(1, 500);
    sd = struct('X', t, 'Y', y, 'thresholdValue', 100, 'thresholdDirection', 'upper');
    ns.notify(ev, sd);
    % Check snapshots were created
    files = dir(fullfile(ns.SnapshotDir, '*.png'));
    assert(numel(files) >= 2, 'snapshots_created');
    rmdir(ns.SnapshotDir, 's');
    fprintf('  PASS: test_snapshot_generation\n');
end

function test_transport_delegation()
    % Proves that recipients / subject / body are forwarded correctly to Transport.send.
    mock = MockEmailTransport();
    recips = {{'a@b.com'}};
    subjTemplate = 'Event: {sensor} - {threshold}';
    ns = NotificationService('Transport', mock, 'CooldownMinutes', 0);
    ns.setDefaultRule(NotificationRule( ...
        'Recipients',      recips, ...
        'Subject',         subjTemplate, ...
        'IncludeSnapshot', false));

    ev = Event(now, now+0.01, 'sensorA', 'thresh1', 50, 'upper');
    ev = ev.setStats(55, 5, 48, 55, 51, 51.5, 1.5);
    sd = struct('X', [now], 'Y', [55], 'thresholdValue', 50, 'thresholdDirection', 'upper');
    ns.notify(ev, sd);

    assert(numel(mock.Calls) == 1, 'transport_delegation: expected exactly 1 call');
    call = mock.Calls{1};
    % Recipients must be forwarded (nested cell as stored in rule.Recipients).
    assert(iscell(call.recipients), 'recipients_is_cell');
    % Subject must be template-filled with the event data.
    expectedSubj = strrep(strrep(subjTemplate, '{sensor}', 'sensorA'), '{threshold}', 'thresh1');
    assert(strcmp(call.subject, expectedSubj), ...
        sprintf('subject mismatch: got "%s", expected "%s"', call.subject, expectedSubj));
    % Body must be non-empty.
    assert(~isempty(call.body), 'body_non_empty');
    fprintf('  PASS: test_transport_delegation\n');
end

function test_cooldown_suppresses_within_window()
    % Notifying the SAME (sensor, threshold) twice back-to-back suppresses the second.
    mock2 = MockEmailTransport();
    ns = NotificationService('Transport', mock2, 'CooldownMinutes', 5);
    ns.setDefaultRule(NotificationRule( ...
        'Recipients',      {{'x@y.com'}}, ...
        'IncludeSnapshot', false));

    ev = Event(now, now+0.01, 'sensorB', 'thresh2', 10, 'upper');
    ev = ev.setStats(12, 2, 9, 12, 10.5, 10.6, 0.8);
    sd = struct('X', [now], 'Y', [12], 'thresholdValue', 10, 'thresholdDirection', 'upper');

    ns.notify(ev, sd);  % First notify: proceeds
    ns.notify(ev, sd);  % Second notify: should be suppressed within the 5-min window

    assert(numel(mock2.Calls) == 1, ...
        sprintf('cooldown_suppresses: mock should have 1 call, got %d', numel(mock2.Calls)));
    assert(ns.NotificationCount == 1, ...
        sprintf('cooldown_suppresses: NotificationCount should be 1, got %d', ns.NotificationCount));
    assert(ns.SuppressedCount == 1, ...
        sprintf('cooldown_suppresses: SuppressedCount should be 1, got %d', ns.SuppressedCount));
    fprintf('  PASS: test_cooldown_suppresses_within_window\n');
end

function test_cooldown_allows_after_expiry()
    % After expiry, a second notify should go through.
    % Uses the Hidden test seam setLastSentForTesting_ to back-date the stamp
    % by 10 minutes (> the 5-minute window) — deterministic, no sleep needed.
    mock3 = MockEmailTransport();
    ns = NotificationService('Transport', mock3, 'CooldownMinutes', 5);
    ns.setDefaultRule(NotificationRule( ...
        'Recipients',      {{'z@w.com'}}, ...
        'IncludeSnapshot', false));

    ev = Event(now, now+0.01, 'sensorC', 'thresh3', 20, 'upper');
    ev = ev.setStats(22, 3, 18, 22, 20.5, 20.6, 0.9);
    sd = struct('X', [now], 'Y', [22], 'thresholdValue', 20, 'thresholdDirection', 'upper');

    ns.notify(ev, sd);  % First notify: proceeds (mock3.Calls==1)
    assert(numel(mock3.Calls) == 1, 'after_expiry: first notify must go through');

    % Back-date the cooldown stamp by 10 minutes (>5-min window) so expiry is simulated.
    ns.setLastSentForTesting_(ev, now() - 10/1440); %#ok<TNOW1>

    suppressedBefore = ns.SuppressedCount;
    ns.notify(ev, sd);  % Second notify after expiry: should proceed

    assert(numel(mock3.Calls) == 2, ...
        sprintf('after_expiry: expected 2 calls after expiry, got %d', numel(mock3.Calls)));
    assert(ns.SuppressedCount == suppressedBefore, ...
        'after_expiry: SuppressedCount must not increase after expiry');
    fprintf('  PASS: test_cooldown_allows_after_expiry\n');
end
