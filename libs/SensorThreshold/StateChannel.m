classdef StateChannel < handle
    %STATECHANNEL Discrete state signal with zero-order hold lookup.
    %   StateChannel models a piecewise-constant ("zero-order hold") time
    %   series representing a discrete system state (e.g., machine mode,
    %   recipe phase).  Given a query time, it returns the most recent
    %   known state value.  The class supports both numeric and
    %   string/categorical state values.
    %
    %   StateChannel is used by Sensor to condition ThresholdRule
    %   evaluation: each Sensor may reference one or more StateChannels
    %   whose values determine which threshold rules are active at any
    %   given moment.
    %
    %   StateChannel Properties:
    %     Key     — unique string identifier for this channel
    %     MatFile — path to the .mat file containing the raw data
    %     KeyName — field name inside the .mat file (defaults to Key)
    %     X       — 1xN sorted datenum timestamps of state transitions
    %     Y       — 1xN state values (numeric array or cell array of char)
    %
    %   StateChannel Methods:
    %     StateChannel — Constructor; accepts key and name-value options
    %     load         — Load data from external source (placeholder)
    %     valueAt      — Zero-order-hold lookup at one or more query times
    %
    %   Example:
    %     sc = StateChannel('machine', 'MatFile', 'data/states.mat');
    %     sc.X = [737000, 737001, 737002];
    %     sc.Y = [0, 1, 2];
    %     val = sc.valueAt(737001.5);   % returns 1
    %
    %   See also Sensor, ThresholdRule, alignStateToTime.

    properties
        Key       % char: unique string identifier for this state channel
        MatFile   % char: path to .mat file containing the state data
        KeyName   % char: field name in .mat file (defaults to Key)
        X         % 1xN datenum: sorted timestamps of state transitions
        Y         % 1xN numeric or 1xN cell: state values at each transition
    end

    methods
        function obj = StateChannel(key, varargin)
            %STATECHANNEL Construct a StateChannel object.
            %   sc = StateChannel(key) creates a channel with the given
            %   identifier and default properties.
            %
            %   sc = StateChannel(key, Name, Value, ...) additionally sets
            %   optional name-value pairs:
            %     'MatFile' — char, path to .mat file
            %     'KeyName' — char, field name in .mat (defaults to key)
            %
            %   Input:
            %     key — char, unique identifier for this channel
            %
            %   Output:
            %     obj — StateChannel object
            %
            %   See also StateChannel.load, StateChannel.valueAt.

            obj.Key = key;
            obj.KeyName = key;        % Default: same as Key
            obj.MatFile = '';
            obj.X = [];
            obj.Y = [];

            % Parse optional name-value pairs
            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'MatFile'
                        obj.MatFile = varargin{i+1};
                    case 'KeyName'
                        obj.KeyName = varargin{i+1};
                    otherwise
                        error('StateChannel:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end

        function load(obj)
            %LOAD Load state data from the external data source.
            %   sc.load() populates sc.X and sc.Y by loading the file
            %   specified in sc.MatFile.  This is a placeholder that must
            %   be overridden or extended to integrate with your project's
            %   data loading library.  Alternatively, set X and Y directly.
            %
            %   See also StateChannel.valueAt.

            error('StateChannel:notImplemented', ...
                'load() is a wrapper for an external loading library. Set X and Y directly or implement your loader.');
        end

        function val = valueAt(obj, t)
            %VALUEAT Return state value at time t using zero-order hold.
            %   val = sc.valueAt(t) performs a zero-order hold lookup: it
            %   returns the last state value whose transition timestamp is
            %   at or before the query time t.  If t precedes the first
            %   timestamp, the first state value is returned (clamp).
            %
            %   Supports both scalar and vector queries:
            %     val  = sc.valueAt(5.0)       — single scalar query
            %     vals = sc.valueAt([1 2 3])   — vectorized bulk query
            %
            %   Input:
            %     t — scalar or 1xN double, query time(s) in datenum
            %
            %   Output:
            %     val — state value(s); numeric scalar/array or char/cell
            %           depending on the type of Y
            %
            %   See also StateChannel.bsearchRight, alignStateToTime.

            if isscalar(t)
                % --- Scalar path: single binary search lookup ---
                idx = obj.bsearchRight(t);
                if iscell(obj.Y)
                    val = obj.Y{idx};
                else
                    val = obj.Y(idx);
                end
            else
                % --- Vector path: loop over each query time ---
                n = numel(t);
                if iscell(obj.Y)
                    val = cell(1, n);
                    for k = 1:n
                        idx = obj.bsearchRight(t(k));
                        val{k} = obj.Y{idx};
                    end
                else
                    val = zeros(1, n);
                    for k = 1:n
                        idx = obj.bsearchRight(t(k));
                        val(k) = obj.Y(idx);
                    end
                end
            end
        end
    end

    methods (Access = private)
        function idx = bsearchRight(obj, val)
            %BSEARCHRIGHT Last index where X(idx) <= val, clamped to [1, N].
            %   idx = bsearchRight(obj, val) performs a right-biased binary
            %   search on obj.X, returning the largest index i such that
            %   X(i) <= val.  The result is clamped to [1, numel(X)] so
            %   that queries before the first timestamp return index 1.
            %
            %   Input:
            %     val — scalar double, the query value
            %
            %   Output:
            %     idx — scalar integer, 1-based index into X/Y
            %
            %   See also binary_search.

            idx = binary_search(obj.X, val, 'right');
        end
    end
end
