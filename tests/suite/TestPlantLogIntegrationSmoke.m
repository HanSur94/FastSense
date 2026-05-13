classdef TestPlantLogIntegrationSmoke < matlab.unittest.TestCase
%TESTPLANTLOGINTEGRATIONSMOKE End-to-end smoke for Phase 1029.
%   Critically: this test does NOT manually addpath libs/PlantLog/ — it
%   relies on install.m's libs-block including that directory. If the
%   install.m edit is missing, this suite fails at the first 'which'
%   assertion.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testPathPickupPlantLogStore(testCase)
            p = which('PlantLogStore');
            testCase.verifyNotEmpty(p, 'PlantLogStore must be on path after install()');
            testCase.verifySubstring(p, 'PlantLog', 'PlantLogStore must live under libs/PlantLog');
        end

        function testPathPickupPlantLogEntry(testCase)
            p = which('PlantLogEntry');
            testCase.verifyNotEmpty(p, 'PlantLogEntry must be on path after install()');
            testCase.verifySubstring(p, 'PlantLog', 'PlantLogEntry must live under libs/PlantLog');
        end

        function testEndToEndLifecycle(testCase)
            s = PlantLogStore('synthetic.csv');
            testCase.verifyEqual(s.getCount(), 0);

            es = [ ...
                PlantLogEntry('Timestamp', 100, 'Message', 'pump on',  'Metadata', struct('Machine', 'M1')), ...
                PlantLogEntry('Timestamp', 200, 'Message', 'pump off', 'Metadata', struct('Machine', 'M1'))];
            ss(1) = struct('Timestamp', 150, 'Message', 'temp warn', 'Metadata', struct('Machine', 'M2'), 'SourceFile', 'synthetic.csv', 'Id', '', 'RowHash', '');
            ss(2) = struct('Timestamp', 250, 'Message', 'cooler on', 'Metadata', struct('Machine', 'M2'), 'SourceFile', 'synthetic.csv', 'Id', '', 'RowHash', '');
            s.addEntries(es);
            s.addEntries(ss);
            testCase.verifyEqual(s.getCount(), 4);

            all_entries = s.getEntries();
            testCase.verifyEqual([all_entries.Timestamp], [100 150 200 250]);

            mid = s.getEntriesInRange(150, 225);
            testCase.verifyEqual([mid.Timestamp], [150 200]);
        end

        function testDedupOnReadd(testCase)
            s = PlantLogStore('x.csv');
            arr = [ ...
                PlantLogEntry('Timestamp', 1, 'Message', 'a', 'Metadata', struct()), ...
                PlantLogEntry('Timestamp', 2, 'Message', 'b', 'Metadata', struct())];
            s.addEntries(arr);
            s.addEntries(arr);
            testCase.verifyEqual(s.getCount(), 2);
        end

        function testStaticHashAccessible(testCase)
            h = PlantLogStore.computeEntryHash('pump on', struct('Machine', 'M1'));
            testCase.verifyMatches(h, '^[0-9a-f]{16}$');
        end

        function testClearResetsIdCounter(testCase)
            s = PlantLogStore('x.csv');
            s.addEntries(PlantLogEntry('Timestamp', 1, 'Message', 'a', 'Metadata', struct()));
            s.addEntries(PlantLogEntry('Timestamp', 2, 'Message', 'b', 'Metadata', struct()));
            s.clear();
            s.addEntries(PlantLogEntry('Timestamp', 5, 'Message', 'c', 'Metadata', struct()));
            testCase.verifyEqual(s.getEntries().Id, 'plog_1');
        end

        function testIndependenceFromEventStore(testCase)
            s  = PlantLogStore('x.csv');
            es = EventStore(tempname);
            for k = 1:5
                s.addEntries(PlantLogEntry('Timestamp', k, 'Message', sprintf('plant-%d', k), 'Metadata', struct('K', k)));
            end
            testCase.verifyTrue(isempty(es.getEvents()));
            testCase.verifyEqual(s.getCount(), 5);
        end
    end
end
