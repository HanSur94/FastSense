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

        function testMultiPageWidgetAddressing(testCase)
        %TESTMULTIPAGEWIDGETADDRESSING P0-1: widget-addressing methods are page-aware.
        %   getWidgetByTitle/setWidgetPosition/markAllDirty/preview must operate on
        %   the active page's widgets, not the (empty) obj.Widgets, once addPage is used.
            d = DashboardEngine('mp');
            d.addPage('P1');
            w = MockDashboardWidget('Title', 'Alpha', 'Position', [1 1 4 2]);
            d.addWidget(w);
            % Widget lives under the page; obj.Widgets stays empty in multi-page mode.
            testCase.verifyEmpty(d.Widgets);
            testCase.verifyEqual(numel(d.Pages{1}.Widgets), 1);

            % getWidgetByTitle finds the page widget (returned [] before P0-1 fix).
            g = d.getWidgetByTitle('Alpha');
            testCase.verifyTrue(~isempty(g) && g == w);

            % setWidgetPosition on a valid index does not throw and moves the widget
            % (threw DashboardEngine:invalidIndex before P0-1 fix).
            threw = false;
            try
                d.setWidgetPosition(1, [3 3 4 2]);
            catch
                threw = true;
            end
            testCase.verifyFalse(threw);
            testCase.verifyEqual(w.Position(1), 3);

            % markAllDirty flags the page widget (was a no-op before P0-1 fix).
            w.Dirty = false;
            d.markAllDirty();
            testCase.verifyTrue(w.Dirty);

            % preview reports the widget instead of "(empty)" (printed empty before fix).
            out = evalc('d.preview(''Width'', 120)');
            testCase.verifyFalse(contains(out, 'empty -- no widgets'));
            testCase.verifyTrue(contains(out, '1 widgets'));
        end

        function testSinglePageWidgetAddressingUnchanged(testCase)
        %TESTSINGLEPAGEWIDGETADDRESSINGUNCHANGED P0-1 regression: single-page path intact.
            d = DashboardEngine('sp');
            w = MockDashboardWidget('Title', 'Solo', 'Position', [1 1 4 2]);
            d.addWidget(w);
            testCase.verifyEqual(numel(d.Widgets), 1);
            g = d.getWidgetByTitle('Solo');
            testCase.verifyTrue(~isempty(g) && g == w);
            threw = false;
            try
                d.setWidgetPosition(1, [2 2 4 2]);
            catch
                threw = true;
            end
            testCase.verifyFalse(threw);
            testCase.verifyEqual(w.Position(1), 2);
            w.Dirty = false;
            d.markAllDirty();
            testCase.verifyTrue(w.Dirty);
        end

        function testRemovePageDropsPage(testCase)
        %TESTREMOVEPAGEDROPSPAGE removePage drops the page and keeps the rest.
            d = DashboardEngine('mp');
            d.addPage('P1'); d.addPage('P2'); d.addPage('P3');
            testCase.verifyEqual(numel(d.Pages), 3);
            d.removePage(2);
            testCase.verifyEqual(numel(d.Pages), 2);
            testCase.verifyEqual(d.Pages{1}.Name, 'P1');
            testCase.verifyEqual(d.Pages{2}.Name, 'P3');
        end

        function testRemovePageBeforeActiveKeepsActive(testCase)
        %TESTREMOVEPAGEBEFOREACTIVEKEEPSACTIVE Removing a page before ActivePage keeps the same page active.
            d = DashboardEngine('mp');
            d.addPage('P1'); d.addPage('P2'); d.addPage('P3');
            d.switchPage(3);
            testCase.verifyEqual(d.ActivePage, 3);
            d.removePage(1);
            testCase.verifyEqual(numel(d.Pages), 2);
            testCase.verifyEqual(d.Pages{d.ActivePage}.Name, 'P3');
        end

        function testRemoveActivePageClampsActive(testCase)
        %TESTREMOVEACTIVEPAGECLAMPSACTIVE Removing the active (last) page leaves ActivePage valid.
            d = DashboardEngine('mp');
            d.addPage('P1'); d.addPage('P2');
            d.switchPage(2);
            d.removePage(2);
            testCase.verifyEqual(numel(d.Pages), 1);
            testCase.verifyTrue(d.ActivePage >= 1 && d.ActivePage <= numel(d.Pages));
        end

        function testRemoveLastRemainingPage(testCase)
        %TESTREMOVELASTREMAININGPAGE Removing the only page resets ActivePage to 0.
            d = DashboardEngine('mp');
            d.addPage('P1');
            d.removePage(1);
            testCase.verifyEmpty(d.Pages);
            testCase.verifyEqual(d.ActivePage, 0);
        end

        function testRemovePageInvalidIndexErrors(testCase)
        %TESTREMOVEPAGEINVALIDINDEXERRORS Out-of-range index errors with a namespaced id.
            d = DashboardEngine('mp');
            d.addPage('P1');
            testCase.verifyError(@() d.removePage(99), 'DashboardEngine:invalidIndex');
        end

    end

end

function deleteFile(f)
    if exist(f, 'file')
        delete(f);
    end
end
