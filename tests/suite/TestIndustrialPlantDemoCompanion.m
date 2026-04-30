classdef TestIndustrialPlantDemoCompanion < matlab.unittest.TestCase
%TESTINDUSTRIALPLANTDEMOCOMPANION Phase 1023 milestone-canary tests.
%   Covers COMPDEMO-01..04 by running the REAL run_demo() flow (no mocks)
%   and asserting the FastSenseCompanion wiring landed in Plan 01:
%     COMPDEMO-01 — ctx.companion field is a live FastSenseCompanion
%     COMPDEMO-02 — run_demo('Companion', false) suppresses companion
%     COMPDEMO-03 — TagRegistry has tags with area:* labels (catalog precondition)
%     COMPDEMO-04 — teardownDemo closes companion + leaves no orphan timers
%
%   Each test method calls addTeardown(@() teardownDemo(ctx)) IMMEDIATELY
%   after run_demo() so cleanup runs even on assertion failure. Skipped on
%   Octave (assumeFalse on OCTAVE_VERSION).
%
%   See also: run_demo, teardownDemo, FastSenseCompanion, TagRegistry.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
        %ADDPATHS Add demo + suite + lib paths and run install().
            here = fileparts(mfilename('fullpath'));
            repoRoot = fullfile(here, '..', '..');
            addpath(fullfile(repoRoot, 'demo', 'industrial_plant'));
            addpath(fullfile(repoRoot, 'tests', 'suite'));
            run(fullfile(repoRoot, 'install.m'));
        end
    end

    methods (Test)

        function testCOMPDEMO01_companionFieldIsValid(testCase)
        %TESTCOMPDEMO01_COMPANIONFIELDISVALID COMPDEMO-01: ctx.companion is a live FastSenseCompanion wrapping the demo dashboard.
            testCase.assumeFalse(exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestIndustrialPlantDemoCompanion is MATLAB-only.');
            TagRegistry.clear();
            ctx = run_demo();
            testCase.addTeardown(@() teardownDemo(ctx));
            testCase.addTeardown(@() TagRegistry.clear());
            testCase.assertTrue(isfield(ctx, 'companion'), ...
                'COMPDEMO-01: ctx must have a companion field after run_demo()');
            testCase.assertNotEmpty(ctx.companion, ...
                'COMPDEMO-01: ctx.companion must be non-empty when Companion defaults to true');
            testCase.assertTrue(isa(ctx.companion, 'FastSenseCompanion'), ...
                'COMPDEMO-01: ctx.companion must be a FastSenseCompanion instance');
            testCase.assertTrue(isvalid(ctx.companion), ...
                'COMPDEMO-01: ctx.companion must be a valid handle');
            testCase.verifyTrue(ctx.companion.IsOpen, ...
                'COMPDEMO-01: ctx.companion.IsOpen must be true while demo is running');
            testCase.assertNotEmpty(ctx.companion.Dashboards, ...
                'COMPDEMO-01: companion.Dashboards must contain the demo engine');
            testCase.verifyEqual(ctx.companion.Dashboards{1}, ctx.engine, ...
                'COMPDEMO-01: companion.Dashboards{1} must be the same handle as ctx.engine');
        end

        function testCOMPDEMO02_companionFalseSuppresses(testCase)
        %TESTCOMPDEMO02_COMPANIONFALSESUPPRESSES COMPDEMO-02: 'Companion', false yields ctx.companion = [].
            testCase.assumeFalse(exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestIndustrialPlantDemoCompanion is MATLAB-only.');
            TagRegistry.clear();
            ctx = run_demo('Companion', false);
            testCase.addTeardown(@() teardownDemo(ctx));
            testCase.addTeardown(@() TagRegistry.clear());
            testCase.assertTrue(isfield(ctx, 'companion'), ...
                'COMPDEMO-02: ctx must still have a companion field even when suppressed');
            testCase.verifyTrue(isempty(ctx.companion), ...
                'COMPDEMO-02: ctx.companion must be [] when Companion=false');
            testCase.verifyTrue(isa(ctx.engine, 'DashboardEngine'), ...
                'COMPDEMO-02: dashboard engine must still be built when companion is suppressed');
        end

        function testCOMPDEMO03_tagCatalogReflectsRegistry(testCase)
        %TESTCOMPDEMO03_TAGCATALOGREFLECTSREGISTRY COMPDEMO-03: TagRegistry has tags with area:* labels.
        %   The actual visual grouping of the catalog by Labels is covered by
        %   Phase 1019's TestTagCatalogPane suite. This test verifies the
        %   PRECONDITION: registerPlantTags populates the registry with tags
        %   carrying area:* labels so the companion catalog can group them.
            testCase.assumeFalse(exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestIndustrialPlantDemoCompanion is MATLAB-only.');
            TagRegistry.clear();
            ctx = run_demo();
            testCase.addTeardown(@() teardownDemo(ctx));
            testCase.addTeardown(@() TagRegistry.clear());
            % Call TagRegistry.list() for its side effect (prints to cmd window).
            TagRegistry.list();
            % Get all registered tags via find to assert count and scan labels.
            tags = TagRegistry.find(@(t) true);
            testCase.assertNotEmpty(tags, ...
                'COMPDEMO-03: TagRegistry must have tags after run_demo()');
            hasAreaLabel = false;
            for i = 1:numel(tags)
                tag = tags{i};
                labels = tag.Labels;
                for j = 1:numel(labels)
                    if ~isempty(strfind(labels{j}, 'area:'))
                        hasAreaLabel = true;
                        break;
                    end
                end
                if hasAreaLabel
                    break;
                end
            end
            testCase.verifyTrue(hasAreaLabel, ...
                'COMPDEMO-03: at least one registered plant tag must have an area:* Labels entry (catalog grouping precondition)');
        end

        function testCOMPDEMO04_teardownClosesCompanionAndNoOrphanTimers(testCase)
        %TESTCOMPDEMO04_TEARDOWNCLOSESCOMPANIONANDNOORPHANTIMERS COMPDEMO-04: teardownDemo closes companion + leaves no orphan timers.
            testCase.assumeFalse(exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestIndustrialPlantDemoCompanion is MATLAB-only.');
            TagRegistry.clear();
            preTimers = timerfindall();
            ctx = run_demo();
            testCase.addTeardown(@() TagRegistry.clear());
            testCase.assertNotEmpty(ctx.companion, ...
                'COMPDEMO-04 precondition: companion must exist for the teardown assertion to be meaningful');
            testCase.assertTrue(isvalid(ctx.companion), ...
                'COMPDEMO-04 precondition: companion must be valid before teardown');
            % Run teardown explicitly (NOT via addTeardown) so we can assert
            % POST-teardown state inside this test method. teardownDemo is
            % idempotent — the addTeardown safety-net call below is a no-op.
            teardownDemo(ctx);
            drawnow;
            testCase.addTeardown(@() teardownDemo(ctx));   % belt-and-braces
            testCase.verifyTrue( ~isvalid(ctx.companion) || ~ctx.companion.IsOpen, ...
                'COMPDEMO-04: teardownDemo must close ctx.companion (handle invalid OR IsOpen=false)');
            postTimers = timerfindall();
            newTimers  = setdiff(postTimers, preTimers);
            testCase.verifyEmpty(newTimers, ...
                'COMPDEMO-04: teardownDemo must leave no NEW timers in timerfindall (no orphans)');
        end

    end

end
