classdef MockDataSource < DataSource
    % MockDataSource  Generates realistic industrial sensor signals for testing.

    properties
        BaseValue       = 100
        NoiseStd        = 1
        DriftRate       = 0        % drift per second
        SampleInterval  = 3        % seconds between points
        BacklogDays     = 3        % days of history on first fetch
        ViolationProbability  = 0.005  % chance per point of starting violation
        ViolationAmplitude    = 20     % how far signal ramps beyond base
        ViolationDuration     = 60     % seconds per violation episode
        StateValues           = {{}}   % cell of char, e.g. {'idle','running'}
        StateChangeProbability = 0.001 % chance per point of state transition
        Seed                  = []     % optional RNG seed
        PipelineInterval      = 15     % seconds per fetch cycle
    end

    properties (Access = private)
        rng_            % RNG stream
        lastTime_       % datenum of last generated point
        backlogDone_    = false
        currentState_   = ''
        inViolation_    = false
        violationEnd_   = 0
        violationSign_  = 1
        driftAccum_     = 0
    end

    methods
        function obj = MockDataSource(varargin)
            p = inputParser();
            p.addParameter('BaseValue',       100);
            p.addParameter('NoiseStd',        1);
            p.addParameter('DriftRate',        0);
            p.addParameter('SampleInterval',   3);
            p.addParameter('BacklogDays',      3);
            p.addParameter('ViolationProbability',  0.005);
            p.addParameter('ViolationAmplitude',    20);
            p.addParameter('ViolationDuration',     60);
            p.addParameter('StateValues',      {{}});
            p.addParameter('StateChangeProbability', 0.001);
            p.addParameter('Seed',             []);
            p.addParameter('PipelineInterval', 15);
            p.parse(varargin{:});
            flds = fieldnames(p.Results);
            for i = 1:numel(flds)
                obj.(flds{i}) = p.Results.(flds{i});
            end
            if exist('RandStream', 'class')
                if ~isempty(obj.Seed)
                    obj.rng_ = RandStream('mt19937ar', 'Seed', obj.Seed);
                else
                    obj.rng_ = RandStream('mt19937ar', 'Seed', 'shuffle');
                end
            else
                % Octave: seed the global RNG instead
                if ~isempty(obj.Seed)
                    rand('state', obj.Seed);
                    randn('state', obj.Seed);
                end
                obj.rng_ = [];
            end
            if ~isempty(obj.StateValues) && ~isempty(obj.StateValues{1})
                obj.currentState_ = obj.StateValues{1}{1};
            end
        end

        function result = fetchNew(obj)
            if ~obj.backlogDone_
                result = obj.generateBacklog();
                obj.backlogDone_ = true;
            else
                result = obj.generateIncremental();
            end
        end
    end

    methods (Access = private)
        function v = rngRand(obj)
            if isempty(obj.rng_); v = rand(); else; v = obj.rng_.rand(); end
        end
        function v = rngRandn(obj)
            if isempty(obj.rng_); v = randn(); else; v = obj.rng_.randn(); end
        end
        function v = rngRandi(obj, n)
            if isempty(obj.rng_); v = randi(n); else; v = obj.rng_.randi(n); end
        end

        function result = generateBacklog(obj)
            nPoints = floor(obj.BacklogDays * 86400 / obj.SampleInterval);
            if ~isempty(obj.Seed)
                % Use a fixed reference time for deterministic output
                tEnd = floor(now);
            else
                tEnd = now;
            end
            dt = obj.SampleInterval / 86400;  % to datenum
            tStart = tEnd - (nPoints - 1) * dt;
            X = tStart + dt * (0:nPoints-1);
            [Y, stateX, stateY] = obj.generateSignal(X);
            obj.lastTime_ = X(end);
            result = struct('X', X, 'Y', Y, 'stateX', stateX, 'stateY', {stateY}, 'changed', true);
        end

        function result = generateIncremental(obj)
            nPoints = round(obj.PipelineInterval / obj.SampleInterval);
            dt = obj.SampleInterval / 86400;  % to datenum
            X = obj.lastTime_ + dt * (1:nPoints);
            [Y, stateX, stateY] = obj.generateSignal(X);
            obj.lastTime_ = X(end);
            result = struct('X', X, 'Y', Y, 'stateX', stateX, 'stateY', {stateY}, 'changed', true);
        end

        function [Y, stateX, stateY] = generateSignal(obj, X)
            n = numel(X);
            Y = zeros(1, n);
            stateX = [];
            stateY = {};
            hasStates = ~isempty(obj.StateValues) && ~isempty(obj.StateValues{1});

            for i = 1:n
                % Drift
                obj.driftAccum_ = obj.driftAccum_ + obj.DriftRate * obj.SampleInterval;

                % Base + noise + drift
                noise = obj.NoiseStd * obj.rngRandn();
                val = obj.BaseValue + obj.driftAccum_ + noise;

                % Violation episode
                if obj.inViolation_
                    tSec = (X(i) - obj.violationEnd_) * 86400;
                    if tSec >= 0
                        obj.inViolation_ = false;
                    else
                        remaining = (obj.violationEnd_ - X(i)) * 86400;
                        total = obj.ViolationDuration;
                        progress = 1 - remaining / total;
                        envelope = sin(pi * progress);  % smooth ramp up and down
                        val = val + obj.violationSign_ * obj.ViolationAmplitude * envelope;
                    end
                else
                    if obj.rngRand() < obj.ViolationProbability
                        obj.inViolation_ = true;
                        obj.violationEnd_ = X(i) + obj.ViolationDuration / 86400;
                        obj.violationSign_ = 2 * (obj.rngRand() > 0.5) - 1;
                    end
                end

                Y(i) = val;

                % State transitions (sparse)
                if hasStates && obj.rngRand() < obj.StateChangeProbability
                    states = obj.StateValues{1};
                    newIdx = obj.rngRandi(numel(states));
                    newState = states{newIdx};
                    if ~strcmp(newState, obj.currentState_)
                        obj.currentState_ = newState;
                        stateX(end+1) = X(i);
                        stateY{end+1} = newState;
                    end
                end
            end
        end
    end
end
