function test_function_transport()
%TEST_FUNCTION_TRANSPORT Function-based unit tests for FunctionTransport.
%   Verifies that FunctionTransport forwards send() calls to the wrapped
%   function handle, normalises recipients to a flat cellstr, defaults
%   attachments to {}, rejects non-handle constructor input, and works as a
%   drop-in NotificationService Transport.  No real email is sent — the
%   wrapped handle targets a MockEmailTransport recorder.
%
%   See also FunctionTransport, EmailTransport, NotificationService.

    add_event_path();
    test_forwards_args();
    test_recipients_normalized();
    test_attachments_default();
    test_invalid_handle();
    test_integration_with_notificationservice();
    fprintf('test_function_transport: ALL PASSED\n');
end

function add_event_path()
    thisDir  = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    addpath(fullfile(repoRoot, 'libs', 'FastSense'));
    addpath(fullfile(repoRoot, 'tests', 'suite'));   % MockEmailTransport recorder
    install();
end

function test_forwards_args()
    mock = MockEmailTransport();
    t = FunctionTransport(@(r, s, b, a) mock.send(r, s, b, a));
    t.send({'a@b.com'}, 'subj', 'body', {});
    assert(isscalar(mock.Calls), 'forwards_args: exactly one call expected');
    rec = mock.Calls{1};
    assert(isequal(rec.recipients, {'a@b.com'}), 'forwards_args: recipients mismatch');
    assert(strcmp(rec.subject, 'subj'),          'forwards_args: subject mismatch');
    assert(strcmp(rec.body, 'body'),             'forwards_args: body mismatch');
    assert(iscell(rec.attachments) && isempty(rec.attachments), ...
        'forwards_args: attachments must be {}');
    fprintf('  PASS: test_forwards_args\n');
end

function test_recipients_normalized()
    % Nested {{...}} (as NotificationService forwards rule.Recipients) -> flat cellstr.
    mock = MockEmailTransport();
    t = FunctionTransport(@(r, s, b, a) mock.send(r, s, b, a));
    t.send({{'a@b.com', 'c@d.com'}}, 's', 'b', {});
    assert(isequal(mock.Calls{1}.recipients, {'a@b.com', 'c@d.com'}), ...
        'recipients_normalized: nested cell must flatten to 1x2 cellstr');
    % Bare char -> 1x1 cellstr.
    mock2 = MockEmailTransport();
    t2 = FunctionTransport(@(r, s, b, a) mock2.send(r, s, b, a));
    t2.send('solo@x.com', 's', 'b', {});
    assert(isequal(mock2.Calls{1}.recipients, {'solo@x.com'}), ...
        'recipients_normalized: char must become {char}');
    fprintf('  PASS: test_recipients_normalized\n');
end

function test_attachments_default()
    mock = MockEmailTransport();
    t = FunctionTransport(@(r, s, b, a) mock.send(r, s, b, a));
    t.send({'a@b'}, 's', 'b');   % NO attachments arg -> must default to {}
    assert(iscell(mock.Calls{1}.attachments) && isempty(mock.Calls{1}.attachments), ...
        'attachments_default: omitted attachments must default to {}');
    fprintf('  PASS: test_attachments_default\n');
end

function test_invalid_handle()
    caught   = false;
    caughtId = '';
    try
        FunctionTransport(42);
    catch ME
        caught   = true;
        caughtId = ME.identifier;
    end
    assert(caught, 'invalid_handle: must throw an error');
    assert(strcmp(caughtId, 'FunctionTransport:invalidHandle'), ...
        sprintf('invalid_handle: expected FunctionTransport:invalidHandle, got %s', caughtId));
    fprintf('  PASS: test_invalid_handle\n');
end

function test_integration_with_notificationservice()
    % FunctionTransport as a drop-in NotificationService Transport: notify() must
    % route through it with the rule's recipients (flattened) and filled subject.
    mock = MockEmailTransport();
    transport = FunctionTransport(@(r, s, b, a) mock.send(r, s, b, a));
    ns = NotificationService('Transport', transport, 'CooldownMinutes', 0);
    ns.setDefaultRule(NotificationRule('Recipients', {{'ops@co.com'}}, ...
        'IncludeSnapshot', false, 'Subject', 'Event: {sensor}'));
    ev = Event(now, now + 0.01, 'temp', 'HH', 100, 'upper'); %#ok<TNOW1>
    ns.notify(ev, struct());
    assert(isscalar(mock.Calls), 'integration: exactly one send expected');
    assert(isequal(mock.Calls{1}.recipients, {'ops@co.com'}), ...
        'integration: recipients mismatch');
    assert(strcmp(mock.Calls{1}.subject, 'Event: temp'), ...
        'integration: subject template not filled');
    fprintf('  PASS: test_integration_with_notificationservice\n');
end
