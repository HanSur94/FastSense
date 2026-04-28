classdef TestDashboardSerializerTagExport < matlab.unittest.TestCase
%TESTDASHBOARDSERIALIZERTAGEXPORT MEXP-01..05 round-trip — DashboardSerializer
%   .m export emits TagRegistry.get('key') for Tag-bound widgets, both
%   single-page (save inline switch + exportScript linesForWidget helper)
%   and multi-page (exportScriptPages); a missing tag triggers
%   DashboardSerializer:tagNotRegistered at script run via try/catch.
%
%   Phase 1014 — see .planning/phases/1014-dashboardserializer-m-export-for-tag-bound-widgets/1014-01-PLAN.md.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function clearRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)

        function singlePageTagWidgetRoundTripsViaSave(testCase)
            % MEXP-01, MEXP-04 — exercises DashboardSerializer.save() inline switch.
            key = 'press_a';
            MakePhase1009Fixtures.makeSensorTag(key);

            d = DashboardEngine('TagRoundTrip');
            d.addWidget('fastsense', 'Title', 'Pressure A', ...
                'Position', [1 1 12 3], 'Tag', TagRegistry.get(key));

            filepath = iMakeTempMPath();
            testCase.addTeardown(@() iSafeDelete(filepath));
            d.save(filepath);

            % File-content assertions: try/catch guard + lookup + error ID present.
            content = fileread(filepath);
            testCase.verifyTrue(~isempty(strfind(content, 'try')), ...
                'Generated .m must contain a try statement');
            testCase.verifyTrue(~isempty(strfind(content, 'TagRegistry.get(')), ...
                'Generated .m must contain TagRegistry.get(...)');
            testCase.verifyTrue(~isempty(strfind(content, 'DashboardSerializer:tagNotRegistered')), ...
                'Generated .m must contain DashboardSerializer:tagNotRegistered error ID');
            % Negative check: must not reference the non-existent .has method.
            testCase.verifyEmpty(strfind(content, 'TagRegistry.has'));

            % Reload — registry already has the tag from fixture.
            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(numel(d2.Widgets), 1);
            w = d2.Widgets{1};
            testCase.verifyNotEmpty(w.Tag);
            testCase.verifyEqual(char(w.Tag.Key), key);
        end

        function singlePageTagWidgetRoundTripsViaExportScript(testCase)
            % MEXP-01, MEXP-04 — exercises the linesForWidget helper on the
            % single-page path (which DashboardSerializer.save() does NOT use).
            key = 'press_x1';
            MakePhase1009Fixtures.makeSensorTag(key);

            d = DashboardEngine('TagExportScriptRT');
            d.addWidget('fastsense', 'Title', 'X1', ...
                'Position', [1 1 12 3], 'Tag', TagRegistry.get(key));

            filepath = iMakeTempMPath();
            testCase.addTeardown(@() iSafeDelete(filepath));

            % Build cfg directly and call exportScript (the linesForWidget path).
            cfg = DashboardSerializer.widgetsToConfig( ...
                d.Name, d.Theme, d.LiveInterval, d.Widgets, d.InfoFile);
            DashboardSerializer.exportScript(cfg, filepath);

            content = fileread(filepath);
            testCase.verifyTrue(~isempty(strfind(content, 'try')), ...
                'exportScript output must contain try');
            testCase.verifyTrue(~isempty(strfind(content, ['TagRegistry.get(''', key, ''')'])), ...
                'exportScript output must contain TagRegistry.get for the bound key');
            testCase.verifyTrue(~isempty(strfind(content, 'DashboardSerializer:tagNotRegistered')), ...
                'exportScript output must contain DashboardSerializer:tagNotRegistered');
            testCase.verifyEmpty(strfind(content, 'TagRegistry.has'));
            % Confirm the addWidget line landed too (linesForWidget shape).
            testCase.verifyTrue(~isempty(strfind(content, 'd.addWidget(''fastsense''')), ...
                'exportScript output must contain a d.addWidget(''fastsense'' call');
        end

        function multiPageTagWidgetsRoundTripViaM(testCase)
            % MEXP-02, MEXP-04 — exercises exportScriptPages via linesForWidget.
            keyA = 'press_a';
            keyB = 'press_b';
            MakePhase1009Fixtures.makeSensorTag(keyA);
            MakePhase1009Fixtures.makeSensorTag(keyB);

            d = DashboardEngine('TagMultiPage');
            d.addPage('PageA');
            d.addPage('PageB');
            d.switchPage(1);
            d.addWidget('fastsense', 'Title', 'A', ...
                'Position', [1 1 12 3], 'Tag', TagRegistry.get(keyA));
            d.switchPage(2);
            d.addWidget('fastsense', 'Title', 'B', ...
                'Position', [1 1 12 3], 'Tag', TagRegistry.get(keyB));

            filepath = iMakeTempMPath();
            testCase.addTeardown(@() iSafeDelete(filepath));
            d.save(filepath);
            % d.save() routes .m + multi-page through exportScriptPages
            % (DashboardEngine.save line 430).

            content = fileread(filepath);
            testCase.verifyTrue(~isempty(strfind(content, ['TagRegistry.get(''', keyA, ''')'])), ...
                'Multi-page output must contain TagRegistry.get for keyA');
            testCase.verifyTrue(~isempty(strfind(content, ['TagRegistry.get(''', keyB, ''')'])), ...
                'Multi-page output must contain TagRegistry.get for keyB');

            d2 = DashboardEngine.load(filepath);
            testCase.verifyNotEmpty(d2.Pages);
            pageAW = d2.Pages{1}.Widgets;
            pageBW = d2.Pages{2}.Widgets;
            testCase.verifyEqual(char(pageAW{1}.Tag.Key), keyA);
            testCase.verifyEqual(char(pageBW{1}.Tag.Key), keyB);
        end

        function unregisteredTagFailsLoudly(testCase)
            % MEXP-03 — the try/catch guard must fire and rethrow with our
            % error ID, not the underlying TagRegistry:unknownKey.
            key = 'press_xy';
            MakePhase1009Fixtures.makeSensorTag(key);

            d = DashboardEngine('TagGuardTest');
            d.addWidget('fastsense', 'Title', 'X', ...
                'Position', [1 1 12 3], 'Tag', TagRegistry.get(key));

            filepath = iMakeTempMPath();
            testCase.addTeardown(@() iSafeDelete(filepath));
            d.save(filepath);

            % Wipe registry so the try/catch guard must error.
            TagRegistry.clear();

            [fdir, funcname, ~] = fileparts(filepath);
            addpath(fdir);
            cleanupPath = onCleanup(@() rmpath(fdir)); %#ok<NASGU>
            testCase.verifyError(@() feval(funcname), ...
                'DashboardSerializer:tagNotRegistered');
        end

    end
end

function p = iMakeTempMPath()
    %IMAKETEMPMPATH Generate a unique .m path with a valid MATLAB function name.
    %   tempname() on some platforms (e.g. macOS Octave) inserts hyphens
    %   that produce invalid MATLAB function identifiers, breaking
    %   DashboardEngine.load(.m). Use a deterministic alphanumeric/underscore
    %   name in tempdir to guarantee feval-ability on every platform.
    %   Microseconds + a per-call counter avoid same-tick collisions.
    persistent counter;
    if isempty(counter), counter = 0; end
    counter = counter + 1;
    suffix = sprintf('%s_%d', datestr(now, 'HHMMSSFFF'), counter);
    p = fullfile(tempdir, ['tag_export_', suffix, '.m']);
end

function iSafeDelete(p)
    %ISAFEDELETE Delete file if present, swallow errors (test teardown).
    try
        if exist(p, 'file') == 2
            delete(p);
        end
    catch
    end
end
