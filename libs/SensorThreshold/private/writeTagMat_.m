function writeTagMat_(outputDir, tag, x, y, mode)
    %WRITETAGMAT_ Write per-tag .mat file matching the SensorTag.load contract.
    %   writeTagMat_(outputDir, tag, x, y)
    %   writeTagMat_(outputDir, tag, x, y, mode)
    %
    %   outputDir - char, must exist (caller ensures via OutputDir lifecycle)
    %   tag       - handle with .Key property (SensorTag or StateTag)
    %   x, y      - column vectors (y may be numeric OR cellstr for StateTag)
    %   mode      - 'overwrite' (default) or 'append'
    %
    %   File layout (per D-09, D-10):
    %     <outputDir>/<tag.Key>.mat contains ONE variable `data`
    %     data.(tag.Key) = struct('x', X, 'y', Y)
    %
    %   Append semantics (Pitfall 2 guard):
    %     load existing file -> concatenate X/Y -> save (NOT the append
    %     flag on save, which OVERWRITES the existing `data` variable in
    %     v7 mat-files rather than merging its fields).
    %
    %   Errors:
    %     TagPipeline:invalidWriteMode - unknown mode arg
    %
    %   See also: readRawDelimited_, selectTimeAndValue_, SensorTag/load.

    if nargin < 5 || isempty(mode)
        mode = 'overwrite';
    end

    key = char(tag.Key);
    outPath = fullfile(outputDir, [key '.mat']);

    switch mode
        case 'overwrite'
            payload = buildPayload_(x, y);
            saveTagVar_(outPath, key, payload);

        case 'append'
            priorX = [];
            priorY = [];
            if exist(outPath, 'file')
                prior = load(outPath);
                if isfield(prior, key)
                    old = prior.(key);
                    if isstruct(old)
                        if isfield(old, 'x')
                            priorX = old.x;
                        end
                        if isfield(old, 'y')
                            priorY = old.y;
                        end
                    end
                end
            end
            mergedX = concatCol_(priorX, x);
            mergedY = concatCol_(priorY, y);
            payload = buildPayload_(mergedX, mergedY);
            saveTagVar_(outPath, key, payload);

        otherwise
            error('TagPipeline:invalidWriteMode', ...
                'Unknown write mode ''%s'' (expected ''overwrite'' or ''append'')', ...
                char(mode));
    end
end

function payload = buildPayload_(x, y)
    %BUILDPAYLOAD_ Build the {x, y} struct ensuring cellstr Y is wrapped.
    %   struct('y', cellArray) expands cellArray into a struct array
    %   (one element per cell). Wrapping in a single outer cell forces
    %   scalar struct with cellstr field. Numeric Y passes through.
    if iscell(y)
        payload = struct('x', x, 'y', {y});
    else
        payload = struct('x', x, 'y', y);
    end
end

function saveTagVar_(outPath, key, payload)
    %SAVETAGVAR_ Save payload under a dynamically-named variable equal to key.
    %   Satisfies SensorTag.load() expectation that the file contain ONE
    %   top-level variable named <KeyName> holding struct('x', X, 'y', Y).
    %
    %   Uses the -struct save form so the variable name is exactly `key`
    %   without requiring eval or assignin(). The outer struct holds one
    %   field named key; save -struct peels that field into a top-level
    %   variable.
    wrap = struct();
    wrap.(key) = payload;
    save(outPath, '-struct', 'wrap');
end

function out = concatCol_(prior, new)
    %CONCATCOL_ Concatenate along rows preserving cellstr vs numeric typing.
    %   Handles the StateTag case where Y may be cellstr. If either side is
    %   a cell, both are coerced to cell before concatenation.
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
