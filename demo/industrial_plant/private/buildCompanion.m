function companion = buildCompanion(ctx)
%BUILDCOMPANION Construct the FastSenseCompanion for the industrial plant demo.
%   companion = buildCompanion(ctx) wraps the demo's already-built
%   DashboardEngine (ctx.engine) and the populated TagRegistry singleton
%   inside a FastSenseCompanion window so the milestone canary covers
%   both surfaces with a single run_demo() invocation.
%
%   Preconditions:
%     - ctx.engine must be a live DashboardEngine handle (run_demo calls
%       ctx.engine = buildDashboard(ctx) BEFORE invoking this helper).
%     - TagRegistry singleton has been populated by registerPlantTags so
%       the companion's catalog reflects every plant tag.
%
%   Theme is hardcoded to 'light' -- matching buildDashboard.m which also
%   renders the demo dashboard in 'light' theme. Keeping the two windows
%   visually consistent. If the demo gains a theme option in a later
%   phase, lift this through ctx.
%
%   Returns:
%     companion - live FastSenseCompanion handle (uifigure already visible).
%
%   See also: run_demo, teardownDemo, FastSenseCompanion, buildDashboard.

    companion = FastSenseCompanion( ...
        'Dashboards', {ctx.engine}, ...
        'Theme',      'light');
end
