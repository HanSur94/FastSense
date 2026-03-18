function test_event()
%TEST_EVENT Tests for Event value class.

    add_event_path();

    % testConstructor
    e = Event(10, 20, 'temp', 'warning high', 80, 'upper');
    assert(e.StartTime == 10, 'constructor: StartTime');
    assert(e.EndTime == 20, 'constructor: EndTime');
    assert(e.Duration == 10, 'constructor: Duration');
    assert(strcmp(e.SensorName, 'temp'), 'constructor: SensorName');
    assert(strcmp(e.ThresholdLabel, 'warning high'), 'constructor: ThresholdLabel');
    assert(e.ThresholdValue == 80, 'constructor: ThresholdValue');
    assert(strcmp(e.Direction, 'upper'), 'constructor: Direction');

    % testStats
    e = Event(1, 5, 'temp', 'warn', 80, 'upper');
    e = e.setStats(100, 3, 70, 90, 82, 83, 5);
    assert(e.PeakValue == 100, 'stats: PeakValue');
    assert(e.NumPoints == 3, 'stats: NumPoints');
    assert(e.MinValue == 70, 'stats: MinValue');
    assert(e.MaxValue == 90, 'stats: MaxValue');
    assert(abs(e.MeanValue - 82) < 1e-10, 'stats: MeanValue');
    assert(abs(e.RmsValue - 83) < 1e-10, 'stats: RmsValue');
    assert(abs(e.StdValue - 5) < 1e-10, 'stats: StdValue');

    % testInvalidDirection
    threw = false;
    try
        Event(1, 5, 'temp', 'warn', 80, 'sideways');
    catch
        threw = true;
    end
    assert(threw, 'invalidDirection: should throw');

    % testEndBeforeStart
    threw = false;
    try
        Event(10, 5, 'temp', 'warn', 80, 'upper');
    catch
        threw = true;
    end
    assert(threw, 'endBeforeStart: should throw');

    fprintf('    All 4 event tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
