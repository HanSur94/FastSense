classdef TestMultiStatusWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = MultiStatusWidget();
            testCase.verifyEqual(w.getType(), 'multistatus');
            testCase.verifyEqual(w.ShowLabels, true);
            testCase.verifyEqual(w.IconStyle, 'dot');
        end

        function testToStruct(testCase)
            w = MultiStatusWidget('Title', 'Status Grid');
            w.Columns = 4;
            w.IconStyle = 'square';
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'multistatus');
            testCase.verifyEqual(s.columns, 4);
            testCase.verifyEqual(s.iconStyle, 'square');
        end
    end
end
