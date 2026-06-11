classdef TestMultiStatusWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = MultiStatusWidget();
            testCase.verifyEqual(w.getType(), 'multistatus');
            testCase.verifyEqual(w.ShowLabels, true);
            testCase.verifyEqual(w.IconStyle, 'dot');
        end

        function testToStruct(testCase)
            w = MultiStatusWidget('Title', 'Status Grid');
            w.Columns = 4;
            w.IconStyle = 'square';
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'multistatus');
            testCase.verifyEqual(s.columns, 4);
            testCase.verifyEqual(s.iconStyle, 'square');
        end

        function testShortWideWidgetSpreadsDotsHorizontally(testCase)
        %TESTSHORTWIDEWIDGETSPREADSDOTSHORIZONTALLY Regression for the dot/label
        %   clump on short, wide widgets (grid Position like [1 1 24 2]): the axes
        %   used DataAspectRatio=[1 1 1] with square [0 1]x[0 1] limits, which
        %   letterboxed the drawable area into a square sized by the panel HEIGHT,
        %   so all dots+labels rendered overlapping in a tiny centred square.
        %   After the fix the dots must spread across the panel width in a single
        %   row with pairwise non-overlapping label extents.
            hFig = figure('Visible', 'off', 'Position', [100 100 1548 620]);
            testCase.addTeardown(@() close(hFig));
            % Panel geometry of a full-width, 2-grid-row widget (~90 px tall).
            hp = uipanel('Parent', hFig, 'Units', 'pixels', ...
                'Position', [24 500 1500 90], 'Title', 'Reticle - sensor status');

            w = MultiStatusWidget('Title', 'Reticle - sensor status');
            n = 6;
            items = cell(1, n);
            for k = 1:n
                items{k} = struct('threshold', [], 'value', [], ...
                    'label', sprintf('Sensor%02d', k));
            end
            w.Sensors = items;
            w.render(hp);
            drawnow;

            rects = testCase.labelExtentsPx_(hp, n);

            % 1) No pairwise label overlap (failed with 4 overlapping pairs
            %    before the fix — labels 46 px wide on a ~25 px pitch).
            for a = 1:n-1
                for b = a+1:n
                    testCase.verifyFalse(testCase.rectsOverlap_(rects(a, :), rects(b, :)), ...
                        sprintf('labels %d and %d overlap at 2-row widget height', a, b));
                end
            end

            % 2) Labels must span most of the panel width (was 49 px = 3%
            %    of the 1500 px panel before the fix; ~1200 px = 80% after).
            centersX = rects(:, 1) + rects(:, 3) / 2;
            spread = max(centersX) - min(centersX);
            testCase.verifyGreaterThan(spread, 0.5 * 1500, ...
                'dot/label strip must spread across the short, wide widget');
        end

        function testSquarePanelKeepsGridLayout(testCase)
        %TESTSQUAREPANELKEEPSGRIDLAYOUT Auto column count on a square panel must
        %   keep the historic ceil(sqrt(n)) grid (3 cols x 2 rows for 6 items) so
        %   generously sized widgets do not regress to a single squeezed row.
            hFig = figure('Visible', 'off', 'Position', [100 100 600 600]);
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Units', 'pixels', ...
                'Position', [50 50 400 400]);

            w = MultiStatusWidget('Title', 'Status Grid');
            n = 6;
            items = cell(1, n);
            for k = 1:n
                items{k} = struct('threshold', [], 'value', [], ...
                    'label', sprintf('S%d', k));
            end
            w.Sensors = items;
            w.render(hp);
            drawnow;

            rects = testCase.labelExtentsPx_(hp, n);
            centersX = rects(:, 1) + rects(:, 3) / 2;
            centersY = rects(:, 2) + rects(:, 4) / 2;
            testCase.verifyNumElements(uniquetol(centersX, 2, 'DataScale', 1), 3, ...
                '6 items on a square panel must keep 3 columns');
            testCase.verifyNumElements(uniquetol(centersY, 2, 'DataScale', 1), 2, ...
                '6 items on a square panel must keep 2 rows');
            % Labels stay pairwise non-overlapping at generous sizes too.
            for a = 1:n-1
                for b = a+1:n
                    testCase.verifyFalse(testCase.rectsOverlap_(rects(a, :), rects(b, :)), ...
                        sprintf('labels %d and %d overlap on a square panel', a, b));
                end
            end
        end

        function testThresholdOnLimitNotViolated(testCase)
        %TESTTHRESHOLDONLIMITNOTVIOLATED Regression for the inclusive (>=) bug in
        %   deriveColorFromThreshold: a value sitting EXACTLY on a threshold limit
        %   should NOT be a violation (strict > / < convention matching all other
        %   dashboard widgets). The private method now delegates to isThresholdViolated.
            upper = MockThreshold(true, 10);
            lower = MockThreshold(false, 5);
            % On the limit — must NOT be a violation.
            testCase.verifyFalse(isThresholdViolated(upper, 10), ...
                'val == upper limit must NOT be a violation (was inclusive >= before fix)');
            testCase.verifyFalse(isThresholdViolated(lower, 5), ...
                'val == lower limit must NOT be a violation (was inclusive <= before fix)');
            % Strictly beyond the limit — must be a violation.
            testCase.verifyTrue(isThresholdViolated(upper, 11));
            testCase.verifyTrue(isThresholdViolated(lower, 4));
        end
    end

    methods (Access = private)
        function rects = labelExtentsPx_(testCase, hp, n)
        %LABELEXTENTSPX_ Rendered label Extent rectangles in axes pixel space.
            ax = findobj(hp, 'Type', 'axes');
            labels = findobj(ax, 'Type', 'text');
            testCase.assertNumElements(labels, n, ...
                'expected one rendered label per sensor item');
            set(labels, 'Units', 'pixels');
            rects = zeros(n, 4);
            for k = 1:n
                rects(k, :) = get(labels(k), 'Extent');   % [x y w h] px
            end
        end
    end

    methods (Static, Access = private)
        function tf = rectsOverlap_(ra, rb)
        %RECTSOVERLAP_ True when two [x y w h] rectangles intersect.
            tf = ~(ra(1) + ra(3) <= rb(1) || rb(1) + rb(3) <= ra(1) || ...
                   ra(2) + ra(4) <= rb(2) || rb(2) + rb(4) <= ra(2));
        end
    end
end
