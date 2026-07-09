---
type: quick
quick_id: 260709-act
slug: implement-issue-318-webbridge-actions
issue: 318
status: complete
---

# Quick Task: WebBridge.unregisterAction/listActions (#318)

## Goal
Round out the action-registry lifecycle (register/has already exist) with
remove + list.

## Scope (additive only)
- `libs/WebBridge/WebBridge.m`: unregisterAction(name) (rmfield + push if
  connected; no-op if absent), listActions() -> fieldnames cellstr.

## Test
- `tests/suite/TestWebBridge.m`: unregister, absent-no-op, list-includes,
  list-reflects-unregister.

## Verification
- TestWebBridge 6/6. check_matlab_code + MISS_HIT clean.
