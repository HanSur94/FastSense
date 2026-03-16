"""CLI entry point for the FastPlot bridge server.

Connects to MATLAB's TCP server, receives the init message, starts
the FastAPI HTTP/WebSocket server, and notifies MATLAB when ready.

Usage:
    fastplot-bridge --matlab-port 5555
    fastplot-bridge --matlab-port 5555 --host 0.0.0.0 --port 9090
"""

import argparse
import asyncio

import uvicorn

from .server import AppState, create_app
from .tcp_client import MatlabTcpClient


async def run(matlab_port: int, http_host: str, http_port: int) -> None:
    """Main async entry point: connect to MATLAB and start serving.

    Args:
        matlab_port: Port of the MATLAB tcpserver.
        http_host: Host to bind the HTTP server to.
        http_port: Port to bind the HTTP server to.
    """
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
    config = uvicorn.Config(
        app, host=http_host, port=http_port, log_level="info"
    )
    server = uvicorn.Server(config)

    async def notify_ready() -> None:
        """Wait until uvicorn is actually serving, then tell MATLAB."""
        while not server.started:
            await asyncio.sleep(0.05)
        await client.send_bridge_ready(http_port)

    try:
        await asyncio.gather(server.serve(), notify_ready())
    finally:
        state.close_readers()
        await client.close()


def main() -> None:
    """Parse CLI arguments and run the bridge server."""
    parser = argparse.ArgumentParser(
        description="FastPlot Bridge Server"
    )
    parser.add_argument(
        "--matlab-port",
        type=int,
        required=True,
        help="MATLAB TCP server port",
    )
    parser.add_argument(
        "--host",
        default="localhost",
        help="HTTP bind host (default: localhost)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8080,
        help="HTTP port (default: 8080)",
    )
    args = parser.parse_args()

    asyncio.run(run(args.matlab_port, args.host, args.port))


if __name__ == "__main__":
    main()
