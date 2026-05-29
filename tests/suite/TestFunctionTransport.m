classdef TestFunctionTransport < matlab.unittest.TestCase
    %TESTFUNCTIONTRANSPORT Class-based unit tests for FunctionTransport.
    %   Mirrors test_function_transport.m so the new logic is exercised by the
    %   CI suite runner (scripts/run_tests_with_coverage.m runs tests/suite
    %   only — function-based test_*.m files are not collected there).  No real
    %   email is sent; the wrapped handle targets a MockEmailTransport recorder.
    %
    %   Test coverage:
    %     testForwardsArgs                  — send() forwards args to the wrapped handle
    %     testRecipientsNormalized          — nested {{...}} / char flattened to cellstr
    %     testAttachmentsDefault            — omitted attachments default to {}
    %     testInvalidHandle                 — non-handle constructor input errors
    %     testIntegrationWithNotification   — works as a NotificationService Transport
    %
    %   See also FunctionTransport, test_function_transport, NotificationService.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(here);   % tests/suite — for MockEmailTransport
        end
    end

    methods (Test)

        function testForwardsArgs(testCase)
            mock = MockEmailTransport();
            t = FunctionTransport(@(r, s, b, a) mock.send(r, s, b, a));
            t.send({'a@b.com'}, 'subj', 'body', {});
            testCase.verifyTrue(isscalar(mock.Calls), 'exactly one call');
            rec = mock.Calls{1};
            testCase.verifyEqual(rec.recipients, {'a@b.com'}, 'recipients');
            testCase.verifyEqual(rec.subject, 'subj', 'subject');
            testCase.verifyEqual(rec.body, 'body', 'body');
            testCase.verifyTrue(iscell(rec.attachments) && isempty(rec.attachments), 'attachments {}');
        end

        function testRecipientsNormalized(testCase)
            % Nested {{...}} (as NotificationService forwards rule.Recipients) -> flat cellstr.
            mock = MockEmailTransport();
            t = FunctionTransport(@(r, s, b, a) mock.send(r, s, b, a));
            t.send({{'a@b.com', 'c@d.com'}}, 's', 'b', {});
            testCase.verifyEqual(mock.Calls{1}.recipients, {'a@b.com', 'c@d.com'}, ...
                'nested cell flattened');
            % Bare char -> 1x1 cellstr.
            mock2 = MockEmailTransport();
            t2 = FunctionTransport(@(r, s, b, a) mock2.send(r, s, b, a));
            t2.send('solo@x.com', 's', 'b', {});
            testCase.verifyEqual(mock2.Calls{1}.recipients, {'solo@x.com'}, 'char -> {char}');
        end

        function testAttachmentsDefault(testCase)
            mock = MockEmailTransport();
            t = FunctionTransport(@(r, s, b, a) mock.send(r, s, b, a));
            t.send({'a@b'}, 's', 'b');   % NO attachments arg -> must default to {}
            testCase.verifyTrue(iscell(mock.Calls{1}.attachments) && isempty(mock.Calls{1}.attachments), ...
                'omitted attachments default to {}');
        end

        function testInvalidHandle(testCase)
            testCase.verifyError(@() FunctionTransport(42), 'FunctionTransport:invalidHandle');
        end

        function testIntegrationWithNotification(testCase)
            % Drop-in NotificationService Transport: notify() routes through it
            % with the rule's recipients (flattened) and the filled subject.
            mock = MockEmailTransport();
            transport = FunctionTransport(@(r, s, b, a) mock.send(r, s, b, a));
            ns = NotificationService('Transport', transport, 'CooldownMinutes', 0);
            ns.setDefaultRule(NotificationRule('Recipients', {{'ops@co.com'}}, ...
                'IncludeSnapshot', false, 'Subject', 'Event: {sensor}'));
            ev = Event(now, now + 0.01, 'temp', 'HH', 100, 'upper'); %#ok<TNOW1>
            ns.notify(ev, struct());
            testCase.verifyTrue(isscalar(mock.Calls), 'one send');
            testCase.verifyEqual(mock.Calls{1}.recipients, {'ops@co.com'}, 'recipients');
            testCase.verifyEqual(mock.Calls{1}.subject, 'Event: temp', 'subject filled');
        end

    end

end
