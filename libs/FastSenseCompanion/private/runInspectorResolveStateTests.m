function runInspectorResolveStateTests()
%RUNINSPECTORRESOLVESTATETESTS Test runner for inspectorResolveState (sibling-folder pattern).
%   Lives inside libs/FastSenseCompanion/private/ so MATLAB's private-folder
%   visibility makes inspectorResolveState reachable. Called by
%   tests/test_companion_inspector_resolve_state.m via add_companion_path().
%
%   Octave-compatible -- uses lightweight stub TagRegistry struct (only .get(key) is invoked).
%   See also inspectorResolveState, InspectorStateEventData, AdHocPlotEventData.

    nPassed = 0;

    % --- Stub registry (only .get(key) is exercised) ---
    tagHandles = struct('k1', struct('Key', 'k1', 'Name', 'Tag One'), ...
                        'k2', struct('Key', 'k2', 'Name', 'Tag Two'));
    stubReg = struct('get', @(k) tagHandles.(k));
    stubDashboard = @(nm) struct('Name', nm);

    % Test 1: welcome with no inputs
    [s, p] = inspectorResolveState('', {}, 0, {}, stubReg);
    assert(strcmp(s, 'welcome'), 'T1: state must be welcome');
    assert(p.nTags == 0, 'T1: nTags must be 0');
    assert(p.nDashboards == 0, 'T1: nDashboards must be 0');
    nPassed = nPassed + 1;

    % Test 2: welcome with dashboards but no tags
    ds = {stubDashboard('A'), stubDashboard('B'), stubDashboard('C')};
    [s, p] = inspectorResolveState('', {}, 0, ds, stubReg);
    assert(strcmp(s, 'welcome'), 'T2: state must be welcome');
    assert(p.nDashboards == 3, 'T2: nDashboards must be 3');
    nPassed = nPassed + 1;

    % Test 3: tag state with 1 key
    [s, p] = inspectorResolveState('tags', {'k1'}, 0, {}, stubReg);
    assert(strcmp(s, 'tag'), 'T3: state must be tag');
    assert(strcmp(p.tag.Key, 'k1'), 'T3: payload.tag must be the resolved Tag handle for k1');
    assert(iscell(p.tagKeys) && numel(p.tagKeys) == 1, 'T3: payload.tagKeys must be 1-element cellstr');
    nPassed = nPassed + 1;

    % Test 4: multitag state with 2 keys
    [s, p] = inspectorResolveState('tags', {'k1','k2'}, 0, {}, stubReg);
    assert(strcmp(s, 'multitag'), 'T4: state must be multitag');
    assert(iscell(p.tags) && numel(p.tags) == 2, 'T4: payload.tags must have 2 entries');
    assert(isequal(p.tagKeys, {'k1','k2'}), 'T4: payload.tagKeys must equal input');
    nPassed = nPassed + 1;

    % Test 5: dashboard state -- lastInteraction='dashboard', idx=2
    [s, p] = inspectorResolveState('dashboard', {}, 2, ds, stubReg);
    assert(strcmp(s, 'dashboard'), 'T5: state must be dashboard');
    assert(strcmp(p.dashboard.Name, 'B'), 'T5: payload.dashboard must be dashboards{2}');
    nPassed = nPassed + 1;

    % Test 6: idx=0 falls back to welcome
    [s, ~] = inspectorResolveState('dashboard', {}, 0, ds, stubReg);
    assert(strcmp(s, 'welcome'), 'T6: idx=0 must fall back to welcome');
    nPassed = nPassed + 1;

    % Test 7: idx > nDashboards falls back to welcome
    [s, ~] = inspectorResolveState('dashboard', {}, 99, ds, stubReg);
    assert(strcmp(s, 'welcome'), 'T7: idx out of range must fall back to welcome');
    nPassed = nPassed + 1;

    % Test 8: 1 tag wins over dashboard click
    [s, ~] = inspectorResolveState('dashboard', {'k1'}, 1, ds, stubReg);
    assert(strcmp(s, 'tag'), 'T8: 1 tag must produce tag state even when LastInteraction=dashboard');
    nPassed = nPassed + 1;

    % Test 9: 2 tags win over dashboard click
    [s, ~] = inspectorResolveState('dashboard', {'k1','k2'}, 1, ds, stubReg);
    assert(strcmp(s, 'multitag'), 'T9: 2 tags must produce multitag state even when LastInteraction=dashboard');
    nPassed = nPassed + 1;

    % Test 10: InspectorStateEventData round-trip
    stubTag = struct('Key', 'k1', 'Name', 'Tag One');
    ed = InspectorStateEventData('tag', struct('tag', stubTag));
    assert(strcmp(ed.State, 'tag'), 'T10: ed.State must be tag');
    assert(strcmp(ed.Payload.tag.Key, 'k1'), 'T10: ed.Payload.tag must be the constructed struct');
    nPassed = nPassed + 1;

    % Test 11: InspectorStateEventData rejects unknown state
    threw = false;
    try
        InspectorStateEventData('bogus', struct());
    catch ME
        threw = strcmp(ME.identifier, 'FastSenseCompanion:invalidEventData');
    end
    assert(threw, 'T11: unknown state must throw FastSenseCompanion:invalidEventData');
    nPassed = nPassed + 1;

    % Test 12: AdHocPlotEventData round-trip
    ed = AdHocPlotEventData({'a','b'}, 'Overlay');
    assert(isequal(ed.TagKeys, {'a','b'}), 'T12: TagKeys round-trip');
    assert(strcmp(ed.Mode, 'Overlay'), 'T12: Mode round-trip');
    nPassed = nPassed + 1;

    % Test 13: AdHocPlotEventData rejects unknown mode
    threw = false;
    try
        AdHocPlotEventData({'a'}, 'Bogus');
    catch ME
        threw = strcmp(ME.identifier, 'FastSenseCompanion:invalidEventData');
    end
    assert(threw, 'T13: unknown mode must throw FastSenseCompanion:invalidEventData');
    nPassed = nPassed + 1;

    fprintf('    All %d tests passed.\n', nPassed);
end
