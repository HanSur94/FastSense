function test_fastsense_datenum_autopromote()
%TEST_FASTSENSE_DATENUM_AUTOPROMOTE Auto-promote XType when X sits in datenum range.
%   FastSense.addLine auto-promotes XType='datenum' (and IsDatetime=true)
%   when numeric X values fall inside the MATLAB serial-date window for
%   years 1910-2100 (697000..769000). Keeps Tag/SensorTag data
%   timestamped with now() rendering as dates without every caller
%   passing 'XType','datenum' by hand.
%
%   Guards checked:
%     - numeric X in datenum range           -> promotes to 'datenum'
%     - numeric X below the datenum window   -> stays 'numeric'
%     - explicit 'XType','numeric' NV-pair   -> suppresses promotion
%     - empty X                              -> stays 'numeric'
%     - X straddling the window              -> stays 'numeric'

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();

    % --- Auto-promote: X in the datenum range -------------------------
    fp = FastSense();
    xDate = now() + (0:100) / 86400;
    fp.addLine(xDate, sin(1:numel(xDate)));
    assert(strcmp(fp.XType, 'datenum'), ...
        'testAutoPromote: expected XType=datenum, got %s', fp.XType);
    assert(fp.IsDatetime, 'testAutoPromote: IsDatetime must flip to true');

    % --- No promotion: small-integer X (sample indices) ---------------
    fp = FastSense();
    fp.addLine(1:100, rand(1, 100));
    assert(strcmp(fp.XType, 'numeric'), ...
        'testSmallX: expected XType=numeric, got %s', fp.XType);
    assert(~fp.IsDatetime, 'testSmallX: IsDatetime must stay false');

    % --- Explicit opt-out: 'XType','numeric' in the datenum window ---
    % A caller with numeric counters in that range must be able to
    % suppress the heuristic — e.g. step counters starting at 700000.
    fp = FastSense();
    xCounter = 700000 + (0:50);
    fp.addLine(xCounter, rand(1, numel(xCounter)), 'XType', 'numeric');
    assert(strcmp(fp.XType, 'numeric'), ...
        'testExplicitOptOut: expected XType=numeric, got %s', fp.XType);
    assert(~fp.IsDatetime, 'testExplicitOptOut: IsDatetime must stay false');

    % --- Explicit opt-in: 'XType','datenum' on any numeric data ------
    fp = FastSense();
    fp.addLine(1:10, (1:10).^2, 'XType', 'datenum');
    assert(strcmp(fp.XType, 'datenum'), ...
        'testExplicitOptIn: expected XType=datenum, got %s', fp.XType);

    % --- No promotion: X straddles the datenum window ----------------
    fp = FastSense();
    xMixed = linspace(500000, 800000, 50);   % crosses both bounds
    fp.addLine(xMixed, rand(1, numel(xMixed)));
    assert(strcmp(fp.XType, 'numeric'), ...
        'testStraddle: expected XType=numeric, got %s', fp.XType);

    % --- Empty X is a no-op on the heuristic -------------------------
    fp = FastSense();
    fp.addLine([], []);
    assert(strcmp(fp.XType, 'numeric'), ...
        'testEmpty: expected XType=numeric, got %s', fp.XType);

    fprintf('    All 6 datenum auto-promote tests passed.\n');
end
