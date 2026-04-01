# Phase 4: Multi-Page Navigation - Research

**Researched:** 2026-04-01
**Domain:** MATLAB Dashboard Engine — page model, navigation UI, serialization, live-timer scoping
**Confidence:** HIGH

## Summary

Phase 4 adds a page layer above the widget layer in `DashboardEngine`. The core model is a `DashboardPage` handle class that holds a name and a widget cell array. `DashboardEngine` gains a `Pages` cell array and an `ActivePage` index. `addWidget()` appends to the active page. `render()` and `onLiveTick()` operate only on active-page widgets. A `PageBar` uipanel rendered between `DashboardToolbar` and the content area shows one pushbutton per page; it is hidden when `numel(Pages) == 1`.

The tab-switching pattern in `GroupWidget.renderTabbedChildren()` / `switchTab()` is a direct template for the PageBar interaction pattern. `DashboardSerializer` already follows the pattern of extending `widgetsToConfig` / `configToWidgets` / `save` / `loadJSON` for new structural fields, established in Phase 1 with GroupWidget children and Phase 2 with collapsed state.

Single-page dashboards with no `pages` field in JSON must load as before (backward compatibility). The `DashboardEngine.load()` static method applies `normalizeToCell` — the same normalization must be applied to any new `pages` array decoded from JSON.

**Primary recommendation:** Create `DashboardPage.m` as a thin handle class (Name, Widgets), add `Pages`/`ActivePage` to `DashboardEngine`, render `PageBar` as a fixed-height uipanel below the toolbar, reuse `TabActiveBg`/`TabInactiveBg` theme colors, and extend `DashboardSerializer` following the existing GroupWidget serialization pattern.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Page Model
- DashboardEngine gains a Pages cell array of DashboardPage objects
- DashboardPage is a thin wrapper holding: name, widgets list, and active state
- Single-page dashboards have exactly one implicit page (no visible page bar)
- addWidget() routes to the active page's widget list

#### Page Navigation UI
- PageBar rendered as a row of pushbuttons above the dashboard grid area
- Styled consistently with existing DashboardToolbar
- Only visible when Pages count > 1
- Active page button visually distinguished (like tab active state)

#### Serialization
- DashboardSerializer extended for multi-page JSON structure
- Active page name persisted in JSON
- Single-page JSON loads without a page bar (backward compatible)

### Claude's Discretion
- Exact PageBar layout and styling
- DashboardPage class design (separate file vs. nested struct)
- How page switching interacts with live timer (refresh only active page widgets)

### Deferred Ideas (OUT OF SCOPE)
None.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LAYOUT-03 | Multi-page dashboards — user can define multiple pages within a single dashboard figure | DashboardEngine.Pages cell array + DashboardPage class; addWidget() routes to active page |
| LAYOUT-04 | Page navigation UI — toolbar buttons or tab strip to switch between pages | PageBar uipanel with pushbuttons; switchPage() method toggling panel Visible; TabActiveBg/TabInactiveBg colors |
| LAYOUT-05 | Active page persists through save/load cycle | DashboardSerializer extended to write/read pages array + activePage name field |
| LAYOUT-06 | Only the active page's widgets are rendered; inactive pages are hidden | render() scopes allocatePanels() to active-page widgets; onLiveTick() loops over active-page widgets only |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Pure MATLAB uicontrol/uipanel | R2020b+ | PageBar pushbuttons, panel containers | Project constraint: no external dependencies |
| DashboardTheme | existing | TabActiveBg, TabInactiveBg, ToolbarBackground colors for PageBar | All tab/button chrome already done this way |

No new external libraries. This phase is pure MATLAB OOP extending existing classes.

**Installation:** None required.

---

## Architecture Patterns

### Recommended Project Structure

```
libs/Dashboard/
├── DashboardPage.m          NEW  — thin handle class: Name, Widgets
├── DashboardEngine.m        MOD  — Pages, ActivePage, addPage(), switchPage(), PageBar logic
├── DashboardSerializer.m    MOD  — widgetsToConfig, configToWidgets, save, loadJSON for pages
└── (all others unchanged)
tests/suite/
├── TestDashboardMultiPage.m  NEW  — LAYOUT-03..06 unit tests
```

### Pattern 1: DashboardPage Handle Class

**What:** Thin handle class that owns a name string and a widgets cell array. Keeps the engine clean by separating per-page widget lists.

**When to use:** Whenever DashboardEngine needs to dispatch addWidget(), render(), onLiveTick(), or serialization to a specific page scope.

**Design (separate file is preferred):**

```matlab
classdef DashboardPage < handle
%DASHBOARDPAGE Named page container within a multi-page dashboard.
    properties (Access = public)
        Name    = ''
        Widgets = {}
    end
    methods
        function obj = DashboardPage(name)
            if nargin >= 1, obj.Name = name; end
        end
        function w = addWidget(obj, w)
            obj.Widgets{end+1} = w;
        end
        function s = toStruct(obj)
            s.name = obj.Name;
            s.widgets = cell(1, numel(obj.Widgets));
            for i = 1:numel(obj.Widgets)
                s.widgets{i} = obj.Widgets{i}.toStruct();
            end
        end
    end
end
```

**Rationale for separate file over nested struct:** Consistent with all other `Dashboard*` and `*Widget` classes being separate `.m` files. Allows `isa(x, 'DashboardPage')` checks, future property additions without serializer rewrite, and cleaner error messages.

### Pattern 2: PageBar as Fixed-Height uipanel

**What:** A `uipanel` rendered between the toolbar and the content grid, containing one `uicontrol('Style','pushbutton')` per page. Hidden (`Visible off`) when only one page exists.

**When to use:** During `render()`, after the toolbar is created and before `Layout.ContentArea` is set.

**Sizing:** The existing `DashboardToolbar` uses `Height = 0.04` (normalized). The `TimePanelHeight = 0.06` is already reserved at the bottom. A `PageBarHeight = 0.04` (same as toolbar) placed immediately below the toolbar is natural. The `ContentArea` calculation in `render()` must subtract `PageBarHeight` when pages > 1:

```matlab
% In render(), after DashboardToolbar is created:
toolbarH = obj.Toolbar.Height;
if numel(obj.Pages) > 1
    pageBarH = obj.PageBarHeight;  % new property, default 0.04
    obj.renderPageBar(themeStruct);
else
    pageBarH = 0;
end
obj.Layout.ContentArea = [0, obj.TimePanelHeight, ...
    1, 1 - toolbarH - pageBarH - obj.TimePanelHeight];
```

**Button styling — reuse GroupWidget tab pattern:**

```matlab
% Active page button
set(hBtn, 'BackgroundColor', theme.TabActiveBg, ...
          'ForegroundColor', theme.GroupHeaderFg);
% Inactive page button
set(hBtn, 'BackgroundColor', theme.TabInactiveBg, ...
          'ForegroundColor', theme.ToolbarFontColor);
```

This is identical to `GroupWidget.switchTab()` and requires no new theme fields.

### Pattern 3: addWidget() Routing to Active Page

**What:** `DashboardEngine.addWidget()` appends to the active page's Widgets list instead of directly to `obj.Widgets`. For single-page mode, `obj.Widgets` becomes a computed property or the engine always works through `obj.Pages{obj.ActivePage}.Widgets`.

**Key decision — backward compatibility bridge:**

The engine currently has `obj.Widgets` used throughout (`render()`, `onLiveTick()`, `save()`, `preview()`, etc.). The cleanest approach for backward compatibility is to maintain `obj.Widgets` as a *reference to the active page's widget list* via a helper:

```matlab
function ws = activeWidgets(obj)
    if isempty(obj.Pages)
        ws = obj.Widgets;  % legacy / fallback
    else
        ws = obj.Pages{obj.ActivePage}.Widgets;
    end
end
```

All internal methods that currently loop over `obj.Widgets` are updated to call `obj.activeWidgets()`. This avoids breaking `obj.Widgets` for external callers while routing internally through pages.

**Alternative:** Keep `obj.Widgets` as the flat list for single-page compatibility and only populate `Pages` when `addPage()` is called explicitly. Single-page dashboards never call `addPage()` so `obj.Widgets` continues to work. This is simpler and avoids a migration of all internal loops. The planner should choose this approach — it minimizes scope.

### Pattern 4: Page Switching (switchPage)

**What:** Sets `ActivePage` index, updates button background colors, hides old page panels, shows new page panels. Calls `rerenderWidgets()` if the new page's widgets have not been realized.

**Template — GroupWidget.switchTab():**

```matlab
function switchPage(obj, pageIdx)
    if pageIdx < 1 || pageIdx > numel(obj.Pages)
        return;
    end
    obj.ActivePage = pageIdx;
    % Update button colors
    for i = 1:numel(obj.hPageButtons)
        if i == pageIdx
            set(obj.hPageButtons{i}, 'BackgroundColor', activeBg);
        else
            set(obj.hPageButtons{i}, 'BackgroundColor', inactiveBg);
        end
    end
    % Re-render the new page's widgets
    obj.rerenderWidgets();
end
```

`rerenderWidgets()` already tears down and recreates panels — this is the correct path. No need for a panel-show/hide approach unless performance becomes an issue (it won't for the widget counts expected here).

### Pattern 5: onLiveTick() Active-Page Scoping

**What:** `onLiveTick()` currently loops over `obj.Widgets`. After multi-page, it must loop over only the active page's widgets.

**CONTEXT.md concern (from STATE.md blockers):** "DashboardEngine render guard interaction with panel-visibility-based page switching needs architecture review." The research conclusion is: **use rerenderWidgets() for page switching, not panel-visibility toggling**. This avoids stale handle issues when switching back to a previously rendered page and sidesteps the guard interaction entirely. The cost is re-rendering on each page switch, which is acceptable for the widget counts in this use case.

### Pattern 6: Serialization Extension

**What:** `widgetsToConfig()` emits a `pages` array when pages > 1. `configToWidgets()` (and `loadJSON()`) reads `pages` if present, otherwise falls back to the flat `widgets` array.

**JSON structure (multi-page):**

```json
{
  "name": "My Dashboard",
  "theme": "dark",
  "liveInterval": 5,
  "activePage": "Overview",
  "pages": [
    {
      "name": "Overview",
      "widgets": [ ... ]
    },
    {
      "name": "Details",
      "widgets": [ ... ]
    }
  ]
}
```

**JSON structure (single-page, backward compatible):**

```json
{
  "name": "My Dashboard",
  "theme": "dark",
  "liveInterval": 5,
  "widgets": [ ... ]
}
```

**Load guard in `DashboardEngine.load()`:**

```matlab
if isfield(config, 'pages') && ~isempty(config.pages)
    pages = normalizeToCell(config.pages);
    for i = 1:numel(pages)
        pg = DashboardPage(pages{i}.name);
        pgWidgets = normalizeToCell(pages{i}.widgets);
        for j = 1:numel(pgWidgets)
            pg.addWidget(DashboardSerializer.createWidgetFromStruct(pgWidgets{j}));
        end
        obj.Pages{end+1} = pg;
    end
    % Restore active page
    if isfield(config, 'activePage') && ~isempty(config.activePage)
        for i = 1:numel(obj.Pages)
            if strcmp(obj.Pages{i}.Name, config.activePage)
                obj.ActivePage = i;
                break;
            end
        end
    end
else
    % Legacy single-page JSON
    widgets = DashboardSerializer.configToWidgets(config, resolver);
    for i = 1:numel(widgets)
        obj.Widgets{end+1} = widgets{i};
    end
end
```

**normalizeToCell requirement:** The `pages` array decoded from JSON by `jsondecode` will be a struct array when it has multiple elements. Apply `normalizeToCell(config.pages)` before iteration — exactly as done for `config.widgets` in `loadJSON()`.

### Pattern 7: .m Export for Multi-Page

**What:** `DashboardSerializer.save()` must emit `d.addPage('PageName')` calls when pages > 1. The `addPage()` method on `DashboardEngine` sets the active page context so subsequent `addWidget()` calls route to that page.

**Example emitted script:**

```matlab
function d = my_dashboard()
    d = DashboardEngine('My Dashboard');
    d.Theme = 'dark';

    d.addPage('Overview');
    d.addWidget('fastsense', 'Title', 'Temp', 'Position', [1 1 12 3], ...);

    d.addPage('Details');
    d.addWidget('number', 'Title', 'Count', 'Position', [1 1 6 2]);
end
```

`addPage()` creates a new `DashboardPage`, appends to `obj.Pages`, and sets `obj.ActivePage` to the new page index.

### Anti-Patterns to Avoid

- **Panel-visibility toggling for page switching:** Keeping all page widget panels alive and toggling `Visible` on/off is tempting but creates stale handle risks on re-render (e.g., after figure resize). Use `rerenderWidgets()` instead.
- **Duplicating the Widgets flat list:** Do not maintain both `obj.Widgets` and `obj.Pages{i}.Widgets` in sync. Pick one source of truth. The recommended approach: single-page dashboards keep `obj.Widgets`; multi-page dashboards use `obj.Pages`. The `addWidget()` dispatcher checks which mode is active.
- **Breaking backward compatibility on single-page load:** If `pages` field is absent in JSON, always fall back to flat `widgets` array. Never require existing JSON files to be regenerated.
- **Calling allocatePanels with all-pages widgets:** `allocatePanels()` / `createPanels()` receives the widget list to lay out. Always pass only the active page's widgets, never a concatenation of all pages.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tab/page button styling | Custom color logic | `theme.TabActiveBg` / `theme.TabInactiveBg` | Already defined for all 6 presets in DashboardTheme |
| Widget teardown/recreate | Custom panel delete loop | `rerenderWidgets()` | Already handles Realized flag reset + panel delete + createPanels |
| jsondecode array normalization | Custom isfield/struct loop | `normalizeToCell()` (existing private helper) | Used throughout for widgets; same issue applies to pages |
| Tab switching precedent | New pattern | `GroupWidget.switchTab()` | Direct template: button color update + panel visibility |
| Content area computation | Ad-hoc position math | Existing `toolbarH + timePanelH` formula in `render()` | Just add `pageBarH` to the subtraction |

---

## Common Pitfalls

### Pitfall 1: jsondecode struct-array normalization for pages

**What goes wrong:** When a multi-page JSON is decoded by `jsondecode`, `config.pages` becomes a struct array (not a cell array) when there are 2+ pages. Iterating with `config.pages{i}` throws an error.

**Why it happens:** MATLAB's `jsondecode` maps JSON arrays of objects to struct arrays, not cell arrays. This bit the team in Phase 1 (INFRA-03) and was solved with `normalizeToCell`.

**How to avoid:** Always wrap: `pages = normalizeToCell(config.pages)` before iterating. Do the same for `pages{i}.widgets`.

**Warning signs:** Error message `"Expected cell array"` or indexing error `"()` indexing not supported"` when loading a multi-page JSON.

### Pitfall 2: ContentArea not updated when PageBar visibility changes

**What goes wrong:** When switching from a multi-page dashboard to single-page (or rendering a single-page dashboard), if `PageBarHeight` is not excluded from `ContentArea`, the content grid has a gap or overlap at the top.

**Why it happens:** `render()` computes `Layout.ContentArea` once. If `PageBar` is hidden (single-page mode), its height must not be subtracted.

**How to avoid:** Compute `pageBarH = 0` when `numel(obj.Pages) <= 1` and `pageBarH = obj.PageBarHeight` otherwise. Always pass the computed value to `Layout.ContentArea`.

### Pitfall 3: onLiveTick() refreshing inactive-page widgets

**What goes wrong:** If `onLiveTick()` loops over all pages' widgets, off-screen widgets that are not realized will trigger `w.refresh()` on unrealized state, causing errors or unnecessary work.

**Why it happens:** The existing guard `w.Dirty && w.Realized` already prevents refresh on unrealized widgets, but widgets on inactive pages will never be realized via `realizeBatch()` so the Realized guard is necessary to prevent errors.

**How to avoid:** Restrict `onLiveTick()` to `obj.activePageWidgets()` (active page only). Unrealized inactive-page widgets will be realized on page switch via `rerenderWidgets()`.

### Pitfall 4: addWidget() routing breaks when no pages defined

**What goes wrong:** If `addWidget()` always tries `obj.Pages{obj.ActivePage}.addWidget(w)`, it errors on a freshly constructed `DashboardEngine` before any page is added.

**Why it happens:** `Pages = {}` and `ActivePage = 0` on construction.

**How to avoid:** `addWidget()` checks `isempty(obj.Pages)` and appends to `obj.Widgets` (legacy mode). When `addPage()` is called for the first time, migrate `obj.Widgets` into the first page.

**Alternative (cleaner):** `DashboardEngine` constructor always creates one implicit default page. `obj.Pages = {DashboardPage('Default')}` and `obj.ActivePage = 1`. `obj.Widgets` becomes a pass-through to `obj.Pages{1}.Widgets`. Single-page dashboards are just the normal case of one page with no visible PageBar. This eliminates the branching in `addWidget()`.

### Pitfall 5: ReflowCallback injection skipped for widgets loaded onto non-default pages

**What goes wrong:** When loading from JSON, the loop that injects `ReflowCallback` into collapsible GroupWidgets (in `DashboardEngine.load()`) only sees `obj.Widgets`. If widgets are in `obj.Pages{i}.Widgets`, they are missed.

**Why it happens:** The injection loop was added in Phase 2 and directly accesses `obj.Widgets`.

**How to avoid:** The injection loop must iterate over all pages' widget lists, or (better) the `activeWidgets()` helper is replaced with a `allWidgets()` helper for setup operations, and the injection loop uses `allWidgets()`.

### Pitfall 6: save() / widgetsToConfig() emitting stale single-page format for multi-page dashboards

**What goes wrong:** `save()` calls `DashboardSerializer.widgetsToConfig(obj.Name, obj.Theme, obj.LiveInterval, obj.Widgets, obj.InfoFile)`. If `obj.Widgets` is empty (multi-page mode) and pages are in `obj.Pages`, the saved JSON has an empty widgets list.

**Why it happens:** `obj.Widgets` is not the source of truth in multi-page mode.

**How to avoid:** `DashboardEngine.save()` must detect multi-page mode and pass the pages structure to a new serializer path. Add a `widgetsPagesToConfig()` overload or extend `widgetsToConfig()` to accept an optional pages argument.

---

## Code Examples

### Existing tab switch pattern (template for PageBar)

```matlab
% Source: libs/Dashboard/GroupWidget.m — switchTab()
function switchTab(obj, tabName)
    idx = obj.findTab(tabName);
    if idx == 0, return; end
    obj.ActiveTab = tabName;
    if ~isempty(obj.hChildPanels)
        for i = 1:numel(obj.hChildPanels)
            if i == idx
                set(obj.hChildPanels{i}, 'Visible', 'on');
            else
                set(obj.hChildPanels{i}, 'Visible', 'off');
            end
        end
    end
    if ~isempty(obj.hTabButtons)
        theme = obj.getTheme();
        activeBg  = obj.getThemeField(theme, 'TabActiveBg',   [0.20 0.20 0.25]);
        inactiveBg = obj.getThemeField(theme, 'TabInactiveBg', [0.12 0.12 0.16]);
        for i = 1:numel(obj.hTabButtons)
            if i == idx
                set(obj.hTabButtons{i}, 'BackgroundColor', activeBg);
            else
                set(obj.hTabButtons{i}, 'BackgroundColor', inactiveBg);
            end
        end
    end
end
```

For PageBar: replace `hChildPanels` with `rerenderWidgets()` call, use same theme color logic.

### normalizeToCell usage pattern

```matlab
% Source: libs/Dashboard/DashboardSerializer.m — loadJSON()
config.widgets = normalizeToCell(config.widgets);

% Same pattern required for pages:
pages = normalizeToCell(config.pages);
for i = 1:numel(pages)
    pgWidgets = normalizeToCell(pages{i}.widgets);
    ...
end
```

### ContentArea computation with optional PageBar

```matlab
% Source: libs/Dashboard/DashboardEngine.m — render() (to be modified)
toolbarH = obj.Toolbar.Height;  % 0.04
pageBarH = 0;
if numel(obj.Pages) > 1
    obj.renderPageBar(themeStruct);
    pageBarH = obj.PageBarHeight;   % new property, 0.04
end
obj.Layout.ContentArea = [0, obj.TimePanelHeight, ...
    1, 1 - toolbarH - pageBarH - obj.TimePanelHeight];
```

### Toolbar pushbutton layout pattern (template for PageBar)

```matlab
% Source: libs/Dashboard/DashboardToolbar.m — constructor
hPanel = uipanel('Parent', hFigure, ...
    'Units', 'normalized', ...
    'Position', [0, 1 - obj.Height, 1, obj.Height], ...
    'BorderType', 'none', ...
    'BackgroundColor', theme.ToolbarBackground);

% Buttons: fixed width, normalized horizontal layout
btnW = 0.06; btnH = 0.7; btnY = 0.15;
```

For PageBar: dynamic button width = `0.9 / nPages` (cap at `0.15` per tab — same cap used in GroupWidget tabbed mode). Reserve `0.05` left margin.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flat widget list in DashboardEngine | Pages cell array of DashboardPage objects | Phase 4 (this phase) | addWidget/render/onLiveTick all become page-scoped |
| No page navigation | PageBar uipanel with pushbuttons | Phase 4 | Visible only when Pages > 1 |
| Flat widgets in JSON | Nested pages.widgets in JSON (backward compatible) | Phase 4 | Old JSON still loads via widgets fallback |

---

## Open Questions

1. **Default implicit page name**
   - What we know: Single-page dashboards need exactly one implicit page
   - What's unclear: Should the implicit page be named `'Default'`, `''` (empty), or the dashboard name?
   - Recommendation: Use `'Default'` as the implicit page name. It serializes cleanly and is a recognizable sentinel. The serializer can elide page structure when `numel(Pages) == 1 && strcmp(Pages{1}.Name, 'Default')` to maintain single-page JSON format.

2. **addPage() API — user-facing vs. internal**
   - What we know: DashboardBuilder API must remain unchanged for single-page dashboards (COMPAT-04)
   - What's unclear: Should users call `d.addPage('PageName')` directly, or only via DashboardBuilder?
   - Recommendation: Expose `addPage(name)` as a public method on DashboardEngine. It is the natural scripting API (`d.addPage('Overview'); d.addWidget(...)`) and matches how GroupWidget's `addChild(w, tabName)` creates tabs.

3. **rerenderWidgets() vs. panel Visible toggling for page switching**
   - What we know: STATE.md flags "render guard interaction with panel-visibility-based page switching needs architecture review"
   - What's unclear: Would keeping all page panels alive (just toggling visibility) be faster?
   - Recommendation: Use `rerenderWidgets()` (full re-layout). Panel toggling requires allocating panels for ALL pages on first `render()`, which complicates `allocatePanels()`. Full re-layout is O(n_active_widgets) and already well-tested. Panel toggling is premature optimization for this use case.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 4 is pure MATLAB code changes with no external tool dependencies beyond the existing MATLAB R2020b+ / Octave 7+ runtime already validated in prior phases.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | MATLAB `matlab.unittest.TestCase` (class-based) |
| Config file | none — discovered by `tests/run_all_tests.m` |
| Quick run command | `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests/suite'); install(); results = runtests('TestDashboardMultiPage'); assert(~any([results.Failed]))"` |
| Full suite command | `cd /Users/hannessuhr/FastPlot && matlab -batch "run_all_tests"` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LAYOUT-03 | addPage() creates DashboardPage; addWidget() routes to active page | unit | `runtests('TestDashboardMultiPage', 'Name', 'testAddPage')` | Wave 0 |
| LAYOUT-03 | Single-page dashboard: no Pages populated, Widgets accessible normally | unit | `runtests('TestDashboardMultiPage', 'Name', 'testSinglePageBackcompat')` | Wave 0 |
| LAYOUT-04 | PageBar not visible for single-page dashboard | unit | `runtests('TestDashboardMultiPage', 'Name', 'testPageBarHiddenSinglePage')` | Wave 0 |
| LAYOUT-04 | PageBar visible for multi-page dashboard | unit | `runtests('TestDashboardMultiPage', 'Name', 'testPageBarVisibleMultiPage')` | Wave 0 |
| LAYOUT-04 | switchPage() updates ActivePage and button colors | unit | `runtests('TestDashboardMultiPage', 'Name', 'testSwitchPage')` | Wave 0 |
| LAYOUT-05 | save/load round-trip preserves pages and activePage | unit | `runtests('TestDashboardMultiPage', 'Name', 'testSaveLoadRoundTrip')` | Wave 0 |
| LAYOUT-05 | Old single-page JSON loads without page bar | unit | `runtests('TestDashboardMultiPage', 'Name', 'testLegacyJsonLoad')` | Wave 0 |
| LAYOUT-06 | onLiveTick() only ticks active-page widgets | unit | `runtests('TestDashboardMultiPage', 'Name', 'testLiveTickScopedToActivePage')` | Wave 0 |

### Sampling Rate

- **Per task commit:** `runtests('TestDashboardMultiPage')`
- **Per wave merge:** `runtests('TestDashboardEngine')` + `runtests('TestDashboardSerializer')` + `runtests('TestDashboardMultiPage')`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/suite/TestDashboardMultiPage.m` — covers LAYOUT-03 through LAYOUT-06 (all 8 test methods above)

*(No framework install needed — matlab.unittest already available)*

---

## Project Constraints (from CLAUDE.md)

- **Tech stack:** Pure MATLAB — no external dependencies. `DashboardPage.m` must be plain MATLAB OOP (handle class, no toolbox requirements).
- **Backward compatibility:** Existing dashboard scripts and serialized dashboards must continue to work. JSON without `pages` field must load as before.
- **Widget contract:** New features must work through the existing `DashboardWidget` base class interface. `DashboardPage` holds `DashboardWidget` instances, not subclasses of its own.
- **Performance:** Detached live-mirrored widgets (Phase 5) must not degrade refresh rate. For Phase 4, `onLiveTick()` must not iterate over inactive-page widgets.
- **Naming:** Classes PascalCase (`DashboardPage`), properties PascalCase (`Name`, `Widgets`, `ActivePage`), methods camelCase (`addPage`, `switchPage`, `activeWidgets`).
- **Error IDs:** Pattern `ClassName:camelCaseProblem` — e.g., `DashboardPage:invalidName`, `DashboardEngine:unknownPage`.
- **Style:** MISS_HIT line length 160 max, 4-space tabs, cyclomatic complexity < 80.
- **Test lifecycle:** `TestClassSetup` named `addPaths`, test methods camelCase starting with verb.
- **Comments:** All public classes need header comment with description, usage examples, property/method list. All public methods need `%METHODNAME Description.` header.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection: `libs/Dashboard/DashboardEngine.m` — full source read; render(), addWidget(), onLiveTick(), load() patterns
- Direct codebase inspection: `libs/Dashboard/GroupWidget.m` — full source read; switchTab(), renderTabbedChildren() as tab switching template
- Direct codebase inspection: `libs/Dashboard/DashboardSerializer.m` — full source read; widgetsToConfig(), configToWidgets(), save(), loadJSON() patterns
- Direct codebase inspection: `libs/Dashboard/DashboardToolbar.m` — pushbutton layout pattern for PageBar
- Direct codebase inspection: `libs/Dashboard/DashboardTheme.m` — TabActiveBg, TabInactiveBg confirmed in all 6 presets
- Direct codebase inspection: `libs/Dashboard/DashboardLayout.m` — allocatePanels(), createPanels(), ContentArea usage
- Direct codebase inspection: `tests/suite/TestDashboardEngine.m` — test class pattern
- `.planning/phases/04-multi-page-navigation/04-CONTEXT.md` — locked decisions

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` — recorded decisions from Phases 1–3, blocker notes on render guard interaction
- `.planning/REQUIREMENTS.md` — LAYOUT-03 through LAYOUT-06 requirement text

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure MATLAB, no new libraries, patterns already proven in codebase
- Architecture: HIGH — DashboardPage class design, PageBar pattern, serialization extension all derived directly from existing GroupWidget/DashboardToolbar/DashboardSerializer patterns
- Pitfalls: HIGH — jsondecode normalization, ContentArea sizing, onLiveTick scoping, ReflowCallback injection all verified against actual source code

**Research date:** 2026-04-01
**Valid until:** 2026-05-01 (stable MATLAB OOP codebase, no external dependencies to track)
