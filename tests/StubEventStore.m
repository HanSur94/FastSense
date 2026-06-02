classdef StubEventStore < handle
    %STUBEVENTSTORE Fake EventStore handle for NotificationCenterPane tests.
    %   A lightweight test double that stands in for a real EventStore so the
    %   notification-pane logic can be exercised without persisting to disk.
    %   Mirrors the public surface the pane relies on: getEvents / numEvents /
    %   acknowledgeEvent. Modeled on tests/CaptureNotificationService.m.
    %
    %   Configurable failure switches let tests drive the stale-on-read path
    %   (ThrowOnGet_) and the already-acked race path (ThrowOnAck_).
    %
    %   Usage:
    %     s = StubEventStore;
    %     s.Events_ = [e1 e2 e3];                 % configure fixtures
    %     evs = s.getEvents();                     % -> Events_
    %     s.acknowledgeEvent('evt_2', struct());   % records id + sets AckedAt
    %     assert(isequal(s.AckedIds_, {'evt_2'}));
    %     s.ThrowOnAck_ = true;                    % next ack throws unknownEventId
    %     s.ThrowOnGet_ = true;                    % next getEvents throws
    %
    %   Phase 1040 Plan 01.
    %
    %   See also EventStore, Event, NotificationCenterPane, CaptureNotificationService.

    properties
        Events_     = Event.empty   % Event array; configure in test setup
        AckedIds_   = {}            % cellstr: each eventId passed to acknowledgeEvent, in call order
        ThrowOnAck_ = false         % when true, acknowledgeEvent throws EventStore:unknownEventId
        ThrowOnGet_ = false         % when true, getEvents throws (exercises the stale path)
    end

    methods
        function evs = getEvents(obj)
        %GETEVENTS Return the configured Event array (or throw when ThrowOnGet_).
            if obj.ThrowOnGet_
                error('EventStore:getEventsFailed', 'stub throw');
            end
            evs = obj.Events_;
        end

        function n = numEvents(obj)
        %NUMEVENTS Count of configured events.
            n = numel(obj.Events_);
        end

        function ack = acknowledgeEvent(obj, eventId, ~)
        %ACKNOWLEDGEEVENT Record the id and mutate the matching Event's AckedAt.
        %   Mirrors the real EventStore single-user behavior: records the
        %   call, sets the matching in-memory Event's AckedAt, and returns an
        %   ack struct. When ThrowOnAck_ is set, throws the same identifier the
        %   real store raises on an unknown id so the race path can be tested.
            if obj.ThrowOnAck_
                error('EventStore:unknownEventId', 'stub: not found');
            end
            obj.AckedIds_{end+1} = eventId;
            for i = 1:numel(obj.Events_)
                if strcmp(obj.Events_(i).Id, eventId)
                    obj.Events_(i).AckedAt = now;
                    break;
                end
            end
            ack = struct('eventId', eventId, 'action', 'ack');
        end

        function store = getEventStore(obj)
        %GETEVENTSTORE Return self, so the stub can double as the Companion's store resolver.
        %   NotificationCenterPane.ackOne_ calls Companion_.getEventStore(); pointing the
        %   pane's Companion_ at this stub routes acks straight back here.
            store = obj;
        end

        function save(obj) %#ok<MANU>
        %SAVE No-op; events live in memory. Lets ackOne_'s post-ack save() succeed.
        end
    end
end
