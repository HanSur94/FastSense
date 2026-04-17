classdef TestFastSenseAddTag < matlab.unittest.TestCase
    %TESTFASTSENSEADDTAG Unit tests for FastSense.addTag polymorphic dispatcher (TAG-10).
    %   Verifies the Phase 1005-03 Wave 2 integration: FastSense gains a
    %   single public method addTag(tag, varargin) that routes by
    %   tag.getKind() — not by isa() on subclass names (Pitfall 1 gate).
    %
    %   Coverage:
    %     - Non-Tag input         -> FastSense:invalidTag
    %     - Post-render call      -> FastSense:alreadyRendered
    %     - SensorTag             -> addLine(x, y, 'DisplayName', name)
    %     - StateTag numeric Y    -> staircase line (2N-1 points)
    %     - StateTag cellstr Y    -> FastSense:stateTagCellstrNotSupported
    %     - MockTag (kind='mock') -> FastSense:unsupportedTagKind
    %     - Mix with legacy addSensor -> both paths coexist (strangler-fig)
    %     - Empty StateTag        -> silent no-op
    %     - Pitfall 1 grep gate   -> FastSense.m has NO isa(.., 'SensorTag'|'StateTag')
    %
    %   See also FastSense, Tag, SensorTag, StateTag, TagRegistry, TestAddLine.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function clearBefore(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function clearAfter(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)

        % ---- Guard clauses ----

        function testAddTagRejectsNonTag(testCase)
            fp = FastSense();
            testCase.verifyError(@() fp.addTag(struct('x', 1)), ...
                'FastSense:invalidTag');
        end

        function testAddTagRejectsAfterRender(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1, 10));
            fp.render();
            st = SensorTag('s', 'X', 1:5, 'Y', 1:5);
            testCase.verifyError(@() fp.addTag(st), ...
                'FastSense:alreadyRendered');
            try, delete(fp); catch, end %#ok<NOCOM>
        end

        % ---- Dispatch — success paths ----

        function testAddTagWithSensorTagAddsLine(testCase)
            fp = FastSense();
            x = 1:100;
            y = sin(x * 0.1);
            st = SensorTag('press_a', 'Name', 'Press', 'X', x, 'Y', y);
            fp.addTag(st);
            testCase.verifyEqual(numel(fp.Lines), 1);
            testCase.verifyEqual(fp.Lines(1).Options.DisplayName, 'Press');
            testCase.verifyEqual(fp.Lines(1).X, x);
            testCase.verifyEqual(fp.Lines(1).Y, y);
        end

        function testAddTagWithStateTagAddsStaircase(testCase)
            fp = FastSense();
            st = StateTag('mode', 'X', [1 5 10 20], 'Y', [0 1 2 3]);
            fp.addTag(st);
            testCase.verifyEqual(numel(fp.Lines), 1);
            % Interleaved staircase: N=4 -> 2N-1 = 7 points
            expectedX = [1 5 5 10 10 20 20];
            expectedY = [0 0 1 1 2 2 3];
            testCase.verifyEqual(numel(fp.Lines(1).X), 7);
            testCase.verifyEqual(fp.Lines(1).X, expectedX);
            testCase.verifyEqual(fp.Lines(1).Y, expectedY);
            testCase.verifyEqual(fp.Lines(1).Options.DisplayName, 'mode');
        end

        % ---- Dispatch — error paths ----

        function testAddTagRejectsCellstrStateTag(testCase)
            fp = FastSense();
            st = StateTag('m', 'X', [1 5 10], 'Y', {'idle', 'run', 'stop'});
            testCase.verifyError(@() fp.addTag(st), ...
                'FastSense:stateTagCellstrNotSupported');
        end

        function testAddTagRejectsUnsupportedKind(testCase)
            fp = FastSense();
            mt = MockTag('m');   % MockTag.getKind() == 'mock'
            testCase.verifyError(@() fp.addTag(mt), ...
                'FastSense:unsupportedTagKind');
        end

        % ---- Strangler-fig parity ----

        function testAddTagMixedWithLegacy(testCase)
            fp = FastSense();
            legacy = SensorTag('legacy', 'Name', 'Legacy');
            legacy.updateData(1:50, cos(legacy.X * 0.2));
            fp.addTag(legacy, 'ShowThresholds', false);

            st = SensorTag('modern', 'Name', 'Modern', 'X', 1:30, 'Y', sin(1:30));
            fp.addTag(st);

            testCase.verifyEqual(numel(fp.Lines), 2, ...
                'legacy addSensor + new addTag must coexist on one FastSense');
            testCase.verifyEqual(fp.Lines(1).Options.DisplayName, 'Legacy');
            testCase.verifyEqual(fp.Lines(2).Options.DisplayName, 'Modern');
        end

        % ---- Edge cases ----

        function testAddTagEmptyStateTagIsNoOp(testCase)
            fp = FastSense();
            st = StateTag('empty');   % no X, no Y
            fp.addTag(st);            % must not throw
            testCase.verifyEqual(numel(fp.Lines), 0, ...
                'Empty StateTag should be a silent no-op (no line added)');
        end

        % ---- Pitfall 1 grep gate ----

        function testPitfall1NoIsaSensorTag(testCase)
            % Pitfall 1 gate — addTag must dispatch on getKind() only,
            % NOT isa() on subclass names. The one permitted isa(tag, 'Tag')
            % is a contract guard (base-class check), not a dispatch.
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            fsPath = fullfile(repo, 'libs', 'FastSense', 'FastSense.m');
            src = fileread(fsPath);
            match = regexp(src, 'isa\s*\([^,]*,\s*''(SensorTag|StateTag)''\s*\)', 'once');
            testCase.verifyEmpty(match, ...
                'Pitfall 1: FastSense.m must not dispatch via isa(SensorTag|StateTag).');
        end
    end
end
