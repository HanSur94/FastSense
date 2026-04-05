#!/usr/bin/env python3
"""Simple Python dashboard that consumes live data from MATLAB via WebBridge.

Demonstrates the full pipeline:
  MATLAB (live sensors) → WebBridge (REST API) → Python (matplotlib dashboard)

Prerequisites:
  1. Start the MATLAB side first:
       >> example_webbridge
  2. pip install matplotlib requests websockets

Usage:
  python examples/06-webbridge/example_webbridge_dashboard.py

The dashboard:
  - Fetches all available signals from the bridge
  - Plots each signal with thresholds
  - Auto-refreshes every 2 seconds via WebSocket push notifications
  - Press 'r' to trigger MATLAB recalculation
  - Press 'm' to open the selected signal in MATLAB (exports .mat)
  - Close the window to exit
"""

import sys
import json
import threading

import requests
import matplotlib
matplotlib.use("TkAgg")
import matplotlib.pyplot as plt
from matplotlib.widgets import Button

BRIDGE_URL = "http://localhost:8080"
WS_URL = "ws://localhost:8080/ws"


def fetch_signals():
    """Get list of available signals from the bridge."""
    resp = requests.get(f"{BRIDGE_URL}/api/signals", timeout=5)
    resp.raise_for_status()
    return resp.json()


def fetch_signal_data(signal_id, max_points=2000):
    """Fetch time series data for a signal."""
    resp = requests.get(
        f"{BRIDGE_URL}/api/signals/{signal_id}/data",
        params={"maxPoints": max_points},
        timeout=5,
    )
    resp.raise_for_status()
    return resp.json()


def fetch_thresholds(signal_id):
    """Fetch threshold lines for a signal."""
    resp = requests.get(
        f"{BRIDGE_URL}/api/signals/{signal_id}/thresholds",
        timeout=5,
    )
    resp.raise_for_status()
    return resp.json()


def fetch_bulk(signal_ids, max_points=2000):
    """Fetch multiple signals in one request."""
    resp = requests.post(
        f"{BRIDGE_URL}/api/signals/bulk",
        json={"signals": signal_ids, "maxPoints": max_points},
        timeout=5,
    )
    resp.raise_for_status()
    return resp.json()


def invoke_action(name, args=None):
    """Invoke a MATLAB action via the bridge."""
    resp = requests.post(
        f"{BRIDGE_URL}/api/actions/{name}",
        json={"args": args or {}},
        timeout=35,
    )
    resp.raise_for_status()
    return resp.json()


def open_in_matlab(signal_id, x_min=None, x_max=None):
    """Export signal data to .mat and open analysis script in MATLAB."""
    params = {}
    if x_min is not None:
        params["xMin"] = x_min
    if x_max is not None:
        params["xMax"] = x_max
    resp = requests.post(
        f"{BRIDGE_URL}/api/open-in-matlab/{signal_id}",
        params=params,
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json()


def start_ws_listener(on_update):
    """Listen for WebSocket push notifications in a background thread."""
    try:
        import websockets.sync.client as ws_sync
    except ImportError:
        print("  [WS] websockets not installed, using polling instead")
        return None

    def listen():
        try:
            with ws_sync.connect(WS_URL) as ws:
                print("  [WS] Connected — receiving live updates")
                for msg_text in ws:
                    msg = json.loads(msg_text)
                    if msg.get("type") == "data_changed":
                        on_update(msg.get("signals", []))
                    elif msg.get("type") == "shutdown":
                        print("  [WS] MATLAB shutting down")
                        break
        except Exception as e:
            print(f"  [WS] Disconnected: {e}")

    t = threading.Thread(target=listen, daemon=True)
    t.start()
    return t


class Dashboard:
    """Simple matplotlib dashboard with live updates."""

    def __init__(self):
        # Fetch available signals
        self.signals = fetch_signals()
        if not self.signals:
            print("No signals available. Is the MATLAB example running?")
            sys.exit(1)

        self.signal_ids = [s["id"] for s in self.signals]
        self.n = len(self.signals)

        # Create figure
        self.fig, self.axes = plt.subplots(
            self.n, 1, figsize=(12, 3 * self.n),
            sharex=True, squeeze=False,
        )
        self.fig.suptitle("FastSense Live Dashboard (Python)", fontsize=14)
        self.fig.canvas.manager.set_window_title("FastSense WebBridge Dashboard")

        self.lines = {}
        self.threshold_lines = {}

        # Initial plot
        self.refresh_all()

        # Buttons
        ax_recalc = self.fig.add_axes([0.7, 0.01, 0.12, 0.03])
        self.btn_recalc = Button(ax_recalc, "Recalculate")
        self.btn_recalc.on_clicked(lambda _: self.on_recalculate())

        ax_matlab = self.fig.add_axes([0.84, 0.01, 0.14, 0.03])
        self.btn_matlab = Button(ax_matlab, "Open in MATLAB")
        self.btn_matlab.on_clicked(lambda _: self.on_open_matlab())

        self.fig.subplots_adjust(bottom=0.08, hspace=0.3)

        # Key bindings
        self.fig.canvas.mpl_connect("key_press_event", self.on_key)

        # Start WebSocket listener for live updates
        self._pending_update = False
        start_ws_listener(self.on_ws_update)

        # Fallback polling timer (in case WS is not available)
        self._timer = self.fig.canvas.new_timer(interval=3000)
        self._timer.add_callback(self.poll_update)
        self._timer.start()

    def refresh_all(self):
        """Fetch and plot all signals."""
        bulk = fetch_bulk(self.signal_ids)
        for i, sig in enumerate(self.signals):
            sid = sig["id"]
            ax = self.axes[i, 0]
            data = bulk.get(sid, {"x": [], "y": []})

            if sid not in self.lines:
                # First draw
                line, = ax.plot(data["x"], data["y"], linewidth=0.8)
                self.lines[sid] = line
                ax.set_ylabel(sig["title"])
                ax.grid(True, alpha=0.3)

                # Draw thresholds
                try:
                    thresholds = fetch_thresholds(sid)
                    for th in thresholds:
                        ax.axhline(
                            y=th["value"],
                            color="red" if "alarm" in th["label"].lower() else "orange",
                            linestyle="--", linewidth=0.8, alpha=0.7,
                            label=th["label"],
                        )
                    if thresholds:
                        ax.legend(loc="upper right", fontsize=7)
                except Exception:
                    pass
            else:
                # Update existing
                self.lines[sid].set_xdata(data["x"])
                self.lines[sid].set_ydata(data["y"])
                ax.relim()
                ax.autoscale_view()

        self.axes[-1, 0].set_xlabel("Time (s)")
        self.fig.canvas.draw_idle()

    def on_ws_update(self, signal_ids):
        """Called from WS thread when data changes."""
        self._pending_update = True

    def poll_update(self):
        """Check for pending updates and refresh."""
        if self._pending_update:
            self._pending_update = False
            try:
                self.refresh_all()
            except Exception as e:
                print(f"  [Update] Error: {e}")

    def on_recalculate(self):
        """Trigger MATLAB recalculation."""
        print("  Triggering recalculate...")
        try:
            result = invoke_action("recalculate")
            print(f"  Result: {result}")
            self.refresh_all()
        except Exception as e:
            print(f"  Error: {e}")

    def on_open_matlab(self):
        """Open the first signal in MATLAB."""
        sid = self.signal_ids[0]
        print(f"  Opening '{sid}' in MATLAB...")
        try:
            result = open_in_matlab(sid)
            print(f"  Result: {result}")
        except Exception as e:
            print(f"  Error: {e}")

    def on_key(self, event):
        if event.key == "r":
            self.on_recalculate()
        elif event.key == "m":
            self.on_open_matlab()

    def show(self):
        plt.show()


def main():
    print("=" * 50)
    print("  FastSense WebBridge Dashboard (Python)")
    print("=" * 50)
    print()

    # Check bridge is running
    try:
        resp = requests.get(f"{BRIDGE_URL}/health", timeout=3)
        resp.raise_for_status()
        print(f"  Bridge: {BRIDGE_URL} [OK]")
    except Exception:
        print(f"  ERROR: Bridge not reachable at {BRIDGE_URL}")
        print(f"  Start MATLAB first: >> example_webbridge")
        sys.exit(1)

    signals = fetch_signals()
    print(f"  Signals: {', '.join(s['id'] for s in signals)}")
    print()
    print("  Keys: [r] recalculate  [m] open in MATLAB")
    print()

    dashboard = Dashboard()
    dashboard.show()


if __name__ == "__main__":
    main()
