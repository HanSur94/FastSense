function key = conditionKey(condStruct)
%CONDITIONKEY Generate a unique, deterministic string key for a condition struct.
%   key = CONDITIONKEY(condStruct) serializes a condition struct into a
%   canonical string so that two structs with the same fields and values
%   always produce the same key, regardless of field ordering.  This is
%   used by Sensor.resolve() to group conditions that share
%   identical conditions and can therefore share the same active-segment
%   computation.
%
%   Format: fields are sorted alphabetically and joined with '&'.  Each
%   field produces a 'name=value' token.  An empty struct yields the
%   sentinel key '__empty__'.
%
%   Examples:
%     conditionKey(struct('machine', 1, 'vacuum', 2))
%       => 'machine=1&vacuum=2'
%     conditionKey(struct())
%       => '__empty__'
%
%   Input:
%     condStruct — struct (may be empty) whose field names are state
%                  channel keys and values are the required states
%
%   Output:
%     key — char, canonical string representation of the condition
%
%   See also Sensor.resolve, ThresholdRule.

    % Sort field names for deterministic ordering
    fields = sort(fieldnames(condStruct));
    parts = cell(1, numel(fields));

    for i = 1:numel(fields)
        val = condStruct.(fields{i});
        % Format value according to type
        if ischar(val) || isstring(val)
            parts{i} = sprintf('%s=%s', fields{i}, val);
        else
            parts{i} = sprintf('%s=%g', fields{i}, val);
        end
    end

    % Return sentinel for empty (unconditional) conditions
    if isempty(parts)
        key = '__empty__';
    else
        key = strjoin(parts, '&');
    end
end
