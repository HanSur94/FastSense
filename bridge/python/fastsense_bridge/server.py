"""FastAPI server: lean REST API + WebSocket connectivity bridge.

Provides endpoints for listing signals, querying time-series data,
reading thresholds/violations, and invoking MATLAB actions. WebSocket
endpoint broadcasts real-time events from MATLAB to connected clients.

No UI — this is a pure data relay for external frameworks to consume.
"""

import asyncio
import uuid
from typing import Any

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel

from .sqlite_reader import SqliteReader


class ActionRequest(BaseModel):
    """Request body for action invocation."""

    args: dict[str, Any] = {}


class AppState:
    """Shared state between the TCP client and the HTTP server.

    Holds the current signal list, action registry, SQLite readers,
    WebSocket clients, and pending action futures.
    """

    def __init__(self) -> None:
        self.signals: list[dict[str, Any]] = []
        self.actions: list[str] = []
        self.tcp_client: Any = None
        self._readers: dict[str, SqliteReader] = {}
        self._ws_clients: set[WebSocket] = set()
        self._pending_actions: dict[str, asyncio.Future[dict[str, Any]]] = {}

    def get_reader(self, signal_id: str) -> SqliteReader | None:
        """Get or create a SqliteReader for the given signal."""
        sig = next((s for s in self.signals if s["id"] == signal_id), None)
        if not sig or not sig.get("dbPath"):
            return None
        db_path = sig["dbPath"]
        if db_path not in self._readers:
            self._readers[db_path] = SqliteReader(db_path)
        return self._readers[db_path]

    def close_readers(self) -> None:
        """Close all open SQLite readers."""
        for reader in self._readers.values():
            reader.close()
        self._readers.clear()

    async def broadcast_ws(self, msg: dict[str, Any]) -> None:
        """Send a JSON message to all connected WebSocket clients."""
        dead: set[WebSocket] = set()
        for ws in list(self._ws_clients):
            try:
                await ws.send_json(msg)
            except Exception:
                dead.add(ws)
        self._ws_clients -= dead

    def on_matlab_message(self, msg: dict[str, Any]) -> None:
        """Handle incoming message from MATLAB (called by tcp_client).

        Must be called from within the asyncio event loop context,
        as it uses asyncio.create_task() internally.
        """
        msg_type = msg.get("type", "")
        if msg_type == "data_changed":
            for sig_id in msg.get("signals", []):
                sig = next(
                    (s for s in self.signals if s["id"] == sig_id), None
                )
                if sig and sig.get("dbPath") in self._readers:
                    self._readers[sig["dbPath"]].close()
                    del self._readers[sig["dbPath"]]
            asyncio.create_task(self.broadcast_ws(msg))
        elif msg_type == "actions_changed":
            self.actions = msg.get("actions", self.actions)
            asyncio.create_task(self.broadcast_ws(msg))
        elif msg_type == "action_result":
            req_id = msg.get("id", "")
            if req_id in self._pending_actions:
                self._pending_actions[req_id].set_result(msg)
        elif msg_type == "shutdown":
            for fut in self._pending_actions.values():
                if not fut.done():
                    fut.set_exception(ConnectionError("MATLAB disconnected"))
            self._pending_actions.clear()
            asyncio.create_task(
                self.broadcast_ws({"type": "shutdown"})
            )


def create_app(state: AppState) -> FastAPI:
    """Create the FastAPI application with all routes."""
    app = FastAPI(
        title="FastSense Bridge",
        description="Lean connectivity bridge for MATLAB data access",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # --- Signal Data API ---

    @app.get("/api/signals")
    def list_signals() -> list[dict[str, str]]:
        return [
            {"id": s["id"], "title": s.get("title", s["id"])}
            for s in state.signals
        ]

    @app.get("/api/signals/{signal_id}/data")
    def get_signal_data(
        signal_id: str,
        xMin: float = -1e30,
        xMax: float = 1e30,
        maxPoints: int = 4000,
        fmt: str = "json",
    ) -> Any:
        reader = state.get_reader(signal_id)
        if reader is None:
            raise HTTPException(404, f"Signal '{signal_id}' not found")
        x, y = reader.get_range(xMin, xMax, max_points=maxPoints)
        if fmt == "binary":
            # Return raw float64 binary: [n_points (uint32), x_data, y_data]
            import struct
            import numpy as np
            xa = np.array(x, dtype=np.float64)
            ya = np.array(y, dtype=np.float64)
            header = struct.pack("<I", len(x))
            return Response(
                content=header + xa.tobytes() + ya.tobytes(),
                media_type="application/octet-stream",
            )
        return {"x": x, "y": y}

    @app.get("/api/signals/{signal_id}/thresholds")
    def get_thresholds(signal_id: str) -> list[dict]:
        reader = state.get_reader(signal_id)
        if reader is None:
            raise HTTPException(404, f"Signal '{signal_id}' not found")
        return reader.get_thresholds()

    @app.get("/api/signals/{signal_id}/violations")
    def get_violations(signal_id: str) -> list[dict]:
        reader = state.get_reader(signal_id)
        if reader is None:
            raise HTTPException(404, f"Signal '{signal_id}' not found")
        return reader.get_violations()

    @app.get("/api/signals/{signal_id}/columns/{col_name}")
    def get_column(
        signal_id: str, col_name: str,
        xMin: float = -1e30, xMax: float = 1e30,
    ) -> list:
        reader = state.get_reader(signal_id)
        if reader is None:
            raise HTTPException(404, f"Signal '{signal_id}' not found")
        return reader.get_column(col_name, xMin, xMax)

    # --- Bulk Data API (fetch multiple signals in one request) ---

    @app.post("/api/signals/bulk")
    def bulk_signal_data(
        request: dict[str, Any],
    ) -> dict[str, dict[str, list[float]]]:
        """Fetch data for multiple signals in a single request.

        Body: {"signals": ["id1", "id2"], "xMin": 0, "xMax": 100, "maxPoints": 2000}
        """
        signal_ids = request.get("signals", [])
        x_min = request.get("xMin", -1e30)
        x_max = request.get("xMax", 1e30)
        max_points = request.get("maxPoints", 4000)
        result: dict[str, dict[str, list[float]]] = {}
        for sid in signal_ids:
            reader = state.get_reader(sid)
            if reader is None:
                continue
            x, y = reader.get_range(x_min, x_max, max_points=max_points)
            result[sid] = {"x": x, "y": y}
        return result

    # --- Action API ---

    @app.get("/api/actions")
    def list_actions() -> list[str]:
        return state.actions

    @app.post("/api/actions/{action_name}")
    async def invoke_action(
        action_name: str,
        request: ActionRequest = ActionRequest(),
    ) -> dict[str, Any]:
        if action_name not in state.actions:
            raise HTTPException(
                404, f"Action '{action_name}' not found"
            )
        req_id = str(uuid.uuid4())
        future: asyncio.Future[dict[str, Any]] = (
            asyncio.get_running_loop().create_future()
        )
        state._pending_actions[req_id] = future
        try:
            await state.tcp_client.send_action(
                req_id, action_name, request.args
            )
            result = await asyncio.wait_for(future, timeout=30.0)
            return result
        except asyncio.TimeoutError:
            return {"ok": False, "error": "timeout"}
        finally:
            state._pending_actions.pop(req_id, None)

    # --- WebSocket ---

    @app.websocket("/ws")
    async def websocket_endpoint(ws: WebSocket) -> None:
        await ws.accept()
        state._ws_clients.add(ws)
        try:
            while True:
                await ws.receive_text()
        except WebSocketDisconnect:
            state._ws_clients.discard(ws)

    # --- MATLAB Integration ---

    @app.post("/api/open-in-matlab/{signal_id}")
    async def open_in_matlab(
        signal_id: str,
        xMin: float = -1e30,
        xMax: float = 1e30,
    ) -> dict[str, Any]:
        """Open a signal in MATLAB for deeper analysis.

        If MATLAB is connected via TCP: saves .mat + opens analysis script.
        If not: returns a downloadable .m script with data query.
        """
        # Try live MATLAB connection first
        if "openInMatlab" in state.actions and state.tcp_client is not None:
            req_id = str(uuid.uuid4())
            future: asyncio.Future[dict[str, Any]] = (
                asyncio.get_running_loop().create_future()
            )
            state._pending_actions[req_id] = future
            try:
                await state.tcp_client.send_action(
                    req_id, "openInMatlab",
                    {"signalId": signal_id, "xMin": xMin, "xMax": xMax},
                )
                result = await asyncio.wait_for(future, timeout=10.0)
                return result
            except asyncio.TimeoutError:
                return {"ok": False, "error": "MATLAB did not respond"}
            finally:
                state._pending_actions.pop(req_id, None)

        # Fallback: generate .m script with data
        sig = next((s for s in state.signals if s["id"] == signal_id), None)
        if not sig:
            raise HTTPException(404, f"Signal '{signal_id}' not found")
        return {
            "ok": True,
            "mode": "script",
            "scriptUrl": f"/api/export/script/{signal_id}?xMin={xMin}&xMax={xMax}",
        }

    @app.get("/api/export/script/{signal_id}")
    def export_matlab_script(
        signal_id: str,
        xMin: float = -1e30,
        xMax: float = 1e30,
    ) -> Response:
        """Generate a .m script that loads signal data into MATLAB."""
        sig = next((s for s in state.signals if s["id"] == signal_id), None)
        if not sig:
            raise HTTPException(404, f"Signal '{signal_id}' not found")

        db_path = sig.get("dbPath", "")
        title = sig.get("title", signal_id)

        # Read actual data so we can embed it in the script
        reader = state.get_reader(signal_id)
        if reader is not None:
            x, y = reader.get_range(xMin, xMax, max_points=10000)
        else:
            x, y = [], []

        lines = [
            f"%% Analysis: {title}",
            f"% Generated by FastSense Bridge",
            f"% Signal: {signal_id} | {len(x)} points",
            "",
            "%% Data",
        ]

        # Embed data directly for portability (no SQLite dependency)
        if len(x) <= 5000:
            x_str = "[" + ", ".join(f"{v:.8g}" for v in x) + "]"
            y_str = "[" + ", ".join(f"{v:.8g}" for v in y) + "]"
            lines.append(f"x = {x_str};")
            lines.append(f"y = {y_str};")
        else:
            # Too large to embed — reference the SQLite file
            lines.extend([
                f"% Data too large to embed ({len(x)} pts), loading from disk:",
                f"dbPath = '{db_path}';",
                "ds = FastSenseDataStore();",
                "ds = ds.openExisting(dbPath);",
            ])
            if xMin > -1e29 or xMax < 1e29:
                lines.append(f"[x, y] = ds.getRange({xMin}, {xMax});")
            else:
                lines.append("[x, y] = ds.getRange(ds.XMin, ds.XMax);")

        lines.extend([
            "",
            f"fprintf('Loaded %d points for: {title}\\n', numel(x));",
            "",
            "%% Plot",
            f"figure('Name', '{title}', 'NumberTitle', 'off');",
            "plot(x, y, 'LineWidth', 1);",
            f"title('{title}');",
            "xlabel('Time'); ylabel('Value');",
            "grid on;",
            "",
            "%% Your analysis below",
            "",
        ])

        script = "\n".join(lines) + "\n"
        return Response(
            content=script,
            media_type="text/plain",
            headers={
                "Content-Disposition": f'attachment; filename="analyze_{signal_id}.m"',
            },
        )

    # --- Health ---

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    return app
