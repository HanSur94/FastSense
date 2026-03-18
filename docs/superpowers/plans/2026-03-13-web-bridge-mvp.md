# WebBridge MVP Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a live data bridge from MATLAB dashboards to a web browser, using TCP + SQLite for MATLAB→Python communication and REST/WebSocket for Python→browser.

**Architecture:** MATLAB `WebBridge` class runs a `tcpserver` sending NDJSON messages. Python FastAPI bridge reads SQLite directly for bulk data, proxies control messages via TCP. Vanilla JS frontend with uPlot charts renders the dashboard in the browser.

**Tech Stack:** MATLAB (tcpserver, mksqlite), Python 3.11+ (FastAPI, uvicorn, websockets, aiosqlite), vanilla JS (uPlot for charts)

**Spec:** `docs/superpowers/specs/2026-03-13-web-bridge-design.md`

**Out of scope (separate plan):** Node.js bridge server

---

## File Structure

### MATLAB (new files)

| File | Responsibility |
|------|---------------|
| `libs/WebBridge/WebBridge.m` | Main class: TCP server, action registry, bridge launcher, config poll |
| `libs/WebBridge/WebBridgeProtocol.m` | NDJSON encode/decode, message builders |
| `tests/suite/TestWebBridgeProtocol.m` | Unit tests for protocol encoding |
| `tests/suite/TestWebBridge.m` | Unit tests for WebBridge (TCP, actions) |

### MATLAB (modified files)

| File | Change |
|------|--------|
| `libs/FastSense/FastSenseDataStore.m` | Add `enableWAL()` / `disableWAL()` methods |
| `setup.m` | Add `libs/WebBridge` to MATLAB path |
| `tests/suite/TestDataStoreWAL.m` | Tests for WAL methods |

### Python bridge

| File | Responsibility |
|------|---------------|
| `bridge/python/pyproject.toml` | Package config, dependencies |
| `bridge/python/fastsense_bridge/__init__.py` | Package init |
| `bridge/python/fastsense_bridge/__main__.py` | CLI entry point |
| `bridge/python/fastsense_bridge/blob_decoder.py` | mksqlite typed BLOB header parser |
| `bridge/python/fastsense_bridge/sqlite_reader.py` | SQLite queries + BLOB decoding + downsampling |
| `bridge/python/fastsense_bridge/tcp_client.py` | Async NDJSON-over-TCP client to MATLAB |
| `bridge/python/fastsense_bridge/server.py` | FastAPI app: REST API + WebSocket + static files |
| `bridge/python/tests/test_blob_decoder.py` | Unit tests for BLOB parser |
| `bridge/python/tests/test_sqlite_reader.py` | Unit tests for SQLite reader |
| `bridge/python/tests/test_tcp_client.py` | Unit tests for TCP client |
| `bridge/python/tests/test_server.py` | API integration tests |

### Web frontend

| File | Responsibility |
|------|---------------|
| `bridge/web/index.html` | Main page, loads JS/CSS |
| `bridge/web/css/style.css` | Dashboard grid, widget styles, dark/light theme |
| `bridge/web/js/app.js` | Entry point, WebSocket connection, routing |
| `bridge/web/js/chart.js` | uPlot wrapper with zoom/pan → API fetch |
| `bridge/web/js/dashboard.js` | CSS grid layout renderer from config |
| `bridge/web/js/widgets.js` | Widget type renderers (KPI, gauge, table, etc.) |
| `bridge/web/js/actions.js` | Action panel with buttons and argument forms |
| `bridge/web/vendor/uPlot.min.js` | uPlot library (vendored) |
| `bridge/web/vendor/uPlot.min.css` | uPlot styles |

---

## Chunk 1: MATLAB Foundation (DataStore WAL + Protocol + WebBridge)

### Task 0: Add WebBridge to MATLAB Path

**Files:**
- Modify: `setup.m`

- [ ] **Step 1: Add WebBridge path to setup.m**

Find the existing `addpath` calls in `setup.m` and add:

```matlab
addpath(fullfile(rootDir, 'libs', 'WebBridge'));
```

- [ ] **Step 2: Create the WebBridge directory**

```bash
mkdir -p libs/WebBridge
```

- [ ] **Step 3: Commit**

```bash
git add setup.m libs/WebBridge
git commit -m "chore: add WebBridge to MATLAB path in setup.m"
```

---

### Task 1: Add WAL Methods to FastSenseDataStore

**Files:**
- Modify: `libs/FastSense/FastSenseDataStore.m`
- Test: `tests/suite/TestDataStoreWAL.m`

- [ ] **Step 1: Write the failing test**

Create `tests/suite/TestDataStoreWAL.m`:

```matlab
classdef TestDataStoreWAL < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testEnableWAL(testCase)
            % Create a DataStore with some data
            x = 1:1000;
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() delete(ds));

            % Enable WAL mode
            ds.enableWAL();

            % Verify WAL mode is active by querying pragma
            ds.ensureOpen();
            result = mksqlite(ds.DbId, 'PRAGMA journal_mode');
            testCase.verifyEqual(lower(result.journal_mode), 'wal');
        end

        function testDisableWAL(testCase)
            x = 1:1000;
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() delete(ds));

            ds.enableWAL();
            ds.disableWAL();

            ds.ensureOpen();
            result = mksqlite(ds.DbId, 'PRAGMA journal_mode');
            testCase.verifyEqual(lower(result.journal_mode), 'delete');
        end

        function testDataAccessAfterWAL(testCase)
            x = 1:1000;
            y = sin(x);
            ds = FastSenseDataStore(x, y);
            testCase.addTeardown(@() delete(ds));

            ds.enableWAL();

            % Verify data is still readable
            [xOut, yOut] = ds.getRange(1, 1000);
            testCase.verifyGreaterThan(numel(xOut), 0);
            testCase.verifyGreaterThan(numel(yOut), 0);
        end
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "run_all_tests('TestDataStoreWAL')"`
Expected: FAIL — `enableWAL` method not found

- [ ] **Step 3: Implement enableWAL and disableWAL**

Add to `libs/FastSense/FastSenseDataStore.m` in the public methods block:

```matlab
function enableWAL(obj)
    %ENABLEWAL Switch database to WAL journal mode for concurrent reads.
    if ~obj.UseSqlite; return; end
    obj.ensureOpen();
    mksqlite(obj.DbId, 'PRAGMA journal_mode = WAL');
    mksqlite(obj.DbId, 'PRAGMA locking_mode = NORMAL');
end

function disableWAL(obj)
    %DISABLEWAL Revert database to DELETE journal mode.
    if ~obj.UseSqlite; return; end
    obj.ensureOpen();
    mksqlite(obj.DbId, 'PRAGMA journal_mode = DELETE');
    mksqlite(obj.DbId, 'PRAGMA locking_mode = EXCLUSIVE');
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "run_all_tests('TestDataStoreWAL')"`
Expected: PASS (3/3 tests)

- [ ] **Step 5: Commit**

```bash
git add libs/FastSense/FastSenseDataStore.m tests/suite/TestDataStoreWAL.m
git commit -m "feat: add enableWAL/disableWAL to FastSenseDataStore for concurrent reads"
```

---

### Task 2: WebBridgeProtocol — NDJSON Message Encoding

**Files:**
- Create: `libs/WebBridge/WebBridgeProtocol.m`
- Test: `tests/suite/TestWebBridgeProtocol.m`

- [ ] **Step 1: Write the failing test**

Create `tests/suite/TestWebBridgeProtocol.m`:

```matlab
classdef TestWebBridgeProtocol < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testEncodeInit(testCase)
            signals = struct('id', {'s1', 's2'}, ...
                             'dbPath', {'/tmp/a.fpdb', '/tmp/b.fpdb'}, ...
                             'title', {'Temp', 'Pressure'});
            dashboard = struct('name', 'Test', 'theme', 'light');
            actions = {'recalc', 'setRange'};

            msg = WebBridgeProtocol.encodeInit(signals, dashboard, actions);
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "run_all_tests('TestWebBridgeProtocol')"`
Expected: FAIL — WebBridgeProtocol not found

- [ ] **Step 3: Create libs/WebBridge directory and implement WebBridgeProtocol**

```bash
mkdir -p libs/WebBridge
```

Create `libs/WebBridge/WebBridgeProtocol.m`:

```matlab
classdef WebBridgeProtocol
    %WEBBRIDGEPROTOCOL NDJSON message encoding/decoding for WebBridge TCP protocol.

    methods (Static)
        function msg = encodeInit(signals, dashboard, actions)
            %ENCODEINIT Build the init message sent when bridge connects.
            s = struct('type', 'init', ...
                       'signals', {signals}, ...
                       'dashboard', dashboard, ...
                       'actions', {actions});
            msg = [jsonencode(s), newline];
        end

        function msg = encodeDataChanged(signalIds)
            %ENCODEDATACHANGED Notify bridge that signal data has changed.
            s = struct('type', 'data_changed', 'signals', {signalIds});
            msg = [jsonencode(s), newline];
        end

        function msg = encodeConfigChanged(dashboard)
            %ENCODECONFIGCHANGED Notify bridge that dashboard config has changed.
            s = struct('type', 'config_changed', 'dashboard', dashboard);
            msg = [jsonencode(s), newline];
        end

        function msg = encodeActionResult(requestId, name, ok, errorMsg)
            %ENCODEACTIONRESULT Response to an action invocation.
            s = struct('type', 'action_result', 'id', requestId, 'name', name, 'ok', ok);
            if ~ok && ~isempty(errorMsg)
                s.error = errorMsg;
            end
            msg = [jsonencode(s), newline];
        end

        function msg = encodeShutdown()
            %ENCODESHUTDOWN Notify bridge of MATLAB shutdown.
            msg = [jsonencode(struct('type', 'shutdown')), newline];
        end

        function msg = encodeBridgeReady(httpPort)
            %ENCODEBRIDGEREADY Used by bridge to tell MATLAB it's ready.
            s = struct('type', 'bridge_ready', 'httpPort', httpPort);
            msg = [jsonencode(s), newline];
        end

        function msg = decode(raw)
            %DECODE Parse a JSON string into a struct.
            msg = jsondecode(strtrim(raw));
        end
    end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "run_all_tests('TestWebBridgeProtocol')"`
Expected: PASS (7/7 tests)

- [ ] **Step 5: Commit**

```bash
git add libs/WebBridge/WebBridgeProtocol.m tests/suite/TestWebBridgeProtocol.m
git commit -m "feat: add WebBridgeProtocol for NDJSON message encoding/decoding"
```

---

### Task 3: WebBridge Core — TCP Server, Init, Shutdown

**Files:**
- Create: `libs/WebBridge/WebBridge.m`
- Test: `tests/suite/TestWebBridge.m`

**Dependencies:** Task 1 (DataStore WAL), Task 2 (Protocol)

- [ ] **Step 1: Write the failing test**

Create `tests/suite/TestWebBridge.m`:

```matlab
classdef TestWebBridge < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
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

            % Connect a test client via tcpclient
            client = tcpclient('localhost', bridge.TcpPort, 'Timeout', 5);
            testCase.addTeardown(@() delete(client));
            pause(0.5);

            % Read init message (NDJSON line)
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
            % Consume init message
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

            % Connect and consume init
            client = tcpclient('localhost', bridge.TcpPort, 'Timeout', 5);
            testCase.addTeardown(@() delete(client));
            pause(0.3);
            readline(client);

            % Send action request
            actionMsg = jsonencode(struct('type', 'action', 'id', 'req-1', ...
                'name', 'add', 'args', struct('a', 2, 'b', 3)));
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "run_all_tests('TestWebBridge')"`
Expected: FAIL — WebBridge not found

- [ ] **Step 3: Implement WebBridge.m**

Create `libs/WebBridge/WebBridge.m`:

```matlab
classdef WebBridge < handle
    %WEBBRIDGE Bidirectional TCP bridge between MATLAB dashboards and web frontends.
    %
    %   bridge = WebBridge(dashboardEngine);
    %   bridge.registerAction('recalc', @() sensor.resolve());
    %   bridge.serve();   % starts TCP + launches Python bridge
    %   bridge.stop();    % clean shutdown

    properties (Access = public)
        Dashboard
        ConfigPollInterval = 1  % seconds
    end

    properties (SetAccess = private)
        TcpPort      = 0
        HttpPort     = 0
        IsServing    = false
    end

    properties (Access = private)
        TcpServer    = []
        ClientConnected = false
        Actions      = struct()  % name → function_handle map
        ConfigTimer  = []
        LastConfigHash = ''
        BridgeProcess = []
    end

    methods (Access = public)
        function obj = WebBridge(dashboard, varargin)
            obj.Dashboard = dashboard;
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function serve(obj)
            %SERVE Start TCP server and launch bridge process.
            obj.enableWALOnDataStores();
            obj.startTcp();
            obj.launchBridge();
            obj.startConfigPoll();
        end

        function startTcp(obj)
            %STARTTCP Start the TCP server (can be used without launching bridge).
            if obj.IsServing; return; end
            obj.TcpServer = tcpserver('localhost', 0, ...
                'ConnectionChangedFcn', @(src, evt) obj.onConnectionChanged(src, evt));
            obj.TcpPort = obj.TcpServer.ServerPort;
            obj.IsServing = true;
        end

        function stop(obj)
            %STOP Clean shutdown: notify bridge, stop TCP, revert WAL.
            if ~obj.IsServing; return; end
            obj.sendToClient(WebBridgeProtocol.encodeShutdown());
            obj.stopConfigPoll();
            pause(0.1);
            delete(obj.TcpServer);
            obj.TcpServer = [];
            obj.IsServing = false;
            obj.disableWALOnDataStores();
        end

        function registerAction(obj, name, callback)
            %REGISTERACTION Register a named action callable from the web frontend.
            obj.Actions.(name) = callback;
            if obj.IsServing
                obj.sendConfigChanged();
            end
        end

        function tf = hasAction(obj, name)
            tf = isfield(obj.Actions, name);
        end

        function notifyDataChanged(obj, signalId)
            %NOTIFYDATACHANGED Push data_changed event to connected bridges.
            if ~obj.IsServing; return; end
            if iscell(signalId)
                msg = WebBridgeProtocol.encodeDataChanged(signalId);
            else
                msg = WebBridgeProtocol.encodeDataChanged({signalId});
            end
            obj.sendToClient(msg);
        end

        function delete(obj)
            if obj.IsServing
                obj.stop();
            end
        end
    end

    methods (Access = private)
        function onConnectionChanged(obj, src, ~)
            % src is the tcpserver object itself. tcpserver supports
            % one client at a time; read/write through the server object.
            if src.Connected
                obj.ClientConnected = true;
                obj.sendInit();
                configureCallback(obj.TcpServer, 'terminator', ...
                    @(s,~) obj.onDataReceived(s));
            else
                obj.ClientConnected = false;
                configureCallback(obj.TcpServer, 'terminator', 'off');
                if obj.IsServing
                    warning('WebBridge:disconnected', ...
                        'Bridge disconnected. Call bridge.serve() to restart.');
                end
            end
        end

        function onDataReceived(obj, server)
            try
                data = readline(server);
                if isempty(data); return; end
                msg = WebBridgeProtocol.decode(data);
                obj.handleMessage(msg);
            catch ex
                warning('WebBridge:receiveError', 'Error reading TCP: %s', ex.message);
            end
        end

        function handleMessage(obj, msg)
            switch msg.type
                case 'action'
                    obj.executeAction(msg);
                case 'bridge_ready'
                    obj.HttpPort = msg.httpPort;
                    fprintf('Dashboard served at http://localhost:%d\n', obj.HttpPort);
            end
        end

        function executeAction(obj, msg)
            name = msg.name;
            requestId = msg.id;
            if ~isfield(obj.Actions, name)
                resp = WebBridgeProtocol.encodeActionResult(requestId, name, false, ...
                    sprintf('Unknown action: %s', name));
                writeline(obj.TcpServer, strtrim(resp));
                return;
            end
            try
                callback = obj.Actions.(name);
                if isfield(msg, 'args') && ~isempty(fieldnames(msg.args))
                    callback(msg.args);
                else
                    callback();
                end
                resp = WebBridgeProtocol.encodeActionResult(requestId, name, true, '');
            catch ex
                resp = WebBridgeProtocol.encodeActionResult(requestId, name, false, ex.message);
            end
            writeline(obj.TcpServer, strtrim(resp));
        end

        function sendInit(obj)
            signals = obj.buildSignalList();
            dashConfig = obj.buildDashboardConfig();
            actionNames = fieldnames(obj.Actions);
            if isempty(actionNames); actionNames = {}; end
            msg = WebBridgeProtocol.encodeInit(signals, dashConfig, actionNames);
            writeline(obj.TcpServer, strtrim(msg));
        end

        function signals = buildSignalList(obj)
            signals = struct('id', {}, 'dbPath', {}, 'title', {});
            if isempty(obj.Dashboard) || isempty(obj.Dashboard.Widgets)
                return;
            end
            idx = 0;
            for i = 1:numel(obj.Dashboard.Widgets)
                w = obj.Dashboard.Widgets{i};
                if ~isa(w, 'FastSenseWidget'); continue; end
                idx = idx + 1;
                if isprop(w, 'Sensor') && ~isempty(w.Sensor) && isprop(w.Sensor, 'Key')
                    sid = w.Sensor.Key;
                else
                    sid = sprintf('ds_%d', idx);
                end
                dbPath = '';
                if isprop(w, 'DataStore') && ~isempty(w.DataStore) && isprop(w.DataStore, 'DbPath')
                    dbPath = w.DataStore.DbPath;
                elseif isprop(w, 'Sensor') && ~isempty(w.Sensor) ...
                        && isprop(w.Sensor, 'DataStore') && ~isempty(w.Sensor.DataStore)
                    dbPath = w.Sensor.DataStore.DbPath;
                end
                signals(end+1) = struct('id', sid, 'dbPath', dbPath, 'title', w.Title); %#ok<AGROW>
            end
        end

        function config = buildDashboardConfig(obj)
            if isempty(obj.Dashboard)
                config = struct('name', '', 'theme', 'light', 'widgets', {{}});
                return;
            end
            config = DashboardSerializer.widgetsToConfig(...
                obj.Dashboard.Name, obj.Dashboard.Theme, ...
                obj.Dashboard.LiveInterval, obj.Dashboard.Widgets);
        end

        function sendToClient(obj, msg)
            %SENDTOCLIENT Send NDJSON message to the connected bridge client.
            if ~obj.ClientConnected || isempty(obj.TcpServer); return; end
            try
                writeline(obj.TcpServer, strtrim(msg));
            catch
                obj.ClientConnected = false;
            end
        end

        function sendConfigChanged(obj)
            config = obj.buildDashboardConfig();
            msg = WebBridgeProtocol.encodeConfigChanged(config);
            obj.sendToClient(msg);
        end

        function startConfigPoll(obj)
            obj.LastConfigHash = obj.computeConfigHash();
            obj.ConfigTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', obj.ConfigPollInterval, ...
                'TimerFcn', @(~,~) obj.checkConfigChanged());
            start(obj.ConfigTimer);
        end

        function stopConfigPoll(obj)
            if ~isempty(obj.ConfigTimer)
                stop(obj.ConfigTimer);
                delete(obj.ConfigTimer);
                obj.ConfigTimer = [];
            end
        end

        function checkConfigChanged(obj)
            h = obj.computeConfigHash();
            if ~strcmp(h, obj.LastConfigHash)
                obj.LastConfigHash = h;
                obj.sendConfigChanged();
            end
        end

        function h = computeConfigHash(obj)
            config = obj.buildDashboardConfig();
            json = jsonencode(config);
            % Simple hash: use Java if available, else use length+checksum
            try
                md = java.security.MessageDigest.getInstance('MD5');
                md.update(uint8(json));
                h = sprintf('%02x', typecast(md.digest(), 'uint8'));
            catch
                h = sprintf('%d_%d', length(json), sum(uint8(json)));
            end
        end

        function launchBridge(obj)
            % Find the bridge script relative to this file
            bridgeDir = fullfile(fileparts(mfilename('fullpath')), ...
                '..', '..', 'bridge', 'python');
            cmd = sprintf('python -m fastsense_bridge --matlab-port %d', obj.TcpPort);
            if ispc
                fullCmd = sprintf('start /B %s', cmd);
            else
                fullCmd = sprintf('cd "%s" && %s &', bridgeDir, cmd);
            end
            system(fullCmd);

            % Wait for bridge_ready with timeout
            t0 = tic;
            while toc(t0) < 10
                drawnow;
                if obj.HttpPort > 0
                    return;
                end
                pause(0.1);
            end
            obj.stop();
            error('WebBridge:timeout', ...
                'Bridge did not start within 10s. Check that fastsense-bridge is installed.');
        end

        function enableWALOnDataStores(obj)
            stores = obj.collectDataStores();
            for i = 1:numel(stores)
                stores{i}.enableWAL();
            end
        end

        function disableWALOnDataStores(obj)
            stores = obj.collectDataStores();
            for i = 1:numel(stores)
                stores{i}.disableWAL();
            end
        end

        function stores = collectDataStores(obj)
            stores = {};
            if isempty(obj.Dashboard) || isempty(obj.Dashboard.Widgets)
                return;
            end
            for i = 1:numel(obj.Dashboard.Widgets)
                w = obj.Dashboard.Widgets{i};
                if ~isa(w, 'FastSenseWidget'); continue; end
                ds = [];
                if isprop(w, 'DataStore') && ~isempty(w.DataStore)
                    ds = w.DataStore;
                elseif isprop(w, 'Sensor') && ~isempty(w.Sensor) ...
                        && isprop(w.Sensor, 'DataStore') && ~isempty(w.Sensor.DataStore)
                    ds = w.Sensor.DataStore;
                end
                if ~isempty(ds)
                    stores{end+1} = ds; %#ok<AGROW>
                end
            end
        end
    end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "run_all_tests('TestWebBridge')"`
Expected: PASS (7/7 tests)

- [ ] **Step 5: Commit**

```bash
git add libs/WebBridge/WebBridge.m tests/suite/TestWebBridge.m
git commit -m "feat: add WebBridge class with TCP server, action registry, and lifecycle"
```

---

## Chunk 2: Python Bridge Server

### Task 4: Python Project Setup + BLOB Decoder

**Files:**
- Create: `bridge/python/pyproject.toml`
- Create: `bridge/python/fastsense_bridge/__init__.py`
- Create: `bridge/python/fastsense_bridge/blob_decoder.py`
- Test: `bridge/python/tests/test_blob_decoder.py`

- [ ] **Step 1: Create project structure**

```bash
mkdir -p bridge/python/fastsense_bridge bridge/python/tests
```

Create `bridge/python/pyproject.toml`:

```toml
[project]
name = "fastsense-bridge"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi>=0.104",
    "uvicorn[standard]>=0.24",
    "websockets>=12.0",
    "aiosqlite>=0.19",
    "numpy>=1.24",
]

[project.optional-dependencies]
dev = ["pytest>=7.0", "pytest-asyncio>=0.21", "httpx>=0.25"]

[project.scripts]
fastsense-bridge = "fastsense_bridge.__main__:main"

[tool.pytest.ini_options]
asyncio_mode = "auto"
```

Create `bridge/python/fastsense_bridge/__init__.py`:

```python
"""FastSense Bridge — serves MATLAB dashboard data via REST/WebSocket."""
```

- [ ] **Step 2: Write the failing test for blob_decoder**

Create `bridge/python/tests/test_blob_decoder.py`:

```python
import struct
import numpy as np
import pytest
from fastsense_bridge.blob_decoder import decode_typed_blob, MKSQ_MAGIC

MX_DOUBLE = 6
MX_SINGLE = 7
MX_INT32 = 12
TAG_CHAR = 100
TAG_LOGICAL = 101


def _make_blob(class_id: int, rows: int, cols: int, data: bytes) -> bytes:
    header = struct.pack("<6I", MKSQ_MAGIC, 3, class_id, 2, rows, cols)
    return header + data


class TestBlobDecoder:
    def test_decode_double_array(self):
        values = np.array([1.0, 2.0, 3.0], dtype=np.float64)
        blob = _make_blob(MX_DOUBLE, 1, 3, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_decode_single_array(self):
        values = np.array([1.5, 2.5], dtype=np.float32)
        blob = _make_blob(MX_SINGLE, 1, 2, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_decode_int32_array(self):
        values = np.array([10, 20, 30], dtype=np.int32)
        blob = _make_blob(MX_INT32, 1, 3, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, values)

    def test_decode_char(self):
        text = b"hello"
        blob = _make_blob(TAG_CHAR, 1, 5, text)
        result = decode_typed_blob(blob)
        assert result == "hello"

    def test_decode_logical(self):
        data = bytes([1, 0, 1])
        blob = _make_blob(TAG_LOGICAL, 1, 3, data)
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result, np.array([True, False, True]))

    def test_invalid_magic_raises(self):
        blob = struct.pack("<6I", 0xDEADBEEF, 3, MX_DOUBLE, 2, 1, 1) + b"\x00" * 8
        with pytest.raises(ValueError, match="magic"):
            decode_typed_blob(blob)

    def test_truncated_blob_raises(self):
        blob = struct.pack("<6I", MKSQ_MAGIC, 3, MX_DOUBLE, 2, 1, 3)  # expects 24 bytes of data
        with pytest.raises(ValueError, match="truncated"):
            decode_typed_blob(blob)

    def test_2d_matrix(self):
        values = np.array([[1.0, 2.0], [3.0, 4.0]], dtype=np.float64, order="F")
        blob = _make_blob(MX_DOUBLE, 2, 2, values.tobytes())
        result = decode_typed_blob(blob)
        np.testing.assert_array_equal(result.reshape(2, 2, order="F"), values)
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense/bridge/python && pip install -e ".[dev]" && pytest tests/test_blob_decoder.py -v`
Expected: FAIL — module not found

- [ ] **Step 4: Implement blob_decoder.py**

Create `bridge/python/fastsense_bridge/blob_decoder.py`:

```python
"""Decoder for mksqlite typed BLOB format (24-byte header + raw data)."""

import struct
import numpy as np

MKSQ_MAGIC = 0x4D4B5351
HEADER_SIZE = 24
HEADER_FMT = "<6I"  # magic, version, class_id, ndims, rows, cols

# mxClassID → numpy dtype
_NUMERIC_DTYPES: dict[int, np.dtype] = {
    6: np.dtype("float64"),   # mxDOUBLE_CLASS
    7: np.dtype("float32"),   # mxSINGLE_CLASS
    8: np.dtype("int8"),      # mxINT8_CLASS
    9: np.dtype("uint8"),     # mxUINT8_CLASS
    10: np.dtype("int16"),    # mxINT16_CLASS
    11: np.dtype("uint16"),   # mxUINT16_CLASS
    12: np.dtype("int32"),    # mxINT32_CLASS
    13: np.dtype("uint32"),   # mxUINT32_CLASS
    14: np.dtype("int64"),    # mxINT64_CLASS
    15: np.dtype("uint64"),   # mxUINT64_CLASS
}

TAG_CHAR = 100
TAG_LOGICAL = 101
TAG_CELL = 102
TAG_CATEGORICAL = 103


def decode_typed_blob(data: bytes | memoryview) -> np.ndarray | str | list:
    """Decode a mksqlite typed BLOB into a numpy array, string, or list."""
    if len(data) < HEADER_SIZE:
        raise ValueError(f"Blob too short ({len(data)} bytes), need at least {HEADER_SIZE}")

    magic, version, class_id, ndims, rows, cols = struct.unpack_from(HEADER_FMT, data)

    if magic != MKSQ_MAGIC:
        raise ValueError(f"Invalid magic: 0x{magic:08X}, expected 0x{MKSQ_MAGIC:08X}")

    numel = rows * cols
    payload = data[HEADER_SIZE:]

    # Numeric types
    if class_id in _NUMERIC_DTYPES:
        dtype = _NUMERIC_DTYPES[class_id]
        expected = numel * dtype.itemsize
        if len(payload) < expected:
            raise ValueError(f"Blob truncated: need {expected} bytes, got {len(payload)}")
        return np.frombuffer(payload[:expected], dtype=dtype).copy()

    # Char
    if class_id == TAG_CHAR:
        if len(payload) < numel:
            raise ValueError(f"Blob truncated: need {numel} bytes for char, got {len(payload)}")
        return payload[:numel].decode("latin-1")

    # Logical
    if class_id == TAG_LOGICAL:
        if len(payload) < numel:
            raise ValueError(f"Blob truncated: need {numel} bytes for logical, got {len(payload)}")
        return np.array([b != 0 for b in payload[:numel]], dtype=bool)

    raise ValueError(f"Unsupported class_id: {class_id}")
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense/bridge/python && pytest tests/test_blob_decoder.py -v`
Expected: PASS (8/8 tests)

- [ ] **Step 6: Commit**

```bash
git add bridge/python/
git commit -m "feat: add Python bridge project setup and mksqlite BLOB decoder"
```

---

### Task 5: Python SQLite Reader

**Files:**
- Create: `bridge/python/fastsense_bridge/sqlite_reader.py`
- Test: `bridge/python/tests/test_sqlite_reader.py`

**Dependencies:** Task 4 (blob_decoder)

- [ ] **Step 1: Write the failing test**

Create `bridge/python/tests/test_sqlite_reader.py`:

```python
import struct
import sqlite3
import tempfile
import numpy as np
import pytest
from pathlib import Path
from fastsense_bridge.blob_decoder import MKSQ_MAGIC
from fastsense_bridge.sqlite_reader import SqliteReader


def _make_double_blob(values: list[float]) -> bytes:
    arr = np.array(values, dtype=np.float64)
    header = struct.pack("<6I", MKSQ_MAGIC, 3, 6, 2, 1, len(values))
    return header + arr.tobytes()


@pytest.fixture
def sample_db(tmp_path) -> Path:
    """Create a minimal .fpdb file matching FastSenseDataStore schema."""
    db_path = tmp_path / "test.fpdb"
    conn = sqlite3.connect(str(db_path))

    conn.execute("""CREATE TABLE chunks (
        chunk_id INTEGER PRIMARY KEY,
        x_min REAL NOT NULL, x_max REAL NOT NULL,
        y_min REAL NOT NULL, y_max REAL NOT NULL,
        pt_offset INTEGER NOT NULL, pt_count INTEGER NOT NULL,
        x_data BLOB NOT NULL, y_data BLOB NOT NULL
    )""")
    conn.execute("CREATE INDEX idx_xrange ON chunks (x_min, x_max)")

    # Insert 3 chunks: [0-10], [10-20], [20-30]
    for i in range(3):
        x_vals = list(np.linspace(i * 10, (i + 1) * 10, 100))
        y_vals = list(np.sin(x_vals))
        conn.execute(
            "INSERT INTO chunks VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (i, x_vals[0], x_vals[-1], min(y_vals), max(y_vals),
             i * 100, 100, _make_double_blob(x_vals), _make_double_blob(y_vals)),
        )

    # Add thresholds table
    conn.execute("""CREATE TABLE resolved_thresholds (
        idx INTEGER PRIMARY KEY, x_data BLOB, y_data BLOB,
        direction TEXT NOT NULL, label TEXT NOT NULL,
        color BLOB, line_style TEXT NOT NULL, value REAL NOT NULL
    )""")
    conn.execute(
        "INSERT INTO resolved_thresholds VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (0, _make_double_blob([0.0, 30.0]), _make_double_blob([0.5, 0.5]),
         'upper', 'limit', None, '-', 0.5),
    )

    # Add violations table
    conn.execute("""CREATE TABLE resolved_violations (
        idx INTEGER PRIMARY KEY, x_data BLOB, y_data BLOB,
        direction TEXT NOT NULL, label TEXT NOT NULL
    )""")

    conn.commit()
    conn.close()
    return db_path


class TestSqliteReader:
    def test_get_range_full(self, sample_db):
        reader = SqliteReader(str(sample_db))
        x, y = reader.get_range(0, 30)
        assert len(x) == 300
        assert len(y) == 300
        assert x[0] == pytest.approx(0.0)
        assert x[-1] == pytest.approx(30.0)
        reader.close()

    def test_get_range_subset(self, sample_db):
        reader = SqliteReader(str(sample_db))
        x, y = reader.get_range(5, 15)
        assert len(x) > 0
        assert all(xi >= 0 and xi <= 20 for xi in x)  # includes neighboring chunks
        reader.close()

    def test_get_range_with_max_points(self, sample_db):
        reader = SqliteReader(str(sample_db))
        x, y = reader.get_range(0, 30, max_points=20)
        assert len(x) <= 20
        assert len(y) <= 20
        reader.close()

    def test_get_thresholds(self, sample_db):
        reader = SqliteReader(str(sample_db))
        thresholds = reader.get_thresholds()
        assert len(thresholds) == 1
        assert thresholds[0]["label"] == "limit"
        assert thresholds[0]["direction"] == "upper"
        assert len(thresholds[0]["x"]) == 2
        reader.close()

    def test_get_violations(self, sample_db):
        reader = SqliteReader(str(sample_db))
        violations = reader.get_violations()
        assert isinstance(violations, list)
        reader.close()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense/bridge/python && pytest tests/test_sqlite_reader.py -v`
Expected: FAIL — SqliteReader not found

- [ ] **Step 3: Implement sqlite_reader.py**

Create `bridge/python/fastsense_bridge/sqlite_reader.py`:

```python
"""Read FastSenseDataStore SQLite files and decode typed BLOBs."""

import sqlite3
import numpy as np
from .blob_decoder import decode_typed_blob


class SqliteReader:
    """Synchronous reader for .fpdb files created by FastSenseDataStore."""

    def __init__(self, db_path: str):
        self._conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        self._conn.row_factory = sqlite3.Row

    def close(self):
        self._conn.close()

    def get_range(
        self, x_min: float, x_max: float, max_points: int = 0
    ) -> tuple[list[float], list[float]]:
        """Fetch X/Y data for chunks overlapping [x_min, x_max]."""
        rows = self._conn.execute(
            "SELECT x_data, y_data FROM chunks "
            "WHERE x_max >= ? AND x_min <= ? ORDER BY x_min",
            (x_min, x_max),
        ).fetchall()

        if not rows:
            return [], []

        x_parts: list[np.ndarray] = []
        y_parts: list[np.ndarray] = []
        for row in rows:
            x_parts.append(decode_typed_blob(row["x_data"]))
            y_parts.append(decode_typed_blob(row["y_data"]))

        x = np.concatenate(x_parts)
        y = np.concatenate(y_parts)

        if max_points > 0 and len(x) > max_points:
            x, y = _minmax_downsample(x, y, max_points)

        return x.tolist(), y.tolist()

    def get_thresholds(self) -> list[dict]:
        """Fetch resolved thresholds."""
        try:
            rows = self._conn.execute(
                "SELECT * FROM resolved_thresholds ORDER BY idx"
            ).fetchall()
        except sqlite3.OperationalError:
            return []

        result = []
        for row in rows:
            entry: dict = {
                "direction": row["direction"],
                "label": row["label"],
                "lineStyle": row["line_style"],
                "value": row["value"],
                "x": [],
                "y": [],
            }
            if row["x_data"]:
                entry["x"] = decode_typed_blob(row["x_data"]).tolist()
            if row["y_data"]:
                entry["y"] = decode_typed_blob(row["y_data"]).tolist()
            if row["color"]:
                entry["color"] = decode_typed_blob(row["color"]).tolist()
            result.append(entry)
        return result

    def get_violations(self) -> list[dict]:
        """Fetch resolved violations."""
        try:
            rows = self._conn.execute(
                "SELECT * FROM resolved_violations ORDER BY idx"
            ).fetchall()
        except sqlite3.OperationalError:
            return []

        result = []
        for row in rows:
            entry: dict = {
                "direction": row["direction"],
                "label": row["label"],
                "x": [],
                "y": [],
            }
            if row["x_data"]:
                entry["x"] = decode_typed_blob(row["x_data"]).tolist()
            if row["y_data"]:
                entry["y"] = decode_typed_blob(row["y_data"]).tolist()
            result.append(entry)
        return result

    def get_column(
        self, col_name: str, x_min: float, x_max: float
    ) -> list:
        """Fetch an extra column's data for a given X range."""
        # Map x range to pt_offset range via chunks table
        chunk_rows = self._conn.execute(
            "SELECT pt_offset, pt_count FROM chunks "
            "WHERE x_max >= ? AND x_min <= ? ORDER BY x_min",
            (x_min, x_max),
        ).fetchall()
        if not chunk_rows:
            return []

        offset_min = chunk_rows[0]["pt_offset"]
        last = chunk_rows[-1]
        offset_max = last["pt_offset"] + last["pt_count"]

        rows = self._conn.execute(
            "SELECT col_data FROM columns "
            "WHERE col_name = ? AND pt_offset >= ? AND pt_offset < ? "
            "ORDER BY pt_offset",
            (col_name, offset_min, offset_max),
        ).fetchall()

        parts = []
        for row in rows:
            decoded = decode_typed_blob(row["col_data"])
            if isinstance(decoded, np.ndarray):
                parts.extend(decoded.tolist())
            elif isinstance(decoded, str):
                parts.append(decoded)
            else:
                parts.extend(decoded)
        return parts


def _minmax_downsample(
    x: np.ndarray, y: np.ndarray, max_points: int
) -> tuple[np.ndarray, np.ndarray]:
    """Downsample by keeping min and max per bucket (preserves peaks)."""
    n = len(x)
    n_buckets = max_points // 2
    if n_buckets < 1:
        n_buckets = 1
    bucket_size = n / n_buckets

    x_out = []
    y_out = []
    for i in range(n_buckets):
        start = int(i * bucket_size)
        end = int((i + 1) * bucket_size)
        if start >= n:
            break
        end = min(end, n)
        segment_y = y[start:end]
        idx_min = start + np.argmin(segment_y)
        idx_max = start + np.argmax(segment_y)
        # Keep min before max to preserve visual shape
        if idx_min <= idx_max:
            x_out.extend([x[idx_min], x[idx_max]])
            y_out.extend([y[idx_min], y[idx_max]])
        else:
            x_out.extend([x[idx_max], x[idx_min]])
            y_out.extend([y[idx_max], y[idx_min]])

    return np.array(x_out), np.array(y_out)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense/bridge/python && pytest tests/test_sqlite_reader.py -v`
Expected: PASS (5/5 tests)

- [ ] **Step 5: Commit**

```bash
git add bridge/python/fastsense_bridge/sqlite_reader.py bridge/python/tests/test_sqlite_reader.py
git commit -m "feat: add SQLite reader with BLOB decoding and minmax downsampling"
```

---

### Task 6: Python TCP Client

**Files:**
- Create: `bridge/python/fastsense_bridge/tcp_client.py`
- Test: `bridge/python/tests/test_tcp_client.py`

- [ ] **Step 1: Write the failing test**

Create `bridge/python/tests/test_tcp_client.py`:

```python
import asyncio
import json
import pytest
import pytest_asyncio
from fastsense_bridge.tcp_client import MatlabTcpClient


@pytest_asyncio.fixture
async def mock_matlab_server():
    """A mock MATLAB TCP server that sends an init message on connect."""
    init_msg = json.dumps({
        "type": "init",
        "signals": [{"id": "s1", "dbPath": "/tmp/test.fpdb", "title": "Temp"}],
        "dashboard": {"name": "Test", "theme": "light", "widgets": []},
        "actions": ["recalc"],
    })

    received: list[str] = []

    async def handle_client(reader, writer):
        writer.write((init_msg + "\n").encode())
        await writer.drain()
        try:
            while True:
                line = await reader.readline()
                if not line:
                    break
                received.append(line.decode().strip())
        except asyncio.CancelledError:
            pass
        finally:
            writer.close()

    server = await asyncio.start_server(handle_client, "localhost", 0)
    port = server.sockets[0].getsockname()[1]
    yield server, port, received
    server.close()
    await server.wait_closed()


class TestMatlabTcpClient:
    @pytest.mark.asyncio
    async def test_connect_receives_init(self, mock_matlab_server):
        server, port, _ = mock_matlab_server
        client = MatlabTcpClient("localhost", port)

        init_msg = await client.connect()
        assert init_msg["type"] == "init"
        assert len(init_msg["signals"]) == 1
        assert init_msg["signals"][0]["id"] == "s1"
        await client.close()

    @pytest.mark.asyncio
    async def test_send_action(self, mock_matlab_server):
        server, port, received = mock_matlab_server
        client = MatlabTcpClient("localhost", port)
        await client.connect()

        await client.send_action("req-1", "recalc", {"x": 1})
        await asyncio.sleep(0.1)

        assert len(received) == 1
        msg = json.loads(received[0])
        assert msg["type"] == "action"
        assert msg["id"] == "req-1"
        assert msg["name"] == "recalc"
        await client.close()

    @pytest.mark.asyncio
    async def test_send_bridge_ready(self, mock_matlab_server):
        server, port, received = mock_matlab_server
        client = MatlabTcpClient("localhost", port)
        await client.connect()

        await client.send_bridge_ready(8080)
        await asyncio.sleep(0.1)

        msg = json.loads(received[0])
        assert msg["type"] == "bridge_ready"
        assert msg["httpPort"] == 8080
        await client.close()

    @pytest.mark.asyncio
    async def test_message_callback(self, mock_matlab_server):
        server, port, _ = mock_matlab_server
        client = MatlabTcpClient("localhost", port)
        await client.connect()

        messages: list[dict] = []
        client.on_message = lambda msg: messages.append(msg)

        # The server doesn't send more messages in this mock, so just verify callback is set
        assert client.on_message is not None
        await client.close()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense/bridge/python && pytest tests/test_tcp_client.py -v`
Expected: FAIL — MatlabTcpClient not found

- [ ] **Step 3: Implement tcp_client.py**

Create `bridge/python/fastsense_bridge/tcp_client.py`:

```python
"""Async NDJSON-over-TCP client for connecting to MATLAB's WebBridge."""

import asyncio
import json
from collections.abc import Callable
from typing import Any


class MatlabTcpClient:
    """Connects to MATLAB's tcpserver and exchanges NDJSON messages."""

    def __init__(self, host: str, port: int):
        self._host = host
        self._port = port
        self._reader: asyncio.StreamReader | None = None
        self._writer: asyncio.StreamWriter | None = None
        self._listen_task: asyncio.Task | None = None
        self.on_message: Callable[[dict], None] | None = None

    async def connect(self) -> dict:
        """Connect and return the init message."""
        self._reader, self._writer = await asyncio.open_connection(
            self._host, self._port
        )
        # First message from MATLAB is always the init
        line = await self._reader.readline()
        init_msg = json.loads(line.decode().strip())
        return init_msg

    def start_listening(self):
        """Start background task to receive messages from MATLAB."""
        self._listen_task = asyncio.create_task(self._listen_loop())

    async def _listen_loop(self):
        try:
            while self._reader and not self._reader.at_eof():
                line = await self._reader.readline()
                if not line:
                    break
                msg = json.loads(line.decode().strip())
                if self.on_message:
                    self.on_message(msg)
        except (asyncio.CancelledError, ConnectionError):
            pass

    async def send_action(self, request_id: str, name: str, args: dict[str, Any]):
        """Send an action invocation to MATLAB."""
        msg = {"type": "action", "id": request_id, "name": name, "args": args}
        await self._send(msg)

    async def send_bridge_ready(self, http_port: int):
        """Tell MATLAB the bridge HTTP server is ready."""
        await self._send({"type": "bridge_ready", "httpPort": http_port})

    async def _send(self, msg: dict):
        if self._writer is None:
            raise ConnectionError("Not connected")
        data = json.dumps(msg) + "\n"
        self._writer.write(data.encode())
        await self._writer.drain()

    async def close(self):
        if self._listen_task:
            self._listen_task.cancel()
            try:
                await self._listen_task
            except asyncio.CancelledError:
                pass
        if self._writer:
            self._writer.close()
            try:
                await self._writer.wait_closed()
            except Exception:
                pass
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense/bridge/python && pytest tests/test_tcp_client.py -v`
Expected: PASS (4/4 tests)

- [ ] **Step 5: Commit**

```bash
git add bridge/python/fastsense_bridge/tcp_client.py bridge/python/tests/test_tcp_client.py
git commit -m "feat: add async NDJSON TCP client for MATLAB communication"
```

---

### Task 7: Python FastAPI Server

**Files:**
- Create: `bridge/python/fastsense_bridge/server.py`
- Create: `bridge/python/fastsense_bridge/__main__.py`
- Test: `bridge/python/tests/test_server.py`

**Dependencies:** Task 5 (sqlite_reader), Task 6 (tcp_client)

- [ ] **Step 1: Write the failing test**

Create `bridge/python/tests/test_server.py`:

```python
import json
import struct
import sqlite3
import pytest
import numpy as np
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock
from fastapi.testclient import TestClient
from fastsense_bridge.blob_decoder import MKSQ_MAGIC
from fastsense_bridge.server import create_app, AppState


def _make_double_blob(values: list[float]) -> bytes:
    arr = np.array(values, dtype=np.float64)
    header = struct.pack("<6I", MKSQ_MAGIC, 3, 6, 2, 1, len(values))
    return header + arr.tobytes()


@pytest.fixture
def sample_db(tmp_path) -> Path:
    db_path = tmp_path / "test.fpdb"
    conn = sqlite3.connect(str(db_path))
    conn.execute("""CREATE TABLE chunks (
        chunk_id INTEGER PRIMARY KEY,
        x_min REAL NOT NULL, x_max REAL NOT NULL,
        y_min REAL NOT NULL, y_max REAL NOT NULL,
        pt_offset INTEGER NOT NULL, pt_count INTEGER NOT NULL,
        x_data BLOB NOT NULL, y_data BLOB NOT NULL
    )""")
    conn.execute("CREATE INDEX idx_xrange ON chunks (x_min, x_max)")
    x = list(np.linspace(0, 10, 100))
    y = list(np.sin(x))
    conn.execute(
        "INSERT INTO chunks VALUES (0, ?, ?, ?, ?, 0, 100, ?, ?)",
        (x[0], x[-1], min(y), max(y), _make_double_blob(x), _make_double_blob(y)),
    )
    conn.execute("""CREATE TABLE resolved_thresholds (
        idx INTEGER PRIMARY KEY, x_data BLOB, y_data BLOB,
        direction TEXT NOT NULL, label TEXT NOT NULL,
        color BLOB, line_style TEXT NOT NULL, value REAL NOT NULL
    )""")
    conn.execute("""CREATE TABLE resolved_violations (
        idx INTEGER PRIMARY KEY, x_data BLOB, y_data BLOB,
        direction TEXT NOT NULL, label TEXT NOT NULL
    )""")
    conn.commit()
    conn.close()
    return db_path


@pytest.fixture
def app_state(sample_db) -> AppState:
    state = AppState()
    state.signals = [
        {"id": "s1", "dbPath": str(sample_db), "title": "Temperature"},
    ]
    state.dashboard = {"name": "Test", "theme": "light", "widgets": []}
    state.actions = ["recalc"]
    state.tcp_client = MagicMock()
    state.tcp_client.send_action = AsyncMock()
    return state


@pytest.fixture
def client(app_state) -> TestClient:
    app = create_app(app_state)
    return TestClient(app)


class TestServerAPI:
    def test_get_signals(self, client):
        resp = client.get("/api/signals")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["id"] == "s1"

    def test_get_signal_data(self, client):
        resp = client.get("/api/signals/s1/data?xMin=0&xMax=10")
        assert resp.status_code == 200
        data = resp.json()
        assert "x" in data
        assert "y" in data
        assert len(data["x"]) == 100

    def test_get_signal_data_with_max_points(self, client):
        resp = client.get("/api/signals/s1/data?xMin=0&xMax=10&maxPoints=20")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["x"]) <= 20

    def test_get_signal_not_found(self, client):
        resp = client.get("/api/signals/nonexistent/data?xMin=0&xMax=10")
        assert resp.status_code == 404

    def test_get_thresholds(self, client):
        resp = client.get("/api/signals/s1/thresholds")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)

    def test_get_dashboard(self, client):
        resp = client.get("/api/dashboard")
        assert resp.status_code == 200
        data = resp.json()
        assert data["name"] == "Test"

    def test_get_actions(self, client):
        resp = client.get("/api/actions")
        assert resp.status_code == 200
        assert "recalc" in resp.json()

    def test_post_action(self, client, app_state):
        resp = client.post("/api/actions/recalc", json={})
        assert resp.status_code == 200
        app_state.tcp_client.send_action.assert_called_once()

    def test_post_unknown_action(self, client):
        resp = client.post("/api/actions/nonexistent", json={})
        assert resp.status_code == 404
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense/bridge/python && pytest tests/test_server.py -v`
Expected: FAIL — create_app / AppState not found

- [ ] **Step 3: Implement server.py**

Create `bridge/python/fastsense_bridge/server.py`:

```python
"""FastAPI server: REST API + WebSocket + static file serving."""

import asyncio
import json
import uuid
from pathlib import Path
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from .sqlite_reader import SqliteReader


class ActionRequest(BaseModel):
    args: dict = {}


class AppState:
    """Shared state between the TCP client and the HTTP server."""

    def __init__(self):
        self.signals: list[dict] = []
        self.dashboard: dict = {}
        self.actions: list[str] = []
        self.tcp_client = None
        self._readers: dict[str, SqliteReader] = {}
        self._ws_clients: set[WebSocket] = set()
        self._pending_actions: dict[str, asyncio.Future] = {}

    def get_reader(self, signal_id: str) -> SqliteReader | None:
        sig = next((s for s in self.signals if s["id"] == signal_id), None)
        if not sig or not sig.get("dbPath"):
            return None
        db_path = sig["dbPath"]
        if db_path not in self._readers:
            self._readers[db_path] = SqliteReader(db_path)
        return self._readers[db_path]

    def close_readers(self):
        for reader in self._readers.values():
            reader.close()
        self._readers.clear()

    async def broadcast_ws(self, msg: dict):
        dead: set[WebSocket] = set()
        for ws in self._ws_clients:
            try:
                await ws.send_json(msg)
            except Exception:
                dead.add(ws)
        self._ws_clients -= dead

    def on_matlab_message(self, msg: dict):
        """Handle incoming message from MATLAB (called by tcp_client)."""
        msg_type = msg.get("type", "")
        if msg_type == "data_changed":
            # Close affected readers so they reopen with fresh data
            for sig_id in msg.get("signals", []):
                sig = next((s for s in self.signals if s["id"] == sig_id), None)
                if sig and sig.get("dbPath") in self._readers:
                    self._readers[sig["dbPath"]].close()
                    del self._readers[sig["dbPath"]]
            asyncio.create_task(self.broadcast_ws(msg))
        elif msg_type == "config_changed":
            self.dashboard = msg.get("dashboard", self.dashboard)
            asyncio.create_task(self.broadcast_ws(msg))
        elif msg_type == "action_result":
            req_id = msg.get("id", "")
            if req_id in self._pending_actions:
                self._pending_actions[req_id].set_result(msg)
        elif msg_type == "shutdown":
            asyncio.create_task(self.broadcast_ws({"type": "shutdown"}))


def create_app(state: AppState) -> FastAPI:
    app = FastAPI(title="FastSense Bridge")

    # --- REST API ---

    @app.get("/api/signals")
    def list_signals():
        return [{"id": s["id"], "title": s["title"]} for s in state.signals]

    @app.get("/api/signals/{signal_id}/data")
    def get_signal_data(signal_id: str, xMin: float, xMax: float, maxPoints: int = 4000):
        reader = state.get_reader(signal_id)
        if reader is None:
            raise HTTPException(404, f"Signal '{signal_id}' not found")
        x, y = reader.get_range(xMin, xMax, max_points=maxPoints)
        return {"x": x, "y": y}

    @app.get("/api/signals/{signal_id}/thresholds")
    def get_thresholds(signal_id: str):
        reader = state.get_reader(signal_id)
        if reader is None:
            raise HTTPException(404, f"Signal '{signal_id}' not found")
        return reader.get_thresholds()

    @app.get("/api/signals/{signal_id}/violations")
    def get_violations(signal_id: str):
        reader = state.get_reader(signal_id)
        if reader is None:
            raise HTTPException(404, f"Signal '{signal_id}' not found")
        return reader.get_violations()

    @app.get("/api/signals/{signal_id}/columns/{col_name}")
    def get_column(signal_id: str, col_name: str, xMin: float, xMax: float):
        reader = state.get_reader(signal_id)
        if reader is None:
            raise HTTPException(404, f"Signal '{signal_id}' not found")
        return reader.get_column(col_name, xMin, xMax)

    @app.get("/api/dashboard")
    def get_dashboard():
        return state.dashboard

    @app.get("/api/actions")
    def list_actions():
        return state.actions

    @app.post("/api/actions/{action_name}")
    async def invoke_action(action_name: str, request: ActionRequest = ActionRequest()):
        if action_name not in state.actions:
            raise HTTPException(404, f"Action '{action_name}' not found")
        req_id = str(uuid.uuid4())
        future = asyncio.get_running_loop().create_future()
        state._pending_actions[req_id] = future
        try:
            await state.tcp_client.send_action(req_id, action_name, request.args)
            result = await asyncio.wait_for(future, timeout=30.0)
            return result
        except asyncio.TimeoutError:
            return {"ok": False, "error": "timeout"}
        finally:
            state._pending_actions.pop(req_id, None)

    # --- WebSocket ---

    @app.websocket("/ws")
    async def websocket_endpoint(ws: WebSocket):
        await ws.accept()
        state._ws_clients.add(ws)
        try:
            while True:
                await ws.receive_text()  # keep connection alive
        except WebSocketDisconnect:
            state._ws_clients.discard(ws)

    # --- Static files ---

    # server.py is at bridge/python/fastsense_bridge/server.py
    # Go up to bridge/python/fastsense_bridge → bridge/python → bridge, then /web
    web_dir = Path(__file__).resolve().parent.parent.parent / "web"
    if web_dir.is_dir():
        @app.get("/")
        def index():
            return FileResponse(web_dir / "index.html")

        app.mount("/static", StaticFiles(directory=str(web_dir)), name="static")

    return app
```

- [ ] **Step 4: Implement __main__.py**

Create `bridge/python/fastsense_bridge/__main__.py`:

```python
"""CLI entry point for the FastSense bridge server."""

import argparse
import asyncio
import uvicorn
from .tcp_client import MatlabTcpClient
from .server import create_app, AppState


async def run(matlab_port: int, http_host: str, http_port: int):
    state = AppState()

    # Connect to MATLAB
    client = MatlabTcpClient("localhost", matlab_port)
    init_msg = await client.connect()

    state.signals = init_msg.get("signals", [])
    state.dashboard = init_msg.get("dashboard", {})
    state.actions = init_msg.get("actions", [])
    state.tcp_client = client
    client.on_message = state.on_matlab_message
    client.start_listening()

    # Create and start HTTP server
    app = create_app(state)
    config = uvicorn.Config(app, host=http_host, port=http_port, log_level="info")
    server = uvicorn.Server(config)

    async def notify_ready():
        """Wait until uvicorn is actually serving, then tell MATLAB."""
        while not server.started:
            await asyncio.sleep(0.05)
        await client.send_bridge_ready(http_port)

    try:
        await asyncio.gather(server.serve(), notify_ready())
    finally:
        state.close_readers()
        await client.close()


def main():
    parser = argparse.ArgumentParser(description="FastSense Bridge Server")
    parser.add_argument("--matlab-port", type=int, required=True, help="MATLAB TCP port")
    parser.add_argument("--host", default="localhost", help="HTTP bind host")
    parser.add_argument("--port", type=int, default=8080, help="HTTP port")
    args = parser.parse_args()

    asyncio.run(run(args.matlab_port, args.host, args.port))


if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense/bridge/python && pytest tests/test_server.py -v`
Expected: PASS (9/9 tests)

- [ ] **Step 6: Commit**

```bash
git add bridge/python/fastsense_bridge/server.py bridge/python/fastsense_bridge/__main__.py bridge/python/tests/test_server.py
git commit -m "feat: add FastAPI bridge server with REST API, WebSocket, and CLI entry point"
```

---

## Chunk 3: Web Frontend

### Task 8: HTML Shell + CSS + App Entry Point

**Files:**
- Create: `bridge/web/index.html`
- Create: `bridge/web/css/style.css`
- Create: `bridge/web/js/app.js`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p bridge/web/css bridge/web/js bridge/web/vendor
```

- [ ] **Step 2: Create index.html**

Create `bridge/web/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FastSense Dashboard</title>
    <link rel="stylesheet" href="/static/vendor/uPlot.min.css">
    <link rel="stylesheet" href="/static/css/style.css">
</head>
<body>
    <header id="header">
        <h1 id="dashboard-title">FastSense Dashboard</h1>
        <div id="connection-status" class="status-connected">Connected</div>
    </header>
    <main id="dashboard-grid"></main>
    <aside id="action-panel"></aside>
    <div id="toast-container"></div>

    <script src="/static/vendor/uPlot.min.js"></script>
    <script src="/static/js/chart.js"></script>
    <script src="/static/js/widgets.js"></script>
    <script src="/static/js/dashboard.js"></script>
    <script src="/static/js/actions.js"></script>
    <script src="/static/js/app.js"></script>
</body>
</html>
```

- [ ] **Step 3: Create style.css**

Create `bridge/web/css/style.css`:

```css
:root {
    --bg: #f5f5f5;
    --surface: #ffffff;
    --text: #1a1a1a;
    --text-secondary: #666;
    --border: #e0e0e0;
    --accent: #2563eb;
    --danger: #dc2626;
    --success: #16a34a;
    --warning: #d97706;
    --grid-cols: 12;
    --grid-gap: 12px;
}

* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: var(--bg); color: var(--text); }

#header {
    display: flex; align-items: center; justify-content: space-between;
    padding: 12px 20px; background: var(--surface); border-bottom: 1px solid var(--border);
}
#header h1 { font-size: 18px; font-weight: 600; }
.status-connected { color: var(--success); font-size: 13px; }
.status-disconnected { color: var(--danger); font-size: 13px; }

#dashboard-grid {
    display: grid;
    grid-template-columns: repeat(var(--grid-cols), 1fr);
    gap: var(--grid-gap);
    padding: var(--grid-gap);
    min-height: calc(100vh - 100px);
}

.widget {
    background: var(--surface); border: 1px solid var(--border); border-radius: 8px;
    overflow: hidden; display: flex; flex-direction: column;
}
.widget-header {
    padding: 8px 12px; font-size: 13px; font-weight: 600; color: var(--text-secondary);
    border-bottom: 1px solid var(--border);
}
.widget-body { flex: 1; padding: 8px; overflow: hidden; position: relative; }

/* KPI widget */
.kpi-value { font-size: 36px; font-weight: 700; text-align: center; padding: 16px 0; }
.kpi-trend { font-size: 13px; text-align: center; color: var(--text-secondary); }

/* Status widget */
.status-badge {
    display: inline-block; padding: 4px 12px; border-radius: 4px;
    font-weight: 600; font-size: 14px;
}
.status-ok { background: #dcfce7; color: var(--success); }
.status-warning { background: #fef3c7; color: var(--warning); }
.status-alarm { background: #fee2e2; color: var(--danger); }

/* Gauge widget */
.gauge-container { display: flex; justify-content: center; align-items: center; height: 100%; }
.gauge-value { font-size: 24px; font-weight: 700; text-align: center; }

/* Text widget */
.text-content { padding: 8px; font-size: 14px; line-height: 1.5; }

/* Placeholder widget (RawAxes) */
.placeholder { display: flex; justify-content: center; align-items: center; height: 100%; color: var(--text-secondary); font-style: italic; }

/* Action panel */
#action-panel {
    padding: 12px 20px; background: var(--surface); border-top: 1px solid var(--border);
    display: flex; gap: 8px; flex-wrap: wrap;
}
#action-panel:empty { display: none; }
.action-btn {
    padding: 6px 16px; border: 1px solid var(--border); border-radius: 6px;
    background: var(--surface); cursor: pointer; font-size: 13px;
}
.action-btn:hover { background: var(--bg); }
.action-btn:disabled { opacity: 0.5; cursor: not-allowed; }

/* Toast notifications */
#toast-container { position: fixed; bottom: 20px; right: 20px; z-index: 100; }
.toast {
    padding: 10px 16px; border-radius: 6px; margin-top: 8px;
    font-size: 13px; box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    animation: fadeIn 0.2s ease;
}
.toast-error { background: #fee2e2; color: var(--danger); }
.toast-success { background: #dcfce7; color: var(--success); }
@keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: none; } }

/* Table widget */
.widget-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.widget-table th, .widget-table td { padding: 4px 8px; text-align: left; border-bottom: 1px solid var(--border); }
.widget-table th { font-weight: 600; color: var(--text-secondary); }
```

- [ ] **Step 4: Create app.js**

Create `bridge/web/js/app.js`:

```javascript
/**
 * FastSense Bridge — Main entry point.
 * Connects WebSocket, loads dashboard, handles live updates.
 */
const App = (() => {
    let ws = null;
    let reconnectTimer = null;

    async function init() {
        await loadDashboard();
        await loadActions();
        connectWebSocket();
    }

    async function loadDashboard() {
        try {
            const resp = await fetch('/api/dashboard');
            const config = await resp.json();
            document.getElementById('dashboard-title').textContent = config.name || 'FastSense Dashboard';
            Dashboard.render(config);
        } catch (e) {
            showToast('Failed to load dashboard', 'error');
        }
    }

    async function loadActions() {
        try {
            const resp = await fetch('/api/actions');
            const actions = await resp.json();
            Actions.render(actions);
        } catch (e) {
            console.error('Failed to load actions:', e);
        }
    }

    function connectWebSocket() {
        const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
        ws = new WebSocket(`${proto}//${location.host}/ws`);

        ws.onopen = () => {
            setConnectionStatus(true);
            if (reconnectTimer) { clearTimeout(reconnectTimer); reconnectTimer = null; }
        };

        ws.onmessage = (evt) => {
            const msg = JSON.parse(evt.data);
            handleMessage(msg);
        };

        ws.onclose = () => {
            setConnectionStatus(false);
            reconnectTimer = setTimeout(connectWebSocket, 3000);
        };

        ws.onerror = () => ws.close();
    }

    function handleMessage(msg) {
        switch (msg.type) {
            case 'data_changed':
                (msg.signals || []).forEach(id => Chart.refresh(id));
                break;
            case 'config_changed':
                Dashboard.render(msg.dashboard);
                break;
            case 'shutdown':
                setConnectionStatus(false);
                showToast('MATLAB disconnected', 'error');
                break;
        }
    }

    function setConnectionStatus(connected) {
        const el = document.getElementById('connection-status');
        el.textContent = connected ? 'Connected' : 'Disconnected';
        el.className = connected ? 'status-connected' : 'status-disconnected';
    }

    document.addEventListener('DOMContentLoaded', init);

    return { loadDashboard, loadActions };
})();

function showToast(message, type = 'success') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = message;
    container.appendChild(toast);
    setTimeout(() => toast.remove(), 4000);
}
```

- [ ] **Step 5: Commit**

```bash
git add bridge/web/
git commit -m "feat: add web frontend shell with HTML, CSS grid layout, and WebSocket app"
```

---

### Task 9: Chart Viewer (uPlot Wrapper)

**Files:**
- Create: `bridge/web/js/chart.js`
- Vendor: `bridge/web/vendor/uPlot.min.js`, `bridge/web/vendor/uPlot.min.css`

- [ ] **Step 1: Download uPlot**

```bash
cd /Users/hannessuhr/FastSense/bridge/web/vendor
curl -L -o uPlot.min.js "https://unpkg.com/uplot@1.6.31/dist/uPlot.iife.min.js"
curl -L -o uPlot.min.css "https://unpkg.com/uplot@1.6.31/dist/uPlot.min.css"
```

- [ ] **Step 2: Create chart.js**

Create `bridge/web/js/chart.js`:

```javascript
/**
 * Chart — uPlot wrapper with zoom/pan that fetches data from the API.
 */
const Chart = (() => {
    const instances = {};  // signalId → { uplot, container, xMin, xMax }

    function create(signalId, container) {
        const opts = {
            width: container.clientWidth,
            height: container.clientHeight - 10,
            cursor: { drag: { x: true, y: false } },
            scales: { x: { time: false } },
            axes: [
                { size: 40 },
                { size: 60 },
            ],
            series: [
                {},
                { stroke: '#2563eb', width: 1.5 },
            ],
            hooks: {
                setScale: [(u, key) => {
                    if (key === 'x') {
                        const xMin = u.scales.x.min;
                        const xMax = u.scales.x.max;
                        fetchAndUpdate(signalId, xMin, xMax);
                    }
                }],
            },
        };

        const data = [[], []];
        const uplot = new uPlot(opts, data, container);
        instances[signalId] = { uplot, container, xMin: null, xMax: null };

        // Initial load
        fetchAndUpdate(signalId);

        // Resize observer
        const ro = new ResizeObserver(() => {
            uplot.setSize({ width: container.clientWidth, height: container.clientHeight - 10 });
        });
        ro.observe(container);

        return uplot;
    }

    async function fetchAndUpdate(signalId, xMin, xMax) {
        const inst = instances[signalId];
        if (!inst) return;

        let url = `/api/signals/${encodeURIComponent(signalId)}/data?maxPoints=4000`;
        if (xMin != null && xMax != null) {
            url += `&xMin=${xMin}&xMax=${xMax}`;
            inst.xMin = xMin;
            inst.xMax = xMax;
        } else {
            // Full range — use very wide bounds
            url += '&xMin=-1e30&xMax=1e30';
        }

        try {
            const resp = await fetch(url);
            const { x, y } = await resp.json();
            inst.uplot.setData([x, y]);
        } catch (e) {
            console.error(`Failed to fetch data for ${signalId}:`, e);
        }
    }

    function refresh(signalId) {
        const inst = instances[signalId];
        if (!inst) return;
        fetchAndUpdate(signalId, inst.xMin, inst.xMax);
    }

    function destroy(signalId) {
        const inst = instances[signalId];
        if (inst) {
            inst.uplot.destroy();
            delete instances[signalId];
        }
    }

    function destroyAll() {
        Object.keys(instances).forEach(destroy);
    }

    return { create, refresh, destroy, destroyAll };
})();
```

- [ ] **Step 3: Commit**

```bash
git add bridge/web/js/chart.js bridge/web/vendor/
git commit -m "feat: add uPlot chart wrapper with zoom/pan and API data fetching"
```

---

### Task 10: Dashboard Layout + Widget Renderers

**Files:**
- Create: `bridge/web/js/dashboard.js`
- Create: `bridge/web/js/widgets.js`

- [ ] **Step 1: Create widgets.js**

Create `bridge/web/js/widgets.js`:

```javascript
/**
 * Widgets — renders widget content by type.
 */
const Widgets = (() => {

    function render(widgetConfig, bodyEl) {
        const type = widgetConfig.type || '';
        switch (type) {
            case 'fastsense': return renderFastSense(widgetConfig, bodyEl);
            case 'kpi':      return renderKpi(widgetConfig, bodyEl);
            case 'status':   return renderStatus(widgetConfig, bodyEl);
            case 'table':    return renderTable(widgetConfig, bodyEl);
            case 'gauge':    return renderGauge(widgetConfig, bodyEl);
            case 'text':     return renderText(widgetConfig, bodyEl);
            case 'timeline': return renderTimeline(widgetConfig, bodyEl);
            case 'rawaxes':  return renderPlaceholder(bodyEl);
            default:         return renderPlaceholder(bodyEl);
        }
    }

    function renderFastSense(config, el) {
        // Determine signal ID from config source
        let signalId = '';
        if (config.source) {
            signalId = config.source.name || config.source.id || '';
        }
        if (!signalId && config.signalId) {
            signalId = config.signalId;
        }
        if (signalId) {
            Chart.create(signalId, el);
        }
    }

    function renderKpi(config, el) {
        const val = config.value != null ? config.value : '—';
        const fmt = config.format || '';
        el.innerHTML = `
            <div class="kpi-value">${formatValue(val, fmt)}</div>
            ${config.trend ? `<div class="kpi-trend">${config.trend}</div>` : ''}
        `;
    }

    function renderStatus(config, el) {
        const status = (config.status || 'ok').toLowerCase();
        const cls = status === 'ok' ? 'status-ok' : status === 'warning' ? 'status-warning' : 'status-alarm';
        el.innerHTML = `<div style="display:flex;justify-content:center;align-items:center;height:100%">
            <span class="status-badge ${cls}">${config.status || 'OK'}</span>
        </div>`;
    }

    function renderTable(config, el) {
        const data = config.data || { headers: [], rows: [] };
        let html = '<table class="widget-table"><thead><tr>';
        (data.headers || []).forEach(h => html += `<th>${h}</th>`);
        html += '</tr></thead><tbody>';
        (data.rows || []).forEach(row => {
            html += '<tr>';
            row.forEach(cell => html += `<td>${cell}</td>`);
            html += '</tr>';
        });
        html += '</tbody></table>';
        el.innerHTML = html;
    }

    function renderGauge(config, el) {
        const value = config.value != null ? config.value : 0;
        const min = config.min != null ? config.min : 0;
        const max = config.max != null ? config.max : 100;
        const pct = Math.max(0, Math.min(1, (value - min) / (max - min)));
        const angle = -135 + pct * 270;

        el.innerHTML = `<div class="gauge-container">
            <svg viewBox="0 0 200 200" width="160" height="160">
                <path d="M 30 150 A 80 80 0 1 1 170 150" fill="none" stroke="#e0e0e0" stroke-width="12" stroke-linecap="round"/>
                <line x1="100" y1="100" x2="100" y2="30"
                    stroke="#2563eb" stroke-width="3" stroke-linecap="round"
                    transform="rotate(${angle}, 100, 100)"/>
                <circle cx="100" cy="100" r="5" fill="#2563eb"/>
            </svg>
        </div>
        <div class="gauge-value">${value}</div>`;
    }

    function renderText(config, el) {
        el.innerHTML = `<div class="text-content">${config.content || ''}</div>`;
    }

    function renderTimeline(config, el) {
        const events = config.events || [];
        if (!events.length) {
            el.innerHTML = '<div class="placeholder">No events</div>';
            return;
        }
        const allTimes = events.flatMap(e => [e.startTime, e.endTime]);
        const tMin = Math.min(...allTimes);
        const tMax = Math.max(...allTimes);
        const range = tMax - tMin || 1;

        let html = '<div style="position:relative;height:100%;padding:4px 0;">';
        events.forEach((e, i) => {
            const left = ((e.startTime - tMin) / range * 100).toFixed(1);
            const width = Math.max(1, ((e.endTime - e.startTime) / range * 100)).toFixed(1);
            const top = (i * 24 + 2);
            html += `<div style="position:absolute;left:${left}%;width:${width}%;top:${top}px;height:18px;background:var(--accent);border-radius:3px;opacity:0.7;" title="${e.label || ''}"></div>`;
        });
        html += '</div>';
        el.innerHTML = html;
    }

    function renderPlaceholder(el) {
        el.innerHTML = '<div class="placeholder">View in MATLAB</div>';
    }

    function formatValue(val, fmt) {
        if (typeof val === 'number' && fmt) {
            try {
                const decimals = (fmt.match(/\.(\d+)f/) || [])[1];
                if (decimals) return val.toFixed(parseInt(decimals));
            } catch {}
        }
        return val;
    }

    return { render };
})();
```

- [ ] **Step 2: Create dashboard.js**

Create `bridge/web/js/dashboard.js`:

```javascript
/**
 * Dashboard — renders the widget grid from dashboard config.
 */
const Dashboard = (() => {

    function render(config) {
        Chart.destroyAll();
        const grid = document.getElementById('dashboard-grid');
        grid.innerHTML = '';

        const widgets = config.widgets || [];
        widgets.forEach((w, i) => {
            const el = createWidgetElement(w, i);
            grid.appendChild(el);
        });
    }

    function createWidgetElement(config, index) {
        const el = document.createElement('div');
        el.className = 'widget';

        // Position on grid
        const pos = config.position || {};
        el.style.gridColumn = `${pos.col || 1} / span ${pos.width || 3}`;
        el.style.gridRow = `${pos.row || 1} / span ${pos.height || 2}`;

        // Header
        const header = document.createElement('div');
        header.className = 'widget-header';
        header.textContent = config.title || `Widget ${index + 1}`;
        el.appendChild(header);

        // Body
        const body = document.createElement('div');
        body.className = 'widget-body';
        el.appendChild(body);

        // Render widget content
        Widgets.render(config, body);

        return el;
    }

    return { render };
})();
```

- [ ] **Step 3: Commit**

```bash
git add bridge/web/js/dashboard.js bridge/web/js/widgets.js
git commit -m "feat: add dashboard layout renderer and widget type renderers"
```

---

### Task 11: Action Panel

**Files:**
- Create: `bridge/web/js/actions.js`

- [ ] **Step 1: Create actions.js**

Create `bridge/web/js/actions.js`:

```javascript
/**
 * Actions — renders action buttons and handles invocation.
 */
const Actions = (() => {

    function render(actionNames) {
        const panel = document.getElementById('action-panel');
        panel.innerHTML = '';

        actionNames.forEach(name => {
            const btn = document.createElement('button');
            btn.className = 'action-btn';
            btn.textContent = name;
            btn.onclick = () => invoke(name, btn);
            panel.appendChild(btn);
        });
    }

    async function invoke(name, btn) {
        btn.disabled = true;
        btn.textContent = `${name}...`;
        try {
            const resp = await fetch(`/api/actions/${encodeURIComponent(name)}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ args: {} }),
            });
            const result = await resp.json();
            if (result.ok === false) {
                showToast(`Action "${name}" failed: ${result.error}`, 'error');
            } else {
                showToast(`Action "${name}" completed`, 'success');
            }
        } catch (e) {
            showToast(`Action "${name}" failed: ${e.message}`, 'error');
        } finally {
            btn.disabled = false;
            btn.textContent = name;
        }
    }

    return { render };
})();
```

- [ ] **Step 2: Commit**

```bash
git add bridge/web/js/actions.js
git commit -m "feat: add action panel with button rendering and invocation"
```

---

## Chunk 4: Integration & Wiring

### Task 12: Wire FastSenseWidget Signal IDs into Dashboard Config

The web frontend needs to know which signal ID maps to each FastSenseWidget. The `DashboardSerializer.widgetsToConfig` output must include this mapping.

**Files:**
- Modify: `libs/WebBridge/WebBridge.m` (buildDashboardConfig method)

- [ ] **Step 1: Update buildDashboardConfig to inject signalId per widget**

In `libs/WebBridge/WebBridge.m`, update `buildDashboardConfig`:

```matlab
function config = buildDashboardConfig(obj)
    if isempty(obj.Dashboard)
        config = struct('name', '', 'theme', 'light', 'widgets', {{}});
        return;
    end
    config = DashboardSerializer.widgetsToConfig(...
        obj.Dashboard.Name, obj.Dashboard.Theme, ...
        obj.Dashboard.LiveInterval, obj.Dashboard.Widgets);
    % Inject signal IDs so the web frontend knows which signal maps to which widget
    signals = obj.buildSignalList();
    sigIdx = 0;
    for i = 1:numel(config.widgets)
        w = config.widgets{i};
        if strcmp(w.type, 'fastsense') && sigIdx < numel(signals)
            sigIdx = sigIdx + 1;
            config.widgets{i}.signalId = signals(sigIdx).id;
        end
    end
end
```

- [ ] **Step 2: Run existing WebBridge tests to verify no regressions**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "run_all_tests('TestWebBridge')"`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add libs/WebBridge/WebBridge.m
git commit -m "feat: inject signalId into dashboard widget configs for web frontend mapping"
```

---

### Task 13: End-to-End Smoke Test

**Files:**
- Create: `tests/suite/TestWebBridgeE2E.m`

This test verifies the full MATLAB → TCP → Python bridge chain (without a browser).

- [ ] **Step 1: Write the E2E test**

Create `tests/suite/TestWebBridgeE2E.m`:

```matlab
classdef TestWebBridgeE2E < matlab.unittest.TestCase
    %TESTWEBBRIDGEE2E End-to-end test: MATLAB WebBridge + Python bridge.
    %
    %   Requires: Python 3.11+ with fastsense-bridge installed.
    %   Skip if not available.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testServeAndFetchData(testCase)
            % Skip if Python bridge not installed
            [status, ~] = system('python -c "import fastsense_bridge"');
            testCase.assumeTrue(status == 0, ...
                'fastsense-bridge Python package not installed');

            % Create a dashboard with one signal
            x = linspace(0, 100, 10000);
            y = sin(x);
            engine = DashboardEngine('E2E Test');
            engine.addWidget('fastsense', 'Title', 'Sine Wave', ...
                'XData', x, 'YData', y, 'Position', [1 1 6 3]);

            bridge = WebBridge(engine);
            testCase.addTeardown(@() bridge.stop());

            bridge.serve();

            % Verify HTTP port was set
            testCase.verifyGreaterThan(bridge.HttpPort, 0);

            % Fetch data via REST API
            url = sprintf('http://localhost:%d/api/signals', bridge.HttpPort);
            signals = webread(url);
            testCase.verifyGreaterThan(numel(signals), 0);

            % Fetch signal data
            sigId = signals(1).id;
            dataUrl = sprintf('http://localhost:%d/api/signals/%s/data?xMin=0&xMax=100&maxPoints=100', ...
                bridge.HttpPort, sigId);
            data = webread(dataUrl);
            testCase.verifyTrue(isfield(data, 'x'));
            testCase.verifyTrue(isfield(data, 'y'));
            testCase.verifyGreaterThan(numel(data.x), 0);
        end
    end
end
```

- [ ] **Step 2: Run the E2E test (requires Python bridge installed)**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "run_all_tests('TestWebBridgeE2E')"`
Expected: PASS (or SKIP if Python not set up)

- [ ] **Step 3: Commit**

```bash
git add tests/suite/TestWebBridgeE2E.m
git commit -m "test: add end-to-end smoke test for WebBridge + Python bridge"
```

---

### Deferred Items

The following items from the spec are deferred for a future iteration:
- `libs/WebBridge/MksqliteBlobReader.m` — MATLAB-side BLOB reader for testing/debugging
- Optional auth token (UUID generation, Bearer header validation)
- Node.js bridge server (separate plan)
