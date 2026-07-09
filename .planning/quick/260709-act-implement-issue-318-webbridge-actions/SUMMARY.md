---
type: quick
quick_id: 260709-act
slug: implement-issue-318-webbridge-actions
issue: 318
status: complete
---

# Summary: WebBridge.unregisterAction / listActions (#318)

## What was built
- `libs/WebBridge/WebBridge.m`:
  - `unregisterAction(name)` — mirror of registerAction: rmfield from the
    Actions struct and, when a client is connected, push the updated action
    list via sendActionsChanged; silent no-op if the action is absent.
  - `listActions()` — fieldnames(Actions) as a cellstr ({} when none).
  Purely server-side registry management over the existing Actions struct — no
  protocol/wire change.
- `tests/suite/TestWebBridge.m`: +4 tests (unregister, absent-no-op,
  list-includes-registered, list-reflects-unregister).

## Verification
- TestWebBridge: 6 passed / 0 failed (was 2; +4).
- check_matlab_code + MISS_HIT mh_style/mh_lint: clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB · no protocol/wire change ·
existing register/has actions untouched.
