function test_event_console()
%TEST_EVENT_CONSOLE Tests for console output functions.

    add_event_path();

    % --- Setup events ---
    e1 = Event(10, 25, 'Temperature', 'warning high', 80, 'high');
    e1 = e1.setStats(95.2, 150, 72, 95.2, 87.3, 88.1, 4.21);
    e2 = Event(50, 55, 'Pressure', 'low alarm', 5, 'low');
    e2 = e2.setStats(2.1, 50, 2.1, 6.8, 4.5, 4.7, 1.2);
    events = [e1, e2];

    % testPrintEventSummary — should not error, should produce output
    out = evalc('printEventSummary(events)');
    assert(~isempty(out), 'printSummary: produces output');
    assert(contains(out, 'Temperature'), 'printSummary: contains sensor name');
    assert(contains(out, 'warning high'), 'printSummary: contains threshold label');
    assert(contains(out, 'Pressure'), 'printSummary: contains second sensor');

    % testPrintEventSummaryEmpty — should not error
    out = evalc('printEventSummary([])');
    assert(contains(out, 'No events'), 'printSummaryEmpty: no events message');

    % testEventLogger — returns function handle
    logger = eventLogger();
    assert(isa(logger, 'function_handle'), 'eventLogger: returns function handle');

    % testEventLoggerOutput — prints one-line log
    out = evalc('logger(e1)');
    assert(~isempty(out), 'eventLoggerOutput: produces output');
    assert(contains(out, 'EVENT'), 'eventLoggerOutput: contains EVENT tag');
    assert(contains(out, 'Temperature'), 'eventLoggerOutput: contains sensor name');
    assert(contains(out, 'warning high'), 'eventLoggerOutput: contains label');

    fprintf('    All 4 event_console tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);setup();
end
