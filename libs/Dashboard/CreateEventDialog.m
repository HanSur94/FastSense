classdef CreateEventDialog < handle
%CREATEEVENTDIALOG Modal dialog to create a manual annotation Event (260513-snt).
%
%   d = CreateEventDialog(fastSenseWidget, dashboardEngine)
%
%   Opens a modal figure pre-filled with the widget's current X view as
%   the event time range and the widget's bound Tag.Key as the tag
%   binding. On Save: appends an Event to engine.EventStore, registers
%   per-tag EventBinding entries, calls EventStore.save() and finally
%   engine.notifyEventsChanged() so EventTimelineWidget +
%   FastSenseWidget instances and the slider's event-marker overlay
%   refresh.
%
%   The dialog mirrors DashboardConfigDialog's pattern: classical
%   figure (NOT uifigure) with WindowStyle='modal', styled from the
%   engine's theme. All UI callbacks are wrapped in try/catch with
%   non-blocking errordlg so a bad input never tears down the dialog.
%
%   Properties (SetAccess = private):
%     Widget   - bound FastSenseWidget
%     Engine   - bound DashboardEngine
%     hFigure  - modal figure handle
%
%   Methods (public):
%     onSave   - validate, persist, notify, close dialog on success
%     onCancel - close dialog without writing
%     delete   - destructor, tears down figure
%
%   Methods (Static, public):
%     persistEventStatic(engine, tStart, tEnd, label, sev, cat, notes,
%                        keys, primaryName) - mock-friendly persistence
%       seam used by Task-3 tests; instance persistEvent_ delegates here.
%
%   Errors raised (all namespaced):
%     CreateEventDialog:invalidWidget    - widget is not a FastSenseWidget
%     CreateEventDialog:invalidEngine    - engine is not a DashboardEngine
%     CreateEventDialog:noStore          - engine.EventStore is empty
%     CreateEventDialog:invalidTimeRange - EndTime < StartTime (or
%                                          not finite)
%     CreateEventDialog:emptyLabel       - Label is empty after trim
%
%   See also DashboardEngine, FastSenseWidget, EventStore, EventBinding,
%            Event, Tag.addManualEvent.
%
%   NOTE (260513-v69 - supersedes 260513-snt's trigger):
%     The "+" button on FastSenseWidget no longer triggers this dialog
%     directly. Clicking "+" now enters a two-click pick-on-chart mode
%     on the widget's FastSense axes (see FastSense.startEventPick_).
%     The pick flow constructs the Event programmatically and hands off
%     to FastSense.openEventDetails_ for Notes editing. This dialog
%     remains available as a programmatic API:
%         CreateEventDialog(widget, engine)
%     and CreateEventDialog.persistEventStatic remains the single source
%     of truth for "persist a manual Event into the engine's EventStore";
%     FastSense.completeEventPick_ calls it.

    properties (SetAccess = private)
        Widget    = []
        Engine    = []
        hFigure   = []
        % Cached uicontrol handles populated by buildUI for onSave to read.
        hStartEdit  = []
        hEndEdit    = []
        hLabelEdit  = []
        hSevPopup   = []
        hCatPopup   = []
        hNotesEdit  = []
        hKeysEdit   = []
    end

    properties (Constant, Access = private)
        SEVERITY_LABELS = {'1 - info / ok', '2 - warn', '3 - alarm'}
        CATEGORY_LABELS = {'manual_annotation', 'alarm', 'maintenance', 'process_change'}
    end

    methods
        function obj = CreateEventDialog(widget, engine)
            %CREATEEVENTDIALOG Construct + show modal dialog.
            if ~isa(widget, 'FastSenseWidget')
                error('CreateEventDialog:invalidWidget', ...
                    'widget must be a FastSenseWidget; got %s.', class(widget));
            end
            if ~isa(engine, 'DashboardEngine')
                error('CreateEventDialog:invalidEngine', ...
                    'engine must be a DashboardEngine; got %s.', class(engine));
            end
            if isempty(engine.EventStore)
                error('CreateEventDialog:noStore', ...
                    'engine.EventStore is empty; cannot persist event.');
            end
            obj.Widget = widget;
            obj.Engine = engine;
            obj.buildUI();
        end

        function delete(obj)
            %DELETE Tear down the modal figure if still alive.
            try
                if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                    delete(obj.hFigure);
                end
            catch
                % best-effort teardown
            end
            obj.hFigure = [];
        end

        function onSave(obj, ~, ~)
            %ONSAVE Validate inputs, persist Event, refresh dashboard, close dialog.
            %   Wraps the full pipeline in try/catch so any throw surfaces
            %   via errordlg without tearing the dialog down — the user
            %   can correct input and Save again. On success: deletes
            %   the modal figure.
            try
                tStart = obj.readNumeric_(obj.hStartEdit, 'Start time');
                tEnd   = obj.readNumeric_(obj.hEndEdit,   'End time');
                label  = strtrim(get(obj.hLabelEdit, 'String'));
                sevIdx = get(obj.hSevPopup, 'Value');
                catIdx = get(obj.hCatPopup, 'Value');
                sev    = sevIdx;  % 1..3 maps directly to Event.Severity
                cat    = obj.CATEGORY_LABELS{catIdx};
                notes  = obj.flattenNotes_(get(obj.hNotesEdit, 'String'));
                keys   = obj.parseTagKeys_(get(obj.hKeysEdit, 'String'));
                obj.persistEvent_(tStart, tEnd, label, sev, cat, notes, keys);
                % Persistence + notify succeeded — close the dialog.
                if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                    delete(obj.hFigure);
                end
                obj.hFigure = [];
            catch ME
                errordlg(ME.message, 'Create Event');
            end
        end

        function onCancel(obj, ~, ~)
            %ONCANCEL Close the dialog without writing.
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                delete(obj.hFigure);
            end
            obj.hFigure = [];
        end
    end

    methods (Access = private)
        function buildUI(obj)
            %BUILDUI Construct the modal figure with all input controls.
            theme = obj.resolveTheme_();
            [xStart, xEnd, primaryKey] = obj.derivePrefill_();

            figW = 380;
            figH = 480;
            obj.hFigure = figure( ...
                'Name', 'Create Event', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'Units', 'pixels', ...
                'Position', [120 120 figW figH], ...
                'WindowStyle', 'modal', ...
                'Resize', 'off', ...
                'Color', theme.WidgetBackground, ...
                'CloseRequestFcn', @(s,e) obj.onCancel(s, e));
            try
                movegui(obj.hFigure, 'center');
            catch
            end

            fg       = theme.ForegroundColor;
            bg       = theme.WidgetBackground;
            fontName = theme.FontName;

            padding = 14;
            labelW  = 110;
            rowH    = 28;
            ctrlX   = padding + labelW + 8;
            ctrlW   = figW - ctrlX - padding;

            y = figH - padding - rowH;

            % Start time
            obj.makeLabel_('Start time', [padding, y+4, labelW, rowH-8], theme);
            obj.hStartEdit = uicontrol('Parent', obj.hFigure, ...
                'Style', 'edit', ...
                'String', num2str(xStart), ...
                'Position', [ctrlX, y+2, ctrlW, rowH-4], ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', [1 1 1], ...
                'FontName', fontName);
            y = y - rowH;

            % End time
            obj.makeLabel_('End time', [padding, y+4, labelW, rowH-8], theme);
            obj.hEndEdit = uicontrol('Parent', obj.hFigure, ...
                'Style', 'edit', ...
                'String', num2str(xEnd), ...
                'Position', [ctrlX, y+2, ctrlW, rowH-4], ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', [1 1 1], ...
                'FontName', fontName);
            y = y - rowH;

            % Label
            obj.makeLabel_('Label', [padding, y+4, labelW, rowH-8], theme);
            obj.hLabelEdit = uicontrol('Parent', obj.hFigure, ...
                'Style', 'edit', ...
                'String', '', ...
                'Position', [ctrlX, y+2, ctrlW, rowH-4], ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', [1 1 1], ...
                'FontName', fontName);
            y = y - rowH;

            % Severity (popup)
            obj.makeLabel_('Severity', [padding, y+4, labelW, rowH-8], theme);
            obj.hSevPopup = uicontrol('Parent', obj.hFigure, ...
                'Style', 'popupmenu', ...
                'String', obj.SEVERITY_LABELS, ...
                'Value', 2, ...
                'Position', [ctrlX, y+2, ctrlW, rowH-4], ...
                'BackgroundColor', [1 1 1], ...
                'FontName', fontName);
            y = y - rowH;

            % Category (popup)
            obj.makeLabel_('Category', [padding, y+4, labelW, rowH-8], theme);
            obj.hCatPopup = uicontrol('Parent', obj.hFigure, ...
                'Style', 'popupmenu', ...
                'String', obj.CATEGORY_LABELS, ...
                'Value', 1, ...
                'Position', [ctrlX, y+2, ctrlW, rowH-4], ...
                'BackgroundColor', [1 1 1], ...
                'FontName', fontName);
            y = y - rowH;

            % Tag keys (comma-separated)
            obj.makeLabel_('Tag keys', [padding, y+4, labelW, rowH-8], theme);
            obj.hKeysEdit = uicontrol('Parent', obj.hFigure, ...
                'Style', 'edit', ...
                'String', primaryKey, ...
                'Position', [ctrlX, y+2, ctrlW, rowH-4], ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Comma-separated Tag keys to bind this event to.', ...
                'BackgroundColor', [1 1 1], ...
                'FontName', fontName);
            y = y - rowH;

            % Notes (multi-line)
            notesH = 120;
            obj.makeLabel_('Notes', [padding, y - notesH + rowH + 4, labelW, rowH-8], theme);
            obj.hNotesEdit = uicontrol('Parent', obj.hFigure, ...
                'Style', 'edit', ...
                'String', '', ...
                'Max', 4, 'Min', 0, ...
                'Position', [ctrlX, y - notesH + rowH, ctrlW, notesH], ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', [1 1 1], ...
                'FontName', fontName);
            y = y - notesH;

            % Buttons row
            btnY = padding;
            btnW = 80;
            uicontrol('Parent', obj.hFigure, ...
                'Style', 'pushbutton', ...
                'String', 'Cancel', ...
                'Position', [figW - padding - 2*btnW - 10, btnY, btnW, 30], ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'ForegroundColor', fg, ...
                'Callback', @(s,e) obj.onCancel(s, e));
            uicontrol('Parent', obj.hFigure, ...
                'Style', 'pushbutton', ...
                'String', 'Save', ...
                'Position', [figW - padding - btnW, btnY, btnW, 30], ...
                'FontWeight', 'bold', ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'ForegroundColor', fg, ...
                'Callback', @(s,e) obj.onSave(s, e));

            % Coarsely silence the y-unused warning when the buttons row
            % is placed at a fixed btnY (intentional: notes block can grow
            % without pushing buttons off-screen because Resize='off').
            assert(y >= 0 || y < 0); %#ok<*BDSCA>
        end

        function makeLabel_(obj, str, pos, theme)
            uicontrol('Parent', obj.hFigure, ...
                'Style', 'text', ...
                'String', str, ...
                'Position', pos, ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', theme.WidgetBackground, ...
                'ForegroundColor', theme.ForegroundColor, ...
                'FontName', theme.FontName);
        end

        function theme = resolveTheme_(obj)
            %RESOLVETHEME_ Return a theme struct, preferring engine cached theme.
            theme = [];
            try
                if ismethod(obj.Engine, 'getCachedTheme')
                    theme = obj.Engine.getCachedTheme();
                end
            catch
                theme = [];
            end
            if ~isstruct(theme) || ~isfield(theme, 'WidgetBackground')
                try
                    theme = DashboardTheme('light');
                catch
                    % Last-resort minimal theme struct.
                    theme = struct( ...
                        'WidgetBackground',  [1 1 1], ...
                        'ForegroundColor',   [0.1 0.1 0.1], ...
                        'ToolbarBackground', [0.94 0.94 0.95], ...
                        'ToolbarFontColor',  [0.20 0.20 0.25], ...
                        'FontName',          'Helvetica');
                end
            end
        end

        function [xStart, xEnd, primaryKey] = derivePrefill_(obj)
            %DERIVEPREFILL_ Pre-fill time range from widget XLim + primary tag key.
            xStart = 0;
            xEnd   = 1;
            primaryKey = '';

            % Prefer the FastSense axes XLim — that's the current view.
            try
                fp = obj.Widget.FastSenseObj;
                if ~isempty(fp) && ~isempty(fp.hAxes) && ishandle(fp.hAxes)
                    xl = get(fp.hAxes, 'XLim');
                    if numel(xl) == 2 && all(isfinite(xl))
                        xStart = xl(1);
                        xEnd   = xl(2);
                    end
                end
            catch
                % keep defaults
            end

            % If the host figure has stashed a hover-selection appdata blob
            % under the widget's panel, prefer that range.
            try
                hFig = ancestor(obj.Widget.hPanel, 'figure');
                if ~isempty(hFig) && ishandle(hFig)
                    sel = getappdata(hFig, 'HoverSelection');
                    if isstruct(sel) && isfield(sel, 'tStart') && ...
                            isfield(sel, 'tEnd') && all(isfinite([sel.tStart sel.tEnd]))
                        xStart = sel.tStart;
                        xEnd   = sel.tEnd;
                    end
                end
            catch
                % keep XLim
            end

            % Primary tag key from widget.Tag.Key (FastSenseWidget is single-Tag).
            try
                if ~isempty(obj.Widget.Tag) && isprop(obj.Widget.Tag, 'Key') && ...
                        ~isempty(obj.Widget.Tag.Key)
                    primaryKey = char(obj.Widget.Tag.Key);
                end
            catch
                primaryKey = '';
            end
        end

        function v = readNumeric_(~, h, fieldName)
            %READNUMERIC_ Read + validate a uicontrol edit field as numeric.
            str = get(h, 'String');
            v = str2double(str);
            if ~isfinite(v)
                error('CreateEventDialog:invalidTimeRange', ...
                    '%s must be a finite number; got "%s".', fieldName, str);
            end
        end

        function s = flattenNotes_(~, raw)
            %FLATTENNOTES_ Convert multi-line edit input to a newline-joined char.
            if ischar(raw)
                s = raw;
                return;
            end
            if iscell(raw)
                s = strjoin(raw, sprintf('\n'));
                return;
            end
            % Cell of cell of char or char matrix — defensive fallback.
            try
                s = char(raw);
            catch
                s = '';
            end
        end

        function keys = parseTagKeys_(~, raw)
            %PARSETAGKEYS_ Split comma-separated keys, trim whitespace, drop empties.
            keys = {};
            if isempty(raw)
                return;
            end
            if iscell(raw)
                raw = strjoin(raw, ',');
            end
            parts = strsplit(raw, ',');
            for i = 1:numel(parts)
                k = strtrim(parts{i});
                if ~isempty(k)
                    keys{end+1} = k; %#ok<AGROW>
                end
            end
        end

        function persistEvent_(obj, tStart, tEnd, label, sev, cat, notes, keys)
            %PERSISTEVENT_ Instance method delegating to the static seam.
            %   Kept as a thin wrapper so tests can call persistEventStatic
            %   directly without instantiating the dialog (and thus
            %   without opening a figure under headless test runs).
            primaryName = obj.derivePrimaryName_();
            CreateEventDialog.persistEventStatic(obj.Engine, ...
                tStart, tEnd, label, sev, cat, notes, keys, primaryName);
        end

        function s = derivePrimaryName_(obj)
            %DERIVEPRIMARYNAME_ Return a sensible Event.SensorName for the dialog.
            %   Prefers the widget's bound Tag.Key, then Tag.Name, then
            %   widget.Title; falls back to 'manual_event' so Event's
            %   constructor never sees an empty SensorName.
            s = '';
            try
                if ~isempty(obj.Widget.Tag) && isprop(obj.Widget.Tag, 'Key') && ...
                        ~isempty(obj.Widget.Tag.Key)
                    s = char(obj.Widget.Tag.Key);
                    return;
                end
                if ~isempty(obj.Widget.Tag) && isprop(obj.Widget.Tag, 'Name') && ...
                        ~isempty(obj.Widget.Tag.Name)
                    s = char(obj.Widget.Tag.Name);
                    return;
                end
                if ~isempty(obj.Widget.Title)
                    s = char(obj.Widget.Title);
                    return;
                end
            catch
                s = '';
            end
            if isempty(s)
                s = 'manual_event';
            end
        end
    end

    methods (Static)
        function persistEventStatic(engine, tStart, tEnd, label, sev, cat, notes, keys, primaryName)
            %PERSISTEVENTSTATIC Persist a manual annotation Event into engine.EventStore (260513-snt).
            %   Public static seam called by the instance persistEvent_
            %   wrapper AND directly by Task-3 tests. Keeping the
            %   write-side logic free of any figure handles makes it
            %   trivially unit-testable.
            %
            %   Inputs:
            %     engine      - DashboardEngine (must expose EventStore + notifyEventsChanged)
            %     tStart,tEnd - numeric finite scalars; tEnd >= tStart
            %     label       - char/string; non-empty after trim
            %     sev         - numeric 1..3 (Event.Severity)
            %     cat         - char; Event.Category (e.g. 'manual_annotation')
            %     notes       - char; Event.Notes
            %     keys        - cellstr; one EventBinding.attach per entry
            %     primaryName - char; Event SensorName carrier (falls back
            %                   to first key if empty)
            %
            %   Side effects (on success):
            %     - engine.EventStore.append(ev)        creates Event with Id
            %     - ev.TagKeys = keys                   AFTER append (id-stable)
            %     - EventBinding.attach(ev.Id, k)       for each key
            %     - engine.EventStore.save()            atomic .mat write
            %     - engine.notifyEventsChanged()        refreshes UI
            %
            %   Errors:
            %     CreateEventDialog:invalidTimeRange - tEnd < tStart or non-finite
            %     CreateEventDialog:emptyLabel       - label trim is empty
            %     CreateEventDialog:noStore          - engine.EventStore is empty

            % --- Input validation ---
            if ~isnumeric(tStart) || ~isscalar(tStart) || ~isfinite(tStart) || ...
                    ~isnumeric(tEnd) || ~isscalar(tEnd) || ~isfinite(tEnd)
                error('CreateEventDialog:invalidTimeRange', ...
                    'Start and End must be finite numeric scalars.');
            end
            if tEnd < tStart
                error('CreateEventDialog:invalidTimeRange', ...
                    'EndTime (%g) must be >= StartTime (%g).', tEnd, tStart);
            end
            if isempty(strtrim(char(label)))
                error('CreateEventDialog:emptyLabel', ...
                    'Label must be non-empty after trim.');
            end
            if isempty(engine) || ~isa(engine, 'DashboardEngine')
                error('CreateEventDialog:invalidEngine', ...
                    'engine must be a DashboardEngine.');
            end
            if isempty(engine.EventStore)
                error('CreateEventDialog:noStore', ...
                    'engine.EventStore is empty; cannot persist event.');
            end
            if nargin < 9 || isempty(primaryName)
                if ~isempty(keys) && ~isempty(keys{1})
                    primaryName = char(keys{1});
                else
                    primaryName = 'manual_event';
                end
            end

            % --- Build + append Event (mirrors Tag.addManualEvent) ---
            ev = Event(tStart, tEnd, char(primaryName), char(label), NaN, 'upper');
            ev.Category = char(cat);
            ev.Severity = sev;
            ev.Notes    = char(notes);
            engine.EventStore.append(ev);
            % TagKeys + EventBinding.attach AFTER append so Id exists.
            if ~isempty(keys)
                ev.TagKeys = keys;
                for i = 1:numel(keys)
                    try
                        EventBinding.attach(ev.Id, char(keys{i}));
                    catch
                        % best-effort — a bad key shouldn't roll back the event
                    end
                end
            end

            % --- Persist + notify ---
            try
                engine.EventStore.save();
            catch ME
                warning('CreateEventDialog:saveFailed', ...
                    'EventStore.save failed: %s', ME.message);
            end
            try
                engine.notifyEventsChanged();
            catch ME
                warning('CreateEventDialog:notifyFailed', ...
                    'engine.notifyEventsChanged failed: %s', ME.message);
            end
        end
    end
end
