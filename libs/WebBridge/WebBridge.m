classdef WebBridge < handle
    properties (Access = public)
        Dashboard
        ConfigPollInterval = 1
    end
    properties (SetAccess = private)
        TcpPort = 0
        HttpPort = 0
        IsServing = false
    end
    properties (Access = private)
        TcpServer = []
        ClientConnected = false
        Actions = struct()
        ConfigTimer = []
        LastConfigHash = ''
    end
    methods (Access = public)
        function obj = WebBridge(dashboard, varargin)
            obj.Dashboard = dashboard;
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end
        function serve(obj)
            obj.enableWALOnDataStores();
            obj.startTcp();
            obj.launchBridge();
            obj.startConfigPoll();
        end
        function startTcp(obj)
            if obj.IsServing; return; end
            obj.TcpServer = tcpserver('localhost', 0, ...
                'ConnectionChangedFcn', @(src, evt) obj.onConnectionChanged(src, evt));
            obj.TcpPort = obj.TcpServer.ServerPort;
            obj.IsServing = true;
        end
        function stop(obj)
            if ~obj.IsServing; return; end
            obj.sendToClient(WebBridgeProtocol.encodeShutdown());
            obj.stopConfigPoll();
            pause(0.1);
            delete(obj.TcpServer);
            obj.TcpServer = [];
            obj.IsServing = false;
            obj.ClientConnected = false;
            obj.disableWALOnDataStores();
        end
        function registerAction(obj, name, callback)
            obj.Actions.(name) = callback;
            if obj.IsServing && obj.ClientConnected
                obj.sendConfigChanged();
            end
        end
        function tf = hasAction(obj, name)
            tf = isfield(obj.Actions, name);
        end
        function notifyDataChanged(obj, signalId)
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
            if isempty(obj.Dashboard) || isempty(obj.Dashboard.Widgets); return; end
            idx = 0;
            for i = 1:numel(obj.Dashboard.Widgets)
                w = obj.Dashboard.Widgets{i};
                if ~isa(w, 'FastPlotWidget'); continue; end
                idx = idx + 1;
                if isprop(w, 'Sensor') && ~isempty(w.Sensor) && isprop(w.Sensor, 'Key')
                    sid = w.Sensor.Key;
                else
                    sid = sprintf('ds_%d', idx);
                end
                dbPath = '';
                if isprop(w, 'DataStore') && ~isempty(w.DataStore) && isprop(w.DataStore, 'DbPath')
                    dbPath = w.DataStore.DbPath;
                elseif isprop(w, 'Sensor') && ~isempty(w.Sensor) && isprop(w.Sensor, 'DataStore') && ~isempty(w.Sensor.DataStore)
                    dbPath = w.Sensor.DataStore.DbPath;
                end
                signals(end+1) = struct('id', sid, 'dbPath', dbPath, 'title', w.Title);
            end
        end
        function config = buildDashboardConfig(obj)
            if isempty(obj.Dashboard)
                config = struct('name', '', 'theme', 'light', 'widgets', {{}});
                return;
            end
            config = DashboardSerializer.widgetsToConfig(obj.Dashboard.Name, obj.Dashboard.Theme, obj.Dashboard.LiveInterval, obj.Dashboard.Widgets);
            signals = obj.buildSignalList();
            sigIdx = 0;
            for i = 1:numel(config.widgets)
                w = config.widgets{i};
                if strcmp(w.type, 'fastplot') && sigIdx < numel(signals)
                    sigIdx = sigIdx + 1;
                    config.widgets{i}.signalId = signals(sigIdx).id;
                end
            end
        end
        function sendToClient(obj, msg)
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
            obj.ConfigTimer = timer('ExecutionMode', 'fixedRate', 'Period', obj.ConfigPollInterval, 'TimerFcn', @(~,~) obj.checkConfigChanged());
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
            try
                md = java.security.MessageDigest.getInstance('MD5');
                md.update(uint8(json));
                h = sprintf('%02x', typecast(md.digest(), 'uint8'));
            catch
                h = sprintf('%d_%d', length(json), sum(uint8(json)));
            end
        end
        function launchBridge(obj)
            bridgeDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'bridge', 'python');
            cmd = sprintf('python -m fastplot_bridge --matlab-port %d', obj.TcpPort);
            if ispc
                fullCmd = sprintf('start /B %s', cmd);
            else
                fullCmd = sprintf('cd "%s" && %s &', bridgeDir, cmd);
            end
            system(fullCmd);
            t0 = tic;
            while toc(t0) < 10
                drawnow;
                if obj.HttpPort > 0; return; end
                pause(0.1);
            end
            obj.stop();
            error('WebBridge:timeout', 'Bridge did not start within 10s. Check that fastplot-bridge is installed.');
        end
        function enableWALOnDataStores(obj)
            stores = obj.collectDataStores();
            for i = 1:numel(stores); stores{i}.enableWAL(); end
        end
        function disableWALOnDataStores(obj)
            stores = obj.collectDataStores();
            for i = 1:numel(stores); stores{i}.disableWAL(); end
        end
        function stores = collectDataStores(obj)
            stores = {};
            if isempty(obj.Dashboard) || isempty(obj.Dashboard.Widgets); return; end
            for i = 1:numel(obj.Dashboard.Widgets)
                w = obj.Dashboard.Widgets{i};
                if ~isa(w, 'FastPlotWidget'); continue; end
                ds = [];
                if isprop(w, 'DataStore') && ~isempty(w.DataStore)
                    ds = w.DataStore;
                elseif isprop(w, 'Sensor') && ~isempty(w.Sensor) && isprop(w.Sensor, 'DataStore') && ~isempty(w.Sensor.DataStore)
                    ds = w.Sensor.DataStore;
                end
                if ~isempty(ds); stores{end+1} = ds; end
            end
        end
    end
end
