classdef Tag < handle
    %TAG Abstract base for the unified Tag domain model.
    %   Tag is the root of the v2.0 domain hierarchy.  Subclasses
    %   (SensorTag, StateTag, MonitorTag, CompositeTag) provide concrete
    %   implementations of the six abstract-by-convention methods.
    %
    %   Tag uses the Octave-safe "throw-from-base" abstract pattern:
    %   the base class provides stub methods that raise a notImplemented
    %   error, and subclasses override with concrete implementations.
    %   Do NOT use the Abstract-methods block pattern here — it has
    %   divergent semantics between MATLAB and Octave (see DataSource.m
    %   for the proven pattern used here).
    %
    %   Tag Properties (public):
    %     Key         — char: unique identifier (required, non-empty)
    %     Name        — char: human-readable name (defaults to Key)
    %     Units       — char: measurement unit
    %     Description — char: free-text description
    %     Labels      — cellstr: cross-cutting classification (META-01)
    %     Metadata    — struct: open key-value bag (META-03)
    %     Criticality — char enum: 'low'|'medium'|'high'|'safety' (META-04)
    %     SourceRef   — char: optional provenance string
    %
    %   Tag Methods (abstract-by-convention — subclass must implement):
    %     getXY               — return [X, Y] data vectors
    %     valueAt(t)          — return scalar value at time t
    %     getTimeRange        — return [tMin, tMax]
    %     getKind             — return kind string ('sensor'|'state'|'monitor'|'composite'|'mock')
    %     toStruct            — return serializable struct
    %     fromStruct (Static) — reconstruct from struct
    %
    %   Tag Methods (default hooks — override when needed):
    %     resolveRefs(registry) — Pass-2 deserialization hook; default no-op
    %
    %   Example (subclass):
    %     classdef SensorTag < Tag
    %         methods
    %             function obj = SensorTag(key, varargin)
    %                 obj@Tag(key, varargin{:});
    %             end
    %             function [X, Y] = getXY(obj)
    %                 X = obj.X_;
    %                 Y = obj.Y_;
    %             end
    %             % ... other abstracts ...
    %         end
    %     end
    %
    %   See also TagRegistry, MockTag, DataSource.

    properties
        Key          = ''       % char: unique identifier
        Name         = ''       % char: human-readable name
        Units        = ''       % char: measurement unit
        Description  = ''       % char: free-text description
        Labels       = {}       % cellstr: cross-cutting classification
        Metadata     = struct() % struct: open key-value bag
        Criticality  = 'medium' % char enum: 'low'|'medium'|'high'|'safety'
        SourceRef    = ''       % char: optional provenance string
        EventStore   = []       % EventStore handle; [] disables event convenience methods
    end

    methods
        function obj = Tag(key, varargin)
            %TAG Construct a Tag with required key and optional name-value pairs.
            %
            %   t = Tag(key) creates a Tag with the given key; Name defaults to key.
            %
            %   t = Tag(key, 'Name', n, 'Labels', {...}, 'Criticality', 'safety', ...)
            %   sets optional properties.
            %
            %   Valid name-value keys: Name, Units, Description, Labels,
            %   Metadata, Criticality, SourceRef.
            %
            %   Error IDs raised:
            %     invalidKey         — key is empty or not char
            %     unknownOption      — name-value key not recognized
            %     invalidCriticality — Criticality not in valid set

            if nargin < 1 || isempty(key) || ~ischar(key)
                error('Tag:invalidKey', 'Key must be a non-empty char.');
            end
            obj.Key  = key;
            obj.Name = key;  % default Name = Key

            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Name',        obj.Name        = varargin{i+1};
                    case 'Units',       obj.Units       = varargin{i+1};
                    case 'Description', obj.Description = varargin{i+1};
                    case 'Labels',      obj.Labels      = varargin{i+1};
                    case 'Metadata',    obj.Metadata    = varargin{i+1};
                    case 'Criticality', obj.Criticality = varargin{i+1};
                    case 'SourceRef',   obj.SourceRef   = varargin{i+1};
                    otherwise
                        error('Tag:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end

        function set.Criticality(obj, v)
            %SET.CRITICALITY Validate enum before assigning.
            valid = {'low', 'medium', 'high', 'safety'};
            if ~ischar(v) || ~any(strcmp(v, valid))
                error('Tag:invalidCriticality', ...
                    'Criticality must be one of: %s. Got: ''%s''.', ...
                    strjoin(valid, ', '), char(v));
            end
            obj.Criticality = v;
        end

        % ---- Abstract-by-convention (throw-from-base) ----
        % Pitfall 1 budget: EXACTLY 5 instance abstracts + 1 static = 6 total.

        function [X, Y] = getXY(obj) %#ok<STOUT,MANU>
            %GETXY Return [X, Y] data vectors.  Subclass must override.
            error('Tag:notImplemented', 'Subclass must implement getXY().');
        end

        function v = valueAt(obj, t) %#ok<STOUT,INUSD>
            %VALUEAT Return scalar value at time t.  Subclass must override.
            error('Tag:notImplemented', 'Subclass must implement valueAt(t).');
        end

        function [tMin, tMax] = getTimeRange(obj) %#ok<STOUT,MANU>
            %GETTIMERANGE Return [tMin, tMax] time bounds.  Subclass must override.
            error('Tag:notImplemented', 'Subclass must implement getTimeRange().');
        end

        function k = getKind(obj) %#ok<STOUT,MANU>
            %GETKIND Return kind string.  Subclass must override.
            error('Tag:notImplemented', 'Subclass must implement getKind().');
        end

        function s = toStruct(obj) %#ok<STOUT,MANU>
            %TOSTRUCT Return serializable struct.  Subclass must override.
            error('Tag:notImplemented', 'Subclass must implement toStruct().');
        end

        % ---- Default serialization hook (NOT abstract) ----

        function resolveRefs(obj, registry) %#ok<INUSD>
            %RESOLVEREFS Pass-2 hook for two-phase deserialization.
            %   Default: no-op.  CompositeTag (Phase 1008) will override to
            %   wire up children by key.  Leaf tags (Sensor/State/Monitor)
            %   do not need references resolved.
        end

        function addManualEvent(obj, tStart, tEnd, label, message) %#ok<INUSD>
            %ADDMANUALEVENT Create a manual annotation event bound to this tag.
            %   tag.addManualEvent(tStart, tEnd, label, message) creates an Event
            %   with Category = 'manual_annotation' and TagKeys = {obj.Key},
            %   appends to the bound EventStore, and registers in EventBinding.
            %
            %   Errors: Tag:noEventStore if EventStore is not bound.
            if isempty(obj.EventStore)
                error('Tag:noEventStore', 'Bind an EventStore before adding events.');
            end
            ev = Event(tStart, tEnd, char(obj.Key), label, NaN, 'upper');
            ev.Category = 'manual_annotation';
            obj.EventStore.append(ev);
            ev.TagKeys = {char(obj.Key)};
            EventBinding.attach(ev.Id, char(obj.Key));
        end

        function events = eventsAttached(obj)
            %EVENTSATTACHED Query events bound to this tag via EventBinding.
            %   Returns Event array (possibly empty). This is a query, NOT a
            %   stored property -- no Event handles on Tag (Pitfall 4).
            if isempty(obj.EventStore)
                events = [];
                return;
            end
            events = obj.EventStore.getEventsForTag(char(obj.Key));
        end
    end

    methods (Static)
        function obj = fromStruct(s) %#ok<STOUT,INUSD>
            %FROMSTRUCT Reconstruct a Tag from a struct.  Subclass must override.
            error('Tag:notImplemented', ...
                'fromStruct must be provided by a concrete Tag subclass.');
        end
    end
end
