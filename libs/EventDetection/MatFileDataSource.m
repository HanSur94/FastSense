classdef MatFileDataSource < DataSource
    % MatFileDataSource  Reads sensor data from a continuously-updated .mat file.

    properties
        FilePath     = ''
        XVar         = 'X'
        YVar         = 'Y'
        StateXVar    = ''
        StateYVar    = ''
    end

    properties (Access = private)
        lastModTime_  = 0
        lastIndex_    = 0
        lastStateIdx_ = 0
    end

    methods
        function obj = MatFileDataSource(filePath, varargin)
            p = inputParser();
            p.addRequired('filePath', @ischar);
            p.addParameter('XVar', 'X', @ischar);
            p.addParameter('YVar', 'Y', @ischar);
            p.addParameter('StateXVar', '', @ischar);
            p.addParameter('StateYVar', '', @ischar);
            p.parse(filePath, varargin{:});
            obj.FilePath  = p.Results.filePath;
            obj.XVar      = p.Results.XVar;
            obj.YVar      = p.Results.YVar;
            obj.StateXVar = p.Results.StateXVar;
            obj.StateYVar = p.Results.StateYVar;
        end

        function result = fetchNew(obj)
            result = DataSource.emptyResult();

            if ~isfile(obj.FilePath)
                return;
            end

            info = dir(obj.FilePath);
            modTime = info.datenum;

            if modTime <= obj.lastModTime_
                return;
            end
            obj.lastModTime_ = modTime;

            data = load(obj.FilePath);

            if ~isfield(data, obj.XVar) || ~isfield(data, obj.YVar)
                return;
            end

            allX = data.(obj.XVar);
            allY = data.(obj.YVar);

            if obj.lastIndex_ >= numel(allX)
                return;
            end

            newIdx = (obj.lastIndex_ + 1):numel(allX);
            result.X = allX(newIdx);
            result.Y = allY(newIdx);
            result.changed = true;
            obj.lastIndex_ = numel(allX);

            % State data
            if ~isempty(obj.StateXVar) && isfield(data, obj.StateXVar)
                allStateX = data.(obj.StateXVar);
                allStateY = data.(obj.StateYVar);
                if obj.lastStateIdx_ < numel(allStateX)
                    sIdx = (obj.lastStateIdx_ + 1):numel(allStateX);
                    result.stateX = allStateX(sIdx);
                    result.stateY = allStateY(sIdx);
                    obj.lastStateIdx_ = numel(allStateX);
                end
            end
        end
    end
end
