classdef ChipBarWidget < DashboardWidget
%CHIPBARWIDGET Horizontal row of mini status chips for system health summary.
%
%   Displays N colored circle icons with labels in a compact horizontal strip.
%   Designed as a dense multi-sensor status overview at a glance.
%
%   Usage:
%     w = ChipBarWidget('Title', 'System Health');
%     w.Chips = {
%         struct('label', 'Pump',  'statusFcn', @() 'ok'),
%         struct('label', 'Tank',  'statusFcn', @() 'warn'),
%         struct('label', 'Fan',   'statusFcn', @() 'alarm')
%     };
%     d.addWidget(w);
%
%   Each chip struct may contain:
%     label      — string displayed below the chip circle (required)
%     sensor     — Sensor object for auto state color (optional)
%     statusFcn  — @() returning 'ok'|'warn'|'alarm'|'info'|'inactive' (optional)
%     iconColor  — [r g b] override, skips state resolution (optional)
%
%   Properties:
%     Chips       — cell array of chip structs
%     hChipCircles — fill handles for chip circles (read-only after render)
%
%   Methods:
%     render(parentPanel) — draw chips in a single shared axes
%     refresh()           — update chip colors from statusFcn/sensor state
%     getType()           — returns 'chipbar'
%     toStruct()          — serializes to struct with type='chipbar'
%     fromStruct(s)       — static; reconstruct from saved struct
%
%   See also DashboardWidget, StatusWidget, MultiStatusWidget.

    properties (Access = public)
        Chips = {}          % Cell array of chip structs (label, statusFcn, sensor, iconColor)
    end

    properties (SetAccess = private)
        hAx          = []   % Single shared axes for all chips
        hChipCircles = {}   % Cell array of fill handles, one per chip
        hChipLabels  = {}   % Cell array of text handles, one per chip
    end

    methods
        function obj = ChipBarWidget(varargin)
        %CHIPBARWIDGET Construct a ChipBarWidget with optional name-value pairs.
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 12 1];
            end
        end

        function render(obj, parentPanel)
        %RENDER Draw all chips in a single shared axes inside parentPanel.
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            nChips = numel(obj.Chips);
            if nChips == 0
                return;
            end

            % Measure panel height in pixels for adaptive font size
            oldUnits = get(parentPanel, 'Units');
            set(parentPanel, 'Units', 'pixels');
            pxPos = get(parentPanel, 'Position');
            set(parentPanel, 'Units', oldUnits);
            pxH = pxPos(4);

            % Single axes spanning full panel
            obj.hAx = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1], ...
                'Visible', 'off', ...
                'HitTest', 'off', ...
                'XLim', [0 nChips], ...
                'YLim', [0 1]);
            try set(obj.hAx, 'PickableParts', 'none'); catch, end
            try disableDefaultInteractivity(obj.hAx); catch, end
            hold(obj.hAx, 'on');

            % Compute aspect ratio correction so circles don't stretch
            % Axes spans [0, nChips] x [0, 1] but panel is wider than tall,
            % so x-radius must be shrunk relative to y-radius.
            pxW = pxPos(3);
            ry = 0.22;  % radius in y-axis units
            if pxW > 0 && pxH > 0
                rx = ry * (pxH / pxW) * nChips;  % scale x-radius by panel aspect
            else
                rx = ry;
            end
            theta = linspace(0, 2*pi, 60);
            chipFontSz = max(6, min(9, round(pxH * 0.18)));

            obj.hChipCircles = cell(1, nChips);
            obj.hChipLabels  = cell(1, nChips);

            for i = 1:nChips
                chip = obj.Chips{i};
                xc = i - 0.5;
                chipColor = obj.resolveChipColor(chip, theme);

                obj.hChipCircles{i} = fill(obj.hAx, ...
                    xc + rx * cos(theta), ...
                    0.60 + ry * sin(theta), ...
                    chipColor, 'EdgeColor', 'none', 'HitTest', 'off');

                if isfield(chip, 'label')
                    chipLabel = chip.label;
                else
                    chipLabel = '';
                end

                obj.hChipLabels{i} = text(obj.hAx, xc, 0.18, chipLabel, ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', chipFontSz, ...
                    'Color', theme.ForegroundColor, ...
                    'HitTest', 'off');
            end

            obj.refresh();
        end

        function refresh(obj)
        %REFRESH Update chip circle colors from statusFcn or sensor state.
            if isempty(obj.hPanel) || ~ishandle(obj.hPanel)
                return;
            end
            if isempty(obj.hChipCircles)
                return;
            end

            theme = obj.getTheme();

            for i = 1:numel(obj.Chips)
                chip = obj.Chips{i};
                chipColor = obj.resolveChipColor(chip, theme);

                if i <= numel(obj.hChipCircles) && ...
                        ~isempty(obj.hChipCircles{i}) && ...
                        ishandle(obj.hChipCircles{i})
                    set(obj.hChipCircles{i}, 'FaceColor', chipColor);
                end
            end
        end

        function t = getType(~)
        %GETTYPE Return widget type string.
            t = 'chipbar';
        end

        function s = toStruct(obj)
        %TOSTRUCT Serialize widget to struct for JSON export.
            s = toStruct@DashboardWidget(obj);
            nChips = numel(obj.Chips);
            s.chips = cell(1, nChips);
            for i = 1:nChips
                chip = obj.Chips{i};
                entry = struct('label', '');
                if isfield(chip, 'label')
                    entry.label = chip.label;
                end
                if isfield(chip, 'iconColor') && isnumeric(chip.iconColor)
                    entry.iconColor = chip.iconColor;
                end
                if isfield(chip, 'threshold') && ~isempty(chip.threshold)
                    t = chip.threshold;
                    if ischar(t) || isstring(t)
                        entry.threshold = t;
                    elseif isprop(t, 'Key')
                        entry.threshold = t.Key;
                    end
                end
                if isfield(chip, 'value')
                    entry.value = chip.value;
                end
                % Note: statusFcn and sensor cannot be serialized as function handles
                s.chips{i} = entry;
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
        %FROMSTRUCT Reconstruct ChipBarWidget from a saved struct.
            obj = ChipBarWidget();
            if isfield(s, 'title'),       obj.Title       = s.title;       end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                                s.position.width, s.position.height];
            end
            if isfield(s, 'chips')
                chips = s.chips;
                % normalise: jsondecode may return struct array or cell array
                if isstruct(chips)
                    nC = numel(chips);
                    chipCell = cell(1, nC);
                    for i = 1:nC
                        chipCell{i} = chips(i);
                    end
                    chips = chipCell;
                end
                obj.Chips = chips;
                % Resolve threshold keys in chips
                for i = 1:numel(obj.Chips)
                    chip = obj.Chips{i};
                    if isstruct(chip) && isfield(chip, 'threshold') && ...
                            (ischar(chip.threshold) || isstring(chip.threshold))
                        if exist('ThresholdRegistry', 'class')
                            try
                                chip.threshold = ThresholdRegistry.get(chip.threshold);
                                obj.Chips{i} = chip;
                            catch
                                warning('ChipBarWidget:thresholdNotFound', ...
                                    'Threshold key ''%s'' not found.', chip.threshold);
                            end
                        end
                    end
                end
            end
        end
    end

    methods (Access = private)
        function chipColor = resolveChipColor(~, chip, theme)
        %RESOLVECHIPCOLOR Map chip struct to an [r g b] color triple.
        %
        %   Priority:
        %     1. chip.iconColor (numeric [r g b] explicit override)
        %     2. chip.statusFcn() -> state string -> theme color
        %     3. chip.sensor -> derive state -> theme color
        %     4. default gray [0.5 0.5 0.5]

            % Explicit color override
            if isfield(chip, 'iconColor') && isnumeric(chip.iconColor) && ...
                    numel(chip.iconColor) == 3
                chipColor = chip.iconColor;
                return;
            end

            % Resolve state string
            state = 'inactive';
            if isfield(chip, 'threshold') && ~isempty(chip.threshold)
                % Threshold-based chip color
                t = chip.threshold;
                if ischar(t) || isstring(t)
                    try t = ThresholdRegistry.get(t); catch, chipColor = [0.5 0.5 0.5]; return; end
                end
                val = [];
                if isfield(chip, 'valueFcn') && ~isempty(chip.valueFcn)
                    try val = chip.valueFcn(); catch, end
                elseif isfield(chip, 'value')
                    val = chip.value;
                end
                if isempty(val), chipColor = [0.5 0.5 0.5]; return; end
                tVals = t.allValues();
                state = 'ok';
                for v = 1:numel(tVals)
                    if (t.IsUpper && val > tVals(v)) || (~t.IsUpper && val < tVals(v))
                        state = 'alarm'; break;
                    end
                end
            elseif isfield(chip, 'statusFcn') && ~isempty(chip.statusFcn)
                try
                    state = chip.statusFcn();
                catch
                    state = 'inactive';
                end
            elseif isfield(chip, 'sensor') && ~isempty(chip.sensor)
                sensor = chip.sensor;
                if ~isempty(sensor.Y) && ~isempty(sensor.Thresholds)
                    latestY = sensor.Y(end);
                    state = 'ok';
                    for k = 1:numel(sensor.Thresholds)
                        t = sensor.Thresholds{k};
                        tVals = t.allValues();
                        for v = 1:numel(tVals)
                            if (t.IsUpper && latestY > tVals(v)) || ...
                                    (~t.IsUpper && latestY < tVals(v))
                                state = 'alarm';
                                break;
                            end
                        end
                        if strcmp(state, 'alarm'), break; end
                    end
                else
                    state = 'ok';
                end
            end

            % Map state to theme color
            switch state
                case 'ok'
                    chipColor = theme.StatusOkColor;
                case {'warn', 'warning'}
                    chipColor = theme.StatusWarnColor;
                case 'alarm'
                    chipColor = theme.StatusAlarmColor;
                case 'info'
                    chipColor = theme.InfoColor;
                otherwise
                    chipColor = [0.5 0.5 0.5];
            end
        end
    end
end
