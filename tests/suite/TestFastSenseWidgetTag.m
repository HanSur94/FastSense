classdef TestFastSenseWidgetTag < matlab.unittest.TestCase
    %TESTFASTSENSEWIDGETTAG MATLAB unittest suite for FastSenseWidget Tag migration.
    %   Phase 1009 Plan 01 — covers the additive Tag property on
    %   FastSenseWidget and proves the legacy Sensor path remains
    %   functional.  Mirror of the Octave-flat test_fastsense_widget_tag.m.
    %
    %   See also FastSenseWidget, makePhase1009Fixtures.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'tests', 'suite'));
        end
    end

    methods (TestMethodSetup)
        function resetRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function teardownRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)

        function testSensorTagRender(testCase)
            st = makePhase1009Fixtures.makeSensorTag('press_a', 'Units', 'bar');

            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            w = FastSenseWidget('Tag', st);
            w.render(hp);

            testCase.verifyNotEmpty(w.FastSenseObj);
            testCase.verifyTrue(w.FastSenseObj.IsRendered);
            testCase.verifyGreaterThanOrEqual(numel(w.FastSenseObj.Lines), 1);
        end

        function testMonitorTagRender(testCase)
            st = makePhase1009Fixtures.makeSensorTag('press_b');
            m  = makePhase1009Fixtures.makeMonitorTag('press_hi', st);

            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            w = FastSenseWidget('Tag', m);
            w.render(hp);

            testCase.verifyNotEmpty(w.FastSenseObj);
            testCase.verifyTrue(w.FastSenseObj.IsRendered);
        end

        function testTagUpdateIncremental(testCase)
            st = makePhase1009Fixtures.makeSensorTag('press_c', ...
                'X', 1:10, 'Y', (1:10) * 1.0);

            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            w = FastSenseWidget('Tag', st);
            w.render(hp);

            st.updateData(1:15, (1:15) * 1.0);
            w.update();

            testCase.verifyGreaterThanOrEqual(w.CachedXMax, 15);
        end

        function testTagRoundTrip(testCase)
            st = makePhase1009Fixtures.makeSensorTag('press_rt', 'Units', 'Pa');

            w = FastSenseWidget('Tag', st);
            s = w.toStruct();

            testCase.verifyTrue(isfield(s, 'source'));
            testCase.verifyEqual(s.source.type, 'tag');
            testCase.verifyEqual(s.source.key, 'press_rt');

            w2 = FastSenseWidget.fromStruct(s);
            testCase.verifyNotEmpty(w2.Tag);
            testCase.verifyTrue(w2.Tag == st);
        end

        function testLegacySensorPathStillWorks(testCase)
            s = SensorTag('legacy_s', 'Name', 'LegacyTemp');
            s.updateData(1:50, rand(1, 50));

            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            w = FastSenseWidget('Sensor', s);
            w.render(hp);

            testCase.verifyNotEmpty(w.FastSenseObj);
            testCase.verifyGreaterThanOrEqual(numel(w.FastSenseObj.Lines), 1);
        end

        function testPitfall1NoIsaInWidget(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            widgetFile = fullfile(repo, 'libs', 'Dashboard', 'FastSenseWidget.m');
            src = fileread(widgetFile);

            badKinds = {'SensorTag', 'MonitorTag', 'StateTag', 'CompositeTag'};
            for i = 1:numel(badKinds)
                pattern = ['isa\([^,]+,\s*''', badKinds{i}, ''''];
                matches = regexp(src, pattern, 'once');
                testCase.verifyEmpty(matches, ...
                    sprintf('Pitfall 1 violation — isa(.., ''%s'') in FastSenseWidget.m', ...
                            badKinds{i}));
            end
        end

        function testYLabelFromTagUnits(testCase)
            st = makePhase1009Fixtures.makeSensorTag('press_units', 'Units', 'kPa');
            w = FastSenseWidget('Tag', st);
            testCase.verifyEqual(w.YLabel, 'kPa');
        end

    end
end
