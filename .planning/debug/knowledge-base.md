# GSD Debug Knowledge Base

Resolved debug sessions. Used by `gsd-debugger` to surface known-pattern hypotheses at the start of new investigations.

---

## 260526-info-icon-vanishes-after-plantlog-toggle — Info icon disappears from FastSenseWidget button bar after PlantLog L toggle on/off cycle
- **Date:** 2026-05-26
- **Error patterns:** PlantLog toggle, InfoIconButton, WidgetButtonBar, FastSenseWidget chrome, button cluster overlap, addPlantLogToggle, reflowChrome_, hardcoded position, 3-button cluster, 4-button cluster
- **Root cause:** DashboardLayout.addPlantLogToggle hardcoded xPL = barW - 84 for a 3-button right cluster, but FastSenseWidgets carry a 4-button cluster (Detach + Create + Info + PlantLog). On callback-driven rebuilds (toggle ON/OFF), the recreated L button was placed at barW - 84 — exactly the InfoIconButton's post-reflow x-position — visually covering the i icon. The initial render was rescued by reflowChrome_ at the end of realizeWidget; callback re-invocations were not.
- **Fix:** Call DashboardLayout.reflowChrome_ at the end of addPlantLogToggle (wrapped in try/catch so reflow failure cannot break the toggle itself). reflowChrome_ knows the canonical math for all button-cluster permutations.
- **Files changed:** libs/Dashboard/DashboardLayout.m, tests/suite/TestDashboardLayoutPlantLogToggle.m, tests/test_dashboard_layout_plant_log_toggle.m
---

