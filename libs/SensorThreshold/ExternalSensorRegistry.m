classdef ExternalSensorRegistry < handle
    %EXTERNALSENSORREGISTRY Non-singleton sensor registry for external data.
    %   ExternalSensorRegistry holds explicitly registered Sensor objects
    %   and wires them to .mat file data sources for use with
    %   LiveEventPipeline.
    %
    %   Unlike SensorRegistry (singleton with hardcoded catalog), this
    %   class supports multiple instances and is populated via register().
    %
    %   See also SensorRegistry, Sensor, DataSourceMap.

    properties
        Name  % char: human-readable label for this registry
    end

    properties (Access = private)
        catalog_  % containers.Map (char -> Sensor)
        dsMap_    % DataSourceMap
    end

    methods
        function obj = ExternalSensorRegistry(name)
            %EXTERNALSENSORREGISTRY Construct a named registry.
            %   reg = ExternalSensorRegistry('MyLab')
            obj.Name = name;
            obj.catalog_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.dsMap_ = DataSourceMap();
        end

        function n = count(obj)
            %COUNT Number of registered sensors.
            n = double(obj.catalog_.Count);
        end

        function k = keys(obj)
            %KEYS Return all registered sensor keys.
            k = obj.catalog_.keys();
        end

        function register(obj, key, sensor)
            %REGISTER Add a Sensor to the catalog.
            %   reg.register('key', sensorObj)
            assert(isa(sensor, 'Sensor'), ...
                'ExternalSensorRegistry:invalidType', ...
                'Value must be a Sensor object.');
            obj.catalog_(key) = sensor;
        end

        function unregister(obj, key)
            %UNREGISTER Remove a Sensor from the catalog.
            if obj.catalog_.isKey(key)
                obj.catalog_.remove(key);
            end
        end

        function s = get(obj, key)
            %GET Retrieve a sensor by key.
            if ~obj.catalog_.isKey(key)
                error('ExternalSensorRegistry:unknownKey', ...
                    'No sensor with key ''%s'' in registry ''%s''.', key, obj.Name);
            end
            s = obj.catalog_(key);
        end

        function sensors = getMultiple(obj, keys)
            %GETMULTIPLE Retrieve multiple sensors by key.
            sensors = cell(1, numel(keys));
            for i = 1:numel(keys)
                sensors{i} = obj.get(keys{i});
            end
        end

        function m = getAll(obj)
            %GETALL Return a copy of the catalog as a containers.Map.
            m = containers.Map(obj.catalog_.keys(), obj.catalog_.values());
        end

        function list(obj)
            %LIST Print all registered sensor keys and names.
            ks = sort(obj.catalog_.keys());
            fprintf('\n  [%s] Available sensors:\n', obj.Name);
            for i = 1:numel(ks)
                s = obj.catalog_(ks{i});
                name = s.Name;
                if isempty(name); name = '(no name)'; end
                fprintf('    %-25s  %s\n', ks{i}, name);
            end
            fprintf('\n');
        end

        function printTable(obj)
            %PRINTTABLE Print a detailed table of all registered sensors.
            ks = sort(obj.catalog_.keys());
            nSensors = numel(ks);
            if nSensors == 0
                fprintf('No sensors registered in ''%s''.\n', obj.Name);
                return;
            end
            fprintf('\n  [%s]\n', obj.Name);
            fprintf('  %-20s %-25s %6s  %-20s %-20s %7s %6s %8s\n', ...
                'Key', 'Name', 'ID', 'Source', 'MatFile', '#States', '#Rules', '#Points');
            fprintf('  %s\n', repmat('-', 1, 118));
            for i = 1:nSensors
                s = obj.catalog_(ks{i});
                name = s.Name; if isempty(name); name = ''; end
                idStr = ''; if ~isempty(s.ID); idStr = num2str(s.ID); end
                nStates = numel(s.StateChannels);
                nRules  = numel(s.ThresholdRules);
                nPts    = numel(s.X);
                fprintf('  %-20s %-25s %6s  %-20s %-20s %7d %6d %8d\n', ...
                    ExternalSensorRegistry.truncStr(ks{i}, 20), ...
                    ExternalSensorRegistry.truncStr(name, 25), ...
                    idStr, ...
                    ExternalSensorRegistry.truncStr(s.Source, 20), ...
                    ExternalSensorRegistry.truncStr(s.MatFile, 20), ...
                    nStates, nRules, nPts);
            end
            fprintf('\n  %d sensor(s) total.\n\n', nSensors);
        end

        function wireMatFile(obj, matFilePath, mappings)
            %WIREMATFILE Wire .mat file fields to registered sensor keys.
            %   reg.wireMatFile('data.mat', {
            %       'sensorKey', 'XVar', 'time', 'YVar', 'value';
            %   })
            %
            %   Each row of mappings: {sensorKey, 'XVar', xField, 'YVar', yField}
            for i = 1:size(mappings, 1)
                key = mappings{i, 1};
                if ~obj.catalog_.isKey(key)
                    error('ExternalSensorRegistry:unknownKey', ...
                        'Cannot wire ''%s'': not registered in ''%s''.', key, obj.Name);
                end

                % Parse name-value pairs from remaining columns
                nvPairs = mappings(i, 2:end);
                p = inputParser();
                p.addParameter('XVar', 'X', @ischar);
                p.addParameter('YVar', 'Y', @ischar);
                p.parse(nvPairs{:});

                % Set Sensor properties
                s = obj.catalog_(key);
                s.MatFile = matFilePath;
                s.KeyName = p.Results.YVar;

                % Create MatFileDataSource
                ds = MatFileDataSource(matFilePath, ...
                    'XVar', p.Results.XVar, 'YVar', p.Results.YVar);

                % Warn on overwrite
                if obj.dsMap_.has(key)
                    warning('ExternalSensorRegistry:overwrite', ...
                        'Overwriting data source for ''%s'' in ''%s''.', key, obj.Name);
                end
                obj.dsMap_.add(key, ds);
            end
        end

        function dsMap = getDataSourceMap(obj)
            %GETDATASOURCEMAP Return the DataSourceMap for pipeline use.
            dsMap = obj.dsMap_;
        end

        function hFig = viewer(obj)
            %VIEWER Open a GUI figure showing all registered sensors.
            ks = sort(obj.catalog_.keys());
            nSensors = numel(ks);

            colNames = {'Key', 'Name', 'ID', 'Source', 'MatFile', '#States', '#Rules', '#Points'};
            data = cell(nSensors, numel(colNames));
            for i = 1:nSensors
                s = obj.catalog_(ks{i});
                data{i,1} = ks{i};
                data{i,2} = s.Name;
                if isempty(s.ID); data{i,3} = ''; else; data{i,3} = s.ID; end
                data{i,4} = s.Source;
                data{i,5} = s.MatFile;
                data{i,6} = numel(s.StateChannels);
                data{i,7} = numel(s.ThresholdRules);
                data{i,8} = numel(s.X);
            end

            hFig = figure('Name', sprintf('%s — Sensor Registry', obj.Name), ...
                'NumberTitle', 'off', ...
                'Position', [200 200 900 400], ...
                'Color', [0.15 0.15 0.18], ...
                'MenuBar', 'none', 'ToolBar', 'none');

            uicontrol('Parent', hFig, 'Style', 'text', ...
                'String', sprintf('%s  (%d sensors)', obj.Name, nSensors), ...
                'Units', 'normalized', 'Position', [0.02 0.92 0.96 0.06], ...
                'BackgroundColor', [0.15 0.15 0.18], ...
                'ForegroundColor', [0.9 0.9 0.9], ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left');

            colWidths = {140, 180, 50, 140, 140, 55, 50, 60};
            uitable('Parent', hFig, ...
                'Data', data, 'ColumnName', colNames, ...
                'ColumnWidth', colWidths, ...
                'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.88], ...
                'RowName', [], ...
                'BackgroundColor', [0.22 0.22 0.25; 0.18 0.18 0.21], ...
                'ForegroundColor', [0.9 0.9 0.9], 'FontSize', 11);
        end

        function wireStateChannel(obj, sensorKey, stateKey, matFilePath, varargin)
            %WIRESTATECHANNEL Wire state channel data to a registered sensor.
            %   reg.wireStateChannel('sensorKey', 'stateKey', 'states.mat', ...
            %       'XVar', 'state_time', 'YVar', 'state_val')
            if ~obj.catalog_.isKey(sensorKey)
                error('ExternalSensorRegistry:unknownKey', ...
                    'Cannot wire state to ''%s'': not registered in ''%s''.', ...
                    sensorKey, obj.Name);
            end

            p = inputParser();
            p.addParameter('XVar', 'X', @ischar);
            p.addParameter('YVar', 'Y', @ischar);
            p.parse(varargin{:});

            % Create StateChannel
            % Note: For different-file state channels, the caller must populate
            % sc.X and sc.Y manually (or via MatFileDataSource with state vars),
            % because StateChannel.load() is not yet implemented.
            sc = StateChannel(stateKey, 'MatFile', matFilePath, ...
                'KeyName', p.Results.YVar);

            % Attach to sensor
            s = obj.catalog_(sensorKey);
            s.addStateChannel(sc);

            % If same file as sensor data, update existing DataSource
            if obj.dsMap_.has(sensorKey)
                ds = obj.dsMap_.get(sensorKey);
                if strcmp(ds.FilePath, matFilePath)
                    ds.StateXVar = p.Results.XVar;
                    ds.StateYVar = p.Results.YVar;
                end
            end
        end
    end

    methods (Static, Access = private)
        function s = truncStr(s, maxLen)
            if isempty(s); s = ''; end
            if numel(s) > maxLen
                s = [s(1:maxLen-2), '..'];
            end
        end
    end
end
