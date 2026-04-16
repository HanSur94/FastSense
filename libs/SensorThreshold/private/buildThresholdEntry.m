function th = buildThresholdEntry(segBounds, thY, rule)
%BUILDTHRESHOLDENTRY Build a resolved threshold struct from segment data.
%   th = BUILDTHRESHOLDENTRY(segBounds, thY, rule) constructs a scalar
%   struct representing a single threshold time series.  The struct
%   carries the segment-boundary X grid, the corresponding threshold
%   Y values (NaN where the rule is inactive), and visual properties
%   copied from the originating ThresholdRule.
%
%   This struct is the intermediate representation used during
%   Sensor.resolve() before the final merge and step-function
%   conversion performed by mergeResolvedByLabel().
%
%   Inputs:
%     segBounds — 1xS double, segment boundary timestamps
%     thY       — 1xS double, threshold value at each boundary (NaN
%                 where the rule's condition is not satisfied)
%     rule      — ThresholdRule object providing metadata; typically an
%                 internal condition from Threshold.conditions_
%
%   Output:
%     th — scalar struct with fields:
%          .X         — 1xS double, segment boundary timestamps
%          .Y         — 1xS double, threshold values (with NaN gaps)
%          .Direction — char, 'upper' or 'lower'
%          .Label     — char, display label
%          .Color     — 1x3 double or [], RGB color
%          .LineStyle — char, line-style token
%          .Value     — numeric, the constant threshold value
%
%   See also Sensor.resolve, appendResults, mergeResolvedByLabel.

    th.X = segBounds;
    th.Y = thY;
    th.Direction = rule.Direction;
    th.Label = rule.Label;
    th.Color = rule.Color;
    th.LineStyle = rule.LineStyle;
    th.Value = rule.Value;
end
