classdef DataSourceMap < handle
    % DataSourceMap  Maps sensor keys to DataSource instances.

    properties (Access = private)
        map_
    end

    methods
        function obj = DataSourceMap()
            obj.map_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function add(obj, key, dataSource)
            assert(isa(dataSource, 'DataSource'), 'DataSourceMap:invalidType', ...
                'Value must be a DataSource subclass.');
            obj.map_(key) = dataSource;
        end

        function ds = get(obj, key)
            if ~obj.map_.isKey(key)
                error('DataSourceMap:unknownKey', 'No DataSource for key "%s".', key);
            end
            ds = obj.map_(key);
        end

        function k = keys(obj)
            k = obj.map_.keys();
        end

        function tf = has(obj, key)
            tf = obj.map_.isKey(key);
        end

        function remove(obj, key)
            if obj.map_.isKey(key)
                obj.map_.remove(key);
            end
        end
    end
end
