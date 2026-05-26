classdef LiveModeCapture < handle
%LIVEMODECAPTURE Tiny test helper — accumulates booleans into Vals.
    properties
        Vals = logical([])
    end
    methods
        function push(obj, v)
            obj.Vals(end+1) = logical(v);
        end
    end
end
