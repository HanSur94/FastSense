function test_notification_rule()
    add_event_path();
    test_constructor();
    test_matches_sensor_and_threshold();
    test_matches_sensor_only();
    test_matches_default();
    test_fill_template();
    fprintf('test_notification_rule: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    install();
end

function test_constructor()
    r = NotificationRule('SensorKey', 'temp', 'ThresholdLabel', 'HH', ...
        'Recipients', {{'a@b.com'}}, 'Subject', 'Alert: {sensor}');
    assert(strcmp(r.SensorKey, 'temp'), 'sensor');
    assert(strcmp(r.ThresholdLabel, 'HH'), 'label');
    assert(strcmp(r.Recipients{1}, 'a@b.com'), 'recipient');
    fprintf('  PASS: test_constructor\n');
end

function test_matches_sensor_and_threshold()
    r = NotificationRule('SensorKey', 'temp', 'ThresholdLabel', 'HH');
    ev = Event(now, now+0.01, 'temp', 'HH', 100, 'upper');
    assert(r.matches(ev) == 3, 'exact_match_score_3');
    ev2 = Event(now, now+0.01, 'temp', 'H', 80, 'upper');
    assert(r.matches(ev2) == 0, 'wrong_threshold_no_match');
    fprintf('  PASS: test_matches_sensor_and_threshold\n');
end

function test_matches_sensor_only()
    r = NotificationRule('SensorKey', 'temp');
    ev = Event(now, now+0.01, 'temp', 'HH', 100, 'upper');
    assert(r.matches(ev) == 2, 'sensor_match_score_2');
    ev2 = Event(now, now+0.01, 'pressure', 'HH', 100, 'upper');
    assert(r.matches(ev2) == 0, 'wrong_sensor');
    fprintf('  PASS: test_matches_sensor_only\n');
end

function test_matches_default()
    r = NotificationRule();  % no sensor/threshold = default
    ev = Event(now, now+0.01, 'anything', 'X', 1, 'upper');
    assert(r.matches(ev) == 1, 'default_score_1');
    fprintf('  PASS: test_matches_default\n');
end

function test_fill_template()
    r = NotificationRule('Subject', 'ALERT: {sensor} - {threshold} ({direction})', ...
        'Message', 'Peak: {peak}, Duration: {duration}');
    ev = Event(now, now + 1/24, 'temp', 'HH', 100, 'upper');
    ev.setStats(105, 10, 90, 105, 98, 99, 3);
    subj = r.fillTemplate(r.Subject, ev);
    assert(~isempty(strfind(subj, 'temp')), 'subj_sensor');
    assert(~isempty(strfind(subj, 'HH')), 'subj_threshold');
    assert(~isempty(strfind(subj, 'upper')), 'subj_direction');
    msg = r.fillTemplate(r.Message, ev);
    assert(~isempty(strfind(msg, '105')), 'msg_peak');
    fprintf('  PASS: test_fill_template\n');
end
