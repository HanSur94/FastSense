%EXAMPLE_BACKGROUND_EMAIL_MONITOR  Bounded demo wrapper for the background email monitor.
%
%   This is the "click me to see it run" demo entry. It bootstraps the repo
%   paths and invokes runBackgroundMonitoring on the standalone setup
%   function (examples/05-events/example_background_email_monitor_setup.m) with
%   a bounded MaxRuntimeSec so the demo exits deterministically.
%
%   Production launchd / systemd / cron jobs DO NOT need this wrapper — they
%   invoke the runner + setup-function-handle directly:
%
%       matlab -batch "install; runBackgroundMonitoring(@example_background_email_monitor_setup, 'PollSec', 30, 'MaxRuntimeSec', 0)"
%
%   See examples/05-events/README_background_email.md for full setup notes.
%
%   See also example_background_email_monitor_setup, runBackgroundMonitoring.

%% --- Bootstrap repo paths (mirrors example_live_pipeline.m) ---
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% --- Invoke the headless runner (bounded MaxRuntimeSec=8) ---
fprintf('\n=== example_background_email_monitor: starting (bounded MaxRuntimeSec=8) ===\n\n');
pipeline = runBackgroundMonitoring(@example_background_email_monitor_setup, ...
    'PollSec', 2, ...
    'MaxRuntimeSec', 8);

%% --- Post-run summary ---
fprintf('\n=== Demo summary ===\n');
fprintf('Pipeline status:           %s\n', pipeline.Status);
if ~isempty(pipeline.EventStore)
    fprintf('Total events in store:     %d\n', pipeline.EventStore.numEvents());
end
if ~isempty(pipeline.NotificationService)
    fprintf('NotificationCount:         %d\n', pipeline.NotificationService.NotificationCount);
    fprintf('DryRun?                    %d\n', pipeline.NotificationService.DryRun);
end
fprintf('\nDone.\n');
