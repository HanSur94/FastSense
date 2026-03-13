# WebBridge: Live Data Access for External Tools

**Date:** 2026-03-13
**Status:** Draft

## Overview

A bidirectional communication layer that makes FastPlot data, metadata, and dashboard state accessible to web frontends in real-time while MATLAB is running. MATLAB runs a minimal TCP server; a separate bridge process (Python or Node.js) serves a REST API, WebSocket, and web UI.

## Goals

- **Live inspection**: External tools view data while MATLAB is running
- **Full data access**: Time-series data, thresholds, violations, state channels, and dashboard layout
- **Bidirectional control**: Web frontend can invoke user-registered MATLAB callbacks
- **Language-agnostic**: Bridge server works in Python (FastAPI) or Node.js (Express)
- **Explicit opt-in**: Data is served only when the user calls `.serve()`

## Requirements

- **Minimum MATLAB version:** R2021a (for `tcpserver`)
- **Same-host only:** Bridge server must run on the same machine as MATLAB (shared filesystem access to SQLite file)

## Non-Goals

- Arbitrary MATLAB eval from the browser
- User authentication (localhost-only by default)
- Editing dashboard layout from the browser
- Persistent web-side state
- Remote/cross-machine bridge deployment (future consideration)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      MATLAB                             │
│                                                         │
│  Dashboard / Sensor / DataStore                         │
│       │                                                 │
│       ▼                                                 │
│  WebBridge  ◄──── tcpserver (NDJSON-over-TCP) ───┐     │
│  - publishes data, config, actions list           │     │
│  - receives action invocations                    │     │
│  - reads from SQLite for bulk data                │     │
└───────────────────────────────────────────────────┼─────┘
                                                    │
                                             TCP (auto port)
                                                    │
┌───────────────────────────────────────────────────┼─────┐
│                  Bridge Server                    │     │
│              (Python or Node.js)                  │     │
│                                                   │     │
│  TCP Client ──────────────────────────────────────┘     │
│       │                                                 │
│       ├── REST API  (/api/signals, /api/dashboard, ...) │
│       ├── WebSocket (real-time push to browser)         │
│       └── SQLite Reader (bulk data queries)             │
│                                                         │
│  Static File Server (serves the web UI)                 │
└─────────────────────┬───────────────────────────────────┘
                      │
               HTTP (auto port) + WS
                      │
┌─────────────────────▼───────────────────────────────────┐
│                   Browser                               │
│                                                         │
│  Web UI (vanilla JS + uPlot)                            │
│  - Chart viewer (zoom/pan)                              │
│  - Dashboard layout                                     │
│  - Action buttons (invoke MATLAB callbacks)             │
└─────────────────────────────────────────────────────────┘
```

### Two Data Paths

1. **Control path (TCP):** Small messages — dashboard config, action invocations, data change notifications, registered callbacks
2. **Data path (SQLite):** Bulk time-series reads — the bridge opens the SQLite file read-only and decodes the mksqlite typed BLOB chunks directly

## MATLAB Side: WebBridge Class

### Usage

```matlab
bridge = WebBridge(dashboard);
bridge.serve();
bridge.registerAction('recalc', @() sensor.resolve());
bridge.registerAction('setRange', @(args) fp.setXLim(args.xMin, args.xMax));
bridge.stop();
```

### Responsibilities

- Starts a `tcpserver` on an auto-assigned port, bound to `localhost`
- On connect: sends initial state (dashboard config, signal list, available actions, SQLite file path)
- Pushes change notifications when data/config changes. Uses explicit `bridge.notifyDataChanged(signalId)` calls (since DataStore properties lack `SetObservable`). Dashboard config changes are detected via a lightweight poll timer that compares serialized config hashes.
- Receives action invocations, dispatches to registered callbacks
- Switches SQLite to WAL mode on `.serve()` by calling `DataStore.enableWAL()` on each DataStore (ensures the switch happens on the DataStore's own mksqlite connection). Reverts on `.stop()` via `DataStore.disableWAL()`.

### TCP Protocol (NDJSON)

Each message is a single JSON object terminated by `\n`.

```
→ Bridge connects
← {"type":"init",
   "signals":[
     {"id":"s1","dbPath":"/tmp/fp_s1.fpdb","title":"Temperature"},
     {"id":"s2","dbPath":"/tmp/fp_s2.fpdb","title":"Pressure"}
   ],
   "dashboard":{...layout config...},
   "actions":["recalc","setRange"]}

← {"type":"data_changed","signals":["s1"]}
← {"type":"config_changed","dashboard":{...layout only, no inline data...}}

→ {"type":"action","id":"req-1","name":"recalc","args":{}}
← {"type":"action_result","id":"req-1","name":"recalc","ok":true}

→ {"type":"action","id":"req-2","name":"setRange","args":{"xMin":0,"xMax":100}}
← {"type":"action_result","id":"req-2","name":"setRange","ok":true}

← {"type":"shutdown"}
```

**Protocol notes:**
- `id` field on action messages is a client-generated request ID echoed back in the result, enabling response correlation when multiple actions are in-flight
- `config_changed` sends layout/widget config only (positions, types, titles) — no inline data blobs
- JSON string values containing literal newlines are JSON-escaped (`\\n`), so NDJSON line-splitting is safe
- Maximum message size: 1 MB (dashboard configs should stay well under this)
- `error` field is present only when `ok` is false
- `data_changed` triggers a full re-fetch for the affected signals (no incremental chunk tracking — keeps the bridge simple)

## Bridge Server

A standalone process (Python or Node) connecting to MATLAB's TCP server.

### Startup

```bash
# Launched automatically by MATLAB's .serve() via system()
# Or manually:
fastplot-bridge --matlab-port 5555

# Node
npx fastplot-bridge --matlab-port 5555
```

### Components

1. **TCP Client** — Connects to MATLAB, receives NDJSON messages, maintains current state
2. **SQLite Reader** — Opens database read-only, decodes mksqlite typed BLOBs (24-byte header: magic, version, class_id, ndims, rows, cols + raw data)
3. **REST API** — see below
4. **WebSocket** — Pushes real-time events to browsers
5. **Static File Server** — Serves the web UI

### REST API

| Endpoint | Method | Description |
|---|---|---|
| `/api/signals` | GET | List available signals with metadata |
| `/api/signals/:id/data` | GET | Query data by `?xMin=&xMax=&maxPoints=N` |
| `/api/signals/:id/thresholds` | GET | Thresholds + violations |
| `/api/signals/:id/columns/:name` | GET | Extra column data |
| `/api/dashboard` | GET | Current dashboard config + layout |
| `/api/actions` | GET | List registered actions |
| `/api/actions/:name` | POST | Invoke an action with `{args: {...}}` |

### WebSocket Events

- `data_changed` — browser re-fetches affected signal data
- `config_changed` — browser rebuilds dashboard layout
- `action_result` — confirms action completed

### SQLite Reader: Typed BLOB Decoding

The mksqlite typed BLOB header (24 bytes):

```
Offset  Size  Field
0       4     magic      (0x4D4B5351 = "MKSQ")
4       4     version    (3)
8       4     class_id   (mxDOUBLE_CLASS=6, or TAG_* codes)
12      4     ndims      (number of dimensions)
16      4     rows       (first dimension size)
20      4     cols       (second dimension size)
24+     ...   raw data   (rows * cols * sizeof(type))
```

The `mksqlite.c` is part of this project (not an external dependency), so the format is stable and fully controlled.

**class_id to dtype mapping:**

| class_id | MATLAB type | Python dtype | JS typed array | Bytes/elem |
|---|---|---|---|---|
| 6 (mxDOUBLE) | double | float64 | Float64Array | 8 |
| 7 (mxSINGLE) | single | float32 | Float32Array | 4 |
| 8 (mxINT8) | int8 | int8 | Int8Array | 1 |
| 9 (mxUINT8) | uint8 | uint8 | Uint8Array | 1 |
| 10 (mxINT16) | int16 | int16 | Int16Array | 2 |
| 11 (mxUINT16) | uint16 | uint16 | Uint16Array | 2 |
| 12 (mxINT32) | int32 | int32 | Int32Array | 4 |
| 13 (mxUINT32) | uint32 | uint32 | Uint32Array | 4 |
| 14 (mxINT64) | int64 | int64 | BigInt64Array | 8 |
| 15 (mxUINT64) | uint64 | uint64 | BigUint64Array | 8 |
| 100 (TAG_CHAR) | char | str (1 byte/char) | — | 1 |
| 101 (TAG_LOGICAL) | logical | bool (1 byte/elem) | — | 1 |
| 102 (TAG_CELL) | cell | nested (length-prefixed) | — | variable |
| 103 (TAG_CATEGORICAL) | categorical | nested struct | — | variable |

For the data endpoint, X/Y chunks are always `mxDOUBLE` (class_id=6). Extra columns may use any type.

### Server-Side Downsampling

The data endpoint accepts an optional `maxPoints` query parameter (default: 4000). When the requested range contains more points than `maxPoints`, the bridge applies minmax downsampling (keep min/max per bucket) server-side before returning JSON. This matches FastPlot's existing downsampling strategy and keeps browser payloads manageable.

### Signal Identity

Signals are identified by `Sensor.Key` (a char string). For DataStore-backed widgets without a Sensor, WebBridge auto-generates a key from the widget title or a sequential ID (e.g. `"ds_1"`, `"ds_2"`).

## Web Frontend

Vanilla HTML/JS/CSS served by the bridge.

### Components

1. **Chart Viewer** — uPlot library for fast rendering of large datasets. Zoom/pan triggers data re-fetch via REST API with `maxPoints` parameter. Threshold lines and violation markers overlaid.

2. **Dashboard Layout** — Reads config from `/api/dashboard`, renders a CSS grid of widgets:
   - FastPlotWidget → Chart Viewer (uPlot)
   - KpiWidget → Big number display
   - StatusWidget → Color-coded badge
   - TableWidget → HTML table
   - GaugeWidget → SVG gauge
   - TextWidget → Static text
   - EventTimelineWidget → Horizontal bar chart
   - RawAxesWidget → Placeholder tile ("View in MATLAB") — arbitrary MATLAB rendering cannot be replicated in browser

3. **Action Panel** — Fetches `/api/actions`, renders buttons. Actions with arguments show a simple form. Invokes `POST /api/actions/:name`.

4. **Live Updates** — WebSocket connection. On `data_changed`, affected charts re-fetch their viewport. On `config_changed`, dashboard rebuilds.

### Data Flow for Chart Interaction

```
User zooms chart
  → JS computes new xMin/xMax
  → GET /api/signals/s1/data?xMin=0&xMax=100
  → Bridge reads SQLite chunks, decodes BLOBs, returns JSON
  → Chart re-renders
```

## File & Module Organization

```
libs/
  WebBridge/
    WebBridge.m              — Main MATLAB class (TCP server, action registry)
    WebBridgeProtocol.m      — NDJSON message encoding/decoding
    MksqliteBlobReader.m     — Utility to read typed BLOBs (testing/debugging)

bridge/
  python/
    fastplot_bridge/
      __init__.py
      server.py              — FastAPI app (REST + WebSocket)
      tcp_client.py          — MATLAB TCP connection
      sqlite_reader.py       — SQLite + typed BLOB decoder
      blob_decoder.py        — mksqlite 24-byte header parser
    pyproject.toml

  node/
    src/
      server.js              — Express/ws app (REST + WebSocket)
      tcp-client.js          — MATLAB TCP connection
      sqlite-reader.js       — SQLite + typed BLOB decoder
      blob-decoder.js        — mksqlite header parser
    package.json

  web/                        — Shared web frontend (served by either bridge)
    index.html
    css/
      style.css
    js/
      app.js                 — Main entry, WebSocket, routing
      chart.js               — uPlot wrapper
      dashboard.js           — Layout renderer
      widgets.js             — Widget type renderers
      actions.js             — Action panel
```

## Error Handling & Lifecycle

### Startup Sequence

1. User calls `bridge = WebBridge(dashboard); bridge.serve()` in MATLAB
2. WebBridge switches SQLite to WAL mode
3. WebBridge starts `tcpserver` on auto-assigned port, bound to localhost
4. WebBridge launches bridge server via `system()` in background, passing the TCP port
   - Unix/macOS: appends `&` to run in background
   - Windows: uses `start /B` prefix
   - If bridge executable not found, throws clear error with install instructions
5. Bridge connects to MATLAB TCP, receives `init` message
6. Bridge starts HTTP/WebSocket server on auto-assigned port
7. Bridge sends `{"type":"bridge_ready","httpPort":8080}` to MATLAB via TCP
8. MATLAB prints: `Dashboard served at http://localhost:<port>`

**Blocking behavior:** `.serve()` blocks until `bridge_ready` is received or a 10-second timeout fires. If the timeout fires, WebBridge throws: `'Bridge did not start within 10s. Check that fastplot-bridge is installed.'` Actions can be registered before or after `.serve()` — the action list is sent as part of `init` and refreshed via `config_changed` when new actions are added.

**Config change detection:** A MATLAB timer polls every 1 second, comparing a hash of the serialized dashboard config. Configurable via `WebBridge('ConfigPollInterval', N)`.

### Clean Shutdown

1. User calls `bridge.stop()` or MATLAB sends `{"type":"shutdown"}`
2. Bridge closes WebSocket connections, HTTP server, TCP client
3. MATLAB stops `tcpserver`, reverts SQLite to non-WAL mode (`PRAGMA journal_mode = DELETE`)

### MATLAB Exits Unexpectedly

- Bridge detects TCP disconnect, enters "stale" mode
- Web UI shows "MATLAB disconnected" banner
- Data still viewable (SQLite file exists) but actions disabled
- Bridge auto-exits after configurable timeout (default 60s)

### Bridge Crashes

- MATLAB detects TCP client disconnect via `tcpserver` callback
- WebBridge emits warning: `'Bridge disconnected. Call bridge.serve() to restart.'`
- MATLAB data continues working normally

### Multiple Browser Clients

The bridge supports multiple simultaneous WebSocket connections. All connected browsers receive the same real-time events. Action invocations are serialized (one at a time) to avoid conflicts.

### Action Execution Model

MATLAB is single-threaded. Action callbacks execute on the MATLAB event queue (like timer callbacks). While an action runs:
- Further TCP messages are buffered by the OS
- The bridge queues additional action requests and processes them sequentially
- Actions have a default timeout of 30 seconds; if exceeded, the bridge returns `{"ok":false,"error":"timeout"}` to the browser
- Long-running actions should be designed to return quickly and use MATLAB timers for async work

### Action Errors

- If a MATLAB callback throws, WebBridge catches and sends `{"type":"action_result","id":"...","name":"...","ok":false,"error":"..."}`
- Bridge forwards to browser as a notification

## SQLite Configuration for Concurrent Access

Each `FastPlotDataStore` gains two methods: `enableWAL()` and `disableWAL()`. These run on the DataStore's own mksqlite connection (ensuring no connection ownership conflicts):

**`enableWAL()`** — called by WebBridge on `.serve()`:
```sql
PRAGMA journal_mode = WAL;           -- allow concurrent readers
PRAGMA locking_mode = NORMAL;        -- release locks between transactions
-- keep existing: cache_size, mmap_size, page_size
```

**`disableWAL()`** — called by WebBridge on `.stop()`:
```sql
PRAGMA journal_mode = DELETE;
PRAGMA locking_mode = EXCLUSIVE;
```

WebBridge iterates all DataStores referenced by dashboard widgets and calls `enableWAL()` / `disableWAL()` on each.

## Security

- TCP server and HTTP server bound to `localhost` by default
- Optional auth token: generated as a random UUID by MATLAB on `.serve()`, printed to console. Bridge receives it as a CLI argument. Browser must include it as `Authorization: Bearer <token>` header on API requests.
- When no auth token is configured, any local process can invoke actions. Use the auth token on shared machines.
- No arbitrary MATLAB eval — only registered callbacks can be invoked

## Known Limitations

- **Same-host only:** Bridge must run on the same machine as MATLAB to access the SQLite file. Cross-machine access would require streaming data over TCP instead of direct SQLite reads (future work).
- **RawAxesWidget:** Cannot be rendered in the browser — shown as a placeholder tile.
- **WAL mode on crash:** If MATLAB crashes without calling `.stop()`, the SQLite file remains in WAL mode. This is harmless — SQLite handles WAL recovery gracefully on next open.
