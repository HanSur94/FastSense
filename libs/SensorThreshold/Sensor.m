classdef Sensor < handle
    %SENSOR Represents a sensor with data, state channels, and threshold rules.
    %   s = Sensor('pressure', 'Name', 'Chamber Pressure', 'MatFile', 'data.mat')
    %   s.addStateChannel(stateChannel);
    %   s.addThresholdRule(struct('machine', 1), 50, 'Direction', 'upper');
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

        function addThresholdRule(obj, condition, value, varargin)
            %ADDTHRESHOLDRULE Add a dynamic threshold rule.
            %   s.addThresholdRule(struct('machine', 1), 50, 'Direction', 'upper')
            rule = ThresholdRule(condition, value, varargin{:});
            obj.ThresholdRules{end+1} = rule;
        end

        function resolve(obj)
            %RESOLVE Precompute threshold time series, violations, and state bands.
            %   Segment-based algorithm: evaluates conditions at state-change
            %   boundaries, then vectorizes violation detection within active segments.

            nRules = numel(obj.ThresholdRules);

            if nRules == 0
                obj.ResolvedThresholds = [];
                obj.ResolvedViolations = [];
                obj.ResolvedStateBands = [];
                return;
            end

            sensorX = obj.X;
            sensorY = obj.Y;

            % --- Step 1: Find segment boundaries from state channels ---
            nChannels = numel(obj.StateChannels);

            if nChannels == 0
                % No state channels — single segment spanning all data
                segBounds = [sensorX(1), sensorX(end)];
            else
                % Merge all state-change timestamps
                allChanges = [];
                for i = 1:nChannels
                    allChanges = [allChanges, obj.StateChannels{i}.X(:)'];
                end
                segBounds = unique(allChanges);

                % Ensure we cover the full sensor data range
                if segBounds(1) > sensorX(1)
                    segBounds = [sensorX(1), segBounds];
                end
                if segBounds(end) < sensorX(end)
                    segBounds = [segBounds, sensorX(end)];
                end
            end

            nSegs = numel(segBounds);

            % --- Step 2: Evaluate state at each segment boundary ---
            segStates = cell(1, nSegs);
            for s = 1:nSegs
                st = struct();
                for i = 1:nChannels
                    sc = obj.StateChannels{i};
                    st.(sc.Key) = sc.valueAt(segBounds(s));
                end
                segStates{s} = st;
            end

            % --- Step 3: Group rules by condition for batching ---
            condKeys = cell(1, nRules);
            for r = 1:nRules
                condKeys{r} = conditionKey(obj.ThresholdRules{r}.Condition);
            end

            [uniqueKeys, ~, groupIdx] = unique(condKeys);
            nGroups = numel(uniqueKeys);

            % --- Step 4: For each condition group, find active segments once ---
            resolvedTh = [];
            resolvedViol = [];

            for g = 1:nGroups
                ruleIndices = find(groupIdx == g);
                refRule = obj.ThresholdRules{ruleIndices(1)};

                % Evaluate condition at each segment boundary
                segActive = false(1, nSegs);
                for s = 1:nSegs
                    segActive(s) = refRule.matchesState(segStates{s});
                end

                % Find [lo, hi] index ranges in sensorX for each active segment
                activeSegs = find(segActive);
                nActive = numel(activeSegs);

                if nActive == 0
                    % No active segments — all rules in this group have no violations
                    for ri = 1:numel(ruleIndices)
                        r = ruleIndices(ri);
                        rule = obj.ThresholdRules{r};
                        th = buildThresholdEntry(segBounds, NaN(1, nSegs), rule);
                        viol = struct('X', [], 'Y', [], 'Direction', rule.Direction, 'Label', rule.Label);
                        [resolvedTh, resolvedViol] = appendResults(resolvedTh, resolvedViol, th, viol);
                    end
                    continue;
                end

                segLo = zeros(1, nActive);
                segHi = zeros(1, nActive);
                for a = 1:nActive
                    si = activeSegs(a);
                    segStart = segBounds(si);
                    if si < nSegs
                        segEnd = segBounds(si + 1);
                    else
                        segEnd = sensorX(end);
                    end

                    segLo(a) = binary_search(sensorX, segStart, 'left');
                    if si < nSegs
                        % Exclusive end: last point strictly before next segment
                        segHi(a) = binary_search(sensorX, segEnd, 'left') - 1;
                        if segHi(a) < segLo(a)
                            segHi(a) = segLo(a);
                        end
                    else
                        segHi(a) = numel(sensorX);
                    end
                end

                % --- Step 5: Vectorized violation detection for each rule in group ---
                nBatchRules = numel(ruleIndices);
                thresholdValues = zeros(1, nBatchRules);
                directions = zeros(1, nBatchRules);
                for ri = 1:nBatchRules
                    rule = obj.ThresholdRules{ruleIndices(ri)};
                    thresholdValues(ri) = rule.Value;
                    directions(ri) = strcmp(rule.Direction, 'upper');
                end

                % Try MEX path, fall back to vectorized MATLAB
                batchViolIdx = compute_violations_batch(sensorY, segLo, segHi, ...
                    thresholdValues, directions);

                % Build output for each rule in the group
                for ri = 1:nBatchRules
                    r = ruleIndices(ri);
                    rule = obj.ThresholdRules{r};

                    % Build threshold time series (stepped line at boundaries)
                    thY = NaN(1, nSegs);
                    for s = 1:nSegs
                        if segActive(s)
                            thY(s) = rule.Value;
                        end
                    end
                    th = buildThresholdEntry(segBounds, thY, rule);

                    % Build violation output
                    vIdx = batchViolIdx{ri};
                    viol.X = sensorX(vIdx);
                    viol.Y = sensorY(vIdx);
                    viol.Direction = rule.Direction;
                    viol.Label = rule.Label;

                    [resolvedTh, resolvedViol] = appendResults(resolvedTh, resolvedViol, th, viol);
                end
            end

            obj.ResolvedThresholds = resolvedTh;
            obj.ResolvedViolations = resolvedViol;
            obj.ResolvedStateBands = struct();
        end

        function active = getThresholdsAt(obj, t)
            %GETTHRESHOLDSAT Evaluate all rules at a single time point.
            active = [];
            st = struct();
            for i = 1:numel(obj.StateChannels)
                sc = obj.StateChannels{i};
                st.(sc.Key) = sc.valueAt(t);
            end

            for r = 1:numel(obj.ThresholdRules)
                rule = obj.ThresholdRules{r};
                if rule.matchesState(st)
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

end
