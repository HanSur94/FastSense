function test_event_console()
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (known Octave classdef limitation)\n');
        return;
    end
%TEST_EVENT_CONSOLE Tests for console output functions.

    add_event_path();

    % --- Setup events ---
    e1 = Event(10, 25, 'Temperature', 'warning high', 80, 'upper');
    e1.setStats(95.2, 150, 72, 95.2, 87.3, 88.1, 4.21);
    e2 = Event(50, 55, 'Pressure', 'low alarm', 5, 'lower');
    e2.setStats(2.1, 50, 2.1, 6.8, 4.5, 4.7, 1.2);
    events = [e1, e2];

    % testPrintEventSummary — should not error, should produce output
    out = evalc('printEventSummary(events)');
    assert(~isempty(out), 'printSummary: produces output');
    assert(~isempty(strfind(out, 'Temperature')), 'printSummary: contains sensor name');
    assert(~isempty(strfind(out, 'warning high')), 'printSummary: contains threshold label');
    assert(~isempty(strfind(out, 'Pressure')), 'printSummary: contains second sensor');

    % testPrintEventSummaryEmpty — should not error
    out = evalc('printEventSummary([])');
    assert(~isempty(strfind(out, 'No events')), 'printSummaryEmpty: no events message');

    % testEventLogger — returns function handle
    logger = eventLogger();
    assert(isa(logger, 'function_handle'), 'eventLogger: returns function handle');

    % testEventLoggerOutput — prints one-line log
    out = evalc('logger(e1)');
    assert(~isempty(out), 'eventLoggerOutput: produces output');
    assert(~isempty(strfind(out, 'EVENT')), 'eventLoggerOutput: contains EVENT tag');
    assert(~isempty(strfind(out, 'Temperature')), 'eventLoggerOutput: contains sensor name');
    assert(~isempty(strfind(out, 'warning high')), 'eventLoggerOutput: contains label');

    fprintf('    All 4 event_console tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);setup();
end
