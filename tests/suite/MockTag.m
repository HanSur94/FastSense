classdef MockTag < Tag
    %MOCKTAG Minimal concrete Tag subclass for testing.
    %   MockTag implements all 6 abstract-by-convention Tag methods with
    %   trivial stubs so that TestTag (Plan 1004-01) and TestTagRegistry
    %   (Plan 1004-02) can exercise Tag / TagRegistry behavior without
    %   waiting on Phase 1005 (SensorTag, StateTag) concrete subclasses.
    %
    %   Mirrors the MockDashboardWidget and MockDataSource patterns used
    %   elsewhere in the test suite.
    %
    %   MockTag Methods (abstract overrides):
    %     getXY        — returns [], []
    %     valueAt(t)   — returns NaN (ignores t)
    %     getTimeRange — returns NaN, NaN
    %     getKind      — returns 'mock'
    %     toStruct     — returns struct with kind='mock' and key/name/labels/metadata/criticality
    %     fromStruct   — static factory that rebuilds MockTag from toStruct output
    %
    %   See also Tag, MockDashboardWidget, MockDataSource.

    methods
        function obj = MockTag(key, varargin)
            %MOCKTAG Construct a MockTag by delegating to Tag superconstructor.
            obj@Tag(key, varargin{:});
        end

        function [X, Y] = getXY(obj) %#ok<MANU>
            %GETXY Return empty X, Y vectors (mock has no data).
            X = [];
            Y = [];
        end

        function v = valueAt(obj, t) %#ok<INUSD,MANU>
            %VALUEAT Return NaN (mock has no data).
            v = NaN;
        end

        function [tMin, tMax] = getTimeRange(obj) %#ok<MANU>
            %GETTIMERANGE Return NaN bounds (mock has no data).
            tMin = NaN;
            tMax = NaN;
        end

        function k = getKind(obj) %#ok<MANU>
            %GETKIND Return the kind identifier 'mock'.
            k = 'mock';
        end

        function s = toStruct(obj)
            %TOSTRUCT Serialize MockTag state to a plain struct.
            s = struct();
            s.kind        = 'mock';
            s.key         = obj.Key;
            s.name        = obj.Name;
            s.labels      = {obj.Labels};  % wrap to survive struct() cellstr collapse; unwrap in fromStruct
            s.metadata    = obj.Metadata;
            s.criticality = obj.Criticality;
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            %FROMSTRUCT Reconstruct a MockTag from a struct produced by toStruct.
            labels = {};
            if isfield(s, 'labels') && ~isempty(s.labels)
                L = s.labels;
                if iscell(L) && numel(L) == 1 && iscell(L{1})
                    L = L{1};  % unwrap the struct() wrap
                end
                if iscell(L)
                    labels = L;
                end
            end
            metadata = struct();
            if isfield(s, 'metadata') && isstruct(s.metadata)
                metadata = s.metadata;
            end
            criticality = 'medium';
            if isfield(s, 'criticality') && ~isempty(s.criticality)
                criticality = s.criticality;
            end
            name = s.key;
            if isfield(s, 'name') && ~isempty(s.name)
                name = s.name;
            end
            obj = MockTag(s.key, 'Name', name, 'Labels', labels, ...
                'Metadata', metadata, 'Criticality', criticality);
        end
    end
end
