"""Tests for the async NDJSON TCP client."""

import asyncio
import json

import pytest
import pytest_asyncio

from fastsense_bridge.tcp_client import MatlabTcpClient


@pytest_asyncio.fixture
async def mock_matlab_server():
    """A mock MATLAB TCP server that sends an init message on connect."""
    init_msg = json.dumps(
        {
            "type": "init",
            "signals": [
                {"id": "s1", "dbPath": "/tmp/test.fpdb", "title": "Temp"}
            ],
            "dashboard": {"name": "Test", "theme": "light", "widgets": []},
            "actions": ["recalc"],
        }
    )

    received: list[str] = []

    async def handle_client(
        reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) -> None:
        writer.write((init_msg + "\n").encode())
        await writer.drain()
        try:
            while True:
                line = await reader.readline()
                if not line:
                    break
                received.append(line.decode().strip())
        except asyncio.CancelledError:
            pass
        finally:
            writer.close()

    server = await asyncio.start_server(handle_client, "localhost", 0)
    port = server.sockets[0].getsockname()[1]
    yield server, port, received
    server.close()
    await server.wait_closed()


class TestMatlabTcpClient:
    """Tests for MatlabTcpClient connection and messaging."""

    @pytest.mark.asyncio
    async def test_connect_receives_init(
        self, mock_matlab_server: tuple
    ) -> None:
        _server, port, _ = mock_matlab_server
        client = MatlabTcpClient("localhost", port)

        init_msg = await client.connect()
        assert init_msg["type"] == "init"
        assert len(init_msg["signals"]) == 1
        assert init_msg["signals"][0]["id"] == "s1"
        assert init_msg["dashboard"]["name"] == "Test"
        assert init_msg["actions"] == ["recalc"]
        await client.close()

    @pytest.mark.asyncio
    async def test_send_action(self, mock_matlab_server: tuple) -> None:
        _server, port, received = mock_matlab_server
        client = MatlabTcpClient("localhost", port)
        await client.connect()

        await client.send_action("req-1", "recalc", {"x": 1})
        await asyncio.sleep(0.1)

        assert len(received) == 1
        msg = json.loads(received[0])
        assert msg["type"] == "action"
        assert msg["id"] == "req-1"
        assert msg["name"] == "recalc"
        assert msg["args"] == {"x": 1}
        await client.close()

    @pytest.mark.asyncio
    async def test_send_bridge_ready(
        self, mock_matlab_server: tuple
    ) -> None:
        _server, port, received = mock_matlab_server
        client = MatlabTcpClient("localhost", port)
        await client.connect()

        await client.send_bridge_ready(8080)
        await asyncio.sleep(0.1)

        assert len(received) == 1
        msg = json.loads(received[0])
        assert msg["type"] == "bridge_ready"
        assert msg["httpPort"] == 8080
        await client.close()

    @pytest.mark.asyncio
    async def test_send_not_connected_raises(self) -> None:
        client = MatlabTcpClient("localhost", 0)
        with pytest.raises(ConnectionError, match="Not connected"):
            await client.send_action("req-1", "test", {})

    @pytest.mark.asyncio
    async def test_message_callback(
        self, mock_matlab_server: tuple
    ) -> None:
        _server, port, _ = mock_matlab_server
        client = MatlabTcpClient("localhost", port)
        await client.connect()

        messages: list[dict] = []
        client.on_message = lambda msg: messages.append(msg)
        assert client.on_message is not None
        await client.close()

    @pytest.mark.asyncio
    async def test_listening_receives_messages(self) -> None:
        """Test that start_listening dispatches messages to on_message."""
        messages: list[dict] = []

        async def handle_client(
            reader: asyncio.StreamReader, writer: asyncio.StreamWriter
        ) -> None:
            # Send init
            init = json.dumps({"type": "init", "signals": [],
                              "dashboard": {}, "actions": []})
            writer.write((init + "\n").encode())
            await writer.drain()
            # Send a data_changed message
            update = json.dumps(
                {"type": "data_changed", "signals": ["s1"]}
            )
            writer.write((update + "\n").encode())
            await writer.drain()
            # Wait a bit then close
            await asyncio.sleep(0.2)
            writer.close()

        server = await asyncio.start_server(
            handle_client, "localhost", 0
        )
        port = server.sockets[0].getsockname()[1]

        client = MatlabTcpClient("localhost", port)
        await client.connect()
        client.on_message = lambda msg: messages.append(msg)
        client.start_listening()

        await asyncio.sleep(0.3)
        await client.close()
        server.close()
        await server.wait_closed()

        assert len(messages) == 1
        assert messages[0]["type"] == "data_changed"
        assert messages[0]["signals"] == ["s1"]
