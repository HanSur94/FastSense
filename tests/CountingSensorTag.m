classdef CountingSensorTag < SensorTag
%COUNTINGSENSORTAG Test helper — SensorTag subclass that counts getXY calls.
%
%   Used by test_dashboard_load_perf.m (260610-ov3) to verify that a single
%   render() pass calls Tag.getXY at most once (down from 3-4 pre-cache).
%
%   Usage:
%     tag = CountingSensorTag('key', 'X', x, 'Y', y);
%     w.render(hp);
%     assert(tag.getXYCallCount <= 1);

    properties (Access = private)
        GetXYCallCount_ = 0
    end

    properties (Dependent)
        getXYCallCount
    end

    methods
        function obj = CountingSensorTag(key, varargin)
        %COUNTINGSENSORTAG Construct and reset the call counter.
            obj = obj@SensorTag(key, varargin{:});
            obj.GetXYCallCount_ = 0;
        end

        function n = get.getXYCallCount(obj)
        %GETXYCALLCOUNT Return number of times getXY was called.
            n = obj.GetXYCallCount_;
        end

        function [x, y] = getXY(obj)
        %GETXY Override to count calls then delegate to SensorTag.getXY.
            obj.GetXYCallCount_ = obj.GetXYCallCount_ + 1;
            [x, y] = getXY@SensorTag(obj);
        end

        function resetCount(obj)
        %RESETCOUNT Reset getXY call counter to zero.
            obj.GetXYCallCount_ = 0;
        end
    end
end
