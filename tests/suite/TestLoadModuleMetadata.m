classdef TestLoadModuleMetadata < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Static)
        function ms = makeMetadataStruct(stateKeys, nPoints)
            %MAKEMETADATASTRUCT Build a fake metadata struct for testing.
            ms.time_utc = linspace(datenum(2024,1,1), datenum(2024,1,2), nPoints);
            for i = 1:numel(stateKeys)
                ms.(stateKeys{i}) = zeros(1, nPoints);
                ms.doc.(stateKeys{i}).name = stateKeys{i};
                ms.doc.(stateKeys{i}).datum = 'time_utc';
            end
        end

        function s = makeSensorWithRule(key, conditionStruct, value)
            %MAKESENSORWITHRULE Create a sensor with one ThresholdRule.
            s = Sensor(key);
            s.X = linspace(datenum(2024,1,1), datenum(2024,1,2), 100);
            s.Y = randn(1, 100);
            s.addThresholdRule(conditionStruct, value, ...
                'Direction', 'upper', 'Label', 'test');
        end
    end

    methods (Test)
        function testBasicNumericState(testCase)
            % One sensor with one rule referencing 'machine' state
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 1), 50);

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);
            % Set state: 0 for first 50 points, 1 for last 50
            ms.machine(51:100) = 1;

            sensors = loadModuleMetadata(ms, {s});

            testCase.verifyEqual(numel(sensors), 1, 'returns_sensors');
            testCase.verifyEqual(numel(sensors{1}.StateChannels), 1, 'one_sc');
            sc = sensors{1}.StateChannels{1};
            testCase.verifyEqual(sc.Key, 'machine', 'sc_key');
            % Compressed: 2 transitions (first point=0, then change to 1)
            testCase.verifyEqual(numel(sc.X), 2, 'sparse_X');
            testCase.verifyEqual(sc.Y, [0 1], 'sparse_Y');
        end

        function testCellStringState(testCase)
            % State channel with cell array of char values
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('recipe', 'bake'), 80);

            ms.doc.recipe.name = 'recipe';
            ms.doc.recipe.datum = 'time_utc';
            ms.time_utc = linspace(datenum(2024,1,1), datenum(2024,1,2), 6);
            ms.recipe = {'idle', 'idle', 'bake', 'bake', 'bake', 'idle'};

            sensors = loadModuleMetadata(ms, {s});

            sc = sensors{1}.StateChannels{1};
            testCase.verifyEqual(sc.Key, 'recipe', 'sc_key');
            % Transitions: idle->bake->idle = 3 points
            testCase.verifyEqual(numel(sc.X), 3, 'sparse_X');
            testCase.verifyEqual(sc.Y, {'idle', 'bake', 'idle'}, 'sparse_Y');
        end

        function testMultipleSensorsGetIndependentHandles(testCase)
            % Two sensors both reference 'machine' — same data, own instances
            s1 = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 1), 50);
            s2 = TestLoadModuleMetadata.makeSensorWithRule( ...
                'press', struct('machine', 1), 100);

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);
            ms.machine(51:100) = 1;

            sensors = loadModuleMetadata(ms, {s1, s2});

            sc1 = sensors{1}.StateChannels{1};
            sc2 = sensors{2}.StateChannels{1};
            % Both get same data
            testCase.verifyEqual(sc1.X, sc2.X, 'same_X_data');
            testCase.verifyEqual(sc1.Y, sc2.Y, 'same_Y_data');
            % But independent handles: mutating one does not affect the other
            origX = sc2.X;
            sc1.X = [];
            testCase.verifyEqual(sc2.X, origX, 'sc2_independent');
        end

        function testSensorWithNoRulesSkipped(testCase)
            % Sensor without ThresholdRules gets no StateChannels
            s = Sensor('temp');
            s.X = [1 2 3]; s.Y = [4 5 6];

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);

            sensors = loadModuleMetadata(ms, {s});

            testCase.verifyTrue(isempty(sensors{1}.StateChannels), 'no_sc');
        end

        function testRuleReferencesUnknownState(testCase)
            % Rule references 'recipe' but metadata only has 'machine'
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('recipe', 1), 50);

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);

            sensors = loadModuleMetadata(ms, {s});

            testCase.verifyTrue(isempty(sensors{1}.StateChannels), ...
                'no_sc_for_unknown_key');
        end

        function testMultipleConditionFields(testCase)
            % Rule with condition referencing two state channels
            s = Sensor('temp');
            s.X = linspace(datenum(2024,1,1), datenum(2024,1,2), 100);
            s.Y = randn(1, 100);
            s.addThresholdRule(struct('machine', 1, 'recipe', 2), 50, ...
                'Direction', 'upper', 'Label', 'test');

            ms = TestLoadModuleMetadata.makeMetadataStruct( ...
                {'machine', 'recipe'}, 100);
            ms.machine(51:100) = 1;
            ms.recipe(31:60) = 2;

            sensors = loadModuleMetadata(ms, {s});

            testCase.verifyEqual(numel(sensors{1}.StateChannels), 2, 'two_scs');
            keys = cellfun(@(c) c.Key, sensors{1}.StateChannels, ...
                'UniformOutput', false);
            testCase.verifyTrue(all(ismember({'machine', 'recipe'}, keys)), ...
                'both_keys_attached');
        end

        function testAllIdenticalValues(testCase)
            % State never changes — produces single-point StateChannel
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 0), 50);

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);
            % machine stays 0 everywhere (default)

            sensors = loadModuleMetadata(ms, {s});

            sc = sensors{1}.StateChannels{1};
            testCase.verifyEqual(numel(sc.X), 1, 'single_point');
            testCase.verifyEqual(sc.Y, 0, 'single_value');
        end

        function testSinglePointMetadata(testCase)
            % Metadata with only one time point
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 1), 50);

            ms.doc.machine.name = 'machine';
            ms.doc.machine.datum = 'time_utc';
            ms.time_utc = datenum(2024,1,1);
            ms.machine = 1;

            sensors = loadModuleMetadata(ms, {s});

            sc = sensors{1}.StateChannels{1};
            testCase.verifyEqual(numel(sc.X), 1, 'single_pt_X');
            testCase.verifyEqual(sc.Y, 1, 'single_pt_Y');
        end

        function testColumnVectorInputs(testCase)
            % Column vector inputs must produce row vector StateChannel
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 1), 50);

            ms.doc.machine.name = 'machine';
            ms.doc.machine.datum = 'time_utc';
            ms.time_utc = linspace(datenum(2024,1,1), datenum(2024,1,2), 6)';
            ms.machine = [0; 0; 1; 1; 0; 0];

            sensors = loadModuleMetadata(ms, {s});

            sc = sensors{1}.StateChannels{1};
            testCase.verifyEqual(size(sc.X, 1), 1, 'X_is_row');
            testCase.verifyEqual(size(sc.Y, 1), 1, 'Y_is_row');
        end

        function testEmptySensors(testCase)
            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);
            sensors = loadModuleMetadata(ms, {});
            testCase.verifyTrue(isempty(sensors), 'empty_passthrough');
        end

        function testMissingDocErrors(testCase)
            ms = struct('machine', [1 2 3]);
            threw = false;
            try
                loadModuleMetadata(ms, {});
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'missing_doc_throws');
        end

        function testDocMissingDatumErrors(testCase)
            % doc entry without .datum field
            ms.doc.machine.name = 'machine';  % no .datum
            ms.machine = [1 2 3];
            threw = false;
            try
                loadModuleMetadata(ms, {});
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'missing_datum_throws');
        end

        function testDatenumFieldNotInStructErrors(testCase)
            ms.doc.machine.name = 'machine';
            ms.doc.machine.datum = 'nonexistent';
            ms.machine = [1 2 3];
            threw = false;
            try
                loadModuleMetadata(ms, {});
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'bad_datenum_ref_throws');
        end

        function testDatumNotCharErrors(testCase)
            % Defensive test: validates datum type
            ms.doc.machine.name = 'machine';
            ms.doc.machine.datum = 42;
            ms.machine = [1 2 3];
            threw = false;
            try
                loadModuleMetadata(ms, {});
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'non_char_datum_throws');
        end

        function testOutputRowOrientation(testCase)
            % StateChannel X/Y must be row vectors (1xN)
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 1), 50);

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);
            ms.machine(51:100) = 1;

            sensors = loadModuleMetadata(ms, {s});

            sc = sensors{1}.StateChannels{1};
            testCase.verifyEqual(size(sc.X, 1), 1, 'X_is_row');
            testCase.verifyEqual(size(sc.Y, 1), 1, 'Y_is_row');
        end

        function testUnconditionalRuleNoStateChannel(testCase)
            % Rule with empty condition struct() needs no state channels
            s = Sensor('temp');
            s.X = [1 2 3]; s.Y = [4 5 6];
            s.addThresholdRule(struct(), 50, ...
                'Direction', 'upper', 'Label', 'always');

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);

            sensors = loadModuleMetadata(ms, {s});

            testCase.verifyTrue(isempty(sensors{1}.StateChannels), ...
                'unconditional_no_sc');
        end

        function testRepeatedCallAccumulatesChannels(testCase)
            % Calling twice adds duplicate StateChannels (by design)
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 1), 50);

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);
            ms.machine(51:100) = 1;

            loadModuleMetadata(ms, {s});
            loadModuleMetadata(ms, {s});

            testCase.verifyEqual(numel(s.StateChannels), 2, ...
                'duplicates_accumulated');
        end
    end
end
