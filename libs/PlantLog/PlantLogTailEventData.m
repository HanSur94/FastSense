classdef (ConstructOnLoad) PlantLogTailEventData < event.EventData
%PLANTLOGTAILEVENTDATA Payload class for PlantLogLiveTail's PlantLogTailTick event.
%   PlantLogLiveTail emits a PlantLogTailTick event after every successful
%   tick, whether or not new entries were appended. The event payload is
%   wrapped in this small event.EventData subclass so MATLAB's notify()
%   can deliver typed properties to listener callbacks.
%
%   Properties:
%     Time          double  -- timestamp of the tick (datenum convention; from now())
%     EntriesAdded  double  -- number of new entries appended on this tick
%     TotalCount    double  -- store.getCount() after the tick
%     ErrorCount    double  -- cumulative parse errors since the tail was constructed
%
%   Construction:
%     pd = PlantLogTailEventData(payload)
%       payload is a struct with the four fields above. Missing fields
%       fall back to sensible defaults (0 / now()).
%     pd = PlantLogTailEventData()
%       returns an event with default values; required by MATLAB so that
%       (ConstructOnLoad) classdef arrays can deserialize cleanly.
%
%   Octave note: Octave's event.EventData support is partial. PlantLogLiveTail
%   wraps the notify() call in try/catch and falls back to a payload-less
%   notify(obj, 'PlantLogTailTick') when constructing this class fails. The
%   function-style cross-runtime test gates the payload-shape assertion via
%   `if exist('OCTAVE_VERSION', 'builtin')`.
%
%   See also PlantLogLiveTail.

    properties
        Time         = NaN
        EntriesAdded = 0
        TotalCount   = 0
        ErrorCount   = 0
    end

    methods
        function obj = PlantLogTailEventData(payload)
            %PLANTLOGTAILEVENTDATA Construct from a struct payload (or defaults).
            if nargin < 1 || ~isstruct(payload)
                payload = struct( ...
                    'Time',         now, ...
                    'EntriesAdded', 0, ...
                    'TotalCount',   0, ...
                    'ErrorCount',   0);
            end
            if isfield(payload, 'Time')
                obj.Time = payload.Time;
            end
            if isfield(payload, 'EntriesAdded')
                obj.EntriesAdded = payload.EntriesAdded;
            end
            if isfield(payload, 'TotalCount')
                obj.TotalCount = payload.TotalCount;
            end
            if isfield(payload, 'ErrorCount')
                obj.ErrorCount = payload.ErrorCount;
            end
        end
    end
end
