function test_resolve_segments()
    add_sensor_path();

    % testSegmentBoundaries — correct segment discovery
    s = Sensor('pressure');
    s.X = 1:100;
    s.Y = rand(1, 100) * 50 + 25;  % values between 25-75

    sc1 = StateChannel('machine');
    sc1.X = [1 30 60]; sc1.Y = [0 1 2];
    sc2 = StateChannel('vacuum');
    sc2.X = [1 20 50 80]; sc2.Y = [0 1 0 1];
    s.addStateChannel(sc1);
    s.addStateChannel(sc2);

    % Rule active when machine==1 AND vacuum==1 (segment [30,50) only)
    s.addThresholdRule(struct('machine', 1, 'vacuum', 1), 40, ...
        'Direction', 'upper', 'Label', 'Combo');

    s.resolve();

    % Violations should only exist in t=[30,49]
    viol = s.ResolvedViolations(1);
    if ~isempty(viol.X)
        assert(all(viol.X >= 30 & viol.X < 50), 'violations only in active segment');
        assert(all(viol.Y > 40), 'violations exceed threshold');
    end

    % testConditionBatching — rules with same condition share segments
    s = Sensor('temp');
    s.X = 1:100;
    s.Y = linspace(0, 100, 100);

    sc = StateChannel('mode');
    sc.X = [1 50]; sc.Y = [0 1];
    s.addStateChannel(sc);

    % Two rules, same condition — should be batched internally
    s.addThresholdRule(struct('mode', 1), 80, 'Direction', 'upper', 'Label', 'Warn');
    s.addThresholdRule(struct('mode', 1), 90, 'Direction', 'upper', 'Label', 'Alarm');

    s.resolve();

    assert(numel(s.ResolvedThresholds) == 2, 'batched: two thresholds');
    assert(numel(s.ResolvedViolations) == 2, 'batched: two violation sets');

    % Alarm violations must be subset of warn violations
    warnV = s.ResolvedViolations(1);
    alarmV = s.ResolvedViolations(2);
    assert(numel(alarmV.X) <= numel(warnV.X), 'alarm subset of warn');

    % testNoStateChannels — always-active threshold
    s = Sensor('pressure');
    s.X = 1:10;
    s.Y = [1 2 3 4 5 6 7 8 9 10];
    s.addThresholdRule(struct(), 5, 'Direction', 'upper', 'Label', 'Static');
    s.resolve();
    viol = s.ResolvedViolations(1);
    assert(isequal(viol.X, [6 7 8 9 10]), 'static: violation X');
    assert(isequal(viol.Y, [6 7 8 9 10]), 'static: violation Y');

    % testLowerDirection
    s = Sensor('pressure');
    s.X = 1:10;
    s.Y = [10 9 8 7 6 5 4 3 2 1];
    s.addThresholdRule(struct(), 5, 'Direction', 'lower', 'Label', 'LL');
    s.resolve();
    viol = s.ResolvedViolations(1);
    assert(isequal(viol.X, [7 8 9 10]), 'lower: violation X');
    assert(isequal(sort(viol.Y), [1 2 3 4]), 'lower: violation Y');

    fprintf('    All 4 resolve_segments tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
