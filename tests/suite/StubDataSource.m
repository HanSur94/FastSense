classdef StubDataSource < DataSource
    %STUBDATASOURCE Test-only DataSource that returns pre-armed results.
    %   Phase 1009 Plan 03 — deterministic live-tick fixture for
    %   LiveEventPipeline MonitorTag tests.  Each call to fetchNew()
    %   consumes the head of Queue_; subsequent calls return
    %   changed=false until another result is armed.
    %
    %   Pitfall 5 invariant: legacy MockDataSource is NOT modified —
    %   this helper lives in tests/suite/ so production code stays
    %   untouched.
    %
    %   Example:
    %     ds = StubDataSource();
    %     ds.setNextResult(struct('changed', true, 'X', 1:5, ...
    %         'Y', [1 1 20 20 1], 'stateX', [], 'stateY', {{}}));
    %     r = ds.fetchNew();  % returns the armed result
    %     r2 = ds.fetchNew(); % returns changed=false (queue empty)
    %
    %   See also DataSource, MockDataSource, TestLiveEventPipelineTag.

    properties (Access = private)
        Queue_ = {}   % cell of result structs; FIFO
    end

    methods
        function setNextResult(obj, result)
            %SETNEXTRESULT Enqueue a pre-armed fetchNew result.
            %   result must be a struct with fields:
            %     .changed, .X, .Y, .stateX, .stateY
            obj.Queue_{end+1} = result;
        end

        function result = fetchNew(obj)
            %FETCHNEW Return the next armed result, or an empty no-change.
            if isempty(obj.Queue_)
                result = DataSource.emptyResult();
                return;
            end
            result = obj.Queue_{1};
            obj.Queue_(1) = [];
        end
    end
end
