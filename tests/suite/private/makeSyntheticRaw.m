function files = makeSyntheticRaw(testCase)
    %MAKESYNTHETICRAW Create synthetic raw-data fixtures in a tempdir.
    %   files = makeSyntheticRaw(testCase) creates a set of synthetic CSV/TXT/DAT
    %   files in a unique tempdir. The caller's testCase.addTeardown removes the
    %   whole tempdir (recursive rmdir) after the test method completes.
    %
    %   Phase 1012 Wave 0 (D-03) — no real sample data is committed to the
    %   repository. All pipeline tests in Phase 1012 obtain their raw inputs
    %   through this helper. It lives under tests/suite/private/ so it is
    %   visible to every suite under tests/suite/ but NOT to flat function
    %   tests (by MATLAB's private/ scoping rule) — deliberate.
    %
    %   Returned fields (all char absolute paths):
    %     files.dir              — the tempdir root
    %     files.wideCsv          — 4-col wide CSV (time,pressure_a,pressure_b,temperature)
    %     files.tallTxt          — 2-col whitespace TXT (time value), no header
    %     files.tallDat          — 2-col tab DAT (time<tab>flow_rate), with header
    %     files.semiCsv          — semicolon-delimited CSV (time;level), with header
    %     files.empty            — zero-byte file
    %     files.headerOnly       — header row only, zero data rows
    %     files.corrupt          — malformed (inconsistent column counts per line)
    %     files.stateCellstrCsv  — time,state (cellstr Y) with states: idle/running/idle
    %     files.missingColumn    — wide file where 'pressure_b' column is absent
    %     files.sharedFile       — file intended to be referenced by >=2 tags (de-dup test)
    %
    %   Uses only fopen / fprintf / fclose / mkdir / tempname / rmdir so it is
    %   fully portable across MATLAB R2020b+ and Octave 7+. No readtable /
    %   writetable / readmatrix / csvwrite dependency.
    %
    %   See also: TestRawDelimitedParser, TestBatchTagPipeline, TestLiveTagPipeline.

    d = tempname();
    mkdir(d);
    testCase.addTeardown(@() rmdir(d, 's'));
    files.dir = d;

    % Wide CSV (comma, with header)
    files.wideCsv = fullfile(d, 'logger_wide.csv');
    fid = fopen(files.wideCsv, 'w');
    fprintf(fid, 'time,pressure_a,pressure_b,temperature\n');
    fprintf(fid, '%d,%d,%d,%d\n', [1 10 20 30; 2 11 21 31; 3 12 22 32]');
    fclose(fid);

    % Tall TXT (whitespace, NO header)
    files.tallTxt = fullfile(d, 'level.txt');
    fid = fopen(files.tallTxt, 'w');
    fprintf(fid, '1 100\n2 101\n3 102\n');
    fclose(fid);

    % Tall DAT (tab, with header)
    files.tallDat = fullfile(d, 'flow.dat');
    fid = fopen(files.tallDat, 'w');
    fprintf(fid, 'time\tflow_rate\n1\t3.14\n2\t3.15\n3\t3.16\n');
    fclose(fid);

    % Semicolon CSV (with header)
    files.semiCsv = fullfile(d, 'level_semi.csv');
    fid = fopen(files.semiCsv, 'w');
    fprintf(fid, 'time;level\n1;5.0\n2;5.1\n3;5.2\n');
    fclose(fid);

    % Empty file (0 bytes)
    files.empty = fullfile(d, 'empty.csv');
    fid = fopen(files.empty, 'w');
    fclose(fid);

    % Header-only (1 line, no data)
    files.headerOnly = fullfile(d, 'header_only.csv');
    fid = fopen(files.headerOnly, 'w');
    fprintf(fid, 'time,value\n');
    fclose(fid);

    % Corrupt: inconsistent column count line-to-line
    files.corrupt = fullfile(d, 'corrupt.csv');
    fid = fopen(files.corrupt, 'w');
    fprintf(fid, 'a,b,c\n1,2,3\n4,5\n6,7,8,9\n');
    fclose(fid);

    % State-cellstr CSV (time + cellstr state values)
    files.stateCellstrCsv = fullfile(d, 'mode.csv');
    fid = fopen(files.stateCellstrCsv, 'w');
    fprintf(fid, 'time,state\n1,idle\n2,running\n3,idle\n');
    fclose(fid);

    % Wide file missing a named column (pressure_b absent)
    files.missingColumn = fullfile(d, 'missing_col.csv');
    fid = fopen(files.missingColumn, 'w');
    fprintf(fid, 'time,pressure_a\n1,10\n2,11\n');
    fclose(fid);

    % Shared-file (used by two tags in de-dup tests)
    files.sharedFile = fullfile(d, 'shared.csv');
    fid = fopen(files.sharedFile, 'w');
    fprintf(fid, 'time,p_a,p_b\n1,1,10\n2,2,20\n3,3,30\n');
    fclose(fid);
end
