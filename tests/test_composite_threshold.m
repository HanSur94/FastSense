function test_composite_threshold()
%TEST_COMPOSITE_THRESHOLD Octave function-based tests for CompositeThreshold.

    add_threshold_path();
    ThresholdRegistry.clear();

    % Test 1: Constructor defaults - isa Threshold, AggregateMode='and'
    c = CompositeThreshold('k');
    assert(isa(c, 'Threshold'), 'test1: CompositeThreshold isa Threshold');
    assert(isa(c, 'CompositeThreshold'), 'test1: CompositeThreshold isa CompositeThreshold');
    assert(strcmp(c.AggregateMode, 'and'), 'test1: default AggregateMode is and');
    assert(strcmp(c.Key, 'k'), 'test1: Key set correctly');

    % Test 2: addChild with object + Value
    c2 = CompositeThreshold('k2');
    t = Threshold('child2');
    t.addCondition(struct(), 100);
    c2.addChild(t, 'Value', 50);
    ch = c2.getChildren();
    assert(numel(ch) == 1, 'test2: child count is 1 after addChild');
    assert(ch{1}.threshold == t, 'test2: child threshold matches');
    assert(ch{1}.value == 50, 'test2: child value is 50');

    ThresholdRegistry.clear();

    % Test 3: computeStatus AND mode (all ok)
    c3 = CompositeThreshold('k3', 'AggregateMode', 'and');
    t1 = Threshold('t3a');
    t1.addCondition(struct(), 100);
    t2 = Threshold('t3b');
    t2.addCondition(struct(), 100);
    c3.addChild(t1, 'Value', 50);
    c3.addChild(t2, 'Value', 60);
    assert(strcmp(c3.computeStatus(), 'ok'), 'test3: AND mode all ok -> ok');

    % Test 4: computeStatus AND mode (one violated)
    c4 = CompositeThreshold('k4', 'AggregateMode', 'and');
    t3 = Threshold('t4a');
    t3.addCondition(struct(), 100);
    t4 = Threshold('t4b');
    t4.addCondition(struct(), 100);
    c4.addChild(t3, 'Value', 50);
    c4.addChild(t4, 'Value', 150);
    assert(strcmp(c4.computeStatus(), 'alarm'), 'test4: AND mode one violated -> alarm');

    % Test 5: computeStatus OR mode
    c5a = CompositeThreshold('k5a', 'AggregateMode', 'or');
    ta = Threshold('t5a');
    ta.addCondition(struct(), 100);
    tb = Threshold('t5b');
    tb.addCondition(struct(), 100);
    c5a.addChild(ta, 'Value', 50);
    c5a.addChild(tb, 'Value', 150);
    assert(strcmp(c5a.computeStatus(), 'ok'), 'test5a: OR mode one ok -> ok');

    c5b = CompositeThreshold('k5b', 'AggregateMode', 'or');
    tc = Threshold('t5c');
    tc.addCondition(struct(), 100);
    td = Threshold('t5d');
    td.addCondition(struct(), 100);
    c5b.addChild(tc, 'Value', 150);
    c5b.addChild(td, 'Value', 200);
    assert(strcmp(c5b.computeStatus(), 'alarm'), 'test5b: OR mode all violated -> alarm');

    % Test 6: computeStatus MAJORITY mode
    c6 = CompositeThreshold('k6', 'AggregateMode', 'majority');
    te = Threshold('t6a');
    te.addCondition(struct(), 100);
    tf = Threshold('t6b');
    tf.addCondition(struct(), 100);
    tg = Threshold('t6c');
    tg.addCondition(struct(), 100);
    c6.addChild(te, 'Value', 50);
    c6.addChild(tf, 'Value', 60);
    c6.addChild(tg, 'Value', 150);
    assert(strcmp(c6.computeStatus(), 'ok'), 'test6: MAJORITY 2/3 ok -> ok');

    % Test 7: Nested composite evaluation
    inner = CompositeThreshold('inner7', 'AggregateMode', 'and');
    ti1 = Threshold('ti1');
    ti1.addCondition(struct(), 100);
    ti2 = Threshold('ti2');
    ti2.addCondition(struct(), 100);
    inner.addChild(ti1, 'Value', 50);
    inner.addChild(ti2, 'Value', 60);

    outer = CompositeThreshold('outer7', 'AggregateMode', 'and');
    outer.addChild(inner);
    assert(strcmp(outer.computeStatus(), 'ok'), 'test7: nested composite inner ok -> outer ok');

    % Test 8: Registry round-trip
    ThresholdRegistry.clear();
    c8 = CompositeThreshold('comp8', 'AggregateMode', 'or');
    ThresholdRegistry.register('comp8', c8);
    got = ThresholdRegistry.get('comp8');
    assert(isa(got, 'CompositeThreshold'), 'test8: registry returns CompositeThreshold');
    assert(isa(got, 'Threshold'), 'test8: registry result isa Threshold');
    assert(strcmp(got.AggregateMode, 'or'), 'test8: AggregateMode preserved');

    % Test 9: allValues returns empty
    c9 = CompositeThreshold('k9');
    tj = Threshold('t9a');
    tj.addCondition(struct(), 50);
    c9.addChild(tj, 'Value', 30);
    assert(isempty(c9.allValues()), 'test9: allValues returns [] for composite');

    ThresholdRegistry.clear();

    fprintf('    All 9 composite threshold tests passed.\n');
end

function add_threshold_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
