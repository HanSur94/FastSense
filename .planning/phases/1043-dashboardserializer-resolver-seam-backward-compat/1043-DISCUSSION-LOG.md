# Phase 1043: DashboardSerializer Resolver Seam + Backward Compat - Discussion Log

> **Audit trail only.** Not consumed by downstream agents. Decisions are in CONTEXT.md.

**Date:** 2026-06-07
**Phase:** 1043-dashboardserializer-resolver-seam-backward-compat
**Areas discussed:** 3 gray areas presented; user deferred all to Claude ("[No preference]")
**Mode:** autonomous --interactive (inline discuss)

---

## Gray-Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Missing-tag warning | No-resolver + registry-miss behavior for tag widgets (SC3) | |
| .m export scoping | How `.m` export emits machine-scoped form without machineId-in-struct (SC4) | |
| Backward-compat test | Which legacy fixtures + whether to add a no-resolver-warning test (SC2) | |

**User's choice:** "[No preference]" — none selected; deferred to Claude.
**Notes:** Mechanical phase with HIGH-confidence research and exact code seams; user in autonomous-momentum mode (matches the "nothing" response on 1042). Claude locked defaults (D-01..D-07 in CONTEXT.md) and proceeded without a separate write-confirm gate, consistent with the autonomous opt-in.

## Claude's Discretion

All decisions Claude-made:
1. Resolver threading completed through the tag path + multi-page gap (D-01, D-02).
2. Missing-tag warning `FastSenseWidget:tagResolverMissing` + leave Tag empty; default `TagRegistry.get` for legacy (D-03, D-04).
3. `.m` export gains an optional machine-variable-name arg switching `TagRegistry.get('k')` → `machine.get('k')` (D-05).
4. Class suite + Octave flat companion covering all four success criteria (D-06, D-07).

## Deferred Ideas
- Fleet-dashboard export wiring (caller passing the machineVar) → exercised in 1046.
- Resolver-inverse / Tag→machine back-reference → not needed.
