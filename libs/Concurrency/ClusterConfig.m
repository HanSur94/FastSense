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

    end
end
