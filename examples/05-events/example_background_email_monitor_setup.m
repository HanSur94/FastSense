function pipeline = example_background_email_monitor_setup()
%EXAMPLE_BACKGROUND_EMAIL_MONITOR_SETUP Build and return a configured LiveEventPipeline.
%
%   This is the production-callable setup function that launchd / systemd / cron
%   snippets invoke via `runBackgroundMonitoring(@example_background_email_monitor_setup, ...)`.
%   It MUST live as a top-level function file so the @-handle resolves from
%   matlab -batch invocations (local functions inside a script body are NOT
%   visible to callers outside the script).
%
%   Builds 2 sensors (temperature, pressure) with simple H thresholds, mocks a
%   small backlog + live samples via MockDataSource, and constructs a
%   LiveEventPipeline with a NotificationService that defaults to DryRun unless
%   the FASTSENSE_SMTP_SERVER environment variable is set.
%
%   Environment variables read:
%     FASTSENSE_SMTP_SERVER  -- if set: DryRun=false (real email sent).
%     FASTSENSE_FROM_ADDR    -- optional, fallback 'fastsense@noreply.local'.
%     FASTSENSE_RECIPIENT    -- optional, fallback 'ops-team@example.com'.
%
%   Returns:
%     pipeline -- LiveEventPipeline ready for pipeline.start() (caller's job).
%
%   See also example_background_email_monitor, runBackgroundMonitoring, LiveEventPipeline.
%   Phase 1039 Plan 03.

    % --- Sensors + MonitorTags (Tag API) ---
    tempSensor = SensorTag('temperature', 'Name', 'Chamber Temperature');
    presSensor = SensorTag('pressure',    'Name', 'Chamber Pressure');

    % Simple H thresholds — tight so the mock will fire violations within seconds.
    tempHi = MonitorTag('temp_hi', tempSensor, @(x, y) y > 95);
    presHi = MonitorTag('pres_hi', presSensor, @(x, y) y > 5.0);

    % --- DataSourceMap with MockDataSources ---
    dsMap = DataSourceMap();
    dsMap.add('temperature', MockDataSource( ...
        'BaseValue', 85, 'NoiseStd', 2, ...
        'ViolationProbability', 0.05, ...  % aggressive: trigger violations fast in the demo
        'ViolationAmplitude', 20, ...
        'ViolationDuration', 4, ...
        'BacklogDays', 0.01, ...           % tiny backlog: faster demo startup
        'SampleInterval', 1, ...
        'PipelineInterval', 2, ...         % match pipeline Interval so live ticks generate fresh samples
        'Seed', 42));
    dsMap.add('pressure', MockDataSource( ...
        'BaseValue', 3.2, 'NoiseStd', 0.1, ...
        'ViolationProbability', 0.05, ...
        'ViolationAmplitude', 2.5, ...
        'ViolationDuration', 4, ...
        'BacklogDays', 0.01, ...
        'SampleInterval', 1, ...
        'PipelineInterval', 2, ...
        'Seed', 99));

    % --- Monitor map (key MUST be the parent sensor key, per processMonitorTag_) ---
    monitors = containers.Map();
    monitors('temperature') = tempHi;
    monitors('pressure')    = presHi;

    % --- EventStore (temp path so the demo is hermetic) ---
    storeFile = fullfile(tempdir, 'fastsense_background_email_demo_events.mat');

    % Bind a shared EventStore to BOTH MonitorTags so MonitorTag.emitEvent_ has a
    % sink and LiveEventPipeline.processMonitorTag_ can harvest the per-tick event
    % delta from monitor.EventStore (it reads `preStore = monitor.EventStore`).
    % Without this wiring the monitors have no bound store, zero events are
    % harvested, and the notify path never fires — the proven Tag-path pipeline
    % pattern wires monitor.EventStore explicitly (see
    % tests/test_live_event_pipeline_tag.m:make_live_tag_fixture).
    eventStore = EventStore(storeFile);
    tempHi.EventStore = eventStore;
    presHi.EventStore = eventStore;

    % --- Resolve SMTP config from env (D-04 Phase 1039) ---
    smtpServer = getenv('FASTSENSE_SMTP_SERVER');
    fromAddr   = getenvOr_('FASTSENSE_FROM_ADDR', 'fastsense@noreply.local');
    recipient  = getenvOr_('FASTSENSE_RECIPIENT', 'ops-team@example.com');
    dryRun     = isempty(smtpServer);  % no SMTP server set -> dry run

    if dryRun
        fprintf('[SETUP] FASTSENSE_SMTP_SERVER not set -- using DryRun=true (no email sent).\n');
    else
        fprintf('[SETUP] SMTP server = %s -- DryRun=false (real email will be sent).\n', smtpServer);
    end

    notif = NotificationService( ...
        'DryRun',      dryRun, ...
        'SmtpServer',  smtpServer, ...
        'FromAddress', fromAddr);

    % Single catch-all rule (D-03 Phase 1039: "one default rule, catches everything").
    notif.setDefaultRule(NotificationRule( ...
        'Recipients',      {{recipient}}, ...
        'Subject',         '[FastSense] {sensor}: {threshold} violation', ...
        'Message',         ['Sensor {sensor} violated threshold {threshold} ({direction}) ' ...
                            'from {startTime} to {endTime}. Peak={peak}, Mean={mean}, ' ...
                            'Duration={duration}.'], ...
        'IncludeSnapshot', true, ...
        'ContextHours',    1, ...
        'SnapshotSize',    [800, 400]));

    % --- Build pipeline with the new NV-pair (Plan 01) ---
    % Reuse the SAME storeFile as the pipeline's own EventStore so the harvested
    % deltas land in the same file the heartbeat / summary reports on.
    pipeline = LiveEventPipeline(monitors, dsMap, ...
        'EventFile',           storeFile, ...
        'Interval',            2, ...   % tight cadence so the demo emits within MaxRuntimeSec=8
        'MinDuration',         0, ...
        'NotificationService', notif);

    fprintf('[SETUP] Pipeline built with %d monitors, store=%s\n', ...
        numel(monitors.keys()), storeFile);
end

function v = getenvOr_(name, fallback)
%GETENVOR_ Return env var value when non-empty; otherwise fallback.
    v = getenv(name);
    if isempty(v)
        v = fallback;
    end
end
