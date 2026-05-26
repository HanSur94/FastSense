function out = dispatchDelimitedParse_(path)
    %DISPATCHDELIMITEDPARSE_ Transparent MEX-or-fallback dispatch for delimited parse.
    %   Mirrors the FastSense convention (e.g. MonitorTag.recompute_'s
    %   to_step_function_mex / fallback dispatch): prefers the compiled
    %   `delimited_parse_mex` when available, falls back to the pure
    %   MATLAB/Octave `readRawDelimited_` when the binary is absent.
    %
    %   Output struct shape and field order are identical between both
    %   code paths — asserted at multiple scales by
    %   tests/suite/TestDelimitedParseParity (Phase 1028 K1, decision D-09).
    %
    %   This wrapper has the SAME signature as readRawDelimited_; call
    %   sites previously calling `readRawDelimited_(path)` should call
    %   `dispatchDelimitedParse_(path)` instead. Public API of Tag classes,
    %   LiveTagPipeline, BatchTagPipeline is unchanged (D-10).
    %
    %   Performance (Phase 1028 Wave 1):
    %     - K1 MEX is ~10–40× faster than the textscan-based fallback at
    %       1000-tag harness scale (8 wide CSVs × ≤4000 rows). Whether
    %       this translates to a meaningful tick-level Δ depends on
    %       parse-share-of-tick (see 1028-VERIFICATION.md tBreakdown row).
    %
    %   See also readRawDelimited_, delimited_parse_mex, LiveTagPipeline,
    %   BatchTagPipeline.

    persistent useMex_
    if isempty(useMex_)
        useMex_ = (exist('delimited_parse_mex', 'file') == 3);
    end

    if useMex_
        out = delimited_parse_mex(path);
    else
        out = readRawDelimited_(path);
    end
end
