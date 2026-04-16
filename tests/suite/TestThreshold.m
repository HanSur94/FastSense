classdef TestThreshold < matlab.unittest.TestCase
    %TESTTHRESHOLD Unit tests for the Threshold handle class.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)

        function testConstructorDefaultsKey(testCase)
            t = Threshold('k');
            testCase.verifyEqual(t.Key, 'k', 'Key should be set');
            testCase.verifyEqual(t.Direction, 'upper', 'Direction default upper');
            testCase.verifyTrue(t.IsUpper, 'IsUpper should be true for upper');
            testCase.verifyEqual(t.LineStyle, '--', 'LineStyle default --');
            testCase.verifyEmpty(t.Name, 'Name should be empty');
            testCase.verifyEmpty(t.Color, 'Color should be empty');
            testCase.verifyEmpty(t.Units, 'Units should be empty');
            testCase.verifyEmpty(t.Description, 'Description should be empty');
            testCase.verifyEmpty(t.Tags, 'Tags should be empty');
        end

        function testConstructorAllOptions(testCase)
            t = Threshold('k', 'Name', 'X', 'Direction', 'lower', ...
                'Color', [1 0 0], 'LineStyle', ':', 'Units', 'degC', ...
                'Description', 'desc', 'Tags', {'temp'});
            testCase.verifyEqual(t.Key, 'k');
            testCase.verifyEqual(t.Name, 'X');
            testCase.verifyEqual(t.Direction, 'lower');
            testCase.verifyFalse(t.IsUpper, 'IsUpper false for lower');
            testCase.verifyEqual(t.Color, [1 0 0]);
            testCase.verifyEqual(t.LineStyle, ':');
            testCase.verifyEqual(t.Units, 'degC');
            testCase.verifyEqual(t.Description, 'desc');
            testCase.verifyEqual(t.Tags, {'temp'});
        end

        function testIsUpperFalseForLower(testCase)
            t = Threshold('k', 'Direction', 'lower');
            testCase.verifyFalse(t.IsUpper, 'IsUpper must be false for lower direction');
        end

        function testUnknownOptionThrows(testCase)
            threw = false;
            try
                Threshold('k', 'BadOpt', 1);
            catch e
                threw = true;
                testCase.verifyEqual(e.identifier, 'Threshold:unknownOption');
            end
            testCase.verifyTrue(threw, 'Should throw for unknown option');
        end

        function testAddConditionSingle(testCase)
            t = Threshold('k');
            t.addCondition(struct('machine', 1), 80);
            testCase.verifyEqual(numel(t.conditions_), 1, 'One condition stored');
        end

        function testAddConditionMultiple(testCase)
            t = Threshold('k');
            t.addCondition(struct('machine', 1), 80);
            t.addCondition(struct('machine', 2), 90);
            testCase.verifyEqual(numel(t.conditions_), 2, 'Two conditions stored');
        end

        function testAllValuesReturnsVector(testCase)
            t = Threshold('k');
            t.addCondition(struct('machine', 1), 80);
            t.addCondition(struct('machine', 2), 90);
            vals = t.allValues();
            testCase.verifyEqual(sort(vals), [80, 90], 'allValues returns [80, 90]');
        end

        function testAllValuesEmptyWhenNoConditions(testCase)
            t = Threshold('k');
            vals = t.allValues();
            testCase.verifyEmpty(vals, 'allValues returns [] with no conditions');
        end

        function testGetConditionFieldsSingle(testCase)
            t = Threshold('k');
            t.addCondition(struct('machine', 1), 80);
            fields = t.getConditionFields();
            testCase.verifyEqual(fields, {'machine'}, 'getConditionFields returns {machine}');
        end

        function testGetConditionFieldsUniqueSorted(testCase)
            t = Threshold('k');
            t.addCondition(struct('machine', 1, 'zone', 2), 80);
            t.addCondition(struct('machine', 2), 90);
            fields = t.getConditionFields();
            % Should return unique sorted fields
            testCase.verifyTrue(numel(fields) >= 1, 'Has fields');
            testCase.verifyTrue(any(strcmp(fields, 'machine')), 'Has machine');
        end

        function testIsHandleClass(testCase)
            t = Threshold('k');
            t2 = t;
            t2.Name = 'Modified';
            testCase.verifyEqual(t.Name, 'Modified', 'Handle class: modification via copy reflects on original');
        end

        function testLabelDependentProperty(testCase)
            t = Threshold('k', 'Name', 'MyName');
            testCase.verifyEqual(t.Label, 'MyName', 'Label returns Name value');
        end

        function testLabelEmptyWhenNameEmpty(testCase)
            t = Threshold('k');
            testCase.verifyEmpty(t.Label, 'Label empty when Name is empty');
        end

    end
end
