function out = readRawDelimitedForTest_(dispatch, varargin)
    %READRAWDELIMITEDFORTEST_ TEST-ONLY shim past private-folder scoping.
    %   out = readRawDelimitedForTest_('parse', path)
    %       Returns the parsed struct (forward of readRawDelimited_).
    %
    %   out = readRawDelimitedForTest_('sniff', path)
    %       Returns the selected delimiter char (derived from the parsed
    %       struct - sniffDelimiter_ itself is a nested helper inside
    %       readRawDelimited_.m and not independently reachable).
    %
    %   out = readRawDelimitedForTest_('select', parsed, rawSource)
    %       Returns a 1x2 cell {x, y} from selectTimeAndValue_.
    %
    %   [] = readRawDelimitedForTest_('write', outDir, tag, x, y, mode)
    %       Forwards to writeTagMat_ so tests can assert error IDs.
    %
    %   Revision-1 / Major-1 Option A - DO NOT CALL FROM PRODUCTION CODE.
    %
    %   This file lives OUTSIDE libs/SensorThreshold/private/ so it is
    %   reachable from tests/suite/*.m after install() addpath. It is the
    %   SOLE public surface of the otherwise-private parser helpers.
    %
    %   Phase 1012 file-count ledger: this file consumes the 12th (final)
    %   slot of the Pitfall 5 12-file budget (margin = 0). See
    %   .planning/phases/1012-.../1012-VALIDATION.md for rationale.
    %
    %   Production code (BatchTagPipeline, LiveTagPipeline) MUST NOT
    %   import this shim. A grep gate in this plan's acceptance criteria
    %   enforces the isolation.
    %
    %   Errors:
    %     TagPipeline:invalidTestDispatch - unknown dispatch string or
    %                                       missing required arguments

    switch dispatch
        case 'parse'
            if numel(varargin) < 1
                error('TagPipeline:invalidTestDispatch', ...
                    '''parse'' requires a path argument.');
            end
            out = readRawDelimited_(varargin{1});

        case 'sniff'
            if numel(varargin) < 1
                error('TagPipeline:invalidTestDispatch', ...
                    '''sniff'' requires a path argument.');
            end
            parsed = readRawDelimited_(varargin{1});
            out = parsed.delimiter;

        case 'select'
            if numel(varargin) < 2
                error('TagPipeline:invalidTestDispatch', ...
                    '''select'' requires (parsed, rawSource) args.');
            end
            [x, y] = selectTimeAndValue_(varargin{1}, varargin{2});
            out = {x, y};

        case 'write'
            if numel(varargin) < 5
                error('TagPipeline:invalidTestDispatch', ...
                    '''write'' requires (outDir, tag, x, y, mode) args.');
            end
            writeTagMat_(varargin{1}, varargin{2}, varargin{3}, ...
                varargin{4}, varargin{5});
            out = [];

        otherwise
            error('TagPipeline:invalidTestDispatch', ...
                'Unknown dispatch ''%s'' (expected: parse|sniff|select|write)', ...
                char(dispatch));
    end
end
