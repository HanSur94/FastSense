function add_fastsense_private_path()
%ADD_FASTSENSE_PRIVATE_PATH Make libs/FastSense/private/ functions accessible from tests.
%   On R2025b+, addpath('private') is rejected, so we copy files to a
%   temp directory proxy.

    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    privDir = fullfile(repo_root, 'libs', 'FastSense', 'private');

    w = warning('off', 'all');
    addpath(privDir);
    warning(w);

    % Check if it actually landed on the path
    dirs = strsplit(path, pathsep);
    if ~any(strcmp(dirs, privDir))
        % R2025b+: addpath('private') was rejected.
        % Make private functions available via a temp directory with copies.
        tmpDir = fullfile(tempdir, 'fastsense_private_proxy');
        if ~exist(tmpDir, 'dir')
            mkdir(tmpDir);
        end
        exts = {'*.m', '*.mex', '*.mexmaci64', '*.mexmaca64', '*.mexa64'};
        for e = 1:numel(exts)
            files = dir(fullfile(privDir, exts{e}));
            for i = 1:numel(files)
                src = fullfile(privDir, files(i).name);
                dst = fullfile(tmpDir, files(i).name);
                copyfile(src, dst);
            end
        end
        addpath(tmpDir);
    end
end
