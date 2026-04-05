classdef CompositeThreshold < Threshold
    %COMPOSITETHRESHOLD Threshold subclass that aggregates child Threshold objects.
    %   CompositeThreshold enables hierarchical status trees where a parent
    %   component's status is derived from its children's statuses using
    %   configurable AND, OR, or MAJORITY logic.
    %
    %   A composite is itself a Threshold (isa returns true), so it can be
    %   registered in ThresholdRegistry and used anywhere a Threshold is
    %   accepted.  Composites can be nested: a CompositeThreshold may be
    %   added as a child of another CompositeThreshold, allowing arbitrarily
    %   deep system-health trees.
    %
    %   CompositeThreshold Properties (public):
    %     AggregateMode — 'and' | 'or' | 'majority' (default 'and')
    %                     Controls how child statuses are combined.
    %
    %   CompositeThreshold Methods:
    %     CompositeThreshold — Constructor; key + optional name-value pairs
    %     addChild           — Add a child Threshold (object or registry key)
    %     computeStatus      — Evaluate aggregate status: 'ok' or 'alarm'
    %     getChildren        — Return internal children cell array (read-only)
    %     allValues          — Returns [] (composites have no direct conditions)
    %
    %   Aggregate modes:
    %     'and'      — all children must be 'ok'; one alarm -> 'alarm'
    %     'or'       — any child 'ok' -> 'ok'; all alarm -> 'alarm'
    %     'majority' — strictly more than half ok -> 'ok', else 'alarm'
    %
    %   Each child is registered with an optional ValueFcn (zero-arg function
    %   returning the current sensor reading) or a static Value scalar.  For
    %   leaf Threshold children, computeStatus resolves the value and compares
    %   it against the child's threshold conditions.  For CompositeThreshold
    %   children, computeStatus delegates recursively.
    %
    %   Example:
    %     t1 = Threshold('press_hi', 'Direction', 'upper');
    %     t1.addCondition(struct(), 100);
    %
    %     t2 = Threshold('temp_hi', 'Direction', 'upper');
    %     t2.addCondition(struct(), 80);
    %
    %     c = CompositeThreshold('pump_a', 'AggregateMode', 'and');
    %     c.addChild(t1, 'Value', 90);
    %     c.addChild(t2, 'Value', 70);
    %     status = c.computeStatus();  % 'ok' if both below threshold
    %
    %   See also Threshold, ThresholdRegistry.

    properties
        AggregateMode = 'and'   % char: 'and' | 'or' | 'majority'
    end

    properties (Access = private)
        children_ = {}   % cell of structs: {threshold, valueFcn, value}
    end

    methods

        function obj = CompositeThreshold(key, varargin)
            %COMPOSITETHRESHOLD Construct a CompositeThreshold.
            %   c = CompositeThreshold(key) creates a composite with the
            %   given key and default AggregateMode='and'.
            %
            %   c = CompositeThreshold(key, Name, Value, ...) sets optional
            %   name-value pairs accepted by Threshold plus:
            %     'AggregateMode' — 'and', 'or', or 'majority'
            %
            %   Input:
            %     key — char, unique identifier string
            %
            %   Output:
            %     obj — CompositeThreshold object

            % Separate our own options from Threshold options
            aggregateMode = 'and';
            thresholdArgs = {};

            i = 1;
            while i <= numel(varargin)
                if strcmp(varargin{i}, 'AggregateMode')
                    aggregateMode = varargin{i+1};
                    i = i + 2;
                else
                    thresholdArgs{end+1} = varargin{i}; %#ok<AGROW>
                    if i + 1 <= numel(varargin) && (mod(numel(thresholdArgs), 2) == 1)
                        thresholdArgs{end+1} = varargin{i+1}; %#ok<AGROW>
                        i = i + 2;
                    else
                        i = i + 1;
                    end
                end
            end

            obj@Threshold(key, thresholdArgs{:});
            obj.AggregateMode = aggregateMode;
            obj.children_ = {};
        end

        function set.AggregateMode(obj, mode)
            %SET.AGGREGATEMODE Validate and set the aggregate mode.
            if ~any(strcmp(mode, {'and', 'or', 'majority'}))
                error('CompositeThreshold:invalidMode', ...
                    'AggregateMode must be ''and'', ''or'', or ''majority''. Got: ''%s''.', mode);
            end
            obj.AggregateMode = mode;
        end

        function addChild(obj, thresholdOrKey, varargin)
            %ADDCHILD Add a child Threshold to this composite.
            %   c.addChild(threshold) adds the given Threshold object as a
            %   child with no associated value (computeStatus will return
            %   'ok' for that child since no value to compare against).
            %
            %   c.addChild(key) resolves the Threshold from ThresholdRegistry.
            %   Issues a warning (CompositeThreshold:unknownChildKey) and
            %   skips the add if the key is not found.
            %
            %   c.addChild(thresholdOrKey, 'Value', v) uses static scalar v
            %   as the measurement value during computeStatus.
            %
            %   c.addChild(thresholdOrKey, 'ValueFcn', fn) calls fn() each
            %   time computeStatus runs to obtain the current measurement.
            %
            %   Inputs:
            %     thresholdOrKey — Threshold object or char key string
            %     'Value'        — numeric scalar (optional)
            %     'ValueFcn'     — zero-arg function handle (optional)
            %
            %   See also CompositeThreshold.computeStatus, ThresholdRegistry.

            % Resolve threshold handle
            if ischar(thresholdOrKey) || isstring(thresholdOrKey)
                try
                    t = ThresholdRegistry.get(char(thresholdOrKey));
                catch
                    warning('CompositeThreshold:unknownChildKey', ...
                        'No threshold registered with key ''%s''. Child not added.', ...
                        char(thresholdOrKey));
                    return;
                end
            else
                t = thresholdOrKey;
            end

            % Self-reference guard
            if t == obj
                error('CompositeThreshold:selfReference', ...
                    'A CompositeThreshold cannot be added as its own child.');
            end

            % Parse ValueFcn / Value options
            valueFcn = [];
            value = [];
            j = 1;
            while j <= numel(varargin)
                switch varargin{j}
                    case 'ValueFcn'
                        valueFcn = varargin{j+1};
                        j = j + 2;
                    case 'Value'
                        value = varargin{j+1};
                        j = j + 2;
                    otherwise
                        j = j + 1;
                end
            end

            entry = struct('threshold', t, 'valueFcn', valueFcn, 'value', value);
            obj.children_{end+1} = entry;
        end

        function status = computeStatus(obj)
            %COMPUTESTATUS Evaluate the aggregate status of this composite.
            %   status = c.computeStatus() returns 'ok' if the aggregate of
            %   all children's statuses satisfies AggregateMode, or 'alarm'
            %   otherwise.  Returns 'ok' when children list is empty.
            %
            %   Output:
            %     status — char: 'ok' or 'alarm'
            %
            %   See also CompositeThreshold.addChild.

            if isempty(obj.children_)
                status = 'ok';
                return;
            end

            statuses = cell(1, numel(obj.children_));
            for i = 1:numel(obj.children_)
                entry = obj.children_{i};
                t = entry.threshold;

                if isa(t, 'CompositeThreshold')
                    % Recursive evaluation for nested composites
                    statuses{i} = t.computeStatus();
                else
                    % Leaf Threshold: resolve value and evaluate
                    val = obj.resolveValue_(entry);
                    statuses{i} = obj.evaluateLeaf_(t, val);
                end
            end

            status = obj.applyAggregateMode_(statuses);
        end

        function ch = getChildren(obj)
            %GETCHILDREN Return the children cell array.
            %   ch = c.getChildren() returns the internal cell array of child
            %   structs, each with fields: threshold, valueFcn, value.
            %
            %   Output:
            %     ch — cell array of structs
            %
            %   See also CompositeThreshold.addChild.
            ch = obj.children_;
        end

        function vals = allValues(obj) %#ok<MANU>
            %ALLVALUES Return [] — composites have no direct conditions.
            %   CompositeThreshold stores no ThresholdRule objects directly.
            %   Status is computed from children, not from threshold conditions.
            %
            %   Output:
            %     vals — [] (always empty)
            vals = [];
        end

    end

    methods (Access = private)

        function val = resolveValue_(obj, entry) %#ok<INUSL>
            %RESOLVEVALUE_ Resolve the measurement value for a child entry.
            %   Uses ValueFcn if provided; otherwise uses static Value.
            %   Returns [] when neither is configured.
            if ~isempty(entry.valueFcn)
                val = entry.valueFcn();
            else
                val = entry.value;
            end
        end

        function status = evaluateLeaf_(obj, threshold, val) %#ok<INUSL>
            %EVALUATELEAF_ Compare val against threshold conditions.
            %   Returns 'ok' if val does not violate the threshold, or if
            %   val is empty (no measurement available).
            %   Returns 'alarm' if the threshold is violated.
            if isempty(val) || isempty(threshold.allValues())
                status = 'ok';
                return;
            end
            threshVals = threshold.allValues();
            threshVal = threshVals(1);  % Use first condition value
            if threshold.IsUpper
                % Upper threshold: alarm if value exceeds threshold
                if val > threshVal
                    status = 'alarm';
                else
                    status = 'ok';
                end
            else
                % Lower threshold: alarm if value is below threshold
                if val < threshVal
                    status = 'alarm';
                else
                    status = 'ok';
                end
            end
        end

        function result = applyAggregateMode_(obj, statuses)
            %APPLYAGGREGATEMODE_ Combine child statuses using AggregateMode.
            %   'and':      all must be 'ok' -> 'ok', else 'alarm'
            %   'or':       any is 'ok' -> 'ok', else 'alarm'
            %   'majority': strictly more than half ok -> 'ok', else 'alarm'
            nOk = sum(strcmp(statuses, 'ok'));
            n = numel(statuses);

            switch obj.AggregateMode
                case 'and'
                    if nOk == n
                        result = 'ok';
                    else
                        result = 'alarm';
                    end
                case 'or'
                    if nOk > 0
                        result = 'ok';
                    else
                        result = 'alarm';
                    end
                case 'majority'
                    if nOk > n / 2
                        result = 'ok';
                    else
                        result = 'alarm';
                    end
                otherwise
                    result = 'alarm';
            end
        end

    end

end
