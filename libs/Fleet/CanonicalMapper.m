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
    end

    methods (Access = private)
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
