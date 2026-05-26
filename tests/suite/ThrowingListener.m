classdef ThrowingListener < handle
%THROWINGLISTENER Listener whose invalidate() throws a known error.
%   Used by TestTagInvalidateBatch/testListenerErrorPropagatesAndAborts
%   to verify the documented contract that Tag.invalidateBatch_ does not
%   swallow listener errors — it propagates them, and the loop aborts at
%   the throwing listener.
%
%   Implements the listener contract required by SensorTag.addListener.
%
%   See also TestTagInvalidateBatch, Tag.invalidateBatch_, CountingListener.

    properties
        ErrorId  = 'ThrowingListener:intentional'
        ErrorMsg = 'invalidate intentionally throws for test.'
    end

    methods
        function invalidate(obj)
            %INVALIDATE Throw the configured error.
            error(obj.ErrorId, '%s', obj.ErrorMsg);
        end
    end
end
