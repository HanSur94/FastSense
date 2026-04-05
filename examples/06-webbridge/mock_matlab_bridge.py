#!/usr/bin/env python3
"""Mock MATLAB side for testing the WebBridge pipeline.

Simulates what MATLAB does: creates SQLite data files with live sensor
data, runs the bridge server, and pushes data_changed notifications.

Usage:
    python examples/mock_matlab_bridge.py

Then in another terminal:
    python examples/example_webbridge_dashboard.py
"""

import asyncio
import json
import math
import random
import sqlite3
import struct
import tempfile
import time
from pathlib import Path

import numpy as np
import uvicorn

from fastsense_bridge.blob_decoder import MKSQ_MAGIC
from fastsense_bridge.server import AppState, create_app


def make_double_blob(values):
    """Create a mksqlite-compatible typed BLOB from float64 array."""
    arr = np.array(values, dtype=np.float64)
    header = struct.pack("<6I", MKSQ_MAGIC, 3, 6, 2, 1, len(values))
    return header + arr.tobytes()


def create_sensor_db(db_path, x, y, thresholds=None):
    """Create a .fpdb SQLite file with chunked data and optional thresholds."""
    conn = sqlite3.connect(str(db_path))
    conn.execute("""CREATE TABLE IF NOT EXISTS chunks (
        chunk_id INTEGER PRIMARY KEY,
        x_min REAL, x_max REAL, y_min REAL, y_max REAL,
        pt_offset INTEGER, pt_count INTEGER,
        x_data BLOB, y_data BLOB
    )""")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_xrange ON chunks (x_min, x_max)")
    conn.execute("DELETE FROM chunks")
    conn.execute(
        "INSERT INTO chunks VALUES (0, ?, ?, ?, ?, 0, ?, ?, ?)",
        (min(x), max(x), min(y), max(y), len(x),
         make_double_blob(x), make_double_blob(y)),
    )

    if thresholds:
        conn.execute("""CREATE TABLE IF NOT EXISTS resolved_thresholds (
            idx INTEGER PRIMARY KEY, x_data BLOB, y_data BLOB,
            direction TEXT, label TEXT, color BLOB, line_style TEXT, value REAL
        )""")
        conn.execute("DELETE FROM resolved_thresholds")
        for i, th in enumerate(thresholds):
            conn.execute(
                "INSERT INTO resolved_thresholds VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (i, make_double_blob([min(x), max(x)]),
                 make_double_blob([th["value"], th["value"]]),
                 th["direction"], th["label"], None, "--", th["value"]),
            )

    conn.commit()
    conn.close()


async def main():
    tmp = Path(tempfile.mkdtemp(prefix="fastsense_mock_"))
    print(f"  Data dir: {tmp}")

    # Initial data
    n = 500
    t = np.linspace(-60, 0, n).tolist()

    sensors = {
        "temperature": {
            "title": "Temperature",
            "db": tmp / "temperature.fpdb",
            "y": [22 + 3 * math.sin(2 * math.pi * ti / 30) + random.gauss(0, 0.3) for ti in t],
            "thresholds": [
                {"value": 28, "direction": "upper", "label": "Hi Warn"},
                {"value": 32, "direction": "upper", "label": "Hi Alarm"},
            ],
        },
        "pressure": {
            "title": "Pressure",
            "db": tmp / "pressure.fpdb",
            "y": [4.5 + 0.5 * math.sin(2 * math.pi * ti / 20) + random.gauss(0, 0.1) for ti in t],
            "thresholds": [
                {"value": 5.5, "direction": "upper", "label": "Max"},
            ],
        },
        "vibration": {
            "title": "Vibration",
            "db": tmp / "vibration.fpdb",
            "y": [2.0 + 0.8 * random.gauss(0, 1) + 0.5 * math.sin(2 * math.pi * ti / 15) for ti in t],
            "thresholds": [
                {"value": 4.0, "direction": "upper", "label": "Alert"},
            ],
        },
    }

    # Create initial databases
    for sid, s in sensors.items():
        create_sensor_db(s["db"], t, s["y"], s["thresholds"])

    # Set up bridge state
    state = AppState()
    state.signals = [
        {"id": sid, "dbPath": str(s["db"]), "title": s["title"]}
        for sid, s in sensors.items()
    ]
    state.actions = ["recalculate", "resetAlarms", "openInMatlab"]

    app = create_app(state)
    config = uvicorn.Config(app, host="localhost", port=8080, log_level="info")
    server = uvicorn.Server(config)

    async def live_updates():
        """Simulate live data every 0.5s."""
        await asyncio.sleep(2)  # wait for server to start
        print("\n  Live data streaming started (0.5s interval)")
        while True:
            await asyncio.sleep(0.5)
            t.append(t[-1] + 0.5)
            ti = t[-1]
            for sid, s in sensors.items():
                if sid == "temperature":
                    s["y"].append(22 + 3 * math.sin(2 * math.pi * ti / 30) + random.gauss(0, 0.3))
                elif sid == "pressure":
                    s["y"].append(4.5 + 0.5 * math.sin(2 * math.pi * ti / 20) + random.gauss(0, 0.1))
                else:
                    s["y"].append(2.0 + 0.8 * random.gauss(0, 1) + 0.5 * math.sin(2 * math.pi * ti / 15))

                # Rewrite the SQLite file
                create_sensor_db(s["db"], t[-500:], s["y"][-500:], s["thresholds"])

                # Remove cached reader so next query reopens with fresh data
                state._readers.pop(str(s["db"]), None)

            # Broadcast to WebSocket clients
            await state.broadcast_ws({
                "type": "data_changed",
                "signals": list(sensors.keys()),
            })

    print()
    print("=" * 50)
    print("  FastSense Mock Bridge")
    print("=" * 50)
    print(f"  Signals: {', '.join(sensors.keys())}")
    print(f"  Actions: {', '.join(state.actions)}")
    print()
    print("  Now run in another terminal:")
    print("    python examples/example_webbridge_dashboard.py")
    print()

    await asyncio.gather(server.serve(), live_updates())


if __name__ == "__main__":
    asyncio.run(main())
