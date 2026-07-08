function warnUnknownOpts_(method, unmatched, validFields)
%WARNUNKNOWNOPTS_ Warn (non-fatally) for unrecognized name-value options.
%   warnUnknownOpts_(METHOD, UNMATCHED, VALIDFIELDS) emits a
%   FastSense:unknownOption warning for each field of the UNMATCHED struct
%   returned by parseOpts, naming the calling METHOD and listing the
%   VALIDFIELDS the method accepts.
%
%   Closed-option-set FastSense methods (addThreshold, addBand, addMarker,
%   addShaded) previously discarded misspelled options silently — e.g.
%   addThreshold(5, 'Colour', 'r') did nothing and said nothing. This
%   surfaces the mistake, mirroring the FastSense constructor's
%   reject-unknown-keys house convention, but as a WARNING rather than an
%   error so existing scripts keep running unchanged (backward-compatible).
%
%   Inputs:
%     method      — char, the calling method name (for the message context)
%     unmatched   — struct of unrecognized name-value pairs (parseOpts output)
%     validFields — cellstr of the option names the method accepts
%
%   This is a private helper for FastSense.
%
%   See also parseOpts, FastSense.

    if nargin < 2 || isempty(unmatched)
        return;
    end
    keys = fieldnames(unmatched);
    for i = 1:numel(keys)
        warning('FastSense:unknownOption', ...
            '%s: unknown option ''%s'' ignored. Valid options: %s', ...
            method, keys{i}, strjoin(validFields, ', '));
    end
end
