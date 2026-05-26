classdef SharedPaths
%SHAREDPATHS Static path builders for the v4.0 cluster-mode shared filesystem.
%
%   All methods are stateless and static. The shared root is resolved via
%   the opts.SharedRoot field or the FASTSENSE_SHARED_ROOT environment
%   variable — single-user mode (no SharedRoot) is the default.
%
%   SharedPaths.isClusterMode()         -> false (single-user default)
%   SharedPaths.isClusterMode(opts)     -> true iff resolveRoot(opts) non-empty
%   SharedPaths.resolveRoot()           -> '' (single-user)
%   SharedPaths.resolveRoot(opts)       -> SharedRoot char or ''
%   SharedPaths.tagsDir(root)           -> fullfile(root, 'tags')
%   SharedPaths.locksDir(root)          -> fullfile(root, 'locks')
%   SharedPaths.eventsDir(root)         -> fullfile(root, 'events')
%
%   Precedence for resolveRoot: opts.SharedRoot > FASTSENSE_SHARED_ROOT env > ''
%
%   See also ClusterConfig, ClusterIdentity.

    methods (Static)

        function tf = isClusterMode(opts)
            %ISCLUSTERMODE Return true iff a shared root is configured.
            %
            %   Input:
            %     opts — (optional) struct; checked for .SharedRoot field
            %   Output:
            %     tf — logical scalar; true when cluster mode is active
            if nargin < 1
                opts = struct();
            end
            tf = ~isempty(SharedPaths.resolveRoot(opts));
        end

        function root = resolveRoot(opts)
            %RESOLVEROOT Resolve the shared filesystem root path.
            %   Precedence: opts.SharedRoot > getenv('FASTSENSE_SHARED_ROOT') > ''
            %
            %   Input:
            %     opts — (optional) struct; may have .SharedRoot field
            %   Output:
            %     root — char; empty string in single-user mode
            if nargin >= 1 && isstruct(opts) && isfield(opts, 'SharedRoot') && ...
                    ~isempty(opts.SharedRoot)
                root = char(opts.SharedRoot);
                return;
            end
            env = getenv('FASTSENSE_SHARED_ROOT');
            if ~isempty(env)
                root = env;
                return;
            end
            root = '';
        end

        function p = tagsDir(root)
            %TAGSDIR Return the tags subdirectory path under root.
            %
            %   Input:
            %     root — char; shared filesystem root
            %   Output:
            %     p — char; fullfile(root, 'tags')
            p = fullfile(root, 'tags');
        end

        function p = locksDir(root)
            %LOCKSDIR Return the locks subdirectory path under root.
            %
            %   Input:
            %     root — char; shared filesystem root
            %   Output:
            %     p — char; fullfile(root, 'locks')
            p = fullfile(root, 'locks');
        end

        function p = eventsDir(root)
            %EVENTSDIR Return the events subdirectory path under root.
            %
            %   Input:
            %     root — char; shared filesystem root
            %   Output:
            %     p — char; fullfile(root, 'events')
            p = fullfile(root, 'events');
        end

    end
end
