"""Async NDJSON-over-TCP client for connecting to MATLAB's WebBridge.

Handles the bidirectional communication protocol: connects to the MATLAB
tcpserver, reads the init message, listens for incoming NDJSON messages,
and sends action invocations and bridge_ready notifications.
"""

import asyncio
import json
from collections.abc import Callable
from typing import Any


class MatlabTcpClient:
    """Connects to MATLAB's tcpserver and exchanges NDJSON messages.

    Usage:
        client = MatlabTcpClient("localhost", 5555)
        init_msg = await client.connect()
        client.on_message = handle_message
        client.start_listening()
        await client.send_bridge_ready(8080)
        ...
        await client.close()
    """

    def __init__(self, host: str, port: int) -> None:
        self._host = host
        self._port = port
        self._reader: asyncio.StreamReader | None = None
        self._writer: asyncio.StreamWriter | None = None
        self._listen_task: asyncio.Task[None] | None = None
        self.on_message: Callable[[dict[str, Any]], None] | None = None

    async def connect(self) -> dict[str, Any]:
        """Connect to MATLAB and return the init message.

        The first message sent by MATLAB on connect is always the init
        message containing signals, dashboard config, and actions.

        Returns:
            Parsed init message as a dict.
        """
        self._reader, self._writer = await asyncio.open_connection(
            self._host, self._port
        )
        # First message from MATLAB is always the init
        line = await self._reader.readline()
        return json.loads(line.decode().strip())

    def start_listening(self) -> None:
        """Start background task to receive messages from MATLAB."""
        self._listen_task = asyncio.create_task(self._listen_loop())

    async def _listen_loop(self) -> None:
        """Read NDJSON lines and dispatch to on_message callback."""
        try:
            while self._reader and not self._reader.at_eof():
                line = await self._reader.readline()
                if not line:
                    break
                msg = json.loads(line.decode().strip())
                if self.on_message:
                    self.on_message(msg)
        except (asyncio.CancelledError, ConnectionError):
            pass

    async def send_action(
        self, request_id: str, name: str, args: dict[str, Any]
    ) -> None:
        """Send an action invocation to MATLAB.

        Args:
            request_id: Client-generated request ID for response correlation.
            name: Name of the registered action.
            args: Action arguments as a dict.
        """
        msg = {
            "type": "action",
            "id": request_id,
            "name": name,
            "args": args,
        }
        await self._send(msg)

    async def send_bridge_ready(self, http_port: int) -> None:
        """Tell MATLAB the bridge HTTP server is ready.

        Args:
            http_port: The port the HTTP server is listening on.
        """
        await self._send({"type": "bridge_ready", "httpPort": http_port})

    async def _send(self, msg: dict[str, Any]) -> None:
        """Send a single NDJSON message."""
        if self._writer is None:
            raise ConnectionError("Not connected")
        data = json.dumps(msg) + "\n"
        self._writer.write(data.encode())
        await self._writer.drain()

    async def close(self) -> None:
        """Cancel listener and close the TCP connection."""
        if self._listen_task:
            self._listen_task.cancel()
            try:
                await self._listen_task
            except asyncio.CancelledError:
                pass
        if self._writer:
            self._writer.close()
            try:
                await self._writer.wait_closed()
            except Exception:
                pass
