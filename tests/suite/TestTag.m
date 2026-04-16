classdef TestTag < matlab.unittest.TestCase
    %TESTTAG Unit tests for the Tag abstract base class.
    %   Covers (Phase 1004-01):
    %     - Constructor required-Key validation (Tag:invalidKey)
    %     - Default property values (Key, Name, Units, Description,
    %       Labels, Metadata, Criticality, SourceRef)
    %     - Name-value constructor parsing
    %     - Unknown option rejection (Tag:unknownOption)
    %     - Labels default and assignment (META-01)
    %     - Metadata open-struct behavior (META-03)
    %     - Criticality enum validation (META-04, Tag:invalidCriticality)
    %     - Abstract-by-convention stubs (TAG-01): all 6 methods throw
    %       Tag:notImplemented when invoked on the base class
    %     - resolveRefs default no-op hook (NOT abstract)
    %     - Pitfall 1 gate: exactly 6 'Tag:notImplemented' occurrences in Tag.m
    %
    %   See also Tag, MockTag, TestCompositeThreshold.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)

        function testConstructorRequiresKey(testCase)
            % Key must be non-empty char.
            testCase.verifyError(@() MockTag(), 'Tag:invalidKey');
            testCase.verifyError(@() MockTag(''), 'Tag:invalidKey');
        end

        function testConstructorDefaults(testCase)
            t = MockTag('k');
            testCase.verifyEqual(t.Key, 'k');
            testCase.verifyEqual(t.Name, 'k');  % defaults to Key
            testCase.verifyEqual(t.Units, '');
            testCase.verifyEqual(t.Description, '');
            testCase.verifyTrue(iscell(t.Labels));
            testCase.verifyEmpty(t.Labels);
            testCase.verifyTrue(isempty(fieldnames(t.Metadata)));
            testCase.verifyEqual(t.Criticality, 'medium');
            testCase.verifyEqual(t.SourceRef, '');
        end

        function testConstructorNameValuePairs(testCase)
            t = MockTag('k', 'Name', 'Pump A', 'Units', 'bar', ...
                'Description', 'main pump', ...
                'Labels', {'alpha', 'beta'}, ...
                'Metadata', struct('asset', 'p3'), ...
                'Criticality', 'safety', ...
                'SourceRef', 'file.mat');
            testCase.verifyEqual(t.Name, 'Pump A');
            testCase.verifyEqual(t.Units, 'bar');
            testCase.verifyEqual(t.Description, 'main pump');
            testCase.verifyEqual(numel(t.Labels), 2);
            testCase.verifyEqual(t.Labels{1}, 'alpha');
            testCase.verifyEqual(t.Labels{2}, 'beta');
            testCase.verifyEqual(t.Metadata.asset, 'p3');
            testCase.verifyEqual(t.Criticality, 'safety');
            testCase.verifyEqual(t.SourceRef, 'file.mat');
        end

        function testConstructorUnknownOptionErrors(testCase)
            testCase.verifyError(@() MockTag('k', 'Bogus', 1), 'Tag:unknownOption');
        end

        function testLabelsDefault(testCase)
            t = MockTag('k');
            testCase.verifyTrue(iscell(t.Labels));
            testCase.verifyEmpty(t.Labels);
        end

        function testLabelsAssign(testCase)
            t = MockTag('k');
            t.Labels = {'x', 'y'};
            testCase.verifyEqual(numel(t.Labels), 2);
            testCase.verifyEqual(t.Labels{1}, 'x');
            testCase.verifyEqual(t.Labels{2}, 'y');
        end

        function testMetadataOpenStruct(testCase)
            t = MockTag('k');
            t.Metadata.asset = 'pump-3';
            t.Metadata.vendor = 'Acme';
            testCase.verifyEqual(t.Metadata.asset, 'pump-3');
            testCase.verifyEqual(t.Metadata.vendor, 'Acme');
        end

        function testMetadataEmptyByDefault(testCase)
            testCase.verifyTrue(isempty(fieldnames(MockTag('k').Metadata)));
        end

        function testCriticalityDefault(testCase)
            testCase.verifyEqual(MockTag('k').Criticality, 'medium');
        end

        function testCriticalityAllValidValues(testCase)
            valid = {'low', 'medium', 'high', 'safety'};
            for i = 1:numel(valid)
                t = MockTag('k', 'Criticality', valid{i});
                testCase.verifyEqual(t.Criticality, valid{i});
            end
        end

        function testCriticalityInvalidInConstructor(testCase)
            testCase.verifyError(@() MockTag('k', 'Criticality', 'emergency'), ...
                'Tag:invalidCriticality');
        end

        function testCriticalityInvalidViaSetter(testCase)
            t = MockTag('k');
            testCase.verifyError(@() assignCriticality(t, 'bogus'), ...
                'Tag:invalidCriticality');
        end

        function testAbstractGetXYThrows(testCase)
            % Tag is abstract-by-convention (NOT declared Abstract), so the
            % base class is instantiable; calling any stub raises notImplemented.
            t = Tag('k');
            testCase.verifyError(@() t.getXY(), 'Tag:notImplemented');
        end

        function testAbstractValueAtThrows(testCase)
            t = Tag('k');
            testCase.verifyError(@() t.valueAt(0), 'Tag:notImplemented');
        end

        function testAbstractGetTimeRangeThrows(testCase)
            t = Tag('k');
            testCase.verifyError(@() t.getTimeRange(), 'Tag:notImplemented');
        end

        function testAbstractGetKindThrows(testCase)
            t = Tag('k');
            testCase.verifyError(@() t.getKind(), 'Tag:notImplemented');
        end

        function testAbstractToStructThrows(testCase)
            t = Tag('k');
            testCase.verifyError(@() t.toStruct(), 'Tag:notImplemented');
        end

        function testAbstractFromStructThrows(testCase)
            testCase.verifyError(@() Tag.fromStruct(struct()), 'Tag:notImplemented');
        end

        function testResolveRefsDefaultIsNoOp(testCase)
            t = MockTag('k');
            fakeRegistry = containers.Map();
            % Should not throw — default is no-op.
            t.resolveRefs(fakeRegistry);
            testCase.verifyTrue(true);  % reaching here proves no throw
        end

        function testAbstractMethodCount(testCase)
            %TESTABSTRACTMETHODCOUNT Pitfall 1 gate: exactly 6 abstract stubs.
            %   Tag.m must contain exactly 6 'Tag:notImplemented' error calls
            %   — one per abstract-by-convention method
            %   (getXY, valueAt, getTimeRange, getKind, toStruct, fromStruct).
            tagPath = which('Tag');
            testCase.assertNotEmpty(tagPath, 'Tag.m not found on path.');
            src = fileread(tagPath);
            count = numel(strfind(src, 'Tag:notImplemented'));
            testCase.verifyEqual(count, 6, ...
                sprintf('Expected exactly 6 abstract-by-convention stubs, got %d', count));
        end

    end
end

function assignCriticality(t, v)
    %ASSIGNCRITICALITY Helper to invoke the Criticality setter in a callable form.
    t.Criticality = v;
end
