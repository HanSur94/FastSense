function c = struct2nvpairs(s)
%STRUCT2NVPAIRS Convert a scalar struct to a name-value cell array.
%   c = STRUCT2NVPAIRS(s) flattens the fields of a scalar struct into a
%   1-by-2N cell array of interleaved name-value pairs, suitable for
%   passing to MATLAB functions that accept name-value syntax such as
%   figure(), set(), or uicontrol().
%
%   This function is a private helper for FastPlot.
%
%   Inputs:
%     s — scalar struct with N fields (any field value types)
%
%   Outputs:
%     c — 1x(2*N) cell array: {'Name1', val1, 'Name2', val2, ...}
%         Field names appear in the order returned by fieldnames().
%
%   Example:
%     s.Color = 'r'; s.LineWidth = 2;
%     c = struct2nvpairs(s);  % {'Color', 'r', 'LineWidth', 2}
%
%   See also parseOpts, fieldnames.

    names = fieldnames(s);
    n = numel(names);
    c = cell(1, 2*n);
    for i = 1:n
        % Odd slots hold field names, even slots hold values
        c{2*i-1} = names{i};
        c{2*i}   = s.(names{i});
    end
end
