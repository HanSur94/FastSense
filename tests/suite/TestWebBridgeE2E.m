classdef TestWebBridgeE2E < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end
    methods (Test)
        function testServeAndFetchData(testCase)
            [status, ~] = system('python -c "import fastsense_bridge"');
            testCase.assumeTrue(status == 0, 'fastsense-bridge Python package not installed');
            x = linspace(0, 100, 10000);
            y = sin(x);
            engine = DashboardEngine('E2E Test');
            engine.addWidget('fastsense', 'Title', 'Sine Wave', 'XData', x, 'YData', y, 'Position', [1 1 6 3]);
            bridge = WebBridge(engine);
            testCase.addTeardown(@() bridge.stop());
            bridge.serve();
            testCase.verifyGreaterThan(bridge.HttpPort, 0);
            url = sprintf('http://localhost:%d/api/signals', bridge.HttpPort);
            signals = webread(url);
            testCase.verifyGreaterThan(numel(signals), 0);
            sigId = signals(1).id;
            dataUrl = sprintf('http://localhost:%d/api/signals/%s/data?xMin=0&xMax=100&maxPoints=100', bridge.HttpPort, sigId);
            data = webread(dataUrl);
            testCase.verifyTrue(isfield(data, 'x'));
            testCase.verifyTrue(isfield(data, 'y'));
            testCase.verifyGreaterThan(numel(data.x), 0);
        end
    end
end
