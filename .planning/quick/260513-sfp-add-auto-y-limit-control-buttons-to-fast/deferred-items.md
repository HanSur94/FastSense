# Deferred Items — 260513-sfp

Out-of-scope discoveries logged during execution per the SCOPE BOUNDARY
rule. These are NOT caused by 260513-sfp changes; do NOT auto-fix in
this task.

## Pre-existing test failure: `tests/test_dashboard_range_selector_integration.m` Case 2

**Symptom (matlab -batch):**
```
ERR: Case 2 debounced xl2(1)=25.0000 expected 0.0000
```

**Verification:**
Reproduced via `git stash` of all 260513-sfp changes, confirming Case 1
still passes but Case 2 already fails on the parent commit
(`9f46c92 Dashboard Live/Follow preserve + resize/tab-switch zombie-panel fix`).
The previously-reported "2/2 PASS" in STATE.md (260513-q7w entry) likely
came from running under the live MATLAB desktop where timer cadence
differs from `-batch`.

**Suspected root cause:** Debounce timer expectation under `-batch`
doesn't match the cwd / event-loop assumptions baked into the test.
Likely needs a `usejava('desktop')` skip or an explicit timer drain.

**Owner:** Future quick task; do NOT bundle into 260513-sfp.

## STATE.md note for `test_dashboard_range_selector_integration`

STATE.md last_activity claims "2/2 PASS" for this test. Under matlab
`-batch` the test reports `1/2 pass + Case 2 ERR`. The interactive
desktop session may still pass. The 260513-sfp verification step uses
the user's live MATLAB desktop, so we explicitly call out this
discrepancy in the SUMMARY and rely on the user to confirm during the
checkpoint:human-verify gate.
