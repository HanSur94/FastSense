"""FastAPI server: REST API + WebSocket + static file serving.

Provides endpoints for listing signals, querying time-series data,
reading thresholds/violations, managing dashboard config, and invoking
MATLAB actions. WebSocket endpoint broadcasts real-time events from
MATLAB to connected browsers.
"""

import asyncio
import json
import uuid
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from .sqlite_reader import SqliteReader


class ActionRequest(BaseModel):
    """Request body for action invocation."""

    args: dict[str, Any] = {}


class AppState:
    """Shared state between the TCP client and the HTTP server.

    Holds the current signal list, dashboard config, action registry,
    SQLite readers, WebSocket clients, and pending action futures.
    """

    def __init__(self) -> None:
        self.signals: list[dict[str, Any]] = []
        self.dashboard: dict[str, Any] = {}
        self.actions: list[str] = []
        self.tcp_client: Any = None
        self._readers: dict[str, SqliteReader] = {}
        self._ws_clients: set[WebSocket] = set()
        self._pending_actions: dict[str, asyncio.Future[dict[str, Any]]] = {}

    def get_reader(self, signal_id: str) -> SqliteReader | None:
        """Get or create a SqliteReader for the given signal.

        Args:
            signal_id: The signal identifier.

        Returns:
            A SqliteReader instance, or None if the signal is not found.
        """
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
        for ws in self._ws_clients:
            try:
                await ws.send_json(msg)
            except Exception:
                dead.add(ws)
        self._ws_clients -= dead

    def on_matlab_message(self, msg: dict[str, Any]) -> None:
        """Handle incoming message from MATLAB (called by tcp_client).

        Dispatches based on message type: data_changed, config_changed,
        action_result, or shutdown.
        """
        msg_type = msg.get("type", "")
        if msg_type == "data_changed":
            # Close affected readers so they reopen with fresh data
            for sig_id in msg.get("signals", []):
                sig = next(
                    (s for s in self.signals if s["id"] == sig_id), None
                )
                if sig and sig.get("dbPath") in self._readers:
                    self._readers[sig["dbPath"]].close()
                    del self._readers[sig["dbPath"]]
            asyncio.create_task(self.broadcast_ws(msg))
        elif msg_type == "config_changed":
            self.dashboard = msg.get("dashboard", self.dashboard)
            if "actions" in msg:
                self.actions = msg["actions"]
            asyncio.create_task(self.broadcast_ws(msg))
        elif msg_type == "actions_changed":
            self.actions = msg.get("actions", self.actions)
            asyncio.create_task(self.broadcast_ws(msg))
        elif msg_type == "action_result":
            req_id = msg.get("id", "")
            if req_id in self._pending_actions:
                self._pending_actions[req_id].set_result(msg)
        elif msg_type == "shutdown":
            asyncio.create_task(
                self.broadcast_ws({"type": "shutdown"})
            )


def create_app(state: AppState) -> FastAPI:
    """Create the FastAPI application with all routes.

    Args:
        state: Shared application state.

    Returns:
        Configured FastAPI app instance.
    """
    app = FastAPI(title="FastPlot Bridge")

    # --- REST API ---

    @app.get("/api/signals")
    def list_signals() -> list[dict[str, str]]:
        return [
            {"id": s["id"], "title": s["title"]} for s in state.signals
        ]

    @app.get("/api/signals/{signal_id}/data")
    def get_signal_data(
        signal_id: str,
        xMin: float = -1e30,
        xMax: float = 1e30,
        maxPoints: int = 4000,
    ) -> dict[str, list[float]]:
        reader = state.get_reader(signal_id)
        if reader is None:
            raise HTTPException(404, f"Signal '{signal_id}' not found")
        x, y = reader.get_range(xMin, xMax, max_points=maxPoints)
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
        signal_id: str, col_name: str, xMin: float, xMax: float
    ) -> list:
        reader = state.get_reader(signal_id)
        if reader is None:
            raise HTTPException(404, f"Signal '{signal_id}' not found")
        return reader.get_column(col_name, xMin, xMax)

    @app.get("/api/dashboard")
    def get_dashboard() -> dict[str, Any]:
        return state.dashboard

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
                await ws.receive_text()  # keep connection alive
        except WebSocketDisconnect:
            state._ws_clients.discard(ws)

    # --- Static files ---

    # server.py is at bridge/python/fastplot_bridge/server.py
    # Go up: fastplot_bridge -> python -> bridge, then into /web
    web_dir = Path(__file__).resolve().parent.parent.parent / "web"
    if web_dir.is_dir():

        @app.get("/")
        def index() -> FileResponse:
            return FileResponse(web_dir / "index.html")

        app.mount(
            "/static",
            StaticFiles(directory=str(web_dir)),
            name="static",
        )

    return app
