# Stack Research

**Domain:** Pure-MATLAB fleet data-model and UI — v5.0 Multi-Machine Fleet additions
**Researched:** 2026-06-02
**Confidence:** HIGH (all recommendations grounded in actual codebase file reads; no new dependencies required)

---

## Scope

This document covers only the built-in (or already-bundled) facilities needed for the four new v5.0 concerns:

1. Fuzzy/approximate string matching and key normalization for `CanonicalMapper`
2. Fleet config-file persistence (`Machine` list, `DataRoot`, canonical overrides)
3. Scalable searchable machine selector in a uifigure
4. Per-machine `DataRoot` folder/file discovery

Nothing in this list introduces a new dependency. The hard constraint from `CLAUDE.md` is respected throughout: pure MATLAB/Octave, no toolboxes, no external libraries.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| MATLAB built-in string functions (`lower`, `regexprep`, `strsplit`, `strtrim`, `strfind`, `strcmp`) | R2020b+ / Octave 7+ | Key normalization pipeline inside `CanonicalMapper` | All present on both runtimes; already used this way throughout the codebase (see `parseOpts.m`, `filterTags.m`, `filterDashboards.m`) |
| Hand-rolled edit-distance (`editDistance_`) | N/A — implement inline in `CanonicalMapper` | Approximate token matching for auto-rule scoring | No Text Analytics Toolbox required; pure nested loops; ~20 LOC; low enough call count (20-200 keys per fleet) that O(n*m) is irrelevant |
| `containers.Map` synonym/alias table | R2014b+ / Octave 7+ | Manual override table mapping local keys to canonical ids | Already the standard lookup structure in this codebase (`TagRegistry`, `DataSourceMap`, `EventBinding`, `BatchTagPipeline.fileCache_`); char→char Map is the natural shape for the overrides file |
| `jsonencode` / `jsondecode` | R2016b+ / Octave 5+ | Fleet config persistence (machine list, roots, canonical overrides) | Already used throughout codebase for all persistent config (see `DashboardSerializer.saveJSON/loadJSON`, `ndjsonEncode`, `ndjsonDecode`); proven on both runtimes; forward-compatible (text format survives refactors) |
| `uilistbox` inside `uigridlayout` + debounced `uieditfield` search | MATLAB R2020b+ | Searchable machine selector in Companion | Exact pattern already live in `TagCatalogPane` (uilistbox with `Multiselect='on'`, `Items`/`ItemsData`, 150 ms debounce timer, pill filters) and `DashboardListPane` (scrollable `uipanel` + per-row `uigridlayout`); copy the pattern verbatim |
| `dir(pattern)` with wildcard glob | R2020b+ / Octave 7+ | Per-machine `DataRoot` scanning for `.dat` / `.mat` / `.csv` raw files | Already the only file-discovery mechanism in the codebase (`EventStore`, `LiveTagPipeline`, `build_mex`); cross-platform; `dir(fullfile(root,'*.dat'))` returns struct array with `.name` and `.folder` |

---

### Supporting Libraries (already bundled — no install needed)

| Library | Purpose | When to Use |
|---------|---------|-------------|
| `containers.Map('KeyType','char','ValueType','any')` | In-memory key→value store for `Machine.tags_` (per-machine tag catalog) | Use for every `Machine` instance; mirrors how `TagRegistry` owns its persistent map |
| `normalizeToCell` (private at `libs/Dashboard/private/normalizeToCell.m`) | Safe `jsondecode` struct-array → cell conversion | Use in `Fleet.fromStruct` when loading a JSON array of machine records; `jsondecode` collapses homogeneous arrays to struct arrays |
| `strfind(lower(s), needle)` idiom | Case-insensitive substring match | Use in `CanonicalMapper` token-overlap scoring and in the machine selector search field; `contains()` is absent in Octave — `strfind` is the portable alternative (confirmed in `filterTags.m` line 33 and `filterDashboards.m`) |
| `movefile(tmp, dest, 'f')` atomic-write pattern | Safe config save without corrupt-file risk | Use for `Fleet.save(path)`; pattern already used in `companionPrefs('save')` and `EventStore.save()` |

---

## Detailed Facility Notes by Concern

### 1. CanonicalMapper — Key Normalization and Approximate Matching

**Objective:** Map `'temp_1'`, `'t1'`, `'TMP_1'` to logical id `'oil_temperature'` automatically via rules, with a manual override table.

**Pipeline (all toolbox-free):**

```
raw key
  → lower(key)                          % case collapse
  → regexprep(key, '[^a-z0-9]', '_')   % punctuation → underscore
  → regexprep(key, '_+', '_')           % collapse repeated underscores
  → strtrim(strrep(key,'_',' '))        % tokenize for overlap scoring
  → strsplit(normalized, ' ')           % token cell array
```

`lower`, `regexprep`, `strsplit`, `strtrim`, `strrep` all exist identically on R2020b+ and Octave 7+.

**Approximate matching — do NOT use `edit_distance` from Statistics Toolbox.** Implement a private helper `editDistance_(a, b)` using the standard Wagner-Fischer DP table (plain double matrix). Call count is at most `n_keys × n_canonical_ids` at config-load time, not per-frame; 200 × 50 = 10,000 pairs is < 1 ms.

**Synonym/override table:** `containers.Map('KeyType','char','ValueType','char')` keyed by normalized local key, value = canonical id. Serialized as a JSON object with `jsonencode`. Loaded back with `jsondecode` + fieldnames-to-map conversion. This is the same pattern used by `DashboardSerializer` for widget type maps.

**Confidence level:** HIGH — every primitive used here appears in `filterTags.m`, `parseOpts.m`, or `DashboardSerializer.m` in this exact project.

---

### 2. Fleet Config Persistence

**Decision: JSON via `jsonencode`/`jsondecode`, NOT `.mat`.**

Rationale grounded in codebase evidence:

- `companionPrefs.m` uses `.mat` (via `prefdir`) for ephemeral **user preferences** (theme, livePeriod). That file is user-local, single-struct, never shared, survives MATLAB class refactors trivially.
- `DashboardSerializer.saveJSON`/`loadJSON` use `jsonencode`/`jsondecode` for **project artifacts** (dashboard configs). The serializer goes to significant lengths (stripping `plantLog`, per-widget encoding, `normalizeToCell` on load) precisely because JSON survives struct shape changes across versions and is human-readable/editable.
- Fleet config is a project artifact — it names machines, paths, and canonical overrides. It must be readable in a text editor, committable to version control, and survive renaming fields in the `Machine` class. `.mat` fails all three requirements.

**Octave parity of `jsonencode`/`jsondecode`:**
- `ndjsonDecode.m` line 29 states explicitly: "Both MATLAB R2016b+ and Octave 5+ ship jsondecode."
- `ndjsonEncode.m` states: "Octave 7+ and MATLAB R2020b+ compatible."
- One confirmed divergence (from `DashboardSerializer.m` line 249): `jsonencode({})` on an empty cell is ambiguous across MATLAB versions. Workaround already established — build JSON strings for arrays-of-heterogeneous-structs by hand using `strjoin(parts, ',')`. Apply the same pattern in `Fleet.save()` when encoding the machines array.
- Another confirmed divergence: `jsonencode(datetime)` throws on both runtimes. Fleet config contains no datetime fields; non-issue.

**Save pattern (copy from `companionPrefs`):**

```matlab
tmpPath = [configPath, '.tmp'];
fid = fopen(tmpPath, 'w');
fwrite(fid, jsonStr);
fclose(fid);
movefile(tmpPath, configPath, 'f');
```

`movefile` is on both runtimes. Atomic on POSIX; near-atomic on Windows (rename syscall). No `.mat` needed.

**Fleet config struct shape:**

```matlab
config.version    = 1;                   % int; bump on breaking schema change
config.machines   = { ... };             % cell of machine structs
config.canonical  = struct( ... );       % overrides map (JSON object)
```

Each machine struct:

```matlab
m.id       = 'machine_a';
m.name     = 'Press A';
m.dataRoot = '/data/press_a/';
m.metadata = struct( ... );              % arbitrary key-value
```

`jsondecode` on load produces a struct array for `config.machines` — apply `normalizeToCell` (already in `libs/Dashboard/private/`) to convert to a cell before iterating.

---

### 3. Searchable Machine Selector

**Decision: Copy the `DashboardListPane` pattern exactly.**

`DashboardListPane` already implements exactly what the machine selector needs:
- `uieditfield` search with 150 ms debounce timer
- `uipanel` with `Scrollable = 'on'` containing a `uigridlayout([nRows 1])`
- Per-row grid `[1 4]` with name button, count label, status dot, action button
- `applyFilter_()` as the single rebuild path (delete old grid, recreate rows)
- Empty-state label when search returns no results
- Selection highlight via `BackgroundColor` on the row button

For a machine selector, each row replaces the dashboard row shape: machine name, machine id (subdued), maybe a machine-status indicator.

**uilistbox as an alternative** (used in `TagCatalogPane`): works if the machine selector needs multi-select or group headers. `uilistbox.Items` and `uilistbox.ItemsData` are the parallel arrays; `Multiselect = 'on'` for multi-machine comparison selection. `uilistbox` does NOT support per-row custom layouts (no status dots, no buttons per row), so for a machine selector that also shows status/action buttons, the per-row grid approach from `DashboardListPane` is more flexible.

**Recommendation:** Use `uilistbox` for the machine selector pane (simpler, single-select by default, already used for TagCatalogPane which is structurally similar), plus a search field with debounce exactly as in both existing panes.

**Octave note:** The entire `FastSenseCompanion` including `TagCatalogPane` and `DashboardListPane` already has an Octave guard at the top of `FastSenseCompanion` constructor (`exist('OCTAVE_VERSION','builtin') ~= 0` → immediate error). The machine selector lives inside the Companion. No Octave compatibility concern for any uifigure component — the Companion is MATLAB-only by design.

**`CanonicalMapper` filter helpers** that do NOT touch uifigure (the pure-logic filtering functions, analogous to `filterTags.m` and `filterDashboards.m`) MUST be Octave-compatible — use `strfind` not `contains`, `~isempty(strfind(...))` not `contains(...)`.

---

### 4. DataRoot Folder/File Discovery

**Decision: `dir(fullfile(dataRoot, '*.ext'))` for initial scan; `dir(parentDir)` for live-tick dedup.**

This is already the codebase pattern. Specifics:

- `dir(fullfile(root, '*.dat'))` returns a struct array with `.name`, `.folder`, `.bytes`, `.datenum`. Works identically on both runtimes and all three OS targets (macOS, Linux, Windows).
- For recursive scan (subdirectories): call `dir(fullfile(root, '**', '*.dat'))` on MATLAB R2019b+. On Octave, recursive globbing (`**`) is NOT supported — implement a recursive helper using `dir` + loop over `[d.isdir]` entries. Given the codebase must support Octave 7+, the recursive helper approach is mandatory if `DataRoot` structures are nested.
- `isfolder(path)` is available on R2017b+ and Octave 7+ — use it instead of `exist(path,'dir')` for clarity (both are used in this codebase; `isfolder` is preferred in newer code).
- `fullfile` handles cross-platform path separators; use it exclusively (never hardcode `/` or `\`).
- `fileparts` decomposes paths into `(dir, name, ext)` — use in `CanonicalMapper` when deriving a candidate key from a discovered filename stem.

**Pattern for Machine discovery at init:**

```matlab
% Discover all raw data files under DataRoot
listing = dir(fullfile(machine.DataRoot, '*.dat'));
% Add .csv and .mat variants
listing = [listing; dir(fullfile(machine.DataRoot, '*.csv'))];
listing = [listing; dir(fullfile(machine.DataRoot, '*.mat'))];
% Extract stems as candidate local keys
for i = 1:numel(listing)
    [~, stem, ~] = fileparts(listing(i).name);
    % feed stem into CanonicalMapper normalization pipeline
end
```

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| `jsonencode`/`jsondecode` for Fleet config | `.mat` binary save (like `companionPrefs`) | `.mat` is user-preference-appropriate (ephemeral, single-user, single-session); Fleet config is a project artifact that must be human-readable, VCS-committable, and cross-platform portable |
| Hand-rolled edit distance | Statistics Toolbox `editDistance` | Toolbox not available by constraint; hand-rolled version is ~20 LOC and adequate for 20-200 key pairs |
| `uilistbox` + debounce for machine selector | `uitree` or `uitable` | `uitree` has no `Items`/`ItemsData` flat-list analog; `uitable` is heavyweight and does not support single-row click-to-select naturally; `uilistbox` already proven at scale in `TagCatalogPane` |
| `dir(pattern)` for file discovery | `what(dir)` | `what()` returns only MATLAB-recognized file types on the MATLAB path; wrong tool for scanning raw sensor data files in arbitrary DataRoots |
| `strfind(lower(s), needle)` for search | `contains(s, needle, 'IgnoreCase', true)` | `contains` is absent in Octave; `strfind` pattern is already established in `filterTags.m` and `filterDashboards.m` as the portable alternative |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Statistics Toolbox `editDistance` | Toolbox not available; violates hard no-external-dependency constraint | Hand-rolled Wagner-Fischer DP in `CanonicalMapper` private helper |
| Text Analytics Toolbox (tokenizer, word2vec, TF-IDF) | Toolbox not available; gross overkill for 20-200 sensor key strings | `lower` + `regexprep` + `strsplit` + edit distance |
| `contains()` in filter helpers that must be Octave-compatible | Absent in Octave | `~isempty(strfind(lower(s), needle))` |
| `jsonencode` on cell-arrays-of-heterogeneous-structs at top level | Ambiguous across MATLAB versions — produces arrays in some, structs in others | Build JSON arrays by hand via `strjoin(parts, ',')` for the `machines` array, matching the pattern in `DashboardSerializer.saveJSON` |
| `prefdir` + `.mat` for Fleet config | User-local path, not portable, not VCS-friendly | `jsonencode` to a user-specified config path |
| Recursive `dir('**/*.dat')` for Octave-targeted code | Octave 7 does not support `**` glob in `dir` | Explicit recursive `dir` + `isdir` loop helper |
| `validatestring` for CanonicalMapper key matching | Requires exact prefix match; throws on ambiguous — wrong semantics for fuzzy mapping | Edit-distance scoring + synonym table |

---

## Version Compatibility

| Function | MATLAB | Octave | Notes |
|----------|--------|--------|-------|
| `jsonencode` / `jsondecode` | R2016b+ | 5.0+ | Confirmed in `ndjsonDecode.m` and `ndjsonEncode.m` |
| `containers.Map` | R2010b+ | 7.0+ | Used throughout codebase; `containers.Map('KeyType','char','ValueType','any')` form required for Octave |
| `isfolder` | R2017b+ | 7.0+ | Both runtimes; prefer over `exist(p,'dir')` |
| `uilistbox`, `uieditfield`, `uigridlayout`, `uipanel(Scrollable)` | R2020b+ | Not supported | Companion is MATLAB-only; Octave guard at top of FastSenseCompanion constructor |
| `strfind` | R2009b+ | All | Portable substring search; use instead of `contains` for Octave-compatible helpers |
| `lower`, `regexprep`, `strsplit`, `strtrim` | R2009b+ | All | Core normalization pipeline; identical on both runtimes |
| `dir(pattern)` | All | All | Wildcard `*` glob works on both; `**` recursive glob is MATLAB-only |
| `movefile(src, dst, 'f')` | R2015b+ | 7.0+ | Atomic-ish rename for safe config write |
| `fullfile`, `fileparts` | All | All | Cross-platform path composition |

---

## Sources

- `libs/FastSenseCompanion/companionPrefs.m` — confirmed `.mat` pattern for user prefs (prefdir, atomic movefile)
- `libs/FastSenseCompanion/TagCatalogPane.m` — confirmed uilistbox + debounce + pill-filter pattern
- `libs/FastSenseCompanion/private/filterTags.m` — confirmed `strfind(lower(...))` Octave-portable search
- `libs/FastSenseCompanion/DashboardListPane.m` — confirmed per-row grid + scrollable panel pattern for searchable lists
- `libs/FastSenseCompanion/private/filterDashboards.m` — confirmed `strfind` not `contains` convention
- `libs/Dashboard/DashboardSerializer.m` — confirmed `jsonencode`/`jsondecode` for project config, `normalizeToCell` on load, hand-built JSON array joining for heterogeneous structs
- `libs/Dashboard/private/normalizeToCell.m` — confirmed helper for post-`jsondecode` cell normalization
- `libs/Concurrency/ndjsonDecode.m` line 29 — "Both MATLAB R2016b+ and Octave 5+ ship jsondecode"
- `libs/Concurrency/ndjsonEncode.m` — "Octave 7+ and MATLAB R2020b+ compatible"
- `libs/EventDetection/EventStore.m` lines 108, 636 — `dir(fullfile(dir, '*.ext'))` pattern for file-set discovery
- `libs/SensorThreshold/LiveTagPipeline.m` lines 731, 751 — `dir(parentDir)` pattern; one-dir-per-tick dedup strategy
- `libs/FastSenseCompanion/FastSenseCompanion.m` line 136-139 — Octave guard confirms Companion is MATLAB-only

---
*Stack research for: v5.0 Multi-Machine Fleet (libs/Fleet, Machine, CanonicalMapper, Companion machine selector)*
*Researched: 2026-06-02*
