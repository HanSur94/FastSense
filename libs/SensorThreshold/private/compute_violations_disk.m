function [batchViolX, batchViolY] = compute_violations_disk(ds, segLo, segHi, thresholdValues, directions)
%COMPUTE_VIOLATIONS_DISK Memory-efficient violation detection for disk-backed sensors.
%   Uses DataStore.findViolations() which filters by chunk-level y_min/y_max
%   metadata, skipping entire chunks that cannot contain violations.  Peak
%   memory is proportional to the hot chunks rather than the full dataset.
%
%   Inputs:
%     ds              — FastPlotDataStore, disk-backed data source
%     segLo           — 1xS integer, start indices of active segments
%     segHi           — 1xS integer, end indices of active segments
%     thresholdValues — 1xT double, threshold value for each rule
%     directions      — 1xT logical, true = upper, false = lower
%
%   Outputs:
%     batchViolX — 1xT cell array of violation X coordinates
%     batchViolY — 1xT cell array of violation Y coordinates
%
%   See also compute_violations_batch, Sensor.resolve, FastPlotDataStore.

    nThresholds = numel(thresholdValues);
    nSegs = numel(segLo);

    batchViolX = cell(1, nThresholds);
    batchViolY = cell(1, nThresholds);

    for t = 1:nThresholds
        vxParts = cell(1, nSegs);
        vyParts = cell(1, nSegs);
        for s = 1:nSegs
            [vxParts{s}, vyParts{s}] = ds.findViolations( ...
                segLo(s), segHi(s), thresholdValues(t), directions(t));
        end
        batchViolX{t} = [vxParts{:}];
        batchViolY{t} = [vyParts{:}];
    end
end
