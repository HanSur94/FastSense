function key = conditionKey(condStruct)
%CONDITIONKEY Generate a unique string key for a condition struct.
%   Used to group rules with identical conditions for batching.
    fields = sort(fieldnames(condStruct));
    parts = cell(1, numel(fields));
    for i = 1:numel(fields)
        parts{i} = sprintf('%s=%g', fields{i}, condStruct.(fields{i}));
    end
    if isempty(parts)
        key = '__empty__';
    else
        key = strjoin(parts, '&');
    end
end
