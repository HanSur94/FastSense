classdef TestNotificationRule < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            install();
        end
    end

    methods (Test)
        function testConstructor(testCase)
            r = NotificationRule('SensorKey', 'temp', 'ThresholdLabel', 'HH', ...
                'Recipients', {{'a@b.com'}}, 'Subject', 'Alert: {sensor}');
            testCase.verifyEqual(r.SensorKey, 'temp', 'sensor');
            testCase.verifyEqual(r.ThresholdLabel, 'HH', 'label');
            testCase.verifyEqual(r.Recipients{1}, 'a@b.com', 'recipient');
        end

        function testMatchesSensorAndThreshold(testCase)
            r = NotificationRule('SensorKey', 'temp', 'ThresholdLabel', 'HH');
            ev = Event(now, now+0.01, 'temp', 'HH', 100, 'upper');
            testCase.verifyEqual(r.matches(ev), 3, 'exact_match_score_3');
            ev2 = Event(now, now+0.01, 'temp', 'H', 80, 'upper');
            testCase.verifyEqual(r.matches(ev2), 0, 'wrong_threshold_no_match');
        end

        function testMatchesSensorOnly(testCase)
            r = NotificationRule('SensorKey', 'temp');
            ev = Event(now, now+0.01, 'temp', 'HH', 100, 'upper');
            testCase.verifyEqual(r.matches(ev), 2, 'sensor_match_score_2');
            ev2 = Event(now, now+0.01, 'pressure', 'HH', 100, 'upper');
            testCase.verifyEqual(r.matches(ev2), 0, 'wrong_sensor');
        end

        function testMatchesDefault(testCase)
            r = NotificationRule();  % no sensor/threshold = default
            ev = Event(now, now+0.01, 'anything', 'X', 1, 'upper');
            testCase.verifyEqual(r.matches(ev), 1, 'default_score_1');
        end

        function testFillTemplate(testCase)
            r = NotificationRule('Subject', 'ALERT: {sensor} - {threshold} ({direction})', ...
                'Message', 'Peak: {peak}, Duration: {duration}');
            ev = Event(now, now + 1/24, 'temp', 'HH', 100, 'upper');
            ev.setStats(105, 10, 90, 105, 98, 99, 3);
            subj = r.fillTemplate(r.Subject, ev);
            testCase.verifyTrue(contains(subj, 'temp'), 'subj_sensor');
            testCase.verifyTrue(contains(subj, 'HH'), 'subj_threshold');
            testCase.verifyTrue(contains(subj, 'upper'), 'subj_direction');
            msg = r.fillTemplate(r.Message, ev);
            testCase.verifyTrue(contains(msg, '105'), 'msg_peak');
        end
    end
end
