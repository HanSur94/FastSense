classdef PlantLogEntry
%PLANTLOGENTRY Immutable value class representing one plant-log entry.
%   e = PlantLogEntry(rowStruct) builds an entry from a struct with
%   fields {Timestamp, Message, Metadata, SourceFile, RowHash, Id}.
%   Missing optional fields default sensibly.
%
%   e = PlantLogEntry('Timestamp', t, 'Message', m, 'Metadata', md, ...)
%   builds an entry from name-value pairs. Equivalent to the struct form.
%
%   PlantLogEntry is a VALUE CLASS (no `< handle`): every field is
%   read-only after construction (SetAccess = private). PlantLogStore
%   mutates only its own internal array — never an existing entry.
%
%   Properties (all SetAccess = private):
%     Timestamp   numeric scalar (datenum convention)
%     Message     char vector
%     Metadata    struct (dynamic fields; may be empty struct())
%     Id          char vector ('' until assigned by PlantLogStore)
%     RowHash     1x16 char vector (lowercase hex; auto-computed if not supplied)
%     SourceFile  char vector (informational; '' if not supplied)
%
%   Errors:
%     PlantLogEntry:invalidInput  — missing required Timestamp field,
%                                   bad arg count, or non-char option key
%     PlantLogEntry:typeMismatch  — field has wrong type
%     PlantLogEntry:unknownOption — name-value key not recognized
%
%   Example:
%     e = PlantLogEntry(struct( ...
%         'Timestamp', datenum('2025-01-15 12:00:00'), ...
%         'Message', 'Pump A started', ...
%         'Metadata', struct('MachineId', 'M1', 'Operator', 'jdoe'), ...
%         'SourceFile', 'plant_log.csv'));
%     e.RowHash   % 16-char lowercase hex
%
%   See also PlantLogStore.

    properties (SetAccess = private)
        Timestamp   = NaN
        Message     = ''
        Metadata    = struct()
        Id          = ''
        RowHash     = ''
        SourceFile  = ''
    end

    methods
        function obj = PlantLogEntry(varargin)
            %PLANTLOGENTRY Construct an immutable entry from struct or name-value pairs.
            % Accept either a single struct OR a varargin name-value list.
            opts = struct( ...
                'Timestamp', NaN, ...
                'Message', '', ...
                'Metadata', struct(), ...
                'Id', '', ...
                'RowHash', '', ...
                'SourceFile', '');

            if nargin == 0
                % No-arg constructor returns a default-valued entry — required
                % by MATLAB for value-class array initialization. Such entries
                % have Timestamp = NaN and are invalid for the store but legal
                % as placeholders.
                return;
            elseif nargin == 1 && isstruct(varargin{1})
                src = varargin{1};
                fn = fieldnames(opts);
                for k = 1:numel(fn)
                    if isfield(src, fn{k})
                        opts.(fn{k}) = src.(fn{k});
                    end
                end
            elseif nargin == 1
                error('PlantLogEntry:invalidInput', ...
                    'Single-argument form requires a struct; got %s.', class(varargin{1}));
            else
                if mod(nargin, 2) ~= 0
                    error('PlantLogEntry:invalidInput', ...
                        'Name-value pairs must come in pairs; got %d args.', nargin);
                end
                validFields = fieldnames(opts);
                for k = 1:2:numel(varargin)
                    key = varargin{k};
                    val = varargin{k+1};
                    if ~ischar(key) && ~isstring(key)
                        error('PlantLogEntry:invalidInput', ...
                            'Option keys must be char; got %s at position %d.', class(key), k);
                    end
                    idx = find(strcmpi(validFields, char(key)), 1);
                    if isempty(idx)
                        error('PlantLogEntry:unknownOption', ...
                            'Unknown option ''%s''. Valid: %s.', char(key), strjoin(validFields, ', '));
                    end
                    opts.(validFields{idx}) = val;
                end
            end

            % --- Validation ---
            if ~isnumeric(opts.Timestamp) || ~isscalar(opts.Timestamp) || isnan(opts.Timestamp)
                error('PlantLogEntry:invalidInput', ...
                    'Timestamp must be a non-NaN numeric scalar; got %s.', class(opts.Timestamp));
            end
            if isstring(opts.Message); opts.Message = char(opts.Message); end
            if ~ischar(opts.Message)
                error('PlantLogEntry:typeMismatch', ...
                    'Message must be char or string; got %s.', class(opts.Message));
            end
            if ~isstruct(opts.Metadata)
                error('PlantLogEntry:typeMismatch', ...
                    'Metadata must be a struct; got %s.', class(opts.Metadata));
            end
            if isstring(opts.Id); opts.Id = char(opts.Id); end
            if ~ischar(opts.Id)
                error('PlantLogEntry:typeMismatch', ...
                    'Id must be char; got %s.', class(opts.Id));
            end
            if isstring(opts.RowHash); opts.RowHash = char(opts.RowHash); end
            if ~ischar(opts.RowHash)
                error('PlantLogEntry:typeMismatch', ...
                    'RowHash must be char; got %s.', class(opts.RowHash));
            end
            if isstring(opts.SourceFile); opts.SourceFile = char(opts.SourceFile); end
            if ~ischar(opts.SourceFile)
                error('PlantLogEntry:typeMismatch', ...
                    'SourceFile must be char; got %s.', class(opts.SourceFile));
            end

            % --- Auto-compute RowHash when not supplied ---
            if isempty(opts.RowHash)
                tmp.Message  = opts.Message;
                tmp.Metadata = opts.Metadata;
                opts.RowHash = computeRowHash(tmp);
            end

            % --- Assign to read-only properties (allowed inside constructor) ---
            obj.Timestamp  = double(opts.Timestamp);
            obj.Message    = opts.Message;
            obj.Metadata   = opts.Metadata;
            obj.Id         = opts.Id;
            obj.RowHash    = opts.RowHash;
            obj.SourceFile = opts.SourceFile;
        end

        function obj = withId(obj, newId)
            %WITHID Return a copy of this entry with Id set to newId.
            %   Used by PlantLogStore to assign sequential 'plog_N' ids.
            %   Because PlantLogEntry is a value class, this returns a
            %   new copy; the original is unchanged.
            if isstring(newId); newId = char(newId); end
            if ~ischar(newId)
                error('PlantLogEntry:typeMismatch', ...
                    'Id must be char; got %s.', class(newId));
            end
            obj.Id = newId;
        end
    end
end
