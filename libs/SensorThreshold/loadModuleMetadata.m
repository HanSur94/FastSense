function registry = loadModuleMetadata(registry, metadataTable)
%LOADMODULEMETADATA Attach state channels from metadata table to sensors.
%   registry = loadModuleMetadata(registry, metadataTable) reads discrete
%   state signals from a MATLAB table, compresses them from dense to
%   sparse transitions, and attaches StateChannel objects to each sensor
%   in the registry whose Thresholds reference matching state column names.
%
%   metadataTable must be a MATLAB table with a 'Date' column (datetime)
%   and one or more state columns. The Date column is converted to
%   datenum for StateChannel timestamps. State columns can be numeric
%   or cell arrays of char.
%
%   Thresholds must be attached to sensors before calling this function.
%   Sensors with no thresholds are skipped. Thresholds with no condition
%   fields (unconditional) contribute no state keys. State keys not found
%   in the table columns are skipped silently.
%
%   Each sensor receives its own StateChannel instance (no shared
%   handles). Compressed data is cached so each column is processed once.
%
%   Returns the registry (handle) for chaining convenience. Sensors are
%   modified in-place via handle semantics.
%
%   See also loadModuleData, StateChannel, Threshold, Sensor.

    narginchk(2, 2);

    % --- Validate table input ---
    if ~istable(metadataTable)
        error('loadModuleMetadata:notTable', ...
            'Second argument must be a table, got %s.', class(metadataTable));
    end

    colNames = metadataTable.Properties.VariableNames;

    if ~ismember('Date', colNames)
        error('loadModuleMetadata:missingDate', ...
            'Metadata table must contain a ''Date'' column.');
    end

    % --- Get all sensors from registry ---
    allKeys = registry.keys();
    if isempty(allKeys)
        return;
    end

    % --- Extract timestamps (datetime -> datenum) ---
    X = datenum(metadataTable.Date);

    % --- State column names (everything except Date) ---
    stateCols = colNames(~strcmp(colNames, 'Date'));

    % --- Struct-based cache for compressed transitions (Octave-safe) ---
    cache = struct();

    % --- Attach state channels to each sensor ---
    for i = 1:numel(allKeys)
        s = registry.get(allKeys{i});

        % Skip sensors with no thresholds
        if isempty(s.Thresholds)
            continue;
        end

        % Collect unique state keys from all threshold conditions
        neededKeys = {};
        for r = 1:numel(s.Thresholds)
            condFields = s.Thresholds{r}.getConditionFields();
            neededKeys = [neededKeys; condFields(:)]; %#ok<AGROW>
        end
        neededKeys = unique(neededKeys);

        % Attach StateChannels for keys found in table columns
        for k = 1:numel(neededKeys)
            key = neededKeys{k};

            % Skip keys not in table
            if ~ismember(key, stateCols)
                continue;
            end

            % Compress on first access, cache for reuse
            if ~isfield(cache, key)
                colData = metadataTable.(key);
                % Table columns are column vectors — reshape to row
                colData = reshape(colData, 1, []);
                cache.(key) = compressTransitions(X, colData);
            end
            cached = cache.(key);

            % Create new StateChannel instance per sensor
            sc = StateChannel(key);
            sc.X = cached.X;
            sc.Y = cached.Y;
            s.addStateChannel(sc);
        end
    end
end

function result = compressTransitions(X, Y_dense)
%COMPRESSTRANSITIONS Compress dense state signal to sparse transitions.
%   result = compressTransitions(X, Y_dense) returns struct with fields
%   X and Y containing only the transition points (plus the first point).
%   Handles both numeric arrays and cell arrays of char.

    if iscell(Y_dense)
        cmp = ~strcmp(Y_dense(1:end-1), Y_dense(2:end));
        changes = [true, reshape(cmp, 1, [])];
    else
        changes = [true, reshape(diff(Y_dense) ~= 0, 1, [])];
    end

    % Ensure row orientation (1xN) per StateChannel contract
    result.X = reshape(X(changes), 1, []);
    result.Y = reshape(Y_dense(changes), 1, []);
end
