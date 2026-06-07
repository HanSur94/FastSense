function test_machine()
%TEST_MACHINE Octave flat-style coverage for Machine (FLEET-02/FLEET-03 critical paths).
%   Covers: tag isolation (TagRegistry.find == empty after 2 machines addTag),
%           duplicate key on one machine raises Machine:duplicateKey,
%           tagSource_ default path (FLEET-03): BatchTagPipeline with no 'TagSource'
%           arg constructs without error (proves single-machine default preserved).
%
%   All tests are RED until Plan 03 delivers libs/Fleet/Machine.m.
%   Uses SensorTag (Octave-safe) for catalog content; no suite-only mocks.
%
%   See also TestMachine, test_fleet.

    add_fleet_path_();
    TagRegistry.clear();

    % --- FLEET-02: two machines with same local key; TagRegistry stays empty ---
    m1 = Machine('Id', 'M01', 'DataRoot', tempdir());
    m1.addTag(SensorTag('temperature'));
    m2 = Machine('Id', 'M02', 'DataRoot', tempdir());
    m2.addTag(SensorTag('temperature'));
    result = TagRegistry.find(@(t) true);
    assert(isempty(result), ...
        'test_machine: TagRegistry must be empty after machine.addTag (FLEET-02)');

    % --- duplicate key on one machine hard-errors ---
    ok = false;
    try
        m1.addTag(SensorTag('temperature'));
    catch me
        ok = ~isempty(strfind(me.identifier, 'Machine:duplicateKey'));
    end
    assert(ok, 'test_machine: duplicateKey error (Machine:duplicateKey expected)');

    TagRegistry.clear();

    % --- FLEET-03: tagSource_ default path ---
    % Construct BatchTagPipeline with NO 'TagSource' arg; must not throw.
    % This proves that the single-machine default (@TagRegistry.find) is preserved
    % after the DI seam is added in Plan 02.
    tmp = tempname();
    if exist(tmp, 'dir') ~= 7; mkdir(tmp); end
    p = BatchTagPipeline('OutputDir', tmp);
    assert(~isempty(p), 'test_machine: BatchTagPipeline(OutputDir,tmp) must construct ok');

    TagRegistry.clear();
    fprintf('    All 3 tests passed.\n');
end

function add_fleet_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
end
