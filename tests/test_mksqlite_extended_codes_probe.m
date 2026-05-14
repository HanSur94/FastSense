function test_mksqlite_extended_codes_probe()
%TEST_MKSQLITE_EXTENDED_CODES_PROBE Capture mksqlite ME.message for SQLITE_BUSY.
%
%   Phase 1029 probe (Unknown 5 from 1029-RESEARCH.md). Records the exact
%   ME.message substring emitted by bundled mksqlite when SQLite returns
%   SQLITE_BUSY (and best-effort SQLITE_BUSY_SNAPSHOT). Output is appended
%   to .planning/phases/1029-foundation/1029-PROBES.md and consumed by
%   Phase 1032's retry wrapper.
%
%   The probe uses two mksqlite connections to the same database file:
%   connection A holds BEGIN IMMEDIATE (write transaction), connection B
%   then attempts BEGIN IMMEDIATE — which triggers SQLITE_BUSY because the
%   database is already reserved for writing.
%
%   SQLITE_BUSY_SNAPSHOT cannot be reliably triggered in a single MATLAB
%   session without WAL mode and careful read-snapshot management; that
%   capture is deferred to Phase 1032 multi-process stress probes.
%
%   Errors:
%     mksqlite_probe:mksqliteUnavailable — mksqlite is not on the path

    if exist('mksqlite', 'file') ~= 3 && exist('mksqlite', 'file') ~= 2
        error('mksqlite_probe:mksqliteUnavailable', ...
            'mksqlite is not on the path (which mksqlite is empty).');
    end

    nPassed = 0;
    busyMsg = '';
    snapshotMsg = 'NOT_REPRODUCED_IN_PROBE — capture under multi-process stress in Phase 1032';

    tmpDB = [tempname(), '.sqlite'];
    cleaner = onCleanup(@() local_cleanup_db_(tmpDB)); %#ok<NASGU>

    dbA = [];
    dbB = [];

    % Open connection A — holds a BEGIN IMMEDIATE (write reservation)
    try
        dbA = mksqlite('open', tmpDB);
        mksqlite(dbA, 'CREATE TABLE IF NOT EXISTS t (id INTEGER PRIMARY KEY, v TEXT)');
        mksqlite(dbA, 'BEGIN IMMEDIATE');
        mksqlite(dbA, 'INSERT INTO t (v) VALUES (''a'')');
    catch outerME
        fprintf(2, 'PROBE setup failed on connection A: %s\n', outerME.message);
        local_close_safe_(dbA);
        error('mksqlite_probe:setupFailed', ...
            'Failed to set up connection A for busy trigger: %s', outerME.message);
    end

    % Open connection B — attempt BEGIN IMMEDIATE on the already-reserved DB.
    % busy_timeout = 100 ms makes it return quickly rather than blocking.
    try
        dbB = mksqlite('open', tmpDB);
        mksqlite(dbB, 'PRAGMA busy_timeout = 100');
        try
            mksqlite(dbB, 'BEGIN IMMEDIATE');
            % If we reach here, the busy was not triggered (unexpected).
            % Insert to ensure we detect it later.
            mksqlite(dbB, 'INSERT INTO t (v) VALUES (''b'')');
            mksqlite(dbB, 'COMMIT');
            fprintf(2, 'WARN: expected SQLITE_BUSY on connection B but second BEGIN IMMEDIATE succeeded\n');
        catch ME
            busyMsg = ME.message;
            nPassed = nPassed + 1;
            fprintf('    Captured SQLITE_BUSY message: ''%s''\n', busyMsg);
        end
    catch setupME
        fprintf(2, 'PROBE: failed to open connection B: %s\n', setupME.message);
    end

    % Clean up connections
    try, mksqlite(dbA, 'ROLLBACK'); catch, end
    local_close_safe_(dbA);
    local_close_safe_(dbB);

    % Capture lockfile_mex branch info for the PROBES.md record
    lfBranch  = 'UNAVAILABLE';
    lfOs      = 'UNAVAILABLE';
    lfPidKind = 'UNAVAILABLE';
    try
        info      = lockfile_mex('probe');
        lfBranch  = info.branch;
        lfOs      = info.os;
        lfPidKind = sprintf('int64 (pid=%d)', double(info.pid));
    catch
        % lockfile_mex unavailable — document but do not fail probe
    end

    % Capture host kernel on POSIX
    hostKernel = '';
    if ~ispc
        try
            [s, out] = system('uname -r');
            if s == 0
                hostKernel = strtrim(out);
            end
        catch
            hostKernel = '';
        end
    end

    % Locate repo root relative to this test file
    here = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    probesPath = fullfile(repoRoot, '.planning', 'phases', '1029-foundation', '1029-PROBES.md');

    % Append structured probe section to 1029-PROBES.md
    [u, h] = userIdentity();
    nowISO = char(datetime('now', 'TimeZone', 'UTC'), 'yyyy-MM-dd''T''HH:mm:ss''Z''');

    fid = fopen(probesPath, 'a');
    if fid < 0
        fprintf(2, 'WARN: could not append to %s\n', probesPath);
    else
        fprintf(fid, '## mksqlite Probe — captured %s on %s\n\n', nowISO, h);
        fprintf(fid, 'mksqlite_busy_string: "%s"\n', strrep(busyMsg, '"', '\\"'));
        fprintf(fid, 'mksqlite_busy_snapshot_string: "%s"\n', snapshotMsg);
        fprintf(fid, 'lockfile_mex_branch: %s\n', lfBranch);
        fprintf(fid, 'lockfile_mex_os: %s\n', lfOs);
        fprintf(fid, 'lockfile_mex_pid_kind: %s\n', lfPidKind);
        fprintf(fid, 'host_kernel: %s\n', hostKernel);
        fprintf(fid, 'probe_run_at: %s\n', nowISO);
        fprintf(fid, 'probe_run_by: %s@%s\n\n', u, h);
        fclose(fid);
    end

    % Fail only if we could not capture any SQLITE_BUSY message at all
    if isempty(busyMsg)
        error('mksqlite_probe:noBusyCaptured', ...
            ['Failed to capture SQLITE_BUSY ME.message from bundled mksqlite. ' ...
             'Check mksqlite availability and SQLite version.']);
    end

    nTotal = nPassed;
    fprintf('    %d/%d probe captures successful.\n', nPassed, nTotal);
end

% ---------------------------------------------------------------------------
function local_cleanup_db_(p)
%LOCAL_CLEANUP_DB_ Delete temp SQLite DB file if present.
    if ischar(p) && ~isempty(p) && exist(p, 'file') == 2
        try, delete(p); catch, end
    end
end

function local_close_safe_(dbId)
%LOCAL_CLOSE_SAFE_ Close an mksqlite connection, ignoring errors.
    if ~isempty(dbId)
        try, mksqlite(dbId, 'close'); catch, end
    end
end
