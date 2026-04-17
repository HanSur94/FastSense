classdef TestSensorTag < matlab.unittest.TestCase
    %TESTSENSORTAG Unit tests for the SensorTag composition wrapper (TAG-08).
    %   Covers (Phase 1005-01):
    %     - Constructor key validation, defaults, Tag+Sensor name-value
    %       pair routing, inline X/Y payload, unknown-option rejection
    %     - isa(Tag) parity (composition via inheritance-from-Tag)
    %     - Tag contract: getKind ('sensor'), getXY zero-copy forwarding,
    %       getTimeRange (including empty -> [NaN NaN]), valueAt ZOH-style
    %       lookup
    %     - Data-role delegation: load(matFile), toDisk/toMemory/isOnDisk
    %       round-trip, DataStore dependent property mirror
    %     - Serialization: toStruct.kind == 'sensor', fromStruct round-trip
    %       of Tag universals + Sensor extras
    %
    %   Each test clears TagRegistry before and after to avoid pollution.
    %   A small MAT-file fixture helper (writeTempMat_) creates an x/y
    %   struct file on disk and auto-registers teardown deletion.
    %
    %   See also SensorTag, Tag, Sensor, TestTag, TestTagRegistry.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function clearBefore(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function clearAfter(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)

        % ---- Constructor / type ----

        function testConstructorRequiresKey(testCase)
            % Key must be non-empty char.  Delegates to Tag:invalidKey.
            testCase.verifyError(@() SensorTag(''), 'Tag:invalidKey');
        end

        function testConstructorDefaults(testCase)
            t = SensorTag('press_a');
            testCase.verifyEqual(t.Key, 'press_a');
            testCase.verifyEqual(t.Name, 'press_a');  % Tag defaults Name to Key
            testCase.verifyEqual(t.Units, '');
            testCase.verifyTrue(iscell(t.Labels));
            testCase.verifyEmpty(t.Labels);
            testCase.verifyEqual(t.Criticality, 'medium');
            [x, y] = t.getXY();
            testCase.verifyEmpty(x);
            testCase.verifyEmpty(y);
        end

        function testConstructorTagNameValuePairs(testCase)
            t = SensorTag('press_a', 'Name', 'Pressure A', 'Units', 'bar', ...
                'Description', 'chamber pressure', ...
                'Labels', {'pressure', 'critical'}, ...
                'Metadata', struct('asset', 'p3'), ...
                'Criticality', 'safety', ...
                'SourceRef', 'daq/press_a.mat');
            testCase.verifyEqual(t.Name, 'Pressure A');
            testCase.verifyEqual(t.Units, 'bar');
            testCase.verifyEqual(t.Description, 'chamber pressure');
            testCase.verifyEqual(numel(t.Labels), 2);
            testCase.verifyEqual(t.Labels{1}, 'pressure');
            testCase.verifyEqual(t.Metadata.asset, 'p3');
            testCase.verifyEqual(t.Criticality, 'safety');
            testCase.verifyEqual(t.SourceRef, 'daq/press_a.mat');
        end

        function testConstructorSensorNameValuePairs(testCase)
            % ID, Source, MatFile, KeyName are routed to the inner Sensor delegate.
            % MatFile/KeyName verified indirectly via testLoadFromMatFile;
            % ID/Source accessible via toStruct's sensor-extras block.
            t = SensorTag('s', 'ID', 42, 'Source', 'raw/file.csv');
            s = t.toStruct();
            testCase.verifyTrue(isfield(s, 'sensor'));
            testCase.verifyEqual(s.sensor.id, 42);
            testCase.verifyEqual(s.sensor.source, 'raw/file.csv');
        end

        function testConstructorInlineXY(testCase)
            t = SensorTag('s', 'X', 1:5, 'Y', [0 1 4 9 16]);
            [x, y] = t.getXY();
            testCase.verifyEqual(numel(x), 5);
            testCase.verifyEqual(numel(y), 5);
            testCase.verifyEqual(y(3), 4);
        end

        function testConstructorUnknownOption(testCase)
            testCase.verifyError(@() SensorTag('s', 'NoSuch', 1), ...
                'SensorTag:unknownOption');
        end

        function testIsATag(testCase)
            t = SensorTag('s');
            testCase.verifyTrue(isa(t, 'Tag'));
            testCase.verifyTrue(isa(t, 'handle'));  % Tag < handle
        end

        % ---- Core Tag contract ----

        function testGetKindIsSensorKind(testCase)
            t = SensorTag('s');
            testCase.verifyEqual(t.getKind(), 'sensor');
        end

        function testGetXYEmptyByDefault(testCase)
            t = SensorTag('s');
            [x, y] = t.getXY();
            testCase.verifyEmpty(x);
            testCase.verifyEmpty(y);
        end

        function testGetTimeRange(testCase)
            t = SensorTag('s', 'X', [1 5 10], 'Y', [2 4 6]);
            [tMin, tMax] = t.getTimeRange();
            testCase.verifyEqual(tMin, 1);
            testCase.verifyEqual(tMax, 10);

            tEmpty = SensorTag('s2');
            [tMin2, tMax2] = tEmpty.getTimeRange();
            testCase.verifyTrue(isnan(tMin2));
            testCase.verifyTrue(isnan(tMax2));
        end

        function testValueAt(testCase)
            % ZOH-style lookup: binary_search(X, t, 'right') clamped to [1, N].
            t = SensorTag('s', 'X', [1 5 10], 'Y', [2 4 6]);
            testCase.verifyEqual(t.valueAt(5), 4);       % exact match
            testCase.verifyEqual(t.valueAt(3), 2);       % between 1 and 5 -> last idx <=3 is 1 -> Y(1)=2
            testCase.verifyEqual(t.valueAt(100), 6);     % past end -> clamp last -> Y(3)=6
            testCase.verifyEqual(t.valueAt(10), 6);

            tEmpty = SensorTag('e');
            testCase.verifyTrue(isnan(tEmpty.valueAt(5)));
        end

        % ---- Data-role delegation ----

        function testLoadFromMatFile(testCase)
            matFile = testCase.writeTempMat_('press_a', (1:100)', sin(1:100)');
            t = SensorTag('press_a', 'MatFile', matFile);
            t.load();
            [x, y] = t.getXY();
            testCase.verifyEqual(numel(x), 100);
            testCase.verifyEqual(numel(y), 100);
        end

        function testLoadRespectsOverrideArg(testCase)
            matFile = testCase.writeTempMat_('press_a', (1:50)', cos(1:50)');
            t = SensorTag('press_a');          % no MatFile set yet
            t.load(matFile);
            [x, ~] = t.getXY();
            testCase.verifyEqual(numel(x), 50);
        end

        function testToDiskToMemoryRoundTrip(testCase)
            N = 1000;
            xr = linspace(0, 100, N);
            yr = sin(xr);
            t = SensorTag('big', 'X', xr, 'Y', yr);

            t.toDisk();
            testCase.verifyTrue(t.isOnDisk());
            % Legacy Sensor.toDisk clears X/Y after pushing to DataStore.
            [xAfter, yAfter] = t.getXY();
            testCase.verifyEmpty(xAfter);
            testCase.verifyEmpty(yAfter);

            t.toMemory();
            testCase.verifyFalse(t.isOnDisk());
            [xBack, yBack] = t.getXY();
            testCase.verifyEqual(numel(xBack), N);
            testCase.verifyEqual(numel(yBack), N);
            testCase.verifyEqual(yBack(500), yr(500), 'AbsTol', 1e-12);
        end

        function testIsOnDiskDefault(testCase)
            t = SensorTag('s');
            testCase.verifyFalse(t.isOnDisk());
        end

        function testDataStorePropertyEmpty(testCase)
            t = SensorTag('s');
            testCase.verifyEmpty(t.DataStore);
        end

        function testDataStorePropertyAfterToDisk(testCase)
            t = SensorTag('big', 'X', 1:100, 'Y', 1:100);
            t.toDisk();
            testCase.verifyTrue(isa(t.DataStore, 'FastSenseDataStore'));
            t.toMemory();  % tidy up (no leak of DataStore cleanup between tests)
        end

        % ---- Serialization ----

        function testToStructKind(testCase)
            t = SensorTag('s', 'Name', 'Sensor S');
            s = t.toStruct();
            testCase.verifyEqual(s.kind, 'sensor');
            testCase.verifyEqual(s.key, 's');
            testCase.verifyEqual(s.name, 'Sensor S');
        end

        function testFromStructRoundTrip(testCase)
            t = SensorTag('p', 'Name', 'Pump', ...
                'Labels', {'pressure', 'critical'}, ...
                'Criticality', 'safety', 'Units', 'bar', ...
                'ID', 42, 'Source', 'file.csv');
            s = t.toStruct();
            t2 = SensorTag.fromStruct(s);
            testCase.verifyEqual(t2.Name, 'Pump');
            testCase.verifyEqual(numel(t2.Labels), 2);
            testCase.verifyEqual(t2.Labels{1}, 'pressure');
            testCase.verifyEqual(t2.Criticality, 'safety');
            testCase.verifyEqual(t2.Units, 'bar');
            % Sensor extras should round-trip through the sensor sub-struct.
            s2 = t2.toStruct();
            testCase.verifyTrue(isfield(s2, 'sensor'));
            testCase.verifyEqual(s2.sensor.id, 42);
            testCase.verifyEqual(s2.sensor.source, 'file.csv');
        end
    end

    methods (Access = private)
        function matFile = writeTempMat_(testCase, key, x, y)
            %WRITETEMPMAT_ Create a .mat file with a struct under `key` and
            %   schedule deletion via testCase.addTeardown.
            matFile = [tempname(), '.mat'];
            entry = struct('x', x, 'y', y); %#ok<NASGU>
            % Dynamically name the saved variable to `key` using eval so the
            % save(..., key) call picks it up by name.
            eval(sprintf('%s = entry;', key));
            save(matFile, key);
            testCase.addTeardown(@() deleteIfExists(matFile));
        end
    end
end

function deleteIfExists(p)
    if exist(p, 'file')
        delete(p);
    end
end
