function [mergedX, mergedY] = writeTagMatCached_(outputDir, tag, x, y, priorX, priorY)
    %WRITETAGMATCACHED_ Append-mode .mat write that skips the load step.
    %   [mergedX, mergedY] = writeTagMatCached_(outputDir, tag, x, y, priorX, priorY)
    %
    %   Phase 1028 plan 02d helper. Functionally equivalent to
    %   writeTagMat_(outputDir, tag, x, y, 'append') for the same inputs and
    %   the same prior state — but supplies the prior X/Y from a caller-side
    %   in-memory cache instead of re-reading them from disk via load().
    %
    %   The on-disk bytes saved are byte-equal to writeTagMat_('append', ...)
    %   when (priorX, priorY) match what load() would have returned (i.e.,
    %   when the cache faithfully reflects the last save). This is the
    %   parity contract enforced by TestPriorStateCacheParity.
    %
    %   Inputs:
    %     outputDir - char, target directory (caller ensures it exists)
    %     tag       - handle with .Key property (SensorTag or StateTag)
    %     x, y      - column vectors (this tick's new rows)
    %     priorX    - column vector of all rows previously saved (or [] if cold cache)
    %     priorY    - column vector / cellstr matching priorX (or [] if cold)
    %
    %   Outputs:
    %     mergedX, mergedY - the concatenated X/Y just written. Returned so
    %                        the caller can refresh its cache without
    %                        re-concatenating.
    %
    %   Cold cache (priorX/priorY empty): degrades to writing only the new
    %   rows. This is identical to writeTagMat_('append', ...) when the file
    %   does not yet exist — the caller is expected to populate the cache
    %   after this call so subsequent ticks take the warm path.
    %
    %   The function deliberately does NOT consult the on-disk file. This is
    %   what makes it fast (no `load` syscall, no MAT-file parse). The
    %   tradeoff is that the caller must guarantee priorX/priorY reflect the
    %   on-disk state — if the cache is wrong, the next saved file will be
    %   wrong. Callers that lose track of the cache (process restart, cache
    %   eviction) MUST fall back to writeTagMat_('append', ...) for the cold
    %   write to re-seed.
    %
    %   See also: writeTagMat_, LiveTagPipeline.processTag_, BatchTagPipeline.run.

    key = char(tag.Key);
    outPath = fullfile(outputDir, [key '.mat']);

    mergedX = concatCol_(priorX, x);
    mergedY = concatCol_(priorY, y);
    payload = buildPayload_(mergedX, mergedY);
    saveTagVar_(outPath, key, payload);
end

function payload = buildPayload_(x, y)
    %BUILDPAYLOAD_ Mirror of writeTagMat_'s buildPayload_ to keep payload
    %   shape byte-identical between the two helpers.
    if iscell(y)
        payload = struct('x', x, 'y', {y});
    else
        payload = struct('x', x, 'y', y);
    end
end

function saveTagVar_(outPath, key, payload)
    %SAVETAGVAR_ Mirror of writeTagMat_'s saveTagVar_ — uses the same
    %   `save -struct wrap` form so the resulting .mat top-level variable
    %   layout is identical between cached and non-cached writers.
    wrap = struct();
    wrap.(key) = payload;
    save(outPath, '-struct', 'wrap');
end

function out = concatCol_(prior, new)
    %CONCATCOL_ Concatenate along rows preserving cellstr vs numeric typing.
    %   Verbatim mirror of writeTagMat_/concatCol_ — duplicated here rather
    %   than shared because both files live in libs/SensorThreshold/private/
    %   and MATLAB's private-folder scoping prevents cross-private-helper
    %   reuse without exposing the helper.
    if isempty(prior)
        if iscell(new)
            out = new(:);
        else
            out = new(:);
        end
        return;
    end
    if iscell(prior) || iscell(new)
        if ~iscell(prior)
            prior = num2cell(prior(:));
        end
        if ~iscell(new)
            new = num2cell(new(:));
        end
        out = [prior(:); new(:)];
    else
        out = [prior(:); new(:)];
    end
end
