classdef DashboardWidgetRegistry
    %DASHBOARDWIDGETREGISTRY Single source of truth for dashboard widget types.
    %   DashboardWidgetRegistry maps a widget type string (e.g. 'number') to the
    %   class that implements it, so that EVERY consumer — DashboardEngine.addWidget,
    %   DashboardEngine.widgetTypes, DashboardSerializer.createWidgetFromStruct and
    %   DetachedMirror.cloneWidget — dispatches through ONE table instead of four
    %   hand-maintained switch statements that drift out of sync.
    %
    %   It mirrors the TagRegistry static-singleton pattern (a classdef of static
    %   methods over a persistent containers.Map), with three intentional deltas:
    %
    %     1. The catalog is seeded NON-empty on first use with the built-in widget
    %        types (TagRegistry starts empty).
    %     2. Type ALIASES (deprecated/renamed type strings) are a separate concern,
    %        resolved via resolveAlias() — e.g. the deprecated 'kpi' -> 'number'.
    %     3. reset() RE-SEEDS the built-ins and built-in aliases rather than wiping
    %        to empty; it exists for test isolation after register()/registerAlias().
    %
    %   DashboardWidgetRegistry Methods (Static, public):
    %     types          — sorted cellstr of all registered canonical type strings
    %     isRegistered   — true if a canonical type is registered (aliases excluded)
    %     resolveAlias   — map an alias to its canonical type (passthrough otherwise)
    %     constructorFor — the @ClassName constructor handle for a type (resolves alias)
    %     fromStruct     — deserialize a widget struct via the type's static fromStruct
    %     register       — add a NEW canonical type (hard error on collision)
    %     registerAlias  — add an alias for an already-registered canonical type
    %     reset          — restore the built-in catalog + aliases (test isolation)
    %
    %   Example:
    %     % Register a custom widget so it works through addWidget, serialization,
    %     % and detach with no core edits:
    %     DashboardWidgetRegistry.register('mywidget', @MyWidget);
    %     w = DashboardWidgetRegistry.fromStruct('mywidget', s);
    %
    %   See also DashboardWidget, DashboardEngine, DashboardSerializer,
    %   DetachedMirror, TagRegistry.

    methods (Static)

        function t = types()
            %TYPES Sorted cellstr of all registered canonical widget type strings.
            %   The single source of truth — DashboardEngine.widgetTypes() derives
            %   its list from this.
            t = sort(DashboardWidgetRegistry.registry().keys());
        end

        function tf = isRegistered(type)
            %ISREGISTERED True if TYPE is a registered canonical type.
            %   Aliases (e.g. 'kpi') are NOT counted — use resolveAlias() first if
            %   you need alias-aware membership.
            tf = DashboardWidgetRegistry.registry().isKey(type);
        end

        function c = resolveAlias(type)
            %RESOLVEALIAS Map an alias to its canonical type.
            %   Returns TYPE unchanged when it is not an alias.
            a = DashboardWidgetRegistry.aliases();
            if a.isKey(type)
                c = a(type);
            else
                c = type;
            end
        end

        function h = constructorFor(type)
            %CONSTRUCTORFOR Constructor handle (@ClassName) for a widget type.
            %   Resolves aliases first. Throws DashboardWidgetRegistry:unknownType
            %   when the (resolved) type is not registered.
            canonical = DashboardWidgetRegistry.resolveAlias(type);
            map = DashboardWidgetRegistry.registry();
            if ~map.isKey(canonical)
                error('DashboardWidgetRegistry:unknownType', ...
                    'Unknown widget type ''%s''. Use DashboardWidgetRegistry.types() to list registered types.', ...
                    type);
            end
            h = map(canonical);
        end

        function w = fromStruct(type, s)
            %FROMSTRUCT Deserialize a widget struct via its class fromStruct.
            %   w = DashboardWidgetRegistry.fromStruct(type, s) resolves TYPE to a
            %   constructor handle, derives the class name, and calls
            %   <Class>.fromStruct(s). Throws DashboardWidgetRegistry:unknownType
            %   when TYPE (resolved) is not registered.
            h = DashboardWidgetRegistry.constructorFor(type);
            className = func2str(h);
            % Named function handles stringify without a leading '@'; strip one
            % defensively in case a user registers an anonymous handle.
            if ~isempty(className) && className(1) == '@'
                className = className(2:end);
            end
            w = feval([className '.fromStruct'], s);
        end

        function register(type, ctorHandle)
            %REGISTER Add a NEW canonical widget type to the catalog.
            %   DashboardWidgetRegistry.register(type, @ClassName) registers a
            %   constructor handle under TYPE. Like TagRegistry.register, this
            %   HARD-ERRORS on collision (DashboardWidgetRegistry:duplicateType) so
            %   a custom widget cannot silently clobber a built-in. Call reset()
            %   to drop custom registrations (test isolation).
            %
            %   Errors:
            %     DashboardWidgetRegistry:invalidType    — ctorHandle is not a handle
            %     DashboardWidgetRegistry:duplicateType  — type already registered
            if ~isa(ctorHandle, 'function_handle')
                error('DashboardWidgetRegistry:invalidType', ...
                    'Constructor must be a function_handle, got %s.', class(ctorHandle));
            end
            map = DashboardWidgetRegistry.registry();
            if map.isKey(type)
                error('DashboardWidgetRegistry:duplicateType', ...
                    'Widget type ''%s'' is already registered. Choose a different type string.', type);
            end
            map(type) = ctorHandle;
        end

        function registerAlias(alias, canonical)
            %REGISTERALIAS Map an alias type string to a registered canonical type.
            %   The canonical type must already be registered, else
            %   DashboardWidgetRegistry:unknownType is thrown.
            map = DashboardWidgetRegistry.registry();
            if ~map.isKey(canonical)
                error('DashboardWidgetRegistry:unknownType', ...
                    'Cannot alias to unregistered type ''%s''.', canonical);
            end
            a = DashboardWidgetRegistry.aliases();
            a(alias) = canonical;
        end

        function reset()
            %RESET Restore the built-in catalog and aliases (test isolation).
            %   Re-seeds the persistent maps in place so register()/registerAlias()
            %   side effects from a prior test do not leak. Mirrors TagRegistry.clear,
            %   but re-seeds the built-ins rather than wiping to empty.
            map = DashboardWidgetRegistry.registry();
            k = map.keys();
            for i = 1:numel(k)
                map.remove(k{i});
            end
            DashboardWidgetRegistry.seedBuiltins_(map);

            a = DashboardWidgetRegistry.aliases();
            ka = a.keys();
            for i = 1:numel(ka)
                a.remove(ka{i});
            end
            DashboardWidgetRegistry.seedAliases_(a);
        end

    end

    methods (Static, Access = private)

        function map = registry()
            %REGISTRY Persistent type->constructor catalog (seeded on first use).
            persistent cache;
            if isempty(cache)
                cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
                DashboardWidgetRegistry.seedBuiltins_(cache);
            end
            map = cache;
        end

        function map = aliases()
            %ALIASES Persistent alias->canonical map (seeded on first use).
            persistent cache;
            if isempty(cache)
                cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
                DashboardWidgetRegistry.seedAliases_(cache);
            end
            map = cache;
        end

        function seedBuiltins_(map)
            %SEEDBUILTINS_ Populate MAP with the built-in widget type->constructor entries.
            map('fastsense')   = @FastSenseWidget;
            map('number')      = @NumberWidget;
            map('status')      = @StatusWidget;
            map('text')        = @TextWidget;
            map('gauge')       = @GaugeWidget;
            map('table')       = @TableWidget;
            map('rawaxes')     = @RawAxesWidget;
            map('timeline')    = @EventTimelineWidget;
            map('group')       = @GroupWidget;
            map('heatmap')     = @HeatmapWidget;
            map('barchart')    = @BarChartWidget;
            map('histogram')   = @HistogramWidget;
            map('scatter')     = @ScatterWidget;
            map('image')       = @ImageWidget;
            map('multistatus') = @MultiStatusWidget;
            map('divider')     = @DividerWidget;
            map('iconcard')    = @IconCardWidget;
            map('chipbar')     = @ChipBarWidget;
            map('sparkline')   = @SparklineCardWidget;
        end

        function seedAliases_(map)
            %SEEDALIASES_ Populate MAP with the built-in deprecated-type aliases.
            map('kpi') = 'number';   % 'kpi' was renamed to 'number'
        end

    end
end
