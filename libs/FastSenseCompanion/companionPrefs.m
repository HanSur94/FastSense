function out = companionPrefs(action, prefs)
%COMPANIONPREFS Load/save FastSenseCompanion user preferences in prefdir.
%
%   prefs = companionPrefs('load')
%       Returns the persisted struct (theme, livePeriod, ...). On a missing
%       file returns an empty struct() silently. On a corrupt / unreadable
%       file returns an empty struct() and issues a single
%       FastSenseCompanion:prefsLoadFailed warning. Never throws.
%
%   companionPrefs('save', prefs)
%       Atomic write of `prefs` to fullfile(prefdir, 'FastSenseCompanion.mat')
%       (saves to a temp file then movefile-renames). On failure issues a
%       FastSenseCompanion:prefsSaveFailed warning. Never throws.
%
%   Forward-compatible: callers handle missing fields. This helper does
%   not validate field names so future settings can be added without
%   schema migration.
%
%   See also FastSenseCompanion, prefdir.

    out = struct();
    if nargin < 1
        return;
    end
    if ~ischar(action) && ~(isstring(action) && isscalar(action))
        warning('FastSenseCompanion:prefsUnknownAction', ...
            'companionPrefs: action must be a char (''load'' or ''save'').');
        return;
    end
    action = char(action);

    prefsPath = fullfile(prefdir, 'FastSenseCompanion.mat');

    switch action
        case 'load'
            if exist(prefsPath, 'file') ~= 2
                return;  % missing → empty struct, no warning
            end
            try
                S = load(prefsPath, 'prefs');
                if isfield(S, 'prefs') && isstruct(S.prefs)
                    out = S.prefs;
                else
                    warning('FastSenseCompanion:prefsLoadFailed', ...
                        'Companion preferences file is missing the ''prefs'' variable.');
                end
            catch err
                warning('FastSenseCompanion:prefsLoadFailed', ...
                    'Could not load Companion preferences: %s', err.message);
            end

        case 'save'
            if nargin < 2 || ~isstruct(prefs)
                warning('FastSenseCompanion:prefsSaveFailed', ...
                    'companionPrefs(''save'', prefs): prefs must be a struct.');
                return;
            end
            tmpPath = [prefsPath, '.tmp'];
            try
                save(tmpPath, 'prefs', '-mat');  %#ok<NASGU>
                movefile(tmpPath, prefsPath, 'f');
            catch err
                % Best-effort cleanup of the temp file.
                if exist(tmpPath, 'file') == 2
                    try
                        delete(tmpPath);
                    catch
                    end
                end
                warning('FastSenseCompanion:prefsSaveFailed', ...
                    'Could not save Companion preferences: %s', err.message);
            end

        otherwise
            warning('FastSenseCompanion:prefsUnknownAction', ...
                'companionPrefs: unknown action ''%s'' (expected ''load'' or ''save'').', ...
                action);
    end
end
