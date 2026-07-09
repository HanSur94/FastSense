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

        % ---- cumulativeIntegral tests (Issue #327) ----

        function testCumulativeIntegralUniformRamp(testCase)
            %TESTCUMULATIVEINTEGRALUNIFORMRAMP Uniform spacing, constant Y=2.
            %   X=0:4, Y=[2 2 2 2 2] => each segment area = 0.5*1*(2+2)=2.
            %   Expected cum = [0 2 4 6 8].
            t = SensorTag('ci_ramp', 'X', 0:1:4, 'Y', [2 2 2 2 2]);
            [x, cum] = t.cumulativeIntegral();
            testCase.verifyEqual(x, 0:1:4, 'AbsTol', 1e-12, ...
                'X must equal input X');
            testCase.verifyEqual(cum, [0 2 4 6 8], 'AbsTol', 1e-12, ...
                'Running integral of constant-2 series must be [0 2 4 6 8]');
        end

        function testCumulativeIntegralNonUniform(testCase)
            %TESTCUMULATIVEINTEGRALNON Nonuniform X spacing verification.
            %   X=[0 1 3 7], Y=[1 3 3 1].
            %   seg1: 0.5*1*(1+3)=2; seg2: 0.5*2*(3+3)=6; seg3: 0.5*4*(3+1)=8.
            %   Expected cum=[0 2 8 16], total=16.
            X = [0 1 3 7];
            Y = [1 3 3 1];
            t = SensorTag('ci_nonunif', 'X', X, 'Y', Y);
            [xOut, cum] = t.cumulativeIntegral();
            % Derive expected from the same formula used in the implementation
            dt       = diff(X);
            area     = 0.5 .* dt .* (Y(1:end-1) + Y(2:end));
            expected = [0, cumsum(area)];
            testCase.verifyEqual(xOut, X, 'AbsTol', 1e-12, 'X passthrough');
            testCase.verifyEqual(cum, expected, 'AbsTol', 1e-12, ...
                'Non-uniform spacing: running integral must match trapezoid formula');
            testCase.verifyEqual(cum(end), 16, 'AbsTol', 1e-12, ...
                'Grand total must equal 16');
        end

        function testCumulativeIntegralRangeWindow(testCase)
            %TESTCUMULATIVEINTEGRALRANGE 'Range' option restricts the window.
            %   Build a tag spanning 0:9; request [2 6]. Derive expected from
            %   the actual getXYRange return (one-point boundary padding may
            %   pull in a flanking sample).
            X = 0:1:9;
            Y = ones(1, 10);
            t = SensorTag('ci_range', 'X', X, 'Y', Y);
            t0 = 2; t1 = 6;
            [xWin, cumWin] = t.cumulativeIntegral('Range', [t0 t1]);
            % Derive expected from what getXYRange actually returns
            [xExp, yExp] = t.getXYRange(t0, t1);
            dt    = diff(xExp);
            areas = 0.5 .* dt .* (yExp(1:end-1) + yExp(2:end));
            cumExp = [0, cumsum(areas)];
            testCase.verifyEqual(xWin, xExp, 'AbsTol', 1e-12, ...
                'Windowed X must equal getXYRange return');
            testCase.verifyEqual(cumWin, cumExp, 'AbsTol', 1e-12, ...
                'Windowed running integral must start at 0');
            testCase.verifyEqual(cumWin(1), 0, 'AbsTol', 1e-12, ...
                'cum(1) must be 0 at the start of the window');
        end

        function testCumulativeIntegralScalarForm(testCase)
            %TESTCUMULATIVEINTEGRALSCALAR 1-out form returns scalar equal to cum(end).
            t = SensorTag('ci_scalar', 'X', 0:1:4, 'Y', [2 2 2 2 2]);
            [~, cum] = t.cumulativeIntegral();
            total    = t.cumulativeIntegral();
            testCase.verifyEqual(numel(total), 1, '1-out form must be scalar');
            testCase.verifyEqual(total, cum(end), 'AbsTol', 1e-12, ...
                '1-out total must equal 2-out cum(end)');
        end

        function testCumulativeIntegralEmptyData(testCase)
            %TESTCUMULATIVEINTEGRALEMPTY MockTag has no data; must return empty/0 without error.
            m = MockTag('ci_empty');
            [x, cum] = m.cumulativeIntegral();
            testCase.verifyEmpty(x,   '2-out X must be empty for empty data');
            testCase.verifyEmpty(cum, '2-out cum must be empty for empty data');
            total = m.cumulativeIntegral();
            testCase.verifyEqual(total, 0, 'AbsTol', 1e-12, ...
                '1-out form of empty data must return scalar 0');
        end

        function testCumulativeIntegralNaNGap(testCase)
            %TESTCUMULATIVEINTEGRALNANGAP Interior NaN must not poison the tail.
            %   X=0:4, Y=[1 1 NaN 1 1]; segments 2-3 and 3-4 are non-finite.
            %   Contributions zeroed; segments 1-2 and 4-5 must still accumulate.
            X = 0:1:4;
            Y = [1 1 NaN 1 1];
            t = SensorTag('ci_nan', 'X', X, 'Y', Y);
            [~, cum] = t.cumulativeIntegral();
            testCase.verifyTrue(isfinite(cum(end)), ...
                'cum(end) must be finite when interior NaN is zeroed');
            testCase.verifyTrue(cum(end) > 0, ...
                'Some area must accumulate outside the NaN gap');
            testCase.verifyTrue(all(isfinite(cum)), ...
                'All cum values after the gap must be finite (no NaN tail)');
        end

        function testCumulativeIntegralDiscreteWarns(testCase)
            %TESTCUMULATIVEINTEGRALDISCRETEWARN StateTag must emit Tag:integralOnDiscrete.
            st = StateTag('ci_disc', 'X', [0 1 2], 'Y', [0 1 0]);
            testCase.verifyWarning(@() st.cumulativeIntegral(), ...
                'Tag:integralOnDiscrete');
            % Also verify it still returns a numeric value (suppress warning for capture)
            warnState = warning('off', 'Tag:integralOnDiscrete');
            cleanupWarn = onCleanup(@() warning(warnState));
            total = st.cumulativeIntegral();
            testCase.verifyTrue(isnumeric(total), ...
                'cumulativeIntegral on StateTag must still return a numeric value');
        end

        function testCumulativeIntegralUnknownOption(testCase)
            %TESTCUMULATIVEINTEGRALUNKNOWNOPTION Bogus key must throw Tag:unknownOption.
            t = SensorTag('ci_bogus', 'X', 0:3, 'Y', [1 2 3 4]);
            testCase.verifyError(@() t.cumulativeIntegral('Bogus', 1), ...
                'Tag:unknownOption');
        end

        % ---- integral(t0, t1) tests (Issue #351) ----

        function testIntegralConstantFullSeries(testCase)
            %TESTINTEGRALCONSTANTFULLSERIES Constant y=2 over [0,10] => area 20.
            t = SensorTag('int_const', 'X', 0:1:10, 'Y', 2 * ones(1, 11));
            testCase.verifyEqual(t.integral(), 20, 'AbsTol', 1e-12, ...
                'Full-series integral of constant 2 over [0,10] must be 20');
        end

        function testIntegralTriangle(testCase)
            %TESTINTEGRALTRIANGLE Triangle ramp 0->4 over X=0:4 => area 8.
            %   trapz([0 1 2 3 4],[0 1 2 3 4]) = 8 (0.5*base*height = 0.5*4*4).
            t = SensorTag('int_tri', 'X', 0:1:4, 'Y', 0:1:4);
            testCase.verifyEqual(t.integral(), 8, 'AbsTol', 1e-12, ...
                'Triangle 0..4 must integrate to 8');
        end

        function testIntegralWindowMatchesRange(testCase)
            %TESTINTEGRALWINDOWMATCHESRANGE integral(t0,t1) == cumulativeIntegral('Range',...).
            X = 0:1:9;
            Y = (1:10) .^ 0.5;   % arbitrary non-uniform-value series
            t = SensorTag('int_win', 'X', X, 'Y', Y);
            t0 = 2; t1 = 6;
            expected = t.cumulativeIntegral('Range', [t0 t1]);
            testCase.verifyEqual(t.integral(t0, t1), expected, 'AbsTol', 1e-12, ...
                'Windowed integral must equal cumulativeIntegral Range end value');
        end

        function testIntegralEmptyBoundsIsFullSeries(testCase)
            %TESTINTEGRALEMPTYBOUNDS [] bounds integrate the full series.
            t = SensorTag('int_eb', 'X', 0:1:4, 'Y', [2 2 2 2 2]);
            testCase.verifyEqual(t.integral([], []), t.integral(), 'AbsTol', 1e-12, ...
                'integral([],[]) must equal integral() (full series)');
        end

        function testIntegralEmptyDataReturnsZero(testCase)
            %TESTINTEGRALEMPTYDATA No data => 0, no error.
            m = MockTag('int_empty');
            testCase.verifyEqual(m.integral(), 0, 'AbsTol', 1e-12, ...
                'Empty-data integral must return scalar 0');
        end

        function testIntegralNaNRobust(testCase)
            %TESTINTEGRALNANROBUST Interior NaN contributes zero area, no NaN result.
            t = SensorTag('int_nan', 'X', 0:1:4, 'Y', [1 1 NaN 1 1]);
            v = t.integral();
            testCase.verifyTrue(isfinite(v) && v > 0, ...
                'Integral with interior NaN must be finite and positive');
        end

        function testIntegralDiscreteWarns(testCase)
            %TESTINTEGRALDISCRETEWARNS StateTag integral emits Tag:integralOnDiscrete.
            st = StateTag('int_disc', 'X', [0 1 2], 'Y', [0 1 0]);
            testCase.verifyWarning(@() st.integral(), 'Tag:integralOnDiscrete');
        end

        % ---- percentile / median / iqr tests (Issue #339) ----

        function testPercentileScalarLevel(testCase)
            %TESTPERCENTILESCALARLEVEL Y=1:10 => P50 = 5.5 (linear interp).
            t = SensorTag('pc_scalar', 'X', 1:10, 'Y', 1:10);
            testCase.verifyEqual(t.percentile(50), 5.5, 'AbsTol', 1e-12);
        end

        function testPercentileVectorLevelsShape(testCase)
            %TESTPERCENTILEVECTORLEVELS Vector levels => vector values, same shape.
            t = SensorTag('pc_vec', 'X', 1:10, 'Y', 1:10);
            pv = t.percentile([0 25 50 75 100]);
            testCase.verifyEqual(size(pv), [1 5], 'shape matches levels');
            testCase.verifyEqual(pv, [1 3.25 5.5 7.75 10], 'AbsTol', 1e-12);
        end

        function testMedianEqualsP50(testCase)
            t = SensorTag('pc_med', 'X', 1:10, 'Y', 1:10);
            testCase.verifyEqual(t.median(), t.percentile(50), 'AbsTol', 1e-12);
        end

        function testIqrEqualsP75MinusP25(testCase)
            %TESTIQR Y=1:10 => IQR = 7.75 - 3.25 = 4.5.
            t = SensorTag('pc_iqr', 'X', 1:10, 'Y', 1:10);
            testCase.verifyEqual(t.iqr(), 4.5, 'AbsTol', 1e-12);
        end

        function testPercentileWindow(testCase)
            %TESTPERCENTILEWINDOW Range args restrict the reduction window.
            t = SensorTag('pc_win', 'X', 1:10, 'Y', 1:10);
            [~, yWin] = t.getXYRange(3, 7);
            ys = sort(yWin(~isnan(yWin))); ys = ys(:);
            n = numel(ys);
            i50  = 0.5 * (n - 1) + 1;
            expected = ys(floor(i50)) + (i50 - floor(i50)) * ...
                (ys(ceil(i50)) - ys(floor(i50)));
            testCase.verifyEqual(t.percentile(50, 3, 7), expected, 'AbsTol', 1e-12);
        end

        function testPercentileNaNRobust(testCase)
            %TESTPERCENTILENANROBUST NaNs are masked; P50 ignores them.
            t = SensorTag('pc_nan', 'X', 1:5, 'Y', [1 NaN 3 NaN 5]);
            testCase.verifyEqual(t.percentile(50), 3, 'AbsTol', 1e-12);
        end

        function testPercentileEmptyDataReturnsNaN(testCase)
            m = MockTag('pc_empty');
            testCase.verifyTrue(isnan(m.percentile(50)), 'empty -> NaN');
        end

        function testPercentileInvalidLevelErrors(testCase)
            t = SensorTag('pc_bad', 'X', 1:10, 'Y', 1:10);
            testCase.verifyError(@() t.percentile(150), 'Tag:invalidPercentile');
            testCase.verifyError(@() t.percentile(-1),  'Tag:invalidPercentile');
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
