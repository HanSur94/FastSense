"""Tests for the FastAPI bridge server REST API."""

import asyncio
import sqlite3
import struct
from pathlib import Path
from typing import Any
from unittest.mock import AsyncMock, MagicMock

import numpy as np
import pytest
from fastapi.testclient import TestClient

from fastsense_bridge.blob_decoder import MKSQ_MAGIC
from fastsense_bridge.server import AppState, create_app


def _make_double_blob(values: list[float]) -> bytes:
    """Build a typed BLOB with double (float64) data."""
    arr = np.array(values, dtype=np.float64)
    header = struct.pack("<6I", MKSQ_MAGIC, 3, 6, 2, 1, len(values))
    return header + arr.tobytes()


def _make_char_blob(text: str) -> bytes:
    """Build a typed BLOB with char data."""
    encoded = text.encode("latin-1")
    header = struct.pack("<6I", MKSQ_MAGIC, 3, 100, 2, 1, len(encoded))
    return header + encoded


@pytest.fixture
def sample_db(tmp_path: Path) -> Path:
    """Create a minimal .fpdb with chunks, thresholds, violations, and columns."""
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
    conn.execute(
        "INSERT INTO resolved_thresholds VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (0, _make_double_blob([0.0, 10.0]), _make_double_blob([0.5, 0.5]),
         "upper", "limit", None, "-", 0.5),
    )
    conn.execute("""CREATE TABLE resolved_violations (
        idx INTEGER PRIMARY KEY, x_data BLOB, y_data BLOB,
        direction TEXT NOT NULL, label TEXT NOT NULL
    )""")
    conn.execute(
        "INSERT INTO resolved_violations VALUES (?, ?, ?, ?, ?)",
        (0, _make_double_blob([3.0, 7.0]), _make_double_blob([0.6, 0.7]),
         "upper", "limit"),
    )
    # Extra columns table
    conn.execute("""CREATE TABLE columns (
        col_name TEXT NOT NULL, pt_offset INTEGER NOT NULL,
        col_data BLOB NOT NULL
    )""")
    conn.execute(
        "INSERT INTO columns VALUES (?, ?, ?)",
        ("labels", 0, _make_char_blob("ABCDE")),
    )
    conn.commit()
    conn.close()
    return db_path


@pytest.fixture
def app_state(sample_db: Path) -> AppState:
    """Create an AppState with one signal and a mocked TCP client."""
    state = AppState()
    state.signals = [
        {"id": "s1", "dbPath": str(sample_db), "title": "Temperature"},
    ]
    state.actions = ["recalc"]
    state.tcp_client = MagicMock()
    state.tcp_client.send_action = AsyncMock()
    return state


@pytest.fixture
def client(app_state: AppState) -> TestClient:
    """Create a FastAPI TestClient with the mocked state."""
    app = create_app(app_state)
    return TestClient(app)


class TestSignalsAPI:
    """Tests for signal-related API endpoints."""

    def test_get_signals(self, client: TestClient) -> None:
        resp = client.get("/api/signals")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["id"] == "s1"
        assert data[0]["title"] == "Temperature"

    def test_get_signal_data(self, client: TestClient) -> None:
        resp = client.get("/api/signals/s1/data?xMin=0&xMax=10")
        assert resp.status_code == 200
        data = resp.json()
        assert "x" in data
        assert "y" in data
        assert len(data["x"]) == 100
        assert len(data["y"]) == 100

    def test_get_signal_data_with_max_points(self, client: TestClient) -> None:
        resp = client.get("/api/signals/s1/data?xMin=0&xMax=10&maxPoints=20")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["x"]) <= 20
        assert len(data["y"]) <= 20

    def test_get_signal_data_binary_format(self, client: TestClient) -> None:
        resp = client.get("/api/signals/s1/data?xMin=0&xMax=10&fmt=binary")
        assert resp.status_code == 200
        assert resp.headers["content-type"] == "application/octet-stream"
        content = resp.content
        n_points = struct.unpack("<I", content[:4])[0]
        assert n_points == 100
        expected_size = 4 + n_points * 8 * 2  # header + x + y as float64
        assert len(content) == expected_size

    def test_get_signal_not_found(self, client: TestClient) -> None:
        resp = client.get("/api/signals/nonexistent/data?xMin=0&xMax=10")
        assert resp.status_code == 404

    def test_get_thresholds(self, client: TestClient) -> None:
        resp = client.get("/api/signals/s1/thresholds")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        assert len(data) == 1
        assert data[0]["label"] == "limit"

    def test_get_thresholds_not_found(self, client: TestClient) -> None:
        resp = client.get("/api/signals/nonexistent/thresholds")
        assert resp.status_code == 404

    def test_get_violations(self, client: TestClient) -> None:
        resp = client.get("/api/signals/s1/violations")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        assert len(data) == 1

    def test_get_violations_not_found(self, client: TestClient) -> None:
        resp = client.get("/api/signals/nonexistent/violations")
        assert resp.status_code == 404

    def test_get_column(self, client: TestClient) -> None:
        resp = client.get("/api/signals/s1/columns/labels?xMin=0&xMax=10")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        assert "".join(data) == "ABCDE"

    def test_get_column_not_found(self, client: TestClient) -> None:
        resp = client.get("/api/signals/nonexistent/columns/labels?xMin=0&xMax=10")
        assert resp.status_code == 404

    def test_bulk_signal_data(self, client: TestClient) -> None:
        resp = client.post(
            "/api/signals/bulk",
            json={"signals": ["s1"], "xMin": 0, "xMax": 10, "maxPoints": 50},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "s1" in data
        assert len(data["s1"]["x"]) <= 50

    def test_bulk_signal_data_unknown_skipped(self, client: TestClient) -> None:
        resp = client.post(
            "/api/signals/bulk",
            json={"signals": ["s1", "nonexistent"], "xMin": 0, "xMax": 10},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "s1" in data
        assert "nonexistent" not in data


class TestActionsAPI:
    """Tests for action endpoints."""

    def test_get_actions(self, client: TestClient) -> None:
        resp = client.get("/api/actions")
        assert resp.status_code == 200
        data = resp.json()
        assert "recalc" in data

    def test_post_action_sends_to_matlab(
        self, client: TestClient, app_state: AppState
    ) -> None:
        # The mock doesn't resolve the future, so this hits the timeout path
        resp = client.post("/api/actions/recalc", json={})
        assert resp.status_code == 200
        app_state.tcp_client.send_action.assert_called_once()

    def test_post_action_success_path(
        self, client: TestClient, app_state: AppState
    ) -> None:
        """Test action invocation when MATLAB responds successfully."""
        original_send = app_state.tcp_client.send_action

        async def send_and_resolve(req_id: str, name: str, args: dict) -> None:
            await original_send(req_id, name, args)
            # Simulate MATLAB responding with success
            if req_id in app_state._pending_actions:
                app_state._pending_actions[req_id].set_result(
                    {"ok": True, "name": name, "id": req_id}
                )

        app_state.tcp_client.send_action = AsyncMock(side_effect=send_and_resolve)
        resp = client.post("/api/actions/recalc", json={"args": {"x": 42}})
        assert resp.status_code == 200
        data = resp.json()
        assert data["ok"] is True
        assert data["name"] == "recalc"

    def test_post_unknown_action(self, client: TestClient) -> None:
        resp = client.post("/api/actions/nonexistent", json={})
        assert resp.status_code == 404


class TestAppState:
    """Tests for AppState methods."""

    def test_get_reader_returns_reader(self, app_state: AppState) -> None:
        reader = app_state.get_reader("s1")
        assert reader is not None
        reader.close()

    def test_get_reader_unknown_signal_returns_none(
        self, app_state: AppState
    ) -> None:
        assert app_state.get_reader("nonexistent") is None

    def test_get_reader_caches(self, app_state: AppState) -> None:
        r1 = app_state.get_reader("s1")
        r2 = app_state.get_reader("s1")
        assert r1 is r2
        app_state.close_readers()

    def test_close_readers(self, app_state: AppState) -> None:
        app_state.get_reader("s1")
        assert len(app_state._readers) == 1
        app_state.close_readers()
        assert len(app_state._readers) == 0


class TestMatlabIntegration:
    """Tests for MATLAB integration endpoints."""

    def test_open_in_matlab_no_action_registered(
        self, client: TestClient, app_state: AppState
    ) -> None:
        # openInMatlab is not in the actions list
        resp = client.post("/api/open-in-matlab/s1?xMin=0&xMax=10")
        assert resp.status_code == 503

    def test_open_in_matlab_sends_action(
        self, client: TestClient, app_state: AppState
    ) -> None:
        app_state.actions.append("openInMatlab")
        resp = client.post("/api/open-in-matlab/s1?xMin=2&xMax=8")
        assert resp.status_code == 200
        app_state.tcp_client.send_action.assert_called_once()
        call_args = app_state.tcp_client.send_action.call_args
        assert call_args[0][1] == "openInMatlab"
        assert call_args[0][2]["signalId"] == "s1"
        assert call_args[0][2]["xMin"] == 2.0
        assert call_args[0][2]["xMax"] == 8.0


class TestHealth:
    """Tests for health endpoint."""

    def test_health(self, client: TestClient) -> None:
        resp = client.get("/health")
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok"}
