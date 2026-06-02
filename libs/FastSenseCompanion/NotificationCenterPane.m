classdef NotificationCenterPane < handle
%NOTIFICATIONCENTERPANE Acknowledgeable notification inbox pane for FastSenseCompanion.
%
%   Self-contained handle class that owns a live "inbox" of UNACKED
%   threshold-violation events read from the shared EventStore. A sibling to
%   EventsLogPane: it attaches into either a uipanel (inline, embedded in the
%   companion's collapsible 4th column) or a uifigure (detached, its own
%   window), fires DetachRequested on the pop-out icon, and preserves its
%   last-good event set + filter selection across attach/detach round-trips.
%
%   Unlike the append-only EventsLogPane, this pane is ack-driven: each row is
%   one unacked Event; acknowledging it (EventStore.acknowledgeEvent) removes
%   it from the inbox on the next refresh and decrements the toolbar bell
%   badge. The pane does NOT own a timer — FastSenseCompanion.onLiveTick_
%   drives refresh (wired in Plan 03).
%
%   This file (Plan 01) ships only the class shell + the pure-logic static
%   helpers that pin the filter / sort / diff / badge semantics. The instance
%   lifecycle (attach/detach/refresh/applyTheme/ack callbacks) is added in
%   Plan 02.
%
%   Static helpers (pure; no UI, no EventStore calls):
%     filterUnacked_   — keep events with empty/NaN AckedAt
%     sortNewestFirst_ — descending StartTime order
%     maxSeverity_     — highest Severity (0 for empty)
%     idsOf_           — cellstr of Event.Id
%     diffIds_         — order-insensitive id-set change test
%     badgeText_       — bell glyph + optional " (N)" count
%     badgeColor_      — severity -> CompanionTheme color token
%
%   Properties:
%     IsAttached (SetAccess private) — true between attach() and detach()
%
%   Events fired:
%     DetachRequested — fired when the user clicks the inline pop-out icon.
%
%   See also EventsLogPane, EventStore, Event, CompanionTheme, EventGanttCanvas.

    events
        DetachRequested  % fired when user clicks the inline pop-out icon
    end

    properties (SetAccess = private)
        IsAttached  logical = false
    end

    properties (Access = private)
        ThemeStruct_    = []           % resolved CompanionTheme struct
        hRoot_          = []           % outer uigridlayout ([3 1] grid)
        hTable_         = []           % uitable for the inbox rows
        hSevDD_         = []           % uidropdown severity filter
        hSearch_        = []           % uieditfield (free-text filter)
        hAckAllBtn_     = []           % "Acknowledge all visible" uibutton
        hLastUpdateLbl_ = []           % "Updated: HH:MM:SS" label
        hPopoutBtn_     = []           % pop-out icon uibutton
        Companion_      = []           % FastSenseCompanion handle (or [])
        LastGoodEvents_ = Event.empty  % last successfully-read unacked set (survives detach)
        LastIds_        = {}           % cellstr of LastGoodEvents_ ids (diff key)
        Listeners_      = {}           % addlistener handles; deleted on teardown
        IsStale_        = false        % true when the last EventStore read failed
    end

    methods (Static)

        function evs = filterUnacked_(allEvents)
        %FILTERUNACKED_ Keep only events that are still unacknowledged.
        %   An event is unacked iff AckedAt is empty OR all-NaN (mirrors
        %   Event.computeDisplayState). Empty input returns an empty Event array.
            if isempty(allEvents)
                evs = Event.empty;
                return;
            end
            mask = false(1, numel(allEvents));
            for i = 1:numel(allEvents)
                a = allEvents(i).AckedAt;
                mask(i) = isempty(a) || (isnumeric(a) && all(isnan(a)));
            end
            evs = allEvents(mask);
        end

        function evs = sortNewestFirst_(events)
        %SORTNEWESTFIRST_ Order events by StartTime, newest first.
            if numel(events) > 1
                [~, ord] = sort([events.StartTime], 'descend');
                evs = events(ord);
            else
                evs = events;
            end
        end

        function s = maxSeverity_(events)
        %MAXSEVERITY_ Highest Severity across events (0 for an empty set).
            if isempty(events)
                s = 0;
            else
                s = max([events.Severity]);
            end
        end

        function ids = idsOf_(events)
        %IDSOF_ Return a cellstr of the events' Id fields ({} for empty input).
            if isempty(events)
                ids = {};
            else
                ids = arrayfun(@(e) e.Id, events, 'UniformOutput', false);
            end
        end

        function changed = diffIds_(newIds, oldIds)
        %DIFFIDS_ True when the two id sets differ (order-insensitive).
        %   {} vs {} -> false. Reordering the same ids -> false.
            if isempty(newIds), newIds = {}; end
            if isempty(oldIds), oldIds = {}; end
            changed = ~isequal(sort(newIds(:)), sort(oldIds(:)));
        end

        function txt = badgeText_(count, glyph)
        %BADGETEXT_ Bell glyph alone for zero, else 'glyph (N)'.
            if count <= 0
                txt = glyph;
            else
                txt = sprintf('%s (%d)', glyph, count);
            end
        end

        function rgb = badgeColor_(maxSev, theme)
        %BADGECOLOR_ Map the highest active severity to a theme color token.
        %   Idle/zero-count recoloring to WidgetBorderColor is handled by the
        %   caller (Plan 03); this returns the active-severity color.
            switch maxSev
                case 3
                    rgb = theme.StatusAlarmColor;
                case 2
                    rgb = theme.StatusWarnColor;
                case {0, 1}
                    rgb = theme.Accent;
                otherwise
                    rgb = theme.Accent;
            end
        end

    end
end
