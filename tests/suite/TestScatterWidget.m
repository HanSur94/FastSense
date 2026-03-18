classdef TestScatterWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = ScatterWidget();
            testCase.verifyEqual(w.getType(), 'scatter');
            testCase.verifyEqual(w.MarkerSize, 6);
            testCase.verifyEqual(w.Colormap, 'parula');
        end

        function testToStruct(testCase)
            w = ScatterWidget('Title', 'Scatter');
            w.MarkerSize = 10;
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'scatter');
            testCase.verifyEqual(s.markerSize, 10);
        end
    end
end
