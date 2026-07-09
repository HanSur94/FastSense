function test_function_signatures()
%TEST_FUNCTION_SIGNATURES Validate functionSignatures.json files parse (#332).
%   Ensures the SensorThreshold tab-completion signatures (and its FastSense /
%   Dashboard siblings) are well-formed JSON with the expected schema and that
%   the new Tag-family entries are present.

    repo = fileparts(fileparts(mfilename('fullpath')));
    addpath(repo); install();

    files = { ...
        fullfile(repo, 'libs', 'SensorThreshold', 'functionSignatures.json'), ...
        fullfile(repo, 'libs', 'FastSense',       'functionSignatures.json'), ...
        fullfile(repo, 'libs', 'Dashboard',       'functionSignatures.json')};

    for i = 1:numel(files)
        assert(exist(files{i}, 'file') == 2, ...
            sprintf('test_function_signatures: missing %s', files{i}));
        s = jsondecode(fileread(files{i}));   % throws on malformed JSON
        assert(isfield(s, 'x_schemaVersion'), ...
            sprintf('test_function_signatures: %s missing _schemaVersion', files{i}));
    end

    % SensorThreshold: the new entry must expose the Tag family + factories.
    st = jsondecode(fileread(files{1}));
    expected = {'SensorTag_SensorTag', 'SensorTag_fromCsv', 'StateTag_StateTag', ...
                'StateTag_nameAt', 'MonitorTag_level', 'MonitorTag_band', ...
                'TagRegistry_toStructs', 'Tag_percentile', 'Tag_findPeaks', ...
                'Tag_correlate', 'Tag_removeOutliers', 'Tag_spectrum', ...
                'Tag_compareWindows'};
    fn = fieldnames(st);
    for i = 1:numel(expected)
        assert(any(strcmp(expected{i}, fn)), ...
            sprintf('test_function_signatures: missing entry %s', expected{i}));
    end

    fprintf('    All function-signature JSON files valid (%d SensorThreshold entries).\n', ...
        numel(fn) - 1);
end
