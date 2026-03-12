classdef Sensor < handle
    %SENSOR Represents a sensor with data, state channels, and threshold rules.
    %   Sensor is the central class of the SensorThreshold library.  It
    %   bundles raw time-series data (X, Y) with a set of StateChannels
    %   (discrete system states) and ThresholdRules (condition-dependent
    %   limit values).  The resolve() method evaluates all rules against
    %   the state channels to produce pre-computed threshold time series,
    %   violation indices, and state-band regions that can be rendered by
    %   a plotting layer such as FastPlot.
    %
    %   Typical workflow:
    %     1. Create a Sensor and set X/Y data (or call load()).
    %     2. Attach one or more StateChannels via addStateChannel().
    %     3. Define threshold rules via addThresholdRule().
    %     4. Call resolve() to pre-compute thresholds and violations.
    %     5. Read ResolvedThresholds / ResolvedViolations for rendering.
    %
    %   Sensor Properties:
    %     Key                — unique string identifier
    %     Name               — human-readable display name
    %     ID                 — numeric sensor ID
    %     Source             — path to the original data file
    %     MatFile            — path to .mat file with transformed data
    %     KeyName            — field name inside the .mat file
    %     X                  — 1xN datenum time stamps
    %     Y                  — 1xN (or MxN) sensor values
    %     StateChannels      — cell array of attached StateChannel objects
    %     ThresholdRules     — cell array of attached ThresholdRule objects
    %     ResolvedThresholds — struct array of precomputed threshold lines
    %     ResolvedViolations — struct array of precomputed violation points
    %     ResolvedStateBands — struct of precomputed state region bands
    %
    %   Sensor Methods:
    %     Sensor           — Constructor with key and name-value options
    %     load             — Load data from external source (placeholder)
    %     addStateChannel  — Attach a StateChannel to this sensor
    %     addThresholdRule — Add a conditional threshold rule
    %     resolve          — Precompute thresholds, violations, state bands
    %     getThresholdsAt  — Evaluate active rules at a single time point
    %
    %   Example:
    %     s = Sensor('pressure', 'Name', 'Chamber Pressure', 'ID', 101);
    %     sc = StateChannel('machine');
    %     sc.X = [0, 10, 20];  sc.Y = [0, 1, 0];
    %     s.addStateChannel(sc);
    %     s.addThresholdRule(struct('machine', 1), 50, ...
    %         'Direction', 'upper', 'Label', 'Pressure HH');
    %     s.X = linspace(0, 30, 1000);
    %     s.Y = randn(1, 1000) * 20 + 40;
    %     s.resolve();
    %
    %   See also StateChannel, ThresholdRule, SensorRegistry.

    properties
        Key           % char: unique string identifier for this sensor
        Name          % char: human-readable display name
        ID            % numeric: sensor ID (e.g., from a database)
        Source        % char: path to the original raw data file
        MatFile       % char: path to .mat file with transformed data
        KeyName       % char: field name in .mat file (defaults to Key)
        X             % 1xN double: datenum time stamps
        Y             % 1xN (or MxN) double: sensor values
        StateChannels % cell array of StateChannel objects
        ThresholdRules % cell array of ThresholdRule objects
        ResolvedThresholds  % struct array: precomputed threshold step-function lines
        ResolvedViolations  % struct array: precomputed violation (X,Y) points
        ResolvedStateBands  % struct: precomputed state region bands for shading
    end

    methods
        function obj = Sensor(key, varargin)
            %SENSOR Construct a Sensor object.
            %   s = Sensor(key) creates a sensor with the given string
            %   identifier and default property values.
            %
            %   s = Sensor(key, Name, Value, ...) additionally sets
            %   optional name-value pairs:
            %     'Name'    — char, human-readable name
            %     'ID'      — numeric, sensor ID
            %     'Source'  — char, original file path
            %     'MatFile' — char, .mat file path
            %     'KeyName' — char, field name in .mat (defaults to key)
            %
            %   Input:
            %     key — char, unique identifier string
            %
            %   Output:
            %     obj — Sensor object
            %
            %   See also Sensor.load, Sensor.addStateChannel,
            %            Sensor.addThresholdRule, Sensor.resolve.

            % Initialize all properties to safe defaults
            obj.Key = key;
            obj.KeyName = key;           % Default: same as Key
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

            % Parse optional name-value pairs
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
            %LOAD Load sensor data from the external data source.
            %   s.load() populates s.X and s.Y by loading the file
            %   specified in s.MatFile.  This is a placeholder that must
            %   be overridden or extended to integrate with your project's
            %   data loading library.  Alternatively, set X and Y directly.
            %
            %   See also Sensor.resolve.

            error('Sensor:notImplemented', ...
                'load() is a wrapper for an external loading library. Set X and Y directly or implement your loader.');
        end

        function addStateChannel(obj, sc)
            %ADDSTATECHANNEL Attach a StateChannel to this sensor.
            %   s.addStateChannel(sc) appends the given StateChannel
            %   object to the sensor's StateChannels list.  During
            %   resolve(), each attached channel's key becomes a field in
            %   the state struct used to evaluate ThresholdRule conditions.
            %
            %   Input:
            %     sc — StateChannel object with populated X and Y
            %
            %   See also Sensor.addThresholdRule, Sensor.resolve.

            obj.StateChannels{end+1} = sc;
        end

        function addThresholdRule(obj, condition, value, varargin)
            %ADDTHRESHOLDRULE Add a dynamic threshold rule to this sensor.
            %   s.addThresholdRule(condition, value, Name, Value, ...)
            %   creates a new ThresholdRule and appends it to the sensor's
            %   ThresholdRules list.  All additional name-value arguments
            %   are forwarded to the ThresholdRule constructor.
            %
            %   Inputs:
            %     condition — struct defining required state values
            %     value     — numeric threshold value
            %     varargin  — name-value pairs forwarded to ThresholdRule
            %                 (e.g., 'Direction', 'upper', 'Label', 'HH')
            %
            %   Example:
            %     s.addThresholdRule(struct('machine', 1), 50, ...
            %         'Direction', 'upper', 'Label', 'Pressure HH');
            %
            %   See also ThresholdRule, Sensor.resolve.

            rule = ThresholdRule(condition, value, varargin{:});
            obj.ThresholdRules{end+1} = rule;
        end

        function resolve(obj)
            %RESOLVE Precompute threshold time series, violations, and state bands.
            %   s.resolve() evaluates all ThresholdRules against the
            %   attached StateChannels and the sensor's own X/Y data.
            %   Results are stored in the ResolvedThresholds,
            %   ResolvedViolations, and ResolvedStateBands properties.
            %
            %   Algorithm overview (segment-based):
            %     1. Collect all state-change timestamps from every
            %        StateChannel to define segment boundaries.
            %     2. Evaluate the composite state struct at each boundary.
            %     3. Group ThresholdRules that share the same condition
            %        (via conditionKey) so that condition matching is done
            %        once per unique condition rather than once per rule.
            %     4. For each condition group, identify the active
            %        segments (where the condition is satisfied) and map
            %        them to index ranges in sensorX.
            %     5. Batch-detect violations within active segments using
            %        compute_violations_batch (MEX or vectorized MATLAB).
            %     6. Merge threshold entries that share the same
            %        Label+Direction into single step-function lines via
            %        mergeResolvedByLabel.
            %
            %   The method is idempotent: calling it again overwrites the
            %   previous resolved results.
            %
            %   See also Sensor.getThresholdsAt, compute_violations_batch,
            %            mergeResolvedByLabel, buildThresholdEntry.

            nRules = numel(obj.ThresholdRules);

            % Early exit when no rules are defined
            if nRules == 0
                obj.ResolvedThresholds = [];
                obj.ResolvedViolations = [];
                obj.ResolvedStateBands = [];
                return;
            end

            % Cache sensor data locally to avoid repeated property access
            sensorX = obj.X;
            sensorY = obj.Y;

            % -------------------------------------------------------
            % Step 1: Find segment boundaries from state channels
            % -------------------------------------------------------
            % Each state channel contributes its transition timestamps.
            % The union of all transitions defines the segment grid on
            % which conditions are evaluated.
            nChannels = numel(obj.StateChannels);

            if nChannels == 0
                % No state channels -- treat the entire time span as one
                % segment (unconditional rules only).
                segBounds = [sensorX(1), sensorX(end)];
            else
                % Merge all state-change timestamps from every channel
                allChanges = [];
                for i = 1:nChannels
                    allChanges = [allChanges, obj.StateChannels{i}.X(:)'];
                end
                segBounds = unique(allChanges);

                % Extend boundaries to cover the full sensor data range
                if segBounds(1) > sensorX(1)
                    segBounds = [sensorX(1), segBounds];
                end
                if segBounds(end) < sensorX(end)
                    segBounds = [segBounds, sensorX(end)];
                end
            end

            nSegs = numel(segBounds);

            % -------------------------------------------------------
            % Step 2: Evaluate the composite state at each boundary
            % -------------------------------------------------------
            % Build a state struct for every segment boundary by querying
            % each StateChannel via zero-order hold.
            segStates = cell(1, nSegs);
            for s = 1:nSegs
                st = struct();
                for i = 1:nChannels
                    sc = obj.StateChannels{i};
                    st.(sc.Key) = sc.valueAt(segBounds(s));
                end
                segStates{s} = st;
            end

            % -------------------------------------------------------
            % Step 3: Group rules by condition for batching
            % -------------------------------------------------------
            % Rules with identical conditions share the same active
            % segments, so grouping avoids redundant matchesState calls.
            % Use pre-cached condition keys from ThresholdRule for speed.
            condKeys = cell(1, nRules);
            for r = 1:nRules
                condKeys{r} = obj.ThresholdRules{r}.CachedConditionKey;
            end

            [uniqueKeys, ~, groupIdx] = unique(condKeys);
            nGroups = numel(uniqueKeys);

            % -------------------------------------------------------
            % Step 4: For each condition group, find active segments
            % -------------------------------------------------------
            resolvedTh = [];
            resolvedViol = [];

            for g = 1:nGroups
                % Indices of rules that belong to this condition group
                ruleIndices = find(groupIdx == g);

                % Use the first rule as the representative for condition
                % matching (all rules in the group share the same condition)
                refRule = obj.ThresholdRules{ruleIndices(1)};

                % Evaluate the condition at each segment boundary
                segActive = false(1, nSegs);
                for s = 1:nSegs
                    segActive(s) = refRule.matchesState(segStates{s});
                end

                % Identify which segments are active (condition satisfied)
                activeSegs = find(segActive);
                nActive = numel(activeSegs);

                if nActive == 0
                    % No active segments: emit NaN threshold lines and
                    % empty violation arrays for every rule in the group
                    for ri = 1:numel(ruleIndices)
                        r = ruleIndices(ri);
                        rule = obj.ThresholdRules{r};
                        th = buildThresholdEntry(segBounds, NaN(1, nSegs), rule);
                        viol = struct('X', [], 'Y', [], 'Direction', rule.Direction, 'Label', rule.Label);
                        [resolvedTh, resolvedViol] = appendResults(resolvedTh, resolvedViol, th, viol);
                    end
                    continue;
                end

                % Map each active segment to [lo, hi] index range in sensorX
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

                    % Left binary search: first index >= segStart
                    segLo(a) = binary_search(sensorX, segStart, 'left');
                    if si < nSegs
                        % Exclusive end: last data point strictly before the
                        % next segment boundary
                        segHi(a) = binary_search(sensorX, segEnd, 'left') - 1;
                        % Guard against empty segments (hi < lo)
                        if segHi(a) < segLo(a)
                            segHi(a) = segLo(a);
                        end
                    else
                        % Last segment extends to the end of the data
                        segHi(a) = numel(sensorX);
                    end
                end

                % ---------------------------------------------------
                % Step 5: Batch violation detection for this group
                % ---------------------------------------------------
                % Collect threshold values and direction flags for every
                % rule in the group so violations can be found in one pass.
                nBatchRules = numel(ruleIndices);
                thresholdValues = zeros(1, nBatchRules);
                directions = false(1, nBatchRules);
                for ri = 1:nBatchRules
                    rule = obj.ThresholdRules{ruleIndices(ri)};
                    thresholdValues(ri) = rule.Value;
                    % Use pre-cached IsUpper flag
                    directions(ri) = rule.IsUpper;
                end

                % Delegate to MEX (if available) or vectorized MATLAB
                batchViolIdx = compute_violations_batch(sensorY, segLo, segHi, ...
                    thresholdValues, directions);

                % Build output structs for each rule in the group
                for ri = 1:nBatchRules
                    r = ruleIndices(ri);
                    rule = obj.ThresholdRules{r};

                    % Threshold time series: value at active boundaries, NaN elsewhere
                    % Use logical indexing instead of per-element loop
                    thY = NaN(1, nSegs);
                    thY(segActive) = rule.Value;
                    th = buildThresholdEntry(segBounds, thY, rule);

                    % Violation output: extract X/Y at the violating indices
                    vIdx = batchViolIdx{ri};
                    viol.X = sensorX(vIdx);
                    viol.Y = sensorY(vIdx);
                    viol.Direction = rule.Direction;
                    viol.Label = rule.Label;

                    [resolvedTh, resolvedViol] = appendResults(resolvedTh, resolvedViol, th, viol);
                end
            end

            % -------------------------------------------------------
            % Step 6: Merge thresholds with same Label+Direction
            % -------------------------------------------------------
            % Rules covering different state combinations (e.g., machine=0
            % vs machine=1) but carrying the same label produce separate
            % entries above.  Merge them into single continuous
            % step-function threshold lines for cleaner rendering.
            [resolvedTh, resolvedViol] = mergeResolvedByLabel( ...
                resolvedTh, resolvedViol, segBounds, sensorX(end));

            % Store final results on the object
            obj.ResolvedThresholds = resolvedTh;
            obj.ResolvedViolations = resolvedViol;
            obj.ResolvedStateBands = struct();
        end

        function active = getThresholdsAt(obj, t)
            %GETTHRESHOLDSAT Evaluate all rules at a single time point.
            %   active = s.getThresholdsAt(t) builds the composite state
            %   struct at time t (by querying each StateChannel), then
            %   tests every ThresholdRule against that state.  Returns a
            %   struct array of all rules whose conditions are satisfied,
            %   with fields Value, Direction, and Label.
            %
            %   This is a lightweight single-point query useful for
            %   tooltips, crosshair readouts, and debugging.  For bulk
            %   pre-computation over the full time range, use resolve().
            %
            %   Input:
            %     t — scalar double, the query time (datenum)
            %
            %   Output:
            %     active — struct array (possibly empty) with fields:
            %              .Value     — numeric threshold value
            %              .Direction — 'upper' or 'lower'
            %              .Label     — char display label
            %
            %   See also Sensor.resolve.

            active = [];

            % Build composite state struct at time t
            st = struct();
            for i = 1:numel(obj.StateChannels)
                sc = obj.StateChannels{i};
                st.(sc.Key) = sc.valueAt(t);
            end

            % Test each rule against the current state
            for r = 1:numel(obj.ThresholdRules)
                rule = obj.ThresholdRules{r};
                if rule.matchesState(st)
                    entry.Value = rule.Value;
                    entry.Direction = rule.Direction;
                    entry.Label = rule.Label;
                    % Grow the struct array (first entry seeds the array)
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
