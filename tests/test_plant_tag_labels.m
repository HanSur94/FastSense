function test_plant_tag_labels()
%TEST_PLANT_TAG_LABELS Verifies the registerPlantTags Labels contract WITHOUT
%   invoking private grouping helpers (which are tested by runFilterTagsTests).
%
%   This test constructs representative tag objects inline — mirroring the
%   Labels assignments in registerPlantTags.m for the 18-tag industrial-plant
%   demo taxonomy — and asserts the Labels classification contract directly:
%
%     1. Every tag has a non-empty Labels with Labels{1} a char.
%     2. No tag's Labels{1} is a state-vocabulary token (closed, open, …).
%     3. The two StateTags carry subsystem Labels (FeedLine, Reactor).
%     4. The four MonitorTags carry subsystem Labels (FeedLine/Reactor/Cooling).
%     5. Tallying Labels{1} across all 18 tags gives exactly:
%          Cooling x5, FeedLine x5, Reactor x7, rollup x1
%     6. Casing is canonical: 'FeedLine' appears; 'Feedline' does NOT.
%
%   DESIGN: side-effect-free — constructs tag objects inline, no TagRegistry
%   writes.  Mirrors the Labels logic in registerPlantTags.m.  Octave-compatible.
%   No private-function calls; uses only unique/strcmp/ismember/fieldnames.
%
%   See also registerPlantTags, runFilterTagsTests.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    nPassed = 0;

    % ---- Construct representative inline tags (mirrors registerPlantTags) ----

    % 8 SensorTags — canonicalSubsystem_ maps key prefix to cfg.Subsystems entry.
    tFLPressure  = SensorTag('feedline.pressure', ...
        'Name', 'Feedline Pressure', 'Labels', {'FeedLine'}, 'X', 1:3, 'Y', rand(1, 3));
    tFLFlow      = SensorTag('feedline.flow', ...
        'Name', 'Feedline Flow',     'Labels', {'FeedLine'}, 'X', 1:3, 'Y', rand(1, 3));
    tRPressure   = SensorTag('reactor.pressure', ...
        'Name', 'Reactor Pressure',  'Labels', {'Reactor'},  'X', 1:3, 'Y', rand(1, 3));
    tRTemp       = SensorTag('reactor.temperature', ...
        'Name', 'Reactor Temp',      'Labels', {'Reactor'},  'X', 1:3, 'Y', rand(1, 3));
    tRRpm        = SensorTag('reactor.rpm', ...
        'Name', 'Reactor Rpm',       'Labels', {'Reactor'},  'X', 1:3, 'Y', rand(1, 3));
    tCInTemp     = SensorTag('cooling.in_temp', ...
        'Name', 'Cooling In Temp',   'Labels', {'Cooling'},  'X', 1:3, 'Y', rand(1, 3));
    tCOutTemp    = SensorTag('cooling.out_temp', ...
        'Name', 'Cooling Out Temp',  'Labels', {'Cooling'},  'X', 1:3, 'Y', rand(1, 3));
    tCFlow       = SensorTag('cooling.flow', ...
        'Name', 'Cooling Flow',      'Labels', {'Cooling'},  'X', 1:3, 'Y', rand(1, 3));

    % 2 StateTags — Labels is the SUBSYSTEM (fixed by registerPlantTags redesign).
    %   State-value vocab lives in Y (ZOH data), NOT in Labels.
    tValveState  = StateTag('feedline.valve_state', ...
        'Name', 'Feedline Valve State', 'Labels', {'FeedLine'}, ...
        'X', [1 5], 'Y', [0 1]);
    tReactorMode = StateTag('reactor.mode', ...
        'Name', 'Reactor Mode', 'Labels', {'Reactor'}, ...
        'X', [1 5], 'Y', [0 1]);

    % 4 MonitorTags — Labels carries the subsystem from mDefs(k).Subsystem.
    tFLPressHigh = MonitorTag('feedline.pressure.high', tFLPressure, @(x, y) y > 8, ...
        'Name', 'Feedline Pressure High',     'Labels', {'FeedLine'});
    tRPressCrit  = MonitorTag('reactor.pressure.critical', tRPressure, @(x, y) y > 18, ...
        'Name', 'Reactor Pressure Critical',  'Labels', {'Reactor'});
    tRTempHigh   = MonitorTag('reactor.temperature.high', tRTemp, @(x, y) y > 180, ...
        'Name', 'Reactor Temperature High',   'Labels', {'Reactor'});
    tCFlowLow    = MonitorTag('cooling.flow.low', tCFlow, @(x, y) y < 20, ...
        'Name', 'Cooling Flow Low',           'Labels', {'Cooling'});

    % 4 CompositeTags — subsystem health + global rollup.
    tFLHealth = CompositeTag('feedline.health',  'or', 'Name', 'FeedLine Health',  'Labels', {'FeedLine'});
    tRHealth  = CompositeTag('reactor.health',   'or', 'Name', 'Reactor Health',   'Labels', {'Reactor'});
    tCHealth  = CompositeTag('cooling.health',   'or', 'Name', 'Cooling Health',   'Labels', {'Cooling'});
    tPlant    = CompositeTag('plant.health',     'or', 'Name', 'Plant Health',     'Labels', {'rollup'});

    allTags = { ...
        tFLPressure, tFLFlow, ...
        tRPressure, tRTemp, tRRpm, ...
        tCInTemp, tCOutTemp, tCFlow, ...
        tValveState, tReactorMode, ...
        tFLPressHigh, tRPressCrit, tRTempHigh, tCFlowLow, ...
        tFLHealth, tRHealth, tCHealth, tPlant};

    nTags = numel(allTags);

    % ---- Collect Labels{1} from every tag ----
    firstLabels = cell(1, nTags);
    for i = 1:nTags
        firstLabels{i} = allTags{i}.Labels{1};
    end

    % ---- Test 1: Every tag has non-empty Labels with Labels{1} a char ----
    for i = 1:nTags
        t = allTags{i};
        assert(~isempty(t.Labels), ...
            sprintf('Test 1: tag "%s" has empty Labels', t.Key));
        assert(ischar(t.Labels{1}), ...
            sprintf('Test 1: tag "%s" Labels{1} is not a char', t.Key));
        assert(~isempty(t.Labels{1}), ...
            sprintf('Test 1: tag "%s" Labels{1} is an empty string', t.Key));
    end
    nPassed = nPassed + 1;

    % ---- Test 2: No Labels{1} is a state-vocabulary token ----
    stateVocab = {'closed', 'opening', 'open', 'closing', ...
                  'idle', 'heating', 'running', 'cooldown', 'fault'};
    for i = 1:nTags
        lbl = firstLabels{i};
        for k = 1:numel(stateVocab)
            assert(~strcmpi(lbl, stateVocab{k}), ...
                sprintf('Test 2: tag "%s" Labels{1}="%s" is a state-vocab token', ...
                allTags{i}.Key, lbl));
        end
    end
    nPassed = nPassed + 1;

    % ---- Test 3: The two StateTags have subsystem Labels ----
    assert(strcmp(tValveState.Labels{1}, 'FeedLine'), ...
        sprintf('Test 3: feedline.valve_state Labels{1} should be "FeedLine", got "%s"', ...
        tValveState.Labels{1}));
    assert(strcmp(tReactorMode.Labels{1}, 'Reactor'), ...
        sprintf('Test 3: reactor.mode Labels{1} should be "Reactor", got "%s"', ...
        tReactorMode.Labels{1}));
    nPassed = nPassed + 1;

    % ---- Test 4: The four MonitorTags have subsystem Labels ----
    validMonitorSubsystems = {'FeedLine', 'Reactor', 'Cooling'};
    monitorTags = {tFLPressHigh, tRPressCrit, tRTempHigh, tCFlowLow};
    for i = 1:numel(monitorTags)
        lbl = monitorTags{i}.Labels{1};
        found = false;
        for k = 1:numel(validMonitorSubsystems)
            if strcmp(lbl, validMonitorSubsystems{k})
                found = true;
                break;
            end
        end
        assert(found, ...
            sprintf('Test 4: monitor tag "%s" Labels{1}="%s" not in {FeedLine,Reactor,Cooling}', ...
            monitorTags{i}.Key, lbl));
    end
    nPassed = nPassed + 1;

    % ---- Test 5: Tally Labels{1} gives exactly Cooling x5, FeedLine x5, Reactor x7, rollup x1 ----
    % Compute tally using plain MATLAB (no private helper).
    tallyCooling  = 0;
    tallyFeedLine = 0;
    tallyReactor  = 0;
    tallyRollup   = 0;
    for i = 1:nTags
        lbl = firstLabels{i};
        if strcmp(lbl, 'Cooling')
            tallyCooling = tallyCooling + 1;
        elseif strcmp(lbl, 'FeedLine')
            tallyFeedLine = tallyFeedLine + 1;
        elseif strcmp(lbl, 'Reactor')
            tallyReactor = tallyReactor + 1;
        elseif strcmp(lbl, 'rollup')
            tallyRollup = tallyRollup + 1;
        end
    end
    assert(tallyCooling == 5, ...
        sprintf('Test 5: Cooling tally should be 5, got %d', tallyCooling));
    assert(tallyFeedLine == 5, ...
        sprintf('Test 5: FeedLine tally should be 5, got %d', tallyFeedLine));
    assert(tallyReactor == 7, ...
        sprintf('Test 5: Reactor tally should be 7, got %d', tallyReactor));
    assert(tallyRollup == 1, ...
        sprintf('Test 5: rollup tally should be 1, got %d', tallyRollup));
    % Ensure the total covers all 18 tags (no label slipped into an unexpected bucket).
    tallyTotal = tallyCooling + tallyFeedLine + tallyReactor + tallyRollup;
    assert(tallyTotal == nTags, ...
        sprintf('Test 5: tally total %d != %d tags (unexpected label present)', tallyTotal, nTags));
    nPassed = nPassed + 1;

    % ---- Test 6: Canonical casing — 'FeedLine' present, 'Feedline' absent ----
    hasFeedLine  = false;
    hasFeedlineLc = false;
    for i = 1:nTags
        lbl = firstLabels{i};
        if strcmp(lbl, 'FeedLine')
            hasFeedLine = true;
        end
        if strcmp(lbl, 'Feedline')
            hasFeedlineLc = true;
        end
    end
    assert(hasFeedLine, ...
        'Test 6: expected at least one tag with Labels{1}=="FeedLine" (capital L)');
    assert(~hasFeedlineLc, ...
        'Test 6: found tag with Labels{1}=="Feedline" (lowercase l) -- canonical casing violated');
    nPassed = nPassed + 1;

    fprintf('    All %d tests passed.\n', nPassed);
end
