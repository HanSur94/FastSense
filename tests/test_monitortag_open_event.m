function test_monitortag_open_event
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root); install();
    fprintf('    SKIP testRisingEdgeEmitsOpenEvent: Plan 1012-02 will wire.\n');
    fprintf('    SKIP testFallingEdgeCallsCloseEvent: Plan 1012-02 will wire.\n');
    fprintf('    SKIP testRunningStatsAccumulateDuringOpenRun: Plan 1012-02 will wire.\n');
    fprintf('    SKIP testOpenRunStatsFinalizedOnClose: Plan 1012-02 will wire.\n');
    fprintf('    All 0 tests passed (4 skipped pending Plan 1012-02).\n');
end
