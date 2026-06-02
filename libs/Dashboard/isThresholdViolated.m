function tf = isThresholdViolated(threshold, value)
%ISTHRESHOLDVIOLATED True when VALUE strictly breaches THRESHOLD.
%   tf = isThresholdViolated(threshold, value) returns true when VALUE violates
%   any of threshold.allValues() under threshold.IsUpper, using the STRICT
%   convention: a value strictly ABOVE an upper limit, or strictly BELOW a lower
%   limit, is a violation. A value sitting EXACTLY on a limit is NOT a violation
%   — matching the SensorThreshold engine and the majority of dashboard widgets
%   (this helper removes the lone inclusive >=/<= comparison that made a sensor
%   on its limit light red in a MultiStatus tile but green in a Status dot).
%
%   This is the single source of truth for the dashboard's threshold-violation
%   check, replacing the copy-pasted comparison loops in MultiStatusWidget,
%   ChipBarWidget and IconCardWidget. (StatusWidget and GaugeWidget keep their
%   own loops because they additionally rank violations by distance to choose
%   the most-violated threshold's colour, which a boolean predicate cannot do.)
%
%   Inputs:
%     threshold — a threshold object exposing IsUpper (logical) and a
%                 allValues() method returning a numeric vector of condition
%                 values (CompositeThreshold returns [], i.e. never violated here).
%     value     — numeric scalar (latest sample or static value).
%
%   Output:
%     tf — logical scalar. Returns false for an empty threshold or value
%          (hot-path tolerant — never throws on missing data).
%
%   See also severityColor, MultiStatusWidget, ChipBarWidget, IconCardWidget.

    tf = false;
    if isempty(threshold) || isempty(value)
        return;
    end

    tVals = threshold.allValues();
    isUpper = threshold.IsUpper;
    for v = 1:numel(tVals)
        if (isUpper && value > tVals(v)) || (~isUpper && value < tVals(v))
            tf = true;
            return;
        end
    end
end
