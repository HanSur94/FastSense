classdef TestCanonicalMapper < matlab.unittest.TestCase
    %TESTCANONICALMAPPER Unit tests for the Phase 1041 CanonicalMapper (Fleet layer).
    %   Nyquist test suite — 30 methods written RED in Wave 0 (Plan 1041-01),
    %   turned GREEN by Plans 1041-02 (suggest/confidence/units),
    %   1041-03 (override/persist/query) and 1041-04 (editor smoke).
    %
    %   Coverage:
    %     CANON-01 (5): normalization, edit-distance symmetry/known-pairs, suggest clustering
    %     CANON-02 (9): confidence thresholds + boundaries, unit-mismatch downgrade
    %     CANON-03 (5): override precedence, toStruct/fromStruct + save/load round-trips
    %     CANON-04 (7): reviewPending / unmapped / isResolvable query API
    %     CANON-05 (1): CanonicalMapEditor construction smoke (MATLAB-only)
    %     SUCCESS-5 (2): Octave-safety + no-toolbox grep gates on CanonicalMapper.m
    %
    %   ===================================================================
    %   LOCKED ALGORITHM CONTRACT (tests assert against this; Plan 02/03 implement it)
    %   ===================================================================
    %   normalize_(key): lower-case, non-alphanumeric -> '_', collapse repeated '_',
    %       trim leading/trailing '_'.
    %   editDistance_(a,b): hand-rolled Wagner-Fischer Levenshtein (NO Statistics
    %       Toolbox editDistance; trailing-underscore name keeps the grep gate green).
    %   similarity: sim = 1 - editDistance_(normA,normB) / max(numel(normA),numel(normB)).
    %   Clustering (seed-then-assign):
    %     - Seeds: cross-machine pairs with sim >= MEDIUM_THRESHOLD_ (0.60) group into
    %       seed clusters (a cluster spans >= 2 machines).
    %     - Centroid: the longest normalized key in the cluster; tie -> lexicographically
    %       smallest normalized key. logicalId = the centroid key. The centroid MEMBER
    %       (for unit purposes) is the first input-order member carrying the centroid key.
    %     - Attach: each leftover tag attaches to the nearest seed centroid IF
    %       simToCentroid >= ATTACH_THRESHOLD_ (0.15); otherwise it stays unmapped.
    %       (A leftover never forms a cluster on its own; with zero seeds nothing attaches.)
    %     - Per-member confidence is scored against the centroid:
    %       sim >= 0.90 -> HIGH ; sim >= 0.60 -> MEDIUM ; else LOW  (boundaries inclusive).
    %       The centroid member scores 1.0 against itself -> HIGH.
    %   Units: canonical unit = centroid member's unit. A member whose (non-empty) unit
    %       differs case-insensitively from the canonical unit gets unitMismatch=true AND
    %       its confidence downgraded one level (HIGH->MEDIUM->LOW). Empty units never
    %       count as a mismatch.
    %   reviewPending(): entries with status AUTO|PENDING AND (confidence==LOW OR
    %       unitMismatch). CONFIRMED/OVERRIDDEN entries are never pending.
    %   isResolvable(logicalId,machineId): CONFIRMED/OVERRIDDEN -> true; otherwise
    %       (confidence HIGH|MEDIUM) AND ~unitMismatch AND status~=PENDING.
    %   override(logicalId,machineId,localKey): creates/sets an OVERRIDDEN entry that
    %       suggest() must never replace (precedence over AUTO).
    %
    %   See also CanonicalMapper, CanonicalMapEditor.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'libs', 'Fleet'));   % redundant-safe; install.m also registers it
            addpath(fullfile(repo, 'tests', 'suite'));
        end
    end

    % ---- Test helpers (not Test methods) ----
    methods (Access = private)
        function s = ti_(~, machineId, localKey, units)
            %TI_ Build one tag-info struct (name defaults to localKey).
            s = struct('machineId', machineId, 'localKey', localKey, ...
                       'name', localKey, 'units', units);
        end

        function tagInfos = sampleTagInfos_(testCase)
            %SAMPLETAGINFOS_ Canonical 3-machine fixture.
            %   M01 temp_motor / M02 temp_mtor cluster at sim 0.90 (HIGH, units match).
            %   M03 pressure is dissimilar (sim 0.10 to centroid) -> unmapped.
            tagInfos = { ...
                testCase.ti_('M01', 'temp_motor', 'degC'), ...
                testCase.ti_('M02', 'temp_mtor',  'degC'), ...
                testCase.ti_('M03', 'pressure',   'bar') ...
            };
        end

        function lowInfos = lowFixture_(testCase)
            %LOWFIXTURE_ LOCKED 3-member fixture shared with Plan 1041-02 Task 2.
            %   M01/M02 identical 'abcdefghij' -> HIGH centroid; M03 'abzzzzzzzz'
            %   attaches at sim 0.20 -> LOW.
            lowInfos = { ...
                testCase.ti_('M01', 'abcdefghij', 'u'), ...
                testCase.ti_('M02', 'abcdefghij', 'u'), ...
                testCase.ti_('M03', 'abzzzzzzzz', 'u') ...
            };
        end

        function e = findEntry_(~, m, logicalId, machineId)
            %FINDENTRY_ Return the entry struct for (logicalId,machineId), or struct([]).
            e = struct([]);
            if ~isKey(m.Entries_, logicalId)
                return;
            end
            c = m.Entries_(logicalId);
            for i = 1:numel(c)
                if strcmp(c{i}.machineId, machineId)
                    e = c{i};
                    return;
                end
            end
        end

        function n = countEntries_(~, m)
            %COUNTENTRIES_ Total entries across all logicalIds.
            n = 0;
            k = keys(m.Entries_);
            for i = 1:numel(k)
                n = n + numel(m.Entries_(k{i}));
            end
        end

        function tf = entryInList_(~, list, logicalId, machineId)
            %ENTRYINLIST_ True if a cell of entry structs contains (logicalId,machineId).
            tf = false;
            for i = 1:numel(list)
                en = list{i};
                if strcmp(en.logicalId, logicalId) && strcmp(en.machineId, machineId)
                    tf = true;
                    return;
                end
            end
        end

        function p = mapperSrcPath_(~)
            %MAPPERSRCPATH_ Absolute path to libs/Fleet/CanonicalMapper.m.
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            p = fullfile(repo, 'libs', 'Fleet', 'CanonicalMapper.m');
        end
    end

    methods (Test)

        % ================= CANON-01: normalization + edit distance + suggest =================

        function testNormalizeLowercase(testCase)
            % Keys differing only by case/punctuation must normalize identically
            % and therefore cluster into ONE logicalId.
            infos = { ...
                testCase.ti_('M01', 'Temp-Motor', 'degC'), ...
                testCase.ti_('M02', 'temp_motor', 'degC') ...
            };
            m = CanonicalMapper();
            m.suggest(infos);
            testCase.verifyEqual(numel(keys(m.Entries_)), 1, ...
                'Case/punctuation-only differences must normalize to one logicalId.');
        end

        function testNormalizeCollapsesRepeats(testCase)
            % normalize_ collapses repeated separators and trims leading/trailing
            % ones: '_temp_motor_' and 'temp__motor' both -> 'temp_motor' -> one cluster.
            infos = { ...
                testCase.ti_('M01', '_temp_motor_', 'degC'), ...
                testCase.ti_('M02', 'temp__motor',  'degC') ...
            };
            m = CanonicalMapper();
            m.suggest(infos);
            testCase.verifyEqual(numel(keys(m.Entries_)), 1, ...
                'Collapsed/trimmed separators must normalize to one logicalId.');
            testCase.verifyTrue(isKey(m.Entries_, 'temp_motor'), ...
                'Normalized centroid key must be temp_motor.');
        end

        function testEditDistanceSymmetry(testCase)
            % Distance is commutative: swapping input order yields the same
            % matched-entry similarity (centroid is order-independent).
            a = { testCase.ti_('M01', 'abcde', 'u'), testCase.ti_('M02', 'abxde', 'u') };
            b = { testCase.ti_('M02', 'abxde', 'u'), testCase.ti_('M01', 'abcde', 'u') };
            m1 = CanonicalMapper(); m1.suggest(a);
            m2 = CanonicalMapper(); m2.suggest(b);
            e1 = testCase.findEntry_(m1, 'abcde', 'M02');   % centroid 'abcde'; M02 is the matched member
            e2 = testCase.findEntry_(m2, 'abcde', 'M02');
            testCase.verifyNotEmpty(e1);
            testCase.verifyNotEmpty(e2);
            testCase.verifyEqual(e1.similarity, e2.similarity, 'AbsTol', 1e-12, ...
                'Similarity must be order-independent (distance is symmetric).');
        end

        function testEditDistanceKnownPairs(testCase)
            % Wagner-Fischer contract: editDist('abc','axc')=1 -> sim = 1 - 1/3.
            infos = { testCase.ti_('M01', 'abc', 'u'), testCase.ti_('M02', 'axc', 'u') };
            m = CanonicalMapper();
            m.suggest(infos);
            e = testCase.findEntry_(m, 'abc', 'M02');   % centroid 'abc' (tie -> lex smallest)
            testCase.verifyNotEmpty(e);
            testCase.verifyEqual(e.similarity, 1 - 1/3, 'AbsTol', 1e-9);
        end

        function testSuggestTwoMatchingPairs(testCase)
            % Two cross-machine matching pairs -> exactly two logicalIds.
            infos = { ...
                testCase.ti_('M01', 'temp_motor',  'degC'), ...
                testCase.ti_('M02', 'temp_mtor',   'degC'), ...   % matches temp_motor
                testCase.ti_('M01', 'pressure_in', 'bar'), ...
                testCase.ti_('M02', 'pressure_inlet', 'bar') ...  % matches pressure_in
            };
            m = CanonicalMapper();
            m.suggest(infos);
            testCase.verifyEqual(numel(keys(m.Entries_)), 2, ...
                'Two matching pairs must produce two distinct logicalIds.');
        end

        function testSuggestNoMatches(testCase)
            % Mutually dissimilar cross-machine keys -> no cluster forms (CANON-01).
            % (The unmapped() tail is asserted separately by the CANON-04 tests.)
            infos = { ...
                testCase.ti_('M01', 'temp',     'degC'), ...
                testCase.ti_('M02', 'pressure', 'bar'), ...
                testCase.ti_('M03', 'flowrate', 'lpm') ...
            };
            m = CanonicalMapper();
            m.suggest(infos);
            testCase.verifyEqual(numel(keys(m.Entries_)), 0, ...
                'Dissimilar keys must not form any cluster.');
        end

        % ================= CANON-02: confidence thresholds =================

        function testConfidenceHighThreshold(testCase)
            % Identical keys across machines -> sim 1.0 -> HIGH.
            infos = { ...
                testCase.ti_('M01', 'temp_motor', 'degC'), ...
                testCase.ti_('M02', 'temp_motor', 'degC') ...
            };
            m = CanonicalMapper();
            m.suggest(infos);
            e = testCase.findEntry_(m, 'temp_motor', 'M02');
            testCase.verifyNotEmpty(e);
            testCase.verifyEqual(e.confidence, 'HIGH');
        end

        function testConfidenceMediumThreshold(testCase)
            % sim in [0.60,0.90): 'temp1' vs 'temp2' -> editDist 1, len 5, sim 0.80 -> MEDIUM.
            infos = { ...
                testCase.ti_('M01', 'temp1', 'u'), ...
                testCase.ti_('M02', 'temp2', 'u') ...
            };
            m = CanonicalMapper();
            m.suggest(infos);
            e = testCase.findEntry_(m, 'temp1', 'M02');   % centroid 'temp1' (tie -> lex smaller)
            testCase.verifyNotEmpty(e);
            testCase.verifyEqual(e.confidence, 'MEDIUM');
        end

        function testConfidenceLowThreshold(testCase)
            % LOCKED fixture: M03 attaches to the abcdefghij centroid at sim 0.20 -> LOW.
            m = CanonicalMapper();
            m.suggest(testCase.lowFixture_());
            e = testCase.findEntry_(m, 'abcdefghij', 'M03');
            testCase.verifyNotEmpty(e, 'M03 must attach to the abcdefghij cluster as a LOW member.');
            testCase.verifyEqual(e.confidence, 'LOW');
            testCase.verifyEqual(e.similarity, 0.20, 'AbsTol', 1e-9);
        end

        function testConfidenceBoundaryHigh(testCase)
            % sim EXACTLY 0.90 (len 10, editDist 1) -> HIGH (inclusive).
            infos = { ...
                testCase.ti_('M01', 'temp_motor', 'degC'), ...
                testCase.ti_('M02', 'temp_motoz', 'degC') ...   % last char r->z, editDist 1
            };
            m = CanonicalMapper();
            m.suggest(infos);
            e = testCase.findEntry_(m, 'temp_motor', 'M02');   % 'temp_motor' < 'temp_motoz'
            testCase.verifyNotEmpty(e);
            testCase.verifyEqual(e.similarity, 0.90, 'AbsTol', 1e-9);
            testCase.verifyEqual(e.confidence, 'HIGH');
        end

        function testConfidenceBoundaryMedium(testCase)
            % sim EXACTLY 0.60 (len 5, editDist 2) -> MEDIUM (inclusive).
            infos = { ...
                testCase.ti_('M01', 'abcde', 'u'), ...
                testCase.ti_('M02', 'abxye', 'u') ...   % c->x, d->y : editDist 2
            };
            m = CanonicalMapper();
            m.suggest(infos);
            e = testCase.findEntry_(m, 'abcde', 'M02');
            testCase.verifyNotEmpty(e);
            testCase.verifyEqual(e.similarity, 0.60, 'AbsTol', 1e-9);
            testCase.verifyEqual(e.confidence, 'MEDIUM');
        end

        % ================= CANON-02: unit-mismatch flagging =================

        function testUnitMismatchDowngradesHigh(testCase)
            % HIGH pair, mismatched units (degC vs K) -> unitMismatch + HIGH->MEDIUM.
            infos = { ...
                testCase.ti_('M01', 'temp_motor', 'degC'), ...
                testCase.ti_('M02', 'temp_motor', 'K') ...
            };
            m = CanonicalMapper();
            m.suggest(infos);
            e = testCase.findEntry_(m, 'temp_motor', 'M02');
            testCase.verifyNotEmpty(e);
            testCase.verifyTrue(e.unitMismatch);
            testCase.verifyEqual(e.confidence, 'MEDIUM');
        end

        function testUnitMismatchDowngradesMedium(testCase)
            % MEDIUM pair, mismatched units -> unitMismatch + MEDIUM->LOW.
            infos = { ...
                testCase.ti_('M01', 'temp1', 'degC'), ...
                testCase.ti_('M02', 'temp2', 'K') ...   % sim 0.80 -> MEDIUM, units differ
            };
            m = CanonicalMapper();
            m.suggest(infos);
            e = testCase.findEntry_(m, 'temp1', 'M02');
            testCase.verifyNotEmpty(e);
            testCase.verifyTrue(e.unitMismatch);
            testCase.verifyEqual(e.confidence, 'LOW');
        end

        function testUnitMismatchEmptyUnitsIgnored(testCase)
            % One empty unit -> no mismatch, no downgrade.
            infos = { ...
                testCase.ti_('M01', 'temp_motor', 'degC'), ...
                testCase.ti_('M02', 'temp_motor', '') ...
            };
            m = CanonicalMapper();
            m.suggest(infos);
            e = testCase.findEntry_(m, 'temp_motor', 'M02');
            testCase.verifyNotEmpty(e);
            testCase.verifyFalse(e.unitMismatch);
            testCase.verifyEqual(e.confidence, 'HIGH');
        end

        function testUnitMatchCaseInsensitive(testCase)
            % degC vs DegC -> not a mismatch.
            infos = { ...
                testCase.ti_('M01', 'temp_motor', 'degC'), ...
                testCase.ti_('M02', 'temp_motor', 'DegC') ...
            };
            m = CanonicalMapper();
            m.suggest(infos);
            e = testCase.findEntry_(m, 'temp_motor', 'M02');
            testCase.verifyNotEmpty(e);
            testCase.verifyFalse(e.unitMismatch);
        end

        % ================= CANON-03: override + persistence =================

        function testOverrideCreatesEntry(testCase)
            % override() sets an OVERRIDDEN entry with the supplied localKey.
            m = CanonicalMapper();
            m.suggest(testCase.sampleTagInfos_());
            m.override('temp_motor', 'M03', 'pressure');
            e = testCase.findEntry_(m, 'temp_motor', 'M03');
            testCase.verifyNotEmpty(e);
            testCase.verifyEqual(e.status, 'OVERRIDDEN');
            testCase.verifyEqual(e.localKey, 'pressure');
        end

        function testOverrideSurvivesResuggest(testCase)
            % suggest() must not overwrite a non-AUTO (OVERRIDDEN) entry.
            m = CanonicalMapper();
            m.suggest(testCase.sampleTagInfos_());
            m.override('temp_motor', 'M03', 'pressure');
            m.suggest(testCase.sampleTagInfos_());   % re-run
            e = testCase.findEntry_(m, 'temp_motor', 'M03');
            testCase.verifyNotEmpty(e);
            testCase.verifyEqual(e.status, 'OVERRIDDEN');
            testCase.verifyEqual(e.localKey, 'pressure');
        end

        function testRoundTripPreservesEntries(testCase)
            % toStruct -> fromStruct preserves entry count and a spot entry.
            m = CanonicalMapper();
            m.suggest(testCase.sampleTagInfos_());
            s = m.toStruct();
            m2 = CanonicalMapper.fromStruct(s);
            testCase.verifyEqual(testCase.countEntries_(m2), testCase.countEntries_(m));
            e = testCase.findEntry_(m2, 'temp_motor', 'M02');
            testCase.verifyNotEmpty(e);
            testCase.verifyEqual(e.confidence, 'HIGH');
        end

        function testRoundTripPreservesOverriddenStatus(testCase)
            % JSON-string round-trip preserves OVERRIDDEN status (no disk I/O).
            m = CanonicalMapper();
            m.suggest(testCase.sampleTagInfos_());
            m.override('temp_motor', 'M03', 'pressure');
            s  = m.toStruct();
            s2 = jsondecode(jsonencode(s));
            m2 = CanonicalMapper.fromStruct(s2);
            e = testCase.findEntry_(m2, 'temp_motor', 'M03');
            testCase.verifyNotEmpty(e);
            testCase.verifyEqual(e.status, 'OVERRIDDEN');
        end

        function testSaveLoadRoundTrip(testCase)
            % save() then load() reproduces entry count and a spot entry.
            m = CanonicalMapper();
            m.suggest(testCase.sampleTagInfos_());
            p = [tempname '.json'];
            cleanup = onCleanup(@() testCase.cleanupFile_(p)); %#ok<NASGU>
            m.save(p);
            m2 = CanonicalMapper.load(p);
            testCase.verifyEqual(testCase.countEntries_(m2), testCase.countEntries_(m));
            e = testCase.findEntry_(m2, 'temp_motor', 'M01');
            testCase.verifyNotEmpty(e);
        end

        % ================= CANON-04: query API =================

        function testReviewPendingReturnsLow(testCase)
            % A LOW AUTO entry appears in reviewPending().
            m = CanonicalMapper();
            m.suggest(testCase.lowFixture_());
            pend = m.reviewPending();
            testCase.verifyTrue(testCase.entryInList_(pend, 'abcdefghij', 'M03'));
        end

        function testReviewPendingReturnsUnitMismatch(testCase)
            % A unit-mismatch entry (any confidence) appears in reviewPending().
            infos = { ...
                testCase.ti_('M01', 'temp_motor', 'degC'), ...
                testCase.ti_('M02', 'temp_motor', 'K') ...   % mismatch -> pending
            };
            m = CanonicalMapper();
            m.suggest(infos);
            pend = m.reviewPending();
            testCase.verifyTrue(testCase.entryInList_(pend, 'temp_motor', 'M02'));
        end

        function testReviewPendingExcludesGoodEntries(testCase)
            % HIGH no-mismatch AUTO entries are excluded; so are CONFIRMED/OVERRIDDEN.
            m = CanonicalMapper();
            m.suggest(testCase.lowFixture_());
            pend = m.reviewPending();
            testCase.verifyFalse(testCase.entryInList_(pend, 'abcdefghij', 'M01'), ...
                'HIGH centroid member must not be pending.');
            m.confirm('abcdefghij', 'M03');                 % CONFIRMED -> excluded
            testCase.verifyFalse(testCase.entryInList_(m.reviewPending(), 'abcdefghij', 'M03'));
            m.override('abcdefghij', 'M03', 'abzzzzzzzz');   % OVERRIDDEN -> excluded
            testCase.verifyFalse(testCase.entryInList_(m.reviewPending(), 'abcdefghij', 'M03'));

            % CR-01 regression: a CONFIRMED unit-mismatch entry must ALSO be excluded.
            % reviewPending must agree with isResolvable — the unitMismatch flag alone
            % must not keep a user-vouched entry pending forever.
            m2 = CanonicalMapper();
            m2.suggest({ testCase.ti_('M01', 'temp_motor', 'degC'), ...
                         testCase.ti_('M02', 'temp_motor', 'K') });
            testCase.verifyTrue(testCase.entryInList_(m2.reviewPending(), 'temp_motor', 'M02'), ...
                'A unit-mismatch AUTO entry should be pending before review.');
            m2.confirm('temp_motor', 'M02');
            testCase.verifyFalse(testCase.entryInList_(m2.reviewPending(), 'temp_motor', 'M02'), ...
                'A CONFIRMED unit-mismatch entry must NOT remain pending (CR-01).');
        end

        function testUnmappedReturnsUnresolved(testCase)
            % The dissimilar M03 key (sim 0.10 < ATTACH_THRESHOLD_) stays unmapped.
            m = CanonicalMapper();
            m.suggest(testCase.sampleTagInfos_());
            testCase.verifyTrue(ismember('pressure', m.unmapped('M03')));
        end

        function testUnmappedEmptyWhenAllMapped(testCase)
            % Every M01 key is clustered -> unmapped('M01') is empty.
            infos = { ...
                testCase.ti_('M01', 'temp_motor', 'degC'), ...
                testCase.ti_('M02', 'temp_mtor',  'degC') ...
            };
            m = CanonicalMapper();
            m.suggest(infos);
            testCase.verifyEmpty(m.unmapped('M01'));
        end

        function testIsResolvableFalseForLow(testCase)
            % A LOW+AUTO entry is not resolvable.
            m = CanonicalMapper();
            m.suggest(testCase.lowFixture_());
            testCase.verifyFalse(m.isResolvable('abcdefghij', 'M03'));
        end

        function testIsResolvableTrueForHigh(testCase)
            % A HIGH+AUTO entry is resolvable.
            m = CanonicalMapper();
            m.suggest(testCase.sampleTagInfos_());
            testCase.verifyTrue(m.isResolvable('temp_motor', 'M02'));
        end

        % ================= CANON-05: editor smoke (MATLAB-only) =================

        function testEditorConstructs(testCase)
            % uifigure is MATLAB-only -> skip cleanly on Octave.
            testCase.assumeTrue(exist('OCTAVE_VERSION', 'builtin') == 0, ...
                'CanonicalMapEditor uses uifigure (MATLAB-only).');
            m = CanonicalMapper();
            m.suggest(testCase.sampleTagInfos_());
            ed = CanonicalMapEditor(m);
            cleanup = onCleanup(@() testCase.cleanupEditor_(ed)); %#ok<NASGU>
            testCase.verifyTrue(isvalid(ed) && ed.IsOpen, ...
                'Editor must construct and report IsOpen == true.');
        end

        % ================= SUCCESS-5: grep gates (fileread, not shell) =================

        function testOctaveSafeGrepGate(testCase)
            % CanonicalMapper.m must not call contains() (Octave-safety).
            p = testCase.mapperSrcPath_();
            testCase.assumeTrue(exist(p, 'file') == 2, ...
                'CanonicalMapper.m not yet implemented (Wave 0 scaffold).');
            src = fileread(p);
            testCase.verifyEmpty(regexp(src, '\<contains\s*\(', 'match'), ...
                'CanonicalMapper.m must not call contains() — use strfind/strcmp (Octave-safe).');
        end

        function testNoToolboxCallGrepGate(testCase)
            % CanonicalMapper.m must not call Statistics Toolbox editDistance().
            % The private helper editDistance_ (trailing underscore) is allowed:
            % \< requires a word boundary, so editDistance_( and x.editDistance_( do not match.
            p = testCase.mapperSrcPath_();
            testCase.assumeTrue(exist(p, 'file') == 2, ...
                'CanonicalMapper.m not yet implemented (Wave 0 scaffold).');
            src = fileread(p);
            testCase.verifyEmpty(regexp(src, '\<editDistance\s*\(', 'match'), ...
                'CanonicalMapper.m must not call Statistics Toolbox editDistance().');
        end

    end

    % ---- Cleanup helpers ----
    methods (Access = private)
        function cleanupFile_(~, p)
            if exist(p, 'file') == 2
                delete(p);
            end
        end
        function cleanupEditor_(~, ed)
            if ~isempty(ed) && isvalid(ed)
                delete(ed);
            end
        end
    end

end
