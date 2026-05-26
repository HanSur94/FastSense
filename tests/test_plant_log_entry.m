function test_plant_log_entry()
%TEST_PLANT_LOG_ENTRY Function-style tests for PlantLogEntry value class.
%   Octave-compatible mirror of tests/suite/TestPlantLogEntry.m.
    add_plant_log_path();

    % testConstructorFromStruct
    s = struct('Timestamp', 736000, ...
               'Message', 'Pump A started', ...
               'Metadata', struct('MachineId', 'M1'), ...
               'SourceFile', 'log.csv');
    e = PlantLogEntry(s);
    assert(e.Timestamp == 736000, 'struct: Timestamp');
    assert(strcmp(e.Message, 'Pump A started'), 'struct: Message');
    assert(strcmp(e.Metadata.MachineId, 'M1'), 'struct: Metadata.MachineId');
    assert(strcmp(e.SourceFile, 'log.csv'), 'struct: SourceFile');
    assert(strcmp(e.Id, ''), 'struct: Id default empty');
    assert(~isempty(e.RowHash) && numel(e.RowHash) == 16, 'struct: RowHash 16 chars');

    % testConstructorNameValue
    e2 = PlantLogEntry('Timestamp', 736000, ...
                       'Message', 'Pump A started', ...
                       'Metadata', struct('MachineId', 'M1'), ...
                       'SourceFile', 'log.csv');
    assert(strcmp(e.RowHash, e2.RowHash), 'name-value vs struct: same RowHash');
    assert(strcmp(e.Message, e2.Message), 'name-value vs struct: same Message');

    % testConstructorPartialDefaults
    e3 = PlantLogEntry('Timestamp', 1, 'Message', 'hi', 'Metadata', struct());
    assert(strcmp(e3.SourceFile, ''), 'partial: SourceFile defaults to empty');
    assert(strcmp(e3.Id, ''), 'partial: Id defaults to empty');

    % testRowHashExplicit
    e4 = PlantLogEntry('Timestamp', 1, 'Message', 'hi', 'Metadata', struct(), ...
                       'RowHash', 'aaaaaaaaaaaaaaaa');
    assert(strcmp(e4.RowHash, 'aaaaaaaaaaaaaaaa'), 'explicit RowHash retained');

    % testImmutability
    threw = false;
    try
        e3.Timestamp = 42;
    catch
        threw = true;
    end
    assert(threw, 'immutability: SetAccess private blocks external write');

    % testInvalidTimestampNaN
    threw = false;
    try
        PlantLogEntry('Timestamp', NaN, 'Message', 'x', 'Metadata', struct());
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogEntry:invalidInput'), 'NaN: correct error id');
    end
    assert(threw, 'NaN timestamp: should throw');

    % testInvalidTimestampNonNumeric
    threw = false;
    try
        PlantLogEntry('Timestamp', 'not-a-number', 'Message', 'x', 'Metadata', struct());
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogEntry:invalidInput'), 'non-numeric ts: correct error id');
    end
    assert(threw, 'non-numeric timestamp: should throw');

    % testInvalidMessage
    threw = false;
    try
        PlantLogEntry('Timestamp', 1, 'Message', 42, 'Metadata', struct());
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogEntry:typeMismatch'), 'numeric msg: correct error id');
    end
    assert(threw, 'numeric message: should throw');

    % testInvalidMetadata
    threw = false;
    try
        PlantLogEntry('Timestamp', 1, 'Message', 'x', 'Metadata', 'not-a-struct');
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogEntry:typeMismatch'), 'bad metadata: correct error id');
    end
    assert(threw, 'non-struct metadata: should throw');

    % testUnknownOption
    threw = false;
    try
        PlantLogEntry('Timestamp', 1, 'Message', 'x', 'Metadata', struct(), 'Bogus', 5);
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'PlantLogEntry:unknownOption'), 'unknown opt: correct error id');
    end
    assert(threw, 'unknown option: should throw');

    % testWithId
    e5 = e.withId('plog_42');
    assert(strcmp(e5.Id, 'plog_42'), 'withId: new copy has new id');
    assert(strcmp(e.Id, ''), 'withId: original unchanged');

    fprintf('    All 11 plant_log_entry tests passed.\n');
end

function add_plant_log_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
    % Plan 03 wires libs/PlantLog/ into install.m; until then, addpath here.
    addpath(fullfile(repo_root, 'libs', 'PlantLog'));
end
