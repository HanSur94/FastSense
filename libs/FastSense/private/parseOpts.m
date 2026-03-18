function [opts, unmatched] = parseOpts(defaults, args, verbose)
%PARSEOPTS Parse name-value pairs against a defaults struct.
%   [opts, unmatched] = PARSEOPTS(defaults, args) matches each name in the
%   cell array args against the field names of defaults (case-insensitive).
%   Matched names override the corresponding default value; unrecognized
%   names are collected into the unmatched output struct for pass-through
%   to other functions (e.g., figure or axes properties).
%
%   [opts, unmatched] = PARSEOPTS(defaults, args, verbose) additionally
%   emits a warning for every unrecognized option when verbose is true.
%
%   This function is a private helper for FastSense.
%
%   Inputs:
%     defaults — scalar struct whose field names define valid option keys
%                and whose values provide the defaults (any type)
%     args     — cell array of name-value pairs, typically varargin from
%                the caller; must have an even number of elements
%     verbose  — (optional) logical scalar. When true, a warning is issued
%                for each key in args that does not match a field in
%                defaults. Default: false.
%
%   Outputs:
%     opts      — struct with the same fields as defaults, where matched
%                 args override the default values
%     unmatched — struct containing any name-value pairs from args whose
%                 names did not match a field in defaults (original casing
%                 is preserved)
%
%   Example:
%     defs.Color = 'r'; defs.Width = 1;
%     [opts, extra] = parseOpts(defs, {'color', 'b', 'Name', 'foo'});
%     % opts.Color == 'b', opts.Width == 1, extra.Name == 'foo'
%
%   See also FastSense, FastSenseGrid, struct2nvpairs.

    if nargin < 3; verbose = false; end

    opts = defaults;
    unmatched = struct();

    % Pre-compute lowercase field names once for O(1)-per-lookup matching
    fnames = fieldnames(defaults);
    fnamesLower = lower(fnames);

    % Iterate over name-value pairs (step by 2)
    for k = 1:2:numel(args)
        key = args{k};
        val = args{k+1};
        keyLower = lower(key);

        % Case-insensitive lookup against the defaults struct fields
        idx = find(strcmp(fnamesLower, keyLower), 1);
        if ~isempty(idx)
            % Matched — override the default with the caller's value
            opts.(fnames{idx}) = val;
        else
            % Unmatched — collect for pass-through
            unmatched.(key) = val;
            if verbose
                warning('FastSense:unknownOption', ...
                    'Unknown option ''%s''. Valid options: %s', ...
                    key, strjoin(fnames, ', '));
            end
        end
    end
end
