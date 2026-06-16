classdef CanonicalMapper < handle
    %CANONICALMAPPER Toolbox-free canonical sensor mapping with confidence + unit checks.
    %   CanonicalMapper auto-suggests a canonical mapping from per-machine local sensor
    %   keys to shared logical sensor names, using only toolbox-free string primitives
    %   (hand-rolled Wagner-Fischer edit distance + normalization). Every mapping entry
    %   carries a confidence level (HIGH/MEDIUM/LOW) and a unit-consistency flag, so a
    %   wrong cross-machine comparison cannot happen silently.
    %
    %   The class is a PURE DATA MODEL (no UI). The companion review/edit surface is
    %   the standalone CanonicalMapEditor window (Phase 1041 Plan 04).
    %
    %   Usage:
    %     m = CanonicalMapper();
    %     tagInfos = { ...
    %         struct('machineId','M01','localKey','temp_motor','name','Motor Temp','units','degC'), ...
    %         struct('machineId','M02','localKey','temp_mtor', 'name','Temp Mtor', 'units','degC') };
    %     m.suggest(tagInfos);
    %     pending = m.reviewPending();        % entries needing human review
    %     leftover = m.unmapped('M02');       % keys with no mapping
    %
    %   Properties (read-only):
    %     Entries_       containers.Map(logicalId -> cell of entry structs)
    %     LastTagInfos_  the tag-info cell from the most recent suggest()
    %
    %   Methods:
    %     suggest        - auto-suggest mappings from a cell of tag-info structs (CANON-01/02)
    %     override       - force a (logicalId,machineId)->localKey mapping (CANON-03)
    %     confirm        - endorse an auto-suggested entry (CANON-03)
    %     reviewPending  - entries needing review: LOW confidence or unit mismatch (CANON-04)
    %     unmapped       - a machine's local keys that landed in no cluster (CANON-04)
    %     isResolvable   - whether a (logicalId,machineId) entry is safe to compare (CANON-04)
    %     toStruct/fromStruct - serialization round-trip (CANON-03)
    %     save/load      - atomic JSON persistence (CANON-03)
    %
    %   Each entry struct has the fields:
    %     logicalId machineId localKey localName localUnits similarity confidence status unitMismatch
    %   where confidence is 'HIGH'|'MEDIUM'|'LOW' and status is 'AUTO'|'CONFIRMED'|'OVERRIDDEN'|'PENDING'.
    %
    %   Algorithm (seed-then-assign clustering):
    %     - Seeds: cross-machine key pairs with similarity >= MEDIUM_THRESHOLD_ (0.60) group
    %       (single-link). The centroid is the longest normalized key (tie -> lexicographically
    %       smallest); logicalId = that normalized centroid key.
    %     - Attach: a leftover key attaches to the nearest seed centroid only if its similarity
    %       to that centroid is >= ATTACH_THRESHOLD_ (0.15); below that it stays unmapped. With
    %       zero seed clusters nothing attaches.
    %     - Confidence is scored per member against the centroid (sim>=0.90 HIGH, >=0.60 MEDIUM,
    %       else LOW), so a distant attached member is correctly LOW.
    %     - Unit consistency: canonical unit = first HIGH member's unit; a member whose non-empty
    %       unit differs (case-insensitive) is flagged unitMismatch and downgraded one level.
    %
    %   See also CanonicalMapEditor, Machine, Fleet.

    properties (SetAccess = private)
        Entries_        % containers.Map('KeyType','char','ValueType','any'); value = cell of entry structs
        LastTagInfos_ = {}   % cell of the tag-info structs from the most recent suggest()
    end

    properties (Constant, Access = private)
        HIGH_THRESHOLD_   = 0.90    % sim >= 0.90 -> HIGH
        MEDIUM_THRESHOLD_ = 0.60    % sim >= 0.60 -> MEDIUM (and the seed grouping threshold)
        ATTACH_THRESHOLD_ = 0.15    % leftover attaches to nearest centroid only if sim >= this
    end

    methods
        function obj = CanonicalMapper()
            %CANONICALMAPPER Construct an empty mapper.
            obj.Entries_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.LastTagInfos_ = {};
        end

        function suggest(obj, tagInfos)
            %SUGGEST Auto-suggest canonical mappings from a cell of tag-info structs.
            %   tagInfos{k} = struct('machineId',char,'localKey',char,'name',char,'units',char).
            %   Populates Entries_(logicalId) = {entry,...}. Existing non-AUTO entries
            %   (OVERRIDDEN/CONFIRMED) are preserved (precedence over auto-suggestions).
            if ~iscell(tagInfos)
                error('CanonicalMapper:invalidInput', ...
                    'suggest expects a cell array of tag-info structs.');
            end
            n = numel(tagInfos);
            infos = cell(1, n);
            for k = 1:n
                t = tagInfos{k};
                if ~isstruct(t) || ~isfield(t, 'machineId') || ~isfield(t, 'localKey') ...
                        || ~isfield(t, 'name')
                    error('CanonicalMapper:invalidInput', ...
                        'each tag-info must be a struct with fields machineId, localKey, name.');
                end
                if ~isfield(t, 'units')
                    t.units = '';
                end
                infos{k} = t;
            end
            obj.LastTagInfos_ = tagInfos;

            % Preserve non-AUTO entries (overrides/confirmations) across re-suggest.
            kept = obj.collectNonAuto_();
            keptKeys = cell(1, numel(kept));
            for q = 1:numel(kept)
                keptKeys{q} = [kept{q}.logicalId '||' kept{q}.machineId];
            end

            % ---- Step A: seed clusters (single-link union over cross-machine pairs >= MEDIUM) ----
            parent = 1:n;
            for i = 1:n
                for j = i + 1:n
                    if strcmp(infos{i}.machineId, infos{j}.machineId)
                        continue;
                    end
                    s = similarity_(infos{i}.localKey, infos{j}.localKey);
                    if s >= obj.MEDIUM_THRESHOLD_ - 1e-12
                        ri = findRoot_(parent, i);
                        rj = findRoot_(parent, j);
                        if ri ~= rj
                            parent(rj) = ri;
                        end
                    end
                end
            end
            roots = zeros(1, n);
            for i = 1:n
                roots(i) = findRoot_(parent, i);
            end

            % Seed clusters = components with >= 2 members (they span >= 2 machines by construction).
            uniqueRoots = unique(roots);
            seedRoots = uniqueRoots(arrayfun(@(r) sum(roots == r) >= 2, uniqueRoots));
            nSeed = numel(seedRoots);

            % Centroid (longest key; tie -> lexicographically smallest normalized) and logicalId per seed.
            centroidKey = cell(1, nSeed);
            logicalId = cell(1, nSeed);
            for c = 1:nSeed
                members = find(roots == seedRoots(c));
                lk = cell(1, numel(members));
                for mi = 1:numel(members)
                    lk{mi} = infos{members(mi)}.localKey;
                end
                ci = pickCentroid_(lk);
                centroidKey{c} = lk{ci};
                logicalId{c} = normalize_(centroidKey{c});
            end

            % Assign each info to a cluster: seed membership first, then nearest-centroid attach.
            assign = zeros(1, n);
            for i = 1:n
                sc = find(seedRoots == roots(i), 1);
                if ~isempty(sc)
                    assign(i) = sc;
                end
            end
            for i = 1:n
                if assign(i) ~= 0
                    continue;
                end
                bestC = 0;
                bestSim = -1;
                for c = 1:nSeed
                    s = similarity_(infos{i}.localKey, centroidKey{c});
                    if s > bestSim
                        bestSim = s;
                        bestC = c;
                    end
                end
                if bestC > 0 && bestSim >= obj.ATTACH_THRESHOLD_ - 1e-12
                    assign(i) = bestC;
                end
            end

            % Build AUTO entries per cluster; skip slots covered by a preserved non-AUTO entry.
            newMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for c = 1:nSeed
                lid = logicalId{c};
                memberIdx = find(assign == c);
                entries = {};
                for mi = 1:numel(memberIdx)
                    t = infos{memberIdx(mi)};
                    if any(strcmp([lid '||' t.machineId], keptKeys))
                        continue;   % a preserved override/confirmation owns this slot
                    end
                    s = similarity_(t.localKey, centroidKey{c});
                    entries{end + 1} = makeEntry_(lid, t, s, obj.assignConfidence_(s)); %#ok<AGROW>
                end
                % Canonical unit = first HIGH member's unit; flag + downgrade mismatches.
                canonicalUnits = '';
                for ei = 1:numel(entries)
                    if strcmp(entries{ei}.confidence, 'HIGH')
                        canonicalUnits = entries{ei}.localUnits;
                        break;
                    end
                end
                for ei = 1:numel(entries)
                    entries{ei} = applyUnitDowngrade_(entries{ei}, canonicalUnits); %#ok<AGROW>
                end
                if ~isempty(entries)
                    newMap(lid) = entries;
                end
            end

            % Re-insert preserved non-AUTO entries (creating their logicalId bucket if needed).
            for q = 1:numel(kept)
                e = kept{q};
                if isKey(newMap, e.logicalId)
                    bucket = newMap(e.logicalId);
                else
                    bucket = {};
                end
                bucket{end + 1} = e; %#ok<AGROW>
                newMap(e.logicalId) = bucket;
            end

            obj.Entries_ = newMap;
        end

        function override(obj, logicalId, machineId, localKey)
            %OVERRIDE Force a (logicalId,machineId)->localKey mapping (CANON-03).
            %   The entry is marked OVERRIDDEN with HIGH confidence and takes precedence:
            %   a subsequent suggest() will not replace it.
            if ~ischar(logicalId) || isempty(logicalId) ...
                    || ~ischar(machineId) || isempty(machineId) ...
                    || ~ischar(localKey) || isempty(localKey)
                error('CanonicalMapper:invalidInput', ...
                    'override requires non-empty char logicalId, machineId, localKey.');
            end
            localName = '';
            localUnits = '';
            for k = 1:numel(obj.LastTagInfos_)
                t = obj.LastTagInfos_{k};
                if strcmp(t.machineId, machineId) && strcmp(t.localKey, localKey)
                    localName = t.name;
                    if isfield(t, 'units')
                        localUnits = t.units;
                    end
                    break;
                end
            end
            e = struct( ...
                'logicalId',    logicalId, ...
                'machineId',    machineId, ...
                'localKey',     localKey, ...
                'localName',    localName, ...
                'localUnits',   localUnits, ...
                'similarity',   1.0, ...
                'confidence',   'HIGH', ...
                'status',       'OVERRIDDEN', ...
                'unitMismatch', false);
            obj.upsertEntry_(e);
        end

        function confirm(obj, logicalId, machineId)
            %CONFIRM Endorse an auto-suggested entry (status -> CONFIRMED; confidence kept).
            if ~isKey(obj.Entries_, logicalId)
                error('CanonicalMapper:unknownLogicalId', ...
                    'No logical sensor "%s".', logicalId);
            end
            bucket = obj.Entries_(logicalId);
            for i = 1:numel(bucket)
                if strcmp(bucket{i}.machineId, machineId)
                    bucket{i}.status = 'CONFIRMED';
                    obj.Entries_(logicalId) = bucket;
                    return;
                end
            end
            error('CanonicalMapper:unknownMachine', ...
                'No entry for machine "%s" under "%s".', machineId, logicalId);
        end

        function pending = reviewPending(obj)
            %REVIEWPENDING Entries needing human review (CANON-04).
            %   An entry is pending iff it is a LOW-confidence AUTO entry OR has a unit
            %   mismatch. This is the gate Phase 1045 uses to keep unreviewed (possibly
            %   wrong) matches out of comparison.
            pending = {};
            logIds = keys(obj.Entries_);
            for i = 1:numel(logIds)
                bucket = obj.Entries_(logIds{i});
                for j = 1:numel(bucket)
                    e = bucket{j};
                    % Vouched entries (CONFIRMED/OVERRIDDEN) are never pending — this keeps
                    % reviewPending aligned with isResolvable. An entry needs review when it
                    % is NOT user-vouched and carries a risk signal (LOW or unit mismatch).
                    isVouched = strcmp(e.status, 'CONFIRMED') || strcmp(e.status, 'OVERRIDDEN');
                    needsReview = ~isVouched ...
                        && (strcmp(e.confidence, 'LOW') || e.unitMismatch);
                    if needsReview
                        pending{end + 1} = e; %#ok<AGROW>
                    end
                end
            end
        end

        function e = resolve(obj, logicalId, machineId)
            %RESOLVE Return the mapping entry for (logicalId,machineId), or [] if none.
            %   e = resolve(logicalId, machineId)
            %
            %   Looks up the entry struct for the given logical-sensor / machine
            %   pair without any confidence gate or side effects (Entries_ and
            %   LastTagInfos_ are never mutated). This is the read seam Phase 1045
            %   resolves ONCE at compare-open time; the confidence gate lives in
            %   the dialog/helper layer (buildCompareResolution_), not here.
            %
            %   Returns the entry struct (fields: logicalId, machineId, localKey,
            %   localName, localUnits, similarity, confidence, status, unitMismatch)
            %   or [] when the logicalId is absent or no bucket entry matches machineId.
            e = [];
            if ~isKey(obj.Entries_, logicalId)
                return;
            end
            bucket = obj.Entries_(logicalId);
            for i = 1:numel(bucket)
                if strcmp(bucket{i}.machineId, machineId)
                    e = bucket{i};
                    return;
                end
            end
        end

        function ids = logicalIds(obj)
            %LOGICALIDS Cellstr of all mapped logical-sensor ids (map keys).
            %   ids = logicalIds()
            %
            %   Public accessor over Entries_ so callers (e.g. the Phase 1045
            %   compare builder's quick-fill dropdown) do not poke the private
            %   containers.Map storage shape. Mirrors the Fleet.machineIds()
            %   seam. Order is containers.Map key order (lexicographic).
            ids = keys(obj.Entries_);
        end

        function ok = isResolvable(obj, logicalId, machineId)
            %ISRESOLVABLE Whether a (logicalId,machineId) entry is safe to compare (CANON-04).
            %   False for LOW+AUTO entries and for unconfirmed unit mismatches; true otherwise.
            ok = false;
            if ~isKey(obj.Entries_, logicalId)
                return;
            end
            bucket = obj.Entries_(logicalId);
            for i = 1:numel(bucket)
                e = bucket{i};
                if strcmp(e.machineId, machineId)
                    isBlocked = (strcmp(e.status, 'AUTO') && strcmp(e.confidence, 'LOW')) ...
                        || (e.unitMismatch && ~strcmp(e.status, 'CONFIRMED') ...
                            && ~strcmp(e.status, 'OVERRIDDEN'));
                    ok = ~isBlocked;
                    return;
                end
            end
        end

        function leftover = unmapped(obj, machineId)
            %UNMAPPED Local keys for machineId from the last suggest() that landed in no cluster.
            %   Returns a cellstr (sorted ascending for determinism), or {} when all mapped.
            mapped = {};
            logIds = keys(obj.Entries_);
            for i = 1:numel(logIds)
                bucket = obj.Entries_(logIds{i});
                for j = 1:numel(bucket)
                    if strcmp(bucket{j}.machineId, machineId)
                        mapped{end + 1} = bucket{j}.localKey; %#ok<AGROW>
                    end
                end
            end
            leftover = {};
            for k = 1:numel(obj.LastTagInfos_)
                t = obj.LastTagInfos_{k};
                if strcmp(t.machineId, machineId) && ~any(strcmp(t.localKey, mapped))
                    leftover{end + 1} = t.localKey; %#ok<AGROW>
                end
            end
            if ~isempty(leftover)
                leftover = unique(leftover);
            end
        end

        function s = toStruct(obj)
            %TOSTRUCT Serialize to a struct (version 1) with a flat cell of all entries.
            s.version = 1;
            entryList = {};
            logIds = keys(obj.Entries_);
            for i = 1:numel(logIds)
                bucket = obj.Entries_(logIds{i});
                for j = 1:numel(bucket)
                    entryList{end + 1} = bucket{j}; %#ok<AGROW>
                end
            end
            s.entries = entryList;
        end

        function save(obj, filepath)
            %SAVE Atomically write the mapper to JSON (per-entry encode + movefile).
            %   Never jsonencode the whole cell-of-structs directly (Pitfall 5): encode
            %   each entry and assemble the array, then write to a .tmp and movefile.
            s = obj.toStruct();
            nEntries = numel(s.entries);
            if nEntries == 0
                entriesJson = '[]';
            else
                parts = cell(1, nEntries);
                for i = 1:nEntries
                    parts{i} = jsonencode(s.entries{i});
                end
                entriesJson = ['[' strjoin(parts, ',') ']'];
            end
            json = sprintf('{"version":%d,"entries":%s}', s.version, entriesJson);
            tmp = [filepath '.tmp'];
            fid = fopen(tmp, 'w');
            if fid == -1
                error('CanonicalMapper:fileError', 'Cannot open file for writing: %s', tmp);
            end
            fwrite(fid, json);
            fclose(fid);
            try
                movefile(tmp, filepath, 'f');
            catch mvErr
                if exist(tmp, 'file') == 2
                    delete(tmp);   % don't leave an orphaned .tmp on a failed move
                end
                error('CanonicalMapper:fileError', ...
                    'Failed to save to %s: %s', filepath, mvErr.message);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            %FROMSTRUCT Rebuild a CanonicalMapper from a toStruct()/jsondecode() struct.
            obj = CanonicalMapper();
            if ~isfield(s, 'version') || s.version ~= 1
                warning('CanonicalMapper:unknownVersion', ...
                    'Unknown schema version; loading as v1.');
            end
            if ~isfield(s, 'entries')
                return;
            end
            entries = s.entries;
            if isstruct(entries)
                entries = normalizeToCell_(entries);   % jsondecode collapses homogeneous arrays
            end
            for i = 1:numel(entries)
                e = entries{i};
                if isKey(obj.Entries_, e.logicalId)
                    bucket = obj.Entries_(e.logicalId);
                else
                    bucket = {};
                end
                bucket{end + 1} = e; %#ok<AGROW>
                obj.Entries_(e.logicalId) = bucket;
            end
        end

        function obj = load(filepath)
            %LOAD Read a mapper from a JSON file written by save().
            if ~isfile(filepath)
                error('CanonicalMapper:fileNotFound', 'File not found: %s', filepath);
            end
            fid = fopen(filepath, 'r');
            if fid == -1
                error('CanonicalMapper:fileError', 'Cannot open file: %s', filepath);
            end
            raw = fread(fid, '*char')';
            fclose(fid);
            s = jsondecode(raw);
            obj = CanonicalMapper.fromStruct(s);
        end
    end

    methods (Access = private)
        function upsertEntry_(obj, e)
            %UPSERTENTRY_ Insert or replace the entry for (e.logicalId, e.machineId).
            if isKey(obj.Entries_, e.logicalId)
                bucket = obj.Entries_(e.logicalId);
            else
                bucket = {};
            end
            for i = 1:numel(bucket)
                if strcmp(bucket{i}.machineId, e.machineId)
                    bucket{i} = e;
                    obj.Entries_(e.logicalId) = bucket;
                    return;
                end
            end
            bucket{end + 1} = e;
            obj.Entries_(e.logicalId) = bucket;
        end

        function conf = assignConfidence_(obj, sim)
            %ASSIGNCONFIDENCE_ Map a similarity to a confidence level (inclusive boundaries).
            %   A 1e-12 tolerance protects the exact-boundary cases (e.g. 1-1/10 -> 0.90)
            %   from binary floating-point representation error without admitting genuinely
            %   sub-threshold values.
            if sim >= obj.HIGH_THRESHOLD_ - 1e-12
                conf = 'HIGH';
            elseif sim >= obj.MEDIUM_THRESHOLD_ - 1e-12
                conf = 'MEDIUM';
            else
                conf = 'LOW';
            end
        end

        function kept = collectNonAuto_(obj)
            %COLLECTNONAUTO_ Return a cell of all entries whose status is not 'AUTO'.
            %   These (OVERRIDDEN/CONFIRMED) survive a re-run of suggest().
            kept = {};
            ks = keys(obj.Entries_);
            for a = 1:numel(ks)
                bucket = obj.Entries_(ks{a});
                for b = 1:numel(bucket)
                    if ~strcmp(bucket{b}.status, 'AUTO')
                        kept{end + 1} = bucket{b}; %#ok<AGROW>
                    end
                end
            end
        end
    end

end

function r = findRoot_(parent, i)
    %FINDROOT_ Union-find root of index i in the parent array.
    r = i;
    while parent(r) ~= r
        r = parent(r);
    end
end

function idx = pickCentroid_(localKeys)
    %PICKCENTROID_ Index of the longest localKey; tie -> lexicographically smallest normalized.
    idx = 1;
    bestLen = numel(localKeys{1});
    bestNorm = normalize_(localKeys{1});
    for i = 2:numel(localKeys)
        thisLen = numel(localKeys{i});
        thisNorm = normalize_(localKeys{i});
        better = thisLen > bestLen || (thisLen == bestLen && lexLess_(thisNorm, bestNorm));
        if better
            idx = i;
            bestLen = thisLen;
            bestNorm = thisNorm;
        end
    end
end

function tf = lexLess_(a, b)
    %LEXLESS_ True if char row-vector a sorts strictly before b (lexicographic).
    if strcmp(a, b)
        tf = false;
        return;
    end
    ordered = sort({a, b});
    tf = strcmp(ordered{1}, a);
end

function e = makeEntry_(logicalId, t, sim, conf)
    %MAKEENTRY_ Build a fully-populated AUTO entry struct (Pattern 2 schema).
    e = struct( ...
        'logicalId',    logicalId, ...
        'machineId',    t.machineId, ...
        'localKey',     t.localKey, ...
        'localName',    t.name, ...
        'localUnits',   t.units, ...
        'similarity',   sim, ...
        'confidence',   conf, ...
        'status',       'AUTO', ...
        'unitMismatch', false);
end

function entry = applyUnitDowngrade_(entry, canonicalUnits)
    %APPLYUNITDOWNGRADE_ Flag a unit mismatch and cap confidence one level.
    %   Empty units on either side -> no info -> no mismatch, no downgrade.
    entry.unitMismatch = false;
    if isempty(entry.localUnits) || isempty(canonicalUnits)
        return;
    end
    if ~strcmp(lower(entry.localUnits), lower(canonicalUnits))   %#ok<STCI> case-insensitive, Octave-safe
        entry.unitMismatch = true;
        switch entry.confidence
            case 'HIGH'
                entry.confidence = 'MEDIUM';
            case 'MEDIUM'
                entry.confidence = 'LOW';
        end
    end
end

function c = normalizeToCell_(x)
    %NORMALIZETOCELL_ Normalize jsondecode output to a cell array.
    %   Ported verbatim from libs/Dashboard/private/normalizeToCell.m so Phase 1041
    %   carries no Dashboard dependency. jsondecode collapses a homogeneous JSON array
    %   of objects into a struct array; this restores consistent {i} cell indexing.
    if isempty(x)
        c = {};
    elseif isstruct(x)
        c = cell(1, numel(x));
        for k = 1:numel(x)
            c{k} = x(k);
        end
    else
        c = x;
    end
end

% ===================================================================
% Local functions (pure, toolbox-free, Octave-safe). Shared by the class
% methods. normalize_/editDistance_ use trailing-underscore names so the
% no-toolbox grep gate (which scans for the bare Statistics-Toolbox call
% name) does not trip on this private helper.
% ===================================================================

function key = normalize_(key)
    %NORMALIZE_ Canonicalize a key: lower-case, non-alphanumeric -> '_', collapse, trim.
    key = lower(key);
    key = regexprep(key, '[^a-z0-9]', '_');   % non-alphanumeric -> _
    key = regexprep(key, '_+', '_');           % collapse repeated _
    key = strtrim(key);
    if ~isempty(key) && key(1) == '_'
        key = key(2:end);
    end
    if ~isempty(key) && key(end) == '_'
        key = key(1:end-1);
    end
end

function d = editDistance_(a, b)
    %EDITDISTANCE_ Wagner-Fischer Levenshtein distance (no Statistics Toolbox).
    m = numel(a);
    n = numel(b);
    if m == 0
        d = n;
        return;
    end
    if n == 0
        d = m;
        return;
    end
    D = zeros(m + 1, n + 1);
    D(:, 1) = (0:m)';
    D(1, :) = 0:n;
    for i = 1:m
        for j = 1:n
            cost = double(a(i) ~= b(j));
            D(i + 1, j + 1) = min([D(i, j) + cost, D(i + 1, j) + 1, D(i, j + 1) + 1]);
        end
    end
    d = D(m + 1, n + 1);
end

function sim = similarity_(a, b)
    %SIMILARITY_ Normalized edit-distance similarity in [0,1] on normalized keys.
    na = normalize_(a);
    nb = normalize_(b);
    L = max(numel(na), numel(nb));
    if L == 0
        sim = 1;   % two empty keys are identical
        return;
    end
    sim = 1 - editDistance_(na, nb) / L;
end
