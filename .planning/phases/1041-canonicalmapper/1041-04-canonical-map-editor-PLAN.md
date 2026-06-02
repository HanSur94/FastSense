---
phase: 1041-canonicalmapper
plan: 04
type: execute
wave: 3
depends_on: ["1041-03"]
files_modified:
  - libs/Fleet/CanonicalMapEditor.m
autonomous: false
requirements: [CANON-05]
must_haves:
  truths:
    - "User can open CanonicalMapEditor(mapper) and see a table of logical name / machine / local key / units-match / confidence / status for every entry"
    - "A LOW-confidence or unit-mismatch row can be promoted to Confirmed via the Promote button, gated by a uiconfirm warning, and the change reflects in mapper state"
    - "User can override a row's local key via the Override button + inputdlg, and the override persists in the mapper"
    - "testEditorConstructs smoke test passes on MATLAB (skips cleanly on Octave)"
    - "All 30 TestCanonicalMapper test methods pass on MATLAB (28 data-model tests green from Plans 02-03, plus testEditorConstructs from this plan, plus the two grep-gate tests counted within those 30); on Octave the suite runs 29 with testEditorConstructs skipped cleanly (no hard failure)"
  artifacts:
    - path: "libs/Fleet/CanonicalMapEditor.m"
      provides: "Standalone MATLAB-only uifigure editor: 3-row uigridlayout, 6-column uitable, Promote/Override/Save/Refresh/Show-Pending actions"
      contains: "classdef CanonicalMapEditor < handle"
      min_lines: 200
  key_links:
    - from: "libs/Fleet/CanonicalMapEditor.m"
      to: "CanonicalMapper.reviewPending / Entries_"
      via: "reload_ rebuilds the uitable Data from mapper"
      pattern: "reviewPending\\(|\\.Entries_"
    - from: "CanonicalMapEditor Promote button"
      to: "CanonicalMapper.confirm"
      via: "onPromote_ -> mapper.confirm(logicalId, machineId) after uiconfirm gate"
      pattern: "\\.confirm\\("
    - from: "CanonicalMapEditor Override button"
      to: "CanonicalMapper.override"
      via: "onOverride_ -> inputdlg -> mapper.override(...)"
      pattern: "\\.override\\("
---

<objective>
Build the standalone `CanonicalMapEditor` uifigure in `libs/Fleet/CanonicalMapEditor.m` implementing the UI-SPEC.md contract: a non-modal MATLAB-only window with a 3-row uigridlayout (toolbar / uitable / action row), a 6-column read-only uitable (Logical Sensor / Machine / Local Key / Units Match / Confidence / Status), and Promote / Override / Save / Refresh / Show-Pending actions. This satisfies CANON-05 (review and edit the canonical map via a table; promote entries).

Purpose: CANON-05 — the human review surface. It is the ONLY way a user can promote a LOW-confidence or unit-mismatch entry into the comparison-eligible set, which is the manual half of "no wrong comparison can happen silently." It is a standalone editor (NOT a Companion modification — full Companion embedding is Phase 1044), MATLAB-only (uifigure), and consumes the completed CanonicalMapper API from Plan 03.
Output: `libs/Fleet/CanonicalMapEditor.m`.

This plan has a checkpoint: the final task is a human-verify checkpoint for the visual/interaction behavior that headless unit tests cannot assert (the Manual-Only Verification row in VALIDATION.md). The automated smoke test (testEditorConstructs) turns GREEN here, completing 30/30.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/1041-canonicalmapper/1041-RESEARCH.md
@.planning/phases/1041-canonicalmapper/1041-UI-SPEC.md
@.planning/phases/1041-canonicalmapper/1041-VALIDATION.md

<interfaces>
<!-- CanonicalMapEditor consumes the completed CanonicalMapper API (Plan 03). The full visual/layout/copy -->
<!-- contract is in 1041-UI-SPEC.md — read it; values below are the load-bearing extracts. -->

CanonicalMapper API this editor calls (built in Plans 02/03):
```matlab
pending = mapper.reviewPending()                 % cell of entry structs needing review
keys = mapper.Entries_.keys()                    % iterate all logicalIds (Entries_ is SetAccess=private, readable)
mapper.confirm(logicalId, machineId)             % Promote button target
mapper.override(logicalId, machineId, localKey)  % Override button target
mapper.save(filepath)                            % Save button target
```
Entry struct fields used for table rows: logicalId, machineId, localKey, localUnits, similarity, confidence, status, unitMismatch.

uitable contract (UI-SPEC.md § Table Contract — LOCKED):
```matlab
ColumnName     = {'Logical Sensor', 'Machine', 'Local Key', 'Units Match', 'Confidence', 'Status'};
ColumnWidth    = {180, 80, 150, 80, 80, 90};
ColumnEditable = false(1, 6);          % ALL read-only; editing via Override button
RowName        = {};
FontName       = 'Menlo';  FontSize = 10;
CellSelectionCallback = @(src, ev) obj.onCellSelected_(ev);   % NOT CellSelectionChangedFcn
Data           = cell(0, 6);
```
Cell display rules (UI-SPEC.md § Color / Copywriting — LOCKED, no per-cell color in R2020b):
- Units Match column: 'NO' when entry.unitMismatch, else 'YES'
- Confidence column: 'HIGH' / 'MEDIUM' / '[!] LOW'; if unitMismatch, prefix '[!] ' regardless of level
- Status column: entry.status verbatim ('AUTO'/'PENDING'/'CONFIRMED'/'OVERRIDDEN')
- Sort: primary by logicalId asc, secondary by machineId asc (deterministic; TagStatusTableWindow.rebuildAll_ pattern)

Layout (UI-SPEC.md § Layout Contract — LOCKED):
```
uifigure: Name='Canonical Sensor Map — FastSense Companion', Position=[100 100 1000 580], Color=t.WidgetBackground
root uigridlayout(hFig,[3 1]): RowHeight={28,'1x',36}, ColumnWidth={'1x'}, Padding=[24 24 24 24], RowSpacing=8
Row1 nested [1 5] grid {180,'1x',80,80,80}, ColumnSpacing=8: title label (FontSize=14 bold) | filter uieditfield | 'Show Pending' | 'Refresh' | 'Save'
Row2: the uitable
Row3 nested [1 4] grid {160,120,'1x',200}, ColumnSpacing=8: 'Promote to Confirmed' (PRIMARY) | 'Override Local Key' | status label | 'Close'
```
Theme inheritance: read the active CompanionTheme exactly as TagStatusTableWindow does (TagStatusTableWindow.m:127-132). Stripe pair via the stripePairFromTheme_ pattern (TagStatusTableWindow.m:666-674): isDark = mean(t.DashboardBackground)<0.5.

uiconfirm gates (UI-SPEC.md § Copywriting — Destructive Confirmation — copy text verbatim):
- Promote a LOW-confidence (no mismatch) row -> Confirmation #1 ('Low-Confidence Mapping', options {'Promote Anyway','Cancel'}, DefaultOption 'Cancel', Icon 'warning')
- Promote a unitMismatch row -> Confirmation #2 ('Unit Mismatch Warning', same options, Icon 'warning')
- Close with IsDirty_ true -> Confirmation #3 ('Unsaved Changes', options {'Close Without Saving','Cancel'}, Icon 'question')
- Neither LOW nor mismatch -> confirm directly, no dialog.

Lifecycle (CLAUDE.md cross-cutting constraints — Phase 1018 lock):
- Listeners_ cell array; delete(obj.Listeners_) in CloseRequestFcn (none needed here unless you addlistener)
- IsOpen public logical set true after construction, false on close
- CloseRequestFcn = @(~,~) obj.onCloseRequest_()
- Standalone uifigure; never parent it inside the Companion

Reference implementations to mirror (read these):
- libs/FastSenseCompanion/TagStatusTableWindow.m — theme read (127-132), stripePairFromTheme_ (666-674), uitable construction (231-244), deterministic rebuild sort (583)
- libs/FastSenseCompanion/NotificationCenterPane.m:178-190 — uitable in uifigure, CellSelectionCallback, ColumnEditable logical array
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: CanonicalMapEditor uifigure scaffold + 3-row layout + 6-column uitable (UI-SPEC layout)</name>
  <files>libs/Fleet/CanonicalMapEditor.m</files>
  <read_first>
    - .planning/phases/1041-canonicalmapper/1041-UI-SPEC.md (the FULL § Layout Contract, § Table Contract, § Spacing Scale, § Typography, § Color — this is the authoritative visual contract; copy the exact px/RGB/FontSize values)
    - libs/FastSenseCompanion/TagStatusTableWindow.m (lines 127-132 theme read; 231-244 uitable; 583 sort; 666-674 stripePairFromTheme_)
    - libs/FastSenseCompanion/NotificationCenterPane.m (lines 178-190 — uitable CellSelectionCallback + ColumnEditable logical array pattern)
    - libs/Fleet/CanonicalMapper.m (the completed API from Plan 03 — Entries_ keys(), reviewPending(); the entry struct fields you render)
  </read_first>
  <action>
    Create `libs/Fleet/CanonicalMapEditor.m` as `classdef CanonicalMapEditor < handle`. MATLAB-only (uifigure). Implement the layout + table; wire data via reload_.

    1. CLASS HEADER comment per CLAUDE.md: description ("Standalone uifigure to review/edit/promote a CanonicalMapper's entries"), Usage `ed = CanonicalMapEditor(mapper)`, Properties list, Methods list, `% See also CanonicalMapper`. Note in the header that this is MATLAB-only (uifigure; Octave unsupported), matching FastSenseCompanion/TagStatusTableWindow.

    2. PROPERTIES:
       ```matlab
       properties (SetAccess = private)
           Mapper_        % CanonicalMapper handle
           hFig_          % uifigure handle
           Table_         % uitable handle
           PromoteBtn_    % uibutton (primary CTA)
           StatusLabel_   % uilabel (count text)
           FilterField_   % uieditfield (text filter)
           SelectedRow_ = []   % index into the current Data
           RowEntries_  = {}   % cell of entry structs, parallel to table rows (maps row -> entry)
           Theme_         % active CompanionTheme struct
           FilePath_ = '' % assigned on first Save
           IsDirty_ = false
           ShowPendingOnly_ = false
       end
       properties
           IsOpen = false  % public — testEditorConstructs asserts this
       end
       ```

    3. CONSTRUCTOR `function obj = CanonicalMapEditor(mapper)`:
       - Validate `nargin>=1 && isa(mapper,'CanonicalMapper')` else `error('CanonicalMapEditor:invalidInput','CanonicalMapEditor requires a CanonicalMapper instance.')`.
       - Store `obj.Mapper_ = mapper;`.
       - Read the active theme the way TagStatusTableWindow does (TagStatusTableWindow.m:127-132) into `obj.Theme_`. If the Companion theme helper is not reachable standalone, fall back to a sensible default struct with the dark RGBs from UI-SPEC § Color (WidgetBackground [0.09 0.13 0.24], ForegroundColor near-white, Accent [0.31 0.80 0.64], etc.). Document the fallback.
       - Build the uifigure: `obj.hFig_ = uifigure('Name','Canonical Sensor Map — FastSense Companion','Position',[100 100 1000 580],'Color',obj.Theme_.WidgetBackground);` and `obj.hFig_.CloseRequestFcn = @(~,~) obj.onCloseRequest_();`.
       - `drawnow;` before constructing child widgets (MEMORY: classical-axes/uifigure stale-render guard — here it ensures the figure is realized before layout; cheap and matches the documented uifigure idiom).
       - Build root `uigridlayout(obj.hFig_,[3 1])` with RowHeight {28,'1x',36}, ColumnWidth {'1x'}, Padding [24 24 24 24], RowSpacing 8.
       - Row 1: nested `uigridlayout(root,[1 5])` ColumnWidth {180,'1x',80,80,80} ColumnSpacing 8 Padding [0 0 0 0]; add: a uilabel 'Canonical Sensor Map' (FontSize 14, FontWeight 'bold'), `obj.FilterField_` uieditfield('text') Placeholder 'Filter entries...' (FontSize 11, ValueChangedFcn -> obj.applyFilter_), a 'Show Pending' uibutton (ButtonPushedFcn -> obj.togglePendingFilter_), a 'Refresh' uibutton (-> obj.reload_), a 'Save' uibutton (-> obj.onSave_). Copy exact labels/tooltips from UI-SPEC § Copywriting.
       - Row 2: `obj.Table_ = uitable(root)` with Layout.Row=2 and the LOCKED table contract: ColumnName/ColumnWidth/ColumnEditable=false(1,6)/RowName={}/FontName 'Menlo'/FontSize 10/CellSelectionCallback=@(src,ev) obj.onCellSelected_(ev)/Data=cell(0,6). Set BackgroundColor to the stripe pair (port stripePairFromTheme_) and ForegroundColor to the theme foreground.
       - Row 3: nested `uigridlayout(root,[1 4])` ColumnWidth {160,120,'1x',200} ColumnSpacing 8 Padding [0 0 0 0]; add `obj.PromoteBtn_` 'Promote to Confirmed' (FontSize 11 bold, ButtonPushedFcn -> obj.onPromote_), 'Override Local Key' uibutton (-> obj.onOverride_), `obj.StatusLabel_` uilabel (FontSize 10, FontName 'Menlo'), 'Close' uibutton (-> obj.onCloseRequest_). Exact labels/tooltips from UI-SPEC § Copywriting.
       - Call `obj.reload_();` to populate the table.
       - Set `obj.IsOpen = true;`.

    4. `reload_(obj)` (data binding): iterate `obj.Mapper_.Entries_.keys()`; for each logicalId, for each entry in the cluster, build a row. Apply the LOCKED display rules:
       - Col1 logicalId; Col2 machineId; Col3 localKey;
       - Col4 = `'NO'` if entry.unitMismatch else `'YES'`;
       - Col5 = confidence label: 'HIGH'/'MEDIUM'/'LOW' with `'[!] '` prefix when unitMismatch OR confidence=='LOW' (so LOW always shows '[!] LOW'; a HIGH/MEDIUM with mismatch shows '[!] HIGH'/'[!] MEDIUM');
       - Col6 = entry.status.
       Collect entries into `obj.RowEntries_` parallel to rows so callbacks can map a selected row back to its (logicalId, machineId). SORT rows primary by logicalId asc, secondary by machineId asc (deterministic — TagStatusTableWindow.m:583 pattern). If ShowPendingOnly_ or a filter string is active, filter rows (entry in reviewPending set, or logicalId/localKey contains the filter via `~isempty(strfind(lower(...),lower(filter)))` — Octave-safe idiom even though this file is MATLAB-only, for consistency). Assign `obj.Table_.Data` and update `obj.StatusLabel_` to `'{N} entries, {P} pending review'` (or `'{N} entries — all reviewed'` when P==0) using numel(reviewPending).
       Empty state: if 0 entries, show the empty-state copy in the status label ('No mappings yet ...').

    5. Stub the interaction callbacks as real-but-minimal for now so the figure constructs without error; Task 2 fills Promote/Override/Save behavior. At minimum implement: `onCellSelected_(obj,ev)` (store `obj.SelectedRow_ = ev.Indices(1)` when non-empty, else []), `applyFilter_`, `togglePendingFilter_`, `reload_`, and `onCloseRequest_(obj)` (delete any listeners, `delete(obj.hFig_)`, `obj.IsOpen=false`). onPromote_/onOverride_/onSave_ may exist as method stubs that Task 2 completes — but they MUST be defined (not missing) so the ButtonPushedFcn handles resolve.

    Constraint: this is the ONLY file with UI code. Do NOT modify CanonicalMapper.m, FastSenseCompanion, or any existing file. Do NOT call setProject. Do NOT parent into the Companion.
  </action>
  <verify>
    <automated>runtests('tests/suite/TestCanonicalMapper/testEditorConstructs') — GREEN on MATLAB (constructs + IsOpen true + deletes), SKIPS on Octave. Run via mcp__matlab__run_matlab_test_file on tests/suite/TestCanonicalMapper.m (the harness runs the single method).</automated>
  </verify>
  <acceptance_criteria>
    - File exists: `ls libs/Fleet/CanonicalMapEditor.m` exits 0
    - `grep -c "classdef CanonicalMapEditor < handle" libs/Fleet/CanonicalMapEditor.m` returns `1`
    - uifigure (NOT classical figure) used: `grep -c "uifigure(" libs/Fleet/CanonicalMapEditor.m` >= 1; `grep -c "uigridlayout(" libs/Fleet/CanonicalMapEditor.m` >= 3 (root + 2 nested)
    - Locked table contract present: `grep -c "false(1, 6)\|false(1,6)" libs/Fleet/CanonicalMapEditor.m` >= 1; `grep -c "CellSelectionCallback" libs/Fleet/CanonicalMapEditor.m` >= 1; `grep -c "CellSelectionChangedFcn" libs/Fleet/CanonicalMapEditor.m` returns `0` (the WRONG property must be absent)
    - Locked column headers present: `grep -c "Logical Sensor" libs/Fleet/CanonicalMapEditor.m` >= 1 and `grep -c "Units Match" libs/Fleet/CanonicalMapEditor.m` >= 1
    - IsOpen property set true: `grep -c "IsOpen = true\|IsOpen=true" libs/Fleet/CanonicalMapEditor.m` >= 1
    - CloseRequestFcn wired: `grep -c "CloseRequestFcn" libs/Fleet/CanonicalMapEditor.m` >= 1
    - Does NOT modify or call into the Companion data path: `grep -c "setProject" libs/Fleet/CanonicalMapEditor.m` returns `0`
    - `mcp__matlab__check_matlab_code` on libs/Fleet/CanonicalMapEditor.m reports no error-level diagnostics
    - `runtests('tests/suite/TestCanonicalMapper/testEditorConstructs')` PASSES on MATLAB (or is reported Incomplete/Skipped if run on Octave — never a hard failure)
  </acceptance_criteria>
  <done>CanonicalMapEditor.m constructs a non-modal uifigure with the locked 3-row layout and 6-column read-only uitable populated from the mapper (sorted, with NO/YES + [!] display rules and the pending-count status label); testEditorConstructs passes on MATLAB; no existing file is touched.</done>
</task>

<task type="auto">
  <name>Task 2: Promote / Override / Save behavior + uiconfirm safety gates (UI-SPEC interaction)</name>
  <files>libs/Fleet/CanonicalMapEditor.m</files>
  <read_first>
    - libs/Fleet/CanonicalMapEditor.m (current state from Task 1 — the callback stubs you now complete)
    - .planning/phases/1041-canonicalmapper/1041-UI-SPEC.md (§ Interaction Contract + § Copywriting — the three uiconfirm dialogs verbatim, the inputdlg override flow, the Save uiputfile flow, the IsDirty_ unsaved-changes close gate)
    - libs/Fleet/CanonicalMapper.m (confirm/override/save signatures from Plan 03)
  </read_first>
  <action>
    Complete the interaction callbacks in `libs/Fleet/CanonicalMapEditor.m` per UI-SPEC § Interaction Contract. Wrap every callback body in try/catch surfacing failures via non-blocking `uialert(obj.hFig_, msg, title)` (CLAUDE.md cross-cutting: every callback wrapped in try/catch + non-blocking alert).

    1. `onPromote_(obj)`: if `isempty(obj.SelectedRow_)`, do nothing (button styled inactive). Else map SelectedRow_ -> entry via `obj.RowEntries_{obj.SelectedRow_}`. Then GATE per UI-SPEC:
       - If `entry.unitMismatch` is true: show uiconfirm Confirmation #2 (Unit Mismatch Warning) — copy the exact message/title/options/DefaultOption 'Cancel'/CancelOption/Icon 'warning' from UI-SPEC § Copywriting Confirmation #2. Proceed only if the user selects 'Promote Anyway'.
       - Else if `strcmp(entry.confidence,'LOW')`: show uiconfirm Confirmation #1 (Low-Confidence Mapping) verbatim from UI-SPEC. Proceed only on 'Promote Anyway'.
       - Else (HIGH/MEDIUM, no mismatch): proceed directly, no dialog.
       On proceed: `obj.Mapper_.confirm(entry.logicalId, entry.machineId);` set `obj.IsDirty_ = true;` then `obj.reload_();`.

    2. `onOverride_(obj)`: if no selection, do nothing. Else `entry = obj.RowEntries_{obj.SelectedRow_}`. Open `answer = inputdlg('Enter the correct local key for this machine:','Override Mapping',1,{entry.localKey});`. If empty/cancelled -> abort. If the entered string is empty -> `uialert(obj.hFig_,'Local key cannot be empty. Enter the correct sensor key for this machine.','Override Mapping')` and abort. Else `newKey = strtrim(answer{1}); obj.Mapper_.override(entry.logicalId, entry.machineId, newKey); obj.IsDirty_ = true; obj.reload_();`.

    3. `onSave_(obj)`: if `isempty(obj.FilePath_)`: `[f,p] = uiputfile({'*.json','Canonical Map JSON'},'Save Canonical Map');` if `isequal(f,0)` abort silently; else `obj.FilePath_ = fullfile(p,f);`. Then `obj.Mapper_.save(obj.FilePath_); obj.IsDirty_ = false;` and update status. On error -> `uialert(obj.hFig_, sprintf('Failed to save: %s. Check file permissions and try again.', err.message),'Save')`.

    4. `togglePendingFilter_(obj)`: flip `obj.ShowPendingOnly_`; restyle the Show Pending button (BackgroundColor = Accent when active, WidgetBorderColor when not) per UI-SPEC § Interaction; call `obj.reload_()`.

    5. `applyFilter_(obj)`: read `obj.FilterField_.Value`; store and `obj.reload_()` (reload_ already applies the filter string via the strfind idiom from Task 1).

    6. Selection -> Promote button styling in `onCellSelected_`: when a row is selected, set `obj.PromoteBtn_.BackgroundColor = obj.Theme_.Accent; obj.PromoteBtn_.FontColor = obj.Theme_.DashboardBackground;` (active). When cleared, reset to WidgetBorderColor / ForegroundColor. (UI-SPEC § Interaction — Cell Selection.)

    7. `onCloseRequest_(obj)`: if `obj.IsDirty_`, show uiconfirm Confirmation #3 (Unsaved Changes) verbatim; proceed to close only on 'Close Without Saving'. On proceed: delete any listeners in Listeners_ (if you created any — none required), `delete(obj.hFig_); obj.IsOpen = false;`.

    8. Re-run the full suite. testEditorConstructs stays GREEN; all 30 tests now GREEN on MATLAB. No regression to the 28 data-model tests.

    Constraint: still ONLY this file changes. Use only built-in uifigure widgets + uiconfirm/uialert/inputdlg/uiputfile (UI-SPEC § Registry Safety). No third-party deps.
  </action>
  <verify>
    <automated>runtests('tests/suite/TestCanonicalMapper') — all 30 GREEN on MATLAB (testEditorConstructs included), 0 failures; testEditorConstructs skips on Octave. Run via mcp__matlab__run_matlab_test_file.</automated>
  </verify>
  <acceptance_criteria>
    - Promote wired to confirm: `grep -c "\.confirm(" libs/Fleet/CanonicalMapEditor.m` >= 1
    - Override wired to override + inputdlg: `grep -c "\.override(" libs/Fleet/CanonicalMapEditor.m` >= 1; `grep -c "inputdlg(" libs/Fleet/CanonicalMapEditor.m` >= 1
    - Save wired to mapper.save + uiputfile: `grep -c "\.save(" libs/Fleet/CanonicalMapEditor.m` >= 1; `grep -c "uiputfile(" libs/Fleet/CanonicalMapEditor.m` >= 1
    - Safety gates present: `grep -c "uiconfirm(" libs/Fleet/CanonicalMapEditor.m` >= 3 (three confirmation dialogs); the exact warning titles appear: `grep -c "Low-Confidence Mapping" libs/Fleet/CanonicalMapEditor.m` >= 1, `grep -c "Unit Mismatch Warning" libs/Fleet/CanonicalMapEditor.m` >= 1, `grep -c "Unsaved Changes" libs/Fleet/CanonicalMapEditor.m` >= 1
    - Callbacks guarded: `grep -c "uialert(" libs/Fleet/CanonicalMapEditor.m` >= 1 and `grep -c "try" libs/Fleet/CanonicalMapEditor.m` >= 3 (callbacks wrapped)
    - IsDirty_ tracking present: `grep -c "IsDirty_" libs/Fleet/CanonicalMapEditor.m` >= 3
    - Still no existing-file modification: `git status --porcelain libs/Fleet/CanonicalMapper.m` shows no change in this plan (only CanonicalMapEditor.m is modified)
    - `mcp__matlab__check_matlab_code` on libs/Fleet/CanonicalMapEditor.m reports no error-level diagnostics
    - `runtests('tests/suite/TestCanonicalMapper')` reports 30 passing on MATLAB (or 29 passing + 1 skipped on Octave); 0 failures
  </acceptance_criteria>
  <done>Promote (gated by the two uiconfirm warnings), Override (inputdlg -> mapper.override), Save (uiputfile -> mapper.save), Show-Pending toggle, filter, selection styling, and the unsaved-changes close gate are implemented per UI-SPEC; all callbacks try/catch-guarded; 30/30 tests GREEN on MATLAB.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3 (checkpoint): Human-verify CanonicalMapEditor visual layout + promote/override flow</name>
  <files>libs/Fleet/CanonicalMapEditor.m</files>
  <action>CHECKPOINT — no code is written in this task. Pause and have the user visually verify the CanonicalMapEditor in the running MATLAB session per the steps in how-to-verify below. This is the Manual-Only Verification row in VALIDATION.md — the visual rendering and interactive promote/override flow that headless unit tests cannot assert. Do not proceed past this task until the user types "approved" or reports discrepancies.</action>
  <what-built>
    The standalone CanonicalMapEditor uifigure (CANON-05). Claude has implemented the full UI-SPEC contract — 3-row layout, 6-column read-only uitable, Promote/Override/Save/Refresh/Show-Pending actions, and the three uiconfirm safety gates — and the automated smoke test (testEditorConstructs) plus all 27 data-model tests are GREEN. This checkpoint covers the Manual-Only Verification row in VALIDATION.md: the visual rendering and interactive promote flow that headless unit tests cannot assert.
  </what-built>
  <how-to-verify>
    In the running MATLAB session (the user has one open; figures appear on their screen):

    1. Build a mapper with a known mismatch and a low-confidence match, then open the editor:
       ```matlab
       install;
       infos = {
           struct('machineId','M01','localKey','temp_motor','name','Motor Temp','units','degC'), ...
           struct('machineId','M02','localKey','temp_mtor', 'name','Temp Mtor', 'units','K'), ...    % unit mismatch vs M01
           struct('machineId','M03','localKey','t_mtr',     'name','T Mtr',     'units','degC') ...    % lower-similarity member
       };
       m = CanonicalMapper(); m.suggest(infos);
       ed = CanonicalMapEditor(m);
       ```
    2. CONFIRM VISUALLY:
       - The window titled 'Canonical Sensor Map — FastSense Companion' opens with a toolbar row (title + filter + Show Pending + Refresh + Save), a table, and an action row (Promote to Confirmed + Override Local Key + status text + Close).
       - The table shows the six columns: Logical Sensor, Machine, Local Key, Units Match, Confidence, Status. Rows for the same logical sensor are grouped together (sorted).
       - The unit-mismatch row shows 'NO' in the Units Match column and a '[!] ' prefix in the Confidence column. A LOW-confidence row shows '[!] LOW'.
       - The status label reads e.g. 'N entries, P pending review'.
    3. CONFIRM INTERACTION:
       - Click the low-confidence row, then click 'Promote to Confirmed'. A warning dialog ('Low-Confidence Mapping') appears with 'Promote Anyway' / 'Cancel', defaulting to Cancel. Click 'Promote Anyway'. The row's Status changes to CONFIRMED on refresh.
       - Click the unit-mismatch row, click 'Promote to Confirmed' — the 'Unit Mismatch Warning' dialog appears. Confirm it gates correctly.
       - Click a row, click 'Override Local Key', enter a new key — the table refreshes with the new local key and Status OVERRIDDEN.
       - Verify in the workspace that the mapper reflects the change: `m.reviewPending()` no longer includes the promoted entry; the OVERRIDDEN entry is present in `m.toStruct().entries`.
       - Click 'Show Pending' — only pending rows remain; click again — all rows return.
    4. Close the window (with an unsaved change, the 'Unsaved Changes' dialog should appear).

    If anything does not match the UI-SPEC (layout, copy, gates, or the mapper not reflecting the change), describe the discrepancy.
  </how-to-verify>
  <read_first>
    - .planning/phases/1041-canonicalmapper/1041-UI-SPEC.md (the contract you are verifying against)
  </read_first>
  <verify>
    <automated>MANUAL — visual/interaction verification only (Manual-Only Verification row in VALIDATION.md). The automated proxy is testEditorConstructs (already GREEN from Tasks 1-2). No additional automated command for the visual layout/promote flow.</automated>
  </verify>
  <acceptance_criteria>
    - The editor window renders the locked layout and 6 columns.
    - The unit-mismatch row shows 'NO' + '[!]' and the LOW row shows '[!] LOW' (no color required).
    - Promote on a LOW row and on a mismatch row each trigger the correct uiconfirm gate; confirming updates mapper state (status -> CONFIRMED, entry leaves reviewPending).
    - Override updates the local key and sets status OVERRIDDEN in the mapper.
    - Show Pending toggles the filtered view; Close with unsaved changes prompts.
  </acceptance_criteria>
  <done>User has visually confirmed the editor renders per UI-SPEC and the promote/override flow updates mapper state, or reported discrepancies for a gap-closure pass.</done>
  <resume-signal>Type "approved" to complete the phase, or describe any UI-SPEC discrepancies for a gap-closure pass.</resume-signal>
</task>

</tasks>

<verification>
- `runtests('tests/suite/TestCanonicalMapper')`: 30/30 GREEN on MATLAB (29 + 1 skipped on Octave). Phase test suite complete.
- `grep -rn "uifigure\|uitable\|uicontrol" libs/Fleet/CanonicalMapper.m` returns 0 (UI stays out of the data model — Critical Invariant #2).
- mcp__matlab__check_matlab_code on CanonicalMapEditor.m: no errors.
- Manual UAT checkpoint approved (visual layout + promote/override flow per UI-SPEC).
- `run_all_tests` green (phase gate) before /gsd:verify-work.
</verification>

<success_criteria>
- User can review and edit the canonical map via a table (logical name / per-machine local key / status / confidence) and promote entries (CANON-05 success criterion #4).
- The editor is standalone (no Companion file modified — Companion embedding deferred to Phase 1044 per RESEARCH.md Q4).
- All UI code lives in CanonicalMapEditor.m; CanonicalMapper.m remains Octave-safe data model.
- 30/30 tests GREEN on MATLAB; manual UAT approved.
</success_criteria>

<output>
After completion, create `.planning/phases/1041-canonicalmapper/1041-04-SUMMARY.md`
</output>
</content>
