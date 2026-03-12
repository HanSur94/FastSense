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
    %   These are stored as typed BLOBs in a separate 'columns' table and
    %   queried by the same chunk-based range mechanism.
    %
    %   Requires mksqlite (https://github.com/AnyBody-Research-Group/mksqlite).
    %   If mksqlite is not available, falls back to binary file storage
    %   (extra columns require mksqlite).
    %
    %   Usage:
    %     ds = FastPlotDataStore(x, y);
    %     [xVis, yVis] = ds.getRange(xMin, xMax);
    %     [xSlice, ySlice] = ds.readSlice(1000, 2000);
    %     n = ds.NumPoints;
    %
    %   Extra columns:
    %     ds.addColumn('labels', {'A','B','C',...});  % cell of strings
    %     ds.addColumn('flags', logical([1 0 1 ...])); % logical
    %     ds.addColumn('category', struct('codes',uint32([...]), ...
    %                   'categories',{{'low','mid','high'}})); % categorical
    %     vals = ds.getColumnRange('labels', xMin, xMax);
    %     vals = ds.getColumnSlice('labels', 1, 100);
    %     names = ds.listColumns();
    %
    %   Cleanup:
    %     Temp files are deleted automatically when the object is destroyed.
    %     Call ds.cleanup() to release resources early.
    %
    %   See also FastPlot, FastPlotDefaults, mksqlite.

    properties (SetAccess = private)
        NumPoints  = 0       % total number of data points stored
        XMin       = NaN     % first X value (data is sorted)
        XMax       = NaN     % last X value
        HasNaN     = false   % true if Y contains any NaN values
        DbPath     = ''      % path to temp SQLite database file (public for tests)
        BinPath    = ''      % path to temp binary file (public for tests)
    end

    properties (Access = private)
        DbId         = -1      % mksqlite database handle ID
        ChunkSize    = 100000  % points per chunk (~1.6 MB per chunk)
        NumChunks    = 0       % total number of stored chunks
        IsValid      = false   % true after successful write
        UseSqlite    = false   % true if mksqlite is available
        ColumnNames  = {}      % cell array of extra column names
    end

    methods (Access = public)
        function obj = FastPlotDataStore(x, y)
            %FASTPLOTDATASTORE Create a disk-backed store from X/Y arrays.
            %   ds = FASTPLOTDATASTORE(x, y) splits the data into chunks
            %   and stores each chunk as a typed BLOB in a temporary SQLite
            %   database. After construction, the caller can clear x and y
            %   from memory.
            %
            %   If mksqlite is not installed, falls back to binary file
            %   storage with sequential range scanning.
            %
            %   Inputs:
            %     x — 1-by-N sorted numeric row vector
            %     y — 1-by-N numeric row vector (same length as x)

            if nargin < 2
                return;
            end

            obj.NumPoints = numel(x);
            if obj.NumPoints == 0
                return;
            end

            % Force row vectors
            if ~isrow(x); x = x(:)'; end
            if ~isrow(y); y = y(:)'; end

            obj.XMin = x(1);
            obj.XMax = x(end);
            obj.HasNaN = any(isnan(y));

            % Check for mksqlite availability
            obj.UseSqlite = (exist('mksqlite', 'file') == 3);

            if obj.UseSqlite
                obj.initSqlite(x, y);
            else
                obj.initBinaryFallback(x, y);
            end
        end

        function [xOut, yOut] = getRange(obj, xMin, xMax)
            %GETRANGE Read data within an X range from the database.
            %   [xOut, yOut] = ds.GETRANGE(xMin, xMax) returns the portion
            %   of the dataset where xMin <= X <= xMax, plus one point of
            %   padding on each side for correct line rendering at edges.
            %
            %   Inputs:
            %     xMin — left boundary of visible range
            %     xMax — right boundary of visible range
            %
            %   Outputs:
            %     xOut — 1-by-M row vector of X values in range
            %     yOut — 1-by-M row vector of Y values in range

            if ~obj.IsValid || obj.NumPoints == 0
                xOut = []; yOut = [];
                return;
            end

            if obj.UseSqlite
                [xOut, yOut] = obj.getRangeSqlite(xMin, xMax);
            else
                [xOut, yOut] = obj.getRangeBinary(xMin, xMax);
            end
        end

        function [xOut, yOut] = readSlice(obj, startIdx, endIdx)
            %READSLICE Read a contiguous slice of data by row index.
            %   [xOut, yOut] = ds.READSLICE(startIdx, endIdx) reads data
            %   points from startIdx to endIdx (1-based, inclusive).
            %
            %   Inputs:
            %     startIdx — first point index (1-based)
            %     endIdx   — last point index (1-based)
            %
            %   Outputs:
            %     xOut — 1-by-M row vector
            %     yOut — 1-by-M row vector

            if ~obj.IsValid
                xOut = []; yOut = [];
                return;
            end

            startIdx = max(1, startIdx);
            endIdx   = min(obj.NumPoints, endIdx);

            if endIdx < startIdx
                xOut = []; yOut = [];
                return;
            end

            if obj.UseSqlite
                [xOut, yOut] = obj.readSliceSqlite(startIdx, endIdx);
            else
                count = endIdx - startIdx + 1;
                [xOut, yOut] = obj.readSliceBinary(startIdx, endIdx, count);
            end
        end

        function addColumn(obj, name, data)
            %ADDCOLUMN Store an extra data column alongside X/Y.
            %   ds.ADDCOLUMN(name, data) stores an additional column of
            %   arbitrary type (cell, char, string, logical, numeric,
            %   categorical struct) chunked in the same way as X/Y data.
            %
            %   The data length must match ds.NumPoints. Data is stored as
            %   typed BLOBs in a 'columns' table, enabling range queries.
            %
            %   Inputs:
            %     name — char; column name (must be unique)
            %     data — array or cell with NumPoints elements
            %
            %   Requires mksqlite (SQLite backend).

            if ~obj.UseSqlite
                error('FastPlotDataStore:noSqlite', ...
                    'addColumn requires mksqlite (SQLite backend).');
            end
            if ~obj.IsValid
                error('FastPlotDataStore:notValid', ...
                    'DataStore is not initialized.');
            end

            % Validate length
            if iscell(data)
                nData = numel(data);
            elseif isstruct(data) && isfield(data, 'codes')
                nData = numel(data.codes);
            else
                nData = numel(data);
            end
            if nData ~= obj.NumPoints
                error('FastPlotDataStore:sizeMismatch', ...
                    'Column data length (%d) must match NumPoints (%d).', ...
                    nData, obj.NumPoints);
            end

            % Create columns table if it doesn't exist yet
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

            % Check for duplicate
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
                    if iscell(data)
                        chunk = data(s:e);
                    elseif isstruct(data) && isfield(data, 'codes')
                        chunk = struct();
                        chunk.codes = data.codes(s:e);
                        chunk.categories = data.categories;
                    else
                        chunk = data(s:e);
                    end
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
            %   data = ds.GETCOLUMNRANGE(name, xMin, xMax) returns the
            %   column data for points within the visible X range.
            %   Uses the same chunk overlap query as getRange.
            %
            %   Inputs:
            %     name — char; column name
            %     xMin — left boundary of visible range
            %     xMax — right boundary of visible range
            %
            %   Output:
            %     data — column data for the matching range

            if ~obj.UseSqlite || ~obj.IsValid
                data = {};
                return;
            end

            % Get chunk IDs that overlap the X range
            res = mksqlite(obj.DbId, ...
                ['SELECT c.chunk_id, c.pt_offset, ch.x_data, c.col_data ' ...
                 'FROM columns c ' ...
                 'JOIN chunks ch ON c.chunk_id = ch.chunk_id ' ...
                 'WHERE c.col_name = ? AND ch.x_max >= ? AND ch.x_min <= ? ' ...
                 'ORDER BY c.chunk_id'], ...
                name, xMin, xMax);

            if numel(res) == 0
                data = {};
                return;
            end

            data = obj.assembleColumnRange(res, xMin, xMax);
        end

        function data = getColumnSlice(obj, name, startIdx, endIdx)
            %GETCOLUMNSLICE Read a column slice by point index range.
            %   data = ds.GETCOLUMNSLICE(name, startIdx, endIdx) returns
            %   column data for points from startIdx to endIdx (1-based).
            %
            %   Inputs:
            %     name     — char; column name
            %     startIdx — first point index (1-based)
            %     endIdx   — last point index (1-based)
            %
            %   Output:
            %     data — column data for the slice

            if ~obj.UseSqlite || ~obj.IsValid
                data = {};
                return;
            end

            startIdx = max(1, startIdx);
            endIdx   = min(obj.NumPoints, endIdx);

            res = mksqlite(obj.DbId, ...
                ['SELECT pt_offset, pt_count, col_data FROM columns ' ...
                 'WHERE col_name = ? AND (pt_offset + pt_count - 1) >= ? ' ...
                 'AND pt_offset <= ? ORDER BY chunk_id'], ...
                name, startIdx, endIdx);

            if numel(res) == 0
                data = {};
                return;
            end

            data = obj.assembleColumnSlice(res, startIdx, endIdx);
        end

        function names = listColumns(obj)
            %LISTCOLUMNS Return names of all stored extra columns.
            names = obj.ColumnNames;
        end

        function cleanup(obj)
            %CLEANUP Close the database and delete temp files.
            if obj.UseSqlite && obj.DbId >= 0
                try
                    mksqlite(obj.DbId, 'close');
                catch
                end
                obj.DbId = -1;
            end
            if ~isempty(obj.DbPath) && exist(obj.DbPath, 'file')
                delete(obj.DbPath);
            end
            if ~isempty(obj.BinPath) && exist(obj.BinPath, 'file')
                delete(obj.BinPath);
            end
            obj.IsValid = false;
        end

        function delete(obj)
            %DELETE Destructor — ensures database and temp file cleanup.
            obj.cleanup();
        end
    end

    % ====================== SQLITE METHODS ==============================
    methods (Access = private)
        function initSqlite(obj, x, y)
            %INITSQLITE Create temp SQLite DB and bulk-insert chunked BLOBs.
            obj.DbPath = [tempname, '.fpdb'];
            obj.DbId = mksqlite('open', obj.DbPath);

            % Enable typed BLOBs: stores MATLAB arrays natively in SQLite
            mksqlite(obj.DbId, 'typedBLOBs', 2);

            % Performance pragmas for fast bulk insert
            mksqlite(obj.DbId, 'PRAGMA journal_mode = OFF');
            mksqlite(obj.DbId, 'PRAGMA synchronous = OFF');
            mksqlite(obj.DbId, 'PRAGMA cache_size = -50000');
            mksqlite(obj.DbId, 'PRAGMA temp_store = MEMORY');
            mksqlite(obj.DbId, 'PRAGMA locking_mode = EXCLUSIVE');

            % Create table: each row holds one chunk of data as BLOBs
            mksqlite(obj.DbId, [...
                'CREATE TABLE chunks (' ...
                '  chunk_id INTEGER PRIMARY KEY,' ...
                '  x_min REAL NOT NULL,' ...
                '  x_max REAL NOT NULL,' ...
                '  pt_offset INTEGER NOT NULL,' ...
                '  pt_count INTEGER NOT NULL,' ...
                '  x_data BLOB NOT NULL,' ...
                '  y_data BLOB NOT NULL' ...
                ')']);

            % Split data into chunks and insert in a single transaction
            n = obj.NumPoints;
            cs = obj.ChunkSize;
            obj.NumChunks = ceil(n / cs);

            mksqlite(obj.DbId, 'BEGIN TRANSACTION');
            try
                chunkId = 0;
                for s = 1:cs:n
                    chunkId = chunkId + 1;
                    e = min(s + cs - 1, n);
                    cx = x(s:e);
                    cy = y(s:e);
                    mksqlite(obj.DbId, ...
                        'INSERT INTO chunks VALUES (?, ?, ?, ?, ?, ?, ?)', ...
                        chunkId, cx(1), cx(end), s, numel(cx), cx, cy);
                end
                mksqlite(obj.DbId, 'COMMIT');
            catch ME
                try mksqlite(obj.DbId, 'ROLLBACK'); catch; end
                obj.cleanup();
                rethrow(ME);
            end

            % Create index on X range for fast overlap queries
            mksqlite(obj.DbId, ...
                'CREATE INDEX idx_xrange ON chunks (x_min, x_max)');

            % Switch to read-optimized settings
            mksqlite(obj.DbId, 'PRAGMA journal_mode = DELETE');
            mksqlite(obj.DbId, 'PRAGMA synchronous = NORMAL');

            obj.IsValid = true;
        end

        function [xOut, yOut] = getRangeSqlite(obj, xMin, xMax)
            %GETRANGESQLITE Query chunks overlapping the visible X range.

            % Find overlapping chunks: chunk.x_max >= xMin AND chunk.x_min <= xMax
            res = mksqlite(obj.DbId, ...
                ['SELECT x_data, y_data FROM chunks ' ...
                 'WHERE x_max >= ? AND x_min <= ? ORDER BY chunk_id'], ...
                xMin, xMax);

            nRes = numel(res);
            if nRes == 0
                xOut = []; yOut = [];
                return;
            end

            % Concatenate chunk data
            if nRes == 1
                xAll = res(1).x_data(:)';
                yAll = res(1).y_data(:)';
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

            % Trim to exact range with one-point padding
            iStart = bsearchLocal(xAll, xMin, 'left');
            iEnd   = bsearchLocal(xAll, xMax, 'right');
            iStart = max(1, iStart - 1);
            iEnd   = min(numel(xAll), iEnd + 1);
            xOut = xAll(iStart:iEnd);
            yOut = yAll(iStart:iEnd);
        end

        function [xOut, yOut] = readSliceSqlite(obj, startIdx, endIdx)
            %READSLICESQLITE Read a slice by point offset range.

            % Find chunks containing the requested point range
            res = mksqlite(obj.DbId, ...
                ['SELECT pt_offset, pt_count, x_data, y_data FROM chunks ' ...
                 'WHERE (pt_offset + pt_count - 1) >= ? AND pt_offset <= ? ' ...
                 'ORDER BY chunk_id'], ...
                startIdx, endIdx);

            nRes = numel(res);
            if nRes == 0
                xOut = []; yOut = [];
                return;
            end

            % Concatenate and extract the exact slice
            if nRes == 1
                xAll = res(1).x_data(:)';
                yAll = res(1).y_data(:)';
                localStart = startIdx - res(1).pt_offset + 1;
                localEnd   = endIdx - res(1).pt_offset + 1;
                localStart = max(1, localStart);
                localEnd   = min(numel(xAll), localEnd);
                xOut = xAll(localStart:localEnd);
                yOut = yAll(localStart:localEnd);
            else
                xCells = cell(1, nRes);
                yCells = cell(1, nRes);
                for k = 1:nRes
                    xCells{k} = res(k).x_data(:)';
                    yCells{k} = res(k).y_data(:)';
                end
                xAll = [xCells{:}];
                yAll = [yCells{:}];
                globalOffset = res(1).pt_offset;
                localStart = startIdx - globalOffset + 1;
                localEnd   = endIdx - globalOffset + 1;
                localStart = max(1, localStart);
                localEnd   = min(numel(xAll), localEnd);
                xOut = xAll(localStart:localEnd);
                yOut = yAll(localStart:localEnd);
            end
        end
    end

    % =================== COLUMN HELPERS ==================================
    methods (Access = private)
        function data = assembleColumnRange(obj, res, xMin, xMax)
            %ASSEMBLECOLUMNRANGE Concatenate column chunks for a range query.
            nRes = numel(res);

            % Get the X data to find exact trim indices
            if nRes == 1
                xAll = res(1).x_data(:)';
                colAll = res(1).col_data;
            else
                xCells = cell(1, nRes);
                colCells = cell(1, nRes);
                for k = 1:nRes
                    xCells{k} = res(k).x_data(:)';
                    colCells{k} = res(k).col_data;
                end
                xAll = [xCells{:}];
                colAll = concatColumnData(colCells);
            end

            % Trim to range with padding
            iStart = bsearchLocal(xAll, xMin, 'left');
            iEnd   = bsearchLocal(xAll, xMax, 'right');
            iStart = max(1, iStart - 1);
            iEnd   = min(numel(xAll), iEnd + 1);

            data = sliceColumnData(colAll, iStart, iEnd);
        end

        function data = assembleColumnSlice(~, res, startIdx, endIdx)
            %ASSEMBLECOLUMNSLICE Concatenate column chunks for a slice query.
            nRes = numel(res);

            if nRes == 1
                colAll = res(1).col_data;
                localStart = startIdx - res(1).pt_offset + 1;
                localEnd   = endIdx - res(1).pt_offset + 1;
                nTotal = columnLength(colAll);
                localStart = max(1, localStart);
                localEnd   = min(nTotal, localEnd);
                data = sliceColumnData(colAll, localStart, localEnd);
            else
                colCells = cell(1, nRes);
                for k = 1:nRes
                    colCells{k} = res(k).col_data;
                end
                colAll = concatColumnData(colCells);
                globalOffset = res(1).pt_offset;
                localStart = startIdx - globalOffset + 1;
                localEnd   = endIdx - globalOffset + 1;
                nTotal = columnLength(colAll);
                localStart = max(1, localStart);
                localEnd   = min(nTotal, localEnd);
                data = sliceColumnData(colAll, localStart, localEnd);
            end
        end
    end

    % =================== BINARY FILE FALLBACK ===========================
    methods (Access = private)
        function initBinaryFallback(obj, x, y)
            %INITBINARYFALLBACK Write data to a temp binary file.

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
            %GETRANGEBINARY Range query on binary file.

            % Quick range-overlap check before reading
            if xMin > obj.XMax || xMax < obj.XMin
                xOut = []; yOut = [];
                return;
            end

            % Read full X to find indices, then only the Y slice
            fid = fopen(obj.BinPath, 'rb');
            allX = fread(fid, [1, obj.NumPoints], 'double');

            idxStart = bsearchLocal(allX, xMin, 'left');
            idxEnd   = bsearchLocal(allX, xMax, 'right');
            idxStart = max(1, idxStart - 1);
            idxEnd   = min(obj.NumPoints, idxEnd + 1);

            xOut = allX(idxStart:idxEnd);
            clear allX;

            count = idxEnd - idxStart + 1;
            fseek(fid, obj.NumPoints * 8 + (idxStart - 1) * 8, 'bof');
            yOut = fread(fid, [1, count], 'double');
            fclose(fid);
        end

        function [xOut, yOut] = readSliceBinary(obj, startIdx, endIdx, count)
            %READSLICEBINARY Read a slice from binary file by index.
            fid = fopen(obj.BinPath, 'rb');
            if fid == -1
                error('FastPlotDataStore:fileError', ...
                    'Cannot read temp file: %s', obj.BinPath);
            end
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

% ========================= LOCAL HELPERS ================================

function n = columnLength(data)
%COLUMNLENGTH Return the number of elements in a column data chunk.
    if iscell(data)
        n = numel(data);
    elseif isstruct(data) && isfield(data, 'codes')
        n = numel(data.codes);
    else
        n = numel(data);
    end
end

function out = sliceColumnData(data, iStart, iEnd)
%SLICECOLUMNDATA Extract a sub-range from column data.
    if iscell(data)
        out = data(iStart:iEnd);
    elseif isstruct(data) && isfield(data, 'codes')
        out = struct();
        out.codes = data.codes(iStart:iEnd);
        out.categories = data.categories;
    elseif ischar(data)
        % char vector: slice directly
        out = data(iStart:iEnd);
    else
        out = data(iStart:iEnd);
    end
end

function out = concatColumnData(cells)
%CONCATCOLUMNDATA Concatenate multiple column chunks.
    if isempty(cells)
        out = {};
        return;
    end
    first = cells{1};
    if iscell(first)
        out = {};
        for k = 1:numel(cells)
            out = [out, cells{k}(:)'];  %#ok<AGROW>
        end
    elseif isstruct(first) && isfield(first, 'codes')
        codes = [];
        for k = 1:numel(cells)
            codes = [codes, cells{k}.codes(:)'];  %#ok<AGROW>
        end
        out = struct();
        out.codes = codes;
        out.categories = first.categories;
    elseif ischar(first)
        out = '';
        for k = 1:numel(cells)
            out = [out, cells{k}(:)'];  %#ok<AGROW>
        end
    elseif islogical(first)
        out = logical([]);
        for k = 1:numel(cells)
            out = [out, cells{k}(:)'];  %#ok<AGROW>
        end
    else
        out = [];
        for k = 1:numel(cells)
            out = [out, cells{k}(:)'];  %#ok<AGROW>
        end
    end
end

function idx = bsearchLocal(x, val, mode)
%BSEARCHLOCAL Binary search on a sorted vector.
%   idx = BSEARCHLOCAL(x, val, 'left')  — first index where x(idx) >= val
%   idx = BSEARCHLOCAL(x, val, 'right') — last index where x(idx) <= val
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
