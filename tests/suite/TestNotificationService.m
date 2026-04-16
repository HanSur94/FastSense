classdef TestNotificationService < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'FastSense'));
            install();
        end
    end

    methods (Test)
        function testConstructor(testCase)
            ns = NotificationService();
            testCase.verifyTrue(ns.Enabled, 'enabled_default');
            testCase.verifyEmpty(ns.Rules, 'no_rules');
        end

        function testAddRule(testCase)
            ns = NotificationService();
            r = NotificationRule('SensorKey', 'temp', 'Recipients', {'a@b.com'});
            ns.addRule(r);
            testCase.verifyEqual(numel(ns.Rules), 1, 'one_rule');
        end

        function testRuleMatchingPriority(testCase)
            ns = NotificationService();
            % Default rule
            ns.setDefaultRule(NotificationRule('Recipients', {'default@b.com'}));
            % Sensor rule
            ns.addRule(NotificationRule('SensorKey', 'temp', 'Recipients', {'sensor@b.com'}));
            % Sensor+threshold rule
            ns.addRule(NotificationRule('SensorKey', 'temp', 'ThresholdLabel', 'HH', ...
                'Recipients', {'exact@b.com'}));

            ev = Event(now, now+0.01, 'temp', 'HH', 100, 'upper');
            rule = ns.findBestRule(ev);
            testCase.verifyEqual(rule.Recipients{1}, 'exact@b.com', 'best_is_exact');

            ev2 = Event(now, now+0.01, 'temp', 'H', 80, 'upper');
            rule2 = ns.findBestRule(ev2);
            testCase.verifyEqual(rule2.Recipients{1}, 'sensor@b.com', 'best_is_sensor');

            ev3 = Event(now, now+0.01, 'pressure', 'X', 50, 'upper');
            rule3 = ns.findBestRule(ev3);
            testCase.verifyEqual(rule3.Recipients{1}, 'default@b.com', 'best_is_default');
        end

        function testNotifyDryRun(testCase)
            ns = NotificationService('DryRun', true);
            ns.setDefaultRule(NotificationRule('Recipients', {'test@b.com'}, 'IncludeSnapshot', false));
            ev = Event(now, now+0.01, 'temp', 'HH', 100, 'upper');
            ev = ev.setStats(105, 10, 90, 105, 98, 99, 3);
            sd = struct('X', linspace(now-1,now,100), 'Y', 80*ones(1,100), ...
                'thresholdValue', 100, 'thresholdDirection', 'upper');
            % Should not throw (dry run skips actual email)
            ns.notify(ev, sd);
            testCase.verifyEqual(ns.NotificationCount, 1, 'count_incremented');
        end

        function testDefaultRule(testCase)
            ns = NotificationService('DryRun', true);
            ev = Event(now, now+0.01, 'x', 'Y', 1, 'upper');
            rule = ns.findBestRule(ev);
            testCase.verifyEmpty(rule, 'no_default_no_match');
        end

        function testDisabled(testCase)
            ns = NotificationService('Enabled', false, 'DryRun', true);
            ns.setDefaultRule(NotificationRule('Recipients', {'x@y.com'}, 'IncludeSnapshot', false));
            ev = Event(now, now+0.01, 'x', 'Y', 1, 'upper');
            ev = ev.setStats(2, 1, 1, 2, 1.5, 1.6, 0.5);
            sd = struct('X', [now], 'Y', [2], 'thresholdValue', 1, 'thresholdDirection', 'upper');
            ns.notify(ev, sd);
            testCase.verifyEqual(ns.NotificationCount, 0, 'disabled_no_notify');
        end

        function testSnapshotGeneration(testCase)
            ns = NotificationService('DryRun', true, 'SnapshotDir', tempname);
            ns.setDefaultRule(NotificationRule('Recipients', {'x@y.com'}, 'IncludeSnapshot', true));
            ev = Event(now-1/24, now-0.5/24, 'temp', 'HH', 100, 'upper');
            ev = ev.setStats(115, 50, 90, 115, 105, 106, 5);
            rng(42);
            t = linspace(now-3/24, now, 500);
            y = 80 + 2*randn(1,500);
            sd = struct('X', t, 'Y', y, 'thresholdValue', 100, 'thresholdDirection', 'upper');
            ns.notify(ev, sd);
            % Check snapshots were created
            files = dir(fullfile(ns.SnapshotDir, '*.png'));
            testCase.verifyTrue(numel(files) >= 2, 'snapshots_created');
            rmdir(ns.SnapshotDir, 's');
        end
    end
end
