classdef ClusterIdentity
%CLUSTERIDENTITY Resolve and cache the (user, host, pid, epoch) tuple
%   used to stamp every shared write. Single source of truth for
%   identity in v4.0 cluster mode.
%
%   ClusterIdentity.resolve()                 -> struct (cached)
%   ClusterIdentity.resolve('Strict', true)   -> struct, throws on empty user/host
%   ClusterIdentity.resolve(NV-pairs)         -> overrides (testing only)
%   ClusterIdentity.pid()                     -> int64
%   ClusterIdentity.clearCache()              -> void (test reset)
%
%   Identity struct fields:
%     .user   — OS username (char, non-empty when resolvable)
%     .host   — hostname     (char, non-empty when resolvable)
%     .pid    — process ID   (int64)
%     .epoch  — UTC datetime of first resolve call (datetime, TimeZone='UTC')
%
%   Errors:
%     Concurrency:identityResolutionFailed — Strict=true and user or host is empty
%     Concurrency:unknownOption            — unrecognised option key passed
%
%   See also userIdentity, ClusterConfig, SharedPaths.

    methods (Static)

        function id = resolve(varargin)
            %RESOLVE Return the (user, host, pid, epoch) identity struct.
            %   id = ClusterIdentity.resolve() — returns cached struct.
            %   id = ClusterIdentity.resolve('Strict', true) — throws
            %       Concurrency:identityResolutionFailed if user or host
            %       cannot be resolved (IDENT-01 cluster-mode guard).
            %   id = ClusterIdentity.resolve('OverrideUser', u, 'OverrideHost', h)
            %       — bypass cache and inject values (testing only).
            %
            %   Input:
            %     varargin — name-value pairs: Strict (logical), OverrideUser (char),
            %                OverrideHost (char)
            %   Output:
            %     id — scalar struct with .user, .host, .pid, .epoch fields

            % Parse NV-pairs: Strict (logical, default false), OverrideUser, OverrideHost
            strict = false;
            hasOverrideUser = false;   % true iff OverrideUser key was provided
            hasOverrideHost = false;
            overrideUser = '';
            overrideHost = '';
            for k = 1:2:numel(varargin)
                key = varargin{k};
                val = varargin{k + 1};
                switch key
                    case 'Strict'
                        strict = logical(val);
                    case 'OverrideUser'
                        overrideUser = char(val);
                        hasOverrideUser = true;
                    case 'OverrideHost'
                        overrideHost = char(val);
                        hasOverrideHost = true;
                    otherwise
                        error('Concurrency:unknownOption', ...
                            'Unknown option ''%s'' to ClusterIdentity.resolve.', key);
                end
            end

            cached = ClusterIdentity.cache_();
            useCache = ~hasOverrideUser && ~hasOverrideHost;
            if useCache && isfield(cached, 'user')
                id = cached;
                if strict && (isempty(id.user) || isempty(id.host))
                    error('Concurrency:identityResolutionFailed', ...
                        'Could not resolve identity: user=''%s'' host=''%s''.', id.user, id.host);
                end
                return;
            end

            [u, h] = userIdentity();
            if hasOverrideUser
                u = overrideUser;
            end
            if hasOverrideHost
                h = overrideHost;
            end

            id = struct();
            id.user  = u;
            id.host  = h;
            id.pid   = ClusterIdentity.pid();
            id.epoch = datetime('now', 'TimeZone', 'UTC');

            if strict && (isempty(id.user) || isempty(id.host))
                error('Concurrency:identityResolutionFailed', ...
                    'Could not resolve identity: user=''%s'' host=''%s''.', id.user, id.host);
            end

            if useCache
                ClusterIdentity.cache_(id);
            end
        end

        function p = pid()
            %PID Return the current process ID as int64.
            %   Centralises feature('getpid') (MATLAB) vs getpid() (Octave).
            %
            %   Output:
            %     p — int64 process ID
            if exist('OCTAVE_VERSION', 'builtin') == 5
                p = int64(getpid());
            else
                p = int64(feature('getpid'));
            end
        end

        function clearCache()
            %CLEARCACHE Reset the persistent identity cache.
            %   Call between tests to force re-resolution on next resolve().
            ClusterIdentity.cache_(struct());
        end

    end

    methods (Static, Access = private)

        function out = cache_(replacement)
            %CACHE_ Get or replace the persistent identity cache.
            %   cache_()           — returns the current cached struct
            %   cache_(newStruct)  — replaces the cache and returns it
            persistent cached;
            if isempty(cached)
                cached = struct();
            end
            if nargin >= 1
                cached = replacement;
            end
            out = cached;
        end

    end
end
