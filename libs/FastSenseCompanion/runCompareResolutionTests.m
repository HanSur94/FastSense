function runCompareResolutionTests()
%RUNCOMPARERESOLUTIONTESTS Execute unit tests for the cross-machine resolution foundation.
%   Called by tests/test_compare_resolution.m. Lives here (inside
%   libs/FastSenseCompanion) so MATLAB's private-directory mechanism makes the
%   private helpers buildCompareResolution_ and compareSeriesColor_ visible
%   (private functions are accessible to callers in the same folder). Mirrors
%   runFilterMachinesTests.
%
%   Covers (CMP-02, CMP-03, CMP-04, CMP-05 seam):
%     T1      — CanonicalMapper.resolve returns the entry struct for a known pair
%     T2      — resolve returns [] for unknown machineId / unknown logicalId
%     Tmapper — Fleet.mapper() is eq-identical to Mapper_ and resolves identically
%     T3      — buildCompareResolution_ states {'auto','confirm_needed','none'} (2-arg, color=[])
%     T4      — unit-mismatch detection (both units non-empty + differ -> true; either empty -> false)
%     Ttheme  — 3-arg form populates every row.color via compareSeriesColor_ (incl. 'none' row)
%     Tcolor  — compareSeriesColor_ is stable per machine by fleet insertion index (modulo palette)
%
%   Octave-safe: no matlab.unittest, no contains. Pure logic + handles only.
%
%   See also CanonicalMapper, Fleet, buildCompareResolution_, compareSeriesColor_.

    nPassed = 0;
    nFailed = 0;

    % ---- T1: resolve returns entry struct for a known pair ----
    try
        mapper = buildSharedSensorMapper_();
        e = mapper.resolve('temp_motor', 'M01');
        assert(isstruct(e), 'T1: resolve must return a struct for a known pair');
        assert(strcmp(e.machineId, 'M01'), 'T1: machineId must be M01');
        assert(isfield(e, 'localKey') && isfield(e, 'confidence') ...
            && isfield(e, 'status') && isfield(e, 'unitMismatch'), ...
            'T1: entry must carry localKey/confidence/status/unitMismatch');
        nPassed = nPassed + 1;
    catch ME
        fprintf('FAIL T1: %s\n', ME.message);
        nFailed = nFailed + 1;
    end

    % ---- T2: resolve returns [] for unknown pair / unknown logicalId ----
    try
        mapper = buildSharedSensorMapper_();
        assert(isempty(mapper.resolve('temp_motor', 'MZZ')), ...
            'T2: unknown machineId must resolve to []');
        assert(isempty(mapper.resolve('no_such_logical', 'M01')), ...
            'T2: unknown logicalId must resolve to []');
        nPassed = nPassed + 1;
    catch ME
        fprintf('FAIL T2: %s\n', ME.message);
        nFailed = nFailed + 1;
    end

    % ---- Tmapper: Fleet.mapper() identity + identical resolve behavior ----
    try
        fleet = Fleet();
        m1 = fleet.addMachine('Id', 'M01', 'Name', 'Press Line 3');
        m1.addTag(SensorTag('temp_motor', 'Name', 'Motor Temp', 'Units', 'degC', 'X', 0:9, 'Y', 0:9));
        m2 = fleet.addMachine('Id', 'M02', 'Name', 'Pump Station 1');
        m2.addTag(SensorTag('temp_mtor', 'Name', 'Temp Mtor', 'Units', 'degC', 'X', 0:9, 'Y', 0:9));
        fleet.mapper().suggest(sharedTagInfos_());
        assert(fleet.mapper() == fleet.Mapper_, ...
            'Tmapper: Fleet.mapper() must be the same handle as Mapper_');
        e1 = fleet.mapper().resolve('temp_motor', 'M01');
        e2 = fleet.Mapper_.resolve('temp_motor', 'M01');
        assert(isequal(e1, e2), 'Tmapper: mapper() resolve must match Mapper_ resolve');
        nPassed = nPassed + 1;
    catch ME
        fprintf('FAIL Tmapper: %s\n', ME.message);
        nFailed = nFailed + 1;
    end

    % ---- T3: buildCompareResolution_ states in machineIds order (2-arg, color=[]) ----
    try
        fleet = buildThreeStateFleet_();
        rows = buildCompareResolution_(fleet, 'temp_motor');
        assert(numel(rows) == 3, 'T3: must produce one row per machine');
        states = {rows.state};
        assert(isequal(states, {'auto', 'confirm_needed', 'none'}), ...
            sprintf('T3: states must be auto/confirm_needed/none, got %s', strjoin(states, ',')));
        assert(strcmp(rows(2).state, 'confirm_needed'), 'T3: LOW+AUTO row must be confirm_needed');
        assert(isempty(rows(1).color) && isempty(rows(2).color) && isempty(rows(3).color), ...
            'T3: 2-arg form must leave every row.color = []');
        nPassed = nPassed + 1;
    catch ME
        fprintf('FAIL T3: %s\n', ME.message);
        nFailed = nFailed + 1;
    end

    % ---- T4: unit-mismatch detection ----
    try
        fleet = buildUnitMismatchFleet_('degF');
        rows = buildCompareResolution_(fleet, 'temp_motor');
        m2row = rowFor_(rows, 'M02');
        assert(m2row.unitMismatch == true, 'T4: differing non-empty units must flag unitMismatch');
        fleet2 = buildUnitMismatchFleet_('');
        rows2 = buildCompareResolution_(fleet2, 'temp_motor');
        m2row2 = rowFor_(rows2, 'M02');
        assert(m2row2.unitMismatch == false, 'T4: empty tag unit must not flag unitMismatch');
        nPassed = nPassed + 1;
    catch ME
        fprintf('FAIL T4: %s\n', ME.message);
        nFailed = nFailed + 1;
    end

    % ---- Ttheme: 3-arg form populates every row.color via compareSeriesColor_ ----
    try
        fleet = buildThreeStateFleet_();
        theme = CompanionTheme.get('dark');
        rows = buildCompareResolution_(fleet, 'temp_motor', theme);
        ids = fleet.machineIds();
        for i = 1:numel(rows)
            expected = compareSeriesColor_(theme, fleet, ids{i});
            assert(isequal(size(rows(i).color), [1 3]), ...
                sprintf('Ttheme: row %d color must be 1x3', i));
            assert(isequal(rows(i).color, expected), ...
                sprintf('Ttheme: row %d color must equal compareSeriesColor_', i));
        end
        m3row = rowFor_(rows, 'M03');
        assert(strcmp(m3row.state, 'none') && isequal(size(m3row.color), [1 3]), ...
            'Ttheme: the none-state row must still carry a 1x3 color');
        nPassed = nPassed + 1;
    catch ME
        fprintf('FAIL Ttheme: %s\n', ME.message);
        nFailed = nFailed + 1;
    end

    % ---- Tcolor: stable per-machine color by insertion index (modulo palette) ----
    try
        fleet = buildThreeStateFleet_();
        theme = CompanionTheme.get('dark');
        lc = theme.LineColors;
        expected3 = lc{mod(3 - 1, numel(lc)) + 1};
        assert(isequal(compareSeriesColor_(theme, fleet, 'M03'), expected3), ...
            'Tcolor: M03 color must be LineColors{mod(3-1,n)+1}');
        c1full = compareSeriesColor_(theme, fleet, 'M01');
        assert(isequal(c1full, lc{1}), 'Tcolor: M01 (index 1) must map to LineColors{1}');
        nPassed = nPassed + 1;
    catch ME
        fprintf('FAIL Tcolor: %s\n', ME.message);
        nFailed = nFailed + 1;
    end

    fprintf('    %d of %d tests passed.\n', nPassed, nPassed + nFailed);
    if nFailed > 0
        error('runCompareResolutionTests:failures', '%d test(s) failed.', nFailed);
    end
end

% =================== fixtures (pure, Octave-safe) ===================

function infos = sharedTagInfos_()
%SHAREDTAGINFOS_ Two machines sharing a near-identical sensor name (HIGH match).
    infos = { ...
        struct('machineId', 'M01', 'localKey', 'temp_motor', 'name', 'Motor Temp', 'units', 'degC'), ...
        struct('machineId', 'M02', 'localKey', 'temp_mtor',  'name', 'Temp Mtor',  'units', 'degC') };
end

function mapper = buildSharedSensorMapper_()
%BUILDSHAREDSENSORMAPPER_ A mapper with a 'temp_motor' logical sensor over M01/M02.
    mapper = CanonicalMapper();
    mapper.suggest(sharedTagInfos_());
    if ~isKey(mapper.Entries_, 'temp_motor')
        mapper.override('temp_motor', 'M01', 'temp_motor');
        mapper.override('temp_motor', 'M02', 'temp_mtor');
    end
end

function fleet = buildThreeStateFleet_()
%BUILDTHREESTATEFLEET_ M01=HIGH auto, M02=LOW auto, M03=no mapping (none).
    fleet = Fleet();
    m1 = fleet.addMachine('Id', 'M01', 'Name', 'Press Line 3');
    m1.addTag(SensorTag('temp_motor', 'Name', 'Motor Temp', 'Units', 'degC', 'X', 0:9, 'Y', 0:9));
    m2 = fleet.addMachine('Id', 'M02', 'Name', 'Pump Station 1');
    m2.addTag(SensorTag('tm', 'Name', 'TM', 'Units', 'degC', 'X', 0:9, 'Y', 0:9));
    fleet.addMachine('Id', 'M03', 'Name', 'Conveyor 7');
    mp = fleet.mapper();
    mp.Entries_('temp_motor') = { ...
        makeEntry_('temp_motor', 'M01', 'temp_motor', 'Motor Temp', 'degC', 1.0,  'HIGH', 'AUTO', false), ...
        makeEntry_('temp_motor', 'M02', 'tm',         'TM',         'degC', 0.20, 'LOW',  'AUTO', false) };
end

function fleet = buildUnitMismatchFleet_(m2Units)
%BUILDUNITMISMATCHFLEET_ M01 canonical degC; M02 tag carries the given units (possibly empty).
    fleet = Fleet();
    m1 = fleet.addMachine('Id', 'M01', 'Name', 'Press Line 3');
    m1.addTag(SensorTag('temp_motor', 'Name', 'Motor Temp', 'Units', 'degC', 'X', 0:9, 'Y', 0:9));
    m2 = fleet.addMachine('Id', 'M02', 'Name', 'Pump Station 1');
    m2.addTag(SensorTag('tm', 'Name', 'TM', 'Units', m2Units, 'X', 0:9, 'Y', 0:9));
    mp = fleet.mapper();
    mp.Entries_('temp_motor') = { ...
        makeEntry_('temp_motor', 'M01', 'temp_motor', 'Motor Temp', 'degC', 1.0,  'HIGH', 'AUTO', false), ...
        makeEntry_('temp_motor', 'M02', 'tm',         'TM',         'degC', 0.95, 'HIGH', 'AUTO', false) };
end

function e = makeEntry_(logicalId, machineId, localKey, localName, localUnits, sim, conf, status, mismatch)
%MAKEENTRY_ Build a fully-populated entry struct (test fixture; mirrors CanonicalMapper schema).
    e = struct( ...
        'logicalId',    logicalId, ...
        'machineId',    machineId, ...
        'localKey',     localKey, ...
        'localName',    localName, ...
        'localUnits',   localUnits, ...
        'similarity',   sim, ...
        'confidence',   conf, ...
        'status',       status, ...
        'unitMismatch', mismatch);
end

function row = rowFor_(rows, machineId)
%ROWFOR_ Return the row struct whose machineId matches.
    for i = 1:numel(rows)
        if strcmp(rows(i).machineId, machineId)
            row = rows(i);
            return;
        end
    end
    error('rowFor_:notFound', 'No row for machine %s', machineId);
end
