classdef TestStateTag < matlab.unittest.TestCase
    %TESTSTATETAG Unit tests for the StateTag concrete Tag subclass.
    %   Covers Phase 1005-02 (TAG-09):
    %     - Constructor required-Key validation (Tag:invalidKey)
    %     - Name-value constructor parsing (Tag universals + X/Y)
    %     - Unknown option rejection (StateTag:unknownOption)
    %     - isa(Tag) subtype relationship
    %     - getKind() returns 'state'
    %     - valueAt ZOH semantics (numeric Y) — scalar + vector paths, matches
    %       StateChannel.valueAt byte-for-byte (7-point golden fixture)
    %     - valueAt ZOH semantics (cellstr Y) — scalar + vector paths
    %     - valueAt on empty state raises StateTag:emptyState
    %     - getXY pass-through
    %     - getTimeRange non-empty + empty ([NaN NaN])
    %     - toStruct emits kind='state'
    %     - fromStruct round-trip (numeric AND cellstr Y) preserves X, Y, and
    %       all Tag universals
    %
    %   See also StateTag, StateChannel, TestTag, TestSensorTag.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath'))));  % tests/suite for MockTag siblings
            install();
        end
    end

    methods (TestMethodSetup)
        function clearRegistryBefore(testCase) %#ok<MANU>
            try
                TagRegistry.clear();
            catch
                % TagRegistry may not be on path in isolated runs; ignore.
            end
        end
    end

    methods (TestMethodTeardown)
        function clearRegistryAfter(testCase) %#ok<MANU>
            try
                TagRegistry.clear();
            catch
                % ignore
            end
        end
    end

    methods (Test)

        % ---- Constructor / type ----

        function testConstructorRequiresKey(testCase)
            testCase.verifyError(@() StateTag(''), 'Tag:invalidKey');
        end

        function testConstructorDefaults(testCase)
            t = StateTag('mode');
            testCase.verifyEqual(t.Key, 'mode');
            testCase.verifyEqual(t.Name, 'mode');  % defaults to Key
            testCase.verifyEmpty(t.X);
            testCase.verifyEmpty(t.Y);
            testCase.verifyTrue(iscell(t.Labels));
            testCase.verifyEmpty(t.Labels);
            testCase.verifyEqual(t.Criticality, 'medium');
        end

        function testConstructorNameValuePairs(testCase)
            t = StateTag('s', ...
                'X', [1 5 10], 'Y', [0 1 2], ...
                'Name', 'Machine State', 'Units', '', ...
                'Description', 'line-A machine mode', ...
                'Labels', {'state', 'machine'}, ...
                'Metadata', struct('line', 'A'), ...
                'Criticality', 'high', ...
                'SourceRef', 'states.mat');
            testCase.verifyEqual(t.X, [1 5 10]);
            testCase.verifyEqual(t.Y, [0 1 2]);
            testCase.verifyEqual(t.Name, 'Machine State');
            testCase.verifyEqual(t.Description, 'line-A machine mode');
            testCase.verifyEqual(numel(t.Labels), 2);
            testCase.verifyEqual(t.Labels{1}, 'state');
            testCase.verifyEqual(t.Metadata.line, 'A');
            testCase.verifyEqual(t.Criticality, 'high');
            testCase.verifyEqual(t.SourceRef, 'states.mat');
        end

        function testConstructorUnknownOption(testCase)
            testCase.verifyError(@() StateTag('m', 'NoSuch', 1), 'StateTag:unknownOption');
        end

        function testIsATag(testCase)
            t = StateTag('k');
            testCase.verifyTrue(isa(t, 'Tag'));
        end

        function testGetKindIsState(testCase)
            t = StateTag('k');
            testCase.verifyEqual(t.getKind(), 'state');
        end

        % ---- ZOH numeric — 7 golden scalar points + vector form ----

        function testValueAtNumericScalar(testCase)
            t = StateTag('s', 'X', [1 5 10 20], 'Y', [0 1 2 3]);
            testCase.verifyEqual(t.valueAt(0),   0);
            testCase.verifyEqual(t.valueAt(1),   0);
            testCase.verifyEqual(t.valueAt(3),   0);
            testCase.verifyEqual(t.valueAt(5),   1);
            testCase.verifyEqual(t.valueAt(7),   1);
            testCase.verifyEqual(t.valueAt(15),  2);
            testCase.verifyEqual(t.valueAt(100), 3);
        end

        function testValueAtNumericVector(testCase)
            t = StateTag('s', 'X', [1 5 10 20], 'Y', [0 1 2 3]);
            testCase.verifyEqual(t.valueAt([0 3 5 7 15]), [0 0 1 1 2]);
        end

        % ---- ZOH cellstr ----

        function testValueAtCellstrScalar(testCase)
            t = StateTag('m', 'X', [1 5 10], 'Y', {'off', 'running', 'evacuated'});
            testCase.verifyEqual(t.valueAt(3),  'off');
            testCase.verifyEqual(t.valueAt(7),  'running');
            testCase.verifyEqual(t.valueAt(15), 'evacuated');
        end

        function testValueAtCellstrVector(testCase)
            t = StateTag('m', 'X', [1 5 10], 'Y', {'off', 'running', 'evacuated'});
            v = t.valueAt([0 6 12]);
            testCase.verifyTrue(iscell(v));
            testCase.verifyEqual(v, {'off', 'running', 'evacuated'});
        end

        % ---- Empty-state guard ----

        function testValueAtEmptyStateErrors(testCase)
            t = StateTag('e');
            testCase.verifyError(@() t.valueAt(0), 'StateTag:emptyState');
        end

        % ---- Tag contract: getXY, getTimeRange ----

        function testGetXYPassthrough(testCase)
            t = StateTag('s', 'X', [1 5 10], 'Y', [0 1 2]);
            [x, y] = t.getXY();
            testCase.verifyEqual(x, [1 5 10]);
            testCase.verifyEqual(y, [0 1 2]);

            tc = StateTag('m', 'X', [1 5 10], 'Y', {'a', 'b', 'c'});
            [xc, yc] = tc.getXY();
            testCase.verifyEqual(xc, [1 5 10]);
            testCase.verifyEqual(yc, {'a', 'b', 'c'});
        end

        function testGetTimeRangeNonEmpty(testCase)
            t = StateTag('s', 'X', [1 5 10], 'Y', [0 1 2]);
            [tMin, tMax] = t.getTimeRange();
            testCase.verifyEqual(tMin, 1);
            testCase.verifyEqual(tMax, 10);
        end

        function testGetTimeRangeEmpty(testCase)
            t = StateTag('e');
            [tMin, tMax] = t.getTimeRange();
            testCase.verifyTrue(isnan(tMin));
            testCase.verifyTrue(isnan(tMax));
        end

        % ---- Serialization ----

        function testToStructKind(testCase)
            t = StateTag('s', 'X', [1 5 10], 'Y', [0 1 2]);
            s = t.toStruct();
            testCase.verifyEqual(s.kind, 'state');
        end

        function testFromStructRoundTripNumeric(testCase)
            t = StateTag('mm', 'X', [1 5 10], 'Y', [0 1 2], ...
                'Name', 'Mode', 'Labels', {'state', 'machine'}, ...
                'Criticality', 'high');
            s = t.toStruct();
            t2 = StateTag.fromStruct(s);
            testCase.verifyEqual(t2.Key, 'mm');
            testCase.verifyEqual(t2.Name, 'Mode');
            testCase.verifyTrue(isequal(t2.X, [1 5 10]));
            testCase.verifyTrue(isequal(t2.Y, [0 1 2]));
            testCase.verifyEqual(numel(t2.Labels), 2);
            testCase.verifyEqual(t2.Labels{1}, 'state');
            testCase.verifyEqual(t2.Criticality, 'high');
        end

        function testFromStructRoundTripCellstr(testCase)
            t = StateTag('cc', 'X', [1 5 10], 'Y', {'off', 'running', 'idle'});
            s = t.toStruct();
            t2 = StateTag.fromStruct(s);
            testCase.verifyTrue(iscell(t2.Y));
            testCase.verifyEqual(numel(t2.Y), 3);
            testCase.verifyEqual(t2.Y{1}, 'off');
            testCase.verifyEqual(t2.Y{2}, 'running');
            testCase.verifyEqual(t2.Y{3}, 'idle');
        end

        % ---- Phase 1012-02: RawSource property (D-05 + D-06 + D-11) ----

        function testRawSourceProperty(testCase)
            %TESTRAWSOURCEPROPERTY Phase 1012-02: RawSource NV-pair wiring.
            %   Covers the 8 behaviors in Plan 1012-02 Task 2:
            %     1. Accepts RawSource struct with file/column/format
            %     2. Getter returns stored struct
            %     3. Missing file raises TagPipeline:invalidRawSource
            %     4. toStruct emits s.rawsource when set; absent when not
            %     5. fromStruct round-trips RawSource
            %     6. Existing constructor regression (no RawSource still works)
            %     7. Cellstr Y + RawSource combination (D-11)
            %     8. Unknown option still throws StateTag:unknownOption

            % 1+2. Construct + getter
            rs = struct('file', 'm.csv', 'column', 'state', 'format', '');
            t = StateTag('k', 'RawSource', rs);
            r = t.RawSource;
            testCase.verifyTrue(isstruct(r));
            testCase.verifyEqual(r.file,   'm.csv');
            testCase.verifyEqual(r.column, 'state');
            testCase.verifyEqual(r.format, '');

            % 3. Missing file -> TagPipeline:invalidRawSource (from StateTag's
            %    OWN inline validateRawSource_, NOT a cross-class call)
            testCase.verifyError( ...
                @() StateTag('k2', 'RawSource', struct('column', 'x')), ...
                'TagPipeline:invalidRawSource');

            % 4. toStruct emits s.rawsource when set; absent otherwise
            s1 = t.toStruct();
            testCase.verifyTrue(isfield(s1, 'rawsource'));
            testCase.verifyEqual(s1.rawsource.file, 'm.csv');

            tPlain = StateTag('plain');
            sPlain = tPlain.toStruct();
            testCase.verifyFalse(isfield(sPlain, 'rawsource'));

            % 5. Round-trip through fromStruct preserves RawSource
            t1b = StateTag.fromStruct(s1);
            r1b = t1b.RawSource;
            testCase.verifyEqual(r1b.file,   'm.csv');
            testCase.verifyEqual(r1b.column, 'state');

            % 6. Existing constructor path (no RawSource) still works
            tExisting = StateTag('k3', 'X', [1 2 3], 'Y', [0 1 0]);
            testCase.verifyEqual(tExisting.X, [1 2 3]);
            testCase.verifyEqual(tExisting.Y, [0 1 0]);

            % 7. D-11: Cellstr Y combined with RawSource must still work
            tCellstr = StateTag('k4', 'X', [1 2], 'Y', {'a', 'b'}, ...
                'RawSource', struct('file', 'm.csv'));
            testCase.verifyTrue(iscell(tCellstr.Y));
            testCase.verifyEqual(tCellstr.Y{1}, 'a');
            testCase.verifyEqual(tCellstr.RawSource.file, 'm.csv');

            % 8. Unknown option still throws StateTag:unknownOption
            testCase.verifyError( ...
                @() StateTag('k5', 'NoSuch', 1), ...
                'StateTag:unknownOption');
        end

        % ---- transitions() tests (Issue #342) ----

        function testTransitionsNumeric(testCase)
            % States 0,0,1,1,2,0 -> changes at samples 3(0->1),5(1->2),6(2->0).
            t = StateTag('tr_num', 'X', [1 2 3 4 5 6], 'Y', [0 0 1 1 2 0]);
            S = t.transitions();
            testCase.verifyEqual(numel(S), 3);
            testCase.verifyEqual([S.Time], [3 5 6]);
            testCase.verifyEqual([S.FromState], [0 1 2]);
            testCase.verifyEqual([S.ToState], [1 2 0]);
        end

        function testTransitionsCellstr(testCase)
            t = StateTag('tr_str', 'X', [1 5 10], 'Y', {'off', 'running', 'idle'});
            S = t.transitions();
            testCase.verifyEqual(numel(S), 2);
            testCase.verifyEqual(S(1).FromState, 'off');
            testCase.verifyEqual(S(1).ToState, 'running');
            testCase.verifyEqual(S(2).Time, 10);
            testCase.verifyEqual(S(2).ToState, 'idle');
        end

        function testTransitionsConstantIsEmpty(testCase)
            t = StateTag('tr_const', 'X', [1 2 3], 'Y', [7 7 7]);
            S = t.transitions();
            testCase.verifyEqual(numel(S), 0);
            testCase.verifyTrue(isfield(S, 'Time') && isfield(S, 'FromState') && isfield(S, 'ToState'));
        end

        function testTransitionsEmptyChannel(testCase)
            t = StateTag('tr_empty');
            S = t.transitions();
            testCase.verifyEqual(numel(S), 0);
        end

        % ---- StateNames / nameAt tests (Issue #372) ----

        function testNameAtScalar(testCase)
            st = StateTag('mode', 'X', [1 5 10 20], 'Y', [0 1 2 3], ...
                'StateNames', {0 'Idle'; 1 'Run'; 2 'Fault'; 3 'Maint'});
            testCase.verifyEqual(st.valueAt(7), 1, 'valueAt unchanged (still numeric)');
            testCase.verifyEqual(st.nameAt(7), 'Run');
        end

        function testNameAtVector(testCase)
            st = StateTag('mode', 'X', [1 5 10 20], 'Y', [0 1 2 3], ...
                'StateNames', {0 'Idle'; 1 'Run'; 2 'Fault'; 3 'Maint'});
            testCase.verifyEqual(st.nameAt([0 7 15]), {'Idle', 'Run', 'Fault'});
        end

        function testNameAtUnmappedFallsBackToNumericString(testCase)
            st = StateTag('mode', 'X', [1 5], 'Y', [0 9], ...
                'StateNames', {0 'Idle'});
            testCase.verifyEqual(st.nameAt(6), '9', 'unmapped code -> numeric string');
        end

        function testNameAtNoLegendFallsBack(testCase)
            st = StateTag('mode', 'X', [1 5], 'Y', [0 2]);
            testCase.verifyEqual(st.nameAt(6), '2', 'no legend -> numeric string');
        end

        function testStateNamesRoundTrips(testCase)
            st = StateTag('mode', 'X', [1 5], 'Y', [0 1], ...
                'StateNames', {0 'Idle'; 1 'Run'});
            s = st.toStruct();
            st2 = StateTag.fromStruct(s);
            testCase.verifyEqual(st2.nameAt(6), 'Run', 'legend restored via round-trip');
            testCase.verifyEqual(size(st2.StateNames), [2 2]);
        end

        function testStateNamesOmittedWhenEmpty(testCase)
            st = StateTag('mode', 'X', [1 5], 'Y', [0 1]);
            s = st.toStruct();
            testCase.verifyFalse(isfield(s, 'statenames'), 'omit-when-empty');
        end

    end
end
