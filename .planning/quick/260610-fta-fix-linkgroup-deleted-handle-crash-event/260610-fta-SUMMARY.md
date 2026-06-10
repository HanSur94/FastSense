---
quick_id: 260610-fta
status: complete
date: 2026-06-10
---

# Summary: LinkGroup deleted-handle crash + EventViewer NaN duration

Both bugs reproduced live on R2025b before fixing, re-verified after.

## What changed
- `libs/FastSense/FastSense.m`
  - `propagateXLim`: try/catch probe per registry member; deleted members skipped.
  - `getLinkRegistry`: new `liveRegistryMask` static helper; 'get' prunes dead
    members (cleanup was dead code — never called), 'cleanup' reuses the mask.
- `libs/EventDetection/EventViewer.m`
  - `formatDuration`: non-finite duration → '(open)' (open events showed 'NaNh NaNm').

## Verification (live MATLAB R2025b)
- Repro before: zoom after `delete(member)` → PostSet listener error at FastSense.m:4586.
- Repro after: lastwarn clean; propagation reaches members past the corpse.
- test_linked_axes 3/3 (new deleted-member case), test_event_viewer 8/8 (new open-event case).
- Code Analyzer: no new findings on either lib file.

## Notes
- Reviewer had rated the EventViewer issue a crash; actual behavior was cosmetic
  ('NaNh NaNm') because the else-branch assigns str. Severity downgraded.
- Executed inline (two small guards + tests) with GSD bookkeeping — no separate
  planner/executor subagents (precedent: 260602-p2t).
