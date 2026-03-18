%% FastSense Interactive Demo
% Opens all example plots and keeps them alive for interactive exploration.
% Zoom and pan on any figure as long as you want.
% Press Enter in the command window to close all figures and exit.
%
% Usage:
%   From MATLAB/Octave command window:
%     cd FastSense/examples
%     demo_all
%
%   From terminal (Octave — requires GUI for interactive zoom/pan):
%     cd FastSense
%     octave --gui --eval "run('setup.m'); addpath('libs/FastSense/private'); addpath('examples'); demo_all;"

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));
addpath(fullfile(projectRoot, 'libs', 'FastSense', 'private'));
addpath(fileparts(mfilename('fullpath')));

fprintf('\n');
fprintf('  =============================================\n');
fprintf('  FastSense Interactive Demo\n');
fprintf('  =============================================\n');
fprintf('  Opening all example plots...\n\n');

example_basic;
fprintf('  [1/10] Basic — 10M noisy sine with thresholds\n');

example_multi;
fprintf('  [2/10] Multi — 5 sensor lines with shared threshold\n');

example_alarm_bands;
fprintf('  [3/10] Alarm bands — 4-level HH/H/L/LL\n');

example_nan_gaps;
fprintf('  [4/10] NaN gaps — sensor dropouts\n');

example_lttb_vs_minmax;
fprintf('  [5/10] LTTB vs MinMax — side-by-side comparison\n');

example_vibration;
fprintf('  [6/10] Vibration — 20M accelerometer at 50 kHz\n');

example_ecg;
fprintf('  [7/10] ECG — 5M signal with arrhythmia detection\n');

example_multi_sensor_linked;
fprintf('  [8/10] Multi-sensor linked — 4-channel dashboard\n');

example_linked;
fprintf('  [9/10] Linked axes — 3 synchronized subplots\n');

example_uneven_sampling;
fprintf('  [10/10] Uneven sampling — variable-rate data\n');

nFigs = numel(findobj('Type', 'figure'));
fprintf('\n');
fprintf('  %d figures open. Zoom and pan to explore!\n', nFigs);
fprintf('  Press Enter to close all figures and exit.\n\n');

input('', 's');

close all;
fprintf('  All figures closed.\n');
