classdef SensorRegistry
    %SENSORREGISTRY Catalog of predefined sensor definitions.
    %   SensorRegistry provides a centralized, singleton-style catalog of
    %   all known Sensor objects in the SensorThreshold library. Sensor
    %   definitions are specified in the private catalog() method and
    %   cached in a persistent variable so that repeated lookups incur no
    %   construction overhead.
    %
    %   To add a new sensor, edit the catalog() method at the bottom of
    %   this file.  Each entry creates a Sensor object, optionally
    %   configures its state channels and threshold rules, then stores it
    %   in the containers.Map keyed by a short string identifier.
    %
    %   SensorRegistry Methods:
    %     get         — Retrieve a single Sensor by its string key
    %     getMultiple — Retrieve several Sensors at once (cell array input)
    %     list        — Print a formatted table of all available sensor keys
    %
    %   Example:
    %     s = SensorRegistry.get('pressure');
    %     sensors = SensorRegistry.getMultiple({'pressure', 'temperature'});
    %     SensorRegistry.list();
    %
    %   See also Sensor, ThresholdRule, StateChannel.

    methods (Static)
        function s = get(key)
            %GET Retrieve a predefined sensor by key.
            %   s = SensorRegistry.get(key) returns the Sensor object
            %   registered under the string key. Throws an error if the
            %   key is not found in the catalog.
            %
            %   Input:
            %     key — char, unique identifier for the desired sensor
            %
            %   Output:
            %     s — Sensor object corresponding to the key
            %
            %   See also SensorRegistry.getMultiple, SensorRegistry.list.

            % Fetch the cached catalog map (built on first call)
            map = SensorRegistry.catalog();

            % Validate that the requested key exists
            if ~map.isKey(key)
                error('SensorRegistry:unknownKey', ...
                    'No sensor defined with key ''%s''. Use SensorRegistry.list() to see available sensors.', key);
            end
            s = map(key);
        end

        function sensors = getMultiple(keys)
            %GETMULTIPLE Retrieve multiple sensors by key.
            %   sensors = SensorRegistry.getMultiple(keys) returns a cell
            %   array of Sensor objects, one per element of the input keys.
            %
            %   Input:
            %     keys — cell array of char, sensor identifier strings
            %
            %   Output:
            %     sensors — 1xN cell array of Sensor objects
            %
            %   See also SensorRegistry.get.

            sensors = cell(1, numel(keys));
            for i = 1:numel(keys)
                sensors{i} = SensorRegistry.get(keys{i});
            end
        end

        function list()
            %LIST Print all available sensor keys and names.
            %   SensorRegistry.list() prints a formatted table of every
            %   registered sensor key and its human-readable name to the
            %   command window.  Keys are sorted alphabetically.
            %
            %   See also SensorRegistry.get.

            map = SensorRegistry.catalog();
            keys = sort(map.keys());
            fprintf('\n  Available sensors:\n');
            for i = 1:numel(keys)
                s = map(keys{i});
                name = s.Name;
                % Fall back to placeholder when no display name was set
                if isempty(name); name = '(no name)'; end
                fprintf('    %-25s  %s\n', keys{i}, name);
            end
            fprintf('\n');
        end
    end

    methods (Static, Access = private)
        function map = catalog()
            %CATALOG Define all sensors here. Cached via persistent variable.
            %   map = SensorRegistry.catalog() returns a containers.Map
            %   whose keys are sensor identifier strings and whose values
            %   are fully configured Sensor objects.  The map is built
            %   once and stored in a persistent variable; subsequent calls
            %   return the cached instance with no overhead.
            %
            %   Output:
            %     map — containers.Map (char -> Sensor)

            persistent cache;
            if isempty(cache)
                cache = containers.Map();

                % === Example sensor definitions ===
                % Edit this section to define your sensors.

                s = Sensor('pressure', 'Name', 'Chamber Pressure', 'ID', 101);
                cache('pressure') = s;

                s = Sensor('temperature', 'Name', 'Chamber Temperature', 'ID', 102);
                cache('temperature') = s;

                % Add more sensors below:
                % s = Sensor('flow', 'Name', 'Gas Flow Rate', 'ID', 103, ...
                %     'MatFile', 'data/flow.mat');
                % s.addThresholdRule(@(st) st.machine == 1, 100, ...
                %     'Direction', 'upper', 'Label', 'Flow HH');
                % cache('flow') = s;
            end
            map = cache;
        end
    end
end
