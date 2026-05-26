function line = ndjsonEncode(s)
%NDJSONENCODE Encode a struct to a single NDJSON line (JSON + newline).
%   Octave 7+ and MATLAB R2020b+ compatible. Pre-converts datetime fields
%   to ISO 8601 UTC strings and int64/uint64 fields to double so that
%   jsonencode succeeds on both runtimes.
%
%   Input:  s   — scalar struct with primitive or char/string field values
%   Output: line — char row vector ending with newline character
%
%   Only flat structs with scalar or char/string fields are supported.
%   Nested structs or cell arrays are passed through as-is to jsonencode.
%
%   See also AtomicWriter, ClusterIdentity.

    fields = fieldnames(s);
    for k = 1:numel(fields)
        v = s.(fields{k});
        if isa(v, 'datetime')
            % Convert datetime to ISO 8601 UTC string before jsonencode.
            % Both MATLAB R2020b+ and Octave 7+ fail on raw datetime objects.
            v.TimeZone = 'UTC';
            s.(fields{k}) = char(v, 'yyyy-MM-dd''T''HH:mm:ss''Z''');
        elseif isa(v, 'int64') || isa(v, 'uint64')
            % int64 -> double: safe for PIDs (all realistic PIDs < 2^53).
            s.(fields{k}) = double(v);
        end
    end
    line = [jsonencode(s), newline()];
end
