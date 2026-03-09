classdef Sensor < handle
    %SENSOR Represents a sensor with data, state channels, and threshold rules.
    %   s = Sensor('pressure', 'Name', 'Chamber Pressure', 'MatFile', 'data.mat')
    %   s.addStateChannel(stateChannel);
    %   s.addThresholdRule(@(st) st.machine == 1, 50, 'Direction', 'upper');
    %   s.load();
    %   s.resolve();

    properties
        Key           % char: unique identifier
        Name          % char: human-readable display name
        ID            % numeric: sensor ID
        Source        % char: path to original data file
        MatFile       % char: path to .mat file with transformed data
        KeyName       % char: field name in .mat file (defaults to Key)
        X             % array: time data (datenum)
        Y             % array: sensor values (1xN or MxN)
        StateChannels % cell array of StateChannel objects
        ThresholdRules % cell array of ThresholdRule objects
        ResolvedThresholds  % struct: precomputed threshold time series
        ResolvedViolations  % struct: precomputed violation points
        ResolvedStateBands  % struct: precomputed state region bands
        ResolvedConnectors  % struct array: vertical connectors at threshold transitions
    end

    methods
        function obj = Sensor(key, varargin)
            obj.Key = key;
            obj.KeyName = key;
            obj.Name = '';
            obj.ID = [];
            obj.Source = '';
            obj.MatFile = '';
            obj.X = [];
            obj.Y = [];
            obj.StateChannels = {};
            obj.ThresholdRules = {};
            obj.ResolvedThresholds = struct();
            obj.ResolvedViolations = struct();
            obj.ResolvedStateBands = struct();
            obj.ResolvedConnectors = [];

            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Name',     obj.Name = varargin{i+1};
                    case 'ID',       obj.ID = varargin{i+1};
                    case 'Source',   obj.Source = varargin{i+1};
                    case 'MatFile',  obj.MatFile = varargin{i+1};
                    case 'KeyName',  obj.KeyName = varargin{i+1};
                    otherwise
                        error('Sensor:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end

        function load(obj)
            %LOAD Thin wrapper — delegates to external loading library.
            error('Sensor:notImplemented', ...
                'load() is a wrapper for an external loading library. Set X and Y directly or implement your loader.');
        end

        function addStateChannel(obj, sc)
            %ADDSTATECHANNEL Attach a StateChannel to this sensor.
            obj.StateChannels{end+1} = sc;
        end

        function addThresholdRule(obj, conditionFn, value, varargin)
            %ADDTHRESHOLDRULE Add a dynamic threshold rule.
            %   s.addThresholdRule(@(st) st.machine == 1, 50, 'Direction', 'upper')
            rule = ThresholdRule(conditionFn, value, varargin{:});
            obj.ThresholdRules{end+1} = rule;
        end

        function resolve(obj)
            %RESOLVE Precompute threshold time series, violations, and state bands.
            %   Must be called after X, Y, and all StateChannels are loaded.

            nRules = numel(obj.ThresholdRules);

            if nRules == 0
                obj.ResolvedThresholds = [];
                obj.ResolvedViolations = [];
                obj.ResolvedStateBands = [];
                obj.ResolvedConnectors = [];
                return;
            end

            sensorX = obj.X;
            sensorY = obj.Y;
            n = numel(sensorX);

            % Collect all state-change timestamps into a merged time grid
            allTimes = sensorX(:)';
            for i = 1:numel(obj.StateChannels)
                allTimes = [allTimes, obj.StateChannels{i}.X(:)'];
            end
            timeGrid = unique(allTimes);
            timeGrid = sort(timeGrid);

            % Align all state channels to the time grid
            stateValues = struct();
            for i = 1:numel(obj.StateChannels)
                sc = obj.StateChannels{i};
                stateValues.(sc.Key) = alignStateToTime(sc.X, sc.Y, timeGrid);
            end

            % Also align states to sensor timestamps for violation detection
            sensorStates = struct();
            for i = 1:numel(obj.StateChannels)
                sc = obj.StateChannels{i};
                sensorStates.(sc.Key) = alignStateToTime(sc.X, sc.Y, sensorX);
            end

            % Evaluate each rule across time grid → build stepped threshold line
            resolvedTh = [];
            resolvedViol = [];
            for r = 1:nRules
                rule = obj.ThresholdRules{r};

                % Build threshold time series on the merged time grid
                thY = NaN(1, numel(timeGrid));
                for k = 1:numel(timeGrid)
                    st = obj.buildStateStruct(stateValues, k);
                    if rule.ConditionFn(st)
                        thY(k) = rule.Value;
                    end
                end

                % Store resolved threshold
                th.X = timeGrid;
                th.Y = thY;
                th.Direction = rule.Direction;
                th.Label = rule.Label;
                th.Color = rule.Color;
                th.LineStyle = rule.LineStyle;
                th.Value = rule.Value;

                % Compute violations on sensor data
                % For each sensor point, check if the rule is active and violated
                vX = [];
                vY = [];
                for k = 1:n
                    st = obj.buildStateStruct(sensorStates, k);
                    if rule.ConditionFn(st)
                        if strcmp(rule.Direction, 'upper') && sensorY(k) > rule.Value
                            vX(end+1) = sensorX(k);
                            vY(end+1) = sensorY(k);
                        elseif strcmp(rule.Direction, 'lower') && sensorY(k) < rule.Value
                            vX(end+1) = sensorX(k);
                            vY(end+1) = sensorY(k);
                        end
                    end
                end

                viol.X = vX;
                viol.Y = vY;
                viol.Direction = rule.Direction;
                viol.Label = rule.Label;

                if isempty(resolvedTh)
                    resolvedTh = th;
                    resolvedViol = viol;
                else
                    resolvedTh(end+1) = th;
                    resolvedViol(end+1) = viol;
                end
            end

            obj.ResolvedThresholds = resolvedTh;
            obj.ResolvedViolations = resolvedViol;
            obj.ResolvedStateBands = struct(); % placeholder for state shading

            % Build vertical connectors at threshold level transitions
            connectors = [];
            for dir = {'upper', 'lower'}
                d = dir{1};
                % Find rules matching this direction
                ruleIdx = [];
                for r = 1:numel(resolvedTh)
                    if strcmp(resolvedTh(r).Direction, d)
                        ruleIdx(end+1) = r;
                    end
                end
                if numel(ruleIdx) < 2; continue; end

                % At each time point, determine the active value and color
                nT = numel(timeGrid);
                activeVal = NaN(1, nT);
                activeColor = cell(1, nT);
                for k = 1:nT
                    for ri = ruleIdx
                        if ~isnan(resolvedTh(ri).Y(k))
                            activeVal(k) = resolvedTh(ri).Y(k);
                            activeColor{k} = resolvedTh(ri).Color;
                            break;
                        end
                    end
                end

                % Find transitions where value changes
                for k = 2:nT
                    if ~isnan(activeVal(k-1)) && ~isnan(activeVal(k)) ...
                            && activeVal(k-1) ~= activeVal(k)
                        conn.X = [timeGrid(k), timeGrid(k)];
                        conn.Y = [activeVal(k-1), activeVal(k)];
                        conn.Color = activeColor{k};
                        conn.Direction = d;
                        if isempty(connectors)
                            connectors = conn;
                        else
                            connectors(end+1) = conn;
                        end
                    end
                end
            end
            obj.ResolvedConnectors = connectors;
        end

        function active = getThresholdsAt(obj, t)
            %GETTHRESHOLDSAT Evaluate all rules at a single time point.
            %   Returns struct array of active thresholds at time t.

            active = [];
            st = struct();
            for i = 1:numel(obj.StateChannels)
                sc = obj.StateChannels{i};
                st.(sc.Key) = sc.valueAt(t);
            end

            for r = 1:numel(obj.ThresholdRules)
                rule = obj.ThresholdRules{r};
                if rule.ConditionFn(st)
                    entry.Value = rule.Value;
                    entry.Direction = rule.Direction;
                    entry.Label = rule.Label;
                    if isempty(active)
                        active = entry;
                    else
                        active(end+1) = entry;
                    end
                end
            end
        end
    end

    methods (Access = private)
        function st = buildStateStruct(obj, alignedStates, idx)
            %BUILDSTATESTRUCT Build state struct for a single time index.
            st = struct();
            fields = fieldnames(alignedStates);
            for f = 1:numel(fields)
                vals = alignedStates.(fields{f});
                if iscell(vals)
                    st.(fields{f}) = vals{idx};
                else
                    st.(fields{f}) = vals(idx);
                end
            end
        end
    end
end
