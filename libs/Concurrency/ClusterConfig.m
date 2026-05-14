classdef ClusterConfig
%CLUSTERCONFIG Resolve the cluster-mode configuration for v4.0.
%
%   Determines whether this MATLAB session is operating in cluster mode
%   (shared filesystem) or single-user mode, and validates the configured
%   shared root path.
%
%   ClusterConfig.resolve()             -> struct (SharedRoot='', IsClusterMode=false)
%   ClusterConfig.resolve(struct('SharedRoot', '/mnt/share')) -> struct (validated)
%
%   Precedence: opts.SharedRoot > getenv('FASTSENSE_SHARED_ROOT') > '' (single-user).
%
%   Config struct fields:
%     .SharedRoot    — char; path to shared filesystem root ('' in single-user mode)
%     .IsClusterMode — logical; true iff SharedRoot is non-empty and exists
%
%   Errors:
%     Concurrency:sharedRootUnreachable — SharedRoot non-empty but not an existing folder
%
%   Warnings (one-time per session):
%     Concurrency:smbOplockDetected — checkSharedConfig canary mismatch (Pitfall 14)
%     Concurrency:nfsv3Detected     — sharedRoot is on an NFSv3 mount (Pitfall 2);
%                                     suppress via FASTSENSE_ALLOW_NFSV3=1
%
%   See also SharedPaths, ClusterIdentity.

    methods (Static)

        function cfg = resolve(opts)
            %RESOLVE Resolve and validate the cluster-mode configuration.
            %
            %   cfg = ClusterConfig.resolve() — single-user mode (SharedRoot='').
            %   cfg = ClusterConfig.resolve(opts) — validates opts.SharedRoot if set.
            %
            %   Input:
            %     opts — (optional) struct; may have .SharedRoot field
            %   Output:
            %     cfg — struct with .SharedRoot (char) and .IsClusterMode (logical)
            if nargin < 1 || isempty(opts)
                opts = struct();
            end
            root = SharedPaths.resolveRoot(opts);
            cfg = struct();
            cfg.SharedRoot    = root;
            cfg.IsClusterMode = ~isempty(root);
            if cfg.IsClusterMode && ~isfolder(root)
                error('Concurrency:sharedRootUnreachable', ...
                    'SharedRoot ''%s'' is not an existing folder.', root);
            end
        end

        function result = checkSharedConfig(sharedRoot)
            %CHECKSHAREDCONFIG Best-effort SMB-oplock smoke test (Pitfall 14 detection).
            %
            %   result = ClusterConfig.checkSharedConfig(sharedRoot)
            %
            %   Performs a canary write-and-immediate-read against a small probe file in
            %   <sharedRoot>/.oplock_canary/ to detect gross filesystem incoherency that
            %   suggests SMB oplocks (or similar client-side caching) are corrupting
            %   reads.  This is BEST-EFFORT — false negatives are expected (oplocks
            %   typically misbehave only under multi-process pressure, which a single-
            %   process smoke test cannot reproduce).
            %
            %   Returns:
            %     result.ok        — logical; true if all canary bytes round-tripped
            %     result.evidence  — struct with diagnostic fields:
            %                          .bytesWritten, .bytesRead, .matches (logical),
            %                          .sharedRoot, .canaryPath, .elapsedSec
            %     result.warnings  — cell of warning strings (operator-readable)
            %
            %   On mismatch, emits a one-time warning('Concurrency:smbOplockDetected', ...)
            %   per MATLAB session (guarded by a persistent flag).  NEVER throws — this is
            %   advisory and must not block pipeline startup.
            %
            %   Phase 1033 will wire this method into FastSenseCompanion startup; Phase
            %   1032 only ships the method itself.

            persistent warningEmitted_     %#ok<USENS>

            result = struct('ok', false, 'warnings', {{}}, 'evidence', struct());
            result.evidence.sharedRoot   = '';
            result.evidence.canaryPath   = '';
            result.evidence.bytesWritten = -1;
            result.evidence.bytesRead    = -1;
            result.evidence.matches      = false;
            result.evidence.elapsedSec   = 0;
            result.evidence.nfsv3Detected = false;

            if nargin < 1 || isempty(sharedRoot) || ~ischar(sharedRoot)
                result.warnings{end+1} = 'sharedRoot is empty or not a char';
                return;
            end

            result.evidence.sharedRoot = sharedRoot;

            if ~isfolder(sharedRoot)
                result.warnings{end+1} = sprintf('sharedRoot ''%s'' is not a folder', sharedRoot);
                return;
            end

            try
                canaryDir = fullfile(sharedRoot, '.oplock_canary');
                if ~isfolder(canaryDir), mkdir(canaryDir); end
                canaryPath = fullfile(canaryDir, sprintf('canary_%d_%d.bin', ...
                    feature('getpid'), round(rand() * 1e6)));
                result.evidence.canaryPath = canaryPath;

                tStart = tic;

                % Write a deterministic 1024-byte pattern.
                payload = uint8(mod(1:1024, 256));
                fid = fopen(canaryPath, 'wb');
                if fid < 0
                    result.warnings{end+1} = sprintf('fopen wb failed on canary path: %s', canaryPath);
                    return;
                end
                fwrite(fid, payload, 'uint8');
                fclose(fid);
                result.evidence.bytesWritten = numel(payload);

                % Immediate read-back (no sleep — any oplock-induced cache incoherency
                % would surface here on the oplock-break boundary).
                fid = fopen(canaryPath, 'rb');
                if fid < 0
                    result.warnings{end+1} = sprintf('fopen rb failed on canary path: %s', canaryPath);
                    return;
                end
                readback = fread(fid, [1, Inf], 'uint8=>uint8');
                fclose(fid);
                result.evidence.bytesRead    = numel(readback);
                result.evidence.elapsedSec   = toc(tStart);

                % Verify the canary bytes round-tripped correctly.
                if numel(readback) ~= numel(payload)
                    result.warnings{end+1} = sprintf( ...
                        'TORN READ: wrote %d bytes, read %d — possible SMB oplock caching', ...
                        numel(payload), numel(readback));
                elseif ~isequal(readback, payload)
                    result.warnings{end+1} = ...
                        'TORN READ: byte pattern mismatch — possible SMB oplock caching';
                else
                    result.evidence.matches = true;
                    result.ok = true;
                end

                % Cleanup canary file (always, even on mismatch).
                try
                    delete(canaryPath);
                catch
                    % non-fatal
                end

            catch ME
                result.warnings{end+1} = sprintf('checkSharedConfig probe caught: %s', ME.message);
                % best-effort: probe failure does not mean oplocks are present
                result.ok = false;
            end

            % One-time warning per MATLAB session on torn-read detection.
            if ~result.ok && isempty(warningEmitted_)
                warningEmitted_ = true;
                warning('Concurrency:smbOplockDetected', ...
                    ['SMB oplock canary smoke test FAILED on ''%s''.\n', ...
                     'This may indicate filesystem caching corruption (SMB oplocks, NFS attribute cache).\n', ...
                     'Operational fix: disable oplocks on the EventStore directory.\n', ...
                     'Windows Server: Set-SmbServerConfiguration -EnableLeasing $false\n', ...
                     'Samba: oplocks = no in smb.conf per-share section.\n', ...
                     'See PITFALLS.md Pitfall 14 and examples/cluster-setup/README.md for details.'], ...
                    sharedRoot);
            end

            % --- NFSv3 detection (Pitfall 2) ---
            persistent nfsv3WarningEmitted_     %#ok<USENS>
            try
                isNfsv3 = ClusterConfig.detectNfsv3_(sharedRoot);
            catch
                isNfsv3 = false;  % best-effort — never throw
            end
            result.evidence.nfsv3Detected = isNfsv3;
            if isNfsv3 && isempty(nfsv3WarningEmitted_)
                % Suppress when the operator has explicitly opted in.
                if ~strcmp(getenv('FASTSENSE_ALLOW_NFSV3'), '1')
                    nfsv3WarningEmitted_ = true;
                    warning('Concurrency:nfsv3Detected', ...
                        ['SharedRoot ''%s'' appears to be on an NFSv3 mount.\n', ...
                         'NFSv3 advisory locking is unreliable (rpc.statd may fail to recover\n', ...
                         'locks after network blips, ghost locks possible). Mitigation: use\n', ...
                         'NFSv4 with ''noac'' on Linux clients OR migrate to SMB.\n', ...
                         'To suppress this warning, set FASTSENSE_ALLOW_NFSV3=1.\n', ...
                         'See PITFALLS.md Pitfall 2 and examples/cluster-setup/README.md for details.'], ...
                        sharedRoot);
                end
            end
        end

        function tf = detectNfsv3_(sharedRoot)
            %DETECTNFSV3_ Best-effort NFSv3 mount detection (Pitfall 2).
            %
            %   tf = ClusterConfig.detectNfsv3_(sharedRoot)
            %
            %   Returns true iff sharedRoot is on a POSIX mount whose type is 'nfs'
            %   AND the mount options indicate v3 (or no version flag, which on Linux
            %   defaults to v3 for the legacy 'nfs' type).  On Windows, returns false
            %   (Windows NFSv3 clients are rare; skip the probe).
            %
            %   This is best-effort — failure to parse the mount table silently
            %   returns false.  False negatives are acceptable; false positives would
            %   spam operators.
            %
            %   Input:
            %     sharedRoot — char; path to check
            %   Output:
            %     tf — logical scalar; true if NFSv3 mount detected
            tf = false;
            if ispc()
                return;
            end
            if nargin < 1 || isempty(sharedRoot) || ~ischar(sharedRoot)
                return;
            end
            % Resolve absolute path so we can compare against mount points.
            abspath = '';
            try
                info = dir(sharedRoot);
                if ~isempty(info) && isfield(info, 'folder') && ~isempty(info(1).folder)
                    if info(1).isdir
                        abspath = fullfile(info(1).folder, info(1).name);
                    else
                        abspath = info(1).folder;
                    end
                end
            catch
                abspath = sharedRoot;
            end
            if isempty(abspath), abspath = sharedRoot; end

            % Parse `mount` output.  Linux + macOS share the basic format:
            %   <device> on <mountpoint> type <type> (<opts>)
            [status, out] = system('mount');
            if status ~= 0 || isempty(out)
                return;
            end
            lines = strsplit(out, sprintf('\n'));
            bestMatch = '';
            bestLen   = 0;
            for i = 1:numel(lines)
                line = strtrim(lines{i});
                if isempty(line), continue; end
                % Find " on " token to extract the mountpoint.
                idx = strfind(line, ' on ');
                if isempty(idx), continue; end
                afterOn = line(idx(1)+4:end);
                idx2 = strfind(afterOn, ' type ');
                if isempty(idx2)
                    % macOS format: "/dev/disk1 on / (apfs, ...)" -- no "type" token.
                    idx2 = strfind(afterOn, ' (');
                    if isempty(idx2), continue; end
                    mp   = afterOn(1:idx2(1)-1);
                    rest = afterOn(idx2(1):end);
                else
                    mp   = afterOn(1:idx2(1)-1);
                    rest = afterOn(idx2(1)+6:end);
                end
                % Match longest mountpoint that is a prefix of abspath.
                if ~isempty(mp) && (strcmp(abspath, mp) || ...
                        (numel(mp) > 1 && strncmp(abspath, [mp, '/'], numel(mp)+1)))
                    if numel(mp) > bestLen
                        bestLen   = numel(mp);
                        bestMatch = rest;
                    end
                end
            end
            if isempty(bestMatch), return; end

            % bestMatch now contains either "nfs (opts...)" (Linux) or
            % "(nfs, opts...)" (macOS).
            lowerMatch = lower(bestMatch);
            isNfs = contains(lowerMatch, 'nfs');
            if ~isNfs, return; end

            % Look for explicit version markers.
            if contains(lowerMatch, 'vers=3') || contains(lowerMatch, 'nfsvers=3')
                tf = true;
                return;
            end
            % If 'nfs' appears WITHOUT 'vers=4', 'nfsvers=4', or 'nfs4', treat as
            % v3-suspect.  This is the conservative default — operators who run NFSv4
            % typically have explicit version markers in the mount options.
            hasV4 = contains(lowerMatch, 'vers=4') || contains(lowerMatch, 'nfsvers=4') || ...
                contains(lowerMatch, 'nfs4');
            if ~hasV4
                tf = true;
            end
        end

    end
end
