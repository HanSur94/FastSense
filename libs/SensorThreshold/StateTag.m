classdef StateTag < Tag
    %STATETAG Concrete Tag subclass for discrete state signals with ZOH lookup.
    %   StateTag models a piecewise-constant ("zero-order hold") time
    %   series representing a discrete system state (e.g., machine mode,
    %   recipe phase).  valueAt(t) returns the most recent known state
    %   value using a right-biased binary search on X.  Supports BOTH
    %   numeric and cellstr Y — semantics are byte-for-byte equivalent to
    %   legacy StateChannel.valueAt.  Adds StateTag:emptyState guard so
    %   unloaded tags produce a clean error instead of a bounds crash.
    %
    %   Properties (public, in addition to Tag universals):
    %     X — 1xN sorted numeric: timestamps of state transitions
    %     Y — 1xN numeric OR 1xN cell of char: state values
    %
    %   Methods:
    %     StateTag     — constructor (key + 'X','Y' + Tag universals)
    %     getXY        — return [X, Y] (pass-through)
    %     valueAt(t)   — ZOH lookup; scalar or vector t; numeric or cellstr Y
    %     getTimeRange — [X(1), X(end)]; [NaN NaN] if empty
    %     getKind      — returns 'state'
    %     toStruct     — serialize X, Y, plus Tag universals
    %     fromStruct   — static factory rebuilding StateTag from toStruct
    %
    %   Error IDs:
    %     StateTag:emptyState     — valueAt on empty X/Y
    %     StateTag:unknownOption  — unknown constructor name-value key
    %     StateTag:dataMismatch   — fromStruct struct missing .key
    %
    %   Example:
    %     st = StateTag('mode', 'X', [1 5 10 20], 'Y', [0 1 2 3]);
    %     st.valueAt(7);             % -> 1
    %     st.valueAt([0 3 5 7 15]);  % -> [0 0 1 1 2]
    %
    %   See also Tag, TagRegistry, StateChannel, binary_search.

    properties
        X = []   % 1xN numeric: sorted transition timestamps
        Y = []   % 1xN numeric OR 1xN cell of char: state values
    end

    methods
        function obj = StateTag(key, varargin)
            %STATETAG Construct a StateTag; delegates universals to Tag + parses X/Y.
            %   Valid name-value keys: 'X', 'Y', plus Tag universals (Name,
            %   Units, Description, Labels, Metadata, Criticality, SourceRef).
            %   Raises StateTag:unknownOption for unrecognized or dangling keys.
            [tagArgs, xVal, yVal, hasX, hasY] = StateTag.splitArgs_(varargin);
            obj@Tag(key, tagArgs{:});   % MUST be first — Pitfall 8
            if hasX, obj.X = xVal; end
            if hasY, obj.Y = yVal; end
        end

        function [X, Y] = getXY(obj)
            %GETXY Return [X, Y] data vectors (pass-through).
            X = obj.X;
            Y = obj.Y;
        end

        function val = valueAt(obj, t)
            %VALUEAT Return state value at t using zero-order hold.
            %   Right-biased binary search on X: largest idx with X(idx)<=t,
            %   clamped to [1, N].  Supports scalar and vector t for both
            %   numeric and cellstr Y.  Raises StateTag:emptyState if X or
            %   Y is empty.  Semantics match StateChannel.valueAt byte-for-byte.
            if isempty(obj.X) || isempty(obj.Y)
                error('StateTag:emptyState', ...
                    'StateTag ''%s'' has empty X or Y; cannot evaluate valueAt.', ...
                    obj.Key);
            end
            if isscalar(t)
                % --- Scalar path: single binary search lookup ---
                idx = obj.bsearchRight_(t);
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
                        idx = obj.bsearchRight_(t(k));
                        val{k} = obj.Y{idx};
                    end
                else
                    val = zeros(1, n);
                    for k = 1:n
                        idx = obj.bsearchRight_(t(k));
                        val(k) = obj.Y(idx);
                    end
                end
            end
        end

        function [tMin, tMax] = getTimeRange(obj)
            %GETTIMERANGE Return [X(1), X(end)]; [NaN NaN] if empty.
            if isempty(obj.X)
                tMin = NaN; tMax = NaN;
                return;
            end
            tMin = obj.X(1);
            tMax = obj.X(end);
        end

        function k = getKind(obj) %#ok<MANU>
            %GETKIND Return the kind identifier 'state'.
            k = 'state';
        end

        function s = toStruct(obj)
            %TOSTRUCT Serialize StateTag to a plain struct.
            %   Wraps cellstr Labels and cellstr Y once via {...} to survive
            %   MATLAB's struct() cellstr-collapse.  fromStruct unwraps.
            s = struct();
            s.kind        = 'state';
            s.key         = obj.Key;
            s.name        = obj.Name;
            s.units       = obj.Units;
            s.description = obj.Description;
            s.labels      = {obj.Labels};    % wrap — Pitfall 4
            s.metadata    = obj.Metadata;
            s.criticality = obj.Criticality;
            s.sourceref   = obj.SourceRef;
            s.x           = obj.X;
            if iscell(obj.Y)
                s.y = {obj.Y};               % cellstr-collapse defense
            else
                s.y = obj.Y;
            end
        end
    end

    methods (Access = private)
        function idx = bsearchRight_(obj, val)
            %BSEARCHRIGHT_ Last index where X(idx) <= val; clamped to [1, N].
            idx = binary_search(obj.X, val, 'right');
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            %FROMSTRUCT Reconstruct StateTag from a toStruct output.
            if ~isstruct(s) || ~isfield(s, 'key') || isempty(s.key)
                error('StateTag:dataMismatch', ...
                    'fromStruct requires a struct with non-empty .key');
            end
            % Unwrap labels (MockTag pattern)
            labels = {};
            if isfield(s, 'labels') && ~isempty(s.labels)
                L = s.labels;
                if iscell(L) && numel(L) == 1 && iscell(L{1}), L = L{1}; end
                if iscell(L), labels = L; end
            end
            metadata = struct();
            if isfield(s, 'metadata') && isstruct(s.metadata), metadata = s.metadata; end
            criticality = 'medium';
            if isfield(s, 'criticality') && ~isempty(s.criticality), criticality = s.criticality; end
            name = s.key;
            if isfield(s, 'name') && ~isempty(s.name), name = s.name; end
            units = '';
            if isfield(s, 'units') && ~isempty(s.units), units = s.units; end
            description = '';
            if isfield(s, 'description') && ~isempty(s.description), description = s.description; end
            sourceref = '';
            if isfield(s, 'sourceref') && ~isempty(s.sourceref), sourceref = s.sourceref; end
            xVal = [];
            if isfield(s, 'x'), xVal = s.x; end
            yVal = [];
            if isfield(s, 'y')
                Y = s.y;
                % Unwrap cellstr wrap from toStruct; numeric passes through
                if iscell(Y) && numel(Y) == 1 && iscell(Y{1}), Y = Y{1}; end
                yVal = Y;
            end
            obj = StateTag(s.key, ...
                'Name', name, 'Units', units, 'Description', description, ...
                'Labels', labels, 'Metadata', metadata, ...
                'Criticality', criticality, 'SourceRef', sourceref, ...
                'X', xVal, 'Y', yVal);
        end
    end

    methods (Static, Access = private)
        function [tagArgs, xVal, yVal, hasX, hasY] = splitArgs_(args)
            %SPLITARGS_ Partition varargin into Tag universals vs. X/Y.
            %   Unknown or dangling keys raise StateTag:unknownOption.
            tagKeys = {'Name', 'Units', 'Description', 'Labels', ...
                       'Metadata', 'Criticality', 'SourceRef'};
            tagArgs = {};
            xVal = [];
            yVal = [];
            hasX = false;
            hasY = false;
            i = 1;
            while i <= numel(args)
                k = args{i};
                if i + 1 > numel(args)
                    error('StateTag:unknownOption', ...
                        'Option ''%s'' has no matching value.', char(k));
                end
                v = args{i+1};
                if any(strcmp(k, tagKeys))
                    tagArgs{end+1} = k; %#ok<AGROW>
                    tagArgs{end+1} = v; %#ok<AGROW>
                elseif strcmp(k, 'X')
                    xVal = v; hasX = true;
                elseif strcmp(k, 'Y')
                    yVal = v; hasY = true;
                else
                    error('StateTag:unknownOption', ...
                        'Unknown option ''%s''.', char(k));
                end
                i = i + 2;
            end
        end
    end
end
