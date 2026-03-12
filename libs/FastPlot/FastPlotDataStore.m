classdef FastPlotDataStore < handle
    %FASTPLOTDATASTORE SQLite-backed data storage for large time series.
    %   Stores X/Y data in a temporary SQLite database via mksqlite using
    %   chunked typed BLOBs for fast bulk insert and range-based retrieval.
    %   This avoids loading full datasets into MATLAB memory, preventing
    %   out-of-memory errors on Windows and memory-constrained systems.
    %
    %   Data is split into chunks of ~100K points. Each chunk is stored as
    %   a pair of typed BLOBs (X and Y arrays) with the chunk's X range
    %   indexed for fast overlap queries. On zoom/pan, only the chunks
    %   overlapping the visible range are loaded, then trimmed to the exact
    %   view window.
    %
    %   Additional data columns (cell, char, string, categorical, logical,
    %   or any numeric type) can be attached via addColumn / getColumn.
    %
    %   Requires mksqlite. If not available, falls back to binary file
    %   storage (extra columns require mksqlite).
    %
    %   Usage:
    %     ds = FastPlotDataStore(x, y);
    %     [xVis, yVis] = ds.getRange(xMin, xMax);
    %     [xSlice, ySlice] = ds.readSlice(1000, 2000);
    %
    %   Extra columns:
    %     ds.addColumn('labels', {'A','B','C',...});
    %     vals = ds.getColumnRange('labels', xMin, xMax);
    %     vals = ds.getColumnSlice('labels', 1, 100);
    %     names = ds.listColumns();
    %
    %   See also FastPlot, FastPlotDefaults, mksqlite.

    properties (SetAccess = private)
        NumPoints  = 0
        XMin       = NaN
        XMax       = NaN
        HasNaN     = false
        DbPath     = ''
        BinPath    = ''
        PyramidX   = []   % Pre-computed L1 minmax downsample X
        PyramidY   = []   % Pre-computed L1 minmax downsample Y
    end

    properties (Access = private)
        DbId         = -1
        ChunkSize    = 100000
        NumChunks    = 0
        IsValid      = false
        UseSqlite    = false
        ColumnNames  = {}
        DbOpen       = false   % Track whether connection is currently open
    end

    methods (Access = public)
        function obj = FastPlotDataStore(x, y)
            %FASTPLOTDATASTORE Create a disk-backed store from X/Y arrays.
            if nargin < 2; return; end

            obj.NumPoints = numel(x);
            if obj.NumPoints == 0; return; end

            if ~isrow(x); x = x(:)'; end
            if ~isrow(y); y = y(:)'; end

            obj.XMin = x(1);
            obj.XMax = x(end);
            obj.HasNaN = any(isnan(y));
            obj.UseSqlite = (exist('mksqlite', 'file') == 3);

            if obj.UseSqlite
                obj.initSqlite(x, y);
            else
                obj.initBinaryFallback(x, y);
            end

            % Pre-compute L1 minmax pyramid while data is in memory.
            % This avoids re-reading the full dataset from disk on first
            % render.  Reduction factor 100 matches FastPlot.PyramidReduction.
            obj.buildPyramidFromMemory(x, y, 100);
        end

        function [xOut, yOut] = getRange(obj, xMin, xMax)
            %GETRANGE Read data within an X range (with one-point padding).
            if ~obj.IsValid || obj.NumPoints == 0
                xOut = []; yOut = [];
                return;
            end
            obj.ensureOpen();
            if obj.UseSqlite
                [xOut, yOut] = obj.getRangeSqlite(xMin, xMax);
            else
                [xOut, yOut] = obj.getRangeBinary(xMin, xMax);
            end
        end

        function [xOut, yOut] = readSlice(obj, startIdx, endIdx)
            %READSLICE Read a contiguous slice of data by row index.
            if ~obj.IsValid
                xOut = []; yOut = [];
                return;
            end
            obj.ensureOpen();
            startIdx = max(1, startIdx);
            endIdx   = min(obj.NumPoints, endIdx);
            if endIdx < startIdx
                xOut = []; yOut = [];
                return;
            end
            if obj.UseSqlite
                [xOut, yOut] = obj.readSliceSqlite(startIdx, endIdx);
            else
                [xOut, yOut] = obj.readSliceBinary(startIdx, endIdx);
            end
        end

        function addColumn(obj, name, data)
            %ADDCOLUMN Store an extra data column alongside X/Y.
            %   Categorical arrays auto-convert to codes+categories struct.
            %   String arrays auto-convert to cell of char.
            if ~obj.UseSqlite
                error('FastPlotDataStore:noSqlite', ...
                    'addColumn requires mksqlite (SQLite backend).');
            end
            obj.ensureOpen();
            if ~obj.IsValid
                error('FastPlotDataStore:notValid', ...
                    'DataStore is not initialized.');
            end

            % Auto-convert types
            if isa(data, 'categorical')
                data = FastPlotDataStore.fromCategorical(data);
            end
            if isa(data, 'string')
                data = cellstr(data);
            end

            % Validate length
            nData = columnLength(data);
            if nData ~= obj.NumPoints
                error('FastPlotDataStore:sizeMismatch', ...
                    'Column data length (%d) must match NumPoints (%d).', ...
                    nData, obj.NumPoints);
            end

            % Create columns table if needed
            if isempty(obj.ColumnNames)
                mksqlite(obj.DbId, [...
                    'CREATE TABLE IF NOT EXISTS columns (' ...
                    '  chunk_id INTEGER NOT NULL,' ...
                    '  col_name TEXT NOT NULL,' ...
                    '  pt_offset INTEGER NOT NULL,' ...
                    '  pt_count INTEGER NOT NULL,' ...
                    '  col_data BLOB NOT NULL,' ...
                    '  PRIMARY KEY (col_name, chunk_id)' ...
                    ')']);
            end

            if any(strcmp(name, obj.ColumnNames))
                error('FastPlotDataStore:duplicateColumn', ...
                    'Column ''%s'' already exists.', name);
            end

            % Chunk and insert
            n = obj.NumPoints;
            cs = obj.ChunkSize;
            mksqlite(obj.DbId, 'BEGIN TRANSACTION');
            try
                chunkId = 0;
                for s = 1:cs:n
                    chunkId = chunkId + 1;
                    e = min(s + cs - 1, n);
                    chunk = sliceColumnData(data, s, e);
                    mksqlite(obj.DbId, ...
                        'INSERT INTO columns VALUES (?, ?, ?, ?, ?)', ...
                        chunkId, name, s, e - s + 1, chunk);
                end
                mksqlite(obj.DbId, 'COMMIT');
            catch ME
                try mksqlite(obj.DbId, 'ROLLBACK'); catch; end
                rethrow(ME);
            end

            obj.ColumnNames{end+1} = name;
        end

        function data = getColumnRange(obj, name, xMin, xMax)
            %GETCOLUMNRANGE Read a column's data within an X range.
            %   Converts the X range to a point-offset range using chunk
            %   metadata (no x_data BLOB fetch), then delegates to slice.
            if ~obj.UseSqlite || ~obj.IsValid
                data = {};
                return;
            end
            obj.ensureOpen();
            % Find the point-offset range covering [xMin, xMax] with
            % one neighbour chunk on each side for padding.
            ids = mksqlite(obj.DbId, ...
                'SELECT chunk_id FROM chunks WHERE x_max >= ? AND x_min <= ?', ...
                xMin, xMax);
            if numel(ids) == 0; data = {}; return; end
            lo = max(1, ids(1).chunk_id - 1);
            hi = ids(end).chunk_id + 1;
            meta = mksqlite(obj.DbId, ...
                ['SELECT pt_offset, pt_count FROM chunks ' ...
                 'WHERE chunk_id BETWEEN ? AND ? ORDER BY chunk_id'], ...
                lo, hi);
            if numel(meta) == 0; data = {}; return; end
            startIdx = meta(1).pt_offset;
            lastRow  = meta(end);
            endIdx   = lastRow.pt_offset + lastRow.pt_count - 1;
            data = obj.getColumnSlice(name, startIdx, endIdx);
        end

        function data = getColumnSlice(obj, name, startIdx, endIdx)
            %GETCOLUMNSLICE Read a column slice by point index range.
            if ~obj.UseSqlite || ~obj.IsValid
                data = {};
                return;
            end
            obj.ensureOpen();
            startIdx = max(1, startIdx);
            endIdx   = min(obj.NumPoints, endIdx);
            res = mksqlite(obj.DbId, ...
                ['SELECT pt_offset, pt_count, col_data FROM columns ' ...
                 'WHERE col_name = ? AND (pt_offset + pt_count - 1) >= ? ' ...
                 'AND pt_offset <= ? ORDER BY chunk_id'], ...
                name, startIdx, endIdx);
            if numel(res) == 0; data = {}; return; end
            data = assembleColumnByOffset(res, startIdx, endIdx);
        end

        function names = listColumns(obj)
            %LISTCOLUMNS Return names of all stored extra columns.
            names = obj.ColumnNames;
        end

        function idx = findIndex(obj, xVal, side)
            %FINDINDEX Binary search for a global point index by X value.
            %   idx = ds.findIndex(xVal, 'left') returns the first index
            %   where X(idx) >= xVal.  idx = ds.findIndex(xVal, 'right')
            %   returns the last index where X(idx) <= xVal.
            %
            %   Uses chunk metadata (x_min, x_max) to read only one chunk's
            %   X data from disk, giving O(log C + log K) performance where
            %   C is the number of chunks and K is the chunk size.
            %
            %   See also readSlice, getRange.

            if ~obj.IsValid || obj.NumPoints == 0
                idx = 1;
                return;
            end
            obj.ensureOpen();

            if ~obj.UseSqlite
                % Binary file fallback: binary search on file
                fid = fopen(obj.BinPath, 'rb');
                idx = bsearchBinaryFile(fid, obj.NumPoints, xVal, side);
                fclose(fid);
                return;
            end

            if strcmp(side, 'left')
                % First index where X >= xVal: find the first chunk
                % whose x_max reaches xVal.
                res = mksqlite(obj.DbId, ...
                    ['SELECT pt_offset, x_data FROM chunks ' ...
                     'WHERE x_max >= ? ORDER BY chunk_id LIMIT 1'], ...
                    xVal);
                if isempty(res)
                    idx = obj.NumPoints;
                    return;
                end
                chunkX = res(1).x_data(:)';
                localIdx = bsearchLocal(chunkX, xVal, 'left');
                idx = res(1).pt_offset + localIdx - 1;
            else
                % Last index where X <= xVal: find the last chunk
                % whose x_min is still <= xVal.
                res = mksqlite(obj.DbId, ...
                    ['SELECT pt_offset, x_data FROM chunks ' ...
                     'WHERE x_min <= ? ORDER BY chunk_id DESC LIMIT 1'], ...
                    xVal);
                if isempty(res)
                    idx = 1;
                    return;
                end
                chunkX = res(1).x_data(:)';
                localIdx = bsearchLocal(chunkX, xVal, 'right');
                idx = res(1).pt_offset + localIdx - 1;
            end
        end

        function [violX, violY] = findViolations(obj, startIdx, endIdx, threshold, isUpper)
            %FINDVIOLATIONS Find violation points using chunk-level Y filtering.
            %   [vx, vy] = ds.findViolations(lo, hi, thresh, true) finds all
            %   points in [lo, hi] where Y > thresh (upper violation).
            %   [vx, vy] = ds.findViolations(lo, hi, thresh, false) finds
            %   points where Y < thresh (lower violation).
            %
            %   Uses chunk y_min/y_max metadata to skip entire chunks that
            %   cannot contain violations, avoiding BLOB reads for safe chunks.

            if ~obj.IsValid
                violX = []; violY = [];
                return;
            end
            obj.ensureOpen();

            if ~obj.UseSqlite
                % Binary fallback: read and filter
                [x, y] = obj.readSlice(startIdx, endIdx);
                if isUpper; mask = y > threshold;
                else;       mask = y < threshold; end
                violX = x(mask); violY = y(mask);
                return;
            end

            % Single query: only fetch chunks whose y-range could violate
            if isUpper
                res = mksqlite(obj.DbId, ...
                    ['SELECT pt_offset, pt_count, x_data, y_data FROM chunks ' ...
                     'WHERE (pt_offset+pt_count-1) >= ? AND pt_offset <= ? ' ...
                     'AND y_max > ? ORDER BY chunk_id'], ...
                    startIdx, endIdx, threshold);
            else
                res = mksqlite(obj.DbId, ...
                    ['SELECT pt_offset, pt_count, x_data, y_data FROM chunks ' ...
                     'WHERE (pt_offset+pt_count-1) >= ? AND pt_offset <= ? ' ...
                     'AND y_min < ? ORDER BY chunk_id'], ...
                    startIdx, endIdx, threshold);
            end

            if isempty(res)
                violX = []; violY = [];
                return;
            end

            nRes = numel(res);
            vxParts = cell(1, nRes);
            vyParts = cell(1, nRes);
            for k = 1:nRes
                cx = res(k).x_data(:)';
                cy = res(k).y_data(:)';

                % Trim to [startIdx, endIdx]
                localStart = max(1, startIdx - res(k).pt_offset + 1);
                localEnd   = min(numel(cx), endIdx - res(k).pt_offset + 1);
                if localEnd < localStart; continue; end
                cx = cx(localStart:localEnd);
                cy = cy(localStart:localEnd);

                if isUpper; mask = cy > threshold;
                else;       mask = cy < threshold; end
                vxParts{k} = cx(mask);
                vyParts{k} = cy(mask);
            end
            violX = [vxParts{:}];
            violY = [vyParts{:}];
        end
    end

    methods (Static)
        function c = toCategorical(s)
            %TOCATEGORICAL Convert a codes+categories struct back to categorical.
            if ~isCategoricalStruct(s)
                error('FastPlotDataStore:badInput', ...
                    'Input must be a struct with ''codes'' and ''categories'' fields.');
            end
            catNames = s.categories(:)';
            if exist('categorical', 'class')
                c = categorical(catNames(s.codes), catNames);
            else
                c = catNames(s.codes);
            end
        end

        function c = fromCategorical(data)
            %FROMCATEGORICAL Convert a MATLAB categorical to codes+categories struct.
            if ~isa(data, 'categorical')
                error('FastPlotDataStore:badInput', ...
                    'Input must be a categorical array.');
            end
            catNames = categories(data);
            [~, codes] = ismember(cellstr(data), catNames);
            c = struct('codes', uint32(codes(:)'), 'categories', {catNames(:)'});
        end
    end

    methods (Access = public)
        function storeResolved(obj, resolvedTh, resolvedViol)
            %STORERESOLVED Cache pre-computed resolve() results in SQLite.
            %   ds.storeResolved(resolvedTh, resolvedViol) stores the
            %   threshold and violation struct arrays produced by
            %   Sensor.resolve() into the database for instant retrieval.
            if ~obj.UseSqlite; return; end
            obj.ensureOpen();
            mksqlite(obj.DbId, 'BEGIN TRANSACTION');
            try
                for i = 1:numel(resolvedTh)
                    th = resolvedTh(i);
                    mksqlite(obj.DbId, ...
                        'INSERT INTO resolved_thresholds VALUES (?,?,?,?,?,?,?,?)', ...
                        i, th.X, th.Y, th.Direction, th.Label, ...
                        th.Color, th.LineStyle, th.Value);
                end
                for i = 1:numel(resolvedViol)
                    v = resolvedViol(i);
                    mksqlite(obj.DbId, ...
                        'INSERT INTO resolved_violations VALUES (?,?,?,?,?)', ...
                        i, v.X, v.Y, v.Direction, v.Label);
                end
                mksqlite(obj.DbId, 'COMMIT');
            catch ME
                try mksqlite(obj.DbId, 'ROLLBACK'); catch; end
                rethrow(ME);
            end
            obj.closeDb();
        end

        function [resolvedTh, resolvedViol] = loadResolved(obj)
            %LOADRESOLVED Load pre-computed resolve() results from SQLite.
            %   Returns empty arrays if no cached results exist.
            resolvedTh = [];
            resolvedViol = [];
            if ~obj.UseSqlite; return; end
            obj.ensureOpen();
            rows = mksqlite(obj.DbId, ...
                'SELECT * FROM resolved_thresholds ORDER BY idx');
            if isempty(rows) || numel(rows) == 0; return; end
            for i = 1:numel(rows)
                r = rows(i);
                if isempty(r.x_data); th.X = [];
                else; th.X = r.x_data(:)'; end
                if isempty(r.y_data); th.Y = [];
                else; th.Y = r.y_data(:)'; end
                th.Direction = r.direction;
                th.Label = r.label;
                c = r.color;
                if isempty(c) || numel(c) == 0
                    th.Color = [];
                else
                    th.Color = c(:)';
                end
                th.LineStyle = r.line_style;
                th.Value = r.value;
                if isempty(resolvedTh)
                    resolvedTh = th;
                else
                    resolvedTh(end+1) = th;
                end
            end
            vrows = mksqlite(obj.DbId, ...
                'SELECT * FROM resolved_violations ORDER BY idx');
            for i = 1:numel(vrows)
                r = vrows(i);
                if isempty(r.x_data); v.X = [];
                else; v.X = r.x_data(:)'; end
                if isempty(r.y_data); v.Y = [];
                else; v.Y = r.y_data(:)'; end
                v.Direction = r.direction;
                v.Label = r.label;
                if isempty(resolvedViol)
                    resolvedViol = v;
                else
                    resolvedViol(end+1) = v;
                end
            end
        end

        function clearResolved(obj)
            %CLEARRESOLVED Invalidate pre-computed resolve() cache.
            if ~obj.UseSqlite; return; end
            obj.ensureOpen();
            mksqlite(obj.DbId, 'DELETE FROM resolved_thresholds');
            mksqlite(obj.DbId, 'DELETE FROM resolved_violations');
        end

        function cleanup(obj)
            %CLEANUP Close the database and delete temp files.
            obj.closeDb();
            if ~isempty(obj.DbPath) && exist(obj.DbPath, 'file')
                delete(obj.DbPath);
            end
            if ~isempty(obj.BinPath) && exist(obj.BinPath, 'file')
                delete(obj.BinPath);
            end
            obj.IsValid = false;
        end

        function delete(obj)
            obj.cleanup();
        end
    end

    methods (Access = private)
        function ensureOpen(obj)
            %ENSUREOPEN Reopen the SQLite connection if it was closed.
            if obj.DbOpen || ~obj.UseSqlite || isempty(obj.DbPath); return; end
            obj.DbId = mksqlite('open', obj.DbPath);
            mksqlite(obj.DbId, 'typedBLOBs', 2);
            mksqlite(obj.DbId, 'PRAGMA mmap_size = 268435456');
            obj.DbOpen = true;
        end

        function closeDb(obj)
            %CLOSEDB Close the SQLite connection to free the slot.
            if ~obj.DbOpen || obj.DbId < 0; return; end
            try mksqlite(obj.DbId, 'close'); catch; end
            obj.DbId = -1;
            obj.DbOpen = false;
        end

        function initSqlite(obj, x, y)
            obj.DbPath = [tempname, '.fpdb'];

            n = obj.NumPoints;
            % Auto-tune chunk size: aim for 500-2000 chunks to balance
            % granularity (zoom precision) vs overhead (chunk metadata).
            cs = max(10000, min(500000, ceil(n / 1000)));
            obj.ChunkSize = cs;
            obj.NumChunks = ceil(n / cs);

            % MEX fast path: single C call replaces ~20K mksqlite round-trips
            if exist('build_store_mex', 'file') == 3
                try
                    build_store_mex(obj.DbPath, x, y, cs);
                    obj.IsValid = true;
                    return;
                catch
                    % Fall through to MATLAB path
                    if exist(obj.DbPath, 'file'); delete(obj.DbPath); end
                end
            end

            % MATLAB fallback path (used when MEX not compiled)
            obj.DbId = mksqlite('open', obj.DbPath);
            obj.DbOpen = true;
            mksqlite(obj.DbId, 'typedBLOBs', 2);

            mksqlite(obj.DbId, 'PRAGMA journal_mode = OFF');
            mksqlite(obj.DbId, 'PRAGMA synchronous = OFF');
            mksqlite(obj.DbId, 'PRAGMA cache_size = -50000');
            mksqlite(obj.DbId, 'PRAGMA temp_store = MEMORY');
            mksqlite(obj.DbId, 'PRAGMA locking_mode = EXCLUSIVE');
            mksqlite(obj.DbId, 'PRAGMA page_size = 65536');
            mksqlite(obj.DbId, 'PRAGMA mmap_size = 268435456');

            mksqlite(obj.DbId, [...
                'CREATE TABLE chunks (' ...
                '  chunk_id INTEGER PRIMARY KEY,' ...
                '  x_min REAL NOT NULL,' ...
                '  x_max REAL NOT NULL,' ...
                '  y_min REAL NOT NULL,' ...
                '  y_max REAL NOT NULL,' ...
                '  pt_offset INTEGER NOT NULL,' ...
                '  pt_count INTEGER NOT NULL,' ...
                '  x_data BLOB NOT NULL,' ...
                '  y_data BLOB NOT NULL' ...
                ')']);

            % Pre-computed resolve() cache tables
            mksqlite(obj.DbId, [...
                'CREATE TABLE resolved_thresholds (' ...
                '  idx INTEGER PRIMARY KEY,' ...
                '  x_data BLOB,' ...
                '  y_data BLOB,' ...
                '  direction TEXT NOT NULL,' ...
                '  label TEXT NOT NULL,' ...
                '  color BLOB,' ...
                '  line_style TEXT NOT NULL,' ...
                '  value REAL NOT NULL' ...
                ')']);
            mksqlite(obj.DbId, [...
                'CREATE TABLE resolved_violations (' ...
                '  idx INTEGER PRIMARY KEY,' ...
                '  x_data BLOB,' ...
                '  y_data BLOB,' ...
                '  direction TEXT NOT NULL,' ...
                '  label TEXT NOT NULL' ...
                ')']);

            mksqlite(obj.DbId, 'BEGIN TRANSACTION');
            try
                chunkId = 0;
                for s = 1:cs:n
                    chunkId = chunkId + 1;
                    e = min(s + cs - 1, n);
                    cx = x(s:e);
                    cy = y(s:e);
                    mksqlite(obj.DbId, ...
                        'INSERT INTO chunks VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', ...
                        chunkId, cx(1), cx(end), min(cy), max(cy), ...
                        s, numel(cx), cx, cy);
                end

                % Build indexes inside the transaction while journal_mode=OFF
                mksqlite(obj.DbId, 'CREATE INDEX idx_xrange ON chunks (x_min, x_max)');
                mksqlite(obj.DbId, 'CREATE INDEX idx_ptoffset ON chunks (pt_offset)');
                mksqlite(obj.DbId, 'COMMIT');
            catch ME
                try mksqlite(obj.DbId, 'ROLLBACK'); catch; end
                obj.cleanup();
                rethrow(ME);
            end

            mksqlite(obj.DbId, 'ANALYZE');
            mksqlite(obj.DbId, 'PRAGMA journal_mode = DELETE');
            mksqlite(obj.DbId, 'PRAGMA synchronous = NORMAL');
            % Release exclusive lock so resolve_disk_mex can open a
            % concurrent read-only connection to this database file.
            mksqlite(obj.DbId, 'PRAGMA locking_mode = NORMAL');
            % A read must occur to actually release the EXCLUSIVE lock.
            mksqlite(obj.DbId, 'SELECT 1 FROM chunks LIMIT 1');
            obj.IsValid = true;
            % Close connection to free the mksqlite slot — reopened on demand
            obj.closeDb();
        end

        function [xOut, yOut] = getRangeSqlite(obj, xMin, xMax)
            % Fetch overlapping chunks plus one neighbour on each side
            % so that one-point padding is always available at boundaries.
            ids = mksqlite(obj.DbId, ...
                'SELECT chunk_id FROM chunks WHERE x_max >= ? AND x_min <= ?', ...
                xMin, xMax);
            if numel(ids) == 0; xOut = []; yOut = []; return; end
            lo = ids(1).chunk_id - 1;
            hi = ids(end).chunk_id + 1;
            res = mksqlite(obj.DbId, ...
                ['SELECT pt_count, x_data, y_data FROM chunks ' ...
                 'WHERE chunk_id BETWEEN ? AND ? ORDER BY chunk_id'], ...
                max(1, lo), hi);
            if numel(res) == 0; xOut = []; yOut = []; return; end

            [xAll, yAll] = concatChunks(res);
            iStart = bsearchLocal(xAll, xMin, 'left');
            iEnd   = bsearchLocal(xAll, xMax, 'right');
            [iStart, iEnd] = padClamp(iStart, iEnd, numel(xAll));
            xOut = xAll(iStart:iEnd);
            yOut = yAll(iStart:iEnd);
        end

        function [xOut, yOut] = readSliceSqlite(obj, startIdx, endIdx)
            res = mksqlite(obj.DbId, ...
                ['SELECT pt_offset, pt_count, x_data, y_data FROM chunks ' ...
                 'WHERE (pt_offset + pt_count - 1) >= ? AND pt_offset <= ? ' ...
                 'ORDER BY chunk_id'], ...
                startIdx, endIdx);
            if numel(res) == 0; xOut = []; yOut = []; return; end

            [xAll, yAll] = concatChunks(res);
            localStart = startIdx - res(1).pt_offset + 1;
            localEnd   = endIdx - res(1).pt_offset + 1;
            localStart = max(1, localStart);
            localEnd   = min(numel(xAll), localEnd);
            xOut = xAll(localStart:localEnd);
            yOut = yAll(localStart:localEnd);
        end

        function buildPyramidFromMemory(obj, x, y, R)
            %BUILDPYRAMIDFROMMEMORY Build L1 minmax pyramid while data is in memory.
            %   Avoids re-reading the entire dataset from disk on first render.
            %   Implements inline minmax downsampling (cannot call private/
            %   minmax_downsample from here).
            n = numel(x);
            nb = max(1, round(n / R));  % number of buckets
            if n <= 2 * nb
                % Too few points to downsample — store raw
                obj.PyramidX = x;
                obj.PyramidY = y;
                return;
            end

            bucketSize = floor(n / nb);
            usable = bucketSize * nb;
            yMat = reshape(y(1:usable), bucketSize, nb);

            [yMinVals, iMin] = min(yMat, [], 1);
            [yMaxVals, iMax] = max(yMat, [], 1);

            offsets = (0:nb-1) * bucketSize;
            gMin = iMin + offsets;
            gMax = iMax + offsets;

            % Fold remainder into last bucket
            if usable < n
                remY = y(usable+1:end);
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

            xMinVals = x(gMin);
            xMaxVals = x(gMax);

            % Interleave min/max in X-monotonic order
            minFirst = gMin <= gMax;
            px = zeros(1, 2*nb);
            py = zeros(1, 2*nb);
            odd  = 1:2:2*nb;
            even = 2:2:2*nb;

            px(odd(minFirst))   = xMinVals(minFirst);
            py(odd(minFirst))   = yMinVals(minFirst);
            px(even(minFirst))  = xMaxVals(minFirst);
            py(even(minFirst))  = yMaxVals(minFirst);

            px(odd(~minFirst))  = xMaxVals(~minFirst);
            py(odd(~minFirst))  = yMaxVals(~minFirst);
            px(even(~minFirst)) = xMinVals(~minFirst);
            py(even(~minFirst)) = yMinVals(~minFirst);

            obj.PyramidX = px;
            obj.PyramidY = py;
        end

        function initBinaryFallback(obj, x, y)
            obj.BinPath = [tempname, '.fpdat'];
            fid = fopen(obj.BinPath, 'wb');
            if fid == -1
                error('FastPlotDataStore:fileError', ...
                    'Cannot create temp file: %s', obj.BinPath);
            end
            try
                fwrite(fid, x, 'double');
                fwrite(fid, y, 'double');
                fclose(fid);
            catch ME
                fclose(fid);
                if exist(obj.BinPath, 'file'); delete(obj.BinPath); end
                rethrow(ME);
            end
            obj.IsValid = true;
        end

        function [xOut, yOut] = getRangeBinary(obj, xMin, xMax)
            if xMin > obj.XMax || xMax < obj.XMin
                xOut = []; yOut = [];
                return;
            end
            n = obj.NumPoints;
            fid = fopen(obj.BinPath, 'rb');

            % Binary search on disk: read only sampled X values to find
            % approximate bounds, then refine on a small neighbourhood.
            idxStart = bsearchBinaryFile(fid, n, xMin, 'left');
            idxEnd   = bsearchBinaryFile(fid, n, xMax, 'right');
            [idxStart, idxEnd] = padClamp(idxStart, idxEnd, n);

            count = idxEnd - idxStart + 1;
            fseek(fid, (idxStart - 1) * 8, 'bof');
            xOut = fread(fid, [1, count], 'double');
            fseek(fid, n * 8 + (idxStart - 1) * 8, 'bof');
            yOut = fread(fid, [1, count], 'double');
            fclose(fid);
        end

        function [xOut, yOut] = readSliceBinary(obj, startIdx, endIdx)
            fid = fopen(obj.BinPath, 'rb');
            if fid == -1
                error('FastPlotDataStore:fileError', ...
                    'Cannot read temp file: %s', obj.BinPath);
            end
            count = endIdx - startIdx + 1;
            try
                fseek(fid, (startIdx - 1) * 8, 'bof');
                xOut = fread(fid, [1, count], 'double');
                fseek(fid, obj.NumPoints * 8 + (startIdx - 1) * 8, 'bof');
                yOut = fread(fid, [1, count], 'double');
                fclose(fid);
            catch ME
                fclose(fid);
                rethrow(ME);
            end
        end
    end
end


function tf = isCategoricalStruct(data)
%ISCATEGORICALSTRUCT True if data is a struct with codes+categories fields.
    tf = isstruct(data) && isfield(data, 'codes') && isfield(data, 'categories');
end

function [xAll, yAll] = concatChunks(res)
%CONCATCHUNKS Concatenate x_data/y_data from query results.
%   Uses pre-allocated arrays when pt_count metadata is available.
    nRes = numel(res);
    if nRes == 1
        xAll = res(1).x_data(:)';
        yAll = res(1).y_data(:)';
    elseif isfield(res, 'pt_count')
        % Pre-allocate using known chunk sizes
        totalPts = sum([res.pt_count]);
        xAll = zeros(1, totalPts);
        yAll = zeros(1, totalPts);
        pos = 0;
        for k = 1:nRes
            chunk = res(k).x_data(:)';
            n = numel(chunk);
            xAll(pos+1:pos+n) = chunk;
            yAll(pos+1:pos+n) = res(k).y_data(:)';
            pos = pos + n;
        end
        if pos < totalPts
            xAll = xAll(1:pos);
            yAll = yAll(1:pos);
        end
    else
        xCells = cell(1, nRes);
        yCells = cell(1, nRes);
        for k = 1:nRes
            xCells{k} = res(k).x_data(:)';
            yCells{k} = res(k).y_data(:)';
        end
        xAll = [xCells{:}];
        yAll = [yCells{:}];
    end
end

function [iStart, iEnd] = padClamp(iStart, iEnd, n)
%PADCLAMP Add one-point padding and clamp to [1, n].
    iStart = max(1, iStart - 1);
    iEnd   = min(n, iEnd + 1);
end

function data = assembleColumnByOffset(res, startIdx, endIdx)
%ASSEMBLECOLUMNBYOFFSET Concatenate column chunks and trim by point offset.
    nRes = numel(res);
    if nRes == 1
        colAll = res(1).col_data;
        globalOffset = res(1).pt_offset;
    else
        colCells = cell(1, nRes);
        for k = 1:nRes
            colCells{k} = res(k).col_data;
        end
        colAll = concatColumnData(colCells);
        globalOffset = res(1).pt_offset;
    end
    localStart = max(1, startIdx - globalOffset + 1);
    localEnd   = min(columnLength(colAll), endIdx - globalOffset + 1);
    data = sliceColumnData(colAll, localStart, localEnd);
end

function n = columnLength(data)
    if isCategoricalStruct(data)
        n = numel(data.codes);
    else
        n = numel(data);
    end
end

function out = sliceColumnData(data, iStart, iEnd)
    if isCategoricalStruct(data)
        out = struct('codes', data.codes(iStart:iEnd), ...
                     'categories', {data.categories});
    else
        out = data(iStart:iEnd);
    end
end

function out = concatColumnData(cells)
    if isempty(cells); out = {}; return; end
    nCells = numel(cells);
    first = cells{1};
    if isCategoricalStruct(first)
        codeParts = cell(1, nCells);
        for k = 1:nCells
            codeParts{k} = cells{k}.codes(:)';
        end
        out = struct('codes', [codeParts{:}], 'categories', {first.categories});
    elseif iscell(first)
        parts = cell(1, nCells);
        for k = 1:nCells
            parts{k} = cells{k}(:)';
        end
        out = [parts{:}];
    else
        parts = cell(1, nCells);
        for k = 1:nCells
            parts{k} = cells{k}(:)';
        end
        out = [parts{:}];
    end
end

function idx = bsearchBinaryFile(fid, n, val, mode)
%BSEARCHBINARYFILE Binary search on a double array stored in a binary file.
%   Reads O(log n) individual values from disk instead of loading the
%   entire X array. fid must be an open file handle positioned at the
%   start of the X data (offset 0).
    if strcmp(mode, 'left')
        lo = 1; hi = n + 1;
        while lo < hi
            mid = floor((lo + hi) / 2);
            fseek(fid, (mid - 1) * 8, 'bof');
            v = fread(fid, 1, 'double');
            if v < val; lo = mid + 1; else; hi = mid; end
        end
        idx = min(lo, n);
    else
        lo = 0; hi = n;
        while lo < hi
            mid = ceil((lo + hi) / 2);
            fseek(fid, (mid - 1) * 8, 'bof');
            v = fread(fid, 1, 'double');
            if v > val; hi = mid - 1; else; lo = mid; end
        end
        idx = max(hi, 1);
    end
end

function idx = bsearchLocal(x, val, mode)
    n = numel(x);
    if n == 0; idx = 1; return; end
    if strcmp(mode, 'left')
        lo = 1; hi = n + 1;
        while lo < hi
            mid = floor((lo + hi) / 2);
            if x(mid) < val; lo = mid + 1; else; hi = mid; end
        end
        idx = min(lo, n);
    else
        lo = 0; hi = n;
        while lo < hi
            mid = ceil((lo + hi) / 2);
            if x(mid) > val; hi = mid - 1; else; lo = mid; end
        end
        idx = max(hi, 1);
    end
end
