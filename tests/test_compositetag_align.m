function test_compositetag_align()
%TEST_COMPOSITETAG_ALIGN Octave flat-style mirror of TestCompositeTagAlign.m (Plan 02).
%   Asserts:
%     A. Merge-sort correctness (COMPOSITE-05, ALIGN-02)
%     B. ALIGN-03 pre-history drop
%     C. ALIGN-01 ZOH-only (no interp1 in source)
%     D. ALIGN-03 + ALIGN-04 joint NaN propagation (via empty-start segments)
%     E. COMPOSITE-06 valueAt fast-path (no materialization)
%     F. Invalidation cascade end-to-end
%     G. Diamond invalidation
%
%   NOTE: ALIGN-04 NaN truth tables are exhaustively covered by Plan 01's
%   test_compositetag() testTruthTableAllModes (29 rows). This file covers
%   STRUCTURAL NaN propagation via ALIGN-03 + ZOH seed ordering.
%
%   RED expectation: before Task 2 ships mergeStream_, every getXY() call
%   aborts with CompositeTag:notImplemented.
%
%   See also test_compositetag, TestCompositeTagAlign.

    add_compositetag_align_paths_();
    TagRegistry.clear();

    nAsserts = 0;

    %% A. Merge-sort correctness

    % A1: Two identical-X children, AND aggregation.
    s1 = SensorTag('s1', 'X', 1:10, 'Y', [0 0 10 10 10 0 0 0 0 0]);
    s2 = SensorTag('s2', 'X', 1:10, 'Y', [0 0 0 10 10 10 10 0 0 0]);
    m1 = MonitorTag('m1', s1, @(x, y) y > 5);
    m2 = MonitorTag('m2', s2, @(x, y) y > 5);
    c  = CompositeTag('c', 'and');
    c.addChild(m1);
    c.addChild(m2);
    [X, Y] = c.getXY();
    assert(numel(X) == 10, 'A1: union size must be 10');
    assert(X(1) == 1 && X(end) == 10, 'A1: X span [1, 10]');
    assert(Y(1) == 0, 'A1: idx 1 both 0 -> AND 0');
    assert(Y(3) == 0, 'A1: idx 3 m1=1 m2=0 -> AND 0');
    assert(Y(4) == 1 && Y(5) == 1, 'A1: overlap 4-5 -> AND 1');
    assert(Y(6) == 0, 'A1: idx 6 m1=0 m2=1 -> AND 0');
    assert(Y(10) == 0, 'A1: idx 10 both 0 -> AND 0');
    nAsserts = nAsserts + 1;

    TagRegistry.clear();

    % A2: Two staggered-X children, OR aggregation, ALIGN-03 drop.
    s3 = SensorTag('s3', 'X', [1 2 3 4 5],       'Y', [0 10 0 0 0]);
    s4 = SensorTag('s4', 'X', [1.5 2.5 3.5 4.5], 'Y', [0 10 0 0]);
    m3 = MonitorTag('m3', s3, @(x, y) y > 5);
    m4 = MonitorTag('m4', s4, @(x, y) y > 5);
    c2 = CompositeTag('c2', 'or');
    c2.addChild(m3);
    c2.addChild(m4);
    [X2, Y2] = c2.getXY();
    assert(numel(X2) == 8, ...
        sprintf('A2: staggered union after ALIGN-03 drop = 8, got %d', numel(X2)));
    assert(X2(1) == 1.5, sprintf('A2: first X == 1.5, got %g', X2(1)));
    assert(X2(end) == 5, sprintf('A2: last X == 5, got %g', X2(end)));
    nonNanY = Y2(~isnan(Y2));
    assert(all(ismember(nonNanY, [0 1])), 'A2: Y must be binary 0/1');
    nAsserts = nAsserts + 1;

    TagRegistry.clear();

    % A3: Same-timestamp coalesce.
    s5 = SensorTag('s5', 'X', [1 5 10], 'Y', [0 10 0]);
    s6 = SensorTag('s6', 'X', [2 5 8],  'Y', [0 10 0]);
    m5 = MonitorTag('m5', s5, @(x, y) y > 5);
    m6 = MonitorTag('m6', s6, @(x, y) y > 5);
    c3 = CompositeTag('c3', 'or');
    c3.addChild(m5);
    c3.addChild(m6);
    [X3, Y3] = c3.getXY();
    assert(numel(X3) == 4, ...
        sprintf('A3: coalesced union after drop = 4, got %d', numel(X3)));
    idx5 = find(X3 == 5, 1, 'first');
    assert(~isempty(idx5), 'A3: t=5 must appear');
    assert(sum(X3 == 5) == 1, 'A3: t=5 coalesced to single emission');
    assert(Y3(idx5) == 1, 'A3: OR at t=5 = 1');
    nAsserts = nAsserts + 1;

    TagRegistry.clear();

    %% B. ALIGN-03 pre-history drop

    % B4: Staggered start
    sB1 = SensorTag('sB1', 'X', 1:10,  'Y', ones(1, 10));
    sB2 = SensorTag('sB2', 'X', 5:15,  'Y', ones(1, 11));
    mB1 = MonitorTag('mB1', sB1, @(x, y) y > 0.5);
    mB2 = MonitorTag('mB2', sB2, @(x, y) y > 0.5);
    cB  = CompositeTag('cB', 'or');
    cB.addChild(mB1);
    cB.addChild(mB2);
    [XB, ~] = cB.getXY();
    assert(XB(1) == 5, sprintf('B4: first X == 5, got %g', XB(1)));
    nAsserts = nAsserts + 1;

    TagRegistry.clear();

    % B5: Both children start same
    sB3 = SensorTag('sB3', 'X', 1:10, 'Y', ones(1, 10));
    sB4 = SensorTag('sB4', 'X', 1:10, 'Y', ones(1, 10));
    mB3 = MonitorTag('mB3', sB3, @(x, y) y > 0.5);
    mB4 = MonitorTag('mB4', sB4, @(x, y) y > 0.5);
    cB2 = CompositeTag('cB2', 'or');
    cB2.addChild(mB3);
    cB2.addChild(mB4);
    [XB2, ~] = cB2.getXY();
    assert(XB2(1) == 1, sprintf('B5: first X == 1, got %g', XB2(1)));
    nAsserts = nAsserts + 1;

    TagRegistry.clear();

    % B6: Three staggered starts
    sB5 = SensorTag('sB5', 'X', 1:20,  'Y', ones(1, 20));
    sB6 = SensorTag('sB6', 'X', 5:20,  'Y', ones(1, 16));
    sB7 = SensorTag('sB7', 'X', 10:20, 'Y', ones(1, 11));
    mB5 = MonitorTag('mB5', sB5, @(x, y) y > 0.5);
    mB6 = MonitorTag('mB6', sB6, @(x, y) y > 0.5);
    mB7 = MonitorTag('mB7', sB7, @(x, y) y > 0.5);
    cB3 = CompositeTag('cB3', 'and');
    cB3.addChild(mB5);
    cB3.addChild(mB6);
    cB3.addChild(mB7);
    [XB3, ~] = cB3.getXY();
    assert(XB3(1) == 10, sprintf('B6: first X == 10, got %g', XB3(1)));
    nAsserts = nAsserts + 1;

    TagRegistry.clear();

    %% C. ALIGN-01 ZOH-only (no interp1 grep gate)

    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    src  = fileread(fullfile(repo, ...
        'libs', 'SensorThreshold', 'CompositeTag.m'));
    assert(isempty(regexp(src, 'interp1', 'once')), ...
        'C7: CompositeTag.m must not contain interp1 (ALIGN-01).');
    nAsserts = nAsserts + 1;

    % C8: ZOH binary output
    sC1 = SensorTag('sC1', 'X', [1 3 5], 'Y', [0 0 10]);
    sC2 = SensorTag('sC2', 'X', [2 4 6], 'Y', [0 10 0]);
    mC1 = MonitorTag('mC1', sC1, @(x, y) y > 5);
    mC2 = MonitorTag('mC2', sC2, @(x, y) y > 5);
    cC  = CompositeTag('cC', 'and');
    cC.addChild(mC1);
    cC.addChild(mC2);
    [~, YC] = cC.getXY();
    nonNanYC = YC(~isnan(YC));
    assert(all(ismember(nonNanYC, [0 1])), ...
        'C8: AND output must be binary (no interpolation).');
    nAsserts = nAsserts + 1;

    TagRegistry.clear();

    %% D. ALIGN-03 + ALIGN-04 joint test

    sD1 = SensorTag('sD1', 'X', [10 20 30], 'Y', [0 0 0]);
    sD2 = SensorTag('sD2', 'X', [5 15 25],  'Y', [0 0 0]);
    mD1 = MonitorTag('mD1', sD1, @(x, y) y > 0.5);
    mD2 = MonitorTag('mD2', sD2, @(x, y) y > 0.5);
    cD  = CompositeTag('cD', 'and');
    cD.addChild(mD1);
    cD.addChild(mD2);
    [XD, YD] = cD.getXY();
    assert(XD(1) == 10, ...
        sprintf('D9: first X == 10 (ALIGN-03 drop pre-history), got %g', XD(1)));
    assert(sum(isnan(YD)) == 0, ...
        sprintf('D9: No NaN in Y, got %d NaN(s)', sum(isnan(YD))));
    nAsserts = nAsserts + 1;

    TagRegistry.clear();

    %% E. COMPOSITE-06 valueAt fast-path

    sE1 = SensorTag('sE1', 'X', 1:10, 'Y', 1:10);
    sE2 = SensorTag('sE2', 'X', 1:10, 'Y', 1:10);
    mE1 = MonitorTag('mE1', sE1, @(x, y) y > 5);
    mE2 = MonitorTag('mE2', sE2, @(x, y) y > 5);
    cE  = CompositeTag('cE', 'and');
    cE.addChild(mE1);
    cE.addChild(mE2);
    v = cE.valueAt(7);
    assert(v == 1, sprintf('E10: valueAt at t=7 expected 1, got %g', v));
    assert(cE.recomputeCount_ == 0, ...
        sprintf('E10: valueAt must NOT materialize (got recomputeCount_=%d)', ...
            cE.recomputeCount_));
    assert(cE.isDirty(), 'E10: cache must still be dirty after valueAt');
    nAsserts = nAsserts + 1;

    TagRegistry.clear();

    % E11: valueAt matches getXY samples
    sE3 = SensorTag('sE3', 'X', 1:10, 'Y', 1:10);
    mE3 = MonitorTag('mE3', sE3, @(x, y) y > 5);
    cE2 = CompositeTag('cE2', 'and');
    cE2.addChild(mE3);
    [XE, YE] = cE2.getXY();
    assert(cE2.recomputeCount_ == 1, 'E11: getXY must increment recomputeCount_');
    for k = 1:numel(XE)
        vv = cE2.valueAt(XE(k));
        if isnan(YE(k))
            assert(isnan(vv), sprintf( ...
                'E11: valueAt(%.3f) must be NaN', XE(k)));
        else
            assert(vv == YE(k), sprintf( ...
                'E11: valueAt(%.3f) must equal Y(%d)=%g, got %g', ...
                XE(k), k, YE(k), vv));
        end
    end
    nAsserts = nAsserts + 1;

    TagRegistry.clear();

    %% F. Invalidation cascade end-to-end

    sF = SensorTag('sF', 'X', 1:10, 'Y', 1:10);
    mF = MonitorTag('mF', sF, @(x, y) y > 5);
    cF = CompositeTag('cF', 'and');
    cF.addChild(mF);
    cF.getXY();   % warm cache
    assert(~cF.isDirty(), 'F12 pre: cache populated after getXY');
    sF.updateData(11:20, 11:20);
    assert(cF.isDirty(), 'F12: child-update cascades to composite.invalidate');
    nAsserts = nAsserts + 1;

    TagRegistry.clear();

    %% G. Diamond invalidation

    sG   = SensorTag('sG', 'X', 1:10, 'Y', 1:10);
    leaf = MonitorTag('leaf', sG, @(x, y) y > 5);
    midA = CompositeTag('midA', 'and');
    midB = CompositeTag('midB', 'or');
    midA.addChild(leaf);
    midB.addChild(leaf);
    top  = CompositeTag('top', 'and');
    top.addChild(midA);
    top.addChild(midB);
    top.getXY();
    assert(~top.isDirty(), 'G13 pre: top cache populated');
    sG.updateData(11:20, 11:20);
    assert(top.isDirty(), 'G13: diamond invalidation reaches top');
    nAsserts = nAsserts + 1;

    TagRegistry.clear();

    fprintf('    All %d CompositeTag align tests passed.\n', nAsserts);
end

function add_compositetag_align_paths_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    addpath(fullfile(here, 'suite'));
    install();
end
