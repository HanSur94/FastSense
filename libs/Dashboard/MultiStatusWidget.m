classdef MultiStatusWidget < DashboardWidget
    properties (Access = public)
        Sensors    = {}         % Cell array of Sensor objects
        Columns    = []         % Grid columns (empty = auto)
        ShowLabels = true
        IconStyle  = 'dot'      % 'dot', 'square', 'icon'
    end

    properties (SetAccess = private)
        hAxes = []
    end

    methods
        function obj = MultiStatusWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 8 3];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            % Re-layout on resize so pixel-scaled fonts/geometry stay correct.
            try obj.hPanel.SizeChangedFcn = @(~,~) obj.relayout_(); catch, end
            theme = obj.getTheme();
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.96 0.96], ...
                'Visible', 'off', ...
                'XLim', [0 1], 'YLim', [0 1]);
            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            % Expand CompositeThreshold items into child dots + summary row (per D-08)
            expandedItems = obj.expandSensors_();
            n = numel(expandedItems);
            if n == 0, return; end

            cols = obj.Columns;
            if isempty(cols)
                cols = ceil(sqrt(n));
            end
            rows = ceil(n / cols);

            cla(obj.hAxes);
            hold(obj.hAxes, 'on');

            theme = obj.getTheme();
            okColor = theme.StatusOkColor;
            warnColor = theme.StatusWarnColor;
            alarmColor = theme.StatusAlarmColor;

            % Compute aspect ratio correction for circles
            oldUnits = get(obj.hPanel, 'Units');
            set(obj.hPanel, 'Units', 'pixels');
            pxPos = get(obj.hPanel, 'Position');
            set(obj.hPanel, 'Units', oldUnits);
            pxW = pxPos(3);
            pxH = pxPos(4);

            for i = 1:n
                col = mod(i-1, cols);
                row = floor((i-1) / cols);

                cx = (col + 0.5) / cols;
                cy = 1 - (row + 0.5) / rows;

                item = expandedItems{i};

                % Draw indicator — aspect-ratio-corrected so circles stay round
                ry = 0.3 / max(cols, rows);
                if pxW > 0 && pxH > 0
                    rx = ry * (pxH / pxW);
                else
                    rx = ry;
                end

                if isstruct(item)
                    % Tag-first dispatch (v2.0 Tag API) — falls through to legacy
                    % threshold path when .tag is absent (Pitfall 5 preserved).
                    if isfield(item, 'tag') && ~isempty(item.tag)
                        color = obj.deriveColorFromTag_(item, okColor, theme);
                    elseif isfield(item, 'threshold')
                        color = obj.deriveColorFromThreshold(item, okColor, theme);
                    else
                        color = okColor;
                    end
                    if strcmp(obj.IconStyle, 'square')
                        rectangle(obj.hAxes, 'Position', [cx-rx cy-ry 2*rx 2*ry], ...
                            'FaceColor', color, 'EdgeColor', 'none');
                    else
                        theta = linspace(0, 2*pi, 30);
                        fill(obj.hAxes, cx + rx*cos(theta), cy + ry*sin(theta), ...
                            color, 'EdgeColor', 'none');
                    end
                    if obj.ShowLabels && isfield(item, 'label')
                        text(obj.hAxes, cx, cy - ry - 0.02, item.label, ...
                            'HorizontalAlignment', 'center', ...
                            'FontSize', 8, ...
                            'Color', theme.AxisColor);
                    end
                else
                    % Sensor object item
                    color = obj.deriveColor(item, okColor);
                    if strcmp(obj.IconStyle, 'square')
                        rectangle(obj.hAxes, 'Position', [cx-rx cy-ry 2*rx 2*ry], ...
                            'FaceColor', color, 'EdgeColor', 'none');
                    else
                        theta = linspace(0, 2*pi, 30);
                        fill(obj.hAxes, cx + rx*cos(theta), cy + ry*sin(theta), ...
                            color, 'EdgeColor', 'none');
                    end
                    if obj.ShowLabels && ~isempty(item)
                        name = item.Name;
                        if isempty(name), name = item.Key; end
                        text(obj.hAxes, cx, cy - ry - 0.02, name, ...
                            'HorizontalAlignment', 'center', ...
                            'FontSize', 8, ...
                            'Color', theme.AxisColor);
                    end
                end
            end
            hold(obj.hAxes, 'off');
        end

        function t = getType(~)
            t = 'multistatus';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                n = numel(obj.Sensors);
                if n > 0
                    nOk = 0;
                    for k = 1:n
                        s = obj.Sensors{k};
                        % Threshold-binding struct items count as ok (no live data yet)
                        if isstruct(s)
                            nOk = nOk + 1;
                            continue;
                        end
                        if isempty(s) || isempty(s.Y) || isempty(s.Thresholds)
                            nOk = nOk + 1;
                            continue;
                        end
                        val = s.Y(end);
                        violated = false;
                        for r = 1:numel(s.Thresholds)
                            t = s.Thresholds{r};
                            tVals = t.allValues();
                            for v = 1:numel(tVals)
                                if (t.IsUpper && val > tVals(v)) || ...
                                        (~t.IsUpper && val < tVals(v))
                                    violated = true;
                                    break;
                                end
                            end
                            if violated, break; end
                        end
                        if ~violated
                            nOk = nOk + 1;
                        end
                    end
                    info = sprintf('%d sensors: %d OK, %d alert', n, nOk, n - nOk);
                else
                    info = '[-- multistatus --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end

        function s = toStruct(obj)
            % Fully override — does not use base Sensor property
            s = struct();
            s.type = 'multistatus';
            s.title = obj.Title;
            s.description = obj.Description;
            s.position = struct('col', obj.Position(1), 'row', obj.Position(2), ...
                'width', obj.Position(3), 'height', obj.Position(4));
            if ~isempty(fieldnames(obj.ThemeOverride))
                s.themeOverride = obj.ThemeOverride;
            end
            s.columns = obj.Columns;
            s.showLabels = obj.ShowLabels;
            s.iconStyle = obj.IconStyle;
            % Serialize items (mixed Sensor + threshold-binding structs)
            items = cell(1, numel(obj.Sensors));
            for i = 1:numel(obj.Sensors)
                item = obj.Sensors{i};
                if isstruct(item) && isfield(item, 'tag') && ~isempty(item.tag)
                    entry = struct('type', 'tag');
                    if isfield(item, 'label'), entry.label = item.label; end
                    t = item.tag;
                    if ischar(t) || isstring(t)
                        entry.key = char(t);
                    elseif isa(t, 'Tag')
                        entry.key = t.Key;
                    end
                    items{i} = entry;
                elseif isstruct(item)
                    entry = struct('type', 'threshold');
                    if isfield(item, 'label'), entry.label = item.label; end
                    if isfield(item, 'threshold') && ~isempty(item.threshold)
                        t = item.threshold;
                        if ischar(t) || isstring(t)
                            entry.key = t;
                        elseif isprop(t, 'Key')
                            entry.key = t.Key;
                        end
                    end
                    if isfield(item, 'value'), entry.value = item.value; end
                    items{i} = entry;
                else
                    items{i} = struct('type', 'sensor', 'key', item.Key);
                end
            end
            s.items = items;
        end
    end

    methods (Access = private)
        function relayout_(obj)
        %RELAYOUT_ Rebuild pixel-scaled elements on panel resize.
            if isempty(obj.hPanel) || ~ishandle(obj.hPanel), return; end
            try DashboardWidget.clearPanelControls(obj.hPanel); catch, end
            try delete(findobj(obj.hPanel, '-depth', 1, 'Type', 'axes')); catch, end
            obj.render(obj.hPanel);
        end

        function expandedItems = expandSensors_(obj)
        %EXPANDSENSORS_ Expand CompositeThreshold/CompositeTag items into children + summary.
        %   Non-composite items pass through unchanged.
        %
        %   Documented Pitfall 1 exception: `isa(item.tag, 'CompositeTag')`
        %   below is a SHAPE-recursion check parallel to the existing
        %   CompositeThreshold branch — it asks "is this an aggregator that
        %   needs child expansion?", not "dispatch based on kind". Value
        %   dispatch always goes through polymorphic valueAt/getXY.
            expandedItems = {};
            for i = 1:numel(obj.Sensors)
                item = obj.Sensors{i};
                if isstruct(item) && isfield(item, 'tag') && ~isempty(item.tag) && ...
                        isa(item.tag, 'CompositeTag')
                    ct = item.tag;
                    for c = 1:ct.getChildCount()
                        childTag = ct.getChildAt(c);
                        childItem = struct('tag', childTag);
                        if ~isempty(childTag.Name)
                            childItem.label = childTag.Name;
                        else
                            childItem.label = childTag.Key;
                        end
                        expandedItems{end+1} = childItem; %#ok<AGROW>
                    end
                    summaryLabel = '';
                    if isfield(item, 'label') && ~isempty(item.label)
                        summaryLabel = item.label;
                    elseif ~isempty(ct.Name)
                        summaryLabel = ct.Name;
                    else
                        summaryLabel = ct.Key;
                    end
                    expandedItems{end+1} = struct('tag', ct, ...
                        'label', summaryLabel, ...
                        'isCompositeSummary', true); %#ok<AGROW>
                elseif isstruct(item) && isfield(item, 'threshold') && ...
                        isa(item.threshold, 'CompositeThreshold')
                    ct = item.threshold;
                    children = ct.getChildren();
                    for c = 1:numel(children)
                        entry = children{c};
                        childItem = struct('threshold', entry.threshold, ...
                            'valueFcn', entry.valueFcn, 'value', entry.value);
                        % Derive child label from Name or Key
                        if isprop(entry.threshold, 'Name') && ~isempty(entry.threshold.Name)
                            childItem.label = entry.threshold.Name;
                        else
                            childItem.label = entry.threshold.Key;
                        end
                        expandedItems{end+1} = childItem; %#ok<AGROW>
                    end
                    % Add summary row for the composite itself
                    summaryLabel = '';
                    if isfield(item, 'label') && ~isempty(item.label)
                        summaryLabel = item.label;
                    elseif isprop(ct, 'Name') && ~isempty(ct.Name)
                        summaryLabel = ct.Name;
                    else
                        summaryLabel = ct.Key;
                    end
                    summaryItem = struct('threshold', ct, ...
                        'valueFcn', [], 'value', [], 'label', summaryLabel, ...
                        'isCompositeSummary', true);
                    expandedItems{end+1} = summaryItem; %#ok<AGROW>
                else
                    expandedItems{end+1} = item; %#ok<AGROW>
                end
            end
        end

        function color = deriveColorFromTag_(~, item, defaultColor, theme)
        %DERIVECOLORFROMTAG_ Derive color from a Tag-bound item (v2.0 Tag API).
        %   item.tag may be a Tag handle OR a string key resolved via
        %   TagRegistry. CompositeTag goes through valueAt(now) fast path
        %   (COMPOSITE-06); monitor-kind output maps 0->default, 1->alarm.
        %   Dispatch is polymorphic — no isa-on-subclass-name switches
        %   (Pitfall 1 invariant).
            color = defaultColor;
            t = item.tag;
            if ischar(t) || isstring(t)
                try t = TagRegistry.get(char(t)); catch, return; end
            end
            if ~isa(t, 'Tag'), return; end
            try
                v = t.valueAt(now);
            catch
                return;
            end
            if isempty(v) || any(isnan(v)), return; end
            if v >= 0.5
                color = theme.StatusAlarmColor;
            else
                color = defaultColor;
            end
        end

        function color = deriveColorFromThreshold(~, item, defaultColor, theme)
        %DERIVECOLORFROMTHRESHOLD Derive color from a threshold-binding struct item.
            color = defaultColor;
            if ~isfield(item, 'threshold') || isempty(item.threshold), return; end
            t = item.threshold;
            % Resolve string key if needed
            if ischar(t) || isstring(t)
                try
                    t = TagRegistry.get(t);
                catch
                    return;
                end
            end
            % CompositeThreshold: derive color from computeStatus (per D-04)
            if isa(t, 'CompositeThreshold')
                cStatus = t.computeStatus();
                switch cStatus
                    case 'ok',    color = defaultColor;
                    case 'alarm', color = theme.StatusAlarmColor;
                    otherwise,    color = theme.StatusWarnColor;
                end
                return;
            end
            % Get value
            val = [];
            if isfield(item, 'valueFcn') && ~isempty(item.valueFcn)
                try val = item.valueFcn(); catch, return; end
            elseif isfield(item, 'value')
                val = item.value;
            end
            if isempty(val), return; end
            % Check violation
            tVals = t.allValues();
            for v = 1:numel(tVals)
                if (t.IsUpper && val >= tVals(v)) || (~t.IsUpper && val <= tVals(v))
                    if ~isempty(t.Color)
                        color = t.Color;
                    else
                        color = theme.StatusAlarmColor;
                    end
                    return;
                end
            end
        end

        function color = deriveColor(obj, sensor, defaultColor)
            %DERIVECOLOR Derive cell color for a bare (non-struct) Sensors entry.
            %   Two branches by item type:
            %     - Tag handle (SensorTag/MonitorTag/CompositeTag): dispatch
            %       through sensor.valueAt(now); value >= 0.5 -> alarm color
            %       (mirrors deriveColorFromTag_ for struct-wrapped items).
            %     - Legacy Sensor handle (.Y + .Thresholds cell): original
            %       threshold-walk (byte-for-byte preserved for backward compat).
            %   Gap closure for 1015-UAT Test 1: MonitorTag has no .Y property,
            %   so the legacy branch threw. See 1015-04-PLAN.md.
            color = defaultColor;
            if isempty(sensor)
                return;
            end
            if isa(sensor, 'Tag')
                try
                    theme = obj.getTheme();
                    v = sensor.valueAt(now);
                    if ~isempty(v) && isnumeric(v) && ~any(isnan(v)) && v(1) >= 0.5
                        color = theme.StatusAlarmColor;
                    end
                catch
                    % Defensive: any Tag-side failure falls through to default.
                end
                return;
            end
            % Legacy Sensor path (pre-Phase-1011 Sensor objects and any other
            % non-Tag duck-typed handle exposing .Y + .Thresholds).
            if isempty(sensor.Y)
                return;
            end
            val = sensor.Y(end);
            if isempty(sensor.Thresholds)
                return;
            end
            for k = 1:numel(sensor.Thresholds)
                t = sensor.Thresholds{k};
                if isempty(t.Color), continue; end
                tVals = t.allValues();
                for v = 1:numel(tVals)
                    if t.IsUpper && val >= tVals(v)
                        color = t.Color;
                    elseif ~t.IsUpper && val <= tVals(v)
                        color = t.Color;
                    end
                end
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = MultiStatusWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'columns'), obj.Columns = s.columns; end
            if isfield(s, 'showLabels'), obj.ShowLabels = s.showLabels; end
            if isfield(s, 'iconStyle'), obj.IconStyle = s.iconStyle; end
            % Restore items (mixed sensor + threshold-binding structs)
            if isfield(s, 'items')
                rawItems = s.items;
                if isstruct(rawItems)
                    nC = numel(rawItems);
                    tmp = cell(1, nC);
                    for i = 1:nC
                        tmp{i} = rawItems(i);
                    end
                    rawItems = tmp;
                end
                nIt = numel(rawItems);
                entries = cell(1, nIt);
                for i = 1:nIt
                    it = rawItems{i};
                    if isstruct(it) && isfield(it, 'type')
                        switch it.type
                            case 'tag'
                                entry = struct('label', '');
                                if isfield(it, 'label'), entry.label = it.label; end
                                if isfield(it, 'key') && exist('TagRegistry', 'class')
                                    try
                                        entry.tag = TagRegistry.get(it.key);
                                    catch
                                        warning('MultiStatusWidget:tagNotFound', ...
                                            'Could not resolve Tag key ''%s'' on load.', it.key);
                                    end
                                end
                                entries{i} = entry;
                            case 'threshold'
                                entry = struct('label', '');
                                if isfield(it, 'label'), entry.label = it.label; end
                                if isfield(it, 'key') && exist('TagRegistry', 'class')
                                    try
                                        entry.threshold = TagRegistry.get(it.key);
                                    catch
                                    end
                                end
                                if isfield(it, 'value'), entry.value = it.value; end
                                entries{i} = entry;
                            case 'sensor'
                                if isfield(it, 'key') && exist('TagRegistry', 'class')
                                    try
                                        entries{i} = TagRegistry.get(it.key);
                                    catch
                                    end
                                end
                        end
                    end
                end
                obj.Sensors = entries;
            end
            % Sensor resolution via resolver in configToWidgets (legacy s.sensors field)
        end
    end
end
