classdef TestMexParity < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastplot_private_path();
        end
    end

    methods (Test)
        function testBinarySearchParityBasic(testCase)
            testCase.assumeTrue(exist('binary_search_mex', 'file') == 3, 'MEX not compiled');

            x = [1 3 5 7 9 11 13 15 17 19];

            test_cases = {
                4,   'left',  3;
                6,   'right', 3;
                5,   'left',  3;
                5,   'right', 3;
                0,   'left',  1;
                100, 'right', 10;
                100, 'left',  10;
                0,   'right', 1;
            };

            for t = 1:size(test_cases, 1)
                val = test_cases{t, 1};
                dir = test_cases{t, 2};
                expected = test_cases{t, 3};
                result = binary_search_mex(x, val, dir);
                testCase.verifyEqual(result, expected, ...
                    sprintf('binary_search_mex(%g, ''%s''): expected %d, got %d', ...
                    val, dir, expected, result));
            end
        end

        function testBinarySearchParityLargeArray(testCase)
            testCase.assumeTrue(exist('binary_search_mex', 'file') == 3, 'MEX not compiled');

            x_large = linspace(0, 1000, 1e6);
            vals = [0.001, 50.5, 500, 999.999];
            for v = 1:numel(vals)
                idx_m = TestMexParity.binary_search_matlab(x_large, vals(v), 'left');
                idx_c = binary_search_mex(x_large, vals(v), 'left');
                testCase.verifyEqual(idx_m, idx_c, ...
                    sprintf('binary_search parity failed for left val=%g: matlab=%d mex=%d', ...
                    vals(v), idx_m, idx_c));

                idx_m = TestMexParity.binary_search_matlab(x_large, vals(v), 'right');
                idx_c = binary_search_mex(x_large, vals(v), 'right');
                testCase.verifyEqual(idx_m, idx_c, ...
                    sprintf('binary_search parity failed for right val=%g: matlab=%d mex=%d', ...
                    vals(v), idx_m, idx_c));
            end
        end

        function testMinmaxCoreParity(testCase)
            testCase.assumeTrue(exist('minmax_core_mex', 'file') == 3, 'MEX not compiled');

            tol = 1e-12;
            sizes = [100, 1000, 10000, 100000];
            buckets_list = [5, 50, 100, 500];

            for s = 1:numel(sizes)
                n = sizes(s);
                nb = buckets_list(s);
                x = linspace(0, 100, n);
                y = sin(x * 2 * pi / 10) + 0.3 * randn(1, n);

                [xm, ym] = TestMexParity.minmax_core_matlab(x, y, nb);
                [xc, yc] = minmax_core_mex(x, y, nb);

                testCase.verifyEqual(numel(xm), numel(xc), ...
                    sprintf('minmax_core output size mismatch at n=%d', n));
                testCase.verifyLessThan(max(abs(xm - xc)), tol, ...
                    sprintf('minmax_core X mismatch at n=%d, maxdiff=%g', n, max(abs(xm - xc))));
                testCase.verifyLessThan(max(abs(ym - yc)), tol, ...
                    sprintf('minmax_core Y mismatch at n=%d, maxdiff=%g', n, max(abs(ym - yc))));
            end
        end

        function testLttbCoreParity(testCase)
            testCase.assumeTrue(exist('lttb_core_mex', 'file') == 3, 'MEX not compiled');

            tol = 1e-12;
            sizes = [100, 1000, 10000];
            outs_list = [10, 50, 200];

            for s = 1:numel(sizes)
                n = sizes(s);
                nout = outs_list(s);
                x = linspace(0, 100, n);
                y = sin(x * 2 * pi / 10) + 0.3 * randn(1, n);

                [xm, ym] = TestMexParity.lttb_core_matlab(x, y, nout);
                [xc, yc] = lttb_core_mex(x, y, nout);

                testCase.verifyEqual(numel(xm), numel(xc), ...
                    sprintf('lttb_core output size mismatch at n=%d', n));
                testCase.verifyLessThan(max(abs(xm - xc)), tol, ...
                    sprintf('lttb_core X mismatch at n=%d, maxdiff=%g', n, max(abs(xm - xc))));
                testCase.verifyLessThan(max(abs(ym - yc)), tol, ...
                    sprintf('lttb_core Y mismatch at n=%d, maxdiff=%g', n, max(abs(ym - yc))));
            end
        end

        function testViolationCullParityScalar(testCase)
            testCase.assumeTrue(exist('violation_cull_mex', 'file') == 3, 'MEX not compiled');

            tol = 1e-12;
            x = linspace(0, 100, 10000);
            y = sin(x) * 5;
            [xm, ym] = violation_cull(x, y, 0, 3.0, 'upper', 0.1, 0);
            [xc, yc] = violation_cull_mex(x, y, 0, 3.0, 1, 0.1, 0);
            testCase.verifyEqual(numel(xm), numel(xc), 'violation_cull scalar: count mismatch');
            testCase.verifyLessThan(max(abs(xm - xc)), tol, 'violation_cull scalar: X mismatch');
        end

        function testViolationCullParityTimeVarying(testCase)
            testCase.assumeTrue(exist('violation_cull_mex', 'file') == 3, 'MEX not compiled');

            tol = 1e-12;
            x = linspace(0, 100, 10000);
            y = sin(x) * 5;
            [xm, ym] = violation_cull(x, y, [0 50], [3 4], 'upper', 0.1, 0);
            [xc, yc] = violation_cull_mex(x, y, [0 50], [3 4], 1, 0.1, 0);
            testCase.verifyEqual(numel(xm), numel(xc), 'violation_cull tv: count mismatch');
            testCase.verifyLessThan(max(abs(xm - xc)), tol, 'violation_cull tv: X mismatch');
        end

        function testBuildStoreParitySmall(testCase)
            testCase.assumeTrue(exist('build_store_mex', 'file') == 3, 'MEX not compiled');
            testCase.assumeTrue(exist('mksqlite', 'file') == 3, 'mksqlite not compiled');

            tol = 1e-12;
            n = 50000;
            cs = 10000;
            x = linspace(0, 100, n);
            y = sin(x * 2 * pi / 10) + 0.3 * randn(1, n);

            % Build via MEX
            dbMex = [tempname, '.fpdb'];
            testCase.addTeardown(@() delete(dbMex));
            build_store_mex(dbMex, x, y, cs);

            % Read back and verify via mksqlite
            dbId = mksqlite('open', dbMex);
            mksqlite(dbId, 'typedBLOBs', 2);
            testCase.addTeardown(@() mksqlite(dbId, 'close'));

            rows = mksqlite(dbId, 'SELECT * FROM chunks ORDER BY chunk_id');
            testCase.verifyEqual(numel(rows), ceil(n / cs), 'chunk count mismatch');

            % Verify each chunk's data and metadata
            for k = 1:numel(rows)
                r = rows(k);
                s = (k - 1) * cs + 1;
                e = min(k * cs, n);
                expectedX = x(s:e);
                expectedY = y(s:e);

                chunkX = r.x_data(:)';
                chunkY = r.y_data(:)';

                testCase.verifyEqual(numel(chunkX), numel(expectedX), ...
                    sprintf('chunk %d: X length mismatch', k));
                testCase.verifyLessThan(max(abs(chunkX - expectedX)), tol, ...
                    sprintf('chunk %d: X data mismatch', k));
                testCase.verifyLessThan(max(abs(chunkY - expectedY)), tol, ...
                    sprintf('chunk %d: Y data mismatch', k));

                % Verify metadata
                testCase.verifyEqual(r.x_min, expectedX(1), ...
                    sprintf('chunk %d: x_min mismatch', k));
                testCase.verifyEqual(r.x_max, expectedX(end), ...
                    sprintf('chunk %d: x_max mismatch', k));
                testCase.verifyLessThan(abs(r.y_min - min(expectedY)), tol, ...
                    sprintf('chunk %d: y_min mismatch', k));
                testCase.verifyLessThan(abs(r.y_max - max(expectedY)), tol, ...
                    sprintf('chunk %d: y_max mismatch', k));
                testCase.verifyEqual(r.pt_offset, s, ...
                    sprintf('chunk %d: pt_offset mismatch', k));
                testCase.verifyEqual(r.pt_count, e - s + 1, ...
                    sprintf('chunk %d: pt_count mismatch', k));
            end
        end

        function testBuildStoreParityLarge(testCase)
            testCase.assumeTrue(exist('build_store_mex', 'file') == 3, 'MEX not compiled');
            testCase.assumeTrue(exist('mksqlite', 'file') == 3, 'mksqlite not compiled');

            tol = 1e-12;
            n = 1000000;
            cs = 100000;
            x = linspace(0, 1000, n);
            y = sin(x) + 0.1 * randn(1, n);

            % Build via MEX
            dbMex = [tempname, '.fpdb'];
            testCase.addTeardown(@() delete(dbMex));
            build_store_mex(dbMex, x, y, cs);

            % Verify via DataStore getRange (end-to-end)
            dbId = mksqlite('open', dbMex);
            mksqlite(dbId, 'typedBLOBs', 2);
            mksqlite(dbId, 'PRAGMA mmap_size = 268435456');
            testCase.addTeardown(@() mksqlite(dbId, 'close'));

            % Read all chunks and concatenate
            rows = mksqlite(dbId, ...
                'SELECT x_data, y_data FROM chunks ORDER BY chunk_id');
            allX = [];
            allY = [];
            for k = 1:numel(rows)
                allX = [allX, rows(k).x_data(:)'];
                allY = [allY, rows(k).y_data(:)'];
            end

            testCase.verifyEqual(numel(allX), n, 'total point count mismatch');
            testCase.verifyLessThan(max(abs(allX - x)), tol, 'X data mismatch');
            testCase.verifyLessThan(max(abs(allY - y)), tol, 'Y data mismatch');
        end
    end

    methods (Static, Access = private)
        function idx = binary_search_matlab(x, val, direction)
            n = numel(x);
            if strcmp(direction, 'left')
                lo = 1; hi = n; idx = n;
                while lo <= hi
                    mid = floor((lo + hi) / 2);
                    if x(mid) >= val; idx = mid; hi = mid - 1;
                    else; lo = mid + 1; end
                end
            else
                lo = 1; hi = n; idx = 1;
                while lo <= hi
                    mid = floor((lo + hi) / 2);
                    if x(mid) <= val; idx = mid; lo = mid + 1;
                    else; hi = mid - 1; end
                end
            end
        end

        function [xOut, yOut] = minmax_core_matlab(segX, segY, nb)
            segLen = numel(segY);
            bucketSize = floor(segLen / nb);
            usable = bucketSize * nb;
            yMat = reshape(segY(1:usable), bucketSize, nb);
            [yMinVals, iMin] = min(yMat, [], 1);
            [yMaxVals, iMax] = max(yMat, [], 1);
            offsets = (0:nb-1) * bucketSize;
            gMin = iMin + offsets;
            gMax = iMax + offsets;
            if usable < segLen
                remY = segY(usable+1:end);
                [remMinVal, remMinIdx] = min(remY);
                [remMaxVal, remMaxIdx] = max(remY);
                if remMinVal < yMinVals(nb)
                    yMinVals(nb) = remMinVal;
                    gMin(nb) = remMinIdx + usable;
                end
                if remMaxVal > yMaxVals(nb)
                    yMaxVals(nb) = remMaxVal;
                    gMax(nb) = remMaxIdx + usable;
                end
            end
            xMinVals = segX(gMin);
            xMaxVals = segX(gMax);
            minFirst = gMin <= gMax;
            xOut = zeros(1, 2*nb);
            yOut = zeros(1, 2*nb);
            odd  = 1:2:2*nb;
            even = 2:2:2*nb;
            xOut(odd(minFirst))   = xMinVals(minFirst);
            yOut(odd(minFirst))   = yMinVals(minFirst);
            xOut(even(minFirst))  = xMaxVals(minFirst);
            yOut(even(minFirst))  = yMaxVals(minFirst);
            xOut(odd(~minFirst))  = xMaxVals(~minFirst);
            yOut(odd(~minFirst))  = yMaxVals(~minFirst);
            xOut(even(~minFirst)) = xMinVals(~minFirst);
            yOut(even(~minFirst)) = yMinVals(~minFirst);
        end

        function [xOut, yOut] = lttb_core_matlab(x, y, numOut)
            n = numel(x);
            xOut = zeros(1, numOut);
            yOut = zeros(1, numOut);
            xOut(1) = x(1); yOut(1) = y(1);
            xOut(numOut) = x(n); yOut(numOut) = y(n);
            bucketSize = (n - 2) / (numOut - 2);
            prevSelectedIdx = 1;
            for i = 2:numOut-1
                bStart = floor((i-2) * bucketSize) + 2;
                bEnd   = min(floor((i-1) * bucketSize) + 1, n-1);
                nStart = floor((i-1) * bucketSize) + 2;
                nEnd   = min(floor(i * bucketSize) + 1, n-1);
                if nEnd < nStart; nEnd = nStart; end
                avgX = mean(x(nStart:nEnd));
                avgY = mean(y(nStart:nEnd));
                pX = x(prevSelectedIdx);
                pY = y(prevSelectedIdx);
                candidates = bStart:bEnd;
                areas = abs((pX - avgX) .* (y(candidates) - pY) - (pX - x(candidates)) .* (avgY - pY));
                [~, bestLocal] = max(areas);
                bestIdx = candidates(bestLocal);
                xOut(i) = x(bestIdx);
                yOut(i) = y(bestIdx);
                prevSelectedIdx = bestIdx;
            end
        end
    end
end
