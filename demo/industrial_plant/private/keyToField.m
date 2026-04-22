function f = keyToField(key)
%KEYTOFIELD Convert a dotted tag key to a valid MATLAB struct fieldname.
%   f = keyToField('feedline.pressure') -> 'feedline_pressure'
%
%   Used across the demo so plantConfig can key its Units / Ranges /
%   Baselines maps by flat fieldnames while registerPlantTags can look
%   them up given the canonical dotted tag key.

    f = strrep(key, '.', '_');
end
