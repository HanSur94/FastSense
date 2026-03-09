function test_datetime()
%TEST_DATETIME Tests for datetime X axis support.

    run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));
    add_fastplot_private_path();

    close all force;
    drawnow;

    % testXTypeDefaultIsNumeric
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    assert(strcmp(fp.XType, 'numeric'), 'testXTypeDefault: should be numeric');

    % testXTypeDatenum
    fp = FastPlot();
    x = datenum(2024,1,1) + (0:99)/24;
    fp.addLine(x, rand(1,100), 'XType', 'datenum');
    assert(strcmp(fp.XType, 'datenum'), 'testXTypeDatenum: should be datenum');

    % testDatetimeAutoConvert
    % Only run in MATLAB where datetime exists
    if exist('datetime', 'class')
        fp = FastPlot();
        dt = datetime(2024,1,1) + hours(0:99);
        fp.addLine(dt, rand(1,100));
        assert(strcmp(fp.XType, 'datenum'), 'testDatetimeAutoConvert: should be datenum');
        assert(isnumeric(fp.Lines(1).X), 'testDatetimeAutoConvert: X should be numeric');
    end

    % testTickLabelsAreDateStrings
    fp = FastPlot();
    x = datenum(2024,1,1) + (0:99)/24;  % ~4 days of hourly data
    fp.addLine(x, rand(1,100), 'XType', 'datenum');
    fp.render();
    labels = get(fp.hAxes, 'XTickLabel');
    % Labels should contain ':' (time formatting) not plain numbers
    hasTime = false;
    for i = 1:numel(labels)
        if any(labels{i} == ':')
            hasTime = true;
            break;
        end
    end
    assert(hasTime, 'testTickLabels: should have time-formatted labels');
    close(fp.hFigure);

    % testTickFormatChangesOnZoom
    fp = FastPlot();
    x = datenum(2024,1,1) + (0:9999)/86400;  % ~0.1s resolution
    fp.addLine(x, rand(1,10000), 'XType', 'datenum');
    fp.render();
    % Zoom to 30 seconds
    set(fp.hAxes, 'XLim', [x(1), x(1) + 30/86400]);
    drawnow;
    labels = get(fp.hAxes, 'XTickLabel');
    % Should show seconds (HH:MM:SS format)
    hasSeconds = false;
    for i = 1:numel(labels)
        if sum(labels{i} == ':') >= 2
            hasSeconds = true;
            break;
        end
    end
    assert(hasSeconds, 'testTickFormatZoom: should show seconds when zoomed');
    close(fp.hFigure);

    % testToolbarFormatX
    % Verify the static helper returns date string for datenum XType
    xVal = datenum(2024, 3, 15, 10, 30, 45);
    result = FastPlotToolbar.formatX(xVal, 'datenum');
    assert(any(result == ':'), 'testToolbarFormatX: should contain colon');
    resultNum = FastPlotToolbar.formatX(42.5, 'numeric');
    assert(~any(resultNum == ':'), 'testToolbarFormatXNum: should not contain colon');

    fprintf('    All datetime tests passed.\n');
end
