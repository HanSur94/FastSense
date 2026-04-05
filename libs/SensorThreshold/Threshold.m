classdef Threshold < handle
    %THRESHOLD First-class threshold entity with condition-value pairs.
    %   Threshold is an independent, reusable entity that encapsulates a
    %   threshold definition — its direction, appearance, metadata, and a
    %   set of condition-value pairs (ThresholdRule objects).
    %
    %   Unlike ThresholdRule (which is sensor-scoped), Threshold is a
    %   standalone entity that can be registered in ThresholdRegistry and
    %   shared across multiple sensors or dashboard widgets.
    %
    %   Typical workflow:
    %     1. Create a Threshold with a key and optional metadata.
    %     2. Add one or more condition-value pairs via addCondition().
    %     3. Register in ThresholdRegistry for reuse across sensors.
    %     4. Retrieve later with ThresholdRegistry.get(key).
    %
    %   Threshold Properties (public):
    %     Key         — unique string identifier (positional, required)
    %     Name        — human-readable display name
    %     Direction   — 'upper' or 'lower' (default 'upper')
    %     Color       — 1x3 RGB color triplet (empty = theme default)
    %     LineStyle   — MATLAB line-style string (default '--')
    %     Units       — measurement unit string (e.g., 'degC', 'bar')
    %     Description — free-text description
    %     Tags        — cell array of string tags for filtering
    %
    %   Threshold Properties (read-only):
    %     IsUpper     — logical, true when Direction is 'upper'
    %     conditions_ — cell array of ThresholdRule objects
    %
    %   Threshold Properties (dependent):
    %     Label       — returns Name; minimises churn in consumers that
    %                   read .Label (e.g., buildThresholdEntry)
    %
    %   Threshold Methods:
    %     Threshold          — Constructor; key + optional name-value pairs
    %     addCondition       — Append a condition-value pair (ThresholdRule)
    %     allValues          — Return numeric vector of all condition values
    %     getConditionFields — Return unique sorted fieldnames across conditions
    %
    %   Example:
    %     t = Threshold('press_hi', 'Name', 'Pressure High', ...
    %         'Direction', 'upper', 'Color', [1 0.3 0], 'Units', 'bar', ...
    %         'Tags', {'pressure', 'alarm'});
    %     t.addCondition(struct('machine', 1), 80);
    %     t.addCondition(struct('machine', 2), 90);
    %     ThresholdRegistry.register('press_hi', t);
    %
    %   See also ThresholdRule, ThresholdRegistry, SensorRegistry.

    properties
        Key          % char: unique identifier
        Name         % char: human-readable display name
        Direction    % char: 'upper' or 'lower'
        Color        % 1x3 double: RGB color (empty = theme default)
        LineStyle    % char: MATLAB line-style token
        Units        % char: measurement unit
        Description  % char: free-text description
        Tags         % cell: string tags for filtering/discovery
    end

    properties (SetAccess = private)
        IsUpper      % logical: true when Direction is 'upper' (cached)
        conditions_  % cell: ThresholdRule objects added via addCondition
    end

    properties (Dependent)
        Label        % char: alias for Name; for buildThresholdEntry compat
    end

    methods
        function obj = Threshold(key, varargin)
            %THRESHOLD Construct a Threshold object.
            %   t = Threshold(key) creates a threshold with the given key
            %   and default values: Direction='upper', LineStyle='--'.
            %
            %   t = Threshold(key, Name, Value, ...) additionally sets
            %   optional name-value pairs:
            %     'Name'        — char, display name (default '')
            %     'Direction'   — 'upper' or 'lower' (default 'upper')
            %     'Color'       — 1x3 double RGB (default [])
            %     'LineStyle'   — char, line-style token (default '--')
            %     'Units'       — char, measurement unit (default '')
            %     'Description' — char, free text (default '')
            %     'Tags'        — cell of char tags (default {})
            %
            %   Input:
            %     key — char, unique identifier string
            %
            %   Output:
            %     obj — Threshold object
            %
            %   See also Threshold.addCondition, ThresholdRegistry.

            obj.Key         = key;
            obj.Name        = '';
            obj.Direction   = 'upper';
            obj.Color       = [];
            obj.LineStyle   = '--';
            obj.Units       = '';
            obj.Description = '';
            obj.Tags        = {};
            obj.conditions_ = {};

            % Parse optional name-value pairs
            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Name'
                        obj.Name = varargin{i+1};
                    case 'Direction'
                        obj.Direction = varargin{i+1};
                    case 'Color'
                        obj.Color = varargin{i+1};
                    case 'LineStyle'
                        obj.LineStyle = varargin{i+1};
                    case 'Units'
                        obj.Units = varargin{i+1};
                    case 'Description'
                        obj.Description = varargin{i+1};
                    case 'Tags'
                        obj.Tags = varargin{i+1};
                    otherwise
                        error('Threshold:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end

            % Cache IsUpper from Direction
            obj.IsUpper = strcmp(obj.Direction, 'upper');
        end

        function addCondition(obj, conditionStruct, value)
            %ADDCONDITION Append a condition-value pair as a ThresholdRule.
            %   t.addCondition(conditionStruct, value) creates an internal
            %   ThresholdRule using the threshold's Direction, Name, Color,
            %   and LineStyle, then appends it to conditions_.
            %
            %   Inputs:
            %     conditionStruct — struct whose fields define required state
            %     value           — numeric threshold value for this condition
            %
            %   See also ThresholdRule, Threshold.allValues.

            rule = ThresholdRule(conditionStruct, value, ...
                'Direction', obj.Direction, ...
                'Label',     obj.Name, ...
                'Color',     obj.Color, ...
                'LineStyle', obj.LineStyle);
            obj.conditions_{end+1} = rule;
        end

        function vals = allValues(obj)
            %ALLVALUES Return numeric vector of all condition values.
            %   vals = t.allValues() extracts the Value from each
            %   ThresholdRule in conditions_ and returns them as a row
            %   vector.  Returns [] when no conditions are defined.
            %
            %   Output:
            %     vals — 1xN double, empty if no conditions
            %
            %   See also Threshold.addCondition, Threshold.getConditionFields.

            if isempty(obj.conditions_)
                vals = [];
                return;
            end
            vals = cellfun(@(r) r.Value, obj.conditions_);
        end

        function fields = getConditionFields(obj)
            %GETCONDITIONFIELDS Return unique sorted fieldnames across all conditions.
            %   fields = t.getConditionFields() iterates every condition in
            %   conditions_ and returns the union of all struct fieldnames as
            %   a sorted, deduplicated cell array of char.
            %
            %   Output:
            %     fields — cell array of char, sorted unique fieldnames
            %
            %   See also Threshold.addCondition.

            allFields = {};
            for i = 1:numel(obj.conditions_)
                cf = obj.conditions_{i}.ConditionFields;
                allFields = [allFields; cf(:)]; %#ok<AGROW>
            end
            fields = unique(allFields);
        end

        function label = get.Label(obj)
            %GET.LABEL Dependent property: returns Name.
            %   Provides backward compatibility with code that reads .Label
            %   (e.g., buildThresholdEntry uses rule.Label).
            label = obj.Name;
        end
    end
end
