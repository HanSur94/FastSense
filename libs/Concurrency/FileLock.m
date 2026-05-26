classdef FileLock < handle
%FILELOCK Cross-process advisory file lock with identity-stamped body.
%
%   Provides per-key mutual exclusion across MATLAB processes (and hosts in
%   cluster mode) using kernel-level advisory locks from lockfile_mex when
%   available, falling back to an atomic sidecar-rename pattern when MEX is
%   absent.
%
%   The lock file has a sibling body file (<key>.lock.body) containing
%   plain-text identity fields (user, host, pid, epoch, acquired_at,
%   heartbeat_at).  The holder rewrites this body every HeartbeatInterval
%   seconds to bump its server-side mtime.  Other nodes use the mtime to
%   determine whether the lock is stale (Pitfall 9 — NEVER use wall-clock
%   acquired_at for staleness; only use filesystem mtime).
%
%   Usage:
%     lock = FileLock('pressure');
%     if lock.tryAcquire()
%         try
%             % ... critical section ...
%         finally
%             lock.release();
%         end
%     end
%     delete(lock);
%
%   Constructor options (name-value pairs):
%     'LockDir'          — char; defaults to SharedPaths.locksDir(root) if
%                          cluster mode, else fullfile(tempdir, 'fs-locks')
%     'StaleTimeout'     — double; seconds before a held lock is considered
%                          stale (default 90 — Unknown 4 calibration)
%     'HeartbeatInterval'— double; seconds between heartbeat body rewrites
%                          (default 10)
%     'Strict'           — logical; when true, throws
%                          Concurrency:lockfileMexUnavailable if lockfile_mex
%                          is not on the path (default false)
%
%   Public methods:
%     [ok, reason] = tryAcquire('Timeout', t)
%     release()
%     tf = isHeld()
%     tf = stillHeldByMe()
%     tf = isStale()
%     info = peek()
%     lp   = lockPath()
%     bp   = bodyPath()
%     delete(lock)   — destructor; releases if held; stops heartbeat timer
%
%   Static methods:
%     FileLock.clearCache() — reset the per-process held-keys registry (tests)
%
%   Errors:
%     Concurrency:nestedLockAcquireForbidden — same process tried to acquire
%         a key it already holds (Unknown 3 / Pitfall B)
%     Concurrency:lockfileMexUnavailable     — lockfile_mex absent and
%         Strict=true
%
%   See also lockfile_mex, LockFileFormat, ClusterIdentity, AtomicWriter.

    % ------------------------------------------------------------------ %
    properties (SetAccess = private)
        Key                     % char; lock key name
        LockDir                 % char; directory containing the .lock file
        StaleTimeout   = 90     % double; stale-detection threshold (seconds); Unknown 4
        HeartbeatInterval = 10  % double; body-rewrite interval (seconds)
        Strict         = false  % logical; true → throw if MEX absent
    end

    properties (Access = private)
        lockPath_       % char; full path to the kernel lock file
        bodyPath_       % char; full path to the identity body file
        handle_  = []   % int64 from lockfile_mex('acquire',...), or [] when not held
        heartbeatTimer_ = []  % timer object; [] when not running
        Listeners_ = {}       % cell; STATE.md cross-cutting constraint placeholder
        identity_             % struct; cached from ClusterIdentity.resolve() at acquire
    end

    % ------------------------------------------------------------------ %
    methods (Static)

        function clearCache()
            %CLEARCACHE Reset the per-process held-keys registry.
            %   Call between tests to prevent cross-test lock state leakage.
            m = FileLock.heldKeys_();
            if m.Count > 0
                remove(m, keys(m));
            end
        end

    end

    % ------------------------------------------------------------------ %
    methods (Static, Access = private)

        function map = heldKeys_(markPath)
            %HELDKEYS_ Return (and optionally update) the persistent per-process held-key registry.
            %   heldKeys_()         — return the map (read-only)
            %   heldKeys_(lockPath) — mark lockPath as held, then return map
            %
            %   Follows the TagRegistry persistent-singleton pattern (Research §Patterns).
            %   Keys are absolute lockPath strings; values are logical true.
            persistent cache;
            if isempty(cache)
                cache = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            end
            if nargin >= 1 && ~isempty(markPath)
                cache(markPath) = true;
            end
            map = cache;
        end

    end

    % ------------------------------------------------------------------ %
    methods

        function obj = FileLock(key, varargin)
            %FILELOCK Construct a FileLock for the given key.
            %
            %   lock = FileLock(key)
            %   lock = FileLock(key, 'StaleTimeout', 90, 'Strict', false, ...)
            %
            %   Input:
            %     key      — char or string; non-empty lock key name
            %     varargin — name-value pairs (see class header)

            if nargin < 1 || isempty(key)
                error('Concurrency:invalidKey', ...
                    'FileLock key must be a non-empty char or string.');
            end
            obj.Key = char(key);

            % Parse options.
            lockDir          = '';
            staleTimeout     = 90;
            heartbeatInterval = 10;
            strict           = false;
            for k = 1:2:numel(varargin)
                optName = varargin{k};
                optVal  = varargin{k + 1};
                switch optName
                    case 'LockDir'
                        lockDir = char(optVal);
                    case 'StaleTimeout'
                        staleTimeout = double(optVal);
                    case 'HeartbeatInterval'
                        heartbeatInterval = double(optVal);
                    case 'Strict'
                        strict = logical(optVal);
                    otherwise
                        error('Concurrency:unknownOption', ...
                            'Unknown FileLock option ''%s''.', optName);
                end
            end
            obj.StaleTimeout      = staleTimeout;
            obj.HeartbeatInterval = heartbeatInterval;
            obj.Strict            = strict;

            % Resolve lock directory.
            if isempty(lockDir)
                root = SharedPaths.resolveRoot(struct());
                if ~isempty(root)
                    lockDir = SharedPaths.locksDir(root);
                else
                    lockDir = fullfile(tempdir(), 'fs-locks');
                end
            end
            obj.LockDir = lockDir;
            if ~isfolder(obj.LockDir)
                mkdir(obj.LockDir);
            end

            % Compute derived paths.
            obj.lockPath_ = fullfile(obj.LockDir, [obj.Key, '.lock']);
            obj.bodyPath_ = [obj.lockPath_, '.body'];
        end

        function [acquired, reason] = tryAcquire(obj, varargin)
            %TRYACQUIRE Attempt to acquire the lock without blocking (default).
            %
            %   acquired = lock.tryAcquire()
            %   acquired = lock.tryAcquire('Timeout', t)
            %
            %   Input:
            %     'Timeout', t — double; seconds to retry before giving up (default 0)
            %   Output:
            %     acquired — logical; true iff this call acquired the lock
            %     reason   — char; '' on success, error description on failure
            %
            %   Throws Concurrency:nestedLockAcquireForbidden if the same process
            %   already holds the lock on this key (Unknown 3 / Pitfall B).

            tSec = 0;
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'Timeout')
                    tSec = double(varargin{k + 1});
                end
            end

            % --- In-process re-entrance guard (Unknown 3 / Pitfall B) ---
            m = FileLock.heldKeys_();
            if m.isKey(obj.lockPath_)
                error('Concurrency:nestedLockAcquireForbidden', ...
                    ['Same process already holds FileLock for key ''%s''. ', ...
                     'Nested acquire would deadlock (OFD/LockFileEx re-acquire). ', ...
                     'Release the existing lock first.'], obj.Key);
            end

            % --- Determine which acquisition path to use ---
            mexAvailable = exist('lockfile_mex', 'file') == 3;
            if ~mexAvailable && obj.Strict
                error('Concurrency:lockfileMexUnavailable', ...
                    ['lockfile_mex is not on the path and Strict=true. ', ...
                     'Cannot acquire lock for key ''%s'' without MEX.'], obj.Key);
            end

            if mexAvailable
                acquired = obj.acquireViaMex_(tSec);
            else
                acquired = obj.acquireViaSidecar_(tSec);
            end

            reason = '';
            if ~acquired
                reason = sprintf('Lock for key ''%s'' is currently held by another holder.', obj.Key);
            end
        end

        function release(obj)
            %RELEASE Release the lock and stop the heartbeat timer.
            %
            %   Idempotent — safe to call when not held or after delete().
            %   Timer is stopped before deleted per STATE.md contract.

            % Stop and delete the heartbeat timer (STATE.md: stop before delete).
            if ~isempty(obj.heartbeatTimer_) && isvalid(obj.heartbeatTimer_)
                stop(obj.heartbeatTimer_); delete(obj.heartbeatTimer_);  % STATE.md order: stop first
            end
            obj.heartbeatTimer_ = [];

            % Remove from in-process held-keys registry.
            m = FileLock.heldKeys_();
            if m.isKey(obj.lockPath_)
                remove(m, obj.lockPath_);
            end

            % Release the kernel-level lock.
            if ~isempty(obj.handle_)
                mexAvailable = exist('lockfile_mex', 'file') == 3;
                if mexAvailable
                    try
                        lockfile_mex('release', obj.handle_);
                    catch
                        % Best-effort; lock may already be released.
                    end
                end
                obj.handle_ = [];
            end

            % Delete body file (best-effort; non-fatal on error).
            if isfile(obj.bodyPath_)
                try
                    delete(obj.bodyPath_);
                catch
                end
            end

            obj.identity_ = [];
        end

        function tf = isHeld(obj)
            %ISHELD Return true iff this FileLock instance currently owns the lock.
            %
            %   Output:
            %     tf — logical; true when this object has acquired the lock and not released it
            m = FileLock.heldKeys_();
            tf = ~isempty(obj.handle_) && m.isKey(obj.lockPath_) && m(obj.lockPath_);
        end

        function tf = stillHeldByMe(obj)
            %STILLHELDBYME Re-read body and verify identity still matches.
            %   Use this as the Pitfall 10 re-validation hook: call before any
            %   critical write (e.g., inside AtomicWriter.replace's StillHeldByMe
            %   predicate) to verify no silent lock takeover occurred.
            %
            %   Output:
            %     tf — logical; true iff the body file's {user, host, pid} matches
            %          ClusterIdentity.resolve() for this process

            if ~isfile(obj.bodyPath_)
                tf = false;
                return;
            end
            try
                id = ClusterIdentity.resolve();
                fid = fopen(obj.bodyPath_, 'r');
                if fid < 0
                    tf = false;
                    return;
                end
                txt = fread(fid, '*char')';
                fclose(fid);
                s = LockFileFormat.decodeBody(txt);
                tf = strcmp(s.user, id.user) && strcmp(s.host, id.host) && ...
                    (s.pid == id.pid);
            catch
                tf = false;
            end
        end

        function [stale, ageSec] = isStale(obj)
            %ISSTALE Return true iff the lock body's server-side mtime is stale.
            %
            %   Staleness is determined ONLY by filesystem mtime (dir().datenum),
            %   never by the wall-clock acquired_at or heartbeat_at fields in the
            %   body. This prevents clock-skew false positives (Pitfall 9).
            %
            %   If the body file does not exist, returns false (no stale lock).
            %   If the body file's mtime is IN THE FUTURE (clock step-back or NTP
            %   jump), returns false for one cycle and logs a warning.
            %
            %   Output:
            %     stale  — logical
            %     ageSec — double; seconds since server-side mtime (NaN when unknown)

            stale  = false;
            ageSec = NaN;

            info = dir(obj.bodyPath_);
            if isempty(info)
                % No body file → no stale lock to break.
                return;
            end

            % Server-side filesystem mtime is the authoritative staleness clock (Pitfall 9).
            % dir(bodyPath_).datenum is the single-clock source of truth; wall-clock
            % acquired_at/heartbeat_at fields are NEVER used for staleness decisions.
            % Convert from MATLAB datenum (days) to seconds.
            mtimeDN   = dir(obj.bodyPath_).datenum;
            nowDN     = now();  %#ok<TNOW1>  % MATLAB datenum for 'now'
            deltaDays = nowDN - mtimeDN;

            if deltaDays < 0
                % mtime is in the future — clock step-back or NTP correction.
                % Do NOT declare stale; log warning and skip for one cycle (Pitfall 9).
                warning('Concurrency:futureMtime', ...
                    ['FileLock.isStale: mtime of body file is %.1f seconds in the future. ', ...
                     'This may indicate clock skew. Stale-takeover skipped for this cycle.'], ...
                    -deltaDays * 86400);
                stale  = false;
                ageSec = -deltaDays * 86400;
                return;
            end

            ageSec = deltaDays * 86400;   % convert days → seconds
            stale  = ageSec > obj.StaleTimeout;
        end

        function info = peek(obj)
            %PEEK Read and decode the body file without acquiring the lock.
            %   Returns the decoded body struct or [] on any error.
            %
            %   Output:
            %     info — struct (decoded body) or [] if absent or malformed
            info = [];
            if ~isfile(obj.bodyPath_)
                return;
            end
            try
                fid = fopen(obj.bodyPath_, 'r');
                if fid < 0
                    return;
                end
                txt = fread(fid, '*char')';
                fclose(fid);
                info = LockFileFormat.decodeBody(txt);
            catch
                info = [];
            end
        end

        function lp = lockPath(obj)
            %LOCKPATH Return the absolute path to the kernel lock file.
            lp = obj.lockPath_;
        end

        function bp = bodyPath(obj)
            %BODYPATH Return the absolute path to the identity body file.
            bp = obj.bodyPath_;
        end

        function delete(obj)
            %DELETE Destructor — release lock and clean up timer if still held.
            %   Idempotent.
            try
                obj.release();
            catch
            end
        end

    end

    % ------------------------------------------------------------------ %
    methods (Access = private)

        function acquired = acquireViaMex_(obj, tSec)
            %ACQUIREVIAMEX_ Acquire lock via lockfile_mex.
            %
            %   Input:
            %     tSec     — double; timeout in seconds (0 = non-blocking try)
            %   Output:
            %     acquired — logical

            h = lockfile_mex('acquire', obj.lockPath_, tSec);
            if h == int64(-1)
                acquired = false;
                return;
            end
            obj.handle_   = h;
            obj.identity_ = ClusterIdentity.resolve();
            obj.writeBody_();
            obj.startHeartbeat_();
            FileLock.heldKeys_(obj.lockPath_);  % mark as held
            acquired = true;
        end

        function acquired = acquireViaSidecar_(obj, tSec)
            %ACQUIREVIASIDESCAR_ Acquire lock via pure-MATLAB sidecar+rename fallback.
            %   Used when lockfile_mex is absent and Strict=false.
            %   Atomic on most filesystems via movefile rename semantics.
            %
            %   Input:
            %     tSec     — double; timeout in seconds (0 = single try)
            %   Output:
            %     acquired — logical

            obj.identity_ = ClusterIdentity.resolve();
            pid           = double(obj.identity_.pid);
            rnd           = sprintf('%06d', randi([0, 999999]));
            eps           = char(datetime('now', 'TimeZone', 'UTC'), 'yyyyMMddHHmmssSSS');
            tmpBody       = sprintf('%s.tmp.%d.%s.%s', obj.bodyPath_, pid, eps, rnd);

            % Write tentative body to temp file.
            txt = LockFileFormat.encodeBody(obj.identity_, obj.Key);
            fid = fopen(tmpBody, 'w');
            if fid < 0
                acquired = false;
                return;
            end
            fprintf(fid, '%s', txt);
            fclose(fid);

            deadline = tic();
            acquired = false;
            while true
                % Attempt atomic rename: movefile fails if destination already exists
                % when called WITHOUT the 'f' flag.
                try
                    movefile(tmpBody, obj.bodyPath_);  % no 'f' — fails if exists
                    % Re-read to verify WE own the body (race check).
                    if obj.stillHeldByMe()
                        % We own the body — sidecar acquire succeeded.
                        obj.handle_   = int64(1);   % sentinel for sidecar mode
                        FileLock.heldKeys_(obj.lockPath_);
                        obj.startHeartbeat_();
                        acquired = true;
                        return;
                    end
                    % Another process overwrote our body — we lost the race.
                catch
                    % movefile failed: body already exists (another holder).
                end

                if toc(deadline) >= tSec
                    break;
                end
                pause(0.05);
            end

            % Clean up temp file if rename never succeeded.
            if isfile(tmpBody)
                try, delete(tmpBody); catch, end
            end
        end

        function writeBody_(obj)
            %WRITEBODY_ Write the identity body file atomically.
            txt    = LockFileFormat.encodeBody(obj.identity_, obj.Key);
            pid    = double(obj.identity_.pid);
            eps    = char(datetime('now', 'TimeZone', 'UTC'), 'yyyyMMddHHmmssSSS');
            rnd    = sprintf('%06d', randi([0, 999999]));
            tmpBp  = sprintf('%s.tmp.%d.%s.%s', obj.bodyPath_, pid, eps, rnd);
            fid    = fopen(tmpBp, 'w');
            if fid < 0
                % Non-fatal: body write failed; heartbeat will retry.
                return;
            end
            fprintf(fid, '%s', txt);
            fclose(fid);
            try
                movefile(tmpBp, obj.bodyPath_, 'f');
            catch
                if isfile(tmpBp)
                    try, delete(tmpBp); catch, end
                end
            end
        end

        function startHeartbeat_(obj)
            %STARTHEARTBEAT_ Start the periodic body-rewrite timer.
            %   Rewrites the body file every HeartbeatInterval seconds to bump
            %   server-side mtime.  Uses BusyMode='drop' (Pitfall 7) so that
            %   long MATLAB pauses do not queue up missed heartbeat firings.

            t = timer( ...
                'ExecutionMode', 'fixedRate', ...
                'Period',        obj.HeartbeatInterval, ...
                'BusyMode',      'drop', ...
                'TimerFcn',      @(~, ~) obj.heartbeat_());
            start(t);
            obj.heartbeatTimer_ = t;
        end

        function heartbeat_(obj)
            %HEARTBEAT_ Periodic heartbeat: rewrite body to bump mtime.
            %   Only runs when the lock is still held (timer may fire after release).
            if isempty(obj.handle_) || ~isfile(obj.bodyPath_)
                return;
            end
            try
                fid = fopen(obj.bodyPath_, 'r');
                if fid < 0; return; end
                txt = fread(fid, '*char')';
                fclose(fid);
                txt = LockFileFormat.updateHeartbeat(txt);
                pid = double(obj.identity_.pid);
                eps = char(datetime('now', 'TimeZone', 'UTC'), 'yyyyMMddHHmmssSSS');
                rnd = sprintf('%06d', randi([0, 999999]));
                tmpBp = sprintf('%s.hb.%d.%s.%s', obj.bodyPath_, pid, eps, rnd);
                fid2 = fopen(tmpBp, 'w');
                if fid2 < 0; return; end
                fprintf(fid2, '%s', txt);
                fclose(fid2);
                movefile(tmpBp, obj.bodyPath_, 'f');
            catch
                % Non-fatal heartbeat failure; next timer tick will retry.
            end
        end

    end

end
