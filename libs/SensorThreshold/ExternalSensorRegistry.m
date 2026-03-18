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
