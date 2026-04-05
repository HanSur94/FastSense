classdef WebBridge < handle
    %WEBBRIDGE Connectivity bridge between MATLAB and external frameworks.
    %   Exposes signal data (from FastSenseDataStore SQLite files) and
    %   registered actions via a REST API + WebSocket push channel.
    %   External clients (Python, JS, React, etc.) can query data and
    %   invoke MATLAB callbacks through the HTTP API.
    %
    %   This is a pure data relay — no dashboard rendering or UI logic.
    %
    %   Architecture:
    %     MATLAB (tcpserver) —TCP/NDJSON—> Python (FastAPI) —HTTP/WS—> Clients
    %
    %   Usage:
    %     bridge = WebBridge(dashboard);
    %     bridge.registerAction('recalc', @() sensor.resolve());
    %     bridge.serve();  % starts at http://localhost:8080
    %     bridge.notifyDataChanged('temperature');
    %     bridge.stop();
    %
    %   See also WebBridgeProtocol, FastSenseDataStore.

    properties (Access = public)
        Dashboard
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
    end
    methods (Access = public)
        function obj = WebBridge(dashboard, varargin)
            %WEBBRIDGE Create a bridge for the given dashboard.
            obj.Dashboard = dashboard;
            validKeys = {};
            for k = 1:2:numel(varargin)
                key = varargin{k};
                if ~ismember(key, validKeys)
                    error('WebBridge:unknownOption', 'Unknown option ''%s''.', key);
                end
                obj.(key) = varargin{k+1};
            end
        end
        function serve(obj)
            %SERVE Start the TCP server and launch the Python bridge.
            if obj.IsServing; return; end
            obj.registerBuiltinActions();
            obj.enableWALOnDataStores();
            obj.startTcp();
            try
                obj.launchBridge();
            catch ex
                obj.stop();
                rethrow(ex);
            end
        end
        function stop(obj)
            %STOP Shut down the bridge and clean up resources.
            if ~obj.IsServing; return; end
            obj.sendToClient(WebBridgeProtocol.encodeShutdown());
            pause(0.1);
            delete(obj.TcpServer);
            obj.TcpServer = [];
            obj.IsServing = false;
            obj.ClientConnected = false;
            obj.disableWALOnDataStores();
        end
        function registerAction(obj, name, callback)
            %REGISTERACTION Register a named action callable from external clients.
            obj.Actions.(name) = callback;
            if obj.IsServing && obj.ClientConnected
                obj.sendActionsChanged();
            end
        end
        function tf = hasAction(obj, name)
            %HASACTION Check if an action is registered.
            tf = isfield(obj.Actions, name);
        end
        function notifyDataChanged(obj, signalId)
            %NOTIFYDATACHANGED Tell connected clients that signal data has updated.
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
        function startTcp(obj)
            if obj.IsServing; return; end
            if exist('OCTAVE_VERSION', 'builtin')
                error('WebBridge:unsupported', ...
                    'WebBridge requires MATLAB R2021a+ (tcpserver). GNU Octave is not supported.');
            end
            obj.TcpServer = tcpserver('localhost', 0, ...
                'ConnectionChangedFcn', @(src, evt) obj.onConnectionChanged(src, evt));
            obj.TcpPort = obj.TcpServer.ServerPort;
            obj.IsServing = true;
        end
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
        function registerBuiltinActions(obj)
            %REGISTERBUILTINACTIONS Register built-in bridge actions.
            obj.Actions.openInMatlab = @(args) obj.openInMatlab(args);
        end
        function openInMatlab(obj, args)
            %OPENINMATLAB Export signal data and open an analysis script.
            %   Called when a frontend user clicks "Open in MATLAB".
            %   Saves the viewed data to a .mat file and creates a starter
            %   analysis script, then opens it in the MATLAB editor.
            signalId = args.signalId;
            [widget, ds] = obj.findWidgetAndStore(signalId);
            if isempty(widget)
                error('WebBridge:signalNotFound', 'Signal ''%s'' not found.', signalId);
            end
            % Load data for the viewed range
            xMin = args.xMin;
            xMax = args.xMax;
            if ~isempty(ds)
                if xMin <= -1e29; xMin = ds.XMin; end
                if xMax >= 1e29; xMax = ds.XMax; end
                [x, y] = ds.getRange(xMin, xMax);
            else
                x = []; y = [];
            end
            % Collect threshold info
            thresholds = struct('value', {}, 'label', {}, 'direction', {});
            if isprop(widget, 'Sensor') && ~isempty(widget.Sensor) && ...
                    isprop(widget.Sensor, 'Thresholds')
                for t = 1:numel(widget.Sensor.Thresholds)
                    th = widget.Sensor.Thresholds(t);
                    thresholds(end+1) = struct('value', th.Value, ...
                        'label', th.Label, 'direction', th.Direction);
                end
            end
            % Build metadata
            signalTitle = widget.Title;
            viewRange = [xMin, xMax];
            nPoints = numel(x);
            exportTime = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            % Save .mat file
            exportDir = fullfile(tempdir, 'fastsense_exports');
            if ~exist(exportDir, 'dir'); mkdir(exportDir); end
            matFile = fullfile(exportDir, sprintf('%s.mat', signalId));
            save(matFile, 'x', 'y', 'signalId', 'signalTitle', 'viewRange', ...
                'thresholds', 'nPoints', 'exportTime');
            % Generate analysis script
            scriptFile = fullfile(exportDir, sprintf('analyze_%s.m', signalId));
            obj.writeAnalysisScript(scriptFile, matFile, signalId, signalTitle);
            % Open in editor
            try
                edit(scriptFile);
            catch
                % editor may not be available in some environments
            end
            fprintf('[WebBridge] Exported %d points to %s\n', nPoints, matFile);
            fprintf('[WebBridge] Analysis script: %s\n', scriptFile);
        end
        function writeAnalysisScript(~, scriptFile, matFile, signalId, signalTitle)
            %WRITEANALYSISSCRIPT Generate a starter .m script for analysis.
            fid = fopen(scriptFile, 'w');
            fprintf(fid, '%%%% Analysis: %s\n', signalTitle);
            fprintf(fid, '%% Exported from FastSense WebBridge\n');
            fprintf(fid, '%% Signal: %s\n\n', signalId);
            fprintf(fid, '%%%% Load data\n');
            fprintf(fid, 'data = load(''%s'');\n', strrep(matFile, '''', ''''''));
            fprintf(fid, 'x = data.x;\n');
            fprintf(fid, 'y = data.y;\n');
            fprintf(fid, 'fprintf(''Loaded %%d points for: %s\\n'', numel(x));\n\n', signalTitle);
            fprintf(fid, '%%%% Quick plot\n');
            fprintf(fid, 'figure(''Name'', ''%s'', ''NumberTitle'', ''off'');\n', signalTitle);
            fprintf(fid, 'plot(x, y);\n');
            fprintf(fid, 'title(''%s'');\n', signalTitle);
            fprintf(fid, 'xlabel(''Time''); ylabel(''Value'');\n');
            fprintf(fid, 'grid on;\n\n');
            fprintf(fid, '%%%% Thresholds\n');
            fprintf(fid, 'if ~isempty(data.thresholds)\n');
            fprintf(fid, '    hold on;\n');
            fprintf(fid, '    for i = 1:numel(data.thresholds)\n');
            fprintf(fid, '        yline(data.thresholds(i).value, ''--r'', data.thresholds(i).label);\n');
            fprintf(fid, '    end\n');
            fprintf(fid, '    hold off;\n');
            fprintf(fid, 'end\n\n');
            fprintf(fid, '%%%% Your analysis below\n');
            fprintf(fid, '%% e.g. find peaks, compute FFT, detect anomalies...\n');
            fprintf(fid, '\n');
            fclose(fid);
        end
        function [widget, ds] = findWidgetAndStore(obj, signalId)
            %FINDWIDGETANDSTORE Find the widget and DataStore for a signal ID.
            widget = [];
            ds = [];
            if isempty(obj.Dashboard) || isempty(obj.Dashboard.Widgets); return; end
            for i = 1:numel(obj.Dashboard.Widgets)
                w = obj.Dashboard.Widgets{i};
                if ~isa(w, 'FastSenseWidget'); continue; end
                sid = '';
                if isprop(w, 'Sensor') && ~isempty(w.Sensor) && isprop(w.Sensor, 'Key')
                    sid = w.Sensor.Key;
                end
                if strcmp(sid, signalId)
                    widget = w;
                    if isprop(w, 'DataStore') && ~isempty(w.DataStore)
                        ds = w.DataStore;
                    elseif isprop(w, 'Sensor') && ~isempty(w.Sensor) && ...
                            isprop(w.Sensor, 'DataStore') && ~isempty(w.Sensor.DataStore)
                        ds = w.Sensor.DataStore;
                    end
                    return;
                end
            end
        end
        function handleMessage(obj, msg)
            switch msg.type
                case 'action'
                    obj.executeAction(msg);
                case 'bridge_ready'
                    obj.HttpPort = msg.httpPort;
                    fprintf('Bridge serving at http://localhost:%d\n', obj.HttpPort);
                    fprintf('  API docs:  http://localhost:%d/docs\n', obj.HttpPort);
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
            actionNames = fieldnames(obj.Actions);
            if isempty(actionNames); actionNames = {}; end
            msg = WebBridgeProtocol.encodeInit(signals, actionNames);
            writeline(obj.TcpServer, strtrim(msg));
        end
        function signals = buildSignalList(obj)
            %BUILDSIGNALLIST Build signal list from dashboard widgets.
            signals = struct('id', {}, 'dbPath', {}, 'title', {});
            if isempty(obj.Dashboard) || isempty(obj.Dashboard.Widgets); return; end
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
                elseif isprop(w, 'Sensor') && ~isempty(w.Sensor) && isprop(w.Sensor, 'DataStore') && ~isempty(w.Sensor.DataStore)
                    dbPath = w.Sensor.DataStore.DbPath;
                end
                signals(end+1) = struct('id', sid, 'dbPath', dbPath, 'title', w.Title);
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
        function sendActionsChanged(obj)
            actionNames = fieldnames(obj.Actions);
            if isempty(actionNames); actionNames = {}; end
            msg = WebBridgeProtocol.encodeActionsChanged(actionNames);
            obj.sendToClient(msg);
        end
        function launchBridge(obj)
            bridgeDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'bridge', 'python');
            logFile = [tempname, '_webbridge.log'];
            cmd = sprintf('python -m fastsense_bridge --matlab-port %d', obj.TcpPort);
            if ispc
                fullCmd = sprintf('cd /d "%s" && start /B %s >"%s" 2>&1', bridgeDir, cmd, logFile);
            else
                fullCmd = sprintf('cd "%s" && %s >"%s" 2>&1 &', bridgeDir, cmd, logFile);
            end
            system(fullCmd);
            t0 = tic;
            while toc(t0) < 10
                drawnow;
                if obj.HttpPort > 0; return; end
                pause(0.1);
            end
            diagMsg = '';
            try
                fid = fopen(logFile, 'r');
                if fid ~= -1
                    diagMsg = fread(fid, '*char')';
                    fclose(fid);
                    delete(logFile);
                end
            catch
            end
            obj.stop();
            if ~isempty(diagMsg)
                error('WebBridge:timeout', 'Bridge did not start within 10s.\nOutput:\n%s', diagMsg);
            else
                error('WebBridge:timeout', 'Bridge did not start within 10s. Check that fastsense-bridge is installed.');
            end
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
                if ~isa(w, 'FastSenseWidget'); continue; end
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
