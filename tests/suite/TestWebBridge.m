classdef TestWebBridge < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end
    methods (Test)
        function testConstructor(testCase)
            engine = DashboardEngine('Test');
            bridge = WebBridge(engine);
            testCase.addTeardown(@() delete(bridge));
            testCase.verifyEqual(bridge.Dashboard, engine);
            testCase.verifyFalse(bridge.IsServing);
        end
        function testRegisterAction(testCase)
            engine = DashboardEngine('Test');
            bridge = WebBridge(engine);
            testCase.addTeardown(@() delete(bridge));
            bridge.registerAction('test', @() disp('called'));
            testCase.verifyTrue(bridge.hasAction('test'));
        end

        % ---- Issue #318: unregisterAction / listActions ----

        function testUnregisterAction(testCase)
            engine = DashboardEngine('Test');
            bridge = WebBridge(engine);
            testCase.addTeardown(@() delete(bridge));
            bridge.registerAction('test', @() disp('called'));
            testCase.verifyTrue(bridge.hasAction('test'));
            bridge.unregisterAction('test');
            testCase.verifyFalse(bridge.hasAction('test'), 'action removed');
        end

        function testUnregisterActionAbsentIsNoOp(testCase)
            engine = DashboardEngine('Test');
            bridge = WebBridge(engine);
            testCase.addTeardown(@() delete(bridge));
            bridge.unregisterAction('never_registered');  % must not error
            testCase.verifyFalse(bridge.hasAction('never_registered'));
        end

        function testListActionsIncludesRegistered(testCase)
            engine = DashboardEngine('Test');
            bridge = WebBridge(engine);
            testCase.addTeardown(@() delete(bridge));
            bridge.registerAction('alpha', @() 1);
            names = bridge.listActions();
            testCase.verifyTrue(iscell(names));
            testCase.verifyTrue(ismember('alpha', names), 'registered action listed');
        end

        function testListActionsReflectsUnregister(testCase)
            engine = DashboardEngine('Test');
            bridge = WebBridge(engine);
            testCase.addTeardown(@() delete(bridge));
            bridge.registerAction('beta', @() 1);
            bridge.unregisterAction('beta');
            testCase.verifyFalse(ismember('beta', bridge.listActions()), ...
                'unregistered action no longer listed');
        end
    end
end
