function add_private_path()
%ADD_PRIVATE_PATH Make private/ functions accessible from tests.
%   On R2020b: addpath('private') works directly.
%   On R2025b+: addpath('private') is rejected, so we add the project
%   root instead — a thin wrapper there (test_private_helper.m) can
%   call private functions on behalf of tests.
%
%   For tests that call private functions directly (binary_search, etc.),
%   R2025b requires using test_private_helper('funcname', args...).
%   Tests that only use class methods (FastPlot, etc.) work on all versions.

    projRoot = fullfile(fileparts(mfilename('fullpath')), '..');
    run(fullfile(projRoot, 'setup.m'));

    privDir = fullfile(projRoot, 'libs', 'FastPlot', 'private');
    w = warning('off', 'all');
    addpath(privDir);
    warning(w);

    % Check if it actually landed on the path
    dirs = strsplit(path, pathsep);
    if ~any(strcmp(dirs, privDir))
        % R2025b+: addpath('private') was rejected.
        % Make private functions available via a temp directory with symlinks.
        tmpDir = fullfile(tempdir, 'fastplot_private_proxy');
        if ~exist(tmpDir, 'dir')
            mkdir(tmpDir);
        end
        % Always sync files to pick up new/changed private functions
        files = dir(fullfile(privDir, '*.m'));
        for i = 1:numel(files)
            src = fullfile(privDir, files(i).name);
            dst = fullfile(tmpDir, files(i).name);
            copyfile(src, dst);
        end
        addpath(tmpDir);
    end
end
