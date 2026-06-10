classdef Fleet < handle
    %FLEET Searchable collection of Machine instances with JSON persistence.
    %   Fleet owns an insertion-ordered collection of Machine handles, enforces
    %   unique machine Ids within the fleet, provides composable case-insensitive
    %   group and name filters, embeds a CanonicalMapper for cross-machine tag
    %   resolution, and persists the whole fleet definition (machine metadata +
    %   embedded canonical map) to a single JSON file.
    %
    %   Usage:
    %     fleet = Fleet();
    %     fleet.addMachine('Id', 'M01', 'Name', 'Pump 1', 'Group', 'pumps', ...
    %                      'DataRoot', '/data/m01');
    %     fleet.addMachine('Id', 'M02', 'Name', 'Motor A', 'Group', 'motors', ...
    %                      'DataRoot', '/data/m02');
    %
    %     byPumps = fleet.filterByGroup('pumps');   % cell of Machine handles
    %     byAlpha = fleet.filterByName('alpha');
    %
    %     fleet.save('/cfg/fleet.json');
    %     fleet2 = Fleet.load('/cfg/fleet.json');
    %
    %   Properties (SetAccess = private):
    %     Mapper_     CanonicalMapper handle for cross-machine logical-sensor resolution
    %
    %   Methods (public):
    %     addMachine     - add Machine (factory NV-pair form or pre-built handle)
    %     getMachine     - retrieve Machine by Id (Fleet:unknownMachineId on miss)
    %     machineCount   - number of machines in the fleet
    %     filterByName   - case-insensitive substring filter on Name; returns cell
    %     filterByGroup  - case-insensitive substring filter on Group; returns cell
    %     resolveLogical - bridge logicalId to per-machine {machine, Tag} pairs
    %     save           - atomically write fleet config to JSON
    %
    %   Static:
    %     load           - read fleet config from JSON (Fleet:fileNotFound on miss)
    %
    %   Errors (namespaced under Fleet:*):
    %     Fleet:duplicateMachineId  -- addMachine with Id already in fleet
    %     Fleet:unknownMachineId    -- getMachine with Id not in fleet
    %     Fleet:fileNotFound        -- load called with non-existent file
    %     Fleet:fileError           -- save/load I/O failure
    %
    %   Design notes:
    %     - JSON persistence uses per-entry jsonencode + strjoin to avoid MATLAB/Octave
    %       divergence on cell-of-structs encoding (Pitfall 3 from 1042-RESEARCH.md).
    %     - Atomic write: write to .tmp then movefile(tmp, dest, 'f') so an interrupted
    %       save never corrupts the prior config (T-1042-09).
    %     - DataRoot resolution on load is delegated to Machine.fromConfigStruct (D-07).
    %     - No UI code; fully Octave 7+ compatible; Octave-safe search only; no TagRegistry writes.
    %
    %   See also Machine, CanonicalMapper, Fleet.load.

    properties (SetAccess = private)
        Machines_   % containers.Map: machineId (char) -> Machine handle
        MachineIds_ % cell of char; insertion-order list of Ids
        Mapper_     % CanonicalMapper handle for cross-machine tag resolution
    end

    methods (Access = public)

        function obj = Fleet()
            %FLEET Construct an empty fleet.
            %   fleet = Fleet()
            %   Creates an empty Machines_ map, an empty MachineIds_ list, and
            %   a fresh CanonicalMapper in Mapper_.
            obj.Machines_   = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.MachineIds_ = {};
            obj.Mapper_     = CanonicalMapper();
        end

        function m = addMachine(obj, varargin)
            %ADDMACHINE Add a Machine to the fleet (factory or handle form).
            %   m = fleet.addMachine('Id', 'M01', 'Name', 'Pump 1', ...)
            %   m = fleet.addMachine(preBuiltMachine)
            %
            %   Factory form: passes all arguments to the Machine constructor.
            %   Handle form:  accepts a pre-built Machine handle directly.
            %   Returns the Machine handle in either case.
            %
            %   Errors:
            %     Fleet:duplicateMachineId -- Id already present in this fleet (D-10)
            if numel(varargin) == 1 && isa(varargin{1}, 'Machine')
                m = varargin{1};
            else
                m = Machine(varargin{:});
            end
            if obj.Machines_.isKey(m.Id)
                error('Fleet:duplicateMachineId', ...
                    'Machine with Id ''%s'' already in fleet. Use a unique Id.', m.Id);
            end
            obj.Machines_(m.Id)    = m;
            obj.MachineIds_{end+1} = m.Id;
        end

        function m = getMachine(obj, id)
            %GETMACHINE Retrieve a Machine by Id.
            %   m = fleet.getMachine('M01')
            %
            %   Errors:
            %     Fleet:unknownMachineId -- id not present in this fleet
            if ~obj.Machines_.isKey(id)
                error('Fleet:unknownMachineId', ...
                    'No machine with Id ''%s'' in this fleet.', id);
            end
            m = obj.Machines_(id);
        end

        function n = machineCount(obj)
            %MACHINECOUNT Return the number of machines in this fleet.
            %   n = fleet.machineCount()
            n = numel(obj.MachineIds_);
        end

        function ids = machineIds(obj)
            %MACHINEIDS Return insertion-ordered cell array of machine Ids.
            %   ids = fleet.machineIds()
            ids = obj.MachineIds_;
        end

        function m = mapper(obj)
            %MAPPER Return the CanonicalMapper handle for cross-machine resolution.
            %   m = fleet.mapper()
            %
            %   Public accessor (mirrors machineIds()) so callers reach the
            %   embedded CanonicalMapper through a documented seam rather than
            %   the private Mapper_ field. Used by the Phase 1045 cross-machine
            %   comparison helpers (buildCompareResolution_).
            m = obj.Mapper_;
        end

        function ms = filterByName(obj, pattern)
            %FILTERBYNAME Case-insensitive substring filter on Machine Name.
            %   ms = fleet.filterByName(pattern)
            %
            %   Returns a cell array of Machine handles whose Name contains
            %   pattern (case-insensitive substring match). Returns {} when
            %   no machines match. Order follows insertion order.
            %
            %   Octave-safe: uses strfind(lower(...)), never the MATLAB-only 'contains' builtin.
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
            %FILTERBYGROUP Case-insensitive substring filter on Machine Group.
            %   ms = fleet.filterByGroup(group)
            %
            %   Returns a cell array of Machine handles whose Group contains
            %   group (case-insensitive substring match). Returns {} when
            %   no machines match. Order follows insertion order.
            %
            %   Octave-safe: uses strfind(lower(...)), never the MATLAB-only 'contains' builtin.
            grp = lower(char(group));
            ms = {};
            for i = 1:numel(obj.MachineIds_)
                m = obj.Machines_(obj.MachineIds_{i});
                if ~isempty(strfind(lower(m.Group), grp))
                    ms{end+1} = m; %#ok<AGROW>
                end
            end
        end

        function pairs = resolveLogical(obj, logicalId)
            %RESOLVELOGICAL Bridge a logicalId to per-machine {machine, Tag} pairs.
            %   pairs = fleet.resolveLogical(logicalId)
            %
            %   Queries Mapper_ for the logicalId's per-machine local keys. For
            %   each machine that (1) is present in this fleet and (2) has the
            %   mapped local key in its catalog, returns a 2-element cell
            %   {machine, tag}. Machines that cannot be resolved (absent from
            %   fleet, key not in catalog, or no mapping) are silently skipped.
            %
            %   Returns a Nx2 cell where each row is {Machine, Tag}, or {} when
            %   no machine can resolve the logicalId.
            pairs = {};
            if ~isKey(obj.Mapper_.Entries_, logicalId)
                return;
            end
            bucket = obj.Mapper_.Entries_(logicalId);
            for i = 1:numel(bucket)
                e = bucket{i};
                machineId = e.machineId;
                localKey  = e.localKey;
                if ~obj.Machines_.isKey(machineId)
                    continue;
                end
                m = obj.Machines_(machineId);
                try
                    tag = m.get(localKey);
                    pairs{end+1} = {m, tag}; %#ok<AGROW>
                catch
                    % Key absent from machine catalog; skip gracefully.
                end
            end
        end

        function save(obj, filepath)
            %SAVE Atomically write the fleet config to JSON.
            %   fleet.save(filepath)
            %
            %   Builds a JSON document:
            %     {"fleetConfigVersion":1,"machines":[...],"canonicalMap":{...}}
            %   Machines and canonical-map entries are encoded per-entry using
            %   jsonencode + strjoin to avoid MATLAB/Octave cell-of-structs
            %   divergence (Pitfall 3). Writes to filepath.tmp then atomic
            %   movefile so an interrupted save never corrupts the prior config.
            %
            %   Errors:
            %     Fleet:fileError -- fopen/movefile failure

            % Build machines JSON array via per-entry encode
            nMachines = numel(obj.MachineIds_);
            if nMachines == 0
                machinesJson = '[]';
            else
                machineParts = cell(1, nMachines);
                for i = 1:nMachines
                    m = obj.Machines_(obj.MachineIds_{i});
                    machineParts{i} = jsonencode(m.toConfigStruct());
                end
                machinesJson = ['[' strjoin(machineParts, ',') ']'];
            end

            % Embed canonical map: per-entry encode Mapper_.toStruct().entries
            cmStruct  = obj.Mapper_.toStruct();
            nEntries  = numel(cmStruct.entries);
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

            % Assemble top-level document with schema version (FLEET-04)
            json = sprintf('{"fleetConfigVersion":1,"machines":%s,"canonicalMap":%s}', ...
                machinesJson, cmJson);

            % Atomic write: .tmp + movefile (T-1042-09)
            tmp = [filepath '.tmp'];
            fid = fopen(tmp, 'w');
            if fid == -1
                error('Fleet:fileError', 'Cannot open file for writing: %s', tmp);
            end
            fwrite(fid, json);
            fclose(fid);
            try
                movefile(tmp, filepath, 'f');
            catch mvErr
                if exist(tmp, 'file') == 2
                    delete(tmp);
                end
                error('Fleet:fileError', 'Failed to save to %s: %s', filepath, mvErr.message);
            end
        end

    end

    methods (Static)

        function obj = load(filepath)
            %LOAD Read a fleet config from a JSON file written by save().
            %   fleet = Fleet.load(filepath)
            %
            %   Decodes the JSON, normalizes the machines array via normalizeToCell_,
            %   reconstructs each Machine via Machine.fromConfigStruct (which resolves
            %   relative DataRoots against fileparts(filepath), D-07), and rehydrates
            %   the embedded CanonicalMapper via CanonicalMapper.fromStruct.
            %
            %   Forward-compatible: if fleetConfigVersion is absent it defaults to 1
            %   (Pitfall 12 guard).
            %
            %   Errors:
            %     Fleet:fileNotFound -- filepath does not exist
            %     Fleet:fileError    -- fopen failure
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

            % Forward-compatibility guard: default missing version field to 1
            if ~isfield(s, 'fleetConfigVersion')
                s.fleetConfigVersion = 1;
            end

            obj = Fleet();

            % Rebuild machines in insertion order
            machines = normalizeToCell_(s.machines);
            for i = 1:numel(machines)
                m = Machine.fromConfigStruct(machines{i}, filepath);
                obj.addMachine(m);
            end

            % Rehydrate embedded canonical map when present
            if isfield(s, 'canonicalMap')
                obj.Mapper_ = CanonicalMapper.fromStruct(s.canonicalMap);
            end
        end

    end

end
