/* ============================================================
   app.js — Main entry point: fetch config, connect WebSocket
   ============================================================ */

(function () {
    "use strict";

    var WS_RECONNECT_MS = 3000;
    var statusEl = document.getElementById("connection-status");
    var ws = null;

    /* --- Toast --------------------------------------------- */
    window.showToast = function (message, type) {
        type = type || "success";
        var container = document.getElementById("toast-container");
        var toast = document.createElement("div");
        toast.className = "toast toast-" + type;
        toast.textContent = message;
        container.appendChild(toast);

        setTimeout(function () {
            toast.classList.add("fade-out");
            toast.addEventListener("animationend", function () {
                toast.remove();
            });
        }, 4000);
    };

    /* --- Initial data load --------------------------------- */
    function loadDashboard() {
        fetch("/api/dashboard")
            .then(function (r) {
                if (!r.ok) throw new Error("HTTP " + r.status);
                return r.json();
            })
            .then(function (config) {
                Dashboard.render(config);
            })
            .catch(function (err) {
                console.error("[app] Failed to load dashboard config:", err);
                showToast("Failed to load dashboard", "error");
            });
    }

    function loadActions() {
        fetch("/api/actions")
            .then(function (r) {
                if (!r.ok) throw new Error("HTTP " + r.status);
                return r.json();
            })
            .then(function (data) {
                var names = data || [];
                Actions.render(names);
            })
            .catch(function (err) {
                console.error("[app] Failed to load actions:", err);
            });
    }

    /* --- WebSocket ----------------------------------------- */
    function setStatus(state) {
        statusEl.textContent = state;
        statusEl.className = "";
        if (state === "Connected")    statusEl.classList.add("status-connected");
        else if (state === "Reconnecting") statusEl.classList.add("status-reconnecting");
        else                          statusEl.classList.add("status-disconnected");
    }

    function connectWebSocket() {
        var proto = location.protocol === "https:" ? "wss:" : "ws:";
        var url   = proto + "//" + location.host + "/ws";

        ws = new WebSocket(url);

        ws.onopen = function () {
            setStatus("Connected");
        };

        ws.onmessage = function (ev) {
            var msg;
            try { msg = JSON.parse(ev.data); } catch (e) { return; }

            switch (msg.type) {
                case "data_changed":
                    handleDataChanged(msg);
                    break;
                case "config_changed":
                    loadDashboard();
                    loadActions();
                    break;
                case "actions_changed":
                    Actions.render(msg.actions || []);
                    break;
                case "shutdown":
                    setStatus("Disconnected");
                    showToast("Server shutting down", "error");
                    break;
                default:
                    break;
            }
        };

        ws.onclose = function () {
            setStatus("Reconnecting");
            setTimeout(connectWebSocket, WS_RECONNECT_MS);
        };

        ws.onerror = function () {
            ws.close();
        };
    }

    function handleDataChanged(msg) {
        var signals = msg.signals;
        if (signals && signals.length > 0) {
            for (var i = 0; i < signals.length; i++) {
                Chart.refresh(signals[i]);
            }
        } else {
            // Refresh all charts if no specific signals listed
            var ids = Chart.getSignalIds();
            for (var i = 0; i < ids.length; i++) {
                Chart.refresh(ids[i]);
            }
        }
    }

    /* --- Boot ---------------------------------------------- */
    loadDashboard();
    loadActions();
    connectWebSocket();
})();
