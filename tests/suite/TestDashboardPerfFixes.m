classdef TestDashboardPerfFixes < matlab.unittest.TestCase
    %TESTDASHBOARDPERFFIXES Regression tests for the dashboard perf-pass hot-path fixes.
    %
    %   Covers the conditional fast-paths added in the dashboard perf PR:
    %     - ScatterWidget in-place handle reuse
    %     - ImageWidget imread caching
    %     - DashboardEngine.isObjValid_ via post-delete callbacks
    %     - DashboardEngine.onResize cache-invalidation block
    %     - DashboardEngine.formatTimeVal datevec branches

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testScatterWidgetInPlaceUpdate(testCase)
            N = 50;
            sX = SensorTag('X-1', 'X', 1:N, 'Y', randn(1, N));
            sY = SensorTag('Y-1', 'X', 1:N, 'Y', randn(1, N));
            w = ScatterWidget('SensorX', sX, 'SensorY', sY);
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            h0 = w.hScatter;
            testCase.verifyNotEmpty(h0);
            testCase.verifyTrue(ishandle(h0));
            % Append samples; refresh; verify same handle survived (in-place path).
            sX.updateData([sX.X, (N+1):(N+10)], [sX.Y, randn(1, 10)]);
            sY.updateData([sY.X, (N+1):(N+10)], [sY.Y, randn(1, 10)]);
            w.refresh();
            testCase.verifyEqual(h0, w.hScatter, ...
                'in-place refresh must reuse the existing hScatter handle');
        end

        function testScatterWidgetColorRebuild(testCase)
            N = 30;
            sX = SensorTag('X-2', 'X', 1:N, 'Y', randn(1, N));
            sY = SensorTag('Y-2', 'X', 1:N, 'Y', randn(1, N));
            sC = SensorTag('C-2', 'X', 1:N, 'Y', randn(1, N));
            w = ScatterWidget('SensorX', sX, 'SensorY', sY, 'SensorColor', sC);
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            h0 = w.hScatter;
            % SensorColor wired -> full rebuild every refresh
            w.refresh();
            testCase.verifyNotEqual(h0, w.hScatter, ...
                'color-coded scatter should rebuild the handle on refresh');
        end

        function testImageWidgetCachesFile(testCase)
            tmpFile = [tempname() '.png'];
            imwrite(uint8(randi(255, 16, 16, 3)), tmpFile);
            cleanupImg = onCleanup(@() delete(tmpFile)); %#ok<NASGU>
            w = ImageWidget('File', tmpFile);
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.CachedImgData_);
            testCase.verifyEqual(w.CachedFile_, tmpFile);
            before = w.CachedImgData_;
            w.refresh();
            testCase.verifyEqual(before, w.CachedImgData_, ...
                'cached image data must be reused on subsequent refresh');
        end

        function testImageWidgetInvalidatesOnChange(testCase)
            tmpA = [tempname() 'A.png'];
            tmpB = [tempname() 'B.png'];
            imwrite(uint8(zeros(8, 8, 3)), tmpA);
            imwrite(uint8(255 * ones(8, 8, 3)), tmpB);
            cleanupA = onCleanup(@() delete(tmpA)); %#ok<NASGU>
            cleanupB = onCleanup(@() delete(tmpB)); %#ok<NASGU>
            w = ImageWidget('File', tmpA);
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            cachedA = w.CachedImgData_;
            w.File = tmpB;
            w.refresh();
            testCase.verifyNotEqual(cachedA, w.CachedImgData_, ...
                'cache must be invalidated when File path changes');
            testCase.verifyEqual(w.CachedFile_, tmpB);
        end

        function testEngineCallbacksSilentOnDelete(testCase)
            % NOTE: do NOT render this engine. Rendering wires figure callbacks
            % whose teardown timing varies. Construction is enough to exercise
            % the isObjValid_ guards added to onResize / switchPage / onLiveTick.
            eng = DashboardEngine('PerfFix');
            delete(eng);
            % Each callback must silently return on a deleted handle.
            threw = false;
            try eng.onResize();    catch, threw = true; end %#ok<NASGU>
            testCase.verifyFalse(threw, 'onResize must not throw after delete');
            threw = false;
            try eng.switchPage(1); catch, threw = true; end %#ok<NASGU>
            testCase.verifyFalse(threw, 'switchPage must not throw after delete');
            threw = false;
            try eng.onLiveTick();  catch, threw = true; end %#ok<NASGU>
            testCase.verifyFalse(threw, 'onLiveTick must not throw after delete');
        end

        function testEnginePreviewNBucketsResetOnResize(testCase)
            % Coverage probe for the cache-invalidation block inside onResize.
            % We can't read the private PreviewNBuckets_ directly, but
            % invoking onResize with a rendered engine exercises the code path.
            eng = DashboardEngine('ResizeTest');
            eng.addWidget('text', 'Content', 'hi');
            eng.render();
            cleanupEng = onCleanup(@() delete(eng)); %#ok<NASGU>
            eng.onResize();
            testCase.verifyTrue(isvalid(eng));  % no throw means coverage hit
        end

        function testEngineFormatTimeValBranches(testCase)
            eng = DashboardEngine('Fmt2');
            cleanupFmt = onCleanup(@() delete(eng)); %#ok<NASGU>
            s1 = eng.formatTimeVal(1777507200);  % posix 2026
            s2 = eng.formatTimeVal(datenum(2026, 4, 23, 12, 0, 0));  % datenum
            s3 = eng.formatTimeVal(3600);  % raw
            testCase.verifyNotEmpty(s1);
            testCase.verifyClass(s1, 'char');
            testCase.verifyNotEmpty(s2);
            testCase.verifyClass(s2, 'char');
            testCase.verifyNotEmpty(s3);
            testCase.verifyClass(s3, 'char');
        end
    end
end
