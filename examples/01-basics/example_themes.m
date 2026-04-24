%% FastSense Theme Comparison
% Demonstrates all 6 built-in themes, color palettes, FastSenseDefaults,
% reapplyTheme, resetDefaults, and distFig.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

n = 1e5;
x = linspace(0, 50, n);
y1 = sin(x*2*pi/10) + 0.2*randn(1,n);
y2 = cos(x*2*pi/8) + 0.3*randn(1,n);
y3 = 0.5*sin(x*2*pi/5) + 0.15*randn(1,n);

%% 1. Built-in theme presets ('light' and 'dark')
%   Legacy preset names ('default', 'industrial', 'scientific', 'ocean')
%   are accepted and aliased to 'light' for backward compatibility.
themes = {'light', 'dark'};

for i = 1:numel(themes)
    themeName = themes{i};
    fp = FastSense('Theme', themeName);
    fp.addLine(x, y1, 'DisplayName', 'Signal A');
    fp.addLine(x, y2, 'DisplayName', 'Signal B');
    fp.addLine(x, y3, 'DisplayName', 'Signal C');
    fp.addBand(-0.5, 0.5, 'FaceColor', [0.5 0.5 0.5], 'FaceAlpha', 0.1);
    fp.addThreshold(1.2, 'Direction', 'upper', 'ShowViolations', true);
    fp.render();
    title(fp.hAxes, sprintf('Theme: %s', themeName));
end

fprintf('Both themes rendered. Compare the styles!\n');

%% 2. Color palettes via LineColorOrder ('vibrant', 'muted', 'colorblind')
palettes = {'vibrant', 'muted', 'colorblind'};
for i = 1:numel(palettes)
    theme = FastSenseTheme('light', 'LineColorOrder', palettes{i});
    fp = FastSense('Theme', theme);
    for k = 1:8
        fp.addLine(x, sin(x*2*pi/(5+k)) + k, 'DisplayName', sprintf('Line %d', k));
    end
    fp.render();
    title(fp.hAxes, sprintf('Palette: %s', palettes{i}));
end
fprintf('3 color palettes rendered (vibrant, muted, colorblind).\n');

%% 3. Theme overrides via FastSenseTheme name-value pairs
customTheme = FastSenseTheme('dark', 'FontSize', 14, 'LineWidth', 2, ...
    'GridAlpha', 0.4, 'GridStyle', ':');
fp = FastSense('Theme', customTheme);
fp.addLine(x, y1, 'DisplayName', 'Custom styled');
fp.render();
title(fp.hAxes, 'Custom theme overrides (dark + larger font/lines)');

%% 4. reapplyTheme — switch theme on a rendered plot
fp.Theme = FastSenseTheme('light');
fp.reapplyTheme();
title(fp.hAxes, 'reapplyTheme: switched from dark to light');
fprintf('reapplyTheme() demo: switched theme on an already-rendered plot.\n');

%% 5. FastSenseDefaults — inspect global defaults
cfg = FastSenseDefaults();
fprintf('\nFastSenseDefaults() fields:\n');
fprintf('  Theme = %s\n', cfg.Theme);
fprintf('  DefaultDownsampleMethod = %s\n', cfg.DefaultDownsampleMethod);
fprintf('  XScale = %s, YScale = %s\n', cfg.XScale, cfg.YScale);
fprintf('  LiveInterval = %.1f s\n', cfg.LiveInterval);
fprintf('  StorageMode = %s, MemoryLimit = %.0f bytes\n', cfg.StorageMode, cfg.MemoryLimit);

%% 6. resetDefaults — force re-read of defaults file
FastSense.resetDefaults();
fprintf('FastSense.resetDefaults() called — cached defaults cleared.\n');

%% 7. distFig — arrange all open figures on the screen
FastSense.distFig();
fprintf('FastSense.distFig() called — all figures arranged in a grid.\n');
