classdef ThrowingTagStub < Tag
%THROWINGTAGSTUB Test-only Tag subclass whose getXY() throws.
%   Used by test_companion_tag_status_table to verify TagStatusTableWindow.buildRow_
%   absorbs throws and renders em-dash placeholders without aborting.
%
%   Reports itself as a 'sensor' kind so the type/criticality columns render
%   normally; only the dynamic columns should fall back to em-dash.
%
%   See also Tag, TagStatusTableWindow, test_companion_tag_status_table.

    methods
        function obj = ThrowingTagStub(key)
            obj@Tag(key);
        end

        function [X, Y] = getXY(obj) %#ok<STOUT,MANU>
            %GETXY Always throws — exercises buildRow_ error-recovery path.
            error('ThrowingTagStub:intentional', ...
                'getXY intentionally throws for test_companion_tag_status_table.');
        end

        function v = valueAt(obj, t) %#ok<STOUT,INUSD>
            %VALUEAT Always throws.
            error('ThrowingTagStub:intentional', ...
                'valueAt intentionally throws for test_companion_tag_status_table.');
        end

        function [tMin, tMax] = getTimeRange(obj) %#ok<MANU>
            %GETTIMERANGE Empty range.
            tMin = NaN;
            tMax = NaN;
        end

        function k = getKind(obj) %#ok<MANU>
            %GETKIND Pretend to be a sensor so the type column has a real value.
            k = 'sensor';
        end

        function s = toStruct(obj) %#ok<MANU>
            %TOSTRUCT Not needed for these tests.
            s = struct('kind', 'sensor');
        end
    end
end
