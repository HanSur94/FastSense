function test_function_signatures()
%TEST_FUNCTION_SIGNATURES Validate functionSignatures.json files parse (#332).
%   Ensures the SensorThreshold tab-completion signatures (and its FastSense /
%   Dashboard siblings) are well-formed JSON and that the new Tag-family entries
%   are present. Field-name checks use the raw JSON text (not jsondecode field
%   names) because MATLAB and Octave mangle keys like "_schemaVersion" and
%   "Class.method" differently.

    repo = fileparts(fileparts(mfilename('fullpath')));
    addpath(repo); install();

    files = { ...
        fullfile(repo, 'libs', 'SensorThreshold', 'functionSignatures.json'), ...
        fullfile(repo, 'libs', 'FastSense',       'functionSignatures.json'), ...
        fullfile(repo, 'libs', 'Dashboard',       'functionSignatures.json')};

    for i = 1:numel(files)
        assert(exist(files{i}, 'file') == 2, ...
            sprintf('test_function_signatures: missing %s', files{i}));
        raw = fileread(files{i});
        s = jsondecode(raw);                     % throws on malformed JSON
        assert(isstruct(s) && ~isempty(fieldnames(s)), ...
            sprintf('test_function_signatures: %s decoded to an empty struct', files{i}));
        assert(~isempty(strfind(raw, '_schemaVersion')), ...
            sprintf('test_function_signatures: %s missing _schemaVersion', files{i})); %#ok<STREMP>
    end

    % SensorThreshold: the new entry must expose the Tag family + factories.
    raw = fileread(files{1});
    expected = {'"SensorTag.SensorTag"', '"SensorTag.fromCsv"', '"StateTag.StateTag"', ...
                '"StateTag.nameAt"', '"MonitorTag.level"', '"MonitorTag.band"', ...
                '"TagRegistry.toStructs"', '"Tag.percentile"', '"Tag.findPeaks"', ...
                '"Tag.correlate"', '"Tag.removeOutliers"', '"Tag.spectrum"', ...
                '"Tag.compareWindows"'};
    for i = 1:numel(expected)
        assert(~isempty(strfind(raw, expected{i})), ...
            sprintf('test_function_signatures: missing entry %s', expected{i})); %#ok<STREMP>
    end

    fprintf('    All function-signature JSON files valid.\n');
end
