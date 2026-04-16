classdef ThresholdRegistry
    %THRESHOLDREGISTRY Singleton catalog of named Threshold entities.
    %   ThresholdRegistry provides a centralized, persistent catalog of all
    %   known Threshold objects.  It mirrors the SensorRegistry API so the
    %   two registries have a consistent interface.
    %
    %   The catalog starts EMPTY — no predefined entries.  Users add their
    %   own thresholds via ThresholdRegistry.register(key, t) and retrieve
    %   them later via ThresholdRegistry.get(key).
    %
    %   ThresholdRegistry Methods:
    %     get            — Retrieve a Threshold by key; error if missing
    %     getMultiple    — Retrieve several Thresholds at once (cell keys)
    %     register       — Add a Threshold to the catalog
    %     unregister     — Remove a Threshold from the catalog
    %     list           — Print sorted keys + names to command window
    %     printTable     — Print detailed table (Key, Name, Direction, #Conditions, Tags)
    %     viewer         — Open a GUI figure with uitable of the catalog
    %     findByTag      — Return cell of Thresholds that carry a given tag
    %     findByDirection— Return cell of Thresholds with a given direction
    %
    %   Example:
    %     t = Threshold('press_hi', 'Name', 'Pressure High', ...
    %         'Direction', 'upper', 'Tags', {'pressure', 'alarm'});
    %     t.addCondition(struct('machine', 1), 80);
    %     ThresholdRegistry.register('press_hi', t);
    %
    %     got = ThresholdRegistry.get('press_hi');
    %     ThresholdRegistry.list();
    %     ThresholdRegistry.printTable();
    %     results = ThresholdRegistry.findByTag('alarm');
    %
    %   See also Threshold, ThresholdRule, SensorRegistry.

    methods (Static)

        function t = get(key)
            %GET Retrieve a Threshold by key.
            %   t = ThresholdRegistry.get(key) returns the Threshold stored
            %   under key.  Throws 'ThresholdRegistry:unknownKey' if not found.
            %
            %   Input:
            %     key — char, unique identifier
            %
            %   Output:
            %     t — Threshold handle
            %
            %   See also ThresholdRegistry.getMultiple, ThresholdRegistry.list.

            map = ThresholdRegistry.catalog();
            if ~map.isKey(key)
                error('ThresholdRegistry:unknownKey', ...
                    'No threshold defined with key ''%s''. Use ThresholdRegistry.list() to see available keys.', key);
            end
            t = map(key);
        end

        function ts = getMultiple(keys)
            %GETMULTIPLE Retrieve multiple Thresholds by key.
            %   ts = ThresholdRegistry.getMultiple(keys) returns a 1xN cell
            %   array of Threshold handles, one per element of keys.
            %
            %   Input:
            %     keys — cell array of char
            %
            %   Output:
            %     ts — 1xN cell array of Threshold objects
            %
            %   See also ThresholdRegistry.get.

            ts = cell(1, numel(keys));
            for i = 1:numel(keys)
                ts{i} = ThresholdRegistry.get(keys{i});
            end
        end

        function register(key, t)
            %REGISTER Add a Threshold to the catalog.
            %   ThresholdRegistry.register(key, t) stores t under key.
            %   Overwrites any existing entry with the same key.
            %
            %   Inputs:
            %     key — char, unique identifier
            %     t   — Threshold object
            %
            %   See also ThresholdRegistry.unregister.

            m = ThresholdRegistry.catalog();
            m(key) = t;
        end

        function unregister(key)
            %UNREGISTER Remove a Threshold from the catalog.
            %   ThresholdRegistry.unregister(key) removes the entry if it
            %   exists.  No error if the key is not present.
            %
            %   Input:
            %     key — char, identifier to remove
            %
            %   See also ThresholdRegistry.register.

            m = ThresholdRegistry.catalog();
            if m.isKey(key)
                m.remove(key);
            end
        end

        function clear()
            %CLEAR Remove all entries from the catalog.
            %   ThresholdRegistry.clear() empties the entire catalog.
            %   Primarily used in tests to reset state between test runs.
            %
            %   See also ThresholdRegistry.register, ThresholdRegistry.unregister.

            m = ThresholdRegistry.catalog();
            k = m.keys();
            for i = 1:numel(k)
                m.remove(k{i});
            end
        end

        function list()
            %LIST Print all registered threshold keys and names.
            %   ThresholdRegistry.list() prints a formatted list of every
            %   registered threshold key and its human-readable name.
            %   Keys are printed in sorted order.
            %
            %   See also ThresholdRegistry.printTable, ThresholdRegistry.get.

            map = ThresholdRegistry.catalog();
            keys = sort(map.keys());
            fprintf('\n  Available thresholds:\n');
            for i = 1:numel(keys)
                t = map(keys{i});
                name = t.Name;
                if isempty(name); name = '(no name)'; end
                fprintf('    %-25s  %s\n', keys{i}, name);
            end
            fprintf('\n');
        end

        function printTable()
            %PRINTTABLE Print a detailed table of all registered thresholds.
            %   ThresholdRegistry.printTable() prints a formatted table with
            %   columns: Key, Name, Direction, #Conditions, Tags.

            map = ThresholdRegistry.catalog();
            keys = sort(map.keys());
            nThr = numel(keys);

            if nThr == 0
                fprintf('No thresholds registered.\n');
                return;
            end

            % Header
            fprintf('\n');
            fprintf('  %-22s %-25s %-8s  %11s  %s\n', ...
                'Key', 'Name', 'Direction', '#Conditions', 'Tags');
            fprintf('  %s\n', repmat('-', 1, 90));

            % Rows
            for i = 1:nThr
                t = map(keys{i});
                name = t.Name;
                if isempty(name); name = ''; end
                tagStr = '';
                if ~isempty(t.Tags)
                    tagStr = strjoin(t.Tags, ', ');
                end
                nCond = numel(t.conditions_);
                fprintf('  %-22s %-25s %-8s  %11d  %s\n', ...
                    ThresholdRegistry.truncStr(keys{i}, 22), ...
                    ThresholdRegistry.truncStr(name, 25), ...
                    t.Direction, ...
                    nCond, ...
                    tagStr);
            end
            fprintf('\n  %d threshold(s) total.\n\n', nThr);
        end

        function hFig = viewer()
            %VIEWER Open a GUI figure showing all registered thresholds.
            %   hFig = ThresholdRegistry.viewer() creates a figure with a
            %   uitable listing every threshold's Key, Name, Direction,
            %   #Conditions, Units, and Tags.

            map = ThresholdRegistry.catalog();
            keys = sort(map.keys());
            nThr = numel(keys);

            % Build table data
            colNames = {'Key', 'Name', 'Direction', '#Conditions', 'Units', 'Tags'};
            data = cell(nThr, numel(colNames));
            for i = 1:nThr
                t = map(keys{i});
                data{i,1} = keys{i};
                data{i,2} = t.Name;
                data{i,3} = t.Direction;
                data{i,4} = numel(t.conditions_);
                data{i,5} = t.Units;
                tagStr = '';
                if ~isempty(t.Tags)
                    tagStr = strjoin(t.Tags, ', ');
                end
                data{i,6} = tagStr;
            end

            % Create figure
            hFig = figure('Name', 'Threshold Registry', ...
                'NumberTitle', 'off', ...
                'Position', [200 200 860 400], ...
                'Color', [0.15 0.15 0.18], ...
                'MenuBar', 'none', ...
                'ToolBar', 'none');

            % Title label
            uicontrol('Parent', hFig, 'Style', 'text', ...
                'String', sprintf('Threshold Registry  (%d thresholds)', nThr), ...
                'Units', 'normalized', 'Position', [0.02 0.92 0.96 0.06], ...
                'BackgroundColor', [0.15 0.15 0.18], ...
                'ForegroundColor', [0.9 0.9 0.9], ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left');

            % Table
            colWidths = {150, 180, 70, 80, 70, 200};
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

        function ts = findByTag(tag)
            %FINDBYTAG Return all Thresholds carrying the given tag.
            %   ts = ThresholdRegistry.findByTag(tag) iterates the catalog
            %   and returns a cell array of Threshold handles whose Tags
            %   cell contains an entry matching tag.  Returns {} if none.
            %
            %   Input:
            %     tag — char, tag string to search for
            %
            %   Output:
            %     ts — cell array of Threshold handles (may be empty)
            %
            %   See also ThresholdRegistry.findByDirection.

            map = ThresholdRegistry.catalog();
            keys = map.keys();
            ts = {};
            for i = 1:numel(keys)
                t = map(keys{i});
                if ~isempty(t.Tags) && any(strcmp(t.Tags, tag))
                    ts{end+1} = t; %#ok<AGROW>
                end
            end
        end

        function ts = findByDirection(dir)
            %FINDBYDIRECTION Return all Thresholds with the given direction.
            %   ts = ThresholdRegistry.findByDirection(dir) iterates the
            %   catalog and returns a cell array of Threshold handles whose
            %   Direction matches dir ('upper' or 'lower').  Returns {} if none.
            %
            %   Input:
            %     dir — char, 'upper' or 'lower'
            %
            %   Output:
            %     ts — cell array of Threshold handles (may be empty)
            %
            %   See also ThresholdRegistry.findByTag.

            map = ThresholdRegistry.catalog();
            keys = map.keys();
            ts = {};
            for i = 1:numel(keys)
                t = map(keys{i});
                if strcmp(t.Direction, dir)
                    ts{end+1} = t; %#ok<AGROW>
                end
            end
        end

    end

    methods (Static, Access = private)

        function s = truncStr(s, maxLen)
            %TRUNCSTR Truncate string to maxLen with trailing '..'.
            if numel(s) > maxLen
                s = [s(1:maxLen-2), '..'];
            end
        end

        function map = catalog()
            %CATALOG Return the persistent containers.Map catalog.
            %   catalog() returns the singleton containers.Map that stores
            %   all registered Threshold objects.  The map is created empty
            %   on first call and cached in a persistent variable thereafter.
            %
            %   Output:
            %     map — containers.Map (char -> Threshold)

            persistent cache;
            if isempty(cache)
                cache = containers.Map();
                % Catalog starts EMPTY — no predefined entries.
                % Users add thresholds via ThresholdRegistry.register().
            end
            map = cache;
        end

    end
end
