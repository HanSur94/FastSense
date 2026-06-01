classdef TestTimeRangeSelectorCurrentView < matlab.unittest.TestCase
%TESTTIMERANGESELECTORCURRENTVIEW Unit tests for the Phase 1039 current-view boxes.
%   Covers TimeRangeSelector.setCurrentViews / setCurrentView / hideCurrentView:
%   the per-graph box pool (patch + two dashed edge lines each), DataRange
%   clamping, swapped-bound reordering, per-index palette colouring, the
%   visually-distinct + non-interactive style, and the no-throw lifecycle after
%   the underlying graphics are destroyed.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
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
            testCase.verifyEqual(numel(sel.hCurrentViewBoxes), 1, ...
                'A single box must exist after setCurrentView.');
            testCase.verifyTrue(ishandle(sel.hCurrentViewBoxes(1)), ...
                'Pooled box must be a valid handle after setCurrentView.');
            testCase.verifyEqual(char(get(sel.hCurrentViewBoxes(1), 'Visible')), 'on', ...
                'Box must become visible after setCurrentView.');
            testCase.verifyEqual(sel.CurrentViews, [20 60], ...
                'CurrentViews must store the requested [tStart tEnd] row.');
        end

        function testCurrentViewBoxGeometry(testCase)
            % Compare orientation-agnostically: MATLAB and Octave disagree on
            % whether patch/line XData/YData come back as rows or columns, so
            % flatten each to a row before checking.
            sel = testCase.makeSelector();
            sel.setCurrentView(20, 60);
            boxX  = reshape(get(sel.hCurrentViewBoxes(1),  'XData'), 1, []);
            boxY  = reshape(get(sel.hCurrentViewBoxes(1),  'YData'), 1, []);
            leftX = reshape(get(sel.hCurrentViewEdgesL(1), 'XData'), 1, []);
            rightX = reshape(get(sel.hCurrentViewEdgesR(1), 'XData'), 1, []);
            testCase.verifyEqual(boxX, [20 20 60 60], ...
                'Box XData must follow the [xL xL xR xR] patch shape.');
            testCase.verifyEqual(boxY, [0 1 1 0], ...
                'Box YData must span the full [0 1 1 0] height.');
            testCase.verifyEqual(leftX, [20 20], ...
                'Left edge must sit at the box start.');
            testCase.verifyEqual(rightX, [60 60], ...
                'Right edge must sit at the box end.');
        end

        function testMultipleBoxesPerGraphColoured(testCase)
            % Two out-of-sync graphs -> two SEPARATE boxes, each coloured from the
            % shared preview palette by its colour index (box k matches preview
            % line k). palette row 1 = blue [0 .45 .70], row 2 = orange [.90 .40 .20].
            sel = testCase.makeSelector();
            sel.setCurrentViews([10 30; 50 80], [1 2]);
            testCase.verifyEqual(numel(sel.hCurrentViewBoxes), 2, ...
                'Two ranges must produce two boxes.');
            testCase.verifyEqual(size(sel.CurrentViews, 1), 2, ...
                'CurrentViews must hold two rows.');
            c1 = get(sel.hCurrentViewBoxes(1), 'FaceColor');
            c2 = get(sel.hCurrentViewBoxes(2), 'FaceColor');
            testCase.verifyEqual(c1, [0.00 0.45 0.70], 'AbsTol', 1e-6, ...
                'Box 1 must use preview-palette colour index 1 (blue).');
            testCase.verifyEqual(c2, [0.90 0.40 0.20], 'AbsTol', 1e-6, ...
                'Box 2 must use preview-palette colour index 2 (orange).');
            x1 = reshape(get(sel.hCurrentViewBoxes(1), 'XData'), 1, []);
            x2 = reshape(get(sel.hCurrentViewBoxes(2), 'XData'), 1, []);
            testCase.verifyEqual(x1, [10 10 30 30], 'Box 1 geometry must match its range.');
            testCase.verifyEqual(x2, [50 50 80 80], 'Box 2 geometry must match its range.');
        end

        function testBoxPoolShrinks(testCase)
            % Going from two boxes to one must delete the surplus handle.
            sel = testCase.makeSelector();
            sel.setCurrentViews([10 30; 50 80], [1 2]);
            testCase.verifyEqual(numel(sel.hCurrentViewBoxes), 2);
            sel.setCurrentViews([40 60], 3);
            testCase.verifyEqual(numel(sel.hCurrentViewBoxes), 1, ...
                'Pool must shrink to one box.');
            c = get(sel.hCurrentViewBoxes(1), 'FaceColor');
            testCase.verifyEqual(c, [0.20 0.60 0.20], 'AbsTol', 1e-6, ...
                'Single remaining box must use palette index 3 (green).');
        end

        function testHideCurrentViewClearsPool(testCase)
            sel = testCase.makeSelector();
            sel.setCurrentViews([10 30; 50 80], [1 2]);
            sel.hideCurrentView();
            testCase.verifyEmpty(sel.hCurrentViewBoxes, ...
                'Box pool must be emptied after hideCurrentView.');
            testCase.verifyEmpty(sel.hCurrentViewEdgesL, ...
                'Left-edge pool must be emptied after hideCurrentView.');
            testCase.verifyEmpty(sel.hCurrentViewEdgesR, ...
                'Right-edge pool must be emptied after hideCurrentView.');
            testCase.verifyEmpty(sel.CurrentViews, ...
                'CurrentViews must be cleared after hideCurrentView.');
        end

        function testClampToDataRange(testCase)
            sel = testCase.makeSelector();
            sel.setCurrentView(-50, 250);
            testCase.verifyEqual(sel.CurrentViews, [0 100], ...
                'setCurrentView must clamp to DataRange [0 100].');
        end

        function testReordersSwappedBounds(testCase)
            sel = testCase.makeSelector();
            sel.setCurrentView(70, 30);
            testCase.verifyEqual(sel.CurrentViews, [30 70], ...
                'Swapped bounds must be reordered to [30 70].');
        end

        function testDistinctFromSelection(testCase)
            sel = testCase.makeSelector();
            sel.setCurrentView(20, 60);
            cvAlpha  = get(sel.hCurrentViewBoxes(1), 'FaceAlpha');
            selAlpha = get(sel.hSelection, 'FaceAlpha');
            testCase.verifyEqual(cvAlpha, 0.12, ...
                'Current-view box FaceAlpha must be 0.12.');
            testCase.verifyEqual(selAlpha, 0.20, ...
                'Selection FaceAlpha must remain 0.20 (unchanged).');
            testCase.verifyNotEqual(cvAlpha, selAlpha, ...
                'Current-view box must be visually distinct from the Selection.');
            testCase.verifyEqual(char(get(sel.hCurrentViewBoxes(1), 'PickableParts')), 'none', ...
                'Current-view box must be non-pickable.');
            testCase.verifyEqual(char(get(sel.hCurrentViewBoxes(1), 'HitTest')), 'off', ...
                'Current-view box must not intercept mouse events.');
        end

        function testNoThrowAfterGraphicsDestroyed(testCase)
            % Realistic "after delete" contract: the underlying figure (and every
            % graphics handle the selector owns) is destroyed, but the
            % TimeRangeSelector OBJECT itself is still a live handle. The API must
            % no-op via its ishandle guards rather than throw.
            %
            % NOTE: calling a method on a *deleted* handle object (delete(sel) then
            % sel.method()) is not testable — MATLAB throws "Invalid or deleted
            % object" at dispatch. Destroying the graphics while keeping the object
            % alive is the case the production guards are designed for.
            hFig = figure('Visible', 'off');
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            sel = TimeRangeSelector(hp);
            testCase.addTeardown(@() delete(sel));
            sel.setDataRange(0, 100);
            sel.setCurrentViews([10 20; 40 60], [1 2]);  % boxes live before nuke
            delete(hFig);                                  % destroys axes + boxes
            try
                sel.setCurrentViews([30 40], 1);
                sel.hideCurrentView();
                testCase.verifyTrue(true, ...
                    'setCurrentViews/hideCurrentView must not throw after graphics destroyed.');
            catch err
                testCase.verifyFail(sprintf( ...
                    'Post-graphics-destroy API must not throw, but threw: %s', err.message));
            end
        end
    end
end
