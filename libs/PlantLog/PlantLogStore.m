classdef PlantLogStore < handle
%PLANTLOGSTORE In-memory store for imported plant-log entries.
%   s = PLANTLOGSTORE(sourceFile) creates an empty store. `sourceFile`
%   is an informational char/string path; the store does NOT read the
%   file (Phase 1030 owns the reader). Entries are inserted via
%   addEntries(...) in sorted-ascending-by-Timestamp order with dedup
%   on the composite key (Timestamp, RowHash).
%
%   PlantLogStore is independent of EventStore: no plant-log entry
%   ever crosses into EventStore.getEvents() (PLOG-ST-01).
%
%   Properties (SetAccess = private):
%     SourceFile  char — the path passed to the constructor
%
%   Methods:
%     addEntries(entries)          — append PlantLogEntry array OR struct array (auto-promoted)
%     mergeEntries(other)          — append every entry from another PlantLogStore
%     clear()                      — empty the store and reset id counter
%     entries = getEntries()       — all entries in sorted order
%     entries = getEntriesInRange(t0, t1)  — entries where Timestamp in [t0, t1]
%     n = getCount()               — number of stored entries
%
%   Static methods:
%     h = PlantLogStore.computeEntryHash(message, metadata)
%         — Delegates to private/computeRowHash. Exposed for tests and
%           for the Phase 1030 reader (compute hash without ctor cost).
%
%   Errors:
%     PlantLogStore:invalidInput    — sourceFile not char/string; non-numeric range; t0 > t1
%     PlantLogStore:typeMismatch    — addEntries / mergeEntries received wrong type
%     PlantLogStore:emptyEntry      — a struct in addEntries is missing Timestamp
%     PlantLogStore:unknownOption   — unrecognized varargin key
%
%   Example:
%     s = PlantLogStore('plant.csv');
%     s.addEntries([ ...
%         PlantLogEntry('Timestamp', datenum('2025-01-15 12:00'), 'Message', 'Pump on', 'Metadata', struct()), ...
%         PlantLogEntry('Timestamp', datenum('2025-01-15 12:05'), 'Message', 'Pump off', 'Metadata', struct())]);
%     s.getCount();                                            % 2
%     s.getEntriesInRange(datenum('2025-01-15'), datenum('2025-01-16'));
%
%   See also PlantLogEntry, EventStore.

    properties (SetAccess = private)
        SourceFile = ''
    end

    properties (Access = private)
        % entries_ holds the sorted-ascending-by-Timestamp PlantLogEntry array.
        % We default to [] (not PlantLogEntry.empty) because Octave does not
        % support the static `.empty` method on classdef value classes; every
        % code path that touches `[entries_.Timestamp]` is guarded by an
        % `isempty(obj.entries_)` check, so the [] default is safe on both
        % runtimes. Empty returns from getEntriesInRange also use [] for the
        % same reason.
        entries_  = []
        nextId_   = uint64(0)
    end

    methods
        function obj = PlantLogStore(sourceFile, varargin)
            %PLANTLOGSTORE Construct an empty store with an informational sourceFile.
            if nargin < 1
                error('PlantLogStore:invalidInput', ...
                    'PlantLogStore requires a sourceFile (char/string).');
            end
            if isstring(sourceFile)
                sourceFile = char(sourceFile);
            end
            if ~ischar(sourceFile)
                error('PlantLogStore:invalidInput', ...
                    'sourceFile must be char or string; got %s.', class(sourceFile));
            end
            obj.SourceFile = sourceFile;

            % Forward-compatibility: tolerate empty varargin; throw on any
            % unknown key. No public options exist in Phase 1029.
            if ~isempty(varargin)
                if mod(numel(varargin), 2) ~= 0
                    error('PlantLogStore:invalidInput', ...
                        'Name-value args must come in pairs; got %d.', numel(varargin));
                end
                for k = 1:2:numel(varargin)
                    error('PlantLogStore:unknownOption', ...
                        'Unknown option ''%s''. No options are defined in Phase 1029.', ...
                        char(varargin{k}));
                end
            end
        end

        function addEntries(obj, entries)
            %ADDENTRIES Append PlantLogEntry array OR struct array (auto-promoted).
            %   Dedup: any new entry whose (Timestamp, RowHash) matches an
            %   existing stored entry is SILENTLY SKIPPED (no error, no replace).
            %   Inserts preserve sorted-ascending-by-Timestamp invariant.
            %   Ids are assigned in input order ('plog_1', 'plog_2', ...).
            if isempty(entries)
                return;
            end

            % --- Auto-promote struct array -> PlantLogEntry array ---
            if isstruct(entries)
                promoted = [];
                for k = 1:numel(entries)
                    rowStruct = entries(k);
                    if ~isfield(rowStruct, 'Timestamp') || ...
                            isempty(rowStruct.Timestamp) || ...
                            ~isnumeric(rowStruct.Timestamp)
                        error('PlantLogStore:emptyEntry', ...
                            'Entry %d missing or invalid Timestamp.', k);
                    end
                    next_entry = PlantLogEntry(rowStruct);
                    if isempty(promoted)
                        promoted = next_entry;
                    else
                        promoted(end+1) = next_entry; %#ok<AGROW>
                    end
                end
                entries = promoted;
            end

            if ~isa(entries, 'PlantLogEntry')
                error('PlantLogStore:typeMismatch', ...
                    'addEntries expects PlantLogEntry array or struct array; got %s.', class(entries));
            end

            % --- Insert one at a time, with dedup + sorted insertion ---
            for k = 1:numel(entries)
                cand = entries(k);

                % Dedup check: scan for any existing entry with matching
                % (Timestamp, RowHash). Linear scan is fine for v3.1; plant
                % logs are O(1000s of entries). Filter by Timestamp equality
                % first, so the inner RowHash compare only runs for the
                % few entries sharing the candidate timestamp.
                if ~isempty(obj.entries_)
                    ts = [obj.entries_.Timestamp];
                    candTs = cand.Timestamp;
                    same = ts == candTs;
                    if any(same)
                        existing = obj.entries_(same);
                        isDup = false;
                        for di = 1:numel(existing)
                            if strcmp(existing(di).RowHash, cand.RowHash)
                                isDup = true;
                                break;
                            end
                        end
                        if isDup
                            continue;   % silent skip
                        end
                    end
                end

                % Assign id (only after dedup passes — no id-burn on dup)
                obj.nextId_ = obj.nextId_ + uint64(1);
                cand = cand.withId(sprintf('plog_%d', obj.nextId_));

                % Sorted insertion via binary_search('left')
                if isempty(obj.entries_)
                    obj.entries_ = cand;
                else
                    ts = [obj.entries_.Timestamp];
                    if cand.Timestamp >= ts(end)
                        obj.entries_(end+1) = cand;
                    else
                        ins = binary_search(ts, cand.Timestamp, 'left');
                        % binary_search('left') returns first idx where
                        % ts(idx) >= val. Insert cand BEFORE position ins.
                        obj.entries_ = [obj.entries_(1:ins-1), cand, obj.entries_(ins:end)];
                    end
                end
            end
        end

        function mergeEntries(obj, other)
            %MERGEENTRIES Append every entry from another PlantLogStore.
            if ~isa(other, 'PlantLogStore')
                error('PlantLogStore:typeMismatch', ...
                    'mergeEntries expects PlantLogStore; got %s.', class(other));
            end
            obj.addEntries(other.getEntries());
        end

        function clear(obj)
            %CLEAR Empty the store and reset the id counter.
            obj.entries_ = [];
            obj.nextId_  = uint64(0);
        end

        function entries = getEntries(obj)
            %GETENTRIES Return all stored entries in sorted order.
            entries = obj.entries_;
        end

        function entries = getEntriesInRange(obj, t0, t1)
            %GETENTRIESINRANGE Return entries with Timestamp in [t0, t1] inclusive.
            if ~isnumeric(t0) || ~isscalar(t0) || ~isnumeric(t1) || ~isscalar(t1)
                error('PlantLogStore:invalidInput', ...
                    't0 and t1 must be numeric scalars; got %s, %s.', class(t0), class(t1));
            end
            if t0 > t1
                error('PlantLogStore:invalidInput', ...
                    't0 (%g) must be <= t1 (%g).', t0, t1);
            end
            if isempty(obj.entries_)
                entries = [];
                return;
            end
            ts = [obj.entries_.Timestamp];
            lo = binary_search(ts, t0, 'left');   % first idx where ts(idx) >= t0
            hi = binary_search(ts, t1, 'right');  % last  idx where ts(idx) <= t1
            if lo > hi || ts(lo) > t1 || ts(hi) < t0
                entries = [];
                return;
            end
            entries = obj.entries_(lo:hi);
        end

        function n = getCount(obj)
            %GETCOUNT Return number of stored entries.
            n = numel(obj.entries_);
        end
    end

    methods (Static)
        function h = computeEntryHash(message, metadata)
            %COMPUTEENTRYHASH Hash entry point exposed for tests and Phase 1030.
            %   h = PlantLogStore.computeEntryHash(message, metadata)
            %   delegates to private/computeRowHash so callers can compute
            %   the dedup key without constructing a full PlantLogEntry.
            if nargin < 2
                metadata = struct();
            end
            tmp.Message  = message;
            tmp.Metadata = metadata;
            h = computeRowHash(tmp);
        end
    end
end
