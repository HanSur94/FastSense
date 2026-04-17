%% FastSense Multi-Line Example — 5 sensors, 1M points each
% Demonstrates multiple lines with thresholds and resetColorIndex.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

n = 1e6;
x = linspace(0, 60, n); % 60 seconds

fprintf('Creating 5 lines x %d points = %d total...\n', n, 5*n);
tic;

fp = FastSense();
colors = [0 0.447 0.741; 0.85 0.325 0.098; 0.929 0.694 0.125; 0.494 0.184 0.556; 0.466 0.674 0.188];
for i = 1:5
    y = sin(x * 2 * pi * i / 10) + 0.3 * randn(1, n) + i * 2;
    fp.addLine(x, y, 'DisplayName', sprintf('Sensor %d', i), ...
end
fp.addThreshold(10, 'Direction', 'upper', 'ShowViolations', true, ...
fp.render();

fprintf('Rendered in %.3f seconds.\n', toc);
title(fp.hAxes, 'FastSense — 5 Lines x 1M Points');
legend(fp.hAxes, 'show');

%% resetColorIndex — restart the auto color cycle
% Useful when replacing all lines and wanting colors to restart
fp2 = FastSense('Theme', 'light');
for i = 1:3
    fp2.addLine(x, sin(x*2*pi*i/10) + i*3, 'DisplayName', sprintf('Group A-%d', i));
end
fp2.resetColorIndex();  % next addLine starts from first palette color again
for i = 1:3
    fp2.addLine(x, cos(x*2*pi*i/8) + i*3, 'DisplayName', sprintf('Group B-%d', i));
end
fp2.render();
title(fp2.hAxes, 'resetColorIndex — Group B reuses Group A colors');
fprintf('resetColorIndex() demo: color cycle restarted for second group.\n');
