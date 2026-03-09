classdef ThresholdRule
    %THRESHOLDRULE Defines a condition-value pair for dynamic thresholds.
    %   rule = ThresholdRule(struct('machine', 1), 50)
    %   rule = ThresholdRule(struct('machine', 1, 'vacuum', 2), 50, 'Direction', 'upper')
    %
    %   The condition struct defines required state values (implicit AND).
    %   An empty struct() means the threshold is always active.

    properties (Constant)
        DIRECTIONS = {'upper', 'lower'}
    end

    properties
        Condition   % struct: field names = state channel keys, values = required state
        Value       % numeric: threshold value when condition is true
        Direction   % char: 'upper' or 'lower'
        Label       % char: display label
        Color       % 1x3 double: RGB color (empty = use theme default)
        LineStyle   % char: line style
    end

    methods
        function obj = ThresholdRule(condition, value, varargin)
            if ~isstruct(condition)
                error('ThresholdRule:invalidCondition', ...
                    'Condition must be a struct, got %s.', class(condition));
            end
            obj.Condition = condition;
            obj.Value = value;

            % Defaults
            obj.Direction = 'upper';
            obj.Label = '';
            obj.Color = [];
            obj.LineStyle = '--';

            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Direction'
                        d = varargin{i+1};
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
        end

        function tf = matchesState(obj, st)
            %MATCHESSTATE Check if a state struct satisfies this rule's condition.
            %   All fields in Condition must match (implicit AND).
            %   Empty condition always returns true.
            fields = fieldnames(obj.Condition);
            tf = true;
            for f = 1:numel(fields)
                key = fields{f};
                if ~isfield(st, key)
                    tf = false;
                    return;
                end
                condVal = obj.Condition.(key);
                stVal = st.(key);
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
