classdef AtomicWriter
%ATOMICWRITER Atomic temp+rename writes for shared-FS safety.
%
%   The documented single seam for every shared-FS write in v4.0.
%   Consolidates the existing libs/EventDetection/EventStore.m
%   temp+rename pattern (EventStore.save lines 148-172) and extends it
%   with post-rename validation and reader-side retry helpers.
%
%   Prior idiom (EventStore.save):
%     tmpFile = [obj.FilePath '.tmp'];
%     movefile(tmpFile, obj.FilePath);        % no post-rename check
%
%   This class replaces that raw movefile with:
%     1. movefile(temp, final, 'f')
%     2. Post-rename re-stat: dir(final); if bytes==0 or isempty -> retry
%     3. Up to N retries with pause(backoffMs/1000) between attempts
%
%   Public surface:
%     AtomicWriter.replace(tempPath, finalPath)
%     AtomicWriter.replace(tempPath, finalPath, opts)
%     AtomicWriter.write(finalPath, payloadFn, identity)
%     AtomicWriter.write(finalPath, payloadFn, identity, opts)
%     out = AtomicWriter.readWithRetry(finalPath, loaderFn)
%     out = AtomicWriter.readWithRetry(finalPath, loaderFn, opts)
%
%   opts fields (struct):
%     .Retries       — max retry count           (default 3)
%     .BackoffMs     — pause between retries, ms (default 50)
%     .StillHeldByMe — function_handle predicate; called before movefile;
%                      aborts and throws lockLostBeforeReplace if false
%     .StampIdentity — logical; when true, writes a sibling .identity.json
%
%   Errors:
%     Concurrency:atomicWriteFailed       — post-rename validation failed
%                                           after N retries
%     Concurrency:lockLostBeforeReplace   — StillHeldByMe predicate returned
%                                           false; temp file deleted
%     Concurrency:atomicWriteTempMissing  — tempPath does not exist when
%                                           replace() is called
%
%   See also lockfile_mex, FileLock, ClusterIdentity.

    methods (Static)

        function replace(tempPath, finalPath, opts)
            %REPLACE Atomically rename tempPath to finalPath.
            %   replace(tempPath, finalPath)
            %   replace(tempPath, finalPath, opts)
            %
            %   Retries up to opts.Retries times (default 3) with
            %   opts.BackoffMs (default 50 ms) when movefile itself throws
            %   (e.g. SMB transient failure).
            %
            %   NOTE on zero-byte semantics: after a successful movefile,
            %   tempPath is consumed.  If dir(finalPath).bytes == 0, a
            %   second movefile iteration would fail immediately (no temp
            %   left), so the function throws Concurrency:atomicWriteFailed
            %   without a productive retry.  The retry loop is for the case
            %   where movefile ITSELF throws (source-unavailable errors on
            %   SMB).

            if nargin < 3 || isempty(opts)
                opts = struct();
            end
            retries = AtomicWriter.optGet_(opts, 'Retries',   3);
            backoff = AtomicWriter.optGet_(opts, 'BackoffMs', 50) / 1000;
            stillFn = AtomicWriter.optGet_(opts, 'StillHeldByMe', []);

            if ~isfile(tempPath)
                error('Concurrency:atomicWriteTempMissing', ...
                    'Temp file not found: %s', tempPath);
            end

            if ~isempty(stillFn) && isa(stillFn, 'function_handle')
                try
                    ok = stillFn();
                catch
                    ok = false;
                end
                if ~ok
                    try, delete(tempPath); catch, end
                    error('Concurrency:lockLostBeforeReplace', ...
                        'Lock no longer held; aborted replace of %s.', finalPath);
                end
            end

            lastErr = sprintf('replace failed after %d retries', retries);
            for attempt = 1:max(1, retries)
                try
                    movefile(tempPath, finalPath, 'f');
                    info = dir(finalPath);
                    if ~isempty(info) && info(1).bytes > 0
                        return;   % success
                    end
                    % movefile succeeded but result is 0 bytes.
                    % Temp is consumed — no productive retry possible.
                    if isempty(info)
                        lastErr = sprintf( ...
                            'post-rename: dir(%s) returned empty on attempt %d', ...
                            finalPath, attempt);
                    else
                        lastErr = sprintf( ...
                            'post-rename: dir(%s).bytes == 0 on attempt %d', ...
                            finalPath, attempt);
                    end
                    break;  % exit loop; temp gone, no further movefile possible
                catch mvErr
                    lastErr = mvErr.message;
                end
                if attempt < retries
                    pause(backoff);
                end
            end
            error('Concurrency:atomicWriteFailed', ...
                'movefile %s -> %s failed after %d retries: %s', ...
                tempPath, finalPath, retries, lastErr);
        end

        function write(finalPath, payloadFn, identity, opts)
            %WRITE Write payload via callback to a temp file then atomically replace.
            %   write(finalPath, payloadFn, identity)
            %   write(finalPath, payloadFn, identity, opts)
            %
            %   Generates a unique sibling temp filename:
            %     <finalPath>.tmp.<pid>.<epoch>.<rand>
            %   Calls payloadFn(tempPath) — callers save()/fwrite() into it.
            %   Then calls replace(tempPath, finalPath, opts).
            %
            %   When opts.StampIdentity == true, also writes a sidecar
            %   <finalPath>.identity.json containing the identity struct.

            if nargin < 4 || isempty(opts)
                opts = struct();
            end
            stampId = AtomicWriter.optGet_(opts, 'StampIdentity', false);
            pid     = double(ClusterIdentity.pid());
            eps     = char(datetime('now', 'TimeZone', 'UTC'), 'yyyyMMddHHmmssSSS');
            rnd     = sprintf('%06d', randi([0 999999]));
            tempPath = sprintf('%s.tmp.%d.%s.%s', finalPath, pid, eps, rnd);
            try
                payloadFn(tempPath);
            catch err
                if isfile(tempPath)
                    try, delete(tempPath); catch, end
                end
                rethrow(err);
            end
            AtomicWriter.replace(tempPath, finalPath, opts);

            if stampId
                sidecarTemp  = sprintf('%s.identity.tmp.%d.%s.%s', ...
                                       finalPath, pid, eps, rnd);
                sidecarFinal = [finalPath, '.identity.json'];
                fid = fopen(sidecarTemp, 'w');
                if fid > 0
                    fprintf(fid, '%s', ndjsonEncode(identity));
                    fclose(fid);
                    try
                        AtomicWriter.replace(sidecarTemp, sidecarFinal, opts);
                    catch
                        % Best-effort sidecar write; non-fatal.
                    end
                end
            end
        end

        function out = readWithRetry(finalPath, loaderFn, opts)
            %READWITHRETRY Invoke loaderFn(finalPath) with retry on error.
            %   out = readWithRetry(finalPath, loaderFn)
            %   out = readWithRetry(finalPath, loaderFn, opts)
            %
            %   Retries loaderFn up to opts.Retries times (default 3) with
            %   opts.BackoffMs (default 50 ms) between attempts.  Converts
            %   mid-rename "torn read" windows into brief stalls (Pitfall 12:
            %   MAT v7.3 partial-read window).  Re-throws the final error
            %   to the caller if all retries are exhausted.

            if nargin < 3 || isempty(opts)
                opts = struct();
            end
            retries = AtomicWriter.optGet_(opts, 'Retries',   3);
            backoff = AtomicWriter.optGet_(opts, 'BackoffMs', 50) / 1000;
            lastErr = MException('Concurrency:readWithRetryFailed', 'unknown');
            for attempt = 1:max(1, retries)
                try
                    out = loaderFn(finalPath);
                    return;
                catch err
                    lastErr = err;
                    if attempt < retries
                        pause(backoff);
                    end
                end
            end
            rethrow(lastErr);
        end

    end

    methods (Static, Access = private)

        function v = optGet_(opts, name, default)
            %OPTGET_ Extract a field from opts struct with fallback to default.
            if isstruct(opts) && isfield(opts, name)
                v = opts.(name);
            else
                v = default;
            end
        end

    end
end
