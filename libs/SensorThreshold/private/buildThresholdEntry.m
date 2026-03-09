function th = buildThresholdEntry(segBounds, thY, rule)
%BUILDTHRESHOLDENTRY Build resolved threshold struct from segment data.
    th.X = segBounds;
    th.Y = thY;
    th.Direction = rule.Direction;
    th.Label = rule.Label;
    th.Color = rule.Color;
    th.LineStyle = rule.LineStyle;
    th.Value = rule.Value;
end
