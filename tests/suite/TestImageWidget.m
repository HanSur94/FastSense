classdef TestImageWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = ImageWidget();
            testCase.verifyEqual(w.getType(), 'image');
            testCase.verifyEqual(w.Scaling, 'fit');
        end

        function testRenderWithImageFcn(testCase)
            w = ImageWidget('Title', 'Test Image');
            w.ImageFcn = @() uint8(randi(255, 50, 50, 3));

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hPanel);
        end

        function testToStruct(testCase)
            w = ImageWidget('Title', 'Img');
            w.File = '/tmp/test.png';
            w.Caption = 'A test image';
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'image');
            testCase.verifyEqual(s.file, '/tmp/test.png');
            testCase.verifyEqual(s.caption, 'A test image');
        end
    end
end
