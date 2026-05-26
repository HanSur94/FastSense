classdef ComputeAddStub < handle
    %COMPUTEADDSTUB Test-only object-form compute strategy for DerivedTag.
    %   Implements the object-compute contract expected by DerivedTag —
    %   a `compute(parents)` method returning [X, Y] — plus toStruct /
    %   fromStruct so the round-trip path through DerivedTag.toStruct /
    %   DerivedTag.fromStruct + resolveRefs can be exercised.
    %
    %   Used exclusively by TestDerivedTag.m. Lives in tests/suite/ so
    %   the run_all_tests harness picks it up alongside the test class.
    %
    %   Example:
    %     stub = ComputeAddStub(2);            % Scale = 2
    %     d = DerivedTag('d', {a, b}, stub);   % object-compute path
    %     [x, y] = d.getXY();                  % y = (a.Y + b.Y) * 2
    %
    %   See also DerivedTag, TestDerivedTag.

    properties
        Scale = 1   % multiplier applied to (parents{1}.Y + parents{2}.Y)
    end

    methods
        function obj = ComputeAddStub(scale)
            %COMPUTEADDSTUB Construct with optional scale (default 1).
            if nargin >= 1 && ~isempty(scale)
                obj.Scale = scale;
            end
        end

        function [X, Y] = compute(obj, parents)
            %COMPUTE Sum first two parents' Y values, scaled by obj.Scale.
            %   Returns the X grid of parents{1} verbatim — the test fixtures
            %   align both parents on the same grid.
            X = parents{1}.X;
            Y = (parents{1}.Y + parents{2}.Y) * obj.Scale;
        end

        function s = toStruct(obj)
            %TOSTRUCT Serialize to a plain struct (Scale only).
            s = struct();
            s.Scale = obj.Scale;
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            %FROMSTRUCT Reconstruct a ComputeAddStub from a toStruct output.
            obj = ComputeAddStub();
            if isstruct(s) && isfield(s, 'Scale') && ~isempty(s.Scale)
                obj.Scale = s.Scale;
            end
        end
    end
end
