function test_plant_log_hash()
%TEST_PLANT_LOG_HASH Tests for hash helpers via PlantLogEntry.RowHash.
%   Hash helpers (djb2Hash, computeRowHash) live under libs/PlantLog/private/
%   and are not callable directly from tests/. Coverage is via
%   PlantLogEntry construction with controlled inputs.
    add_plant_log_path();

    % testHashDeterminism
    md1 = struct('A', 1, 'B', 'x');
    e1 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md1);
    e2 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md1);
    assert(strcmp(e1.RowHash, e2.RowHash), 'determinism: identical inputs -> identical hash');

    % testHashSortStability
    md2 = struct('A', 1, 'B', 'x');
    md3 = struct('B', 'x', 'A', 1);
    e3 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md2);
    e4 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md3);
    assert(strcmp(e3.RowHash, e4.RowHash), ...
        'sort-stability: metadata field order does not change hash');

    % testHashSensitivityMessage
    e5 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md1);
    e6 = PlantLogEntry('Timestamp', 1, 'Message', 'world', 'Metadata', md1);
    assert(~strcmp(e5.RowHash, e6.RowHash), 'sensitivity: Message change -> different hash');

    % testHashSensitivityMetadata
    md4 = struct('A', 2, 'B', 'x');  % only A changes
    e7 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md1);
    e8 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md4);
    assert(~strcmp(e7.RowHash, e8.RowHash), 'sensitivity: Metadata change -> different hash');

    % testHashShape
    e9 = PlantLogEntry('Timestamp', 1, 'Message', 'hello', 'Metadata', md1);
    assert(numel(e9.RowHash) == 16, 'shape: hash length 16');
    assert(~isempty(regexp(e9.RowHash, '^[0-9a-f]{16}$', 'once')), ...
        'shape: hash is lowercase 16-char hex');

    % testHashEmptyInput - djb2 seed = 5381 = 0x1505 -> padded to 16 chars
    eEmpty = PlantLogEntry('Timestamp', 1, 'Message', '', 'Metadata', struct());
    assert(strcmp(eEmpty.RowHash, '0000000000001505'), ...
        'empty: hash of empty Message + empty Metadata is djb2 seed in hex');

    fprintf('    All 6 plant_log_hash tests passed.\n');
end

function add_plant_log_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
    addpath(fullfile(repo_root, 'libs', 'PlantLog'));
end
