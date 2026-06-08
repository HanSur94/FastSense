function test_machine_selector_pane()
%TEST_MACHINE_SELECTOR_PANE Octave-flat pure-logic tests for filterMachines.
%   Covers MACH-01: filterMachines(machines, term) substring logic over
%   Machine Name + Id (empty term = all, Name match, Id match, no match,
%   empty input). No uifigure required — headless safe.
%
%   Delegates to runFilterMachinesTests which lives inside
%   libs/FastSenseCompanion so that MATLAB's private-directory mechanism
%   makes filterMachines accessible (private functions are visible to
%   callers in the same folder). Mirrors test_companion_filter_tags.
%
%   See also filterMachines, MachineSelectorPane, runFilterMachinesTests.

    add_companion_path();
    runFilterMachinesTests();
end

function add_companion_path()
%ADD_COMPANION_PATH Add libs to path.
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
end
