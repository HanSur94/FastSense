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

        % ---- findPeaks tests (Issue #329) ----

        function testFindPeaksSingle(testCase)
            t = SensorTag('fp_one', 'X', 1:5, 'Y', [0 1 3 1 0]);
            p = t.findPeaks();
            testCase.verifyEqual(p.count, 1);
            testCase.verifyEqual(p.times, 3, 'AbsTol', 1e-12);
            testCase.verifyEqual(p.values, 3, 'AbsTol', 1e-12);
            testCase.verifyEqual(p.prominences, 3, 'AbsTol', 1e-12);
            testCase.verifyEqual(p.polarity, 1);
        end

        function testFindPeaksMultipleCountAndIntervals(testCase)
            t = SensorTag('fp_multi', 'X', 1:7, 'Y', [0 2 0 4 0 1 0]);
            p = t.findPeaks();
            testCase.verifyEqual(p.count, 3);
            testCase.verifyEqual(p.times, [2 4 6], 'AbsTol', 1e-12);
            testCase.verifyEqual(p.values, [2 4 1], 'AbsTol', 1e-12);
            testCase.verifyEqual(p.intervals, [2 2], 'AbsTol', 1e-12);
        end

        function testFindPeaksProminenceFilter(testCase)
            t = SensorTag('fp_prom', 'X', 1:7, 'Y', [0 2 0 4 0 1 0]);
            p = t.findPeaks('MinProminence', 3);
            testCase.verifyEqual(p.count, 1, 'only the prom-4 peak survives');
            testCase.verifyEqual(p.times, 4, 'AbsTol', 1e-12);
        end

        function testFindPeaksSeparationMerge(testCase)
            % Two peaks 1 x-unit apart; MinSeparation 2 keeps the more prominent.
            t = SensorTag('fp_sep', 'X', 1:6, 'Y', [0 2 0 5 0 0]);
            p = t.findPeaks('MinSeparation', 3);
            testCase.verifyEqual(p.count, 1);
            testCase.verifyEqual(p.times, 4, 'AbsTol', 1e-12, 'keeps prom-5 peak at t=4');
        end

        function testFindPeaksFlatTopPlateau(testCase)
            t = SensorTag('fp_flat', 'X', 1:7, 'Y', [0 1 2 2 2 1 0]);
            p = t.findPeaks();
            testCase.verifyEqual(p.count, 1, 'one peak per plateau');
            testCase.verifyEqual(p.values, 2, 'AbsTol', 1e-12);
            testCase.verifyEqual(p.times, 4, 'AbsTol', 1e-12, 'plateau midpoint');
        end

        function testFindPeaksMinimaPolarity(testCase)
            t = SensorTag('fp_min', 'X', 1:5, 'Y', [0 -1 -3 -1 0]);
            p = t.findPeaks('Polarity', 'min');
            testCase.verifyEqual(p.count, 1);
            testCase.verifyEqual(p.times, 3, 'AbsTol', 1e-12);
            testCase.verifyEqual(p.values, -3, 'AbsTol', 1e-12);
            testCase.verifyEqual(p.prominences, 3, 'AbsTol', 1e-12, 'positive depth');
            testCase.verifyEqual(p.polarity, -1);
        end

        function testFindPeaksBothPolarity(testCase)
            t = SensorTag('fp_both', 'X', 1:5, 'Y', [0 3 0 -3 0]);
            p = t.findPeaks('Polarity', 'both');
            testCase.verifyEqual(p.count, 2);
            testCase.verifyEqual(p.times, [2 4], 'AbsTol', 1e-12);
            testCase.verifyEqual(p.polarity, [1 -1]);
        end

        function testFindPeaksNaNGap(testCase)
            t = SensorTag('fp_nan', 'X', 1:7, 'Y', [0 2 0 NaN 0 3 0]);
            p = t.findPeaks();
            testCase.verifyEqual(p.count, 2, 'NaN splits the series into segments');
            testCase.verifyEqual(p.times, [2 6], 'AbsTol', 1e-12);
        end

        function testFindPeaksRangeSubset(testCase)
            t = SensorTag('fp_rng', 'X', 1:7, 'Y', [0 2 0 4 0 1 0]);
            p = t.findPeaks('Range', [3 7]);
            testCase.verifyTrue(all(p.times >= 3 & p.times <= 7));
            testCase.verifyTrue(ismember(4, p.times), 'peak at t=4 within window');
        end

        function testFindPeaksTwoOutForm(testCase)
            t = SensorTag('fp_2out', 'X', 1:7, 'Y', [0 2 0 4 0 1 0]);
            [tt, vv] = t.findPeaks();
            testCase.verifyEqual(tt, [2 4 6], 'AbsTol', 1e-12);
            testCase.verifyEqual(vv, [2 4 1], 'AbsTol', 1e-12);
        end

        function testFindPeaksUnknownOptionErrors(testCase)
            t = SensorTag('fp_bad', 'X', 1:5, 'Y', [0 1 3 1 0]);
            testCase.verifyError(@() t.findPeaks('Bogus', 1), 'Tag:unknownOption');
            testCase.verifyError(@() t.findPeaks('Polarity', 'sideways'), ...
                'Tag:findPeaksBadOption');
        end

        function testFindPeaksDiscreteWarns(testCase)
            st = StateTag('fp_disc', 'X', 1:5, 'Y', [0 1 3 1 0]);
            testCase.verifyWarning(@() st.findPeaks(), 'Tag:findPeaksOnDiscrete');
        end

        % ---- correlate(other) tests (Issue #340) ----

        function testCorrelateIdentical(testCase)
            a = SensorTag('cr_a', 'X', 1:10, 'Y', 1:10);
            b = SensorTag('cr_b', 'X', 1:10, 'Y', 1:10);
            testCase.verifyEqual(a.correlate(b), 1, 'AbsTol', 1e-10);
        end

        function testCorrelateAntiCorrelated(testCase)
            a = SensorTag('cr_a2', 'X', 1:10, 'Y', 1:10);
            b = SensorTag('cr_bn', 'X', 1:10, 'Y', -(1:10));
            testCase.verifyEqual(a.correlate(b), -1, 'AbsTol', 1e-10);
        end

        function testCorrelateZero(testCase)
            % A centered = [-1.5 -0.5 0.5 1.5], B = [1 -1 -1 1] -> dot product 0.
            a = SensorTag('cr_z1', 'X', 1:4, 'Y', [1 2 3 4]);
            b = SensorTag('cr_z2', 'X', 1:4, 'Y', [1 -1 -1 1]);
            testCase.verifyEqual(a.correlate(b), 0, 'AbsTol', 1e-10);
        end

        function testCorrelateSampleCountOut(testCase)
            a = SensorTag('cr_n1', 'X', 1:10, 'Y', 1:10);
            b = SensorTag('cr_n2', 'X', 1:10, 'Y', 1:10);
            [r, n] = a.correlate(b);
            testCase.verifyEqual(r, 1, 'AbsTol', 1e-10);
            testCase.verifyEqual(n, 10, 'aligned sample count');
        end

        function testCorrelateZeroVarianceReturnsNaN(testCase)
            a = SensorTag('cr_v1', 'X', 1:5, 'Y', 1:5);
            c = SensorTag('cr_const', 'X', 1:5, 'Y', [2 2 2 2 2]);
            testCase.verifyTrue(isnan(a.correlate(c)), 'constant channel -> NaN');
        end

        function testCorrelateTooFewReturnsNaN(testCase)
            p = SensorTag('cr_o1', 'X', 1, 'Y', 5);
            q = SensorTag('cr_o2', 'X', 1, 'Y', 3);
            testCase.verifyTrue(isnan(p.correlate(q)), 'n<2 -> NaN');
        end

        function testCorrelateZOHAlignment(testCase)
            % B on a coarser grid; ZOH-sampled onto A's timestamps still tracks.
            a = SensorTag('cr_ma', 'X', 1:10, 'Y', 1:10);
            b = SensorTag('cr_mb', 'X', [1 5 10], 'Y', [1 5 10]);
            % ZOH staircase vs a ramp tracks strongly (~0.885), not exactly 1.
            testCase.verifyGreaterThan(a.correlate(b), 0.85);
        end

        function testCorrelateRangeWindow(testCase)
            a = SensorTag('cr_r1', 'X', 1:10, 'Y', 1:10);
            b = SensorTag('cr_r2', 'X', 1:10, 'Y', 1:10);
            testCase.verifyEqual(a.correlate(b, 3, 7), 1, 'AbsTol', 1e-10);
        end

        function testCorrelateBadOtherErrors(testCase)
            a = SensorTag('cr_e', 'X', 1:10, 'Y', 1:10);
            testCase.verifyError(@() a.correlate(42), 'Tag:correlateBadOther');
        end

        % ---- lagCorrelation(other, MaxLag) tests (Issue #341) ----

        function testLagCorrelationRecoversDelay(testCase)
            % Gaussian bump at t=8 (A) vs t=12 (B) => B lags A by +4.
            t = 1:20;
            a = SensorTag('lc_a', 'X', t, 'Y', exp(-((t - 8) .^ 2) / 4));
            b = SensorTag('lc_b', 'X', t, 'Y', exp(-((t - 12) .^ 2) / 4));
            [dt, r] = a.lagCorrelation(b);
            testCase.verifyEqual(dt, 4, 'AbsTol', 1e-9, 'recovers the +4 delay');
            testCase.verifyGreaterThan(r, 0.99, 'near-perfect match at best lag');
        end

        function testLagCorrelationIdenticalZeroLag(testCase)
            t = 1:20;
            y = exp(-((t - 10) .^ 2) / 4);
            a = SensorTag('lc_i1', 'X', t, 'Y', y);
            b = SensorTag('lc_i2', 'X', t, 'Y', y);
            [dt, r] = a.lagCorrelation(b);
            testCase.verifyEqual(dt, 0, 'AbsTol', 1e-9);
            testCase.verifyEqual(r, 1, 'AbsTol', 1e-9);
        end

        function testLagCorrelationMaxLagClamps(testCase)
            t = 1:20;
            a = SensorTag('lc_c1', 'X', t, 'Y', exp(-((t - 8) .^ 2) / 4));
            b = SensorTag('lc_c2', 'X', t, 'Y', exp(-((t - 12) .^ 2) / 4));
            dt = a.lagCorrelation(b, 'MaxLag', 2);
            testCase.verifyLessThanOrEqual(abs(dt), 2, 'search clamped to +/-MaxLag');
        end

        function testLagCorrelationFullCurve(testCase)
            t = 1:20;
            a = SensorTag('lc_f1', 'X', t, 'Y', exp(-((t - 8) .^ 2) / 4));
            b = SensorTag('lc_f2', 'X', t, 'Y', exp(-((t - 12) .^ 2) / 4));
            [~, ~, lags, rr] = a.lagCorrelation(b);
            testCase.verifyEqual(numel(lags), numel(rr), 'lag axis matches curve');
            testCase.verifyEqual(lags(1), -lags(end), 'AbsTol', 1e-12, 'symmetric lag axis');
        end

        function testLagCorrelationTooFewReturnsNaN(testCase)
            p = SensorTag('lc_o1', 'X', 1, 'Y', 5);
            q = SensorTag('lc_o2', 'X', 1, 'Y', 3);
            testCase.verifyTrue(isnan(p.lagCorrelation(q)), 'n<2 -> NaN');
        end

        function testLagCorrelationZeroVarianceReturnsNaN(testCase)
            t = 1:20;
            a = SensorTag('lc_v1', 'X', t, 'Y', exp(-((t - 8) .^ 2) / 4));
            c = SensorTag('lc_v2', 'X', t, 'Y', 3 * ones(1, 20));
            testCase.verifyTrue(isnan(a.lagCorrelation(c)), 'constant channel -> NaN');
        end

        function testLagCorrelationBadOtherErrors(testCase)
            a = SensorTag('lc_e', 'X', 1:10, 'Y', 1:10);
            testCase.verifyError(@() a.lagCorrelation(42), 'Tag:correlateBadOther');
        end

        % ---- removeOutliers tests (Issue #343) ----

        function testRemoveOutliersHampelDetectsSpike(testCase)
            t = SensorTag('ro_h', 'X', 1:9, 'Y', [1 1 1 1 100 1 1 1 1]);
            [cleanY, idx] = t.removeOutliers();   % hampel, Fill nan
            testCase.verifyEqual(idx, 5, 'spike at index 5 flagged');
            testCase.verifyTrue(isnan(cleanY(5)), 'offender NaN-filled');
            testCase.verifyEqual(cleanY([1 9]), [1 1], 'non-outliers untouched');
        end

        function testRemoveOutliersNonMutating(testCase)
            t = SensorTag('ro_nm', 'X', 1:5, 'Y', [1 1 50 1 1]);
            t.removeOutliers();
            [~, Y] = t.getXY();
            testCase.verifyEqual(Y, [1 1 50 1 1], 'tag Y is unchanged');
        end

        function testRemoveOutliersFillLinear(testCase)
            t = SensorTag('ro_lin', 'X', 1:5, 'Y', [1 2 100 4 5]);
            cleanY = t.removeOutliers('Fill', 'linear');
            testCase.verifyEqual(cleanY(3), 3, 'AbsTol', 1e-12, 'linear interp across spike');
        end

        function testRemoveOutliersFillPrevious(testCase)
            t = SensorTag('ro_prev', 'X', 1:5, 'Y', [1 2 100 4 5]);
            cleanY = t.removeOutliers('Fill', 'previous');
            testCase.verifyEqual(cleanY(3), 2, 'carries previous good value');
        end

        function testRemoveOutliersFillRemoveShrinks(testCase)
            t = SensorTag('ro_rm', 'X', 1:5, 'Y', [1 2 100 4 5]);
            [cleanX, cleanY, idx] = t.removeOutliers('Fill', 'remove');
            testCase.verifyEqual(numel(cleanY), 4, 'offender dropped');
            testCase.verifyEqual(numel(cleanX), 4, 'cleanX shrinks to match');
            testCase.verifyEqual(idx, 3);
            testCase.verifyFalse(any(cleanY == 100));
        end

        function testRemoveOutliersIqrMethod(testCase)
            t = SensorTag('ro_iqr', 'X', 1:7, 'Y', [10 11 9 10 12 11 500]);
            [~, idx] = t.removeOutliers('Method', 'iqr');
            testCase.verifyEqual(idx, 7, 'gross outlier flagged by IQR fence');
        end

        function testRemoveOutliersZscoreMethod(testCase)
            t = SensorTag('ro_z', 'X', 1:9, 'Y', [1 2 1 3 2 50 2 1 3]);
            [~, idx] = t.removeOutliers('Method', 'zscore');
            testCase.verifyEqual(idx, 6, 'modified z-score flags the 50');
        end

        function testRemoveOutliersNonNumericErrors(testCase)
            st = StateTag('ro_state', 'X', [1 2 3], 'Y', {'a', 'b', 'c'});
            testCase.verifyError(@() st.removeOutliers(), 'Tag:notNumeric');
        end

        function testRemoveOutliersBadOptionsError(testCase)
            t = SensorTag('ro_bad', 'X', 1:5, 'Y', [1 2 3 4 5]);
            testCase.verifyError(@() t.removeOutliers('Method', 'nope'), ...
                'Tag:removeOutliersBadMethod');
            testCase.verifyError(@() t.removeOutliers('Fill', 'nope'), ...
                'Tag:removeOutliersBadFill');
            testCase.verifyError(@() t.removeOutliers('Window', 2.5), ...
                'Tag:removeOutliersBadWindow');
        end

        % ---- spectrum / dominantFrequency tests (Issue #338) ----

        function testSpectrumDominantBin(testCase)
            % 10 Hz sine sampled at 100 Hz -> peak at 10 Hz.
            x = (0:99) / 100;
            t = SensorTag('sp_sine', 'X', x, 'Y', sin(2 * pi * 10 * x));
            testCase.verifyEqual(t.dominantFrequency(), 10, 'AbsTol', 1e-9);
        end

        function testSpectrumAmplitudeAndLength(testCase)
            x = (0:99) / 100;
            t = SensorTag('sp_amp', 'X', x, 'Y', 3 * sin(2 * pi * 10 * x));
            [f, amp] = t.spectrum();
            testCase.verifyEqual(numel(f), 51, 'floor(N/2)+1 bins');
            testCase.verifyEqual(numel(amp), 51);
            [pk, bi] = max(amp);
            testCase.verifyEqual(f(bi), 10, 'AbsTol', 1e-9);
            testCase.verifyEqual(pk, 3, 'AbsTol', 1e-6, 'single-sided amplitude ~ A');
        end

        function testSpectrumSampleRateOverride(testCase)
            x = (0:99) / 100;
            t = SensorTag('sp_fs', 'X', x, 'Y', sin(2 * pi * 10 * x));
            % Claiming Fs=200 doubles the frequency axis: same bin -> 20 Hz.
            testCase.verifyEqual(t.dominantFrequency('SampleRate', 200), 20, 'AbsTol', 1e-9);
        end

        function testSpectrumDetrendRemovesDC(testCase)
            x = (0:99) / 100;
            t = SensorTag('sp_dc', 'X', x, 'Y', 5 + sin(2 * pi * 10 * x));
            [~, ampRaw] = t.spectrum();
            [~, ampDet] = t.spectrum('Detrend', 'mean');
            testCase.verifyGreaterThan(ampRaw(1), 4, 'DC bin large without detrend');
            testCase.verifyLessThan(ampDet(1), 1e-6, 'mean-detrend zeroes the DC bin');
        end

        function testSpectrumTooFewPointsErrors(testCase)
            t = SensorTag('sp_one', 'X', 1, 'Y', 5);
            testCase.verifyError(@() t.spectrum(), 'Tag:spectrumTooFewPoints');
        end

        function testSpectrumNonNumericErrors(testCase)
            st = StateTag('sp_state', 'X', [1 2 3], 'Y', {'a', 'b', 'c'});
            testCase.verifyError(@() st.spectrum(), 'Tag:notNumeric');
        end

        function testSpectrumBadOptionsError(testCase)
            x = (0:9) / 10;
            t = SensorTag('sp_bad', 'X', x, 'Y', sin(x));
            testCase.verifyError(@() t.spectrum('SampleRate', -1), 'Tag:spectrumBadRate');
            testCase.verifyError(@() t.spectrum('Detrend', 'nope'), 'Tag:spectrumBadDetrend');
            testCase.verifyError(@() t.spectrum('Bogus', 1), 'Tag:unknownOption');
        end

        % ---- compareWindows tests (Issue #358) ----

        function testCompareWindowsStart(testCase)
            t = SensorTag('cw', 'X', 1:20, 'Y', 1:20);
            s = t.compareWindows({[1 5], [11 15]});
            testCase.verifyEqual(numel(s), 2);
            testCase.verifyEqual(s(1).Window, [1 5]);
            testCase.verifyEqual(s(2).Window, [11 15]);
            [x1, ~] = t.getXYRange(1, 5);
            testCase.verifyEqual(s(1).RelT, x1(:).' - 1, 'AbsTol', 1e-12, ...
                'start anchor re-zeroes at t0');
            [x2, ~] = t.getXYRange(11, 15);
            testCase.verifyEqual(s(2).RelT, x2(:).' - 11, 'AbsTol', 1e-12);
        end

        function testCompareWindowsEndAnchor(testCase)
            t = SensorTag('cw2', 'X', 1:20, 'Y', 1:20);
            s = t.compareWindows({[1 5]}, 'Anchor', 'end');
            [x1, ~] = t.getXYRange(1, 5);
            testCase.verifyEqual(s(1).RelT, x1(:).' - 5, 'AbsTol', 1e-12, ...
                'end anchor aligns on t1');
        end

        function testCompareWindowsScalarAnchor(testCase)
            t = SensorTag('cw3', 'X', 1:20, 'Y', 1:20);
            s = t.compareWindows({[1 5]}, 'Anchor', 0);
            [x1, ~] = t.getXYRange(1, 5);
            testCase.verifyEqual(s(1).RelT, x1(:).', 'AbsTol', 1e-12, ...
                'scalar 0 anchor leaves absolute time');
        end

        function testCompareWindowsCarriesY(testCase)
            t = SensorTag('cw4', 'X', 1:20, 'Y', (1:20) * 10);
            s = t.compareWindows({[5 8]});
            [~, y1] = t.getXYRange(5, 8);
            testCase.verifyEqual(s(1).Y(:).', y1(:).', 'Y passes through unchanged');
        end

        function testCompareWindowsBadArgsError(testCase)
            t = SensorTag('cw5', 'X', 1:20, 'Y', 1:20);
            testCase.verifyError(@() t.compareWindows([]), 'Tag:compareWindowsBadWindows');
            testCase.verifyError(@() t.compareWindows({[1 2 3]}), 'Tag:compareWindowsBadWindows');
            testCase.verifyError(@() t.compareWindows({[1 5]}, 'Anchor', 'middle'), ...
                'Tag:compareWindowsBadAnchor');
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
