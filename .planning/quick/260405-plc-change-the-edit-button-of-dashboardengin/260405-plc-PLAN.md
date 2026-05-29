---
phase: quick
plan: 260405-plc
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/Dashboard/DashboardToolbar.m
  - tests/suite/TestDashboardToolbar.m
autonomous: true
requirements: [quick-task]
must_haves:
  truths:
    - "Clicking Edit opens the MATLAB source file in the editor"
    - "If no FilePath is set, Edit button is disabled or shows a warning"
  artifacts:
    - path: "libs/Dashboard/DashboardToolbar.m"
      provides: "Edit button opens source file via MATLAB edit() command"
  key_links:
    - from: "DashboardToolbar.onEdit"
      to: "DashboardEngine.FilePath"
      via: "obj.Engine.FilePath property access"
      pattern: "edit\\(obj\\.Engine\\.FilePath\\)"
---

<objective>
Change the DashboardToolbar Edit button so it opens the MATLAB file that created the dashboard (using MATLAB's `edit()` command on `Engine.FilePath`) instead of toggling the DashboardBuilder edit mode.

Purpose: Let users quickly jump to the source script to make changes, rather than using the in-GUI builder.
Output: Modified DashboardToolbar.m with new onEdit behavior.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@libs/Dashboard/DashboardToolbar.m
@libs/Dashboard/DashboardEngine.m
</context>

<tasks>

<task type="auto">
  <name>Task 1: Change Edit button to open source file in MATLAB editor</name>
  <files>libs/Dashboard/DashboardToolbar.m</files>
  <action>
Replace the `onEdit` method (lines 162-175) in DashboardToolbar.m. The new behavior:

1. Read `obj.Engine.FilePath` — this is set by `DashboardEngine.load()` to the path of the `.m` or `.json` file that created the dashboard.
2. If FilePath is non-empty and the file exists, call `edit(obj.Engine.FilePath)` to open it in the MATLAB editor.
3. If FilePath is empty, call `warndlg('No source file associated with this dashboard. Save first or load from a file.', 'Edit')` to inform the user.
4. If FilePath is set but file does not exist, call `warndlg(sprintf('Source file not found: %s', obj.Engine.FilePath), 'Edit')`.

Remove the Builder property (line 22: `Builder = []`) and remove the DashboardBuilder import/usage entirely since the Edit button no longer toggles build mode. Keep the `hEditBtn` String as 'Edit' always (no toggle to 'Done').

Also remove the `obj.hLiveBtn Enable off/on` toggling that was part of the old edit mode since opening a file in the editor does not conflict with live mode.

The full new onEdit method:
```matlab
function onEdit(obj)
    fp = obj.Engine.FilePath;
    if isempty(fp)
        warndlg('No source file associated with this dashboard. Save first or load from a file.', 'Edit');
        return;
    end
    if ~exist(fp, 'file')
        warndlg(sprintf('Source file not found: %s', fp), 'Edit');
        return;
    end
    edit(fp);
end
```
  </action>
  <verify>
    <automated>cd /Users/hannessuhr/FastPlot && grep -A 12 'function onEdit' libs/Dashboard/DashboardToolbar.m | grep -q 'edit(fp)' && echo "PASS: edit() call found" || echo "FAIL"</automated>
  </verify>
  <done>Edit button calls MATLAB edit() on Engine.FilePath; Builder property and DashboardBuilder dependency removed from DashboardToolbar; warndlg shown when no file path is set or file not found.</done>
</task>

</tasks>

<verification>
- `grep 'DashboardBuilder' libs/Dashboard/DashboardToolbar.m` returns no matches (Builder dependency removed)
- `grep 'edit(fp)' libs/Dashboard/DashboardToolbar.m` returns a match
- `grep 'warndlg' libs/Dashboard/DashboardToolbar.m` returns matches for both warning cases
- Existing test suite passes: `cd /Users/hannessuhr/FastPlot && octave --eval "install(); run_all_tests();"` (no regressions)
</verification>

<success_criteria>
- Edit button opens MATLAB editor with the dashboard source file
- Graceful handling when no FilePath is set (warning dialog)
- DashboardBuilder no longer referenced from DashboardToolbar
- No test regressions
</success_criteria>

<output>
After completion, create `.planning/quick/260405-plc-change-the-edit-button-of-dashboardengin/260405-plc-SUMMARY.md`
</output>
