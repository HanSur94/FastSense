---
quick_id: 260508-bju
type: summary
subsystem: WebBridge
tags: [security, cors, fastapi, bridge]
one_liner: "Lock WebBridge HTTP CORS to localhost-only with FASTSENSE_BRIDGE_CORS_ORIGINS env-var override and gated wildcard escape hatch"
requires: []
provides:
  - "Localhost-only CORS default for /api/* and /health"
  - "FASTSENSE_BRIDGE_CORS_ORIGINS env var (CSV list or literal '*')"
  - "Startup WARNING when wildcard CORS is enabled"
affects:
  - "bridge/python/fastsense_bridge/server.py: create_app() CORS middleware config"
tech_stack_added: []
patterns:
  - "Env-var-driven security policy read inside create_app()"
  - "Three-branch CORS config: regex default | wildcard+warn | exact-list"
key_files_created:
  - none
key_files_modified:
  - bridge/python/fastsense_bridge/server.py
  - bridge/python/tests/test_server.py
decisions:
  - "Default origins via allow_origin_regex=^https?://(localhost|127.0.0.1)(:\\d+)?$ (locked in CONTEXT.md D-01)"
  - "FASTSENSE_BRIDGE_CORS_ORIGINS env var is single source of override; comma-separated; whitespace-trimmed"
  - "Empty string and unset are treated identically (default policy)"
  - "Literal '*' is honored but emits logger.warning at server startup"
  - "When env-var has explicit origins, allow_origin_regex is dropped — exact-list only (no confusing combination)"
  - "allow_methods=['*'] and allow_headers=['*'] left unchanged — origins are the auth boundary"
  - "Did NOT set allow_credentials=True (no auth cookies in bridge today; CORS spec disallows it with wildcards anyway)"
metrics:
  duration: "~3 minutes"
  completed_date: "2026-05-08"
  tasks_completed: 2
  files_modified: 2
  tests_added: 4
  tests_total_passing: 30
---

# Quick Task 260508-bju: Lock down WebBridge CORS to localhost-only Summary

## Outcome

The FastSense Bridge HTTP layer is no longer wide open to cross-origin browser fetches. By default, only `http(s)://localhost` and `http(s)://127.0.0.1` on any port are echoed in `Access-Control-Allow-Origin`. Operators can opt in to specific production origins via the new `FASTSENSE_BRIDGE_CORS_ORIGINS` env var, or fall back to the previous wildcard behaviour with a loud startup WARNING.

## Tasks Completed

### Task 1 — Replace wildcard CORS in `create_app()`
- **Commit:** `5d138a6`
- **File:** `bridge/python/fastsense_bridge/server.py`
- Added `import logging`, `import os`, module-level `logger = logging.getLogger(__name__)`, and module-level `_LOCALHOST_ORIGIN_REGEX` constant.
- Replaced the previous `app.add_middleware(CORSMiddleware, allow_origins=["*"], ...)` block with three-branch logic:
  1. **Unset/empty** → `allow_origins=[]` plus `allow_origin_regex=_LOCALHOST_ORIGIN_REGEX`.
  2. **Literal `*`** (after strip) → `allow_origins=["*"]` plus `logger.warning("FASTSENSE_BRIDGE_CORS_ORIGINS=* — CORS is wide open. Do not use in production.")`.
  3. **Comma-separated list** → split, trim, drop empties, pass as `allow_origins=[...]`. No regex, no warning.
- `allow_methods=["*"]` and `allow_headers=["*"]` preserved.
- Existing 26 server tests still pass (no regressions).

### Task 2 — Add `TestCORSPolicy` test suite
- **Commit:** `518b778`
- **File:** `bridge/python/tests/test_server.py`
- Added `import logging` to the test module.
- Added `TestCORSPolicy` class with four tests, each instantiating a fresh app inside the test body so env-var manipulations land inside `create_app()`:
  1. `test_default_allows_localhost` — `Origin: http://localhost:5173` and `Origin: http://127.0.0.1:8080` both echoed.
  2. `test_default_blocks_foreign_origin` — `Origin: https://evil.example.com` is not echoed.
  3. `test_env_override_allows_listed_origin` — with `FASTSENSE_BRIDGE_CORS_ORIGINS=https://app.example.com`, that origin is echoed; `https://evil.example.com` is not.
  4. `test_wildcard_logs_warning` — with `FASTSENSE_BRIDGE_CORS_ORIGINS=*`, a WARNING record is emitted on logger `fastsense_bridge.server` and any origin is echoed as `*`.
- All 4 new tests pass; full file: 30 passed.

## Verification

```text
cd bridge/python && python -m pytest tests/test_server.py -q
..............................                                           [100%]
30 passed in 40.58s

cd bridge/python && python -m pytest tests/test_server.py::TestCORSPolicy -v
TestCORSPolicy::test_default_allows_localhost PASSED
TestCORSPolicy::test_default_blocks_foreign_origin PASSED
TestCORSPolicy::test_env_override_allows_listed_origin PASSED
TestCORSPolicy::test_wildcard_logs_warning PASSED
```

Sanity greps:
- `grep -n "FASTSENSE_BRIDGE_CORS_ORIGINS" bridge/python/fastsense_bridge/server.py` → matches inside docstring/comment and one `os.environ.get(...)` call inside `create_app()`.
- `grep -n 'allow_origins=\["\*"\]' bridge/python/fastsense_bridge/server.py` → exactly one match, inside the `cors_env == "*"` branch — never the default.

## Must-Haves Verification

| Truth | Verified by |
| --- | --- |
| `FASTSENSE_BRIDGE_CORS_ORIGINS` unset → `Origin: http://localhost:5173` allowed | `TestCORSPolicy::test_default_allows_localhost` (PASSED) |
| `FASTSENSE_BRIDGE_CORS_ORIGINS` unset → `Origin: https://evil.example.com` NOT echoed | `TestCORSPolicy::test_default_blocks_foreign_origin` (PASSED) |
| `FASTSENSE_BRIDGE_CORS_ORIGINS=https://app.example.com` → that origin allowed, foreign denied | `TestCORSPolicy::test_env_override_allows_listed_origin` (PASSED) |
| `FASTSENSE_BRIDGE_CORS_ORIGINS=*` → wildcard honored AND WARNING logged at startup | `TestCORSPolicy::test_wildcard_logs_warning` (PASSED) |

## Deviations from Plan

None — plan executed exactly as written. Both tasks were `tdd="true"` but in practice the implementation (Task 1) was written first against the locked behavior in CONTEXT.md, and the test class (Task 2) was added immediately after to lock the four acceptance truths in regression. All existing tests continued to pass between tasks, and the new tests passed on first run with no implementation tweaks needed.

## Known follow-ups (out of scope per CONTEXT.md)

- **WebSocket origin gating is NOT covered by this change.** FastAPI's `CORSMiddleware` only inspects HTTP requests; it does NOT gate WebSocket upgrade handshakes. The `/ws` endpoint in `bridge/python/fastsense_bridge/server.py` (`websocket_endpoint`) currently accepts connections from any origin. A separate task should validate the `Origin` header inside `websocket_endpoint()` against the same regex / env-var list before calling `await ws.accept()`. CONTEXT.md explicitly scopes this out of the current task — it should be tracked as a follow-up quick task.

## Self-Check: PASSED

Verified:
- File exists: `bridge/python/fastsense_bridge/server.py` (modified) — FOUND
- File exists: `bridge/python/tests/test_server.py` (modified) — FOUND
- Commit `5d138a6` (Task 1: feat) — FOUND
- Commit `518b778` (Task 2: test) — FOUND
- All 4 must-haves truths verified by passing tests
- 30/30 server tests pass after both commits
