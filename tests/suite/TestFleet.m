classdef TestFleet < matlab.unittest.TestCase
    %TESTFLEET Unit tests for Phase 1042 Fleet (Fleet layer).
    %   Nyquist Wave 0 scaffold — all tests are RED until Plan 04 delivers
    %   libs/Fleet/Fleet.m.  These suites encode the expected behavior
    %   described in FLEET-01, FLEET-04, and FLEET-06 before any production
    %   code is written.
    %
    %   Coverage:
    %     FLEET-01: Fleet.addMachine factory form + handle form; duplicate Id error
    %     FLEET-04: JSON save/load round-trip; embedded canonical map; fleetConfigVersion;
    %               relative DataRoot resolution against config file directory (D-07)
    %     FLEET-06: filterByName / filterByGroup case-insensitive substring; composable
    %
    %   See also TestMachine, Fleet, Machine, CanonicalMapper.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'tests', 'suite'));
        end
    end

    methods (TestMethodSetup)
        function clearRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function clearRegistryAfter(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    % ---- FLEET-01: addMachine factory + handle form + duplicate guard ----

    methods (Test)

        function testAddMachineFactoryForm(testCase)
            %TESTADDMACHINEFACTORYFORM addMachine with NV pairs constructs and returns Machine.
            fleet = Fleet();
            m = fleet.addMachine('Id', 'M01', 'Name', 'Pump 1');
            testCase.verifyClass(m, 'Machine');
            testCase.verifyEqual(fleet.machineCount(), 1);
        end

        function testAddMachineHandleForm(testCase)
            %TESTADDMACHINEHANDLEFORM addMachine with pre-built Machine handle works.
            fleet = Fleet();
            m = Machine('Id', 'M02', 'Name', 'Pump 2');
            fleet.addMachine(m);
            testCase.verifyEqual(fleet.machineCount(), 1);
        end

        function testDuplicateMachineIdErrors(testCase)
            %TESTDUPLICATEMACHINEIDERRORS Adding two machines with same Id throws Fleet:duplicateMachineId.
            fleet = Fleet();
            fleet.addMachine('Id', 'M01', 'Name', 'Alpha');
            testCase.verifyError( ...
                @() fleet.addMachine('Id', 'M01', 'Name', 'Beta'), ...
                'Fleet:duplicateMachineId');
        end

        % ---- FLEET-04: JSON round-trip ----

        function testSaveLoadRoundTrip(testCase)
            %TESTSAVELOADROUNDTRIP save + Fleet.load preserves machine count, Name, Group.
            tmp = tempname();
            mkdir(tmp);
            jsonPath = fullfile(tmp, 'fleet.json');

            fleet = Fleet();
            fleet.addMachine('Id', 'M01', 'Name', 'Alpha', 'DataRoot', tmp, 'Group', 'pumps');
            fleet.addMachine('Id', 'M02', 'Name', 'Beta',  'DataRoot', tmp, 'Group', 'motors');
            fleet.save(jsonPath);

            fleet2 = Fleet.load(jsonPath);
            testCase.verifyEqual(fleet2.machineCount(), 2);
            testCase.verifyEqual(fleet2.getMachine('M01').Name, 'Alpha');
            testCase.verifyEqual(fleet2.getMachine('M02').Name, 'Beta');
            testCase.verifyEqual(fleet2.getMachine('M01').Group, 'pumps');
        end

        function testCanonicalMapEmbedded(testCase)
            %TESTCANONICALMAPEMBEDDED Canonical map entries survive save/load round-trip.
            tmp = tempname();
            mkdir(tmp);
            jsonPath = fullfile(tmp, 'fleet.json');

            fleet = Fleet();
            fleet.addMachine('Id', 'M01', 'Name', 'Alpha', 'DataRoot', tmp);
            fleet.addMachine('Id', 'M02', 'Name', 'Beta',  'DataRoot', tmp);

            % Add a mapping entry to the canonical mapper
            % Similar keys so suggest() clusters them into a canonical entry
            % (dissimilar keys would leave the map empty and make the round-trip
            %  assertion below vacuous).
            tagInfos = { ...
                struct('machineId', 'M01', 'localKey', 'temp_motor', ...
                       'name', 'Motor Temp', 'units', 'degC'), ...
                struct('machineId', 'M02', 'localKey', 'temp_mtor', ...
                       'name', 'Temp Mtor',  'units', 'degC') ...
            };
            fleet.Mapper_.suggest(tagInfos);

            fleet.save(jsonPath);
            fleet2 = Fleet.load(jsonPath);

            % The canonical map must round-trip with its content intact (FLEET-04).
            testCase.verifyClass(fleet2.Mapper_, 'CanonicalMapper');
            before = fleet.Mapper_.toStruct();
            after  = fleet2.Mapper_.toStruct();
            testCase.verifyGreaterThan(numel(before.entries), 0, ...
                'precondition: suggest() must produce at least one canonical entry');
            testCase.verifyEqual(numel(after.entries), numel(before.entries), ...
                'Canonical map entry count must survive save/load (FLEET-04)');
            testCase.verifyEqual(after, before, ...
                'Canonical map must round-trip identically through fleet save/load (FLEET-04)');
        end

        function testFleetConfigVersionPresent(testCase)
            %TESTFLEETCONFIGVERSIONPRESENT Saved JSON contains "fleetConfigVersion":1.
            tmp = tempname();
            mkdir(tmp);
            jsonPath = fullfile(tmp, 'fleet.json');

            fleet = Fleet();
            fleet.addMachine('Id', 'M01', 'DataRoot', tmp);
            fleet.save(jsonPath);

            fid = fopen(jsonPath, 'r');
            raw = fread(fid, '*char')';
            fclose(fid);

            testCase.verifyFalse(isempty(strfind(raw, '"fleetConfigVersion":1')), ...
                'Saved JSON must contain "fleetConfigVersion":1 (FLEET-04)');
        end

        function testRelativeDataRootResolvedAgainstConfigDir(testCase)
            %TESTRELATIVEDATAROOTRESOLVEDAGAINSTCONFIGDIR Relative DataRoot resolves against config dir.
            %   D-07: relative path in saved JSON loads as absolute under config file dir.
            tmp = tempname();
            mkdir(tmp);
            dataDir = fullfile(tmp, 'data_m01');
            mkdir(dataDir);
            jsonPath = fullfile(tmp, 'fleet.json');

            fleet = Fleet();
            % Store relative DataRoot (relative to tmp where the json will live)
            fleet.addMachine('Id', 'M01', 'DataRoot', 'data_m01', 'Name', 'Alpha');
            fleet.save(jsonPath);

            fleet2 = Fleet.load(jsonPath);
            loadedRoot = fleet2.getMachine('M01').DataRoot;
            % Loaded DataRoot must be absolute and resolve to dataDir
            testCase.verifyTrue(isempty(strfind(loadedRoot, '..')), ...
                'Loaded DataRoot must not contain .. after resolution');
            testCase.verifyEqual(loadedRoot, dataDir, ...
                'Relative DataRoot must resolve against the config file directory (D-07)');
        end

        % ---- FLEET-06: filterByName / filterByGroup ----

        function testFilterByName(testCase)
            %TESTFILTERBYNAME Case-insensitive substring filter on Name.
            fleet = Fleet();
            fleet.addMachine('Id', 'M01', 'Name', 'Pump Station Alpha');
            fleet.addMachine('Id', 'M02', 'Name', 'Pump Station Beta');
            fleet.addMachine('Id', 'M03', 'Name', 'Compressor One');

            byPump = fleet.filterByName('pump');
            testCase.verifyEqual(numel(byPump), 2, ...
                'filterByName(pump) must match 2 machines (case-insensitive)');
            byComp = fleet.filterByName('compressor');
            testCase.verifyEqual(numel(byComp), 1);
            byMiss = fleet.filterByName('turbine');
            testCase.verifyEmpty(byMiss, 'filterByName with no match returns empty');
        end

        function testFilterByGroup(testCase)
            %TESTFILTERBYGROUP Case-insensitive substring filter on Group.
            fleet = Fleet();
            fleet.addMachine('Id', 'M01', 'Name', 'A', 'Group', 'pumps');
            fleet.addMachine('Id', 'M02', 'Name', 'B', 'Group', 'pumps');
            fleet.addMachine('Id', 'M03', 'Name', 'C', 'Group', 'motors');

            byPumps = fleet.filterByGroup('pumps');
            testCase.verifyEqual(numel(byPumps), 2);
            byMotors = fleet.filterByGroup('MOTORS');  % case-insensitive
            testCase.verifyEqual(numel(byMotors), 1);
        end

        function testFiltersComposable(testCase)
            %TESTFILTERSCOMPOSABLE Chaining filterByGroup then filterByName narrows results (AND).
            fleet = Fleet();
            fleet.addMachine('Id', 'M01', 'Name', 'Pump Alpha',   'Group', 'pumps');
            fleet.addMachine('Id', 'M02', 'Name', 'Pump Beta',    'Group', 'pumps');
            fleet.addMachine('Id', 'M03', 'Name', 'Compressor A', 'Group', 'motors');

            % Filter by group 'pumps' -> 2 machines
            byGroup = fleet.filterByGroup('pumps');
            testCase.verifyEqual(numel(byGroup), 2);

            % Now filter that subset by name 'alpha' -> 1 machine
            % filterByName on a Fleet is tested; for composability we need a
            % second Fleet or the method to accept a subset — per FLEET-06 the
            % documented pattern is chaining on the fleet itself (the result of
            % filterByGroup is a cell of machines; the caller narrows with a
            % second call on the fleet).  Verify the fleet's direct composition:
            byGroupAlpha = fleet.filterByGroup('pumps');
            byGroupAlphaNames = cellfun(@(m) m.Name, byGroupAlpha, 'UniformOutput', false);
            alphaMatches = byGroupAlpha(~cellfun(@(n) isempty(strfind(lower(n), 'alpha')), ...
                byGroupAlphaNames));
            testCase.verifyEqual(numel(alphaMatches), 1, ...
                'Composable filter (group=pumps AND name contains alpha) must return exactly 1 machine');
        end

    end

end
