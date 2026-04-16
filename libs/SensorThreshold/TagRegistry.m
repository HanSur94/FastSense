classdef TagRegistry
    %TAGREGISTRY Singleton catalog of named Tag entities.
    %   TagRegistry provides a centralized, persistent catalog of all
    %   known Tag objects in the v2.0 domain model.  It mirrors the
    %   ThresholdRegistry API for CRUD / query / introspection, with
    %   three intentional deltas:
    %
    %     1. register() HARD-ERRORS on duplicate key (Pitfall 7).
    %        ThresholdRegistry silently overwrites — TagRegistry does
    %        not, to prevent subtle identity bugs when two different
    %        tags claim the same key.
    %     2. loadFromStructs() uses two-phase deserialization
    %        (Pitfall 8):
    %          Pass 1 — instantiate every tag with empty children.
    %          Pass 2 — call tag.resolveRefs(registry) on each.
    %        This is order-insensitive; no silent try/warn/skip.  Any
    %        resolveRefs failure is wrapped as TagRegistry unresolvedRef.
    %     3. findByKind() replaces findByDirection() because Tag is
    %        multi-kind (sensor | state | monitor | composite | mock).
    %
    %   The catalog starts EMPTY on first use.
    %
    %   TagRegistry Methods (Static, public):
    %     get             — retrieve Tag by key; errors if missing
    %     register        — add Tag to catalog; hard error on duplicate
    %     unregister      — remove Tag (silent no-op if missing)
    %     clear           — wipe catalog
    %     find            — tags matching predicate fn
    %     findByLabel     — tags carrying a given label (META-02)
    %     findByKind      — tags whose getKind() matches
    %     list            — print sorted keys + names to command window
    %     printTable      — detailed table (Key/Name/Kind/Criticality/Units/Labels)
    %     viewer          — uitable GUI (Octave-safe)
    %     loadFromStructs — two-phase JSON round-trip (TAG-06, TAG-07)
    %     instantiateByKind — dispatch s.kind -> the right fromStruct
    %
    %   Example:
    %     t = SensorTag('press_a', 'Labels', {'pressure', 'critical'});
    %     TagRegistry.register('press_a', t);
    %     got = TagRegistry.get('press_a');
    %     critical = TagRegistry.findByLabel('critical');
    %
    %   See also Tag, MockTag, ThresholdRegistry.

    methods (Static)

        function t = get(key)
            %GET Retrieve a Tag by key.
            %   t = TagRegistry.get(key) returns the Tag stored under key.
            %   Throws TagRegistry unknownKey if not registered.
            %
            %   Input:
            %     key — char, unique identifier
            %
            %   Output:
            %     t — Tag handle

            map = TagRegistry.catalog();
            if ~map.isKey(key)
                error('TagRegistry:unknownKey', ...
                    'No tag registered with key ''%s''. Use TagRegistry.list() to see available keys.', ...
                    key);
            end
            t = map(key);
        end

        function register(key, tag)
            %REGISTER Add a Tag to the catalog (hard error on collision).
            %   TagRegistry.register(key, tag) stores tag under key.
            %   Unlike ThresholdRegistry (which silently overwrites), this
            %   registry HARD-ERRORS on collision with TagRegistry
            %   duplicateKey (Pitfall 7).  Call TagRegistry.unregister(key)
            %   first to replace an existing entry.
            %
            %   Inputs:
            %     key — char, unique identifier
            %     tag — Tag object
            %
            %   Errors:
            %     TagRegistry invalidType   — tag is not a Tag object
            %     TagRegistry duplicateKey  — key already in catalog

            if ~isa(tag, 'Tag')
                error('TagRegistry:invalidType', ...
                    'Value must be a Tag object, got %s.', class(tag));
            end
            map = TagRegistry.catalog();
            if map.isKey(key)
                existing = map(key);
                error('TagRegistry:duplicateKey', ...
                    'Key ''%s'' already registered (existing kind=''%s'', new kind=''%s''). Call TagRegistry.unregister(key) first to replace.', ...
                    key, existing.getKind(), tag.getKind());
            end
            map(key) = tag;
        end

        function unregister(key)
            %UNREGISTER Remove a Tag (silent no-op if missing).
            %
            %   Input:
            %     key — char, identifier to remove

            map = TagRegistry.catalog();
            if map.isKey(key)
                map.remove(key);
            end
        end

        function clear()
            %CLEAR Wipe the catalog.  Primarily for test isolation.
            map = TagRegistry.catalog();
            k = map.keys();
            for i = 1:numel(k)
                map.remove(k{i});
            end
        end

        function ts = find(predicateFn)
            %FIND Return cell of Tags matching predicateFn(tag) -> logical.
            %
            %   Input:
            %     predicateFn — function handle accepting a Tag, returning logical
            %
            %   Output:
            %     ts — cell array of Tag handles (may be empty)

            map = TagRegistry.catalog();
            keys = map.keys();
            ts = {};
            for i = 1:numel(keys)
                t = map(keys{i});
                if predicateFn(t)
                    ts{end+1} = t; %#ok<AGROW>
                end
            end
        end

        function ts = findByLabel(label)
            %FINDBYLABEL Return cell of Tags carrying the given label (META-02).
            %
            %   Input:
            %     label — char, label string to search for
            %
            %   Output:
            %     ts — cell array of Tag handles (may be empty)

            map = TagRegistry.catalog();
            keys = map.keys();
            ts = {};
            for i = 1:numel(keys)
                t = map(keys{i});
                if ~isempty(t.Labels) && any(strcmp(t.Labels, label))
                    ts{end+1} = t; %#ok<AGROW>
                end
            end
        end

        function ts = findByKind(kind)
            %FINDBYKIND Return cell of Tags where getKind() == kind.
            %
            %   Input:
            %     kind — char, e.g. 'sensor' | 'state' | 'monitor' | 'composite' | 'mock'
            %
            %   Output:
            %     ts — cell array of Tag handles (may be empty)

            map = TagRegistry.catalog();
            keys = map.keys();
            ts = {};
            for i = 1:numel(keys)
                t = map(keys{i});
                if strcmp(t.getKind(), kind)
                    ts{end+1} = t; %#ok<AGROW>
                end
            end
        end

        function list()
            %LIST Print sorted keys + names to command window.
            map = TagRegistry.catalog();
            keys = sort(map.keys());
            fprintf('\n  Available tags:\n');
            for i = 1:numel(keys)
                t = map(keys{i});
                name = t.Name;
                if isempty(name); name = '(no name)'; end
                fprintf('    %-25s  %s\n', keys{i}, name);
            end
            fprintf('\n');
        end

        function printTable()
            %PRINTTABLE Print Key/Name/Kind/Criticality/Units/Labels table.
            map = TagRegistry.catalog();
            keys = sort(map.keys());
            nTag = numel(keys);

            if nTag == 0
                fprintf('No tags registered.\n');
                return;
            end

            fprintf('\n');
            fprintf('  %-22s %-25s %-10s %-11s %-10s %s\n', ...
                'Key', 'Name', 'Kind', 'Criticality', 'Units', 'Labels');
            fprintf('  %s\n', repmat('-', 1, 110));

            for i = 1:nTag
                t = map(keys{i});
                name = t.Name;
                if isempty(name); name = ''; end
                labelStr = '';
                if ~isempty(t.Labels)
                    labelStr = strjoin(t.Labels, ', ');
                end
                fprintf('  %-22s %-25s %-10s %-11s %-10s %s\n', ...
                    TagRegistry.truncStr(keys{i}, 22), ...
                    TagRegistry.truncStr(name, 25), ...
                    t.getKind(), ...
                    t.Criticality, ...
                    t.Units, ...
                    labelStr);
            end
            fprintf('\n  %d tag(s) total.\n\n', nTag);
        end

        function hFig = viewer()
            %VIEWER Open uitable GUI showing all registered tags (Octave-safe).
            map = TagRegistry.catalog();
            keys = sort(map.keys());
            nTag = numel(keys);

            colNames = {'Key', 'Name', 'Kind', 'Criticality', 'Units', 'Labels'};
            data = cell(nTag, numel(colNames));
            for i = 1:nTag
                t = map(keys{i});
                data{i,1} = keys{i};
                data{i,2} = t.Name;
                data{i,3} = t.getKind();
                data{i,4} = t.Criticality;
                data{i,5} = t.Units;
                labelStr = '';
                if ~isempty(t.Labels)
                    labelStr = strjoin(t.Labels, ', ');
                end
                data{i,6} = labelStr;
            end

            hFig = figure('Name', 'Tag Registry', ...
                'NumberTitle', 'off', ...
                'Position', [200 200 900 400], ...
                'Color', [0.15 0.15 0.18], ...
                'MenuBar', 'none', 'ToolBar', 'none');

            uicontrol('Parent', hFig, 'Style', 'text', ...
                'String', sprintf('Tag Registry  (%d tags)', nTag), ...
                'Units', 'normalized', 'Position', [0.02 0.92 0.96 0.06], ...
                'BackgroundColor', [0.15 0.15 0.18], ...
                'ForegroundColor', [0.9 0.9 0.9], ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left');

            uitable('Parent', hFig, ...
                'Data', data, ...
                'ColumnName', colNames, ...
                'ColumnWidth', {150, 180, 80, 100, 80, 220}, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.96 0.88], ...
                'RowName', [], ...
                'BackgroundColor', [0.22 0.22 0.25; 0.18 0.18 0.21], ...
                'ForegroundColor', [0.9 0.9 0.9], ...
                'FontSize', 11);
        end

        function loadFromStructs(structs)
            %LOADFROMSTRUCTS Two-phase JSON deserialization (TAG-06, Pitfall 8).
            %   Pass 1: instantiate every tag with empty children and
            %           register it via TagRegistry.register (so duplicate
            %           keys in the input surface as TagRegistry
            %           duplicateKey, and unknown kinds surface as
            %           TagRegistry unknownKind).
            %   Pass 2: call tag.resolveRefs(catalog) on every registered
            %           tag.  Any error raised during Pass 2 is wrapped
            %           and rethrown as TagRegistry unresolvedRef — never
            %           silently swallowed.
            %
            %   Inputs:
            %     structs — cell array OR struct array of tag structs
            %               (each struct must carry a 'kind' field used
            %               by instantiateByKind to dispatch to the
            %               appropriate fromStruct).
            %
            %   Errors:
            %     TagRegistry unknownKind   — struct.kind missing / not dispatched
            %     TagRegistry duplicateKey  — two structs share the same key
            %     TagRegistry unresolvedRef — any resolveRefs throws

            % Normalise struct-array to cell-of-structs (CompositeThreshold pattern).
            if isstruct(structs)
                tmp = cell(1, numel(structs));
                for i = 1:numel(structs)
                    tmp{i} = structs(i);
                end
                structs = tmp;
            end

            % Pass 1 — instantiate and register.
            for i = 1:numel(structs)
                s = structs{i};
                tag = TagRegistry.instantiateByKind(s);
                TagRegistry.register(tag.Key, tag);  % hard-errors on duplicate
            end

            % Pass 2 — resolve cross-references.
            map = TagRegistry.catalog();
            keys = map.keys();
            for i = 1:numel(keys)
                tag = map(keys{i});
                try
                    tag.resolveRefs(map);
                catch me
                    error('TagRegistry:unresolvedRef', ...
                        'Tag ''%s'' failed to resolve refs: %s', ...
                        keys{i}, me.message);
                end
            end
        end

        function tag = instantiateByKind(s)
            %INSTANTIATEBYKIND Dispatch fromStruct based on s.kind.
            %   Phase 1004 ships 'mock' and 'mockThrowingResolve' only
            %   (tests).  Phase 1005+ extends the switch for sensor,
            %   state, monitor, and composite kinds.
            %
            %   Errors:
            %     TagRegistry unknownKind — s.kind missing or unrecognized

            if ~isfield(s, 'kind') || isempty(s.kind)
                error('TagRegistry:unknownKind', ...
                    'Struct is missing the required ''kind'' field.');
            end
            kind = lower(s.kind);
            switch kind
                case 'mock'
                    tag = MockTag.fromStruct(s);
                case 'mockthrowingresolve'
                    tag = MockTagThrowingResolve.fromStruct(s);
                case 'sensor'
                    tag = SensorTag.fromStruct(s);
                case 'state'
                    tag = StateTag.fromStruct(s);
                case 'monitor'
                    tag = MonitorTag.fromStruct(s);
                case 'composite'
                    tag = CompositeTag.fromStruct(s);
                otherwise
                    error('TagRegistry:unknownKind', ...
                        'Unknown tag kind ''%s''. Valid kinds (Phase 1008): mock, sensor, state, monitor, composite.', ...
                        kind);
            end
        end

    end

    methods (Static, Access = private)

        function s = truncStr(s, maxLen)
            %TRUNCSTR Truncate string to maxLen with trailing '..'.
            if numel(s) > maxLen
                s = [s(1:maxLen-2), '..'];
            end
        end

        function map = catalog()
            %CATALOG Return the persistent containers.Map catalog.
            %   Singleton; the map is created empty on first call and
            %   cached in a persistent variable thereafter.  Tests call
            %   TagRegistry.clear() to reset state between runs.
            persistent cache;
            if isempty(cache)
                cache = containers.Map();
            end
            map = cache;
        end

    end
end
