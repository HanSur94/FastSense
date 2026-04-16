classdef TestLoadModuleMetadata < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Static)
        function t = makeMetadataTable(stateKeys, nPoints)
            %MAKEMETADATATABLE Build a fake metadata table for testing.
            Date = datetime(2024,1,1) + linspace(0, 1, nPoints)';
            args = {'Date', Date};
            for i = 1:numel(stateKeys)
                args{end+1} = stateKeys{i}; %#ok<AGROW>
                args{end+1} = zeros(nPoints, 1); %#ok<AGROW>
            end
            t = table(args{:});
        end

        function reg = makeRegistryWithRule(key, conditionStruct, value)
            %MAKEREGISTRYWITHRULE Create a registry with one sensor + threshold.
            reg = ExternalSensorRegistry('Test');
            s = Sensor(key);
            s.X = linspace(datenum(2024,1,1), datenum(2024,1,2), 100);
            s.Y = randn(1, 100);
            t = Threshold([key '_thr'], 'Name', 'test', 'Direction', 'upper');
            t.addCondition(conditionStruct, value);
            s.addThreshold(t);
            reg.register(key, s);
        end
    end

    methods (Test)
        function testBasicNumericState(testCase)
            reg = TestLoadModuleMetadata.makeRegistryWithRule( ...
                'temp', struct('machine', 1), 50);

            t = TestLoadModuleMetadata.makeMetadataTable({'machine'}, 100);
            t.machine(51:100) = 1;

            out = loadModuleMetadata(reg, t);

            testCase.verifyTrue(isa(out, 'ExternalSensorRegistry'), 'returns_reg');
            s = reg.get('temp');
            testCase.verifyEqual(numel(s.StateChannels), 1, 'one_sc');
            sc = s.StateChannels{1};
            testCase.verifyEqual(sc.Key, 'machine', 'sc_key');
            testCase.verifyEqual(numel(sc.X), 2, 'sparse_X');
            testCase.verifyEqual(sc.Y, [0 1], 'sparse_Y');
        end

        function testCellStringState(testCase)
            reg = TestLoadModuleMetadata.makeRegistryWithRule( ...
                'temp', struct('recipe', 'bake'), 80);

            Date = datetime(2024,1,1) + linspace(0, 1, 6)';
            recipe = {'idle'; 'idle'; 'bake'; 'bake'; 'bake'; 'idle'};
            t = table(Date, recipe);

            loadModuleMetadata(reg, t);

            sc = reg.get('temp').StateChannels{1};
            testCase.verifyEqual(sc.Key, 'recipe', 'sc_key');
            testCase.verifyEqual(numel(sc.X), 3, 'sparse_X');
            testCase.verifyEqual(sc.Y, {'idle', 'bake', 'idle'}, 'sparse_Y');
        end

        function testMultipleSensorsGetIndependentHandles(testCase)
            reg = ExternalSensorRegistry('Test');
            s1 = Sensor('temp'); s1.X = [1 2]; s1.Y = [3 4];
            t1 = Threshold('temp_thr', 'Name', 'test', 'Direction', 'upper');
            t1.addCondition(struct('machine', 1), 50);
            s1.addThreshold(t1);
            reg.register('temp', s1);
            s2 = Sensor('press'); s2.X = [1 2]; s2.Y = [5 6];
            t2 = Threshold('press_thr', 'Name', 'test', 'Direction', 'upper');
            t2.addCondition(struct('machine', 1), 100);
            s2.addThreshold(t2);
            reg.register('press', s2);

            t = TestLoadModuleMetadata.makeMetadataTable({'machine'}, 100);
            t.machine(51:100) = 1;

            loadModuleMetadata(reg, t);

            sc1 = reg.get('temp').StateChannels{1};
            sc2 = reg.get('press').StateChannels{1};
            testCase.verifyEqual(sc1.X, sc2.X, 'same_X_data');
            testCase.verifyEqual(sc1.Y, sc2.Y, 'same_Y_data');
            % Independent handles: mutating one does not affect the other
            origX = sc2.X;
            sc1.X = [];
            testCase.verifyEqual(sc2.X, origX, 'sc2_independent');
        end

        function testSensorWithNoRulesSkipped(testCase)
            reg = ExternalSensorRegistry('Test');
            s = Sensor('temp'); s.X = [1 2 3]; s.Y = [4 5 6];
            reg.register('temp', s);

            t = TestLoadModuleMetadata.makeMetadataTable({'machine'}, 100);
            loadModuleMetadata(reg, t);

            testCase.verifyTrue(isempty(reg.get('temp').StateChannels), 'no_sc');
        end

        function testRuleReferencesUnknownState(testCase)
            reg = TestLoadModuleMetadata.makeRegistryWithRule( ...
                'temp', struct('recipe', 1), 50);

            t = TestLoadModuleMetadata.makeMetadataTable({'machine'}, 100);
            loadModuleMetadata(reg, t);

            testCase.verifyTrue(isempty(reg.get('temp').StateChannels), ...
                'no_sc_for_unknown_key');
        end

        function testMultipleConditionFields(testCase)
            reg = ExternalSensorRegistry('Test');
            s = Sensor('temp');
            s.X = linspace(datenum(2024,1,1), datenum(2024,1,2), 100);
            s.Y = randn(1, 100);
            t = Threshold('temp_thr', 'Name', 'test', 'Direction', 'upper');
            t.addCondition(struct('machine', 1, 'recipe', 2), 50);
            s.addThreshold(t);
            reg.register('temp', s);

            t = TestLoadModuleMetadata.makeMetadataTable( ...
                {'machine', 'recipe'}, 100);
            t.machine(51:100) = 1;
            t.recipe(31:60) = 2;

            loadModuleMetadata(reg, t);

            scs = reg.get('temp').StateChannels;
            testCase.verifyEqual(numel(scs), 2, 'two_scs');
            keys = cellfun(@(c) c.Key, scs, 'UniformOutput', false);
            testCase.verifyTrue(all(ismember({'machine', 'recipe'}, keys)), ...
                'both_keys_attached');
        end

        function testAllIdenticalValues(testCase)
            reg = TestLoadModuleMetadata.makeRegistryWithRule( ...
                'temp', struct('machine', 0), 50);

            t = TestLoadModuleMetadata.makeMetadataTable({'machine'}, 100);
            loadModuleMetadata(reg, t);

            sc = reg.get('temp').StateChannels{1};
            testCase.verifyEqual(numel(sc.X), 1, 'single_point');
            testCase.verifyEqual(sc.Y, 0, 'single_value');
        end

        function testSinglePointMetadata(testCase)
            reg = TestLoadModuleMetadata.makeRegistryWithRule( ...
                'temp', struct('machine', 1), 50);

            t = table(datetime(2024,1,1), 1, ...
                'VariableNames', {'Date', 'machine'});
            loadModuleMetadata(reg, t);

            sc = reg.get('temp').StateChannels{1};
            testCase.verifyEqual(numel(sc.X), 1, 'single_pt_X');
            testCase.verifyEqual(sc.Y, 1, 'single_pt_Y');
        end

        function testEmptyRegistry(testCase)
            reg = ExternalSensorRegistry('Test');
            t = TestLoadModuleMetadata.makeMetadataTable({'machine'}, 100);
            out = loadModuleMetadata(reg, t);

            testCase.verifyTrue(isa(out, 'ExternalSensorRegistry'), 'returns_reg');
        end

        function testNotTableErrors(testCase)
            reg = ExternalSensorRegistry('Test');
            threw = false;
            try
                loadModuleMetadata(reg, struct('x', 1));
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'not_table_throws');
        end

        function testMissingDateColumnErrors(testCase)
            reg = ExternalSensorRegistry('Test');
            t = table([1; 2; 3], 'VariableNames', {'machine'});
            threw = false;
            try
                loadModuleMetadata(reg, t);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'missing_date_throws');
        end

        function testOutputRowOrientation(testCase)
            reg = TestLoadModuleMetadata.makeRegistryWithRule( ...
                'temp', struct('machine', 1), 50);

            t = TestLoadModuleMetadata.makeMetadataTable({'machine'}, 100);
            t.machine(51:100) = 1;
            loadModuleMetadata(reg, t);

            sc = reg.get('temp').StateChannels{1};
            testCase.verifyEqual(size(sc.X, 1), 1, 'X_is_row');
            testCase.verifyEqual(size(sc.Y, 1), 1, 'Y_is_row');
        end

        function testUnconditionalRuleNoStateChannel(testCase)
            reg = ExternalSensorRegistry('Test');
            s = Sensor('temp'); s.X = [1 2 3]; s.Y = [4 5 6];
            t = Threshold('temp_thr', 'Name', 'always', 'Direction', 'upper');
            t.addCondition(struct(), 50);
            s.addThreshold(t);
            reg.register('temp', s);

            t = TestLoadModuleMetadata.makeMetadataTable({'machine'}, 100);
            loadModuleMetadata(reg, t);

            testCase.verifyTrue(isempty(reg.get('temp').StateChannels), ...
                'unconditional_no_sc');
        end

        function testRepeatedCallAccumulatesChannels(testCase)
            reg = TestLoadModuleMetadata.makeRegistryWithRule( ...
                'temp', struct('machine', 1), 50);

            t = TestLoadModuleMetadata.makeMetadataTable({'machine'}, 100);
            t.machine(51:100) = 1;

            loadModuleMetadata(reg, t);
            loadModuleMetadata(reg, t);

            testCase.verifyEqual(numel(reg.get('temp').StateChannels), 2, ...
                'duplicates_accumulated');
        end
    end
end
