classdef CompanionTimeRange < handle
%COMPANIONTIMERANGE Source of truth for the companion's global time window.
%
%   Holds a spec (relative / absolute / all) and resolves it to a concrete
%   [t0, t1] in MATLAB datenum at query time.  Relative specs resolve against
%   wall-clock now().  Fires RangeChanged on every edit via notify().
%
%   Usage:
%     r = CompanionTimeRange();             % default: Last 7 days
%     r.setRelative(24, 'hours');           % Last 24 hours
%     r.setAbsolute(datenum(2024,1,1), datenum(2024,3,1));
%     r.setAll();                           % full series
%     [t0, t1] = r.resolve();              % concrete datenum window
%     lbl = r.label();                     % e.g. 'Last 7 days'
%
%   Events:
%     RangeChanged — fired by setRelative, setAbsolute, setAll.
%
%   Methods:
%     resolve        — [t0,t1] datenum; 'all' yields t0=[], t1=[]
%     setRelative    — set relative spec (N, unit); fires RangeChanged
%     setAbsolute    — set absolute spec (t0, t1 datenum); fires RangeChanged
%     setAll         — set all-data spec; fires RangeChanged
%     label          — char label for toolbar button
%     isDefault      — true iff spec equals default (relative N=7 unit='days')
%     toStruct       — struct for companionPrefs persistence
%     fromStruct     — (Static) rebuild from toStruct output
%
%   See also FastSenseCompanion, CompanionTimeBar.

    events
        % RANGECHANGED Fired when the spec is edited via setRelative/setAbsolute/setAll.
        RangeChanged
    end

    properties (Access = private)
        SpecType_ = 'relative'   % 'relative' | 'absolute' | 'all'
        RelN_     = 7            % numeric — magnitude for relative spec
        RelUnit_  = 'days'       % 'hours' | 'days' | 'weeks' | 'months' | 'years'
        AbsT0_    = []           % datenum scalar — absolute window start
        AbsT1_    = []           % datenum scalar — absolute window end
    end

    methods

        function [t0, t1] = resolve(obj)
        %RESOLVE Resolve the current spec to concrete [t0, t1] datenum.
        %
        %   Returns datenum scalars t0 <= t1.
        %   For 'relative': t1 = now(); t0 = t1 - N_as_days.
        %   For 'absolute': returns exactly the stored [AbsT0_, AbsT1_].
        %   For 'all':      returns t0=[], t1=[] signalling "full series".
            switch obj.SpecType_
                case 'relative'
                    t1 = now();
                    t0 = t1 - obj.relN_asDays_();
                case 'absolute'
                    t0 = obj.AbsT0_;
                    t1 = obj.AbsT1_;
                case 'all'
                    t0 = [];
                    t1 = [];
                otherwise
                    t0 = [];
                    t1 = [];
            end
        end

        function setRelative(obj, N, unit)
        %SETRELATIVE Set relative spec and fire RangeChanged.
        %
        %   setRelative(obj, N, unit) where N > 0 and unit is one of
        %   'hours', 'days', 'weeks', 'months', 'years'.
        %
        %   Throws CompanionTimeRange:invalidUnit if unit is not recognised.
            valid = {'hours', 'days', 'weeks', 'months', 'years'};
            if ~ismember(unit, valid)
                error('CompanionTimeRange:invalidUnit', ...
                    'unit must be one of: %s', strjoin(valid, ', '));
            end
            obj.SpecType_ = 'relative';
            obj.RelN_     = N;
            obj.RelUnit_  = unit;
            notify(obj, 'RangeChanged');
        end

        function setAbsolute(obj, t0, t1)
        %SETABSOLUTE Set absolute spec and fire RangeChanged.
        %
        %   setAbsolute(obj, t0, t1) where t0 and t1 are datenum scalars
        %   with t0 < t1.
        %
        %   Throws CompanionTimeRange:invalidBounds if t0 >= t1 or non-scalar.
            if ~(isscalar(t0) && isscalar(t1)) || t0 >= t1
                error('CompanionTimeRange:invalidBounds', ...
                    't0 and t1 must be scalars with t0 < t1.');
            end
            obj.SpecType_ = 'absolute';
            obj.AbsT0_    = t0;
            obj.AbsT1_    = t1;
            notify(obj, 'RangeChanged');
        end

        function setAll(obj)
        %SETALL Set all-data spec and fire RangeChanged.
        %
        %   Resolves to t0=[], t1=[] (full series).
            obj.SpecType_ = 'all';
            notify(obj, 'RangeChanged');
        end

        function lbl = label(obj)
        %LABEL Return the human-readable toolbar label for the current spec.
        %
        %   'relative'  -> 'Last N unit'                    e.g. 'Last 7 days'
        %   'absolute'  -> 'YYYY-MM-DD to YYYY-MM-DD'       e.g. '2024-01-01 to 2024-03-01'
        %   'all'       -> 'All data'
            switch obj.SpecType_
                case 'relative'
                    lbl = sprintf('Last %d %s', obj.RelN_, obj.RelUnit_);
                case 'absolute'
                    lbl = sprintf('%s to %s', ...
                        datestr(obj.AbsT0_, 'yyyy-mm-dd'), ...
                        datestr(obj.AbsT1_, 'yyyy-mm-dd'));
                case 'all'
                    lbl = 'All data';
                otherwise
                    lbl = 'All data';
            end
        end

        function tf = isDefault(obj)
        %ISDEFAULT Return true iff spec equals the default (relative N=7 unit='days').
        %
        %   Used by the toolbar to show the accent colour only when a
        %   non-default filter is active.
            tf = strcmp(obj.SpecType_, 'relative') && ...
                 obj.RelN_ == 7 && ...
                 strcmp(obj.RelUnit_, 'days');
        end

        function s = toStruct(obj)
        %TOSTRUCT Serialise spec to a plain struct for companionPrefs persistence.
        %
        %   Fields: type (char), N (double), unit (char), t0 (double|[]), t1 (double|[]).
        %   Round-trips through fromStruct.
            s = struct( ...
                'type', obj.SpecType_, ...
                'N',    obj.RelN_,    ...
                'unit', obj.RelUnit_, ...
                't0',   obj.AbsT0_,  ...
                't1',   obj.AbsT1_);
        end

    end

    methods (Static)

        function obj = fromStruct(s)
        %FROMSTRUCT Rebuild a CompanionTimeRange from a toStruct output.
        %
        %   Tolerant of missing or empty fields — falls back to defaults.
        %   Non-struct input silently returns a default CompanionTimeRange.
            obj = CompanionTimeRange();
            if ~isstruct(s)
                return;
            end
            if isfield(s, 'type') && ~isempty(s.type)
                obj.SpecType_ = s.type;
            end
            if isfield(s, 'N') && ~isempty(s.N)
                obj.RelN_ = s.N;
            end
            if isfield(s, 'unit') && ~isempty(s.unit)
                obj.RelUnit_ = s.unit;
            end
            if isfield(s, 't0')
                obj.AbsT0_ = s.t0;
            end
            if isfield(s, 't1')
                obj.AbsT1_ = s.t1;
            end
        end

    end

    methods (Access = private)

        function d = relN_asDays_(obj)
        %RELN_ASDAYS_ Convert RelN_ to fractional days for resolve().
        %
        %   hours  -> N/24
        %   days   -> N
        %   weeks  -> 7*N
        %   months -> 30*N  (30-day month approximation)
        %   years  -> 365*N (365-day year approximation)
            switch obj.RelUnit_
                case 'hours',  d = obj.RelN_ / 24;
                case 'days',   d = obj.RelN_;
                case 'weeks',  d = obj.RelN_ * 7;
                case 'months', d = obj.RelN_ * 30;
                case 'years',  d = obj.RelN_ * 365;
                otherwise,     d = obj.RelN_;
            end
        end

    end

end
