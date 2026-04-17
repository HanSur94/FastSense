classdef EventBinding
    %EVENTBINDING Singleton many-to-many registry binding Events to Tags.
    %   EventBinding stores (eventId, tagKey) pairs using two persistent
    %   containers.Map indexes (forward: eventId -> {tagKeys}, reverse:
    %   tagKey -> {eventIds}) for O(1) lookup in both directions.
    %
    %   This is the single-write-side for Event-Tag binding (EVENT-02).
    %   Only EventBinding.attach mutates the registry. Convenience wrappers
    %   on Event/Tag/EventStore delegate to this class.
    %
    %   Static methods:
    %     attach(eventId, tagKey)              — idempotent; adds binding
    %     getTagKeysForEvent(eventId)          — returns cell of tagKey strings
    %     getEventsForTag(tagKey, eventStore)  — returns Event array
    %     clear()                              — resets all bindings
    %
    %   Error IDs:
    %     EventBinding:emptyId — eventId is empty
    %
    %   See also Event, EventStore, Tag.

    methods (Static)
        function attach(eventId, tagKey)
            %ATTACH Bind an event to a tag (idempotent).
            %   EventBinding.attach(eventId, tagKey) adds the (eventId, tagKey)
            %   pair to both forward and reverse indexes. Silent on duplicate.
            %
            %   Errors:
            %     EventBinding:emptyId — eventId is empty char or empty string
            if isempty(eventId)
                error('EventBinding:emptyId', ...
                    'eventId must be non-empty.');
            end
            eventId = char(eventId);
            tagKey  = char(tagKey);
            fwdMap = EventBinding.bindings_();
            revMap = EventBinding.reverseIndex_();
            % Forward: eventId -> {tagKey1, tagKey2, ...}
            if fwdMap.isKey(eventId)
                keys = fwdMap(eventId);
                if any(strcmp(tagKey, keys))
                    return;  % idempotent
                end
                keys{end+1} = tagKey;
                fwdMap(eventId) = keys; %#ok<NASGU>
            else
                fwdMap(eventId) = {tagKey}; %#ok<NASGU>
            end
            % Reverse: tagKey -> {eventId1, eventId2, ...}
            if revMap.isKey(tagKey)
                ids = revMap(tagKey);
                ids{end+1} = eventId;
                revMap(tagKey) = ids; %#ok<NASGU>
            else
                revMap(tagKey) = {eventId}; %#ok<NASGU>
            end
        end

        function keys = getTagKeysForEvent(eventId)
            %GETTAGKEYSFOREVENT Return cell of tagKey strings bound to eventId.
            eventId = char(eventId);
            fwdMap = EventBinding.bindings_();
            if fwdMap.isKey(eventId)
                keys = fwdMap(eventId);
            else
                keys = {};
            end
        end

        function events = getEventsForTag(tagKey, eventStore)
            %GETEVENTSFORTAG Return Event array bound to tagKey via reverse index.
            %   Uses the reverse index for O(1) lookup of eventIds, then
            %   filters the eventStore's events by matching Id.
            tagKey = char(tagKey);
            revMap = EventBinding.reverseIndex_();
            events = [];
            if ~revMap.isKey(tagKey)
                return;
            end
            ids = revMap(tagKey);
            allEvents = eventStore.getEvents();
            if isempty(allEvents)
                return;
            end
            keep = false(1, numel(allEvents));
            for i = 1:numel(allEvents)
                ev = allEvents(i);
                if ~isempty(ev.Id) && any(strcmp(ev.Id, ids))
                    keep(i) = true;
                end
            end
            events = allEvents(keep);
        end

        function clear()
            %CLEAR Reset all bindings in both forward and reverse indexes.
            fwdMap = EventBinding.bindings_();
            revMap = EventBinding.reverseIndex_();
            if fwdMap.Count > 0
                remove(fwdMap, fwdMap.keys());
            end
            if revMap.Count > 0
                remove(revMap, revMap.keys());
            end
        end
    end

    methods (Static, Access = private)
        function map = bindings_()
            %BINDINGS_ Persistent forward index: eventId -> cell of tagKeys.
            persistent bindings
            if isempty(bindings)
                bindings = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
            map = bindings;
        end

        function map = reverseIndex_()
            %REVERSEINDEX_ Persistent reverse index: tagKey -> cell of eventIds.
            persistent revIdx
            if isempty(revIdx)
                revIdx = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
            map = revIdx;
        end
    end
end
