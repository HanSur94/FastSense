classdef TestPlantLogLiveTail < matlab.unittest.TestCase
%TESTPLANTLOGLIVETAIL Class-based suite for PlantLogLiveTail (MATLAB only).
%   Mirrors tests/test_plant_log_live_tail.m and adds a real-timer smoke
%   test (testRealTimerSmokes) that exercises the full timer plumbing
%   end-to-end. Most tests use the hidden tick_() seam for deterministic
%   driving; the single real-timer test proves the timer actually works.
%
%   Coverage: PLOG-LT-01..05.
%
%   Contract: deliberately omits manual `addpath(fullfile( ..., 'libs',
%   'PlantLog'))` -- install.m's libs-block edit (Phase 1029 Plan 03) is
%   the regression gate.

    properties
        TempFiles = {}     % tracked temp paths cleaned by TestMethodTeardown
        Tails     = {}     % tracked PlantLogLiveTail handles cleaned by TestMethodTeardown
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            this_dir  = fileparts(mfilename('fullpath'));
            tests_dir = fileparts(this_dir);
            repo_root = fileparts(tests_dir);
            addpath(repo_root);
            install();
        end
    end

    methods (TestMethodTeardown)
        function cleanupAll(testCase)
            for k = 1:numel(testCase.Tails)
                try
                    if ~isempty(testCase.Tails{k}) && isvalid(testCase.Tails{k})
                        delete(testCase.Tails{k});
                    end
                catch
                end
            end
            testCase.Tails = {};
            for k = 1:numel(testCase.TempFiles)
                try
                    p = testCase.TempFiles{k};
                    if exist(p, 'file') == 2
                        delete(p);
                    end
                catch
                end
            end
            testCase.TempFiles = {};
        end
    end

    methods (Test)

        function testConstructorDefaults(testCase)
            s = PlantLogStore('x');
            m = struct('TimestampColumn', 'timestamp', ...
                       'MessageColumn',   'message', ...
                       'TimestampFormat', '');
            t = PlantLogLiveTail(s, '/tmp/dummy.csv', m);
            testCase.Tails{end+1} = t;
            testCase.verifyEqual(t.getInterval(), 5);
            testCase.verifyFalse(t.isRunning());
            testCase.verifyEqual(t.getErrorCount(), 0);
        end

        function testConstructorCustomInterval(testCase)
            s = PlantLogStore('x');
            m = struct('TimestampColumn', 'timestamp', ...
                       'MessageColumn',   'message', ...
                       'TimestampFormat', '');
            t = PlantLogLiveTail(s, '/tmp/dummy.csv', m, 'Interval', 0.25);
            testCase.Tails{end+1} = t;
            testCase.verifyEqual(t.getInterval(), 0.25);
        end

        function testConstructorValidatesStore(testCase)
            m = struct('TimestampColumn', 'timestamp', ...
                       'MessageColumn',   'message', ...
                       'TimestampFormat', '');
            testCase.verifyError( ...
                @() PlantLogLiveTail(struct('foo', 1), '/tmp/x.csv', m), ...
                'PlantLogLiveTail:invalidInput');
        end

        function testConstructorValidatesMapping(testCase)
            s = PlantLogStore('x');
            badMapping = struct('MessageColumn', 'message');  % no TimestampColumn
            testCase.verifyError( ...
                @() PlantLogLiveTail(s, '/tmp/x.csv', badMapping), ...
                'PlantLogLiveTail:invalidInput');
        end

        function testConstructorRejectsUnknownOption(testCase)
            s = PlantLogStore('x');
            m = struct('TimestampColumn', 'timestamp', ...
                       'MessageColumn',   'message', ...
                       'TimestampFormat', '');
            testCase.verifyError( ...
                @() PlantLogLiveTail(s, '/tmp/x.csv', m, 'Frequency', 1), ...
                'PlantLogLiveTail:unknownOption');
        end

        function testTickIngestsRows(testCase)
            p = testCase.makeTempCsv_();
            testCase.writeCsv_(p, { ...
                {'2025-01-15 10:00:00', 'pump on'}, ...
                {'2025-01-15 10:01:00', 'pump off'}, ...
                {'2025-01-15 10:02:00', 'valve open'}});
            s = PlantLogStore(p);
            m = struct('TimestampColumn', 'timestamp', ...
                       'MessageColumn',   'message', ...
                       'TimestampFormat', '');
            t = PlantLogLiveTail(s, p, m);
            testCase.Tails{end+1} = t;
            t.tick_();
            testCase.verifyEqual(s.getCount(), 3);
        end

        function testTickDedupSilent(testCase)
            p = testCase.makeTempCsv_();
            testCase.writeCsv_(p, { ...
                {'2025-01-15 10:00:00', 'pump on'}, ...
                {'2025-01-15 10:01:00', 'pump off'}});
            s = PlantLogStore(p);
            m = struct('TimestampColumn', 'timestamp', ...
                       'MessageColumn',   'message', ...
                       'TimestampFormat', '');
            t = PlantLogLiveTail(s, p, m);
            testCase.Tails{end+1} = t;
            t.tick_();
            t.tick_();
            testCase.verifyEqual(s.getCount(), 2, ...
                'Two ticks on unchanged file: dedup must hold count at 2');
        end

        function testTickAppendedRows(testCase)
            p = testCase.makeTempCsv_();
            testCase.writeCsv_(p, { ...
                {'2025-01-15 10:00:00', 'pump on'}, ...
                {'2025-01-15 10:01:00', 'pump off'}});
            s = PlantLogStore(p);
            m = struct('TimestampColumn', 'timestamp', ...
                       'MessageColumn',   'message', ...
                       'TimestampFormat', '');
            t = PlantLogLiveTail(s, p, m);
            testCase.Tails{end+1} = t;
            t.tick_();
            testCase.verifyEqual(s.getCount(), 2);
            testCase.appendCsv_(p, { ...
                {'2025-01-15 10:02:00', 'valve open'}, ...
                {'2025-01-15 10:03:00', 'pressure spike'}});
            t.tick_();
            testCase.verifyEqual(s.getCount(), 4);
        end

        function testTailTickEventPayload(testCase)
            p = testCase.makeTempCsv_();
            testCase.writeCsv_(p, { ...
                {'2025-01-15 10:00:00', 'pump on'}, ...
                {'2025-01-15 10:01:00', 'pump off'}});
            s = PlantLogStore(p);
            m = struct('TimestampColumn', 'timestamp', ...
                       'MessageColumn',   'message', ...
                       'TimestampFormat', '');
            t = PlantLogLiveTail(s, p, m);
            testCase.Tails{end+1} = t;

            captured = containers.Map('KeyType', 'char', 'ValueType', 'any');
            captured('payload') = [];
            captured('fires')   = 0;
            lis = addlistener(t, 'PlantLogTailTick', ...
                @(src, ed) testCase.captureTickPayload_(captured, ed));
            cleanupL = onCleanup(@() testCase.deleteHandle_(lis));

            t.tick_();
            testCase.verifyGreaterThanOrEqual(captured('fires'), 1);
            payload = captured('payload');
            testCase.verifyClass(payload, 'PlantLogTailEventData');
            testCase.verifyTrue(isprop(payload, 'Time'));
            testCase.verifyTrue(isprop(payload, 'EntriesAdded'));
            testCase.verifyTrue(isprop(payload, 'TotalCount'));
            testCase.verifyTrue(isprop(payload, 'ErrorCount'));
            testCase.verifyEqual(payload.EntriesAdded, 2);
            testCase.verifyEqual(payload.TotalCount, s.getCount());
            testCase.verifyEqual(payload.ErrorCount, 0);
            testCase.verifyTrue(isnumeric(payload.Time) && isscalar(payload.Time));
            clear cleanupL;
        end

        function testStartStopCleanup(testCase)
            s = PlantLogStore('x');
            m = struct('TimestampColumn', 'timestamp', ...
                       'MessageColumn',   'message', ...
                       'TimestampFormat', '');
            t = PlantLogLiveTail(s, '/tmp/dummy.csv', m, 'Interval', 5);
            testCase.Tails{end+1} = t;
            % Suppress tickError warnings from any spurious tick on dummy path.
            w = warning('off', 'PlantLogLiveTail:tickError');
            cleanupW = onCleanup(@() warning(w));
            baseline = numel(timerfindall());
            t.start();
            pause(0.05);
            testCase.verifyTrue(t.isRunning());
            t.stop();
            testCase.verifyFalse(t.isRunning());
            after = numel(timerfindall());
            testCase.verifyLessThanOrEqual(after, baseline, ...
                'timerfindall after stop() must not exceed baseline');
            clear cleanupW;
        end

        function testRealTimerSmokes(testCase)
            % End-to-end real-timer smoke: write CSV, start tail with short
            % interval, wait for at least 2 ticks to fire, assert store is
            % populated and tail is still running. Then stop + verify clean.
            p = testCase.makeTempCsv_();
            testCase.writeCsv_(p, { ...
                {'2025-01-15 10:00:00', 'pump on'}, ...
                {'2025-01-15 10:01:00', 'pump off'}, ...
                {'2025-01-15 10:02:00', 'valve open'}});
            s = PlantLogStore(p);
            m = struct('TimestampColumn', 'timestamp', ...
                       'MessageColumn',   'message', ...
                       'TimestampFormat', '');
            baseline = numel(timerfindall());
            t = PlantLogLiveTail(s, p, m, ...
                'Interval', 0.2, 'StartImmediately', true);
            testCase.Tails{end+1} = t;
            pause(0.6);  % gives ~2-3 ticks
            testCase.verifyTrue(t.isRunning());
            testCase.verifyEqual(s.getCount(), 3);
            t.stop();
            testCase.verifyFalse(t.isRunning());
            after = numel(timerfindall());
            testCase.verifyLessThanOrEqual(after, baseline, ...
                'Real-timer test: timerfindall must return to baseline after stop()');
        end

    end

    methods (Access = private)

        function p = makeTempCsv_(testCase)
            p = [tempname() '.csv'];
            testCase.TempFiles{end+1} = p;
        end

        function writeCsv_(testCase, path, rows) %#ok<INUSL>
            fid = fopen(path, 'w');
            fprintf(fid, 'timestamp,message\n');
            for k = 1:numel(rows)
                fprintf(fid, '%s,%s\n', rows{k}{1}, rows{k}{2});
            end
            fclose(fid);
        end

        function appendCsv_(testCase, path, rows) %#ok<INUSL>
            fid = fopen(path, 'a');
            for k = 1:numel(rows)
                fprintf(fid, '%s,%s\n', rows{k}{1}, rows{k}{2});
            end
            fclose(fid);
        end

        function captureTickPayload_(testCase, captured, ed) %#ok<INUSL>
            % Mutates the shared containers.Map captured in place.
            % NASGU suppression: containers.Map(key)=val is a subsasgn call,
            % not a workspace assignment; the linter false-flags it.
            captured('fires') = captured('fires') + 1;
            captured('payload') = ed; %#ok<NASGU>
        end

        function deleteHandle_(testCase, h) %#ok<INUSL>
            try
                if ~isempty(h) && isvalid(h)
                    delete(h);
                end
            catch
            end
        end

    end
end
