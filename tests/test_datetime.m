function test_datetime()
%TEST_DATETIME Tests for datetime X axis support.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

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

    fprintf('    All datetime input tests passed.\n');
end
