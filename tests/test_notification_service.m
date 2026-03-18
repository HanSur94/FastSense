function test_notification_service()
    add_event_path();
    test_constructor();
    test_add_rule();
    test_rule_matching_priority();
    test_notify_dry_run();
    test_default_rule();
    test_disabled();
    test_snapshot_generation();
    fprintf('test_notification_service: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    addpath(fullfile(repoRoot, 'libs', 'FastSense'));
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
    sd = struct('X', linspace(now-1,now,100), 'Y', 80*ones(1,100), ...
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
    y = 80 + 2*randn(1,500);
    sd = struct('X', t, 'Y', y, 'thresholdValue', 100, 'thresholdDirection', 'upper');
    ns.notify(ev, sd);
    % Check snapshots were created
    files = dir(fullfile(ns.SnapshotDir, '*.png'));
    assert(numel(files) >= 2, 'snapshots_created');
    rmdir(ns.SnapshotDir, 's');
    fprintf('  PASS: test_snapshot_generation\n');
end
