classdef makePhase1009Fixtures
    %MAKEPHASE1009FIXTURES Shared Tag fixture factory for Phase 1009 tests.
    %   Provides static-method factories for SensorTag, MonitorTag,
    %   CompositeTag, and an ephemeral EventStore path.  Every factory
    %   REGISTERS the produced Tag with TagRegistry so round-trip tests
    %   can resolve by key — callers are responsible for invoking
    %   TagRegistry.clear() in TestMethodSetup / at the top of the test.
    %
    %   Default Y pattern mirrors the golden integration test fixture
    %   (tests/test_golden_integration.m lines 18-19) so assertions are
    %   known-good against the project's canonical synthetic sensor.
    %
    %   Static methods:
    %     t = makeSensorTag(key, varargin)          — SensorTag factory
    %     m = makeMonitorTag(key, parentTag, varargin) — MonitorTag factory
    %     c = makeCompositeTag(key, childTags, mode)   — CompositeTag factory
    %     tmpPath = makeEventStoreTmp()             — tempname with .mat ext
    %
    %   See also Tag, SensorTag, MonitorTag, CompositeTag, TagRegistry.

    methods (Static)

        function t = makeSensorTag(key, varargin)
            %MAKESENSORTAG Construct + register a SensorTag with golden Y pattern.
            %   Default X=1:20, Y mirrors golden_integration fixture.
            %   Varargin forwards to SensorTag constructor (overrides
            %   defaults when 'X' or 'Y' NV pair is passed).
            defX = 1:20;
            defY = [5 5 5 12 14 16 14 5 5 5 5 5 18 20 22 5 5 5 5 5];

            % Detect if caller supplied X or Y in varargin.
            hasX = false;
            hasY = false;
            for i = 1:2:numel(varargin)
                if i <= numel(varargin) && ischar(varargin{i})
                    if strcmp(varargin{i}, 'X'), hasX = true; end
                    if strcmp(varargin{i}, 'Y'), hasY = true; end
                end
            end

            args = varargin;
            if ~hasX, args = [args, {'X', defX}]; end
            if ~hasY, args = [args, {'Y', defY}]; end

            t = SensorTag(key, args{:});
            TagRegistry.register(key, t);
        end

        function m = makeMonitorTag(key, parentTag, varargin)
            %MAKEMONITORTAG Construct + register a MonitorTag on parentTag.
            %   Default condition: y > 15 (matches golden fixture — fires
            %   on peaks at Y=16, 18, 20, 22).  Varargin appended after
            %   condition (for 'MinDuration' / 'EventStore' NV pairs).
            cond = @(x, y) y > 15;
            m = MonitorTag(key, parentTag, cond, varargin{:});
            TagRegistry.register(key, m);
        end

        function c = makeCompositeTag(key, childTags, mode)
            %MAKECOMPOSITETAG Construct + register a CompositeTag.
            %   childTags — cell array of Tag handles to add as children.
            %   mode      — aggregate mode string ('and'|'or'|...).
            if nargin < 3 || isempty(mode), mode = 'and'; end
            c = CompositeTag(key, mode);
            for i = 1:numel(childTags)
                c.addChild(childTags{i});
            end
            TagRegistry.register(key, c);
        end

        function tmpPath = makeEventStoreTmp()
            %MAKEEVENTSTORETMP Return an ephemeral .mat path for EventStore.
            tmpPath = [tempname(), '.mat'];
        end

    end
end
