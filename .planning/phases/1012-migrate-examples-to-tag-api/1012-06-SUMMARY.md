---
phase: 1012-migrate-examples-to-tag-api
plan: 06
status: complete
commits: 1
files_changed: 6
duration: 8min
---

# Plan 1012-06 Summary — Migrate examples/04-widgets to Tag API

## Outcome

One atomic commit (`da5ada5`). Fixed 6 of the 19 widget examples — the 13 others were already Tag-API-clean from Phase 1011's bulk text replace.

### Files changed

| File | Hazard | Fix |
|------|--------|-----|
| `example_widget_fastsense.m` | `sTemp.X = t;` + `sTemp.Y = ...` direct writes (Pitfall 3: X/Y are read-only on SensorTag) | Extract `tempY = ...` first; construct with `SensorTag(..., 'X', t, 'Y', tempY)` in one call |
| `example_widget_sparkline.m` | Self-referential `sCpu.Y` construct + `sCpu.Y = ...` writes | Compute `cpuY` locally; pass to constructor NV-pairs |
| `example_widget_histogram.m` | `sPress.X = t;` + bimodal `sPress.Y` writes | Build `pressY` locally; single-call constructor |
| `example_widget_scatter.m` | Duplicate `sPress.Y = ...` (already in constructor) | Drop the duplicate |
| `example_widget_status.m` | `sTemp.countViolations()` etc. in fprintf | Replace with v2.0 explanatory note; MultiStatusWidget still displays the status |
| `example_widget_table.m` | `sTemp.ResolvedViolations` loop | Replaced with `MonitorTag + EventStore + EventBinding.getEventsForTag` pattern |

## Acceptance gates

| Gate | Result |
|------|--------|
| `^\s*\w+\.(X\|Y)\s*=` direct assignments in `04-widgets/` | 0 hits ✓ |
| `\.ResolvedViolations\|\.countViolations` executable refs in `04-widgets/` | 0 hits (only one comment-string mention in status fprintf) ✓ |
| Legacy constructor regex in `04-widgets/` | 0 hits ✓ |

## Self-Check: PASSED

- [x] Exactly 1 atomic commit.
- [x] All 6 modified files preserve their narrative structure and widget positions.
- [x] MonitorTag constructor signature verified against class source.
- [x] MATLAB-only widgets (chipbar, divider, iconcard, sparkline) handled via Plan 01's smoke skip list — no Octave parse failures from toolbox-dependent code.
