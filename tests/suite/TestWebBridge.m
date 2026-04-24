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
    end
end
