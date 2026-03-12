classdef ThresholdRule
    %THRESHOLDRULE Defines a condition-value pair for dynamic thresholds.
    %   ThresholdRule pairs a state-condition struct with a numeric
    %   threshold value.  A rule is "active" when every field in its
    %   Condition struct matches the current system state (implicit AND).
    %   An empty condition struct() means the rule is always active
    %   (unconditional threshold).
    %
    %   The Direction property determines whether the threshold is an
    %   upper limit ('upper' -- violation when sensor > Value) or a lower
    %   limit ('lower' -- violation when sensor < Value).
    %
    %   ThresholdRule Properties:
    %     Condition — struct whose field names are state channel keys and
    %                 whose values are the required state for activation
    %     Value     — numeric threshold value when the condition is met
    %     Direction — 'upper' or 'lower'; defines the violation sense
    %     Label     — human-readable display label for plots/legends
    %     Color     — 1x3 RGB triplet (empty = defer to theme default)
    %     LineStyle — char line-style token for rendering (default '--')
    %
    %   ThresholdRule Methods:
    %     ThresholdRule — Constructor; condition, value, and name-value opts
    %     matchesState  — Test whether a state struct satisfies the condition
    %
    %   Example:
    %     rule = ThresholdRule(struct('machine', 1), 50, ...
    %         'Direction', 'upper', 'Label', 'Pressure HH');
    %     tf = rule.matchesState(struct('machine', 1));  % true
    %     tf = rule.matchesState(struct('machine', 2));  % false
    %
    %   See also Sensor, StateChannel, conditionKey.

    properties (Constant)
        DIRECTIONS = {'upper', 'lower'}  % Allowed direction values
    end

    properties
        Condition   % struct: field names = state channel keys, values = required state
        Value       % numeric: threshold value when condition is true
        Direction   % char: 'upper' or 'lower' violation direction
        Label       % char: display label for plots and legends
        Color       % 1x3 double: RGB color (empty = use theme default)
        LineStyle   % char: MATLAB line-style specifier (e.g., '--', ':')
    end

    properties (SetAccess = private)
        CachedConditionKey  % char: pre-computed conditionKey for batching
        ConditionFields     % cell: sorted field names of Condition (cached)
        IsUpper             % logical: true if Direction is 'upper' (cached)
    end

    methods
        function obj = ThresholdRule(condition, value, varargin)
            %THRESHOLDRULE Construct a ThresholdRule object.
            %   rule = ThresholdRule(condition, value) creates a rule with
            %   default direction 'upper', empty label, and dashed line.
            %
            %   rule = ThresholdRule(condition, value, Name, Value, ...)
            %   additionally sets optional name-value pairs:
            %     'Direction' — 'upper' or 'lower' (default 'upper')
            %     'Label'     — char, display label (default '')
            %     'Color'     — 1x3 double RGB (default [])
            %     'LineStyle' — char, line-style token (default '--')
            %
            %   Inputs:
            %     condition — struct whose fields define required state
            %                 values.  An empty struct() is unconditional.
            %     value     — numeric, the threshold value
            %
            %   Output:
            %     obj — ThresholdRule object
            %
            %   See also ThresholdRule.matchesState, Sensor.addThresholdRule.

            % Validate condition type
            if ~isstruct(condition)
                error('ThresholdRule:invalidCondition', ...
                    'Condition must be a struct, got %s.', class(condition));
            end
            obj.Condition = condition;
            obj.Value = value;

            % Set sensible defaults before parsing optional arguments
            obj.Direction = 'upper';
            obj.Label = '';
            obj.Color = [];
            obj.LineStyle = '--';

            % Parse optional name-value pairs
            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Direction'
                        d = varargin{i+1};
                        % Validate against the allowed set
                        if ~ismember(d, ThresholdRule.DIRECTIONS)
                            error('ThresholdRule:invalidDirection', ...
                                'Direction must be ''upper'' or ''lower'', got ''%s''.', d);
                        end
                        obj.Direction = d;
                    case 'Label'
                        obj.Label = varargin{i+1};
                    case 'Color'
                        obj.Color = varargin{i+1};
                    case 'LineStyle'
                        obj.LineStyle = varargin{i+1};
                    otherwise
                        error('ThresholdRule:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end

            % Pre-compute cached properties for fast resolve()
            obj.CachedConditionKey = conditionKey(condition);
            obj.ConditionFields = sort(fieldnames(condition));
            obj.IsUpper = strcmp(obj.Direction, 'upper');
        end

        function tf = matchesState(obj, st)
            %MATCHESSTATE Check if a state struct satisfies this rule's condition.
            %   tf = rule.matchesState(st) returns true if every field in
            %   the rule's Condition struct exists in st and has a matching
            %   value (implicit AND logic).  An empty Condition always
            %   returns true, meaning the rule is unconditional.
            %
            %   Uses pre-cached ConditionFields for faster iteration.
            %
            %   Input:
            %     st — struct representing the current system state
            %
            %   Output:
            %     tf — logical scalar, true if the condition is satisfied
            %
            %   See also ThresholdRule, StateChannel.valueAt.

            fields = obj.ConditionFields;
            tf = true;
            for f = 1:numel(fields)
                key = fields{f};

                % If the required state channel key is absent, fail immediately
                if ~isfield(st, key)
                    tf = false;
                    return;
                end

                condVal = obj.Condition.(key);
                stVal = st.(key);

                % Use type-appropriate comparison
                if ischar(condVal) || isstring(condVal)
                    if ~strcmp(condVal, stVal)
                        tf = false;
                        return;
                    end
                else
                    if stVal ~= condVal
                        tf = false;
                        return;
                    end
                end
            end
        end
    end
end
