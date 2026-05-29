classdef TestEmailTransport < matlab.unittest.TestCase
    %TESTEMAILRANSPORT Class-based unit tests for EmailTransport.
    %   Mirrors test_email_transport.m assertions using verifyEqual / verifyError /
    %   verifyFalse.  Tests are PURE: no real SMTP connections are made.
    %
    %   Test coverage:
    %     testPropMapNone          — 'none' mode only sets mail.smtp.port
    %     testPropMapStarttls      — 'starttls' mode sets auth + starttls.enable + port
    %     testPropMapSsl           — 'ssl' mode sets auth + socketFactory + port
    %     testInvalidModeError     — unrecognised SecurityMode throws correct error ID
    %     testOctaveGuardNoThrow   — send() does not raise EmailTransport:* errors
    %
    %   See also EmailTransport, test_email_transport, NotificationService.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here     = fileparts(mfilename('fullpath'));
            repo     = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'tests', 'suite'));
        end
    end

    methods (Test)

        function testPropMapNone(testCase)
            m = EmailTransport.buildMailProps('none', 587);
            testCase.verifyTrue(isKey(m, 'mail.smtp.port'),           'none: must have port');
            testCase.verifyEqual(m('mail.smtp.port'), '587',           'none: port == 587');
            testCase.verifyFalse(isKey(m, 'mail.smtp.auth'),          'none: no auth key');
            testCase.verifyFalse(isKey(m, 'mail.smtp.starttls.enable'), 'none: no starttls key');
            testCase.verifyFalse(isKey(m, 'mail.smtp.socketFactory.class'), 'none: no socketFactory key');
        end

        function testPropMapStarttls(testCase)
            m = EmailTransport.buildMailProps('starttls', 587);
            testCase.verifyEqual(m('mail.smtp.auth'), 'true',              'starttls: auth=true');
            testCase.verifyEqual(m('mail.smtp.starttls.enable'), 'true',   'starttls: starttls.enable=true');
            testCase.verifyEqual(m('mail.smtp.port'), '587',               'starttls: port=587');
            testCase.verifyFalse(isKey(m, 'mail.smtp.socketFactory.class'), 'starttls: no socketFactory key');
        end

        function testPropMapSsl(testCase)
            m = EmailTransport.buildMailProps('ssl', 465);
            testCase.verifyEqual(m('mail.smtp.auth'), 'true',                                    'ssl: auth=true');
            testCase.verifyEqual(m('mail.smtp.socketFactory.class'), 'javax.net.ssl.SSLSocketFactory', ...
                'ssl: socketFactory.class');
            testCase.verifyEqual(m('mail.smtp.socketFactory.port'), '465',                       'ssl: socketFactory.port=465');
            testCase.verifyEqual(m('mail.smtp.port'), '465',                                     'ssl: port=465');
        end

        function testInvalidModeError(testCase)
            testCase.verifyError(@() EmailTransport('SecurityMode', 'bogus'), ...
                'EmailTransport:invalidSecurityMode');
        end

        function testOctaveGuardNoThrow(testCase)
            % Same guarantee as test_octave_guard_no_throw: EmailTransport.send
            % must not emit an identifier beginning with 'EmailTransport:'.
            t = EmailTransport('Server', 'localhost', 'SecurityMode', 'none');
            threwFromOurCode = false;
            try
                t.send({'a@b.com'}, 'subj', 'body', {});
            catch ME
                if strncmp(ME.identifier, 'EmailTransport:', numel('EmailTransport:'))
                    threwFromOurCode = true;
                end
            end
            testCase.verifyFalse(threwFromOurCode, ...
                'send() must not throw with EmailTransport:* identifier');
        end

    end

end
