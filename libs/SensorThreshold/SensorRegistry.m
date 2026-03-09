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

        function printTable()
            %PRINTTABLE Print a detailed table of all registered sensors.
            %   SensorRegistry.printTable() prints a formatted table with
            %   columns: Key, Name, ID, Source, MatFile, #States, #Rules, #Points.

            map = SensorRegistry.catalog();
            keys = sort(map.keys());
            nSensors = numel(keys);

            if nSensors == 0
                fprintf('No sensors registered.\n');
                return;
            end

            % Header
            fprintf('\n');
            fprintf('  %-20s %-25s %6s  %-20s %-20s %7s %6s %8s\n', ...
                'Key', 'Name', 'ID', 'Source', 'MatFile', '#States', '#Rules', '#Points');
            fprintf('  %s\n', repmat('-', 1, 118));

            % Rows
            for i = 1:nSensors
                s = map(keys{i});
                name = s.Name;
                if isempty(name); name = ''; end

                idStr = '';
                if ~isempty(s.ID); idStr = num2str(s.ID); end

                nStates = numel(s.StateChannels);
                nRules  = numel(s.ThresholdRules);
                nPts    = numel(s.X);

                fprintf('  %-20s %-25s %6s  %-20s %-20s %7d %6d %8d\n', ...
                    SensorRegistry.truncStr(keys{i}, 20), ...
                    SensorRegistry.truncStr(name, 25), ...
                    idStr, ...
                    SensorRegistry.truncStr(s.Source, 20), ...
                    SensorRegistry.truncStr(s.MatFile, 20), ...
                    nStates, nRules, nPts);
            end
            fprintf('\n  %d sensor(s) total.\n\n', nSensors);
        end

        function hFig = viewer()
            %VIEWER Open a GUI figure showing all registered sensors.
            %   hFig = SensorRegistry.viewer() creates a figure with a
            %   uitable listing every sensor's Key, Name, ID, Source,
            %   MatFile, #States, #Rules, and #Points.

            map = SensorRegistry.catalog();
            keys = sort(map.keys());
            nSensors = numel(keys);

            % Build table data
            colNames = {'Key', 'Name', 'ID', 'Source', 'MatFile', '#States', '#Rules', '#Points'};
            data = cell(nSensors, numel(colNames));
            for i = 1:nSensors
                s = map(keys{i});
                data{i,1} = keys{i};
                data{i,2} = s.Name;
                if isempty(s.ID)
                    data{i,3} = '';
                else
                    data{i,3} = s.ID;
                end
                data{i,4} = s.Source;
                data{i,5} = s.MatFile;
                data{i,6} = numel(s.StateChannels);
                data{i,7} = numel(s.ThresholdRules);
                data{i,8} = numel(s.X);
            end

            % Create figure
            hFig = figure('Name', 'Sensor Registry', ...
                'NumberTitle', 'off', ...
                'Position', [200 200 900 400], ...
                'Color', [0.15 0.15 0.18], ...
                'MenuBar', 'none', ...
                'ToolBar', 'none');

            % Title label
            uicontrol('Parent', hFig, 'Style', 'text', ...
                'String', sprintf('Sensor Registry  (%d sensors)', nSensors), ...
                'Units', 'normalized', 'Position', [0.02 0.92 0.96 0.06], ...
                'BackgroundColor', [0.15 0.15 0.18], ...
                'ForegroundColor', [0.9 0.9 0.9], ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left');

            % Table
            colWidths = {140, 180, 50, 140, 140, 55, 50, 60};
            uitable('Parent', hFig, ...
                'Data', data, ...
                'ColumnName', colNames, ...
                'ColumnWidth', colWidths, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.96 0.88], ...
                'RowName', [], ...
                'BackgroundColor', [0.22 0.22 0.25; 0.18 0.18 0.21], ...
                'ForegroundColor', [0.9 0.9 0.9], ...
                'FontSize', 11);
        end
    end

    methods (Static, Access = private)
        function s = truncStr(s, maxLen)
            if numel(s) > maxLen
                s = [s(1:maxLen-2), '..'];
            end
        end

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
