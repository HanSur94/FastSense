classdef ConsoleProgressBar < handle
%CONSOLEPROGRESSBAR Single-line console progress bar with indentation.
%   Uses fprintf + carriage return to animate a progress bar on one line.
%   Call freeze() to make the current state permanent (prints newline)
%   so the next bar can start on a fresh line below.
%
%   Usage:
%     pb = ConsoleProgressBar(2);   % 2-space indent
%     pb.start();
%     for k = 1:8
%         pb.update(k, 8, 'Tile 1');
%         pause(0.1);
%     end
%     pb.freeze();   % becomes permanent line
%
%   See also FastPlot, FastPlotFigure, FastPlotDock.

    properties (Access = private)
        Label        char = ''
        Current      (1,1) double = 0
        Total        (1,1) double = 0
        BarWidth     (1,1) double = 30
        Indent       (1,1) double = 0    % number of leading spaces
        IsStarted    (1,1) logical = false
        IsFrozen     (1,1) logical = false
        LastLen      (1,1) double = 0
    end

    methods
        function obj = ConsoleProgressBar(indent)
        %CONSOLEPROGRESSBAR Construct a progress bar.
        %   pb = ConsoleProgressBar()       — no indent
        %   pb = ConsoleProgressBar(indent) — indent spaces
            if nargin >= 1
                obj.Indent = indent;
            end
        end

        function start(obj)
        %START Initialize the progress display.
            obj.IsStarted = true;
            obj.IsFrozen  = false;
            obj.LastLen   = 0;
            obj.printBar();
        end

        function update(obj, current, total, label)
        %UPDATE Update progress and redraw.
        %   pb.update(current, total)
        %   pb.update(current, total, label)
            obj.Current = current;
            obj.Total   = total;
            if nargin >= 4
                obj.Label = label;
            end
            if obj.IsStarted && ~obj.IsFrozen
                obj.printBar();
            end
        end

        function freeze(obj)
        %FREEZE Make current bar state permanent (print newline).
        %   After freeze(), this bar no longer updates. A new bar
        %   can start on the next line.
            if ~obj.IsStarted || obj.IsFrozen; return; end
            obj.printBar();
            fprintf('\n');
            obj.IsFrozen = true;
        end

        function finish(obj)
        %FINISH Set to 100%, freeze, and mark done.
            if ~obj.IsStarted; return; end
            obj.Current = obj.Total;
            if ~obj.IsFrozen
                obj.printBar();
                fprintf('\n');
            end
            obj.IsStarted = false;
            obj.IsFrozen  = true;
        end
    end

    methods (Access = private)
        function printBar(obj)
        %PRINTBAR Redraw the bar using backspace to erase previous output.
            filled = char(9608);
            empty  = char(9617);

            prefix = repmat(' ', 1, obj.Indent);

            lbl = obj.Label;
            if numel(lbl) > 12; lbl = lbl(1:12); end
            lbl = sprintf('%-12s', lbl);

            if obj.Total > 0
                nFilled = round(obj.BarWidth * obj.Current / obj.Total);
            else
                nFilled = 0;
            end
            nFilled = max(0, min(obj.BarWidth, nFilled));
            nEmpty  = obj.BarWidth - nFilled;

            barStr = [repmat(filled, 1, nFilled), repmat(empty, 1, nEmpty)];
            line = sprintf('%s%s [%s] %d/%d', prefix, lbl, barStr, obj.Current, obj.Total);

            % Erase previous output with backspaces, then print new line
            if obj.LastLen > 0
                fprintf(repmat('\b', 1, obj.LastLen));
            end
            fprintf('%s', line);
            obj.LastLen = numel(line);
        end
    end
end
