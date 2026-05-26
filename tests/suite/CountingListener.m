classdef CountingListener < handle
%COUNTINGLISTENER Minimal listener that counts invalidate() calls.
%   Used by TestTagInvalidateBatch to verify that Tag.invalidateBatch_
%   dispatches `invalidate()` to each unique listener exactly once.
%
%   Implements the listener contract required by SensorTag.addListener,
%   StateTag.addListener, MonitorTag.addListener, CompositeTag.addListener,
%   and DerivedTag.addListener — `ismethod(m, 'invalidate')` must hold.
%
%   Not a Tag subclass — Tag.invalidateBatch_ only requires that each
%   listener handle responds to invalidate(); it does not require the
%   listener to BE a Tag. This mirrors the broader contract that any
%   handle implementing invalidate() can be a downstream observer.
%
%   See also TestTagInvalidateBatch, Tag.invalidateBatch_, ThrowingListener.

    properties (SetAccess = private)
        Count = 0
    end

    methods
        function invalidate(obj)
            %INVALIDATE Bump the call counter.
            obj.Count = obj.Count + 1;
        end
    end
end
