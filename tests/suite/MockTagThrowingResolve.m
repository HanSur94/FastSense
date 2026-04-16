classdef MockTagThrowingResolve < MockTag
    %MOCKTAGTHROWINGRESOLVE Test helper: resolveRefs deliberately throws.
    %   Used by TestTagRegistry.testLoadFromStructsUnresolvedRefErrors to
    %   exercise TagRegistry's Pitfall 8 behaviour: any resolveRefs error
    %   raised in Pass 2 of loadFromStructs must be wrapped and rethrown
    %   as TagRegistry:unresolvedRef (never silently swallowed).
    %
    %   The originating error identifier is the MockTagThrowingResolve
    %   deliberate-failure code defined in resolveRefs below.  The registry
    %   wrapper is expected to replace that identifier with the
    %   TagRegistry unresolvedRef code while preserving the original
    %   message context.
    %
    %   The kind string is overridden to 'mockThrowingResolve' so the
    %   TagRegistry.instantiateByKind dispatch table can route structs
    %   produced by this class back through MockTagThrowingResolve.fromStruct
    %   during round-trip deserialization tests.
    %
    %   See also MockTag, TagRegistry, TestTagRegistry.

    methods
        function obj = MockTagThrowingResolve(key, varargin)
            %MOCKTAGTHROWINGRESOLVE Delegate to MockTag constructor.
            obj@MockTag(key, varargin{:});
        end

        function resolveRefs(obj, registry) %#ok<INUSD>
            %RESOLVEREFS Deliberately throw to exercise Pitfall 8 wrapping.
            error('MockTagThrowingResolve:deliberate', ...
                'deliberate resolveRefs failure for test');
        end

        function s = toStruct(obj)
            %TOSTRUCT Serialize, tagging kind as 'mockThrowingResolve'.
            s = toStruct@MockTag(obj);
            s.kind = 'mockThrowingResolve';
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            %FROMSTRUCT Reconstruct a MockTagThrowingResolve from struct.
            obj = MockTagThrowingResolve(s.key);
        end
    end
end
