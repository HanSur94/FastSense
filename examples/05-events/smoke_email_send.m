% smoke_email_send  MANUAL one-shot real-email smoke test for EmailTransport.
%
%   MANUAL smoke test — sends ONE real email.
%   Requires a reachable SMTP server and the FASTSENSE_SMTP_PASSWORD env var.
%   NOT part of the automated suite; run by hand:
%
%     run('examples/05-events/smoke_email_send.m')
%
%   Required environment variables:
%     FASTSENSE_SMTP_SERVER   — hostname of your SMTP server (e.g. smtp.gmail.com)
%     FASTSENSE_SMTP_USER     — SMTP auth username (e.g. alerts@example.com)
%     FASTSENSE_SMTP_FROM     — From address in the envelope (e.g. alerts@example.com)
%     FASTSENSE_SMTP_TO       — Recipient address (e.g. you@example.com)
%     FASTSENSE_SMTP_PASSWORD — SMTP auth password (read via PasswordEnv at send time)
%
%   On Octave, EmailTransport.send detects the absence of sendmail and logs
%   a skip message rather than erroring — no real email will be sent on Octave.
%
%   See also EmailTransport, NotificationService.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% Read configuration from environment variables
server = getenv('FASTSENSE_SMTP_SERVER');
user   = getenv('FASTSENSE_SMTP_USER');
from   = getenv('FASTSENSE_SMTP_FROM');
to     = getenv('FASTSENSE_SMTP_TO');
pwEnv  = 'FASTSENSE_SMTP_PASSWORD';

%% Guard: print instructions and return when required variables are unset
if isempty(server) || isempty(user) || isempty(to)
    fprintf('\n[smoke_email_send] Required environment variables are not set.\n');
    fprintf('Please set the following before running this script:\n');
    fprintf('  FASTSENSE_SMTP_SERVER   — SMTP hostname\n');
    fprintf('  FASTSENSE_SMTP_USER     — SMTP auth username\n');
    fprintf('  FASTSENSE_SMTP_FROM     — From address\n');
    fprintf('  FASTSENSE_SMTP_TO       — Recipient address\n');
    fprintf('  FASTSENSE_SMTP_PASSWORD — SMTP auth password\n');
    fprintf('\nExample (bash):\n');
    fprintf('  export FASTSENSE_SMTP_SERVER=smtp.example.com\n');
    fprintf('  export FASTSENSE_SMTP_USER=alerts@example.com\n');
    fprintf('  export FASTSENSE_SMTP_FROM=alerts@example.com\n');
    fprintf('  export FASTSENSE_SMTP_TO=you@example.com\n');
    fprintf('  export FASTSENSE_SMTP_PASSWORD=yourpassword\n');
    return;
end

%% Build EmailTransport and send one test email
t = EmailTransport('Server', server, 'Port', 587, 'User', user, ...
    'PasswordEnv', pwEnv, 'SecurityMode', 'starttls', 'From', from);

t.send({to}, '[FastSense] smoke test', ...
    sprintf('EmailTransport smoke test sent %s', datestr(now)), {}); %#ok<TNOW1,DATST>

fprintf('[smoke_email_send] Sent to %s via %s:587 (starttls). Check the inbox.\n', to, server);
