function [opts, unmatched] = parseOpts(defaults, args, verbose)
%PARSEOPTS Parse name-value pairs against a defaults struct.
%   [opts, unmatched] = parseOpts(defaults, args)
%   [opts, unmatched] = parseOpts(defaults, args, verbose)
%
%   Provides case-insensitive matching of name-value pairs against a
%   defaults struct. Unrecognized keys are returned in the unmatched
%   output, allowing pass-through to other functions (e.g. figure props).
%
%   Inputs:
%     defaults — struct whose field names define valid keys and defaults
%     args     — cell array of name-value pairs (typically varargin)
%     verbose  — (optional) logical, warn on unknown keys (default: false)
%
%   Outputs:
%     opts      — struct with defaults overridden by matched args
%     unmatched — struct of key-value pairs that didn't match any field
%
%   Example:
%     defs.Color = 'r'; defs.Width = 1;
%     [opts, extra] = parseOpts(defs, {'color', 'b', 'Name', 'foo'});
%     % opts.Color = 'b', opts.Width = 1, extra.Name = 'foo'
%
%   See also FastPlot, FastPlotFigure.

    if nargin < 3; verbose = false; end

    opts = defaults;
    unmatched = struct();

    % Pre-compute lowercase field names for case-insensitive matching
    fnames = fieldnames(defaults);
    fnamesLower = lower(fnames);

    for k = 1:2:numel(args)
        key = args{k};
        val = args{k+1};
        keyLower = lower(key);

        idx = find(strcmp(fnamesLower, keyLower), 1);
        if ~isempty(idx)
            opts.(fnames{idx}) = val;
        else
            unmatched.(key) = val;
            if verbose
                warning('FastPlot:unknownOption', ...
                    'Unknown option ''%s''. Valid options: %s', ...
                    key, strjoin(fnames, ', '));
            end
        end
    end
end
