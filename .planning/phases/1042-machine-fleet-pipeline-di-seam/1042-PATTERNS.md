# Phase 1042: Machine + Fleet + Pipeline DI Seam - Pattern Map

**Mapped:** 2026-06-03
**Files analyzed:** 9 (2 new classes, 1 private helper, 2 pipeline modifications, 4 test files)
**Analogs found:** 9 / 9

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `libs/Fleet/Machine.m` | model | CRUD | `libs/SensorThreshold/TagRegistry.m` (read API) + `libs/Fleet/CanonicalMapper.m` (handle class shape) | role-match |
| `libs/Fleet/Fleet.m` | model | CRUD + file-I/O | `libs/Fleet/CanonicalMapper.m` (save/load + toStruct/fromStruct) | exact |
| `libs/Fleet/private/normalizeToCell_.m` | utility | transform | `libs/Dashboard/private/normalizeToCell.m` | exact |
| `libs/SensorThreshold/BatchTagPipeline.m` (modify) | service | batch | self (additive seam only) + `libs/SensorThreshold/LiveTagPipeline.m` (DI seam shape) | exact |
| `libs/SensorThreshold/LiveTagPipeline.m` (modify) | service | event-driven | self (additive seam only) + `libs/SensorThreshold/BatchTagPipeline.m` (DI seam shape) | exact |
| `tests/suite/TestMachine.m` | test | — | `tests/suite/TestCanonicalMapper.m` | exact |
| `tests/suite/TestFleet.m` | test | — | `tests/suite/TestCanonicalMapper.m` | exact |
| `tests/test_machine.m` | test | — | `tests/test_tag_registry.m` | exact |
| `tests/test_fleet.m` | test | — | `tests/test_tag_registry.m` | exact |

---

## Pattern Assignments

### `libs/Fleet/Machine.m` (model, CRUD)

**Primary analog:** `libs/SensorThreshold/TagRegistry.m` (read API to mirror)
**Secondary analog:** `libs/Fleet/CanonicalMapper.m` (handle class + constructor + containers.Map + error style)

**Class header + properties pattern** — copy from `libs/Fleet/CanonicalMapper.m` lines 1-69:
```matlab
classdef Machine < handle
    %MACHINE Per-machine isolated tag catalog with pipeline and EventStore ownership.
    %   ...
    %
    %   See also Fleet, TagRegistry, CanonicalMapper.

    properties (Access = public)
        Id          % char; user-supplied, required, unique within Fleet
        Name        % char; display name; defaults to Id
        DataRoot    % char; output dir for pipelines + EventStore root
        Group       % char; freeform group label (default '')
        Metadata    % struct; arbitrary user metadata
        Dashboards  % cell; DashboardEngine handles (Phase 1044)
    end

    properties (SetAccess = private)
        EventStore  % EventStore handle owned by this machine
    end

    properties (Access = private)
        Tags_        % containers.Map('KeyType','char','ValueType','any')
        LivePipeline_ = []   % LiveTagPipeline handle (set by startLive)
    end
```

**Constructor NV pattern** — model after `libs/Fleet/CanonicalMapper.m` lines 65-69 (simple constructor) + `libs/SensorThreshold/BatchTagPipeline.m` lines 85-117 (NV switch with otherwise guard):
```matlab
    methods
        function obj = Machine(varargin)
            %MACHINE Construct a machine with NV pairs.
            %   m = Machine('Id', 'M01', 'Name', 'Pump 1', 'DataRoot', '/data/m01')
            %   m = Machine('Id', 'M01', 'DataRoot', '/data/m01', 'Group', 'pumps')
            %
            %   Required: 'Id' (non-empty char)
            %   Errors:
            %     Machine:missingId     -- Id not supplied or empty
            %     Machine:invalidOption -- unknown NV key
            opts = struct('Id', '', 'Name', '', 'DataRoot', '', 'Group', '', 'Metadata', struct());
            for k = 1:2:numel(varargin)
                key = varargin{k};
                if k + 1 > numel(varargin) || ~ischar(key)
                    error('Machine:invalidOption', 'Options must be name-value pairs with char keys.');
                end
                switch key
                    case 'Id';       opts.Id       = char(varargin{k+1});
                    case 'Name';     opts.Name     = char(varargin{k+1});
                    case 'DataRoot'; opts.DataRoot  = char(varargin{k+1});
                    case 'Group';    opts.Group    = char(varargin{k+1});
                    case 'Metadata'; opts.Metadata = varargin{k+1};
                    otherwise
                        error('Machine:invalidOption', 'Unknown option ''%s''.', key);
                end
            end
            if isempty(opts.Id)
                error('Machine:missingId', 'Id is required (non-empty char).');
            end
            obj.Id        = opts.Id;
            obj.Name      = opts.Name;
            if isempty(obj.Name); obj.Name = obj.Id; end
            obj.DataRoot  = opts.DataRoot;
            obj.Group     = opts.Group;
            obj.Metadata  = opts.Metadata;
            obj.Tags_     = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.Dashboards = {};
            if ~isempty(obj.DataRoot)
                obj.EventStore = EventStore(obj.DataRoot);
            end
        end
```

**addTag pattern** — mirrors `libs/SensorThreshold/TagRegistry.m` lines 67-95 (duplicate-key hard error):
```matlab
        function addTag(obj, tag)
            %ADDTAG Add a Tag to this machine's catalog (hard error on duplicate key).
            %   Tags are NOT registered in the global TagRegistry (FLEET-02).
            if ~isa(tag, 'Tag')
                error('Machine:invalidType', 'Value must be a Tag object, got %s.', class(tag));
            end
            key = char(tag.Key);
            if obj.Tags_.isKey(key)
                error('Machine:duplicateKey', ...
                    'Key ''%s'' already in machine ''%s''. Call machine.removeTag(key) first.', ...
                    key, obj.Id);
            end
            obj.Tags_(key) = tag;
        end
```

**Duck-type read API** — copy method bodies from `libs/SensorThreshold/TagRegistry.m` lines 47-212, adapting from static to instance methods:
```matlab
        % get — mirrors TagRegistry.get (line 47)
        function t = get(obj, localKey)
            if ~obj.Tags_.isKey(localKey)
                error('Machine:unknownKey', ...
                    'No tag with key ''%s'' in machine ''%s''.', localKey, obj.Id);
            end
            t = obj.Tags_(localKey);
        end

        % find — mirrors TagRegistry.find (line 154)
        function ts = find(obj, predicateFn)
            ks = obj.Tags_.keys();
            ts = {};
            for i = 1:numel(ks)
                t = obj.Tags_(ks{i});
                if predicateFn(t)
                    ts{end+1} = t; %#ok<AGROW>
                end
            end
        end

        % findByKind — mirrors TagRegistry.findByKind (line 194)
        function ts = findByKind(obj, kind)
            ts = obj.find(@(t) strcmp(t.getKind(), kind));
        end

        % findByLabel — mirrors TagRegistry.findByLabel (line 174)
        function ts = findByLabel(obj, label)
            ts = obj.find(@(t) ~isempty(t.Labels) && any(strcmp(t.Labels, label)));
        end

        % keys — mirrors TagRegistry internal keys()
        function ks = keys(obj)
            ks = obj.Tags_.keys();
        end
```

**ingestBatch / startLive wrappers** — from RESEARCH.md Pattern 5:
```matlab
        function report = ingestBatch(obj, varargin)
            if isempty(obj.DataRoot)
                error('Machine:missingDataRoot', 'DataRoot must be set before calling ingestBatch.');
            end
            p = BatchTagPipeline('OutputDir', obj.DataRoot, ...
                'TagSource', @(pred) obj.find(pred), ...
                varargin{:});
            report = p.run();
        end

        function startLive(obj, interval, varargin)
            if isempty(obj.DataRoot)
                error('Machine:missingDataRoot', 'DataRoot must be set before calling startLive.');
            end
            if nargin < 2 || isempty(interval); interval = 15; end
            obj.LivePipeline_ = LiveTagPipeline('OutputDir', obj.DataRoot, ...
                'TagSource', @(pred) obj.find(pred), ...
                'Interval',  interval, ...
                varargin{:});
            obj.LivePipeline_.start();
        end

        function delete(obj)
            if ~isempty(obj.LivePipeline_)
                obj.LivePipeline_.stop();
                delete(obj.LivePipeline_);
            end
        end
```

**toConfigStruct / fromConfigStruct** — camelCase JSON fields (matching CanonicalMapper entry field convention):
```matlab
        function s = toConfigStruct(obj)
            s = struct('id', char(obj.Id), 'name', char(obj.Name), ...
                       'dataRoot', char(obj.DataRoot), 'group', char(obj.Group));
            if ~isempty(fieldnames(obj.Metadata))
                s.metadata = obj.Metadata;
            end
        end

    end

    methods (Static)
        function obj = fromConfigStruct(s, fleetFilePath)
            % Resolve DataRoot path (D-07): relative -> against fleet file dir;
            % leading ~ -> getenv('HOME') (Octave-safe; works on MATLAB too).
            dataRoot = char(s.dataRoot);
            if numel(dataRoot) >= 1 && dataRoot(1) == '~'
                home = getenv('HOME');
                if ~isempty(home)
                    dataRoot = [home dataRoot(2:end)];
                end
            end
            if ~isempty(dataRoot) && dataRoot(1) ~= filesep && ...
                    ~(numel(dataRoot) > 1 && dataRoot(2) == ':')
                fleetDir = fileparts(fleetFilePath);
                dataRoot = fullfile(fleetDir, dataRoot);
            end
            nvArgs = {'Id', char(s.id), 'Name', char(s.name), ...
                      'DataRoot', dataRoot, 'Group', char(s.group)};
            if isfield(s, 'metadata')
                nvArgs = [nvArgs, {'Metadata', s.metadata}];
            end
            obj = Machine(nvArgs{:});
        end
    end
```

---

### `libs/Fleet/Fleet.m` (model, CRUD + file-I/O)

**Analog:** `libs/Fleet/CanonicalMapper.m` (save lines 351-383, load lines 413-426, fromStruct lines 387-411, toStruct lines 337-349)

**Class header + properties:**
```matlab
classdef Fleet < handle
    %FLEET Searchable collection of Machine instances with JSON persistence.
    %   See also Machine, CanonicalMapper.

    properties (SetAccess = private)
        Machines_   % containers.Map: machineId -> Machine handle
        MachineIds_ % cell of char; insertion-order list
        Mapper_     % CanonicalMapper handle
    end
```

**addMachine — duplicate guard** — mirrors `libs/SensorThreshold/TagRegistry.m` lines 86-94:
```matlab
        function m = addMachine(obj, varargin)
            if numel(varargin) == 1 && isa(varargin{1}, 'Machine')
                m = varargin{1};
            else
                m = Machine(varargin{:});
            end
            if obj.Machines_.isKey(m.Id)
                error('Fleet:duplicateMachineId', ...
                    'Machine with Id ''%s'' already in fleet. Use a unique Id.', m.Id);
            end
            obj.Machines_(m.Id) = m;
            obj.MachineIds_{end+1} = m.Id;
        end
```

**filterByName / filterByGroup** — `strfind(lower(...))` pattern from `libs/FastSenseCompanion/private/filterTags.m`:
```matlab
        function ms = filterByName(obj, pattern)
            pat = lower(char(pattern));
            ms = {};
            for i = 1:numel(obj.MachineIds_)
                m = obj.Machines_(obj.MachineIds_{i});
                if ~isempty(strfind(lower(m.Name), pat))
                    ms{end+1} = m; %#ok<AGROW>
                end
            end
        end

        function ms = filterByGroup(obj, group)
            grp = lower(char(group));
            ms = {};
            for i = 1:numel(obj.MachineIds_)
                m = obj.Machines_(obj.MachineIds_{i});
                if ~isempty(strfind(lower(m.Group), grp))
                    ms{end+1} = m; %#ok<AGROW>
                end
            end
        end
```

**save — per-entry jsonencode + strjoin + movefile** — exact pattern from `libs/Fleet/CanonicalMapper.m` lines 351-383:
```matlab
        function save(obj, filepath)
            %SAVE Atomically write the fleet config to JSON.
            %   Per-entry jsonencode + strjoin avoids MATLAB/Octave divergence (Pitfall 3).
            nMachines = numel(obj.MachineIds_);
            machineParts = cell(1, nMachines);
            for i = 1:nMachines
                m = obj.Machines_(obj.MachineIds_{i});
                machineParts{i} = jsonencode(m.toConfigStruct());
            end
            if nMachines == 0
                machinesJson = '[]';
            else
                machinesJson = ['[' strjoin(machineParts, ',') ']'];
            end

            % Embed canonical map (D-05/D-06)
            cmStruct = obj.Mapper_.toStruct();
            nEntries = numel(cmStruct.entries);
            if nEntries == 0
                cmEntriesJson = '[]';
            else
                cmParts = cell(1, nEntries);
                for j = 1:nEntries
                    cmParts{j} = jsonencode(cmStruct.entries{j});
                end
                cmEntriesJson = ['[' strjoin(cmParts, ',') ']'];
            end
            cmJson = sprintf('{"version":%d,"entries":%s}', cmStruct.version, cmEntriesJson);

            json = sprintf('{"fleetConfigVersion":1,"machines":%s,"canonicalMap":%s}', ...
                machinesJson, cmJson);

            % Atomic write — mirrors CanonicalMapper.save (lines 367-382)
            tmp = [filepath '.tmp'];
            fid = fopen(tmp, 'w');
            if fid == -1
                error('Fleet:fileError', 'Cannot open: %s', tmp);
            end
            fwrite(fid, json);
            fclose(fid);
            try
                movefile(tmp, filepath, 'f');
            catch mvErr
                if exist(tmp, 'file') == 2; delete(tmp); end
                error('Fleet:fileError', 'Failed to save to %s: %s', filepath, mvErr.message);
            end
        end
```

**load — jsondecode + normalizeToCell_ + fromStruct** — pattern from `libs/Fleet/CanonicalMapper.m` lines 413-426 + fromStruct lines 387-411:
```matlab
    methods (Static)
        function obj = load(filepath)
            %LOAD Read a fleet config from a JSON file written by save().
            if ~isfile(filepath)
                error('Fleet:fileNotFound', 'File not found: %s', filepath);
            end
            fid = fopen(filepath, 'r');
            if fid == -1
                error('Fleet:fileError', 'Cannot open file: %s', filepath);
            end
            raw = fread(fid, '*char')';
            fclose(fid);
            s = jsondecode(raw);

            if ~isfield(s, 'fleetConfigVersion')
                s.fleetConfigVersion = 1;
            end

            obj = Fleet();
            machines = normalizeToCell_(s.machines);   % private copy; Dashboard-private not accessible
            for i = 1:numel(machines)
                m = Machine.fromConfigStruct(machines{i}, filepath);
                obj.addMachine(m);
            end
            if isfield(s, 'canonicalMap')
                obj.Mapper_ = CanonicalMapper.fromStruct(s.canonicalMap);
            end
        end
    end
```

---

### `libs/Fleet/private/normalizeToCell_.m` (utility, transform)

**Analog:** `libs/Dashboard/private/normalizeToCell.m` (lines 1-26) — exact copy with trailing-underscore name per CLAUDE.md private convention.

Full content to copy verbatim (adjust function name only):
```matlab
function c = normalizeToCell_(x)
%NORMALIZETOCELL_ Normalize jsondecode output to cell array (Fleet-private copy).
%   C = NORMALIZETOCELL_(X) converts struct arrays produced by jsondecode
%   back to cell arrays. jsondecode collapses homogeneous JSON arrays of
%   objects to MATLAB struct arrays; this helper reverses that.
%   Identical logic to libs/Dashboard/private/normalizeToCell.m; copied
%   because Dashboard/private/ is not callable from libs/Fleet/.
    if isempty(x)
        c = {};
    elseif isstruct(x)
        c = cell(1, numel(x));
        for k = 1:numel(x)
            c{k} = x(k);
        end
    else
        c = x;
    end
end
```

**Source:** `libs/Dashboard/private/normalizeToCell.m` lines 1-26

---

### `libs/SensorThreshold/BatchTagPipeline.m` (modify — DI seam only)

**Read location:** `libs/SensorThreshold/BatchTagPipeline.m`

**Three additive changes only — no other modifications:**

**Change 1: Add `tagSource_` to private properties block** (after line 74, before `methods`):
```matlab
        tagSource_ = @TagRegistry.find   % DI seam (FLEET-03/D-12); default = single-machine path.
                                         % Override via 'TagSource' NV pair. Default is captured at
                                         % class-load time in this scope so TagRegistry resolution is correct.
```

**Change 2: Add `'TagSource'` to opts struct and switch block** — insert into `opts` struct (line 85) and add case before `otherwise` (line 97-100):
```matlab
% opts struct (line 85) — ADD 'TagSource' field:
opts = struct('OutputDir', '', 'Verbose', false, 'TagSource', @TagRegistry.find);

% switch block — ADD case before 'otherwise' (line 97):
                    case 'TagSource'
                        opts.TagSource = varargin{k+1};
```

**After switch loop, assign** (after `obj.Verbose = opts.Verbose;` line 115):
```matlab
            obj.tagSource_ = opts.TagSource;
```

**Change 3: eligibleTags_** (line 251-261) — change `~` to `obj` and `TagRegistry.find` to `obj.tagSource_`:
```matlab
        function tags = eligibleTags_(obj)
            %ELIGIBLETAGS_ Filter tag source to SensorTag/StateTag with non-empty RawSource.
            tags = obj.tagSource_(@(t) ...
                (isa(t, 'SensorTag') || isa(t, 'StateTag')) && ...
                isstruct(t.RawSource) && ...
                isfield(t.RawSource, 'file') && ...
                ~isempty(t.RawSource.file));
        end
```

**Source lines for context:** `libs/SensorThreshold/BatchTagPipeline.m` lines 41-74 (properties), 85-117 (constructor), 251-261 (eligibleTags_)

---

### `libs/SensorThreshold/LiveTagPipeline.m` (modify — DI seam only)

**Identical three changes as BatchTagPipeline** applied to the LiveTagPipeline seam locations:

**Change 1: `tagSource_` property** — add to private properties block (after line 164):
```matlab
        tagSource_ = @TagRegistry.find   % DI seam (FLEET-03/D-12); mirrors BatchTagPipeline.
```

**Change 2: opts struct + switch** — add `'TagSource'` to opts (line 178) and add case before `otherwise` (line 200-202):
```matlab
% opts struct (line 178) — ADD:
opts = struct('OutputDir', '', 'Interval', 15, 'ErrorFcn', [], 'Verbose', false, ...
    'SharedRoot', '', 'LockTimeout', 5.0, 'TagSource', @TagRegistry.find);

% switch block — ADD before 'otherwise' (line 200):
                    case 'TagSource'
                        opts.TagSource = varargin{k+1};
```

After switch loop assign (after `obj.Verbose = opts.Verbose;` line ~221):
```matlab
            obj.tagSource_ = opts.TagSource;
```

**Change 3: eligibleTags_** (lines 786-806) — `~` → `obj`, `TagRegistry.find` → `obj.tagSource_`:
```matlab
        function tags = eligibleTags_(obj)
            %ELIGIBLETAGS_ Query tag source for ingestable tags.
            %   Body byte-semantically identical to BatchTagPipeline.eligibleTags_.
            %   Update BOTH sites in lockstep when adding a new eligible tag kind.
            tags = obj.tagSource_(@(t) ...
                (isa(t, 'SensorTag') || isa(t, 'StateTag')) && ...
                isstruct(t.RawSource) && ...
                isfield(t.RawSource, 'file') && ...
                ~isempty(t.RawSource.file));
        end
```

**Source lines:** `libs/SensorThreshold/LiveTagPipeline.m` lines 155-164 (properties), 178-228 (constructor), 786-806 (eligibleTags_)

---

### `tests/suite/TestMachine.m` + `tests/suite/TestFleet.m` (class-based, MATLAB only)

**Analog:** `tests/suite/TestCanonicalMapper.m` lines 1-56

**Class header + TestClassSetup pattern** (copy and adapt from TestCanonicalMapper.m lines 1-56):
```matlab
classdef TestMachine < matlab.unittest.TestCase
    %TESTMACHINE Unit tests for Phase 1042 Machine (Fleet layer).
    %
    %   Coverage:
    %     FLEET-01: Machine NV constructor; addTag; get/find/findByKind/findByLabel/keys
    %     FLEET-02: Two machines with same local key coexist; TagRegistry untouched
    %     FLEET-03: ingestBatch/startLive wrap pipelines with TagSource + OutputDir
    %     FLEET-05: 5-machine startup metadata-only (no X/Y materialization)
    %
    %   See also TestFleet, Machine.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
        end
    end
```

**Test method naming** — camelCase starting with verb (CLAUDE.md convention):
```matlab
    methods (Test)
        function testConstructorRequiresId(testCase)
        function testNameDefaultsToId(testCase)
        function testAddTagDuplicateKeyErrors(testCase)
        function testGetUnknownKeyErrors(testCase)
        function testFindByKind(testCase)
        function testFindByLabel(testCase)
        function testKeys(testCase)
        function testTwoMachinesSameLocalKeyCoexist(testCase)
        function testTagRegistryUntouched(testCase)
        % ... etc
    end
```

**Error assertion pattern** — matches TestCanonicalMapper style (verifyError):
```matlab
        function testConstructorRequiresId(testCase)
            testCase.verifyError(@() Machine(), 'Machine:missingId');
        end

        function testAddTagDuplicateKeyErrors(testCase)
            m = Machine('Id', 'M01', 'DataRoot', tempdir());
            t = MockTag('temp');
            m.addTag(t);
            testCase.verifyError(@() m.addTag(MockTag('temp')), 'Machine:duplicateKey');
        end
```

---

### `tests/test_machine.m` + `tests/test_fleet.m` (Octave flat)

**Analog:** `tests/test_tag_registry.m` lines 1-70

**Structure to copy** — function-based, `add_*_path()` helper, assert-based, no TestCase:
```matlab
function test_machine()
%TEST_MACHINE Octave flat-style coverage for Machine (FLEET-02/FLEET-03 critical paths).
%   Covers: tag isolation (TagRegistry.find == empty after 2 machines),
%           tagSource_ default unchanged (single-machine path).
%   See also TestMachine, test_fleet.

    add_fleet_path_();
    TagRegistry.clear();

    % FLEET-02: two machines with same local key; TagRegistry stays empty
    m1 = Machine('Id', 'M01', 'DataRoot', tempdir());
    m1.addTag(MockTag('temperature'));
    m2 = Machine('Id', 'M02', 'DataRoot', tempdir());
    m2.addTag(MockTag('temperature'));
    result = TagRegistry.find(@(t) true);
    assert(isempty(result), 'test_machine: TagRegistry must be empty after machine.addTag');

    % duplicate key hard-errors
    ok = false;
    try
        m1.addTag(MockTag('temperature'));
    catch me
        ok = ~isempty(strfind(me.identifier, 'Machine:duplicateKey'));
    end
    assert(ok, 'test_machine: duplicateKey error');

    TagRegistry.clear();
    fprintf('    All N tests passed.\n');
end

function add_fleet_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
end
```

**test_fleet.m covers:** JSON round-trip (save/load), filterByName/filterByGroup (Octave `strfind` path), `fleetConfigVersion` field present in saved JSON.

---

## Shared Patterns

### containers.Map Initialization
**Source:** `libs/Fleet/CanonicalMapper.m` line 67; `libs/SensorThreshold/TagRegistry.m` line 419
**Apply to:** `Machine.Tags_`, `Fleet.Machines_`
```matlab
containers.Map('KeyType', 'char', 'ValueType', 'any')
```

### Duplicate-Key Hard Error
**Source:** `libs/SensorThreshold/TagRegistry.m` lines 88-93
**Apply to:** `Machine.addTag`, `Fleet.addMachine`
```matlab
if map.isKey(key)
    error('ClassName:duplicateKey', 'Key ''%s'' already registered ...', key);
end
```

### NV Constructor with `otherwise` Guard
**Source:** `libs/SensorThreshold/BatchTagPipeline.m` lines 86-101
**Apply to:** `Machine` constructor, `Fleet` constructor (if it takes any NV args)
```matlab
opts = struct(...defaults...);
for k = 1:2:numel(varargin)
    switch varargin{k}
        case '...'; opts.Field = varargin{k+1};
        otherwise
            error('ClassName:invalidOption', 'Unknown option ''%s''.', varargin{k});
    end
end
```

### Atomic JSON Write
**Source:** `libs/Fleet/CanonicalMapper.m` lines 367-382
**Apply to:** `Fleet.save`
```matlab
tmp = [filepath '.tmp'];
fid = fopen(tmp, 'w');
fwrite(fid, json);
fclose(fid);
try; movefile(tmp, filepath, 'f');
catch mvErr
    if exist(tmp, 'file') == 2; delete(tmp); end
    error('ClassName:fileError', '...', filepath, mvErr.message);
end
```

### Octave-Safe JSON Read
**Source:** `libs/Fleet/CanonicalMapper.m` lines 413-426
**Apply to:** `Fleet.load`
```matlab
fid = fopen(filepath, 'r');
raw = fread(fid, '*char')';
fclose(fid);
s = jsondecode(raw);
```

### Per-Entry jsonencode + strjoin (Octave-safe array encode)
**Source:** `libs/Fleet/CanonicalMapper.m` lines 355-365
**Apply to:** `Fleet.save` machines array + canonicalMap entries array
```matlab
parts = cell(1, n);
for i = 1:n
    parts{i} = jsonencode(scalar_struct);
end
json = ['[' strjoin(parts, ',') ']'];
```

### Octave-Safe Text Search
**Source:** `libs/FastSenseCompanion/private/filterTags.m` (strfind pattern)
**Apply to:** `Fleet.filterByName`, `Fleet.filterByGroup`
```matlab
~isempty(strfind(lower(candidate), lower(pattern)))
```
Never use `contains()`.

### DI Seam — fn-handle private property with NV override
**Source:** `libs/SensorThreshold/BatchTagPipeline.m` lines 43-47 (`writeFn_` seam)
**Apply to:** `tagSource_` in both pipelines
```matlab
% In private properties:
tagSource_ = @TagRegistry.find   % default preserves single-machine behavior

% In opts struct:
opts = struct(..., 'TagSource', @TagRegistry.find);

% In switch:
case 'TagSource'; opts.TagSource = varargin{k+1};

% After switch:
obj.tagSource_ = opts.TagSource;
```

### TestClassSetup addPaths
**Source:** `tests/suite/TestCanonicalMapper.m` lines 48-57
**Apply to:** `TestMachine`, `TestFleet`
```matlab
methods (TestClassSetup)
    function addPaths(testCase) %#ok<MANU>
        here = fileparts(mfilename('fullpath'));
        repo = fileparts(fileparts(here));
        addpath(repo);
        install();
    end
end
```

### Octave Flat Test addpath Helper
**Source:** `tests/test_tag_registry.m` (local `add_tag_registry_path()` function pattern)
**Apply to:** `test_machine.m`, `test_fleet.m`
```matlab
function add_fleet_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
end
```

---

## No Analog Found

All files have close analogs in the codebase. No file requires falling back to RESEARCH.md patterns exclusively.

---

## Metadata

**Analog search scope:** `libs/Fleet/`, `libs/SensorThreshold/`, `libs/Dashboard/private/`, `tests/suite/`, `tests/`
**Files read:** `TagRegistry.m`, `CanonicalMapper.m` (lines 1-120, 330-430), `BatchTagPipeline.m` (lines 40-270), `LiveTagPipeline.m` (lines 155-230, 780-810), `normalizeToCell.m`, `TestCanonicalMapper.m` (lines 1-80), `test_tag_registry.m` (lines 1-70)
**Pattern extraction date:** 2026-06-03
