classdef EventStore < handle
    % EventStore  Atomic read/write of events to a shared .mat file.

    properties
        FilePath        = ''
        MaxBackups      = 5
        PipelineConfig  = struct()
        SensorData      = []   % struct array: name, t, y (for EventViewer click-to-plot)
        ThresholdColors = struct()  % serialized threshold colors struct
        Timestamp       = []        % datetime: when events were saved
    end

    properties (Access = private)
        events_     = []
        nextId_     = 0
    end

    methods
        function obj = EventStore(filePath, varargin)
            defaults.MaxBackups = 5;
            opts = parseOpts(defaults, varargin);
            obj.FilePath   = filePath;
            obj.MaxBackups = opts.MaxBackups;
        end

        function append(obj, newEvents)
            if isempty(newEvents); return; end
            for i = 1:numel(newEvents)
                obj.nextId_ = obj.nextId_ + 1;
                newEvents(i).Id = sprintf('evt_%d', obj.nextId_);
                if isempty(obj.events_)
                    obj.events_ = newEvents(i);
                else
                    obj.events_(end+1) = newEvents(i);
                end
            end
        end

        function events = getEvents(obj)
            events = obj.events_;
        end

        function events = getEventsForTag(obj, tagKey)
        %GETEVENTSFORTAG Return events bound to tagKey via EventBinding + carrier fallback.
        %   Primary path: uses EventBinding.getEventsForTag for events
        %   with non-empty Id (Phase 1010 EVENT-01/EVENT-03).
        %   Fallback path: carrier-field matching (SensorName/ThresholdLabel)
        %   for events without Id (backward compat, Pitfall 4).
        %
        %   Errors:
        %     EventStore:invalidTagKey — tagKey not char / string
            events = [];
            if isempty(obj.events_), return; end
            if ~ischar(tagKey) && ~isstring(tagKey)
                error('EventStore:invalidTagKey', ...
                    'tagKey must be char or string; got %s.', class(tagKey));
            end
            tagKey = char(tagKey);
            % Primary path: EventBinding-based lookup
            boundEvents = EventBinding.getEventsForTag(tagKey, obj);
            % Fallback path: carrier-field matching (SensorName/ThresholdLabel)
            % for events NOT already found by EventBinding
            keep = false(1, numel(obj.events_));
            for i = 1:numel(obj.events_)
                ev = obj.events_(i);
                % Check if this event was already found by EventBinding (by Id)
                alreadyBound = false;
                evId = '';
                if isa(ev, 'Event') && ~isempty(ev.Id)
                    evId = ev.Id;
                end
                if ~isempty(evId)
                    for bi = 1:numel(boundEvents)
                        if strcmp(evId, boundEvents(bi).Id)
                            alreadyBound = true;
                            break;
                        end
                    end
                end
                if alreadyBound
                    continue;
                end
                sn = '';
                tl = '';
                if isa(ev, 'Event')
                    sn = ev.SensorName;
                    tl = ev.ThresholdLabel;
                elseif isstruct(ev)
                    if isfield(ev, 'SensorName'), sn = ev.SensorName; end
                    if isfield(ev, 'ThresholdLabel'), tl = ev.ThresholdLabel; end
                end
                keep(i) = strcmp(sn, tagKey) || strcmp(tl, tagKey);
            end
            carrierEvents = obj.events_(keep);
            % Combine: EventBinding results + carrier fallback (dedup by handle ==)
            if isempty(boundEvents) && isempty(carrierEvents)
                events = [];
            elseif isempty(boundEvents)
                events = carrierEvents;
            elseif isempty(carrierEvents)
                events = boundEvents;
            else
                events = [boundEvents, carrierEvents];
            end
        end

        function save(obj)
            if isempty(obj.FilePath); return; end

            % Backup existing file
            if isfile(obj.FilePath) && obj.MaxBackups > 0
                obj.createBackup();
            end

            % Atomic write: save to temp, then rename
            tmpFile = [obj.FilePath '.tmp'];
            events = obj.events_; %#ok<PROPLC>
            lastUpdated = now; %#ok<NASGU>
            pipelineConfig = obj.PipelineConfig; %#ok<PROPLC,NASGU>
            sensorData = obj.SensorData; %#ok<PROPLC,NASGU>
            thresholdColors = obj.ThresholdColors; %#ok<PROPLC,NASGU>
            timestamp = obj.Timestamp; %#ok<PROPLC,NASGU>

            varList = {'events', 'lastUpdated', 'pipelineConfig'};
            if ~isempty(sensorData)
                varList{end+1} = 'sensorData';
            end
            if isstruct(thresholdColors) && ~isempty(fieldnames(thresholdColors))
                varList{end+1} = 'thresholdColors';
            end
            if ~isempty(timestamp)
                varList{end+1} = 'timestamp';
            end
            if exist('OCTAVE_VERSION', 'builtin')
                builtin('save', tmpFile, varList{:});
            else
                builtin('save', tmpFile, varList{:}, '-v7.3');
            end
            movefile(tmpFile, obj.FilePath);
        end

        function n = numEvents(obj)
            n = numel(obj.events_);
        end
    end

    methods (Static)
        function [events, meta, changed] = loadFile(filePath)
            persistent lastModTime lastData;
            if isempty(lastModTime)
                lastModTime = containers.Map('KeyType', 'char', 'ValueType', 'double');
                lastData = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end

            events = [];
            meta = struct();
            changed = false;

            if ~isfile(filePath); return; end

            info = dir(filePath);
            modTime = info.datenum;

            if lastModTime.isKey(filePath) && modTime <= lastModTime(filePath)
                % Unchanged — return cached results without re-reading file
                if lastData.isKey(filePath)
                    cached = lastData(filePath);
                    events = cached.events;
                    meta = cached.meta;
                end
                return;
            end

            lastModTime(filePath) = modTime;
            changed = true;

            data = builtin('load', filePath);
            if isfield(data, 'events')
                events = data.events;
            end
            if isfield(data, 'lastUpdated')
                meta.lastUpdated = data.lastUpdated;
            end
            if isfield(data, 'pipelineConfig')
                meta.pipelineConfig = data.pipelineConfig;
            end

            % Cache for future unchanged calls
            lastData(filePath) = struct('events', events, 'meta', meta);
        end
    end

    methods (Access = private)
        function createBackup(obj)
            [fdir, fname, fext] = fileparts(obj.FilePath);
            stamp = datestr(now, 'yyyymmdd_HHMMSS');
            backupName = fullfile(fdir, [fname '_backup_' stamp fext]);
            copyfile(obj.FilePath, backupName);
            obj.pruneBackups();
        end

        function pruneBackups(obj)
            [fdir, fname] = fileparts(obj.FilePath);
            pattern = fullfile(fdir, [fname '_backup_*.mat']);
            backups = dir(pattern);
            if numel(backups) > obj.MaxBackups
                [~, idx] = sort([backups.datenum]);
                toDelete = backups(idx(1:end - obj.MaxBackups));
                for i = 1:numel(toDelete)
                    delete(fullfile(fdir, toDelete(i).name));
                end
            end
        end
    end
end
