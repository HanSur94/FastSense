function c = severityColor(theme, severity)
%SEVERITYCOLOR Map event severity (1/2/3) to a 1x3 RGB triplet.
%
%   c = severityColor(theme, severity) returns a 1x3 RGB row vector picked
%   from the dashboard theme's status palette. The mapping mirrors the
%   FastSense main-axes glyph palette so slider-preview event markers and
%   FastSense glyphs stay visually consistent:
%
%       severity >= 3 -> theme.StatusAlarmColor   (default [0.91 0.27 0.38])
%       severity >= 2 -> theme.StatusWarnColor    (default [0.91 0.63 0.27])
%       else          -> theme.StatusOkColor      (default [0.31 0.80 0.64])
%
%   The helper is hot-path tolerant — it never throws:
%     - `theme` may be [] or any non-struct; the field lookup is skipped
%       and the hardcoded fallbacks are returned instead.
%     - `severity` may be empty, NaN, +/-Inf, or non-numeric; in any of
%       those cases the OK (severity=1) branch is selected.
%
%   Tiebreaker convention (used by callers, not enforced here): when two
%   widgets emit a marker for the same time, the engine keeps the row with
%   the highest severity. This helper returns one color at a time — the
%   dedup pass lives in DashboardEngine.computeEventMarkers.
%
%   Octave 7+ parity: the return is always a 1x3 RGB triplet (never RGBA),
%   matching FastSenseTheme conventions.
%
%   See also: DashboardTheme, FastSense.severityToColor_,
%             TimeRangeSelector.setEventMarkers.

    % Coerce severity to a finite scalar; default to 1 (OK) for anything
    % weird (empty, non-numeric, NaN, Inf).
    if ~isnumeric(severity) || isempty(severity)
        sev = 1;
    else
        sev = severity(1);
        if ~isfinite(sev)
            sev = 1;
        end
    end

    if sev >= 3
        if isstruct(theme) && isfield(theme, 'StatusAlarmColor')
            c = theme.StatusAlarmColor;
        else
            c = [0.91 0.27 0.38];
        end
    elseif sev >= 2
        if isstruct(theme) && isfield(theme, 'StatusWarnColor')
            c = theme.StatusWarnColor;
        else
            c = [0.91 0.63 0.27];
        end
    else
        if isstruct(theme) && isfield(theme, 'StatusOkColor')
            c = theme.StatusOkColor;
        else
            c = [0.31 0.80 0.64];
        end
    end

    % Defensive: ensure 1x3 row vector. If theme accidentally stored a
    % column or 4-tuple, normalize.
    c = c(:).';
    if numel(c) >= 3
        c = c(1:3);
    else
        c = [0.31 0.80 0.64];
    end
end
