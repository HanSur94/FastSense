classdef TestDemoStressFleets < matlab.unittest.TestCase
    %TESTDEMOSTRESSFLEETS Verify the industrial-plant stress-fleet helpers.
    %
    %   The stress fleets are opt-in additions to run_demo (via 'StressMode')
    %   that register N synthetic SensorTags backed by K << N shared
    %   multi-column .dat files. They exercise the LiveTagPipeline's
    %   wide-CSV ingestion path at scale -- useful for performance work,
    %   stress testing, and benchmarking, without changing demo defaults.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repoRoot = fileparts(fileparts(here));
            run(fullfile(repoRoot, 'install.m'));
        end
    end

    methods (TestMethodTeardown)
        function clearAfter(testCase) %#ok<MANU>
            try
                stragglers = timerfindall('Name', 'IndustrialPlantDataGen');
                for i = 1:numel(stragglers)
                    try stop(stragglers(i)); catch, end
                    try delete(stragglers(i)); catch, end
                end
            catch
            end
            try TagRegistry.clear(); catch, end
        end
    end

    methods (Test)

        function testStressFleetsOff(testCase)
            f = stressFleets('off');
            testCase.verifyTrue(isstruct(f));
            testCase.verifyEqual(numel(f), 0);
        end

        function testStressFleetsSmall(testCase)
            f = stressFleets('small');
            testCase.verifyEqual(numel(f), 1);
            testCase.verifyEqual(f(1).name, 'pumps');
            testCase.verifyEqual(f(1).nBanks * f(1).nPerBank, 50);
        end

        function testStressFleetsMedium(testCase)
            f = stressFleets('medium');
            testCase.verifyEqual(numel(f), 2);
            total = sum([f.nBanks] .* [f.nPerBank]);
            testCase.verifyEqual(total, 150);
        end

        function testStressFleetsLarge(testCase)
            f = stressFleets('large');
            testCase.verifyEqual(numel(f), 3);
            total = sum([f.nBanks] .* [f.nPerBank]);
            testCase.verifyEqual(total, 350);
        end

        function testStressFleetsUnknownMode(testCase)
            testCase.verifyError(@() stressFleets('huge'), 'stressFleets:unknownMode');
        end

        function testRegisterStressFleetTagsSmall(testCase)
            % 50 tags / 5 files in TagRegistry after registration.
            TagRegistry.clear();
            tmp = tempname();
            mkdir(tmp);
            cleanup = onCleanup(@() cleanupTempDir_(tmp)); %#ok<NASGU>

            fleets = stressFleets('small');
            keys   = registerStressFleetTags(tmp, fleets);

            testCase.verifyEqual(numel(keys), 50);
            for i = 1:numel(keys)
                tag = TagRegistry.get(keys{i});
                testCase.verifyClass(tag, 'SensorTag');
            end
            files = cell(numel(keys), 1);
            for i = 1:numel(keys)
                tag = TagRegistry.get(keys{i});
                files{i} = tag.RawSource.file;
            end
            testCase.verifyEqual(numel(unique(files)), 5, ...
                '50 tags should be backed by exactly 5 shared files');
        end

        function testWriteStressFleetRowProducesFiles(testCase)
            tmp = tempname();
            mkdir(tmp);
            cleanup = onCleanup(@() cleanupTempDir_(tmp)); %#ok<NASGU>

            fleets = stressFleets('small');
            writeStressFleetRow_(tmp, fleets, now(), 0);

            d = dir(fullfile(tmp, 'pump_bank_*.dat'));
            testCase.verifyEqual(numel(d), 5, ...
                'small mode should produce 5 pump_bank_*.dat files');
            for i = 1:numel(d)
                fid = fopen(fullfile(tmp, d(i).name), 'r');
                cleanupFid = onCleanup(@() fclose(fid)); %#ok<NASGU>
                hdr = fgetl(fid);
                % Header: time + 10 column names = 11 fields
                parts = strsplit(hdr, ',');
                testCase.verifyEqual(numel(parts), 11, ...
                    'header should have time + 10 pump columns');
                testCase.verifyEqual(parts{1}, 'time');
            end
        end

        function testWriteStressFleetRowConveyorsOneFile(testCase)
            % medium mode: pumps + conveyors. Conveyors should land in
            % exactly 1 file with 100 columns.
            tmp = tempname();
            mkdir(tmp);
            cleanup = onCleanup(@() cleanupTempDir_(tmp)); %#ok<NASGU>

            fleets = stressFleets('medium');
            writeStressFleetRow_(tmp, fleets, now(), 0);

            d = dir(fullfile(tmp, 'conveyors.dat'));
            testCase.verifyEqual(numel(d), 1);

            fid = fopen(fullfile(tmp, 'conveyors.dat'), 'r');
            cleanupFid = onCleanup(@() fclose(fid)); %#ok<NASGU>
            hdr = fgetl(fid);
            parts = strsplit(hdr, ',');
            testCase.verifyEqual(numel(parts), 101, ...
                'conveyors header should have time + 100 columns');
        end

        function testRegisterFleetsOffIsNoOp(testCase)
            TagRegistry.clear();
            tmp = tempname();
            mkdir(tmp);
            cleanup = onCleanup(@() cleanupTempDir_(tmp)); %#ok<NASGU>

            fleets = stressFleets('off');
            keys   = registerStressFleetTags(tmp, fleets);

            testCase.verifyEqual(numel(keys), 0);
            % Sanity: no leftover files
            d = dir(fullfile(tmp, '*.dat'));
            testCase.verifyEqual(numel(d), 0);
        end
    end
end

function cleanupTempDir_(tmp)
    try
        if exist(tmp, 'dir')
            rmdir(tmp, 's');
        end
    catch
    end
end
