classdef MockTagThrowingGetXY < SensorTag
%MOCKTAGTHROWINGGETXY SensorTag whose getXY throws (sparkline failure path).
%   Used by TestInspectorPane.testINSPECT06_sparklineFailureFallsBackToLabel
%   to exercise the 'Sparkline unavailable' fallback branch in InspectorPane.
%
%   See also SensorTag, TestInspectorPane, InspectorPane.

    methods
        function obj = MockTagThrowingGetXY(varargin)
        %MOCKTAGTHROWINGGETXY Construct via SensorTag superclass.
            obj@SensorTag(varargin{:});
        end

        function [x, y] = getXY(obj) %#ok<MANU,STOUT>
        %GETXY Intentionally throws to exercise sparkline error path.
            error('MockTag:getXYFailure', 'getXY intentionally fails for test.');
        end
    end

end
