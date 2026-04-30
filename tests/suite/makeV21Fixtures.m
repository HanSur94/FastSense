classdef MakeV21Fixtures
    %MAKEV21FIXTURES Phase 1015 migration-helper for legacy threshold-API → MonitorTag.
    %   Companion to MakePhase1009Fixtures.  Tests that previously
    %   built a legacy threshold construct + addCondition call now invoke
    %   MakeV21Fixtures.makeThresholdMonitor instead, getting back
    %   a registered MonitorTag bound to a parent SensorTag.
    %
    %   The helper is a pure shim: it does NOT change semantics, only
    %   the construction call site.  Migrated tests assert identical
    %   observable state (event count, run boundaries) as the
    %   pre-migration version.
    %
    %   Static methods:
    %     m = makeThresholdMonitor(key, parentTag, value, direction)
    %       — value     numeric scalar (legacy addCondition value operand)
    %       — direction 'upper' | 'lower' (legacy Direction NV pair)
    %       Builds condFn = @(x,y) y > value  if direction == 'upper'
    %                       @(x,y) y < value  if direction == 'lower'
    %       Registers in TagRegistry under `key`.
    %
    %   See also MakePhase1009Fixtures, MonitorTag, TagRegistry.

    methods (Static)

        function m = makeThresholdMonitor(key, parentTag, value, direction)
            %MAKETHRESHOLDMONITOR Legacy threshold value+direction → MonitorTag shim.
            if nargin < 4 || isempty(direction); direction = 'upper'; end
            if ~ischar(direction)
                error('MakeV21Fixtures:badDirection', ...
                    'direction must be ''upper'' or ''lower''.');
            end

            switch lower(direction)
                case 'upper'
                    condFn = @(x, y) y > value;
                case 'lower'
                    condFn = @(x, y) y < value;
                otherwise
                    error('MakeV21Fixtures:badDirection', ...
                        'direction must be ''upper'' or ''lower'', got ''%s''.', direction);
            end

            m = MonitorTag(key, parentTag, condFn);
            TagRegistry.register(key, m);
        end

    end
end
