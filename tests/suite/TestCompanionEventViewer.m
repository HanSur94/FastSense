classdef TestCompanionEventViewer < matlab.unittest.TestCase
%TESTCOMPANIONEVENTVIEWER Class-based tests for CompanionEventViewer.
%   See docs/superpowers/specs/2026-05-08-companion-event-viewer-design.md.

    methods (TestClassSetup)
        function gateModernMatlab(testCase)
            testCase.assumeTrue(~verLessThan('matlab', '9.10'), ...
                'Companion suite requires MATLAB R2021a+');
        end
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function skipOnOctave(testCase)
            testCase.assumeFalse( ...
                exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestCompanionEventViewer: skipped on Octave (companion is MATLAB-only).');
        end
    end

    methods (Test)
        function testConstructorRequiresEventStore(testCase)
            testCase.verifyError( ...
                @() CompanionEventViewer([], TagRegistry, makeFakeCompanion_()), ...
                'CompanionEventViewer:invalidStore');
        end

        function testConstructorRequiresRegistry(testCase)
            es = makeStore_(testCase);
            testCase.verifyError( ...
                @() CompanionEventViewer(es, [], makeFakeCompanion_()), ...
                'CompanionEventViewer:invalidRegistry');
        end

        function testConstructorRequiresCompanion(testCase)
            es = makeStore_(testCase);
            testCase.verifyError( ...
                @() CompanionEventViewer(es, TagRegistry, []), ...
                'CompanionEventViewer:invalidCompanion');
        end

        function testConstructorOpensFigure(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            testCase.verifyTrue(isgraphics(v.hFigure));
        end

        function testCloseIsIdempotent(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            v.close();
            testCase.verifyWarningFree(@() v.close(), ...
                'close() must be idempotent.');
        end

        function testCloseDeletesFigure(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            f = v.hFigure;
            v.close();
            testCase.verifyFalse(isgraphics(f), 'figure must be destroyed.');
        end

        function testBringToFrontIdempotent(testCase)
            es = makeStore_(testCase);
            comp = makeRealCompanion_(testCase);
            v = CompanionEventViewer(es, TagRegistry, comp);
            testCase.addTeardown(@() v.close());
            testCase.verifyWarningFree(@() v.bringToFront());
            testCase.verifyTrue(isgraphics(v.hFigure));
        end
    end
end

% --- File-local helpers (after the classdef end) ----------------------
function es = makeStore_(testCase)
    storePath = [tempname() '.mat'];
    es = EventStore(storePath);
    testCase.addTeardown(@() delete(storePath));
end

function comp = makeFakeCompanion_()
    % Minimal stub for typecheck — real companion needed for listener wiring tests later.
    comp = struct('IsLive', false, 'LivePeriod', 1.0);
end

function comp = makeRealCompanion_(testCase)
    comp = FastSenseCompanion();
    testCase.addTeardown(@() comp.close());
end
