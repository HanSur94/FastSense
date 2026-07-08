---
phase: quick-260629-tgy
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/SensorThreshold/Tag.m
  - tests/suite/TestTag.m
autonomous: true
requirements: [ISSUE-327]
must_haves:
  truths:
    - "Any Tag subclass exposes tag.cumulativeIntegral() returning the running trapezoidal integral of Y w.r.t. X"
    - "2-out form returns [X, cum]; 1-out form returns scalar cum(end)"
    - "'Range',[t0 t1] computes the integral within a time window via getXYRange"
    - "Empty data returns a documented empty/zero value without error"
    - "An interior NaN gap does not poison the running total into an all-NaN tail"
    - "Calling on a discrete StateTag emits the Tag:integralOnDiscrete warning but still returns a value"
    - "No public signature or serialized format changes anywhere (purely additive)"
  artifacts:
    - path: "libs/SensorThreshold/Tag.m"
      provides: "cumulativeIntegral public method on the Tag base class"
      contains: "function"
    - path: "tests/suite/TestTag.m"
      provides: "cumulativeIntegral unit tests"
      contains: "cumulativeIntegral"
  key_links:
    - from: "libs/SensorThreshold/Tag.m"
      to: "getXYRange / getXY"
      via: "method dispatch on the Range option"
      pattern: "getXYRange|getXY"
    - from: "libs/SensorThreshold/Tag.m"
      to: "cumtrapz"
      via: "trapezoidal accumulation"
      pattern: "cumtrapz|cumsum"
---

<objective>
Add a single additive public method `cumulativeIntegral` to the `Tag` base class
(`libs/SensorThreshold/Tag.m`) that returns the running trapezoidal integral of a
tag's Y w.r.t. X. Because it sits on the base class and consumes only the existing
`getXY`/`getXYRange` seam, every Tag subclass (SensorTag, StateTag, MonitorTag,
CompositeTag, DerivedTag, MockTag) inherits it for free.

Implements GitHub issue #327: a trapezoidal "totalizer" series — `cum(end)` is the
grand total (e.g. flow → volume, power → energy).

Purpose: Give engineers a running integral / grand total over any tag's series, on
non-uniform time spacing, toolbox-free, without touching any signature or serialized
format.

Output:
- `Tag.cumulativeIntegral([...])` public method (concrete, NOT a 7th abstract stub).
- New unit tests in `tests/suite/TestTag.m`.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md

# Target file — add the method near getXYRange (Tag.m:125), in the public methods block.
# Tag.m uses inline name-value parsing in its own constructor (Tag.m:90-103) — mirror that
# minimal style for the single 'Range' option; do NOT pull in an external parseOpts helper.
@libs/SensorThreshold/Tag.m

# Test patterns: MockTag.getXY returns [] (use for empty-data + via getKind='mock').
# Data-bearing tags for tests: SensorTag('k','X',...,'Y',...) and StateTag('k','X',...,'Y',...).
@tests/suite/TestTag.m
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Implement Tag.cumulativeIntegral</name>
  <files>libs/SensorThreshold/Tag.m</files>
  <behavior>
    Place the method in the public `methods` block of Tag.m, immediately AFTER
    `getXYRange` (after Tag.m:159) so it reads alongside the data-access seam.

    Signature: `function varargout = cumulativeIntegral(obj, varargin)`

    Option parsing (minimal, mirror the constructor's inline switch at Tag.m:90-103):
    - Accept exactly one optional name-value key: `'Range'`, value `[t0 t1]` numeric pair.
    - Any other key -> `error('Tag:unknownOption', 'Unknown option ''%s''.', key)`.
    - If 'Range' supplied: `[X, Y] = obj.getXYRange(t0, t1)`. Else: `[X, Y] = obj.getXY()`.

    Kind-aware warning:
    - `if strcmp(obj.getKind(), 'state')` -> `warning('Tag:integralOnDiscrete', ...)`
      with a message noting area under a discrete/step channel is rarely intended.
      STILL compute and return (warn, do not error).

    Column/row robustness:
    - Force X and Y to row (or column) vectors consistently before cumtrapz so the
      result shape is deterministic regardless of caller orientation.

    Empty-data guard (DOCUMENT the choice in the method header):
    - If `isempty(X)`: 2-out form -> return `X=[]`, `cum=[]`; 1-out form -> return `0`
      (scalar zero "no area"). Document: "empty series integrates to 0".

    NaN-gap policy (DOCUMENT precisely in the method header):
    - A trapezoid segment [i, i+1] whose either endpoint X(i)/X(i+1)/Y(i)/Y(i+1) is
      NaN contributes ZERO area (treated as a gap), so a single interior NaN does NOT
      turn the entire running tail into NaN.
    - Algorithm (specify exactly, do NOT call cumtrapz directly when NaNs may be present):
        dt   = diff(X);
        area = 0.5 .* dt .* (Y(1:end-1) + Y(2:end));   % per-segment trapezoid areas
        area(~isfinite(area)) = 0;                      % zero out any NaN/Inf segment
        cum  = [0, cumsum(area)];                       % running total, cum(1)=0
      This matches `cumtrapz(X,Y)` exactly when there are no NaNs (cum(1)=0,
      cum grows by each trapezoid), and is gap-robust when NaNs are present.
    - Single-sample series (numel(X)==1): cum = 0 (one point bounds no area).

    Output via nargout:
    - `nargout <= 1` (1-out / scalar form): `varargout{1} = cum(end)` (grand total of
      the windowed/full series); for empty data `varargout{1} = 0`.
    - `nargout == 2`: `varargout{1} = X; varargout{2} = cum`.
    - Do not allow nargout > 2.

    Header doc: add a `%CUMULATIVEINTEGRAL` block documenting the 3 call forms, the
    empty-data return (0 / []), the NaN-gap policy, and the Tag:integralOnDiscrete
    warning. Add a one-line entry to the class header "Tag Methods" list noting
    `cumulativeIntegral` as a concrete convenience method (additive, keep it short).

    CRITICAL gate constraint: the method is CONCRETE — it must NOT contain the string
    `Tag:notImplemented`. The `testAbstractMethodCount` test asserts exactly 6
    occurrences of `Tag:notImplemented` in Tag.m; do not add a 7th.
  </behavior>
  <action>
Add a concrete public method `cumulativeIntegral(obj, varargin)` to Tag.m's public
methods block, immediately after `getXYRange` (Tag.m:159). Parse a single optional
`'Range',[t0 t1]` name-value pair using the same inline switch style as the Tag
constructor (Tag.m:90-103); reject unknown keys with `Tag:unknownOption`. Pull data
via `getXYRange(t0,t1)` when 'Range' is given else `getXY()`. Coerce X,Y to a
consistent vector orientation. Compute the running trapezoidal integral via the
explicit per-segment-area + cumsum algorithm specified in <behavior> (gap-robust:
zero out non-finite segment areas so an interior NaN does not poison the tail; result
is identical to `cumtrapz(X,Y)` when no NaNs are present, cum(1)=0). Empty series ->
`0` (1-out) / `[]` (2-out). Emit `warning('Tag:integralOnDiscrete', ...)` when
`getKind()=='state'` but still return the value. Use `nargout` to switch between the
2-out `[X, cum]` form and the 1-out scalar `cum(end)` form. Document all three call
forms, the empty/zero behavior, the NaN-gap policy, and the discrete warning in the
method header, and add a one-line mention to the class-header method list. Pure
MATLAB/Octave only — no toolbox call, no MEX. Do NOT add any `Tag:notImplemented`
string (keep the abstract-stub count at exactly 6). No toStruct/fromStruct,
DashboardWidget, or interface change.
  </action>
  <verify>
    <automated>grep -c "Tag:notImplemented" libs/SensorThreshold/Tag.m   # MUST be 6 (unchanged)</automated>
    <automated>grep -c "function varargout = cumulativeIntegral" libs/SensorThreshold/Tag.m   # MUST be 1</automated>
    <automated>grep -nE "cumtrapz|cumsum" libs/SensorThreshold/Tag.m   # accumulation present</automated>
  </verify>
  <done>
    Tag.m has a concrete `cumulativeIntegral` method after getXYRange; it parses a
    single 'Range' option, dispatches to getXYRange/getXY, computes a gap-robust
    running trapezoidal integral, warns Tag:integralOnDiscrete for state kind, and
    returns [X,cum] (2-out) or scalar cum(end) (1-out). The 6 abstract stubs are
    untouched. No signature or serialization change anywhere.
  </done>
</task>

<task type="auto">
  <name>Task 2: Add cumulativeIntegral unit tests to TestTag</name>
  <files>tests/suite/TestTag.m</files>
  <action>
Add new `methods (Test)` cases to `tests/suite/TestTag.m` covering Tag.cumulativeIntegral
(install() is already wired by the suite's addPaths TestClassSetup, so SensorTag /
StateTag are on the path). Add the following tests:

1. testCumulativeIntegralUniformRamp — `SensorTag('s','X',0:1:4,'Y',[2 2 2 2 2])`;
   `[x,cum]=t.cumulativeIntegral()`; verify `cum` equals `[0 2 4 6 8]` and `x` equals
   `0:1:4` (use verifyEqual with an AbsTol, e.g. 1e-12).

2. testCumulativeIntegralNonUniform — pick non-uniform X (e.g. `X=[0 1 3 7]`,
   `Y=[1 3 3 1]`); compute the expected running integral by hand / with the same
   trapezoid formula in the test and verify `cum` matches (AbsTol 1e-12). Pin the
   total `cum(end)` to the hand value as well.

3. testCumulativeIntegralRangeWindow — build a SensorTag spanning a wider X; call
   `t.cumulativeIntegral('Range',[t0 t1])` and verify the returned series is the
   windowed integral (cum starts at 0 within the window; total equals the integral
   over the windowed samples). Account for getXYRange's one-point boundary padding
   (Tag.m:151-152) by asserting against the integral of the actual returned X window
   — re-derive expected from `t.getXYRange(t0,t1)` rather than assuming exact endpoints.

4. testCumulativeIntegralScalarForm — `total = t.cumulativeIntegral()` (1-out) returns
   a scalar equal to the 2-out `cum(end)` for the same tag/window.

5. testCumulativeIntegralEmptyData — `MockTag('m')` (getXY returns []):
   `[x,cum]=t.cumulativeIntegral()` returns empty x and empty cum; `total=...` (1-out)
   returns 0. No error thrown.

6. testCumulativeIntegralNaNGap — series with an interior NaN in Y
   (e.g. `X=0:1:4`, `Y=[1 1 NaN 1 1]`): verify `cum` is finite at the END (not NaN),
   i.e. `isfinite(cum(end))` is true and the NaN segment contributed 0 area — the tail
   is not all-NaN.

7. testCumulativeIntegralDiscreteWarns — `StateTag('st','X',[0 1 2],'Y',[0 1 0])`;
   use `verifyWarning(@() st.cumulativeIntegral(), 'Tag:integralOnDiscrete')` and also
   confirm it still returns a numeric value (capture output in a separate call with
   warnings suppressed, or assert the warning-returning call still produced a result).

8. testCumulativeIntegralUnknownOption — `verifyError(@() t.cumulativeIntegral('Bogus',1), 'Tag:unknownOption')`.

Keep each test small and use AbsTol on float comparisons. Do NOT modify or reorder any
existing test method. Do NOT change `testAbstractMethodCount` (it still expects 6).
  </action>
  <verify>
    <automated>grep -c "function testCumulativeIntegral" tests/suite/TestTag.m   # MUST be >= 7</automated>
    <automated>grep -nE "integralOnDiscrete|unknownOption|Range" tests/suite/TestTag.m   # discrete-warn + range + unknown-option cases present</automated>
  </verify>
  <done>
    TestTag.m has >=7 new cumulativeIntegral tests covering: uniform ramp exact area,
    non-uniform spacing, Range windowing, 1-out scalar form, empty-data guard,
    NaN-gap finite tail, discrete StateTag warning, and unknown-option rejection. No
    existing test method changed; testAbstractMethodCount still asserts 6.
  </done>
</task>

</tasks>

<verification>
- `grep -c "Tag:notImplemented" libs/SensorThreshold/Tag.m` returns 6 (abstract-stub gate intact).
- Static analysis clean per CLAUDE.md: code is pure MATLAB/Octave, no toolbox, no MEX;
  lines <= 160 chars, 4-space indent (mh_style/mh_lint expectation).
- Orchestrator runs the MATLAB suite afterward (executor does NOT invoke the MATLAB MCP):
  `tests/suite/TestTag.m` — all existing tests still pass AND the 8 new cumulativeIntegral
  tests pass. Expected uniform-ramp result cum = [0 2 4 6 8], total 8.
</verification>

<success_criteria>
- `Tag.cumulativeIntegral` exists on the base class and is inherited by all Tag subclasses.
- 2-out `[X,cum]` and 1-out scalar `cum(end)` forms both work; 'Range' windows via getXYRange.
- Empty data -> 0 (1-out) / [] (2-out); interior NaN does not produce an all-NaN tail.
- Discrete StateTag triggers `Tag:integralOnDiscrete` but still returns a value.
- Purely additive: no signature, serialized-format, or interface change anywhere; backward-compatible.
- New TestTag.m cases cover every requirement above.
</success_criteria>

<output>
Create `.planning/quick/260629-tgy-tag-cumulativeintegral-trapezoidal-total/260629-tgy-SUMMARY.md` when done.
</output>
