classdef TestTag < matlab.unittest.TestCase
    %TESTTAG Unit tests for the Tag abstract base class.
    %   Covers (Phase 1004-01):
    %     - Constructor required-Key validation (Tag:invalidKey)
    %     - Default property values (Key, Name, Units, Description,
    %       Labels, Metadata, Criticality, SourceRef)
    %     - Name-value constructor parsing
    %     - Unknown option rejection (Tag:unknownOption)
    %     - Labels default and assignment (META-01)
    %     - Metadata open-struct behavior (META-03)
    %     - Criticality enum validation (META-04, Tag:invalidCriticality)
    %     - Abstract-by-convention stubs (TAG-01): all 6 methods throw
    %       Tag:notImplemented when invoked on the base class
    %     - resolveRefs default no-op hook (NOT abstract)
    %     - Pitfall 1 gate: exactly 6 'Tag:notImplemented' occurrences in Tag.m
    %
    %   See also Tag, MockTag, TestCompositeThreshold.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)

        function testConstructorRequiresKey(testCase)
            % Key must be non-empty char. Empty-string key must throw
            % Tag:invalidKey. (Calling MockTag() with zero args would fail
            % in the MockTag constructor forwarding line with MATLAB:minrhs
            % before reaching Tag's nargin<1 check — not a meaningful
            % contract probe, so we only exercise the empty-string case.)
            testCase.verifyError(@() MockTag(''), 'Tag:invalidKey');
        end

        function testConstructorDefaults(testCase)
            t = MockTag('k');
            testCase.verifyEqual(t.Key, 'k');
            testCase.verifyEqual(t.Name, 'k');  % defaults to Key
            testCase.verifyEqual(t.Units, '');
            testCase.verifyEqual(t.Description, '');
            testCase.verifyTrue(iscell(t.Labels));
            testCase.verifyEmpty(t.Labels);
            testCase.verifyTrue(isempty(fieldnames(t.Metadata)));
            testCase.verifyEqual(t.Criticality, 'medium');
            testCase.verifyEqual(t.SourceRef, '');
        end

        function testConstructorNameValuePairs(testCase)
            t = MockTag('k', 'Name', 'Pump A', 'Units', 'bar', ...
                'Description', 'main pump', ...
                'Labels', {'alpha', 'beta'}, ...
                'Metadata', struct('asset', 'p3'), ...
                'Criticality', 'safety', ...
                'SourceRef', 'file.mat');
            testCase.verifyEqual(t.Name, 'Pump A');
            testCase.verifyEqual(t.Units, 'bar');
            testCase.verifyEqual(t.Description, 'main pump');
            testCase.verifyEqual(numel(t.Labels), 2);
            testCase.verifyEqual(t.Labels{1}, 'alpha');
            testCase.verifyEqual(t.Labels{2}, 'beta');
            testCase.verifyEqual(t.Metadata.asset, 'p3');
            testCase.verifyEqual(t.Criticality, 'safety');
            testCase.verifyEqual(t.SourceRef, 'file.mat');
        end

        function testConstructorUnknownOptionErrors(testCase)
            testCase.verifyError(@() MockTag('k', 'Bogus', 1), 'Tag:unknownOption');
        end

        function testLabelsDefault(testCase)
            t = MockTag('k');
            testCase.verifyTrue(iscell(t.Labels));
            testCase.verifyEmpty(t.Labels);
        end

        function testLabelsAssign(testCase)
            t = MockTag('k');
            t.Labels = {'x', 'y'};
            testCase.verifyEqual(numel(t.Labels), 2);
            testCase.verifyEqual(t.Labels{1}, 'x');
            testCase.verifyEqual(t.Labels{2}, 'y');
        end

        function testMetadataOpenStruct(testCase)
            t = MockTag('k');
            t.Metadata.asset = 'pump-3';
            t.Metadata.vendor = 'Acme';
            testCase.verifyEqual(t.Metadata.asset, 'pump-3');
            testCase.verifyEqual(t.Metadata.vendor, 'Acme');
        end

        function testMetadataEmptyByDefault(testCase)
            testCase.verifyTrue(isempty(fieldnames(MockTag('k').Metadata)));
        end

        function testCriticalityDefault(testCase)
            testCase.verifyEqual(MockTag('k').Criticality, 'medium');
        end

        function testCriticalityAllValidValues(testCase)
            valid = {'low', 'medium', 'high', 'safety'};
            for i = 1:numel(valid)
                t = MockTag('k', 'Criticality', valid{i});
                testCase.verifyEqual(t.Criticality, valid{i});
            end
        end

        function testCriticalityInvalidInConstructor(testCase)
            testCase.verifyError(@() MockTag('k', 'Criticality', 'emergency'), ...
                'Tag:invalidCriticality');
        end

        function testCriticalityInvalidViaSetter(testCase)
            t = MockTag('k');
            testCase.verifyError(@() assignCriticality(t, 'bogus'), ...
                'Tag:invalidCriticality');
        end

        function testAbstractGetXYThrows(testCase)
            % Tag is abstract-by-convention (NOT declared Abstract), so the
            % base class is instantiable; calling any stub raises notImplemented.
            t = Tag('k');
            testCase.verifyError(@() t.getXY(), 'Tag:notImplemented');
        end

        function testAbstractValueAtThrows(testCase)
            t = Tag('k');
            testCase.verifyError(@() t.valueAt(0), 'Tag:notImplemented');
        end

        function testAbstractGetTimeRangeThrows(testCase)
            t = Tag('k');
            testCase.verifyError(@() t.getTimeRange(), 'Tag:notImplemented');
        end

        function testAbstractGetKindThrows(testCase)
            t = Tag('k');
            testCase.verifyError(@() t.getKind(), 'Tag:notImplemented');
        end

        function testAbstractToStructThrows(testCase)
            t = Tag('k');
            testCase.verifyError(@() t.toStruct(), 'Tag:notImplemented');
        end

        function testAbstractFromStructThrows(testCase)
            testCase.verifyError(@() Tag.fromStruct(struct()), 'Tag:notImplemented');
        end

        function testResolveRefsDefaultIsNoOp(testCase)
            t = MockTag('k');
            fakeRegistry = containers.Map();
            % Should not throw — default is no-op.
            t.resolveRefs(fakeRegistry);
            testCase.verifyTrue(true);  % reaching here proves no throw
        end

        function testDataChangedEventFiresOnSensorTagUpdate(testCase)
            % SensorTag.updateData must fire the Tag 'DataChanged' event
            % so dashboard listeners can react to data replacement.
            % Octave hasn't implemented notify(); skip there.
            testCase.assumeTrue(exist('OCTAVE_VERSION', 'builtin') == 0, ...
                'notify() not implemented in Octave');
            s = SensorTag('t_event', 'X', 1:3, 'Y', [1 1 1]);
            % containers.Map is a handle — closure mutation persists.
            box = containers.Map('KeyType', 'char', 'ValueType', 'double');
            box('count') = 0;
            lh = addlistener(s, 'DataChanged', ...
                @(~,~) bumpMap_(box, 'count'));
            testCase.addTeardown(@() delete(lh));
            s.updateData(1:5, [1 2 3 4 5]);
            s.updateData(1:2, [9 9]);
            testCase.verifyEqual(box('count'), 2, ...
                'DataChanged must fire on every updateData call');
        end

        function testDataChangedEventFiresOnStateTagUpdate(testCase)
            testCase.assumeTrue(exist('OCTAVE_VERSION', 'builtin') == 0, ...
                'notify() not implemented in Octave');
            s = StateTag('st_event');
            box = containers.Map('KeyType', 'char', 'ValueType', 'double');
            box('count') = 0;
            lh = addlistener(s, 'DataChanged', ...
                @(~,~) bumpMap_(box, 'count'));
            testCase.addTeardown(@() delete(lh));
            s.updateData(1:3, [0 1 0]);
            testCase.verifyEqual(box('count'), 1, ...
                'StateTag.updateData must fire DataChanged');
        end

        function testLiveEventPipelineAcceptsMonitorsNVPair(testCase)
            % Constructor first positional is legacy 'sensors'; real
            % Tag-path callers pass the monitor map via 'Monitors' NV.
            % Regression guard — parseOpts used to silently drop unknown
            % NV keys, leaving MonitorTargets empty.
            emptyMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            dsMap   = DataSourceMap();
            monMap  = containers.Map('KeyType', 'char', 'ValueType', 'any');
            monMap('key1') = 'stub';  % any value; we only check routing
            pipeline = LiveEventPipeline(emptyMap, dsMap, ...
                'Monitors', monMap, 'Interval', 60);
            testCase.verifyEqual(pipeline.MonitorTargets.Count, uint64(1), ...
                '''Monitors'' NV-pair must populate MonitorTargets');
            testCase.verifyTrue(pipeline.MonitorTargets.isKey('key1'), ...
                '''Monitors'' NV map must be used verbatim');
        end

        function testFastSenseDataStoreGetRangeInvertedIsEmpty(testCase)
            % getRange with xMin > xMax must return empty, not error
            % inside fread with a negative count.
            ds = FastSenseDataStore(1:1000, sin(1:1000));
            testCase.addTeardown(@() ds.cleanup());
            [xr, yr] = ds.getRange(500, 100);
            testCase.verifyEmpty(xr, 'inverted range -> empty X');
            testCase.verifyEmpty(yr, 'inverted range -> empty Y');
        end

        function testAbstractMethodCount(testCase)
            %TESTABSTRACTMETHODCOUNT Pitfall 1 gate: exactly 6 abstract stubs.
            %   Tag.m must contain exactly 6 'Tag:notImplemented' error calls
            %   — one per abstract-by-convention method
            %   (getXY, valueAt, getTimeRange, getKind, toStruct, fromStruct).
            tagPath = which('Tag');
            testCase.assertNotEmpty(tagPath, 'Tag.m not found on path.');
            src = fileread(tagPath);
            count = numel(strfind(src, 'Tag:notImplemented'));
            testCase.verifyEqual(count, 6, ...
                sprintf('Expected exactly 6 abstract-by-convention stubs, got %d', count));
        end

    end
end

function assignCriticality(t, v)
    %ASSIGNCRITICALITY Helper to invoke the Criticality setter in a callable form.
    t.Criticality = v;
end

function bumpMap_(m, key)
    %BUMPMAP_ Increment an integer counter stored in a containers.Map
    %   by key. Used by DataChanged listener tests as a handle-semantic
    %   counter (local structs in MATLAB are value-copied).
    m(key) = m(key) + 1;
end
