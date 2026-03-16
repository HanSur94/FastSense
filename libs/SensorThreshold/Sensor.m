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
    %     countViolations  — Count total violation points across all rules
    %     currentStatus    — Derive 'ok'/'warning'/'alarm' from latest value
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
        Units         % char: measurement unit (e.g., 'degC', 'bar', 'rpm')
        DataStore     % FastPlotDataStore: disk-backed storage (set by toDisk)
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
            obj.Units = '';
            obj.DataStore = [];
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
                    case 'Units',    obj.Units = varargin{i+1};
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
            % Invalidate pre-computed resolve cache if data is on disk
            if obj.isOnDisk()
                obj.DataStore.clearResolved();
            end
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
            % Invalidate pre-computed resolve cache if data is on disk
            if obj.isOnDisk()
                obj.DataStore.clearResolved();
            end
        end

        function toDisk(obj)
            %TODISK Move sensor X/Y data to disk-backed DataStore.
            %   s.toDisk() creates a FastPlotDataStore from the sensor's
            %   X and Y arrays, then clears X and Y from memory. The data
            %   remains accessible via s.DataStore.getRange() and
            %   s.DataStore.readSlice(). Subsequent calls to resolve(),
            %   addSensor(), and FastPlot rendering all work transparently.
            %
            %   Call toDisk() after setting X and Y but before or after
            %   resolve(). resolve() automatically reads from the DataStore
            %   when X/Y are empty.
            %
            %   Example:
            %     s = Sensor('pressure', 'Name', 'Chamber Pressure');
            %     s.X = linspace(0, 100, 5e6);
            %     s.Y = 40 + 20*sin(2*pi*s.X/30) + 5*randn(1, 5e6);
            %     s.toDisk();     % moves data to disk, frees memory
            %     s.resolve();    % works with disk-backed data
            %     fp.addSensor(s);
            %     fp.render();
            %
            %   See also toMemory, isOnDisk, FastPlotDataStore.

            if isempty(obj.X) && ~isempty(obj.DataStore)
                return;  % already on disk
            end
            if isempty(obj.X)
                error('Sensor:noData', 'No X/Y data to move to disk.');
            end
            obj.DataStore = FastPlotDataStore(obj.X, obj.Y);

            % Pre-compute resolve() while X/Y are still in memory (fastest
            % path).  Results are stored in the SQLite database so that
            % subsequent resolve() calls are instant.
            if ~isempty(obj.ThresholdRules)
                obj.resolve();
                obj.DataStore.storeResolved( ...
                    obj.ResolvedThresholds, obj.ResolvedViolations);
            end

            obj.X = [];
            obj.Y = [];
        end

        function toMemory(obj)
            %TOMEMORY Load disk-backed data back into memory.
            %   s.toMemory() reads the full dataset from the DataStore
            %   back into s.X and s.Y, then cleans up the DataStore.
            %
            %   See also toDisk, isOnDisk.

            if isempty(obj.DataStore)
                return;  % already in memory
            end
            [obj.X, obj.Y] = obj.DataStore.readSlice(1, obj.DataStore.NumPoints);
            obj.DataStore.cleanup();
            obj.DataStore = [];
        end

        function tf = isOnDisk(obj)
            %ISONDISK True if sensor data is stored on disk.
            %   See also toDisk, toMemory.
            tf = ~isempty(obj.DataStore);
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

            % ----- Check for pre-computed cache (stored during toDisk) -----
            onDisk = obj.isOnDisk();
            if onDisk
                [cachedTh, cachedViol] = obj.DataStore.loadResolved();
                if ~isempty(cachedTh)
                    obj.ResolvedThresholds = cachedTh;
                    obj.ResolvedViolations = cachedViol;
                    obj.ResolvedStateBands = struct();
                    return;
                end
            end

            % ----- Determine data source -----
            % For disk-backed sensors, use DataStore metadata instead of
            % loading the entire dataset into memory.  Peak memory stays
            % proportional to the largest active segment, not total points.
            if onDisk
                dataXMin = obj.DataStore.XMin;
                dataXMax = obj.DataStore.XMax;
                dataN    = obj.DataStore.NumPoints;
            else
                sensorX = obj.X;
                sensorY = obj.Y;
                dataXMin = sensorX(1);
                dataXMax = sensorX(end);
                dataN    = numel(sensorX);
            end

            % -------------------------------------------------------
            % Step 1: Find segment boundaries from state channels
            % -------------------------------------------------------
            nChannels = numel(obj.StateChannels);

            if nChannels == 0
                segBounds = [dataXMin, dataXMax];
            else
                allChanges = [];
                for i = 1:nChannels
                    allChanges = [allChanges, obj.StateChannels{i}.X(:)'];
                end
                segBounds = unique(allChanges);

                if segBounds(1) > dataXMin
                    segBounds = [dataXMin, segBounds];
                end
                if segBounds(end) < dataXMax
                    segBounds = [segBounds, dataXMax];
                end
            end

            nSegs = numel(segBounds);

            % -------------------------------------------------------
            % Step 2: Evaluate the composite state at each boundary
            % -------------------------------------------------------
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
                ruleIndices = find(groupIdx == g);
                refRule = obj.ThresholdRules{ruleIndices(1)};

                segActive = false(1, nSegs);
                for s = 1:nSegs
                    segActive(s) = refRule.matchesState(segStates{s});
                end

                activeSegs = find(segActive);
                nActive = numel(activeSegs);

                if nActive == 0
                    for ri = 1:numel(ruleIndices)
                        r = ruleIndices(ri);
                        rule = obj.ThresholdRules{r};
                        th = buildThresholdEntry(segBounds, NaN(1, nSegs), rule);
                        viol = struct('X', [], 'Y', [], 'Direction', rule.Direction, 'Label', rule.Label);
                        [resolvedTh, resolvedViol] = appendResults(resolvedTh, resolvedViol, th, viol);
                    end
                    continue;
                end

                % Map each active segment to [lo, hi] index range
                segLo = zeros(1, nActive);
                segHi = zeros(1, nActive);
                for a = 1:nActive
                    si = activeSegs(a);
                    segStart = segBounds(si);
                    if si < nSegs
                        segEnd = segBounds(si + 1);
                    else
                        segEnd = dataXMax;
                    end

                    if onDisk
                        segLo(a) = obj.DataStore.findIndex(segStart, 'left');
                    else
                        segLo(a) = binary_search(sensorX, segStart, 'left');
                    end

                    if si < nSegs
                        if onDisk
                            segHi(a) = obj.DataStore.findIndex(segEnd, 'left') - 1;
                        else
                            segHi(a) = binary_search(sensorX, segEnd, 'left') - 1;
                        end
                        if segHi(a) < segLo(a)
                            segHi(a) = segLo(a);
                        end
                    else
                        segHi(a) = dataN;
                    end
                end

                % ---------------------------------------------------
                % Step 5: Batch violation detection for this group
                % ---------------------------------------------------
                nBatchRules = numel(ruleIndices);
                thresholdValues = zeros(1, nBatchRules);
                directions = false(1, nBatchRules);
                for ri = 1:nBatchRules
                    rule = obj.ThresholdRules{ruleIndices(ri)};
                    thresholdValues(ri) = rule.Value;
                    directions(ri) = rule.IsUpper;
                end

                if onDisk
                    % Memory-efficient: read each segment from disk
                    [batchViolX, batchViolY] = compute_violations_disk( ...
                        obj.DataStore, segLo, segHi, ...
                        thresholdValues, directions);
                else
                    [batchViolX, batchViolY] = compute_violations_batch( ...
                        sensorX, sensorY, segLo, segHi, ...
                        thresholdValues, directions);
                end

                % Build output structs for each rule in the group
                for ri = 1:nBatchRules
                    r = ruleIndices(ri);
                    rule = obj.ThresholdRules{r};

                    thY = NaN(1, nSegs);
                    thY(segActive) = rule.Value;
                    th = buildThresholdEntry(segBounds, thY, rule);

                    viol.X = batchViolX{ri};
                    viol.Y = batchViolY{ri};
                    viol.Direction = rule.Direction;
                    viol.Label = rule.Label;

                    [resolvedTh, resolvedViol] = appendResults(resolvedTh, resolvedViol, th, viol);
                end
            end

            % -------------------------------------------------------
            % Step 6: Merge thresholds with same Label+Direction
            % -------------------------------------------------------
            [resolvedTh, resolvedViol] = mergeResolvedByLabel( ...
                resolvedTh, resolvedViol, segBounds, dataXMax);

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

        function n = countViolations(obj)
            %COUNTVIOLATIONS Count total violation points across all rules.
            %   n = s.countViolations() returns the total number of
            %   violation data points summed over all ResolvedViolations.
            %   Call resolve() first.
            %
            %   Output:
            %     n — scalar integer, total violation points
            %
            %   See also Sensor.resolve.

            n = 0;
            if isempty(obj.ResolvedViolations)
                return;
            end
            for k = 1:numel(obj.ResolvedViolations)
                n = n + numel(obj.ResolvedViolations(k).X);
            end
        end

        function st = currentStatus(obj)
            %CURRENTSTATUS Derive 'ok'/'warning'/'alarm' from latest value.
            %   st = s.currentStatus() evaluates the sensor's latest Y
            %   value against all threshold rules active at the latest X
            %   time. Returns 'ok' if no thresholds are violated,
            %   'warning' if a warning-level rule is violated, or 'alarm'
            %   if an alarm-level rule is violated.
            %
            %   Severity is determined by the threshold rule's Color and
            %   Label: rules containing 'Alarm' in the Label are treated
            %   as alarm severity; all other violated rules are warnings.
            %
            %   Output:
            %     st — char: 'ok', 'warning', or 'alarm'
            %
            %   See also Sensor.getThresholdsAt, Sensor.resolve.

            st = 'ok';
            if isempty(obj.Y) || isempty(obj.ThresholdRules)
                return;
            end

            val = obj.Y(end);
            tLast = obj.X(end);
            activeRules = obj.getThresholdsAt(tLast);

            for r = 1:numel(activeRules)
                rule = activeRules(r);
                violated = false;
                if strcmp(rule.Direction, 'upper') && val > rule.Value
                    violated = true;
                elseif strcmp(rule.Direction, 'lower') && val < rule.Value
                    violated = true;
                end
                if violated
                    if contains(rule.Label, 'Alarm')
                        st = 'alarm';
                        return;
                    else
                        st = 'warning';
                    end
                end
            end
        end
    end

end
