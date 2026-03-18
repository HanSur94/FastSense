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
        function testStartTcpServer(testCase)
            engine = DashboardEngine('Test');
            bridge = WebBridge(engine);
            testCase.addTeardown(@() bridge.stop());
            bridge.startTcp();
            testCase.verifyTrue(bridge.IsServing);
            testCase.verifyGreaterThan(bridge.TcpPort, 0);
        end
        function testTcpSendsInitOnConnect(testCase)
            engine = DashboardEngine('Test');
            bridge = WebBridge(engine);
            testCase.addTeardown(@() bridge.stop());
            bridge.startTcp();
            client = tcpclient('localhost', bridge.TcpPort, 'Timeout', 5);
            testCase.addTeardown(@() delete(client));
            pause(0.5);
            data = readline(client);
            msg = jsondecode(data);
            testCase.verifyEqual(msg.type, 'init');
            testCase.verifyTrue(isfield(msg, 'signals'));
            testCase.verifyTrue(isfield(msg, 'dashboard'));
            testCase.verifyTrue(isfield(msg, 'actions'));
        end
        function testShutdownSendsMessage(testCase)
            engine = DashboardEngine('Test');
            bridge = WebBridge(engine);
            bridge.startTcp();
            client = tcpclient('localhost', bridge.TcpPort, 'Timeout', 5);
            testCase.addTeardown(@() delete(client));
            pause(0.3);
            readline(client);
            bridge.stop();
            pause(0.3);
            data = readline(client);
            msg = jsondecode(data);
            testCase.verifyEqual(msg.type, 'shutdown');
        end
        function testRegisterAction(testCase)
            engine = DashboardEngine('Test');
            bridge = WebBridge(engine);
            testCase.addTeardown(@() delete(bridge));
            bridge.registerAction('test', @() disp('called'));
            testCase.verifyTrue(bridge.hasAction('test'));
        end
        function testActionInvocation(testCase)
            engine = DashboardEngine('Test');
            bridge = WebBridge(engine);
            testCase.addTeardown(@() bridge.stop());
            bridge.registerAction('add', @(args) struct('sum', args.a + args.b));
            bridge.startTcp();
            client = tcpclient('localhost', bridge.TcpPort, 'Timeout', 5);
            testCase.addTeardown(@() delete(client));
            pause(0.3);
            readline(client);
            actionMsg = jsonencode(struct('type', 'action', 'id', 'req-1', 'name', 'add', 'args', struct('a', 2, 'b', 3)));
            writeline(client, actionMsg);
            pause(0.5);
            data = readline(client);
            msg = jsondecode(data);
            testCase.verifyEqual(msg.type, 'action_result');
            testCase.verifyEqual(msg.id, 'req-1');
            testCase.verifyTrue(msg.ok);
        end
        function testNotifyDataChanged(testCase)
            engine = DashboardEngine('Test');
            bridge = WebBridge(engine);
            testCase.addTeardown(@() bridge.stop());
            bridge.startTcp();
            client = tcpclient('localhost', bridge.TcpPort, 'Timeout', 5);
            testCase.addTeardown(@() delete(client));
            pause(0.3);
            readline(client);
            bridge.notifyDataChanged('s1');
            pause(0.3);
            data = readline(client);
            msg = jsondecode(data);
            testCase.verifyEqual(msg.type, 'data_changed');
        end
    end
end
