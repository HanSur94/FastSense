classdef TestDatetime < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testXTypeDefaultIsNumeric(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            testCase.verifyEqual(fp.XType, 'numeric', 'testXTypeDefault: should be numeric');
        end

        function testXTypeDatenum(testCase)
            fp = FastSense();
            x = datenum(2024,1,1) + (0:99)/24;
            fp.addLine(x, rand(1,100), 'XType', 'datenum');
            testCase.verifyEqual(fp.XType, 'datenum', 'testXTypeDatenum: should be datenum');
        end

        function testDatetimeAutoConvert(testCase)
            if exist('datetime', 'class')
                fp = FastSense();
                dt = datetime(2024,1,1) + hours(0:99);
                fp.addLine(dt, rand(1,100));
                testCase.verifyEqual(fp.XType, 'datenum', 'testDatetimeAutoConvert: should be datenum');
                testCase.verifyTrue(isnumeric(fp.Lines(1).X), 'testDatetimeAutoConvert: X should be numeric');
            end
        end

        function testTickLabelsAreDateStrings(testCase)
            fp = FastSense();
            x = datenum(2024,1,1) + (0:99)/24;  % ~4 days of hourly data
            fp.addLine(x, rand(1,100), 'XType', 'datenum');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            labels = cellstr(get(fp.hAxes, 'XTickLabel'));
            % Labels should contain ':' (time formatting) not plain numbers
            hasTime = false;
            for i = 1:numel(labels)
                if any(labels{i} == ':')
                    hasTime = true;
                    break;
                end
            end
            testCase.verifyTrue(hasTime, 'testTickLabels: should have time-formatted labels');
        end

        function testTickFormatChangesOnZoom(testCase)
            fp = FastSense();
            x = datenum(2024,1,1) + (0:9999)/86400;  % ~0.1s resolution
            fp.addLine(x, rand(1,10000), 'XType', 'datenum');
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            % Zoom to 30 seconds
            set(fp.hAxes, 'XLim', [x(1), x(1) + 30/86400]);
            drawnow;
            labels = cellstr(get(fp.hAxes, 'XTickLabel'));
            % Should show seconds (HH:MM:SS format)
            hasSeconds = false;
            for i = 1:numel(labels)
                if sum(labels{i} == ':') >= 2
                    hasSeconds = true;
                    break;
                end
            end
            testCase.verifyTrue(hasSeconds, 'testTickFormatZoom: should show seconds when zoomed');
        end

        function testToolbarFormatX(testCase)
            % Verify the static helper returns date string for datenum XType
            xVal = datenum(2024, 3, 15, 10, 30, 45);
            result = FastSenseToolbar.formatX(xVal, 'datenum');
            testCase.verifyTrue(any(result == ':'), 'testToolbarFormatX: should contain colon');
            resultNum = FastSenseToolbar.formatX(42.5, 'numeric');
            testCase.verifyTrue(~any(resultNum == ':'), 'testToolbarFormatXNum: should not contain colon');
        end
    end
end
