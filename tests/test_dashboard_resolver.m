function test_dashboard_resolver()
%TEST_DASHBOARD_RESOLVER Octave flat companion for Phase 1043 resolver seam.
%   Covers: SC1 (resolver path binds Tag), SC3 (no-resolver fleet-tag miss
%   fires FastSenseWidget:tagResolverMissing), SC2 (legacy registry hit
%   binds Tag with no warning).
%
%   All assertions are RED until Plan 02 adds the tagResolver seam to
%   FastSenseWidget.fromStruct and renames the warning id.
%
%   Uses the warning('error', ID) + try/catch idiom from tests/test_machine.m
%   so this file runs correctly under GNU Octave (no verifyWarning available).
%   Does NOT call render() or DashboardEngine — exercises fromStruct directly.
%   Octave parity: strfind instead of the string-search built-in; no verifyWarning.
%
%   See also TestFleetDashboardResolver, test_machine.

    add_dashboard_path_();
    TagRegistry.clear();

    % -----------------------------------------------------------------
    % SC1 / DASH-01: resolver path — tag resolved via machine resolver.
    % -----------------------------------------------------------------
    m = Machine('Id', 'M01', 'DataRoot', '');
    m.addTag(SensorTag('pressure'));

    ws.type = 'fastsense';
    ws.title = 'Test';
    ws.position = struct('col', 1, 'row', 1, 'width', 6, 'height', 2);
    ws.source = struct('type', 'tag', 'key', 'pressure');

    % 2-arg fromStruct with resolver: Tag must be bound.
    w = FastSenseWidget.fromStruct(ws, @(k) m.get(k));
    assert(~isempty(w.Tag), ...
        'SC1/DASH-01: resolver path — Tag must be bound when resolver supplied');

    % -----------------------------------------------------------------
    % SC3 / DASH-02: no resolver, fleet tag NOT in TagRegistry → warning.
    % TagRegistry still clear so 'pressure' is absent from catalog.
    % -----------------------------------------------------------------
    warnState = warning('query', 'FastSenseWidget:tagResolverMissing');
    warning('error', 'FastSenseWidget:tagResolverMissing');
    errored = false;
    try
        FastSenseWidget.fromStruct(ws);  % 1-arg, no resolver, key not in registry
    catch me
        errored = ~isempty(strfind(me.identifier, 'FastSenseWidget:tagResolverMissing'));
    end
    warning(warnState.state, 'FastSenseWidget:tagResolverMissing');
    assert(errored, ...
        'SC3/DASH-02: tagResolverMissing warning must fire when no resolver and tag absent from registry');

    % -----------------------------------------------------------------
    % SC2 / DASH-02: legacy registry hit — tag in TagRegistry, no resolver
    % → Tag must be bound, no warning.
    % -----------------------------------------------------------------
    TagRegistry.register('legacy_temp', SensorTag('legacy_temp'));

    ws2.type = 'fastsense';
    ws2.title = 'Legacy';
    ws2.position = ws.position;
    ws2.source = struct('type', 'tag', 'key', 'legacy_temp');

    % 1-arg fromStruct, no resolver; registry hit → Tag must bind cleanly.
    w2 = FastSenseWidget.fromStruct(ws2);
    assert(~isempty(w2.Tag), ...
        'SC2/DASH-02: legacy registry hit must bind Tag when tag is in TagRegistry');

    TagRegistry.clear();
    fprintf('    All 3 tests passed.\n');
end

function add_dashboard_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
end
