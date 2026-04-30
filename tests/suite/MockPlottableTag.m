classdef MockPlottableTag < SensorTag
%MOCKPLOTTABLETAG SensorTag fixture with controllable getXY for openAdHocPlot tests.
%   Used by libs/FastSenseCompanion/private/runOpenAdHocPlotTests.m and
%   tests/suite/TestFastSenseCompanion.m ADHOC tests to drive openAdHocPlot
%   without FastSenseDataStore overhead.
%
%   Behavior modes (set via Behavior property AFTER construction):
%     'Default'     - getXY returns stored X, Y (the SensorTag X/Y inputs)
%     'ReturnEmpty' - getXY returns ([], []) so helper marks tag as 'no data'
%     'Throw'       - getXY errors with MockPlottableTag:intentionalGetXYError
%
%   Default Behavior is 'Default' on construction.
%
%   Example:
%     m = MockPlottableTag('mock_a', 'Name', 'Mock A', 'X', 1:5, 'Y', 1:5);
%     m.Behavior = 'Throw';
%     try; m.getXY(); catch ME; disp(ME.identifier); end
%     % -> MockPlottableTag:intentionalGetXYError
%
%   See also SensorTag, MockTagThrowingGetXY, openAdHocPlot.

    properties (Access = public)
        Behavior = 'Default'   % 'Default' | 'ReturnEmpty' | 'Throw'
    end

    methods
        function obj = MockPlottableTag(varargin)
        %MOCKPLOTTABLETAG Construct via SensorTag superclass (passthrough varargin).
            obj@SensorTag(varargin{:});
        end

        function [x, y] = getXY(obj)
        %GETXY Return stored X/Y, empty, or throw — based on Behavior.
            switch obj.Behavior
                case 'Default'
                    [x, y] = getXY@SensorTag(obj);
                case 'ReturnEmpty'
                    x = [];
                    y = [];
                case 'Throw'
                    error('MockPlottableTag:intentionalGetXYError', ...
                        'MockPlottableTag.getXY intentionally fails (Behavior=Throw).');
                otherwise
                    error('MockPlottableTag:invalidBehavior', ...
                        'Unknown Behavior ''%s''. Valid: Default | ReturnEmpty | Throw.', ...
                        char(obj.Behavior));
            end
        end
    end
end
