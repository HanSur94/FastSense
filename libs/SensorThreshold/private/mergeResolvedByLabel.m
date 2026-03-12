function [mergedTh, mergedViol] = mergeResolvedByLabel(resolvedTh, resolvedViol, segBounds, dataEnd)
%MERGERESOLVEDBYLABEL Merge resolved thresholds sharing the same Label+Direction.
%   [mergedTh, mergedViol] = MERGERESOLVEDBYLABEL(resolvedTh, resolvedViol, segBounds, dataEnd)
%   consolidates threshold and violation entries that were produced by
%   different condition groups during Sensor.resolve() but logically
%   represent the same threshold line (same Label and Direction).
%
%   The merge involves three operations per group:
%     1. Overlay Y values: fill NaN gaps in one entry with non-NaN values
%        from sibling entries, producing a single composite Y array that
%        covers all active segments for the shared label.
%     2. Convert to step-function format via toStepFunction(), which
%        duplicates X at boundaries for sharp vertical steps and inserts
%        NaN separators between non-contiguous active regions.
%     3. Concatenate and time-sort the violation X/Y arrays from all
%        sibling entries.
%
%   Unlabeled entries (empty Label) are never merged; each receives a
%   unique synthetic key to keep them separate.
%
%   Inputs:
%     resolvedTh   — struct array of threshold entries from resolve()
%     resolvedViol — struct array of violation entries (same length)
%     segBounds    — 1xS double, segment boundary timestamps
%     dataEnd      — scalar double, timestamp of the last sensor sample
%
%   Outputs:
%     mergedTh   — struct array, one entry per unique Label+Direction
%     mergedViol — struct array, companion violation data (same length)
%
%   See also Sensor.resolve, appendResults, buildThresholdEntry.

    % Pass through when there is nothing to merge
    if isempty(resolvedTh)
        mergedTh = resolvedTh;
        mergedViol = resolvedViol;
        return;
    end

    nEntries = numel(resolvedTh);

    % --- Build merge keys from Label + Direction ---
    % Labeled entries with the same label and direction share a key;
    % unlabeled entries get unique synthetic keys to prevent merging.
    mergeKeys = cell(1, nEntries);
    for i = 1:nEntries
        lbl = resolvedTh(i).Label;
        if isempty(lbl)
            mergeKeys{i} = sprintf('__unlabeled_%d__', i);
        else
            mergeKeys{i} = [lbl '|' resolvedTh(i).Direction];
        end
    end

    % Group entries by their merge key (stable preserves original order)
    [uniqueKeys, ~, groupIdx] = unique(mergeKeys, 'stable');
    nGroups = numel(uniqueKeys);

    mergedTh = [];
    mergedViol = [];

    for g = 1:nGroups
        members = find(groupIdx == g);
        nMembers = numel(members);
        base = resolvedTh(members(1));

        if nMembers == 1
            % --- Fast path: single member, no merge needed ---
            % Violations are already sorted (produced by left-to-right
            % segment scan).  Skip allocation, copy, and sort entirely.
            [stepX, stepY] = toStepFunction(segBounds, base.Y, dataEnd);
            base.X = stepX;
            base.Y = stepY;

            v = resolvedViol(members(1));
            mergedViol_entry = struct('X', v.X, 'Y', v.Y, ...
                'Direction', base.Direction, 'Label', base.Label);
        else
            % --- Multi-member merge ---
            % Overlay Y arrays from all members
            mergedY = base.Y;
            for m = 2:nMembers
                otherY = resolvedTh(members(m)).Y;
                fill = isnan(mergedY) & ~isnan(otherY);
                mergedY(fill) = otherY(fill);
            end

            [stepX, stepY] = toStepFunction(segBounds, mergedY, dataEnd);
            base.X = stepX;
            base.Y = stepY;

            % Concatenate violation arrays from all members.
            % Each member's violations are already sorted (segment scan
            % order) and come from non-overlapping time segments, so the
            % concatenation is already in chronological order — skip sort.
            totalViolLen = 0;
            for m = 1:nMembers
                totalViolLen = totalViolLen + numel(resolvedViol(members(m)).X);
            end

            if totalViolLen == 0
                allViolX = [];
                allViolY = [];
            else
                allViolX = zeros(1, totalViolLen);
                allViolY = zeros(1, totalViolLen);
                pos = 0;
                for m = 1:nMembers
                    v = resolvedViol(members(m));
                    nv = numel(v.X);
                    if nv > 0
                        allViolX(pos+1:pos+nv) = v.X;
                        allViolY(pos+1:pos+nv) = v.Y;
                        pos = pos + nv;
                    end
                end
            end
            mergedViol_entry = struct('X', allViolX, 'Y', allViolY, ...
                'Direction', base.Direction, 'Label', base.Label);
        end

        [mergedTh, mergedViol] = appendResults(mergedTh, mergedViol, ...
            base, mergedViol_entry);
    end
end


function [stepX, stepY] = toStepFunction(segBounds, values, dataEnd)
%TOSTEPFUNCTION Convert segment boundary values to step-function arrays.
%   [stepX, stepY] = TOSTEPFUNCTION(segBounds, values, dataEnd) transforms
%   a segment-boundary representation (one value per boundary) into a
%   piecewise-constant plot-ready representation where each segment is a
%   horizontal line from segStart to segEnd.
%
%   Rendering rules:
%     - Active segments (non-NaN value) emit two X/Y points:
%       [segStart, value] and [segEnd, value].
%     - Contiguous active segments share a boundary; the shared X is
%       duplicated to produce a vertical step between differing values.
%     - Non-contiguous active segments (separated by NaN gaps) are joined
%       by NaN separators so that the plot line breaks between them.
%
%   Inputs:
%     segBounds — 1xS double, segment boundary timestamps
%     values    — 1xS double, threshold value at each boundary (NaN =
%                 inactive)
%     dataEnd   — scalar double, end-of-data timestamp (used as the right
%                 edge of the last segment)
%
%   Outputs:
%     stepX — 1xP double, X coordinates for plotting
%     stepY — 1xP double, Y coordinates for plotting
%
%   See also mergeResolvedByLabel.

    nB = numel(segBounds);
    parts = {};  % Cell array of {X_array, Y_array} pairs (one per contiguous run)

    for k = 1:nB
        % Skip inactive (NaN) segments
        if isnan(values(k))
            continue;
        end

        % Determine the right edge of this segment
        segStart = segBounds(k);
        if k < nB
            segEnd = segBounds(k + 1);
        else
            segEnd = dataEnd;
        end

        % Decide whether to extend the previous contiguous part or start new
        if ~isempty(parts) && parts{end}{1}(end) == segStart
            % Contiguous with the previous part: append a step at the
            % shared boundary by duplicating the boundary X coordinate.
            parts{end}{1} = [parts{end}{1}, segStart, segEnd];
            parts{end}{2} = [parts{end}{2}, values(k), values(k)];
        else
            % Start a new disconnected part (gap in active segments)
            parts{end+1} = {[segStart, segEnd], [values(k), values(k)]};
        end
    end

    % Handle the case where no segments are active
    if isempty(parts)
        stepX = [];
        stepY = [];
        return;
    end

    % Fast path: single contiguous run needs no NaN separators
    if numel(parts) == 1
        stepX = parts{1}{1};
        stepY = parts{1}{2};
        return;
    end

    % --- Concatenate parts with NaN separators ---
    % Pre-compute total output length: sum of part lengths + (nParts - 1) NaNs
    totalLen = 0;
    for p = 1:numel(parts)
        totalLen = totalLen + numel(parts{p}{1});
    end
    totalLen = totalLen + numel(parts) - 1;  % NaN separators between parts

    stepX = zeros(1, totalLen);
    stepY = zeros(1, totalLen);
    idx = 1;
    for p = 1:numel(parts)
        % Insert NaN separator before the second and subsequent parts
        if p > 1
            stepX(idx) = NaN;
            stepY(idx) = NaN;
            idx = idx + 1;
        end
        n = numel(parts{p}{1});
        stepX(idx:idx+n-1) = parts{p}{1};
        stepY(idx:idx+n-1) = parts{p}{2};
        idx = idx + n;
    end
end
