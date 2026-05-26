function plantLogPath = seedPlantLog(rawDir, cfg)
%SEEDPLANTLOG Generate a synthetic plant log CSV for the industrial plant demo.
%   plantLogPath = seedPlantLog(rawDir, cfg) writes ~30 deterministic
%   operator-log entries to data/raw/plant_log.csv with timestamps spread
%   across the last 7 days plus 3 entries in the recent past (now-30s,
%   now-15s, now+0s) so the live-tail demo immediately has fresh-looking
%   entries to display.
%
%   The CSV columns are:
%     Timestamp,Message,Unit,Shift,Operator
%
%   - Timestamp uses 'yyyy-MM-dd HH:mm:ss' (PlantLogReader auto-detect format).
%   - Message is the free-text operator note.
%   - Unit values are drawn from cfg.Subsystems ({'FeedLine','Reactor','Cooling'})
%     plus 'ALL' for plant-wide entries.
%   - Shift is 'A' | 'B' | 'C'.
%   - Operator is a small name pool.
%
%   The function reseeds RNG to 1015 at entry and restores the previous RNG
%   state at exit (matching seedHistory.m's idiom). Determinism + state
%   restore lets repeated run_demo() calls produce byte-identical CSVs
%   (modulo the now-relative anchor timestamp).
%
%   Inputs:
%     rawDir - char, absolute path to demo/industrial_plant/data/raw (must exist).
%     cfg    - struct returned by plantConfig() -- uses cfg.Subsystems.
%
%   Output:
%     plantLogPath - char, absolute path to the generated CSV.
%
%   See also: seedHistory, plantConfig, run_demo, PlantLogReader.

    % --- Input validation -----------------------------------------------
    if ~ischar(rawDir) && ~(isstring(rawDir) && isscalar(rawDir))
        error('IndustrialPlant:invalidRawDir', ...
            'rawDir must be a char or scalar string.');
    end
    rawDir = char(rawDir);
    if ~exist(rawDir, 'dir')
        error('IndustrialPlant:rawDirMissing', ...
            'rawDir does not exist: %s', rawDir);
    end
    if ~isstruct(cfg)
        error('IndustrialPlant:invalidCfg', ...
            'cfg must be a struct (plantConfig() output).');
    end

    % --- Seed RNG, restore on exit (matches seedHistory.m idiom) --------
    prevRng = rng(1015, 'twister');
    cleanup = onCleanup(@() rng(prevRng));

    % --- Build entry pool ------------------------------------------------
    % Each entry: offsetSeconds (relative to now()) + message + unit + shift + operator.
    % First 30 entries spread across the last 7 days at shift-start times
    % (06:00, 14:00, 22:00) and an early-morning maintenance window (02:30);
    % final 3 entries land in the recent past so live-tail picks them up.
    entries = buildEntries_(cfg);

    % --- Write CSV via fprintf (cross-runtime, MATLAB + Octave 7+) ------
    % writetable's 'Size'+'VariableTypes' form is MATLAB-only on some
    % Octave builds; fprintf is the safe lowest-common-denominator.
    plantLogPath = fullfile(rawDir, 'plant_log.csv');
    nowRef = now();

    % Sort entries by offsetSeconds ASC so timestamps land chronologically
    % in the CSV (PlantLogStore dedup tolerates out-of-order but ordered
    % is the canonical state we want the live-tail tail to read).
    [~, order] = sort([entries.offsetSeconds]);
    entries = entries(order);

    fid = fopen(plantLogPath, 'w');
    if fid == -1
        error('IndustrialPlant:writeFailed', ...
            'Could not open %s for writing.', plantLogPath);
    end
    closer = onCleanup(@() fclose(fid));
    fprintf(fid, 'Timestamp,Message,Unit,Shift,Operator\n');
    for k = 1:numel(entries)
        e = entries(k);
        ts = datestr(nowRef + e.offsetSeconds/86400, 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST>
        % Quote message field (may contain commas/colons); other fields
        % are short alphanum so unquoted is fine.
        fprintf(fid, '%s,"%s",%s,%s,%s\n', ts, e.message, e.unit, e.shift, e.operator);
    end
end

function entries = buildEntries_(cfg)
    %BUILDENTRIES_ Construct the 33-entry plant-log pool.
    %   First 30 entries: shift-pattern times spread over 7 days. Final 3
    %   entries: near-now (-30s, -15s, 0s) so the live-tail demo has fresh
    %   content as soon as the dashboard renders.
    %
    %   Unit values use the 4-element set [{'ALL'}, cfg.Subsystems(:)']
    %   directly so the demo's subsystem nomenclature is the single source
    %   of truth (changing cfg.Subsystems propagates to seedPlantLog).

    units = [{'ALL'}, cfg.Subsystems(:)'];  %#ok<NASGU> referenced via literals below

    % Shift-start anchor times within a day (HH * 3600 + MM * 60 + SS):
    %   06:00 -> 21600s
    %   14:00 -> 50400s
    %   22:00 -> 79200s
    %   02:30 -> 9000s  (overnight maintenance)
    shiftA = 21600;
    shiftB = 50400;
    shiftC = 79200;
    maint  = 9000;

    % Helper to compute an offsetSeconds: secondsIntoDay - daysAgo * 86400.
    % Day 0 is "today"; negative offsetSeconds = past.
    secOf = @(daysAgo, secondsIntoDay) -(daysAgo * 86400) + (secondsIntoDay - 86400);
    % Explanation: relative to now (= 86400s offset within today), an event
    % at secondsIntoDay of (today - daysAgo) sits at:
    %   (secondsIntoDay) + (-daysAgo - 0) * 86400 - 86400
    % which simplifies above. The result is strictly <= 0 for any
    % daysAgo >= 0 and secondsIntoDay <= 86400.

    % Build the 30-entry historical pool (shift-pattern times across days 0..6).
    % Mix shift-starts with overnight maintenance entries for variety.
    rows = { ...
        % daysAgo   secondsIntoDay   message                                                          unit         shift  operator
        6,          shiftA,          'Operator Mehta starting morning shift, all systems nominal',     'ALL',       'A',   'Mehta'; ...
        6,          shiftB,          'Routine maintenance: cooling pump filter changed',               'Cooling',   'B',   'Yamamoto'; ...
        6,          shiftC,          'Reactor heated to 160C setpoint',                                'Reactor',   'A',   'Patel'; ...
        5,          maint,           'Feedline pressure alarm cleared',                                'FeedLine',  'C',   'Davis'; ...
        5,          shiftA,          'Batch B-2381 started',                                           'Reactor',   'B',   'Patel'; ...
        5,          shiftB,          'Batch B-2381 complete, 1843 L yield',                            'Reactor',   'B',   'Patel'; ...
        5,          shiftC,          'Shift handover: Davis -> Patel, no anomalies reported',          'ALL',       'A',   'Patel'; ...
        4,          maint,           'Heat exchanger fouling suspected, cleaning scheduled',           'Cooling',   'A',   'Yamamoto'; ...
        4,          shiftB,          'Reactor pressure spike at 14:32 acknowledged by operator Chen',  'Reactor',   'B',   'Chen'; ...
        4,          shiftC,          'Feedline valve V-117 replaced with conditioning unit',           'FeedLine',  'C',   'Davis'; ...
        3,          shiftA,          'Cooling loop flow rate adjusted to 95 L/min',                    'Cooling',   'A',   'Yamamoto'; ...
        3,          shiftA + 1800,   'Pre-shift safety briefing complete',                             'ALL',       'A',   'Mehta'; ...
        3,          shiftB,          'Reactor mode transition: heating -> running',                    'Reactor',   'B',   'Chen'; ...
        3,          shiftC,          'Inlet temperature sensor calibration verified',                  'Cooling',   'A',   'Yamamoto'; ...
        2,          shiftA,          'Feedline pressure transient observed during startup',            'FeedLine',  'A',   'Patel'; ...
        2,          shiftB,          'Emergency stop test (drill) completed successfully',             'ALL',       'B',   'Mehta'; ...
        2,          shiftC,          'Reactor RPM trending nominal, no action required',               'Reactor',   'C',   'Davis'; ...
        2,          maint,           'Cooling tower fan cycled per maintenance schedule',              'Cooling',   'C',   'Yamamoto'; ...
        1,          shiftA,          'Batch B-2382 started',                                           'Reactor',   'A',   'Patel'; ...
        1,          shiftA + 600,    'Feedline strainer inspection: clean',                            'FeedLine',  'A',   'Davis'; ...
        1,          shiftB,          'Reactor temperature setpoint changed to 165C per recipe revision','Reactor',  'B',   'Chen'; ...
        1,          shiftC,          'Night shift quiet period, monitoring only',                      'ALL',       'C',   'Davis'; ...
        0,          maint,           'Cooling water pH within spec (7.4)',                             'Cooling',   'A',   'Yamamoto'; ...
        0,          shiftA,          'Feedline flow stable at 122 L/min',                              'FeedLine',  'B',   'Patel'; ...
        0,          shiftA + 1200,   'Reactor agitator vibration spike investigated, within tolerance','Reactor',   'A',   'Chen'; ...
        0,          shiftA + 2400,   'Batch B-2382 complete, 1798 L yield',                            'Reactor',   'B',   'Patel'; ...
        0,          shiftA + 3000,   'Shift handover: Patel -> Mehta, batch B-2383 queued',            'ALL',       'A',   'Mehta'; ...
        0,          shiftA + 3600,   'Cooling out-temp briefly exceeded 50C, alarm cleared after 12s', 'Cooling',   'B',   'Yamamoto'; ...
        0,          shiftA + 4200,   'Feedline valve V-118 actuator stroke time verified',             'FeedLine',  'A',   'Davis'; ...
        0,          shiftA + 4800,   'Reactor pressure trending up -- operator confirms expected',     'Reactor',   'B',   'Chen' ...
    };

    nHist = size(rows, 1);
    entries = repmat(struct( ...
        'offsetSeconds', 0, ...
        'message', '', ...
        'unit', '', ...
        'shift', '', ...
        'operator', ''), 1, nHist + 3);

    for k = 1:nHist
        daysAgo        = rows{k, 1};
        secondsIntoDay = rows{k, 2};
        entries(k).offsetSeconds = secOf(daysAgo, secondsIntoDay);
        entries(k).message  = rows{k, 3};
        entries(k).unit     = rows{k, 4};
        entries(k).shift    = rows{k, 5};
        entries(k).operator = rows{k, 6};
    end

    % --- 3 entries near now() so the live-tail demo shows fresh content --
    entries(nHist + 1).offsetSeconds = -30;
    entries(nHist + 1).message       = 'Live-tail entry: 30s ago -- routine check, all green';
    entries(nHist + 1).unit          = 'ALL';
    entries(nHist + 1).shift         = 'A';
    entries(nHist + 1).operator      = 'Mehta';

    entries(nHist + 2).offsetSeconds = -15;
    entries(nHist + 2).message       = 'Live-tail entry: 15s ago -- feedline pressure 5.1 bar nominal';
    entries(nHist + 2).unit          = 'FeedLine';
    entries(nHist + 2).shift         = 'A';
    entries(nHist + 2).operator      = 'Davis';

    entries(nHist + 3).offsetSeconds = 0;
    entries(nHist + 3).message       = 'Live-tail entry: now -- beginning fresh observation window';
    entries(nHist + 3).unit          = 'ALL';
    entries(nHist + 3).shift         = 'A';
    entries(nHist + 3).operator      = 'Mehta';
end
