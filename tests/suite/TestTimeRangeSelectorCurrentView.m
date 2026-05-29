classdef TestTimeRangeSelectorCurrentView < matlab.unittest.TestCase
%TESTTIMERANGESELECTORCURRENTVIEW Unit tests for the Phase 1039 current-view box.
%   Covers TimeRangeSelector.setCurrentView / hideCurrentView: the box
%   graphics (patch + two dashed edge lines), DataRange clamping, swapped-
%   bound reordering, the visually-distinct + non-interactive style, and the
%   no-throw lifecycle when called after the selector is deleted.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Access = private)
        function sel = makeSelector(testCase)
            %makeSelector  Off-screen selector over DataRange [0 100].
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            sel = TimeRangeSelector(hp);
            testCase.addTeardown(@() delete(sel));
            sel.setDataRange(0, 100);
        end
    end

    methods (Test)
        function testSetCurrentViewDrawsVisibleBox(testCase)
            sel = testCase.makeSelector();
            sel.setCurrentView(20, 60);
            testCase.verifyTrue(ishandle(sel.hCurrentViewBox), ...
                'hCurrentViewBox must be a valid handle after setCurrentView.');
            testCase.verifyEqual(char(get(sel.hCurrentViewBox, 'Visible')), 'on', ...
                'Box must become visible after setCurrentView.');
            testCase.verifyEqual(sel.CurrentView, [20 60], ...
                'CurrentView must store the requested [tStart tEnd].');
        end

        function testCurrentViewBoxGeometry(testCase)
            % Compare orientation-agnostically: MATLAB and Octave disagree on
            % whether patch/line XData/YData come back as rows or columns, so
            % flatten each to a row before checking (mirrors the robust pattern
            % in TestTimeRangeSelectorEventMarkers).
            sel = testCase.makeSelector();
            sel.setCurrentView(20, 60);
            boxX = reshape(get(sel.hCurrentViewBox, 'XData'), 1, []);
            boxY = reshape(get(sel.hCurrentViewBox, 'YData'), 1, []);
            leftX = reshape(get(sel.hCurrentViewLeft, 'XData'), 1, []);
            rightX = reshape(get(sel.hCurrentViewRight, 'XData'), 1, []);
            testCase.verifyEqual(boxX, [20 20 60 60], ...
                'Box XData must follow the [xL xL xR xR] patch shape.');
            testCase.verifyEqual(boxY, [0 1 1 0], ...
                'Box YData must span the full [0 1 1 0] height.');
            testCase.verifyEqual(leftX, [20 20], ...
                'Left edge must sit at the box start.');
            testCase.verifyEqual(rightX, [60 60], ...
                'Right edge must sit at the box end.');
        end

        function testHideCurrentViewHidesBox(testCase)
            sel = testCase.makeSelector();
            sel.setCurrentView(20, 60);
            sel.hideCurrentView();
            testCase.verifyEqual(char(get(sel.hCurrentViewBox, 'Visible')), 'off', ...
                'Box must be hidden after hideCurrentView.');
            testCase.verifyEqual(char(get(sel.hCurrentViewLeft, 'Visible')), 'off', ...
                'Left edge must be hidden after hideCurrentView.');
            testCase.verifyEqual(char(get(sel.hCurrentViewRight, 'Visible')), 'off', ...
                'Right edge must be hidden after hideCurrentView.');
            testCase.verifyEmpty(sel.CurrentView, ...
                'CurrentView must be cleared after hideCurrentView.');
        end

        function testClampToDataRange(testCase)
            sel = testCase.makeSelector();
            sel.setCurrentView(-50, 250);
            testCase.verifyEqual(sel.CurrentView, [0 100], ...
                'setCurrentView must clamp to DataRange [0 100].');
        end

        function testReordersSwappedBounds(testCase)
            sel = testCase.makeSelector();
            sel.setCurrentView(70, 30);
            testCase.verifyEqual(sel.CurrentView, [30 70], ...
                'Swapped bounds must be reordered to [30 70].');
        end

        function testDistinctFromSelection(testCase)
            sel = testCase.makeSelector();
            sel.setCurrentView(20, 60);
            cvAlpha  = get(sel.hCurrentViewBox, 'FaceAlpha');
            selAlpha = get(sel.hSelection, 'FaceAlpha');
            testCase.verifyEqual(cvAlpha, 0.12, ...
                'Current-view box FaceAlpha must be 0.12.');
            testCase.verifyEqual(selAlpha, 0.20, ...
                'Selection FaceAlpha must remain 0.20 (unchanged).');
            testCase.verifyNotEqual(cvAlpha, selAlpha, ...
                'Current-view box must be visually distinct from the Selection.');
            testCase.verifyEqual(char(get(sel.hCurrentViewBox, 'PickableParts')), 'none', ...
                'Current-view box must be non-pickable.');
            testCase.verifyEqual(char(get(sel.hCurrentViewBox, 'HitTest')), 'off', ...
                'Current-view box must not intercept mouse events.');
        end

        function testNoThrowAfterGraphicsDestroyed(testCase)
            % Realistic "after delete" contract: the underlying figure (and
            % therefore every graphics handle the selector owns) is destroyed,
            % but the TimeRangeSelector OBJECT itself is still a live handle.
            % setCurrentView/hideCurrentView must no-op via their ishandle
            % guards rather than throw.
            %
            % NOTE: calling a method on a *deleted* handle object (delete(sel)
            % then sel.method()) is not testable — MATLAB throws "Invalid or
            % deleted object" at dispatch, before any in-method guard can run.
            % Destroying the graphics while keeping the object alive is the
            % case the production guards (ishandle on hAxes + each box handle)
            % are actually designed for.
            hFig = figure('Visible', 'off');
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            sel = TimeRangeSelector(hp);
            testCase.addTeardown(@() delete(sel));
            sel.setDataRange(0, 100);
            sel.setCurrentView(10, 20);   % box live before we nuke the figure
            delete(hFig);                  % destroys axes + all box graphics
            try
                sel.setCurrentView(30, 40);
                sel.hideCurrentView();
                testCase.verifyTrue(true, ...
                    'setCurrentView/hideCurrentView must not throw after graphics destroyed.');
            catch err
                testCase.verifyFail(sprintf( ...
                    'Post-graphics-destroy API must not throw, but threw: %s', err.message));
            end
        end
    end
end
