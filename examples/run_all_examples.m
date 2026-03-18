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
    run(fullfile(projectRoot, 'setup.m'));
    addpath(fullfile(projectRoot, 'libs', 'FastSense', 'private'));
    addpath(fileparts(mfilename('fullpath')));

    examples = {
        'example_basic',            '10M pts, 4 alarm/warning thresholds'
        'example_multi',            '5 sensors x 1M pts on one axes'
        'example_alarm_bands',      '2M pts, industrial HH/H/L/LL alarm bands'
        'example_nan_gaps',         '1M pts with sensor dropout gaps'
        'example_lttb_vs_minmax',   '5M pts, side-by-side downsampling comparison (linked)'
        'example_vibration',        '20M pts @ 50kHz, bearing fault detection'
        'example_ecg',              '5M pts ECG with arrhythmia thresholds'
        'example_multi_sensor_linked', '4-channel dashboard, 2M pts each (linked)'
        'example_linked',           '3 linked subplots, 5M pts each'
        'example_uneven_sampling',  '260K pts, event-driven variable rate'
        'example_visual_features',  '500K pts, bands/shading/fill/markers in 2x2 dashboard'
        'example_themes',           '100K pts, all 5 theme presets side by side'
        'example_dashboard',        '1M pts, dark-themed 4-tile dashboard'
        'example_100M',             '100M pts stress test (needs ~1.6 GB RAM)'
        'example_sensor_static',    'Sensor with static upper & lower thresholds'
        'example_sensor_multi_state', 'Multi-state sensor, combined conditions, getThresholdsAt'
        'example_sensor_registry',  'SensorRegistry API (list, get, getMultiple)'
        'example_sensor_dashboard', 'Multi-sensor 2x2 dashboard with SensorRegistry'
        'example_mixed_tiles',     'Mixed tile types: FastSense + bar/scatter/histogram'
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
