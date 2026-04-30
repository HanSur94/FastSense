function run_all_examples(mode)
%RUN_ALL_EXAMPLES Run each FastSense example.
%   run_all_examples()        — interactive: press ENTER between examples
%   run_all_examples('auto')  — non-interactive: 5s pause between examples
%
%   All plots are left open so you can zoom/pan them.

    if nargin < 1
        mode = 'interactive';
    end

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    run(fullfile(projectRoot, 'install.m'));
    addpath(fullfile(projectRoot, 'libs', 'FastSense', 'private'));
    exDir = fileparts(mfilename('fullpath'));
    addpath(exDir);
    addpath(fullfile(exDir, '01-basics'));
    addpath(fullfile(exDir, '02-sensors'));
    addpath(fullfile(exDir, '03-dashboard'));
    addpath(fullfile(exDir, '04-widgets'));
    addpath(fullfile(exDir, '05-events'));
    addpath(fullfile(exDir, '06-webbridge'));
    addpath(fullfile(exDir, '07-advanced'));

    % ====================================================================
    % Curated CI skip-list (Phase 1015 DIFF-04 — parity-checked by
    % scripts/check_skip_list_parity.sh against tests/test_examples_smoke.m).
    % Format: one example name per line between the markers, sorted
    % alphabetically. Currently empty — populated by Phase 1012 P02
    % once tests/test_examples_smoke.m lands on this branch.
    % --------------------------------------------------------------------
    % SKIP_LIST_BEGIN
    % SKIP_LIST_END
    % ====================================================================

    examples = {
        'example_basic',            '10M pts, thresholds, setScale, updateData'
        'example_multi',            '5 sensors x 1M pts, resetColorIndex'
        'example_alarm_bands',      '2M pts, HH/H/L/LL bands, setViolationsVisible'
        'example_nan_gaps',         '1M pts with sensor dropout gaps'
        'example_lttb_vs_minmax',   '5M pts, side-by-side downsampling comparison (linked)'
        'example_vibration',        '20M pts @ 50kHz, bearing fault detection'
        'example_ecg',              '5M pts ECG with arrhythmia thresholds'
        'example_multi_sensor_linked', '4-channel dashboard, 2M pts each (linked)'
        'example_linked',           '3 linked subplots, 5M pts each, setViewMode'
        'example_uneven_sampling',  '260K pts, event-driven variable rate'
        'example_visual_features',  '500K pts, bands/shading/fill/markers in 2x2 dashboard'
        'example_themes',           'Themes, palettes, defaults, reapplyTheme, distFig'
        'example_toolbar',          'Toolbar, metadata lookup, openLoupe'
        'example_dashboard',        '1M pts, 4-tile dashboard, setTileTheme'
        'example_100M',             '100M pts, DeferDraw/ShowProgress, ConsoleProgressBar'
        'example_sensor_static',    'Sensor: static thresholds, currentStatus, countViolations'
        'example_sensor_multi_state', 'Multi-state sensor, valueAt, getThresholdsAt'
        'example_sensor_registry',  'SensorRegistry: list, get, register, viewer, printTable'
        'example_sensor_dashboard', 'Multi-sensor 2x2 dashboard with SensorRegistry'
        'example_dock',             'Tabbed dock: 5 dashboards, undockTab'
        'example_dashboard_engine', 'DashboardEngine: widgets, save/load, removeWidget, setWidgetPosition'
        'example_mixed_tiles',      'Mixed tile types: FastSense + bar/scatter/histogram'
        'example_dashboard_advanced', 'Advanced dashboard: multi-page, tooltips, detach, dividers, collapsible, YLimits, save/load'
    };

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FastSense Examples (%d total)\n', size(examples, 1));
    if strcmp(mode, 'auto')
        fprintf('  Auto mode: 5s pause between examples\n');
    else
        fprintf('  Press ENTER for next, q to quit\n');
    end
    fprintf('========================================\n\n');

    for i = 1:size(examples, 1)
        fprintf('[%d/%d] %s\n', i, size(examples, 1), examples{i, 2});
        fprintf('       Running %s...\n\n', examples{i, 1});

        try
            feval(examples{i, 1});
        catch e
            fprintf('  ERROR: %s\n', e.message);
        end

        if i < size(examples, 1)
            if strcmp(mode, 'auto')
                pause(5);
            else
                reply = input('\nPress ENTER for next example (q to quit): ', 's');
                if strcmpi(reply, 'q')
                    fprintf('Stopped. All plots left open.\n');
                    return;
                end
            end
        end
    end

    fprintf('\n========================================\n');
    fprintf('  All examples complete! All plots left open.\n');
    fprintf('========================================\n');
end
