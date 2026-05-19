classdef PlantLogImportDialog < handle
%PLANTLOGIMPORTDIALOG Modal uifigure for confirming/overriding column mapping (PLOG-IM-06..08).
%
%   Owns a uifigure with WindowStyle='modal' that displays:
%     - Header: filename + detected row count
%     - Two dropdowns: Timestamp column / Message column
%     - Edit field: Timestamp format override (blank = auto)
%     - Inline error label: red text shown when timestamp column does not parse
%     - 10-row uitable preview of the raw table (first 10 rows)
%     - Buttons: Cancel (always enabled) + Confirm (enabled only when timestamp parses)
%
%   Usage:
%     dlg = PlantLogImportDialog(filePath, rawTable, autoMapping);
%     mapping = dlg.runModal();   % blocks; returns mapping struct or []
%
%   Constructor inputs:
%     filePath    char/string -- informational; rendered in header
%     rawTable    MATLAB table (already loaded by the caller via readtablePortable)
%     autoMapping struct -- PlantLogReader.autoDetect output:
%                   .TimestampColumn (char; '' if none detected)
%                   .MessageColumn   (char; '' if none detected)
%                   .TimestampFormat (char; '' = auto)
%     varargin    name-value:
%                   'Theme' -- 'dark' | 'light' (default 'dark')
%
%   Public methods:
%     mapping = runModal()   -- blocks until Confirm or Cancel; returns mapping or []
%     close()                -- tear down the figure (idempotent)
%     delete(obj)            -- destructor; calls close()
%
%   Errors:
%     PlantLogImportDialog:invalidInput -- bad constructor args
%
%   See also PlantLogReader, CompanionSettingsDialog, CompanionTheme.

    properties (SetAccess = private)
        FilePath    = ''
        RawTable    = []
        AutoMapping = struct('TimestampColumn', '', 'MessageColumn', '', 'TimestampFormat', '')
        Theme       = 'dark'
    end

    properties (Access = private)
        hFigure_      = []
        hTsDropdown_  = []
        hMsgDropdown_ = []
        hFmtEdit_     = []
        hPreviewTbl_  = []
        hErrorLabel_  = []
        hConfirmBtn_  = []
        hCancelBtn_   = []

        FinalMapping_ = []     % [] on Cancel/close; struct on Confirm
        IsClosing_    = false
    end

    methods (Access = public)

        function obj = PlantLogImportDialog(filePath, rawTable, autoMapping, varargin)
            %PLANTLOGIMPORTDIALOG Construct the dialog (does not show yet).
            %   Call runModal() to display and block until user dismisses.
            if isstring(filePath); filePath = char(filePath); end
            if ~ischar(filePath) || isempty(filePath)
                error('PlantLogImportDialog:invalidInput', ...
                    'filePath must be non-empty char/string.');
            end
            if ~istable(rawTable)
                error('PlantLogImportDialog:invalidInput', ...
                    'rawTable must be a MATLAB table; got %s.', class(rawTable));
            end
            if ~isstruct(autoMapping) || ~isfield(autoMapping, 'TimestampColumn') || ...
                    ~isfield(autoMapping, 'MessageColumn')
                error('PlantLogImportDialog:invalidInput', ...
                    'autoMapping must be a struct with TimestampColumn + MessageColumn fields.');
            end
            if ~isfield(autoMapping, 'TimestampFormat')
                autoMapping.TimestampFormat = '';
            end

            % Parse 'Theme' option
            themeChoice = 'dark';
            for k = 1:2:numel(varargin)
                key = varargin{k};
                val = varargin{k+1};
                if (ischar(key) || isstring(key)) && strcmpi(char(key), 'Theme')
                    themeChoice = char(val);
                end
            end

            obj.FilePath    = filePath;
            obj.RawTable    = rawTable;
            obj.AutoMapping = autoMapping;
            obj.Theme       = themeChoice;

            obj.buildUi_();
            obj.refreshState_();   % pre-validate auto-mapping; set Confirm enabled/disabled
        end

        function mapping = runModal(obj)
            %RUNMODAL Block until the user dismisses; return mapping or [].
            if isempty(obj.hFigure_) || ~isvalid(obj.hFigure_)
                mapping = [];
                return;
            end
            uiwait(obj.hFigure_);
            % uiwait returns once the figure is closed (Confirm/Cancel/close)
            mapping = obj.FinalMapping_;
        end

        function close(obj)
            %CLOSE Tear down the figure. Idempotent.
            if obj.IsClosing_
                return;
            end
            obj.IsClosing_ = true;
            try
                if ~isempty(obj.hFigure_) && isvalid(obj.hFigure_)
                    uiresume(obj.hFigure_);   % unblock runModal
                    delete(obj.hFigure_);
                end
            catch
            end
            obj.hFigure_ = [];
        end

        function delete(obj)
            %DELETE Handle-class destructor.
            obj.close();
        end

    end

    methods (Access = private)

        function buildUi_(obj)
            t = obj.themeStruct_();

            % Fixed-size modal -- readability over responsiveness
            obj.hFigure_ = uifigure( ...
                'Name',              sprintf('Plant Log Import -- %s', obj.fileShort_()), ...
                'Position',          [200 200 720 540], ...
                'Resize',            'off', ...
                'WindowStyle',       'modal', ...
                'AutoResizeChildren', 'off', ...
                'Color',             t.DashboardBackground, ...
                'Visible',           'off');   % unhide at end of build to avoid flicker

            varNames = obj.RawTable.Properties.VariableNames;
            nRows = height(obj.RawTable);

            % --- Header label ---
            hHeader = uilabel(obj.hFigure_, ...
                'Text',     sprintf('File: %s     Rows: %d', obj.fileShort_(), nRows), ...
                'Position', [16 504 688 20], ...
                'FontWeight','bold', ...
                'FontColor', t.ToolbarFontColor);

            % --- Timestamp column row ---
            tsLabel = uilabel(obj.hFigure_, ...
                'Text',     'Timestamp column:', ...
                'Position', [16 466 140 22], ...
                'FontColor', t.ToolbarFontColor);
            tsValue = obj.AutoMapping.TimestampColumn;
            if isempty(tsValue) || ~ismember(tsValue, varNames)
                tsValue = varNames{1};
            end
            obj.hTsDropdown_ = uidropdown(obj.hFigure_, ...
                'Items',           varNames, ...
                'Value',           tsValue, ...
                'Position',        [160 466 220 22], ...
                'ValueChangedFcn', @(s,e) obj.onMappingChanged_(s,e));

            % --- Message column row ---
            msgLabel = uilabel(obj.hFigure_, ...
                'Text',     'Message column:', ...
                'Position', [400 466 130 22], ...
                'FontColor', t.ToolbarFontColor);
            msgValue = obj.AutoMapping.MessageColumn;
            if isempty(msgValue) || ~ismember(msgValue, varNames)
                msgValue = varNames{min(2, numel(varNames))};
            end
            obj.hMsgDropdown_ = uidropdown(obj.hFigure_, ...
                'Items',           varNames, ...
                'Value',           msgValue, ...
                'Position',        [534 466 170 22], ...
                'ValueChangedFcn', @(s,e) obj.onMappingChanged_(s,e));

            % --- Timestamp format override ---
            fmtLabel = uilabel(obj.hFigure_, ...
                'Text',     'Timestamp format (blank = auto):', ...
                'Position', [16 432 240 22], ...
                'FontColor', t.ToolbarFontColor);
            obj.hFmtEdit_ = uieditfield(obj.hFigure_, 'text', ...
                'Value',           obj.AutoMapping.TimestampFormat, ...
                'Position',        [260 432 220 22], ...
                'ValueChangedFcn', @(s,e) obj.onMappingChanged_(s,e));

            % --- Inline error label (red, hidden by default) ---
            obj.hErrorLabel_ = uilabel(obj.hFigure_, ...
                'Text',      '', ...
                'Position',  [16 402 688 22], ...
                'FontColor', [0.85 0.20 0.20], ...
                'Visible',   'off');

            % --- Preview table (first 10 rows of raw table) ---
            previewN = min(10, height(obj.RawTable));
            if previewN > 0
                previewT = obj.RawTable(1:previewN, :);
            else
                previewT = obj.RawTable;
            end
            obj.hPreviewTbl_ = uitable(obj.hFigure_, ...
                'Data',     previewT, ...
                'Position', [16 80 688 308]);

            % --- Buttons ---
            obj.hCancelBtn_ = uibutton(obj.hFigure_, 'push', ...
                'Text',            'Cancel', ...
                'Position',        [520 24 80 32], ...
                'ButtonPushedFcn', @(~,~) obj.onCancel_());

            obj.hConfirmBtn_ = uibutton(obj.hFigure_, 'push', ...
                'Text',            'Confirm', ...
                'Position',        [620 24 80 32], ...
                'ButtonPushedFcn', @(~,~) obj.onConfirm_());

            % Close handler behaves like Cancel
            obj.hFigure_.CloseRequestFcn = @(~,~) obj.onCancel_();

            % Now make visible (no flicker)
            obj.hFigure_.Visible = 'on';

            % Touch local label handles so checkcode keeps them in scope.
            assert(isvalid(hHeader));
            assert(isvalid(tsLabel));
            assert(isvalid(msgLabel));
            assert(isvalid(fmtLabel));
        end

        function onMappingChanged_(obj, ~, ~)
            %ONMAPPINGCHANGED_ Re-validate when dropdown or format changes.
            try
                obj.refreshState_();
            catch err
                obj.surfaceError_(err);
            end
        end

        function refreshState_(obj)
            %REFRESHSTATE_ Re-validate the current dropdown/edit-field selection.
            tsName  = obj.hTsDropdown_.Value;
            msgName = obj.hMsgDropdown_.Value;
            fmt     = obj.hFmtEdit_.Value;
            if isstring(tsName);  tsName  = char(tsName);  end
            if isstring(msgName); msgName = char(msgName); end
            if isstring(fmt);     fmt     = char(fmt);     end

            % Score the timestamp column with the current format hint
            varNames = obj.RawTable.Properties.VariableNames;
            if ~ismember(tsName, varNames)
                obj.setError_('Timestamp column not found in file.');
                obj.setConfirmEnabled_(false);
                return;
            end

            % Guard: timestamp and message columns must differ. With a 1-column
            % file the dialog can't pick distinct columns; user must add a
            % column to the source file (or use the headless API).
            if strcmp(tsName, msgName)
                obj.setError_('Timestamp and Message columns must be different.');
                obj.setConfirmEnabled_(false);
                return;
            end

            col = obj.RawTable.(tsName);
            sampleN = min(50, numel(col));
            if sampleN == 0
                obj.setError_('Empty table -- nothing to parse.');
                obj.setConfirmEnabled_(false);
                return;
            end
            [~, ratio] = parseTimestampLadder(col(1:sampleN), fmt);

            if ratio >= 0.9
                obj.setError_('');                 % clear label
                obj.setConfirmEnabled_(true);
            else
                obj.setError_(sprintf( ...
                    'Selected timestamp column does not parse (%d%% success). Pick another column or set a format.', ...
                    round(ratio * 100)));
                obj.setConfirmEnabled_(false);
            end
        end

        function setConfirmEnabled_(obj, tf)
            if ~isempty(obj.hConfirmBtn_) && isvalid(obj.hConfirmBtn_)
                if tf
                    obj.hConfirmBtn_.Enable = 'on';
                else
                    obj.hConfirmBtn_.Enable = 'off';
                end
            end
        end

        function setError_(obj, msg)
            if ~isempty(obj.hErrorLabel_) && isvalid(obj.hErrorLabel_)
                if isempty(msg)
                    obj.hErrorLabel_.Visible = 'off';
                    obj.hErrorLabel_.Text = '';
                else
                    obj.hErrorLabel_.Visible = 'on';
                    obj.hErrorLabel_.Text = msg;
                end
            end
        end

        function onConfirm_(obj)
            try
                tsName  = char(obj.hTsDropdown_.Value);
                msgName = char(obj.hMsgDropdown_.Value);
                fmt     = char(obj.hFmtEdit_.Value);
                obj.FinalMapping_ = struct( ...
                    'TimestampColumn', tsName, ...
                    'MessageColumn',   msgName, ...
                    'TimestampFormat', fmt);
                obj.close();
            catch err
                obj.surfaceError_(err);
            end
        end

        function onCancel_(obj)
            try
                obj.FinalMapping_ = [];
                obj.close();
            catch err
                obj.surfaceError_(err);
            end
        end

        function surfaceError_(obj, err)
            %SURFACEERROR_ Non-blocking uialert; never throws to user.
            try
                if ~isempty(obj.hFigure_) && isvalid(obj.hFigure_)
                    uialert(obj.hFigure_, err.message, 'Plant Log Import', 'Icon', 'error');
                end
            catch
            end
        end

        function t = themeStruct_(obj)
            %THEMESTRUCT_ Return a theme struct via CompanionTheme.
            try
                t = CompanionTheme.get(obj.Theme);
            catch
                % Fallback if CompanionTheme is somehow unavailable
                t.DashboardBackground = [0.13 0.16 0.20];
                t.ToolbarFontColor    = [0.92 0.94 0.96];
                t.Accent              = [0.31 0.80 0.64];
            end
        end

        function s = fileShort_(obj)
            [~, name, ext] = fileparts(obj.FilePath);
            s = [name ext];
        end

    end
end
