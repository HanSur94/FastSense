function test_fastsense_addtag()
%TEST_FASTSENSE_ADDTAG Octave flat-style port of TestFastSenseAddTag.m.
%   Mirrors the key assertions for FastSense.addTag polymorphic dispatcher
%   (TAG-10, Phase 1005-03):
%     - Non-Tag input       -> FastSense:invalidTag
%     - Post-render call    -> FastSense:alreadyRendered
%     - SensorTag           -> addLine with DisplayName
%     - StateTag numeric Y  -> staircase line (2N-1 points)
%     - StateTag cellstr Y  -> FastSense:stateTagCellstrNotSupported
%     - Unsupported kind    -> FastSense:unsupportedTagKind (MockTag)
%     - Pitfall 1 grep gate -> FastSense.m has no isa(.., 'SensorTag'|'StateTag')
%
%   See also TestFastSenseAddTag, test_tag, test_sensortag, test_statetag.

    add_fastsense_addtag_path();
    TagRegistry.clear();

    % --- Guard: non-Tag input ---
    fp = FastSense();
    ok = false;
    try
        fp.addTag(struct('x', 1));
    catch me
        ok = ~isempty(strfind(me.identifier, 'FastSense:invalidTag'));
    end
    assert(ok, 'test_fastsense_addtag: invalidTag error');

    % --- Guard: post-render ---
    fp = FastSense();
    fp.addLine(1:10, rand(1, 10));
    fp.render();
    st = SensorTag('s', 'X', 1:5, 'Y', 1:5);
    ok = false;
    try
        fp.addTag(st);
    catch me
        ok = ~isempty(strfind(me.identifier, 'FastSense:alreadyRendered'));
    end
    assert(ok, 'test_fastsense_addtag: alreadyRendered error');
    try, delete(fp); catch, end %#ok<NOCOM>

    % --- Dispatch: SensorTag -> line ---
    fp = FastSense();
    x = 1:100;
    y = sin(x * 0.1);
    st = SensorTag('press_a', 'Name', 'Press', 'X', x, 'Y', y);
    fp.addTag(st);
    assert(numel(fp.Lines) == 1, 'test_fastsense_addtag: SensorTag line count');
    assert(strcmp(fp.Lines(1).Options.DisplayName, 'Press'), ...
        'test_fastsense_addtag: SensorTag DisplayName');
    assert(isequal(fp.Lines(1).X, x), 'test_fastsense_addtag: SensorTag X');
    assert(isequal(fp.Lines(1).Y, y), 'test_fastsense_addtag: SensorTag Y');

    % --- Dispatch: StateTag numeric -> staircase ---
    fp = FastSense();
    st = StateTag('mode', 'X', [1 5 10 20], 'Y', [0 1 2 3]);
    fp.addTag(st);
    assert(numel(fp.Lines) == 1, 'test_fastsense_addtag: StateTag line count');
    % Interleaved staircase: N=4 -> 2N-1 = 7 points
    expectedX = [1 5 5 10 10 20 20];
    expectedY = [0 0 1 1 2 2 3];
    assert(numel(fp.Lines(1).X) == 7, 'test_fastsense_addtag: StateTag staircase length');
    assert(isequal(fp.Lines(1).X, expectedX), 'test_fastsense_addtag: StateTag staircase X');
    assert(isequal(fp.Lines(1).Y, expectedY), 'test_fastsense_addtag: StateTag staircase Y');
    assert(strcmp(fp.Lines(1).Options.DisplayName, 'mode'), ...
        'test_fastsense_addtag: StateTag DisplayName');

    % --- Dispatch: StateTag cellstr -> deferred error ---
    fp = FastSense();
    st = StateTag('m', 'X', [1 5 10], 'Y', {'idle', 'run', 'stop'});
    ok = false;
    try
        fp.addTag(st);
    catch me
        ok = ~isempty(strfind(me.identifier, 'FastSense:stateTagCellstrNotSupported'));
    end
    assert(ok, 'test_fastsense_addtag: cellstr StateTag deferred error');

    % --- Dispatch: MockTag -> unsupportedTagKind ---
    fp = FastSense();
    mt = MockTag('m');
    ok = false;
    try
        fp.addTag(mt);
    catch me
        ok = ~isempty(strfind(me.identifier, 'FastSense:unsupportedTagKind'));
    end
    assert(ok, 'test_fastsense_addtag: unsupportedTagKind error');

    % --- Strangler-fig parity: addSensor + addTag on same fp ---
    fp = FastSense();
    legacy = SensorTag('legacy', 'Name', 'Legacy', 'X', 1:50, 'Y', cos((1:50) * 0.2));
    fp.addTag(legacy);
    st = SensorTag('modern', 'Name', 'Modern', 'X', 1:30, 'Y', sin(1:30));
    fp.addTag(st);
    assert(numel(fp.Lines) == 2, 'test_fastsense_addtag: mix addSensor + addTag');

    % --- Empty StateTag: silent no-op ---
    fp = FastSense();
    st = StateTag('empty');
    fp.addTag(st);   % must not throw
    assert(numel(fp.Lines) == 0, 'test_fastsense_addtag: empty StateTag is no-op');

    % --- Pitfall 1 grep gate ---
    % FastSense.m must not dispatch via isa(tag, 'SensorTag') or isa(tag, 'StateTag').
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    src = fileread(fullfile(repo, 'libs', 'FastSense', 'FastSense.m'));
    match = regexp(src, 'isa\s*\([^,]*,\s*''(SensorTag|StateTag)''\s*\)', 'once');
    assert(isempty(match), ...
        'test_fastsense_addtag: Pitfall 1 — no isa on SensorTag/StateTag subclass names');

    TagRegistry.clear();
    fprintf('    All test_fastsense_addtag tests passed.\n');
end

function add_fastsense_addtag_path()
    %ADD_FASTSENSE_ADDTAG_PATH Ensure repo root + tests/suite are on the path.
    test_dir  = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    addpath(fullfile(test_dir, 'suite'));  % for MockTag
    install();
end
