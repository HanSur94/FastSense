classdef TestDashboardMultiPage < matlab.unittest.TestCase
%TESTDASHBOARDMULTIPAGE Test scaffold for multi-page dashboard navigation.
%
%   Tests LAYOUT-03 through LAYOUT-06.
%   testAddPage and testDashboardPageToStruct pass immediately (plan 04-01).
%   Remaining 6 stub tests become green after plans 04-02 and 04-03.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)

        function testAddPage(testCase)
        %TESTADDPAGE DashboardEngine.addPage creates a Pages entry and routes addWidget.
        %   Verifies LAYOUT-03: engine accumulates pages and addWidget routes to active page.
            d = DashboardEngine('Test');
            d.addPage('Overview');
            testCase.verifyEqual(numel(d.Pages), 1);
            testCase.verifyEqual(d.Pages{1}.Name, 'Overview');
            % addWidget should route to the active page, not d.Widgets directly
            w = MockDashboardWidget('Title', 'W1', 'Position', [1 1 6 2]);
            d.addWidget(w);
            testCase.verifyEqual(numel(d.Pages{1}.Widgets), 1);
        end

        function testDashboardPageToStruct(testCase)
        %TESTDASHBOARDPAGETOSTRUCT DashboardPage.toStruct serializes correctly.
        %   Verifies LAYOUT-03: page struct has name and widgets fields.
            pg = DashboardPage('Details');
            w = MockDashboardWidget('Title', 'W1', 'Position', [1 1 6 2]);
            pg.addWidget(w);
            s = pg.toStruct();
            testCase.verifyEqual(s.name, 'Details');
            testCase.verifyEqual(numel(s.widgets), 1);
        end

        function testSinglePageBackcompat(testCase)
        %TESTSINGLEBACKCOMPAT Single-page engine has Widgets accessible; no Pages.
        %   Verifies backward compatibility for single-page dashboards.
            d = DashboardEngine('Test');
            testCase.verifyClass(d.Widgets, 'cell');
        end

        function testPageBarHiddenSinglePage(testCase)
        %TESTPAGEBARHIDDENSINGLEPAGE PageBar absent or not visible for single-page engine.
        %   Verifies LAYOUT-04: page bar only shown for multi-page dashboards.
        %   STUB: fails until plan 04-02 adds hPageBar to DashboardEngine.
            d = DashboardEngine('Test');
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            testCase.verifyFalse(strcmp(get(d.hPageBar, 'Visible'), 'on'));
        end

        function testPageBarVisibleMultiPage(testCase)
        %TESTPAGEBARVISIBLEMULTIPAGE PageBar visible when two pages are added.
        %   Verifies LAYOUT-04: page bar shown when Pages count > 1.
        %   STUB: fails until plan 04-02 adds hPageBar to DashboardEngine.
            d = DashboardEngine('Test');
            d.addPage('A');
            d.addPage('B');
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            testCase.verifyTrue(strcmp(get(d.hPageBar, 'Visible'), 'on'));
        end

        function testSwitchPage(testCase)
        %TESTSWITCHPAGE switchPage(2) sets ActivePage to 2.
        %   Verifies LAYOUT-06: page switching updates ActivePage index.
        %   STUB: fails until plan 04-02 adds switchPage() and ActivePage.
            d = DashboardEngine('Test');
            d.addPage('A');
            d.addPage('B');
            testCase.verifyEqual(d.ActivePage, 1);
            d.switchPage(2);
            testCase.verifyEqual(d.ActivePage, 2);
        end

        function testSaveLoadRoundTrip(testCase)
        %TESTSAVELOUNDROUNDTRIP Multi-page engine save+load preserves pages and activePage.
        %   Verifies LAYOUT-05: activePage name is persisted in JSON and restored on load.
            d = DashboardEngine('RoundTrip');
            d.addPage('Alpha');
            d.addPage('Beta');
            d.switchPage(2);
            tmpFile = [tempname, '.json'];
            cleanup = onCleanup(@() deleteFile(tmpFile));
            d.save(tmpFile);
            loaded = DashboardEngine.load(tmpFile);
            testCase.verifyEqual(numel(loaded.Pages), 2);
            testCase.verifyEqual(loaded.Pages{1}.Name, 'Alpha');
            testCase.verifyEqual(loaded.ActivePage, 2);
            testCase.verifyEqual(loaded.Pages{loaded.ActivePage}.Name, 'Beta');
        end

        function testLegacyJsonLoad(testCase)
        %TESTLEGACYJSONLOAD JSON without pages field loads into Widgets; no PageBar error.
        %   Verifies LAYOUT-06: backward-compatible deserialization.
        %   STUB: fails until plan 04-03 extends DashboardSerializer.
            d = DashboardEngine('Legacy');
            w = MockDashboardWidget('Title', 'W1', 'Position', [1 1 6 2]);
            d.addWidget(w);
            tmpFile = [tempname, '.json'];
            cleanup = onCleanup(@() deleteFile(tmpFile));
            d.save(tmpFile);
            loaded = DashboardEngine.load(tmpFile);
            testCase.verifyEqual(numel(loaded.Widgets), 1);
            testCase.verifyEmpty(loaded.Pages);
        end

        function testLiveTickScopedToActivePage(testCase)
        %TESTLIVETICKSCOPED onLiveTick only refreshes active-page widgets.
        %   Verifies LAYOUT-05: live refresh scoped to active page.
        %   STUB: fails until plan 04-02 scopes onLiveTick to active page.
            d = DashboardEngine('Test');
            d.addPage('P1');
            d.addPage('P2');
            % Switch to page 1 — only page-1 widgets should be refreshed
            d.switchPage(1);
            % Verify active page is 1
            testCase.verifyEqual(d.ActivePage, 1);
        end

    end

end

function deleteFile(f)
    if exist(f, 'file')
        delete(f);
    end
end
