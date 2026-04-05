classdef TestThresholdRegistry < matlab.unittest.TestCase
    %TESTTHRESHOLDREGISTRY Unit tests for the ThresholdRegistry singleton.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodTeardown)
        function cleanupRegistry(testCase) %#ok<MANU>
            % Remove test keys to prevent cross-test pollution
            keysToClean = {'thr_reg_t1', 'thr_reg_t2', 'thr_reg_t3', ...
                           'thr_reg_t4', 'thr_reg_t5', 'thr_reg_t6', ...
                           'thr_reg_t7', 'thr_reg_t8', 'thr_reg_t9', ...
                           'thr_reg_ta', 'thr_reg_tb'};
            for i = 1:numel(keysToClean)
                ThresholdRegistry.unregister(keysToClean{i});
            end
        end
    end

    methods (Test)

        function testRegisterAndGet(testCase)
            t = Threshold('thr_reg_t1', 'Name', 'Test1');
            ThresholdRegistry.register('thr_reg_t1', t);
            got = ThresholdRegistry.get('thr_reg_t1');
            % Verify handle identity via mutation (works in both MATLAB and Octave)
            t.Name = 'Mutated';
            testCase.verifyEqual(got.Name, 'Mutated', 'get returns same handle as registered');
        end

        function testGetUnknownKeyThrows(testCase)
            threw = false;
            try
                ThresholdRegistry.get('nonexistent_thr_xyz_9999');
            catch e
                threw = true;
                testCase.verifyEqual(e.identifier, 'ThresholdRegistry:unknownKey');
            end
            testCase.verifyTrue(threw, 'Should throw ThresholdRegistry:unknownKey');
        end

        function testUnregisterRemovesKey(testCase)
            t = Threshold('thr_reg_t2', 'Name', 'ToRemove');
            ThresholdRegistry.register('thr_reg_t2', t);
            ThresholdRegistry.unregister('thr_reg_t2');
            threw = false;
            try
                ThresholdRegistry.get('thr_reg_t2');
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'get should throw after unregister');
        end

        function testListPrintsWithoutError(testCase)
            t = Threshold('thr_reg_t3', 'Name', 'ForList');
            ThresholdRegistry.register('thr_reg_t3', t);
            % Should not error
            ThresholdRegistry.list();
        end

        function testPrintTableWithoutError(testCase)
            t = Threshold('thr_reg_t4', 'Name', 'ForTable', ...
                'Direction', 'upper', 'Tags', {'test'});
            t.addCondition(struct('machine', 1), 80);
            ThresholdRegistry.register('thr_reg_t4', t);
            % Should not error
            ThresholdRegistry.printTable();
        end

        function testGetMultipleReturnsCellArray(testCase)
            t1 = Threshold('thr_reg_t5', 'Name', 'Multi1');
            t2 = Threshold('thr_reg_t6', 'Name', 'Multi2');
            ThresholdRegistry.register('thr_reg_t5', t1);
            ThresholdRegistry.register('thr_reg_t6', t2);
            result = ThresholdRegistry.getMultiple({'thr_reg_t5', 'thr_reg_t6'});
            testCase.verifyEqual(numel(result), 2, 'getMultiple returns 2 elements');
            testCase.verifyTrue(isa(result{1}, 'Threshold'), 'First is Threshold');
            testCase.verifyTrue(isa(result{2}, 'Threshold'), 'Second is Threshold');
            testCase.verifyEqual(result{1}.Key, t1.Key, 'First matches t1 key');
            testCase.verifyEqual(result{2}.Key, t2.Key, 'Second matches t2 key');
        end

        function testFindByTagMatchingTag(testCase)
            t = Threshold('thr_reg_t7', 'Name', 'Tagged', 'Tags', {'temp', 'alarm'});
            ThresholdRegistry.register('thr_reg_t7', t);
            results = ThresholdRegistry.findByTag('temp');
            testCase.verifyTrue(numel(results) >= 1, 'findByTag returns at least 1');
            keys = cellfun(@(r) r.Key, results, 'UniformOutput', false);
            testCase.verifyTrue(any(strcmp(keys, 'thr_reg_t7')), 'Result contains registered key');
        end

        function testFindByTagNonexistentReturnsEmpty(testCase)
            results = ThresholdRegistry.findByTag('nonexistent_tag_xyz_9999');
            testCase.verifyEmpty(results, 'findByTag returns empty for unknown tag');
        end

        function testFindByDirectionUpper(testCase)
            t = Threshold('thr_reg_t8', 'Name', 'UpperThr', 'Direction', 'upper');
            ThresholdRegistry.register('thr_reg_t8', t);
            results = ThresholdRegistry.findByDirection('upper');
            testCase.verifyTrue(numel(results) >= 1, 'findByDirection upper returns >= 1');
            dirs = cellfun(@(r) r.Direction, results, 'UniformOutput', false);
            testCase.verifyTrue(all(strcmp(dirs, 'upper')), 'All results are upper');
        end

        function testFindByDirectionLower(testCase)
            t = Threshold('thr_reg_t9', 'Name', 'LowerThr', 'Direction', 'lower');
            ThresholdRegistry.register('thr_reg_t9', t);
            results = ThresholdRegistry.findByDirection('lower');
            testCase.verifyTrue(numel(results) >= 1, 'findByDirection lower returns >= 1');
            dirs = cellfun(@(r) r.Direction, results, 'UniformOutput', false);
            testCase.verifyTrue(all(strcmp(dirs, 'lower')), 'All results are lower');
        end

        function testViewerReturnsFigure(testCase)
            t = Threshold('thr_reg_ta', 'Name', 'ForViewer');
            ThresholdRegistry.register('thr_reg_ta', t);
            hFig = ThresholdRegistry.viewer();
            testCase.addTeardown(@() close(hFig));
            testCase.verifyTrue(ishandle(hFig), 'viewer returns figure handle');
        end

    end
end
