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
    end

    properties (Access = private)
        DbId         = -1
        ChunkSize    = 100000
        NumChunks    = 0
        IsValid      = false
        UseSqlite    = false
        ColumnNames  = {}
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
        end

        function [xOut, yOut] = getRange(obj, xMin, xMax)
            %GETRANGE Read data within an X range (with one-point padding).
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
            if ~obj.UseSqlite || ~obj.IsValid
                data = {};
                return;
            end
            res = mksqlite(obj.DbId, ...
                ['SELECT c.chunk_id, c.pt_offset, ch.x_data, c.col_data ' ...
                 'FROM columns c ' ...
                 'JOIN chunks ch ON c.chunk_id = ch.chunk_id ' ...
                 'WHERE c.col_name = ? AND ch.x_max >= ? AND ch.x_min <= ? ' ...
                 'ORDER BY c.chunk_id'], ...
                name, xMin, xMax);
            if numel(res) == 0; data = {}; return; end
            data = assembleColumnByRange(res, xMin, xMax);
        end

        function data = getColumnSlice(obj, name, startIdx, endIdx)
            %GETCOLUMNSLICE Read a column slice by point index range.
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
            if numel(res) == 0; data = {}; return; end
            data = assembleColumnByOffset(res, startIdx, endIdx);
        end

        function names = listColumns(obj)
            %LISTCOLUMNS Return names of all stored extra columns.
            names = obj.ColumnNames;
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
        function cleanup(obj)
            %CLEANUP Close the database and delete temp files.
            if obj.UseSqlite && obj.DbId >= 0
                try mksqlite(obj.DbId, 'close'); catch; end
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
            obj.cleanup();
        end
    end

    methods (Access = private)
        function initSqlite(obj, x, y)
            obj.DbPath = [tempname, '.fpdb'];
            obj.DbId = mksqlite('open', obj.DbPath);
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
                '  pt_offset INTEGER NOT NULL,' ...
                '  pt_count INTEGER NOT NULL,' ...
                '  x_data BLOB NOT NULL,' ...
                '  y_data BLOB NOT NULL' ...
                ')']);

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

            mksqlite(obj.DbId, 'CREATE INDEX idx_xrange ON chunks (x_min, x_max)');
            mksqlite(obj.DbId, 'ANALYZE');
            mksqlite(obj.DbId, 'PRAGMA journal_mode = DELETE');
            mksqlite(obj.DbId, 'PRAGMA synchronous = NORMAL');
            obj.IsValid = true;
        end

        function [xOut, yOut] = getRangeSqlite(obj, xMin, xMax)
            res = mksqlite(obj.DbId, ...
                ['SELECT x_data, y_data FROM chunks ' ...
                 'WHERE x_max >= ? AND x_min <= ? ORDER BY chunk_id'], ...
                xMin, xMax);
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
    nRes = numel(res);
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
end

function [iStart, iEnd] = padClamp(iStart, iEnd, n)
%PADCLAMP Add one-point padding and clamp to [1, n].
    iStart = max(1, iStart - 1);
    iEnd   = min(n, iEnd + 1);
end

function data = assembleColumnByRange(res, xMin, xMax)
%ASSEMBLECOLUMNBYRANGE Concatenate column chunks and trim by X range.
    nRes = numel(res);
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
    iStart = bsearchLocal(xAll, xMin, 'left');
    iEnd   = bsearchLocal(xAll, xMax, 'right');
    [iStart, iEnd] = padClamp(iStart, iEnd, numel(xAll));
    data = sliceColumnData(colAll, iStart, iEnd);
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
