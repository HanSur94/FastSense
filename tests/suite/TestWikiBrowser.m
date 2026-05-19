classdef TestWikiBrowser < matlab.unittest.TestCase
%TESTWIKIBROWSER Class-based UI tests for libs/Help/WikiBrowser.m (Phase 1034 Plan 05).
%
%   Exercises the constructor, navigation, history, cross-doc link
%   rewrite, theme switch, and close idempotency of the non-modal Wiki
%   Browser uifigure built in Plan 04. The pure-logic layer (WikiPageIndex)
%   is exercised headless by tests/test_wiki_page_index.m; THIS file
%   targets the uihtml + uifigure UI orchestrator on the MATLAB desktop.
%
%   Headless / Octave: skipped via assumeTrue(usejava('desktop')) +
%   Octave guard. UI assertions exercise constructor argument validation,
%   navigation, history, cross-doc link rewrite, theme switch, and close
%   idempotency.
%
%   The cross-doc rewrite test uses the same uihtml-locator idiom that
%   TestDashboardInfo.testShowInfoOpensModalFigure and the production
%   DashboardEngine.showInfoModal_ rely on
%   (findobj(parent, '-depth', 1, 'Type', 'uihtml')), with a deep
%   findobj walk fallback because the uihtml sits several layers deep
%   inside the body grid.
%
%   See also WikiBrowser, WikiPageIndex, TestFastSenseCompanion,
%   test_wiki_page_index, TestDashboardInfo.

    properties (Access = private)
        Wiki     = []   % WikiBrowser instance under test (cleared each method)
        WikiDir_ = ''   % absolute path to <repo>/wiki
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            %ADDPATHS One-shot setup — gate on Octave + headless before
            %   touching addpath/install, then resolve the project's wiki/
            %   directory so individual tests can stay terse.
            if exist('OCTAVE_VERSION', 'builtin') ~= 0
                testCase.assumeFail('TestWikiBrowser: skipped on Octave (uifigure not available)');
                return;
            end
            testCase.assumeTrue(usejava('desktop'), ...
                'TestWikiBrowser: skipped headless — uifigure + uihtml require MATLAB desktop');

            here = fileparts(mfilename('fullpath'));                % tests/suite
            addpath(fullfile(here, '..', '..'));                    % repo root
            install();

            % <repo>/wiki — here is tests/suite, parent twice gets repo root.
            testCase.WikiDir_ = fullfile(fileparts(fileparts(here)), 'wiki');
            assert(isfolder(testCase.WikiDir_), ...
                'TestWikiBrowser: wiki/ not found at %s', testCase.WikiDir_);
        end
    end

    methods (TestMethodTeardown)
        function closeAnyOpenWiki(testCase)
            %CLOSEANYOPENWIKI Aggressive teardown — close the WikiBrowser
            %   the test opened, then sweep any stray WikiBrowserRoot
            %   uifigure so test ordering is irrelevant.
            try
                if ~isempty(testCase.Wiki) && isvalid(testCase.Wiki)
                    testCase.Wiki.close();
                    delete(testCase.Wiki);
                end
            catch
                % Best-effort cleanup; swallow.
            end
            testCase.Wiki = [];

            % Belt-and-braces: kill any stray uifigure with the magic Tag.
            hs = findall(0, 'Type', 'figure', 'Tag', 'WikiBrowserRoot');
            for k = 1:numel(hs)
                try
                    set(hs(k), 'CloseRequestFcn', '');
                    delete(hs(k));
                catch
                    % Figure may already be in mid-destruction.
                end
            end
        end
    end

    methods (Test)

        % ---- Constructor / argument validation ----

        function testConstructorOpensFigure(testCase)
            %TESTCONSTRUCTOROPENSFIGURE Defaults open IsOpen=true with a
            %   non-modal Tag='WikiBrowserRoot' uifigure on Home.
            testCase.Wiki = WikiBrowser('OpenTo', 'Home', ...
                'WikiDir', testCase.WikiDir_);
            testCase.verifyTrue(testCase.Wiki.IsOpen, ...
                'expected IsOpen=true on MATLAB desktop');
            testCase.verifyEqual(testCase.Wiki.CurrentPage, 'Home');

            hFig = findall(0, 'Type', 'figure', 'Tag', 'WikiBrowserRoot');
            testCase.verifyNotEmpty(hFig, 'expected a WikiBrowserRoot figure');
            testCase.verifyEqual(hFig(1).WindowStyle, 'normal', ...
                'WikiBrowser must be non-modal');
        end

        function testConstructorUnknownOptionThrows(testCase)
            %TESTCONSTRUCTORUNKNOWNOPTIONTHROWS Unknown NV key surfaces a
            %   namespaced WikiBrowser:unknownOption error.
            testCase.verifyError( ...
                @() WikiBrowser('Bogus', 1, 'WikiDir', testCase.WikiDir_), ...
                'WikiBrowser:unknownOption');
        end

        function testConstructorOddArgsThrows(testCase)
            %TESTCONSTRUCTORODDARGSTHROWS A single positional arg violates
            %   the NV-pair contract.
            testCase.verifyError( ...
                @() WikiBrowser('OpenTo'), ...
                'WikiBrowser:invalidArgs');
        end

        % ---- navigateTo + history ----

        function testNavigateToSetsCurrentPage(testCase)
            %TESTNAVIGATETOSETSCURRENTPAGE Known page updates CurrentPage.
            testCase.Wiki = WikiBrowser('OpenTo', 'Home', ...
                'WikiDir', testCase.WikiDir_);
            testCase.Wiki.navigateTo('Companion-Overview');
            testCase.verifyEqual(testCase.Wiki.CurrentPage, 'Companion-Overview');
        end

        function testNavigateToUnknownFallsBackToHome(testCase)
            %TESTNAVIGATETOUNKNOWNFALLSBACKTOHOME Missing page silently
            %   falls back to Home.md (per WikiPageIndex.readPage contract).
            testCase.Wiki = WikiBrowser('OpenTo', 'Home', ...
                'WikiDir', testCase.WikiDir_);
            testCase.Wiki.navigateTo('No-Such-Page-XYZZY');
            testCase.verifyEqual(testCase.Wiki.CurrentPage, 'Home');
        end

        function testBackForwardHistory(testCase)
            %TESTBACKFORWARDHISTORY Three-page round-trip — back/forward
            %   walk the stack, no-op at both ends.
            wb = WikiBrowser('OpenTo', 'Home', ...
                'WikiDir', testCase.WikiDir_);
            testCase.Wiki = wb;
            wb.navigateTo('Companion-Overview');
            wb.navigateTo('Tag-Status-Table');
            testCase.verifyEqual(wb.CurrentPage, 'Tag-Status-Table');

            wb.back();
            testCase.verifyEqual(wb.CurrentPage, 'Companion-Overview');
            wb.back();
            testCase.verifyEqual(wb.CurrentPage, 'Home');
            wb.back();   % at start — no-op
            testCase.verifyEqual(wb.CurrentPage, 'Home');

            wb.forward();
            testCase.verifyEqual(wb.CurrentPage, 'Companion-Overview');
            wb.forward();
            testCase.verifyEqual(wb.CurrentPage, 'Tag-Status-Table');
            wb.forward();   % at end — no-op
            testCase.verifyEqual(wb.CurrentPage, 'Tag-Status-Table');
        end

        function testForwardTruncatesOnNewNavigation(testCase)
            %TESTFORWARDTRUNCATESONNEWNAVIGATION Navigating from a middle
            %   history index truncates the forward portion (standard
            %   browser semantics, per WikiBrowser.navigateTo).
            wb = WikiBrowser('OpenTo', 'Home', ...
                'WikiDir', testCase.WikiDir_);
            testCase.Wiki = wb;
            wb.navigateTo('Companion-Overview');
            wb.navigateTo('Tag-Status-Table');
            wb.back();   % at Companion-Overview
            wb.back();   % at Home
            wb.navigateTo('Event-Viewer');   % truncates Companion-Overview + Tag-Status-Table
            testCase.verifyEqual(wb.CurrentPage, 'Event-Viewer');

            wb.forward();   % no-op — forward was truncated
            testCase.verifyEqual(wb.CurrentPage, 'Event-Viewer');
        end

        function testHistoryCapAt50(testCase)
            %TESTHISTORYCAPAT50 60 alternating navigations + behavioural
            %   back-step count proves the 50-entry cap (D-11).
            %
            %   Rather than reaching into HistoryStack_ private state, we
            %   step back from the end state and count how many distinct
            %   transitions occur before back() becomes a no-op. With a
            %   cap of 50 entries, there must be exactly 49 transitions.
            wb = WikiBrowser('OpenTo', 'Home', ...
                'WikiDir', testCase.WikiDir_);
            testCase.Wiki = wb;
            for k = 1:60
                if mod(k, 2) == 0
                    wb.navigateTo('Companion-Overview');
                else
                    wb.navigateTo('Home');
                end
            end

            stepsBack = 0;
            for k = 1:60
                priorPage = wb.CurrentPage;
                wb.back();
                if strcmp(priorPage, wb.CurrentPage)
                    break;   % back() became a no-op — we hit the head of the stack
                end
                stepsBack = stepsBack + 1;
            end
            testCase.verifyGreaterThanOrEqual(stepsBack, 49, ...
                'expected at least 49 back-steps if cap is 50 (50 entries → 49 transitions)');
            testCase.verifyLessThanOrEqual(stepsBack, 49, ...
                'expected at most 49 back-steps if cap is 50 (50 entries → 49 transitions)');
        end

        % ---- Theme / focus / close ----

        function testApplyThemeReRenders(testCase)
            %TESTAPPLYTHEMERERENDERS Theme switch updates Theme prop +
            %   keeps the window open.
            wb = WikiBrowser('OpenTo', 'Home', 'Theme', 'dark', ...
                'WikiDir', testCase.WikiDir_);
            testCase.Wiki = wb;
            wb.applyTheme('light');
            testCase.verifyEqual(wb.Theme, 'light');
            testCase.verifyTrue(wb.IsOpen);
        end

        function testCloseIsIdempotent(testCase)
            %TESTCLOSEISIDEMPOTENT Double-close must not throw; IsOpen
            %   stays false.
            wb = WikiBrowser('OpenTo', 'Home', ...
                'WikiDir', testCase.WikiDir_);
            testCase.Wiki = wb;
            wb.close();
            testCase.verifyFalse(wb.IsOpen);
            wb.close();   % must not throw
            testCase.verifyFalse(wb.IsOpen);
        end

        function testFocusOnClosedIsNoOp(testCase)
            %TESTFOCUSONCLOSEDISNOOP focus() on a closed window stays
            %   silent (used defensively by openWiki in later plans).
            wb = WikiBrowser('OpenTo', 'Home', ...
                'WikiDir', testCase.WikiDir_);
            testCase.Wiki = wb;
            wb.close();
            wb.focus();   % must not throw
            testCase.verifyFalse(wb.IsOpen);
        end

        function testTagOnRootFigure(testCase)
            %TESTTAGONROOTFIGURE Tag='WikiBrowserRoot' is the contract
            %   Plan 08's theme walker uses to skip the WikiBrowser —
            %   verify it is present while open and gone after close.
            wb = WikiBrowser('OpenTo', 'Home', ...
                'WikiDir', testCase.WikiDir_);
            testCase.Wiki = wb;
            hs = findall(0, 'Type', 'figure', 'Tag', 'WikiBrowserRoot');
            testCase.verifyNotEmpty(hs, ...
                'expected WikiBrowserRoot figure while open');

            wb.close();
            hs2 = findall(0, 'Type', 'figure', 'Tag', 'WikiBrowserRoot');
            testCase.verifyEmpty(hs2, ...
                'expected no WikiBrowserRoot figure after close');
        end

        % ---- Cross-doc link rewrite (uihtml inspection) ----

        function testCrossDocLinkRewriteInjectsJsBridge(testCase)
            %TESTCROSSDOCLINKREWRITEINJECTSJSBRIDGE Plan-checker I5 — the
            %   rendered HTML must carry BOTH class="wiki-internal" AND
            %   data-page="..." attributes AND the htmlComponent.Data
            %   bridge script, so internal cross-doc clicks round-trip
            %   back to navigateTo through HTMLEventReceivedFcn.
            %
            %   Companion-Overview.md contains markdown links to other
            %   wiki pages; after MarkdownRenderer + rewriteCrossDocLinks_
            %   those anchors must be marked .wiki-internal with the
            %   original page name preserved verbatim in data-page.
            wb = WikiBrowser('OpenTo', 'Companion-Overview', ...
                'WikiDir', testCase.WikiDir_);
            testCase.Wiki = wb;

            % Locate the uihtml inside the WikiBrowser figure. Mirror the
            % findobj idiom from DashboardEngine.m:966-967 +
            % TestDashboardInfo.testShowInfoOpensModalFigure (line 230).
            % If depth-1 misses (uihtml is several layers deep inside the
            % uigridlayout body), fall back to a deep findobj walk — both
            % calls are cheap.
            hFig = findall(0, 'Type', 'figure', 'Tag', 'WikiBrowserRoot');
            testCase.assertNotEmpty(hFig, ...
                'expected WikiBrowserRoot figure to host the uihtml');
            htmlObj = findobj(hFig(1), '-depth', 1, 'Type', 'uihtml');
            if isempty(htmlObj)
                htmlObj = findobj(hFig(1), 'Type', 'uihtml');
            end
            testCase.assertNotEmpty(htmlObj, ...
                'expected a uihtml descendant of WikiBrowserRoot');

            src = htmlObj(1).HTMLSource;
            testCase.verifyNotEmpty(strfind(src, 'class="wiki-internal"'), ...
                'expected wiki-internal class on rewritten anchors (plan-checker I5)');
            testCase.verifyNotEmpty(strfind(src, 'data-page="'), ...
                'expected data-page attribute on rewritten anchors (plan-checker I5)');
            testCase.verifyNotEmpty(strfind(src, 'htmlComponent.Data'), ...
                'expected JS bridge to htmlComponent.Data');
        end

        function testCrossDocLinkCallbackWiredToDataChangedFcn(testCase)
            %TESTCROSSDOCLINKCALLBACKWIREDTODATACHANGEDFCN Regression for
            %   the post-spot-check bug: the JS bridge sets
            %   htmlComponent.Data, which only fires DataChangedFcn —
            %   NOT HTMLEventReceivedFcn (that one is for
            %   sendEventToMATLAB which we do not use). Verify the
            %   correct callback is wired so JS-side clicks actually
            %   round-trip back to navigateTo.
            %
            %   We can't fire a real JS click from headless MATLAB, so
            %   this test inspects the wired callback handle directly.
            %   The matching live-click round-trip is exercised in the
            %   human-verify checkpoint (Plan 09).
            wb = WikiBrowser('OpenTo', 'Companion-Overview', ...
                'WikiDir', testCase.WikiDir_);
            testCase.Wiki = wb;

            hFig = findall(0, 'Type', 'figure', 'Tag', 'WikiBrowserRoot');
            testCase.assertNotEmpty(hFig);
            htmlObj = findobj(hFig(1), '-depth', 1, 'Type', 'uihtml');
            if isempty(htmlObj)
                htmlObj = findobj(hFig(1), 'Type', 'uihtml');
            end
            testCase.assertNotEmpty(htmlObj);

            % The JS bridge sets htmlComponent.Data — only DataChangedFcn
            % fires for that path. HTMLEventReceivedFcn is for
            % sendEventToMATLAB and would never fire.
            testCase.verifyClass(htmlObj(1).DataChangedFcn, ...
                'function_handle', ...
                ['DataChangedFcn must be a function handle — JS-bridge ' ...
                'writes to htmlComponent.Data only fire DataChangedFcn']);
            testCase.verifyEmpty(htmlObj(1).HTMLEventReceivedFcn, ...
                ['HTMLEventReceivedFcn must be empty — wiring it would ' ...
                'be a regression to the pre-fix bug (Plan 09 spot-check)']);
        end
    end
end
