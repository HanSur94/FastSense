classdef TestTagPerfRegression < matlab.unittest.TestCase
    %TESTTAGPERFREGRESSION Asserts the 5 D-08 hard-constraint benchmark gates remain green throughout phase 1028.
    %   Each test method invokes one existing bench script via evalc (to swallow stdout).
    %   The bench's own internal assert() / error() raises on regression; this suite
    %   surfaces that as a TestCase failure.
    %
    %   D-08 gates (verbatim from phase 1028 CONTEXT.md):
    %     - bench_monitortag_tick           ≤10% regression vs SensorTag baseline
    %     - bench_compositetag_merge        <200 ms @ 8×100k, ≤1.10× output
    %     - bench_sensortag_getxy           zero-copy invariant
    %     - bench_monitortag_append         ≥5× speedup vs full recompute
    %     - bench_consumer_migration_tick   ≤10% overhead
    %
    %   None of the existing bench files are modified; the contract is solely
    %   that each one calls assert() / error() on regression. Failure of the
    %   suite means the phase has regressed against an existing gate.
    %
    %   See also: bench_monitortag_tick, bench_compositetag_merge,
    %             bench_sensortag_getxy, bench_monitortag_append,
    %             bench_consumer_migration_tick.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
        end
    end

    methods (Test)
        function testMonitorTagTickGate(testCase) %#ok<MANU>
            evalc('bench_monitortag_tick();');
        end

        function testCompositeTagMergeGate(testCase) %#ok<MANU>
            evalc('bench_compositetag_merge();');
        end

        function testSensorTagGetxyGate(testCase) %#ok<MANU>
            evalc('bench_sensortag_getxy();');
        end

        function testMonitorTagAppendGate(testCase) %#ok<MANU>
            evalc('bench_monitortag_append();');
        end

        function testConsumerMigrationTickGate(testCase) %#ok<MANU>
            evalc('bench_consumer_migration_tick();');
        end
    end
end
