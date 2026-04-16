function test_sensor_resolve()
%TEST_SENSOR_RESOLVE Tests for Sensor.resolve() precomputation.

    add_sensor_path();

    % testResolveSingleRule — one state channel, one threshold
    s = Sensor('pressure');
    s.X = 1:20;
    s.Y = [5 5 5 5 15 15 15 15 5 5 5 5 15 15 15 15 5 5 5 5];

    sc = StateChannel('machine');
    sc.X = [1 10];
    sc.Y = [0 1];
    s.addStateChannel(sc);

    % Threshold of 10 only applies when machine == 1 (timestamps 10-20)
    t = Threshold('hh', 'Name', 'HH', 'Direction', 'upper');
    t.addCondition(struct('machine', 1), 10);
    s.addThreshold(t);

    s.resolve();

    % Should have one resolved threshold
    assert(numel(s.ResolvedThresholds) == 1, 'testSingleRule: count');
    th = s.ResolvedThresholds(1);
    assert(strcmp(th.Label, 'HH'), 'testSingleRule: label');
    assert(strcmp(th.Direction, 'upper'), 'testSingleRule: direction');
    % Violations should only be at t=13,14,15,16 (where y=15 > 10 AND machine==1)
    viol = s.ResolvedViolations(1);
    assert(all(viol.X >= 10), 'testSingleRule: violations only in active region');
    assert(all(viol.Y > 10), 'testSingleRule: violation values exceed threshold');

    % testResolveMultipleRules — two states, two thresholds
    s = Sensor('temp');
    s.X = 1:20;
    s.Y = [30 30 30 30 60 60 60 60 30 30 30 30 60 60 60 60 30 30 30 30];

    sc = StateChannel('mode');
    sc.X = [1 11];
    sc.Y = [0 1];
    s.addStateChannel(sc);

    t1 = Threshold('normal_hh', 'Name', 'Normal HH', 'Direction', 'upper');
    t1.addCondition(struct('mode', 0), 50);
    t2 = Threshold('strict_hh', 'Name', 'Strict HH', 'Direction', 'upper');
    t2.addCondition(struct('mode', 1), 40);
    s.addThreshold(t1);
    s.addThreshold(t2);

    s.resolve();

    assert(numel(s.ResolvedThresholds) == 2, 'testMultipleRules: threshold count');

    % testResolveMultipleStateChannels
    s = Sensor('pressure');
    s.X = 1:20;
    s.Y = ones(1, 20) * 50;

    sc1 = StateChannel('machine');
    sc1.X = [1 10]; sc1.Y = [0 1];
    sc2 = StateChannel('zone');
    sc2.X = [1 5 15]; sc2.Y = [0 1 2];
    s.addStateChannel(sc1);
    s.addStateChannel(sc2);

    tc = Threshold('combo', 'Name', 'Combo alarm', 'Direction', 'upper');
    tc.addCondition(struct('machine', 1, 'zone', 1), 40);
    s.addThreshold(tc);

    s.resolve();
    assert(numel(s.ResolvedThresholds) == 1, 'testMultiState: threshold count');

    % testResolveNoRules — should not error
    s = Sensor('pressure');
    s.X = 1:10;
    s.Y = ones(1, 10);
    s.resolve();
    assert(isempty(s.ResolvedThresholds), 'testNoRules: empty thresholds');
    assert(isempty(s.ResolvedViolations), 'testNoRules: empty violations');

    % testResolveNoStateChannels — rules with no state dependency
    s = Sensor('pressure');
    s.X = 1:10;
    s.Y = [1 2 3 4 5 6 7 8 9 10];
    ts = Threshold('static', 'Name', 'Static', 'Direction', 'upper');
    ts.addCondition(struct(), 5);
    s.addThreshold(ts);
    s.resolve();
    assert(numel(s.ResolvedThresholds) == 1, 'testNoState: threshold count');
    viol = s.ResolvedViolations(1);
    assert(isequal(viol.X, [6 7 8 9 10]), 'testNoState: violation X');

    % testGetThresholdsAt
    s = Sensor('pressure');
    s.X = 1:20;
    s.Y = ones(1, 20);
    sc = StateChannel('machine');
    sc.X = [1 10]; sc.Y = [0 1];
    s.addStateChannel(sc);
    tm0 = Threshold('m0_hh', 'Direction', 'upper');
    tm0.addCondition(struct('machine', 0), 50);
    tm1 = Threshold('m1_hh', 'Direction', 'upper');
    tm1.addCondition(struct('machine', 1), 80);
    s.addThreshold(tm0);
    s.addThreshold(tm1);
    active = s.getThresholdsAt(5);
    assert(numel(active) == 1 && active(1).Value == 50, 'testGetThresholdsAt: state 0');
    active = s.getThresholdsAt(15);
    assert(numel(active) == 1 && active(1).Value == 80, 'testGetThresholdsAt: state 1');

    fprintf('    All 6 sensor_resolve tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
