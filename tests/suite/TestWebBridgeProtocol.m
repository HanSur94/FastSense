classdef TestWebBridgeProtocol < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end
    methods (Test)
        function testEncodeInit(testCase)
            signals = struct('id', {'s1', 's2'}, 'dbPath', {'/tmp/a.fpdb', '/tmp/b.fpdb'}, 'title', {'Temp', 'Pressure'});
            actions = {'recalc', 'setRange'};
            msg = WebBridgeProtocol.encodeInit(signals, actions);
            testCase.verifyTrue(endsWith(msg, newline));
            decoded = jsondecode(msg);
            testCase.verifyEqual(decoded.type, 'init');
            testCase.verifyEqual(numel(decoded.signals), 2);
            testCase.verifyEqual(decoded.signals(1).id, 's1');
        end
        function testEncodeDataChanged(testCase)
            msg = WebBridgeProtocol.encodeDataChanged({'s1'});
            decoded = jsondecode(msg);
            testCase.verifyEqual(decoded.type, 'data_changed');
            testCase.verifyEqual(decoded.signals, {'s1'});
        end
        function testEncodeActionResult(testCase)
            msg = WebBridgeProtocol.encodeActionResult('req-1', 'recalc', true, '');
            decoded = jsondecode(msg);
            testCase.verifyEqual(decoded.type, 'action_result');
            testCase.verifyEqual(decoded.id, 'req-1');
            testCase.verifyTrue(decoded.ok);
            testCase.verifyFalse(isfield(decoded, 'error'));
        end
        function testEncodeActionResultError(testCase)
            msg = WebBridgeProtocol.encodeActionResult('req-2', 'bad', false, 'something broke');
            decoded = jsondecode(msg);
            testCase.verifyFalse(decoded.ok);
            testCase.verifyEqual(decoded.error, 'something broke');
        end
        function testEncodeShutdown(testCase)
            msg = WebBridgeProtocol.encodeShutdown();
            decoded = jsondecode(msg);
            testCase.verifyEqual(decoded.type, 'shutdown');
        end
        function testDecodeAction(testCase)
            raw = '{"type":"action","id":"req-1","name":"recalc","args":{"x":1}}';
            msg = WebBridgeProtocol.decode(raw);
            testCase.verifyEqual(msg.type, 'action');
            testCase.verifyEqual(msg.id, 'req-1');
            testCase.verifyEqual(msg.name, 'recalc');
            testCase.verifyEqual(msg.args.x, 1);
        end
        function testDecodeBridgeReady(testCase)
            raw = '{"type":"bridge_ready","httpPort":8080}';
            msg = WebBridgeProtocol.decode(raw);
            testCase.verifyEqual(msg.type, 'bridge_ready');
            testCase.verifyEqual(msg.httpPort, 8080);
        end
    end
end
