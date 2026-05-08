---
phase: quick-260508-bxh
plan: 01
subsystem: WebBridge / FastAPI bridge server
tags: [security, cors, websocket, fastapi, python]
requires:
  - bridge/python/fastsense_bridge/server.py
  - quick-260508-bju (HTTP CORS lock-down — this task closes the WS gap left behind)
provides:
  - resolve_cors_policy() helper (single source of truth for HTTP + WS origin policy)
  - CorsPolicy frozen dataclass (mode + regex + origins)
  - is_origin_allowed(policy, origin) helper with documented edge cases
  - /ws endpoint origin gate (close 1008 before accept on violation)
affects:
  - bridge/python/fastsense_bridge/server.py
  - bridge/python/tests/test_server.py
tech-stack:
  added: []
  patterns:
    - "Shared policy dataclass consumed by both ASGI middleware setup and the WS handler — env-var parsing happens exactly once per create_app() call."
    - "WS origin gate runs before await ws.accept(), producing a handshake-time HTTP 403 that surfaces as WebSocketDisconnect(code=1008) on the client."
key-files:
  created: []
  modified:
    - bridge/python/fastsense_bridge/server.py
    - bridge/python/tests/test_server.py
decisions:
  - "Wildcard warning lives inside resolve_cors_policy() (called once from create_app), preserving the existing test_wildcard_logs_warning behavior — exactly one WARNING record per create_app() call."
  - "Missing Origin header is rejected under regex and list modes; only wildcard mode permits None. Real browsers always send Origin on WS upgrades, so absence implies a non-browser client which is out of scope for the default localhost policy."
  - "Capture the resolved policy in create_app's enclosing scope and reuse it from /ws — do NOT recompute per WS connection (would re-emit the wildcard warning and duplicate parsing)."
metrics:
  duration: "~2m"
  completed: 2026-05-08
  tasks: 1
  files: 2
---

# Quick Task 260508-bxh: Gate WebSocket /ws with Same Origin Policy as HTTP CORS — Summary

Gate the FastAPI WebSocket `/ws` endpoint with the same origin policy that controls HTTP CORS by extracting a shared `resolve_cors_policy()` helper and rejecting disallowed origins with close code 1008 before accepting the upgrade.

## What Was Built

### Shared CORS policy

Added at module scope in `bridge/python/fastsense_bridge/server.py`:

- `CorsPolicy` — frozen dataclass with `mode: Literal["regex", "wildcard", "list"]`, optional `regex`, and `origins` tuple.
- `resolve_cors_policy()` — reads `FASTSENSE_BRIDGE_CORS_ORIGINS` and returns the resolved policy. Logs the wildcard warning here so it fires exactly once per `create_app()` call.
- `is_origin_allowed(policy, origin)` — pure predicate. Wildcard mode allows any origin including `None`; regex/list modes reject `None` and check `re.fullmatch` / `in` respectively.

### create_app() refactor

Replaced the inline env-var parsing block with a single `policy = resolve_cors_policy()` call followed by a small switch that wires `CORSMiddleware`. HTTP CORS behavior is unchanged — every existing `TestCORSPolicy` assertion still passes.

### /ws endpoint origin gate

The endpoint now reads `ws.headers.get("origin")`, checks `is_origin_allowed(policy, origin)`, and on violation calls `await ws.close(code=1008)` BEFORE `await ws.accept()`. The captured `policy` is reused from the enclosing `create_app` scope so the wildcard warning is not re-emitted per connection.

## Test Count Delta

- **+5 tests** in new `TestWebSocketOriginPolicy` class:
  - `test_default_allows_localhost_origin`
  - `test_default_blocks_foreign_origin` (asserts WebSocketDisconnect code 1008)
  - `test_default_blocks_missing_origin` (asserts WebSocketDisconnect code 1008)
  - `test_env_override_list_allows_listed_origin`
  - `test_wildcard_allows_any_origin_including_missing` (incl. missing Origin)
- **0 modifications** to `TestCORSPolicy` — all 4 existing tests still pass unchanged.
- Full suite: **35 passed in 41.27s** (was 30 before this task).

## TDD Trace

1. **RED** — `test(quick-260508-bxh-01)`: added `TestWebSocketOriginPolicy` class first; pytest reported 3 failures (the rejection cases — the unguarded `/ws` accepted everything).
2. **GREEN** — `feat(quick-260508-bxh-01)`: extracted `resolve_cors_policy()` + `is_origin_allowed()`, refactored `create_app()` to use the policy, and added the origin gate to `/ws`. All 35 tests passed.

No REFACTOR commit — the GREEN implementation is already structured per the plan.

## Verification Run

```
cd bridge/python && python -m pytest tests/test_server.py -v
============================= 35 passed in 41.27s ==============================
```

Specific gates verified:
- `TestCORSPolicy` (4/4) — HTTP CORS unchanged.
- `test_wildcard_logs_warning` — single WARNING record per `create_app()` confirmed.
- `TestWebSocketOriginPolicy` (5/5) — every WS upgrade case from `must_haves.truths` passes.

## Deviations from Plan

None — plan executed exactly as written.

## Commits

- `43ec9dd` — `test(quick-260508-bxh-01): add failing tests for /ws origin gate`
- `e1aeebc` — `feat(quick-260508-bxh-01): gate /ws upgrade with shared origin policy`

## Self-Check: PASSED

- `bridge/python/fastsense_bridge/server.py` — FOUND (modified)
- `bridge/python/tests/test_server.py` — FOUND (modified, +85 lines, +5 tests, +1 import)
- Commit `43ec9dd` — FOUND in `git log`
- Commit `e1aeebc` — FOUND in `git log`
- `resolve_cors_policy` — FOUND in server.py
- `is_origin_allowed` — FOUND in server.py
- `close(code=1008)` — FOUND in server.py /ws endpoint
- `TestWebSocketOriginPolicy` — FOUND in test_server.py
