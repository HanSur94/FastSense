close all; clear all; rehash;
profile on;
example_dock_disk;
profile off;
p = profile('info');
ft = p.FunctionTable;
[~, idx] = sort([ft.TotalTime], 'descend');
fprintf('\n=== TOP 40 ===\n');
fprintf('%-55s %8s %10s %10s\n', 'Function', 'Calls', 'Total(s)', 'Self(s)');
fprintf('%s\n', repmat('-', 1, 87));
for i = 1:min(40, numel(idx))
    f = ft(idx(i));
    fprintf('%-55s %8d %10.3f %10.3f\n', ...
        f.FunctionName, f.NumCalls, f.TotalTime, ...
        f.TotalTime - f.TotalRecursiveTime);
end
