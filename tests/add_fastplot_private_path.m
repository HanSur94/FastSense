function add_fastplot_private_path()
%ADD_FASTPLOT_PRIVATE_PATH Make libs/FastPlot/private/ functions accessible from tests.
%   On R2025b+, addpath('private') is rejected, so we copy files to a
%   temp directory proxy.

    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    privDir = fullfile(repo_root, 'libs', 'FastPlot', 'private');

    w = warning('off', 'all');
    addpath(privDir);
    warning(w);

    % Check if it actually landed on the path
    dirs = strsplit(path, pathsep);
    if ~any(strcmp(dirs, privDir))
        % R2025b+: addpath('private') was rejected.
        % Make private functions available via a temp directory with copies.
        tmpDir = fullfile(tempdir, 'fastplot_private_proxy');
        if ~exist(tmpDir, 'dir')
            mkdir(tmpDir);
        end
        files = dir(fullfile(privDir, '*.m'));
        for i = 1:numel(files)
            src = fullfile(privDir, files(i).name);
            dst = fullfile(tmpDir, files(i).name);
            copyfile(src, dst);
        end
        addpath(tmpDir);
    end
end
