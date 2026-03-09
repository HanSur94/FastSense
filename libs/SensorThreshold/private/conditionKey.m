function key = conditionKey(condStruct)
%CONDITIONKEY Generate a unique string key for a condition struct.
%   Used to group rules with identical conditions for batching.
    fields = sort(fieldnames(condStruct));
    parts = cell(1, numel(fields));
    for i = 1:numel(fields)
        val = condStruct.(fields{i});
        if ischar(val) || isstring(val)
            parts{i} = sprintf('%s=%s', fields{i}, val);
        else
            parts{i} = sprintf('%s=%g', fields{i}, val);
        end
    end
    if isempty(parts)
        key = '__empty__';
    else
        key = strjoin(parts, '&');
    end
end
