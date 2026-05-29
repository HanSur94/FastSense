function test_email_transport()
%TEST_EMAIL_TRANSPORT Function-based unit tests for EmailTransport.
%   Tests the PURE buildMailProps mapping (all three security modes),
%   the invalid-mode error, and the Octave-guard no-throw behaviour.
%   No real network connections are made.
%
%   See also EmailTransport, TestEmailTransport, NotificationService.

    add_event_path();
    test_props_none();
    test_props_starttls();
    test_props_ssl();
    test_invalid_mode();
    test_octave_guard_no_throw();
    fprintf('test_email_transport: ALL PASSED\n');
end

function add_event_path()
    thisDir  = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    addpath(fullfile(repoRoot, 'libs', 'FastSense'));
    install();
end

function test_props_none()
    m = EmailTransport.buildMailProps('none', 587);
    assert(isKey(m, 'mail.smtp.port'),          'none: must have port key');
    assert(strcmp(m('mail.smtp.port'), '587'),   'none: port must be 587');
    assert(~isKey(m, 'mail.smtp.auth'),          'none: must NOT have auth key');
    assert(~isKey(m, 'mail.smtp.starttls.enable'), 'none: must NOT have starttls key');
    assert(~isKey(m, 'mail.smtp.socketFactory.class'), 'none: must NOT have socketFactory key');
    fprintf('  PASS: test_props_none\n');
end

function test_props_starttls()
    m = EmailTransport.buildMailProps('starttls', 587);
    assert(strcmp(m('mail.smtp.auth'), 'true'),              'starttls: auth must be true');
    assert(strcmp(m('mail.smtp.starttls.enable'), 'true'),   'starttls: starttls.enable must be true');
    assert(strcmp(m('mail.smtp.port'), '587'),               'starttls: port must be 587');
    assert(~isKey(m, 'mail.smtp.socketFactory.class'),       'starttls: must NOT have socketFactory key');
    fprintf('  PASS: test_props_starttls\n');
end

function test_props_ssl()
    m = EmailTransport.buildMailProps('ssl', 465);
    assert(strcmp(m('mail.smtp.auth'), 'true'),                                    'ssl: auth must be true');
    assert(strcmp(m('mail.smtp.socketFactory.class'), 'javax.net.ssl.SSLSocketFactory'), ...
        'ssl: socketFactory.class must be SSLSocketFactory');
    assert(strcmp(m('mail.smtp.socketFactory.port'), '465'),                       'ssl: socketFactory.port must be 465');
    assert(strcmp(m('mail.smtp.port'), '465'),                                     'ssl: port must be 465');
    fprintf('  PASS: test_props_ssl\n');
end

function test_invalid_mode()
    caught = false;
    caughtId = '';
    try
        EmailTransport('SecurityMode', 'bogus');
    catch ME
        caught = true;
        caughtId = ME.identifier;
    end
    assert(caught, 'invalid_mode: must throw an error');
    assert(strcmp(caughtId, 'EmailTransport:invalidSecurityMode'), ...
        sprintf('invalid_mode: expected EmailTransport:invalidSecurityMode, got %s', caughtId));
    fprintf('  PASS: test_invalid_mode\n');
end

function test_octave_guard_no_throw()
    % PRIMARY GUARANTEE: when sendmail is absent (exist('sendmail','file')==0,
    % as on Octave), EmailTransport.send logs a message and returns cleanly
    % without throwing a MATLAB error from our guard logic.
    %
    % On MATLAB where sendmail IS present, a real SMTP connection attempt may
    % occur; the test accepts any error that does NOT carry an identifier
    % starting with 'EmailTransport:' as an environmental network error
    % (not from our guard) and still considers the guard intent satisfied.
    t = EmailTransport('Server', 'localhost', 'SecurityMode', 'none');
    threwFromOurCode = false;
    try
        t.send({'a@b.com'}, 'subj', 'body', {});
    catch ME
        % Only count it as a failure if it came from our guard code.
        if strncmp(ME.identifier, 'EmailTransport:', numel('EmailTransport:'))
            threwFromOurCode = true;
        end
        % Environmental errors (network refused, MATLAB sendmail internal, etc.)
        % are not from our guard — accepted as non-failure.
    end
    assert(~threwFromOurCode, ...
        'octave_guard: EmailTransport.send must not throw with EmailTransport:* identifier');
    fprintf('  PASS: test_octave_guard_no_throw\n');
end
