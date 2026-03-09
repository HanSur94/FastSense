%% FastPlot Theme Comparison — All 5 built-in themes side by side
% Opens one figure per theme to compare visual styles

run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));

n = 1e5;
x = linspace(0, 50, n);
y1 = sin(x*2*pi/10) + 0.2*randn(1,n);
y2 = cos(x*2*pi/8) + 0.3*randn(1,n);
y3 = 0.5*sin(x*2*pi/5) + 0.15*randn(1,n);

themes = {'default', 'dark', 'light', 'industrial', 'scientific'};

for i = 1:numel(themes)
    themeName = themes{i};
    fp = FastPlot('Theme', themeName);
    fp.addLine(x, y1, 'DisplayName', 'Signal A');
    fp.addLine(x, y2, 'DisplayName', 'Signal B');
    fp.addLine(x, y3, 'DisplayName', 'Signal C');
    fp.addBand(-0.5, 0.5, 'FaceColor', [0.5 0.5 0.5], 'FaceAlpha', 0.1);
    fp.addThreshold(1.2, 'Direction', 'upper', 'ShowViolations', true);
    fp.render();
    title(fp.hAxes, sprintf('Theme: %s', themeName));
end

fprintf('All 5 themes rendered. Compare the styles!\n');
