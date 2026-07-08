function test_eventviewer_exportimage()
%TEST_EVENTVIEWER_EXPORTIMAGE Headless test for EventViewer.exportImage (#321).
%   Verifies PNG/JPEG export writes a non-empty file, format inference from
%   the extension, and the notRendered / unknownImageFormat guards.
%
%   Runs headless (object + file IO, not visual inspection). Skipped on
%   Octave (classdef/figure limitation, matching test_event_viewer).
%
%   Run via the matlab MCP: install(); test_eventviewer_exportimage()

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (known Octave classdef limitation)\n');
        return;
    end

    add_event_path_();
    nTests = 0;

    e1 = Event(10, 25, 'Temperature', 'warning high', 80, 'upper');
    e1.setStats(95.2, 150, 72, 95.2, 87.3, 88.1, 4.21);
    e2 = Event(50, 55, 'Pressure', 'low alarm', 5, 'lower');
    e2.setStats(2.1, 50, 2.1, 6.8, 4.5, 4.7, 1.2);
    events = [e1, e2];

    % --- PNG export writes a non-empty file (explicit format) -------------
    v = EventViewer(events);
    pngPath = [tempname, '.png'];
    cleanupPng = onCleanup(@() removeIfExists_(pngPath));
    v.exportImage(pngPath, 'png');
    assert(exist(pngPath, 'file') == 2, 'png file created');            nTests = nTests + 1;
    d = dir(pngPath);
    assert(d.bytes > 0, 'png file non-empty');                          nTests = nTests + 1;
    close(v.hFigure);

    % --- JPEG export via extension inference (no format arg) ---------------
    v2 = EventViewer(events);
    jpgPath = [tempname, '.jpg'];
    cleanupJpg = onCleanup(@() removeIfExists_(jpgPath));
    v2.exportImage(jpgPath);
    assert(exist(jpgPath, 'file') == 2, 'jpg file created (inferred)');  nTests = nTests + 1;
    dj = dir(jpgPath);
    assert(dj.bytes > 0, 'jpg file non-empty');                         nTests = nTests + 1;
    close(v2.hFigure);

    % --- Unknown format guard ---------------------------------------------
    v3 = EventViewer(events);
    threw = false;
    try
        v3.exportImage([tempname, '.png'], 'gif');
    catch err
        threw = strcmp(err.identifier, 'EventViewer:unknownImageFormat');
    end
    assert(threw, 'unknown format rejected');                            nTests = nTests + 1;
    close(v3.hFigure);

    % --- notRendered guard (figure closed) --------------------------------
    v4 = EventViewer(events);
    close(v4.hFigure);
    threw = false;
    try
        v4.exportImage([tempname, '.png']);
    catch err
        threw = strcmp(err.identifier, 'EventViewer:notRendered');
    end
    assert(threw, 'notRendered rejected after close');                   nTests = nTests + 1;

    fprintf('    All %d tests passed.\n', nTests);
end

function removeIfExists_(p)
    if exist(p, 'file') == 2
        delete(p);
    end
end

function add_event_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    addpath(fullfile(here, 'suite'));
    install();
end
