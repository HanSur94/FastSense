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
        events_     = Event.empty()
    end

    methods
        function obj = EventStore(filePath, varargin)
            p = inputParser();
            p.addRequired('filePath', @ischar);
            p.addParameter('MaxBackups', 5, @isnumeric);
            p.parse(filePath, varargin{:});
            obj.FilePath   = p.Results.filePath;
            obj.MaxBackups = p.Results.MaxBackups;
        end

        function append(obj, newEvents)
            if isempty(newEvents); return; end
            if isempty(obj.events_)
                obj.events_ = newEvents(:)';
            else
                obj.events_ = [obj.events_, newEvents(:)'];
            end
        end

        function events = getEvents(obj)
            events = obj.events_;
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
            builtin('save', tmpFile, varList{:}, '-v7.3');
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

            events = Event.empty();
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
