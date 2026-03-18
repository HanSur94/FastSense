classdef TestSensorTodisk < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testBasicToDiskAndIsOnDisk(testCase)
            s = Sensor('pressure', 'Name', 'Chamber Pressure');
            s.X = linspace(0, 100, 100000);
            s.Y = 40 + 20*sin(2*pi*s.X/30) + 5*randn(1, 100000);

            testCase.verifyTrue(~s.isOnDisk(), 'should start in memory');
            testCase.verifyEqual(numel(s.X), 100000, 'X should have data');

            s.toDisk();
            testCase.addTeardown(@() s.DataStore.cleanup());
            testCase.verifyTrue(s.isOnDisk(), 'should be on disk after toDisk');
            testCase.verifyEmpty(s.X, 'X should be empty after toDisk');
            testCase.verifyEmpty(s.Y, 'Y should be empty after toDisk');
            testCase.verifyEqual(s.DataStore.NumPoints, 100000, 'DataStore should have 100K pts');
        end

        function testToMemoryRoundTrip(testCase)
            s = Sensor('pressure', 'Name', 'Chamber Pressure');
            s.X = linspace(0, 100, 100000);
            s.Y = 40 + 20*sin(2*pi*s.X/30) + 5*randn(1, 100000);
            s.toDisk();

            s.toMemory();
            testCase.verifyTrue(~s.isOnDisk(), 'should be in memory after toMemory');
            testCase.verifyEqual(numel(s.X), 100000, 'X should be restored');
            testCase.verifyEqual(numel(s.Y), 100000, 'Y should be restored');
            testCase.verifyEmpty(s.DataStore, 'DataStore should be cleared');
        end

        function testResolveWithDiskData(testCase)
            s2 = Sensor('temp', 'Name', 'Temperature');
            s2.X = linspace(0, 100, 50000);
            s2.Y = 40 + 20*sin(2*pi*s2.X/30) + 5*randn(1, 50000);

            sc = StateChannel('machine');
            sc.X = [0, 25, 50, 75];
            sc.Y = [0, 1, 2, 1];
            s2.addStateChannel(sc);
            s2.addThresholdRule(struct('machine', 1), 55, ...
                'Direction', 'upper', 'Label', 'HH (running)');

            s2.resolve();
            nThMem = numel(s2.ResolvedThresholds);

            % Re-create with same structure, move to disk, resolve
            s2.X = linspace(0, 100, 50000);
            s2.Y = 40 + 20*sin(2*pi*s2.X/30) + 5*randn(1, 50000);
            s2.toDisk();
            testCase.addTeardown(@() s2.DataStore.cleanup());
            s2.resolve();
            nThDisk = numel(s2.ResolvedThresholds);
            nViolDisk = numel(s2.ResolvedViolations);

            testCase.verifyEqual(nThDisk, nThMem, 'threshold count should match');
            testCase.verifyTrue(nViolDisk > 0, 'should have violations');
        end

        function testAddSensorWithDiskBacked(testCase)
            s2 = Sensor('temp', 'Name', 'Temperature');
            s2.X = linspace(0, 100, 50000);
            s2.Y = 40 + 20*sin(2*pi*s2.X/30) + 5*randn(1, 50000);

            sc = StateChannel('machine');
            sc.X = [0, 25, 50, 75];
            sc.Y = [0, 1, 2, 1];
            s2.addStateChannel(sc);
            s2.addThresholdRule(struct('machine', 1), 55, ...
                'Direction', 'upper', 'Label', 'HH (running)');

            s2.toDisk();
            testCase.addTeardown(@() s2.DataStore.cleanup());
            s2.resolve();

            fp = FastSense();
            fp.addSensor(s2, 'ShowThresholds', true);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(numel(fp.Lines) >= 1, 'should have at least 1 line');
            testCase.verifyNotEmpty(fp.Lines(1).DataStore, 'line should have DataStore');
        end

        function testAddSensorNoThresholds(testCase)
            s3 = Sensor('flow', 'Name', 'Gas Flow');
            s3.X = linspace(0, 100, 10000);
            s3.Y = rand(1, 10000);
            s3.toDisk();
            testCase.addTeardown(@() s3.DataStore.cleanup());
            fp2 = FastSense();
            fp2.addSensor(s3);
            fp2.render();
            testCase.addTeardown(@close, fp2.hFigure);
            testCase.verifyEqual(numel(fp2.Lines), 1, 'should have 1 line');
        end

        function testDoubleToDiskIdempotent(testCase)
            s4 = Sensor('test');
            s4.X = 1:100;
            s4.Y = rand(1, 100);
            s4.toDisk();
            ds1 = s4.DataStore;
            s4.toDisk();
            testCase.verifyTrue(s4.DataStore == ds1, 'DataStore should not change');
            testCase.addTeardown(@() s4.DataStore.cleanup());
        end

        function testToDiskEmptyError(testCase)
            s5 = Sensor('empty');
            threw = false;
            try
                s5.toDisk();
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'should throw on empty data');
        end

        function testDataStoreMetadata(testCase)
            s6 = Sensor('meta', 'Name', 'With Metadata');
            s6.X = linspace(0, 50, 20000);
            s6.Y = sin(s6.X) + randn(1, 20000) * 0.1;
            s6.toDisk();
            testCase.addTeardown(@() s6.DataStore.cleanup());
            testCase.verifyTrue(abs(s6.DataStore.XMin - s6.DataStore.PyramidX(1)) < 1, ...
                'PyramidX should start near XMin');
            testCase.verifyEqual(s6.DataStore.NumPoints, 20000, 'NumPoints should match');
        end
    end
end
