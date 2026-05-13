classdef TestPlantLogStore < matlab.unittest.TestCase
%TESTPLANTLOGSTORE Class-based MATLAB-only suite for PlantLogStore.
%   Mirrors tests/test_plant_log_store.m. Both suites cover constructor,
%   addEntries (class array, struct array, empty, type mismatch, missing
%   timestamp), dedup (identical readd, same-ts different-content),
%   getEntriesInRange (basic, boundary, empty store, no match, invalid
%   args), getCount, mergeEntries (success, type mismatch), clear (count
%   reset + id reset), static computeEntryHash, and independence from
%   EventStore (PLOG-ST-01).

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            addpath(repo_root);
            install();
            addpath(fullfile(repo_root, 'libs', 'PlantLog'));
        end
    end

    methods (Test)
        function testConstructorDefault(testCase)
            s = PlantLogStore('plant.csv');
            testCase.verifyEqual(s.SourceFile, 'plant.csv');
            testCase.verifyEqual(s.getCount(), 0);
        end

        function testConstructorInvalidInput(testCase)
            testCase.verifyError(@() PlantLogStore(42), 'PlantLogStore:invalidInput');
        end

        function testConstructorUnknownOption(testCase)
            testCase.verifyError(@() PlantLogStore('x.csv', 'Bogus', 5), ...
                'PlantLogStore:unknownOption');
        end

        function testAddEntriesClassArray(testCase)
            s = PlantLogStore('x.csv');
            e1 = PlantLogEntry('Timestamp', 10, 'Message', 'a', 'Metadata', struct());
            e2 = PlantLogEntry('Timestamp', 20, 'Message', 'b', 'Metadata', struct());
            e3 = PlantLogEntry('Timestamp', 15, 'Message', 'c', 'Metadata', struct());
            s.addEntries([e1, e2, e3]);
            testCase.verifyEqual(s.getCount(), 3);
            all_entries = s.getEntries();
            testCase.verifyEqual([all_entries.Timestamp], [10 15 20]);
            testCase.verifyEqual({all_entries.Id}, {'plog_1','plog_3','plog_2'});
        end

        function testAddEntriesStructArray(testCase)
            s = PlantLogStore('x.csv');
            ss(1) = struct('Timestamp', 1, 'Message', 'a', 'Metadata', struct('K','v'), 'SourceFile', 'x.csv', 'Id', '', 'RowHash', '');
            ss(2) = struct('Timestamp', 2, 'Message', 'b', 'Metadata', struct('K','w'), 'SourceFile', 'x.csv', 'Id', '', 'RowHash', '');
            s.addEntries(ss);
            testCase.verifyEqual(s.getCount(), 2);
            all_entries = s.getEntries();
            testCase.verifyEqual(all_entries(1).Id, 'plog_1');
            testCase.verifyEqual(all_entries(2).Id, 'plog_2');
        end

        function testAddEntriesEmpty(testCase)
            s = PlantLogStore('x.csv');
            s.addEntries([]);
            testCase.verifyEqual(s.getCount(), 0);
            s.addEntries(PlantLogEntry('Timestamp', 1, 'Message', 'a', 'Metadata', struct()));
            testCase.verifyEqual(s.getEntries().Id, 'plog_1');
        end

        function testAddEntriesTypeMismatch(testCase)
            s = PlantLogStore('x.csv');
            testCase.verifyError(@() s.addEntries('bad'), 'PlantLogStore:typeMismatch');
        end

        function testAddEntriesMissingTimestamp(testCase)
            s = PlantLogStore('x.csv');
            bad = struct('Message', 'no ts');
            testCase.verifyError(@() s.addEntries(bad), 'PlantLogStore:emptyEntry');
        end

        function testDedupIdenticalReadd(testCase)
            s = PlantLogStore('x.csv');
            e1 = PlantLogEntry('Timestamp', 1, 'Message', 'a', 'Metadata', struct());
            e2 = PlantLogEntry('Timestamp', 2, 'Message', 'b', 'Metadata', struct());
            arr = [e1, e2];
            s.addEntries(arr);
            s.addEntries(arr);
            testCase.verifyEqual(s.getCount(), 2);
        end

        function testDedupSameTimestampDifferentContent(testCase)
            s = PlantLogStore('x.csv');
            e1 = PlantLogEntry('Timestamp', 5, 'Message', 'a', 'Metadata', struct());
            e2 = PlantLogEntry('Timestamp', 5, 'Message', 'b', 'Metadata', struct());
            s.addEntries([e1, e2]);
            testCase.verifyEqual(s.getCount(), 2);
        end

        function testGetEntriesInRangeBasic(testCase)
            s = PlantLogStore('x.csv');
            for k = [1 5 10 15 20]
                s.addEntries(PlantLogEntry('Timestamp', k, 'Message', sprintf('e%d', k), 'Metadata', struct()));
            end
            out = s.getEntriesInRange(5, 15);
            testCase.verifyEqual([out.Timestamp], [5 10 15]);
        end

        function testGetEntriesInRangeBoundary(testCase)
            s = PlantLogStore('x.csv');
            s.addEntries(PlantLogEntry('Timestamp', 10, 'Message', 'a', 'Metadata', struct()));
            testCase.verifyEqual(numel(s.getEntriesInRange(10, 10)), 1);
            testCase.verifyEqual(numel(s.getEntriesInRange(10, 20)), 1);
            testCase.verifyEqual(numel(s.getEntriesInRange(0, 10)), 1);
        end

        function testGetEntriesInRangeEmptyStore(testCase)
            s = PlantLogStore('x.csv');
            testCase.verifyTrue(isempty(s.getEntriesInRange(0, 100)));
        end

        function testGetEntriesInRangeNoMatch(testCase)
            s = PlantLogStore('x.csv');
            for k = 1:5
                s.addEntries(PlantLogEntry('Timestamp', k, 'Message', 'a', 'Metadata', struct('K', k)));
            end
            testCase.verifyTrue(isempty(s.getEntriesInRange(100, 200)));
        end

        function testGetEntriesInRangeInvalid(testCase)
            s = PlantLogStore('x.csv');
            testCase.verifyError(@() s.getEntriesInRange(10, 5), 'PlantLogStore:invalidInput');
            testCase.verifyError(@() s.getEntriesInRange('a', 5), 'PlantLogStore:invalidInput');
        end

        function testGetCount(testCase)
            s = PlantLogStore('x.csv');
            testCase.verifyEqual(s.getCount(), 0);
            s.addEntries(PlantLogEntry('Timestamp', 1, 'Message', 'a', 'Metadata', struct()));
            testCase.verifyEqual(s.getCount(), 1);
        end

        function testMergeEntries(testCase)
            a = PlantLogStore('a.csv');
            b = PlantLogStore('b.csv');
            e1 = PlantLogEntry('Timestamp', 1, 'Message', 'common', 'Metadata', struct());
            e2 = PlantLogEntry('Timestamp', 2, 'Message', 'a-only', 'Metadata', struct());
            e3 = PlantLogEntry('Timestamp', 3, 'Message', 'b-only-1', 'Metadata', struct());
            e4 = PlantLogEntry('Timestamp', 4, 'Message', 'b-only-2', 'Metadata', struct());
            a.addEntries([e1, e2]);
            b.addEntries([e1, e3, e4]);
            a.mergeEntries(b);
            testCase.verifyEqual(a.getCount(), 4);
        end

        function testMergeEntriesTypeMismatch(testCase)
            a = PlantLogStore('a.csv');
            testCase.verifyError(@() a.mergeEntries('bad'), 'PlantLogStore:typeMismatch');
        end

        function testClear(testCase)
            s = PlantLogStore('x.csv');
            s.addEntries(PlantLogEntry('Timestamp', 1, 'Message', 'a', 'Metadata', struct()));
            s.addEntries(PlantLogEntry('Timestamp', 2, 'Message', 'b', 'Metadata', struct()));
            s.clear();
            testCase.verifyEqual(s.getCount(), 0);
            s.addEntries(PlantLogEntry('Timestamp', 5, 'Message', 'c', 'Metadata', struct()));
            testCase.verifyEqual(s.getEntries().Id, 'plog_1');
        end

        function testComputeEntryHashStatic(testCase)
            h1 = PlantLogStore.computeEntryHash('foo', struct('A', 1));
            h2 = PlantLogStore.computeEntryHash('foo', struct('A', 1));
            h3 = PlantLogStore.computeEntryHash('foo', struct('A', 2));
            testCase.verifyEqual(h1, h2);
            testCase.verifyNotEqual(h1, h3);
            testCase.verifyMatches(h1, '^[0-9a-f]{16}$');
        end

        function testIndependenceFromEventStore(testCase)
            ps = PlantLogStore('x.csv');
            es = EventStore(tempname);
            ps.addEntries(PlantLogEntry('Timestamp', 1, 'Message', 'plant', 'Metadata', struct()));
            ps.addEntries(PlantLogEntry('Timestamp', 2, 'Message', 'plant2', 'Metadata', struct()));
            evs = es.getEvents();
            testCase.verifyTrue(isempty(evs));
            testCase.verifyEqual(ps.getCount(), 2);
        end
    end
end
