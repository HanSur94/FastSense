function teardownDemo(ctx)
%TEARDOWNDEMO Stop all demo runtime components and clear the TagRegistry.
%   teardownDemo(ctx) gracefully tears down the components started by
%   run_demo. Every step is wrapped in try/catch so one failure does not
%   block the others -- teardown is best-effort by design (D-13).
%
%   ctx fields (any may be [] / missing):
%     writerTimer - MATLAB timer returned by makeDataGenerator
%     pipeline    - LiveTagPipeline returned by startLivePipeline
%     engine      - DashboardEngine (wired in by plan 02)
%
%   Regardless of ctx contents, the final step always clears TagRegistry.
%
%   See also: run_demo, makeDataGenerator, startLivePipeline.

    if nargin < 1 || isempty(ctx) || ~isstruct(ctx)
        ctx = struct();
    end

    % ---- Writer timer ----
    if isfield(ctx, 'writerTimer') && ~isempty(ctx.writerTimer)
        try
            if isvalid(ctx.writerTimer)
                stop(ctx.writerTimer);
                delete(ctx.writerTimer);
            end
        catch
            % Best-effort -- swallow.
        end
    end

    % Also sweep any stray IndustrialPlantDataGen timers that leaked from
    % prior runs; this keeps timerfindall clean across repeated test runs.
    try
        stragglers = timerfindall('Name', 'IndustrialPlantDataGen');
        for i = 1:numel(stragglers)
            try
                stop(stragglers(i));
            catch
            end
            try
                delete(stragglers(i));
            catch
            end
        end
    catch
    end

    % ---- Live pipeline ----
    if isfield(ctx, 'pipeline') && ~isempty(ctx.pipeline)
        try
            ctx.pipeline.stop();
        catch
            % Best-effort.
        end
    end

    % ---- Dashboard engine (plan 02 wires this) ----
    if isfield(ctx, 'engine') && ~isempty(ctx.engine)
        try
            % DashboardEngine uses stopLive() to halt the live timer
            % (no plain stop() method). Try stopLive() first, fall back
            % to stop() for forward compatibility.
            if ismethod(ctx.engine, 'stopLive')
                ctx.engine.stopLive();
            elseif ismethod(ctx.engine, 'stop')
                ctx.engine.stop();
            end
        catch
        end
    end

    % Also sweep dashboard LiveTimer stragglers that might have leaked.
    try
        stragglers = timerfindall('Tag', 'DashboardEngine');
        for i = 1:numel(stragglers)
            try stop(stragglers(i)); catch, end
            try delete(stragglers(i)); catch, end
        end
    catch
    end

    % ---- Final: TagRegistry.clear() always runs ----
    try
        TagRegistry.clear();
    catch
    end
end
