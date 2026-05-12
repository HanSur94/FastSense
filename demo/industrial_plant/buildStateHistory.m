function [xValve, yValve, xMode, yMode] = buildStateHistory(cfg, tStart, nDays)
%BUILDSTATEHISTORY Build a 7-day reactor.mode + feedline.valve_state history.
%   [xValve, yValve, xMode, yMode] = buildStateHistory(cfg, tStart, nDays)
%   returns datenum-keyed transition lists for the two StateTags. Each
%   day is one identical cycle:
%       reactor.mode:
%         00:00 -> idle
%         02:00 -> heating
%         04:00 -> running
%         20:00 -> cooldown
%         22:00 -> idle
%       feedline.valve_state (synced to reactor.mode):
%         00:00 -> closed       (reactor idle)
%         02:00 -> opening      (reactor heating starts)
%         02:00:03 -> open
%         20:00 -> closing      (reactor cooldown starts)
%         20:00:03 -> closed
%
%   X is a column of MATLAB datenums, Y is a column cellstr (mode) or
%   cellstr (valve). The vectors are returned only for samples whose
%   label DIFFERS from the previous label (StateTag's existing contract:
%   one row per transition). cfg is plantConfig() output and is read for
%   the validated label sets only.
%
%   See also: seedHistory, plantConfig.

    sec = 1/86400;            % 1 second in days
    h   = 1/24;               % 1 hour in days

    % Static label sets per the daily cycle. Assert these match the
    % allowed labels in plantConfig so a rename in plantConfig is
    % caught here rather than silently writing an invalid StateTag value.
    modeLabels  = {'idle', 'heating', 'running', 'cooldown', 'idle'};
    valveLabels = {'closed', 'opening', 'open', 'closing', 'closed'};

    assert(isfield(cfg.Labels, 'reactor_mode'), ...
        'plantConfig().Labels.reactor_mode missing');
    assert(isfield(cfg.Labels, 'feedline_valve_state'), ...
        'plantConfig().Labels.feedline_valve_state missing');
    assert(all(ismember(modeLabels, cfg.Labels.reactor_mode)), ...
        'buildStateHistory: hardcoded reactor mode labels not all in cfg.Labels.reactor_mode');
    assert(all(ismember(valveLabels, cfg.Labels.feedline_valve_state)), ...
        'buildStateHistory: hardcoded valve labels not all in cfg.Labels.feedline_valve_state');

    xValve = []; yValve = {};
    xMode  = []; yMode  = {};

    for d = 0:(nDays-1)
        dayStart = tStart + d;

        % Reactor mode for this day.
        modeTimes  = dayStart + [0, 2*h, 4*h, 20*h, 22*h];

        % Valve state for this day. Three-second open/close ramps.
        valveTimes  = dayStart + [0, 2*h, 2*h + 3*sec, 20*h, 20*h + 3*sec];

        for k = 1:numel(modeTimes)
            label = modeLabels{k};
            if isempty(yMode) || ~strcmp(yMode{end}, label)
                xMode(end+1)   = modeTimes(k); %#ok<AGROW>
                yMode{end+1}   = label;        %#ok<AGROW>
            end
        end
        for k = 1:numel(valveTimes)
            label = valveLabels{k};
            if isempty(yValve) || ~strcmp(yValve{end}, label)
                xValve(end+1)  = valveTimes(k); %#ok<AGROW>
                yValve{end+1}  = label;         %#ok<AGROW>
            end
        end
    end

    xValve = xValve(:);
    yValve = yValve(:);
    xMode  = xMode(:);
    yMode  = yMode(:);
end
