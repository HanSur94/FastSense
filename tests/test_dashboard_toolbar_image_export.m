function test_dashboard_toolbar_image_export()
%TEST_DASHBOARD_TOOLBAR_IMAGE_EXPORT Octave parallel suite for Phase 1004.
%
%   Covers the Octave-safe subset:
%     IMG-02: exportImage PNG
%     IMG-03: exportImage JPEG
%     IMG-04: filename sanitization regex
%     IMG-07: dispatchImageExport cancel no-op
%
%   SKIPPED on Octave (intentional — not a bug):
%     IMG-01: button-present verification. Octave print() excludes uicontrols
%             by default, so visual parity with MATLAB is not guaranteed.
%             The button IS created (uicontrol call is the same) — we just
%             don't re-verify its properties here to keep this suite short.
%     IMG-05/06/08/09: covered by the MATLAB suite; Octave timer semantics
%             differ enough that IMG-09 (live) is best verified under MATLAB.

    add_dashboard_path();

    nPassed = 0;
    nFailed = 0;

    % testExportImagePNG (IMG-02)
    %   Uses NumberWidget (uicontrol-only, no axes) to exercise the
    %   exportImage stub-axes fallback path. Octave's print() refuses to
    %   print a figure without a top-level axes object; the engine adds a
    %   hidden 1px stub axes to satisfy this. MATLAB recurses into uipanels
    %   for axes discovery so the stub is harmless there.
    try
        d = DashboardEngine('OctTest');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');
        tmp = [tempname, '.png'];
        d.exportImage(tmp, 'png');
        assert(exist(tmp, 'file') == 2, ...
            'testExportImagePNG: file should exist');
        info = dir(tmp);
        assert(info.bytes > 0, 'testExportImagePNG: file should be non-empty');
        delete(tmp);
        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testExportImagePNG: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testExportImageJPEG (IMG-03)
    try
        d = DashboardEngine('OctJpeg');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');
        tmp = [tempname, '.jpg'];
        d.exportImage(tmp, 'jpeg');
        assert(exist(tmp, 'file') == 2, ...
            'testExportImageJPEG: file should exist');
        info = dir(tmp);
        assert(info.bytes > 0, 'testExportImageJPEG: file should be non-empty');
        delete(tmp);
        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testExportImageJPEG: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testSanitizeFilename (IMG-04)
    try
        raw = 'My Dash/Board: v1';
        safe = regexprep(raw, '[/\\:*?"<>|\s]', '_');
        assert(strcmp(safe, 'My_Dash_Board__v1'), ...
            sprintf('testSanitizeFilename: got ''%s''', safe));

        % Also verify the defaultImageFilename helper end-to-end
        d = DashboardEngine('My Dash/Board: v1');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');
        fn = d.Toolbar.defaultImageFilename();
        assert(~isempty(regexp(fn, '^My_Dash_Board__v1_\d{8}_\d{6}\.png$', 'once')), ...
            sprintf('testSanitizeFilename: default filename shape: ''%s''', fn));
        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testSanitizeFilename: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testCancelNoOp (IMG-07)
    try
        d = DashboardEngine('OctCancel');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');
        % Bypass uiputfile: dispatchImageExport with file==0 must not throw
        d.Toolbar.dispatchImageExport(0, '', 1);
        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testCancelNoOp: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0
        error('test_dashboard_toolbar_image_export:fail', ...
            '%d of %d tests failed', nFailed, nPassed + nFailed);
    end
end

function add_dashboard_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fullfile(thisDir, '..');
    addpath(repoRoot);
    install();
end
