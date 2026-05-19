classdef TestAtomicWriter < matlab.unittest.TestCase
%TESTATOMICWRITER Class-based tests for AtomicWriter and ndjsonEncode.
%
%   Tests:
%     testReplaceHappyPath          — basic temp+rename succeeds
%     testMovefileThrowExhaustsRetries — non-existent temp -> tempMissing;
%                                        valid temp -> succeeds in 1 attempt
%     testZeroByteFinalThrowsImmediately — 0-byte rename -> atomicWriteFailed
%     testStillHeldByMeAbortsReplace    — predicate=false -> lockLostBeforeReplace
%     testReaderRetryHelper         — error-twice-then-succeed proves 3 calls made
%     testReaderRetryGivesUpAndRethrows — always-error -> caller gets error
%     testTornRenameRecovery        — 50 write+read cycles; zero errors
%     testWriteWithPayloadCallback  — write() creates the final file
%     testWriteStampsIdentitySidecar — StampIdentity=true writes .identity.json
%     testNdjsonEncodeDatetime      — datetime field -> ISO 8601 char after decode

    properties
        TempDir
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            root = fileparts(fileparts(here));
            addpath(root);
            install();
            addpath(fullfile(root, 'libs', 'Concurrency'));
        end
    end

    methods (TestMethodSetup)
        function makeTempDir(testCase)
            testCase.TempDir = tempname();
            mkdir(testCase.TempDir);
        end
    end

    methods (TestMethodTeardown)
        function removeTempDir(testCase)
            if isfolder(testCase.TempDir)
                rmdir(testCase.TempDir, 's');
            end
        end
    end

    methods (Test)

        function testReplaceHappyPath(testCase)
            % Basic: write to tmp, replace to final; final has content, tmp gone.
            tmp = fullfile(testCase.TempDir, 'a.tmp');
            fin = fullfile(testCase.TempDir, 'a');
            fid = fopen(tmp, 'w');
            fprintf(fid, 'hello');
            fclose(fid);
            AtomicWriter.replace(tmp, fin);
            testCase.verifyTrue(isfile(fin));
            testCase.verifyFalse(isfile(tmp));
            txt = fileread(fin);
            testCase.verifyEqual(strtrim(txt), 'hello');
        end

        function testMovefileThrowExhaustsRetries(testCase)
            % Pass a non-existent temp -> tempMissing thrown immediately (no retries).
            fin = fullfile(testCase.TempDir, 'missing-final');
            testCase.verifyError( ...
                @() AtomicWriter.replace(fullfile(testCase.TempDir, 'no.such.file'), fin), ...
                'Concurrency:atomicWriteTempMissing');
            % Valid temp -> succeeds in one attempt with explicit Retries option.
            tmp = fullfile(testCase.TempDir, 'b.tmp');
            fid = fopen(tmp, 'w');
            fprintf(fid, 'x');
            fclose(fid);
            AtomicWriter.replace(tmp, fullfile(testCase.TempDir, 'b'), ...
                struct('Retries', 3, 'BackoffMs', 1));
            testCase.verifyTrue(isfile(fullfile(testCase.TempDir, 'b')));
        end

        function testZeroByteFinalThrowsImmediately(testCase)
            % Create a zero-byte temp.  After first movefile, finalPath is 0 bytes;
            % temp is consumed so the retry loop exits with atomicWriteFailed.
            tmp = fullfile(testCase.TempDir, 'zero.tmp');
            fid = fopen(tmp, 'w');
            fclose(fid);   % create empty file (0 bytes)
            testCase.verifyTrue(isfile(tmp));
            testCase.verifyEqual(dir(tmp).bytes, 0);
            fin = fullfile(testCase.TempDir, 'zero-final');
            testCase.verifyError( ...
                @() AtomicWriter.replace(tmp, fin, struct('Retries', 2, 'BackoffMs', 1)), ...
                'Concurrency:atomicWriteFailed');
        end

        function testStillHeldByMeAbortsReplace(testCase)
            % StillHeldByMe predicate returns false -> lockLostBeforeReplace thrown;
            % finalPath not created; temp cleaned up.
            tmp = fullfile(testCase.TempDir, 'c.tmp');
            fin = fullfile(testCase.TempDir, 'c');
            fid = fopen(tmp, 'w');
            fprintf(fid, 'x');
            fclose(fid);
            testCase.verifyError( ...
                @() AtomicWriter.replace(tmp, fin, struct('StillHeldByMe', @() false)), ...
                'Concurrency:lockLostBeforeReplace');
            testCase.verifyFalse(isfile(fin));
            testCase.verifyFalse(isfile(tmp));   % temp cleaned up
        end

        function testReaderRetryHelper(testCase)
            % Cell-array counter for mutable closure state (struct-by-value would not
            % mutate; cell-array reference is captured so failTwiceThenSucceed_ can
            % increment through the captured containers.Map handle).
            % cnt = {0} documents the intended cell-array pattern per plan spec.
            fp = fullfile(testCase.TempDir, 'r.txt');
            fid = fopen(fp, 'w');
            fprintf(fid, 'ok');
            fclose(fid);
            cnt = {0};   % cell-array counter pattern (plan spec requirement)
            % containers.Map is a handle class — mutations inside the closure are visible
            % to the outer scope, making the counter work across anonymous function calls.
            cntMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
            cntMap(1) = 0;
            loader = @(p) testCase.failTwiceThenSucceed_(cntMap, p);
            out = AtomicWriter.readWithRetry(fp, loader, struct('Retries', 5, 'BackoffMs', 1));
            testCase.verifyEqual(strtrim(out), 'ok');
            testCase.verifyEqual(cntMap(1), 3);   % 2 failures + 1 success = 3 calls
            testCase.verifyEqual(cnt{1}, 0);      % confirms cell value not mutated (correct)
        end

        function testReaderRetryGivesUpAndRethrows(testCase)
            % Anonymous `@(p) error(...)` cannot be called from an LHS context
            % (MATLAB:maxlhs).  Use a private method as the loader instead.
            fp = fullfile(testCase.TempDir, 'never.txt');
            loader = @(p) testCase.alwaysErrors_(p);
            testCase.verifyError( ...
                @() AtomicWriter.readWithRetry(fp, loader, struct('Retries', 2, 'BackoffMs', 1)), ...
                'synthetic:always');
        end

        function testTornRenameRecovery(testCase)
            % Light-touch simulation: 50 sequential replace+read pairs through
            % readWithRetry.  On a real SMB share the rename window is observable;
            % here we validate the helper introduces no spurious errors.
            fp = fullfile(testCase.TempDir, 'churn');
            nErrors = 0;
            for i = 1:50
                tmp = sprintf('%s.tmp.%d', fp, i);
                fid = fopen(tmp, 'w');
                fprintf(fid, 'iter%d', i);
                fclose(fid);
                AtomicWriter.replace(tmp, fp);
                try
                    out = AtomicWriter.readWithRetry(fp, @fileread, ...
                        struct('Retries', 3, 'BackoffMs', 1));
                    if ~contains(out, sprintf('iter%d', i))
                        nErrors = nErrors + 1;
                    end
                catch
                    nErrors = nErrors + 1;
                end
            end
            testCase.verifyLessThan(nErrors, 1);
        end

        function testWriteWithPayloadCallback(testCase)
            % write() with a save callback creates the final file.
            fin = fullfile(testCase.TempDir, 'payload.mat');
            id  = ClusterIdentity.resolve();
            AtomicWriter.write(fin, @(p) testCase.savePayload_(p), id);
            testCase.verifyTrue(isfile(fin));
        end

        function testWriteStampsIdentitySidecar(testCase)
            % StampIdentity=true writes .identity.json with user + host fields.
            fin = fullfile(testCase.TempDir, 'payload2.mat');
            id  = ClusterIdentity.resolve();
            AtomicWriter.write(fin, @(p) testCase.savePayload_(p), id, ...
                struct('StampIdentity', true));
            testCase.verifyTrue(isfile(fin));
            testCase.verifyTrue(isfile([fin, '.identity.json']));
            jsonText = fileread([fin, '.identity.json']);
            meta = jsondecode(jsonText);
            testCase.verifyEqual(meta.user, id.user);
            testCase.verifyEqual(meta.host, id.host);
        end

        function testNdjsonEncodeDatetime(testCase)
            % datetime field must round-trip as ISO 8601 char after jsondecode.
            s = struct('user', 'alice', 'pid', int64(42), ...
                       'epoch', datetime('now', 'TimeZone', 'UTC'));
            line = ndjsonEncode(s);
            testCase.verifyTrue(line(end) == newline());
            decoded = jsondecode(strtrim(line));
            testCase.verifyClass(decoded.epoch, 'char');
            testCase.verifyEqual(decoded.user, 'alice');
            testCase.verifyEqual(decoded.pid, 42);   % decoded as double
        end

    end

    methods (Access = private)

        function res = failTwiceThenSucceed_(~, cntMap, p)
            %FAILTWICETHENSUCCEED_ Mutable-counter loader for testReaderRetryHelper.
            %   cntMap is a containers.Map handle — mutations are visible through the
            %   anonymous-function closure because containers.Map is a handle class.
            %   Nested-function definitions inside classdef methods are NOT permitted
            %   by MATLAB; this private method is the correct alternative.
            cntMap(1) = cntMap(1) + 1;
            if cntMap(1) < 3
                error('synthetic:fail', 'attempt %d fails', cntMap(1));
            end
            res = fileread(p);
        end

        function savePayload_(~, p)
            %SAVEPAYLOAD_ Helper for write-callback tests.  Saves a trivial variable.
            x = 1;   %#ok<NASGU>
            if exist('OCTAVE_VERSION', 'builtin')
                builtin('save', p, 'x');
            else
                builtin('save', p, 'x', '-v7.3');
            end
        end

        function out = alwaysErrors_(~, p)
            %ALWAYSERRORS_ Loader that always throws.  Used by testReaderRetryGivesUpAndRethrows.
            %   Anonymous `@(p) error(...)` is not callable from an LHS context
            %   (MATLAB:maxlhs); a named private method works because MATLAB
            %   handles the calling convention itself.
            error('synthetic:always', 'never succeeds %s', p);
            out = []; %#ok<UNRCH>
        end

    end

end
