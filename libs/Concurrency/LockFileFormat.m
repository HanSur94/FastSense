classdef LockFileFormat
%LOCKFILEFORMAT Encode/decode the body of a FastSense lockfile.
%
%   The body is a plain-text key:value file (NOT JSON, to avoid the
%   jsonencode(datetime) gap documented in 1029-RESEARCH.md Unknown 7).
%
%   Schema (one field per line, '<name>: <value>'):
%     key          — lock key name
%     user         — OS username
%     host         — hostname
%     pid          — process ID (decimal integer)
%     epoch        — ISO 8601 UTC datetime of first resolve call
%     acquired_at  — ISO 8601 UTC datetime of lock acquire (wall-clock forensics only)
%     heartbeat_at — ISO 8601 UTC datetime of most recent heartbeat write
%
%   Staleness detection uses filesystem mtime (dir().datenum), NOT acquired_at.
%   The acquired_at and heartbeat_at fields are forensics-only (Pitfall 9).
%
%   Methods (Static):
%     txt = LockFileFormat.encodeBody(identity, key)
%     s   = LockFileFormat.decodeBody(txt)
%     txt = LockFileFormat.updateHeartbeat(txt)
%
%   Errors:
%     Concurrency:lockFileBodyMalformed — missing or unparseable field
%
%   See also FileLock, ClusterIdentity.

    methods (Static)

        function txt = encodeBody(identity, key)
            %ENCODEBODY Encode a lockfile body string from identity and key.
            %   txt = LockFileFormat.encodeBody(identity, key)
            %
            %   Input:
            %     identity — struct from ClusterIdentity.resolve() with .user, .host,
            %                .pid (int64), .epoch (datetime UTC)
            %     key      — char or string lock key name
            %   Output:
            %     txt      — char row vector; plain-text key:value body with trailing newline

            if ~isstruct(identity) || ~isfield(identity, 'user') || ~isfield(identity, 'host')
                error('Concurrency:lockFileBodyMalformed', ...
                    'encodeBody requires a struct with user, host, pid, epoch fields.');
            end
            tNow = datetime('now', 'TimeZone', 'UTC');
            tEpoch = identity.epoch;
            if ~isa(tEpoch, 'datetime')
                tEpoch = datetime(tEpoch, 'TimeZone', 'UTC');
            end
            fmt = 'yyyy-MM-dd''T''HH:mm:ss''Z''';
            lines = { ...
                sprintf('key: %s',          char(key)), ...
                sprintf('user: %s',         identity.user), ...
                sprintf('host: %s',         identity.host), ...
                sprintf('pid: %d',          double(identity.pid)), ...
                sprintf('epoch: %s',        char(tEpoch, fmt)), ...
                sprintf('acquired_at: %s',  char(tNow, fmt)), ...
                sprintf('heartbeat_at: %s', char(tNow, fmt)) ...
            };
            txt = [strjoin(lines, newline()), newline()];
        end

        function s = decodeBody(txt)
            %DECODEBODY Parse a lockfile body string into a struct.
            %   s = LockFileFormat.decodeBody(txt)
            %
            %   Input:
            %     txt — char or string; lockfile body as produced by encodeBody
            %   Output:
            %     s   — struct with fields: .key, .user, .host, .pid (int64),
            %           .epoch (datetime UTC), .acquired_at (datetime UTC),
            %           .heartbeat_at (datetime UTC)
            %
            %   Throws Concurrency:lockFileBodyMalformed on missing or bad fields.

            lines = regexp(txt, '\r?\n', 'split');
            fmt = 'yyyy-MM-dd''T''HH:mm:ss''Z''';
            required = {'key', 'user', 'host', 'pid', 'epoch', 'acquired_at', 'heartbeat_at'};
            s = struct();
            for k = 1:numel(lines)
                L = strtrim(lines{k});
                if isempty(L)
                    continue;
                end
                tok = regexp(L, '^([a-zA-Z_]+):\s*(.*)$', 'tokens', 'once');
                if isempty(tok)
                    continue;
                end
                fname = tok{1};
                val   = tok{2};
                switch fname
                    case 'pid'
                        s.(fname) = int64(str2double(val));
                    case {'epoch', 'acquired_at', 'heartbeat_at'}
                        try
                            s.(fname) = datetime(val, 'InputFormat', fmt, 'TimeZone', 'UTC');
                        catch
                            error('Concurrency:lockFileBodyMalformed', ...
                                'Could not parse field ''%s'' = ''%s''.', fname, val);
                        end
                    otherwise
                        s.(fname) = val;
                end
            end
            for r = 1:numel(required)
                if ~isfield(s, required{r})
                    error('Concurrency:lockFileBodyMalformed', ...
                        'Lock body missing required field ''%s''.', required{r});
                end
            end
        end

        function txt = updateHeartbeat(txt)
            %UPDATEHEARTBEAT Rewrite the heartbeat_at field with the current UTC time.
            %   txt = LockFileFormat.updateHeartbeat(txt)
            %
            %   Input:
            %     txt — char; existing lockfile body
            %   Output:
            %     txt — char; body with heartbeat_at line replaced by current time
            %
            %   Only the heartbeat_at line is modified; all other fields are preserved.

            fmt  = 'yyyy-MM-dd''T''HH:mm:ss''Z''';
            tNow = char(datetime('now', 'TimeZone', 'UTC'), fmt);
            txt  = regexprep(txt, ...
                '^heartbeat_at:.*$', ...
                ['heartbeat_at: ', tNow], ...
                'lineanchors');
            % Ensure trailing newline is preserved (regexprep may strip on some platforms).
            if isempty(txt) || txt(end) ~= newline()
                txt = [txt, newline()];
            end
        end

    end
end
