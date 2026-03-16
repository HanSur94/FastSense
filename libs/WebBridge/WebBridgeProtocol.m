classdef WebBridgeProtocol
    %WEBBRIDGEPROTOCOL NDJSON message encoding/decoding for WebBridge TCP protocol.
    methods (Static)
        function msg = encodeInit(signals, dashboard, actions)
            s = struct('type', 'init', 'signals', {signals}, 'dashboard', dashboard, 'actions', {actions});
            msg = [jsonencode(s), newline];
        end
        function msg = encodeDataChanged(signalIds)
            s = struct('type', 'data_changed', 'signals', {signalIds});
            msg = [jsonencode(s), newline];
        end
        function msg = encodeConfigChanged(dashboard)
            s = struct('type', 'config_changed', 'dashboard', dashboard);
            msg = [jsonencode(s), newline];
        end
        function msg = encodeActionsChanged(actionNames)
            s = struct('type', 'actions_changed', 'actions', {actionNames});
            msg = [jsonencode(s), newline];
        end
        function msg = encodeActionResult(requestId, name, ok, errorMsg)
            s = struct('type', 'action_result', 'id', requestId, 'name', name, 'ok', ok);
            if ~ok && ~isempty(errorMsg)
                s.error = errorMsg;
            end
            msg = [jsonencode(s), newline];
        end
        function msg = encodeShutdown()
            msg = [jsonencode(struct('type', 'shutdown')), newline];
        end
        function msg = encodeBridgeReady(httpPort)
            s = struct('type', 'bridge_ready', 'httpPort', httpPort);
            msg = [jsonencode(s), newline];
        end
        function msg = decode(raw)
            msg = jsondecode(strtrim(raw));
        end
    end
end
