classdef TestCompositeThreshold < matlab.unittest.TestCase
    %TESTCOMPOSITETHRESHOLD Unit tests for the CompositeThreshold class.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodTeardown)
        function clearRegistry(testCase) %#ok<MANU>
            ThresholdRegistry.clear();
        end
    end

    methods (Test)

        function testIsThresholdSubclass(testCase)
            c = CompositeThreshold('k');
            testCase.verifyTrue(isa(c, 'Threshold'), 'CompositeThreshold must be a Threshold subclass');
        end

        function testDefaultAggregateMode(testCase)
            c = CompositeThreshold('k');
            testCase.verifyEqual(c.AggregateMode, 'and', 'Default AggregateMode should be and');
        end

        function testAddChildObject(testCase)
            c = CompositeThreshold('k');
            t = Threshold('child1');
            t.addCondition(struct(), 50);
            c.addChild(t, 'Value', 30);
            ch = c.getChildren();
            testCase.verifyEqual(numel(ch), 1, 'Child count should be 1 after addChild');
        end

        function testAddChildByKey(testCase)
            t = Threshold('reg_child');
            t.addCondition(struct(), 50);
            ThresholdRegistry.register('reg_child', t);
            c = CompositeThreshold('k');
            c.addChild('reg_child', 'Value', 30);
            ch = c.getChildren();
            testCase.verifyEqual(numel(ch), 1, 'addChild by key should resolve from registry');
        end

        function testAddChildUnknownKeyWarns(testCase)
            c = CompositeThreshold('k');
            testCase.verifyWarning(@() c.addChild('nonexistent_key_xyz'), ...
                'CompositeThreshold:unknownChildKey');
            ch = c.getChildren();
            testCase.verifyEmpty(ch, 'Child should not be added for unknown key');
        end

        function testComputeStatusAndAllOk(testCase)
            c = CompositeThreshold('k', 'AggregateMode', 'and');
            t1 = Threshold('t1');
            t1.addCondition(struct(), 100);
            t2 = Threshold('t2');
            t2.addCondition(struct(), 100);
            c.addChild(t1, 'Value', 50);
            c.addChild(t2, 'Value', 60);
            testCase.verifyEqual(c.computeStatus(), 'ok', 'AND mode: all ok -> ok');
        end

        function testComputeStatusAndOneViolated(testCase)
            c = CompositeThreshold('k', 'AggregateMode', 'and');
            t1 = Threshold('t1');
            t1.addCondition(struct(), 100);
            t2 = Threshold('t2');
            t2.addCondition(struct(), 100);
            c.addChild(t1, 'Value', 50);
            c.addChild(t2, 'Value', 150);
            testCase.verifyEqual(c.computeStatus(), 'alarm', 'AND mode: one violated -> alarm');
        end

        function testComputeStatusOrOneOk(testCase)
            c = CompositeThreshold('k', 'AggregateMode', 'or');
            t1 = Threshold('t1');
            t1.addCondition(struct(), 100);
            t2 = Threshold('t2');
            t2.addCondition(struct(), 100);
            c.addChild(t1, 'Value', 50);
            c.addChild(t2, 'Value', 150);
            testCase.verifyEqual(c.computeStatus(), 'ok', 'OR mode: one ok -> ok');
        end

        function testComputeStatusOrAllViolated(testCase)
            c = CompositeThreshold('k', 'AggregateMode', 'or');
            t1 = Threshold('t1');
            t1.addCondition(struct(), 100);
            t2 = Threshold('t2');
            t2.addCondition(struct(), 100);
            c.addChild(t1, 'Value', 150);
            c.addChild(t2, 'Value', 200);
            testCase.verifyEqual(c.computeStatus(), 'alarm', 'OR mode: all violated -> alarm');
        end

        function testComputeStatusMajority(testCase)
            c = CompositeThreshold('k', 'AggregateMode', 'majority');
            t1 = Threshold('t1');
            t1.addCondition(struct(), 100);
            t2 = Threshold('t2');
            t2.addCondition(struct(), 100);
            t3 = Threshold('t3');
            t3.addCondition(struct(), 100);
            % 2 ok, 1 violated -> majority ok
            c.addChild(t1, 'Value', 50);
            c.addChild(t2, 'Value', 60);
            c.addChild(t3, 'Value', 150);
            testCase.verifyEqual(c.computeStatus(), 'ok', 'MAJORITY mode: >50% ok -> ok');
        end

        function testComputeStatusMajorityAlarm(testCase)
            c = CompositeThreshold('k', 'AggregateMode', 'majority');
            t1 = Threshold('t1');
            t1.addCondition(struct(), 100);
            t2 = Threshold('t2');
            t2.addCondition(struct(), 100);
            t3 = Threshold('t3');
            t3.addCondition(struct(), 100);
            % 1 ok, 2 violated -> majority alarm
            c.addChild(t1, 'Value', 50);
            c.addChild(t2, 'Value', 150);
            c.addChild(t3, 'Value', 200);
            testCase.verifyEqual(c.computeStatus(), 'alarm', 'MAJORITY mode: <=50% ok -> alarm');
        end

        function testComputeStatusCallsValueFcn(testCase)
            c = CompositeThreshold('k');
            t1 = Threshold('t1');
            t1.addCondition(struct(), 100);
            called = false;
            valueFcn = @() (setField() + 30);
            function v = setField()
                called = true; %#ok<NASGU>
                v = 30;
            end
            c.addChild(t1, 'ValueFcn', valueFcn);
            status = c.computeStatus();
            testCase.verifyEqual(status, 'ok', 'ValueFcn result below threshold -> ok');
        end

        function testComputeStatusStaticValue(testCase)
            c = CompositeThreshold('k');
            t1 = Threshold('t1');
            t1.addCondition(struct(), 100);
            c.addChild(t1, 'Value', 50);
            testCase.verifyEqual(c.computeStatus(), 'ok', 'Static Value below threshold -> ok');
        end

        function testNestedComposite(testCase)
            % Inner composite: both children ok
            inner = CompositeThreshold('inner', 'AggregateMode', 'and');
            t1 = Threshold('t1');
            t1.addCondition(struct(), 100);
            t2 = Threshold('t2');
            t2.addCondition(struct(), 100);
            inner.addChild(t1, 'Value', 50);
            inner.addChild(t2, 'Value', 60);

            % Outer composite
            outer = CompositeThreshold('outer', 'AggregateMode', 'and');
            outer.addChild(inner);
            testCase.verifyEqual(outer.computeStatus(), 'ok', 'Nested composite: inner ok -> outer ok');

            % Change one inner child to violated
            inner2 = CompositeThreshold('inner2', 'AggregateMode', 'and');
            t3 = Threshold('t3');
            t3.addCondition(struct(), 100);
            inner2.addChild(t3, 'Value', 150);
            outer2 = CompositeThreshold('outer2', 'AggregateMode', 'and');
            outer2.addChild(inner2);
            testCase.verifyEqual(outer2.computeStatus(), 'alarm', 'Nested composite: inner alarm -> outer alarm');
        end

        function testSharedChildHandle(testCase)
            t = Threshold('shared');
            t.addCondition(struct(), 100);

            c1 = CompositeThreshold('c1');
            c1.addChild(t, 'Value', 50);

            c2 = CompositeThreshold('c2');
            c2.addChild(t, 'Value', 150);

            testCase.verifyEqual(c1.computeStatus(), 'ok', 'Shared handle c1: value below -> ok');
            testCase.verifyEqual(c2.computeStatus(), 'alarm', 'Shared handle c2: value above -> alarm');
        end

        function testRegistryRoundtrip(testCase)
            c = CompositeThreshold('comp_key', 'AggregateMode', 'or');
            ThresholdRegistry.register('comp_key', c);
            got = ThresholdRegistry.get('comp_key');
            testCase.verifyTrue(isa(got, 'CompositeThreshold'), 'Retrieved object isa CompositeThreshold');
            testCase.verifyTrue(isa(got, 'Threshold'), 'Retrieved object isa Threshold');
            testCase.verifyEqual(got.AggregateMode, 'or', 'AggregateMode preserved in registry');
        end

        function testEmptyChildrenReturnsOk(testCase)
            c = CompositeThreshold('k');
            testCase.verifyEqual(c.computeStatus(), 'ok', 'No children -> status is ok');
        end

        function testAllValuesReturnsEmpty(testCase)
            c = CompositeThreshold('k');
            t = Threshold('child');
            t.addCondition(struct(), 50);
            c.addChild(t, 'Value', 30);
            testCase.verifyEmpty(c.allValues(), 'CompositeThreshold.allValues returns []');
        end

        function testSelfAddChildGuard(testCase)
            c = CompositeThreshold('k');
            testCase.verifyError(@() c.addChild(c), 'CompositeThreshold:selfReference');
        end

        function testAggregateModeSetValidation(testCase)
            c = CompositeThreshold('k');
            c.AggregateMode = 'or';
            testCase.verifyEqual(c.AggregateMode, 'or', 'Can set AggregateMode to or');
            c.AggregateMode = 'majority';
            testCase.verifyEqual(c.AggregateMode, 'majority', 'Can set AggregateMode to majority');
            testCase.verifyError(@() setMode(c, 'invalid'), 'CompositeThreshold:invalidMode');
            function setMode(obj, m)
                obj.AggregateMode = m;
            end
        end

        function testGetChildrenReturnsCell(testCase)
            c = CompositeThreshold('k');
            testCase.verifyClass(c.getChildren(), 'cell', 'getChildren returns cell array');
        end

        % --- Serialization tests ---

        function testToStructBasic(testCase)
            c = CompositeThreshold('sys_a', 'AggregateMode', 'or');
            c.Name = 'System A';
            s = c.toStruct();
            testCase.verifyEqual(s.type, 'composite', 'type must be composite');
            testCase.verifyEqual(s.key, 'sys_a', 'key must match');
            testCase.verifyEqual(s.aggregateMode, 'or', 'aggregateMode must match');
        end

        function testToStructChildren(testCase)
            t1 = Threshold('child_a');
            t1.addCondition(struct(), 50);
            t2 = Threshold('child_b');
            t2.addCondition(struct(), 80);
            c = CompositeThreshold('parent');
            c.addChild(t1, 'Value', 30);
            c.addChild(t2, 'Value', 60);
            s = c.toStruct();
            testCase.verifyEqual(numel(s.children), 2, 'children array should have 2 entries');
            testCase.verifyEqual(s.children{1}.key, 'child_a', 'first child key');
            testCase.verifyEqual(s.children{2}.key, 'child_b', 'second child key');
        end

        function testToStructChildValue(testCase)
            t1 = Threshold('cv_child');
            t1.addCondition(struct(), 50);
            c = CompositeThreshold('cv_parent');
            c.addChild(t1, 'Value', 42);
            s = c.toStruct();
            testCase.verifyEqual(s.children{1}.value, 42, 'static value should appear in child struct');
        end

        function testFromStructRoundTrip(testCase)
            t1 = Threshold('rt_child1');
            t1.addCondition(struct(), 50);
            ThresholdRegistry.register('rt_child1', t1);
            c = CompositeThreshold('rt_parent', 'AggregateMode', 'or');
            c.addChild(t1, 'Value', 30);
            s = c.toStruct();
            c2 = CompositeThreshold.fromStruct(s);
            testCase.verifyEqual(c2.AggregateMode, 'or', 'AggregateMode preserved in round-trip');
            testCase.verifyEqual(numel(c2.getChildren()), 1, 'child count preserved in round-trip');
        end

        function testFromStructResolvesChildKeys(testCase)
            t = Threshold('resolve_child');
            t.addCondition(struct(), 50);
            ThresholdRegistry.register('resolve_child', t);
            s.type = 'composite';
            s.key = 'resolve_parent';
            s.aggregateMode = 'and';
            child.key = 'resolve_child';
            s.children = {child};
            c = CompositeThreshold.fromStruct(s);
            ch = c.getChildren();
            testCase.verifyEqual(numel(ch), 1, 'fromStruct should resolve child key from registry');
            testCase.verifyTrue(ch{1}.threshold == t, 'resolved child should be same handle');
        end

        function testFromStructMissingChildKeyWarns(testCase)
            s.type = 'composite';
            s.key = 'warn_parent';
            s.aggregateMode = 'and';
            child.key = 'totally_missing_key_xyz999';
            s.children = {child};
            c = [];
            testCase.verifyWarning(@() assignIfWarn(), 'CompositeThreshold:loadChildFailed');
            function assignIfWarn()
                c = CompositeThreshold.fromStruct(s); %#ok<NASGU>
            end
        end

        function testNestedCompositeRoundTrip(testCase)
            % Build nested composite: outer -> inner -> leaf
            leaf = Threshold('nested_leaf');
            leaf.addCondition(struct(), 100);
            ThresholdRegistry.register('nested_leaf', leaf);

            inner = CompositeThreshold('nested_inner', 'AggregateMode', 'and');
            inner.addChild(leaf, 'Value', 50);
            ThresholdRegistry.register('nested_inner', inner);

            outer = CompositeThreshold('nested_outer', 'AggregateMode', 'or');
            outer.addChild(inner);

            % Round-trip outer
            s = outer.toStruct();
            outer2 = CompositeThreshold.fromStruct(s);
            testCase.verifyEqual(outer2.AggregateMode, 'or', 'outer AggregateMode preserved');
            testCase.verifyEqual(numel(outer2.getChildren()), 1, 'outer child count preserved');
            innerChild = outer2.getChildren();
            testCase.verifyTrue(isa(innerChild{1}.threshold, 'CompositeThreshold'), ...
                'child of nested outer is a CompositeThreshold');
        end

    end
end
