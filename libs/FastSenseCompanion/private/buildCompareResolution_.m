function rows = buildCompareResolution_(fleet, logicalId, theme)
%BUILDCOMPARERESOLUTION_ Assemble per-machine row states for a logical sensor.
%   rows = buildCompareResolution_(fleet, logicalId)
%   rows = buildCompareResolution_(fleet, logicalId, theme)
%
%   For each machine in fleet.machineIds() order, resolves the (logicalId,
%   machineId) mapping via fleet.mapper().resolve and classifies it into a row
%   state for the cross-machine compare builder (Phase 1045):
%     'auto'           - resolvable AUTO (HIGH/MEDIUM) entry, CONFIRMED, or OVERRIDDEN
%     'confirm_needed' - LOW-confidence AUTO entry (excluded by default; invariant #4)
%     'none'           - no mapping entry for this machine
%
%   The confidence gate lives HERE, not in Fleet/CanonicalMapper: LOW+AUTO
%   matches are never marked included-by-default. Unit mismatch is flagged only
%   when both the canonical entry's localUnits and the resolved tag's Units are
%   non-empty and differ case-insensitively (Pitfall 7).
%
%   Inputs:
%     fleet     - Fleet handle
%     logicalId - char logical sensor id (a CanonicalMapper key)
%     theme     - (optional) CompanionTheme struct; when present each row's
%                 color is populated via compareSeriesColor_; when absent
%                 (nargin < 3 or empty) every row.color = [].
%
%   Output:
%     rows - 1xN struct array (N = machineCount) with fields:
%       machineId localKey localName localUnits confidence status
%       unitMismatch state insertionIdx color
%
%   Octave-safe: plain loops + strcmp/strcmpi; no contains, no isa, no
%   validateattributes. Mirrors the filterMachines.m pure-helper shape.
%
%   See also CanonicalMapper.resolve, Fleet.machineIds, compareSeriesColor_.

    if nargin < 3
        theme = [];
    end

    ids = fleet.machineIds();
    n = numel(ids);
    rows = repmat(emptyRow_(), 1, max(n, 0));
    if n == 0
        rows = emptyRow_();
        rows(1) = [];   % 1x0 struct array with the right fields
        return;
    end

    mapper = fleet.mapper();
    for i = 1:n
        machineId = ids{i};
        r = emptyRow_();
        r.machineId    = machineId;
        r.insertionIdx = i;

        e = mapper.resolve(logicalId, machineId);
        if isempty(e)
            r.state = 'none';
        else
            r.localKey    = e.localKey;
            r.localName   = e.localName;
            r.localUnits  = e.localUnits;
            r.confidence  = e.confidence;
            r.status      = e.status;
            if strcmp(e.status, 'AUTO') && strcmp(e.confidence, 'LOW')
                r.state = 'confirm_needed';
            else
                r.state = 'auto';
            end
            r.unitMismatch = detectUnitMismatch_(fleet, machineId, e.localKey, e.localUnits);
        end

        if ~isempty(theme)
            r.color = compareSeriesColor_(theme, fleet, machineId);
        end

        rows(i) = r;
    end
end

% --------------------------- helpers --------------------------------

function r = emptyRow_()
%EMPTYROW_ A row struct with all fields at their defaults.
    r = struct( ...
        'machineId',    '', ...
        'localKey',     '', ...
        'localName',    '', ...
        'localUnits',   '', ...
        'confidence',   '', ...
        'status',       '', ...
        'unitMismatch', false, ...
        'state',        'none', ...
        'insertionIdx', 0, ...
        'color',        []);
end

function tf = detectUnitMismatch_(fleet, machineId, localKey, canonicalUnits)
%DETECTUNITMISMATCH_ True only when both units are non-empty and differ (case-insensitive).
%   Empty units on either side -> not detectable -> false. Tag lookup failures
%   degrade to false (no mismatch claimed when the data is unavailable).
    tf = false;
    if isempty(canonicalUnits) || isempty(localKey)
        return;
    end
    tagUnits = '';
    try
        tag = fleet.getMachine(machineId).get(localKey);
        if isprop(tag, 'Units')
            tagUnits = tag.Units;
        end
    catch
        return;
    end
    if isempty(tagUnits)
        return;
    end
    if ~strcmpi(canonicalUnits, tagUnits)
        tf = true;
    end
end
