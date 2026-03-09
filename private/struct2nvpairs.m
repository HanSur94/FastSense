function c = struct2nvpairs(s)
%STRUCT2NVPAIRS Convert a scalar struct to a name-value cell array.
%   c = struct2nvpairs(s)
%
%   Useful for passing struct fields as name-value arguments to MATLAB
%   functions like figure(), set(), or uicontrol().
%
%   Input:
%     s — scalar struct with N fields
%
%   Output:
%     c — 1x(2*N) cell array {'Name1', val1, 'Name2', val2, ...}
%
%   Example:
%     s.Color = 'r'; s.LineWidth = 2;
%     c = struct2nvpairs(s);  % {'Color', 'r', 'LineWidth', 2}

    names = fieldnames(s);
    n = numel(names);
    c = cell(1, 2*n);
    for i = 1:n
        c{2*i-1} = names{i};
        c{2*i}   = s.(names{i});
    end
end
