---
phase: quick-260508-huo
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/FastSenseCompanion/runFilterDashboardsTests.m
  - libs/FastSenseCompanion/runInspectorResolveStateTests.m
  - libs/FastSenseCompanion/runOpenAdHocPlotTests.m
  - libs/FastSenseCompanion/private/runFilterDashboardsTests.m
  - libs/FastSenseCompanion/private/runInspectorResolveStateTests.m
  - libs/FastSenseCompanion/private/runOpenAdHocPlotTests.m
  - libs/Dashboard/DashboardEngine.m
autonomous: true
requirements:
  - CI-FIX-OCTAVE-RUNNERS
  - CI-FIX-MATLAB-INFO-SEGFAULT
must_haves:
  truths:
    - "Octave CI: tests/test_companion_filter_dashboards.m successfully resolves runFilterDashboardsTests() at call site"
    - "Octave CI: tests/test_companion_inspector_resolve_state.m successfully resolves runInspectorResolveStateTests()"
    - "Octave CI: tests/test_companion_open_ad_hoc_plot.m successfully resolves runOpenAdHocPlotTests()"
    - "MATLAB CI: TestDashboardInfo suite no longer segfaults under -batch -nodisplay"
    - "Interactive MATLAB session still pops the info HTML in a browser tab when showInfo() is called"
    - "PR is open against main with both fixes summarized; awaits human review"
  artifacts:
    - path: "libs/FastSenseCompanion/runFilterDashboardsTests.m"
      provides: "Octave-reachable runner that exercises private filterDashboards helper"
    - path: "libs/FastSenseCompanion/runInspectorResolveStateTests.m"
      provides: "Octave-reachable runner that exercises private inspectorResolveState helper"
    - path: "libs/FastSenseCompanion/runOpenAdHocPlotTests.m"
      provides: "Octave-reachable runner that exercises private openAdHocPlot helper"
    - path: "libs/Dashboard/DashboardEngine.m"
      provides: "writeAndOpenInfoHtml that guards web() behind interactive-session check"
  key_links:
    - from: "tests/test_companion_filter_dashboards.m"
      to: "libs/FastSenseCompanion/runFilterDashboardsTests.m"
      via: "function-on-path resolution after install() addpath of libs/FastSenseCompanion"
      pattern: "runFilterDashboardsTests\\(\\)"
    - from: "libs/Dashboard/DashboardEngine.m::writeAndOpenInfoHtml"
      to: "isInteractiveSession check (usejava('desktop') && ~batchStartupOptionUsed)"
      via: "inline guard around web() call"
      pattern: "usejava\\('desktop'\\)"
---

<objective>
Unblock both CI jobs (Octave Tests + MATLAB Tests) on Linux runners with two surgical, independently-revertable fixes, then push the branch and open a PR for human review.

Purpose: Latest main runs (failed run id 25550691546) leave both CI lanes red — Octave tests fail because three companion test runners live in `private/` (unreachable from `tests/`), and MATLAB Tests segfault when `web()` is invoked inside the headless `-batch -nodisplay` runner. Both have pinpointed root causes; this plan ships the smallest viable fix for each and pushes a PR.

Output:
- 3 runner files relocated one directory up (no content changes)
- DashboardEngine.writeAndOpenInfoHtml guards web() with isInteractiveSession check
- Branch pushed to origin and PR opened against main (not merged)
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/STATE.md

# Key existing patterns the executor should follow

@libs/Dashboard/DashboardProgress.m
@libs/FastSenseCompanion/runFilterTagsTests.m

<interfaces>
<!-- Helper pattern to mirror inline (do NOT refactor DashboardProgress; copy the logic) -->

From libs/Dashboard/DashboardProgress.m:148-158:
```matlab
function tf = isInteractiveSession()
    if exist('OCTAVE_VERSION', 'builtin')
        tf = exist('isguirunning', 'builtin') && isguirunning();
        return;
    end
    tf = usejava('desktop');
    if tf && exist('batchStartupOptionUsed', 'builtin') && ...
            batchStartupOptionUsed()
        tf = false;
    end
end
```

Current DashboardEngine.m::writeAndOpenInfoHtml branch that segfaults (lines 808-818):
```matlab
if exist('OCTAVE_VERSION', 'builtin')
    if ismac
        system(['open "' obj.InfoTempFile '"']);
    elseif ispc
        system(['cmd /c start "" "' obj.InfoTempFile '"']);
    else
        system(['xdg-open "' obj.InfoTempFile '"']);
    end
else
    web(obj.InfoTempFile, '-new');   % <-- this segfaults under -batch -nodisplay
end
```

Working sibling pattern (already at correct level — model the moves on this):
- libs/FastSenseCompanion/runFilterTagsTests.m  (NOT in private/)
- Reaches private/filterTags.m because it sits in the parent of private/
- Called from tests/test_companion_filter_tags.m successfully on both MATLAB and Octave
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Hoist 3 companion test-runner helpers out of private/ so tests can reach them</name>
  <files>
    libs/FastSenseCompanion/runFilterDashboardsTests.m (new — moved from private/),
    libs/FastSenseCompanion/runInspectorResolveStateTests.m (new — moved from private/),
    libs/FastSenseCompanion/runOpenAdHocPlotTests.m (new — moved from private/)
  </files>
  <action>
    Move three runner files from `libs/FastSenseCompanion/private/` to `libs/FastSenseCompanion/` using `git mv` so history is preserved.

    Run from repo root:
    ```bash
    git mv libs/FastSenseCompanion/private/runFilterDashboardsTests.m libs/FastSenseCompanion/runFilterDashboardsTests.m
    git mv libs/FastSenseCompanion/private/runInspectorResolveStateTests.m libs/FastSenseCompanion/runInspectorResolveStateTests.m
    git mv libs/FastSenseCompanion/private/runOpenAdHocPlotTests.m libs/FastSenseCompanion/runOpenAdHocPlotTests.m
    ```

    DO NOT modify file contents. The helpers (`filterDashboards`, `inspectorResolveState`, `openAdHocPlot`) remain in `libs/FastSenseCompanion/private/` and are still reachable from the runners because the runners now sit in the *parent* of `private/` (same relationship as the working `runFilterTagsTests.m` sibling).

    Why this works: MATLAB's `private/` rule is "callable only from functions in the parent folder". The runners need to *call* private helpers, so they must live in the parent. The tests then reach the runners via `addpath(libs/FastSenseCompanion)` from `install.m`.

    Why no content edits: the function bodies already use bare-name calls to the private helpers (e.g. `filterDashboards(...)`); those resolve correctly from the new location.

    Conventional commit (commit only the 3 renames, no other staged changes):
    ```bash
    git add -A libs/FastSenseCompanion/
    git commit -m "fix(companion): hoist test runner helpers out of private/ so tests can call them

    Octave CI was failing because tests/test_companion_filter_dashboards.m,
    tests/test_companion_inspector_resolve_state.m, and
    tests/test_companion_open_ad_hoc_plot.m call top-level runner functions
    that lived in libs/FastSenseCompanion/private/. MATLAB's private-folder
    rule makes those callable only from the parent folder, not from tests/.

    Move them one level up to libs/FastSenseCompanion/, mirroring the working
    sibling runFilterTagsTests.m. Private helpers (filterDashboards,
    inspectorResolveState, openAdHocPlot) stay in private/ and remain
    reachable because the runners now sit in the parent of private/."
    ```
  </action>
  <verify>
    <automated>
    Confirm the 3 files moved (not duplicated) and static checks still pass:
    ```bash
    test ! -f libs/FastSenseCompanion/private/runFilterDashboardsTests.m && \
    test ! -f libs/FastSenseCompanion/private/runInspectorResolveStateTests.m && \
    test ! -f libs/FastSenseCompanion/private/runOpenAdHocPlotTests.m && \
    test -f libs/FastSenseCompanion/runFilterDashboardsTests.m && \
    test -f libs/FastSenseCompanion/runInspectorResolveStateTests.m && \
    test -f libs/FastSenseCompanion/runOpenAdHocPlotTests.m && \
    mh_style libs/FastSenseCompanion/ && \
    mh_lint libs/FastSenseCompanion/ && \
    mh_metric --ci libs/FastSenseCompanion/
    ```
    Also confirm `git log --oneline -1 -- libs/FastSenseCompanion/runFilterDashboardsTests.m` shows the new commit and `git log --follow` retains pre-move history.
    DO NOT run any MATLAB or Octave tests locally per user constraint.
    </automated>
  </verify>
  <done>
    The three runners exist at `libs/FastSenseCompanion/<name>.m` (parent folder), `libs/FastSenseCompanion/private/` no longer contains them, MISS_HIT static checks pass on the FastSenseCompanion library, and a single conventional commit is on `claude/stoic-wu-801103` with the message above.
  </done>
</task>

<task type="auto">
  <name>Task 2: Guard web() in DashboardEngine.writeAndOpenInfoHtml so headless MATLAB CI does not segfault</name>
  <files>libs/Dashboard/DashboardEngine.m</files>
  <action>
    Edit `libs/Dashboard/DashboardEngine.m` inside `writeAndOpenInfoHtml` (currently lines ~794-819). Replace the unconditional `web(obj.InfoTempFile, '-new')` in the MATLAB branch (the `else` arm of the `exist('OCTAVE_VERSION', 'builtin')` check) with an inline interactivity guard mirroring `DashboardProgress.isInteractiveSession`.

    Target final shape of the MATLAB branch (lines ~816-818):
    ```matlab
    else
        % Only open the browser tab when running in an interactive desktop
        % MATLAB session. Calling web() inside `-batch -nodisplay` on Linux
        % CI destabilises the JVM/MEX loader and segfaults the runner
        % (see TestDashboardInfo failure, GitHub Actions run 25550691546).
        % The temp HTML file is already on disk above, which is what the
        % TestDashboardInfo suite verifies.
        interactive = usejava('desktop');
        if interactive && exist('batchStartupOptionUsed', 'builtin') && ...
                batchStartupOptionUsed()
            interactive = false;
        end
        if interactive
            web(obj.InfoTempFile, '-new');
        end
    end
    ```

    Constraints / what NOT to do:
    - Do NOT refactor `DashboardProgress.isInteractiveSession` into a shared utility — keep the change tight and self-contained inside `DashboardEngine`. Copy the logic inline.
    - Do NOT touch the Octave branch (`system(['open ...']` etc.). Those launchers already fail silently on headless runners; symmetry is optional and out of scope.
    - Do NOT change the file-write portion (fopen/fwrite/fclose) above the guard — TestDashboardInfo verifies `exist(d.InfoTempFile, 'file') == 2`, so the temp file must still be written unconditionally.
    - Do NOT add new public methods or properties. Inline-only edit.
    - Keep line length ≤ 160 chars (MISS_HIT rule).

    Conventional commit (single file, single commit):
    ```bash
    git add libs/Dashboard/DashboardEngine.m
    git commit -m "fix(dashboard): skip web() in headless MATLAB to prevent CI segfault

    TestDashboardInfo segfaulted under -batch -nodisplay on the Linux
    MATLAB runner (GitHub Actions run 25550691546). MATLAB crash dump
    showed dlclose -> utUnloadLibrary -> mdClearFunctionsByTimestamp
    triggered by web() invoking the JVM in a headless session.

    Guard the web() call in DashboardEngine.writeAndOpenInfoHtml with an
    inline isInteractiveSession check (usejava('desktop') AND NOT
    batchStartupOptionUsed), mirroring DashboardProgress.isInteractiveSession.
    The temp HTML file is still written unconditionally, which is what
    TestDashboardInfo actually verifies; only the browser launch is gated."
    ```
  </action>
  <verify>
    <automated>
    Confirm the guard is in place and static checks pass:
    ```bash
    grep -n "usejava('desktop')" libs/Dashboard/DashboardEngine.m && \
    grep -n "batchStartupOptionUsed" libs/Dashboard/DashboardEngine.m && \
    mh_style libs/Dashboard/ && \
    mh_lint libs/Dashboard/ && \
    mh_metric --ci libs/Dashboard/
    ```
    Also: `git log --oneline -1 libs/Dashboard/DashboardEngine.m` shows the new commit.
    DO NOT run TestDashboardInfo or any MATLAB/Octave tests locally per user constraint.
    </automated>
  </verify>
  <done>
    `libs/Dashboard/DashboardEngine.m::writeAndOpenInfoHtml` calls `web()` only when `usejava('desktop')` is true AND `batchStartupOptionUsed()` is false; the temp HTML file is still written before the guard; MISS_HIT static checks pass on `libs/Dashboard/`; a single conventional commit is on the branch.
  </done>
</task>

<task type="auto">
  <name>Task 3: Push branch and open PR against main (no merge)</name>
  <files>(no file changes — git/gh operations only)</files>
  <action>
    Push branch `claude/stoic-wu-801103` to origin (set upstream) and open a PR against `main` summarizing both fixes. Do NOT merge — leave for human review.

    Steps:

    1. Push the branch:
    ```bash
    git push -u origin claude/stoic-wu-801103
    ```

    2. Open PR with `gh pr create` using a HEREDOC body. Title under 70 chars; body summarizes both fixes and links the failed run.
    ```bash
    gh pr create --base main --head claude/stoic-wu-801103 \
      --title "fix(ci): unblock Octave + MATLAB Tests on linux runners" \
      --body "$(cat <<'EOF'
    ## Summary

    Two surgical CI fixes for the failures on `main` (latest failed run: [25550691546](https://github.com/HanSur94/FastPlot/actions/runs/25550691546)).

    ### Octave Tests — 2 failures resolved

    `tests/test_companion_filter_dashboards.m` and
    `tests/test_companion_inspector_resolve_state.m` (and the latent
    `tests/test_companion_open_ad_hoc_plot.m`) called runner functions that
    lived in `libs/FastSenseCompanion/private/`. MATLAB's private-folder
    rule makes those reachable only from the parent folder, not from
    `tests/`. Hoisted all three runners one level up to
    `libs/FastSenseCompanion/`, mirroring the working sibling
    `runFilterTagsTests.m`. Private helpers stay in `private/` and remain
    callable because the runners now sit in the parent of `private/`. No
    content changes inside the runner files; `git mv` preserves history.

    ### MATLAB Tests — TestDashboardInfo segfault resolved

    Under `-batch -nodisplay` on the Linux MATLAB runner,
    `DashboardEngine.writeAndOpenInfoHtml` called `web(obj.InfoTempFile, '-new')`
    unconditionally. The crash dump showed
    `dlclose -> utUnloadLibrary -> mdClearFunctionsByTimestamp` — JVM/MEX
    bootstrapping inside a headless session. Guarded the `web()` call with
    an inline `isInteractiveSession` check
    (`usejava('desktop')` AND NOT `batchStartupOptionUsed()`), mirroring
    `DashboardProgress.isInteractiveSession`. The temp HTML file is still
    written unconditionally, which is what `TestDashboardInfo` actually
    verifies; only the browser launch is gated.

    ## Test plan

    - [ ] CI: Octave Tests job (Linux) goes green — `test_companion_filter_dashboards`, `test_companion_inspector_resolve_state`, `test_companion_open_ad_hoc_plot` resolve their runners
    - [ ] CI: MATLAB Tests job (Linux) goes green — `TestDashboardInfo` no longer segfaults
    - [ ] CI: MATLAB Tests job (macOS / interactive) — `TestDashboardInfo` still passes (web() path skipped only when headless)
    - [ ] Local sanity (already done): `mh_style`, `mh_lint`, `mh_metric --ci` clean on `libs/FastSenseCompanion/` and `libs/Dashboard/`
    - [ ] Manual: open a dashboard with `InfoFile` set in interactive MATLAB and confirm `showInfo()` still pops a browser tab

    Per the user's request, no MATLAB or Octave tests were run locally — only MISS_HIT static checks.

    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    EOF
    )"
    ```

    3. Print the PR URL so the user can review:
    ```bash
    gh pr view --json url --jq .url
    ```

    Constraints:
    - DO NOT merge the PR.
    - DO NOT enable auto-merge.
    - DO NOT push --force.
    - DO NOT use `--no-verify` or otherwise skip hooks.
    - If `git push` is rejected because remote has new commits: stop and surface the error to the user — do not rebase or force-push without permission.
  </action>
  <verify>
    <automated>
    `gh pr view --json url,state,baseRefName,headRefName,isDraft --jq '.'` returns a PR with `state: "OPEN"`, `baseRefName: "main"`, `headRefName: "claude/stoic-wu-801103"`. Also confirm `git rev-parse @{u}` resolves (upstream is set) and `git status` shows the branch is up to date with origin.
    </automated>
  </verify>
  <done>
    Branch `claude/stoic-wu-801103` is pushed to origin with upstream tracking; an open (non-merged, non-draft) PR exists against `main` with the title and body above; the PR URL has been surfaced back to the user; both CI fix commits are part of the PR.
  </done>
</task>

</tasks>

<verification>
End-of-plan checks (all static — no test execution):

1. `git log --oneline -3` on `claude/stoic-wu-801103` shows two new fix commits (Task 1 + Task 2) on top of the previous tip.
2. `mh_style libs/FastSenseCompanion/ libs/Dashboard/` clean.
3. `mh_lint libs/FastSenseCompanion/ libs/Dashboard/` clean.
4. `mh_metric --ci libs/FastSenseCompanion/ libs/Dashboard/` clean.
5. `gh pr view` returns a PR open against `main` with both fixes summarized.
6. The 3 runner files exist only at `libs/FastSenseCompanion/<name>.m` (not under `private/`).
7. `libs/Dashboard/DashboardEngine.m` contains both `usejava('desktop')` and `batchStartupOptionUsed` inside `writeAndOpenInfoHtml`.
</verification>

<success_criteria>
- Two atomic, independently-revertable commits on `claude/stoic-wu-801103` (one per code fix); a third "task" only opens the PR (no commit needed).
- MISS_HIT `mh_style`, `mh_lint`, `mh_metric --ci` pass on the touched libraries (`libs/FastSenseCompanion/`, `libs/Dashboard/`).
- No MATLAB or Octave test execution occurred locally during the plan (per explicit user constraint).
- PR is open against `main`, not merged, not draft, with title `fix(ci): unblock Octave + MATLAB Tests on linux runners` and a body that summarizes both fixes and links GitHub Actions run 25550691546.
- Once CI runs on the PR: Octave Tests job and MATLAB Tests job both go green (this is the ultimate success signal — confirmed by the human reviewer, not by this plan's executor).
</success_criteria>

<output>
After completion, create `.planning/quick/260508-huo-fix-octave-tests-move-companion-runner-f/260508-huo-SUMMARY.md` capturing:
- Commit SHAs for the two fix commits
- PR URL
- Confirmation that no MATLAB/Octave tests were run locally
- Note for the human reviewer: "Verify both CI jobs go green on the PR before merging."
</output>
