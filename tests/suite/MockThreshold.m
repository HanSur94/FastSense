classdef MockThreshold < handle
%MOCKTHRESHOLD Minimal threshold stub for testing isThresholdViolated.
%   Exposes the IsUpper property and allValues() method (plus Color) that the
%   dashboard widgets and isThresholdViolated rely on, without depending on the
%   full SensorThreshold class graph.
%
%   Usage:
%     t = MockThreshold(true, 10);        % upper limit at 10
%     t = MockThreshold(false, [2 5]);    % lower limit, composite values

    properties
        IsUpper = true
        Values  = []
        Color   = []
    end

    methods
        function obj = MockThreshold(isUpper, values)
            if nargin >= 1, obj.IsUpper = isUpper; end
            if nargin >= 2, obj.Values = values; end
        end

        function vals = allValues(obj)
            vals = obj.Values;
        end
    end
end
